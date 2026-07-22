//
//  GuardianSafetyPolicy.swift
//  Ohana
//
//  Pure, deterministic rules shared by client projections and mirrored by the
//  Family guardian backend. A guardian acknowledgement is not a Presence fact.
//

import Foundation

nonisolated struct GuardianGuardDaySchedule: Equatable, Sendable {
    let weekdays: Set<Int>
    let deadlineHour: Int
    let deadlineMinute: Int
    let gracePeriodMinutes: Int
    let timeZoneIdentifier: String

    init(
        weekdays: Set<Int> = Set(1 ... 7),
        deadlineHour: Int = 20,
        deadlineMinute: Int = 0,
        gracePeriodMinutes: Int = GuardianSafetyEvaluationPolicy.defaultGracePeriodMinutes,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.weekdays = Set(weekdays.filter { (1 ... 7).contains($0) })
        self.deadlineHour = min(max(deadlineHour, 0), 23)
        self.deadlineMinute = min(max(deadlineMinute, 0), 59)
        self.gracePeriodMinutes = min(max(gracePeriodMinutes, 15), 180)
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

nonisolated struct GuardianGuardDayOccurrence: Equatable, Sendable {
    let dayKey: String
    let weekday: Int
    let isScheduledWeekday: Bool
    let deadline: Date
    let evaluationTime: Date
    let isPaused: Bool

    func receivedByEvaluationTime(_ checkInDate: Date?) -> Bool {
        guard let checkInDate else { return false }
        return checkInDate <= evaluationTime
    }
}

/// Resolves guard-day boundaries in the schedule's named time zone. Existing
/// facts retain their original day key/time zone; a later time-zone change only
/// affects occurrences created under the newer schedule revision.
nonisolated enum GuardianGuardDaySchedulePolicy {
    static func occurrence(
        containing instant: Date,
        schedule: GuardianGuardDaySchedule,
        pauseUntil: Date? = nil
    ) -> GuardianGuardDayOccurrence? {
        guard let timeZone = TimeZone(identifier: schedule.timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone

        let local = calendar.dateComponents([.era, .year, .month, .day, .weekday], from: instant)
        guard let era = local.era,
              let year = local.year,
              let month = local.month,
              let day = local.day,
              let weekday = local.weekday,
              let dayStart = calendar.date(from: DateComponents(
                  calendar: calendar,
                  timeZone: timeZone,
                  era: era,
                  year: year,
                  month: month,
                  day: day
              )),
              let deadline = calendar.nextDate(
                  after: dayStart.addingTimeInterval(-1),
                  matching: DateComponents(
                      calendar: calendar,
                      timeZone: timeZone,
                      hour: schedule.deadlineHour,
                      minute: schedule.deadlineMinute,
                      second: 0
                  ),
                  matchingPolicy: .nextTime,
                  repeatedTimePolicy: .first,
                  direction: .forward
              ),
              calendar.isDate(deadline, inSameDayAs: dayStart),
              let evaluationTime = calendar.date(
                  byAdding: .minute,
                  value: schedule.gracePeriodMinutes,
                  to: deadline
              )
        else { return nil }

        return GuardianGuardDayOccurrence(
            dayKey: String(format: "%04d-%02d-%02d", year, month, day),
            weekday: weekday,
            isScheduledWeekday: schedule.weekdays.contains(weekday),
            deadline: deadline,
            evaluationTime: evaluationTime,
            isPaused: pauseUntil.map { instant < $0 } ?? false
        )
    }
}

nonisolated struct GuardianSafetyOccurrenceContext: Equatable, Sendable {
    let dayKey: String
    let isZenParticipationActive: Bool
    let hasFamilyEntitlement: Bool
    let hasActiveOwner: Bool
    let isPolicyEnabled: Bool
    let isScheduledWeekday: Bool
    let isPaused: Bool
    let receivedOwnerCheckInByDeadline: Bool

    init(
        dayKey: String,
        isZenParticipationActive: Bool = true,
        hasFamilyEntitlement: Bool = true,
        hasActiveOwner: Bool = true,
        isPolicyEnabled: Bool = true,
        isScheduledWeekday: Bool = true,
        isPaused: Bool = false,
        receivedOwnerCheckInByDeadline: Bool = false
    ) {
        self.dayKey = dayKey
        self.isZenParticipationActive = isZenParticipationActive
        self.hasFamilyEntitlement = hasFamilyEntitlement
        self.hasActiveOwner = hasActiveOwner
        self.isPolicyEnabled = isPolicyEnabled
        self.isScheduledWeekday = isScheduledWeekday
        self.isPaused = isPaused
        self.receivedOwnerCheckInByDeadline = receivedOwnerCheckInByDeadline
    }
}

nonisolated struct GuardianSafetyIncidentProgress: Equatable, Sendable {
    var consecutiveMisses: Int
    var lastGuardDayKey: String?
    var isIncidentOpen: Bool
    var didSubmitInitial: Bool
    var didSubmitFollowUp: Bool
    var isAcknowledged: Bool

    init(
        consecutiveMisses: Int = 0,
        lastGuardDayKey: String? = nil,
        isIncidentOpen: Bool = false,
        didSubmitInitial: Bool = false,
        didSubmitFollowUp: Bool = false,
        isAcknowledged: Bool = false
    ) {
        self.consecutiveMisses = max(0, consecutiveMisses)
        self.lastGuardDayKey = lastGuardDayKey
        self.isIncidentOpen = isIncidentOpen
        self.didSubmitInitial = didSubmitInitial
        self.didSubmitFollowUp = didSubmitFollowUp
        self.isAcknowledged = isAcknowledged
    }

    static let empty = GuardianSafetyIncidentProgress()
}

nonisolated enum GuardianSafetyEvaluationAction: Equatable, Sendable {
    case none
    case queueInitialAlert(consecutiveMisses: Int)
    case queueFollowUp(consecutiveMisses: Int)
    case queueRecovery
    case resetWithoutNotification
}

nonisolated struct GuardianSafetyEvaluationResult: Equatable, Sendable {
    let progress: GuardianSafetyIncidentProgress
    let action: GuardianSafetyEvaluationAction
}

nonisolated enum GuardianSafetyEvaluationPolicy {
    static let initialAlertMissCount = 2
    static let followUpMissCount = 3
    static let maximumPauseDays = 30
    static let defaultGracePeriodMinutes = 60

    static func evaluate(
        previous: GuardianSafetyIncidentProgress,
        occurrence: GuardianSafetyOccurrenceContext
    ) -> GuardianSafetyEvaluationResult {
        guard occurrence.isZenParticipationActive,
              occurrence.hasFamilyEntitlement,
              occurrence.hasActiveOwner,
              occurrence.isPolicyEnabled
        else {
            return GuardianSafetyEvaluationResult(progress: .empty, action: .resetWithoutNotification)
        }

        // A planned pause starts a new sequence when monitoring resumes. This
        // avoids a pre-pause miss making the first post-pause miss alertable.
        guard !occurrence.isPaused else {
            return GuardianSafetyEvaluationResult(progress: .empty, action: .resetWithoutNotification)
        }

        // Days outside the chosen schedule are not guard occurrences: they
        // neither increase nor reset the current consecutive count.
        guard occurrence.isScheduledWeekday else {
            return GuardianSafetyEvaluationResult(progress: previous, action: .none)
        }

        if occurrence.receivedOwnerCheckInByDeadline {
            let shouldRecover = previous.isIncidentOpen &&
                previous.didSubmitInitial &&
                !previous.isAcknowledged
            return GuardianSafetyEvaluationResult(
                progress: .empty,
                action: shouldRecover ? .queueRecovery : .resetWithoutNotification
            )
        }

        var progress = previous
        progress.consecutiveMisses += 1
        progress.lastGuardDayKey = occurrence.dayKey

        if progress.consecutiveMisses == initialAlertMissCount,
           !progress.didSubmitInitial {
            progress.isIncidentOpen = true
            progress.didSubmitInitial = true
            return GuardianSafetyEvaluationResult(
                progress: progress,
                action: .queueInitialAlert(consecutiveMisses: progress.consecutiveMisses)
            )
        }

        if progress.consecutiveMisses == followUpMissCount,
           progress.isIncidentOpen,
           progress.didSubmitInitial,
           !progress.didSubmitFollowUp,
           !progress.isAcknowledged {
            progress.didSubmitFollowUp = true
            return GuardianSafetyEvaluationResult(
                progress: progress,
                action: .queueFollowUp(consecutiveMisses: progress.consecutiveMisses)
            )
        }

        return GuardianSafetyEvaluationResult(progress: progress, action: .none)
    }

    static func acknowledge(
        _ progress: GuardianSafetyIncidentProgress
    ) -> GuardianSafetyEvaluationResult {
        guard progress.isIncidentOpen, progress.didSubmitInitial else {
            return GuardianSafetyEvaluationResult(progress: progress, action: .none)
        }
        return GuardianSafetyEvaluationResult(progress: .empty, action: .resetWithoutNotification)
    }

    static func clampedPauseUntil(
        requested: Date,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let latest = calendar.date(byAdding: .day, value: maximumPauseDays, to: now)
            ?? now.addingTimeInterval(Double(maximumPauseDays) * 86_400)
        return min(max(requested, now), latest)
    }
}
