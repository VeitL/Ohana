//
//  QuickPottyDetailSheet.swift
//  Ohana
//
//  便便详情页 — 排泄记录 + 健康洞察 + 快速打卡
//

import SwiftUI
import SwiftData

struct QuickPottyDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private let pottyBrown = Color(red: 0.6, green: 0.4, blue: 0.2)

    private var todayLogs: [PetPottyLog] {
        pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    private var recentLogs: [PetPottyLog] {
        Array(pet.pottyLogs.sorted { $0.date > $1.date }.prefix(15))
    }

    private var last7DaysCounts: [(date: Date, count: Int)] {
        (0..<7).map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let c = pet.pottyLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: d) }.count
            return (d, c)
        }.reversed()
    }

    private var last7AbnormalRatio: Double {
        let logs7 = pet.pottyLogs.filter {
            guard let d = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return $0.date >= d
        }
        guard !logs7.isEmpty else { return 0 }
        let abnormal = logs7.filter { $0.pottyType == .softPoop || $0.pottyType == .liquidPoop }.count
        return Double(abnormal) / Double(logs7.count)
    }

    private var weekAvg: Double {
        let total = last7DaysCounts.reduce(0) { $0 + $1.count }
        return Double(total) / 7.0
    }

    private var prevWeekAvg: Double {
        let cal = Calendar.current
        let total = (7..<14).reduce(0) { acc, offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return acc + pet.pottyLogs.filter { cal.isDate($0.date, inSameDayAs: d) }.count
        }
        return Double(total) / 7.0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        petHeader
                        ExecutorPickerBar(tint: themeColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        todayStats
                        weekChart
                        quickLogSection
                        healthInsights
                        recentLogList
                        removeQuickActionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom, 28)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header
    private var petHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(themeColor.opacity(0.15)).frame(width: 48, height: 48)
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 48, height: 48).clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 24))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("排泄记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Image(systemName: "oval.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(pottyBrown)
        }
    }

    // MARK: - Today Stats
    private var todayStats: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(todayLogs.count)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(pottyBrown)
                Text("今日便便次数")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Week Chart
    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近 7 天")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7DaysCounts, id: \.date) { item in
                    VStack(spacing: 4) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                Calendar.current.isDateInToday(item.date)
                                    ? pottyBrown
                                    : (item.count > 0 ? pottyBrown.opacity(0.4) : Color.primary.opacity(0.08))
                            )
                            .frame(height: max(6, CGFloat(item.count) * 18))
                        Text(item.date, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90, alignment: .bottom)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Quick Log
    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速打卡")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4)).tracking(2)
            HStack(spacing: 10) {
                ForEach(PottyType.allCases, id: \.rawValue) { type in
                    Button { logPotty(type: type) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.systemIconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(pottyTypeColor(type))
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .goGlassBackground(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pottyTypeColor(_ type: PottyType) -> Color {
        switch type {
        case .perfectPoop: return pottyBrown
        case .softPoop:    return Color(hex: "F59E0B")
        case .liquidPoop:  return Color(hex: "EF4444")
        case .pee:         return Color(hex: "3B82F6")
        }
    }

    // MARK: - Health Insights
    @ViewBuilder
    private var healthInsights: some View {
        let abnormalPct = Int(last7AbnormalRatio * 100)
        let freqDelta = weekAvg - prevWeekAvg
        if abnormalPct > 30 || abs(freqDelta) > 1 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.goRed)
                    Text("健康洞察")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }

                if abnormalPct > 30 {
                    HStack(spacing: 8) {
                        Text("⚠️").font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("异常便便占比 \(abnormalPct)%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goRed)
                            Text("近7天软便/水便比例较高，建议关注饮食或就医")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if abs(freqDelta) > 1 {
                    HStack(spacing: 8) {
                        Text(freqDelta > 0 ? "📈" : "📉").font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("排便频率\(freqDelta > 0 ? "上升" : "下降")")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goYellow)
                            Text("本周日均 \(String(format: "%.1f", weekAvg)) 次，上周日均 \(String(format: "%.1f", prevWeekAvg)) 次")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Recent Logs
    private var recentLogList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if recentLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentLogs) { log in
                    HStack(spacing: 10) {
                        Image(systemName: log.pottyType.systemIconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(pottyTypeColor(log.pottyType))
                        Text(log.pottyType.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        } label: {
                            Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Remove Footer
    private var removeQuickActionFooter: some View {
        VStack(spacing: 14) {
            Divider().opacity(0.35)
            Button(role: .destructive) { onRemove(); dismiss() } label: {
                Text("移除此快捷入口")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions
    private func logPotty(type: PottyType) {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordPotty(pet: pet, type: type, context: modelContext, executorId: eid)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
