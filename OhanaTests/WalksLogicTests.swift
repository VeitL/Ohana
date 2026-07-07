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

    @Test func sharedWalkTargetsKeepOnlyEligibleDogs() {
        let source = Pet(name: "Piper", species: "狗")
        let secondDog = Pet(name: "Rex", species: "dog")
        let cat = Pet(name: "Mochi", species: "猫")
        let deceasedDog = Pet(name: "Sunny", species: "dog")
        deceasedDog.passedAwayDate = Date()

        let targets = WalkFeaturePolicy.normalizedWalkTargets(
            [cat, secondDog, deceasedDog],
            fallback: source
        )

        #expect(targets.map(\.id) == [source.id, secondDog.id])
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

        #expect(cardSource.contains("var onStopWalk: ([Pet], [String]) -> WalkStopRewardSummary"))
        #expect(cardSource.contains("@State var lastStopRewardSummary: WalkStopRewardSummary?"))
        #expect(actionsSource.contains("let rewardSummary = onStopWalk(selectedWalkTargets, selectedWalkExecutorIds)"))
        #expect(actionsSource.contains("guard rewardSummary.didPersist else"))
        #expect(actionsSource.contains("lastStopRewardSummary = rewardSummary.hasReward ? rewardSummary : nil"))
        #expect(summarySource.contains("summaryRewardBadge(delta: coconutDelta)"))
        #expect(summarySource.contains("walk-tracking-summary-coconut-reward"))
        #expect(summarySource.contains("finishedCoconutDelta(for:"))
    }

    @Test func walkMapSnapshotRehydratesLogBeforeWritingAsyncImageData() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let managerSource = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Walks/PetWalkingManager.swift"),
            encoding: .utf8
        )

        #expect(managerSource.contains("let walkLogID = walkLog.id"))
        #expect(managerSource.contains("let modelContainer = modelContext.container"))
        #expect(managerSource.contains("let snapshotContext = ModelContext(modelContainer)"))
        #expect(managerSource.contains("FetchDescriptor<PetWalkLog>"))
        #expect(managerSource.contains("persistedWalkLog.mapSnapshotData = jpegData"))
        #expect(!managerSource.contains("walkLog.mapSnapshotData = jpegData"))
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

    func stop(modelContext _: ModelContext, sharedTargets _: [Pet], executorIds _: [String]) -> WalkStopRewardSummary {
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
