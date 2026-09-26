//
//  VerticalSolidHomeBottomBar.swift
//  Ohana
//
//  App-owned split-island root navigation and contextual actions.
//

import Foundation
import SwiftUI

struct HomeBottomNavigationLayoutMetrics: Equatable {
    let barHeight: CGFloat
    let horizontalPadding: CGFloat
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let tabSpacing: CGFloat
    let actionGap: CGFloat
    let actionDiameter: CGFloat
    let actionHitSize: CGFloat
    let showsSelectedLabel: Bool
}

enum HomeBottomNavigationLayoutPolicy {
    static func metrics(tabCount: Int, isAccessibilitySize: Bool = false) -> HomeBottomNavigationLayoutMetrics {
        let normalizedCount = max(tabCount, 1)
        let showsSelectedLabel = false
        let barHeight: CGFloat = isAccessibilitySize ? 64 : 58
        let tabSpacing: CGFloat = normalizedCount >= 5 ? 0 : 2

        return HomeBottomNavigationLayoutMetrics(
            barHeight: barHeight,
            horizontalPadding: 14,
            leadingPadding: 8,
            trailingPadding: 8,
            tabSpacing: tabSpacing,
            actionGap: 12,
            actionDiameter: 54,
            actionHitSize: 58,
            showsSelectedLabel: showsSelectedLabel
        )
    }

    static func estimatedTabSlotWidth(
        containerWidth: CGFloat,
        tabCount: Int,
        isAccessibilitySize: Bool = false
    ) -> CGFloat {
        let metrics = metrics(tabCount: tabCount, isAccessibilitySize: isAccessibilitySize)
        let normalizedCount = max(tabCount, 1)
        let fixedWidth = metrics.horizontalPadding * 2
            + metrics.leadingPadding
            + metrics.trailingPadding
            + metrics.actionGap
            + metrics.actionHitSize
            + CGFloat(max(normalizedCount - 1, 0)) * metrics.tabSpacing
        let availableWidth = max(44 * CGFloat(normalizedCount), containerWidth - fixedWidth)
        return availableWidth / CGFloat(normalizedCount)
    }
}

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

struct VerticalSolidHomeBottomBar: View {
    let selectedTab: VerticalSolidHomeTab
    let visibleTabs: [VerticalSolidHomeTab]
    let taskCenterBadge: TaskCenterBadgeSnapshot
    let quickRecordTargets: [HomeToolbarQuickRecordTarget]
    let safeBottom: CGFloat
    let allowsSelectionMotion: Bool
    let contextActionDisabledReason: HomeBottomContextActionDisabledReason?
    let localization: L10n
    let onSelect: (VerticalSolidHomeTab) -> Void
    let onQuickRecord: (HomeToolbarQuickRecordTarget, QuickActionItem?, String?) -> Void
    let onContextAction: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var tabSelectionNamespace

    private var metrics: HomeBottomNavigationLayoutMetrics {
        HomeBottomNavigationLayoutPolicy.metrics(
            tabCount: visibleTabs.count,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var contextAction: HomeBottomContextAction {
        HomeBottomContextAction.action(for: selectedTab)
    }

    private var isContextActionEnabled: Bool {
        contextActionDisabledReason == nil
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *), !reduceTransparency {
                islands(usesLiquidGlass: true)
            } else {
                islands(usesLiquidGlass: false)
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, max(safeBottom - 2, 4))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-bottom-navigation")
    }

    private func islands(usesLiquidGlass: Bool) -> some View {
        HStack(spacing: metrics.actionGap) {
            tabIsland(usesLiquidGlass: usesLiquidGlass)
                .frame(maxWidth: .infinity)

            contextActionControl(usesLiquidGlass: usesLiquidGlass)
                .id(contextAction.icon)
                .transition(.opacity)
        }
        .frame(height: metrics.barHeight)
        .animation(
            allowsSelectionMotion ? VerticalHomeTabTransitionPolicy.selectionAnimation : GoMotion.reduced,
            value: selectedTab
        )
    }

    @ViewBuilder
    private func tabIsland(usesLiquidGlass: Bool) -> some View {
        let content = HStack(spacing: metrics.tabSpacing) {
            ForEach(visibleTabs) { tab in
                HomeBottomNavigationTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    attentionCount: tab == .calendar ? taskCenterBadge.attentionCount : 0,
                    position: (visibleTabs.firstIndex(of: tab) ?? 0) + 1,
                    totalCount: visibleTabs.count,
                    localization: localization,
                    selectionNamespace: tabSelectionNamespace,
                    allowsSelectionMotion: allowsSelectionMotion,
                    action: onSelect
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.leading, metrics.leadingPadding)
        .padding(.trailing, metrics.trailingPadding)
        .frame(height: metrics.barHeight)

        if usesLiquidGlass {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func contextActionControl(usesLiquidGlass: Bool) -> some View {
        if contextAction == .quickRecord {
            HomeQuickRecordPopoutControl(
                selectedTab: selectedTab,
                quickRecordTargets: quickRecordTargets,
                localization: localization,
                unavailableAccessibilityHint: contextActionDisabledReason?
                    .accessibilityDescription(localization),
                isEnabled: isContextActionEnabled,
                diameter: metrics.actionDiameter,
                hitSize: metrics.actionHitSize,
                usesLiquidGlass: usesLiquidGlass,
                allowsMotion: allowsSelectionMotion,
                onQuickRecord: onQuickRecord
            )
            .opacity(isContextActionEnabled ? 1 : 0.52)
        } else {
            Button {
                OhanaFeedback.medium()
                onContextAction()
            } label: {
                contextActionLabel
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .modifier(HomeBottomContextActionChrome(
                diameter: metrics.actionDiameter,
                hitSize: metrics.actionHitSize,
                usesLiquidGlass: usesLiquidGlass
            ))
            .disabled(!isContextActionEnabled)
            .opacity(isContextActionEnabled ? 1 : 0.52)
            .accessibilityLabel(contextAction.accessibilityLabel(localization))
            .accessibilityHint(
                contextActionDisabledReason?.accessibilityDescription(localization)
                    ?? contextAction.accessibilityHint(localization)
            )
            .accessibilityIdentifier("home-primary-action")
        }
    }

    @ViewBuilder
    private var contextActionLabel: some View {
        Group {
            if contextAction == .injectEnergy {
                VStack(spacing: 1) {
                    Image(systemName: contextAction.icon)
                        .font(.system(size: 17, weight: .black)) // a11y: allow fixed glyph inside fixed dock circle; Button owns the scalable label.
                    Text("\(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥")
                        .font(.system(size: 9, weight: .black, design: .rounded)) // a11y: allow compact visual cost; Button exposes the full localized value.
                        .monospacedDigit()
                }
            } else {
                Image(systemName: contextAction.icon)
                    .font(.system(size: 20, weight: .black)) // a11y: allow fixed glyph inside fixed dock circle; Button owns the scalable label.
            }
        }
    }
}

private struct HomeBottomNavigationTabButton: View {
    let tab: VerticalSolidHomeTab
    let isSelected: Bool
    let attentionCount: Int
    let position: Int
    let totalCount: Int
    let localization: L10n
    let selectionNamespace: Namespace.ID
    let allowsSelectionMotion: Bool
    let action: (VerticalSolidHomeTab) -> Void

    var body: some View {
        Button {
            action(tab)
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: .black)) // a11y: allow fixed glyph inside fixed tab slot; Button exposes label and position.
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        selectionBackground
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if attentionCount > 0 {
                        Text(attentionCount > 99 ? "99+" : "\(attentionCount)")
                            .font(.system(size: 9, weight: .black, design: .rounded)) // a11y: allow compact visual badge; Button label announces the count.
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.goRed, in: Capsule())
                            .offset(x: 3, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(triggersHaptic: false))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityPosition)
        .accessibilityIdentifier("home-tab-\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if allowsSelectionMotion {
            Circle()
                .fill(Color.goPrimary)
                .matchedGeometryEffect(
                    id: "home-bottom-tab-selection",
                    in: selectionNamespace,
                    properties: .position
                )
        } else {
            Circle()
                .fill(Color.goPrimary)
        }
    }

    private var accessibilityLabel: String {
        guard tab == .calendar, attentionCount > 0 else {
            return tab.title(localization)
        }
        return localization.tr(
            zh: "\(tab.title(localization))，待处理：\(attentionCount)",
            en: "\(tab.title(localization)), needs attention: \(attentionCount)",
            de: "\(tab.title(localization)), offen: \(attentionCount)",
            es: "\(tab.title(localization)), pendientes: \(attentionCount)",
            pt: "\(tab.title(localization)), pendentes: \(attentionCount)",
            fr: "\(tab.title(localization)), à traiter : \(attentionCount)",
            ja: "\(tab.title(localization))、未対応：\(attentionCount)件",
            ko: "\(tab.title(localization)), 처리할 항목: \(attentionCount)개",
            it: "\(tab.title(localization)), da gestire: \(attentionCount)"
        )
    }

    private var accessibilityPosition: String {
        localization.tr(
            zh: "第 \(position) 个，共 \(totalCount) 个",
            en: "\(position) of \(totalCount)",
            de: "\(position) von \(totalCount)",
            es: "\(position) de \(totalCount)",
            pt: "\(position) de \(totalCount)",
            fr: "\(position) sur \(totalCount)",
            ja: "\(totalCount)個中\(position)番目",
            ko: "\(totalCount)개 중 \(position)번째",
            it: "\(position) di \(totalCount)"
        )
    }
}

private struct HomeBottomContextActionChrome: ViewModifier {
    let diameter: CGFloat
    let hitSize: CGFloat
    let usesLiquidGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let control = content
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())

        if usesLiquidGlass {
            control
                .glassEffect(.regular.tint(Color.goPrimary).interactive(), in: Circle())
                .frame(width: hitSize, height: hitSize)
        } else {
            control
                .background(Color.goPrimary, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.ohanaPrimaryActionText.opacity(0.22), lineWidth: 1)
                }
                .frame(width: hitSize, height: hitSize)
        }
    }
}

private struct HomeQuickRecordPopoutControl: View {
    let selectedTab: VerticalSolidHomeTab
    let quickRecordTargets: [HomeToolbarQuickRecordTarget]
    let localization: L10n
    let unavailableAccessibilityHint: String?
    let isEnabled: Bool
    let diameter: CGFloat
    let hitSize: CGFloat
    let usesLiquidGlass: Bool
    let allowsMotion: Bool
    let onQuickRecord: (HomeToolbarQuickRecordTarget, QuickActionItem?, String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var itemsVisible = false
    @State private var selectedTargetID: String?
    @State private var selectedActionID: String?
    @State private var transitionTask: Task<Void, Never>?

    private var canOpen: Bool {
        isEnabled && !quickRecordTargets.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: toggleMenu) {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .accessibilityHidden(true)
                    .font(.system(size: 20, weight: .black)) // a11y: allow fixed glyph inside fixed dock circle; Button exposes a scalable label.
                    .contentTransition(canAnimate ? .symbolEffect(.replace) : .identity)
            }
            .buttonStyle(ScaleButtonStyle(triggersHaptic: false))
            .modifier(HomeBottomContextActionChrome(
                diameter: diameter,
                hitSize: hitSize,
                usesLiquidGlass: usesLiquidGlass
            ))
            .disabled(!canOpen)
            .accessibilityLabel(HomeBottomContextAction.quickRecord.accessibilityLabel(localization))
            .accessibilityValue(isExpanded ? expandedAccessibilityValue : collapsedAccessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityIdentifier("home-quick-record-action")

            if isExpanded {
                floatingMenu
                    .fixedSize(horizontal: true, vertical: true)
                    .offset(y: -(hitSize + 10))
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                    .zIndex(30)
            }
        }
        .frame(width: hitSize, height: hitSize, alignment: .bottomTrailing)
        .zIndex(isExpanded ? 30 : 0)
        .onChange(of: selectedTab) { _, _ in
            dismissImmediately()
        }
        .onChange(of: quickRecordTargets) { _, _ in
            dismissImmediately()
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { dismissImmediately() }
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
    }

    @ViewBuilder
    private var floatingMenu: some View {
        if #available(iOS 26.0, *), usesLiquidGlass {
            GlassEffectContainer(spacing: 10) {
                floatingMenuItems(usesLiquidGlass: true)
            }
        } else {
            floatingMenuItems(usesLiquidGlass: false)
        }
    }

    private func floatingMenuItems(usesLiquidGlass: Bool) -> some View {
        let items = menuItems
        return VStack(alignment: .trailing, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HomeQuickRecordPopoutItemButton(
                    item: item,
                    usesLiquidGlass: usesLiquidGlass,
                    action: { handle(item.intent) }
                )
                .ohanaStaggeredMenuItem(
                    isVisible: itemsVisible,
                    index: index,
                    total: items.count,
                    anchor: .bottomTrailing
                )
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var menuItems: [HomeQuickRecordPopoutItem] {
        guard let selectedTarget else {
            return quickRecordTargets.map { target in
                HomeQuickRecordPopoutItem(
                    id: target.accessibilityIdentifier,
                    title: target.name,
                    icon: target.kind.systemImage,
                    tint: targetTint(target.kind),
                    accessibilityLabel: targetAccessibilityLabel(target),
                    accessibilityIdentifier: target.accessibilityIdentifier,
                    intent: .target(target.id)
                )
            }
        }

        guard let selectedAction else {
            return [backItem] + selectedTarget.quickActions.map { action in
                let title = action.displayLabel(localization: localization)
                return HomeQuickRecordPopoutItem(
                    id: "\(selectedTarget.accessibilityIdentifier)-\(action.id)",
                    title: title,
                    icon: action.icon,
                    tint: Color(hex: action.colorHex),
                    accessibilityLabel: "\(selectedTarget.name): \(title)",
                    accessibilityIdentifier: "\(selectedTarget.accessibilityIdentifier)-\(action.actionType)",
                    intent: .action(action.id)
                )
            }
        }

        let options = HomeQuickActionOptionCatalog.options(
            for: selectedAction.actionType,
            localization: localization
        )
        return [backItem] + options.map { option in
            HomeQuickRecordPopoutItem(
                id: "\(selectedTarget.accessibilityIdentifier)-\(selectedAction.actionType)-\(option.id)",
                title: option.title,
                icon: option.icon,
                tint: option.colorToken.color,
                accessibilityLabel: "\(selectedTarget.name): \(selectedAction.displayLabel(localization: localization)): \(option.title)",
                accessibilityIdentifier: "\(selectedTarget.accessibilityIdentifier)-\(selectedAction.actionType)-\(option.id)",
                intent: .option(option.id)
            )
        }
    }

    private var selectedTarget: HomeToolbarQuickRecordTarget? {
        guard let selectedTargetID else { return nil }
        return quickRecordTargets.first(where: { $0.id == selectedTargetID })
    }

    private var selectedAction: QuickActionItem? {
        guard let selectedActionID else { return nil }
        return selectedTarget?.quickActions.first(where: { $0.id == selectedActionID })
    }

    private var backItem: HomeQuickRecordPopoutItem {
        HomeQuickRecordPopoutItem(
            id: "quick-record-back-\(selectedTargetID ?? "root")-\(selectedActionID ?? "actions")",
            title: localization.tr(
                zh: "返回", en: "Back", de: "Zurück", es: "Atrás", pt: "Voltar",
                fr: "Retour", ja: "戻る", ko: "뒤로", it: "Indietro"
            ),
            icon: "chevron.backward",
            tint: Color.ohanaSecondaryText,
            accessibilityLabel: localization.tr(
                zh: "返回上一级", en: "Back", de: "Zurück", es: "Atrás", pt: "Voltar",
                fr: "Retour", ja: "戻る", ko: "뒤로", it: "Indietro"
            ),
            accessibilityIdentifier: "home-quick-record-back",
            intent: .back
        )
    }

    private func toggleMenu() {
        guard canOpen else { return }
        OhanaFeedback.medium()
        if isExpanded {
            dismissMenu()
        } else {
            transitionTask?.cancel()
            selectedTargetID = nil
            selectedActionID = nil
            withAnimation(menuAnimation) {
                isExpanded = true
            }
            transitionTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: canAnimate ? 16 : 0) {
                withAnimation(menuAnimation) {
                    itemsVisible = true
                }
                transitionTask = nil
            }
        }
    }

    private func handle(_ intent: HomeQuickRecordPopoutIntent) {
        switch intent {
        case .back:
            if selectedActionID != nil {
                transition(toTargetID: selectedTargetID, actionID: nil)
            } else {
                transition(toTargetID: nil, actionID: nil)
            }
        case let .target(targetID):
            guard let target = quickRecordTargets.first(where: { $0.id == targetID }) else { return }
            if target.kind == .plant {
                perform(target: target, action: nil, optionID: nil)
            } else {
                transition(toTargetID: targetID, actionID: nil)
            }
        case let .action(actionID):
            guard let target = selectedTarget,
                  let action = target.quickActions.first(where: { $0.id == actionID }) else { return }
            if HomeQuickActionOptionCatalog.hasOptions(for: action.actionType) {
                transition(toTargetID: target.id, actionID: actionID)
            } else {
                perform(target: target, action: action, optionID: nil)
            }
        case let .option(optionID):
            guard let target = selectedTarget,
                  let action = selectedAction,
                  HomeQuickActionOptionCatalog.options(
                    for: action.actionType,
                    localization: localization
                  ).contains(where: { $0.id == optionID }) else { return }
            perform(target: target, action: action, optionID: optionID)
        }
    }

    private func transition(toTargetID targetID: String?, actionID: String?) {
        transitionTask?.cancel()
        OhanaFeedback.light()
        withAnimation(menuAnimation) {
            itemsVisible = false
        }
        transitionTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: canAnimate ? 390 : 0
        ) {
            selectedTargetID = targetID
            selectedActionID = actionID
            withAnimation(menuAnimation) {
                itemsVisible = true
            }
            transitionTask = nil
        }
    }

    private func perform(
        target: HomeToolbarQuickRecordTarget,
        action: QuickActionItem?,
        optionID: String?
    ) {
        OhanaFeedback.light()
        dismissMenu()
        OhanaFrameScheduler.runAfterNextFrame {
            onQuickRecord(target, action, optionID)
        }
    }

    private func dismissMenu() {
        transitionTask?.cancel()
        withAnimation(menuAnimation) {
            itemsVisible = false
        }
        transitionTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: canAnimate ? 390 : 0
        ) {
            withAnimation(menuAnimation) {
                isExpanded = false
            }
            selectedTargetID = nil
            selectedActionID = nil
            transitionTask = nil
        }
    }

    private func dismissImmediately() {
        transitionTask?.cancel()
        transitionTask = nil
        guard isExpanded || itemsVisible || selectedTargetID != nil || selectedActionID != nil else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isExpanded = false
            itemsVisible = false
            selectedTargetID = nil
            selectedActionID = nil
        }
    }

    private var menuAnimation: Animation {
        canAnimate ? GoMotion.fab : GoMotion.reduced
    }

    private var canAnimate: Bool {
        allowsMotion && !reduceMotion
    }

    private var accessibilityHint: String {
        unavailableAccessibilityHint
            ?? (quickRecordTargets.isEmpty ? emptyTitle : quickRecordHint)
    }

    private var emptyTitle: String {
        if selectedTab == .plants {
            return localization.tr(
                zh: "暂无可记录的植物", en: "No plants to log", de: "Keine Pflanzen zum Erfassen",
                es: "No hay plantas para registrar", pt: "Nenhuma planta para registrar",
                fr: "Aucune plante à enregistrer", ja: "記録できる植物がありません",
                ko: "기록할 식물이 없습니다", it: "Nessuna pianta da registrare"
            )
        }
        return localization.tr(
            zh: "暂无可记录的成员", en: "No members to log", de: "Keine Mitglieder zum Erfassen",
            es: "No hay miembros para registrar", pt: "Nenhum membro para registrar",
            fr: "Aucun membre à enregistrer", ja: "記録できるメンバーがいません",
            ko: "기록할 구성원이 없습니다", it: "Nessun membro da registrare"
        )
    }

    private var quickRecordHint: String {
        localization.tr(
            zh: "展开后选择成员与记录类别", en: "Expand, then choose a member and record category.",
            de: "Öffnen und Mitglied sowie Kategorie wählen.",
            es: "Despliega y elige un miembro y una categoría.",
            pt: "Expanda e escolha um membro e uma categoria.",
            fr: "Déployez puis choisissez un membre et une catégorie.",
            ja: "展開してメンバーと記録カテゴリを選びます。",
            ko: "펼친 후 구성원과 기록 카테고리를 선택하세요.",
            it: "Espandi, poi scegli un membro e una categoria."
        )
    }

    private var expandedAccessibilityValue: String {
        localization.tr(
            zh: "已展开", en: "Expanded", de: "Geöffnet", es: "Desplegado", pt: "Expandido",
            fr: "Déployé", ja: "展開中", ko: "펼쳐짐", it: "Espanso"
        )
    }

    private var collapsedAccessibilityValue: String {
        localization.tr(
            zh: "已收起", en: "Collapsed", de: "Geschlossen", es: "Contraído", pt: "Recolhido",
            fr: "Replié", ja: "折りたたみ", ko: "접힘", it: "Chiuso"
        )
    }

    private func targetAccessibilityLabel(_ target: HomeToolbarQuickRecordTarget) -> String {
        let kind = switch target.kind {
        case .human:
            localization.tr(
                zh: "人类", en: "Person", de: "Person", es: "Persona", pt: "Pessoa",
                fr: "Personne", ja: "人", ko: "사람", it: "Persona"
            )
        case .pet:
            localization.tr(
                zh: "宠物", en: "Pet", de: "Haustier", es: "Mascota", pt: "Pet",
                fr: "Animal", ja: "ペット", ko: "반려동물", it: "Animale"
            )
        case .plant:
            localization.tr(
                zh: "植物", en: "Plant", de: "Pflanze", es: "Planta", pt: "Planta",
                fr: "Plante", ja: "植物", ko: "식물", it: "Pianta"
            )
        }
        return "\(kind): \(target.name)"
    }

    private func targetTint(_ kind: HomeToolbarQuickRecordTarget.Kind) -> Color {
        switch kind {
        case .human: Color.goPurple
        case .pet: Color.goOrange
        case .plant: Color.goTeal
        }
    }
}

private struct HomeQuickRecordPopoutItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let intent: HomeQuickRecordPopoutIntent
}

private enum HomeQuickRecordPopoutIntent {
    case back
    case target(String)
    case action(String)
    case option(String)
}

private struct HomeQuickRecordPopoutItemButton: View {
    let item: HomeQuickRecordPopoutItem
    let usesLiquidGlass: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                titleSurface
                iconSurface
            }
            .frame(minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(triggersHaptic: false))
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }

    @ViewBuilder
    private var titleSurface: some View {
        let title = Text(item.title)
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: 190)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)

        if #available(iOS 26.0, *), usesLiquidGlass {
            title
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            title
                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var iconSurface: some View {
        let icon = Image(systemName: item.icon)
            .font(.system(size: 17, weight: .black)) // a11y: allow fixed glyph inside 44pt floating Button; the Button exposes its text label.
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(item.tint)
            .frame(
                width: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                height: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )

        if #available(iOS 26.0, *), usesLiquidGlass {
            icon
                .glassEffect(.regular.tint(item.tint.opacity(0.16)).interactive(), in: Circle())
        } else {
            icon
                .background(Color.ohanaCardSurfaceElevated, in: Circle())
                .overlay {
                    Circle().strokeBorder(item.tint.opacity(0.34), lineWidth: 1)
                }
        }
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
