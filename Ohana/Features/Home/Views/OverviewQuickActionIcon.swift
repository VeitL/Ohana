//
//  OverviewQuickActionIcon.swift
//  Ohana
//
//  Render-only duotone quick-action glyphs and one-shot semantic motion.
//

import SwiftUI

nonisolated enum OhanaQuickActionIconStatePolicy {
    static func accentOpacity(isStateful: Bool, isInProgress: Bool, isCompleted: Bool) -> Double {
        guard isStateful else { return 1 }
        return isInProgress || isCompleted ? 1 : 0.16
    }

    static func animationTrigger(
        base: Int,
        isInProgress: Bool,
        isCompleted: Bool
    ) -> Int {
        let stateCode = isCompleted ? 2 : (isInProgress ? 1 : 0)
        return base &* 4 &+ stateCode
    }
}

struct OhanaQuickActionIcon: View {
    let actionType: String
    let fallbackSystemName: String
    var size: CGFloat = 32
    /// Accent color. Member-card callers pass the pet/human theme color.
    var color: Color = .goPrimary
    /// The approved quick-action artwork uses a white main silhouette on dark card surfaces.
    var primaryColor: Color = .goCardWhite
    var isStateful = false
    var isInProgress = false
    var isCompleted = false
    var showsCompletionBadge = false
    var animationTrigger = 0
    var animatesStateChanges = true

    private var glyphKind: OhanaQuickActionGlyphKind? {
        OhanaQuickActionGlyphKind.resolve(actionType: actionType, fallbackSystemName: fallbackSystemName)
    }

    private var restingAccentOpacity: Double {
        OhanaQuickActionIconStatePolicy.accentOpacity(
            isStateful: isStateful,
            isInProgress: isInProgress,
            isCompleted: isCompleted
        )
    }

    private var resolvedAnimationTrigger: Int {
        OhanaQuickActionIconStatePolicy.animationTrigger(
            base: animationTrigger,
            isInProgress: isInProgress,
            isCompleted: isCompleted
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            glyphLayer

            if showsCompletionBadge, isCompleted {
                completionBadge
                    .offset(x: size * 0.08, y: size * 0.08)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(GoMotion.stateChange, value: isCompleted)
        .animation(GoMotion.stateChange, value: isInProgress)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyphLayer: some View {
        if let glyphKind {
            OhanaQuickActionGlyphArtwork(
                kind: glyphKind,
                primaryColor: primaryColor,
                accentColor: color,
                restingAccentOpacity: restingAccentOpacity,
                animationTrigger: resolvedAnimationTrigger,
                animatesStateChanges: animatesStateChanges
            )
            .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size * 0.62, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(primaryColor, color.opacity(restingAccentOpacity))
                .frame(width: size, height: size)
        }
    }

    private var completionBadge: some View {
        let badgeSize = max(12, size * 0.36)
        return ZStack {
            Circle()
                .fill(color)
            Image(systemName: "checkmark") // a11y: allow decorative badge; surrounding button exposes completion state.
                .accessibilityHidden(true)
                .font(.system(size: badgeSize * 0.52, weight: .black))
                .foregroundStyle(primaryColor)
        }
        .frame(width: badgeSize, height: badgeSize)
        .overlay {
            Circle()
                .strokeBorder(Color.ohanaCardSurface.opacity(0.85), lineWidth: max(1, size * 0.035))
        }
    }
}

enum OhanaQuickActionAccentMotionKind: Equatable, Sendable {
    case drop
    case step
    case float
    case sweep
    case gauge
    case bounce
    case pulse
    case confirm
    case tilt
    case waterDrop
    case waterChange
    case litterScoop
    case temperatureMercury
    case sleep
}

private enum OhanaQuickActionAccentPhase: CaseIterable {
    case resting
    case anticipation
    case peak
    case rebound
    case settled
}

private struct OhanaQuickActionMotionTransform {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
}

struct OhanaQuickActionAccentMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: OhanaQuickActionAccentMotionKind
    let elementIndex: Int
    let anchor: UnitPoint
    let restingOpacity: Double
    let trigger: Int
    let enabled: Bool
    let motionScale: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, !reduceMotion {
            content
                .phaseAnimator(OhanaQuickActionAccentPhase.allCases, trigger: trigger) { view, phase in
                    let transform = transform(for: phase)
                    view
                        .opacity(opacity(for: phase))
                        .scaleEffect(
                            x: transform.scaleX,
                            y: transform.scaleY,
                            anchor: anchor
                        )
                        .rotationEffect(.degrees(transform.rotation), anchor: anchor)
                        .offset(x: transform.x * motionScale, y: transform.y * motionScale)
                } animation: { phase in
                    animation(for: phase)
                }
        } else {
            content
                .opacity(restingOpacity)
                .animation(GoMotion.reduced, value: restingOpacity)
        }
    }

    private func opacity(for phase: OhanaQuickActionAccentPhase) -> Double {
        switch phase {
        case .resting, .settled:
            restingOpacity
        case .anticipation:
            max(restingOpacity, 0.28)
        case .peak, .rebound:
            1
        }
    }

    private func animation(for phase: OhanaQuickActionAccentPhase) -> Animation {
        let delay = phase == .anticipation ? min(Double(elementIndex) * 0.055, 0.22) : 0
        switch phase {
        case .resting:
            return GoMotion.reduced
        case .anticipation:
            return .timingCurve(0.18, 0.92, 0.24, 1, duration: 0.12).delay(delay)
        case .peak:
            return .timingCurve(0.18, 0.92, 0.24, 1, duration: 0.18)
        case .rebound:
            return .timingCurve(0.2, 0.84, 0.25, 1, duration: 0.14)
        case .settled:
            return .timingCurve(0.2, 0.82, 0.25, 1, duration: 0.12)
        }
    }

    private func transform(for phase: OhanaQuickActionAccentPhase) -> OhanaQuickActionMotionTransform {
        switch kind {
        case .drop:
            switch phase {
            case .anticipation: return .init(y: -7, scaleX: 0.58, scaleY: 0.58)
            case .peak: return .init(y: 1, scaleX: 1.12, scaleY: 1.12)
            default: return .init()
            }
        case .step:
            switch phase {
            case .anticipation: return .init(x: -2, y: -1, rotation: -6)
            case .peak: return .init(x: 2, rotation: 4)
            default: return .init()
            }
        case .float:
            switch phase {
            case .anticipation: return .init(y: -4, scaleX: 1.06, scaleY: 1.06)
            case .peak: return .init(y: 1, scaleX: 0.96, scaleY: 0.96)
            default: return .init()
            }
        case .sweep:
            switch phase {
            case .anticipation: return .init(x: -3, rotation: -7)
            case .peak: return .init(x: 3, rotation: 6)
            case .rebound: return .init(x: -1, rotation: -2)
            default: return .init()
            }
        case .gauge:
            switch phase {
            case .anticipation: return .init(rotation: -18, scaleX: 0.9, scaleY: 0.9)
            case .peak: return .init(rotation: 9, scaleX: 1.08, scaleY: 1.08)
            case .rebound: return .init(rotation: -4)
            default: return .init()
            }
        case .bounce:
            switch phase {
            case .anticipation: return .init(y: 1, rotation: 5, scaleX: 1.05, scaleY: 0.94)
            case .peak: return .init(y: -5, rotation: 18, scaleX: 0.98, scaleY: 1.03)
            case .rebound: return .init(y: 1, rotation: 30, scaleX: 1.04, scaleY: 0.95)
            default: return .init()
            }
        case .pulse, .confirm:
            switch phase {
            case .anticipation: return .init(scaleX: 0.48, scaleY: 0.48)
            case .peak: return .init(scaleX: 1.16, scaleY: 1.16)
            default: return .init()
            }
        case .tilt:
            switch phase {
            case .anticipation: return .init(rotation: -8, scaleX: 0.96, scaleY: 0.96)
            case .peak: return .init(rotation: 5, scaleX: 1.04, scaleY: 1.04)
            default: return .init()
            }
        case .waterDrop:
            switch phase {
            case .anticipation: return .init(y: -6, scaleX: 0.72, scaleY: 0.72)
            case .peak: return .init(y: 1, scaleX: 1.08, scaleY: 1.08)
            default: return .init()
            }
        case .waterChange:
            switch phase {
            case .peak: return .init(rotation: 18)
            default: return .init()
            }
        case .litterScoop:
            switch phase {
            case .resting, .settled: return .init(rotation: 18)
            case .anticipation: return .init(x: -2, y: 2, rotation: 10)
            case .peak: return .init(x: 1, y: -1, rotation: 22)
            case .rebound: return .init(rotation: 16)
            }
        case .temperatureMercury:
            switch phase {
            case .anticipation: return .init(scaleY: 0.48)
            case .peak: return .init(scaleY: 1.08)
            default: return .init()
            }
        case .sleep:
            switch phase {
            case .anticipation: return .init(y: 2, scaleX: 0.7, scaleY: 0.7)
            case .peak: return .init(x: 1, y: -3, scaleX: 1.08, scaleY: 1.08)
            default: return .init()
            }
        }
    }
}
