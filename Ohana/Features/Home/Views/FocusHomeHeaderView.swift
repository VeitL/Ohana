//
//  FocusHomeHeaderView.swift
//  Ohana
//
//  Top chrome for the wallet home screen.
//

import SwiftUI

struct FocusHomeToolbar: ToolbarContent {
    let selectedTab: VerticalSolidHomeTab
    let coconutBalance: Int?
    let activeHumanDisplayName: String
    let primaryActionIcon: String
    let primaryActionAccessibilityLabel: String
    let localization: L10n
    let onCoconut: () -> Void
    let onPrimaryAction: () -> Void
    let onOpenPlantData: () -> Void
    let onCrew: () -> Void
    let onAccountSwitcher: () -> Void
    let onSettings: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onCoconut) {
                FocusHomeCoconutToolbarLabel(balance: coconutBalance)
            }
            .accessibilityLabel(coconutBalanceAccessibilityLabel)
            .accessibilityIdentifier("home-coconut-action")
            .disabled(coconutBalance == nil)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if selectedTab == .home {
                Menu {
                    Button(action: onAccountSwitcher) {
                        Label(
                            localization.tr(zh: "切换人类账户", en: "Switch human account", de: "Menschenkonto wechseln"),
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                } label: {
                    Image(systemName: "person.2.fill") // a11y: allow parent Menu provides the localized label
                        .accessibilityHidden(true)
                } primaryAction: {
                    onCrew()
                }
                .accessibilityLabel(localization.tr(
                    zh: "Ohana 成员",
                    en: "Ohana members",
                    de: "Ohana-Mitglieder"
                ))
                .accessibilityHint(localization.tr(
                    zh: "点击打开成员名册，长按切换人类账户",
                    en: "Tap to open the roster. Long press to switch human account.",
                    de: "Tippen öffnet die Mitgliederliste. Lange drücken wechselt das Menschenkonto."
                ))
                .accessibilityIdentifier("home-crew-roster-action")
            }

            if selectedTab == .plants {
                Menu {
                    Button {
                        OhanaFeedback.light()
                        onPrimaryAction()
                    } label: {
                        Label(
                            localization.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"),
                            systemImage: "plus"
                        )
                    }
                    .accessibilityIdentifier("home-add-plant-action")

                    Button {
                        OhanaFeedback.light()
                        onOpenPlantData()
                    } label: {
                        Label(
                            localization.tr(zh: "植物数据", en: "Plant data", de: "Pflanzendaten"),
                            systemImage: "chart.bar.xaxis"
                        )
                    }
                    .accessibilityIdentifier("home-plant-data-action")
                } label: {
                    Label(primaryActionAccessibilityLabel, systemImage: primaryActionIcon)
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel(primaryActionAccessibilityLabel)
                .accessibilityIdentifier("home-primary-action")
            } else if selectedTab != .oasis {
                Button {
                    OhanaFeedback.light()
                    onPrimaryAction()
                } label: {
                    Label(primaryActionAccessibilityLabel, systemImage: primaryActionIcon)
                        .labelStyle(.iconOnly)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(primaryActionAccessibilityLabel)
                .accessibilityIdentifier("home-primary-action")
            }

            Button {
                OhanaFeedback.light()
                onSettings()
            } label: {
                Image(systemName: "gearshape") // a11y: allow parent Button provides the localized label
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(localization.tr(
                zh: "设置，当前用户 \(activeHumanDisplayName)",
                en: "Settings, current user \(activeHumanDisplayName)",
                de: "Einstellungen, aktueller Nutzer \(activeHumanDisplayName)"
            ))
            .accessibilityIdentifier("home-settings-action")
        }
    }

    private var coconutBalanceAccessibilityLabel: String {
        guard let coconutBalance else {
            return localization.tr(
                zh: "正在读取椰子余额",
                en: "Loading coconut balance",
                de: "Kokosnussguthaben wird geladen"
            )
        }
        return localization.tr(
            zh: "椰子余额 \(coconutBalance)",
            en: "Coconut balance \(coconutBalance)",
            de: "Kokosnussguthaben \(coconutBalance)"
        )
    }
}

private struct FocusHomeCoconutToolbarLabel: View {
    let balance: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            Text("🥥")
                .accessibilityHidden(true)
            if let balance {
                Text("\(balance)")
                    .monospacedDigit()
                    .ohanaNumericMotion(balance)
            } else {
                Text("…")
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .animation(reduceMotion ? GoMotion.reduced : GoMotion.feedback, value: balance)
    }
}

struct FocusHomeHeaderView: View {
    let safeTop: CGFloat
    let topGap: CGFloat
    let contentHeight: CGFloat
    let coconutBalance: Int
    let coconutDeltaContext: String?
    let activeHumanDisplayName: String
    let activeHumanAvatarImage: UIImage?
    let activeHumanAvatarEmoji: String?
    let primaryActionIcon: String
    let primaryActionAccessibilityLabel: String
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    let onCoconut: () -> Void
    let onCrew: () -> Void
    let onAccountSwitcher: () -> Void
    let onCalendar: () -> Void
    let onSettings: () -> Void
    let onPrimaryAction: () -> Void

    init(
        safeTop: CGFloat,
        topGap: CGFloat = 12,
        contentHeight: CGFloat = 44,
        coconutBalance: Int,
        coconutDeltaContext: String? = nil,
        activeHumanDisplayName: String,
        activeHumanAvatarImage: UIImage?,
        activeHumanAvatarEmoji: String?,
        primaryActionIcon: String,
        primaryActionAccessibilityLabel: String,
        onCoconut: @escaping () -> Void,
        onCrew: @escaping () -> Void,
        onAccountSwitcher: @escaping () -> Void,
        onCalendar: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void
    ) {
        self.safeTop = safeTop
        self.topGap = topGap
        self.contentHeight = contentHeight
        self.coconutBalance = coconutBalance
        self.coconutDeltaContext = coconutDeltaContext
        self.activeHumanDisplayName = activeHumanDisplayName
        self.activeHumanAvatarImage = activeHumanAvatarImage
        self.activeHumanAvatarEmoji = activeHumanAvatarEmoji
        self.primaryActionIcon = primaryActionIcon
        self.primaryActionAccessibilityLabel = primaryActionAccessibilityLabel
        self.onCoconut = onCoconut
        self.onCrew = onCrew
        self.onAccountSwitcher = onAccountSwitcher
        self.onCalendar = onCalendar
        self.onSettings = onSettings
        self.onPrimaryAction = onPrimaryAction
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 8) {
                CoconutBalanceCapsule(
                    balance: coconutBalance,
                    deltaAnimationContext: coconutDeltaContext,
                    onTap: onCoconut
                )
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    OhanaFeedback.medium()
                    onPrimaryAction()
                } label: {
                    primaryActionButton
                }
                .buttonStyle(ScaleButtonStyle())
                .background(headerHitSlop)
                .contentShape(Rectangle())
                .accessibilityLabel(primaryActionAccessibilityLabel)
                .accessibilityIdentifier("home-primary-action")

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

    private var primaryActionButton: some View {
        Image(systemName: primaryActionIcon) // a11y: allow decorative symbol inside the labeled 44pt toolbar button
            .font(OhanaFont.adaptive(size: 12, weight: .black))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 26, height: 26) // a11y: allow visual glyph frame; parent button owns the 44pt hit target
            .background(Color.goPrimary, in: Circle())
            .contentTransition(.symbolEffect(.replace))
            .animation(GoMotion.selection, value: primaryActionIcon)
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
