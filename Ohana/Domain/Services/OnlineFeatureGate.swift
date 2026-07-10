//
//  OnlineFeatureGate.swift
//  Ohana
//
//  Single launch decision point for future paid online collaboration.
//

import Foundation

enum OnlineFeature: String, CaseIterable, Sendable {
    case onlineCollaboration
}

enum OnlineFeatureGate {
    nonisolated static func allows(_ feature: OnlineFeature) -> Bool {
        guard AppCapabilityProfile.shipsCloudFamilyCapabilities else {
            return false
        }

        switch feature {
        case .onlineCollaboration:
            return false
        }
    }
}
