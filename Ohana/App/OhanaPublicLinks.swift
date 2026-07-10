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
}
