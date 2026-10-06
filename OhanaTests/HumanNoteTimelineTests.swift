import Foundation
import Testing
@testable import Ohana

struct HumanNoteTimelineTests {
    @Test func legacyMetadataIsHiddenWithoutInventingDatesOrChangingStoredText() {
        let humanID = UUID()
        let notes = "性别:female｜关系:妈妈\n\n[2026-10-04] Morning walk\n\nA thought without a date"
        let entries = HumanNoteTimelineBuilder.entries(notes: notes, humanID: humanID)
        #expect(entries.map(\.text) == ["Morning walk", "A thought without a date"])
        #expect(entries.first?.date != nil)
        #expect(entries.last?.date == nil)
        #expect(entries.first?.rawString == "[2026-10-04] Morning walk")
        #expect(HumanNoteTimelineBuilder.entries(notes: "性别:female｜关系:妈妈", humanID: humanID).isEmpty)
    }

    @Test func sameDayEntriesUseActualRecordTimesAndStableIdentities() {
        let humanID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let morning = date("2026-10-04T08:00:00Z")
        let evening = date("2026-10-04T20:00:00Z")
        let notes = "[2026-10-04] Morning\n\n[2026-10-04] Evening"
        let records = [
            HumanNoteTimelineRecord(id: firstID, humanID: humanID, sequence: 0, date: morning, rawEntry: "[2026-10-04] Morning", recordedByHumanId: nil),
            HumanNoteTimelineRecord(id: secondID, humanID: humanID, sequence: 1, date: evening, rawEntry: "[2026-10-04] Evening", recordedByHumanId: nil)
        ]
        let entries = HumanNoteTimelineBuilder.entries(notes: notes, humanID: humanID, records: records)
        #expect(entries.map(\.recordID) == [secondID, firstID])
        #expect(entries.map(\.date) == [evening, morning])
        #expect(entries == HumanNoteTimelineBuilder.entries(notes: notes, humanID: humanID, records: records))

        let legacy = HumanNoteTimelineBuilder.entries(notes: "Same\n\nSame", humanID: humanID)
        #expect(Set(legacy.map(\.id)).count == 2)
        #expect(legacy == HumanNoteTimelineBuilder.entries(notes: "Same\n\nSame", humanID: humanID))
        let expanded = HumanNoteTimelineBuilder.entries(notes: "Other\n\nSame\n\nSame", humanID: humanID)
        #expect(expanded.filter { $0.text == "Same" }.map(\.id) == legacy.map(\.id))
    }

    @Test func staleOrOtherMembersSidecarsCannotSupplyAttribution() {
        let humanID = UUID()
        let records = [
            HumanNoteTimelineRecord(id: UUID(), humanID: humanID, sequence: 0, date: Date(), rawEntry: "Old content", recordedByHumanId: UUID().uuidString),
            HumanNoteTimelineRecord(id: UUID(), humanID: UUID(), sequence: 0, date: Date(), rawEntry: "Current content", recordedByHumanId: UUID().uuidString)
        ]
        let entry = HumanNoteTimelineBuilder.entries(notes: "Current content", humanID: humanID, records: records).first
        #expect(entry?.recordID == nil)
        #expect(entry?.recordedByHumanId == nil)
        #expect(entry?.date == nil)
    }

    @Test func searchCombinesWordsAndIncludesFileNamesAndRecorderWithoutSearchingHiddenPaths() {
        let humanID = UUID()
        let recorderID = UUID()
        let attachment = HumanNoteAttachmentReference(id: UUID(), fileName: "Lab October.pdf", relativePath: "hidden-secret/file.pdf", isImage: false)
        let raw = "[2026-10-04] Café after walk" + HumanNoteAttachmentStore.marker(for: [attachment])
        let records = [HumanNoteTimelineRecord(id: UUID(), humanID: humanID, sequence: 0, date: date("2026-10-04T09:00:00Z"), rawEntry: raw, recordedByHumanId: recorderID.uuidString.lowercased())]
        let entries = HumanNoteTimelineBuilder.entries(notes: raw + "\n\nNo file", humanID: humanID, records: records)
        let names = [recorderID: "Maëlle"]
        func search(_ query: String) -> [HumanNoteEntry] {
            HumanNoteTimelineBuilder.filtered(entries, query: query, timeRange: .all, attachmentsOnly: false, recorderNames: names)
        }
        #expect(search("  cafe WALK  ").count == 1)
        #expect(search("October Maelle").count == 1)
        #expect(search("walk swimming").isEmpty)
        #expect(search("hidden-secret").isEmpty)
        #expect(HumanNoteTimelineBuilder.filtered(entries, query: "", timeRange: .all, attachmentsOnly: true).count == 1)
    }

    @Test func timeFiltersUseCalendarDayBoundariesAndRetainUndatedNotesInAllTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let now = date("2026-10-04T12:00:00Z")
        let humanID = UUID()
        let dates = [
            date("2026-09-28T00:00:00+02:00"),
            date("2026-09-27T23:59:59+02:00"),
            date("2026-09-05T00:00:00+02:00"),
            date("2026-09-04T23:59:59+02:00"),
            now.addingTimeInterval(1)
        ]
        let notes = dates.indices.map { "Note \($0)" }.joined(separator: "\n\n") + "\n\nUndated"
        let records = dates.enumerated().map { index, date in
            HumanNoteTimelineRecord(id: UUID(), humanID: humanID, sequence: index, date: date, rawEntry: "Note \(index)", recordedByHumanId: nil)
        }
        let entries = HumanNoteTimelineBuilder.entries(notes: notes, humanID: humanID, records: records)
        #expect(HumanNoteTimelineBuilder.filtered(entries, query: "", timeRange: .all, attachmentsOnly: false, now: now, calendar: calendar).count == 6)
        #expect(HumanNoteTimelineBuilder.filtered(entries, query: "", timeRange: .last7Days, attachmentsOnly: false, now: now, calendar: calendar).map(\.text) == ["Note 0"])
        #expect(HumanNoteTimelineBuilder.filtered(entries, query: "", timeRange: .last30Days, attachmentsOnly: false, now: now, calendar: calendar).count == 3)
    }

    @Test func invalidLegacyDateRemainsVisibleAndUndated() {
        let entry = HumanNoteTimelineBuilder.entries(notes: "[2026-02-30] Keep this note", humanID: UUID()).first
        #expect(entry?.date == nil)
        #expect(entry?.text == "[2026-02-30] Keep this note")
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
