import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanMedicationReminderReliabilityTests {
    @Test func rollingWindowAddsTheNewTailDayAfterDeliveredRequestsDisappear() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 1, day: 10, hour: 7)

        let first = await fixture.refresh(now: now)
        #expect(first.didSucceed)
        #expect(first.scheduledNotificationCount == 14)
        #expect(fixture.center.humanMedicationRequests.count == 14)
        let firstLatest = try #require(fixture.center.latestHumanMedicationDeliveryDate)

        let nextMorning = localDate(year: 2030, month: 1, day: 11, hour: 7)
        fixture.center.removeDeliveredRequests(before: nextMorning)
        fixture.center.resetOperations()
        let second = await fixture.refresh(now: nextMorning)

        #expect(second.didSucceed)
        #expect(second.scheduledNotificationCount == 1)
        #expect(second.removedNotificationCount == 0)
        #expect(fixture.center.humanMedicationRequests.count == 14)
        let secondLatest = try #require(fixture.center.latestHumanMedicationDeliveryDate)
        #expect(Calendar.current.dateComponents([.day], from: firstLatest, to: secondLatest).day == 1)
    }

    @Test func repeatedRollingRefreshIsANoOpForTheSameWindow() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 2, day: 3, hour: 7)

        _ = await fixture.refresh(now: now)
        fixture.center.resetOperations()
        let repeated = await fixture.refresh(now: now)

        #expect(repeated.didSucceed)
        #expect(repeated.scheduledNotificationCount == 0)
        #expect(repeated.removedNotificationCount == 0)
        #expect(!fixture.center.operations.contains(where: { $0.hasPrefix("add:") }))
        #expect(!fixture.center.operations.contains(where: { $0.hasPrefix("remove:") }))
    }

    @Test func rollingRefreshReplacesSameIdentifiersWhenPrivacyMarkerChanges() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 2, day: 4, hour: 7)

        _ = await fixture.refresh(now: now)
        #expect(fixture.center.humanMedicationRequests.allSatisfy {
            MedicationNotificationPrivacyMarker.isCurrent($0.content, hidesDetails: false)
        })

        fixture.defaults.set(true, forKey: MedicationNotificationPrivacyStore.hideDetailsKey)
        fixture.center.resetOperations()
        let hidden = await fixture.refresh(now: now)

        #expect(hidden.didSucceed)
        #expect(hidden.removedNotificationCount == 14)
        #expect(hidden.scheduledNotificationCount == 14)
        #expect(fixture.center.humanMedicationRequests.count == 14)
        #expect(fixture.center.humanMedicationRequests.allSatisfy {
            MedicationNotificationPrivacyMarker.isCurrent($0.content, hidesDetails: true)
                && !$0.content.body.contains("Medication 1")
                && !$0.content.body.contains("1 tablet")
        })
    }

    @Test func processWideMutationFencePreventsAnOlderServiceFromRestoringDetailedBodies() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 2, day: 5, hour: 7)
        _ = await fixture.refresh(now: now)
        let missingID = try #require(fixture.center.humanMedicationRequests.first?.identifier)
        fixture.center.removeRequest(identifier: missingID)
        fixture.center.suspendNextAdd()

        let olderRollingTask = Task { @MainActor in
            await fixture.refresh(now: now)
        }
        await fixture.center.waitUntilAddIsSuspended()

        fixture.defaults.set(true, forKey: MedicationNotificationPrivacyStore.hideDetailsKey)
        let privacyService = MedicationReminderService(
            notificationCenter: fixture.center,
            privacyDefaults: fixture.defaults
        )
        privacyService.invalidateNotificationMutations()
        let privacyTask = Task { @MainActor in
            await privacyService.refreshScheduledMedicationReminders(
                context: fixture.context,
                hidingDetails: true
            )
        }
        fixture.center.resumeSuspendedAdd()

        let olderResult = await olderRollingTask.value
        let privacyResult = await privacyTask.value

        #expect(!olderResult.didSucceed)
        #expect(privacyResult.didSucceed)
        #expect(!fixture.center.humanMedicationRequests.isEmpty)
        #expect(fixture.center.humanMedicationRequests.allSatisfy {
            MedicationNotificationPrivacyMarker.isCurrent($0.content, hidesDetails: true)
                && !$0.content.body.contains("Medication 1")
                && !$0.content.body.contains("1 tablet")
        })
    }

    @Test func appResetSecondFenceStopsAnAddStartedDuringBackupPreparation() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 2, day: 6, hour: 7)
        _ = await fixture.refresh(now: now)
        let missingID = try #require(fixture.center.humanMedicationRequests.first?.identifier)
        let backups = PausingResetAutomaticBackupManager(defaults: fixture.defaults)
        defer {
            backups.resumePrepare()
            fixture.center.resumeSuspendedAdd()
        }
        var fenceCount = 0
        let resetter = StaticAppResetter(
            questManager: QuestManager(),
            automaticBackups: backups,
            defaults: fixture.defaults,
            deletePersistentData: { container in
                fixture.center.removeAllRequests()
                try container.deleteAllData()
            },
            systemSurfaceSnapshotSanitizer: {},
            prepareRuntimeForReset: {
                fenceCount += 1
                fixture.service.invalidateNotificationMutations()
            },
            fenceRuntimeBeforePersistentReset: {
                fenceCount += 1
                fixture.service.invalidateNotificationMutations()
            }
        )

        let resetTask = Task { @MainActor in
            try await resetter.reset(
                context: fixture.context,
                options: AppResetService.Options(
                    preserveLocalePreferences: true,
                    cancelPendingNotifications: false,
                    deleteCustomBackground: false,
                    deleteHumanNoteAttachments: false,
                    resetSharedRuntimeState: false,
                    cleanUpAutomaticBackups: true
                )
            )
        }
        await backups.waitUntilPrepareIsSuspended()

        fixture.center.removeRequest(identifier: missingID)
        fixture.center.suspendNextAdd()
        let staleRollingTask = Task { @MainActor in
            await fixture.refresh(now: now)
        }
        await fixture.center.waitUntilAddIsSuspended()

        backups.resumePrepare()
        let resetResult = try await resetTask.value
        #expect(resetResult.automaticBackupCleanup == .removed)
        #expect(fenceCount == 2)
        #expect(fixture.center.humanMedicationRequests.isEmpty)

        fixture.center.resumeSuspendedAdd()
        let staleResult = await staleRollingTask.value
        #expect(!staleResult.didSucceed)
        #expect(fixture.center.humanMedicationRequests.isEmpty)
    }

    @Test func stoppingAndDeletingAPlanRemoveEveryPendingRequest() async throws {
        let fixture = try makeFixture(medicationCount: 1)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 3, day: 4, hour: 7)
        let medication = try #require(fixture.medications.first)

        _ = await fixture.refresh(now: now)
        #expect(!fixture.center.humanMedicationRequests.isEmpty)

        medication.isActive = false
        try fixture.context.save()
        let stopped = await fixture.refresh(now: now)
        #expect(stopped.removedNotificationCount == 14)
        #expect(fixture.center.humanMedicationRequests.isEmpty)

        medication.isActive = true
        try fixture.context.save()
        _ = await fixture.refresh(now: now)
        #expect(!fixture.center.humanMedicationRequests.isEmpty)

        fixture.context.delete(medication)
        try fixture.context.save()
        let deleted = await fixture.refresh(now: now)
        #expect(deleted.removedNotificationCount == 14)
        #expect(fixture.center.humanMedicationRequests.isEmpty)
    }

    @Test func workBudgetRetryKeepsTheCurrentMedicationPageUntilItsRequestsAreFilled() async throws {
        let fixture = try makeFixture(medicationCount: 2)
        defer { fixture.clearDefaults() }
        let now = localDate(year: 2030, month: 4, day: 5, hour: 7)
        let firstMedicationID = try #require(fixture.medications.first?.id)
        let smallBudget = workBudget(maximumItemCount: 1)

        for _ in 0 ..< 13 {
            let result = await fixture.refresh(now: now, budget: smallBudget)
            #expect(result.hasMoreWork)
            #expect(HumanMedicationReminderRollingCursorStore.offset(defaults: fixture.defaults) == 0)
        }
        let finishingCurrentPage = await fixture.refresh(now: now, budget: smallBudget)

        #expect(finishingCurrentPage.hasMoreWork)
        #expect(HumanMedicationReminderRollingCursorStore.offset(defaults: fixture.defaults) == 1)
        #expect(fixture.center.humanMedicationRequests.count == 14)
        #expect(fixture.center.humanMedicationRequests.allSatisfy {
            MedicationNotificationIdentifierPolicy.humanReminderMedicationID(in: $0.identifier) == firstMedicationID
        })
    }

    @Test func fullSystemNotificationCapacityDoesNotCreatePermanentContinuationRetry() async throws {
        let unrelated = (0 ..< NotificationPendingBudget.managedPendingRequestLimit).map { index in
            pendingRequest(identifier: "unrelated-\(index)")
        }
        let fixture = try makeFixture(medicationCount: 1, initialRequests: unrelated)
        defer { fixture.clearDefaults() }

        let result = await fixture.refresh(
            now: localDate(year: 2030, month: 5, day: 6, hour: 7)
        )

        #expect(result.didSucceed)
        #expect(result.scheduledNotificationCount == 0)
        #expect(!result.hasMoreWork)
        #expect(!HumanMedicationReminderRollingCursorStore.hasContinuation(defaults: fixture.defaults))
        #expect(fixture.center.requests.count == NotificationPendingBudget.managedPendingRequestLimit)
    }

    @Test func nextDayBoundaryUsesCalendarDaysAcrossDaylightSavingChanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let beforeSpringForward = try #require(calendar.date(from: DateComponents(
            year: 2030,
            month: 3,
            day: 10,
            hour: 0,
            minute: 30
        )))
        let sameDay = try #require(calendar.date(byAdding: .hour, value: 8, to: beforeSpringForward))
        let nextBoundary = try #require(HumanMedicationTimelineRefreshPolicy.nextDayBoundary(
            after: beforeSpringForward,
            calendar: calendar
        ))

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextBoundary)
        #expect(components.year == 2030)
        #expect(components.month == 3)
        #expect(components.day == 11)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(!HumanMedicationTimelineRefreshPolicy.crossesDayBoundary(
            from: beforeSpringForward,
            to: sameDay,
            calendar: calendar
        ))
        #expect(HumanMedicationTimelineRefreshPolicy.crossesDayBoundary(
            from: beforeSpringForward,
            to: nextBoundary,
            calendar: calendar
        ))
    }

    @Test func presentationDeadlineAdvancesWhenTheNextDoseBecomesDue() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(calendar.date(from: DateComponents(
            year: 2030,
            month: 6,
            day: 7
        )))
        let beforeDose = try #require(calendar.date(byAdding: .minute, value: 7 * 60 + 30, to: day))
        let doseTime = try #require(calendar.date(byAdding: .hour, value: 8, to: day))
        let afterDose = try #require(calendar.date(byAdding: .minute, value: 8 * 60 + 1, to: day))
        let medication = HumanMedication(
            humanId: UUID().uuidString,
            name: "Medication",
            dosage: "1 tablet",
            frequency: .daily,
            firstDoseTime: doseTime,
            startDate: day.addingTimeInterval(-86400)
        )

        #expect(HumanMedicationTimelineRefreshPolicy.nextDosePresentationDeadline(
            after: beforeDose,
            medications: [medication],
            calendar: calendar
        ) == doseTime)
        #expect(HumanMedicationTimelineRefreshPolicy.nextDosePresentationDeadline(
            after: afterDose,
            medications: [medication],
            calendar: calendar
        ) == nil)
    }

    private func makeFixture(
        medicationCount: Int,
        initialRequests: [UNNotificationRequest] = []
    ) throws -> ReminderReliabilityFixture {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Alex")
        context.insert(human)
        let medications = (0 ..< medicationCount).map { index in
            let medication = HumanMedication(
                humanId: human.id.uuidString,
                name: "Medication \(index + 1)",
                dosage: "1 tablet",
                frequency: .daily,
                firstDoseTime: localDate(year: 2030, month: 1, day: 1, hour: 8),
                // Privacy reconciliation intentionally uses the service's live
                // clock while rolling-window cases inject dates in 2030. Keep
                // the shared fixture active for both clocks so this test proves
                // mutation ordering instead of accidentally testing a future
                // course that cannot yet be rebuilt.
                startDate: Date(timeIntervalSince1970: 0)
            )
            medication.createdAt = Date(timeIntervalSinceReferenceDate: 1000.0 + Double(index))
            context.insert(medication)
            return medication
        }
        try context.save()

        let defaultsName = "HumanMedicationReminderReliabilityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let center = ReliabilityNotificationCenter(requests: initialRequests)
        let service = MedicationReminderService(
            notificationCenter: center,
            privacyDefaults: defaults
        )
        return ReminderReliabilityFixture(
            container: container,
            context: context,
            medications: medications,
            center: center,
            service: service,
            defaultsName: defaultsName,
            defaults: defaults
        )
    }

    private func workBudget(maximumItemCount: Int = 64) -> OhanaBackgroundWorkBudget {
        OhanaBackgroundWorkBudget(
            operation: "human_medication_reminder_reliability_test",
            maximumItemCount: maximumItemCount,
            maximumWallClockSeconds: 30,
            allowsExpensiveWork: true,
            isDeferred: false
        )
    }

    private func localDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? .distantPast
    }

    private func pendingRequest(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: identifier,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
    }
}

@MainActor
private struct ReminderReliabilityFixture {
    let container: ModelContainer
    let context: ModelContext
    let medications: [HumanMedication]
    let center: ReliabilityNotificationCenter
    let service: MedicationReminderService
    let defaultsName: String
    let defaults: UserDefaults

    func refresh(
        now: Date,
        budget: OhanaBackgroundWorkBudget = OhanaBackgroundWorkBudget(
            operation: "human_medication_reminder_reliability_test",
            maximumItemCount: 64,
            maximumWallClockSeconds: 30,
            allowsExpensiveWork: true,
            isDeferred: false
        )
    ) async -> HumanMedicationReminderRollingRefreshResult {
        await service.reconcileHumanMedicationRollingWindow(
            context: context,
            budget: budget,
            now: now
        )
    }

    func clearDefaults() {
        defaults.removePersistentDomain(forName: defaultsName)
        withExtendedLifetime(container) {}
    }
}

@MainActor
private final class ReliabilityNotificationCenter: MedicationLocalNotificationCenterScheduling {
    private(set) var requests: [String: UNNotificationRequest]
    private(set) var operations: [String] = []
    private var shouldSuspendNextAdd = false
    private var didSuspendAdd = false
    private var addStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var addResumeContinuation: CheckedContinuation<Void, Never>?

    init(requests: [UNNotificationRequest]) {
        self.requests = Dictionary(uniqueKeysWithValues: requests.map { ($0.identifier, $0) })
    }

    var humanMedicationRequests: [UNNotificationRequest] {
        requests.values
            .filter { MedicationNotificationIdentifierPolicy.isHumanReminder($0.identifier) }
            .sorted { $0.identifier < $1.identifier }
    }

    var latestHumanMedicationDeliveryDate: Date? {
        humanMedicationRequests.compactMap { request in
            (request.content.userInfo["scheduledAt"] as? NSNumber).map {
                Date(timeIntervalSince1970: $0.doubleValue)
            }
        }.max()
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        operations.append("pending")
        return requests.values.sorted { $0.identifier < $1.identifier }
    }

    func deliveredRequests() async -> [UNNotificationRequest] { [] }

    func add(_ request: UNNotificationRequest) async throws {
        operations.append("add:\(request.identifier)")
        if shouldSuspendNextAdd {
            shouldSuspendNextAdd = false
            didSuspendAdd = true
            let waiters = addStartedWaiters
            addStartedWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                addResumeContinuation = continuation
            }
        }
        requests[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        operations.append("remove:\(identifiers.sorted().joined(separator: ","))")
        for identifier in identifiers {
            requests.removeValue(forKey: identifier)
        }
    }

    func removeDeliveredRequests(withIdentifiers _: [String]) {}

    func removeDeliveredRequests(before date: Date) {
        let identifiers = humanMedicationRequests.compactMap { request -> String? in
            guard let raw = request.content.userInfo["scheduledAt"] as? NSNumber,
                  Date(timeIntervalSince1970: raw.doubleValue) < date else {
                return nil
            }
            return request.identifier
        }
        for identifier in identifiers {
            requests.removeValue(forKey: identifier)
        }
    }

    func resetOperations() {
        operations.removeAll()
    }

    func removeRequest(identifier: String) {
        requests.removeValue(forKey: identifier)
    }

    func removeAllRequests() {
        operations.append("removeAll")
        requests.removeAll()
    }

    func suspendNextAdd() {
        shouldSuspendNextAdd = true
        didSuspendAdd = false
    }

    func waitUntilAddIsSuspended() async {
        if didSuspendAdd { return }
        await withCheckedContinuation { continuation in
            addStartedWaiters.append(continuation)
        }
    }

    func resumeSuspendedAdd() {
        addResumeContinuation?.resume()
        addResumeContinuation = nil
    }
}

@MainActor
private final class PausingResetAutomaticBackupManager: AutomaticBackupManaging {
    private let defaults: UserDefaults
    private var didSuspendPrepare = false
    private var prepareStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var prepareResumeContinuation: CheckedContinuation<Void, Never>?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func snapshot(now: Date) -> AutomaticBackupStatus {
        AutomaticBackupStatusStore(defaults: defaults).snapshot(now: now)
    }

    func setEnabled(_ enabled: Bool, now: Date) {
        AutomaticBackupStatusStore(defaults: defaults).setEnabled(enabled, now: now)
    }

    func markReminderShown(now: Date) {
        AutomaticBackupStatusStore(defaults: defaults).markReminderShown(now: now)
    }

    func runIfDue(
        container _: ModelContainer,
        trigger _: AutomaticBackupTrigger
    ) async -> AutomaticBackupRunResult {
        .skipped(.disabled)
    }

    func runNow(
        container _: ModelContainer,
        trigger _: AutomaticBackupTrigger
    ) async -> AutomaticBackupRunResult {
        .skipped(.disabled)
    }

    func prepareForAppReset() async {
        didSuspendPrepare = true
        let waiters = prepareStartedWaiters
        prepareStartedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            prepareResumeContinuation = continuation
        }
    }

    func removeManagedAutomaticBackupsForReset() async -> AutomaticBackupResetCleanupResult {
        .removed
    }

    func retryManagedAutomaticBackupCleanup() async -> AutomaticBackupResetCleanupResult {
        .removed
    }

    func removeLegacyAutomaticBackupForHealthSafety() async -> AutomaticBackupResetCleanupResult {
        .removed
    }

    func waitUntilPrepareIsSuspended() async {
        if didSuspendPrepare { return }
        await withCheckedContinuation { continuation in
            prepareStartedWaiters.append(continuation)
        }
    }

    func resumePrepare() {
        prepareResumeContinuation?.resume()
        prepareResumeContinuation = nil
    }
}
