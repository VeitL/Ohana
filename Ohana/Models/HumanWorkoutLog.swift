//
//  HumanWorkoutLog.swift
//  Ohana
//
//  U14: 人类运动记录

import SwiftData
import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case running    = "跑步"
    case walking    = "步行"
    case cycling    = "骑行"
    case swimming   = "游泳"
    case gym        = "健身"
    case yoga       = "瑜伽"
    case hiking     = "徒步"
    case other      = "其他"

    var icon: String {
        switch self {
        case .running:  return "figure.run"
        case .walking:  return "figure.walk"
        case .cycling:  return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .gym:      return "dumbbell.fill"
        case .yoga:     return "figure.mind.and.body"
        case .hiking:   return "mountain.2.fill"
        case .other:    return "sparkles"
        }
    }

    var colorHex: String {
        switch self {
        case .running:  return "C8FF00"
        case .walking:  return "80FFEA"
        case .cycling:  return "FF8C42"
        case .swimming: return "5B6AFF"
        case .gym:      return "FF4757"
        case .yoga:     return "B8A9C9"
        case .hiking:   return "00D4AA"
        case .other:    return "FFF44F"
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
        self.human = human
    }

    var workoutType: WorkoutType {
        WorkoutType(rawValue: typeRaw) ?? .other
    }
}
