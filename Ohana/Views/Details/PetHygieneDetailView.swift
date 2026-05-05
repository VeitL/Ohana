//
//  PetHygieneDetailView.swift
//  Ohana
//
//  护理详情页 — 参考饮食管理页风格
//  深色背景 + ScrollView 卡片 + 极简月频条
//

import SwiftUI
import SwiftData

// MARK: - Chart Data Point for Hygiene
private struct HygieneChartPoint: Identifiable {
    var id: Date { day }
    let day: Date
    let count: Int
    let label: String
}

struct PetHygieneDetailView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingPottyOverview = false
    @State private var groomingPlanTarget: HygieneType? = nil

    /// 用于匹配 `HygieneTodoSheet` 写入的 Event 标题前缀：`\(pet.name) — \(type.rawValue)`
    @Query(sort: \Reminder.scheduledAt, order: .forward) private var allReminders: [Reminder]

    /// 与钱包卡、Wellness 一致：直接使用 `themeColorHex`，不用 `PetThemeColor` 枚举（避免 hex 与枚举名不一致时错成默认橙）
    private var themeColor: Color {
        let h = pet.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(hex: h.isEmpty ? "4338FF" : h)
    }

    private func daysSince(_ type: HygieneType) -> Int? {
        guard let last = pet.hygieneLogs.filter({ $0.type == type.rawValue })
            .sorted(by: { $0.date > $1.date }).first else { return nil }
        return Calendar.current.dateComponents([.day], from: last.date, to: Date()).day
    }

    private func statusColor(_ type: HygieneType) -> Color {
        guard let d = daysSince(type) else { return themeColor.opacity(0.42) }
        let p = Double(d) / Double(type.effectiveCycleDays(for: pet.id))
        if p < 0.5 { return themeColor }
        if p < 0.85 { return themeColor.opacity(0.62) }
        return Color.goRed
    }

    /// 与 `HygieneTodoSheet.save()` 写入的标题前缀一致（含备注时仍以此前缀开头）
    private func titlePrefix(for type: HygieneType) -> String {
        "\(pet.name) — \(type.rawValue)"
    }

    private func pendingHygienePlans(for type: HygieneType) -> [Reminder] {
        let pid = pet.id.uuidString
        let prefix = titlePrefix(for: type)
        return allReminders.filter { r in
            guard r.statusEnum == .pending,
                  let ev = r.event,
                  ev.eventType == EventType.grooming.rawValue,
                  ev.relatedEntityType == EntityKind.pet.rawValue,
                  ev.relatedEntityId == pid else { return false }
            return ev.title.hasPrefix(prefix)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func recurrenceLabel(_ days: Int) -> String {
        switch days {
        case 0: return "不重复"
        case 1: return "每天"
        case 2: return "每 2 天"
        case 3: return "每 3 天"
        case 7: return "每周"
        case 14: return "每两周"
        case 30: return "每月"
        default: return "每 \(days) 天"
        }
    }

    /// 近 28 天极简条（左旧右新），仅看打卡频率
    private func monthStripPoints(_ type: HygieneType) -> [HygieneChartPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<28).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = pet.hygieneLogs.filter {
                $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: d)
            }.count
            return HygieneChartPoint(day: d, count: count, label: "")
        }
    }

    @ViewBuilder
    private func monthFrequencyStrip(_ type: HygieneType) -> some View {
        let pts = monthStripPoints(type)
        let maxH: CGFloat = 22
        VStack(alignment: .leading, spacing: 6) {
            Text("近 28 天")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(pts) { pt in
                    let h = min(maxH, 4 + CGFloat(min(pt.count, 4)) * 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(themeColor.opacity(pt.count > 0 ? 0.72 : 0.12))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: maxH, alignment: .bottom)
        }
    }

    private var monthlyTotalCount: Int {
        let cal = Calendar.current
        let now = Date()
        return pet.hygieneLogs.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    private var currentStrike: Int {
        let cal = Calendar.current
        var strike = 0
        var lastDateByType: [String: Date] = [:]

        for log in pet.hygieneLogs.sorted(by: { $0.date < $1.date }) {
            guard let type = HygieneType(rawValue: log.type) else { continue }
            if let lastDate = lastDateByType[log.type] {
                let days = cal.dateComponents(
                    [.day],
                    from: cal.startOfDay(for: lastDate),
                    to: cal.startOfDay(for: log.date)
                ).day ?? 0
                strike = days <= type.effectiveCycleDays(for: pet.id) ? strike + 1 : 1
            } else {
                strike += 1
            }
            lastDateByType[log.type] = log.date
        }
        return strike
    }

    private var overdueTypes: [HygieneType] {
        HygieneType.allCases.filter { type in
            guard let d = daysSince(type) else { return false }
            return d >= type.effectiveCycleDays(for: pet.id)
        }
    }

    private var completedTodayCount: Int {
        HygieneType.allCases.filter { isDoneToday($0) }.count
    }
    @State private var hygieneCycleRefresh = 0
    @State private var showSingleUseNotice = false
    @State private var singleUseNoticeMessage = ""

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── 本月概览（无卡片背景）
                    monthlySummaryCard
                    // ── 5 项护理卡片（打卡 + 计划；顶部状态条已移除，与首页快捷护理重复）
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        hygieneTypeCard(type)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("\(pet.name) · 护理")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeColor)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPottyOverview = true } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
        .sheet(isPresented: $showingPottyOverview) {
            PottyOverviewView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // 护理卡片「计划」按钮 → 待办 sheet
        .sheet(item: $groomingPlanTarget) { hygieneType in
            HygieneTodoSheet(pet: pet, type: hygieneType, accent: themeColor) {
                hygieneCycleRefresh += 1
            }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("今天已经完成了", isPresented: $showSingleUseNotice) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(singleUseNoticeMessage)
        }
    }

    // MARK: - 本月概览
    private var monthlySummaryCard: some View {
        let totalTypes = max(HygieneType.allCases.count, 1)
        let progress = CGFloat(completedTodayCount) / CGFloat(totalTypes)
        let headline = overdueTypes.isEmpty ? "今天的护理节奏很好" : "\(overdueTypes.count) 项护理需要关注"

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(completedTodayCount)/\(totalTypes)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("今日")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text(headline)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(overdueTypes.isEmpty ? "继续保持，下一次护理会自动提醒。" : overdueTypes.map(\.rawValue).joined(separator: "、"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(overdueTypes.isEmpty ? .secondary : Color.goRed.opacity(0.9))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                overviewMetric(icon: "sparkle", value: "\(monthlyTotalCount)", label: "本月护理", tint: themeColor)
                overviewMetric(icon: "bolt.fill", value: "\(currentStrike)", label: "连续打卡 strike", tint: Color.goOrange)
                overviewMetric(icon: "clock", value: "\(overdueTypes.count)", label: "待护理", tint: overdueTypes.isEmpty ? themeColor : Color.goRed)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.12), themeColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func overviewMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 是否今天已完成
    private func isDoneToday(_ type: HygieneType) -> Bool {
        pet.hygieneLogs.contains {
            $0.type == type.rawValue && Calendar.current.isDateInToday($0.date)
        }
    }

    // MARK: - 护理类型卡片（重构）
    private func hygieneTypeCard(_ type: HygieneType) -> some View {
        let _ = hygieneCycleRefresh
        let logs = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
        let color = statusColor(type)
        let days = daysSince(type)
        let stripHasData = monthStripPoints(type).contains { $0.count > 0 }
        let doneToday = isDoneToday(type)
        let plans = pendingHygienePlans(for: type)

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行：名称 + 状态 + 计划 + 打卡（主题色仅用于图标/按钮）
            HStack(spacing: 6) {
                Image(systemName: type.systemIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text(type.rawValue)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if let d = days {
                    Text(d == 0 ? "✓ 今天" : "\(d)天前")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(d == 0 ? themeColor : color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((d == 0 ? themeColor : color).opacity(0.14), in: Capsule())
                } else {
                    Text("未记录")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeColor.opacity(0.55))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(themeColor.opacity(0.1), in: Capsule())
                }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    groomingPlanTarget = type
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.badge.plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("计划")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(themeColor.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(themeColor.opacity(0.35), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                Button {
                    guard !doneToday else {
                        singleUseNoticeMessage = "\(pet.name) 今天已经记录过\(type.rawValue)了，这类护理一天记录一次就够了。"
                        showSingleUseNotice = true
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        return
                    }
                    let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                        .flatMap { $0.isEmpty ? nil : $0 }
                    let log = PetHygieneLog(date: Date(), type: type, pet: pet, executorId: executorId)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    if doneToday {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(themeColor.opacity(0.55))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(themeColor.opacity(0.1), in: Capsule())
                    } else {
                        Text("打卡")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(themeColor, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            // 已添加的护理计划（HygieneTodoSheet → Event + Reminder）
            if !plans.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("已设计划")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.primary.opacity(0.7))

                    ForEach(plans, id: \.id) { rem in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(themeColor)
                                .frame(width: 16, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rem.scheduledAt, format: .dateTime.month().day())
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                if let ev = rem.event, ev.recurrenceDays > 0 {
                                    Text("重复 · \(recurrenceLabel(ev.recurrenceDays))")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.22), lineWidth: 0.5)
                )
            }

            if stripHasData {
                monthFrequencyStrip(type)
            }

            // 周期标签 + 自定义按钮
            HStack(spacing: 6) {
                let effectiveDays = type.effectiveCycleDays(for: pet.id)
                let isCustom = HygieneType.customCycleDays(for: type, petId: pet.id) != nil
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.6))
                Text("每\(effectiveDays)天\(isCustom ? " · 已自定义" : "")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.7))
                Spacer()
            }

            // 最近记录（无分割线）
            if !logs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(logs.prefix(3)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.7))
                            Spacer()
                            Button { modelContext.delete(log); modelContext.safeSave() } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(doneToday ? 0.15 : 0.07), lineWidth: 0.5)
        )
    }
}
