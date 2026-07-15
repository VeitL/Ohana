//
//  PetWalkingManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import MapKit
import Observation
import SwiftData
import UIKit

enum WalkPhase: Equatable {
    case idle
    case running
    case paused
    case finished(elapsed: TimeInterval, poopCount: Int)
}

struct WalkStopRewardSummary: Equatable {
    let walkLogID: UUID?
    let coconutDelta: Int
    let walkCoconutDelta: Int
    let pottyCoconutDelta: Int
    let didPersist: Bool
    let persistenceErrorDescription: String?

    static let empty = WalkStopRewardSummary(
        walkLogID: nil,
        coconutDelta: 0,
        walkCoconutDelta: 0,
        pottyCoconutDelta: 0,
        didPersist: true,
        persistenceErrorDescription: nil
    )

    static let invalidTargets = WalkStopRewardSummary(
        walkLogID: nil,
        coconutDelta: 0,
        walkCoconutDelta: 0,
        pottyCoconutDelta: 0,
        didPersist: false,
        persistenceErrorDescription: nil
    )

    static func failed(_ errorDescription: String?) -> WalkStopRewardSummary {
        WalkStopRewardSummary(
            walkLogID: nil,
            coconutDelta: 0,
            walkCoconutDelta: 0,
            pottyCoconutDelta: 0,
            didPersist: false,
            persistenceErrorDescription: errorDescription
        )
    }

    var hasReward: Bool {
        didPersist && coconutDelta > 0
    }
}

struct WalkPoopMarker: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let latitude: Double?
    let longitude: Double?
    let accuracyMeters: Double?
    let type: PottyType

    init(id: UUID = UUID(), date: Date = Date(), location: CLLocation?, type: PottyType = .perfectPoop) {
        self.id = id
        self.date = date
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.accuracyMeters = location?.horizontalAccuracy
        self.type = type
    }

    nonisolated init(
        id: UUID,
        date: Date,
        latitude: Double?,
        longitude: Double?,
        accuracyMeters: Double?,
        type: PottyType
    ) {
        self.id = id
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.type = type
    }

    init(log: PetPottyLog) {
        self.id = log.id
        self.date = log.date
        self.latitude = log.latitude
        self.longitude = log.longitude
        self.accuracyMeters = log.locationAccuracyMeters
        self.type = log.pottyType
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct WalkStopDraft {
    let pet: Pet
    let targets: [Pet]
    let elapsed: TimeInterval
    let poopCount: Int
    let poopMarkers: [WalkPoopMarker]
    let executorIds: [String]
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double
    let routeLocations: [CLLocation]
    let routeCoordinates: [CLLocationCoordinate2D]
    let routeData: Data?
    let isTooShortForReward: Bool

    var executorId: String? {
        executorIds.first
    }
}

private struct WalkStopWalkRecord {
    let logs: [PetWalkLog]
    let sourceLog: PetWalkLog?
    let coconutDelta: Int
}

private struct WalkStopPottyRecord {
    let logs: [PetPottyLog]
    let coconutDelta: Int
}

@MainActor
@Observable
final class PetWalkingManager {
    var currentPet: Pet?
    var phase: WalkPhase = .idle
    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var poopCount: Int = 0
    var showSummary: Bool = false
    var isWalkCardExpandedSurfaceVisible: Bool = false
    var lastCompletedPetId: UUID?
    var lastCompletedWalk: PetWalkLog?
    var lastCompletedRouteCoordinates: [CLLocationCoordinate2D] = []
    var activePoopMarkers: [WalkPoopMarker] = []
    var lastCompletedPoopMarkers: [WalkPoopMarker] = []
    private(set) var activeWalkExecutorIds: [String] = []

    private var pausedElapsed: TimeInterval = 0 // 暂停前已累计时间
    private var resumeTime: Date? // 最近一次 resume/start 时间
    private var timer: Timer?
    private var activeRecoveryCheckpointID: UUID?
    private var activeWalkModelContext: ModelContext?
    private var lastRecoveryCheckpointAt: Date?
    private var recoveredRouteLocations: [CLLocation] = []
    private var recoveredDistanceMeters: Double = 0
    private var restoredCheckpointNeedsLocationStart = false
    private var walkStopStartedAt: CFAbsoluteTime?
    private var mapSnapshotTask: Task<Void, Never>?
    private var mapSnapshotGeneration = 0
    private let locationManager: any WalkLocationManaging
    private let questManager: QuestManager
    private let careEconomy: CareEventEconomyAwarding
    private let careLedger: CareLedgerRecording
    private let walkCareEvents: WalkCareEventManaging
    private let revisions: DomainRevisionPublishing
    private let activeHumanSelection: ActiveHumanSelecting

    init(
        locationManager: any WalkLocationManaging,
        questManager: QuestManager,
        careEconomy: CareEventEconomyAwarding? = nil,
        careLedger: CareLedgerRecording = CareLedgerService(),
        walkCareEvents: WalkCareEventManaging? = nil,
        revisions: DomainRevisionPublishing? = nil,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    ) {
        self.locationManager = locationManager
        self.questManager = questManager
        self.careEconomy = careEconomy ?? StaticCareEventEconomyAwarder(questManager: questManager)
        self.careLedger = careLedger
        self.walkCareEvents = walkCareEvents ?? StaticWalkCareEventManager()
        self.revisions = revisions ?? SharedDomainRevisionPublisher()
        self.activeHumanSelection = activeHumanSelection
    }

    convenience init(locationManager: any WalkLocationManaging) {
        self.init(locationManager: locationManager, questManager: QuestManager())
    }

    var hasActiveLocationWalk: Bool {
        guard case .running = phase else { return false }
        return currentPet != nil && startTime != nil
    }

    // MARK: - Actions
    func start(pet: Pet) {
        start(
            pet: pet,
            modelContext: nil,
            executorIds: SharedCareParticipantIDs.normalized([], preferredFirst: activeHumanSelection.currentHumanId)
        )
    }

    func start(pet: Pet, modelContext: ModelContext?) {
        start(
            pet: pet,
            modelContext: modelContext,
            executorIds: SharedCareParticipantIDs.normalized([], preferredFirst: activeHumanSelection.currentHumanId)
        )
    }

    func start(pet: Pet, modelContext: ModelContext?, executorIds: [String]) {
        guard WalkFeaturePolicy.canStartWalk(for: pet) else { return }

        activeWalkExecutorIds = SharedCareParticipantIDs.normalized(executorIds)
        currentPet = pet
        phase = .running
        startTime = Date()
        elapsedTime = 0
        pausedElapsed = 0
        resumeTime = Date()
        poopCount = 0
        showSummary = false
        isWalkCardExpandedSurfaceVisible = false
        lastCompletedPetId = nil
        lastCompletedWalk = nil
        lastCompletedRouteCoordinates = []
        activePoopMarkers = []
        lastCompletedPoopMarkers = []
        activeWalkModelContext = modelContext
        activeRecoveryCheckpointID = nil
        lastRecoveryCheckpointAt = nil
        recoveredRouteLocations = []
        recoveredDistanceMeters = 0
        restoredCheckpointNeedsLocationStart = false

        AppFlowPerformance.start(AppPerformanceFlows.walkSession, note: ["action": "start"])
        createRecoveryCheckpointIfPossible(modelContext: modelContext, pet: pet)
        locationManager.startWalkSession()
        startTimer()
    }

    func restore(checkpoint: PetWalkLog, modelContext: ModelContext) {
        guard WalkRecoveryCheckpoint.isRecoverable(checkpoint),
              let pet = checkpoint.pet,
              WalkFeaturePolicy.canStartWalk(for: pet)
        else { return }

        let metadata = WalkRecoveryCheckpoint.decodeMetadata(from: checkpoint)
        currentPet = pet
        phase = .paused
        startTime = checkpoint.startDate
        elapsedTime = metadata?.elapsedSeconds ?? max(0, Date().timeIntervalSince(checkpoint.startDate))
        pausedElapsed = elapsedTime
        resumeTime = nil
        poopCount = metadata?.poopMarkers.count ?? 0
        showSummary = false
        isWalkCardExpandedSurfaceVisible = true
        lastCompletedPetId = nil
        lastCompletedWalk = nil
        lastCompletedRouteCoordinates = []
        activePoopMarkers = metadata?.poopMarkers.map(WalkPoopMarker.init(checkpoint:)) ?? []
        lastCompletedPoopMarkers = []
        activeWalkExecutorIds = checkpoint.executorIds
        activeRecoveryCheckpointID = checkpoint.id
        activeWalkModelContext = modelContext
        lastRecoveryCheckpointAt = Date()
        recoveredRouteLocations = routeLocations(from: checkpoint.routeLocationsData)
        recoveredDistanceMeters = max(0, checkpoint.distanceMeters)
        restoredCheckpointNeedsLocationStart = true

        locationManager.stopAllLocationActivity()
        checkpointActiveWalk(reason: "restore", force: true)
    }

    func discardRecoveryCheckpoint(_ checkpoint: PetWalkLog, modelContext: ModelContext) {
        guard WalkRecoveryCheckpoint.isCheckpoint(checkpoint) else { return }
        modelContext.delete(checkpoint) // derived-state: allow recovery checkpoint cleanup; checkpoint is not a care fact and has no reward/reminder cascade
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            return
        }
        if activeRecoveryCheckpointID == checkpoint.id {
            activeRecoveryCheckpointID = nil
            activeWalkModelContext = nil
            lastRecoveryCheckpointAt = nil
            recoveredRouteLocations = []
            recoveredDistanceMeters = 0
            restoredCheckpointNeedsLocationStart = false
        }
    }

    func pause() {
        // 暂停前把已跑时间存起来
        if let r = resumeTime {
            pausedElapsed += Date().timeIntervalSince(r)
        }
        resumeTime = nil
        phase = .paused
        AppFlowPerformance.mark(
            AppPerformanceFlows.walkSession,
            AppPerformancePhases.sessionPaused,
            note: walkSessionProbeNote(action: "pause")
        )
        checkpointActiveWalk(reason: "pause", force: true)
        locationManager.pauseWalkSession()
        stopTimer()
    }

    func resume() {
        resumeTime = Date()
        phase = .running
        AppFlowPerformance.mark(
            AppPerformanceFlows.walkSession,
            AppPerformancePhases.sessionResumed,
            note: walkSessionProbeNote(action: "resume")
        )
        if restoredCheckpointNeedsLocationStart {
            locationManager.startWalkSession()
            restoredCheckpointNeedsLocationStart = false
        } else {
            locationManager.resumeWalkSession()
        }
        checkpointActiveWalk(reason: "resume", force: true)
        startTimer()
    }

    @discardableResult
    func stop(modelContext: ModelContext, sharedTargets: [Pet] = []) -> WalkStopRewardSummary {
        walkStopStartedAt = CFAbsoluteTimeGetCurrent()
        guard let pet = currentPet, WalkFeaturePolicy.canStartWalk(for: pet) else {
            return finishInvalidStop(resetSession: true, result: .empty)
        }
        let normalizedTargets = WalkFeaturePolicy.normalizedWalkTargets(sharedTargets, fallback: pet)
        guard !normalizedTargets.isEmpty else {
            return finishInvalidStop(resetSession: false, result: .invalidTargets)
        }

        let draft = makeStopDraft(pet: pet, targets: normalizedTargets)
        guard let walkRecord = recordWalk(draft, modelContext: modelContext) else {
            return finishInvalidStop(resetSession: true, result: .empty)
        }
        let pottyRecord = recordPottyEvents(
            draft,
            sourceWalkLog: walkRecord.sourceLog,
            modelContext: modelContext
        )
        return persistStop(
            draft,
            walkRecord: walkRecord,
            pottyRecord: pottyRecord,
            modelContext: modelContext
        )
    }

    private func publishWalkCompletion(
        petID: UUID,
        targets: [Pet],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        endedAt: Date
    ) {
        var affectedEntityIDs = Set(targets.map(\.id))
        affectedEntityIDs.formUnion(walkLogs.map(\.id))
        affectedEntityIDs.formUnion(pottyLogs.map(\.id))
        revisions.publish(
            DomainMutationResult(
                command: .petWalkCompletion(petID: petID),
                affectedEntityIDs: affectedEntityIDs,
                wroteBusinessFact: true,
                occurredAt: endedAt,
                note: "walk.stop"
            )
        )
    }

    func reset() {
        mapSnapshotTask?.cancel()
        mapSnapshotTask = nil
        mapSnapshotGeneration &+= 1
        stopTimer()
        locationManager.stopAllLocationActivity()
        phase = .idle
        currentPet = nil
        startTime = nil
        elapsedTime = 0
        pausedElapsed = 0
        resumeTime = nil
        poopCount = 0
        showSummary = false
        isWalkCardExpandedSurfaceVisible = false
        lastCompletedPetId = nil
        lastCompletedWalk = nil
        lastCompletedRouteCoordinates = []
        activePoopMarkers = []
        lastCompletedPoopMarkers = []
        activeWalkExecutorIds = []
        activeRecoveryCheckpointID = nil
        activeWalkModelContext = nil
        lastRecoveryCheckpointAt = nil
        recoveredRouteLocations = []
        recoveredDistanceMeters = 0
        restoredCheckpointNeedsLocationStart = false
    }

    func pauseForAppBackground() {
        // Used only when the app is terminating or when background route delivery
        // is unavailable. Normal background/lock-screen transitions keep a
        // running walk alive and only stop the UI timer.
        if case .running = phase {
            if let r = resumeTime {
                pausedElapsed += Date().timeIntervalSince(r)
                elapsedTime = pausedElapsed
            }
            resumeTime = nil
            phase = .paused
            checkpointActiveWalk(reason: "backgroundPause", force: true)
            stopTimer()
        }
        locationManager.stopAllLocationActivity()
    }

    func handleAppBackgroundTransition() {
        guard case .running = phase else {
            locationManager.enforceNoLocationUnlessRunningWalk(false, reason: "appBackgroundNoRunningWalk")
            return
        }
        guard hasActiveLocationWalk else {
            locationManager.enforceNoLocationUnlessRunningWalk(false, reason: "appBackgroundInvalidWalk")
            return
        }
        updateElapsedFromClock()
        checkpointActiveWalk(reason: "background", force: true)
        stopTimer()
        locationManager.promoteActiveWalkToBackgroundDelivery()
    }

    func handleAppInactiveTransition() {
        locationManager.enforceNoLocationUnlessRunningWalk(
            hasActiveLocationWalk,
            reason: "appInactive"
        )
    }

    func handleAppForegroundTransition() {
        guard case .running = phase else {
            stopLocationIfNoActiveWalk()
            return
        }
        guard hasActiveLocationWalk else {
            locationManager.enforceNoLocationUnlessRunningWalk(false, reason: "appForegroundInvalidWalk")
            return
        }
        updateElapsedFromClock()
        locationManager.returnActiveWalkToForegroundDelivery()
        checkpointActiveWalk(reason: "foreground", force: true)
        startTimer()
    }

    func stopLocationIfNoActiveWalk() {
        guard hasActiveLocationWalk else {
            locationManager.enforceNoLocationUnlessRunningWalk(false, reason: "noActiveWalk")
            return
        }
    }

    func addPoop(type: PottyType = .perfectPoop) {
        poopCount += 1
        let location = locationManager.currentLocation ?? locationManager.collectedLocations.last
        activePoopMarkers.append(WalkPoopMarker(location: location, type: type))
        checkpointActiveWalk(reason: "poop", force: true)
    }

    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let r = self.resumeTime else { return }
                self.elapsedTime = self.pausedElapsed + Date().timeIntervalSince(r)
                self.checkpointActiveWalk(reason: "timer", force: false)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedFromClock() {
        guard let r = resumeTime else { return }
        elapsedTime = pausedElapsed + Date().timeIntervalSince(r)
    }

    private func createRecoveryCheckpointIfPossible(modelContext: ModelContext?, pet: Pet) {
        guard let modelContext else { return }
        deleteStaleRecoveryCheckpoints(for: pet, modelContext: modelContext)

        let checkpoint = PetWalkLog(
            startDate: startTime ?? Date(),
            pet: pet,
            executorId: activeWalkExecutorIds.first,
            executorIds: activeWalkExecutorIds,
            sharedSessionId: WalkRecoveryCheckpoint.makeSharedSessionID()
        )
        checkpoint.behaviorNotes = WalkRecoveryCheckpoint.encodeMetadata(
            WalkRecoveryCheckpoint.metadata(elapsedTime: elapsedTime, poopMarkers: activePoopMarkers)
        )
        modelContext.insert(checkpoint)
        CloudSyncMutationRecorder.markModified(checkpoint, context: modelContext, modifiedAt: Date())
        activeRecoveryCheckpointID = checkpoint.id
        activeWalkModelContext = modelContext
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if saveResult.didSave {
            lastRecoveryCheckpointAt = Date()
        }
    }

    private func checkpointActiveWalk(reason _: String, force: Bool) {
        guard let modelContext = activeWalkModelContext,
              let checkpoint = activeRecoveryCheckpoint(modelContext: modelContext)
        else { return }

        let now = Date()
        if !force, let lastRecoveryCheckpointAt, now.timeIntervalSince(lastRecoveryCheckpointAt) < 15 {
            return
        }

        let routeLocations = mergedRouteLocationsForPersistence()
        checkpoint.distanceMeters = max(0, recoveredDistanceMeters + locationManager.totalDistance)
        checkpoint.routeLocationsData = routeData(from: routeLocations)
        checkpoint.behaviorNotes = WalkRecoveryCheckpoint.encodeMetadata(
            WalkRecoveryCheckpoint.metadata(elapsedTime: elapsedTime, poopMarkers: activePoopMarkers)
        )
        CloudSyncMutationRecorder.markModified(checkpoint, context: modelContext, modifiedAt: now)
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if saveResult.didSave {
            lastRecoveryCheckpointAt = now
        }
    }

    private func activeRecoveryCheckpoint(modelContext: ModelContext) -> PetWalkLog? {
        guard let id = activeRecoveryCheckpointID else { return nil }
        let descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func deleteRecoveryCheckpointIfPossible(modelContext: ModelContext) {
        guard let checkpoint = activeRecoveryCheckpoint(modelContext: modelContext) else {
            activeRecoveryCheckpointID = nil
            activeWalkModelContext = nil
            lastRecoveryCheckpointAt = nil
            recoveredRouteLocations = []
            recoveredDistanceMeters = 0
            restoredCheckpointNeedsLocationStart = false
            return
        }
        modelContext.delete(checkpoint) // derived-state: allow recovery checkpoint cleanup after authoritative walk fact is saved
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if saveResult.didSave {
            activeRecoveryCheckpointID = nil
            activeWalkModelContext = nil
            lastRecoveryCheckpointAt = nil
            recoveredRouteLocations = []
            recoveredDistanceMeters = 0
            restoredCheckpointNeedsLocationStart = false
        }
    }

    private func deleteStaleRecoveryCheckpoints(for pet: Pet, modelContext: ModelContext) {
        let stale = WalkFeaturePolicy.recoverableWalkCheckpoints(for: pet)
        guard !stale.isEmpty else { return }
        for checkpoint in stale {
            modelContext.delete(checkpoint) // derived-state: allow stale recovery checkpoint replacement before a new walk starts
        }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if !saveResult.didSave {
            modelContext.rollback()
        }
    }

    private func routeData(from locations: [CLLocation]) -> Data? {
        let coordinates = locations.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude]
        }
        return try? JSONSerialization.data(withJSONObject: coordinates)
    }

    private func routeLocations(from data: Data?) -> [CLLocation] {
        guard let data,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocation(latitude: lat, longitude: lon)
        }
    }

    private func mergedRouteLocationsForPersistence() -> [CLLocation] {
        let live = locationManager.routeLocationsForPersistence()
        guard !recoveredRouteLocations.isEmpty else { return live }
        guard let firstLive = live.first,
              let lastRecovered = recoveredRouteLocations.last,
              firstLive.distance(from: lastRecovered) < 1
        else {
            return recoveredRouteLocations + live
        }
        return recoveredRouteLocations + live.dropFirst()
    }

    private func walkSessionProbeNote(action: String) -> [String: String] {
        [
            "action": action,
            "points": "\(locationManager.routeLocationsForPersistence(maxCount: 600).count)",
            "poopCount": "\(poopCount)"
        ]
    }

    // MARK: - Map Snapshot
    private func generateMapSnapshot(
        for walkLogs: [PetWalkLog],
        routeLocations: [CLLocation],
        poopMarkers: [WalkPoopMarker],
        modelContext: ModelContext
    ) {
        let walkLogIDs = walkLogs.map(\.id)
        guard !walkLogIDs.isEmpty, routeLocations.count >= 2 else { return }

        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "walk_map_snapshot",
            requestedItemCount: 1
        )
        guard budget.hasWorkCapacity else {
            AppPerformanceMonitor.shared.record(
                "walk_map_snapshot_deferred",
                valueMS: 0,
                note: "runtime budget deferred"
            )
            return
        }

        let quality: WalkMapSnapshotQuality = budget.allowsExpensiveWork ? .standard : .reduced
        let sampledRoute = WalkMapSnapshotPointCursor.sample(
            locations: routeLocations,
            maximumPointCount: quality.maximumRoutePointCount
        )
        let sampledMarkers = WalkMapSnapshotMarkerCursor.sample(
            markers: poopMarkers.compactMap(WalkMapSnapshotMarker.init),
            maximumMarkerCount: quality.maximumMarkerCount
        )
        let request = WalkMapSnapshotRequest(
            walkLogIDs: walkLogIDs,
            route: sampledRoute.points,
            poopMarkers: sampledMarkers.markers,
            routeCursorStride: sampledRoute.stride,
            poopMarkerCursorStride: sampledMarkers.stride,
            quality: quality,
            isRainbowRoute: WalkEffectPreferenceStore.isRainbowRouteEnabled(),
            isRainbowPoop: WalkEffectPreferenceStore.isRainbowPoopEnabled()
        )
        let modelContainer = modelContext.container
        mapSnapshotTask?.cancel()
        mapSnapshotGeneration &+= 1
        let generation = mapSnapshotGeneration
        let startedAt = CFAbsoluteTimeGetCurrent()
        let budgetStartedAt = Date()
        let snapshotDeadline = budgetStartedAt.addingTimeInterval(budget.maximumWallClockSeconds)
        let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background
        mapSnapshotTask = Task(priority: priority) { [weak self] in
            defer {
                if self?.mapSnapshotGeneration == generation {
                    self?.mapSnapshotTask = nil
                }
            }
            guard !Task.isCancelled,
                  budget.hasTimeRemaining(since: budgetStartedAt) else { return }
            guard let jpegData = await WalkMapSnapshotRenderer.render(
                request: request,
                deadline: snapshotDeadline
            ),
                  !Task.isCancelled,
                  Date() < snapshotDeadline
            else { return }

            do {
                let persistence = WalkMapSnapshotPersistenceActor(modelContainer: modelContainer)
                try await persistence.persist(
                    jpegData: jpegData,
                    to: request.walkLogIDs,
                    deadline: snapshotDeadline
                )
                guard !Task.isCancelled,
                      self?.mapSnapshotGeneration == generation
                else { return }
                AppPerformanceMonitor.shared.record(
                    "walk_map_snapshot_completed",
                    startedAt: startedAt,
                    note: "logs=\(request.walkLogIDs.count), points=\(request.route.count), routeStride=\(request.routeCursorStride), markers=\(request.poopMarkers.count), markerStride=\(request.poopMarkerCursorStride), quality=\(quality)"
                )
            } catch is CancellationError {
                return
            } catch {
                AppPerformanceMonitor.shared.record(
                    "walk_map_snapshot_failed",
                    startedAt: startedAt,
                    note: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Formatted Time
    var formattedTime: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var distanceText: String {
        AppMeasurementSystem.formatDistanceMeters(locationManager.totalDistance, fractionDigits: 2)
    }
}

private extension PetWalkingManager {
    func finishInvalidStop(
        resetSession: Bool,
        result: WalkStopRewardSummary
    ) -> WalkStopRewardSummary {
        if resetSession {
            reset()
        }
        walkStopStartedAt = nil
        return result
    }

    func makeStopDraft(pet: Pet, targets: [Pet]) -> WalkStopDraft {
        // Final elapsed time is the accumulated paused time plus the current segment.
        if let resumeTime {
            pausedElapsed += Date().timeIntervalSince(resumeTime)
        }
        elapsedTime = pausedElapsed
        self.resumeTime = nil

        stopTimer()
        locationManager.stopWalkSession()

        let poopMarkers = activePoopMarkers
        let poopCount = max(self.poopCount, poopMarkers.count)
        let startedAt = startTime ?? Date()
        let endedAt = Date()
        let distanceMeters = recoveredDistanceMeters + locationManager.totalDistance
        let routeLocations = mergedRouteLocationsForPersistence()

        // Participants are locked when the walk starts and restored from its
        // checkpoint. Never reread the device's current Human while stopping.
        return WalkStopDraft(
            pet: pet,
            targets: targets,
            elapsed: elapsedTime,
            poopCount: poopCount,
            poopMarkers: poopMarkers,
            executorIds: activeWalkExecutorIds,
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            routeLocations: routeLocations,
            routeCoordinates: routeLocations.map(\.coordinate),
            routeData: routeData(from: routeLocations),
            isTooShortForReward: !CoconutWalkRewardPolicy.isRewardable(distanceMeters: distanceMeters)
        )
    }

    func recordWalk(
        _ draft: WalkStopDraft,
        modelContext: ModelContext
    ) -> WalkStopWalkRecord? {
        let walkLogs: [PetWalkLog]
        let coconutDelta: Int

        if draft.targets.count > 1 {
            let result = walkCareEvents.recordSharedWalk(
                sourcePet: draft.pet,
                targets: draft.targets,
                distanceMeters: draft.distanceMeters,
                endDate: draft.endedAt,
                context: modelContext,
                executorId: draft.executorId,
                executorIds: draft.executorIds,
                startDate: draft.startedAt
            )
            walkLogs = result.walkLogs
            coconutDelta = result.coconutDelta
        } else {
            guard let record = recordSingleWalk(draft, modelContext: modelContext) else {
                return nil
            }
            walkLogs = record.logs
            coconutDelta = record.coconutDelta
        }

        for walkLog in walkLogs {
            walkLog.routeLocationsData = draft.routeData
        }
        let sourceLog = walkLogs.first { $0.pet?.id == draft.pet.id } ?? walkLogs.first
        return WalkStopWalkRecord(logs: walkLogs, sourceLog: sourceLog, coconutDelta: coconutDelta)
    }

    func recordSingleWalk(
        _ draft: WalkStopDraft,
        modelContext: ModelContext
    ) -> WalkStopWalkRecord? {
        let intent = DomainCareFactCreateIntent(
            kind: .walk(
                distanceMeters: draft.distanceMeters,
                endDate: draft.endedAt,
                coconutsEarned: PetWalkLog.coconuts(for: draft.distanceMeters),
                behaviorNotes: nil,
                moodRating: 0,
                executorIds: draft.executorIds,
                sharedSessionId: ""
            ),
            occurredAt: draft.startedAt,
            modifiedAt: draft.endedAt,
            executorId: draft.executorId,
            source: .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: draft.pet,
            intent: intent,
            context: modelContext,
            logPrefix: "PetWalkingManager.stop.walk"
        ) else { return nil }

        let walkLog = DomainCareFactWriter.createWalkLog(plan: write, context: modelContext)
        var coconutDelta = 0
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            var reward: (humanGot: Int, petGot: Int)?
            if !draft.isTooShortForReward {
                reward = careEconomy.awardCareAction(
                    type: .walk(distanceMeters: draft.distanceMeters),
                    pet: draft.pet,
                    context: modelContext,
                    quality: .none,
                    date: draft.endedAt,
                    executorId: actor.rewardExecutorId,
                    careObjectKey: nil
                )
            }
            let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
            let ledgerEvent = careLedger.record(
                occurredAt: draft.startedAt,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .pet,
                subjectId: draft.pet.id.uuidString,
                eventKind: .walk,
                actionType: "walk",
                amountValue: draft.distanceMeters,
                amountUnit: "m",
                note: walkLog.behaviorNotes ?? "",
                source: .quickAction,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: String(describing: PetWalkLog.self),
                legacyModelId: walkLog.id.uuidString,
                coconutDelta: careLedger.rewardDelta(reward),
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: metadataJSON,
                context: modelContext,
                save: false
            )
            CloudSyncMutationRecorder.markModified(ledgerEvent, context: modelContext, modifiedAt: draft.endedAt)
            careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
            coconutDelta = reward.map { $0.humanGot + $0.petGot } ?? 0
            walkLog.coconutsEarned = coconutDelta
        }
        return WalkStopWalkRecord(logs: [walkLog], sourceLog: walkLog, coconutDelta: coconutDelta)
    }

    func recordPottyEvents(
        _ draft: WalkStopDraft,
        sourceWalkLog: PetWalkLog?,
        modelContext: ModelContext
    ) -> WalkStopPottyRecord {
        let markers = persistedPoopMarkers(for: draft)
        var logs: [PetPottyLog] = []
        var writes: [(PetPottyLog, AuthorizedDomainCareFactWrite)] = []

        for marker in markers {
            let intent = DomainCareFactCreateIntent(
                kind: .potty(type: marker.type, sharedSessionId: ""),
                occurredAt: marker.date,
                modifiedAt: draft.endedAt,
                executorId: draft.executorId,
                source: .userCommand
            )
            guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: draft.pet,
                intent: intent,
                context: modelContext,
                logPrefix: "PetWalkingManager.stop.potty"
            ) else { continue }

            let pottyLog = DomainCareFactWriter.createPottyLog(plan: write, context: modelContext)
            pottyLog.latitude = marker.latitude
            pottyLog.longitude = marker.longitude
            pottyLog.locationAccuracyMeters = marker.accuracyMeters
            pottyLog.walkLogId = sourceWalkLog?.id.uuidString
            logs.append(pottyLog)
            writes.append((pottyLog, write))
        }

        let coconutDelta = rewardPottyEvents(writes, draft: draft, modelContext: modelContext)
        return WalkStopPottyRecord(logs: logs, coconutDelta: coconutDelta)
    }

    func persistedPoopMarkers(for draft: WalkStopDraft) -> [WalkPoopMarker] {
        guard draft.poopMarkers.isEmpty, draft.poopCount > 0 else {
            return draft.poopMarkers
        }
        return (0 ..< draft.poopCount).map { _ in WalkPoopMarker(date: Date(), location: nil) }
    }

    func rewardPottyEvents(
        _ writes: [(PetPottyLog, AuthorizedDomainCareFactWrite)],
        draft: WalkStopDraft,
        modelContext: ModelContext
    ) -> Int {
        var coconutDelta = 0
        for (pottyLog, write) in writes {
            DomainCareFactEffectsDispatcher.run(plan: write) { actor in
                let reward = careEconomy.awardCareAction(
                    type: .potty(isLitter: false),
                    pet: draft.pet,
                    context: modelContext,
                    quality: .none,
                    date: draft.endedAt,
                    executorId: actor.rewardExecutorId,
                    careObjectKey: nil
                )
                let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
                let ledgerEvent = careLedger.record(
                    occurredAt: pottyLog.date,
                    actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                    actorId: actor.effectiveExecutorId,
                    subjectKind: .pet,
                    subjectId: draft.pet.id.uuidString,
                    eventKind: .potty,
                    actionType: pottyLog.pottyType.rawValue,
                    amountValue: 0,
                    amountUnit: "",
                    note: "walk.poop",
                    source: .quickAction,
                    sourceEventId: nil,
                    sourceReminderId: nil,
                    legacyModelName: String(describing: PetPottyLog.self),
                    legacyModelId: pottyLog.id.uuidString,
                    coconutDelta: careLedger.rewardDelta(reward),
                    rewardLogId: nil,
                    privacyFieldRaw: nil,
                    metadataJSON: metadataJSON,
                    context: modelContext,
                    save: false
                )
                CloudSyncMutationRecorder.markModified(ledgerEvent, context: modelContext, modifiedAt: draft.endedAt)
                careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
                coconutDelta += careLedger.rewardDelta(reward)
            }
        }
        return coconutDelta
    }

    func persistStop(
        _ draft: WalkStopDraft,
        walkRecord: WalkStopWalkRecord,
        pottyRecord: WalkStopPottyRecord,
        modelContext: ModelContext
    ) -> WalkStopRewardSummary {
        CloudSyncMutationRecorder.markModified(walkRecord.logs, context: modelContext, modifiedAt: draft.endedAt)
        CloudSyncMutationRecorder.markModified(pottyRecord.logs, context: modelContext, modifiedAt: draft.endedAt)
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            return finishFailedStop(
                draft,
                errorDescription: saveResult.errorDescription,
                modelContext: modelContext
            )
        }

        publishWalkCompletion(
            petID: draft.pet.id,
            targets: draft.targets,
            walkLogs: walkRecord.logs,
            pottyLogs: pottyRecord.logs,
            endedAt: draft.endedAt
        )
        generateMapSnapshot(
            for: walkRecord.logs,
            routeLocations: draft.routeLocations,
            poopMarkers: draft.poopMarkers,
            modelContext: modelContext
        )
        deleteRecoveryCheckpointIfPossible(modelContext: modelContext)
        finishPersistedStop(draft, sourceWalkLog: walkRecord.sourceLog)

        return WalkStopRewardSummary(
            walkLogID: walkRecord.sourceLog?.id,
            coconutDelta: walkRecord.coconutDelta + pottyRecord.coconutDelta,
            walkCoconutDelta: walkRecord.coconutDelta,
            pottyCoconutDelta: pottyRecord.coconutDelta,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    func finishFailedStop(
        _ draft: WalkStopDraft,
        errorDescription: String?,
        modelContext: ModelContext
    ) -> WalkStopRewardSummary {
        modelContext.rollback()
        phase = .paused
        showSummary = false
        lastCompletedPetId = nil
        lastCompletedWalk = nil
        lastCompletedRouteCoordinates = []
        lastCompletedPoopMarkers = []
        AppFlowPerformance.mark(
            AppPerformanceFlows.walkSession,
            AppPerformancePhases.writeFailure,
            startedAt: walkStopStartedAt,
            note: stopPerformanceNote(draft)
        )
        walkStopStartedAt = nil
        return .failed(errorDescription)
    }

    func finishPersistedStop(_ draft: WalkStopDraft, sourceWalkLog: PetWalkLog?) {
        lastCompletedPetId = draft.pet.id
        lastCompletedWalk = sourceWalkLog
        lastCompletedRouteCoordinates = draft.routeCoordinates
        lastCompletedPoopMarkers = draft.poopMarkers
        phase = .finished(elapsed: draft.elapsed, poopCount: draft.poopCount)
        showSummary = true

        var note = stopPerformanceNote(draft)
        note["rewarded"] = draft.isTooShortForReward ? "false" : "true"
        AppFlowPerformance.mark(
            AppPerformanceFlows.walkSession,
            AppPerformancePhases.writeSuccess,
            startedAt: walkStopStartedAt,
            note: note
        )
        walkStopStartedAt = nil
    }

    func stopPerformanceNote(_ draft: WalkStopDraft) -> [String: String] {
        [
            "action": "stop",
            "points": "\(draft.routeLocations.count)",
            "poopCount": "\(draft.poopCount)"
        ]
    }
}
