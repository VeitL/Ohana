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
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var plantReminderDisplayState: [UUID: Bool] = [:]
    @State private var pendingPlantReminderUpdates: [UUID: PendingPlantReminderUpdate] = [:]
    @State private var statusMessage: String?

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerLine: Color { Color.ohanaDivider }
    private var accentColor: Color { Color.goPrimary }

    var body: some View {
        VStack(spacing: 0) {
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
                bulkDeferRow
                if let statusMessage {
                    Text(statusMessage)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.leading, 44)
                        .accessibilityIdentifier("settings-plant-reminders-status")
                }
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

    private var masterRow: some View {
        toggleRow(
            icon: "leaf.fill",
            title: l.tr(
                zh: "植物护理提醒",
                en: "Plant care reminders",
                de: "Pflanzenpflege-Erinnerungen"
            ),
            subtitle: l.tr(
                zh: "控制植物日历、提醒和系统通知",
                en: "Controls plant calendar, reminders, and notifications",
                de: "Steuert Pflanzenkalender, Erinnerungen und Mitteilungen"
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
                    Text(type.emoji)
                        .font(OhanaFont.body(.semibold))
                        .frame(width: 44, height: 44)
                    Text(type.displayName)
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(primaryText)
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
                        Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
                            .font(OhanaFont.body(.semibold))
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name)
                                .font(OhanaFont.body(.semibold))
                                .foregroundStyle(primaryText)
                            Text(plant.location.isEmpty ? plant.species : plant.location)
                                .font(OhanaFont.caption2(.semibold))
                                .foregroundStyle(tertiaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            togglePlantReminders(for: plant)
                        } label: {
                            plantReminderToggleIndicator(isOn: plantRemindersEnabled(for: plant))
                        }
                        .buttonStyle(.plain) // ui-v4: allow switch indicator owns visual state; scale feedback delayed UI-test idle on this compact control
                        .contentShape(Rectangle())
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .frame(width: 50, height: 30)
                            .accessibilityLabel(plantReminderAccessibilityLabel(plant))
                            .accessibilityValue(plantReminderAccessibilityValue(plant))
                            .accessibilityHint(l.tr(
                                zh: "双击切换这株植物的日历提醒",
                                en: "Double tap to toggle calendar reminders for this plant",
                                de: "Doppeltippen, um Kalendererinnerungen für diese Pflanze umzuschalten"
                            ))
                            .accessibilityIdentifier("settings-plant-reminders-plant-toggle-\(plant.name)")
                    }
                    .frame(minHeight: 46)
                    .padding(.leading, 44)
                }
            }
        }
    }

    private var bulkDeferRow: some View {
        Button {
            let result = appServices.plantReminderControls.deferDueTasksOneDay(
                plants: plants,
                context: modelContext,
                executorId: currentActiveHumanId.isEmpty ? nil : currentActiveHumanId
            )
            statusMessage = bulkDeferMessage(result)
            UIImpactFeedbackGenerator(style: result.deferredTaskCount > 0 ? .medium : .light).impactOccurred()
        } label: {
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
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding button text
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                    .foregroundStyle(tertiaryText.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("settings-plant-reminders-defer-all")
    }

    private func plantRemindersEnabled(for plant: Plant) -> Bool {
        plantReminderDisplayState[plant.id] ?? plant.remindersEnabled
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

    private func plantReminderToggleIndicator(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Circle()
                .fill(Color.ohanaCardSurface)
                .frame(width: 22, height: 22) // a11y: allow decorative toggle knob; compact button owns the accessible label/value
        }
        .padding(3)
        .frame(width: 50, height: 30)
        .background(
            Capsule().fill(isOn ? accentColor : Color.ohanaControlFill)
        )
        .overlay(
            Capsule().stroke(isOn ? Color.clear : dividerLine.opacity(0.7), lineWidth: 1)
        )
    }

    private func togglePlantReminders(for plant: Plant) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            setPlantRemindersEnabled(!plantRemindersEnabled(for: plant), for: plant)
        }
    }

    private func setPlantRemindersEnabled(_ enabled: Bool, for plant: Plant) {
        plantReminderDisplayState[plant.id] = enabled
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
            appServices.plantReminderControls.setPlantRemindersEnabled(
                update.enabled,
                plant: plant,
                context: modelContext
            )
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
        ZStack {
            Circle().fill(color.opacity(0.14))
            Image(systemName: systemName)
                .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow compact decorative settings token
                .foregroundStyle(color)
        }
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
}

private struct PendingPlantReminderUpdate: Equatable {
    let plantID: UUID
    let enabled: Bool
}
