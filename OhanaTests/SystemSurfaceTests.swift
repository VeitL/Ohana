import Foundation
import Testing
@testable import Ohana

@Suite(.serialized)
struct SystemSurfaceTests {
    @Test func externalRoutesRoundTripWithoutAcceptingForeignURLs() {
        let petID = UUID()
        let routes: [OhanaExternalRoute] = [
            .taskCenter(focusedItemID: "event:private id"),
            .taskCenter(focusedItemID: nil),
            .activeWalk(petID: petID),
            .settings
        ]

        for route in routes {
            #expect(OhanaExternalRoute.parse(route.url) == route)
        }
        #expect(OhanaExternalRoute.parse(URL(string: "https://example.com/task-center")!) == nil)
        #expect(OhanaExternalRoute.parse(URL(string: "\(OhanaExternalRoute.scheme)://walk?pet=invalid")!) == nil)
    }

    @Test @MainActor func routeInboxRetainsAColdLaunchRequestUntilItsConsumerIsReady() throws {
        let inbox = SystemSurfaceRouteInbox()
        let route = OhanaExternalRoute.taskCenter(focusedItemID: "event:water")

        #expect(inbox.submit(route.url))
        let request = try #require(inbox.pendingRequest)
        #expect(request.route == route)

        inbox.consume(request.id)
        #expect(inbox.pendingRequest == nil)
        #expect(!inbox.submit(URL(string: "https://example.com")!))
    }

    @Test func snapshotStoreRoundTripsVersionedValueDataAndReappliesBackupExclusion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ohana-system-surface-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SystemSurfaceSnapshotStore(containerURL: directory)
        let snapshot = TodayCareWidgetSnapshot.placeholder(now: Date(timeIntervalSince1970: 1_700_000_000))

        try store.write(snapshot)

        #expect(try store.read() == snapshot)
        let snapshotURL = try #require(store.snapshotURL)
        #expect(try directory.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true)
        #expect(try snapshotURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true)

        var includedValues = URLResourceValues()
        includedValues.isExcludedFromBackup = false
        var mutableDirectory = directory
        var mutableSnapshotURL = snapshotURL
        try mutableDirectory.setResourceValues(includedValues)
        try mutableSnapshotURL.setResourceValues(includedValues)
        #expect(try directory.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == false)
        #expect(try snapshotURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == false)

        try store.write(snapshot)
        #expect(try directory.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true)
        var rewrittenSnapshotURL = try #require(store.snapshotURL)
        rewrittenSnapshotURL.removeCachedResourceValue(forKey: .isExcludedFromBackupKey)
        #expect(try rewrittenSnapshotURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true)

        try store.sanitizeForAppReset(.unavailable(languageCode: "en"))
        #expect(try store.read() == nil)
    }

    @Test func snapshotResetSanitizationRequiresWriteOrRemovalToSucceed() throws {
        try SystemSurfaceSnapshotStore.requireSuccessfulResetSanitization(
            writeSucceeded: true,
            removalSucceeded: false
        )
        try SystemSurfaceSnapshotStore.requireSuccessfulResetSanitization(
            writeSucceeded: false,
            removalSucceeded: true
        )
        try SystemSurfaceSnapshotStore.requireSuccessfulResetSanitization(
            writeSucceeded: true,
            removalSucceeded: true
        )

        #expect(throws: SystemSurfaceSnapshotStore.StoreError.resetSanitizationFailed) {
            try SystemSurfaceSnapshotStore.requireSuccessfulResetSanitization(
                writeSucceeded: false,
                removalSucceeded: false
            )
        }
    }

    @Test @MainActor func resetFencePreventsDelayedRefreshFromRewritingPersonalSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ohana-system-surface-reset-fence-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SystemSurfaceSnapshotStore(containerURL: directory)
        try store.write(.placeholder())
        let loader = DelayedSystemSurfaceSnapshotLoader()
        var reloadCount = 0
        let coordinator = SystemSurfaceSnapshotCoordinator(
            revisions: SharedDomainRevisionPublisher(center: ReadModelRevisionCenter()),
            store: store,
            debounceMilliseconds: { 0 },
            allowsSystemWidgets: { true },
            loadSnapshot: { await loader.load() },
            reloadWidget: { reloadCount += 1 }
        )

        coordinator.scheduleRefresh(reason: "beforeReset")
        await loader.waitUntilStarted()
        #expect(loader.callCount == 1)

        coordinator.prepareForAppReset()
        coordinator.scheduleRefresh(reason: "duringReset")
        try store.sanitizeForAppReset(.unavailable(languageCode: "en"))

        loader.resume(with: emptyTaskCenterSnapshot())
        await coordinator.waitForRefreshQuiescenceForTesting()

        #expect(loader.callCount == 1)
        #expect(try store.read() == nil)
        #expect(reloadCount == 0)
        coordinator.finishAppReset()
    }

    @Test func widgetProjectionIsBoundedAndDoesNotExposeFreeFormHouseholdTitles() {
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        let petID = UUID()
        let petSubject = TaskSubjectSnapshot(
            kind: .pet,
            id: petID,
            name: "Piper",
            themeColorHex: nil
        )
        let privateTitle = "Private vet billing note"
        let overdue = item(
            id: "overdue",
            title: privateTitle,
            subject: .household,
            eventType: nil,
            dueAt: now.addingTimeInterval(-600),
            urgency: .overdue
        )
        let watering = item(
            id: "watering",
            title: "Secret custom title",
            subject: petSubject,
            eventType: .watering,
            dueAt: now.addingTimeInterval(3600),
            urgency: .standard
        )
        let third = item(
            id: "third",
            title: "Another private title",
            subject: .household,
            eventType: nil,
            dueAt: now.addingTimeInterval(7200),
            urgency: .standard
        )
        let fourth = item(
            id: "fourth",
            title: "Must be clipped",
            subject: .household,
            eventType: nil,
            dueAt: now.addingTimeInterval(10800),
            urgency: .standard
        )
        let source = TaskCenterSnapshot(
            overdue: [overdue],
            today: [watering, third, fourth],
            upcoming: [],
            unscheduled: [],
            todayCompletedCount: 2,
            todayTotalCount: 5,
            memberFilterContext: .hidden,
            starterJourney: nil
        )

        let snapshot = TodayCareWidgetSnapshotBuilder.make(
            taskCenter: source,
            languageCode: "en",
            now: now
        )

        #expect(snapshot.items.count == 3)
        #expect(snapshot.items.map(\.id) == ["overdue", "watering", "third"])
        #expect(snapshot.items.allSatisfy { $0.title != privateTitle && $0.title != "Secret custom title" })
        #expect(snapshot.items[0].title == "Household task")
        #expect(snapshot.items[1].title == "Watering")
        #expect(snapshot.items[1].subjectName == "Piper")
        #expect(snapshot.completedTodayCount == 2)
        #expect(snapshot.totalTodayCount == 5)
        #expect(snapshot.overdueCount == 1)
        #expect(snapshot.nextRefreshAt == now.addingTimeInterval(3600))
    }

    @Test func widgetProjectionRefreshesAtTheMinimumWindowForAnImminentDueItem() {
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        let dueAt = now.addingTimeInterval(60)
        let source = TaskCenterSnapshot(
            overdue: [],
            today: [
                item(
                    id: "imminent",
                    title: "Private title",
                    subject: .household,
                    eventType: .watering,
                    dueAt: dueAt,
                    urgency: .standard
                )
            ],
            upcoming: [],
            unscheduled: [],
            todayCompletedCount: 0,
            todayTotalCount: 1,
            memberFilterContext: .hidden,
            starterJourney: nil
        )

        let snapshot = TodayCareWidgetSnapshotBuilder.make(
            taskCenter: source,
            languageCode: "en",
            now: now
        )

        #expect(snapshot.nextRefreshAt == now.addingTimeInterval(15 * 60))
        #expect(snapshot.isFresh(at: snapshot.nextRefreshAt.addingTimeInterval(-1)))
        #expect(!snapshot.isFresh(at: snapshot.nextRefreshAt))
    }

    @Test func widgetProjectionOmitsSensitiveHealthAndMedicationCategories() {
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        let subject = TaskSubjectSnapshot(
            kind: .pet,
            id: UUID(),
            name: "Piper",
            themeColorHex: nil
        )
        let source = TaskCenterSnapshot(
            overdue: [
                item(
                    id: "private-medication",
                    title: "Secret dose",
                    subject: subject,
                    eventType: .petMedicationDose,
                    dueAt: now.addingTimeInterval(-60),
                    urgency: .critical
                )
            ],
            today: [
                item(
                    id: "safe-water",
                    title: "Private watering note",
                    subject: subject,
                    eventType: .watering,
                    dueAt: now.addingTimeInterval(3600),
                    urgency: .standard
                )
            ],
            upcoming: [],
            unscheduled: [],
            todayCompletedCount: 0,
            todayTotalCount: 2,
            memberFilterContext: .hidden,
            starterJourney: nil
        )

        let snapshot = TodayCareWidgetSnapshotBuilder.make(
            taskCenter: source,
            languageCode: "en",
            now: now
        )

        #expect(snapshot.items.map(\.id) == ["safe-water"])
        #expect(snapshot.items.first?.title == "Watering")
        #expect(snapshot.items.first?.symbolName == EventType.watering.silhouetteSymbol)
        #expect(snapshot.overdueCount == 0)
    }

    private func item(
        id: String,
        title: String,
        subject: TaskSubjectSnapshot,
        eventType: EventType?,
        dueAt: Date,
        urgency: TaskCenterUrgency
    ) -> TaskCenterItemSnapshot {
        TaskCenterItemSnapshot(
            id: id,
            eventID: UUID(),
            reminderID: nil,
            familyTaskID: nil,
            source: .event,
            title: title,
            subject: subject,
            eventType: eventType,
            symbol: eventType?.silhouetteSymbol ?? "checkmark.circle.fill",
            occurrenceDate: dueAt,
            scheduledAt: dueAt,
            dueAt: dueAt,
            isAllDay: false,
            isRecurring: false,
            urgency: urgency,
            workflowStatus: .scheduled,
            availableActions: [.complete],
            participantHumanIDs: []
        )
    }

    private func emptyTaskCenterSnapshot() -> TaskCenterSnapshot {
        TaskCenterSnapshot(
            overdue: [],
            today: [],
            upcoming: [],
            unscheduled: [],
            todayCompletedCount: 0,
            todayTotalCount: 0,
            memberFilterContext: .hidden,
            starterJourney: nil
        )
    }
}

@MainActor
private final class DelayedSystemSurfaceSnapshotLoader {
    private var continuation: CheckedContinuation<TaskCenterSnapshot, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var didStart = false
    private(set) var callCount = 0

    func load() async -> TaskCenterSnapshot {
        callCount += 1
        didStart = true
        startWaiter?.resume()
        startWaiter = nil
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func resume(with snapshot: TaskCenterSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}
