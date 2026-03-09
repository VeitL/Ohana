//
//  WeightHistoryView.swift
//  Ohana
//
//  体重历史页 (C8a) - 上部图表 + 下部前置layer记录列表
//

import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false

    private var sortedLogs: [PetWeightLog] {
        pet.weightLogs.sorted(by: { $0.date > $1.date })
    }

    private var chartLogs: [PetWeightLog] {
        Array(pet.weightLogs.sorted(by: { $0.date < $1.date }).suffix(20))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // ── 顶部图表区 ──
                chartSection
                    .frame(maxHeight: .infinity)

                // ── 下部前置卡片（记录列表）──
                recordListLayer
                    .frame(height: UIScreen.main.bounds.height * 0.52)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("体重追踪")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goLime)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            GenericWeightEntrySheet(target: .pet(pet))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
                        .foregroundStyle(.white)
                    if let latest = sortedLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", latest.weight))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("kg")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.goTeal)
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
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2))
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 40))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 变化标签
            if chartLogs.count >= 2 {
                let first = chartLogs.first!.weight
                let last = chartLogs.last!.weight
                let delta = last - first
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%+.1f kg", delta))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(delta >= 0 ? Color.goYellow : Color.goTeal)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    (delta >= 0 ? Color.goYellow : Color.goTeal).opacity(0.12),
                    in: Capsule()
                )
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
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 24)
                }
            } else {
                Text("记录 2 条以上体重后可显示趋势图")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }

            Spacer()
        }
    }

    // MARK: - Record List Layer
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "F2F0F5"))
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                HStack {
                    Text("历史记录")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func weightRow(log: PetWeightLog) -> some View {
        HStack(spacing: 14) {
            // 颜色指示点
            Circle()
                .fill(Color.goTeal)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.7))
                Text(log.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", log.weight))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Text("kg")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goTeal)
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

}

// MARK: - Weight Detail Line Chart (大图)
struct WeightDetailLineChart: View {
    let logs: [PetWeightLog]

    private var weights: [Double] { logs.map { $0.weight } }
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
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
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
                    .fill(LinearGradient(
                        colors: [Color.goTeal.opacity(0.4), Color.goTeal.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))

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
                    .stroke(Color.goTeal, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    // 数据点
                    ForEach(Array(logs.enumerated()), id: \.offset) { i, log in
                        Circle()
                            .fill(i == logs.count - 1 ? Color.goTeal : Color.goTeal.opacity(0.5))
                            .frame(width: i == logs.count - 1 ? 8 : 5, height: i == logs.count - 1 ? 8 : 5)
                            .position(x: xPos(i, w: w), y: yPos(log.weight, h: h))
                    }
                }
            }
        }
    }
}
