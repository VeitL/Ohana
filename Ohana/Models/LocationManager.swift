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
    
    private let manager = CLLocationManager()
    // 任务六：iOS 17+ CLBackgroundActivitySession，WhenInUse 下也可后台追踪
    private var backgroundSession: AnyObject? = nil  // CLBackgroundActivitySession（类型擦除避免 iOS<17 符号引用）

    var currentLocation: CLLocation?
    var collectedLocations: [CLLocation] = []
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isTracking = false
    var pendingStart = false
    
    /// 当前设备是否支持后台定位更新（需 UIBackgroundModes 包含 location）
    private var canUseBackgroundLocation: Bool {
        // 1. 模拟器不支持后台定位
        #if targetEnvironment(simulator)
        return false
        #else
        // 2. 检查系统是否允许后台刷新
        guard UIApplication.shared.backgroundRefreshStatus == .available else { return false }
        // 3. 需要 Always 或 WhenInUse 权限
        return authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
        #endif
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }
    
    // MARK: - Permission
    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    /// 是否已拥有 Always 权限（后台遛狗最优模式）
    var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }

    /// 主动请求升级到 Always（仅在 WhenInUse 状态下有效）
    func upgradeToAlways() {
        guard authorizationStatus == .authorizedWhenInUse else { return }
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
        isTracking = true

        #if !targetEnvironment(simulator)
        // 任务六：iOS 17+ — 用 CLBackgroundActivitySession 在 WhenInUse 授权下保持后台追踪
        // 此 Session 在 App 进入后台时保持 "in use" 状态，无需 Always 权限
        if #available(iOS 17.0, *) {
            backgroundSession = CLBackgroundActivitySession()
        } else if canUseBackgroundLocation {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        #endif

        manager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()

        #if !targetEnvironment(simulator)
        // 任务六：销毁后台 session
        if #available(iOS 17.0, *) {
            (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
            backgroundSession = nil
        } else if canUseBackgroundLocation {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
        }
        #endif
    }
    
    func pauseTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        // 暂停时保留后台权限，但停止更新
    }
    
    func resumeTracking() {
        isTracking = true
        if canUseBackgroundLocation {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        currentLocation = locations.last
        collectedLocations.append(contentsOf: locations)
        // F6: 防止无界增长 — 超过阈值时降采样（保留每隔一个点）
        if collectedLocations.count > 5000 {
            collectedLocations = collectedLocations.enumerated().compactMap { i, loc in
                i.isMultiple(of: 2) ? loc : nil
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
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
