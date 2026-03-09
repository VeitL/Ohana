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
    @State private var toastColor: Color = .goLime

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
                            .fill(Color.goLime.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "figure.run")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goLime)
                    }
                    Text("运动记录")
                        .font(OhanaFont.headline())
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            GoDashedDivider().padding(.horizontal, 16)

            // 🚧 占位 UI：Apple Health 同步待开发
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(OhanaFont.callout())
                        .foregroundStyle(.white.opacity(0.4))
                    Text("🚧 Apple Health 接入中")
                        .font(OhanaFont.subheadline(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .padding(.horizontal, 16)
                
                Text("手动记录功能正常使用")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            GoDashedDivider().padding(.horizontal, 16)

            // 最近记录（仅手动记录）
            if sortedLogs.isEmpty {
                emptyState
            } else {
                recentLogsSection
            }
        }
        .ohanaStandardCard(cornerRadius: 20)
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
                .foregroundStyle(Color.goLime.opacity(0.8))
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
                        .foregroundStyle(.white)
                    // Mock: 不显示 HealthKit 标记
                }
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.caption())
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(duration) min")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color(hex: colorHex))
                if distance > 0.01 {
                    Text(String(format: "%.1f km", distance))
                        .font(OhanaFont.caption())
                        .foregroundStyle(.white.opacity(0.45))
                } else if calories > 0 {
                    Text("\(calories) kcal")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle")
                .font(OhanaFont.metric(size: 36))
                .foregroundStyle(.white.opacity(0.2))
            Text("暂无运动记录")
                .font(OhanaFont.subheadline())
                .foregroundStyle(.white.opacity(0.35))
            Button { showAddSheet = true } label: {
                Text("+ 添加运动")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goLime)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: WorkoutType = .running
    @State private var durationStr = ""
    @State private var distanceStr = ""
    @State private var caloriesStr = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 16) {
                        // 运动类型选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("运动类型")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                                ForEach(WorkoutType.allCases, id: \.self) { type in
                                    Button { selectedType = type } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: type.icon)
                                                .font(OhanaFont.title3())
                                                .foregroundStyle(selectedType == type ? Color(hex: type.colorHex) : .white.opacity(0.4))
                                            Text(type.rawValue)
                                                .font(OhanaFont.caption2(.bold))
                                                .foregroundStyle(selectedType == type ? .white : .white.opacity(0.4))
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(
                                            selectedType == type
                                                ? Color(hex: type.colorHex).opacity(0.2)
                                                : Color.white.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 14)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16).ohanaStandardCard(cornerRadius: 20)

                        // 时长/距离/卡路里
                        VStack(spacing: 12) {
                            workoutField(icon: "timer", label: "时长（分钟）", placeholder: "0", text: $durationStr, color: .goLime)
                            workoutField(icon: "map", label: "距离（公里，可选）", placeholder: "0.0", text: $distanceStr, color: .goCardCyan)
                            workoutField(icon: "flame", label: "卡路里（可选）", placeholder: "0", text: $caloriesStr, color: .goOrange)
                        }
                        .padding(16).ohanaStandardCard(cornerRadius: 20)

                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .font(OhanaFont.callout())
                                .foregroundStyle(Color.goPrimary)
                            Text("日期")
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(Color.goLime)
                                .labelsHidden()
                        }
                        .padding(16).ohanaStandardCard(cornerRadius: 20)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .navigationTitle("添加运动记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.goLime)
                        .disabled(durationStr.isEmpty)
                }
            }
        }
    }

    private func workoutField(icon: String, label: String, placeholder: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.callout())
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        let duration = Int(durationStr) ?? 0
        let distance = Double(distanceStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let calories = Int(caloriesStr) ?? 0
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

    private var sortedLogs: [HumanWorkoutLog] {
        human.workoutLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 12) {
                        // 汇总统计
                        summarySection
                            .padding(.horizontal, 16)

                        // 手动记录
                        if !sortedLogs.isEmpty {
                            manualSection
                        }

                        if sortedLogs.isEmpty {
                            VStack(spacing: 12) {
                                Text("还没有运动记录")
                                    .font(OhanaFont.body())
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.top, 60)
                                
                                // 🚧 占位提示
                                HStack(spacing: 8) {
                                    Image(systemName: "hammer.fill")
                                        .font(OhanaFont.callout())
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text("Apple Health 同步功能开发中")
                                        .font(OhanaFont.subheadline(.medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    Color.white.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("运动历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Color.goLime)
                }
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 0) {
            summaryCell(value: "\(sortedLogs.count)", label: "手动记录", color: .goLime)
            Divider().background(.white.opacity(0.2)).frame(height: 40)
            summaryCell(value: "\(sortedLogs.reduce(0) { $0 + $1.durationMinutes })", label: "总分钟", color: .goCardCyan)
            Divider().background(.white.opacity(0.2)).frame(height: 40)
            summaryCell(value: String(format: "%.1f", sortedLogs.reduce(0) { $0 + $1.distanceKm }), label: "总公里", color: .goOrange)
        }
        .padding(.vertical, 14)
        .ohanaStandardCard(cornerRadius: 20)
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(color)
            Text(label)
                .font(OhanaFont.caption())
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    
    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手动记录")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(.white.opacity(0.7))
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
                                .foregroundStyle(.white)
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.caption())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(log.durationMinutes) min")
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(Color(hex: log.workoutType.colorHex))
                            if log.distanceKm > 0.01 {
                                Text(String(format: "%.1f km", log.distanceKm))
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(.white.opacity(0.4))
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
            .ohanaStandardCard(cornerRadius: 20)
            .padding(.horizontal, 16)
        }
    }
}
