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
    let treeLevel: Int
    let treeProgress: Double
    let appLanguage: String
    let coconutBalance: Int
    let coconutDeltaContext: String?
    let activeHumanDisplayName: String
    let activeHumanAvatarImage: UIImage?
    let activeHumanAvatarEmoji: String?

    let onStreak: () -> Void
    let onTreeLevel: () -> Void
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
        treeLevel: Int,
        treeProgress: Double,
        appLanguage: String,
        coconutBalance: Int,
        coconutDeltaContext: String? = nil,
        activeHumanDisplayName: String,
        activeHumanAvatarImage: UIImage?,
        activeHumanAvatarEmoji: String?,
        onStreak: @escaping () -> Void,
        onTreeLevel: @escaping () -> Void,
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
        self.treeLevel = treeLevel
        self.treeProgress = treeProgress
        self.appLanguage = appLanguage
        self.coconutBalance = coconutBalance
        self.coconutDeltaContext = coconutDeltaContext
        self.activeHumanDisplayName = activeHumanDisplayName
        self.activeHumanAvatarImage = activeHumanAvatarImage
        self.activeHumanAvatarEmoji = activeHumanAvatarEmoji
        self.onStreak = onStreak
        self.onTreeLevel = onTreeLevel
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

                Button(action: onTreeLevel) {
                    treeLevelPill
                }
                .buttonStyle(ScaleButtonStyle())
                .background(headerHitSlop)
                .contentShape(Rectangle())
                .accessibilityLabel(treeAccessibilityLabel)
                .accessibilityHint(treeAccessibilityHint)

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
                        Image(systemName: "person.2.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
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

    private var treeLevelPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
            Text("Lv.\(treeLevel)")
                .font(OhanaFont.caption2(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(GoMotion.feedback, value: treeLevel)
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(height: 26)
        .frame(minWidth: 58)
        .background(Color.goPrimary, in: Capsule())
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(Color.arkInk.opacity(0.14))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaPrimaryActionText.opacity(0.86))
                        .frame(width: max(8, 58 * clampedTreeProgress), height: 3)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 3)
                .accessibilityHidden(true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var settingsPill: some View {
        HStack(spacing: 5) {
            miniAvatar
            Text(activeHumanDisplayName)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Image(systemName: "gearshape.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
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
                    .frame(width: 20, height: 20) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .clipShape(Circle())
            }
        } else if let emoji = activeHumanAvatarEmoji, !emoji.isEmpty {
            ZStack {
                Circle()
                    .fill(Color.arkInk.opacity(0.12))
                    .frame(width: 20, height: 20) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(emoji)
                    .font(OhanaFont.adaptive(size: 11))
            }
        } else {
            Image(systemName: "person.crop.circle.badge.exclamationmark").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .frame(width: 20, height: 20) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
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

    private var clampedTreeProgress: CGFloat {
        CGFloat(min(1, max(0, treeProgress)))
    }

    private var treeAccessibilityLabel: String {
        localized(
            zh: "生命之树 \(treeLevel) 级",
            en: "Life Tree level \(treeLevel)",
            de: "Lebensbaum Stufe \(treeLevel)"
        )
    }

    private var treeAccessibilityHint: String {
        localized(
            zh: "点击查看当前成长阶段和功能解锁",
            en: "Opens the current growth stage and feature unlocks",
            de: "Öffnet die aktuelle Wachstumsstufe und Funktionsfreischaltungen"
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}
