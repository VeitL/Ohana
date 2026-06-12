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
        switch feature {
        case .onlineCollaboration:
            false
        }
    }
}
