//
//  HumanHealthKitManager.swift
//  Ohana
//
//  Feature-local mock HealthKit bridge for human workout surfaces.
//

import Combine
import SwiftUI

@MainActor
final class HumanHealthKitManager: ObservableObject {
    @Published var authStatus: Int = 0
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Int = 0
    @Published var todayDistanceKm: Double = 0
    @Published var recentWorkouts: [String] = []
    @Published var isAvailable = false
    @Published var rewardToast: RewardToast?

    struct RewardToast: Equatable {
        let message: String
        let color: Color
    }

    func requestAuthorization() async {
        print("HealthKit is mocked as under development")
    }

    func fetchTodayStats(pets: [Pet] = []) async {
        todaySteps = 0
        todayCalories = 0
        todayDistanceKm = 0
    }

    func fetchRecentWorkouts() async {
        recentWorkouts = []
    }

    func workoutTypeName(_ workout: String) -> String {
        "运动"
    }

    func workoutIcon(_ workout: String) -> String {
        "sparkles"
    }

    func workoutColorHex(_ workout: String) -> String {
        "FFF44F"
    }
}
