//
//  HumanWorkoutCard.swift
//  Ohana
//
//  U14: 人类运动卡片 + Apple Health-backed summary entry

import Combine
import SwiftData
import SwiftUI

// MARK: - HumanWorkoutCard
struct HumanWorkoutCard: View {
    let human: Human
    var pets: [Pet] = []
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var showWorkoutHistory = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var sortedLogs: [HumanWorkoutLog] {
        human.workoutLogs.sorted { $0.date > $1.date }
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button { showWorkoutHistory = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.18))
                            .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        Image(systemName: "figure.run").accessibilityHidden(true)
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                    Text(l.tr(zh: "运动记录", en: "Workout Records", de: "Trainingseinträge"))
                        .font(OhanaFont.headline())
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(ScaleButtonStyle())

            GoDashedDivider().padding(.horizontal, 16)

            // 本月运动统计
            let monthStart = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            let monthLogs = human.workoutLogs.filter { $0.date >= monthStart }
            let totalMinutes = monthLogs.reduce(0) { $0 + $1.durationMinutes }
            let totalKm = monthLogs.reduce(0.0) { $0 + $1.distanceKm }

            HStack(spacing: 0) {
                workoutStatCell(value: "\(monthLogs.count)", label: l.tr(zh: "本月次数", en: "This month", de: "Dieser Monat"), color: .goPrimary)
                Rectangle().fill(Color.ohanaDivider).frame(width: 1, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                workoutStatCell(value: "\(totalMinutes)", label: l.tr(zh: "总分钟", en: "Total min", de: "Minuten gesamt"), color: .goCardCyan)
                Rectangle().fill(Color.ohanaDivider).frame(width: 1, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                workoutStatCell(value: String(format: "%.1f", totalKm), label: l.tr(zh: "总公里", en: "Total km", de: "Kilometer gesamt"), color: .goOrange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            GoDashedDivider().padding(.horizontal, 16)

            // 最近记录（仅手动记录）
            if sortedLogs.isEmpty {
                emptyState
            } else {
                recentLogsSection
            }
        }
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
        .sheet(isPresented: $showAddSheet) {
            AddWorkoutSheet(human: human)
        }
        .sheet(isPresented: $showWorkoutHistory) {
            HumanWorkoutSummaryView(human: human)
        }
    }

    // MARK: - Recent Logs (仅手动记录)
    private var recentLogsSection: some View {
        VStack(spacing: 0) {
            ForEach(sortedLogs.prefix(3)) { log in
                workoutRow(
                    icon: log.workoutType.icon,
                    name: log.workoutType.localizedTitle(l),
                    duration: log.durationMinutes,
                    distance: log.distanceKm,
                    calories: log.calories,
                    date: log.date,
                    colorHex: log.workoutType.colorHex,
                    isHealthKit: log.sourceHealthKit,
                    isPetWalk: !log.sourcePetWalkLogID.isEmpty
                )
                if log.id != sortedLogs.prefix(3).last?.id {
                    GoDashedDivider().padding(.horizontal, 16)
                }
            }

            // 添加按钮 - 保留手动记录功能
            Button { showAddSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                    Text(l.tr(zh: "手动添加运动", en: "Add Manually", de: "Manuell hinzufügen"))
                        .font(OhanaFont.caption(.semibold))
                }
                .foregroundStyle(Color.goPrimary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-workout-add-action")
        }
    }

    private func workoutRow(
        icon: String,
        name: String,
        duration: Int,
        distance: Double,
        calories: Int,
        date: Date,
        colorHex: String,
        isHealthKit: Bool,
        isPetWalk: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: icon)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color(hex: colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if isHealthKit {
                        Text(l.tr(zh: "健康", en: "Health", de: "Health"))
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    if isPetWalk {
                        Text(l.tr(zh: "遛狗", en: "Dog Walk", de: "Hundegang"))
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.goCardCyan, in: Capsule())
                    }
                }
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(duration) min")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color(hex: colorHex))
                if distance > 0.01 {
                    Text(String(format: "%.1f km", distance))
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                } else if calories > 0 {
                    Text("\(calories) kcal")
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func workoutStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(color)
            Text(label)
                .font(OhanaFont.caption2())
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle").accessibilityHidden(true)
                .font(OhanaFont.metric(size: 36))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
            Text(l.tr(zh: "暂无运动记录", en: "No workouts yet", de: "Noch keine Trainings"))
                .font(OhanaFont.subheadline())
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            Button { showAddSheet = true } label: {
                Text(l.tr(zh: "+ 添加运动", en: "+ Add Workout", de: "+ Training hinzufügen"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-workout-add-action")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Add Workout Sheet
struct AddWorkoutSheet: View {
    let human: Human
    var onSaved: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices

    @State private var selectedType: WorkoutType = .running
    @State private var durationStr = ""
    @State private var distanceStr = ""
    @State private var caloriesStr = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var duration: Int { Int(durationStr) ?? 0 }
    private var distance: Double { Double(distanceStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var calories: Int { Int(caloriesStr) ?? 0 }
    private var canSave: Bool { duration > 0 }
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        workoutPreview

                        // 运动类型选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l.tr(zh: "运动类型", en: "Workout Type", de: "Trainingsart"))
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                                ForEach(WorkoutType.allCases, id: \.self) { type in
                                    workoutTypeButton(for: type)
                                }
                            }
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: OhanaRadius.input)

                        // 时长/距离/卡路里
                        VStack(spacing: 12) {
                            workoutField(icon: "timer", label: l.tr(zh: "时长（分钟）", en: "Duration (min)", de: "Dauer (Min.)"), placeholder: "0", text: $durationStr, color: .goPrimary, step: 5)
                            workoutField(icon: "map", label: l.tr(zh: "距离（公里，可选）", en: "Distance (km, optional)", de: "Distanz (km, optional)"), placeholder: "0.0", text: $distanceStr, color: .goCardCyan, step: 0.5)
                            workoutField(icon: "flame", label: l.tr(zh: "卡路里（可选）", en: "Calories (optional)", de: "Kalorien (optional)"), placeholder: "0", text: $caloriesStr, color: .goOrange, step: 5)
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: OhanaRadius.input)

                        // 日期
                        HStack {
                            Image(systemName: "calendar").accessibilityHidden(true)
                                .font(OhanaFont.callout())
                                .foregroundStyle(Color.goPrimary)
                            Text(l.tr(zh: "日期", en: "Date", de: "Datum"))
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: OhanaRadius.input)

                        // 备注
                        VStack(alignment: .leading, spacing: 8) {
                            Label(l.tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)"), systemImage: "note.text")
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            TextEditor(text: $notes)
                                .font(OhanaFont.body())
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80)
                                .padding(10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                                .accessibilityIdentifier("add-human-workout-notes-input")
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: OhanaRadius.input)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .navigationTitle(l.tr(zh: "添加运动记录", en: "Add Workout", de: "Training hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("add-human-workout-sheet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? l.tr(zh: "保存中", en: "Saving", de: "Speichert") : l.tr(zh: "保存", en: "Save", de: "Sichern")) { save() }
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(canSave ? Color.goPrimary : .secondary)
                        .disabled(!canSave || isSaving)
                        .accessibilityIdentifier("add-human-workout-save-action")
                }
            }
        }
    }

    private func workoutTypeButton(for type: WorkoutType) -> some View {
        let isSelected = selectedType == type
        let color = Color(hex: type.colorHex)

        return Button { selectedType = type } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(OhanaFont.title3())
                    .foregroundStyle(isSelected ? color : .primary.opacity(0.45))
                Text(type.localizedTitle(l))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? color.opacity(0.2) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.45) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("add-human-workout-type-\(type.rawValue)")
    }

    private var workoutPreview: some View {
        HStack(spacing: 14) {
            Image(systemName: selectedType.icon)
                .font(OhanaFont.adaptive(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: selectedType.colorHex))
                .frame(width: 56, height: 56)
                .background(Color(hex: selectedType.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(workoutPreviewTitle)
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(previewSubtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(16)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var previewSubtitle: String {
        var parts: [String] = []
        if duration > 0 { parts.append(l.tr(zh: "\(duration) 分钟", en: "\(duration) min", de: "\(duration) Min.")) }
        if distance > 0 { parts.append(l.tr(zh: String(format: "%.1f 公里", distance), en: String(format: "%.1f km", distance), de: String(format: "%.1f km", distance))) }
        if calories > 0 { parts.append("\(calories) kcal") }
        return parts.isEmpty ? l.tr(zh: "填写时长后即可保存", en: "Add duration to save", de: "Dauer eingeben, dann sichern") : parts.joined(separator: " · ")
    }

    private var workoutPreviewTitle: String {
        let title = selectedType.localizedTitle(l)
        return l.tr(zh: "\(human.name) 的\(title)", en: "\(title) for \(human.name)", de: "\(title) für \(human.name)")
    }

    private func workoutField(icon: String, label: String, placeholder: String, text: Binding<String>, color: Color, step: Double) -> some View {
        let allowsDecimal = placeholder.contains(".")
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.callout())
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
            Spacer()
            InlineNumericInput(
                text: text,
                placeholder: placeholder,
                maxFractionDigits: allowsDecimal ? 1 : 0,
                accent: color,
                step: step,
                valueFont: OhanaFont.callout(.bold),
                valueAlignment: .trailing,
                fill: Color.ohanaControlFill,
                cornerRadius: OhanaRadius.row,
                horizontalPadding: 10,
                verticalPadding: 6,
                inputAccessibilityIdentifier: workoutFieldIdentifier(for: label),
                decrementAccessibilityIdentifier: workoutFieldStepIdentifier(for: label, direction: "decrement"),
                incrementAccessibilityIdentifier: workoutFieldStepIdentifier(for: label, direction: "increment")
            )
            .frame(width: 102)
        }
    }

    private func workoutFieldIdentifier(for label: String) -> String? {
        if label == l.tr(zh: "时长（分钟）", en: "Duration (min)", de: "Dauer (Min.)") {
            return "add-human-workout-duration-input"
        }
        if label == l.tr(zh: "距离（公里，可选）", en: "Distance (km, optional)", de: "Distanz (km, optional)") {
            return "add-human-workout-distance-input"
        }
        if label == l.tr(zh: "卡路里（可选）", en: "Calories (optional)", de: "Kalorien (optional)") {
            return "add-human-workout-calories-input"
        }
        return nil
    }

    private func workoutFieldStepIdentifier(for label: String, direction: String) -> String? {
        if label == l.tr(zh: "时长（分钟）", en: "Duration (min)", de: "Dauer (Min.)") {
            return "add-human-workout-duration-\(direction)"
        }
        if label == l.tr(zh: "距离（公里，可选）", en: "Distance (km, optional)", de: "Distanz (km, optional)") {
            return "add-human-workout-distance-\(direction)"
        }
        if label == l.tr(zh: "卡路里（可选）", en: "Calories (optional)", de: "Kalorien (optional)") {
            return "add-human-workout-calories-\(direction)"
        }
        return nil
    }

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        let savedType = selectedType
        let savedDuration = duration
        let savedDistance = distance
        let savedCalories = calories
        let savedDate = date
        let savedNotes = notes
        let command = DomainCommand.humanWorkoutEntry(humanID: human.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).recordWorkout(
                human: human,
                type: savedType,
                durationMinutes: savedDuration,
                date: savedDate,
                distanceKm: savedDistance,
                calories: savedCalories,
                notes: savedNotes,
                source: .detail,
                command: command,
                note: "human.workout.create"
            )
            onSaved?()
            dismiss()
        }
    }
}

// MARK: - Workout History View
struct HumanWorkoutHistoryView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    @State private var showAddSheet = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.workout, viewedBy: activeHumanId) }
    private var l: L10n { L10n(appLanguage) }

    private var sortedLogs: [HumanWorkoutLog] {
        human.workoutLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OhanaAppBackground()

                if isPrivacyLocked {
                    privacyLockedView
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            HumanPrivateDataNotice(human: human, field: .workout)
                                .padding(.horizontal, 16)

                            summarySection
                                .padding(.horizontal, 16)

                            if !sortedLogs.isEmpty {
                                manualSection
                            }

                            if sortedLogs.isEmpty {
                                VStack(spacing: 12) {
                                    Text(l.tr(zh: "还没有运动记录", en: "No workouts yet", de: "Noch keine Trainings"))
                                        .font(OhanaFont.body())
                                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                                        .padding(.top, 60)

                                    HStack(spacing: 8) {
                                        Image(systemName: "hammer.fill").accessibilityHidden(true)
                                            .font(OhanaFont.callout())
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                        Text(l.tr(zh: "可在运动摘要中连接 Apple Health", en: "Connect Apple Health from Workout Summary", de: "Apple Health in der Trainingsübersicht verbinden"))
                                            .font(OhanaFont.subheadline(.medium))
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        Color.ohanaControlFill,
                                        in: RoundedRectangle(cornerRadius: OhanaRadius.chip)
                                    )
                                }
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.top, 8)
                    }
                }

                // ── 底部 FAB
                if !isPrivacyLocked {
                    Button { showAddSheet = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 16, weight: .black))
                            Text(l.tr(zh: "添加运动", en: "Add Workout", de: "Training hinzufügen"))
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("human-workout-add-action")
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(l.tr(zh: "运动历史", en: "Workout History", de: "Trainingsverlauf"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HumanPrivacyToggleButton(human: human, field: .workout)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").accessibilityHidden(true)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .accessibilityIdentifier("human-workout-close-action")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddWorkoutSheet(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow complex workout editor uses full-height system sheet
            }
        }
    }

    private var privacyLockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill").accessibilityHidden(true)
                .font(OhanaFont.metric(size: 44))
                .foregroundStyle(Color.goYellow)
            Text(appServices.privacy.lockedMessage(for: .workout))
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this profile to view it.", de: "Wechsle zu diesem Profil, um es zu sehen."))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summarySection: some View {
        HStack(spacing: 0) {
            summaryCell(value: "\(sortedLogs.count)", label: l.tr(zh: "手动记录", en: "Manual", de: "Manuell"), color: .goPrimary)
            Divider().background(Color.ohanaDivider).frame(height: 40)
            summaryCell(value: "\(sortedLogs.reduce(0) { $0 + $1.durationMinutes })", label: l.tr(zh: "总分钟", en: "Total min", de: "Minuten gesamt"), color: .goCardCyan)
            Divider().background(Color.ohanaDivider).frame(height: 40)
            summaryCell(value: String(format: "%.1f", sortedLogs.reduce(0) { $0 + $1.distanceKm }), label: l.tr(zh: "总公里", en: "Total km", de: "Kilometer gesamt"), color: .goOrange)
        }
        .padding(.vertical, 14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(color)
            Text(label)
                .font(OhanaFont.caption())
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "手动记录", en: "Manual Records", de: "Manuelle Einträge"))
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(sortedLogs) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.workoutType.icon)
                            .font(OhanaFont.callout())
                            .foregroundStyle(Color(hex: log.workoutType.colorHex))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.workoutType.localizedTitle(l))
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.caption())
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(log.durationMinutes) min")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color(hex: log.workoutType.colorHex))
                            if log.distanceKm > 0.01 {
                                Text(String(format: "%.1f km", log.distanceKm))
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            }
                        }
                        Button {
                            let command = DomainCommand.humanWorkoutDelete(humanID: human.id, recordID: log.id)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            commandQueue.enqueue(command) {
                                HumanCareCommandExecutor(context: modelContext, services: appServices).deleteWorkout(
                                    log,
                                    human: human,
                                    command: command,
                                    note: "human.workout.delete"
                                )
                            }
                        } label: {
                            Image(systemName: "trash").accessibilityHidden(true)
                                .font(OhanaFont.caption())
                                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.4))
                        }
                        .accessibilityIdentifier("human-workout-delete-action")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if log.id != sortedLogs.last?.id {
                        GoDashedDivider().padding(.horizontal, 16)
                    }
                }
            }
            .goIslandModuleCard(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }
}

extension WorkoutType {
    func localizedTitle(_ l: L10n) -> String {
        switch self {
        case .running:
            l.tr(zh: "跑步", en: "Running", de: "Laufen")
        case .walking:
            l.tr(zh: "步行", en: "Walking", de: "Gehen")
        case .cycling:
            l.tr(zh: "骑行", en: "Cycling", de: "Radfahren")
        case .swimming:
            l.tr(zh: "游泳", en: "Swimming", de: "Schwimmen")
        case .gym:
            l.tr(zh: "健身", en: "Gym", de: "Fitness")
        case .yoga:
            l.tr(zh: "瑜伽", en: "Yoga", de: "Yoga")
        case .hiking:
            l.tr(zh: "徒步", en: "Hiking", de: "Wandern")
        case .other:
            l.tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }
}
