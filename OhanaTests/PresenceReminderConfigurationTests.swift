import Foundation
import Testing
import UserNotifications
@testable import Ohana

struct PresenceReminderConfigurationTests {
    @Test func presencePendingPolicyUsesSharedCapacityAndKeepsAHealthWindow() {
        #expect(PresenceNotificationPendingPolicy.maximumPresencePendingRequestCount == 28)
        #expect(PresenceNotificationPendingPolicy.availableRequestCount(
            nonPresencePendingCount: 0,
            healthCriticalPendingCount: 0
        ) == 28)
        #expect(PresenceNotificationPendingPolicy.availableRequestCount(
            nonPresencePendingCount: 40,
            healthCriticalPendingCount: 0
        ) == 1)
        #expect(PresenceNotificationPendingPolicy.availableRequestCount(
            nonPresencePendingCount: 40,
            healthCriticalPendingCount: 14
        ) == 15)
        #expect(PresenceNotificationPendingPolicy.availableRequestCount(
            nonPresencePendingCount: NotificationPendingBudget.managedPendingRequestLimit,
            healthCriticalPendingCount: 14
        ) == 0)
    }

    @Test func freeAllowsOneDailyDeadlineAndFixedTemplate() {
        let configuration = PresenceReminderConfiguration.initial
        #expect(PresenceReminderConfigurationPolicy.denial(
            for: configuration,
            capabilities: .make(for: .free)
        ) == nil)

        var weekday = configuration
        weekday.schedules = [.init(weekday: .monday, hour: 20, minute: 0)]
        #expect(PresenceReminderConfigurationPolicy.denial(
            for: weekday,
            capabilities: .make(for: .free)
        ) == .weekdaySchedulesRequirePersonal)
    }

    @Test func personalAllowsWeekdaysGraceSecondReminderAndEditableTemplate() {
        let configuration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [
                .init(weekday: .monday, hour: 20, minute: 0),
                .init(weekday: .friday, hour: 21, minute: 30)
            ],
            gracePeriodMinutes: 30,
            sendsSecondLocalReminder: true,
            messageTemplate: "Please check in."
        )
        #expect(PresenceReminderConfigurationPolicy.denial(
            for: configuration,
            capabilities: .make(for: .personal)
        ) == nil)
    }

    @Test func secondReminderWrapsToTheNextWeekday() throws {
        let configuration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(weekday: .saturday, hour: 23, minute: 50)],
            gracePeriodMinutes: 20,
            sendsSecondLocalReminder: true,
            messageTemplate: PresenceReminderConfiguration.fixedMessageTemplate
        )
        let requests = PresenceReminderRequestFactory.makeRequests(
            configuration: configuration,
            title: "Check in",
            body: "Open Ohana"
        )
        #expect(requests.count == 2)
        let second = try #require(requests.last)
        #expect(second.weekday == PresenceReminderWeekday.sunday.rawValue)
        #expect(second.hour == 0)
        #expect(second.minute == 10)
    }

    @Test func reminderTemplatesExpandIntoBoundedDaySpecificRequests() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 23,
            minute: 40
        )))
        let configuration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(weekday: .saturday, hour: 23, minute: 50)],
            gracePeriodMinutes: 20,
            sendsSecondLocalReminder: true,
            messageTemplate: PresenceReminderConfiguration.fixedMessageTemplate
        )
        let templates = PresenceReminderRequestFactory.makeRequests(
            configuration: configuration,
            title: "Check in",
            body: "Open Ohana"
        )

        let requests = PresenceReminderRequestFactory.datedRequests(
            from: templates,
            now: now,
            calendar: calendar
        )

        // Only the two Saturdays in the shared 14-day rolling window are
        // expanded, with one primary and one second reminder for each.
        #expect(requests.count == 4)
        #expect(requests[0].fireDate == calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 18, hour: 23, minute: 50)
        ))
        #expect(requests[1].fireDate == calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 19, hour: 0, minute: 10)
        ))
        #expect(requests[0].identifier.hasSuffix(".2026-07-18"))
        // The after-midnight reminder still belongs to Saturday's check-in,
        // so completing Saturday cancels both pending notifications.
        #expect(requests[1].identifier.hasSuffix(".2026-07-18"))
        #expect(requests[0].checkInDayKey == "2026-07-18")
        #expect(requests[1].checkInDayKey == "2026-07-18")
        #expect(Set(requests.map(\.identifier)).count == requests.count)
    }

    @Test func duplicateTemplatesStillProduceAtMostPrimaryAndSecondPerCheckInDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 12
        )))
        let configuration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(hour: 20, minute: 0)],
            gracePeriodMinutes: 30,
            sendsSecondLocalReminder: true,
            messageTemplate: PresenceReminderConfiguration.fixedMessageTemplate
        )
        let templates = PresenceReminderRequestFactory.makeRequests(
            configuration: configuration,
            title: "Check in",
            body: "Open Ohana"
        )
        let requests = PresenceReminderRequestFactory.datedRequests(
            from: templates + templates,
            now: now,
            calendar: calendar
        )
        let requestsByDay = Dictionary(grouping: requests, by: \.checkInDayKey)

        #expect(requestsByDay.count == PresenceNotificationPendingPolicy.rollingWindowDays)
        #expect(requestsByDay.values.allSatisfy { $0.count == 2 })
        #expect(requestsByDay.values.allSatisfy { Set($0.map(\.isSecondReminder)).count == 2 })
    }

    @Test func deviceLocalStoreRoundTripsWithoutChangingDefaultShape() throws {
        let suiteName = "PresenceReminderConfigurationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PresenceReminderConfigurationStore(defaults: defaults)

        #expect(store.load() == .initial)
        var expected = PresenceReminderConfiguration.initial
        expected.isEnabled = true
        store.save(expected)
        #expect(store.load() == expected)
        store.clear()
        #expect(store.load() == .initial)
    }

    @Test func currentFamilyGuardianImplementationIsFailClosed() {
        let escalator = DisabledFamilyPresenceGuardianEscalator()
        #expect(escalator.availability == .unavailableInShippingProfile)
        #expect(!AppCapabilityProfile.shipsCloudFamilyCapabilities)
    }

    @MainActor
    @Test func explicitEnableRequestsPermissionAndSchedulesWhileDisableOnlyCancels() async {
        let notifications = StubPresenceNotifications(status: .notDetermined, permissionResult: true)
        let scheduler = RecordingPresenceReminderScheduler()
        let store = MemoryPresenceReminderStore()
        var enabled = PresenceReminderConfiguration.initial
        enabled.isEnabled = true

        let enabledResult = await PresenceReminderActivationCoordinator.applyAfterUserRequest(
            enabled,
            capabilities: .make(for: .free),
            title: "Check in",
            body: "Open Ohana",
            notifications: notifications,
            scheduler: scheduler,
            store: store
        )
        #expect(enabledResult == .scheduled)
        #expect(notifications.permissionRequestCount == 1)
        #expect(scheduler.replacedRequests.count == 1)
        #expect(store.load() == enabled)

        enabled.isEnabled = false
        let disabledResult = await PresenceReminderActivationCoordinator.applyAfterUserRequest(
            enabled,
            capabilities: .make(for: .free),
            title: "Check in",
            body: "Open Ohana",
            notifications: notifications,
            scheduler: scheduler,
            store: store
        )
        #expect(disabledResult == .disabled)
        #expect(notifications.permissionRequestCount == 1)
        #expect(scheduler.cancelCount == 2)
        #expect(store.load() == enabled)
    }

    @MainActor
    @Test func systemSchedulerUsesOnlyRoutineCapacityLeftAfterNonPresenceRequests() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 12
        )))
        let nonPresence = (0 ..< 40).map {
            makePendingNotificationRequest(
                identifier: "routine.\($0)",
                tier: .routine,
                calendar: calendar
            )
        }
        let notificationCenter = RecordingPresenceNotificationCenter(pending: nonPresence)
        let scheduler = SystemPresenceReminderScheduler(
            notificationCenter: notificationCenter,
            now: { now },
            calendar: calendar
        )
        let configuration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(hour: 20, minute: 0)],
            gracePeriodMinutes: 30,
            sendsSecondLocalReminder: true,
            messageTemplate: PresenceReminderConfiguration.fixedMessageTemplate
        )
        let templates = PresenceReminderRequestFactory.makeRequests(
            configuration: configuration,
            title: "Check in",
            body: "Open Ohana"
        )

        try await scheduler.replaceRequests(templates)

        #expect(notificationCenter.addedRequests.count == 1)
        #expect(notificationCenter.removedPendingIdentifiers.isEmpty)
        let added = try #require(notificationCenter.addedRequests.first)
        #expect(added.content.userInfo["notificationTier"] as? String == "routine")
        #expect(added.content.userInfo["notificationCategory"] as? String == "presenceCheckIn")
        #expect(notificationCenter.pending.count == 41)
    }

    @MainActor
    @Test func cancelTodayRemovesPendingAndDeliveredRequestsForOriginalCheckInDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 23,
            minute: 55
        )))
        let todaySuffix = PresenceReminderRequestFactory.dayIdentifierSuffix(for: now, calendar: calendar)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let tomorrowSuffix = PresenceReminderRequestFactory.dayIdentifierSuffix(for: tomorrow, calendar: calendar)
        let pendingPrimary = "\(PresenceReminderRequestFactory.identifierPrefix)0.primary\(todaySuffix)"
        let pendingAfterMidnightSecond = "\(PresenceReminderRequestFactory.identifierPrefix)0.second\(todaySuffix)"
        let deliveredPrimary = "\(PresenceReminderRequestFactory.identifierPrefix)1.primary\(todaySuffix)"
        let deliveredAfterMidnightSecond = "\(PresenceReminderRequestFactory.identifierPrefix)1.second\(todaySuffix)"
        let tomorrowPresence = "\(PresenceReminderRequestFactory.identifierPrefix)0.primary\(tomorrowSuffix)"
        let unrelated = "routine.calendar\(todaySuffix)"
        let notificationCenter = RecordingPresenceNotificationCenter(
            pending: [
                makePendingNotificationRequest(identifier: pendingPrimary, calendar: calendar),
                makePendingNotificationRequest(identifier: pendingAfterMidnightSecond, calendar: calendar),
                makePendingNotificationRequest(identifier: tomorrowPresence, calendar: calendar),
                makePendingNotificationRequest(identifier: unrelated, calendar: calendar)
            ],
            deliveredIdentifiers: [deliveredPrimary, deliveredAfterMidnightSecond, tomorrowPresence, unrelated]
        )
        let scheduler = SystemPresenceReminderScheduler(
            notificationCenter: notificationCenter,
            now: { now },
            calendar: calendar
        )

        await scheduler.cancelToday(now: now)

        #expect(notificationCenter.removedPendingIdentifiers == [pendingPrimary, pendingAfterMidnightSecond])
        #expect(notificationCenter.removedDeliveredIdentifiers == [deliveredPrimary, deliveredAfterMidnightSecond])
        #expect(notificationCenter.pending.map(\.identifier).contains(tomorrowPresence))
        #expect(notificationCenter.pending.map(\.identifier).contains(unrelated))
        #expect(notificationCenter.deliveredIdentifiers.contains(tomorrowPresence))
        #expect(notificationCenter.deliveredIdentifiers.contains(unrelated))
    }

    @MainActor
    @Test func deniedPaidConfigurationNeverRequestsSystemPermission() async {
        let notifications = StubPresenceNotifications(status: .notDetermined, permissionResult: true)
        let scheduler = RecordingPresenceReminderScheduler()
        let store = MemoryPresenceReminderStore()
        let paid = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(weekday: .monday, hour: 20, minute: 0)],
            gracePeriodMinutes: 30,
            sendsSecondLocalReminder: true,
            messageTemplate: "Custom"
        )

        let result = await PresenceReminderActivationCoordinator.applyAfterUserRequest(
            paid,
            capabilities: .make(for: .free),
            title: "Check in",
            body: "Open Ohana",
            notifications: notifications,
            scheduler: scheduler,
            store: store
        )

        #expect(result == .denied(.weekdaySchedulesRequirePersonal))
        #expect(notifications.permissionRequestCount == 0)
        #expect(scheduler.replacedRequests.isEmpty)
        #expect(store.load() == .initial)
    }
}

@MainActor
private func makePendingNotificationRequest(
    identifier: String,
    tier: NotificationDeliveryTier? = nil,
    calendar: Calendar
) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    if let tier {
        content.userInfo = ["notificationTier": tier.rawValue]
    }
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.hour = 20
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
}

@MainActor
private final class RecordingPresenceNotificationCenter: PresenceNotificationCenterAccess {
    private(set) var pending: [UNNotificationRequest]
    private(set) var deliveredIdentifiers: [String]
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedPendingIdentifiers: [String] = []
    private(set) var removedDeliveredIdentifiers: [String] = []

    init(
        pending: [UNNotificationRequest] = [],
        deliveredIdentifiers: [String] = []
    ) {
        self.pending = pending
        self.deliveredIdentifiers = deliveredIdentifiers
    }

    func pendingRequests() async -> [UNNotificationRequest] { pending }

    func deliveredRequestIdentifiers() async -> [String] { deliveredIdentifiers }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        pending.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
        let removed = Set(identifiers)
        pending.removeAll { removed.contains($0.identifier) }
    }

    func removeDeliveredRequests(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
        let removed = Set(identifiers)
        deliveredIdentifiers.removeAll { removed.contains($0) }
    }
}

@MainActor
private final class StubPresenceNotifications: UserNotificationManaging {
    let status: UNAuthorizationStatus
    let permissionResult: Bool
    private(set) var permissionRequestCount = 0

    init(status: UNAuthorizationStatus, permissionResult: Bool) {
        self.status = status
        self.permissionResult = permissionResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestPermission() async -> Bool {
        permissionRequestCount += 1
        return permissionResult
    }

    func pendingNotificationIds() async -> Set<String> { [] }
}

@MainActor
private final class RecordingPresenceReminderScheduler: PresenceReminderScheduling {
    private(set) var replacedRequests: [PresenceLocalNotificationRequest] = []
    private(set) var cancelCount = 0
    private(set) var cancelTodayCount = 0

    func replaceRequests(_ requests: [PresenceLocalNotificationRequest]) async throws {
        cancelCount += 1
        replacedRequests = requests
    }

    func cancelAll() async {
        cancelCount += 1
        replacedRequests = []
    }

    func cancelToday(now _: Date) async {
        cancelTodayCount += 1
    }
}

private final class MemoryPresenceReminderStore: PresenceReminderConfigurationStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value = PresenceReminderConfiguration.initial

    func load() -> PresenceReminderConfiguration { lock.withLock { value } }
    func save(_ configuration: PresenceReminderConfiguration) { lock.withLock { value = configuration } }
    func clear() { lock.withLock { value = .initial } }
}
