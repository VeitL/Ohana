//
//  CoconutBalanceCapsule.swift
//  Ohana
//

import SwiftUI
#if os(iOS)
    import UIKit
#endif

// MARK: - Global Coconut Balance Capsule
struct CoconutBalanceCapsule: View {
    @State private var previousCount: Int
    @State private var pulse = false
    @State private var contextHandoffPulse = false
    @State private var floatingDelta: Int? = nil
    @State private var floatingDeltaProgress: CGFloat = 1
    @State private var floatingDeltaToken = 0
    @State private var contextHandoffToken = 0
    private let balanceOverride: Int?
    private let showsDeltaAnimation: Bool
    private let deltaAnimationContext: String
    let onTap: () -> Void

    init(
        balance: Int? = nil,
        showsDeltaAnimation: Bool? = nil,
        deltaAnimationContext: String? = nil,
        onTap: @escaping () -> Void = {}
    ) {
        self.balanceOverride = balance
        self.showsDeltaAnimation = showsDeltaAnimation ?? true
        self.deltaAnimationContext = deltaAnimationContext ?? "global"
        self.onTap = onTap
        _previousCount = State(initialValue: balance ?? 0)
    }

    private var visibleCount: Int {
        balanceOverride ?? 0
    }

    private var deltaState: CoconutBalanceDeltaState {
        CoconutBalanceDeltaState(count: visibleCount, context: deltaAnimationContext)
    }

    private var capsuleCore: some View {
        HStack(spacing: 3) {
            Text("🥥").font(OhanaFont.metric(size: 9, .medium))
            Text("\(visibleCount)")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .ohanaNumericMotion(visibleCount)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .frame(height: 26)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.goPrimary, in: Capsule())
        .scaleEffect(pulse ? 1.12 : (contextHandoffPulse ? 1.045 : 1.0))
        .overlay(alignment: .bottom) {
            if let delta = floatingDelta, delta != 0 {
                floatingDeltaLabel(delta)
                    .offset(y: floatingDeltaOffsetY)
                    .scaleEffect(pulse ? 1.035 : 1)
                    .opacity(floatingDeltaOpacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(GoMotion.feedback, value: pulse)
        .animation(GoMotion.feedback, value: contextHandoffPulse)
    }

    private var floatingDeltaOffsetY: CGFloat {
        let eased = floatingDeltaEase(floatingDeltaProgress)
        return 18 + (-22 - 18) * eased
    }

    private var floatingDeltaOpacity: Double {
        let eased = floatingDeltaEase(floatingDeltaProgress)
        return Double(max(0, 1 - eased))
    }

    private func floatingDeltaLabel(_ delta: Int) -> some View {
        let tint = delta > 0 ? Color.goLime : Color.goRed
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(OhanaFont.subheadline(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("🥥")
                .font(OhanaFont.caption())
        }
        .foregroundStyle(tint)
        .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4) // ui-v4: allow minimal floating balance delta
    }

    var body: some View {
        Button(action: onTap) {
            capsuleCore
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            previousCount = visibleCount
        }
        .onChange(of: deltaState) { oldValue, newValue in
            let delta = newValue.count - oldValue.count
            previousCount = newValue.count
            guard showsDeltaAnimation else {
                resetFloatingDelta()
                return
            }
            guard oldValue.context == newValue.context else {
                showContextHandoff()
                return
            }
            guard delta != 0 else { return }
            showFloatingDelta(delta)
        }
    }

    private func showFloatingDelta(_ delta: Int) {
        let isInFlight = floatingDelta != nil && floatingDeltaProgress < 1
        let nextDelta = (isInFlight ? (floatingDelta ?? 0) : 0) + delta
        floatingDelta = nextDelta == 0 ? delta : nextDelta
        floatingDeltaToken += 1
        let token = floatingDeltaToken
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floatingDeltaProgress = 0
        }
        withAnimation(GoMotion.feedback) {
            pulse = true
        }
        withAnimation(.easeOut(duration: 1.12)) { // ui-v4: allow one-shot floating balance delta drift
            floatingDeltaProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard token == floatingDeltaToken else { return }
            withAnimation(GoMotion.feedback) {
                pulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.16) {
            guard token == floatingDeltaToken else { return }
            resetFloatingDelta()
        }
    }

    private func showContextHandoff() {
        resetFloatingDelta()
        contextHandoffToken += 1
        let token = contextHandoffToken
        withAnimation(GoMotion.feedback) {
            contextHandoffPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard token == contextHandoffToken else { return }
            withAnimation(GoMotion.feedback) {
                contextHandoffPulse = false
            }
        }
    }

    private func resetFloatingDelta() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floatingDelta = nil
            pulse = false
            contextHandoffPulse = false
            floatingDeltaProgress = 1
        }
    }

    private func floatingDeltaEase(_ value: CGFloat) -> CGFloat {
        let x = min(max(value, 0), 1)
        return 1 - pow(1 - x, 3)
    }
}

private struct CoconutBalanceDeltaState: Equatable {
    let count: Int
    let context: String
}
