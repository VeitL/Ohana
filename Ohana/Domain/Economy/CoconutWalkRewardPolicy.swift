//
//  CoconutWalkRewardPolicy.swift
//  Ohana
//
//  Domain-level walk reward thresholds and split policy.
//

import Foundation

enum CoconutWalkRewardPolicy {
    static let minimumRewardDistanceMeters = 20.0

    static func isRewardable(distanceMeters: Double) -> Bool {
        distanceMeters >= minimumRewardDistanceMeters
    }

    static func baseGrowthXP(for distanceMeters: Double) -> Int {
        min(20, max(8, Int(max(0, distanceMeters) / 250)))
    }

    static func baseCoconuts(for distanceMeters: Double) -> Int {
        min(14, max(5, Int(max(0, distanceMeters) / 350)))
    }

    static func earnedCoconuts(for distanceMeters: Double) -> Int {
        isRewardable(distanceMeters: distanceMeters) ? baseCoconuts(for: distanceMeters) : 0
    }

    static func splitCoconuts(total: Int) -> (human: Int, pet: Int) {
        guard total > 0 else { return (0, 0) }
        let pet = max(1, total / 3)
        return (total - pet, pet)
    }
}
