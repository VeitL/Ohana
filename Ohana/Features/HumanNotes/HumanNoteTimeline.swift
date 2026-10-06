import CryptoKit
import Foundation

// Value-only timeline: parse once at the route boundary, then search visible content.
nonisolated struct HumanNoteEntry: Identifiable, Equatable, Sendable {
    let id: String
    let recordID: UUID?
    let date: Date?
    let text: String
    let attachments: [HumanNoteAttachmentReference]
    let rawString: String
    let recordedByHumanId: String?
}

nonisolated struct HumanNoteTimelineRecord: Sendable {
    let id: UUID
    let humanID: UUID
    let sequence: Int
    let date: Date
    let rawEntry: String
    let recordedByHumanId: String?
}

nonisolated enum HumanNoteTimeRange: String, CaseIterable, Identifiable {
    case all
    case last7Days
    case last30Days

    var id: String { rawValue }

    func includes(_ date: Date?, now: Date, calendar: Calendar) -> Bool {
        guard self != .all else { return true }
        guard let date,
              let start = calendar.date(
                  byAdding: .day,
                  value: self == .last7Days ? -6 : -29,
                  to: calendar.startOfDay(for: now)
              ) else { return false }
        return date >= start && date <= now
    }
}

nonisolated enum HumanNoteTimelineBuilder {
    static func entries(
        notes: String,
        humanID: UUID,
        records: [HumanNoteTimelineRecord] = []
    ) -> [HumanNoteEntry] {
        let recordsBySequence = Dictionary(grouping: records.filter { $0.humanID == humanID }, by: \.sequence)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        var occurrences: [String: Int] = [:]
        let entries = notes.components(separatedBy: "\n\n").enumerated().compactMap { sequence, part -> (Int, HumanNoteEntry)? in
            let raw = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            var content = raw
            var parsedDate: Date?
            if raw.hasPrefix("["), let end = raw.firstIndex(of: "]") {
                let dateString = String(raw[raw.index(after: raw.startIndex) ..< end])
                if let date = formatter.date(from: dateString), formatter.string(from: date) == dateString {
                    parsedDate = date
                    content = String(raw[raw.index(after: end)...])
                }
            }
            let visible = HumanProfileOptions.visibleNoteParts(from: content.trimmingCharacters(in: .whitespacesAndNewlines))
                .joined(separator: "｜")
            let parsed = HumanNoteAttachmentStore.visibleTextAndAttachments(from: visible)
            guard !parsed.text.isEmpty || !parsed.attachments.isEmpty else { return nil }
            let record = recordsBySequence[sequence]?
                .filter { $0.rawEntry.trimmingCharacters(in: .whitespacesAndNewlines) == raw }
                .sorted { $0.id.uuidString < $1.id.uuidString }
                .first
            let occurrence = occurrences[raw, default: 0]
            occurrences[raw] = occurrence + 1
            let digest = SHA256.hash(data: Data("\(humanID.uuidString):\(raw):\(occurrence)".utf8))
                .map { String(format: "%02x", $0) }.joined()
            return (sequence, HumanNoteEntry(
                id: record?.id.uuidString ?? "legacy-\(digest)",
                recordID: record?.id,
                date: record?.date ?? parsedDate,
                text: parsed.text,
                attachments: parsed.attachments,
                rawString: raw,
                recordedByHumanId: record?.recordedByHumanId
            ))
        }
        return entries.sorted { lhs, rhs in
            if lhs.1.date != rhs.1.date {
                return (lhs.1.date ?? .distantPast) > (rhs.1.date ?? .distantPast)
            }
            return lhs.0 > rhs.0
        }.map(\.1)
    }

    static func filtered(
        _ entries: [HumanNoteEntry],
        query: String,
        timeRange: HumanNoteTimeRange,
        attachmentsOnly: Bool,
        recorderNames: [UUID: String] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [HumanNoteEntry] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            guard timeRange.includes(entry.date, now: now, calendar: calendar),
                  !attachmentsOnly || !entry.attachments.isEmpty else { return false }
            let recorderName = entry.recordedByHumanId.flatMap(UUID.init(uuidString:)).flatMap { recorderNames[$0] } ?? ""
            let searchableText = ([entry.text, recorderName] + entry.attachments.map(\.fileName)).joined(separator: " ")
            return words.allSatisfy { searchableText.localizedStandardContains($0) }
        }
    }
}
