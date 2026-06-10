//
//  TodayFocusCard+Presentation.swift
//  Ohana
//

import SwiftUI

extension TodayFocusCard {
    var boardBody: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "今日", en: "TODAY", de: "HEUTE"))
                            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.36))
                            .todayFocusReadableShadow(strength: 0.8)
                        Text(l.tr(zh: "任务盘", en: "Task board", de: "Aufgabenbrett"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
                            .todayFocusReadableShadow()
                    }
                    Spacer()
                    Text(focusStatusText)
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.ohanaControlFill, in: Capsule())
                        .contentTransition(.numericText())
                        .animation(GoMotion.feedback, value: focusStatusText)
                        .todayFocusReadableShadow(strength: 0.75)
                    if case .quest(let q) = content {
                        rewardChip(IslandQuestEngine.coconutReward(forQuestId: q.id))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 4)

                card(showsPageIndicator: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                    .id(contentIdentity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }

    var compactBody: some View {
        card(showsPageIndicator: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .transaction { transaction in
                if freezesToFrontCard {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }

    func startAmbientPulseIfNeeded() {
        guard !shouldReduceWork, !freezesToFrontCard else { return }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = 1 } // ui-v4: allow Today Focus ambient pulse micro-motion; runtime-guardrail: allow gated by Today Focus live state, explicit user opt-in, and AppWorkloadPolicy. // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounceEmoji = true } // ui-v4: allow Today Focus celebration bounce micro-motion; runtime-guardrail: allow gated by Today Focus live state, explicit user opt-in, and AppWorkloadPolicy. // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
    }
}
