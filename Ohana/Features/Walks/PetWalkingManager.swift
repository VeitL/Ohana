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
    private let locationManager: any WalkLocationManaging
    private let questManager: QuestManager
    private let careLedger: CareLedgerRecording
    private let walkCareEvents: WalkCareEventManaging
    private let activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()

    init(
        locationManager: any WalkLocationManaging,
        questManager: QuestManager,
        careLedger: CareLedgerRecording = CareLedgerService(),
        walkCareEvents: WalkCareEventManaging? = nil
    ) {
        self.locationManager = locationManager
        self.questManager = questManager
        self.careLedger = careLedger
        self.walkCareEvents = walkCareEvents ?? StaticWalkCareEventManager()
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
        start(pet: pet, modelContext: nil)
    }

    func start(pet: Pet, modelContext: ModelContext?) {
        guard WalkFeaturePolicy.canStartWalk(for: pet) else { return }

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
    func stop(modelContext: ModelContext, sharedTargets: [Pet] = [], executorIds sharedExecutorIds: [String] = []) -> WalkStopRewardSummary {
        walkStopStartedAt = CFAbsoluteTimeGetCurrent()
        // 最终elapsed：已暂停部分 + 本次跑步部分
        if let r = resumeTime {
            pausedElapsed += Date().timeIntervalSince(r)
        }
        elapsedTime = pausedElapsed
        resumeTime = nil

        stopTimer()
        locationManager.stopWalkSession()

        let elapsed = elapsedTime
        let poopMarkers = activePoopMarkers
        let poop = max(poopCount, poopMarkers.count)

        guard let pet = currentPet, WalkFeaturePolicy.canStartWalk(for: pet) else {
            reset()
            walkStopStartedAt = nil
            return .empty
        }

        // 隐式读取当前设备执行者（静默，不弹窗）
        let executorId = activeHumanSelection.currentHumanId
        let executorIds = SharedCareParticipantIDs.normalized(sharedExecutorIds, preferredFirst: executorId)

        let startedAt = startTime ?? Date()
        let endedAt = Date()
        let distanceMeters = recoveredDistanceMeters + locationManager.totalDistance

        let routeLocations = mergedRouteLocationsForPersistence()
        let routeCoordinates = routeLocations.map(\.coordinate)
        let coordinates = routeLocations.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude]
        }
        let routeData = try? JSONSerialization.data(withJSONObject: coordinates)

        // N2/Phase54: 遛狗椰子奖励（距离 < 20m 不发放奖励，日志正常保存）
        let isTooShortForReward = !CoconutWalkRewardPolicy.isRewardable(distanceMeters: distanceMeters)
        let normalizedTargets = WalkFeaturePolicy.normalizedWalkTargets(sharedTargets, fallback: pet)
        let walkLogs: [PetWalkLog]
        var walkCoconutDelta = 0
        var pottyCoconutDelta = 0
        if normalizedTargets.count > 1 {
            let result = walkCareEvents.recordSharedWalk(
                sourcePet: pet,
                targets: normalizedTargets,
                distanceMeters: distanceMeters,
                endDate: endedAt,
                context: modelContext,
                executorId: executorId,
                executorIds: executorIds,
                startDate: startedAt
            )
            walkLogs = result.walkLogs
            walkCoconutDelta = result.coconutDelta
        } else {
            let intent = DomainCareFactCreateIntent(
                kind: .walk(
                    distanceMeters: distanceMeters,
                    endDate: endedAt,
                    coconutsEarned: PetWalkLog.coconuts(for: distanceMeters),
                    behaviorNotes: nil,
                    moodRating: 0,
                    executorIds: executorIds,
                    sharedSessionId: ""
                ),
                occurredAt: startedAt,
                modifiedAt: endedAt,
                executorId: executorId,
                source: .userCommand
            )
            guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                intent: intent,
                context: modelContext,
                logPrefix: "PetWalkingManager.stop.walk"
            ) else {
                reset()
                walkStopStartedAt = nil
                return .empty
            }
            let walkLog = DomainCareFactWriter.createWalkLog(plan: write, context: modelContext)

            var reward: (humanGot: Int, petGot: Int)?
            DomainCareFactEffectsDispatcher.run(plan: write) { actor in
                if !isTooShortForReward {
                    reward = EconomyRewardDiscipline.awardCareAction(
                        type: .walk(distanceMeters: distanceMeters),
                        pet: pet,
                        context: modelContext,
                        executorId: actor.rewardExecutorId,
                        questManager: questManager
                    )
                }
                let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
                let ledgerEvent = careLedger.record(
                    occurredAt: startedAt,
                    actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                    actorId: actor.effectiveExecutorId,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    eventKind: .walk,
                    actionType: "walk",
                    amountValue: distanceMeters,
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
                CloudSyncMutationRecorder.markModified(ledgerEvent, context: modelContext, modifiedAt: endedAt)
                careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
                let earnedCoconuts = reward.map { $0.humanGot + $0.petGot } ?? 0
                walkCoconutDelta = earnedCoconuts
                walkLog.coconutsEarned = earnedCoconuts
            }
            walkLogs = [walkLog]
        }

        for walkLog in walkLogs {
            walkLog.routeLocationsData = routeData
            generateMapSnapshot(for: walkLog, routeLocations: routeLocations, poopMarkers: poopMarkers, modelContext: modelContext)
        }

        let sourceWalkLog = walkLogs.first { $0.pet?.id == pet.id } ?? walkLogs.first

        // 保存遛狗中的便便路线事件（含真实打卡时间与可选坐标）
        let persistedMarkers: [WalkPoopMarker] = poopMarkers.isEmpty && poop > 0
            ? (0 ..< poop).map { _ in WalkPoopMarker(date: Date(), location: nil) }
            : poopMarkers
        var pottyLogs: [PetPottyLog] = []
        var pottyWrites: [(PetPottyLog, AuthorizedDomainCareFactWrite)] = []
        for marker in persistedMarkers {
            let intent = DomainCareFactCreateIntent(
                kind: .potty(type: marker.type, sharedSessionId: ""),
                occurredAt: marker.date,
                modifiedAt: endedAt,
                executorId: executorId,
                source: .userCommand
            )
            guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                intent: intent,
                context: modelContext,
                logPrefix: "PetWalkingManager.stop.potty"
            ) else { continue }
            let pottyLog = DomainCareFactWriter.createPottyLog(plan: write, context: modelContext)
            pottyLog.latitude = marker.latitude
            pottyLog.longitude = marker.longitude
            pottyLog.locationAccuracyMeters = marker.accuracyMeters
            pottyLog.walkLogId = sourceWalkLog?.id.uuidString
            pottyLogs.append(pottyLog)
            pottyWrites.append((pottyLog, write))
        }

        // 遛狗中每次便便：人+2, 宠物+5（OhanaActionType.potty(isLitter:false)）
        if poop > 0 {
            for (pottyLog, write) in pottyWrites {
                DomainCareFactEffectsDispatcher.run(plan: write) { actor in
                    let reward = EconomyRewardDiscipline.awardCareAction(
                        type: .potty(isLitter: false),
                        pet: pet,
                        context: modelContext,
                        executorId: actor.rewardExecutorId,
                        questManager: questManager
                    )
                    let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
                    let ledgerEvent = careLedger.record(
                        occurredAt: pottyLog.date,
                        actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                        actorId: actor.effectiveExecutorId,
                        subjectKind: .pet,
                        subjectId: pet.id.uuidString,
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
                    CloudSyncMutationRecorder.markModified(ledgerEvent, context: modelContext, modifiedAt: endedAt)
                    careLedger.syncLedgerEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
                    pottyCoconutDelta += careLedger.rewardDelta(reward)
                }
            }
        }

        CloudSyncMutationRecorder.markModified(walkLogs, context: modelContext, modifiedAt: endedAt)
        CloudSyncMutationRecorder.markModified(pottyLogs, context: modelContext, modifiedAt: endedAt)
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
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
                note: [
                    "action": "stop",
                    "points": "\(routeLocations.count)",
                    "poopCount": "\(poop)"
                ]
            )
            walkStopStartedAt = nil
            return .failed(saveResult.errorDescription)
        }

        deleteRecoveryCheckpointIfPossible(modelContext: modelContext)

        lastCompletedPetId = pet.id
        lastCompletedWalk = sourceWalkLog
        lastCompletedRouteCoordinates = routeCoordinates
        lastCompletedPoopMarkers = poopMarkers
        phase = .finished(elapsed: elapsed, poopCount: poop)
        showSummary = true
        AppFlowPerformance.mark(
            AppPerformanceFlows.walkSession,
            AppPerformancePhases.writeSuccess,
            startedAt: walkStopStartedAt,
            note: [
                "action": "stop",
                "points": "\(routeLocations.count)",
                "poopCount": "\(poop)",
                "rewarded": isTooShortForReward ? "false" : "true"
            ]
        )
        walkStopStartedAt = nil
        return WalkStopRewardSummary(
            walkLogID: sourceWalkLog?.id,
            coconutDelta: walkCoconutDelta + pottyCoconutDelta,
            walkCoconutDelta: walkCoconutDelta,
            pottyCoconutDelta: pottyCoconutDelta,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    func reset() {
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
            executorId: activeHumanSelection.currentHumanId,
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
    private func generateMapSnapshot(for walkLog: PetWalkLog, routeLocations: [CLLocation], poopMarkers: [WalkPoopMarker], modelContext: ModelContext) {
        let walkLogID = walkLog.id
        let modelContainer = modelContext.container
        let locations = routeLocations
        guard locations.count >= 2 else { return }

        let coordinates = locations.map(\.coordinate)
        let poopCoordinates = poopMarkers.compactMap(\.coordinate)
        let regionCoordinates = coordinates + poopCoordinates
        var region = MKCoordinateRegion()

        let lats = regionCoordinates.map(\.latitude)
        let lons = regionCoordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (lats.max()! - lats.min()!) * 1.5),
            longitudeDelta: max(0.005, (lons.max()! - lons.min()!) * 1.5)
        )
        region = MKCoordinateRegion(center: center, span: span)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 400, height: 300)
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot, error == nil else { return }

            let image = UIGraphicsImageRenderer(size: snapshot.image.size).image { ctx in
                snapshot.image.draw(at: .zero)

                MapSnapshotRainbowRenderer.drawRoute(
                    coordinates: coordinates,
                    on: snapshot,
                    in: ctx.cgContext,
                    isRainbow: WalkEffectPreferenceStore.isRainbowRouteEnabled(),
                    lineWidth: 3
                )

                // 起点绿点
                let startPoint = snapshot.point(for: coordinates.first!)
                UIColor.green.setFill()
                UIBezierPath(arcCenter: startPoint, radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

                // 终点蓝点
                let endPoint = snapshot.point(for: coordinates.last!)
                UIColor.blue.setFill()
                UIBezierPath(arcCenter: endPoint, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

                for marker in poopMarkers {
                    guard let coordinate = marker.coordinate else { continue }
                    MapSnapshotRainbowRenderer.drawPoopMarker(
                        at: snapshot.point(for: coordinate),
                        in: ctx.cgContext,
                        isRainbow: WalkEffectPreferenceStore.isRainbowPoopEnabled()
                    )
                }
            }

            let jpegData = image.jpegData(compressionQuality: 0.7)
            // F2: SwiftData 模型必须在 MainActor 上写入
            DispatchQueue.main.async {
                let snapshotContext = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<PetWalkLog>(
                    predicate: #Predicate { candidate in
                        candidate.id == walkLogID
                    }
                )
                descriptor.fetchLimit = 1
                guard let persistedWalkLog = try? snapshotContext.fetch(descriptor).first else {
                    return
                }
                persistedWalkLog.mapSnapshotData = jpegData
                let saveResult = snapshotContext.safeSaveResult(publishFailureEvent: true)
                if !saveResult.didSave {
                    snapshotContext.rollback()
                }
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
