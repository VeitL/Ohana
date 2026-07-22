//
//  GuardianSafetyConfiguration.swift
//  Ohana
//
//  Fail-closed runtime configuration for the optional Family guardian service.
//  No endpoint, client identifier, or feature switch is inferred in code.
//

import Foundation

nonisolated struct GuardianSafetyConfiguration: Equatable, Sendable {
    let apiBaseURL: URL
    let cognitoAuthorizationURL: URL
    let cognitoTokenURL: URL
    let cognitoClientID: String
    let redirectURL: URL
    let publicInviteBaseURL: URL

    static var current: GuardianSafetyConfiguration? {
        configuration(from: Bundle.main.infoDictionary ?? [:])
    }

    static func configuration(from values: [String: Any]) -> GuardianSafetyConfiguration? {
        guard values["OHANAGuardianSafetyEnabled"] as? Bool == true,
              let apiBaseURL = configuredURL(for: "OHANAGuardianAPIBaseURL", values: values),
              let cognitoAuthorizationURL = configuredURL(for: "OHANAGuardianCognitoAuthorizationURL", values: values),
              let cognitoTokenURL = configuredURL(for: "OHANAGuardianCognitoTokenURL", values: values),
              let redirectURL = configuredURL(for: "OHANAGuardianRedirectURL", values: values),
              let publicInviteBaseURL = configuredURL(for: "OHANAGuardianInviteBaseURL", values: values),
              let cognitoClientID = configuredString(for: "OHANAGuardianCognitoClientID", values: values),
              isSecureRemoteURL(apiBaseURL),
              isSecureRemoteURL(cognitoAuthorizationURL),
              isSecureRemoteURL(cognitoTokenURL),
              isSecureRemoteURL(publicInviteBaseURL),
              redirectURL.scheme?.lowercased() == "ohana",
              redirectURL.host?.lowercased() == "auth",
              redirectURL.path == "/family"
        else { return nil }

        return GuardianSafetyConfiguration(
            apiBaseURL: apiBaseURL,
            cognitoAuthorizationURL: cognitoAuthorizationURL,
            cognitoTokenURL: cognitoTokenURL,
            cognitoClientID: cognitoClientID,
            redirectURL: redirectURL,
            publicInviteBaseURL: publicInviteBaseURL
        )
    }

    static var featureFlagEnabled: Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OHANAGuardianSafetyEnabled") as? Bool {
            return value
        }
        return false
    }

    private static func configuredString(for key: String, values: [String: Any]) -> String? {
        guard let rawValue = values[key] as? String else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func configuredURL(for key: String, values: [String: Any]) -> URL? {
        guard let value = configuredString(for: key, values: values), let url = URL(string: value) else { return nil }
        return url
    }

    private static func isSecureRemoteURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
            url.host != nil &&
            url.user == nil &&
            url.password == nil &&
            url.fragment == nil
    }
}
