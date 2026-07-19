//
//  PresenceCheckInReadService.swift
//  Ohana
//
//  Bounded value projections for Zen Home and Streak.
//

import Foundation
import SwiftData

nonisolated enum PresenceDayKeyPolicy {
    static func key(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func addingDays(_ value: Int, to dayKey: String) -> String? {
        guard let date = parse(dayKey) else { return nil }
        guard let updated = stableCalendar.date(byAdding: .day, value: value, to: date) else { return nil }
        return key(for: updated, timeZone: stableCalendar.timeZone)
    }

    static func parse(_ dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return stableCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static var stableCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}

nonisolated struct PresenceSubjectSnapshot: Equatable, Identifiable, Sendable {
    let subject: PresenceSubjectRef
    let name: String
    let avatarEmoji: String
    let themeColorHex: String
    let avatarThumbnailSignature: String
    let createdAt: Date
    let isOwner: Bool
    let isCheckedInToday: Bool
    let status: PresenceStatus?
    let isActive: Bool
    let isAnonymousHistory: Bool

    var id: PresenceSubjectRef { subject }
}

nonisolated struct PresenceHomeSnapshot: Equatable, Sendable {
    let ownerHumanId: UUID
    let dayKey: String
    let subjects: [PresenceSubjectSnapshot]

    var checkedInCount: Int { subjects.count(where: \.isCheckedInToday) }
    var isAllCheckedIn: Bool { !subjects.isEmpty && checkedInCount == subjects.count }
}

nonisolated struct PresenceCalendarDaySnapshot: Equatable, Identifiable, Sendable {
    let dayKey: String
    let isParticipating: Bool
    let isCheckedIn: Bool
    let status: PresenceStatus?

    var id: String { dayKey }
}

nonisolated struct PresenceStreakSnapshot: Equatable, Sendable {
    let subject: PresenceSubjectRef
    let currentStreak: Int
    let longestStreak: Int
    let days: [PresenceCalendarDaySnapshot]
}

nonisolated enum PresenceStreakCalculator {
    struct Period: Equatable, Sendable {
        let startedDayKey: String
        let lastParticipatingDayKey: String?
        let isActive: Bool

        init(startedDayKey: String, lastParticipatingDayKey: String?, isActive: Bool) {
            self.startedDayKey = startedDayKey
            self.lastParticipatingDayKey = lastParticipatingDayKey
            self.isActive = isActive
        }
    }

    static func participatingDays(periods: [Period], through todayKey: String) -> [String] {
        var result = Set<String>()
        for period in periods {
            let endKey = period.isActive ? todayKey : period.lastParticipatingDayKey
            guard let endKey, period.startedDayKey <= endKey else { continue }
            var cursor = period.startedDayKey
            var safetyCounter = 0
            while cursor <= endKey, safetyCounter < 36600 {
                result.insert(cursor)
                guard let next = PresenceDayKeyPolicy.addingDays(1, to: cursor) else { break }
                cursor = next
                safetyCounter += 1
            }
        }
        return result.sorted()
    }

    static func calendarDays(from firstDayKey: String, through lastDayKey: String) -> [String] {
        guard firstDayKey <= lastDayKey else { return [] }
        var result: [String] = []
        var cursor = firstDayKey
        var safetyCounter = 0
        while cursor <= lastDayKey, safetyCounter < 36600 {
            result.append(cursor)
            guard let next = PresenceDayKeyPolicy.addingDays(1, to: cursor) else { break }
            cursor = next
            safetyCounter += 1
        }
        return result
    }

    static func streaks(
        checkedDayKeys: Set<String>,
        periods: [Period],
        todayKey: String
    ) -> (current: Int, longest: Int) {
        var eligible = participatingDays(periods: periods, through: todayKey)
        // Today has not become a missed day while the user still has time to
        // check in. Older participating gaps do reset the streak.
        if eligible.last == todayKey, !checkedDayKeys.contains(todayKey) {
            eligible.removeLast()
        }
        guard !eligible.isEmpty else { return (0, 0) }

        var running = 0
        var longest = 0
        for day in eligible {
            if checkedDayKeys.contains(day) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }
        return (running, longest)
    }
}

@MainActor
enum PresenceCheckInReadService {
    static func homeSnapshot(
        context: ModelContext,
        ownerHumanId: UUID,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) throws -> PresenceHomeSnapshot {
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        let checkIns = try checkIns(
            context: context,
            dayKey: dayKey
        )
        let checkInsBySubject = Dictionary(
            checkIns.compactMap { checkIn -> (PresenceSubjectRef, PresenceCheckIn)? in
                checkIn.subject.map { ($0, checkIn) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let subjects = try activeSubjects(context: context, ownerHumanId: ownerHumanId).map { base in
            let checkIn = checkInsBySubject[base.subject]
            return PresenceSubjectSnapshot(
                subject: base.subject,
                name: base.name,
                avatarEmoji: base.avatarEmoji,
                themeColorHex: base.themeColorHex,
                avatarThumbnailSignature: base.avatarThumbnailSignature,
                createdAt: base.createdAt,
                isOwner: base.isOwner,
                isCheckedInToday: checkIn != nil,
                status: checkIn?.status,
                isActive: base.isActive,
                isAnonymousHistory: base.isAnonymousHistory
            )
        }
        return PresenceHomeSnapshot(ownerHumanId: ownerHumanId, dayKey: dayKey, subjects: subjects)
    }

    static func streakSnapshot(
        context: ModelContext,
        ownerHumanId: UUID,
        subject: PresenceSubjectRef,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) throws -> PresenceStreakSnapshot {
        let subjectKindRaw = subject.kind.rawValue
        let subjectIdRaw = subject.id.uuidString
        let todayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        let checkIns = try context.fetch(
            FetchDescriptor<PresenceCheckIn>(
                predicate: #Predicate { item in
                    item.subjectKindRaw == subjectKindRaw &&
                        item.subjectIdRaw == subjectIdRaw
                },
                sortBy: [SortDescriptor(\.dayKey)]
            )
        )
        let ownerPeriods = try participationPeriods(context: context, ownerHumanId: ownerHumanId)
        let ownerCalculatorPeriods = ownerPeriods.map {
            PresenceStreakCalculator.Period(
                startedDayKey: $0.startedDayKey,
                lastParticipatingDayKey: $0.lastParticipatingDayKey,
                isActive: $0.isActive
            )
        }
        let householdPeriods = try participationPeriods(context: context)
        let householdCalculatorPeriods = householdPeriods.map {
            PresenceStreakCalculator.Period(
                startedDayKey: $0.startedDayKey,
                lastParticipatingDayKey: $0.lastParticipatingDayKey,
                isActive: $0.isActive
            )
        }
        let allParticipating = PresenceStreakCalculator.participatingDays(
            periods: householdCalculatorPeriods,
            through: todayKey
        )
        let ownerSubject = PresenceSubjectRef(kind: .human, id: ownerHumanId)
        let subjectCreationDayKey: String? = if subject == ownerSubject {
            nil
        } else if let creationDate = try subjectCreationDate(context: context, subject: subject) {
            PresenceDayKeyPolicy.key(for: creationDate, timeZone: timeZone)
        } else {
            checkIns.first?.dayKey
        }
        let participating = subjectCreationDayKey.map { floor in
            allParticipating.filter { $0 >= floor }
        } ?? allParticipating
        let participatingSet = Set(participating)
        let checkInByDay = Dictionary(checkIns.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
        let checkedDays = Set(checkInByDay.keys)
        let streaks = subject == ownerSubject
            ? PresenceStreakCalculator.streaks(
                checkedDayKeys: checkedDays,
                periods: ownerCalculatorPeriods,
                todayKey: todayKey
            )
            : (current: 0, longest: 0)
        let rawFirstVisibleDay = (householdPeriods.map(\.startedDayKey) + checkIns.map(\.dayKey)).min()
        let firstVisibleDay = subjectCreationDayKey.map { floor in
            max(rawFirstVisibleDay ?? floor, floor)
        } ?? rawFirstVisibleDay
        let visibleDays = firstVisibleDay.map {
            PresenceStreakCalculator.calendarDays(from: $0, through: todayKey)
        } ?? []
        let days = visibleDays.map { dayKey in
            PresenceCalendarDaySnapshot(
                dayKey: dayKey,
                isParticipating: participatingSet.contains(dayKey),
                isCheckedIn: checkInByDay[dayKey] != nil,
                status: checkInByDay[dayKey]?.status
            )
        }
        return PresenceStreakSnapshot(
            subject: subject,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            days: days
        )
    }

    private static func subjectCreationDate(
        context: ModelContext,
        subject: PresenceSubjectRef
    ) throws -> Date? {
        let subjectID = subject.id
        switch subject.kind {
        case .human:
            var descriptor = FetchDescriptor<Human>(
                predicate: #Predicate { $0.id == subjectID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.createdAt
        case .pet:
            var descriptor = FetchDescriptor<Pet>(
                predicate: #Predicate { $0.id == subjectID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.createdAt
        case .plant:
            var descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate { $0.id == subjectID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.createdAt
        }
    }

    static func activeSubjects(
        context: ModelContext,
        ownerHumanId: UUID
    ) throws -> [PresenceSubjectSnapshot] {
        var results: [PresenceSubjectSnapshot] = []
        let humans = try context.fetch(
            FetchDescriptor<Human>(
                predicate: #Predicate { $0.passedAwayDate == nil },
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]
            )
        )
        results += humans.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .human, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.safeThemeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: $0.id == ownerHumanId,
                isCheckedInToday: false,
                status: nil,
                isActive: true,
                isAnonymousHistory: false
            )
        }
        let pets = try context.fetch(
            FetchDescriptor<Pet>(
                predicate: #Predicate { $0.passedAwayDate == nil },
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]
            )
        )
        results += pets.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .pet, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.safeThemeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                isActive: true,
                isAnonymousHistory: false
            )
        }
        let plants = try context.fetch(
            FetchDescriptor<Plant>(
                predicate: #Predicate { $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]
            )
        )
        results += plants.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .plant, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.themeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                isActive: true,
                isAnonymousHistory: false
            )
        }

        return sortedSubjects(results)
    }

    /// Streak is an archival surface. It includes inactive profiles and keeps
    /// an anonymous value row for a physically deleted subject when durable
    /// presence facts still reference that subject ID. Home intentionally uses
    /// `activeSubjects` instead.
    static func streakSubjects(
        context: ModelContext,
        ownerHumanId: UUID
    ) throws -> [PresenceSubjectSnapshot] {
        var results: [PresenceSubjectSnapshot] = []
        let humans = try context.fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)])
        )
        results += humans.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .human, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.safeThemeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: $0.id == ownerHumanId,
                isCheckedInToday: false,
                status: nil,
                isActive: !$0.hasPassedAway,
                isAnonymousHistory: false
            )
        }
        let pets = try context.fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)])
        )
        results += pets.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .pet, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.safeThemeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                isActive: !$0.hasPassedAway,
                isAnonymousHistory: false
            )
        }
        let plants = try context.fetch(
            FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)])
        )
        results += plants.map {
            PresenceSubjectSnapshot(
                subject: .init(kind: .plant, id: $0.id),
                name: $0.name,
                avatarEmoji: $0.avatarEmoji,
                themeColorHex: $0.themeColorHex,
                avatarThumbnailSignature: $0.avatarThumbnailSignature,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                isActive: !$0.isArchived,
                isAnonymousHistory: false
            )
        }

        let knownSubjects = Set(results.map(\.subject))
        let historicalFacts = try context.fetch(
            FetchDescriptor<PresenceCheckIn>(sortBy: [SortDescriptor(\.checkedInAt)])
        )
        var firstFactByDeletedSubject: [PresenceSubjectRef: PresenceCheckIn] = [:]
        for fact in historicalFacts {
            guard let subject = fact.subject,
                  !knownSubjects.contains(subject),
                  firstFactByDeletedSubject[subject] == nil else { continue }
            firstFactByDeletedSubject[subject] = fact
        }
        results += firstFactByDeletedSubject.map { subject, firstFact in
            PresenceSubjectSnapshot(
                subject: subject,
                name: anonymousHistoryName(for: subject.kind),
                avatarEmoji: anonymousHistoryAvatar(for: subject.kind),
                themeColorHex: "8A8A8A",
                avatarThumbnailSignature: "",
                createdAt: firstFact.checkedInAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                isActive: false,
                isAnonymousHistory: true
            )
        }

        return sortedSubjects(results)
    }

    private static func sortedSubjects(_ results: [PresenceSubjectSnapshot]) -> [PresenceSubjectSnapshot] {
        let kindRank: [PresenceSubjectKind: Int] = [.human: 0, .pet: 1, .plant: 2]
        return results.sorted { lhs, rhs in
            if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
            let leftRank = kindRank[lhs.subject.kind] ?? .max
            let rightRank = kindRank[rhs.subject.kind] ?? .max
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.subject.stableKey < rhs.subject.stableKey
        }
    }

    private static func anonymousHistoryName(for kind: PresenceSubjectKind) -> String {
        switch kind {
        case .human: "Human"
        case .pet: "Pet"
        case .plant: "Plant"
        }
    }

    private static func anonymousHistoryAvatar(for kind: PresenceSubjectKind) -> String {
        switch kind {
        case .human: "👤"
        case .pet: "🐾"
        case .plant: "🌱"
        }
    }

    static func participationPeriods(
        context: ModelContext,
        ownerHumanId: UUID
    ) throws -> [PresenceParticipationPeriod] {
        let ownerRaw = ownerHumanId.uuidString
        return try context.fetch(
            FetchDescriptor<PresenceParticipationPeriod>(
                predicate: #Predicate { $0.ownerHumanIdRaw == ownerRaw },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        )
    }

    static func participationPeriods(context: ModelContext) throws -> [PresenceParticipationPeriod] {
        try context.fetch(
            FetchDescriptor<PresenceParticipationPeriod>(sortBy: [SortDescriptor(\.startedAt)])
        )
    }

    private static func checkIns(
        context: ModelContext,
        dayKey: String
    ) throws -> [PresenceCheckIn] {
        try context.fetch(
            FetchDescriptor<PresenceCheckIn>(
                predicate: #Predicate {
                    $0.dayKey == dayKey
                },
                sortBy: [SortDescriptor(\.checkedInAt)]
            )
        )
    }
}
