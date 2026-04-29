//
//  HumanWorkoutCard.swift
//  Ohana
//
//  U14: 人类运动卡片 + Apple Health 同步 (优雅降级 - 待开发)

import SwiftUI
import SwiftData
import Combine

// MARK: - HealthKit Manager (Mock)
@MainActor
final class HumanHealthKitManager: ObservableObject {
    @Published var authStatus: Int = 0 // Mock: 不使用 HKAuthorizationStatus
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Int = 0
    @Published var todayDistanceKm: Double = 0
    @Published var recentWorkouts: [String] = [] // Mock: 不使用 HKWorkout
    @Published var isAvailable = false // Mock: 始终不可用

    static let shared = HumanHealthKitManager()

    func requestAuthorization() async {
        // Mock: 空操作，仅打印日志
        print("HealthKit is mocked as under development")
    }

    func fetchTodayStats(pets: [Pet] = []) async {
        // Mock: 空操作，保持数据为 0
        todaySteps = 0
        todayCalories = 0
        todayDistanceKm = 0
    }

    // MARK: - Toast State (保留用于手动记录奖励)
    struct RewardToast: Equatable {
        let message: String
        let color: Color
    }
    @Published var rewardToast: RewardToast? = nil

    func fetchRecentWorkouts() async {
        // Mock: 空操作
        recentWorkouts = []
    }

    // Mock 方法：保留 UI 兼容性
    func workoutTypeName(_ workout: String) -> String {
        return "运动"
    }

    func workoutIcon(_ workout: String) -> String {
        return "sparkles"
    }

    func workoutColorHex(_ workout: String) -> String {
        return "FFF44F"
    }
}

// MARK: - HumanWorkoutCard
struct HumanWorkoutCard: View {
    let human: Human
    var pets: [Pet] = []
    @Environment(\.modelContext) private var modelContext
    @StateObject private var hkManager = HumanHealthKitManager.shared
    @State private var showAddSheet = false
    @State private var showWorkoutHistory = false
    @State private var toastVisible = false
    @State private var toastMessage = ""
    @State private var toastColor: Color = .goPrimary

    private var sortedLogs: [HumanWorkoutLog] {
        human.workoutLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button { showWorkoutHistory = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "figure.run")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                    Text("运动记录")
                        .font(OhanaFont.headline())
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            GoDashedDivider().padding(.horizontal, 16)

            // 本月运动统计
            let monthStart = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            let monthLogs = human.workoutLogs.filter { $0.date >= monthStart }
            let totalMinutes = monthLogs.reduce(0) { $0 + $1.durationMinutes }
            let totalKm = monthLogs.reduce(0.0) { $0 + $1.distanceKm }

            HStack(spacing: 0) {
                workoutStatCell(value: "\(monthLogs.count)", label: "本月次数", color: .goPrimary)
                Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1, height: 32)
                workoutStatCell(value: "\(totalMinutes)", label: "总分钟", color: .goCardCyan)
                Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1, height: 32)
                workoutStatCell(value: String(format: "%.1f", totalKm), label: "总公里", color: .goOrange)
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
        .goIslandModuleCard(cornerRadius: 20)
        .overlay(alignment: .top) {
            if toastVisible {
                rewardToastBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            await hkManager.requestAuthorization()
            await hkManager.fetchTodayStats(pets: pets)
        }
        .onReceive(hkManager.$rewardToast.compactMap { $0 }) { toast in
            toastMessage = toast.message
            toastColor = toast.color
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toastVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.4)) { toastVisible = false }
                hkManager.rewardToast = nil
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorkoutSheet(human: human)
        }
        .sheet(isPresented: $showWorkoutHistory) {
            HumanWorkoutHistoryView(human: human)
        }
    }

    private var rewardToastBanner: some View {
        HStack(spacing: 8) {
            Text(toastMessage)
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(toastColor, in: Capsule())
        .shadow(color: toastColor.opacity(0.5), radius: 12, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Recent Logs (仅手动记录)
    private var recentLogsSection: some View {
        VStack(spacing: 0) {
            ForEach(sortedLogs.prefix(3)) { log in
                workoutRow(
                    icon: log.workoutType.icon,
                    name: log.workoutType.rawValue,
                    duration: log.durationMinutes,
                    distance: log.distanceKm,
                    calories: log.calories,
                    date: log.date,
                    colorHex: log.workoutType.colorHex,
                    isHealthKit: false // 手动记录始终为 false
                )
                if log.id != sortedLogs.prefix(3).last?.id {
                    GoDashedDivider().padding(.horizontal, 16)
                }
            }

            // 添加按钮 - 保留手动记录功能
            Button { showAddSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(OhanaFont.caption(.bold))
                    Text("手动添加运动")
                        .font(OhanaFont.caption(.semibold))
                }
                .foregroundStyle(Color.goPrimary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    private func workoutRow(icon: String, name: String, duration: Int, distance: Double, calories: Int, date: Date, colorHex: String, isHealthKit: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color(hex: colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(.primary)
                    // Mock: 不显示 HealthKit 标记
                }
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.caption())
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(duration) min")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color(hex: colorHex))
                if distance > 0.01 {
                    Text(String(format: "%.1f km", distance))
                        .font(OhanaFont.caption())
                        .foregroundStyle(.primary.opacity(0.45))
                } else if calories > 0 {
                    Text("\(calories) kcal")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.primary.opacity(0.45))
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
                .foregroundStyle(.primary.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle")
                .font(OhanaFont.metric(size: 36))
                .foregroundStyle(.primary.opacity(0.2))
            Text("暂无运动记录")
                .font(OhanaFont.subheadline())
                .foregroundStyle(.primary.opacity(0.35))
            Button { showAddSheet = true } label: {
                Text("+ 添加运动")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Add Workout Sheet
struct AddWorkoutSheet: View {
    let human: Human
    var onSaved: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: WorkoutType = .running
    @State private var durationStr = ""
    @State private var distanceStr = ""
    @State private var caloriesStr = ""
    @State private var date = Date()
    @State private var notes = ""

    private var duration: Int { Int(durationStr) ?? 0 }
    private var distance: Double { Double(distanceStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var calories: Int { Int(caloriesStr) ?? 0 }
    private var canSave: Bool { duration > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 16) {
                        workoutPreview

                        // 运动类型选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("运动类型")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(.primary.opacity(0.6))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                                ForEach(WorkoutType.allCases, id: \.self) { type in
                                    workoutTypeButton(for: type)
                                }
                            }
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: 20)

                        // 时长/距离/卡路里
                        VStack(spacing: 12) {
                            workoutField(icon: "timer", label: "时长（分钟）", placeholder: "0", text: $durationStr, color: .goPrimary)
                            workoutField(icon: "map", label: "距离（公里，可选）", placeholder: "0.0", text: $distanceStr, color: .goCardCyan)
                            workoutField(icon: "flame", label: "卡路里（可选）", placeholder: "0", text: $caloriesStr, color: .goOrange)
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: 20)

                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .font(OhanaFont.callout())
                                .foregroundStyle(Color.goPrimary)
                            Text("日期")
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: 20)

                        // 备注
                        VStack(alignment: .leading, spacing: 8) {
                            Label("备注（可选）", systemImage: "note.text")
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(.primary)
                            TextEditor(text: $notes)
                                .font(OhanaFont.body())
                                .foregroundStyle(.primary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80)
                                .padding(10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(16).goIslandModuleCard(cornerRadius: 20)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .navigationTitle("添加运动记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(canSave ? Color.goPrimary : .secondary)
                        .disabled(!canSave)
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
                Text(type.rawValue)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? color.opacity(0.2) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.45) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var workoutPreview: some View {
        HStack(spacing: 14) {
            Image(systemName: selectedType.icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: selectedType.colorHex))
                .frame(width: 56, height: 56)
                .background(Color(hex: selectedType.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("\(human.name) 的\(selectedType.rawValue)")
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(.primary)
                Text(previewSubtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .goIslandModuleCard(cornerRadius: 22)
    }

    private var previewSubtitle: String {
        var parts: [String] = []
        if duration > 0 { parts.append("\(duration) 分钟") }
        if distance > 0 { parts.append(String(format: "%.1f 公里", distance)) }
        if calories > 0 { parts.append("\(calories) kcal") }
        return parts.isEmpty ? "填写时长后即可保存" : parts.joined(separator: " · ")
    }

    private func workoutField(icon: String, label: String, placeholder: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.callout())
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(.primary.opacity(0.7))
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        guard canSave else { return }
        let log = HumanWorkoutLog(
            date: date,
            type: selectedType,
            durationMinutes: duration,
            distanceKm: distance,
            calories: calories,
            steps: 0,
            notes: notes,
            sourceHealthKit: false,
            human: human
        )
        modelContext.insert(log)
        modelContext.safeSave()
        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .workout,
            actionType: log.typeRaw,
            amountValue: Double(log.durationMinutes),
            amountUnit: "min",
            note: log.notes,
            source: .detail,
            legacyModelName: "HumanWorkoutLog",
            legacyModelId: log.id.uuidString,
            metadataJSON: "{\"distanceKm\":\(log.distanceKm),\"calories\":\(log.calories),\"steps\":\(log.steps)}",
            context: modelContext
        )
        onSaved?()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

// MARK: - Workout History View
struct HumanWorkoutHistoryView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hkManager = HumanHealthKitManager.shared

    @State private var showAddSheet = false

    private var sortedLogs: [HumanWorkoutLog] {
        human.workoutLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArkBackgroundView()

                ScrollView {
                    VStack(spacing: 12) {
                        summarySection
                            .padding(.horizontal, 16)

                        if !sortedLogs.isEmpty {
                            manualSection
                        }

                        if sortedLogs.isEmpty {
                            VStack(spacing: 12) {
                                Text("还没有运动记录")
                                    .font(OhanaFont.body())
                                    .foregroundStyle(.primary.opacity(0.35))
                                    .padding(.top, 60)

                                HStack(spacing: 8) {
                                    Image(systemName: "hammer.fill")
                                        .font(OhanaFont.callout())
                                        .foregroundStyle(.primary.opacity(0.4))
                                    Text("Apple Health 同步功能开发中")
                                        .font(OhanaFont.subheadline(.medium))
                                        .foregroundStyle(.primary.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    Color.white.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                // ── 底部 FAB
                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .black))
                        Text("添加运动")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.4), radius: 14, y: 5)
                }
                .padding(.bottom, 28)
            }
            .navigationTitle("运动历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HumanPrivacyToggleButton(human: human, field: .workout)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddWorkoutSheet(human: human)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 0) {
            summaryCell(value: "\(sortedLogs.count)", label: "手动记录", color: .goPrimary)
            Divider().background(.white.opacity(0.2)).frame(height: 40)
            summaryCell(value: "\(sortedLogs.reduce(0) { $0 + $1.durationMinutes })", label: "总分钟", color: .goCardCyan)
            Divider().background(.white.opacity(0.2)).frame(height: 40)
            summaryCell(value: String(format: "%.1f", sortedLogs.reduce(0) { $0 + $1.distanceKm }), label: "总公里", color: .goOrange)
        }
        .padding(.vertical, 14)
        .goIslandModuleCard(cornerRadius: 20)
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(color)
            Text(label)
                .font(OhanaFont.caption())
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    
    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手动记录")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(sortedLogs) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.workoutType.icon)
                            .font(OhanaFont.callout())
                            .foregroundStyle(Color(hex: log.workoutType.colorHex))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.workoutType.rawValue)
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(.primary)
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.caption())
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(log.durationMinutes) min")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color(hex: log.workoutType.colorHex))
                            if log.distanceKm > 0.01 {
                                Text(String(format: "%.1f km", log.distanceKm))
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                        }
                        Button {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        } label: {
                            Image(systemName: "trash")
                                .font(OhanaFont.caption())
                                .foregroundStyle(.secondary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if log.id != sortedLogs.last?.id {
                        GoDashedDivider().padding(.horizontal, 16)
                    }
                }
            }
            .goIslandModuleCard(cornerRadius: 20)
            .padding(.horizontal, 16)
        }
    }
}
