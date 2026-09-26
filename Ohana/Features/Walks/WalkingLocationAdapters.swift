import CoreLocation
import Foundation
import SwiftData

@MainActor
protocol WalkLocationManaging: AnyObject {
    var currentLocation: CLLocation? { get }
    var collectedLocations: [CLLocation] { get }
    var totalDistance: Double { get }

    func startWalkSession()
    func stopWalkSession()
    func pauseWalkSession()
    func resumeWalkSession()
    func stopAllLocationActivity()
    func promoteActiveWalkToBackgroundDelivery()
    func returnActiveWalkToForegroundDelivery()
    func enforceNoLocationUnlessRunningWalk(_ isRunningWalk: Bool, reason: String)
    func routeLocationsForPersistence(maxCount: Int) -> [CLLocation]
    func setWalkMetricsUpdateHandler(_ handler: ((Double) -> Void)?)
}

extension WalkLocationManaging {
    func routeLocationsForPersistence() -> [CLLocation] {
        routeLocationsForPersistence(maxCount: 600)
    }

    func setWalkMetricsUpdateHandler(_: ((Double) -> Void)?) {}
}

extension LocationManager: WalkLocationManaging {}

@MainActor
protocol PetWalkingManaging: AnyObject {
    var currentPet: Pet? { get set }
    var phase: WalkPhase { get set }
    var elapsedTime: TimeInterval { get set }
    var poopCount: Int { get set }
    var showSummary: Bool { get set }
    var isWalkCardExpandedSurfaceVisible: Bool { get set }
    var lastCompletedPetId: UUID? { get }
    var lastCompletedWalk: PetWalkLog? { get }
    var lastCompletedRouteCoordinates: [CLLocationCoordinate2D] { get }
    var activePoopMarkers: [WalkPoopMarker] { get }
    var lastCompletedPoopMarkers: [WalkPoopMarker] { get }

    func start(pet: Pet)
    func start(pet: Pet, modelContext: ModelContext, executorIds: [String])
    func pause()
    func resume()
    func restore(checkpoint: PetWalkLog, modelContext: ModelContext)
    func discardRecoveryCheckpoint(_ checkpoint: PetWalkLog, modelContext: ModelContext)
    @discardableResult
    func stop(modelContext: ModelContext, sharedTargets: [Pet]) -> WalkStopRewardSummary
    func addPoop(type: PottyType)
    func reset()
}

extension PetWalkingManaging {
    func start(pet: Pet, modelContext: ModelContext) {
        start(pet: pet)
    }

    func start(pet: Pet, modelContext: ModelContext, executorIds _: [String]) {
        start(pet: pet, modelContext: modelContext)
    }

    func restore(checkpoint _: PetWalkLog, modelContext _: ModelContext) {}

    func discardRecoveryCheckpoint(_: PetWalkLog, modelContext _: ModelContext) {}

    func addPoop() {
        addPoop(type: .perfectPoop)
    }

    @discardableResult
    func stop(modelContext: ModelContext) -> WalkStopRewardSummary {
        stop(modelContext: modelContext, sharedTargets: [])
    }
}

@MainActor
final class SharedPetWalkingManager: PetWalkingManaging {
    private let manager: PetWalkingManager

    init() {
        manager = PetWalkingManager(locationManager: LocationManager())
    }

    init(manager: PetWalkingManager) {
        self.manager = manager
    }

    var currentPet: Pet? {
        get { manager.currentPet }
        set { manager.currentPet = newValue }
    }

    var phase: WalkPhase {
        get { manager.phase }
        set { manager.phase = newValue }
    }

    var elapsedTime: TimeInterval {
        get { manager.elapsedTime }
        set { manager.elapsedTime = newValue }
    }

    var poopCount: Int {
        get { manager.poopCount }
        set { manager.poopCount = newValue }
    }

    var showSummary: Bool {
        get { manager.showSummary }
        set { manager.showSummary = newValue }
    }

    var isWalkCardExpandedSurfaceVisible: Bool {
        get { manager.isWalkCardExpandedSurfaceVisible }
        set { manager.isWalkCardExpandedSurfaceVisible = newValue }
    }

    var lastCompletedPetId: UUID? {
        manager.lastCompletedPetId
    }

    var lastCompletedWalk: PetWalkLog? {
        manager.lastCompletedWalk
    }

    var lastCompletedRouteCoordinates: [CLLocationCoordinate2D] {
        manager.lastCompletedRouteCoordinates
    }

    var activePoopMarkers: [WalkPoopMarker] {
        manager.activePoopMarkers
    }

    var lastCompletedPoopMarkers: [WalkPoopMarker] {
        manager.lastCompletedPoopMarkers
    }

    func start(pet: Pet) {
        manager.start(pet: pet)
    }

    func start(pet: Pet, modelContext: ModelContext) {
        manager.start(pet: pet, modelContext: modelContext)
    }

    func start(pet: Pet, modelContext: ModelContext, executorIds: [String]) {
        manager.start(pet: pet, modelContext: modelContext, executorIds: executorIds)
    }

    func pause() {
        manager.pause()
    }

    func resume() {
        manager.resume()
    }

    func restore(checkpoint: PetWalkLog, modelContext: ModelContext) {
        manager.restore(checkpoint: checkpoint, modelContext: modelContext)
    }

    func discardRecoveryCheckpoint(_ checkpoint: PetWalkLog, modelContext: ModelContext) {
        manager.discardRecoveryCheckpoint(checkpoint, modelContext: modelContext)
    }

    @discardableResult
    func stop(modelContext: ModelContext, sharedTargets: [Pet]) -> WalkStopRewardSummary {
        manager.stop(modelContext: modelContext, sharedTargets: sharedTargets)
    }

    func addPoop(type: PottyType = .perfectPoop) {
        manager.addPoop(type: type)
    }

    func reset() {
        manager.reset()
    }
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var collectedLocations: [CLLocation] { get }
    var totalDistance: Double { get }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    )
}

extension LocationProviding {
    func requestOneShotLocation(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        requestOneShotLocation(accuracy: kCLLocationAccuracyHundredMeters, completion: completion)
    }
}

@MainActor
final class SharedLocationProvider: LocationProviding {
    private let manager: LocationManager

    init() {
        manager = LocationManager()
    }

    init(manager: LocationManager) {
        self.manager = manager
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var collectedLocations: [CLLocation] {
        manager.collectedLocations
    }

    var totalDistance: Double {
        manager.totalDistance
    }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    ) {
        manager.requestOneShotLocation(accuracy: accuracy, completion: completion)
    }
}
