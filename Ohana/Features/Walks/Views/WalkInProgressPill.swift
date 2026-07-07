//
//  WalkInProgressPill.swift
//  Ohana
//
//  巡岛最小化后的迷你胶囊：显示当前宠物 + 时长 + 重开按钮
//

import SwiftUI

struct WalkInProgressPill: View {
    let pet: Pet
    var onTap: () -> Void = {}

    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }
    private var mgr: PetWalkingManaging { appServices.walking }

    private var walkClockInterval: TimeInterval {
        workloadPolicy.refreshInterval(
            default: 1,
            throttled: 15,
            paused: 60,
            isVisible: true,
            allowDuringActiveWalk: true
        )
    }

    private var shouldRunWalkClock: Bool {
        workloadPolicy.refreshBudget(isVisible: true, allowDuringActiveWalk: true) != .paused
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                // 左：行走小人图标（脉动）
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.25))
                        .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    Image(systemName: "figure.walk.motion").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }

                // 中：宠物名 + 时长
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.tr(zh: "\(pet.name) 正在巡岛", en: "\(pet.name) is walking", de: "\(pet.name) ist unterwegs"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    walkElapsedLabel
                }

                Spacer(minLength: 0)

                // 右：展开箭头
                Image(systemName: "arrow.up.left.and.arrow.down.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 26, height: 26) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goPrimary.opacity(0.12), in: Circle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.ohanaCardSurface)
            )
            .overlay(
                Capsule().strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var walkElapsedLabel: some View {
        if shouldRunWalkClock {
            TimelineView(.periodic(from: .now, by: walkClockInterval)) { _ in
                walkElapsedText
            }
        } else {
            walkElapsedText
        }
    }

    private var walkElapsedText: some View {
        let elapsed = Int(mgr.elapsedTime)
        let m = elapsed / 60
        let s = elapsed % 60
        return Text(String(format: "已巡 %02d:%02d", m, s))
            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
