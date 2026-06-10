//
//  CountryDecimalInput.swift
//  Ohana
//
//  Locale-aware decimal input helpers for numeric sheets.
//

import Foundation

enum CountryDecimalInput {
    static func localeIdentifier(for countryCode: String = AppCountry.code) -> String {
        switch AppCountry.normalize(countryCode) {
        case "US": "en_US"
        case "DE": "de_DE"
        case "GB": "en_GB"
        case "JP": "ja_JP"
        case "HK": "zh_HK"
        case "TW": "zh_TW"
        default: "zh_CN"
        }
    }

    static func locale(for countryCode: String = AppCountry.code) -> Locale {
        Locale(identifier: localeIdentifier(for: countryCode))
    }

    static func decimalSeparator(for countryCode: String = AppCountry.code) -> String {
        Locale(identifier: localeIdentifier(for: countryCode)).decimalSeparator ?? "."
    }

    static func placeholder(integer: String = "0", fractionDigits: Int = 1, countryCode: String = AppCountry.code) -> String {
        guard fractionDigits > 0 else { return integer }
        return integer + decimalSeparator(for: countryCode) + String(repeating: "0", count: fractionDigits)
    }

    static func parse(_ text: String, countryCode: String = AppCountry.code) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale(for: countryCode)
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }

        let separator = decimalSeparator(for: countryCode)
        let grouping = Locale(identifier: localeIdentifier(for: countryCode)).groupingSeparator ?? ","
        var normalized = trimmed
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: grouping, with: "")
        normalized = normalized.replacingOccurrences(of: separator, with: ".")
        if separator != "," {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }
        return Double(normalized)
    }

    static func sanitize(_ text: String, countryCode: String = AppCountry.code, maxFractionDigits: Int = 2) -> String {
        let preferredSeparator = decimalSeparator(for: countryCode)
        var result = ""
        var hasSeparator = false
        var fractionCount = 0

        for scalar in text.unicodeScalars {
            let char = Character(scalar)
            if CharacterSet.decimalDigits.contains(scalar) {
                if hasSeparator {
                    guard fractionCount < maxFractionDigits else { continue }
                    fractionCount += 1
                }
                result.append(char)
            } else if scalar == "." || scalar == "," {
                guard maxFractionDigits > 0, !hasSeparator else { continue }
                hasSeparator = true
                result.append(preferredSeparator)
            }
        }

        return result
    }

    static func format(_ value: Double, countryCode: String = AppCountry.code, minFractionDigits: Int = 0, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale(for: countryCode)
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
