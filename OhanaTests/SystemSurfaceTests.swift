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

    @Test func snapshotStoreRoundTripsVersionedValueData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ohana-system-surface-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SystemSurfaceSnapshotStore(containerURL: directory)
        let snapshot = TodayCareWidgetSnapshot.placeholder(now: Date(timeIntervalSince1970: 1_700_000_000))

        try store.write(snapshot)

        #expect(try store.read() == snapshot)
        try store.removeSnapshotIfPresent()
        #expect(try store.read() == nil)
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
}
