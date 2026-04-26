//
//  HumanWeightHistoryView.swift
//  Ohana
//
//  U13: 人类体重记录页

import SwiftUI
import SwiftData

struct HumanWeightHistoryView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var showAddSheet = false
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }

    private var sortedLogs: [HumanWeightLog] {
        human.weightLogs.sorted { $0.date > $1.date }
    }
    private var chartLogs: [HumanWeightLog] {
        Array(human.weightLogs.sorted { $0.date < $1.date }.suffix(20))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                VStack(spacing: 0) {
                    chartSection.frame(maxHeight: .infinity)
                    recordListLayer.frame(height: 320)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("体重追踪")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPrivacyLocked {
                ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goPrimary)
                }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            GenericWeightEntrySheet(target: .human(human))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var privacyLockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.goYellow)
            Text("体重记录仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(.primary)
            Text("当前家庭成员无权查看这些数据。")
                .font(OhanaFont.callout())
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .ohanaStandardCard(cornerRadius: 24)
        .padding(.horizontal, 24)
    }

    // MARK: - Chart
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("体重趋势")
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(.primary)
                    if let latest = sortedLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", latest.weight))
                                .font(OhanaFont.metric(size: 44))
                                .foregroundStyle(.primary)
                            Text("kg")
                                .font(OhanaFont.title3(.bold))
                                .foregroundStyle(Color.goTeal)
                        }
                    }
                }
                Spacer()
                if let data = human.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2))
                } else {
                    Text(human.avatarEmoji).font(.system(size: 40))
                }
            }
            .padding(.horizontal, 24).padding(.top, 16)

            if chartLogs.count >= 2 {
                let delta = chartLogs.last!.weight - chartLogs.first!.weight
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(OhanaFont.caption(.bold))
                    Text(String(format: "%+.1f kg", delta))
                        .font(OhanaFont.footnote(.bold))
                }
                .foregroundStyle(delta >= 0 ? Color.goYellow : Color.goTeal)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background((delta >= 0 ? Color.goYellow : Color.goTeal).opacity(0.12), in: Capsule())
                .padding(.horizontal, 24)
            }

            if chartLogs.count >= 2 {
                HumanWeightLineChart(logs: chartLogs)
                    .frame(height: 130)
                    .padding(.horizontal, 24).padding(.top, 8)
                if let f = chartLogs.first, let l = chartLogs.last {
                    HStack {
                        Text(f.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(l.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(OhanaFont.caption2())
                    .foregroundStyle(.primary.opacity(0.3))
                    .padding(.horizontal, 24)
                }
            } else {
                Text("记录 2 条以上体重后可显示趋势图")
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(.primary.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
            Spacer()
        }
    }

    // MARK: - Record List
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            // 深色玻璃面板，兼容深/浅色模式
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text("历史记录")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20).padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedLogs) { log in
                            weightRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有体重记录\n点击右上角 + 开始记录")
                                .font(OhanaFont.callout())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 40)
                }
            }
        }
    }

    private func weightRow(log: HumanWeightLog) -> some View {
        HStack(spacing: 14) {
            Circle().fill(Color.goPrimary).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(.primary)
                Text(log.date, format: .dateTime.weekday(.wide))
                    .font(OhanaFont.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", log.weight))
                    .font(OhanaFont.metric(size: 20))
                    .foregroundStyle(.primary)
                Text("kg")
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
            }
            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

// MARK: - Line Chart
struct HumanWeightLineChart: View {
    let logs: [HumanWeightLog]

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
                ForEach(0..<3) { i in
                    let y = h / 2 * CGFloat(i)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                }

                if logs.count >= 2 {
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
                        colors: [Color.goPrimary.opacity(0.35), Color.goPrimary.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))

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
                    .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    ForEach(Array(logs.enumerated()), id: \.offset) { i, log in
                        Circle()
                            .fill(i == logs.count - 1 ? Color.goPrimary : Color.goPrimary.opacity(0.5))
                            .frame(width: i == logs.count - 1 ? 8 : 5, height: i == logs.count - 1 ? 8 : 5)
                            .position(x: xPos(i, w: w), y: yPos(log.weight, h: h))
                    }
                }
            }
        }
    }
}
