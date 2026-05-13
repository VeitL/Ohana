//
//  LocationManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import CoreLocation
import Observation
import UIKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    static let backgroundWalkTrackingEnabledKey = "ohana_walk_background_route_enabled_v2"
    private static let legacyBackgroundWalkTrackingEnabledKey = "ohana_walk_background_tracking_enabled"
    private static let backgroundUpgradePromptedKey = "ohana_walk_background_route_prompted_v2"
    
    private let manager = CLLocationManager()
    private var backgroundSession: AnyObject?

    var currentLocation: CLLocation?
    var collectedLocations: [CLLocation] = []
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isTracking = false
    var pendingStart = false

    private var lastAcceptedLocation: CLLocation?
    private let routeAccuracyLimit: CLLocationAccuracy = 65
    private let minimumRoutePointDistance: CLLocationDistance = 8
    private let maximumRoutePointInterval: TimeInterval = 18
    private let maximumPlausibleSpeed: CLLocationSpeed = 12
    private var backgroundWalkTrackingEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.backgroundWalkTrackingEnabledKey)
    }

    var canContinueCurrentWalkInBackground: Bool {
        isTracking && backgroundWalkTrackingEnabled && (
            authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
        )
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        UserDefaults.standard.set(false, forKey: Self.legacyBackgroundWalkTrackingEnabledKey)
        stopAllLocationActivity()
    }
    
    // MARK: - Permission
    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// 是否已拥有 Always 权限（后台遛狗最优模式）
    var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }

    func setBackgroundWalkTrackingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.backgroundWalkTrackingEnabledKey)
        if enabled {
            requestBackgroundTrackingAuthorizationIfNeeded()
            if isTracking {
                beginBackgroundTrackingIfNeeded()
            }
        } else {
            endBackgroundTracking()
        }
    }

    func upgradeToAlways() {
        setBackgroundWalkTrackingEnabled(true)
    }

    private func requestBackgroundTrackingAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            requestAlwaysUpgradeOnce()
        case .denied, .restricted:
            UserDefaults.standard.set(false, forKey: Self.backgroundWalkTrackingEnabledKey)
        default:
            break
        }
    }

    private func requestAlwaysUpgradeOnce() {
        guard !UserDefaults.standard.bool(forKey: Self.backgroundUpgradePromptedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.backgroundUpgradePromptedKey)
        manager.requestAlwaysAuthorization()
    }
    
    // MARK: - Tracking
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            pendingStart = true
            requestPermission()
            return
        }
        
        collectedLocations.removeAll()
        lastAcceptedLocation = nil
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        beginBackgroundTrackingIfNeeded()

        manager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        pendingStart = false
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        endBackgroundTracking()
    }
    
    func pauseTracking() {
        isTracking = false
        pendingStart = false
        manager.stopUpdatingLocation()
        endBackgroundTracking()
    }
    
    func resumeTracking() {
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        beginBackgroundTrackingIfNeeded()
        manager.startUpdatingLocation()
    }

    private func beginBackgroundTrackingIfNeeded() {
        guard backgroundWalkTrackingEnabled else {
            endBackgroundTracking()
            return
        }

        #if !targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            if backgroundSession == nil {
                backgroundSession = CLBackgroundActivitySession()
            }
        } else if authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        #endif
    }

    func stopAllLocationActivity() {
        isTracking = false
        pendingStart = false
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        endBackgroundTracking()
    }

    private func endBackgroundTracking() {
        #if !targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
            backgroundSession = nil
        }
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        #endif
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        currentLocation = locations.last
        for location in locations where shouldAcceptRoutePoint(location) {
            collectedLocations.append(location)
            lastAcceptedLocation = location
        }
        // F6: 防止无界增长 — 保留可见轨迹形状，同时限制内存和后续渲染成本。
        if collectedLocations.count > 1600 {
            collectedLocations = downsample(collectedLocations, maxCount: 800)
            lastAcceptedLocation = collectedLocations.last
        }
    }

    private func shouldAcceptRoutePoint(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= routeAccuracyLimit,
              abs(location.timestamp.timeIntervalSinceNow) < 30
        else { return false }

        guard let previous = lastAcceptedLocation else { return true }
        let distance = location.distance(from: previous)
        let interval = location.timestamp.timeIntervalSince(previous.timestamp)
        guard interval >= 0 else { return false }

        if interval > 0 {
            let speed = distance / interval
            if speed > maximumPlausibleSpeed { return false }
        }

        return distance >= minimumRoutePointDistance || interval >= maximumRoutePointInterval
    }

    func routeLocationsForPersistence(maxCount: Int = 600) -> [CLLocation] {
        downsample(collectedLocations, maxCount: maxCount)
    }

    private func downsample(_ locations: [CLLocation], maxCount: Int) -> [CLLocation] {
        guard locations.count > maxCount, maxCount >= 2 else { return locations }
        let step = Double(locations.count - 1) / Double(maxCount - 1)
        var result: [CLLocation] = []
        result.reserveCapacity(maxCount)

        var lastIndex = -1
        for i in 0..<maxCount {
            let index = min(locations.count - 1, Int((Double(i) * step).rounded()))
            if index != lastIndex {
                result.append(locations[index])
                lastIndex = index
            }
        }
        if let last = locations.last, result.last?.timestamp != last.timestamp {
            result[result.count - 1] = last
        }
        return result
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if backgroundWalkTrackingEnabled &&
            (authorizationStatus == .denied || authorizationStatus == .restricted) {
            UserDefaults.standard.set(false, forKey: Self.backgroundWalkTrackingEnabledKey)
            endBackgroundTracking()
        }

        if backgroundWalkTrackingEnabled && authorizationStatus == .authorizedWhenInUse {
            requestAlwaysUpgradeOnce()
        }
        
        if pendingStart && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            pendingStart = false
            startTracking()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("⚠️ LocationManager error: \(error.localizedDescription)")
        #endif
    }
    
    // MARK: - Computed
    var totalDistance: Double {
        guard collectedLocations.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<collectedLocations.count {
            total += collectedLocations[i].distance(from: collectedLocations[i - 1])
        }
        return total
    }
}
