//
//  GuardianAccountService.swift
//  Ohana
//
//  Cognito hosted OAuth with Sign in with Apple and PKCE. Account use is
//  optional and isolated from the local-first app runtime.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import UIKit

nonisolated struct GuardianAccountSession: Codable, Equatable, Sendable {
    let anonymousAccountID: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isUsable: Bool {
        expiresAt.timeIntervalSinceNow > 60
    }
}

nonisolated enum GuardianAccountState: Equatable, Sendable {
    case unavailable
    case signedOut
    case signingIn
    case signedIn(accountID: String)
    case failed(message: String)
}

nonisolated enum GuardianAccountError: LocalizedError, Equatable {
    case unavailable
    case cancelled
    case invalidCallback
    case invalidIdentityToken
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            String(localized: "guardian.account.unavailable", defaultValue: "Family guardian sign-in is not available in this build.")
        case .cancelled:
            String(localized: "guardian.account.cancelled", defaultValue: "Sign in was cancelled.")
        case .invalidCallback, .invalidIdentityToken, .tokenExchangeFailed:
            String(localized: "guardian.account.failed", defaultValue: "Ohana could not complete Sign in with Apple.")
        }
    }
}

nonisolated protocol GuardianAccountTokenPersisting: Sendable {
    func load() -> GuardianAccountSession?
    func save(_ session: GuardianAccountSession)
    func clear()
}

final nonisolated class KeychainGuardianAccountTokenStore: GuardianAccountTokenPersisting, @unchecked Sendable {
    private let service = "com.guanchen.li.Ohana.guardian-account"
    private let account = "cognito.apple.session.v1"
    private let lock = NSLock()

    func load() -> GuardianAccountSession? {
        lock.withLock {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data
            else { return nil }
            return try? JSONDecoder().decode(GuardianAccountSession.self, from: data)
        }
    }

    func save(_ session: GuardianAccountSession) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(session) else { return }
            let update = [kSecValueData as String: data]
            let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
            guard status == errSecItemNotFound else { return }
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func clear() {
        _ = lock.withLock {
            SecItemDelete(baseQuery as CFDictionary)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

@MainActor
protocol GuardianAccountAuthenticating: AnyObject {
    var state: GuardianAccountState { get }
    var isSignedIn: Bool { get }
    func restore() async
    func signIn() async throws
    func signOut()
    func validAccessToken() async throws -> String
}

@MainActor
@Observable
final class GuardianAccountService: NSObject, GuardianAccountAuthenticating {
    private(set) var state: GuardianAccountState

    @ObservationIgnored private let configuration: GuardianSafetyConfiguration?
    @ObservationIgnored private let tokenStore: any GuardianAccountTokenPersisting
    @ObservationIgnored private let urlSession: URLSession
    @ObservationIgnored private var session: GuardianAccountSession?
    @ObservationIgnored private var webAuthenticationSession: ASWebAuthenticationSession?

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    init(
        configuration: GuardianSafetyConfiguration? = .current,
        tokenStore: any GuardianAccountTokenPersisting = KeychainGuardianAccountTokenStore(),
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.urlSession = urlSession
        state = configuration == nil ? .unavailable : .signedOut
        super.init()
    }

    func restore() async {
        guard configuration != nil else {
            state = .unavailable
            return
        }
        guard let stored = tokenStore.load() else {
            state = .signedOut
            return
        }
        session = stored
        if stored.isUsable {
            state = .signedIn(accountID: stored.anonymousAccountID)
            return
        }
        do {
            let refreshed = try await refresh(stored)
            accept(refreshed)
        } catch {
            tokenStore.clear()
            session = nil
            state = .signedOut
        }
    }

    func signIn() async throws {
        guard let configuration else { throw GuardianAccountError.unavailable }
        state = .signingIn
        let verifier = Self.randomURLSafeString(byteCount: 32)
        let challenge = Self.codeChallenge(for: verifier)
        let expectedState = Self.randomURLSafeString(byteCount: 24)

        var components = URLComponents(url: configuration.cognitoAuthorizationURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.cognitoClientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURL.absoluteString),
            // Guardian accounts need only Cognito's stable anonymous subject.
            // Do not request or persist the Apple relay email or profile name.
            URLQueryItem(name: "scope", value: "openid"),
            URLQueryItem(name: "identity_provider", value: "SignInWithApple"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: expectedState)
        ]
        guard let authorizationURL = components?.url else {
            state = .failed(message: GuardianAccountError.unavailable.localizedDescription)
            throw GuardianAccountError.unavailable
        }

        do {
            let callbackURL = try await authenticate(
                authorizationURL: authorizationURL,
                callbackScheme: configuration.redirectURL.scheme
            )
            guard let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  callback.queryItems?.first(where: { $0.name == "state" })?.value == expectedState,
                  let code = callback.queryItems?.first(where: { $0.name == "code" })?.value
            else { throw GuardianAccountError.invalidCallback }

            let tokenSet = try await exchange(
                form: [
                    "grant_type": "authorization_code",
                    "client_id": configuration.cognitoClientID,
                    "code": code,
                    "redirect_uri": configuration.redirectURL.absoluteString,
                    "code_verifier": verifier
                ],
                configuration: configuration,
                retainedRefreshToken: nil
            )
            accept(tokenSet)
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin {
            state = .signedOut
            throw GuardianAccountError.cancelled
        } catch {
            state = .failed(message: error.localizedDescription)
            throw error
        }
    }

    func signOut() {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        session = nil
        tokenStore.clear()
        state = configuration == nil ? .unavailable : .signedOut
    }

    func validAccessToken() async throws -> String {
        if session == nil { await restore() }
        guard let current = session else { throw GuardianAccountError.unavailable }
        if current.isUsable { return current.accessToken }
        let refreshed = try await refresh(current)
        accept(refreshed)
        return refreshed.accessToken
    }

    private func refresh(_ current: GuardianAccountSession) async throws -> GuardianAccountSession {
        guard let configuration, let refreshToken = current.refreshToken else {
            throw GuardianAccountError.tokenExchangeFailed
        }
        return try await exchange(
            form: [
                "grant_type": "refresh_token",
                "client_id": configuration.cognitoClientID,
                "refresh_token": refreshToken
            ],
            configuration: configuration,
            retainedRefreshToken: refreshToken
        )
    }

    private func accept(_ newSession: GuardianAccountSession) {
        session = newSession
        tokenStore.save(newSession)
        state = .signedIn(accountID: newSession.anonymousAccountID)
    }

    private func authenticate(
        authorizationURL: URL,
        callbackScheme: String?
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthenticationSession = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GuardianAccountError.invalidCallback)
                }
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = true
            webAuthenticationSession = authSession
            guard authSession.start() else {
                webAuthenticationSession = nil
                continuation.resume(throwing: GuardianAccountError.unavailable)
                return
            }
        }
    }

    private func exchange(
        form: [String: String],
        configuration: GuardianSafetyConfiguration,
        retainedRefreshToken: String?
    ) async throws -> GuardianAccountSession {
        var request = URLRequest(url: configuration.cognitoTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .sorted(by: { $0.key < $1.key })
            .map { key, value in "\(Self.formEncode(key))=\(Self.formEncode(value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(CognitoTokenResponse.self, from: data),
              let accountID = Self.jwtSubject(payload.idToken)
        else { throw GuardianAccountError.tokenExchangeFailed }

        return GuardianAccountSession(
            anonymousAccountID: accountID,
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken ?? retainedRefreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(payload.expiresIn, 60)))
        )
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))) ?? value
    }

    private static func jwtSubject(_ token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let data = Data(base64URLString: String(parts[1])),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = object["sub"] as? String,
              !subject.isEmpty
        else { return nil }
        return subject
    }
}

extension GuardianAccountService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let scene = scenes.first else {
            preconditionFailure("Sign in with Apple requires an active window scene")
        }
        return UIWindow(windowScene: scene)
    }
}

private nonisolated struct CognitoTokenResponse: Decodable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private nonisolated extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLString: String) {
        var value = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        value.append(String(repeating: "=", count: (4 - value.count % 4) % 4))
        self.init(base64Encoded: value)
    }
}
