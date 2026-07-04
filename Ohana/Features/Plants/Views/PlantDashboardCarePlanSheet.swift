//
//  PlantDashboardCarePlanSheet.swift
//  Ohana
//
//  Seven-day plant care plan overview for the Plants dashboard.
//

import SwiftUI

struct PlantDashboardCarePlanSheet: View {
    let plants: [Plant]
    let careTasks: [PlantCareTaskSnapshot]
    let onOpenPlant: (UUID) -> Void
    let onOpenCareLog: (Plant, PlantCareType) -> Void
    let onCompleteDueTasks: () -> Void
    let onDeferDueTasks: () -> Void
    let onDeferTask: (PlantCareTaskSnapshot) -> Void
    let onSkipTask: (PlantCareTaskSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

    private var sortedTasks: [PlantCareTaskSnapshot] {
        careTasks.sorted { lhs, rhs in
            if lhs.daysUntilDue != rhs.daysUntilDue {
                return lhs.daysUntilDue < rhs.daysUntilDue
            }
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private var dueTasks: [PlantCareTaskSnapshot] {
        sortedTasks.filter { $0.daysUntilDue <= 0 }
    }

    private var upcomingTasks: [PlantCareTaskSnapshot] {
        sortedTasks.filter { $0.daysUntilDue > 0 }
    }

    private var duePlantCount: Int {
        Set(dueTasks.map(\.plantID)).count
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "植物护理计划", en: "Plant care plan", de: "Pflanzenpflegeplan"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if !dueTasks.isEmpty {
                    dueSection
                }

                if !upcomingTasks.isEmpty {
                    upcomingSection
                }

                if sortedTasks.isEmpty {
                    emptyState
                }
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-dashboard-care-plan-sheet")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.clock") // a11y: allow decorative care-plan glyph; heading and metrics name this sheet.
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "未来 7 天", en: "Next 7 days", de: "Nächste 7 Tage"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .textCase(.uppercase)
                    Text(l.tr(
                        zh: "集中处理浇水、施肥和复查任务。",
                        en: "Review watering, fertilizing, and recheck tasks together.",
                        de: "Gießen, Düngen und Checks gemeinsam prüfen."
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                metricPill(
                    icon: "calendar.badge.exclamationmark",
                    value: "\(dueTasks.count)",
                    label: l.tr(zh: "到期", en: "Due", de: "Fällig"),
                    tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow
                )
                metricPill(
                    icon: "leaf.fill",
                    value: "\(duePlantCount)",
                    label: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                    tint: Color.goTeal
                )
                metricPill(
                    icon: "calendar",
                    value: "\(upcomingTasks.count)",
                    label: l.tr(zh: "即将", en: "Upcoming", de: "Bald"),
                    tint: Color.goPrimary
                )
            }

            if !dueTasks.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        onCompleteDueTasks()
                        dismiss()
                    } label: {
                        Text(l.tr(zh: "全部完成", en: "Complete all", de: "Alle erledigen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("plant-dashboard-care-plan-complete-all")

                    Button {
                        onDeferDueTasks()
                        dismiss()
                    } label: {
                        Text(l.tr(zh: "延后一天", en: "Defer one day", de: "Um einen Tag"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("plant-dashboard-care-plan-defer-all")
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var dueSection: some View {
        taskSection(
            title: l.tr(zh: "今天要处理", en: "Needs care today", de: "Heute pflegen"),
            detail: l.tr(zh: "\(dueTasks.count) 项", en: "\(dueTasks.count) tasks", de: "\(dueTasks.count) Aufgaben"),
            tasks: dueTasks,
            identifier: "plant-dashboard-care-plan-due"
        )
    }

    private var upcomingSection: some View {
        taskSection(
            title: l.tr(zh: "接下来", en: "Coming up", de: "Als Nächstes"),
            detail: l.tr(zh: "\(upcomingTasks.count) 项", en: "\(upcomingTasks.count) tasks", de: "\(upcomingTasks.count) Aufgaben"),
            tasks: upcomingTasks,
            identifier: "plant-dashboard-care-plan-upcoming"
        )
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative empty plan glyph; text explains state.
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "本周没有植物任务", en: "No plant tasks this week", de: "Diese Woche keine Pflanzenaufgaben"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "可以补照片、完善摆放位置或记录一次观察。",
                    en: "Add photos, refine locations, or log an observation.",
                    de: "Fotos ergänzen, Standorte verbessern oder Beobachtung erfassen."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-care-plan-empty")
    }

    private func taskSection(
        title: String,
        detail: String,
        tasks: [PlantCareTaskSnapshot],
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 8)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    if let plant = plant(for: task) {
                        taskRow(task, plant: plant)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func taskRow(_ task: PlantCareTaskSnapshot, plant: Plant) -> some View {
        let careTypeName = task.careType.displayName(l: l)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: careSymbol(for: task.careType)) // a11y: allow decorative task glyph; row text and buttons name actions.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(careTint(for: task.careType))
                    .frame(width: 34, height: 34) // a11y: allow non-interactive task glyph; buttons provide 44pt hit targets.
                    .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(plant.name) · \(careTypeName)")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(task.subtitle) · \(dueText(for: task))")
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)

                Button {
                    onOpenPlant(plant.id)
                    dismiss()
                } label: {
                    Image(systemName: "arrow.right") // a11y: allow decorative open glyph; accessibility label names destination.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "打开\(plant.name)", en: "Open \(plant.name)", de: "\(plant.name) öffnen"))

                Button {
                    onOpenCareLog(plant, task.careType)
                } label: {
                    Image(systemName: "checkmark") // a11y: allow decorative log glyph; accessibility label names the care log.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(Color.goPrimary, in: Circle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "记录\(plant.name)的\(careTypeName)", en: "Log \(careTypeName) for \(plant.name)", de: "\(careTypeName) für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-dashboard-care-plan-task-\(task.id)")
            }

            HStack(spacing: 8) {
                taskFeedbackButton(
                    title: l.tr(zh: "延后一天", en: "Defer 1 day", de: "1 Tag später"),
                    identifier: "plant-dashboard-care-plan-task-defer-\(task.id)",
                    accessibilityLabel: l.tr(zh: "延后\(plant.name)的\(careTypeName)一天", en: "Defer \(careTypeName) for \(plant.name) by one day", de: "\(careTypeName) für \(plant.name) um einen Tag verschieben")
                ) {
                    onDeferTask(task)
                    dismiss()
                }

                taskFeedbackButton(
                    title: l.tr(zh: "跳过", en: "Skip", de: "Überspringen"),
                    identifier: "plant-dashboard-care-plan-task-skip-\(task.id)",
                    accessibilityLabel: l.tr(zh: "跳过\(plant.name)的\(careTypeName)", en: "Skip \(careTypeName) for \(plant.name)", de: "\(careTypeName) für \(plant.name) überspringen")
                ) {
                    onSkipTask(task)
                    dismiss()
                }
            }
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func taskFeedbackButton(
        title: String,
        identifier: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    private func metricPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon) // a11y: allow decorative metric glyph; adjacent text gives value.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func plant(for task: PlantCareTaskSnapshot) -> Plant? {
        plants.first { $0.id == task.plantID }
    }

    private func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            return l.tr(
                zh: "逾期 \(abs(task.daysUntilDue)) 天",
                en: "\(abs(task.daysUntilDue))d overdue",
                de: "\(abs(task.daysUntilDue)) T. überfällig"
            )
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return l.tr(
            zh: "\(task.daysUntilDue) 天后",
            en: "In \(task.daysUntilDue)d",
            de: "In \(task.daysUntilDue) T."
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
