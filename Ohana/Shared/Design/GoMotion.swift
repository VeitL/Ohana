//
//  GoMotion.swift
//  Ohana
//

import SwiftUI

// MARK: - GO Motion Tokens
enum GoMotion {
    static let page: Animation = .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.26)
    static let hero: Animation = .interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.22)
    static let fab: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.18)
    static let feedback: Animation = .interactiveSpring(response: 0.24, dampingFraction: 0.82, blendDuration: 0.10)
    static let quick: Animation = .easeOut(duration: 0.18)
    static let reduced: Animation = .easeInOut(duration: 0.12)
    static let tap: Animation = .interactiveSpring(response: 0.18, dampingFraction: 0.84, blendDuration: 0.08)
    static let selection: Animation = .interactiveSpring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.16)
    static let stateChange: Animation = .interactiveSpring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.18)
    static let sheet: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.22)
    static let heroExpand: Animation = .interactiveSpring(response: 0.62, dampingFraction: 0.91, blendDuration: 0.18)
    static let heroCollapse: Animation = .interactiveSpring(response: 0.54, dampingFraction: 0.94, blendDuration: 0.14)
    static let heroAvatarParallax: Animation = .interactiveSpring(response: 0.50, dampingFraction: 0.84, blendDuration: 0.12)
    static let sheetEnter: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.22)
    static let rewardPop: Animation = .interactiveSpring(response: 0.30, dampingFraction: 0.72, blendDuration: 0.12)
    static let zStackHero: Animation = .interactiveSpring(response: 0.62, dampingFraction: 0.92, blendDuration: 0.18)
    static let zStackMenu: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.16)
    static let zStackPopup: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.20)

    static func staggerDelay(_ index: Int, step: Double = 0.035, maxDelay: Double = 0.24) -> Double {
        min(Double(max(index, 0)) * step, maxDelay)
    }
}

enum HomeJoinHandoffMotion {
    static let scale: CGFloat = 0.58
    static let rotation: CGFloat = 6
    static let flip: CGFloat = -28
    static let y: CGFloat = 86
    static let opacity: CGFloat = 0.72
}
