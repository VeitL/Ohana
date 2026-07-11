//
//  SurfaceActivityGate.swift
//  Ohana
//
//  Small visibility contract for high-frequency surfaces.
//

import Foundation

struct SurfaceActivityGate: Equatable {
    let isVisible: Bool
    let isCovered: Bool
    let isLive: Bool
    let allowsInteraction: Bool
    let allowsAmbientMotion: Bool
    let allowsRefresh: Bool

    static let inactive = SurfaceActivityGate(
        isVisible: false,
        isCovered: true,
        isLive: false,
        allowsInteraction: false,
        allowsAmbientMotion: false,
        allowsRefresh: false
    )
}

extension AppWorkloadPolicy {
    func surfaceGate(
        isVisible: Bool,
        isCovered: Bool = false,
        isLive: Bool = true,
        allowsAmbientOptIn: Bool = true,
        allowDuringActiveWalk: Bool = false
    ) -> SurfaceActivityGate {
        let active = isVisible && !isCovered && isLive
        return SurfaceActivityGate(
            isVisible: isVisible,
            isCovered: isCovered,
            isLive: isLive,
            allowsInteraction: active,
            allowsAmbientMotion: active
                && allowsAmbientOptIn
                && ambientMotionBudget(
                    isVisible: active,
                    allowDuringActiveWalk: allowDuringActiveWalk
                ).allowsMotion,
            allowsRefresh: refreshBudget(
                isVisible: active,
                allowDuringActiveWalk: allowDuringActiveWalk
            ) != .paused
        )
    }
}
