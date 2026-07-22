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
    var avatarModelID: PersistentIdentifier? = nil
    let createdAt: Date
    var inactiveAt: Date? = nil
    let isOwner: Bool
    let isCheckedInToday: Bool
    let status: PresenceStatus?
    var currentDisplayStreak: Int = 0
    var expandedProfile: ZenExpandedProfileDTO? = nil
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
    let isRetrospectiveStatus: Bool

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
        timeZone: TimeZone = .current,
        localization: L10n = .current
    ) throws -> PresenceHomeSnapshot {
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: timeZone)
        let checkIns = try checkIns(
            context: context,
            dayKey: dayKey
        )
        let checkInsBySubject = Dictionary(
            checkIns.compactMap { checkIn -> (PresenceSubjectRef, PresenceCheckIn)? in
                guard checkIn.source != .retrospectiveStatus else { return nil }
                return checkIn.subject.map { ($0, checkIn) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let activeSubjects = try activeSubjects(
            context: context,
            ownerHumanId: ownerHumanId,
            now: now,
            localization: localization
        )
        let recentStatusBySubject = try recentStatusSummaries(
            context: context,
            activeSubjects: activeSubjects,
            todayKey: dayKey
        )
        let displayStreaks = try currentDisplayStreaks(
            context: context,
            ownerHumanId: ownerHumanId,
            subjects: activeSubjects,
            todayKey: dayKey,
            checkedToday: Set(checkInsBySubject.keys),
            timeZone: timeZone
        )
        let subjects = activeSubjects.map { base in
            let checkIn = checkInsBySubject[base.subject]
            return PresenceSubjectSnapshot(
                subject: base.subject,
                name: base.name,
                avatarEmoji: base.avatarEmoji,
                themeColorHex: base.themeColorHex,
                avatarThumbnailSignature: base.avatarThumbnailSignature,
                avatarModelID: base.avatarModelID,
                createdAt: base.createdAt,
                isOwner: base.isOwner,
                isCheckedInToday: checkIn != nil,
                status: checkIn?.status,
                currentDisplayStreak: displayStreaks[base.subject] ?? 0,
                expandedProfile: base.expandedProfile.map { profile in
                    var updated = profile
                    updated.recentStatus = recentStatusBySubject[base.subject] ?? .empty
                    return updated
                },
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
        let genuineCheckIns = checkIns.filter { $0.source != .retrospectiveStatus }
        let checkInByDay = Dictionary(
            genuineCheckIns.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let retrospectiveStatusByDay = Dictionary(
            checkIns.filter { $0.source == .retrospectiveStatus }.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
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
            let checkIn = checkInByDay[dayKey]
            let retrospectiveStatus = retrospectiveStatusByDay[dayKey]
            return PresenceCalendarDaySnapshot(
                dayKey: dayKey,
                isParticipating: participatingSet.contains(dayKey),
                isCheckedIn: checkIn != nil,
                status: checkIn?.status ?? retrospectiveStatus?.status,
                isRetrospectiveStatus: checkIn == nil && retrospectiveStatus != nil
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

    /// Produces the lightweight continuity value shown on Zen Home cards.
    /// Reads are newest-first in small pages and stop as soon as a real missed
    /// participating day is found, so Home never mounts the archival calendar
    /// projection merely to render a compact metric.
    private static func currentDisplayStreaks(
        context: ModelContext,
        ownerHumanId: UUID,
        subjects: [PresenceSubjectSnapshot],
        todayKey: String,
        checkedToday: Set<PresenceSubjectRef>,
        timeZone: TimeZone
    ) throws -> [PresenceSubjectRef: Int] {
        let ownerSubject = PresenceSubjectRef(kind: .human, id: ownerHumanId)
        let ownerPeriods = try participationPeriods(context: context, ownerHumanId: ownerHumanId)
            .map(calculatorPeriod)
        let householdPeriods = try participationPeriods(context: context)
            .map(calculatorPeriod)
        let ownerParticipatingDays = PresenceStreakCalculator.participatingDays(
            periods: ownerPeriods,
            through: todayKey
        )
        let householdParticipatingDays = PresenceStreakCalculator.participatingDays(
            periods: householdPeriods,
            through: todayKey
        )

        var result: [PresenceSubjectRef: Int] = [:]
        result.reserveCapacity(subjects.count)
        for subject in subjects {
            let creationDayKey = subject.subject == ownerSubject
                ? nil
                : PresenceDayKeyPolicy.key(for: subject.createdAt, timeZone: timeZone)
            let baseDays = subject.subject == ownerSubject
                ? ownerParticipatingDays
                : householdParticipatingDays
            var eligibleDays = creationDayKey.map { floor in
                baseDays.filter { $0 >= floor }
            } ?? baseDays

            // Today remains available until the local day ends. An unchecked
            // current day therefore does not erase the continuity earned
            // through yesterday.
            if eligibleDays.last == todayKey,
               !checkedToday.contains(subject.subject) {
                eligibleDays.removeLast()
            }

            result[subject.subject] = try currentDisplayStreak(
                context: context,
                subject: subject.subject,
                eligibleDays: eligibleDays
            )
        }
        return result
    }

    private static func currentDisplayStreak(
        context: ModelContext,
        subject: PresenceSubjectRef,
        eligibleDays: [String]
    ) throws -> Int {
        guard !eligibleDays.isEmpty else { return 0 }

        let subjectKindRaw = subject.kind.rawValue
        let subjectIdRaw = subject.id.uuidString
        let retrospectiveSourceRaw = PresenceCheckInSource.retrospectiveStatus.rawValue
        let pageSize = 64
        var fetchOffset = 0
        var checkedDayKeys = Set<String>()

        while true {
            var descriptor = FetchDescriptor<PresenceCheckIn>(
                predicate: #Predicate { item in
                    item.subjectKindRaw == subjectKindRaw &&
                        item.subjectIdRaw == subjectIdRaw &&
                        item.sourceRaw != retrospectiveSourceRaw
                },
                sortBy: [SortDescriptor(\.dayKey, order: .reverse)]
            )
            descriptor.fetchLimit = pageSize
            descriptor.fetchOffset = fetchOffset
            let page = try context.fetch(descriptor)
            checkedDayKeys.formUnion(page.map(\.dayKey))

            let oldestLoadedDayKey = page.last?.dayKey
            var streak = 0
            var needsOlderPage = false
            for dayKey in eligibleDays.reversed() {
                if checkedDayKeys.contains(dayKey) {
                    streak += 1
                    continue
                }

                if page.count == pageSize,
                   let oldestLoadedDayKey,
                   dayKey < oldestLoadedDayKey {
                    needsOlderPage = true
                    break
                }
                return streak
            }

            if !needsOlderPage || page.count < pageSize {
                return streak
            }
            fetchOffset += page.count
        }
    }

    private static func calculatorPeriod(
        _ period: PresenceParticipationPeriod
    ) -> PresenceStreakCalculator.Period {
        PresenceStreakCalculator.Period(
            startedDayKey: period.startedDayKey,
            lastParticipatingDayKey: period.lastParticipatingDayKey,
            isActive: period.isActive
        )
    }

    static func activeSubjects(
        context: ModelContext,
        ownerHumanId: UUID,
        now: Date = Date(),
        localization: L10n = .current
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
                avatarModelID: $0.persistentModelID,
                createdAt: $0.createdAt,
                isOwner: $0.id == ownerHumanId,
                isCheckedInToday: false,
                status: nil,
                expandedProfile: expandedProfile(for: $0, now: now, localization: localization),
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
                avatarModelID: $0.persistentModelID,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                expandedProfile: expandedProfile(for: $0, now: now, localization: localization),
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
                avatarModelID: $0.persistentModelID,
                createdAt: $0.createdAt,
                isOwner: false,
                isCheckedInToday: false,
                status: nil,
                expandedProfile: expandedProfile(for: $0, now: now, localization: localization),
                isActive: true,
                isAnonymousHistory: false
            )
        }

        return sortedSubjects(results)
    }

    private static func recentStatusSummaries(
        context: ModelContext,
        activeSubjects: [PresenceSubjectSnapshot],
        todayKey: String
    ) throws -> [PresenceSubjectRef: ZenRecentStatusSummary] {
        guard let firstDayKey = PresenceDayKeyPolicy.addingDays(-6, to: todayKey) else {
            return [:]
        }
        let activeSubjectRefs = Set(activeSubjects.map(\.subject))
        let recentFacts = try context.fetch(FetchDescriptor<PresenceCheckIn>(
            predicate: #Predicate { item in
                item.dayKey >= firstDayKey && item.dayKey <= todayKey
            },
            sortBy: [SortDescriptor(\.dayKey), SortDescriptor(\.checkedInAt)]
        ))
        var entriesBySubject: [PresenceSubjectRef: [ZenRecentStatusEntry]] = [:]
        for fact in recentFacts {
            guard let subject = fact.subject,
                  activeSubjectRefs.contains(subject),
                  let status = fact.status else { continue }
            entriesBySubject[subject, default: []].append(
                ZenRecentStatusEntry(dayKey: fact.dayKey, score: status.score)
            )
        }
        return entriesBySubject.mapValues {
            ZenRecentStatusSummary.make(entries: $0, todayKey: todayKey)
        }
    }

    private static func expandedProfile(
        for human: Human,
        now: Date,
        localization l: L10n
    ) -> ZenExpandedProfileDTO {
        var metrics: [ZenExpandedMetricDTO] = []
        if let birthday = human.birthday {
            metrics.append(metric(
                .age,
                label: metricLabel(.age, localization: l),
                value: human.localizedAgeTextForWallet(birthday: birthday, l: l)
            ))
        }
        metrics.append(metric(
            .together,
            label: metricLabel(.together, localization: l),
            value: localizedDays(
                max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: now).day ?? 0),
                localization: l
            )
        ))
        if let birthday = human.birthday {
            metrics.append(metric(
                .zodiac,
                label: metricLabel(.zodiac, localization: l),
                value: Human.westernZodiacDisplay(for: birthday, l: l)
            ))
        }
        let mbti = human.mbti.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !mbti.isEmpty {
            metrics.append(metric(.mbti, label: "MBTI", value: mbti))
        }
        return ZenExpandedProfileDTO(
            metrics: metrics,
            personalityStory: humanPersonalityStory(
                mbti: mbti,
                isOwner: HumanProfileOptions.normalizedRole(human.role) == "owner",
                localization: l
            )
        )
    }

    private static func expandedProfile(
        for pet: Pet,
        now: Date,
        localization l: L10n
    ) -> ZenExpandedProfileDTO {
        var metrics: [ZenExpandedMetricDTO] = []
        if let birthday = pet.birthday {
            metrics.append(metric(
                .age,
                label: metricLabel(.age, localization: l),
                value: pet.localizedAgeTextForWallet(birthday: birthday, l: l)
            ))
        }
        if let homeDate = pet.homeDate {
            let days = Calendar.current.dateComponents([.day], from: homeDate, to: now).day ?? 0
            metrics.append(metric(
                .together,
                label: metricLabel(.together, localization: l),
                value: localizedTogetherDays(days, localization: l)
            ))
        }
        if let birthday = pet.birthday {
            metrics.append(metric(
                .zodiac,
                label: metricLabel(.zodiac, localization: l),
                value: Human.westernZodiacDisplay(for: birthday, l: l)
            ))
            let equivalent = pet.humanEquivalentAgeTextForWallet(birthday: birthday, l: l)
            if !equivalent.isEmpty {
                metrics.append(metric(
                    .humanEquivalentAge,
                    label: metricLabel(.humanEquivalentAge, localization: l),
                    value: equivalent
                ))
            }
        }
        return ZenExpandedProfileDTO(
            metrics: metrics,
            personalityStory: PetTagGreeting.homeSubtitleHint(
                pet: pet,
                hour: Calendar.current.component(.hour, from: now),
                l: l
            )
        )
    }

    private static func expandedProfile(
        for plant: Plant,
        now: Date,
        localization l: L10n
    ) -> ZenExpandedProfileDTO {
        let referenceDate = plant.acquiredDate ?? plant.createdAt
        let days = max(0, Calendar.current.dateComponents([.day], from: referenceDate, to: now).day ?? 0)
        let species = plant.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = [plant.roomName, plant.location]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
        let condition = "\(plantHealthTitle(plant.healthStatus, localization: l)) · \(plantLightTitle(plant.lightLevel, localization: l))"
        var metrics = [
            metric(
                .together,
                label: l.tr(
                    zh: "养护",
                    en: "In care",
                    de: "In Pflege",
                    es: "En cuidado",
                    pt: "Sob cuidado",
                    fr: "En soin",
                    ja: "お世話",
                    ko: "함께 돌봄",
                    it: "In cura"
                ),
                value: localizedDays(days, localization: l)
            )
        ]
        if !species.isEmpty {
            metrics.append(metric(
                .species,
                label: metricLabel(.species, localization: l),
                value: species
            ))
        }
        if let location {
            metrics.append(metric(
                .location,
                label: metricLabel(.location, localization: l),
                value: location
            ))
        }
        metrics.append(metric(
            .condition,
            label: metricLabel(.condition, localization: l),
            value: condition
        ))
        return ZenExpandedProfileDTO(
            metrics: metrics,
            personalityStory: plantPersonalityStory(
                name: plant.name,
                light: plant.lightLevel,
                health: plant.healthStatus,
                localization: l
            )
        )
    }

    private static func metric(
        _ kind: ZenExpandedMetricKind,
        label: String,
        value: String
    ) -> ZenExpandedMetricDTO {
        ZenExpandedMetricDTO(kind: kind, label: label, value: value)
    }

    private static func metricLabel(
        _ kind: ZenExpandedMetricKind,
        localization l: L10n
    ) -> String {
        switch kind {
        case .age:
            l.tr(zh: "年龄", en: "Age", de: "Alter", es: "Edad", pt: "Idade", fr: "Âge", ja: "年齢", ko: "나이", it: "Età")
        case .together:
            l.tr(zh: "相伴", en: "Together", de: "Zusammen", es: "Juntos", pt: "Juntos", fr: "Ensemble", ja: "一緒に", ko: "함께", it: "Insieme")
        case .zodiac:
            l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen", es: "Zodiaco", pt: "Zodíaco", fr: "Signe", ja: "星座", ko: "별자리", it: "Segno")
        case .mbti:
            "MBTI"
        case .humanEquivalentAge:
            l.tr(zh: "人类年龄", en: "Human age", de: "Menschenalter", es: "Edad humana", pt: "Idade humana", fr: "Âge humain", ja: "人間年齢", ko: "사람 나이", it: "Età umana")
        case .species:
            l.tr(zh: "物种", en: "Species", de: "Art", es: "Especie", pt: "Espécie", fr: "Espèce", ja: "種類", ko: "종", it: "Specie")
        case .location:
            l.tr(zh: "位置", en: "Place", de: "Ort", es: "Lugar", pt: "Local", fr: "Emplacement", ja: "場所", ko: "위치", it: "Posizione")
        case .condition:
            l.tr(zh: "状态", en: "Condition", de: "Zustand", es: "Estado", pt: "Estado", fr: "État", ja: "状態", ko: "상태", it: "Stato")
        }
    }

    private static func localizedDays(_ days: Int, localization l: L10n) -> String {
        l.tr(
            zh: "\(days) 天",
            en: "\(days) days",
            de: "\(days) Tage",
            es: "\(days) días",
            pt: "\(days) dias",
            fr: "\(days) jours",
            ja: "\(days)日",
            ko: "\(days)일",
            it: "\(days) giorni"
        )
    }

    private static func localizedTogetherDays(_ days: Int, localization l: L10n) -> String {
        guard days < 0 else { return localizedDays(days, localization: l) }
        let remaining = abs(days)
        return l.tr(
            zh: "\(remaining) 天后到家",
            en: "Home in \(remaining) days",
            de: "In \(remaining) Tagen daheim",
            es: "En casa en \(remaining) días",
            pt: "Em casa em \(remaining) dias",
            fr: "À la maison dans \(remaining) jours",
            ja: "あと\(remaining)日でお迎え",
            ko: "\(remaining)일 후 함께해요",
            it: "A casa tra \(remaining) giorni"
        )
    }

    private static func humanPersonalityStory(
        mbti: String,
        isOwner: Bool,
        localization l: L10n
    ) -> String {
        if mbti.contains("N") && mbti.contains("T") {
            return l.tr(zh: "把好奇心变成清晰想法的思考派。", en: "Turns curiosity into clear ideas.", de: "Macht aus Neugier klare Ideen.", es: "Convierte la curiosidad en ideas claras.", pt: "Transforma curiosidade em ideias claras.", fr: "Transforme la curiosité en idées claires.", ja: "好奇心を明快なアイデアに変えるタイプ。", ko: "호기심을 선명한 생각으로 바꾸는 타입.", it: "Trasforma la curiosità in idee chiare.")
        }
        if mbti.contains("N") && mbti.contains("F") {
            return l.tr(zh: "很会感受人与故事之间的温度。", en: "Notices the warmth between people and stories.", de: "Spürt die Wärme zwischen Menschen und Geschichten.", es: "Percibe la calidez entre personas e historias.", pt: "Percebe o calor entre pessoas e histórias.", fr: "Perçoit la chaleur entre les personnes et les histoires.", ja: "人と物語のあいだの温度を感じ取るタイプ。", ko: "사람과 이야기 사이의 온기를 잘 느껴요.", it: "Coglie il calore tra persone e storie.")
        }
        if mbti.contains("S") && mbti.contains("J") {
            return l.tr(zh: "喜欢把重要的小事安稳照顾好。", en: "Keeps the important little things steady.", de: "Hält die wichtigen kleinen Dinge verlässlich zusammen.", es: "Cuida con constancia las pequeñas cosas importantes.", pt: "Cuida com constância das pequenas coisas importantes.", fr: "Prend soin avec constance des petites choses importantes.", ja: "大切な小さなことを着実に整えるタイプ。", ko: "중요한 작은 일들을 차분히 챙겨요.", it: "Si prende cura con costanza delle piccole cose importanti.")
        }
        if mbti.contains("S") && mbti.contains("P") {
            return l.tr(zh: "擅长捕捉当下的新鲜与乐趣。", en: "Finds freshness and fun in the moment.", de: "Entdeckt Frische und Freude im Augenblick.", es: "Encuentra novedad y diversión en el momento.", pt: "Encontra novidade e diversão no momento.", fr: "Trouve la nouveauté et le plaisir dans l’instant.", ja: "今この瞬間の新鮮さと楽しさを見つけるタイプ。", ko: "지금 이 순간의 새로움과 재미를 잘 찾아요.", it: "Trova novità e divertimento nel momento.")
        }
        return isOwner
            ? l.tr(zh: "家里日常节奏的温柔守护者。", en: "A gentle keeper of the household rhythm.", de: "Behütet sanft den Rhythmus des Zuhauses.", es: "Cuida con cariño el ritmo del hogar.", pt: "Cuida com carinho do ritmo da casa.", fr: "Veille avec douceur au rythme du foyer.", ja: "家の日々のリズムをやさしく守る人。", ko: "집의 일상 리듬을 다정하게 지켜요.", it: "Custodisce con dolcezza il ritmo di casa.")
            : l.tr(zh: "一起生活，也一起把日子变得柔软。", en: "Shares the home and makes everyday life softer.", de: "Teilt das Zuhause und macht den Alltag sanfter.", es: "Comparte el hogar y hace más amable el día a día.", pt: "Compartilha a casa e deixa o dia a dia mais leve.", fr: "Partage le foyer et adoucit le quotidien.", ja: "一緒に暮らし、毎日をやわらかくしてくれる人。", ko: "함께 살며 일상을 더 포근하게 만들어요.", it: "Condivide la casa e rende più dolce ogni giorno.")
    }

    private static func plantPersonalityStory(
        name: String,
        light: PlantLightLevel,
        health: PlantHealthStatus,
        localization l: L10n
    ) -> String {
        if health == .watching || health == .stressed {
            return l.tr(zh: "\(name) 正在轻轻提醒你多看一眼。", en: "\(name) is gently asking for a closer look.", de: "\(name) bittet sanft um einen genaueren Blick.", es: "\(name) pide con suavidad un poco más de atención.", pt: "\(name) pede com delicadeza um pouco mais de atenção.", fr: "\(name) demande doucement un peu plus d’attention.", ja: "\(name)が、もう少し見てほしいとそっと伝えています。", ko: "\(name)이 조금 더 살펴봐 달라고 조용히 말해요.", it: "\(name) chiede con delicatezza un po’ più di attenzione.")
        }
        switch light {
        case .brightIndirect, .direct:
            return l.tr(zh: "\(name) 是喜欢明亮角落的生长派。", en: "\(name) is a bright-corner kind of grower.", de: "\(name) wächst am liebsten in hellen Ecken.", es: "A \(name) le encantan los rincones luminosos.", pt: "\(name) gosta de crescer em cantos iluminados.", fr: "\(name) aime grandir dans les coins lumineux.", ja: "\(name)は明るい場所が好きな成長派。", ko: "\(name)은 밝은 구석에서 자라는 걸 좋아해요.", it: "\(name) ama crescere negli angoli luminosi.")
        case .low, .medium:
            return l.tr(zh: "\(name) 按自己的节奏安静生长。", en: "\(name) grows quietly at their own pace.", de: "\(name) wächst ruhig im eigenen Tempo.", es: "\(name) crece tranquilamente a su ritmo.", pt: "\(name) cresce em silêncio no próprio ritmo.", fr: "\(name) pousse tranquillement à son rythme.", ja: "\(name)は自分のペースで静かに育っています。", ko: "\(name)은 자기만의 속도로 조용히 자라고 있어요.", it: "\(name) cresce in silenzio al proprio ritmo.")
        }
    }

    private static func plantHealthTitle(_ status: PlantHealthStatus, localization l: L10n) -> String {
        switch status {
        case .thriving: l.tr(zh: "状态很好", en: "Thriving", de: "Sehr gut", es: "Floreciente", pt: "Vigorosa", fr: "Épanouie", ja: "元気", ko: "아주 건강함", it: "Rigogliosa")
        case .stable: l.tr(zh: "稳定", en: "Stable", de: "Stabil", es: "Estable", pt: "Estável", fr: "Stable", ja: "安定", ko: "안정적", it: "Stabile")
        case .watching: l.tr(zh: "需要观察", en: "Watching", de: "Beobachten", es: "En observación", pt: "Em observação", fr: "À surveiller", ja: "様子見", ko: "관찰 필요", it: "Da osservare")
        case .stressed: l.tr(zh: "需要留意", en: "Needs attention", de: "Braucht Aufmerksamkeit", es: "Necesita atención", pt: "Precisa de atenção", fr: "À surveiller", ja: "要注意", ko: "주의 필요", it: "Richiede attenzione")
        }
    }

    private static func plantLightTitle(_ level: PlantLightLevel, localization l: L10n) -> String {
        switch level {
        case .low: l.tr(zh: "弱光", en: "Low light", de: "Wenig Licht", es: "Luz baja", pt: "Pouca luz", fr: "Faible lumière", ja: "弱い光", ko: "약한 빛", it: "Luce bassa")
        case .medium: l.tr(zh: "中等光", en: "Medium light", de: "Mittleres Licht", es: "Luz media", pt: "Luz média", fr: "Lumière moyenne", ja: "中程度の光", ko: "중간 빛", it: "Luce media")
        case .brightIndirect: l.tr(zh: "明亮散射光", en: "Bright indirect", de: "Hell indirekt", es: "Luz indirecta brillante", pt: "Luz indireta forte", fr: "Lumière indirecte vive", ja: "明るい間接光", ko: "밝은 간접광", it: "Luce indiretta intensa")
        case .direct: l.tr(zh: "直射光", en: "Direct sun", de: "Direkte Sonne", es: "Sol directo", pt: "Sol direto", fr: "Soleil direct", ja: "直射日光", ko: "직사광", it: "Sole diretto")
        }
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
                inactiveAt: $0.passedAwayDate,
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
                inactiveAt: $0.passedAwayDate,
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
                inactiveAt: $0.archivedAt,
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
