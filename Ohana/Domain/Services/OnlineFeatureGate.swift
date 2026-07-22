//
//  OnlineFeatureGate.swift
//  Ohana
//
//  Single launch decision point for future paid online collaboration.
//

import Foundation

enum OnlineFeature: String, CaseIterable, Sendable {
    case onlineCollaboration
    case guardianSafety
}

enum OnlineFeatureGate {
    nonisolated static func allows(_ feature: OnlineFeature) -> Bool {
        switch feature {
        case .onlineCollaboration:
            AppCapabilityProfile.shipsCloudFamilyCapabilities && false
        case .guardianSafety:
            // The build contains the client, but the shipped Info.plist keeps
            // this off until the signed backend/APNs release gate is complete.
            GuardianSafetyConfiguration.current != nil
        }
    }
}
