//
//  PresenceReminderScheduler.swift
//  Ohana
//
//  Local Zen reminders. Scheduling is user-triggered and has no polling timer.
//

import Foundation
import UserNotifications

nonisolated struct PresenceLocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let weekday: Int?
    let hour: Int
    let minute: Int
    let isSecondReminder: Bool
    /// Relative to the fire date. A second reminder after midnight belongs to
    /// the preceding check-in day and therefore uses `-1`.
    let checkInDayOffset: Int
}

nonisolated struct PresenceDatedLocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
    let isSecondReminder: Bool
    let checkInDayKey: String
}

nonisolated enum PresenceReminderRequestFactory {
    static let identifierPrefix = "presence.deadline."
    static let categoryIdentifier = "OHANA_PRESENCE_CHECK_IN"
    static let okayActionIdentifier = "PRESENCE_OKAY"
    static let maximumPendingRequestCount = PresenceNotificationPendingPolicy.maximumPresencePendingRequestCount

    static func makeRequests(
        configuration: PresenceReminderConfiguration,
        title: String,
        body: String
    ) -> [PresenceLocalNotificationRequest] {
        guard configuration.isEnabled else { return [] }

        return configuration.schedules.enumerated().flatMap { index, schedule in
            let base = PresenceLocalNotificationRequest(
                identifier: identifier(for: index, schedule: schedule, suffix: "primary"),
                title: title,
                body: body,
                weekday: schedule.weekday?.rawValue,
                hour: schedule.hour,
                minute: schedule.minute,
                isSecondReminder: false,
                checkInDayOffset: 0
            )

            guard configuration.sendsSecondLocalReminder,
                  let grace = configuration.gracePeriodMinutes else {
                return [base]
            }

            let totalMinutes = schedule.hour * 60 + schedule.minute + grace
            let wrappedMinutes = totalMinutes % (24 * 60)
            var weekday = schedule.weekday?.rawValue
            if totalMinutes >= 24 * 60, let current = weekday {
                weekday = current == 7 ? 1 : current + 1
            }
            let secondSchedule = PresenceReminderSchedule(
                weekday: weekday.flatMap(PresenceReminderWeekday.init(rawValue:)),
                hour: wrappedMinutes / 60,
                minute: wrappedMinutes % 60
            )
            let second = PresenceLocalNotificationRequest(
                identifier: identifier(for: index, schedule: secondSchedule, suffix: "second"),
                title: title,
                body: body,
                weekday: secondSchedule.weekday?.rawValue,
                hour: secondSchedule.hour,
                minute: secondSchedule.minute,
                isSecondReminder: true,
                checkInDayOffset: totalMinutes >= 24 * 60 ? -1 : 0
            )
            return [base, second]
        }
    }

    private static func identifier(
        for index: Int,
        schedule: PresenceReminderSchedule,
        suffix: String
    ) -> String {
        let weekday = schedule.weekday?.rawValue ?? 0
        return "\(identifierPrefix)\(index).\(weekday).\(schedule.hour).\(schedule.minute).\(suffix)"
    }

    /// Expands repeating schedule templates into bounded, one-shot requests.
    /// A successful check-in can then remove only today's requests without
    /// disabling future reminders. The bounded window is replenished whenever
    /// the user opens Zen mode or saves reminder settings.
    static func datedRequests(
        from templates: [PresenceLocalNotificationRequest],
        now: Date = Date(),
        calendar proposedCalendar: Calendar = .autoupdatingCurrent,
        limit: Int = maximumPendingRequestCount
    ) -> [PresenceDatedLocalNotificationRequest] {
        guard !templates.isEmpty, limit > 0 else { return [] }
        var calendar = proposedCalendar
        calendar.timeZone = proposedCalendar.timeZone
        let start = calendar.startOfDay(for: now)
        guard let horizonEnd = calendar.date(
            byAdding: .day,
            value: PresenceNotificationPendingPolicy.rollingWindowDays,
            to: start
        ) else { return [] }
        var candidates: [PresenceDatedLocalNotificationRequest] = []

        // The extra fire-date day lets an after-midnight second reminder stay
        // attached to the final check-in day in the rolling window.
        for offset in 0 ... PresenceNotificationPendingPolicy.rollingWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for template in templates where template.weekday == nil || template.weekday == weekday {
                guard let fireDate = calendar.date(
                    bySettingHour: template.hour,
                    minute: template.minute,
                    second: 0,
                    of: day
                ), fireDate > now else { continue }
                let checkInDay = calendar.date(
                    byAdding: .day,
                    value: template.checkInDayOffset,
                    to: fireDate
                ) ?? fireDate
                let normalizedCheckInDay = calendar.startOfDay(for: checkInDay)
                guard normalizedCheckInDay >= start,
                      normalizedCheckInDay < horizonEnd else { continue }
                let checkInDayKey = dayKey(for: checkInDay, calendar: calendar)
                candidates.append(PresenceDatedLocalNotificationRequest(
                    identifier: "\(template.identifier).\(checkInDayKey)",
                    title: template.title,
                    body: template.body,
                    fireDate: fireDate,
                    isSecondReminder: template.isSecondReminder,
                    checkInDayKey: checkInDayKey
                ))
            }
        }

        var selected: [PresenceDatedLocalNotificationRequest] = []
        var selectedKindsByDay: [String: Set<Bool>] = [:]
        for candidate in candidates.sorted(by: { $0.fireDate < $1.fireDate }) {
            var selectedKinds = selectedKindsByDay[candidate.checkInDayKey, default: []]
            guard selectedKinds.count < PresenceNotificationPendingPolicy.maximumRequestsPerCheckInDay else {
                continue
            }
            guard selectedKinds.insert(candidate.isSecondReminder).inserted else { continue }
            selectedKindsByDay[candidate.checkInDayKey] = selectedKinds
            selected.append(candidate)
            if selected.count == limit { break }
        }
        return selected
    }

    static func dayIdentifierSuffix(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        ".\(dayKey(for: date, calendar: calendar))"
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

@MainActor
protocol PresenceReminderScheduling {
    func replaceRequests(_ requests: [PresenceLocalNotificationRequest]) async throws
    func cancelToday(now: Date) async
    func cancelAll() async
}

@MainActor
protocol PresenceNotificationCenterAccess: AnyObject {
    func pendingRequests() async -> [UNNotificationRequest]
    func deliveredRequestIdentifiers() async -> [String]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
    func removeDeliveredRequests(withIdentifiers identifiers: [String])
}

@MainActor
private final class SystemPresenceNotificationCenterAccess: PresenceNotificationCenterAccess {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter) {
        self.center = center
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func deliveredRequestIdentifiers() async -> [String] {
        let notifications = await center.deliveredNotifications()
        return notifications.map(\.request.identifier)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredRequests(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class SystemPresenceReminderScheduler: PresenceReminderScheduling {
    private let notificationCenter: any PresenceNotificationCenterAccess
    private let now: () -> Date
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        notificationCenter = SystemPresenceNotificationCenterAccess(center: center)
        self.now = now
        self.calendar = calendar
    }

    init(
        notificationCenter: any PresenceNotificationCenterAccess,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.calendar = calendar
    }

    func replaceRequests(_ requests: [PresenceLocalNotificationRequest]) async throws {
        await cancelAll()
        let pendingRequests = await notificationCenter.pendingRequests()
        let nonPresenceRequests = pendingRequests.filter {
            !$0.identifier.hasPrefix(PresenceReminderRequestFactory.identifierPrefix)
        }
        let healthCriticalCount = nonPresenceRequests.count(where: {
            $0.content.userInfo["notificationTier"] as? String == NotificationDeliveryTier.healthCritical.rawValue
        })
        let availableCount = PresenceNotificationPendingPolicy.availableRequestCount(
            nonPresencePendingCount: nonPresenceRequests.count,
            healthCriticalPendingCount: healthCriticalCount
        )
        let classification = NotificationDeliveryPolicy.presenceCheckInClassification()
        let datedRequests = PresenceReminderRequestFactory.datedRequests(
            from: requests,
            now: now(),
            calendar: calendar,
            limit: availableCount
        )

        for request in datedRequests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            content.categoryIdentifier = PresenceReminderRequestFactory.categoryIdentifier
            var userInfo = NotificationDeliveryPolicy.userInfo(for: classification)
            userInfo["presenceAction"] = "checkInOwner"
            userInfo["notificationId"] = request.identifier
            content.userInfo = userInfo

            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.year = calendar.component(.year, from: request.fireDate)
            components.month = calendar.component(.month, from: request.fireDate)
            components.day = calendar.component(.day, from: request.fireDate)
            components.hour = calendar.component(.hour, from: request.fireDate)
            components.minute = calendar.component(.minute, from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await notificationCenter.add(
                UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            )
        }
    }

    func cancelToday(now: Date = Date()) async {
        let suffix = PresenceReminderRequestFactory.dayIdentifierSuffix(for: now, calendar: calendar)
        let pendingRequests = await notificationCenter.pendingRequests()
        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { isPresenceIdentifier($0, withSuffix: suffix) }
        let deliveredRequests = await notificationCenter.deliveredRequestIdentifiers()
        let deliveredIdentifiers = deliveredRequests
            .filter { isPresenceIdentifier($0, withSuffix: suffix) }
        notificationCenter.removePendingRequests(withIdentifiers: pendingIdentifiers)
        notificationCenter.removeDeliveredRequests(withIdentifiers: deliveredIdentifiers)
    }

    func cancelAll() async {
        let pendingRequests = await notificationCenter.pendingRequests()
        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(PresenceReminderRequestFactory.identifierPrefix) }
        let deliveredRequests = await notificationCenter.deliveredRequestIdentifiers()
        let deliveredIdentifiers = deliveredRequests
            .filter { $0.hasPrefix(PresenceReminderRequestFactory.identifierPrefix) }
        notificationCenter.removePendingRequests(withIdentifiers: pendingIdentifiers)
        notificationCenter.removeDeliveredRequests(withIdentifiers: deliveredIdentifiers)
    }

    private func isPresenceIdentifier(_ identifier: String, withSuffix suffix: String) -> Bool {
        identifier.hasPrefix(PresenceReminderRequestFactory.identifierPrefix) &&
            identifier.hasSuffix(suffix)
    }
}

@MainActor
enum PresenceReminderActivationResult: Equatable {
    case scheduled
    case disabled
    case denied(PresenceReminderConfigurationDenial)
    case notificationsNotAuthorized
    case schedulingFailed
}

@MainActor
struct PresenceReminderActivationCoordinator {
    /// This method is called only from the user's explicit Enable/Save action;
    /// it is never part of onboarding or passive app launch.
    static func applyAfterUserRequest(
        _ configuration: PresenceReminderConfiguration,
        capabilities: OhanaPlanCapabilities,
        title: String,
        body: String,
        notifications: UserNotificationManaging,
        scheduler: PresenceReminderScheduling,
        store: PresenceReminderConfigurationStoring
    ) async -> PresenceReminderActivationResult {
        if let denial = PresenceReminderConfigurationPolicy.denial(
            for: configuration,
            capabilities: capabilities
        ) {
            return .denied(denial)
        }

        guard configuration.isEnabled else {
            store.save(configuration)
            await scheduler.cancelAll()
            return .disabled
        }

        let authorized: Bool = switch await notifications.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined:
            await notifications.requestPermission()
        case .denied:
            false
        @unknown default:
            false
        }
        guard authorized else { return .notificationsNotAuthorized }

        let requests = PresenceReminderRequestFactory.makeRequests(
            configuration: configuration,
            title: title,
            body: body
        )
        do {
            try await scheduler.replaceRequests(requests)
            store.save(configuration)
            return .scheduled
        } catch {
            return .schedulingFailed
        }
    }
}
