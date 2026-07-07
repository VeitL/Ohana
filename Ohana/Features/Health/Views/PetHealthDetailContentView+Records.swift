//
//  PetHealthDetailContentView+Records.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension PetHealthDetailContentView {
    var healthCoreGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            healthCoreCard(
                title: l.tr(zh: "预防", en: "Prevention", de: "Vorsorge"),
                value: nextPreventiveStatusText,
                icon: "shield.checkered",
                tint: isDark ? Color.goPrimary : Color.goTeal
            ) {
                openHealthRecord(.guided(.preventive))
            }
            healthCoreCard(
                title: l.tr(zh: "用药", en: "Medication", de: "Medikation"),
                value: medicationStatusText,
                icon: "pill.fill",
                tint: Color(hex: "FF8A3D")
            ) {
                OhanaFeedback.light()
                healthPlusDestination = .medications
            }
            healthCoreCard(
                title: l.tr(zh: "异常", en: "Symptoms", de: "Auffällig"),
                value: symptomStatusText,
                icon: "waveform.path.ecg",
                tint: latestSymptomLog == nil ? (isDark ? Color.goPrimary : Color.goTeal) : Color.goRed
            ) {
                openHealthRecord(.symptom)
            }
            healthCoreCard(
                title: l.tr(zh: "档案", en: "Archive", de: "Archiv"),
                value: archiveStatusText,
                icon: "folder.fill",
                tint: Color.goPurple
            ) {
                OhanaFeedback.light()
                showingHistory = true
            }
        }
    }

    func healthCoreCard(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            OhanaFeedback.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 19, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(title)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .padding(14)
            .goIslandModuleCard(cornerRadius: OhanaRadius.cardSoft)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var preventiveRingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "防护", en: "Protection", de: "Schutz"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    OhanaFeedback.light()
                    showingPassport = true
                } label: {
                    Image(systemName: "syringe.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(chromeAccent)
                        .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
                .buttonStyle(ScaleButtonStyle())
            }
            immunityOverviewRow
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
    }

    var quickToolsRow: some View {
        HStack(spacing: 10) {
            healthToolButton(title: l.tr(zh: "就诊", en: "Visit", de: "Besuch"), icon: "cross.case.fill", tint: Color.goRed, identifier: "pet-health-tool-visit-action") {
                healthPlusDestination = .guided(.visit)
            }
            healthToolButton(title: l.tr(zh: "疫苗本", en: "Vaccines", de: "Impfausweis"), icon: "syringe.fill", tint: Color.goTeal, identifier: "pet-health-tool-vaccine-passport-action") {
                showingPassport = true
            }
            if !pet.isNeutered {
                healthToolButton(title: l.tr(zh: "生理期", en: "Cycle", de: "Zyklus"), icon: "heart.text.square.fill", tint: Color.pink, identifier: "pet-health-tool-heat-cycle-action") {
                    healthPlusDestination = .heatCycle
                }
            }
            healthToolButton(title: "PDF", icon: "doc.richtext", tint: chromeAccent, identifier: "pet-health-tool-pdf-action") {
                guard !isRenderingPDF else { return }
                isRenderingPDF = true
                Task {
                    pdfURL = await PetVetSummaryPDFRenderer.render(pet: pet, context: modelContext)
                    isRenderingPDF = false
                    if pdfURL != nil { showingPDFPreview = true }
                }
            }
        }
    }

    func healthToolButton(
        title: String,
        icon: String,
        tint: Color,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            OhanaFeedback.light()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .goIslandModuleCard(cornerRadius: OhanaRadius.controlLarge)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }

    var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    OhanaFeedback.light()
                    showingHistory = true
                } label: {
                    Text(l.tr(zh: "全部", en: "All", de: "Alle"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(chromeAccent)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if recentHealthActivities.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 22, weight: .bold))
                        .foregroundStyle(chromeAccent)
                    Text(l.tr(zh: "还没有健康记录", en: "No health records yet", de: "Noch keine Gesundheitseinträge"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(recentHealthActivities) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(item.tint)
                            .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background(item.tint.opacity(isDark ? 0.20 : 0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(item.detail)
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(item.date.formatted(.dateTime.month().day()))
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                    .accessibilityIdentifier("pet-health-recent-row-\(item.id)")
                }
            }
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
    }

    // MARK: - 免疫状态总览条
    var immunityOverviewRow: some View {
        let items: [(HealthLogType, String, String, Int)] = [
            (.vaccine, "syringe.fill", l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"), 365),
            (.dewormingInternal, "pills.fill", l.tr(zh: "体内", en: "Internal", de: "Innen"), 90),
            (.dewormingExternal, "shield.lefthalf.filled", l.tr(zh: "体外", en: "External", de: "Außen"), 90),
            (.checkup, "stethoscope", l.tr(zh: "体检", en: "Checkup", de: "Check-up"), 365)
        ]
        return HStack(spacing: 0) {
            ForEach(items, id: \.0) { type, icon, label, cycle in
                let last = latestLog(type: type)
                let due = dueDate(for: type)
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
                        if let last {
                            let elapsed = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                            let progress = min(1.0, Double(elapsed) / Double(cycle))
                            Circle()
                                .trim(from: 0, to: 1 - progress)
                                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }
                        Image(systemName: icon)
                            .font(OhanaFont.adaptive(size: 16, weight: .black))
                            .foregroundStyle(color)
                    }
                    Text(label)
                        .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    if let d = days {
                        Text(d < 0 ? l.tr(zh: "逾期", en: "Overdue", de: "Überfällig") : l.tr(zh: "\(d)天", en: "\(d)d", de: "\(d) T"))
                            .font(OhanaFont.adaptive(size: 8, weight: .semibold)).foregroundStyle(color)
                    } else {
                        Text(l.tr(zh: "未记录", en: "No log", de: "Kein Eintrag"))
                            .font(OhanaFont.adaptive(size: 8)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    openHealthRecord(.direct(type))
                }
            }
        }
    }

    // MARK: - 散点图主体
    var scatterChart: some View {
        GeometryReader { proxy in
            let rows = HealthLogType.allCases
            let start = chartXDomain.lowerBound.timeIntervalSinceReferenceDate
            let span = max(chartXDomain.upperBound.timeIntervalSinceReferenceDate - start, 1)
            ZStack {
                ForEach(Array(rows.enumerated()), id: \.element.rawValue) { index, _ in
                    let y = rowY(index: index, count: rows.count, height: proxy.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(Color.ohanaPrimaryText.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                }

                ForEach(scatterPoints) { pt in
                    let xRatio = (pt.date.timeIntervalSinceReferenceDate - start) / span
                    let rowIndex = rows.firstIndex(of: pt.typeEnum) ?? 0
                    Circle()
                        .fill(colorForType(pt.typeEnum))
                        .frame(width: 11, height: 11) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .position(
                            x: min(max(CGFloat(xRatio) * proxy.size.width * scatterRevealProgress, 0), proxy.size.width),
                            y: rowY(index: rowIndex, count: rows.count, height: proxy.size.height)
                        )
                }
            }
        }
        .frame(height: 160)
        .onAppear { playScatterReveal() }
    }

    func rowY(index: Int, count: Int, height: CGFloat) -> CGFloat {
        guard count > 1 else { return height / 2 }
        let topInset: CGFloat = 12
        let bottomInset: CGFloat = 12
        let usable = max(1, height - topInset - bottomInset)
        return topInset + usable * CGFloat(index) / CGFloat(count - 1)
    }

    // MARK: - 图例视图
    var trendLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presentTypes, id: \.rawValue) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForType(type))
                            .frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Text(localizedHealthLogType(type))
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - 健康记录趋势（散点时间轴）
    var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "健康记录趋势", en: "Health trend", de: "Gesundheitstrend"), systemImage: "waveform.path.ecg")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text(l.tr(zh: "最近 12 个月", en: "Last 12 months", de: "Letzte 12 Monate"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            scatterChart
            trendLegend
        }
    }

    // MARK: - 健康记录列表卡
    var healthLogsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "健康时间轴", en: "Health timeline", de: "Gesundheitsverlauf"), systemImage: "list.bullet.clipboard.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(chromeAccent)
                Spacer()
                Text(l.tr(zh: "\(sortedLogs.count) 条", en: "\(sortedLogs.count)", de: "\(sortedLogs.count)"))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            if sortedLogs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "heart.text.square").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 34, weight: .black))
                        .foregroundStyle(chromeAccent)
                    Text(l.tr(zh: "暂无健康记录", en: "No health records yet", de: "Noch keine Gesundheitseinträge"))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(sortedLogs) { log in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(colorForType(log.healthLogType).opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            Image(systemName: healthIcon(for: log.healthLogType))
                                .font(OhanaFont.adaptive(size: 15, weight: .black))
                                .foregroundStyle(colorForType(log.healthLogType))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(localizedHealthLogType(log.healthLogType))
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            HStack(spacing: 6) {
                                Text(log.date, format: .dateTime.year().month().day())
                                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                if !log.note.isEmpty {
                                    Text(log.note)
                                        .font(OhanaFont.adaptive(size: 11))
                                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if log.cost > 0 {
                                Text(AppCurrency.format(log.cost, fractionDigits: 0))
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                            }
                            Button {
                                deleteHealthLog(log)
                            } label: {
                                Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                                    .font(OhanaFont.adaptive(size: 11))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            }
                            .disabled(deletingHealthRecordIDs.contains(log.id))
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
    var symptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "异常症状记录", en: "Symptom records", de: "Symptome"), systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.red)
                Spacer()
                Text(l.tr(zh: "\(symptomLogs.count) 条", en: "\(symptomLogs.count)", de: "\(symptomLogs.count)"))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach(sortedSymptomLogs) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: symptomCategoryIcon(log.category))
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(Color.goRed)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.symptomName)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        HStack(spacing: 6) {
                            Text(log.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            Text(localizedSymptomSeverity(log.severity))
                                .font(OhanaFont.adaptive(size: 10, weight: .bold))
                                .foregroundStyle(log.severity == .critical || log.severity == .severe ? Color.red : Color.orange)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background((log.severity == .critical || log.severity == .severe ? Color.red : Color.orange).opacity(0.15), in: Capsule())
                        }
                        if !log.note.isEmpty {
                            Text(log.note)
                                .font(OhanaFont.adaptive(size: 11))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        deleteSymptomLog(log)
                    } label: {
                        Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                            .font(OhanaFont.adaptive(size: 11))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                    .disabled(deletingHealthRecordIDs.contains(log.id))
                }
                .padding(.vertical, 6)
                if log.id != sortedSymptomLogs.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - 生理期记录卡
    var heatCycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "生理期与繁育", en: "Cycle and breeding", de: "Zyklus und Zucht"), systemImage: "heart.text.square.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.pink)
                Spacer()
                Text(l.tr(zh: "\(heatCycleLogs.count) 条", en: "\(heatCycleLogs.count)", de: "\(heatCycleLogs.count)"))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            ForEach(sortedHeatCycleLogs) { log in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: log.status.colorHex).opacity(0.15)).frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: "heart.text.square.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(Color(hex: log.status.colorHex))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedHeatCycleStatus(log.status))
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        HStack(spacing: 6) {
                            Text(log.startDate, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            if log.isMated {
                                Text(l.tr(zh: "已交配", en: "Mated", de: "Gepaart"))
                                    .font(OhanaFont.adaptive(size: 10, weight: .bold))
                                    .foregroundStyle(Color.pink)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.pink.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                    Spacer()
                    Button {
                        deleteHeatCycleLog(log)
                    } label: {
                        Image(systemName: deletingHealthRecordIDs.contains(log.id) ? "hourglass" : "trash")
                            .font(OhanaFont.adaptive(size: 11))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                    .disabled(deletingHealthRecordIDs.contains(log.id))
                }
                .padding(.vertical, 6)
                if log.id != sortedHeatCycleLogs.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Alerts Section（TASK 7）
    var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(isDark ? Color.goPrimary : Color.goOrange)
                Text(l.tr(zh: "健康预警", en: "Health alerts", de: "Gesundheitswarnungen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                Spacer()
                Text(l.tr(zh: "\(healthAlerts.count) 条", en: "\(healthAlerts.count)", de: "\(healthAlerts.count)"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            }

            ForEach(healthAlerts.prefix(5)) { alert in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                            .fill(alertColor(alert).opacity(0.15))
                            .frame(width: 32, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        Image(systemName: alertIcon(for: alert.type))
                            .font(OhanaFont.adaptive(size: 13, weight: .black))
                            .foregroundStyle(alertColor(alert))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(alert.detail)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
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

    func alertColor(_ alert: HealthAlert) -> Color {
        switch alert.severity {
        case .urgent: isDark ? Color.goPrimary : Color.goOrange
        case .warning: isDark ? Color.goPrimary.opacity(0.85) : Color.goYellow
        case .info: isDark ? Color.goPrimary.opacity(0.7) : Color.goTeal
        }
    }

    @ViewBuilder
    func severityBadge(_ severity: HealthAlert.Severity) -> some View {
        let (label, color): (String, Color) = switch severity {
        case .urgent: (l.tr(zh: "紧急", en: "Urgent", de: "Dringend"), isDark ? Color.goPrimary : Color.goOrange)
        case .warning: (l.tr(zh: "注意", en: "Watch", de: "Achtung"), isDark ? Color.goPrimary.opacity(0.9) : Color.goYellow)
        case .info: (l.tr(zh: "提示", en: "Info", de: "Info"), isDark ? Color.goPrimary.opacity(0.75) : Color.goTeal)
        }
        Text(label)
            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    func localizedHealthLogType(_ type: HealthLogType) -> String {
        switch type {
        case .general:
            l.tr(zh: "常规", en: "General", de: "Allgemein")
        case .vaccine:
            l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .medication:
            l.tr(zh: "用药", en: "Medication", de: "Medikation")
        case .dewormingInternal:
            l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .dewormingExternal:
            l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .surgery:
            l.tr(zh: "手术", en: "Surgery", de: "Operation")
        case .dental:
            l.tr(zh: "牙科", en: "Dental", de: "Zähne")
        case .checkup:
            l.tr(zh: "体检", en: "Checkup", de: "Check-up")
        case .emergency:
            l.tr(zh: "急诊", en: "Emergency", de: "Notfall")
        case .other:
            l.tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }

    func localizedSymptomSeverity(_ severity: SymptomSeverity) -> String {
        switch severity {
        case .mild:
            l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case .moderate:
            l.tr(zh: "中度", en: "Moderate", de: "Mittel")
        case .severe:
            l.tr(zh: "严重", en: "Severe", de: "Schwer")
        case .critical:
            l.tr(zh: "紧急", en: "Critical", de: "Kritisch")
        }
    }

    func localizedHeatCycleStatus(_ status: HeatCycleStatus) -> String {
        switch status {
        case .proestrus:
            l.tr(zh: "发情前期", en: "Proestrus", de: "Proöstrus")
        case .estrus:
            l.tr(zh: "发情期", en: "Estrus", de: "Östrus")
        case .diestrus:
            l.tr(zh: "发情后期", en: "Diestrus", de: "Diöstrus")
        case .anestrus:
            l.tr(zh: "休情期", en: "Anestrus", de: "Anöstrus")
        case .pregnant:
            l.tr(zh: "孕期", en: "Pregnancy", de: "Trächtigkeit")
        case .nursing:
            l.tr(zh: "哺乳期", en: "Nursing", de: "Säugezeit")
        }
    }
}
