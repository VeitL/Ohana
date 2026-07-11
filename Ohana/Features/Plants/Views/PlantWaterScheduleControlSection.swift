//
//  PlantWaterScheduleControlSection.swift
//  Ohana
//
//  Focused watering-plan form with explicit bindings and no persistence ownership.
//

import Foundation
import SwiftUI

struct PlantWaterScheduleControlBindings {
    let intervalDays: Binding<Int>
    let startDate: Binding<Date>
    let endEnabled: Binding<Bool>
    let endDate: Binding<Date>
    let planCalendarEnabled: Binding<Bool>
    let systemReminderEnabled: Binding<Bool>
    let reminderLeadDays: Binding<Int>
    let completionCalendarEnabled: Binding<Bool>
}

struct PlantWaterScheduleControlSection: View {
    let l: L10n
    let summary: String
    let persistenceError: String?
    let bindings: PlantWaterScheduleControlBindings
    let onResync: () -> Void

    private var reminderLeadTitle: String {
        (WaterReminderLeadOption(rawValue: bindings.reminderLeadDays.wrappedValue) ?? .sameDay).title(l: l)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            intervalControl
            startDateControl
            endDateControls
            planCalendarControl
            systemReminderControl
            reminderLeadControl
            completionCalendarControl
            persistenceErrorView
            resyncButton
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-schedule")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.clock") // a11y: allow decorative header glyph; adjacent text carries the content.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 36, height: 36) // a11y: allow non-interactive header glyph; this is not a hit target.
                .background(Color.goYellow.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "浇水计划与提醒", en: "Watering plan and reminders", de: "Gießplan und Erinnerungen"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summary)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var intervalControl: some View {
        controlSurface {
            Stepper(value: bindings.intervalDays, in: 1 ... 60) {
                controlText(
                    title: l.tr(zh: "浇水间隔", en: "Watering interval", de: "Gießintervall"),
                    value: l.tr(
                        zh: "每 \(bindings.intervalDays.wrappedValue) 天",
                        en: "Every \(bindings.intervalDays.wrappedValue)d",
                        de: "Alle \(bindings.intervalDays.wrappedValue) T."
                    ),
                    footnote: l.tr(zh: "用于计算下一次浇水和循环日历计划。", en: "Used for the next due date and recurring calendar plan.", de: "Wird für Fälligkeit und wiederkehrenden Kalenderplan genutzt.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-interval-stepper")
    }

    private var startDateControl: some View {
        controlSurface {
            DatePicker(selection: bindings.startDate, displayedComponents: [.date]) {
                controlText(
                    title: l.tr(zh: "起始日期", en: "Start date", de: "Startdatum"),
                    value: fullDateText(bindings.startDate.wrappedValue),
                    footnote: l.tr(zh: "按最近一次浇水作为计划起点。", en: "Uses the last watering date as the plan start.", de: "Nutzt das letzte Gießen als Planstart.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-start-date")
    }

    @ViewBuilder
    private var endDateControls: some View {
        controlSurface {
            Toggle(isOn: bindings.endEnabled) {
                controlText(
                    title: l.tr(zh: "设置结束日期", en: "Set end date", de: "Enddatum setzen"),
                    value: bindings.endEnabled.wrappedValue
                        ? fullDateText(bindings.endDate.wrappedValue)
                        : l.tr(zh: "长期循环", en: "No end date", de: "Ohne Enddatum"),
                    footnote: l.tr(zh: "开启后，循环计划会在结束日期停止。", en: "When enabled, the recurring plan stops at this date.", de: "Wenn aktiv, endet der wiederkehrende Plan an diesem Datum.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-end-enabled")

        if bindings.endEnabled.wrappedValue {
            controlSurface {
                DatePicker(selection: bindings.endDate, displayedComponents: [.date]) {
                    controlText(
                        title: l.tr(zh: "结束日期", en: "End date", de: "Enddatum"),
                        value: fullDateText(bindings.endDate.wrappedValue),
                        footnote: l.tr(zh: "计划到这天后停止循环。", en: "The recurring plan stops after this date.", de: "Der Plan endet nach diesem Datum.")
                    )
                }
                .tint(Color.goTeal)
            }
            .accessibilityIdentifier("plant-care-feature-water-end-date")
        }
    }

    private var planCalendarControl: some View {
        controlSurface {
            Toggle(isOn: bindings.planCalendarEnabled) {
                controlText(
                    title: l.tr(zh: "显示计划到日历", en: "Show plan in calendar", de: "Plan im Kalender zeigen"),
                    value: bindings.planCalendarEnabled.wrappedValue
                        ? l.tr(zh: "已显示", en: "Shown", de: "Angezeigt")
                        : l.tr(zh: "不显示", en: "Hidden", de: "Ausgeblendet"),
                    footnote: l.tr(zh: "只控制未来循环计划；不会删除已经完成的护理记录。", en: "Controls only the future recurring plan; completed care logs stay intact.", de: "Steuert nur den zukünftigen Plan; erledigte Einträge bleiben erhalten.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-calendar-toggle")
    }

    private var systemReminderControl: some View {
        controlSurface {
            Toggle(isOn: bindings.systemReminderEnabled) {
                controlText(
                    title: l.tr(zh: "系统提醒", en: "System alerts", de: "Systemhinweise"),
                    value: bindings.systemReminderEnabled.wrappedValue
                        ? l.tr(zh: "开启", en: "On", de: "Ein")
                        : l.tr(zh: "关闭", en: "Off", de: "Aus"),
                    footnote: l.tr(zh: "关闭后日历计划仍保留，但不会生成提醒或推送。", en: "When off, the calendar plan remains without reminders or push alerts.", de: "Bei Aus bleibt der Kalenderplan ohne Erinnerungen oder Push.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-system-reminder-toggle")
    }

    private var reminderLeadControl: some View {
        controlSurface {
            VStack(alignment: .leading, spacing: 10) {
                controlText(
                    title: l.tr(zh: "提前提醒时间", en: "Reminder lead time", de: "Vorlaufzeit"),
                    value: reminderLeadTitle,
                    footnote: l.tr(zh: "按当前提醒时间窗口发送。", en: "Delivered in the current reminder time window.", de: "Wird im aktuellen Erinnerungsfenster gesendet.")
                )

                Picker(selection: bindings.reminderLeadDays) {
                    ForEach(WaterReminderLeadOption.allCases) { option in
                        Text(option.title(l: l)).tag(option.rawValue)
                    }
                } label: {
                    Text(l.tr(zh: "提前提醒时间", en: "Reminder lead time", de: "Vorlaufzeit"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .tint(Color.goTeal)
            .opacity(bindings.systemReminderEnabled.wrappedValue ? 1 : 0.52)
            .disabled(!bindings.systemReminderEnabled.wrappedValue)
        }
        .accessibilityIdentifier("plant-care-feature-water-lead-picker")
    }

    private var completionCalendarControl: some View {
        controlSurface {
            Toggle(isOn: bindings.completionCalendarEnabled) {
                controlText(
                    title: l.tr(zh: "护理记录显示在日历", en: "Show completed logs in calendar", de: "Erledigte Einträge im Kalender"),
                    value: bindings.completionCalendarEnabled.wrappedValue
                        ? l.tr(zh: "显示", en: "Shown", de: "Angezeigt")
                        : l.tr(zh: "隐藏", en: "Hidden", de: "Ausgeblendet"),
                    footnote: l.tr(zh: "只影响浇水完成记录是否出现在日历；不会删除护理日志。", en: "Controls whether completed watering logs appear in Calendar; care logs are not deleted.", de: "Steuert nur Kalenderanzeige erledigter Einträge; Pflegeprotokolle bleiben erhalten.")
                )
            }
            .tint(Color.goTeal)
        }
        .accessibilityIdentifier("plant-care-feature-water-completion-calendar-toggle")
    }

    @ViewBuilder
    private var persistenceErrorView: some View {
        if let persistenceError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative error glyph; adjacent text announces the failure.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .accessibilityHidden(true)
                Text(persistenceError)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-schedule-error")
        }
    }

    private var resyncButton: some View {
        Button(action: onResync) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath") // a11y: allow decorative sync glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "同步浇水日历计划", en: "Sync watering calendar plan", de: "Gießkalender synchronisieren"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-care-feature-water-reminder-sync")
    }

    private func controlSurface(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }

    private func controlText(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(footnote)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fullDateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
