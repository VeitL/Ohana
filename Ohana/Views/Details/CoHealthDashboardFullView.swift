//
//  CoHealthDashboardFullView.swift
//  Ohana
//
//  模块5：人宠共健仪表盘全屏页

import SwiftUI
import SwiftData
import Charts

struct CoHealthDashboardFullView: View {
    let human: Human
    @Query(sort: \Pet.name) private var allPets: [Pet]

    private var past30Days: Date {
        Calendar.current.date(byAdding: .day, value: -29,
            to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var associatedPets: [Pet] {
        allPets.filter { pet in
            pet.walkLogs.contains { $0.executorId == human.id.uuidString }
        }
    }

    private var thisMonthWalkKm: Double {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? past30Days
        let myId = human.id.uuidString
        let allLogs: [PetWalkLog] = associatedPets.flatMap { $0.walkLogs }
        let filtered = allLogs.filter { $0.executorId == myId && $0.startDate >= start }
        let total = filtered.reduce(0.0) { acc, log in acc + log.distanceMeters }
        return total / 1000
    }

    private var petWeightDelta: Double? {
        guard let pet = associatedPets.first else { return nil }
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? past30Days
        let logs = pet.weightLogs.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard logs.count >= 2 else { return nil }
        return logs.last!.weight - logs.first!.weight
    }

    private var summaryText: String {
        let petName = associatedPets.first?.name ?? "毛孩子"
        let km = String(format: "%.1f", thisMonthWalkKm)
        if let delta = petWeightDelta {
            let dir = delta < 0 ? "瘦了" : "胖了"
            return "本月你带 \(petName) 走了 \(km)km\n\(petName)\(dir) \(String(format: "%.1f", abs(delta)))kg 🎉"
        }
        return "本月你带 \(petName) 走了 \(km)km\n继续加油！💪"
    }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 趣味文案卡
                    summaryCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // 遛狗历史柱状图
                    walkBarSection
                        .padding(.horizontal, 20)

                    // 体重对比折线图
                    weightCompareSection
                        .padding(.horizontal, 20)

                    // 宠物健康摘要
                    if !associatedPets.isEmpty {
                        petHealthSection
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("人宠共健")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let data = human.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 52, height: 52).clipShape(Circle())
                } else {
                    Text(human.avatarEmoji).font(.system(size: 38))
                        .frame(width: 52, height: 52)
                        .background(Color(hex: human.themeColor).opacity(0.2), in: Circle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(human.name + " × 毛孩子")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("人宠共健报告")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Text("🏃").font(.system(size: 36))
            }

            Text(summaryText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goLime)
                .lineSpacing(4)
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }

    // MARK: - Walk Bar Section
    private var walkBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("🦮 遛狗里程（近7天）")

            let data = last7DaysWalkData
            if data.allSatisfy({ $0.km == 0 }) {
                emptyLabel("暂无遛狗记录")
            } else {
                Chart(data) { pt in
                    BarMark(
                        x: .value("日期", pt.label),
                        y: .value("km", pt.km)
                    )
                    .foregroundStyle(pt.isToday ? Color.goLime : Color.goLime.opacity(0.3))
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks { val in
                        AxisValueLabel {
                            if let s = val.as(String.self) {
                                Text(s)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(String(format: "%.1f", v))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(.clear) }
                .frame(height: 130)
            }
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }

    private var last7DaysWalkData: [DayWalkPoint] {
        let myId = human.id.uuidString
        let allLogs: [PetWalkLog] = associatedPets.flatMap { $0.walkLogs }
        let fmt = DateFormatter()
        fmt.dateFormat = "E"
        fmt.locale = Locale(identifier: "zh_CN")
        return (0..<7).map { offset in
            let day = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let dayLogs = allLogs.filter { log in
                log.executorId == myId &&
                Calendar.current.isDate(log.startDate, inSameDayAs: day)
            }
            let totalMeters = dayLogs.reduce(0.0) { acc, log in acc + log.distanceMeters }
            let km = totalMeters / 1000
            let isToday = Calendar.current.isDateInToday(day)
            return DayWalkPoint(label: isToday ? "今" : fmt.string(from: day), km: km, isToday: isToday)
        }
    }

    // MARK: - Weight Compare Section
    private var weightCompareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("⚖️ 体重对比趋势")
            CoHealthDashboardView(human: human)
                .allowsHitTesting(false)
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }

    // MARK: - Pet Health Section
    private var petHealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("🐾 毛孩子健康摘要")
            ForEach(associatedPets) { pet in
                HStack(spacing: 14) {
                    if let data = pet.avatarImageData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 44, height: 44).clipShape(Circle())
                    } else {
                        Text(pet.avatarEmoji).font(.system(size: 30))
                            .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pet.name)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first?.weight {
                            Text("最新体重 \(String(format: "%.1f", w)) kg")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    let monthWalk = pet.walkLogs
                        .filter { $0.executorId == human.id.uuidString &&
                            Calendar.current.isDate($0.startDate, equalTo: Date(), toGranularity: .month) }
                        .reduce(0.0) { $0 + $1.distanceMeters } / 1000
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f km", monthWalk))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goLime)
                        Text("本月同行").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }

    // MARK: - Helpers
    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }

    private func emptyLabel(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
}

private struct DayWalkPoint: Identifiable {
    let id = UUID()
    let label: String
    let km: Double
    let isToday: Bool
}
