//
//  QuickWaterDetailSheet.swift
//  Ohana
//
//  喂水/换水 统一详情 Sheet — 顶部模式开关切换内容
//

import SwiftUI
import SwiftData
import Charts

struct QuickWaterDetailSheet: View {
    let pet: Pet
    var initialModeRaw: String? = nil
    var lockedModeRaw: String? = nil
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var waterModeRaw: String = "drink"

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var isDark: Bool { colorScheme == .dark }
    /// 深色：非「本页宠物数据主色」的控件强调统一荧光绿
    private var chromeTint: Color { isDark ? Color.goPrimary : themeColor }
    private let waterChangeTint = Color(hex: CareType.waterChange.accentColorHex)
    private let filterCleanTint = Color(hex: CareType.filterClean.accentColorHex)

    enum WaterMode: String, CaseIterable {
        case drink = "drink"
        case change = "change"
        var label: String { self == .drink ? "喂水" : "换水" }
        var icon: String { self == .drink ? "💧" : "🪣" }
    }

    private struct WaterQualityBucket: Identifiable {
        let id: String
        let label: String
        let waterChanges: Int
        let filterCleans: Int

        var total: Int { waterChanges + filterCleans }
    }

    private var currentMode: WaterMode {
        WaterMode(rawValue: waterModeRaw) ?? .drink
    }

    private var waterModeStorageKey: String { "waterSheetMode_\(petKey)" }

    // Drink data
    private var todayWaterLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var weekChartData: [(String, Int)] {
        let cal = Calendar.current
        let labels = ["日","一","二","三","四","五","六"]
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            let count = pet.careLogs.filter {
                $0.type == CareType.watering.rawValue && cal.isDate($0.date, inSameDayAs: d)
            }.count
            let weekday = cal.component(.weekday, from: d) - 1
            return (labels[weekday], count)
        }
    }

    // Change data
    @State private var waterIntervalDays: Int = 3
    @State private var waterChangeAnchorDate: Date = Date()
    @State private var hasWaterEndDate: Bool = false
    @State private var waterPlanEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var filterCleanIntervalDays: Int = 14
    @State private var filterReplaceIntervalDays: Int = 90
    @State private var waterReminderOn = false
    @State private var filterReminderOn = false
    @State private var saveToastMessage = ""
    @State private var showSaveToast = false
    @State private var saveToastTask: Task<Void, Never>?

    private var petKey: String { pet.id.uuidString }

    private var lastWaterChange: PetCareLog? {
        waterChangeLogs.first
    }
    private var lastFilterClean: PetCareLog? {
        filterCleanLogs.first
    }
    private var waterChangeLogs: [PetCareLog] {
        pet.careLogs.filter { $0.type == CareType.waterChange.rawValue }.sorted { $0.date > $1.date }
    }
    private var filterCleanLogs: [PetCareLog] {
        pet.careLogs.filter { $0.type == CareType.filterClean.rawValue }.sorted { $0.date > $1.date }
    }
    private var changeRecentLogs: [PetCareLog] {
        pet.careLogs.filter {
            $0.type == CareType.waterChange.rawValue || $0.type == CareType.filterClean.rawValue
        }.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }
    private var waterElapsedDays: Int {
        daysSinceDate(lastWaterChange?.date ?? waterChangeAnchorDate)
    }
    private var filterCleanElapsedDays: Int? {
        lastFilterClean.map { daysSinceDate($0.date) }
    }
    private var filterReplaceElapsedDays: Int? {
        lastFilterClean.map { daysSinceDate($0.date) }
    }
    private var daysUntilWaterChange: Int { waterIntervalDays - waterElapsedDays }
    private var daysUntilFilterClean: Int? { filterCleanElapsedDays.map { filterCleanIntervalDays - $0 } }
    private var daysUntilFilterReplace: Int? { filterReplaceElapsedDays.map { filterReplaceIntervalDays - $0 } }
    private var waterChangesLast30Days: Int { recentCount(type: .waterChange, days: 30) }
    private var filterCleansLast30Days: Int { recentCount(type: .filterClean, days: 30) }
    private var waterQualityBuckets: [WaterQualityBucket] {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        return (0..<6).reversed().compactMap { offset in
            guard let bucketStart = cal.date(byAdding: .day, value: -offset * 5, to: startToday),
                  let bucketEnd = cal.date(byAdding: .day, value: 5, to: bucketStart) else { return nil }
            let waterCount = waterChangeLogs.filter { $0.date >= bucketStart && $0.date < bucketEnd }.count
            let filterCount = filterCleanLogs.filter { $0.date >= bucketStart && $0.date < bucketEnd }.count
            let day = cal.component(.day, from: bucketStart)
            return WaterQualityBucket(
                id: "\(Int(bucketStart.timeIntervalSince1970))",
                label: "\(day)",
                waterChanges: waterCount,
                filterCleans: filterCount
            )
        }
    }
    private func daysSince(_ log: PetCareLog?) -> Int? {
        guard let l = log else { return nil }
        return daysSinceDate(l.date)
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
                        if lockedModeRaw == nil {
                            modeToggle
                        }

                        if currentMode == .drink {
                            drinkContent
                        } else {
                            changeContent
                        }

                        removeQuickActionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .transaction { t in t.disablesAnimations = true }
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom, 28)
            }
            .navigationTitle("")
            .overlay(alignment: .top) {
                if showSaveToast {
                    Text(saveToastMessage)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(chromeTint, in: Capsule())
                        .shadow(color: chromeTint.opacity(0.32), radius: 12, y: 6)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isDark ? Color.goPrimary.opacity(0.85) : Color.secondary)
                    }
                }
            }
        }
        .onAppear {
            migrateLegacyWaterModeIfNeeded()
            if let lockedModeRaw {
                waterModeRaw = lockedModeRaw
            } else if let initialModeRaw {
                waterModeRaw = initialModeRaw
                UserDefaults.standard.set(initialModeRaw, forKey: waterModeStorageKey)
            }
            loadChangeSettings()
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
                Text(currentMode == .drink ? "饮水管理" : "水质管理")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Image(systemName: currentMode == .drink ? "drop.fill" : "arrow.2.circlepath")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(themeColor)
        }
    }

    // MARK: - Mode Toggle
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(WaterMode.allCases, id: \.rawValue) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        waterModeRaw = m.rawValue
                        UserDefaults.standard.set(m.rawValue, forKey: waterModeStorageKey)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m == .drink ? "drop.fill" : "arrow.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                        Text(m.label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(currentMode == m ? Color.arkInk : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        currentMode == m ? themeColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Drink Content
    private var drinkContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(todayWaterLogs.count)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(themeColor)
                    Text("今日喂水次数")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("近 7 天")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Chart(Array(weekChartData.enumerated()), id: \.offset) { _, item in
                    BarMark(x: .value("日", item.0), y: .value("次", item.1))
                        .foregroundStyle(themeColor.opacity(item.1 > 0 ? 0.75 : 0.15))
                        .cornerRadius(4)
                }
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
            .padding(.vertical, 6)

            Button { commitWater() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("喂水打卡")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(themeColor, in: Capsule())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Text("今日记录")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                if todayWaterLogs.isEmpty {
                    Text("暂无记录")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(todayWaterLogs) { log in
                        HStack {
                            Text(log.date, style: .time)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.6))
                            Spacer()
                            Button {
                                modelContext.delete(log)
                                modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Change Content
    private var changeContent: some View {
        VStack(spacing: 20) {
            waterQualityDataCard
            waterChangeCard
            filterCard
            changeHistoryCard
        }
    }

    private var waterQualityDataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chromeTint)
                Text(l.tr(zh: "水质数据", en: "Water data", de: "Wasserdaten"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(l.tr(zh: "近 30 天", en: "30 days", de: "30 Tage"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                waterQualityMetric(
                    title: l.tr(zh: "下次换水", en: "Next water change", de: "Nächster Wasserwechsel"),
                    value: dueText(daysUntil: daysUntilWaterChange),
                    subtitle: l.tr(
                        zh: "已过 \(waterElapsedDays)/\(waterIntervalDays) 天",
                        en: "\(waterElapsedDays)/\(waterIntervalDays) days elapsed",
                        de: "\(waterElapsedDays)/\(waterIntervalDays) Tage vergangen"
                    ),
                    icon: "arrow.2.circlepath",
                    tint: waterChangeTint,
                    isOverdue: daysUntilWaterChange < 0
                )

                waterQualityMetric(
                    title: l.tr(zh: "滤材清洗", en: "Filter clean", de: "Filter reinigen"),
                    value: optionalDueText(daysUntilFilterClean),
                    subtitle: filterCleanElapsedDays.map {
                        l.tr(
                            zh: "已过 \($0)/\(filterCleanIntervalDays) 天",
                            en: "\($0)/\(filterCleanIntervalDays) days elapsed",
                            de: "\($0)/\(filterCleanIntervalDays) Tage vergangen"
                        )
                    } ?? l.tr(zh: "清理一次后开始追踪", en: "Track after first clean", de: "Nach erster Reinigung verfolgen"),
                    icon: "sparkles",
                    tint: filterCleanTint,
                    isOverdue: (daysUntilFilterClean ?? 1) < 0
                )

                waterQualityMetric(
                    title: l.tr(zh: "记录次数", en: "Logged actions", de: "Einträge"),
                    value: "\(waterChangesLast30Days + filterCleansLast30Days)",
                    subtitle: l.tr(
                        zh: "换水 \(waterChangesLast30Days) · 滤材 \(filterCleansLast30Days)",
                        en: "Water \(waterChangesLast30Days) · Filter \(filterCleansLast30Days)",
                        de: "Wasser \(waterChangesLast30Days) · Filter \(filterCleansLast30Days)"
                    ),
                    icon: "number",
                    tint: chromeTint,
                    isOverdue: false
                )

                waterQualityMetric(
                    title: l.tr(zh: "滤芯更换", en: "Filter replace", de: "Filterwechsel"),
                    value: optionalDueText(daysUntilFilterReplace),
                    subtitle: l.tr(zh: "按上次清理估算", en: "Estimated from last clean", de: "Aus letzter Reinigung geschätzt"),
                    icon: "calendar.badge.clock",
                    tint: filterCleanTint,
                    isOverdue: (daysUntilFilterReplace ?? 1) < 0
                )
            }

            VStack(spacing: 12) {
                cycleProgressRow(
                    title: l.tr(zh: "换水周期", en: "Water change cycle", de: "Wasserwechsel-Zyklus"),
                    elapsedDays: waterElapsedDays,
                    intervalDays: waterIntervalDays,
                    tint: waterChangeTint
                )
                cycleProgressRow(
                    title: l.tr(zh: "滤材清洗周期", en: "Filter clean cycle", de: "Filterreinigungs-Zyklus"),
                    elapsedDays: filterCleanElapsedDays,
                    intervalDays: filterCleanIntervalDays,
                    tint: filterCleanTint
                )
            }

            waterQualityActivityBars
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func waterQualityMetric(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isOverdue: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(isOverdue ? Color.goRed : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cycleProgressRow(
        title: String,
        elapsedDays: Int?,
        intervalDays: Int,
        tint: Color
    ) -> some View {
        let safeInterval = max(intervalDays, 1)
        let elapsed = max(elapsedDays ?? 0, 0)
        let progress = min(Double(elapsed) / Double(safeInterval), 1)
        let status = elapsedDays.map {
            l.tr(zh: "\($0)/\(safeInterval) 天", en: "\($0)/\(safeInterval) days", de: "\($0)/\(safeInterval) Tage")
        } ?? l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(status)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(elapsed >= safeInterval ? Color.goRed : .secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(tint.opacity(elapsed >= safeInterval ? 0.95 : 0.72))
                        .frame(width: max(6, proxy.size.width * progress))
                }
            }
            .frame(height: 7)
        }
    }

    private var waterQualityActivityBars: some View {
        let maxTotal = max(waterQualityBuckets.map(\.total).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(l.tr(zh: "记录分布", en: "Activity spread", de: "Verteilung"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                waterQualityLegend(l.tr(zh: "换水", en: "Water", de: "Wasser"), color: waterChangeTint)
                waterQualityLegend(l.tr(zh: "滤材", en: "Filter", de: "Filter"), color: filterCleanTint)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(waterQualityBuckets) { bucket in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.primary.opacity(0.07))
                                .frame(width: 13, height: 52)

                            VStack(spacing: 2) {
                                Spacer(minLength: 0)
                                if bucket.filterCleans > 0 {
                                    Capsule()
                                        .fill(filterCleanTint.opacity(0.78))
                                        .frame(width: 13, height: bucketHeight(bucket.filterCleans, maxTotal: maxTotal))
                                }
                                if bucket.waterChanges > 0 {
                                    Capsule()
                                        .fill(waterChangeTint.opacity(0.88))
                                        .frame(width: 13, height: bucketHeight(bucket.waterChanges, maxTotal: maxTotal))
                                }
                            }
                            .frame(width: 13, height: 52)
                        }
                        Text(bucket.label)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func waterQualityLegend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var waterChangeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("换水计划")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text("从「起算日」与最近一次换水记录推算周期；打开同步后可在日历页查看（与铲屎计划一致）。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let d = daysSince(lastWaterChange) {
                    statusPill(d == 0 ? "今天已换" : "\(d)天前", isOverdue: d >= waterIntervalDays)
                } else {
                    statusPill("未记录", isOverdue: false)
                }
                Spacer()
                Button { doWaterChange() } label: {
                    Text("立即换水")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("换水间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $waterIntervalDays, in: 1...30) {
                    Text("\(waterIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .tint(chromeTint)
                .onChange(of: waterIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "waterInterval_\(petKey)")
                }
            }

            DatePicker("起算日", selection: $waterChangeAnchorDate, displayedComponents: .date)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .onChange(of: waterChangeAnchorDate) { _, d in
                    UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "waterChangeCycleAnchor_\(petKey)")
                }

            // 截止日期（可选）
            Toggle(isOn: $hasWaterEndDate) {
                Text("设置截止日期")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(chromeTint)
            if hasWaterEndDate {
                DatePicker("截止日期", selection: $waterPlanEndDate, in: waterChangeAnchorDate..., displayedComponents: .date)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tint(chromeTint)
                    .onChange(of: waterPlanEndDate) { _, d in
                        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "waterPlanEndDate_\(petKey)")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Toggle(isOn: $waterReminderOn) {
                Text("同步换水计划到日历")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(chromeTint)
            .onChange(of: waterReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "waterReminder_\(petKey)")
            }

            waterPlanSaveButton(title: "保存") { saveWaterChangePlanToCalendar() }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("滤芯管理")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack {
                if let d = daysSince(lastFilterClean) {
                    statusPill(d == 0 ? "今天已清" : "\(d)天前清洗", isOverdue: d >= filterCleanIntervalDays)
                } else {
                    statusPill("未记录", isOverdue: false)
                }
                Spacer()
                Button { doFilterClean() } label: {
                    Text("清理滤芯")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("清洗间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $filterCleanIntervalDays, in: 1...60) {
                    Text("\(filterCleanIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .tint(chromeTint)
                .onChange(of: filterCleanIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "filterCleanInterval_\(petKey)")
                }
            }

            HStack {
                Text("更换间隔")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $filterReplaceIntervalDays, in: 7...365) {
                    Text("\(filterReplaceIntervalDays) 天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .tint(chromeTint)
                .onChange(of: filterReplaceIntervalDays) { _, v in
                    UserDefaults.standard.set(v, forKey: "filterReplaceInterval_\(petKey)")
                }
            }

            Toggle(isOn: $filterReminderOn) {
                Text("到期提醒")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .tint(chromeTint)
            .onChange(of: filterReminderOn) { _, on in
                UserDefaults.standard.set(on, forKey: "filterReminder_\(petKey)")
            }

            waterPlanSaveButton(title: "保存设置") { saveFilterPlanSettings() }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var changeHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if changeRecentLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(changeRecentLogs) { log in
                    HStack {
                        Image(systemName: log.careType.systemIconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeColor)
                        Text(log.careType.label)
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

    // MARK: - Helpers
    private func waterPlanSaveButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveWaterChangePlanToCalendar() {
        UserDefaults.standard.set(waterIntervalDays, forKey: "waterInterval_\(petKey)")
        persistWaterAnchor()
        UserDefaults.standard.set(waterReminderOn, forKey: "waterReminder_\(petKey)")
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet, context: modelContext,
            intervalDays: waterIntervalDays, enabled: waterReminderOn, cycleAnchor: waterChangeAnchorDate
        )
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(waterReminderOn ? "已保存，并同步到日历" : "已保存")
    }

    private func saveFilterPlanSettings() {
        UserDefaults.standard.set(filterCleanIntervalDays, forKey: "filterCleanInterval_\(petKey)")
        UserDefaults.standard.set(filterReplaceIntervalDays, forKey: "filterReplaceInterval_\(petKey)")
        UserDefaults.standard.set(filterReminderOn, forKey: "filterReminder_\(petKey)")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("已保存")
    }

    private func showSaveConfirmation(_ message: String) {
        saveToastTask?.cancel()
        saveToastMessage = message
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            showSaveToast = true
        }
        saveToastTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    showSaveToast = false
                }
            }
        }
    }

    private func statusPill(_ text: String, isOverdue: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(isOverdue ? Color.goRed : .primary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background((isOverdue ? Color.goRed : themeColor).opacity(0.12), in: Capsule())
    }

    private func daysSinceDate(_ date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        return max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    private func recentCount(type: CareType, days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return pet.careLogs.filter { $0.type == type.rawValue && $0.date >= cutoff }.count
    }

    private func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 {
            return l.tr(zh: "还剩 \(daysUntil) 天", en: "\(daysUntil)d left", de: "noch \(daysUntil) T.")
        }
        if daysUntil == 0 {
            return l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
        }
        let overdueDays = abs(daysUntil)
        return l.tr(zh: "逾期 \(overdueDays) 天", en: "\(overdueDays)d overdue", de: "\(overdueDays) T. überfällig")
    }

    private func optionalDueText(_ daysUntil: Int?) -> String {
        guard let daysUntil else {
            return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")
        }
        return dueText(daysUntil: daysUntil)
    }

    private func bucketHeight(_ count: Int, maxTotal: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let ratio = CGFloat(count) / CGFloat(max(maxTotal, 1))
        return max(5, min(52, 52 * ratio))
    }

    private func migrateLegacyWaterModeIfNeeded() {
        let d = UserDefaults.standard
        if d.object(forKey: waterModeStorageKey) == nil,
           let legacy = d.string(forKey: "waterSheetMode") {
            d.set(legacy, forKey: waterModeStorageKey)
        }
        waterModeRaw = d.string(forKey: waterModeStorageKey) ?? "drink"
    }

    private func loadChangeSettings() {
        let d = UserDefaults.standard
        let wi = d.integer(forKey: "waterInterval_\(petKey)")
        waterIntervalDays = wi > 0 ? wi : 3
        let fci = d.integer(forKey: "filterCleanInterval_\(petKey)")
        filterCleanIntervalDays = fci > 0 ? fci : 14
        let fri = d.integer(forKey: "filterReplaceInterval_\(petKey)")
        filterReplaceIntervalDays = fri > 0 ? fri : 90
        waterReminderOn = d.bool(forKey: "waterReminder_\(petKey)")
        filterReminderOn = d.bool(forKey: "filterReminder_\(petKey)")
        let anchorTI = d.double(forKey: "waterChangeCycleAnchor_\(petKey)")
        if anchorTI > 0 {
            waterChangeAnchorDate = Date(timeIntervalSince1970: anchorTI)
        } else {
            waterChangeAnchorDate = Calendar.current.startOfDay(for: Date())
            persistWaterAnchor()
        }
    }

    private func persistWaterAnchor() {
        UserDefaults.standard.set(waterChangeAnchorDate.timeIntervalSince1970, forKey: "waterChangeCycleAnchor_\(petKey)")
    }

    // MARK: - Actions
    private func commitWater() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(pet: pet, type: .watering, amountMl: 250, context: modelContext, executorId: eid, reward: .water)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func doWaterChange() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(
            pet: pet,
            type: .waterChange,
            context: modelContext,
            executorId: eid,
            reward: .general(humanReward: 15, petReward: 20, emoji: CareType.waterChange.emoji, title: "\(pet.name) 换水奖励")
        )
        saveWaterChangePlanToCalendar()
    }

    private func doFilterClean() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        CareEventService.recordCare(
            pet: pet,
            type: .filterClean,
            context: modelContext,
            executorId: eid,
            reward: .general(humanReward: 25, petReward: 40, emoji: CareType.filterClean.emoji, title: "\(pet.name) 清理滤材报酬")
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
