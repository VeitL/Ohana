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

    func stop(modelContext _: ModelContext, sharedTargets _: [Pet], executorIds _: [String]) {
        phase = .finished(elapsed: elapsedTime, poopCount: poopCount)
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
