//
//  PlantFeatureGate.swift
//  Ohana
//
//  Launch gate for the plant feature surface.
//

import Foundation

enum PlantFeature: String, CaseIterable, Sendable {
    case plants
}

enum PlantFeatureGate {
    nonisolated static func allows(_ feature: PlantFeature) -> Bool {
        switch feature {
        case .plants:
            false
        }
    }
}
