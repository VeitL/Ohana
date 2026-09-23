//
//  FocusHomeHeaderView.swift
//  Ohana
//
//  Top chrome for the wallet home screen.
//

import Combine
import SwiftUI

struct FocusHomeToolbar: ToolbarContent {
    let selectedTab: VerticalSolidHomeTab
    let coconutBalance: Int?
    let activeHumanDisplayName: String
    let primaryActionIcon: String
    let primaryActionAccessibilityLabel: String
    let showsHomePrimaryAction: Bool
    let localization: L10n
    let onCoconut: () -> Void
    let onPrimaryAction: () -> Void
    let onOpenAllFeatures: () -> Void
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
                    .accessibilityIdentifier("home-account-switcher-menu-action")
                } label: {
                    Text(activeHumanInitial)
                        .font(OhanaFont.callout(.black))
                        .frame(minWidth: 24)
                } primaryAction: {
                    onCrew()
                }
                .accessibilityLabel(crewAccessibilityLabel)
                .accessibilityHint(localization.tr(
                    zh: "点击打开成员名册，长按切换人类账户",
                    en: "Tap to open the roster. Long press to switch human account.",
                    de: "Tippen öffnet die Mitgliederliste. Lange drücken wechselt das Menschenkonto."
                ))
                .accessibilityIdentifier("home-crew-roster-action")
            }

            if selectedTab == .home, showsHomePrimaryAction {
                Menu {
                    Button {
                        OhanaFeedback.light()
                        onOpenAllFeatures()
                    } label: {
                        Label(
                            localization.tr(
                                zh: "全部功能",
                                en: "All Features",
                                de: "Alle Funktionen",
                                es: "Todas las funciones",
                                pt: "Todos os recursos",
                                fr: "Toutes les fonctions",
                                ja: "すべての機能",
                                ko: "모든 기능",
                                it: "Tutte le funzioni"
                            ),
                            systemImage: "square.grid.2x2.fill"
                        )
                    }
                    .accessibilityIdentifier("home-all-features-action")
                } label: {
                    Label(primaryActionAccessibilityLabel, systemImage: primaryActionIcon)
                        .labelStyle(.iconOnly)
                        .contentTransition(.symbolEffect(.replace))
                } primaryAction: {
                    OhanaFeedback.light()
                    onPrimaryAction()
                }
                .accessibilityLabel(primaryActionAccessibilityLabel)
                .accessibilityHint(localization.tr(
                    zh: "点击查看家庭洞察，长按打开全部功能",
                    en: "Tap for household insights. Long press for all features.",
                    de: "Tippen für Haushaltseinblicke. Lange drücken für alle Funktionen.",
                    es: "Toca para ver información del hogar. Mantén pulsado para ver todas las funciones.",
                    pt: "Toque para ver insights da casa. Mantenha pressionado para ver todos os recursos.",
                    fr: "Touchez pour les aperçus du foyer. Appui long pour toutes les fonctions.",
                    ja: "タップで世帯インサイト、長押しですべての機能を開きます。",
                    ko: "탭하면 가정 인사이트, 길게 누르면 모든 기능이 열립니다.",
                    it: "Tocca per gli insight della casa. Tieni premuto per tutte le funzioni."
                ))
                .accessibilityIdentifier("home-primary-action")
            } else if selectedTab == .plants {
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
            }
        }

        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarPinnedTrailing) {
                settingsButton
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
    }

    private var settingsButton: some View {
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

    private var activeHumanInitial: String {
        let name = activeHumanDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.first.map { String($0).uppercased() } ?? "?"
    }

    private var crewAccessibilityLabel: String {
        localization.tr(
            zh: "Ohana 成员，当前用户 \(activeHumanDisplayName)",
            en: "Ohana members, current user \(activeHumanDisplayName)",
            de: "Ohana-Mitglieder, aktueller Nutzer \(activeHumanDisplayName)",
            es: "Miembros de Ohana, usuario actual \(activeHumanDisplayName)",
            pt: "Membros da Ohana, utilizador atual \(activeHumanDisplayName)",
            fr: "Membres Ohana, profil actuel \(activeHumanDisplayName)",
            ja: "Ohanaメンバー、現在のユーザー \(activeHumanDisplayName)",
            ko: "Ohana 구성원, 현재 사용자 \(activeHumanDisplayName)",
            it: "Membri di Ohana, utente attuale \(activeHumanDisplayName)"
        )
    }
}

@MainActor
final class HomeQuickRecordActionRelay: ObservableObject {
    typealias Action = (HomeToolbarQuickRecordTarget, QuickActionItem?, String?) -> Void

    let objectWillChange = ObservableObjectPublisher()
    private var action: Action = { _, _, _ in }

    func update(action: @escaping Action) {
        self.action = action
    }

    func perform(
        target: HomeToolbarQuickRecordTarget,
        action: QuickActionItem?,
        optionID: String?
    ) {
        self.action(target, action, optionID)
    }
}

struct HomeQuickRecordMenu: View, Equatable {
    let selectedTab: VerticalSolidHomeTab
    let quickRecordTargets: [HomeToolbarQuickRecordTarget]
    let localization: L10n
    var unavailableAccessibilityHint: String?
    let actionRelay: HomeQuickRecordActionRelay

    static func == (lhs: HomeQuickRecordMenu, rhs: HomeQuickRecordMenu) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.quickRecordTargets == rhs.quickRecordTargets
            && lhs.localization.languageCode == rhs.localization.languageCode
            && lhs.unavailableAccessibilityHint == rhs.unavailableAccessibilityHint
            && lhs.actionRelay === rhs.actionRelay
    }

    var body: some View {
        Menu {
            if quickRecordTargets.isEmpty {
                Button(quickRecordEmptyTitle) {}
                    .disabled(true)
            } else {
                ForEach(HomeToolbarQuickRecordTarget.Kind.allCases) { kind in
                    let targets = quickRecordTargets.filter { $0.kind == kind }
                    if !targets.isEmpty {
                        Section(quickRecordSectionTitle(for: kind)) {
                            ForEach(targets) { target in
                                if target.kind == .plant {
                                    Button {
                                        actionRelay.perform(target: target, action: nil, optionID: nil)
                                    } label: {
                                        Label(target.name, systemImage: target.kind.systemImage)
                                    }
                                    .accessibilityLabel(quickRecordTargetAccessibilityLabel(target))
                                    .accessibilityIdentifier(target.accessibilityIdentifier)
                                } else {
                                    quickRecordMemberMenu(target)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "plus") // a11y: allow parent Menu provides the localized label
                .accessibilityHidden(true)
        }
        .accessibilityLabel(localization.tr(
            zh: "快速记录",
            en: "Quick log",
            de: "Schnell erfassen",
            es: "Registro rápido",
            pt: "Registro rápido",
            fr: "Saisie rapide",
            ja: "すばやく記録",
            ko: "빠르게 기록",
            it: "Registrazione rapida"
        ))
        .accessibilityHint(
            unavailableAccessibilityHint
                ?? (quickRecordTargets.isEmpty ? quickRecordEmptyTitle : quickRecordAccessibilityHint)
        )
        .accessibilityIdentifier("home-quick-record-action")
    }

    private func quickRecordMemberMenu(
        _ target: HomeToolbarQuickRecordTarget
    ) -> some View {
        Menu {
            ForEach(target.quickActions) { action in
                let options = HomeQuickActionOptionCatalog.options(
                    for: action.actionType,
                    localization: localization
                )
                if options.isEmpty {
                    Button {
                        actionRelay.perform(target: target, action: action, optionID: nil)
                    } label: {
                        Label(
                            action.displayLabel(localization: localization),
                            systemImage: action.icon
                        )
                    }
                    .accessibilityLabel(
                        "\(target.name): \(action.displayLabel(localization: localization))"
                    )
                    .accessibilityIdentifier(
                        "\(target.accessibilityIdentifier)-\(action.actionType)"
                    )
                } else {
                    quickRecordOptionMenu(target: target, action: action, options: options)
                }
            }
        } label: {
            Label(target.name, systemImage: target.kind.systemImage)
        }
        .accessibilityLabel(quickRecordTargetAccessibilityLabel(target))
        .accessibilityHint(localization.tr(
            zh: "选择记录类别",
            en: "Choose a record category.",
            de: "Wähle eine Kategorie.",
            es: "Elige una categoría de registro.",
            pt: "Escolha uma categoria de registro.",
            fr: "Choisissez une catégorie de saisie.",
            ja: "記録カテゴリを選択します。",
            ko: "기록 카테고리를 선택하세요.",
            it: "Scegli una categoria di registrazione."
        ))
        .accessibilityIdentifier(target.accessibilityIdentifier)
    }

    private func quickRecordOptionMenu(
        target: HomeToolbarQuickRecordTarget,
        action: QuickActionItem,
        options: [HomeQuickActionOption]
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    actionRelay.perform(target: target, action: action, optionID: option.id)
                } label: {
                    Label(option.title, systemImage: option.icon)
                }
                .accessibilityLabel(
                    "\(target.name): \(action.displayLabel(localization: localization)): \(option.title)"
                )
                .accessibilityIdentifier(
                    "\(target.accessibilityIdentifier)-\(action.actionType)-\(option.id)"
                )
            }
        } label: {
            Label(
                action.displayLabel(localization: localization),
                systemImage: action.icon
            )
        }
        .accessibilityLabel(
            "\(target.name): \(action.displayLabel(localization: localization))"
        )
        .accessibilityHint(quickRecordOptionAccessibilityHint)
        .accessibilityIdentifier(
            "\(target.accessibilityIdentifier)-\(action.actionType)"
        )
    }

    private var quickRecordAccessibilityHint: String {
        if selectedTab == .plants {
            return localization.tr(
                zh: "选择植物后，再选择记录类别",
                en: "Choose a plant, then choose a record category.",
                de: "Wähle eine Pflanze und dann eine Kategorie.",
                es: "Elige una planta y luego una categoría de registro.",
                pt: "Escolha uma planta e depois uma categoria de registro.",
                fr: "Choisissez une plante, puis une catégorie de saisie.",
                ja: "植物を選び、次に記録カテゴリを選択します。",
                ko: "식물을 선택한 다음 기록 카테고리를 선택하세요.",
                it: "Scegli una pianta, poi una categoria di registrazione."
            )
        }
        return localization.tr(
            zh: "选择人类或宠物后，再选择记录类别",
            en: "Choose a human or pet, then choose a record category.",
            de: "Wähle einen Menschen oder ein Haustier und dann eine Kategorie.",
            es: "Elige una persona o una mascota y luego una categoría de registro.",
            pt: "Escolha uma pessoa ou um animal e depois uma categoria de registro.",
            fr: "Choisissez une personne ou un animal, puis une catégorie de saisie.",
            ja: "人またはペットを選び、次に記録カテゴリを選択します。",
            ko: "사람이나 반려동물을 선택한 다음 기록 카테고리를 선택하세요.",
            it: "Scegli una persona o un animale, poi una categoria di registrazione."
        )
    }

    private var quickRecordEmptyTitle: String {
        if selectedTab == .plants {
            return localization.tr(
                zh: "暂无可记录的植物",
                en: "No plants to log",
                de: "Keine Pflanzen zum Erfassen",
                es: "No hay plantas para registrar",
                pt: "Nenhuma planta para registrar",
                fr: "Aucune plante à enregistrer",
                ja: "記録できる植物がありません",
                ko: "기록할 식물이 없습니다",
                it: "Nessuna pianta da registrare"
            )
        }
        return localization.tr(
            zh: "暂无可记录的成员",
            en: "No members to log",
            de: "Keine Mitglieder zum Erfassen",
            es: "No hay miembros para registrar",
            pt: "Nenhum membro para registrar",
            fr: "Aucun membre à enregistrer",
            ja: "記録できるメンバーがいません",
            ko: "기록할 구성원이 없습니다",
            it: "Nessun membro da registrare"
        )
    }

    private var quickRecordOptionAccessibilityHint: String {
        localization.tr(
            zh: "选择具体记录项目",
            en: "Choose a specific record.",
            de: "Wähle einen konkreten Eintrag.",
            es: "Elige un registro específico.",
            pt: "Escolha um registro específico.",
            fr: "Choisissez une saisie précise.",
            ja: "具体的な記録項目を選択します。",
            ko: "구체적인 기록 항목을 선택하세요.",
            it: "Scegli una registrazione specifica."
        )
    }

    private func quickRecordSectionTitle(
        for kind: HomeToolbarQuickRecordTarget.Kind
    ) -> String {
        switch kind {
        case .human:
            localization.tr(
                zh: "人类",
                en: "People",
                de: "Menschen",
                es: "Personas",
                pt: "Pessoas",
                fr: "Personnes",
                ja: "人",
                ko: "사람",
                it: "Persone"
            )
        case .pet:
            localization.tr(
                zh: "宠物",
                en: "Pets",
                de: "Haustiere",
                es: "Mascotas",
                pt: "Animais de estimação",
                fr: "Animaux de compagnie",
                ja: "ペット",
                ko: "반려동물",
                it: "Animali domestici"
            )
        case .plant:
            localization.tr(
                zh: "植物",
                en: "Plants",
                de: "Pflanzen",
                es: "Plantas",
                pt: "Plantas",
                fr: "Plantes",
                ja: "植物",
                ko: "식물",
                it: "Piante"
            )
        }
    }

    private func quickRecordTargetAccessibilityLabel(
        _ target: HomeToolbarQuickRecordTarget
    ) -> String {
        "\(quickRecordSectionTitle(for: target.kind)): \(target.name)"
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
