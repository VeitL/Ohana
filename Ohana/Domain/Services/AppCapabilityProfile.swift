//
//  AppCapabilityProfile.swift
//  Ohana
//
//  Compile-time capability boundary for the shipping app profile.
//

import Foundation

/// Compile-time boundary for the deferred CloudKit household-collaboration
/// runtime. The separate, minimum-data Family guardian uses ordinary APNs and
/// its own fail-closed `GuardianSafetyConfiguration`; it never enables this
/// CloudKit profile or uploads local household/care records.
nonisolated enum AppCapabilityProfile: Equatable, Sendable {
    case solo
    case family

    static var current: Self {
        #if OHANA_FAMILY_CAPABILITIES
            .family
        #elseif OHANA_SOLO_CAPABILITIES
            .solo
        #else
            // Fail closed if a configuration has not declared a profile yet.
            .solo
        #endif
    }

    static var shipsCloudFamilyCapabilities: Bool {
        current == .family
    }

    /// Runtime work requires both a signed Family profile and the product gate.
    static var permitsCloudSyncRuntime: Bool {
        shipsCloudFamilyCapabilities && OnlineFeatureGate.allows(.onlineCollaboration)
    }

    static var shippingPermitsCloudSyncDirtyWrites: Bool {
        permitsCloudSyncRuntime
    }

    /// Unit tests retain the CloudKit metadata pipeline as an isolated harness;
    /// this never enables it in an app process launched normally from Xcode or
    /// distributed to a customer.
    static var permitsCloudSyncDirtyWrites: Bool {
        if shippingPermitsCloudSyncDirtyWrites {
            return true
        }

        #if DEBUG
            return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
            return false
        #endif
    }
}
