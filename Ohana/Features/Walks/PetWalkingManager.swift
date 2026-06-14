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

        AppFlowPerformance.start(AppPerformanceFlows.walkSession, note: ["action": "start"])
        locationManager.startWalkSession()
        startTimer()
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
        locationManager.resumeWalkSession()
        startTimer()
    }

    func stop(modelContext: ModelContext, sharedTargets: [Pet] = [], executorIds sharedExecutorIds: [String] = []) {
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
            return
        }

        // 隐式读取当前设备执行者（静默，不弹窗）
        let executorId = activeHumanSelection.currentHumanId
        guard !CareFactWritePolicy.executorCannotWrite(executorId, context: modelContext) else {
            reset()
            walkStopStartedAt = nil
            return
        }
        let executorIds = SharedCareParticipantIDs.normalized(sharedExecutorIds, preferredFirst: executorId)
        guard !CareFactWritePolicy.anyExecutorCannotWrite(executorIds, context: modelContext) else {
            reset()
            walkStopStartedAt = nil
            return
        }

        let startedAt = startTime ?? Date()
        let endedAt = Date()
        let distanceMeters = locationManager.totalDistance

        let routeLocations = locationManager.routeLocationsForPersistence()
        let routeCoordinates = routeLocations.map(\.coordinate)
        let coordinates = routeLocations.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude]
        }
        let routeData = try? JSONSerialization.data(withJSONObject: coordinates)

        // N2/Phase54: 遛狗椰子奖励（距离 < 20m 不发放奖励，日志正常保存）
        let isTooShortForReward = !CoconutWalkRewardPolicy.isRewardable(distanceMeters: distanceMeters)
        let normalizedTargets = WalkFeaturePolicy.normalizedWalkTargets(sharedTargets, fallback: pet)
        let walkLogs: [PetWalkLog]
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
        } else {
            let walkLog = PetWalkLog(startDate: startedAt, pet: pet, executorId: executorId, executorIds: executorIds)
            walkLog.endDate = endedAt
            walkLog.distanceMeters = distanceMeters
            modelContext.insert(walkLog)
            modelContext.safeSave()

            var reward: (humanGot: Int, petGot: Int)?
            if !isTooShortForReward {
                reward = EconomyRewardDiscipline.awardCareAction(
                    type: .walk(distanceMeters: distanceMeters),
                    pet: pet,
                    context: modelContext,
                    executorId: executorId,
                    questManager: questManager
                )
            }
            let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
            let ledgerEvent = careLedger.record(
                occurredAt: startedAt,
                actorKind: executorId == nil ? .unknown : .human,
                actorId: executorId,
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
            careLedger.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
            let earnedCoconuts = reward.map { $0.humanGot + $0.petGot } ?? 0
            walkLog.coconutsEarned = earnedCoconuts
            walkLogs = [walkLog]
        }

        for walkLog in walkLogs {
            walkLog.routeLocationsData = routeData
            generateMapSnapshot(for: walkLog, routeLocations: routeLocations, poopMarkers: poopMarkers, modelContext: modelContext)
        }

        let sourceWalkLog = walkLogs.first { $0.pet?.id == pet.id } ?? walkLogs.first
        lastCompletedPetId = pet.id
        lastCompletedWalk = sourceWalkLog
        lastCompletedRouteCoordinates = routeCoordinates
        lastCompletedPoopMarkers = poopMarkers

        // 保存遛狗中的便便路线事件（含真实打卡时间与可选坐标）
        let persistedMarkers: [WalkPoopMarker] = poopMarkers.isEmpty && poop > 0
            ? (0 ..< poop).map { _ in WalkPoopMarker(date: Date(), location: nil) }
            : poopMarkers
        var pottyLogs: [PetPottyLog] = []
        for marker in persistedMarkers {
            let pottyLog = PetPottyLog(
                date: marker.date,
                type: marker.type,
                pet: pet,
                executorId: executorId,
                latitude: marker.latitude,
                longitude: marker.longitude,
                locationAccuracyMeters: marker.accuracyMeters,
                walkLogId: sourceWalkLog?.id.uuidString
            )
            modelContext.insert(pottyLog)
            pottyLogs.append(pottyLog)
        }

        // 遛狗中每次便便：人+2, 宠物+5（OhanaActionType.potty(isLitter:false)）
        if poop > 0 {
            for pottyLog in pottyLogs {
                let reward = EconomyRewardDiscipline.awardCareAction(
                    type: .potty(isLitter: false),
                    pet: pet,
                    context: modelContext,
                    executorId: executorId,
                    questManager: questManager
                )
                let metadataJSON = careLedger.rewardMetadata(reward, questManager: questManager)
                let ledgerEvent = careLedger.record(
                    occurredAt: pottyLog.date,
                    actorKind: executorId == nil ? .unknown : .human,
                    actorId: executorId,
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
                careLedger.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: modelContext)
            }
        }

        CloudSyncMutationRecorder.markModified(walkLogs, context: modelContext, modifiedAt: endedAt)
        CloudSyncMutationRecorder.markModified(pottyLogs, context: modelContext, modifiedAt: endedAt)
        modelContext.safeSave()

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
    }

    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let r = self.resumeTime else { return }
                self.elapsedTime = self.pausedElapsed + Date().timeIntervalSince(r)
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

    private func walkSessionProbeNote(action: String) -> [String: String] {
        [
            "action": action,
            "points": "\(locationManager.routeLocationsForPersistence(maxCount: 600).count)",
            "poopCount": "\(poopCount)"
        ]
    }

    // MARK: - Map Snapshot
    private func generateMapSnapshot(for walkLog: PetWalkLog, routeLocations: [CLLocation], poopMarkers: [WalkPoopMarker], modelContext: ModelContext) {
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
                walkLog.mapSnapshotData = jpegData
                modelContext.safeSave()
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
