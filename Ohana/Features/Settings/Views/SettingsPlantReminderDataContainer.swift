//
//  SettingsPlantReminderDataContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct SettingsPlantReminderDataContainer: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: SettingsPlantReminderRouteData(),
            loadDelayMilliseconds: 80,
            shouldLoad: { !$0.hasLoaded },
            load: { SettingsPlantReminderRouteData.load(from: modelContext) }
        ) { data in
            SettingsPlantReminderPanelContent(plants: data.plants)
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
    @State private var preferenceRevision = 0
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
                }
            }
        }
        .id(preferenceRevision)
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
            if plants.isEmpty {
                Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 44)
                    .padding(.vertical, 8)
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
                        Toggle("", isOn: Binding(
                            get: { plant.remindersEnabled },
                            set: { value in
                                appServices.plantReminderControls.setPlantRemindersEnabled(
                                    value,
                                    plant: plant,
                                    context: modelContext
                                )
                                statusMessage = plantToggleMessage(plant, enabled: value)
                                preferenceRevision += 1
                            }
                        ))
                        .tint(accentColor)
                        .labelsHidden()
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
            preferenceRevision += 1
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
        preferenceRevision += 1
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

    private func plantToggleMessage(_ plant: Plant, enabled: Bool) -> String {
        l.tr(
            zh: "\(plant.name) \(enabled ? "已开启提醒" : "已静音")",
            en: "\(plant.name) reminders \(enabled ? "enabled" : "muted")",
            de: "Erinnerungen für \(plant.name) \(enabled ? "aktiviert" : "stummgeschaltet")"
        )
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
