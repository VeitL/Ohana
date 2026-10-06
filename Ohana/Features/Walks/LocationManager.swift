//
//  LocationManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import CoreLocation
import Foundation
import Observation
import UIKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let backgroundWalkTrackingEnabledKey = "ohana_walk_background_route_enabled_v2"
    private static let legacyBackgroundWalkTrackingEnabledKey = "ohana_walk_background_tracking_enabled"
    private static let backgroundUpgradePromptedKey = "ohana_walk_background_route_prompted_v2"

    private enum LocationPurpose: String {
        case none
        case oneShot
        case walkForeground
        case walkBackground
    }

    private let manager = CLLocationManager()
    private var backgroundSession: AnyObject?
    private var isBackgroundDeliveryEnabled = false
    private var activePurpose: LocationPurpose = .none
    private var oneShotLocationHandler: ((Result<CLLocation, Error>) -> Void)?
    private var pendingOneShotAccuracy: CLLocationAccuracy?
    private var walkMetricsUpdateHandler: ((Double) -> Void)?
    private var trackedDistanceMeters: Double = 0

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
    var canContinueCurrentWalkInBackground: Bool {
        isTracking && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
    }

    var isBackgroundWalkDeliveryActive: Bool {
        isTracking && isBackgroundDeliveryEnabled
    }

    var debugLocationPurpose: String {
        activePurpose.rawValue
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        UserDefaults.standard.set(false, forKey: Self.legacyBackgroundWalkTrackingEnabledKey)
        UserDefaults.standard.set(false, forKey: Self.backgroundWalkTrackingEnabledKey)
        stopAllLocationActivity()
    }

    // MARK: - Permission
    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters,
        completion: @escaping (Result<CLLocation, Error>) -> Void
    ) {
        switch authorizationStatus {
        case .notDetermined:
            oneShotLocationHandler = completion
            pendingOneShotAccuracy = accuracy
            activePurpose = .oneShot
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                if let currentLocation {
                    completion(.success(currentLocation))
                } else {
                    oneShotLocationHandler = completion
                }
                return
            }
            oneShotLocationHandler = completion
            manager.desiredAccuracy = accuracy
            manager.distanceFilter = kCLDistanceFilterNone
            activePurpose = .oneShot
            manager.requestLocation()
        case .denied, .restricted:
            completion(.failure(LocationManagerOneShotError.unauthorized))
        @unknown default:
            completion(.failure(LocationManagerOneShotError.unavailable))
        }
    }

    /// 是否已拥有 Always 权限（后台遛狗最优模式）
    var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }

    func setBackgroundWalkTrackingEnabled(_ enabled: Bool) {
        // Deprecated user-facing switch. Background delivery now follows only the
        // active walk state: running walk = allowed, paused/stopped/no walk = off.
        UserDefaults.standard.set(false, forKey: Self.backgroundWalkTrackingEnabledKey)
        if enabled {
            requestBackgroundTrackingAuthorizationIfNeeded()
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
        startWalkSession()
    }

    func startWalkSession() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            pendingStart = true
            requestPermission()
            return
        }

        collectedLocations.removeAll()
        lastAcceptedLocation = nil
        trackedDistanceMeters = 0
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        endBackgroundTracking()
        activePurpose = .walkForeground

        manager.startUpdatingLocation()
    }

    func stopTracking() {
        stopWalkSession()
    }

    func stopWalkSession() {
        isTracking = false
        pendingStart = false
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        endBackgroundTracking()
        activePurpose = .none
    }

    func pauseTracking() {
        pauseWalkSession()
    }

    func pauseWalkSession() {
        isTracking = false
        pendingStart = false
        manager.stopUpdatingLocation()
        endBackgroundTracking()
        activePurpose = .none
    }

    func resumeTracking() {
        resumeWalkSession()
    }

    func resumeWalkSession() {
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        endBackgroundTracking()
        activePurpose = .walkForeground
        manager.startUpdatingLocation()
    }

    func promoteActiveWalkToBackgroundDelivery() {
        guard isTracking, authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            endBackgroundTracking()
            return
        }

        #if !targetEnvironment(simulator)
            if #available(iOS 17.0, *) {
                (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
                backgroundSession = nil
            }
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = false
        #endif
        isBackgroundDeliveryEnabled = true
        activePurpose = .walkBackground
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func returnActiveWalkToForegroundDelivery() {
        guard isTracking else {
            stopAllLocationActivity()
            return
        }
        endBackgroundTracking()
        activePurpose = .walkForeground
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func stopAllLocationActivity() {
        isTracking = false
        pendingStart = false
        oneShotLocationHandler = nil
        pendingOneShotAccuracy = nil
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        endBackgroundTracking()
        activePurpose = .none
    }

    func enforceNoLocationUnlessRunningWalk(_ isRunningWalk: Bool, reason: String) {
        if !isRunningWalk {
            stopAllLocationActivity()
        }
        recordLocationPolicy(reason: reason)
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
        isBackgroundDeliveryEnabled = false
        if activePurpose == .walkBackground {
            activePurpose = isTracking ? .walkForeground : .none
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let handler = oneShotLocationHandler, let location = locations.last {
            oneShotLocationHandler = nil
            pendingOneShotAccuracy = nil
            handler(.success(location))
            if !isTracking {
                manager.stopUpdatingLocation()
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.distanceFilter = kCLDistanceFilterNone
                endBackgroundTracking()
                activePurpose = .none
            }
        }

        guard isTracking else {
            if activePurpose != .oneShot {
                stopAllLocationActivity()
            }
            return
        }
        currentLocation = locations.last
        var didAcceptRoutePoint = false
        for location in locations where shouldAcceptRoutePoint(location) {
            if let previous = lastAcceptedLocation {
                trackedDistanceMeters += location.distance(from: previous)
            }
            collectedLocations.append(location)
            lastAcceptedLocation = location
            didAcceptRoutePoint = true
        }
        // F6: 防止无界增长 — 保留可见轨迹形状，同时限制内存和后续渲染成本。
        if collectedLocations.count > 1600 {
            collectedLocations = downsample(collectedLocations, maxCount: 800)
            lastAcceptedLocation = collectedLocations.last
        }
        if didAcceptRoutePoint {
            walkMetricsUpdateHandler?(trackedDistanceMeters)
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

    func setWalkMetricsUpdateHandler(_ handler: ((Double) -> Void)?) {
        walkMetricsUpdateHandler = handler
    }

    private func downsample(_ locations: [CLLocation], maxCount: Int) -> [CLLocation] {
        guard locations.count > maxCount, maxCount >= 2 else { return locations }
        let step = Double(locations.count - 1) / Double(maxCount - 1)
        var result: [CLLocation] = []
        result.reserveCapacity(maxCount)

        var lastIndex = -1
        for i in 0 ..< maxCount {
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

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            UserDefaults.standard.set(false, forKey: Self.backgroundWalkTrackingEnabledKey)
            stopAllLocationActivity()
        }

        if pendingStart && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            pendingStart = false
            startWalkSession()
        }

        if let accuracy = pendingOneShotAccuracy,
           authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            pendingOneShotAccuracy = nil
            manager.desiredAccuracy = accuracy
            manager.distanceFilter = kCLDistanceFilterNone
            manager.requestLocation()
        } else if pendingOneShotAccuracy != nil,
                  authorizationStatus == .denied || authorizationStatus == .restricted {
            let handler = oneShotLocationHandler
            oneShotLocationHandler = nil
            pendingOneShotAccuracy = nil
            activePurpose = .none
            handler?(.failure(LocationManagerOneShotError.unauthorized))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let handler = oneShotLocationHandler {
            oneShotLocationHandler = nil
            pendingOneShotAccuracy = nil
            handler(.failure(error))
            if !isTracking {
                manager.stopUpdatingLocation()
                endBackgroundTracking()
                activePurpose = .none
            }
        }

        #if DEBUG
            OhanaLog.warning("LocationManager error: \(error.localizedDescription)", category: "Location")
        #endif
    }

    // MARK: - Computed
    var totalDistance: Double {
        trackedDistanceMeters
    }

    private func recordLocationPolicy(reason: String) {
        let purpose = activePurpose.rawValue
        let tracking = isTracking
        let background = isBackgroundDeliveryEnabled
        let auth = authorizationStatus.rawValue
        Task { @MainActor in
            AppPerformanceMonitor.shared.record(
                "定位策略",
                valueMS: 0,
                note: "reason=\(reason), purpose=\(purpose), tracking=\(tracking), background=\(background), auth=\(auth)"
            )
        }
    }
}

private enum LocationManagerOneShotError: LocalizedError {
    case unauthorized
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Location permission is not available."
        case .unavailable: "Location is not available."
        }
    }
}
