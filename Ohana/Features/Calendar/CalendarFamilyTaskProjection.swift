//
//  CalendarFamilyTaskProjection.swift
//  Ohana
//
//  Value-only Calendar projections for family-task plan occurrences that have
//  not entered the rolling persistence window yet.
//

import Foundation

nonisolated struct CalendarFamilyTaskPlanProjection: Sendable {
    let id: UUID
    let title: String
    let isAllDay: Bool
    let eventTypeRaw: String
    let relatedEntityType: String
    let relatedEntityID: String
    let assignedToID: String
    let taskCareKindRaw: String
    let recurrenceRule: FamilyTaskRecurrenceRule
    let anchorAt: Date
    let startsAt: Date?
    let endsAt: Date?
    let timeZone: TimeZone
    let scheduleVersion: Int
    let materializedThroughAt: Date?
    let createdAt: Date
}

nonisolated struct CalendarFamilyTaskOccurrenceProjection: Identifiable, Sendable {
    let planID: UUID
    let occurrenceKey: String
    let nominalAt: Date
    let title: String
    let isAllDay: Bool
    let eventTypeRaw: String
    let relatedEntityType: String
    let relatedEntityID: String
    let assignedToID: String
    let taskCareKindRaw: String
    let createdAt: Date

    var id: String { occurrenceKey }

    @MainActor
    func makeReadOnlyEvent() -> Event {
        let intent = DomainScheduleCreateIntent(
            title: title,
            startDate: nominalAt,
            isAllDay: isAllDay,
            eventType: eventTypeRaw,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityID,
            assigneeId: assignedToID,
            taskCareKindRaw: taskCareKindRaw,
            familyTaskPlanId: planID.uuidString,
            familyTaskOccurrenceKey: occurrenceKey,
            writeKind: .collaboration,
            source: .system
        )
        return DomainScheduleWriter.makeUnpersistedEvent(
            intent: intent,
            id: Self.deterministicEventID(for: occurrenceKey),
            createdAt: createdAt
        )
    }

    private nonisolated static func deterministicEventID(for seed: String) -> UUID {
        var first = UInt64(1_469_598_103_934_665_603)
        var second = UInt64(780_984_778_246_553_632)
        for byte in seed.utf8 {
            first ^= UInt64(byte)
            first &*= 1_099_511_628_211
            second ^= UInt64(byte) &+ first
            second &*= 1_099_511_628_211
        }
        let raw = String(
            format: "%08X-%04X-%04X-%04X-%012llX",
            UInt32(truncatingIfNeeded: first),
            UInt16(truncatingIfNeeded: first >> 32),
            UInt16(truncatingIfNeeded: first >> 48),
            UInt16(truncatingIfNeeded: second),
            second & 0x0000_FFFF_FFFF_FFFF
        )
        return UUID(uuidString: raw) ?? UUID()
    }
}

nonisolated enum CalendarFamilyTaskProjectionBuilder {
    static let activePlanFetchLimit = 256
    static let existingOccurrenceFetchLimit = 4096
    static let perPlanOccurrenceLimit = 200
    static let totalOccurrenceLimit = 4096

    static func occurrences(
        plans: [CalendarFamilyTaskPlanProjection],
        existingOccurrenceKeys: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CalendarFamilyTaskOccurrenceProjection] {
        let window = CalendarTimelineWindowPolicy.bounds(around: now, calendar: calendar)
        var result: [CalendarFamilyTaskOccurrenceProjection] = []

        for plan in plans {
            guard result.count < totalOccurrenceLimit else { break }
            let generationStart = firstUnmaterializedDate(
                after: plan.materializedThroughAt,
                windowStart: window.start,
                timeZone: plan.timeZone
            )
            guard generationStart <= window.end else { continue }
            let generated = FamilyTaskRecurrenceGenerator.occurrences(
                planID: plan.id,
                scheduleVersion: plan.scheduleVersion,
                rule: plan.recurrenceRule,
                anchorAt: plan.anchorAt,
                startsAt: plan.startsAt,
                endsAt: plan.endsAt,
                from: generationStart,
                through: window.end,
                timeZone: plan.timeZone,
                limit: perPlanOccurrenceLimit
            )

            for occurrence in generated where !existingOccurrenceKeys.contains(occurrence.occurrenceKey) {
                result.append(
                    CalendarFamilyTaskOccurrenceProjection(
                        planID: plan.id,
                        occurrenceKey: occurrence.occurrenceKey,
                        nominalAt: occurrence.nominalAt,
                        title: plan.title,
                        isAllDay: plan.isAllDay,
                        eventTypeRaw: plan.eventTypeRaw,
                        relatedEntityType: plan.relatedEntityType,
                        relatedEntityID: plan.relatedEntityID,
                        assignedToID: plan.assignedToID,
                        taskCareKindRaw: plan.taskCareKindRaw,
                        createdAt: plan.createdAt
                    )
                )
                if result.count == totalOccurrenceLimit { break }
            }
        }

        return result.sorted {
            if $0.nominalAt == $1.nominalAt {
                return $0.occurrenceKey < $1.occurrenceKey
            }
            return $0.nominalAt < $1.nominalAt
        }
    }

    private static func firstUnmaterializedDate(
        after materializedThroughAt: Date?,
        windowStart: Date,
        timeZone: TimeZone
    ) -> Date {
        guard let materializedThroughAt else { return windowStart }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let materializedDay = calendar.startOfDay(for: materializedThroughAt)
        let followingDay = calendar.date(byAdding: .day, value: 1, to: materializedDay) ?? materializedThroughAt
        return max(windowStart, followingDay)
    }
}
