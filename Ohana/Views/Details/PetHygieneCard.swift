//
//  PetHygieneCard.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct PetHygieneCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    @State private var longPressedType: HygieneType? = nil
    @State private var showHygieneDetail = false
    @State private var undoLog: PetHygieneLog? = nil
    @State private var undoLabel: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // Header — NavigationLink 进入护理详情页
                NavigationLink(destination: PetHygieneDetailView(pet: pet)) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.goCardCyan)
                        Text("护理打卡")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

                GoDashedDivider().padding(.horizontal, 14)

                // C6: 5图标单行等距
                HStack(spacing: 0) {
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        HygieneCheckButton(pet: pet, type: type, households: households, onUndo: { log in
                            undoLog = log
                            undoLabel = type.rawValue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                if undoLog?.id == log.id {
                                    withAnimation(.spring(response: 0.3)) { undoLog = nil }
                                }
                            }
                        }) {
                            longPressedType = type
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 10)

                // task5: 铲屎 / 便便快捷打卡（护理卡片底部）
                let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
                GoDashedDivider().padding(.horizontal, 14)
                HStack {
                    let pottyToday: Int = {
                        if isLitter {
                            return pet.careLogs.filter { $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date) }.count
                        } else {
                            return pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
                        }
                    }()
                    Text(isLitter ? "🪣" : "💩")
                        .font(.system(size: 16))
                    Text(isLitter ? "今日铲屎 \(pottyToday) 次" : "今日便便 \(pottyToday) 次")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button {
                        if isLitter {
                            let log = PetCareLog(date: Date(), type: .litter, pet: pet)
                            modelContext.insert(log)
                        } else {
                            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet)
                            modelContext.insert(log)
                        }
                        modelContext.safeSave()
                        QuestManager.shared.awardAction(type: .potty(isLitter: isLitter), pet: pet, context: modelContext)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("+ 打卡")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color.goYellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .goTranslucentCard(cornerRadius: 20)

            // U16: 3秒撤回 toast
            if undoLog != nil {
                HStack(spacing: 8) {
                    Text("✨ \(undoLabel) 已打卡")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        if let log = undoLog {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        }
                        withAnimation(.spring(response: 0.3)) { undoLog = nil }
                    } label: {
                        Text("撤回")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.black.opacity(0.8), in: Capsule())
                .padding(.horizontal, 8).padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: undoLog != nil)
        .sheet(item: $longPressedType) { type in
            HygieneTodoSheet(pet: pet, type: type)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - U16 护理详情 Sheet（GO Club 沉浸式重构）
private struct HygieneDetailSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingPottyOverview = false

    private var isLitterPet: Bool {
        ["猫", "兔子", "仓鼠", "龙猫", "豚鼠"].contains(pet.species)
    }

    private func daysSince(_ type: HygieneType) -> Int? {
        let last = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }.first
        guard let d = last else { return nil }
        return Calendar.current.dateComponents([.day], from: d.date, to: Date()).day
    }
    private func statusColor(_ type: HygieneType) -> Color {
        guard let d = daysSince(type) else { return .white.opacity(0.25) }
        let p = Double(d) / Double(type.cycleDays)
        if p < 0.5 { return Color.goTeal }
        if p < 0.85 { return Color.goYellow }
        return Color.goRed
    }
    private func last7(_ type: HygieneType) -> [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.hygieneLogs.filter { $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: d) }.count
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // ── 顶栏
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("护理打卡")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(pet.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    // 占位保持居中
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)

                // ── 5图标状态横排（带环形进度）
                HStack(spacing: 0) {
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        let color = statusColor(type)
                        let days = daysSince(type)
                        let progress: Double = {
                            guard let d = days else { return 0 }
                            return min(1, Double(d) / Double(type.cycleDays))
                        }()
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().stroke(color.opacity(0.2), lineWidth: 4)
                                    .frame(width: 52, height: 52)
                                Circle()
                                    .trim(from: 0, to: 1 - progress)
                                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 52, height: 52)
                                    .rotationEffect(.degrees(-90))
                                Text(type.emoji).font(.system(size: 22))
                            }
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                            if let d = days {
                                Text(d == 0 ? "今天" : "\(d)天前")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(color)
                            } else {
                                Text("未记录")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)

                // ── 下层白色面板
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: "F2F0F5"))
                        .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 36, height: 4)
                            .padding(.top, 10).padding(.bottom, 12)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(HygieneType.allCases, id: \.rawValue) { type in
                                    hygieneSectionCard(type)
                                }
                                pottyRadioSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 48)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingPottyOverview) {
            PottyOverviewView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var pottyRadioSection: some View {
        let cal = Calendar.current
        let todayPotty = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
        let todayLitter = isLitterPet
            ? pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            : 0
        let recentPotty = pet.pottyLogs.sorted { $0.date > $1.date }.prefix(5)
        let recentLitter = isLitterPet
            ? pet.careLogs.filter { $0.type == CareType.litter.rawValue }.sorted { $0.date > $1.date }.prefix(5)
            : []

        return VStack(alignment: .leading, spacing: 12) {
            // 标题 + 入口
            HStack(spacing: 6) {
                Text("💩").font(.system(size: 16))
                Text("噗噗电台")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Spacer()
                Button { showingPottyOverview = true } label: {
                    HStack(spacing: 3) {
                        Text("完整分析")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.goYellow)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.goYellow.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // 今日统计行
            HStack(spacing: 12) {
                // 便便
                VStack(spacing: 4) {
                    Text("💩").font(.system(size: 22))
                    Text("\(todayPotty)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.black)
                    Text("今日便便").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.goYellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                // 铲屎（仅猫/兔等）
                if isLitterPet {
                    VStack(spacing: 4) {
                        Text("🪣").font(.system(size: 22))
                        Text("\(todayLitter)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.black)
                        Text("今日铲屎").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "E8E0FF").opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                }
            }

            // 快速打卡按钮行
            HStack(spacing: 10) {
                Button {
                    let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("便便打卡", systemImage: "plus")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.goYellow, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if isLitterPet {
                    Button {
                        let log = PetCareLog(date: Date(), type: .litter, pet: pet)
                        modelContext.insert(log)
                        modelContext.safeSave()
                        QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("铲屎打卡", systemImage: "plus")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "6B4EFF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "E8E0FF"), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 近期便便记录
            if !recentPotty.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("便便记录")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    ForEach(recentPotty) { log in
                        HStack {
                            Text("💩").font(.system(size: 13))
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.7))
                            Spacer()
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // 近期铲屎记录（仅猫/兔等）
            if isLitterPet && !recentLitter.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("铲屎记录")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    ForEach(recentLitter) { log in
                        HStack {
                            Text("🪣").font(.system(size: 13))
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.7))
                            Spacer()
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.goYellow.opacity(0.2), lineWidth: 1))
    }

    private func hygieneSectionCard(_ type: HygieneType) -> some View {
        let logs = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
        let color = statusColor(type)
        let bars = last7(type)
        let maxBar = max(bars.max() ?? 1, 1)
        let days = daysSince(type)

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack(spacing: 6) {
                Text(type.emoji).font(.system(size: 16))
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Spacer()
                if let d = days {
                    Text(d == 0 ? "今天已打卡" : "\(d)天前 · 每\(type.cycleDays)天一次")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(color.opacity(0.1), in: Capsule())
                }
            }

            // 7天 mini bar
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    let h = max(4, CGFloat(v) / CGFloat(maxBar) * 28)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(v > 0 ? color : Color.black.opacity(0.06))
                        .frame(maxWidth: .infinity, minHeight: 4, maxHeight: h)
                }
            }
            .frame(height: 28)

            // 近期记录
            if logs.isEmpty {
                Text("暂无记录").font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                VStack(spacing: 5) {
                    ForEach(logs.prefix(3)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.7))
                            Spacer()
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - C6 Hygiene Check Button（仅打卡按钮，状态颜色+长按设置）
private struct HygieneCheckButton: View {
    let pet: Pet
    let type: HygieneType
    let households: [Household]
    var onUndo: ((PetHygieneLog) -> Void)? = nil  // U16: 撤回回调
    let onLongPress: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var justChecked = false

    private var logs: [PetHygieneLog] {
        pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
    }
    private var daysSince: Int {
        logs.first.map { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 } ?? 999
    }
    private var progress: Double { min(1.0, Double(daysSince) / Double(type.cycleDays)) }
    private var statusColor: Color {
        progress < 0.5 ? Color.goTeal : (progress < 0.85 ? Color.goYellow : Color.goRed)
    }
    private var isDoneToday: Bool {
        logs.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    var body: some View {
        Button { checkIn() } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(justChecked || isDoneToday ? statusColor : statusColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(statusColor.opacity(0.3), lineWidth: 1))
                    Text(type.emoji).font(.system(size: 20))
                }
                Text(type.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDoneToday ? statusColor : .white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress()
            }
        )
    }

    private func checkIn() {
        guard !isDoneToday else { return }
        let log = PetHygieneLog(date: Date(), type: type, pet: pet)
        modelContext.insert(log)
        if let h = households.first {
            IslandProsperityEXP.addEXP(source: .hygiene, household: h, context: modelContext)
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3)) { justChecked = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { justChecked = false }
        }
        // U16: 通知父视图显示撤回 toast
        onUndo?(log)
    }
}

// MARK: - Hygiene Todo Sheet (长按弹出：开始时间 + 结束时间 + 重复频率 → 自动写入日历)
struct HygieneTodoSheet: View {
    let pet: Pet
    let type: HygieneType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var hasEndDate: Bool = false
    @State private var repeatDays: Int = 0
    @State private var customNote: String = ""

    private let repeatOptions: [(String, Int)] = [
        ("不重复", 0), ("每天", 1), ("每2天", 2), ("每3天", 3),
        ("每周", 7), ("每两周", 14), ("每月", 30)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 18)

            // 标题
            HStack(spacing: 12) {
                Text(type.emoji).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("设置护理计划")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("\(pet.name) · \(type.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // ── 开始时间
                    settingRow(icon: "clock.fill", iconColor: .goTeal, label: "开始时间") {
                        DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .tint(Color.goTeal)
                            .labelsHidden()
                    }

                    // ── 结束时间（可选开关）
                    settingRow(icon: "clock.badge.checkmark.fill", iconColor: .goYellow, label: "结束时间") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasEndDate)
                                .tint(Color.goYellow)
                                .labelsHidden()
                            if hasEndDate {
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(Color.goYellow)
                                    .labelsHidden()
                            }
                        }
                    }

                    // ── 重复频率
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.goCardCyan)
                            Text("重复频率").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        }
                        .padding(.horizontal, 4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(repeatOptions, id: \.1) { label, days in
                                    Button { repeatDays = days } label: {
                                        Text(label)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(repeatDays == days ? Color.arkInk : .primary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(
                                                repeatDays == days ? Color.goLime : Color(.systemGray6),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // ── 备注
                    settingRow(icon: "note.text", iconColor: .secondary, label: "备注") {
                        TextField("可选备注", text: $customNote)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tint(Color.goPrimary)
                    }
                }
                .padding(.bottom, 24)
            }

            // ── 保存按钮
            Button { save() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                    Text("添加到日历")
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.goLime, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helper row builder
    private func settingRow<V: View>(icon: String, iconColor: Color, label: String, @ViewBuilder content: () -> V) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Save（写单个 Event + recurrenceDays，不展开实例）
    private func save() {
        let title = "\(pet.name) — \(type.rawValue)"
        let fullTitle = customNote.isEmpty ? title : "\(title) — \(customNote)"

        let event = Event(
            title: fullTitle,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            eventType: EventType.grooming.rawValue,
            relatedEntityType: "pet",
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = repeatDays
        if hasEndDate {
            event.recurrenceEndDate = endDate
        } else if repeatDays > 0 {
            event.recurrenceEndDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)
        }
        modelContext.insert(event)

        let reminder = Reminder(event: event, scheduledAt: startDate)
        reminder.status = "pending"
        modelContext.insert(reminder)
        NotificationManager.shared.schedule(reminder: reminder)

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

extension HygieneType: Identifiable {
    public var id: String { rawValue }
}
