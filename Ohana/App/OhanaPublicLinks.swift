//
//  OhanaPublicLinks.swift
//  Ohana
//
//  Public, release-owned destinations surfaced from Settings.
//

import Foundation

enum OhanaPublicLinks {
    /// Kept in the public source repository so the URL remains available even
    /// when the app is offline from any developer-operated service.
    static let privacyPolicy = URL(string: "https://github.com/VeitL/Ohana/blob/main/docs/privacy-policy.md")!

    /// Support is intentionally email-only for the local-first Solo release;
    /// no diagnostic data or records are attached automatically.
    static let support = URL(string: "mailto:guanchen.li.119@gmail.com?subject=Ohana%20Support")!

    /// Keep the review action absent until App Store Connect has assigned and
    /// the release owner has verified the public Apple ID in every launch
    /// storefront. Do not guess or reuse an unverified numeric ID.
    static let appStoreReview: URL? = nil
}

enum OhanaReleaseIdentity {
    static var currentVersionDisplay: String {
        versionDisplay(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    static func versionDisplay(infoDictionary: [String: Any]) -> String {
        let version = (infoDictionary["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (infoDictionary["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (.some(version), .some(build)):
            return "v\(version) (\(build))"
        case let (.some(version), .none):
            return "v\(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        case (.none, .none):
            return "—"
        }
    }
}
