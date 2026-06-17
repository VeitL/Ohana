//
//  CheckInRewardFeedback.swift
//  Ohana
//
//  Shared one-shot feedback for check-ins and coconut rewards.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class CoconutRewardFeedbackCenter: ObservableObject {
    @Published private(set) var activeEvent: OhanaCoconutRewardEvent?
    @Published private(set) var coalescedAmount = 0
    @Published private(set) var coalescedGrowthXP = 0

    private var hideTask: Task<Void, Never>?

    func enqueue(_ event: OhanaCoconutRewardEvent) {
        guard event.amount > 0 || event.growthXP > 0 else { return }
        let shouldMerge = activeEvent != nil
        activeEvent = event
        coalescedAmount = shouldMerge ? coalescedAmount + event.amount : event.amount
        coalescedGrowthXP = shouldMerge ? coalescedGrowthXP + event.growthXP : event.growthXP

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                self.activeEvent = nil
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            self.coalescedAmount = 0
            self.coalescedGrowthXP = 0
        }
    }
}

struct CoconutRewardFeedbackOverlay: View {
    @StateObject private var center = CoconutRewardFeedbackCenter()
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastHandledEventID: UUID?
    @State private var hapticTask: Task<Void, Never>?

    private var shouldAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var body: some View {
        let animate = shouldAnimate
        VStack {
            if let event = center.activeEvent {
                rewardPill(event)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.86).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
                    .padding(.top, 14)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .onReceive(appServices.domainRevisions.coconutRewardEvents) { event in
            guard lastHandledEventID != event.id else { return }
            lastHandledEventID = event.id
            center.enqueue(event)
            if animate {
                hapticTask?.cancel()
                hapticTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    hapticTask = nil
                }
            }
        }
        .onDisappear {
            hapticTask?.cancel()
            hapticTask = nil
        }
        .animation(animate ? GoMotion.feedback : GoMotion.reduced, value: center.activeEvent?.id)
    }

    private func rewardPill(_ event: OhanaCoconutRewardEvent) -> some View {
        HStack(spacing: 8) {
            Text(event.emoji)
                .font(OhanaFont.adaptive(size: 20))
            Text(rewardAmountText)
                .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
            Text(event.title)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.goYellow.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    private var rewardAmountText: String {
        let coconutText = center.coalescedAmount > 0 ? "+\(center.coalescedAmount)🥥" : nil
        let xpText = center.coalescedGrowthXP > 0 ? "+\(center.coalescedGrowthXP)XP" : nil
        return [coconutText, xpText].compactMap(\.self).joined(separator: " · ")
    }
}

struct CheckInFeedbackToken: Identifiable {
    enum Kind {
        case gain
        case loss
        case done
    }

    let id = UUID()
    let kind: Kind
    let deltaText: String
    let tint: Color
    let createdAt = Date()
}

struct CheckInFeedbackBadge: View {
    let token: CheckInFeedbackToken

    var body: some View {
        Text(token.deltaText)
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                token.tint,
                in: Capsule()
            )
            .contentTransition(.numericText())
            .transition(.scale(scale: 0.84).combined(with: .opacity))
    }
}

struct CheckInPulseModifier: ViewModifier {
    let token: CheckInFeedbackToken?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(token == nil || reduceMotion ? 1 : 1.025)
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.feedback, value: token?.id)
    }
}

extension View {
    func checkInPulse(_ token: CheckInFeedbackToken?) -> some View {
        modifier(CheckInPulseModifier(token: token))
    }
}
