//
//  GuardianSafetyAPI.swift
//  Ohana
//
//  Minimal-data API contract for the optional App-only Family guardian flow.
//

import Foundation

nonisolated struct GuardianRemotePolicyDTO: Codable, Equatable, Sendable {
    let id: String
    let isEnabled: Bool
    let status: GuardianSafetyPolicyStatus
    let weekdays: [Int]
    let deadlineHour: Int
    let deadlineMinute: Int
    let gracePeriodMinutes: Int
    let pauseUntil: Date?
    let timeZoneIdentifier: String
    let scheduleRevision: Int
    let acceptedGuardianCount: Int
    let reachableGuardianCount: Int
    let updatedAt: Date
}

nonisolated struct GuardianRemoteRelationshipDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayLabel: String
    let status: GuardianRelationshipStatus
    let reachability: GuardianNotificationReachability
    let currentUserIsGuardian: Bool
    let acceptedAt: Date?
    let revokedAt: Date?
    let lastOpenedAt: Date?
    let lastAcknowledgedAt: Date?
    let latestNotificationState: GuardianNotificationAttemptState?
    let latestNotificationUpdatedAt: Date?
    let protectedPolicyStatus: GuardianSafetyPolicyStatus?
    let protectedPauseUntil: Date?
    let updatedAt: Date
}

nonisolated struct GuardianRemoteIncidentDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let policyID: String
    let status: GuardianIncidentStatus
    let lastGuardDayKey: String
    let consecutiveMisses: Int
    let initialSubmittedAt: Date?
    let followUpSubmittedAt: Date?
    let acknowledgedAt: Date?
    let recoveredAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct GuardianSafetyDashboardSnapshot: Codable, Equatable, Sendable {
    let policy: GuardianRemotePolicyDTO?
    let relationships: [GuardianRemoteRelationshipDTO]
    let incidents: [GuardianRemoteIncidentDTO]
    let serverTime: Date

    static let empty = GuardianSafetyDashboardSnapshot(
        policy: nil,
        relationships: [],
        incidents: [],
        serverTime: .distantPast
    )
}

nonisolated struct GuardianInvitationSnapshot: Codable, Equatable, Sendable {
    let code: String
    let url: URL
    let expiresAt: Date
}

nonisolated struct GuardianPolicyUpdateRequest: Codable, Equatable, Sendable {
    let isEnabled: Bool
    let weekdays: [Int]
    let deadlineHour: Int
    let deadlineMinute: Int
    let gracePeriodMinutes: Int
    let pauseUntil: Date?
    let timeZoneIdentifier: String
    let scheduleRevision: Int
}

nonisolated struct GuardianSignalUpload: Codable, Equatable, Sendable {
    let eventKey: String
    let kind: GuardianSafetySyncEventKind
    let dayKey: String?
    let occurredAt: Date
    let timeZoneIdentifier: String
    let stopReason: GuardianSafetyStopReason?
}

nonisolated struct GuardianSignalBatchRequest: Codable, Equatable, Sendable {
    let signals: [GuardianSignalUpload]
}

nonisolated struct GuardianSignalBatchResponse: Codable, Equatable, Sendable {
    let acceptedEventKeys: [String]
    let rejectedEventKeys: [String: String]
}

nonisolated struct GuardianDeviceRegistrationRequest: Codable, Equatable, Sendable {
    let deviceID: String
    let apnsToken: String
    let environment: String
    let localeIdentifier: String
    let timeZoneIdentifier: String
    let notificationsAuthorized: Bool
}

nonisolated struct GuardianDeviceRemovalRequest: Codable, Equatable, Sendable {
    let deviceID: String
}

nonisolated struct GuardianEntitlementVerificationRequest: Codable, Equatable, Sendable {
    let signedTransactionInfo: String
}

nonisolated enum GuardianSafetyAPIError: LocalizedError, Equatable {
    case unavailable
    case unauthorized
    case rejected(code: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            String(localized: "guardian.api.unavailable", defaultValue: "Family guardian service is temporarily unavailable.")
        case .unauthorized:
            String(localized: "guardian.api.unauthorized", defaultValue: "Sign in again to continue.")
        case let .rejected(code):
            String(localized: "guardian.api.rejected", defaultValue: "The guardian request could not be completed. (\(code))")
        case .invalidResponse:
            String(localized: "guardian.api.invalid-response", defaultValue: "The guardian service returned an invalid response.")
        }
    }
}

actor GuardianSafetyAPIClient {
    private let configuration: GuardianSafetyConfiguration
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: GuardianSafetyConfiguration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func dashboard(accessToken: String) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(path: "v1/guardian/dashboard", method: "GET", accessToken: accessToken)
    }

    func createInvitation(accessToken: String) async throws -> GuardianInvitationSnapshot {
        try await send(path: "v1/guardian/invitations", method: "POST", accessToken: accessToken)
    }

    func acceptInvitation(code: String, accessToken: String) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(
            path: "v1/guardian/invitations/accept",
            method: "POST",
            body: GuardianInviteAcceptanceRequest(code: code),
            accessToken: accessToken
        )
    }

    func updatePolicy(
        _ request: GuardianPolicyUpdateRequest,
        accessToken: String
    ) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(path: "v1/guardian/policy", method: "PUT", body: request, accessToken: accessToken)
    }

    func acknowledgeIncident(
        id: String,
        accessToken: String
    ) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(
            path: "v1/guardian/incidents/\(Self.pathComponent(id))/acknowledge",
            method: "POST",
            accessToken: accessToken
        )
    }

    func markIncidentOpened(
        id: String,
        accessToken: String
    ) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(
            path: "v1/guardian/incidents/\(Self.pathComponent(id))/opened",
            method: "POST",
            accessToken: accessToken
        )
    }

    func revokeRelationship(
        id: String,
        accessToken: String
    ) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(
            path: "v1/guardian/relationships/\(Self.pathComponent(id))",
            method: "DELETE",
            accessToken: accessToken
        )
    }

    func uploadSignals(
        _ request: GuardianSignalBatchRequest,
        accessToken: String
    ) async throws -> GuardianSignalBatchResponse {
        try await send(path: "v1/guardian/signals/batch", method: "POST", body: request, accessToken: accessToken)
    }

    func registerDevice(
        _ request: GuardianDeviceRegistrationRequest,
        accessToken: String
    ) async throws {
        try await sendWithoutResponse(
            path: "v1/guardian/devices",
            method: "PUT",
            body: request,
            accessToken: accessToken
        )
    }

    func unregisterDevice(
        _ request: GuardianDeviceRemovalRequest,
        accessToken: String
    ) async throws {
        try await sendWithoutResponse(
            path: "v1/guardian/devices/current",
            method: "DELETE",
            body: request,
            accessToken: accessToken
        )
    }

    func verifyFamilyEntitlement(
        _ request: GuardianEntitlementVerificationRequest,
        accessToken: String
    ) async throws -> GuardianSafetyDashboardSnapshot {
        try await send(
            path: "v1/guardian/entitlement",
            method: "PUT",
            body: request,
            accessToken: accessToken
        )
    }

    func deleteAccount(accessToken: String) async throws {
        try await sendWithoutResponse(
            path: "v1/guardian/account",
            method: "DELETE",
            accessToken: accessToken
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String
    ) async throws -> Response {
        try await send(path: path, method: method, body: GuardianEmptyRequest?.none, accessToken: accessToken)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        body: (some Encodable)?,
        accessToken: String
    ) async throws -> Response {
        let (data, _) = try await data(
            path: path,
            method: method,
            body: body,
            accessToken: accessToken
        )
        guard !data.isEmpty, let value = try? decoder.decode(Response.self, from: data) else {
            throw GuardianSafetyAPIError.invalidResponse
        }
        return value
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        body: some Encodable,
        accessToken: String
    ) async throws {
        _ = try await data(path: path, method: method, body: Optional(body), accessToken: accessToken)
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        accessToken: String
    ) async throws {
        _ = try await data(
            path: path,
            method: method,
            body: GuardianEmptyRequest?.none,
            accessToken: accessToken
        )
    }

    private func data(
        path: String,
        method: String,
        body: (some Encodable)?,
        accessToken: String
    ) async throws -> (Data, HTTPURLResponse) {
        let url = configuration.apiBaseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GuardianSafetyAPIError.invalidResponse
        }
        switch http.statusCode {
        case 200 ..< 300:
            return (data, http)
        case 401:
            throw GuardianSafetyAPIError.unauthorized
        case 403:
            let code = (try? decoder.decode(GuardianAPIErrorPayload.self, from: data).code)
                ?? "HTTP_403"
            if code == "UNAUTHORIZED" {
                throw GuardianSafetyAPIError.unauthorized
            }
            throw GuardianSafetyAPIError.rejected(code: code)
        default:
            let code = (try? decoder.decode(GuardianAPIErrorPayload.self, from: data).code)
                ?? "HTTP_\(http.statusCode)"
            throw GuardianSafetyAPIError.rejected(code: code)
        }
    }

    private static func pathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

private nonisolated struct GuardianInviteAcceptanceRequest: Codable {
    let code: String
}

private nonisolated struct GuardianAPIErrorPayload: Codable {
    let code: String
}

private nonisolated struct GuardianEmptyRequest: Codable {}
