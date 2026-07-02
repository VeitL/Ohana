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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

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

    private var l: L10n { L10n(appLanguage) }

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
                .accessibilityLabel(l.tr(zh: "连续打卡 \(streak) 天", en: "\(streak)-day streak", de: "\(streak)-Tage-Serie"))
                .accessibilityIdentifier("home-streak-action")

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
                .accessibilityLabel(l.tr(zh: "Ohana 成员", en: "Ohana members", de: "Ohana-Mitglieder"))
                .accessibilityHint(l.tr(zh: "点击打开成员名册，长按切换人类账户", en: "Tap to open the roster. Long press to switch human account.", de: "Tippen öffnet die Mitgliederliste. Lange drücken wechselt das Menschenkonto."))
                .accessibilityIdentifier("home-crew-roster-action")

                Button {
                    OhanaFeedback.light()
                    onSettings()
                } label: {
                    settingsPill
                }
                .buttonStyle(ScaleButtonStyle())
                .background(headerHitSlop)
                .contentShape(Rectangle())
                .accessibilityLabel(l.tr(zh: "设置，当前用户 \(activeHumanDisplayName)", en: "Settings, current user \(activeHumanDisplayName)", de: "Einstellungen, aktueller Nutzer \(activeHumanDisplayName)"))
                .accessibilityIdentifier("home-settings-action")
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

    private func limePill(@ViewBuilder content: () -> some View) -> some View {
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
