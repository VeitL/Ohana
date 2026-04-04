//
//  WeightHistoryView.swift
//  Ohana
//
//  体重历史页 (C8a) - 上部图表 + 下部前置layer记录列表
//

import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false

    private var sortedLogs: [PetWeightLog] {
        pet.weightLogs.sorted(by: { $0.date > $1.date })
    }

    private var chartLogs: [PetWeightLog] {
        Array(pet.weightLogs.sorted(by: { $0.date < $1.date }).suffix(20))
    }

    // MARK: - Feeding data helpers
    private var recentFoodRecords: [PetFoodRecord] {
        pet.foodRecords.sorted { $0.startDate > $1.startDate }.prefix(7).map { $0 }
    }
    private var avgDailyGrams: Double? {
        let precise = recentFoodRecords.filter { $0.dailyGrams > 0 }
        guard !precise.isEmpty else { return nil }
        return precise.reduce(0.0) { $0 + $1.dailyGrams } / Double(precise.count)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ArkBackgroundView()

                VStack(spacing: 0) {
                    chartSection
                        .frame(maxHeight: .infinity)

                    if let avg = avgDailyGrams {
                        feedingInsightBanner(avg: avg)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    recordListLayer
                        .frame(height: geo.size.height * 0.52)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("体重追踪")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(OhanaFont.title2(.bold))
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            GenericWeightEntrySheet(target: .pet(pet))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("体重趋势")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    if let latest = sortedLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(latest.weightUnit == "g"
                                 ? String(format: "%.0f", latest.weight)
                                 : String(format: "%.1f", latest.weight))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(latest.weightUnit)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    }
                }
                Spacer()
                // 宠物头像
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 2))
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 40))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 变化标签
            if chartLogs.count >= 2 {
                let first = chartLogs.first!.weightInKg
                let last  = chartLogs.last!.weightInKg
                let delta = last - first
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%+.3f kg", delta))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 24)
            }

            // 折线图
            if chartLogs.count >= 2 {
                WeightDetailLineChart(logs: chartLogs)
                    .frame(height: 130)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // X轴标签
                let recent = chartLogs
                if let f = recent.first, let l = recent.last {
                    HStack {
                        Text(f.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(l.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
                    .padding(.horizontal, 24)
                }
            } else {
                Text("记录 2 条以上体重后可显示趋势图")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }

            Spacer()
        }
    }

    // MARK: - Feeding Insight Banner
    private func feedingInsightBanner(avg: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.goOrange)
                .frame(width: 36, height: 36)
                .background(Color.goOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("饮食 · 体重关联")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                HStack(spacing: 4) {
                    Text(String(format: "近期日均摄入 %.0fg", avg))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    if let latest = sortedLogs.first, let prev = sortedLogs.dropFirst().first {
                        let delta = latest.weightInKg - prev.weightInKg
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(delta >= 0 ? Color.goOrange : Color.goTeal)
                        Text(String(format: "%+.2fkg", delta))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(delta >= 0 ? Color.goOrange : Color.goTeal)
                    }
                }
            }

            Spacer()

            // Mini bar showing last few food records
            HStack(alignment: .bottom, spacing: 3) {
                let maxG = recentFoodRecords.map { $0.dailyGrams }.max() ?? 1
                ForEach(Array(recentFoodRecords.prefix(5).enumerated()), id: \.offset) { i, rec in
                    let h = max(6, CGFloat(rec.dailyGrams / maxG) * 28)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == 0 ? Color.goOrange : Color.goOrange.opacity(0.35))
                        .frame(width: 6, height: h)
                }
            }
            .frame(height: 28)
        }
        .padding(12)
        .goTranslucentCard(cornerRadius: 14)
    }

    // MARK: - Record List Layer
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                HStack {
                    Text("历史记录")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedLogs) { log in
                            weightRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有体重记录\n点击右上角 + 开始记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }
                        if let onRemove {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func bcsColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return Color(hex: "4ECDC4")
        case 4...5: return Color.goPrimary
        case 6...7: return Color(hex: "FFD93D")
        default:    return Color(hex: "FF6B6B")
        }
    }

    private func weightRow(log: PetWeightLog) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.primary.opacity(0.6))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                Text(log.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(log.weightUnit == "g"
                         ? String(format: "%.0f", log.weight)
                         : String(format: "%.1f", log.weight))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(log.weightUnit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                if log.bcsScore > 0 {
                    Text("BCS \(log.bcsScore)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(bcsColor(log.bcsScore), in: Capsule())
                }
            }

            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

}

// MARK: - Weight Detail Line Chart (大图)
struct WeightDetailLineChart: View {
    let logs: [PetWeightLog]

    // 统一用 kg 作图（避免 kg/g 混合导致图表失真）
    private var weights: [Double] { logs.map { $0.weightInKg } }
    private var minW: Double { (weights.min() ?? 0) - 0.3 }
    private var maxW: Double { (weights.max() ?? 1) + 0.3 }
    private var range: Double { max(maxW - minW, 0.1) }

    private func xPos(_ i: Int, w: CGFloat) -> CGFloat {
        logs.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(logs.count - 1) * w
    }
    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minW) / range) * h
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // 横向参考线
                ForEach(0..<3) { i in
                    let y = h / 2 * CGFloat(i)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                }

                if logs.count >= 2 {
                    // 填充
                    Path { path in
                        path.move(to: CGPoint(x: xPos(0, w: w), y: h))
                        path.addLine(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y)
                            let cp2 = CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y)
                            path.addCurve(to: curr, control1: cp1, control2: cp2)
                        }
                        path.addLine(to: CGPoint(x: xPos(logs.count-1, w: w), y: h))
                        path.closeSubpath()
                    }
                    .fill(.regularMaterial.opacity(0.3))

                    // 折线
                    Path { path in
                        path.move(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y)
                            let cp2 = CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y)
                            path.addCurve(to: curr, control1: cp1, control2: cp2)
                        }
                    }
                    .stroke(.primary.opacity(0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    // 数据点
                    ForEach(Array(logs.enumerated()), id: \.offset) { i, log in
                        Circle()
                            .fill(i == logs.count - 1 ? Color.primary : Color.primary.opacity(0.5))
                            .frame(width: i == logs.count - 1 ? 8 : 5, height: i == logs.count - 1 ? 8 : 5)
                            .position(x: xPos(i, w: w), y: yPos(log.weight, h: h))
                    }
                }
            }
        }
    }
}
