//
//  HumanWorkoutLog.swift
//  Ohana
//
//  U14: 人类运动记录

import Foundation
import SwiftData

enum WorkoutType: String, Codable, CaseIterable, Sendable {
    case running = "跑步"
    case walking = "步行"
    case cycling = "骑行"
    case swimming = "游泳"
    case gym = "健身"
    case yoga = "瑜伽"
    case hiking = "徒步"
    case other = "其他"

    var icon: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .gym: "dumbbell.fill"
        case .yoga: "figure.mind.and.body"
        case .hiking: "mountain.2.fill"
        case .other: "sparkles"
        }
    }

    var colorHex: String {
        switch self {
        case .running: "F97316"
        case .walking: "80FFEA"
        case .cycling: "FF8C42"
        case .swimming: "5B6AFF"
        case .gym: "FF4757"
        case .yoga: "B8A9C9"
        case .hiking: "00D4AA"
        case .other: "FFF44F"
        }
    }
}

@Model
final class HumanWorkoutLog {
    var id: UUID
    var date: Date
    var typeRaw: String
    var durationMinutes: Int
    var distanceKm: Double
    var calories: Int
    var steps: Int
    var notes: String
    var sourceHealthKit: Bool
    var healthKitWorkoutUUID: String = ""
    var healthKitSourceBundleID: String = ""
    var healthKitSourceName: String = ""
    var sourcePetWalkLogID: String = ""
    var human: Human?

    init(
        date: Date = Date(),
        type: WorkoutType = .walking,
        durationMinutes: Int = 0,
        distanceKm: Double = 0,
        calories: Int = 0,
        steps: Int = 0,
        notes: String = "",
        sourceHealthKit: Bool = false,
        healthKitWorkoutUUID: String = "",
        healthKitSourceBundleID: String = "",
        healthKitSourceName: String = "",
        sourcePetWalkLogID: String = "",
        human: Human? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.typeRaw = type.rawValue
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.calories = calories
        self.steps = steps
        self.notes = notes
        self.sourceHealthKit = sourceHealthKit
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.healthKitSourceBundleID = healthKitSourceBundleID
        self.healthKitSourceName = healthKitSourceName
        self.sourcePetWalkLogID = sourcePetWalkLogID
        self.human = human
    }

    var workoutType: WorkoutType {
        WorkoutType(rawValue: typeRaw) ?? .other
    }
}
