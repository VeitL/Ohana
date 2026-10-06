//
//  VerticalSolidHomeBottomBar.swift
//  Ohana
//
//  Native same-row content tabs and contextual actions.
//

import Foundation
import SwiftUI

enum HomeBottomContextAction: Equatable {
    case quickRecord
    case addEvent
    case injectEnergy

    static func action(for tab: VerticalSolidHomeTab) -> HomeBottomContextAction {
        switch tab {
        case .home, .plants:
            .quickRecord
        case .calendar:
            .addEvent
        case .oasis:
            .injectEnergy
        }
    }

    var icon: String {
        switch self {
        case .quickRecord:
            "plus"
        case .addEvent:
            "calendar.badge.plus"
        case .injectEnergy:
            "bolt.fill"
        }
    }

    func accessibilityLabel(_ localization: L10n) -> String {
        switch self {
        case .quickRecord:
            localization.tr(
                zh: "快速记录",
                en: "Quick log",
                de: "Schnell erfassen",
                es: "Registro rápido",
                pt: "Registro rápido",
                fr: "Saisie rapide",
                ja: "すばやく記録",
                ko: "빠르게 기록",
                it: "Registrazione rapida"
            )
        case .addEvent:
            localization.tr(
                zh: "添加事件",
                en: "Add event",
                de: "Ereignis hinzufügen",
                es: "Añadir evento",
                pt: "Adicionar evento",
                fr: "Ajouter un événement",
                ja: "イベントを追加",
                ko: "이벤트 추가",
                it: "Aggiungi evento"
            )
        case .injectEnergy:
            localization.tr(
                zh: "注入能量",
                en: "Inject energy",
                de: "Energie einspeisen",
                es: "Inyectar energía",
                pt: "Injetar energia",
                fr: "Injecter de l’énergie",
                ja: "エネルギーを注入",
                ko: "에너지 주입",
                it: "Immetti energia"
            )
        }
    }

    func accessibilityHint(_ localization: L10n) -> String {
        switch self {
        case .quickRecord:
            return ""
        case .addEvent:
            return localization.tr(
                zh: "打开新事件表单",
                en: "Opens the new event form.",
                de: "Öffnet das Formular für ein neues Ereignis.",
                es: "Abre el formulario de un nuevo evento.",
                pt: "Abre o formulário de um novo evento.",
                fr: "Ouvre le formulaire d’un nouvel événement.",
                ja: "新しいイベントのフォームを開きます。",
                ko: "새 이벤트 양식을 엽니다.",
                it: "Apre il modulo per un nuovo evento."
            )
        case .injectEnergy:
            let cost = OasisTreeEnergyInjectionPolicy.starterPackageCost
            let energy = OasisTreeEnergyInjectionPolicy.starterPackageXP
            return localization.tr(
                zh: "消耗 \(cost) 个椰子，增加 \(energy) 点能量",
                en: "Uses \(cost) coconuts to add \(energy) energy.",
                de: "Verbraucht \(cost) Kokosnüsse für \(energy) Energie.",
                es: "Usa \(cost) cocos para añadir \(energy) de energía.",
                pt: "Usa \(cost) cocos para adicionar \(energy) de energia.",
                fr: "Utilise \(cost) noix de coco pour ajouter \(energy) d’énergie.",
                ja: "ココナッツを \(cost) 個使い、エネルギーを \(energy) 増やします。",
                ko: "코코넛 \(cost)개를 사용해 에너지 \(energy)을 추가합니다.",
                it: "Usa \(cost) noci di cocco per aggiungere \(energy) energia."
            )
        }
    }
}

enum HomeBottomContextActionDisabledReason: Equatable {
    case loading
    case insufficientCoconuts(required: Int)
    case inProgress
    case unavailable

    func accessibilityDescription(_ localization: L10n) -> String {
        switch self {
        case .loading:
            localization.tr(
                zh: "正在读取数据",
                en: "Loading data.",
                de: "Daten werden geladen.",
                es: "Cargando datos.",
                pt: "Carregando dados.",
                fr: "Chargement des données.",
                ja: "データを読み込んでいます。",
                ko: "데이터를 불러오는 중입니다.",
                it: "Caricamento dei dati."
            )
        case let .insufficientCoconuts(required):
            localization.tr(
                zh: "椰子不足，需要 \(required) 个",
                en: "Not enough coconuts. \(required) required.",
                de: "Nicht genug Kokosnüsse. \(required) benötigt.",
                es: "No hay suficientes cocos. Se necesitan \(required).",
                pt: "Cocos insuficientes. São necessários \(required).",
                fr: "Pas assez de noix de coco. \(required) nécessaires.",
                ja: "ココナッツが不足しています。\(required)個必要です。",
                ko: "코코넛이 부족합니다. \(required)개가 필요합니다.",
                it: "Noci di cocco insufficienti. Ne servono \(required)."
            )
        case .inProgress:
            localization.tr(
                zh: "正在注入能量",
                en: "Injecting energy.",
                de: "Energie wird eingespeist.",
                es: "Inyectando energía.",
                pt: "Injetando energia.",
                fr: "Injection d’énergie en cours.",
                ja: "エネルギーを注入しています。",
                ko: "에너지를 주입하는 중입니다.",
                it: "Immissione di energia in corso."
            )
        case .unavailable:
            localization.tr(
                zh: "当前无法注入能量",
                en: "Energy injection is currently unavailable.",
                de: "Energie kann derzeit nicht eingespeist werden.",
                es: "La inyección de energía no está disponible ahora.",
                pt: "A injeção de energia não está disponível agora.",
                fr: "L’injection d’énergie est actuellement indisponible.",
                ja: "現在エネルギーを注入できません。",
                ko: "현재 에너지를 주입할 수 없습니다.",
                it: "L’immissione di energia non è disponibile al momento."
            )
        }
    }
}

/// Only the placement is app-owned; selection, menu tracking and press feedback are native.
struct VerticalSolidHomeBottomBar: View {
    let selectedTab: VerticalSolidHomeTab
    let visibleTabs: [VerticalSolidHomeTab]
    let taskCenterBadge: TaskCenterBadgeSnapshot
    let quickRecordTargets: [HomeToolbarQuickRecordTarget]
    let contextActionDisabledReason: HomeBottomContextActionDisabledReason?
    let localization: L10n
    let onSelect: (VerticalSolidHomeTab) -> Void
    let onQuickRecord: (HomeToolbarQuickRecordTarget, QuickActionItem?, String?) -> Void
    let onContextAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var contextAction: HomeBottomContextAction {
        HomeBottomContextAction.action(for: selectedTab)
    }

    private var selection: Binding<VerticalSolidHomeTab> {
        Binding(get: { selectedTab }, set: { tab in
            guard tab != selectedTab, visibleTabs.contains(tab) else { return }
            onSelect(tab)
        })
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    tabPicker(symbolsOnly: false)
                        .fixedSize(horizontal: true, vertical: false)
                }
                tabPicker(symbolsOnly: true)
            }
            .frame(maxWidth: .infinity)

            contextControl
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Color.goPrimary)
                .controlSize(.large)
                .frame(minWidth: 48, minHeight: 48)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-bottom-navigation")
    }

    private func tabPicker(symbolsOnly: Bool) -> some View {
        Picker(localization.tr(zh: "页面", en: "Pages", de: "Seiten", es: "Páginas", pt: "Páginas", fr: "Pages", ja: "ページ", ko: "페이지", it: "Pagine"), selection: selection) {
            ForEach(visibleTabs) { tab in
                Group {
                    if symbolsOnly {
                        Image(systemName: tab.icon)
                    } else {
                        Text(tabTitle(tab))
                    }
                }
                .tag(tab)
                .accessibilityLabel(tabTitle(tab))
                .accessibilityIdentifier("home-tab-\(tab.rawValue)")
            }
        }
        .labelsHidden()
        .ohanaContentTabsPickerStyle()
        .controlSize(.large)
        .frame(minWidth: CGFloat(visibleTabs.count) * 44, minHeight: 44)
        .accessibilityIdentifier("home-tab-picker")
    }

    private func tabTitle(_ tab: VerticalSolidHomeTab) -> String {
        let title = tab.title(localization)
        guard tab == .calendar, taskCenterBadge.attentionCount > 0 else { return title }
        return "\(title) · \(taskCenterBadge.attentionCount)"
    }

    @ViewBuilder
    private var contextControl: some View {
        if contextAction == .quickRecord {
            if let onlyTarget = HomeNativeQuickRecordPolicy.singleDirectTarget(quickRecordTargets) {
                Button { onQuickRecord(onlyTarget, nil, nil) } label: { contextLabel }
                    .accessibilityIdentifier("home-quick-record-action")
                    .accessibilityLabel(contextAction.accessibilityLabel(localization))
                    .disabled(contextActionDisabledReason != nil)
            } else {
                Menu {
                    if quickRecordTargets.count == 1, let target = quickRecordTargets.first {
                        targetActions(target)
                    } else {
                        ForEach(quickRecordTargets) { target in
                            if target.kind == .plant {
                                Button { onQuickRecord(target, nil, nil) } label: {
                                    Label(target.name, systemImage: target.kind.systemImage)
                                }
                                .accessibilityIdentifier(target.accessibilityIdentifier)
                            } else {
                                Menu { targetActions(target) } label: {
                                    Label(target.name, systemImage: target.kind.systemImage)
                                }
                                .accessibilityIdentifier(target.accessibilityIdentifier)
                            }
                        }
                    }
                } label: { contextLabel }
                .menuOrder(.fixed)
                .disabled(contextActionDisabledReason != nil || quickRecordTargets.isEmpty)
                .accessibilityLabel(contextAction.accessibilityLabel(localization))
                .accessibilityHint(contextActionDisabledReason?.accessibilityDescription(localization) ?? "")
                .accessibilityIdentifier("home-quick-record-action")
            }
        } else {
            Button(action: onContextAction) { contextLabel }
                .disabled(contextActionDisabledReason != nil)
                .accessibilityLabel(contextAction.accessibilityLabel(localization))
                .accessibilityHint(contextActionDisabledReason?.accessibilityDescription(localization) ?? contextAction.accessibilityHint(localization))
                .accessibilityIdentifier("home-primary-action")
        }
    }

    private var contextLabel: some View {
        Image(systemName: contextAction.icon)
            .font(OhanaFont.title3())
            .dynamicTypeSize(.large)
            .frame(width: 18, height: 18) // a11y: allow decorative glyph; enclosing large native control reserves a minimum 48pt hit target.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func targetActions(_ target: HomeToolbarQuickRecordTarget) -> some View {
        ForEach(target.quickActions) { action in
            let options = HomeQuickActionOptionCatalog.options(for: action.actionType, localization: localization)
            if options.isEmpty {
                Button { onQuickRecord(target, action, nil) } label: {
                    Label(action.displayLabel(localization: localization), systemImage: action.icon)
                }
                .accessibilityIdentifier("\(target.accessibilityIdentifier)-\(action.actionType)")
            } else {
                Menu {
                    ForEach(options) { option in
                        Button { onQuickRecord(target, action, option.id) } label: {
                            Label(option.title, systemImage: option.icon)
                        }
                        .accessibilityIdentifier("\(target.accessibilityIdentifier)-\(action.actionType)-\(option.id)")
                    }
                } label: {
                    Label(action.displayLabel(localization: localization), systemImage: action.icon)
                }
                .accessibilityIdentifier("\(target.accessibilityIdentifier)-\(action.actionType)")
            }
        }
    }
}

enum HomeNativeQuickRecordPolicy {
    /// Plant logging has one intent; member logging still needs an action choice.
    static func singleDirectTarget(_ targets: [HomeToolbarQuickRecordTarget]) -> HomeToolbarQuickRecordTarget? {
        guard targets.count == 1, let target = targets.first, target.kind == .plant else { return nil }
        return target
    }
}

nonisolated enum HomeFabShortcutHitAreaPolicy {
    static let minimumHitSize: CGFloat = 44
    static let visualDiameter: CGFloat = 42
    static let menuColumnWidth: CGFloat = 52
    static let expandedCardEmbeddedActionClearance: CGFloat = 184
}

nonisolated enum HomeBottomNavigationPrimaryActionPresentation {
    static func icon(
        selectedTab: VerticalSolidHomeTab,
        isFabExpanded: Bool,
        usesFabMenu: Bool
    ) -> String {
        if isFabExpanded {
            return "xmark"
        }
        if usesFabMenu {
            return "plus"
        }
        switch selectedTab {
        case .home: return "plus"
        case .calendar: return "plus"
        case .oasis: return "bolt.fill"
        case .plants: return "plus"
        }
    }
}

struct VerticalSolidHomeQuickActionMenu: View {
    let selectedTab: VerticalSolidHomeTab
    @Binding var isFabExpanded: Bool
    @Binding var itemsVisible: Bool
    let activeCard: FocusCard?
    let homeShortcuts: [HomeFabFunctionShortcut]
    let plantShortcuts: [HomeFabFunctionShortcut]
    let expandedShortcuts: [ExpandedCardFabShortcut]
    let safeBottom: CGFloat
    let canAnimate: Bool
    let primaryActionIcon: String
    let primaryActionAccessibilityLabel: String
    let localization: L10n
    let onHomeShortcut: (HomeFabFunctionShortcut) -> Void
    let onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void
    let onPrimaryAction: () -> Void

    @State private var activeHomeSubmenu: HomeFabShortcutSubmenu?
    @State private var submenuItemsVisible = false

    private var l: L10n { localization }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            menuRows
                .frame(width: HomeFabShortcutHitAreaPolicy.menuColumnWidth, alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, menuRowsBottomPadding)

            Button(action: onPrimaryAction) {
                Label(primaryActionAccessibilityLabel, systemImage: primaryActionIcon)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(Color.goPrimary)
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .accessibilityLabel(primaryActionAccessibilityLabel)
            .accessibilityIdentifier("home-primary-action")
            .padding(.trailing, 14)
            .padding(.bottom, primaryActionBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: isFabExpanded)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: itemsVisible)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: activeHomeSubmenu)
        .onChange(of: isFabExpanded) { _, expanded in
            if !expanded { resetHomeSubmenu() }
        }
        .onChange(of: selectedTab) { _, _ in
            resetHomeSubmenu()
        }
        .onChange(of: activeCard?.id) { _, _ in
            resetHomeSubmenu()
        }
    }

    private var menuRowsBottomPadding: CGFloat {
        let basePadding = safeBottom + 76
        guard activeCard != nil else { return basePadding }
        return basePadding + HomeFabShortcutHitAreaPolicy.expandedCardEmbeddedActionClearance
    }

    private var primaryActionBottomPadding: CGFloat {
        max(safeBottom - 2, 4)
    }

    @ViewBuilder
    private var menuRows: some View {
        if isFabExpanded, let activeCard {
            VStack(spacing: 10) {
                ForEach(Array(expandedShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeFabShortcutButton(
                        shortcut: shortcut,
                        accentColor: Color(hex: activeCard.themeColorHex)
                    ) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onExpandedShortcut(shortcut, activeCard)
                    }
                    .ohanaStaggeredMenuItem(
                        isVisible: itemsVisible,
                        index: index,
                        total: expandedShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
            .padding(.vertical, 2)
        } else if isFabExpanded, selectedTab == .home {
            VStack(spacing: 10) {
                if activeHomeSubmenu == .addMember {
                    let childShortcuts = HomeFabShortcutCatalog.addMemberShortcuts(l: l)
                    ForEach(Array(childShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                        VerticalSolidHomeHomeFabShortcutButton(shortcut: shortcut) {
                            guard shortcut.isAvailable else {
                                OhanaFeedback.light()
                                return
                            }
                            resetHomeSubmenu()
                            onHomeShortcut(shortcut)
                        }
                        .ohanaStaggeredMenuItem(
                            isVisible: submenuItemsVisible && itemsVisible,
                            index: index,
                            total: childShortcuts.count,
                            anchor: .bottom
                        )
                        .allowsHitTesting(submenuItemsVisible && itemsVisible)
                        .accessibilityHidden(!(submenuItemsVisible && itemsVisible))
                    }
                }

                ForEach(Array(homeShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeHomeFabShortcutButton(
                        shortcut: shortcut,
                        isDimmed: activeHomeSubmenu == .addMember && shortcut.action == .submenu(.addMember)
                    ) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        handleHomeShortcut(shortcut)
                    }
                    .ohanaStaggeredMenuItem(
                        isVisible: itemsVisible,
                        index: index,
                        total: homeShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
            .padding(.vertical, 2)
        } else if isFabExpanded, selectedTab == .plants {
            VStack(spacing: 10) {
                ForEach(Array(plantShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeHomeFabShortcutButton(shortcut: shortcut) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onHomeShortcut(shortcut)
                    }
                    .ohanaStaggeredMenuItem(
                        isVisible: itemsVisible,
                        index: index,
                        total: plantShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func handleHomeShortcut(_ shortcut: HomeFabFunctionShortcut) {
        switch shortcut.action {
        case .submenu(.addMember):
            OhanaFeedback.light()
            if activeHomeSubmenu == .addMember {
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    submenuItemsVisible = false
                    activeHomeSubmenu = nil
                }
                return
            }
            submenuItemsVisible = false
            withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                activeHomeSubmenu = .addMember
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
                guard activeHomeSubmenu == .addMember else { return }
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    submenuItemsVisible = true
                }
            }
        case .addEntity, .destination, .unavailable:
            resetHomeSubmenu()
            onHomeShortcut(shortcut)
        }
    }

    private func resetHomeSubmenu() {
        submenuItemsVisible = false
        activeHomeSubmenu = nil
    }
}

struct StarterOasisTabPromptView: View {
    let localization: L10n

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill") // a11y: allow decorative onboarding prompt arrow; parent prompt text owns accessibility.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color.goPrimary)

            Text(localization.tr(
                zh: "椰子树已解锁，点击底部椰子树进入 Oasis",
                en: "Coconut Tree unlocked. Tap the tree tab to enter Oasis.",
                de: "Kokosbaum freigeschaltet. Tippe unten auf den Baum."
            ))
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurface, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.goPrimary.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.16), radius: 16, x: 0, y: 8) // ui-v4: allow one-time onboarding nudge depth.
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("starter-oasis-tab-prompt")
    }
}

private struct VerticalSolidHomeFabShortcutButton: View {
    let shortcut: ExpandedCardFabShortcut
    let accentColor: Color
    let action: () -> Void
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(expandedShortcut: shortcut)
        }()

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: accentColor.opacity(shortcut.isAvailable ? 1 : 0.54),
                        primaryColor: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        animatesStateChanges: false
                    )
                    .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.

                    if showsNewFeature {
                        GrowthNewFeatureDot(size: 9)
                            .offset(x: 5, y: -5)
                    } else if let badge = shortcut.badge {
                        Text(badge)
                            .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.goYellow, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                Text(shortcut.label)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 44)
            }
            .opacity(shortcut.isAvailable ? 1 : 0.55)
            .frame(
                minWidth: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
        .accessibilityIdentifier("home-expanded-shortcut-\(shortcut.action.accessibilityIdentifierFragment)")
    }

    private var iconActionType: String {
        switch shortcut.action {
        case let .quick(actionType), let .humanQuick(actionType):
            actionType
        case let .detail(feature):
            feature.rawValue
        case .allFeatures, .humanAllFeatures:
            shortcut.id
        }
    }
}

private extension ExpandedCardFabAction {
    var accessibilityIdentifierFragment: String {
        switch self {
        case let .quick(actionType):
            "quick-\(actionType)"
        case let .detail(feature):
            "detail-\(feature.rawValue)"
        case .allFeatures:
            "allFeatures"
        case let .humanQuick(actionType):
            "humanQuick-\(actionType)"
        case .humanAllFeatures:
            "humanAllFeatures"
        }
    }
}

private struct VerticalSolidHomeHomeFabShortcutButton: View {
    let shortcut: HomeFabFunctionShortcut
    var isDimmed = false
    let action: () -> Void
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(homeShortcut: shortcut)
        }()

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        primaryColor: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        animatesStateChanges: false
                    )
                    .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.

                    if showsNewFeature {
                        GrowthNewFeatureDot(size: 9)
                            .offset(x: 5, y: -5)
                    } else if let badge = shortcut.badge {
                        Text(badge)
                            .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.goYellow, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                Text(shortcut.label)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 46)
            }
            .opacity(shortcut.isAvailable ? (isDimmed ? 0.42 : 1) : 0.55)
            .frame(
                minWidth: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
        .accessibilityIdentifier("home-fab-shortcut-\(shortcut.accessibilityIdentifierFragment)")
    }

    private var iconActionType: String {
        if case let .destination(.featureAggregate(feature)) = shortcut.action {
            return feature.rawValue
        }
        return shortcut.id
    }
}
