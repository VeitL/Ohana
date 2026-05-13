//
//  PetWalkingManager.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData
import Observation
import MapKit
import UIKit

enum WalkPhase: Equatable {
    case idle
    case running
    case paused
    case finished(elapsed: TimeInterval, poopCount: Int)
}

@Observable
final class PetWalkingManager {
    static let shared = PetWalkingManager()
    
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

    private var pausedElapsed: TimeInterval = 0  // 暂停前已累计时间
    private var resumeTime: Date?                // 最近一次 resume/start 时间
    private var timer: Timer?
    private let locationManager = LocationManager.shared
    
    private init() {}
    
    // MARK: - Actions
    func start(pet: Pet) {
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
        
        locationManager.startTracking()
        startTimer()
    }
    
    func pause() {
        // 暂停前把已跑时间存起来
        if let r = resumeTime {
            pausedElapsed += Date().timeIntervalSince(r)
        }
        resumeTime = nil
        phase = .paused
        locationManager.pauseTracking()
        stopTimer()
    }
    
    func resume() {
        resumeTime = Date()
        phase = .running
        locationManager.resumeTracking()
        startTimer()
    }
    
    func stop(modelContext: ModelContext, household: Household? = nil) {
        // 最终elapsed：已暂停部分 + 本次跑步部分
        if let r = resumeTime {
            pausedElapsed += Date().timeIntervalSince(r)
        }
        elapsedTime = pausedElapsed
        resumeTime = nil

        stopTimer()
        locationManager.stopTracking()
        
        let elapsed = elapsedTime
        let poop = poopCount
        
        guard let pet = currentPet else { return }

        // 隐式读取当前设备执行者（静默，不弹窗）
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap {
            $0.isEmpty ? nil : $0
        }

        // 保存遛狗记录
        let walkLog = PetWalkLog(startDate: startTime ?? Date(), pet: pet, executorId: executorId)
        walkLog.endDate = Date()
        let distanceMeters = locationManager.totalDistance
        walkLog.distanceMeters = distanceMeters
        
        let routeLocations = locationManager.routeLocationsForPersistence()
        let routeCoordinates = routeLocations.map(\.coordinate)
        let coordinates = routeLocations.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude]
        }
        walkLog.routeLocationsData = try? JSONSerialization.data(withJSONObject: coordinates)

        lastCompletedPetId = pet.id
        lastCompletedWalk = walkLog
        lastCompletedRouteCoordinates = routeCoordinates
        
        generateMapSnapshot(for: walkLog, routeLocations: routeLocations, modelContext: modelContext)
        
        // 保存便便记录（对应 poopCount 次）
        for _ in 0..<poop {
            let pottyLog = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
            modelContext.insert(pottyLog)
        }
        
        // N2/Phase54: 遛狗椰子奖励（距离 < 20m 不发放奖励，日志正常保存）
        let minimumRewardDistance: Double = 20.0
        let earnedCoconuts = distanceMeters >= minimumRewardDistance
            ? PetWalkLog.coconuts(for: distanceMeters)
            : 0
        walkLog.coconutsEarned = earnedCoconuts
        let isTooShortForReward = distanceMeters < minimumRewardDistance
        if !isTooShortForReward {
            QuestManager.shared.awardAction(
                type: .walk(distanceMeters: distanceMeters),
                pet: pet,
                context: modelContext
            )
        }
        // 遛狗中每次便便：人+2, 宠物+5（OhanaActionType.potty(isLitter:false)）
        if poop > 0 {
            for _ in 0..<poop {
                QuestManager.shared.awardAction(
                    type: .potty(isLitter: false),
                    pet: pet,
                    context: modelContext
                )
            }
        }

        modelContext.insert(walkLog)
        modelContext.safeSave()

        phase = .finished(elapsed: elapsed, poopCount: poop)
        showSummary = true
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
    }

    func pauseForAppBackground() {
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
            locationManager.stopAllLocationActivity()
            return
        }
        if locationManager.canContinueCurrentWalkInBackground {
            return
        }
        pauseForAppBackground()
    }
    
    func addPoop() {
        poopCount += 1
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let r = self.resumeTime else { return }
            self.elapsedTime = self.pausedElapsed + Date().timeIntervalSince(r)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Map Snapshot
    private func generateMapSnapshot(for walkLog: PetWalkLog, routeLocations: [CLLocation], modelContext: ModelContext) {
        let locations = routeLocations
        guard locations.count >= 2 else { return }
        
        let coordinates = locations.map(\.coordinate)
        var region = MKCoordinateRegion()
        
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
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
                
                let path = UIBezierPath()
                for (i, coord) in coordinates.enumerated() {
                    let point = snapshot.point(for: coord)
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                
                UIColor.systemBlue.setStroke()
                path.lineWidth = 3
                path.stroke()
                
                // 起点绿点
                let startPoint = snapshot.point(for: coordinates.first!)
                UIColor.green.setFill()
                UIBezierPath(arcCenter: startPoint, radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
                
                // 终点蓝点
                let endPoint = snapshot.point(for: coordinates.last!)
                UIColor.blue.setFill()
                UIBezierPath(arcCenter: endPoint, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
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
