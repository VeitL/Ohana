//
//  ConfirmationNameMatcher.swift
//  Ohana
//

import Foundation

enum ConfirmationNameMatcher {
    static func matches(_ input: String, expectedName: String) -> Bool {
        normalized(input) == normalized(expectedName)
    }

    private static func normalized(_ value: String) -> String {
        let compatible = value.precomposedStringWithCompatibilityMapping
        let folded = compatible.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let standardizedWhitespace = folded.unicodeScalars.map { scalar -> String in
            CharacterSet.whitespacesAndNewlines.contains(scalar) ? " " : String(scalar)
        }.joined()

        return standardizedWhitespace
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
