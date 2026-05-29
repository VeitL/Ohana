//
//  FocusHomeHeaderView.swift
//  Ohana
//
//  Top chrome for the wallet home screen.
//

import SwiftUI

struct FocusHomeHeaderView: View {
    let safeTop: CGFloat
    let topGap: CGFloat
    let contentHeight: CGFloat
    let streak: Int
    let coconutBalance: Int
    let coconutDeltaContext: String?
    let activeHumanDisplayName: String
    let activeHumanAvatarImage: UIImage?
    let activeHumanAvatarEmoji: String?

    let onStreak: () -> Void
    let onCoconut: () -> Void
    let onCrew: () -> Void
    let onAccountSwitcher: () -> Void
    let onCalendar: () -> Void
    let onSettings: () -> Void

    init(
        safeTop: CGFloat,
        topGap: CGFloat = 12,
        contentHeight: CGFloat = 44,
        streak: Int,
        coconutBalance: Int,
        coconutDeltaContext: String? = nil,
        activeHumanDisplayName: String,
        activeHumanAvatarImage: UIImage?,
        activeHumanAvatarEmoji: String?,
        onStreak: @escaping () -> Void,
        onCoconut: @escaping () -> Void,
        onCrew: @escaping () -> Void,
        onAccountSwitcher: @escaping () -> Void,
        onCalendar: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.safeTop = safeTop
        self.topGap = topGap
        self.contentHeight = contentHeight
        self.streak = streak
        self.coconutBalance = coconutBalance
        self.coconutDeltaContext = coconutDeltaContext
        self.activeHumanDisplayName = activeHumanDisplayName
        self.activeHumanAvatarImage = activeHumanAvatarImage
        self.activeHumanAvatarEmoji = activeHumanAvatarEmoji
        self.onStreak = onStreak
        self.onCoconut = onCoconut
        self.onCrew = onCrew
        self.onAccountSwitcher = onAccountSwitcher
        self.onCalendar = onCalendar
        self.onSettings = onSettings
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onStreak) {
                    limePill {
                        Text("🔥")
                            .font(OhanaFont.metric(size: 9, .medium))
                        Text("\(streak)")
                            .font(OhanaFont.caption2(.black))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(GoMotion.feedback, value: streak)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("连续打卡 \(streak) 天")

                CoconutBalanceCapsule(
                    balance: coconutBalance,
                    deltaAnimationContext: coconutDeltaContext,
                    onTap: onCoconut
                )
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onCrew) {
                    limePill {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12, weight: .black))
                            .frame(width: 18)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .background(headerHitSlop)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            OhanaFeedback.medium()
                            onAccountSwitcher()
                        }
                )
                .accessibilityLabel("家庭协作")
                .accessibilityHint("点击打开家庭协作，长按切换人类账户")

                Button {
                    OhanaFeedback.light()
                    onSettings()
                } label: {
                    settingsPill
                }
                .buttonStyle(ScaleButtonStyle())
                .background(headerHitSlop)
                .contentShape(Rectangle())
                .accessibilityLabel("设置，当前用户 \(activeHumanDisplayName)")
            }
        }
        .padding(.horizontal, K.hPad)
        .padding(.top, safeTop + topGap)
        .frame(height: safeTop + topGap + contentHeight, alignment: .top)
    }

    private var settingsPill: some View {
        HStack(spacing: 5) {
            miniAvatar
            Text(activeHumanDisplayName)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(.leading, 4)
        .padding(.trailing, 7)
        .padding(.vertical, 3)
        .frame(height: 26)
        .frame(maxWidth: 104)
        .background(Color.goPrimary, in: Capsule())
    }

    @ViewBuilder
    private var miniAvatar: some View {
        if let image = activeHumanAvatarImage {
            ZStack {
                Circle()
                    .fill(Color.arkInk.opacity(0.12))
                    .frame(width: 20, height: 20)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            }
        } else if let emoji = activeHumanAvatarEmoji, !emoji.isEmpty {
            ZStack {
                Circle()
                    .fill(Color.arkInk.opacity(0.12))
                    .frame(width: 20, height: 20)
                Text(emoji)
                    .font(.system(size: 11))
            }
        } else {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 14, weight: .black))
                .frame(width: 20, height: 20)
        }
    }

    private func limePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 3) {
            content()
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(height: 26)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.goPrimary, in: Capsule())
    }

    private var headerHitSlop: some View {
        Color.clear
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}
