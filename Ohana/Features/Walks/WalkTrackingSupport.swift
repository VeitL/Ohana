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

    @MainActor
    static func make(pet: Pet, manager: PetWalkingManaging) -> WalkTrackingSnapshot {
        let activeWalks = WalkFeaturePolicy.activeWalkLogs(for: pet)
        let latestWalk: PetWalkLog? = if manager.lastCompletedPetId == pet.id, let completed = manager.lastCompletedWalk {
            completed
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
            thisWeekDistanceKm: weekDistanceKm
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

@MainActor
struct WalkTrackingCommandExecutor {
    let modelContext: ModelContext
    let services: AppServices

    func stopWalk(manager: PetWalkingManaging, sharedTargets: [Pet], executorIds: [String]) {
        manager.stop(modelContext: modelContext, sharedTargets: sharedTargets, executorIds: executorIds)
        services.publishWalkingPresentationChange()
    }

    func saveWeeklyGoal(_ goal: Double, for pet: Pet) {
        PetWalkCommandExecutor(context: modelContext, services: services).saveWeeklyGoal(
            goal,
            for: pet,
            note: "walk.card.goal"
        )
    }
}
