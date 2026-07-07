//
//  PetMedicationDisplayOptions.swift
//  Ohana
//
//  Stable medication option keys plus localized display helpers.
//

import Foundation

enum PetMedicationDoseUnitOption: String, CaseIterable, Identifiable {
    case tablet
    case capsule
    case milliliter = "ml"
    case gram = "g"
    case dose

    var id: String { rawValue }

    func title(l: L10n) -> String {
        switch self {
        case .tablet:
            l.tr(zh: "片", en: "tablet", de: "Tablette")
        case .capsule:
            l.tr(zh: "粒", en: "capsule", de: "Kapsel")
        case .milliliter:
            "ml"
        case .gram:
            "g"
        case .dose:
            l.tr(zh: "次", en: "dose", de: "Dosis")
        }
    }

    static func canonicalKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        switch normalized {
        case "片", "tablet", "tablets", "tab", "tabs":
            return Self.tablet.rawValue
        case "粒", "capsule", "capsules", "cap", "caps":
            return Self.capsule.rawValue
        case "ml", "milliliter", "milliliters", "毫升":
            return Self.milliliter.rawValue
        case "g", "gram", "grams", "克":
            return Self.gram.rawValue
        case "次", "dose", "doses":
            return Self.dose.rawValue
        default:
            return trimmed
        }
    }

    static func displayTitle(for raw: String, l: L10n) -> String {
        let key = canonicalKey(raw)
        return allCases.first { $0.rawValue == key }?.title(l: l) ?? raw
    }

    static func formatDosage(_ raw: String, l: L10n) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            return displayTitle(for: trimmed, l: l)
        }

        let amount = String(parts[0])
        let unit = displayTitle(for: String(parts[1]), l: l)
        return "\(amount) \(unit)"
    }
}

enum PetMedicationAdministrationOption: String, CaseIterable, Identifiable {
    case mixedWithFood
    case direct
    case dissolvedInWater
    case wrappedInTreat

    var id: String { rawValue }

    func title(l: L10n) -> String {
        switch self {
        case .mixedWithFood:
            l.tr(zh: "拌饭", en: "Mixed with food", de: "Ins Futter mischen")
        case .direct:
            l.tr(zh: "直接喂", en: "Direct", de: "Direkt geben")
        case .dissolvedInWater:
            l.tr(zh: "溶水", en: "Dissolved in water", de: "In Wasser loesen")
        case .wrappedInTreat:
            l.tr(zh: "零食包裹", en: "Wrapped in treat", de: "Im Leckerli")
        }
    }

    static func canonicalKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        switch normalized {
        case "拌饭", "mixedwithfood", "mixed_food", "mixed-food", "mixed food", "with food":
            return Self.mixedWithFood.rawValue
        case "直接喂", "direct", "directly":
            return Self.direct.rawValue
        case "溶水", "dissolvedinwater", "dissolved_water", "dissolved-water", "water":
            return Self.dissolvedInWater.rawValue
        case "零食包裹", "wrappedintreat", "wrapped_treat", "wrapped-treat", "treat", "treatwrap":
            return Self.wrappedInTreat.rawValue
        default:
            return trimmed
        }
    }

    static func displayTitle(for raw: String, l: L10n) -> String {
        let key = canonicalKey(raw)
        return allCases.first { $0.rawValue == key }?.title(l: l) ?? raw
    }
}

enum PetMedicationAdministrationMetadata {
    private static let canonicalPrefix = "【admin:"
    private static let legacyPrefix = "【喂法:"

    static func split(from full: String) -> (key: String?, note: String) {
        if let parsed = parse(prefix: canonicalPrefix, from: full) {
            return (PetMedicationAdministrationOption.canonicalKey(parsed.value), parsed.note)
        }
        if let parsed = parse(prefix: legacyPrefix, from: full) {
            return (PetMedicationAdministrationOption.canonicalKey(parsed.value), parsed.note)
        }
        return (nil, full)
    }

    static func merged(key: String?, note: String) -> String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return trimmedNote
        }
        let stableKey = PetMedicationAdministrationOption.canonicalKey(key)
        return "\(canonicalPrefix)\(stableKey)】" + (trimmedNote.isEmpty ? "" : "\n\(trimmedNote)")
    }

    private static func parse(prefix: String, from full: String) -> (value: String, note: String)? {
        guard full.hasPrefix(prefix), let range = full.range(of: "】") else {
            return nil
        }
        let innerStart = full.index(full.startIndex, offsetBy: prefix.count)
        let value = String(full[innerStart ..< range.lowerBound])
        var note = String(full[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if note.hasPrefix("\n") {
            note = String(note.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (value, note)
    }
}
