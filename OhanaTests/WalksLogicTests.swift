import Foundation
import MapKit
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct WalksLogicTests {
    @Test func walkEligibilityBlocksNonDogAndDeceasedPets() {
        let dog = Pet(name: "Piper", species: "狗")
        let cat = Pet(name: "Mochi", species: "猫")
        let deceasedDog = Pet(name: "Sunny", species: "dog")
        deceasedDog.passedAwayDate = Date()

        #expect(WalkFeaturePolicy.canStartWalk(for: dog))
        #expect(!WalkFeaturePolicy.canStartWalk(for: cat))
        #expect(!WalkFeaturePolicy.canStartWalk(for: deceasedDog))
    }

    @Test func sharedWalkTargetsRejectTheWholeSelectionWhenAnyTargetIsIneligible() {
        let source = Pet(name: "Piper", species: "狗")
        let secondDog = Pet(name: "Rex", species: "dog")
        let cat = Pet(name: "Mochi", species: "猫")
        let deceasedDog = Pet(name: "Sunny", species: "dog")
        deceasedDog.passedAwayDate = Date()

        let targets = WalkFeaturePolicy.normalizedWalkTargets(
            [cat, secondDog, deceasedDog],
            fallback: source
        )

        #expect(targets.isEmpty)
    }

    @Test func stoppingSharedWalkWithAnIneligibleTargetPersistsNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = Pet(name: "Piper", species: "狗")
        let ineligible = Pet(name: "Mochi", species: "猫")
        context.insert(source)
        context.insert(ineligible)
        try context.save()

        let location = FakeWalkLocationManager()
        location.totalDistance = 120
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())
        manager.start(pet: source)

        let result = manager.stop(
            modelContext: context,
            sharedTargets: [source, ineligible]
        )

        #expect(result == .invalidTargets)
        #expect(!result.didPersist)
        #expect(manager.currentPet?.id == source.id)
        #expect(manager.phase == .running)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func trackingSnapshotUsesPersistedWalksAndPoopMarkers() {
        let pet = Pet(name: "Piper", species: "狗")
        let activeWalk = PetWalkLog(startDate: Date().addingTimeInterval(-600), pet: pet)
        activeWalk.distanceMeters = 1200
        let activePotty = PetPottyLog(
            date: Date().addingTimeInterval(-580),
            type: .perfectPoop,
            pet: pet,
            walkLogId: activeWalk.id.uuidString
        )
        pet.walkLogs = [activeWalk]
        pet.pottyLogs = [activePotty]

        let snapshot = WalkTrackingSnapshot.make(pet: pet, manager: FakeWalkManager())

        #expect(snapshot.latestWalk?.id == activeWalk.id)
        #expect(snapshot.latestPoopMarkers.map(\.id) == [activePotty.id])
        #expect(abs(snapshot.thisWeekDistanceKm - 1.2) < 0.001)
    }

    @Test func walkSummaryBackFaceSurfacesStopCoconutReward() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let cardSource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/Views/WalkTrackingCard.swift"),
            encoding: .utf8
        )
        let actionsSource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/Views/WalkTrackingCard+Actions.swift"),
            encoding: .utf8
        )
        let summarySource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/Views/WalkTrackingCard+SummaryFace.swift"),
            encoding: .utf8
        )

        #expect(cardSource.contains("var onStopWalk: ([Pet]) -> WalkStopRewardSummary"))
        #expect(cardSource.contains("@State var lastStopRewardSummary: WalkStopRewardSummary?"))
        #expect(actionsSource.contains("guard !targets.isEmpty else"))
        #expect(actionsSource.contains("let rewardSummary = onStopWalk(targets)"))
        #expect(actionsSource.contains("guard rewardSummary.didPersist else"))
        let persistenceGuard = try #require(actionsSource.range(of: "guard rewardSummary.didPersist else"))
        let selectionWrite = try #require(actionsSource.range(of: "SharedPetSelectionMemory.saveSelection("))
        #expect(persistenceGuard.lowerBound < selectionWrite.lowerBound)
        #expect(actionsSource.contains("lastStopRewardSummary = rewardSummary.hasReward ? rewardSummary : nil"))
        #expect(summarySource.contains("summaryRewardBadge(delta: coconutDelta)"))
        #expect(summarySource.contains("walk-tracking-summary-coconut-reward"))
        #expect(summarySource.contains("finishedCoconutDelta(for:"))
    }

    @Test func walkMapSnapshotUsesBoundedCancellableBackgroundPersistence() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let managerSource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/PetWalkingManager.swift"),
            encoding: .utf8
        )
        let workSource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/WalkMapSnapshotWork.swift"),
            encoding: .utf8
        )

        #expect(managerSource.contains("WalkMapSnapshotPointCursor.sample"))
        #expect(managerSource.contains("WalkMapSnapshotMarkerCursor.sample"))
        #expect(managerSource.contains("mapSnapshotTask?.cancel()"))
        #expect(managerSource.contains("WalkMapSnapshotPersistenceActor"))
        #expect(managerSource.contains("let modelContainer = modelContext.container"))
        #expect(managerSource.contains("deadline: snapshotDeadline"))
        #expect(managerSource.contains("defer {"))
        #expect(workSource.contains("@ModelActor"))
        #expect(workSource.contains("withTaskCancellationHandler"))
        #expect(workSource.contains("routeCursorStride"))
        #expect(workSource.contains("poopMarkerCursorStride"))
        #expect(workSource.contains("maximumPointCount"))
        #expect(workSource.contains("maximumMarkerCount"))
        #expect(workSource.contains("let deadlineTask = Task"))
        #expect(workSource.contains("operation.cancelSnapshotterIfInstalled()"))
        #expect(workSource.contains("guard Date() < deadline else { throw CancellationError() }"))
        #expect(workSource.contains("modelContext.safeSaveResult"))
    }

    @Test func walkMapSnapshotPointCursorBoundsDenseRouteAndKeepsEndpoints() {
        let locations = (0 ..< 600).map { index in
            CLLocation(latitude: 37 + Double(index) * 0.0001, longitude: -122 - Double(index) * 0.0001)
        }

        let sample = WalkMapSnapshotPointCursor.sample(
            locations: locations,
            maximumPointCount: 64
        )

        #expect(sample.points.count <= 64)
        #expect(sample.stride > 1)
        #expect(sample.points.first == WalkMapSnapshotPoint(locations[0]))
        #expect(sample.points.last == WalkMapSnapshotPoint(locations[locations.count - 1]))
    }

    @Test func walkMapSnapshotMarkerCursorBoundsDenseMarkersAndKeepsEndpoints() {
        let markers = (0 ..< 80).map { index in
            WalkMapSnapshotMarker(
                latitude: 37 + Double(index) * 0.0001,
                longitude: -122 - Double(index) * 0.0001
            )
        }

        let sample = WalkMapSnapshotMarkerCursor.sample(
            markers: markers,
            maximumMarkerCount: 8
        )

        #expect(sample.markers.count <= 8)
        #expect(sample.stride > 1)
        #expect(sample.markers.first == markers.first)
        #expect(sample.markers.last == markers.last)
    }

    @Test func walkMapSnapshotQualityShrinksRouteAndMarkerBudgetsInReducedMode() {
        #expect(WalkMapSnapshotQuality.standard.maximumRoutePointCount == 240)
        #expect(WalkMapSnapshotQuality.reduced.maximumRoutePointCount == 64)
        #expect(WalkMapSnapshotQuality.standard.maximumMarkerCount == 24)
        #expect(WalkMapSnapshotQuality.reduced.maximumMarkerCount == 8)
    }

    @Test func managerStartNoOpsForIneligiblePetsBeforeStartingLocation() {
        let location = FakeWalkLocationManager()
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())
        let cat = Pet(name: "Mochi", species: "猫")
        let deceasedDog = Pet(name: "Rex", species: "狗")
        deceasedDog.passedAwayDate = Date()

        manager.start(pet: cat)
        manager.start(pet: deceasedDog)

        #expect(manager.currentPet == nil)
        #expect(manager.phase == .idle)
        #expect(location.startWalkSessionCount == 0)
    }

    @Test func startingWalkWithContextPersistsRecoveryCheckpoint() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Piper", species: "狗")
        context.insert(pet)
        try context.save()

        let location = FakeWalkLocationManager()
        location.totalDistance = 42
        location.currentLocation = CLLocation(latitude: 37.1, longitude: -122.1)
        location.collectedLocations = [
            CLLocation(latitude: 37.0, longitude: -122.0),
            CLLocation(latitude: 37.1, longitude: -122.1)
        ]
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())

        manager.start(pet: pet, modelContext: context)
        manager.addPoop(type: .perfectPoop)

        let checkpoints = try context.fetch(FetchDescriptor<PetWalkLog>())
            .filter(WalkRecoveryCheckpoint.isRecoverable)
        let checkpoint = try #require(checkpoints.first)
        let metadata = try #require(WalkRecoveryCheckpoint.decodeMetadata(from: checkpoint))

        #expect(checkpoints.count == 1)
        #expect(checkpoint.pet?.id == pet.id)
        #expect(checkpoint.distanceMeters == 42)
        #expect(checkpoint.routeLocationsData != nil)
        #expect(metadata.poopMarkers.count == 1)
        #expect(location.startWalkSessionCount == 1)
    }

    @Test func stoppingWalkDeletesRecoveryCheckpointAndKeepsOneAuthoritativeWalkLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Piper", species: "狗")
        context.insert(pet)
        try context.save()

        let location = FakeWalkLocationManager()
        location.totalDistance = 80
        location.collectedLocations = [
            CLLocation(latitude: 37.0, longitude: -122.0),
            CLLocation(latitude: 37.1, longitude: -122.1)
        ]
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())

        manager.start(pet: pet, modelContext: context)
        manager.stop(modelContext: context)

        let logs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let checkpoints = logs.filter(WalkRecoveryCheckpoint.isCheckpoint)
        let authoritativeLogs = logs.filter { !WalkRecoveryCheckpoint.isCheckpoint($0) }

        #expect(checkpoints.isEmpty)
        #expect(authoritativeLogs.count == 1)
        #expect(authoritativeLogs.first?.distanceMeters == 80)
    }

    @Test func restoredWalkMergesCheckpointRouteAndNewRouteOnStop() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Piper", species: "狗")
        let checkpoint = PetWalkLog(
            startDate: Date().addingTimeInterval(-240),
            pet: pet,
            sharedSessionId: WalkRecoveryCheckpoint.makeSharedSessionID()
        )
        checkpoint.distanceMeters = 120
        checkpoint.routeLocationsData = routeData([
            CLLocation(latitude: 37.0, longitude: -122.0),
            CLLocation(latitude: 37.1, longitude: -122.1)
        ])
        checkpoint.behaviorNotes = WalkRecoveryCheckpoint.encodeMetadata(
            WalkRecoveryCheckpoint.metadata(
                elapsedTime: 180,
                poopMarkers: [WalkPoopMarker(date: Date().addingTimeInterval(-120), location: nil)]
            )
        )
        context.insert(pet)
        context.insert(checkpoint)
        try context.save()

        let location = FakeWalkLocationManager()
        location.totalDistance = 40
        location.collectedLocations = [
            CLLocation(latitude: 37.1, longitude: -122.1),
            CLLocation(latitude: 37.2, longitude: -122.2)
        ]
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())

        manager.restore(checkpoint: checkpoint, modelContext: context)
        manager.resume()
        manager.stop(modelContext: context)

        let logs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let authoritativeWalk = try #require(logs.first { !WalkRecoveryCheckpoint.isCheckpoint($0) })
        let coordinates = try #require(routeCoordinates(from: authoritativeWalk.routeLocationsData))
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())

        #expect(logs.filter(WalkRecoveryCheckpoint.isCheckpoint).isEmpty)
        #expect(authoritativeWalk.distanceMeters == 160)
        #expect(coordinates.count == 3)
        #expect(pottyLogs.count == 1)
        #expect(location.startWalkSessionCount == 1)
    }

    @Test func recoveryCheckpointsDoNotCountAsFeatureCollectionWalksOrTodayFocusCompletion() {
        let now = Date()
        let pet = Pet(name: "Piper", species: "狗")
        let authoritativeWalk = PetWalkLog(startDate: now, pet: pet)
        authoritativeWalk.distanceMeters = 120
        let checkpoint = PetWalkLog(
            startDate: now,
            pet: pet,
            sharedSessionId: WalkRecoveryCheckpoint.makeSharedSessionID()
        )
        checkpoint.distanceMeters = 900
        pet.walkLogs = [authoritativeWalk, checkpoint]

        let summary = PetFeatureCollectionSummary.load(
            pets: [pet],
            humans: [],
            petAggregateSummaries: [:]
        )

        #expect(summary.todayWalkCount == 1)
        #expect(summary.todayWalkDistanceMeters == 120)

        let walkQuest = IslandQuest(
            id: "q_walk_\(pet.id.uuidString)",
            emoji: "walk",
            title: "Walk",
            subtitle: "",
            isCompleted: false,
            targetPetId: pet.id,
            targetPlantId: nil
        )
        let checkpointOnly = TodayFocusService.refreshedQuests(
            [walkQuest],
            pets: [pet],
            careLogs: [],
            walkLogs: [checkpoint],
            pottyLogs: [],
            now: now
        )
        let authoritative = TodayFocusService.refreshedQuests(
            [walkQuest],
            pets: [pet],
            careLogs: [],
            walkLogs: [authoritativeWalk],
            pottyLogs: [],
            now: now
        )

        #expect(checkpointOnly.first?.isCompleted == false)
        #expect(authoritative.first?.isCompleted == true)
    }

    @Test func homeWalkQuickActionRevealsActiveWalkInsteadOfStartingAnotherSession() {
        let requestedPetID = UUID()
        let otherPetID = UUID()

        #expect(
            HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
                requestedPetID: requestedPetID,
                currentPetID: requestedPetID,
                phase: .running
            ) == .embeddedCurrentPet
        )
        #expect(
            HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
                requestedPetID: requestedPetID,
                currentPetID: requestedPetID,
                phase: .paused
            ) == .embeddedCurrentPet
        )
        #expect(
            HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
                requestedPetID: requestedPetID,
                currentPetID: otherPetID,
                phase: .running
            ) == .floatingOtherPet
        )
        #expect(
            HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
                requestedPetID: requestedPetID,
                currentPetID: requestedPetID,
                phase: .idle
            ) == nil
        )
        #expect(
            HomeWalkQuickActionPresentationPolicy.existingWalkDisposition(
                requestedPetID: requestedPetID,
                currentPetID: requestedPetID,
                phase: .finished(elapsed: 12, poopCount: 0)
            ) == nil
        )
    }

    @Test func pausedWalkUsesStaticPausedRoutePresentation() {
        #expect(WalkTrackingMapPresentationPolicy.routeVisualStyle(for: .running) == .active)
        #expect(WalkTrackingMapPresentationPolicy.routeVisualStyle(for: .paused) == .paused)
        #expect(WalkTrackingMapPresentationPolicy.allowsRainbowRoute(phase: .running, isRainbowEquipped: true))
        #expect(!WalkTrackingMapPresentationPolicy.allowsRainbowRoute(phase: .paused, isRainbowEquipped: true))
        #expect(WalkTrackingMapPresentationPolicy.allowsRouteFlow(phase: .running, shouldAnimate: true))
        #expect(!WalkTrackingMapPresentationPolicy.allowsRouteFlow(phase: .paused, shouldAnimate: true))
    }

    @Test func stoppingWalkWithPoopPersistsPottyLedgerForExecutor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Mia")
        let pet = Pet(name: "Piper", species: "狗")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let location = FakeWalkLocationManager()
        let manager = PetWalkingManager(locationManager: location, questManager: QuestManager())
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defer { UserDefaults.standard.removeObject(forKey: "currentActiveHumanId") }

        manager.start(pet: pet)
        manager.addPoop(type: .perfectPoop)
        manager.stop(modelContext: context)

        let pottyLog = try #require(try context.fetch(FetchDescriptor<PetPottyLog>()).first)
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(pottyLog.executorId == human.id.uuidString)
        #expect(pottyLog.walkLogId != nil)
        #expect(ledgerEvents.contains { event in
            event.eventKind == CareLedgerEventKind.potty.rawValue &&
                event.legacyModelName == String(describing: PetPottyLog.self) &&
                event.legacyModelId == pottyLog.id.uuidString &&
                event.actorId == human.id.uuidString
        })
    }

    @Test func defaultWalkExecutorIsCapturedAtStartInsteadOfRereadAtStop() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Human(name: "First walker")
        let second = Human(name: "Second walker")
        let pet = Pet(name: "Piper", species: "狗")
        context.insert(first)
        context.insert(second)
        context.insert(pet)
        try context.save()

        let selection = MutableWalkActiveHumanSelection(id: first.id.uuidString)
        let manager = PetWalkingManager(
            locationManager: FakeWalkLocationManager(),
            questManager: QuestManager(),
            activeHumanSelection: selection
        )

        manager.start(pet: pet)
        selection.id = second.id.uuidString
        manager.stop(modelContext: context)

        let walk = try #require(try context.fetch(FetchDescriptor<PetWalkLog>()).first)
        #expect(walk.executorId == first.id.uuidString)
        #expect(walk.executorIds == [first.id.uuidString])
    }

    @Test func explicitWalkParticipantsAreCapturedAtStartAndPersistedInOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Human(name: "First walker")
        let second = Human(name: "Second walker")
        let laterSelection = Human(name: "Later selection")
        let pet = Pet(name: "Piper", species: "狗")
        [first, second, laterSelection].forEach(context.insert)
        context.insert(pet)
        try context.save()

        let manager = PetWalkingManager(
            locationManager: FakeWalkLocationManager(),
            questManager: QuestManager(),
            activeHumanSelection: MutableWalkActiveHumanSelection(id: laterSelection.id.uuidString)
        )
        let capturedIDs = [first.id.uuidString, second.id.uuidString]

        manager.start(pet: pet, modelContext: context, executorIds: capturedIDs)
        let checkpoint = try #require(
            try context.fetch(FetchDescriptor<PetWalkLog>()).first(where: WalkRecoveryCheckpoint.isCheckpoint)
        )
        #expect(checkpoint.executorIds == capturedIDs)

        manager.stop(modelContext: context)

        let walks = try context.fetch(FetchDescriptor<PetWalkLog>())
            .filter { !WalkRecoveryCheckpoint.isCheckpoint($0) }
        let walk = try #require(walks.first)
        #expect(walk.executorId == first.id.uuidString)
        #expect(walk.executorIds == capturedIDs)
    }

    @Test func restoredWalkKeepsCheckpointParticipantsAndExplicitEmptyStartStaysUnattributed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = Human(name: "First walker")
        let second = Human(name: "Second walker")
        let pet = Pet(name: "Piper", species: "狗")
        let capturedIDs = [first.id.uuidString, second.id.uuidString]
        let checkpoint = PetWalkLog(
            startDate: Date().addingTimeInterval(-120),
            pet: pet,
            executorId: capturedIDs.first,
            executorIds: capturedIDs,
            sharedSessionId: WalkRecoveryCheckpoint.makeSharedSessionID()
        )
        checkpoint.behaviorNotes = WalkRecoveryCheckpoint.encodeMetadata(
            WalkRecoveryCheckpoint.metadata(elapsedTime: 90, poopMarkers: [])
        )
        context.insert(first)
        context.insert(second)
        context.insert(pet)
        context.insert(checkpoint)
        try context.save()

        let manager = PetWalkingManager(
            locationManager: FakeWalkLocationManager(),
            questManager: QuestManager(),
            activeHumanSelection: MutableWalkActiveHumanSelection(id: UUID().uuidString)
        )
        manager.restore(checkpoint: checkpoint, modelContext: context)
        #expect(manager.activeWalkExecutorIds == capturedIDs)

        manager.stop(modelContext: context)
        let restoredWalk = try #require(
            try context.fetch(FetchDescriptor<PetWalkLog>()).first { !WalkRecoveryCheckpoint.isCheckpoint($0) }
        )
        #expect(restoredWalk.executorIds == capturedIDs)

        let unattributedPet = Pet(name: "Rex", species: "狗")
        context.insert(unattributedPet)
        try context.save()
        let unattributedManager = PetWalkingManager(
            locationManager: FakeWalkLocationManager(),
            questManager: QuestManager(),
            activeHumanSelection: MutableWalkActiveHumanSelection(id: first.id.uuidString)
        )
        unattributedManager.start(pet: unattributedPet, modelContext: context, executorIds: [])
        unattributedManager.stop(modelContext: context)

        let unattributedWalk = try #require(
            try context.fetch(FetchDescriptor<PetWalkLog>()).first { $0.pet?.id == unattributedPet.id }
        )
        #expect(unattributedWalk.executorId == nil)
        #expect(unattributedWalk.executorIds.isEmpty)
    }
}

private final class FakeWalkManager: PetWalkingManaging {
    var currentPet: Pet?
    var phase: WalkPhase = .idle
    var elapsedTime: TimeInterval = 0
    var poopCount: Int = 0
    var showSummary = false
    var isWalkCardExpandedSurfaceVisible = false
    var lastCompletedPetId: UUID?
    var lastCompletedWalk: PetWalkLog?
    var lastCompletedRouteCoordinates: [CLLocationCoordinate2D] = []
    var activePoopMarkers: [WalkPoopMarker] = []
    var lastCompletedPoopMarkers: [WalkPoopMarker] = []

    func start(pet: Pet) {
        currentPet = pet
        phase = .running
    }

    func pause() {
        phase = .paused
    }

    func resume() {
        phase = .running
    }

    func stop(modelContext _: ModelContext, sharedTargets _: [Pet]) -> WalkStopRewardSummary {
        phase = .finished(elapsed: elapsedTime, poopCount: poopCount)
        return .empty
    }

    func addPoop(type: PottyType) {
        poopCount += 1
        activePoopMarkers.append(WalkPoopMarker(date: Date(), location: nil, type: type))
    }

    func reset() {
        currentPet = nil
        phase = .idle
    }
}

private final class FakeWalkLocationManager: WalkLocationManaging {
    var currentLocation: CLLocation?
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0
    private(set) var startWalkSessionCount = 0

    func startWalkSession() {
        startWalkSessionCount += 1
    }

    func stopWalkSession() {}
    func pauseWalkSession() {}
    func resumeWalkSession() {}
    func stopAllLocationActivity() {}
    func promoteActiveWalkToBackgroundDelivery() {}
    func returnActiveWalkToForegroundDelivery() {}
    func enforceNoLocationUnlessRunningWalk(_: Bool, reason _: String) {}
    func routeLocationsForPersistence(maxCount _: Int) -> [CLLocation] { collectedLocations }
}

private final nonisolated class MutableWalkActiveHumanSelection: ActiveHumanSelecting {
    var id: String?

    init(id: String?) {
        self.id = id
    }

    var currentHumanId: String? { id }
    var currentHumanIdRaw: String { id ?? "" }
}

private func makeContainer() throws -> ModelContainer {
    let schema = Schema(ArkSchemaV71.models)
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [config])
}

private func routeData(_ locations: [CLLocation]) -> Data? {
    let coordinates = locations.map {
        ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude]
    }
    return try? JSONSerialization.data(withJSONObject: coordinates)
}

private func routeCoordinates(from data: Data?) -> [[String: Double]]? {
    guard let data else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
}
