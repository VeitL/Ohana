//
//  PetCareTrackingCard.swift
//  Ohana
//
//  喂食 / 喂水 / 铲屎 追踪卡片（T11）
//  - 点击快速打卡
//  - 今日次数 + 7天趋势 mini bar
//  - 铲屎打卡同时写入 PetPottyLog（与噗噗电台互动）
//

import SwiftUI
import SwiftData

struct PetCareTrackingCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    @State private var justChecked: CareType? = nil
    // U18: 详情页 + 撤回
    @State private var showingDetail = false
    @State private var undoLog: PetCareLog? = nil
    @State private var undoLabel: String = ""

    private var visibleTypes: [CareType] {
        var types: [CareType] = [.feeding, .watering]
        let litterSpecies = ["猫", "仓鼠", "兔子", "豚鼠", "龙猫"]
        if litterSpecies.contains(pet.species) {
            types.append(.litter)
        }
        return types
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {

                // ── 顶栏—点击展开详情
                Button { showingDetail = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.goOrange)
                        Text("日常照料")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                GoDashedDivider().padding(.horizontal, 16)

                // ── 每种类型一行
                VStack(spacing: 0) {
                    ForEach(Array(visibleTypes.enumerated()), id: \.element.rawValue) { idx, type in
                        CareTypeRow(pet: pet, type: type, justChecked: $justChecked, households: households, onUndo: { log in
                            undoLog = log
                            undoLabel = type.rawValue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                if undoLog?.id == log.id {
                                    withAnimation(.spring(response: 0.3)) { undoLog = nil }
                                }
                            }
                        })
                            .padding(.horizontal, 16).padding(.vertical, 10)

                        if idx < visibleTypes.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .goTranslucentCard(cornerRadius: 22)

            // U18: 3秒撤回 toast
            if undoLog != nil {
                HStack(spacing: 8) {
                    Text("🍚 \(undoLabel) 已记录")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
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
        .sheet(isPresented: $showingDetail) {
            CareTrackingDetailSheet(pet: pet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - U18 日常照料详情 Sheet（GO Club 沉浸式重构）
struct CareTrackingDetailSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddFeed = false
    @State private var showingCoconutLog = false
    @State private var addGrams: String = ""

    private let displayTypes: [CareType] = [.feeding, .watering, .litter]

    private func todayCount(_ type: CareType) -> Int {
        pet.careLogs.filter { $0.type == type.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }
    private func last7(_ type: CareType) -> [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.careLogs.filter { $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: d) }.count
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // ── 顶部关闭 + 标题
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .glassEffect(.regular, in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("日常照料")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(pet.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    Spacer()
                    CoconutBalanceCapsule { showingCoconutLog = true }
                    Button { showAddFeed = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.goOrange)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                // ── 今日三格统计
                HStack(spacing: 12) {
                    ForEach(displayTypes, id: \.rawValue) { type in
                        VStack(spacing: 6) {
                            Image(systemName: type.systemIconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: type.accentColorHex))
                            Text("\(todayCount(type))")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: type.accentColorHex).opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 16)

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
                            VStack(spacing: 16) {
                                ForEach(displayTypes, id: \.rawValue) { type in
                                    careSectionCard(type)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 48)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .alert("添加喂食记录", isPresented: $showAddFeed) {
            TextField("克数 (g)", text: $addGrams).keyboardType(.decimalPad)
            Button("添加") {
                if let g = Double(addGrams), g > 0 {
                    let log = PetCareLog(date: Date(), type: .feeding, amountGrams: g, pet: pet)
                    modelContext.insert(log); modelContext.safeSave()
                }
                addGrams = ""
            }
            Button("取消", role: .cancel) { addGrams = "" }
        } message: { Text("输入喂食克数") }
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
    }

    private func careSectionCard(_ type: CareType) -> some View {
        let logs = pet.careLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
        let accent = Color(hex: type.accentColorHex)
        let bars = last7(type)
        let maxBar = max(bars.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            // 小标题
            HStack(spacing: 6) {
                Image(systemName: type.systemIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Spacer()
                Text("今日 \(todayCount(type)) 次")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accent.opacity(0.1), in: Capsule())
            }

            // 7天 mini bar
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    let h = max(4, CGFloat(v) / CGFloat(maxBar) * 32)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(v > 0 ? accent : Color.black.opacity(0.06))
                        .frame(maxWidth: .infinity, minHeight: 4, maxHeight: h)
                }
            }
            .frame(height: 32)

            // 最近记录（最多5条）
            if logs.isEmpty {
                Text("暂无记录").font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(logs.prefix(5)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.7))
                            Spacer()
                            if log.amountGrams > 0 {
                                Text("\(Int(log.amountGrams))g")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(accent)
                            } else if log.amountMl > 0 {
                                Text("\(Int(log.amountMl))ml")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(accent)
                            }
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Single Care Type Row
private struct CareTypeRow: View {
    let pet: Pet
    let type: CareType
    @Binding var justChecked: CareType?
    let households: [Household]
    var onUndo: ((PetCareLog) -> Void)? = nil  // U18: 撤回回调

    @Environment(\.modelContext) private var modelContext

    private var todayLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == type.rawValue && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var todayCount: Int { todayLogs.count }

    // 最近7天每天打卡次数
    private var last7Days: [(String, Int)] {
        let cal = Calendar.current
        let labels = ["M","T","W","T","F","S","S"]
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let count = pet.careLogs.filter {
                $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: date)
            }.count
            return (labels[offset], count)
        }
    }

    private var isJustChecked: Bool { justChecked == type }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji
            ZStack {
                Circle()
                    .fill(Color(hex: type.accentColorHex).opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: type.systemIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: type.accentColorHex))
            }

            // 名称 + 7日 mini bar
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(type.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("今日 \(todayCount) 次")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: type.accentColorHex).opacity(0.8))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color(hex: type.accentColorHex).opacity(0.14), in: Capsule())
                }
                // 7天 mini bar
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(last7Days.enumerated()), id: \.offset) { _, item in
                        let (_, count) = item
                        let h = max(3, CGFloat(min(count, 5)) / 5.0 * 18)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(count > 0
                                  ? Color(hex: type.accentColorHex)
                                  : Color.primary.opacity(0.08))
                            .frame(width: 12, height: h)
                    }
                }
            }

            Spacer()

            // 打卡按钮
            Button { checkIn() } label: {
                ZStack {
                    Circle()
                        .fill(isJustChecked
                              ? Color(hex: type.accentColorHex)
                              : Color(hex: type.accentColorHex).opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: isJustChecked ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isJustChecked ? .black : Color(hex: type.accentColorHex))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func checkIn() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: Date(), type: type, pet: pet, executorId: eid)
        var pottyLog: PetPottyLog?
        modelContext.insert(log)

        if type == .litter {
            let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: eid)
            pottyLog = log
            modelContext.insert(log)
        }

        modelContext.safeSave()
        CareLedgerService.recordPetCare(log: log, pet: pet, source: .detail, context: modelContext)
        if let pottyLog {
            CareLedgerService.recordPetPotty(log: pottyLog, pet: pet, source: .detail, context: modelContext)
        }
        withAnimation(.spring(response: 0.3)) { justChecked = type }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if justChecked == type { justChecked = nil } }
        }
        // U18: 通知父视图显示撤回 toast
        onUndo?(log)
    }
}
