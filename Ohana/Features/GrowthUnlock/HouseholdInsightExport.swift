import Foundation

/// Small, side-effect-free helpers shared by user-initiated Household Insight
/// exports. Export stays on-device until the system share sheet is confirmed.
nonisolated enum HouseholdInsightExport {
    static func csvCell(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        String(
            format: "%.\(max(0, fractionDigits))f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}
