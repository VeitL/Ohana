//
//  WalkTrackingSupport.swift
//  Ohana
//
//  遛狗追踪卡片：地图铺满卡片背景，控制面板以玻璃层叠加。
//

import MapKit
import SwiftData
import SwiftUI

struct WalkTrackingSnapshot {
    let latestWalk: PetWalkLog?
    let latestWalkMapData: Data?
    let latestRouteCoordinates: [CLLocationCoordinate2D]
    let latestPoopMarkers: [WalkPoopMarker]
    let thisWeekDistanceKm: Double
    let recoverableWalkCheckpoint: PetWalkLog?
    let hasRecoverableWalkCheckpoint: Bool

    @MainActor
    static func make(pet: Pet, manager: PetWalkingManaging) -> WalkTrackingSnapshot {
        let activeWalks = WalkFeaturePolicy.activeWalkLogs(for: pet)
        let recoverableCheckpoint = WalkFeaturePolicy.recoverableWalkCheckpoints(for: pet)
            .max { $0.startDate < $1.startDate }
        let latestWalk: PetWalkLog? = if manager.lastCompletedPetId == pet.id, let completed = manager.lastCompletedWalk {
            completed
        } else if let recoverableCheckpoint {
            recoverableCheckpoint
        } else {
            activeWalks.max { $0.startDate < $1.startDate }
        }
        let routeCoordinates: [CLLocationCoordinate2D] = if manager.lastCompletedPetId == pet.id, !manager.lastCompletedRouteCoordinates.isEmpty {
            manager.lastCompletedRouteCoordinates
        } else {
            Self.routeCoordinates(from: latestWalk?.routeLocationsData)
        }
        let poopMarkers: [WalkPoopMarker] = if manager.lastCompletedPetId == pet.id, !manager.lastCompletedPoopMarkers.isEmpty {
            manager.lastCompletedPoopMarkers
        } else if let latestWalk {
            WalkFeaturePolicy.activePoopMarkers(for: latestWalk, pet: pet)
        } else {
            []
        }
        let weekDistanceKm = activeWalks
            .filter { $0.startDate >= Self.weekStartDate() }
            .reduce(0) { $0 + $1.distanceMeters } / 1000.0
        return WalkTrackingSnapshot(
            latestWalk: latestWalk,
            latestWalkMapData: latestWalk?.mapSnapshotData,
            latestRouteCoordinates: routeCoordinates,
            latestPoopMarkers: poopMarkers,
            thisWeekDistanceKm: weekDistanceKm,
            recoverableWalkCheckpoint: recoverableCheckpoint,
            hasRecoverableWalkCheckpoint: recoverableCheckpoint != nil
        )
    }

    private static func routeCoordinates(from data: Data?) -> [CLLocationCoordinate2D] {
        guard let data,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private static func weekStartDate() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }
}

enum WalkTrackingRouteVisualStyle: Equatable {
    case active
    case paused
}

enum WalkTrackingMapPresentationPolicy {
    static func routeVisualStyle(for phase: WalkPhase) -> WalkTrackingRouteVisualStyle {
        if case .paused = phase {
            return .paused
        }
        return .active
    }

    static func routeNormalColor(for style: WalkTrackingRouteVisualStyle) -> Color {
        switch style {
        case .active:
            Color.goPrimary
        case .paused:
            Color.ohanaSecondaryText.opacity(0.72)
        }
    }

    static func allowsRainbowRoute(phase: WalkPhase, isRainbowEquipped: Bool) -> Bool {
        guard isRainbowEquipped else { return false }
        if case .paused = phase { return false }
        return true
    }

    static func allowsRouteFlow(phase: WalkPhase, shouldAnimate: Bool) -> Bool {
        guard shouldAnimate else { return false }
        if case .paused = phase { return false }
        return true
    }
}

@MainActor
struct WalkTrackingCommandExecutor {
    let modelContext: ModelContext
    let services: AppServices

    func stopWalk(manager: PetWalkingManaging, sharedTargets: [Pet]) -> WalkStopRewardSummary {
        let rewardSummary = manager.stop(modelContext: modelContext, sharedTargets: sharedTargets)
        services.publishWalkingPresentationChange()
        return rewardSummary
    }

    func saveWeeklyGoal(_ goal: Double, for pet: Pet) -> PetWalkGoalCommandResult {
        PetWalkCommandExecutor(context: modelContext, services: services).saveWeeklyGoal(
            goal,
            for: pet,
            note: "walk.card.goal"
        )
    }
}
