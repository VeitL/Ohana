//
//  PetHealthDetailView.swift
//  Ohana
//
//  健康详情页 — 饮食管理页风格
//  深色背景 + ScrollView卡片 + Swift Charts
//

import SwiftUI
import SwiftData
import Charts

// MARK: - 健康添加 Sheet 路由
private enum HealthPlusDestination: Identifiable {
    case guided(HealthRecordEntryMode)
    case direct(HealthLogType)
    case medications
    case symptom     // 新增
    case heatCycle   // 新增

    var id: String {
        switch self {
        case .guided(let m):
            return m == .preventive ? "guide_p" : "guide_v"
        case .direct(let t):
            return "dir_\(t.rawValue)"
        case .medications:
            return "meds"
        case .symptom:
            return "symptom"
        case .heatCycle:
            return "heat"
        }
    }
}

// MARK: - Health Scatter Point (散点时间轴)
private struct HealthScatterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let typeName: String
    let typeEnum: HealthLogType
}

struct PetHealthDetailView: View {
    let pet: Pet
    var isModal: Bool = false
    /// D4: 关闭时额外回调（如需一并关闭父级）
    var onFullDismiss: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// 健康页「+」与免疫条点按的路由
    @State private var healthPlusDestination: HealthPlusDestination?
    @State private var showingPDFPreview = false
    @State private var pdfURL: URL? = nil
    @State private var isRenderingPDF = false
    @State private var healthAlerts: [HealthAlert] = []
    @State private var scatterRevealProgress: CGFloat = 0.0

    private func playScatterReveal() {
        scatterRevealProgress = 0
        withAnimation(.easeOut(duration: 0.38)) {
            scatterRevealProgress = 1.0
        }
    }

    private var themeColor: Color { pet.themeColor.color }
    private var isDark: Bool { colorScheme == .dark }
    /// 深色：界面结构色统一荧光绿；与宠物相关的记录语义仍用 `themeColor` / `colorForType`
    private var chromeAccent: Color { isDark ? Color.goPrimary : themeColor }

    private var sortedLogs: [PetHealthLog] {
        pet.healthLogs.sorted { $0.date > $1.date }
    }

    private func latestLog(type: HealthLogType) -> PetHealthLog? {
        pet.healthLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }.first
    }

    private func dueDate(for type: HealthLogType) -> Date? {
        guard let last = latestLog(type: type) else { return nil }
        switch type {
        case .vaccine:    return Calendar.current.date(byAdding: .year,  value: 1, to: last.date)
        case .medication, .dewormingInternal, .dewormingExternal:
                          return Calendar.current.date(byAdding: .month, value: 3, to: last.date)
        case .checkup:    return Calendar.current.date(byAdding: .year,  value: 1, to: last.date)
        default:          return nil
        }
    }

    private func daysUntil(_ date: Date?) -> Int? {
        guard let d = date else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }

    private func colorForType(_ type: HealthLogType) -> Color {
        switch type {
        case .vaccine: return themeColor
        case .medication, .dewormingInternal, .dewormingExternal:
            return isDark ? Color.goPrimary.opacity(0.92) : Color.goTeal
        case .checkup:
            return isDark ? themeColor.opacity(0.9) : Color.goYellow
        case .surgery, .emergency:
            return isDark ? Color.goPrimary.opacity(0.85) : Color.goRed
        default:
            return isDark ? Color.goPrimary.opacity(0.78) : Color.goCardCyan
        }
    }

    // 散点数据：最近 12 个月每条记录一个点
    private var scatterPoints: [HealthScatterPoint] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return pet.healthLogs
            .filter { $0.date >= cutoff }
            .map { HealthScatterPoint(date: $0.date, typeName: $0.type,
                                     typeEnum: HealthLogType(rawValue: $0.type) ?? .general) }
    }

    // 图表 X 轴范围
    private var chartXDomain: ClosedRange<Date> {
        let start = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        return start...Date()
    }

    // 颜色映射 domain / range（固定顺序供 chartColorScale 使用）
    private var colorDomain: [String] {
        HealthLogType.allCases.map(\.rawValue)
    }
    private var colorRange: [Color] {
        HealthLogType.allCases.map { colorForType($0) }
    }

    // 图例：当前数据中出现的类型（已排序，稳定）
    private var presentTypes: [HealthLogType] {
        var seen = Set<String>()
        return scatterPoints.compactMap { pt -> HealthLogType? in
            guard seen.insert(pt.typeName).inserted else { return nil }
            return pt.typeEnum
        }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── 健康预警
                    if !healthAlerts.isEmpty {
                        alertsSection
                            .padding(14)
                            .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    // ── 免疫状态总览
                    immunityOverviewRow
                        .padding(14)
                        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    NavigationLink {
                        VaccinePassportView(pet: pet)
                    } label: {
                        HStack(spacing: 10) {
                            Text("💉")
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("疫苗本")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("接种记录与到期提醒")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                    .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    // ── 散点时间轴
                    if !scatterPoints.isEmpty {
                        healthTrendCard
                            .padding(14)
                            .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    // ── 异常症状记录卡
                    if !(pet.symptomLogs ?? []).isEmpty {
                        symptomsCard
                            .padding(14)
                            .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    
                    // ── 生理期记录卡
                    if !(pet.heatCycleLogs ?? []).isEmpty {
                        heatCycleCard
                            .padding(14)
                            .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    // ── 健康记录列表
                    healthLogsCard
                        .padding(14)
                        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .onAppear {
                healthAlerts = PetHealthAlertEngine.shared.scanAlerts(pets: [pet])
            }
        }
        .navigationTitle("\(pet.name) · 健康")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                    // D4: 如果有外部回调（来自 PetDetailView），同时关闭父级
                    onFullDismiss?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // PDF 导出按钮
                    if isRenderingPDF {
                        ProgressView().tint(chromeAccent).scaleEffect(0.8)
                    } else {
                        Button {
                            isRenderingPDF = true
                            Task {
                                pdfURL = await PetVetSummaryPDFRenderer.render(pet: pet)
                                isRenderingPDF = false
                                if pdfURL != nil { showingPDFPreview = true }
                            }
                        } label: {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(chromeAccent.opacity(0.9))
                        }
                    }
                    Menu {
                        Button {
                            healthPlusDestination = .guided(.preventive)
                        } label: {
                            Label("预防护理", systemImage: "shield.checkered")
                        }
                        Button {
                            healthPlusDestination = .guided(.visit)
                        } label: {
                            Label("就诊记录", systemImage: "cross.case.fill")
                        }
                        Button {
                            healthPlusDestination = .medications
                        } label: {
                            Label("用药记录", systemImage: "pill.fill")
                        }
                        Divider()
                        Button {
                            healthPlusDestination = .symptom
                        } label: {
                            Label("记录异常症状", systemImage: "exclamationmark.triangle.fill")
                        }
                        if !pet.isNeutered {
                            Button {
                                healthPlusDestination = .heatCycle
                            } label: {
                                Label("记录生理期", systemImage: "heart.text.square.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "FF5A00"))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .sheet(item: $healthPlusDestination) { dest in
            switch dest {
            case .guided(let mode):
                AddHealthRecordSheet(
                    pet: pet,
                    type: mode == .preventive ? .vaccine : .surgery,
                    entryMode: mode
                )
            case .direct(let t):
                AddHealthRecordSheet(pet: pet, type: t, entryMode: nil)
            case .medications:
                PetMedicationView(pet: pet)
            case .symptom:
                AddSymptomSheet(pet: pet)
            case .heatCycle:
                AddHeatCycleSheet(pet: pet)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let url = pdfURL {
                PetVetPDFShareSheet(pdfURL: url, pet: pet)
            }
        }
    }

    // MARK: - 免疫状态总览条
    private var immunityOverviewRow: some View {
        let items: [(HealthLogType, String, String, Int)] = [
            (.vaccine,           "💉", "疫苗",  365),
            (.dewormingInternal, "🪱", "体内驱虫", 90),
            (.dewormingExternal, "🛡️", "体外驱虫", 90),
            (.checkup,           "🩺", "体检",  365),
        ]
        return HStack(spacing: 0) {
            ForEach(items, id: \.0) { type, emoji, label, cycle in
                let last = latestLog(type: type)
                let due  = dueDate(for: type)
                let days = daysUntil(due)
                let color: Color = {
                    guard let d = days else { return .primary.opacity(0.3) }
                    if d < 0 { return Color.goRed }
                    if d < 30 { return isDark ? Color.goPrimary : Color.goYellow }
                    return themeColor
                }()
                VStack(spacing: 5) {
                    ZStack {
                        Circle().stroke(color.opacity(0.18), lineWidth: 3).frame(width: 44, height: 44)
                        if let last = last {
                            let elapsed = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                            let progress = min(1.0, Double(elapsed) / Double(cycle))
                            Circle()
                                .trim(from: 0, to: 1 - progress)
                                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }
                        Text(emoji).font(.system(size: 18))
                    }
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                    if let d = days {
                        Text(d < 0 ? "逾期" : "\(d)天")
                            .font(.system(size: 8, weight: .semibold)).foregroundStyle(color)
                    } else {
                        Text("未记录")
                            .font(.system(size: 8)).foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture { healthPlusDestination = .direct(type) }
            }
        }
    }

    // MARK: - 散点图主体
    private var scatterChart: some View {
        Chart {
            // 每种类型一条极细引导线
            ForEach(HealthLogType.allCases, id: \.rawValue) { type in
                RuleMark(y: .value("类型", type.rawValue))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                    .foregroundStyle(.primary.opacity(0.08))
            }
            // 每条记录一个散点，直接映射颜色
            ForEach(scatterPoints) { pt in
                PointMark(
                    x: .value("日期", pt.date),
                    y: .value("类型", pt.typeName)
                )
                .foregroundStyle(colorForType(pt.typeEnum))
                .symbolSize(110)
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
            }
        }
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: max(1, geo.size.width * scatterRevealProgress))
            }
        }
        .frame(height: 160)
        .onAppear { playScatterReveal() }
    }

    // MARK: - 图例视图
    private var trendLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presentTypes, id: \.rawValue) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForType(type))
                            .frame(width: 7, height: 7)
                        Text(type.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - 健康记录趋势（散点时间轴）
    private var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("健康记录趋势", systemImage: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text("最近 12 个月")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            scatterChart
            trendLegend
        }
    }

    // MARK: - 健康记录列表卡
    private var healthLogsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("健康时间轴", systemImage: "list.bullet.clipboard.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text("\(sortedLogs.count) 条")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            if sortedLogs.isEmpty {
                VStack(spacing: 10) {
                    Text("💉").font(.system(size: 36))
                    Text("暂无健康记录\n点击右上角 + 开始记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(sortedLogs) { log in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(colorForType(log.healthLogType).opacity(0.15)).frame(width: 38, height: 38)
                            Text(log.healthLogType.emoji).font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(log.type)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                Text(log.date, format: .dateTime.year().month().day())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.4))
                                if !log.note.isEmpty {
                                    Text(log.note)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.primary.opacity(0.4))
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if log.cost > 0 {
                                Text("¥\(Int(log.cost))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.7))
                            }
                            Button {
                                modelContext.delete(log); modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash").font(.system(size: 11))
                                    .foregroundStyle(.primary.opacity(0.3))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    if log.id != sortedLogs.last?.id {
                    Divider()
                }
                }
            }
        }
    }

    // MARK: - 异常症状记录卡
    private var symptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("异常症状记录", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.red)
                Spacer()
                Text("\((pet.symptomLogs ?? []).count) 条")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach((pet.symptomLogs ?? []).sorted(by: { $0.date > $1.date })) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 38, height: 38)
                        Text(log.category.emoji).font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.symptomName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                            Text(log.severity.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(log.severity == .critical || log.severity == .severe ? Color.red : Color.orange)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background((log.severity == .critical || log.severity == .severe ? Color.red : Color.orange).opacity(0.15), in: Capsule())
                        }
                        if !log.note.isEmpty {
                            Text(log.note)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        modelContext.delete(log); modelContext.safeSave()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .padding(.vertical, 6)
                if log.id != (pet.symptomLogs ?? []).sorted(by: { $0.date > $1.date }).last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - 生理期记录卡
    private var heatCycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("生理期与繁育", systemImage: "heart.text.square.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.pink)
                Spacer()
                Text("\((pet.heatCycleLogs ?? []).count) 条")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach((pet.heatCycleLogs ?? []).sorted(by: { $0.startDate > $1.startDate })) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: log.status.colorHex).opacity(0.15)).frame(width: 38, height: 38)
                        Text("💖").font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.status.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text(log.startDate, format: .dateTime.year().month().day())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                            if log.isMated {
                                Text("已交配")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.pink)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.pink.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                    Spacer()
                    Button {
                        modelContext.delete(log); modelContext.safeSave()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .padding(.vertical, 6)
                if log.id != (pet.heatCycleLogs ?? []).sorted(by: { $0.startDate > $1.startDate }).last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Alerts Section（TASK 7）
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isDark ? Color.goPrimary : Color.goOrange)
                Text("健康预警")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                Spacer()
                Text("\(healthAlerts.count) 条")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
            }

            ForEach(healthAlerts.prefix(5)) { alert in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(alertColor(alert).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text(alert.emoji)
                            .font(.system(size: 15))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(alert.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.45))
                            .lineLimit(2)
                    }
                    Spacer()
                    severityBadge(alert.severity)
                }
                .padding(.vertical, 4)
                if alert.id != healthAlerts.prefix(5).last?.id {
                    Divider()
                }
            }
        }
    }

    private func alertColor(_ alert: HealthAlert) -> Color {
        switch alert.severity {
        case .urgent:  return isDark ? Color.goPrimary : Color.goOrange
        case .warning: return isDark ? Color.goPrimary.opacity(0.85) : Color.goYellow
        case .info:    return isDark ? Color.goPrimary.opacity(0.7) : Color.goTeal
        }
    }

    @ViewBuilder
    private func severityBadge(_ severity: HealthAlert.Severity) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case .urgent:  return ("紧急", isDark ? Color.goPrimary : Color.goOrange)
            case .warning: return ("注意", isDark ? Color.goPrimary.opacity(0.9) : Color.goYellow)
            case .info:    return ("提示", isDark ? Color.goPrimary.opacity(0.75) : Color.goTeal)
            }
        }()
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}
