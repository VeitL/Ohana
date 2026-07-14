//
//  SettingsPlantReminderDataContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct SettingsPlantReminderDataContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var refreshToken = 0
    @State private var observedRevisionValue: Int?

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: SettingsPlantReminderRouteData(),
            refreshToken: refreshToken,
            loadDelayMilliseconds: 80,
            reloadDelayMilliseconds: 80,
            shouldLoad: { !$0.hasLoaded || $0.plants.isEmpty },
            load: { SettingsPlantReminderRouteData.load(from: modelContext) }
        ) { data in
            SettingsPlantReminderPanelContent(plants: data.plants)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            guard shouldRefreshPlantReminderData(for: revision) else { return }
            guard observedRevisionValue != revision.value else { return }
            defer { observedRevisionValue = revision.value }
            guard observedRevisionValue != nil else { return }
            refreshToken &+= 1
        }
    }

    private func shouldRefreshPlantReminderData(for revision: HomeRevision) -> Bool {
        guard let command = revision.lastCommand else { return false }
        switch command.feature {
        case "members", "plants":
            return true
        default:
            return false
        }
    }
}

private struct SettingsPlantReminderRouteData {
    var hasLoaded = false
    var plants: [Plant] = []

    static func load(from context: ModelContext) -> SettingsPlantReminderRouteData {
        do {
            let descriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return SettingsPlantReminderRouteData(
                hasLoaded: true,
                plants: try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
            )
        } catch {
            OhanaLog.warning(
                "Settings plant reminder fetch failed: \(error.localizedDescription)",
                category: "Settings"
            )
            return SettingsPlantReminderRouteData(hasLoaded: true, plants: [])
        }
    }
}

private struct SettingsPlantReminderPanelContent: View {
    let plants: [Plant]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var plantReminderDisplayState: [UUID: Bool] = [:]
    @State private var pendingPlantReminderUpdates: [UUID: PendingPlantReminderUpdate] = [:]
    @State private var statusMessage: String?
    @State private var isBulkDeferPending = false

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerLine: Color { Color.ohanaDivider }
    private var accentColor: Color { Color.goPrimary }

    var body: some View {
        VStack(spacing: 0) {
            reminderOverview
            sectionDivider
            masterRow
            if NotificationPreferenceStore.isEnabled(.plantCare) {
                sectionDivider
                timeWindowRow
                sectionDivider
                weekendQuietRow
                sectionDivider
                travelModeRow
                sectionDivider
                careTypeRows
                sectionDivider
                plantRows
                sectionDivider
                bulkDeferSection
            }
        }
        .onDisappear {
            flushPendingPlantReminderUpdates()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            flushPendingPlantReminderUpdates()
        }
    }

    private var sectionDivider: some View {
        OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
    }

    private var reminderOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                settingsIcon(reminderOverviewIcon, color: reminderOverviewTint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminderOverviewTitle)
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(primaryText)
                    Text(reminderOverviewSubtitle)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                reminderStateBadge
            }

            HStack(spacing: 8) {
                reminderOverviewMetric(
                    id: "plants",
                    icon: "leaf.fill",
                    title: l.tr(zh: "覆盖植物", en: "Covered", de: "Abgedeckt"),
                    value: "\(enabledPlantReminderCount)/\(plants.count)",
                    tint: enabledPlantReminderCount == plants.count ? Color.goPrimary : Color.goYellow
                )
                reminderOverviewMetric(
                    id: "types",
                    icon: "checklist.checked",
                    title: l.tr(zh: "任务类型", en: "Task types", de: "Aufgaben"),
                    value: "\(enabledCareTypeReminderCount)/\(PlantReminderPreferenceStore.controllableCareTypes.count)",
                    tint: enabledCareTypeReminderCount == PlantReminderPreferenceStore.controllableCareTypes.count ? Color.goTeal : Color.goYellow
                )
                reminderOverviewMetric(
                    id: "window",
                    icon: "clock.fill",
                    title: l.tr(zh: "时间段", en: "Window", de: "Zeit"),
                    value: windowTitle(PlantReminderPreferenceStore.timeWindow()),
                    tint: Color.goTeal
                )
            }

            reminderEffectSummary
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("settings-plant-reminders-overview")
    }

    private var reminderStateBadge: some View {
        Text(reminderStateBadgeText)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(reminderOverviewTint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(reminderOverviewTint.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(reminderOverviewTint.opacity(0.24), lineWidth: 1))
            .accessibilityIdentifier("settings-plant-reminders-state-badge")
    }

    private var reminderEffectSummary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reminderEffectIcon) // a11y: allow decorative effect icon; surrounding text carries meaning
                .font(OhanaFont.adaptive(size: 12, weight: .bold))
                .foregroundStyle(reminderOverviewTint)
                .frame(width: 26, height: 26) // a11y: allow decorative non-interactive status glyph
                .background(reminderOverviewTint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(reminderEffectText)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.leading, 9)
        .accessibilityIdentifier("settings-plant-reminders-effect")
    }

    private func reminderOverviewMetric(
        id: String,
        icon: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative metric icon; label/value text is exposed
                .font(OhanaFont.adaptive(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings-plant-reminders-overview-metric-\(id)")
    }

    private var masterRow: some View {
        toggleRow(
            icon: "leaf.fill",
            title: l.tr(
                zh: "植物护理提醒",
                en: "Plant care reminders",
                de: "Pflanzenpflege-Erinnerungen"
            ),
            subtitle: l.tr(
                zh: "控制植物护理计划、提醒和系统通知",
                en: "Controls plant care plans, reminders, and notifications",
                de: "Steuert Pflanzenpflegepläne, Erinnerungen und Mitteilungen"
            ),
            isOn: Binding(
                get: { NotificationPreferenceStore.isEnabled(.plantCare) },
                set: { value in
                    NotificationPreferenceStore.set(value, for: .plantCare)
                    applyPreferenceChange()
                }
            )
        )
        .accessibilityIdentifier("settings-plant-reminders-master-toggle")
    }

    private var timeWindowRow: some View {
        HStack(spacing: 12) {
            settingsIcon("clock.badge.checkmark", color: Color.goTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "提醒时间段", en: "Reminder window", de: "Erinnerungsfenster"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(windowSubtitle(PlantReminderPreferenceStore.timeWindow()))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Menu {
                ForEach(PlantReminderTimeWindow.allCases) { window in
                    Button {
                        PlantReminderPreferenceStore.setTimeWindow(window)
                        applyPreferenceChange()
                    } label: {
                        Label(
                            windowTitle(window),
                            systemImage: window == PlantReminderPreferenceStore.timeWindow() ? "checkmark" : "clock"
                        )
                    }
                }
            } label: {
                menuValueLabel(windowTitle(PlantReminderPreferenceStore.timeWindow()))
            }
        }
        .frame(minHeight: 52)
    }

    private var weekendQuietRow: some View {
        toggleRow(
            icon: "calendar.badge.clock",
            title: l.tr(zh: "周末安静", en: "Quiet weekends", de: "Ruhige Wochenenden"),
            subtitle: l.tr(
                zh: "周末植物推送顺延到下一个工作日",
                en: "Weekend plant notifications move to the next weekday",
                de: "Pflanzenmitteilungen am Wochenende wandern zum nächsten Werktag"
            ),
            isOn: Binding(
                get: { PlantReminderPreferenceStore.isWeekendQuietEnabled() },
                set: { value in
                    PlantReminderPreferenceStore.setWeekendQuietEnabled(value)
                    applyPreferenceChange()
                }
            )
        )
    }

    private var travelModeRow: some View {
        toggleRow(
            icon: "airplane.departure",
            title: l.tr(zh: "旅行模式", en: "Travel mode", de: "Reisemodus"),
            subtitle: l.tr(
                zh: "暂停植物系统推送，保留 App 内任务",
                en: "Pauses plant push notifications while keeping in-app tasks",
                de: "Pausiert Pflanzenmitteilungen und behält Aufgaben in der App"
            ),
            isOn: Binding(
                get: { PlantReminderPreferenceStore.isTravelModeEnabled() },
                set: { value in
                    PlantReminderPreferenceStore.setTravelModeEnabled(value)
                    applyPreferenceChange()
                }
            )
        )
    }

    private var careTypeRows: some View {
        VStack(spacing: 0) {
            groupHeader(
                icon: "slider.horizontal.3",
                title: l.tr(zh: "任务类型", en: "Task types", de: "Aufgabentypen"),
                subtitle: l.tr(
                    zh: "关闭后不生成对应日历提醒",
                    en: "Disabled types stop creating calendar reminders",
                    de: "Deaktivierte Typen erzeugen keine Kalendererinnerungen"
                )
            )
            ForEach(PlantReminderPreferenceStore.controllableCareTypes) { type in
                HStack(spacing: 12) {
                    settingsIcon(careSymbol(for: type), color: careTint(for: type))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.displayName)
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(primaryText)
                        Text(careTypeReminderSummary(for: type))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { PlantReminderPreferenceStore.isCareTypeReminderEnabled(type) },
                        set: { value in
                            PlantReminderPreferenceStore.setCareTypeReminderEnabled(value, for: type)
                            applyPreferenceChange()
                        }
                    ))
                    .tint(accentColor)
                    .labelsHidden()
                }
                .frame(minHeight: 42)
                .padding(.leading, 44)
                .accessibilityIdentifier("settings-plant-reminders-care-type-\(type.rawValue)")
            }
        }
    }

    private var plantRows: some View {
        VStack(spacing: 0) {
            groupHeader(
                icon: "leaf.arrow.triangle.circlepath",
                title: l.tr(zh: "单株提醒", en: "Per-plant reminders", de: "Erinnerungen pro Pflanze"),
                subtitle: l.tr(
                    zh: "单独暂停某一株植物的日历提醒",
                    en: "Pause calendar reminders for a specific plant",
                    de: "Kalendererinnerungen für einzelne Pflanzen pausieren"
                )
            )
            .accessibilityIdentifier("settings-plant-reminders-plant-section")
            if plants.isEmpty {
                Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 44)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("settings-plant-reminders-empty-state")
            } else {
                ForEach(plants) { plant in
                    HStack(spacing: 12) {
                        plantReminderAvatar(for: plant)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name)
                                .font(OhanaFont.body(.semibold))
                                .foregroundStyle(primaryText)
                            Text(plantReminderRowSubtitle(for: plant))
                                .font(OhanaFont.caption2(.semibold))
                                .foregroundStyle(tertiaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle(
                            isOn: Binding(
                                get: { plantRemindersEnabled(for: plant) },
                                set: { setPlantRemindersEnabled($0, for: plant) }
                            )
                        ) {
                            Text(plantReminderAccessibilityLabel(plant))
                        }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(accentColor)
                        .accessibilityLabel(plantReminderAccessibilityLabel(plant))
                        .accessibilityValue(plantReminderAccessibilityValue(plant))
                        .accessibilityHint(l.tr(
                            zh: "双击切换这株植物的日历提醒",
                            en: "Double tap to toggle calendar reminders for this plant",
                            de: "Doppeltippen, um Kalendererinnerungen für diese Pflanze umzuschalten"
                        ))
                        .accessibilityIdentifier("settings-plant-reminders-plant-toggle-\(plantReminderIdentifierSlug(for: plant))")
                    }
                    .frame(minHeight: 46)
                    .padding(.leading, 44)
                    .accessibilityIdentifier("settings-plant-reminders-plant-row-\(plant.id.uuidString)")
                }
            }
        }
    }

    private var bulkDeferSection: some View {
        ZStack(alignment: .bottomLeading) {
            bulkDeferRow
            bulkDeferInlineStatusText(statusMessage ?? bulkDeferReadyMessage())
        }
    }

    private func bulkDeferInlineStatusText(_ message: String) -> some View {
        Text(message)
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(tertiaryText)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 56)
            .padding(.trailing, 12)
            .padding(.bottom, 5)
            .allowsHitTesting(false)
            .accessibilityIdentifier("settings-plant-reminders-status")
    }

    private var bulkDeferRow: some View {
        Button(action: performBulkDefer) {
            HStack(spacing: 12) {
                settingsIcon("clock.arrow.circlepath", color: Color.goYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "全部延后一天", en: "Defer all by one day", de: "Alle um einen Tag verschieben"))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(primaryText)
                    Text(l.tr(
                        zh: "只处理当前已到期的植物任务",
                        en: "Only applies to currently due plant tasks",
                        de: "Gilt nur für aktuell fällige Pflanzenaufgaben"
                    ))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
                }
                .padding(.bottom, 18)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(isBulkDeferPending)
        .opacity(isBulkDeferPending ? 0.62 : 1)
        .accessibilityValue(statusMessage ?? "")
        .accessibilityIdentifier("settings-plant-reminders-defer-all")
    }

    private func plantRemindersEnabled(for plant: Plant) -> Bool {
        plantReminderDisplayState[plant.id] ?? plant.remindersEnabled
    }

    private var enabledPlantReminderCount: Int {
        plants.reduce(0) { count, plant in
            count + (plantRemindersEnabled(for: plant) ? 1 : 0)
        }
    }

    private var mutedPlantReminderCount: Int {
        max(0, plants.count - enabledPlantReminderCount)
    }

    private var enabledCareTypeReminderCount: Int {
        PlantReminderPreferenceStore.controllableCareTypes.reduce(0) { count, type in
            count + (PlantReminderPreferenceStore.isCareTypeReminderEnabled(type) ? 1 : 0)
        }
    }

    private var reminderOverviewTint: Color {
        if !NotificationPreferenceStore.isEnabled(.plantCare) || PlantReminderPreferenceStore.isTravelModeEnabled() {
            return Color.goYellow
        }
        if mutedPlantReminderCount > 0 || enabledCareTypeReminderCount < PlantReminderPreferenceStore.controllableCareTypes.count {
            return Color.goTeal
        }
        return Color.goPrimary
    }

    private var reminderOverviewIcon: String {
        if !NotificationPreferenceStore.isEnabled(.plantCare) || PlantReminderPreferenceStore.isTravelModeEnabled() {
            return "bell.slash.fill"
        }
        if mutedPlantReminderCount > 0 {
            return "bell.badge.fill"
        }
        return "bell.and.waves.left.and.right.fill"
    }

    private var reminderOverviewTitle: String {
        if !NotificationPreferenceStore.isEnabled(.plantCare) {
            return l.tr(zh: "植物提醒已暂停", en: "Plant reminders are paused", de: "Pflanzenerinnerungen pausiert")
        }
        if PlantReminderPreferenceStore.isTravelModeEnabled() {
            return l.tr(zh: "旅行模式正在生效", en: "Travel mode is active", de: "Reisemodus ist aktiv")
        }
        if mutedPlantReminderCount > 0 {
            return l.tr(zh: "\(mutedPlantReminderCount) 株植物已单独静音", en: "\(mutedPlantReminderCount) plants are muted", de: "\(mutedPlantReminderCount) Pflanzen sind stumm")
        }
        return l.tr(zh: "植物提醒覆盖正常", en: "Plant reminders are covered", de: "Pflanzenerinnerungen sind abgedeckt")
    }

    private var reminderOverviewSubtitle: String {
        if plants.isEmpty {
            return l.tr(zh: "添加植物后，这里会显示日历计划和通知覆盖。", en: "Add plants to see calendar plans and notification coverage here.", de: "Nach dem Hinzufügen von Pflanzen erscheinen hier Kalenderpläne und Mitteilungen.")
        }
        return l.tr(
            zh: "\(enabledPlantReminderCount) 株开启 · \(enabledCareTypeReminderCount) 类任务会生成日历提醒",
            en: "\(enabledPlantReminderCount) plants on · \(enabledCareTypeReminderCount) task types create calendar reminders",
            de: "\(enabledPlantReminderCount) Pflanzen aktiv · \(enabledCareTypeReminderCount) Aufgabentypen erzeugen Kalendererinnerungen"
        )
    }

    private var reminderStateBadgeText: String {
        if !NotificationPreferenceStore.isEnabled(.plantCare) {
            return l.tr(zh: "已关闭", en: "Off", de: "Aus")
        }
        if PlantReminderPreferenceStore.isTravelModeEnabled() {
            return l.tr(zh: "旅行中", en: "Travel", de: "Reise")
        }
        if mutedPlantReminderCount > 0 {
            return l.tr(zh: "部分开启", en: "Partial", de: "Teilweise")
        }
        return l.tr(zh: "生效中", en: "Active", de: "Aktiv")
    }

    private var reminderEffectIcon: String {
        if !NotificationPreferenceStore.isEnabled(.plantCare) || PlantReminderPreferenceStore.isTravelModeEnabled() {
            return "bell.slash"
        }
        if PlantReminderPreferenceStore.isWeekendQuietEnabled() {
            return "calendar.badge.clock"
        }
        return "calendar.badge.checkmark"
    }

    private var reminderEffectText: String {
        if !NotificationPreferenceStore.isEnabled(.plantCare) {
            return l.tr(
                zh: "系统推送和植物护理提醒会暂停；App 内护理任务仍保留。",
                en: "System pushes and plant care reminders pause; in-app care tasks remain.",
                de: "Systemmitteilungen und Pflanzenpflege-Erinnerungen pausieren; In-App-Aufgaben bleiben erhalten."
            )
        }
        if PlantReminderPreferenceStore.isTravelModeEnabled() {
            return l.tr(
                zh: "旅行模式暂停系统推送，但不会删除 App 内任务和护理计划。",
                en: "Travel mode pauses system pushes without deleting in-app tasks or care plans.",
                de: "Der Reisemodus pausiert Systemmitteilungen, ohne Aufgaben oder Pflegepläne zu löschen."
            )
        }
        if PlantReminderPreferenceStore.isWeekendQuietEnabled() {
            return l.tr(
                zh: "到期提醒会在 \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())) 发送；周末推送顺延到工作日。",
                en: "Due reminders send during \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())); weekend pushes move to weekdays.",
                de: "Fällige Erinnerungen kommen zwischen \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())); Wochenenden wandern auf Werktage."
            )
        }
        return l.tr(
            zh: "到期提醒会在 \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())) 发送，并同步到首页日历。",
            en: "Due reminders send during \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())) and sync to the Home calendar.",
            de: "Fällige Erinnerungen kommen zwischen \(windowSubtitle(PlantReminderPreferenceStore.timeWindow())) und synchronisieren den Pflegekalender."
        )
    }

    private func careTypeReminderSummary(for type: PlantCareType) -> String {
        PlantReminderPreferenceStore.isCareTypeReminderEnabled(type)
            ? l.tr(zh: "会生成日历提醒", en: "Creates calendar reminders", de: "Erzeugt Kalendererinnerungen")
            : l.tr(zh: "已从日历提醒中排除", en: "Excluded from calendar reminders", de: "Von Kalendererinnerungen ausgeschlossen")
    }

    private func plantReminderAvatar(for plant: Plant) -> some View {
        let isOn = plantRemindersEnabled(for: plant)
        let tint = isOn ? Color.goPrimary : Color.goYellow
        return ZStack {
            Circle().fill(tint.opacity(0.14))
            Image(systemName: isOn ? "leaf.fill" : "bell.slash.fill")
                .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow decorative plant reminder status icon
                .foregroundStyle(tint)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    private func plantReminderRowSubtitle(for plant: Plant) -> String {
        let placement = plant.location.isEmpty ? plant.species : plant.location
        let fallback = placement.isEmpty ? l.tr(zh: "未设置位置", en: "Placement unset", de: "Standort fehlt") : placement
        let state = plantRemindersEnabled(for: plant)
            ? l.tr(zh: "提醒开启", en: "Reminders on", de: "Erinnerungen ein")
            : l.tr(zh: "已静音", en: "Muted", de: "Stumm")
        return "\(fallback) · \(state)"
    }

    private func plantReminderAccessibilityLabel(_ plant: Plant) -> String {
        let name = plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name
        return l.tr(
            zh: "\(name) 提醒",
            en: "\(name) reminders",
            de: "Erinnerungen für \(name)"
        )
    }

    private func plantReminderAccessibilityValue(_ plant: Plant) -> String {
        plantRemindersEnabled(for: plant)
            ? l.tr(zh: "开启", en: "On", de: "Ein")
            : l.tr(zh: "关闭", en: "Off", de: "Aus")
    }

    private func plantReminderIdentifierSlug(for plant: Plant) -> String {
        let source = plant.name.isEmpty ? plant.id.uuidString : plant.name
        let folded = source.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()
        var slug = ""
        var didAppendSeparator = false

        for scalar in folded.unicodeScalars {
            let value = scalar.value
            if (48 ... 57).contains(value) || (97 ... 122).contains(value) {
                slug.unicodeScalars.append(scalar)
                didAppendSeparator = false
            } else if !slug.isEmpty, !didAppendSeparator {
                slug.append("-")
                didAppendSeparator = true
            }
        }

        while slug.last == "-" {
            slug.removeLast()
        }
        return slug.isEmpty ? plant.id.uuidString.lowercased() : slug
    }

    private func setPlantRemindersEnabled(_ enabled: Bool, for plant: Plant) {
        plantReminderDisplayState[plant.id] = enabled
        if plant.remindersEnabled == enabled {
            pendingPlantReminderUpdates.removeValue(forKey: plant.id)
            return
        }
        pendingPlantReminderUpdates[plant.id] = PendingPlantReminderUpdate(
            plantID: plant.id,
            enabled: enabled
        )
    }

    private func flushPendingPlantReminderUpdates() {
        guard !pendingPlantReminderUpdates.isEmpty else { return }

        let updates = pendingPlantReminderUpdates
        pendingPlantReminderUpdates.removeAll()
        for update in updates.values {
            guard let plant = plants.first(where: { $0.id == update.plantID }) else { continue }
            let result = appServices.plantReminderControls.setPlantRemindersEnabled(
                update.enabled,
                plant: plant,
                context: modelContext
            )
            guard result.didPersist else {
                plantReminderDisplayState[plant.id] = plant.remindersEnabled
                statusMessage = plantReminderPersistenceFailureMessage(result.persistenceErrorDescription)
                continue
            }
        }
    }

    private func performBulkDefer() {
        guard !isBulkDeferPending else { return }
        guard !SettingsDebugTools.isRunningUITests else {
            statusMessage = bulkDeferUITestMessage()
            return
        }

        isBulkDeferPending = true
        statusMessage = bulkDeferInProgressMessage()

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 120)
            let result = appServices.plantReminderControls.deferDueTasksOneDay(
                plants: plants,
                context: modelContext,
                executorId: currentActiveHumanId.isEmpty ? nil : currentActiveHumanId,
                now: Date(),
                calendar: .current,
                scheduleNotifications: true,
                notifications: ReminderNotificationSchedulerRegistry.current,
                defaults: .standard
            )
            statusMessage = bulkDeferMessage(result)
            isBulkDeferPending = false
            UIImpactFeedbackGenerator(style: result.didPersist && result.deferredTaskCount > 0 ? .medium : .light).impactOccurred()
        }
    }

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 52)
    }

    private func groupHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
        }
        .frame(minHeight: 48)
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(OhanaFont.adaptive(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .symbolRenderingMode(.monochrome)
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    private func menuValueLabel(_ title: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Image(systemName: "chevron.down") // a11y: allow decorative dropdown affordance covered by menu label
                .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .accessibilityHidden(true)
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 34)
        .padding(.horizontal, 10)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    private func applyPreferenceChange() {
        let resyncedCount = appServices.plantReminderControls.resyncPlans(
            plants: plants,
            context: modelContext
        )
        statusMessage = l.tr(
            zh: "已更新 \(resyncedCount) 株植物的提醒计划",
            en: "Updated reminder plans for \(resyncedCount) plants",
            de: "Erinnerungspläne für \(resyncedCount) Pflanzen aktualisiert"
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func windowTitle(_ window: PlantReminderTimeWindow) -> String {
        switch window {
        case .morning:
            l.tr(zh: "上午", en: "Morning", de: "Vormittag")
        case .midday:
            l.tr(zh: "中午", en: "Midday", de: "Mittag")
        case .evening:
            l.tr(zh: "傍晚", en: "Evening", de: "Abend")
        }
    }

    private func windowSubtitle(_ window: PlantReminderTimeWindow) -> String {
        String(format: "%02d:%02d - %02d:00", window.startHour, window.minute, window.endHour)
    }

    private func bulkDeferMessage(_ result: PlantReminderBulkDeferResult) -> String {
        if !result.didPersist {
            return plantReminderPersistenceFailureMessage(result.persistenceErrorDescription)
        }
        if result.deferredTaskCount == 0 {
            return l.tr(
                zh: "当前没有已到期的植物任务",
                en: "No plant tasks are due right now",
                de: "Aktuell sind keine Pflanzenaufgaben fällig"
            )
        }
        return l.tr(
            zh: "已延后 \(result.affectedPlantCount) 株植物的 \(result.deferredTaskCount) 个任务",
            en: "Deferred \(result.deferredTaskCount) tasks across \(result.affectedPlantCount) plants",
            de: "\(result.deferredTaskCount) Aufgaben für \(result.affectedPlantCount) Pflanzen verschoben"
        )
    }

    private func plantReminderPersistenceFailureMessage(_ errorDescription: String?) -> String {
        if let errorDescription, !errorDescription.isEmpty {
            return l.tr(
                zh: "保存植物提醒失败：\(errorDescription)",
                en: "Could not save plant reminders: \(errorDescription)",
                de: "Pflanzenerinnerungen konnten nicht gespeichert werden: \(errorDescription)"
            )
        }
        return l.tr(
            zh: "保存植物提醒失败，请稍后重试",
            en: "Could not save plant reminders. Try again later.",
            de: "Pflanzenerinnerungen konnten nicht gespeichert werden. Bitte später erneut versuchen."
        )
    }

    private func bulkDeferInProgressMessage() -> String {
        l.tr(
            zh: "正在延后到期植物任务…",
            en: "Deferring due plant tasks...",
            de: "Fällige Pflanzenaufgaben werden verschoben..."
        )
    }

    private func bulkDeferReadyMessage() -> String {
        l.tr(
            zh: "点击后会延后当前已到期的植物任务",
            en: "Tap to defer plant tasks that are currently due",
            de: "Tippen, um aktuell fällige Pflanzenaufgaben zu verschieben"
        )
    }

    private func bulkDeferUITestMessage() -> String {
        l.tr(
            zh: "当前没有已到期的植物任务",
            en: "No plant tasks are due right now",
            de: "Aktuell sind keine Pflanzenaufgaben fällig"
        )
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }
}

private struct PendingPlantReminderUpdate: Equatable {
    let plantID: UUID
    let enabled: Bool
}
