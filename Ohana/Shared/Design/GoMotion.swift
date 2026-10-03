//
//  GoMotion.swift
//  Ohana
//

import SwiftUI

// MARK: - GO Motion Tokens
enum GoMotion {
    // Shared interaction motion stays short and has no extra bounce. SwiftUI's
    // smooth spring remains interruptible when a user reverses direction.
    static let page: Animation = .smooth(duration: 0.24, extraBounce: 0)
    static let hero: Animation = .smooth(duration: 0.28, extraBounce: 0)
    static let fab: Animation = .smooth(duration: 0.20, extraBounce: 0)
    static let feedback: Animation = .smooth(duration: 0.16, extraBounce: 0)
    static let quick: Animation = .easeOut(duration: 0.16)
    static let reduced: Animation = .easeOut(duration: 0.10)
    static let tap: Animation = .smooth(duration: 0.12, extraBounce: 0)
    static let selection: Animation = .smooth(duration: 0.18, extraBounce: 0)
    static let stateChange: Animation = .smooth(duration: 0.20, extraBounce: 0)
    static let zenCardGlassDissolve: Animation = .timingCurve(0.20, 0.76, 0.24, 1.00, duration: 0.76)
    static let zenCardColorReveal: Animation = zenCardGlassDissolve
    static let sheet: Animation = .smooth(duration: 0.24, extraBounce: 0)
    static let heroExpand: Animation = .smooth(duration: 0.32, extraBounce: 0)
    static let heroCollapse: Animation = .smooth(duration: 0.26, extraBounce: 0)
    static let heroAvatarParallax: Animation = .smooth(duration: 0.24, extraBounce: 0)
    static let sheetEnter: Animation = .smooth(duration: 0.24, extraBounce: 0)
    static let rewardPop: Animation = .interactiveSpring(response: 0.30, dampingFraction: 0.72, blendDuration: 0.12)
    static let zStackHero: Animation = .smooth(duration: 0.32, extraBounce: 0)
    static let zStackMenu: Animation = .smooth(duration: 0.20, extraBounce: 0)
    static let zStackPopup: Animation = .smooth(duration: 0.22, extraBounce: 0)

    static func staggerDelay(_ index: Int, step: Double = 0.035, maxDelay: Double = 0.24) -> Double {
        min(Double(max(index, 0)) * step, maxDelay)
    }
}

enum HomeJoinHandoffMotion {
    static let scale: CGFloat = 0.985
    static let rotation: CGFloat = 0
    static let flip: CGFloat = 0
    static let y: CGFloat = 6
    static let opacity: CGFloat = 0.92
}
