//
//  QuickFeedDetailSheet.swift
//  Ohana
//
//  喂食详情 Sheet — 手动/按计划 + 粮仓管理（佛系/精准） + 计算器 + 历史
//

import SwiftUI
import SwiftData
import UIKit

private let knownFoodBrands: [String] = [
    "Royal Canin 皇家", "Orijen 渴望", "Acana 爱肯拿", "Ziwi 巅峰",
    "Hill's 希尔斯", "Purina Pro Plan 冠能", "Josera", "Wolfsblut", "Animonda",
    "MAC's", "Myfoodie 麦富迪", "NetEase 严选", "自定义品牌"
]

struct QuickFeedDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var selectedTab: FeedTab = .today
    @State private var portionText = ""
    @State private var goalCount = 3
    @State private var newScheduleTime = Date()
    @State private var newScheduleAmount = ""
    @State private var newRuleKind: FeedRuleKind = .manualReminder
    @State private var showAddSchedule = false
    @State private var schedulePendingDelete: Event? = nil
    @State private var showingDeleteScheduleConfirm = false
    @State private var treatText = ""

    // Stock tracking mode
    @State private var selectedStockMode: FoodTrackingMode = .casual
    @State private var casualOpenDate: Date = Date()
    @State private var casualDurationDays: Int = 30
    private let durationOptions: [(String, Int)] = [
        ("1个月", 30), ("2个月", 60), ("3个月", 90), ("半年", 180)
    ]
    private let foodReminderAdvanceOptions: [Int] = [1, 3, 7, 14]

    // MARK: - State: Anti-repeat check
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)? = nil
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""

    // Stock editing (precise mode)
    @State private var editingStock = false
    @State private var showStockSheet = false
    @State private var selectedBrand: String = ""
    @State private var customBrandInput: String = ""
    @State private var stockKgInput: String = ""
    @State private var stockWeightUnit: FoodWeightUnit = .grams
    @State private var dailyGramsInput: String = ""
    @State private var stockPriceInput: String = ""
    @State private var stockPayerId: String = ""
    @State private var showingFoodUsageRecords = false
    @State private var editingFoodRecord: PetFoodRecord? = nil
    @State private var foodRecordPendingDelete: PetFoodRecord? = nil
    @State private var showingDeleteFoodRecordConfirm = false
    @State private var editFoodRecordBrand = ""
    @State private var editFoodRecordDailyGrams = ""
    @State private var editFoodRecordNotes = ""
    @State private var editFoodRecordStartDate = Date()
    @State private var editingFeedLog: PetCareLog? = nil
    @State private var editFeedLogGrams = ""
    @State private var editFeedLogDate = Date()

    // Calculator
    @State private var showingCalculator = false
    @State private var calcWeightKg: String = ""
    @State private var calcLifeStage: Int = 2
    private let lifeStageLabels = ["幼年（<4月）", "青年（4-12月）", "成年·活跃", "成年·绝育", "老年（>7岁）"]
    private let lifeStageFactors: [Double] = [3.0, 2.0, 1.8, 1.2, 1.2]

    // Toast
    @State private var showOverdoseToast = false
    @State private var overdoseIsSuccess = false
    @State private var toastTask: Task<Void, Never>? = nil

    @AppStorage("defaultFeedGrams") private var defaultFeedGrams: Double = 0

    enum FeedTab: String, CaseIterable {
        case today
        case feeding
        case auto
        case stock

        var icon: String {
            switch self {
            case .today: return "chart.pie.fill"
            case .feeding: return "fork.knife.circle.fill"
            case .auto: return "dot.radiowaves.left.and.right"
            case .stock: return "shippingbox.fill"
            }
        }

        func label(_ l: L10n) -> String {
            switch self {
            case .today: return l.tr(zh: "今日", en: "Today", de: "Heute")
            case .feeding: return l.tr(zh: "喂食", en: "Feed", de: "Füttern")
            case .auto: return l.tr(zh: "自动", en: "Auto", de: "Auto")
            case .stock: return l.tr(zh: "粮仓", en: "Stock", de: "Vorrat")
            }
        }
    }

    enum FoodWeightUnit: String, CaseIterable {
        case grams
        case kilograms

        var label: String {
            switch self {
            case .grams: return "g"
            case .kilograms: return "kg"
            }
        }

        var placeholder: String {
            switch self {
            case .grams: return "2000"
            case .kilograms: return "2"
            }
        }
    }

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var feedTodayState: FeedTodayState {
        FeedTodayState(pet: pet, allEvents: allEvents, manualGoalCount: goalCount)
    }

    private var feedRuleState: FeedRuleState {
        FeedRuleState(pet: pet, allEvents: allEvents)
    }

    private var stockSnapshot: FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: pet, events: allEvents)
    }

    /// 今日仅「手动记录」喂食（与按计划互斥统计）
    private var manualTodayFeedLogs: [PetCareLog] {
        feedTodayState.manualTodayLogs
    }

    private var manualTodayFeedGrams: Double {
        feedTodayState.todayMainFoodGrams
    }

    private var feedScheduleEvents: [Event] {
        feedRuleState.manualReminderEvents
    }

    private var autoFeederEvents: [Event] {
        feedRuleState.autoFeederEvents
    }

    private var savedGoal: Int {
        let key = "feedGoal_\(pet.id.uuidString)"
        let v = UserDefaults.standard.integer(forKey: key)
        return v > 0 ? v : 3
    }

    private var rerResult: (low: Double, high: Double)? {
        guard let kg = Double(calcWeightKg.replacingOccurrences(of: ",", with: ".")), kg > 0 else { return nil }
        let factor = lifeStageFactors[calcLifeStage]
        let rer = 70 * pow(kg, 0.75)
        let mer = rer * factor
        let grams = (mer / 3.5)
        return (low: grams * 0.9, high: grams * 1.1)
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
                        feedTabPicker
                        selectedTabContent
                        removeQuickActionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaPadding(.bottom, 28)

                if showOverdoseToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: overdoseIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(overdoseIsSuccess ? Color.goPrimary : Color.goYellow)
                            Text(overdoseIsSuccess ? "今日份量已达标" : "超出今日额定份量")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(overdoseIsSuccess ? Color.goPrimary : Color.goYellow, in: Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                    .zIndex(99)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showOverdoseToast)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        dismissFeedKeyboard()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goLime)
                }
            }
        }
        .onAppear {
            materializeAutoFeedLogs()
            goalCount = savedGoal
            if pet.dailyPortionGrams > 0 {
                portionText = String(format: "%.0f", pet.dailyPortionGrams)
            }
            selectedStockMode = .precise
            casualOpenDate = pet.restockDate ?? pet.casualOpenDate ?? Date()
            if pet.casualDurationDays > 0 { casualDurationDays = pet.casualDurationDays }
            selectedBrand = knownFoodBrands.contains(pet.foodBrand) ? pet.foodBrand : (pet.foodBrand.isEmpty ? knownFoodBrands[0] : "自定义品牌")
            customBrandInput = pet.foodBrand
            if pet.restockWeight > 0 {
                stockWeightUnit = pet.restockWeight >= 1 ? .kilograms : .grams
                stockKgInput = formattedStockWeightInput(totalGrams: pet.restockWeight * 1000, unit: stockWeightUnit)
            }
            if pet.dailyPortionGrams > 0 { dailyGramsInput = String(format: "%.0f", pet.dailyPortionGrams) }
        }
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button("确定打卡", role: .destructive) {
                pendingRepeatAction?()
                pendingRepeatAction = nil
            }
            Button("取消", role: .cancel) {
                pendingRepeatAction = nil
            }
        } message: {
            Text(antiRepeatMessage)
        }
        .alert(l.tr(zh: "删除喂食计划？", en: "Delete feeding plan?", de: "Fütterungsplan löschen?"), isPresented: $showingDeleteScheduleConfirm) {
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                if let event = schedulePendingDelete {
                    deleteSchedule(event)
                }
                schedulePendingDelete = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                schedulePendingDelete = nil
            }
        } message: {
            Text(l.tr(zh: "删除后不会影响已经产生的喂食历史。", en: "Existing feeding history will stay unchanged.", de: "Bestehende Fütterungshistorie bleibt erhalten."))
        }
        .alert(l.tr(zh: "删除用粮记录？", en: "Delete stock record?", de: "Vorratseintrag löschen?"), isPresented: $showingDeleteFoodRecordConfirm) {
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                if let record = foodRecordPendingDelete {
                    deleteFoodRecord(record)
                }
                foodRecordPendingDelete = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                foodRecordPendingDelete = nil
            }
        } message: {
            Text(l.tr(zh: "只会删除这条粮仓记录，不会删除已经产生的喂食打卡。", en: "Only this stock record is removed. Feeding logs stay saved.", de: "Nur dieser Vorratseintrag wird gelöscht. Fütterungslogs bleiben erhalten."))
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
                Text("喂食管理")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(themeColor)
        }
    }

    // MARK: - Tabs
    private var feedTabPicker: some View {
        HStack(spacing: 6) {
            ForEach(FeedTab.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(tab.label(l))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Color.arkInk : .primary.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.goLime : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.goLime.opacity(0.95) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.6 : 0.8)
                    }
                    .shadow(color: isSelected ? Color.goLime.opacity(0.28) : .clear, radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .today:
            todayFeedTab
        case .feeding:
            feedingTab
        case .auto:
            autoTab
        case .stock:
            stockTab
        }
    }

    // MARK: - Today Tab
    private var todayFeedTab: some View {
        VStack(spacing: 16) {
            todayFocusCard
            todayStockOverviewCard
            todayFeedingOverviewCard
            todayAutoOverviewCard
        }
    }

    private var todayFocusCard: some View {
        let state = feedTodayState
        let stockStatus = currentFoodRunOutStatus
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: state.progress)
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(state.completedCount)/\(state.targetCount)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(state.hasTodayPlan ? l.tr(zh: "计划", en: "Plan", de: "Plan") : l.tr(zh: "餐数", en: "Meals", de: "Mahlz."))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: state.hasOverduePlan ? "exclamationmark.triangle.fill" : "fork.knife.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(state.hasOverduePlan ? Color.goRed : themeColor)
                        Text(todayFeedHeadline)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    Text(todayFeedSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        focusMiniMetric(
                            title: l.tr(zh: "今日主粮", en: "Main food", de: "Hauptfutter"),
                            value: state.todayMainFoodGrams > 0 ? formattedFoodWeight(state.todayMainFoodGrams) : "--",
                            tint: themeColor
                        )
                        focusMiniMetric(
                            title: l.tr(zh: "零食", en: "Treats", de: "Snacks"),
                            value: state.todayTreatGrams > 0 ? formattedFoodWeight(state.todayTreatGrams) : "--",
                            tint: Color.goYellow
                        )
                    }
                    HStack(spacing: 8) {
                        focusMiniMetric(
                            title: l.tr(zh: "粮仓", en: "Stock", de: "Vorrat"),
                            value: stockStatus.value,
                            tint: stockStatus.tint
                        )
                    }
                }
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var todayStockOverviewCard: some View {
        let status = currentFoodRunOutStatus
        let brand = pet.foodBrand.isEmpty
            ? l.tr(zh: "未设置粮食品牌", en: "No food brand", de: "Keine Futtermarke")
            : pet.foodBrand

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(status.tint.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(status.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "粮仓概览", en: "Food stock", de: "Futtervorrat"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(brand)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedTab = .stock
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text(status.message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                todayStockMetric(
                    title: l.tr(zh: "剩余", en: "Left", de: "Rest"),
                    value: status.value,
                    icon: "calendar.badge.clock",
                    tint: status.tint
                )
                todayStockMetric(
                    title: selectedStockMode == .casual
                        ? l.tr(zh: "开包", en: "Opened", de: "Geöffnet")
                        : l.tr(zh: "库存", en: "Stock", de: "Vorrat"),
                    value: todayStockAmountText,
                    icon: selectedStockMode == .casual ? "leaf.fill" : "scalemass.fill",
                    tint: themeColor
                )
                todayStockMetric(
                    title: l.tr(zh: "提醒", en: "Alert", de: "Alarm"),
                    value: todayStockReminderText,
                    icon: pet.foodReminderEnabled ? "bell.badge.fill" : "bell.slash.fill",
                    tint: pet.foodReminderEnabled ? Color.goTeal : Color.secondary
                )
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var todayFeedingOverviewCard: some View {
        let state = feedTodayState
        let pendingText = state.hasTodayPlan
            ? "\(max(0, state.targetCount - state.completedCount))"
            : "\(max(0, goalCount - state.completedCount))"
        return todayModuleShortcutCard(
            icon: "fork.knife.circle.fill",
            title: l.tr(zh: "喂食打卡", en: "Feeding", de: "Fütterung"),
            subtitle: state.hasTodayPlan
                ? l.tr(zh: "手动提醒、今日打卡和零食记录都在这里处理。", en: "Manual reminders, check-ins, and treats live here.", de: "Manuelle Erinnerungen, Einträge und Snacks sind hier.")
                : l.tr(zh: "手动记录主粮/零食，也可以设置每日喂食计划。", en: "Log main food/treats or set a daily feeding plan.", de: "Hauptfutter/Snacks eintragen oder Tagesplan setzen."),
            value: l.tr(zh: "待 \(pendingText)", en: "\(pendingText) left", de: "\(pendingText) offen"),
            tint: themeColor,
            target: .feeding
        )
    }

    private var todayAutoOverviewCard: some View {
        let total = Int(feedRuleState.autoDailyTotalGrams.rounded())
        return todayModuleShortcutCard(
            icon: FeedRuleKind.autoFeeder.iconName,
            title: l.tr(zh: "自动喂食器", en: "Auto feeder", de: "Automat"),
            subtitle: autoFeederEvents.isEmpty
                ? l.tr(zh: "设置自动喂食器后，打开 app 会补齐已到点日志。", en: "Add auto rules to materialize due logs when the app opens.", de: "Auto-Regeln schreiben fällige Logs beim Öffnen.")
                : l.tr(zh: "自动记录只放在自动页，避免和手动计划混在一起。", en: "Auto logging is managed separately from manual plans.", de: "Auto-Logs sind getrennt von manuellen Plänen."),
            value: autoFeederEvents.isEmpty
                ? l.tr(zh: "未设置", en: "None", de: "Keine")
                : "\(formattedFoodWeight(Double(total)))/天",
            tint: Color.goTeal,
            target: .auto
        )
    }

    private func todayModuleShortcutCard(
        icon: String,
        title: String,
        subtitle: String,
        value: String,
        tint: Color,
        target: FeedTab
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedTab = target
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func todayStockMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func focusMiniMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickAmountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l.tr(zh: "本次份量", en: "Amount", de: "Menge"), systemImage: "scalemass.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    GoDraftTextField(
                        "0",
                        text: $portionText,
                        keyboardType: .decimalPad,
                        capitalization: .never
                    )
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("g")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !quickFeedGramOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickFeedGramOptions, id: \.self) { grams in
                            Button {
                                portionText = String(format: "%.0f", grams)
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text("\(Int(grams))g")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(isSelectedQuickAmount(grams) ? Color.arkInk : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .goSelectableSurface(isSelected: isSelectedQuickAmount(grams), tint: themeColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var treatAmountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(l.tr(zh: "零食记录", en: "Treat", de: "Snack"), systemImage: "birthday.cake.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    GoDraftTextField(
                        l.tr(zh: "克数", en: "g", de: "g"),
                        text: $treatText,
                        keyboardType: .decimalPad,
                        capitalization: .never
                    )
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    Text("g")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button { commitTreatFeed() } label: {
                        Text(l.tr(zh: "记录", en: "Log", de: "Eintragen"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.goYellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled((Double(treatText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                    .opacity((Double(treatText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 ? 1 : 0.45)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.goYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text(l.tr(zh: "零食会进入今日摄入和历史，不扣主粮库存。", en: "Treats count toward intake and history, but do not reduce main food stock.", de: "Snacks zählen zur Aufnahme und Historie, reduzieren aber nicht den Hauptvorrat."))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.goYellow.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var todayPlanPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l.tr(zh: "今日手动提醒", en: "Manual reminders", de: "Manuelle Erinnerungen"), systemImage: "clock.badge.checkmark")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(feedTodayState.completedCount)/\(feedTodayState.targetCount)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ForEach(feedTodayState.todayPlanReminders.prefix(4)) { reminder in
                plannedReminderRow(reminder)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var manualGoalCard: some View {
        HStack(spacing: 12) {
            Label(l.tr(zh: "每日目标", en: "Daily goal", de: "Tagesziel"), systemImage: "target")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Stepper(value: $goalCount, in: 1...10) {
                Text("\(goalCount) \(l.tr(zh: "餐", en: "meals", de: "Mahlz."))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(themeColor)
            }
            .onChange(of: goalCount) { _, newVal in
                UserDefaults.standard.set(newVal, forKey: "feedGoal_\(pet.id.uuidString)")
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 从计划标题中解析克数（与计划打卡逻辑一致）
    private func parseScheduleGrams(from event: Event) -> Double {
        FeedRuleMetadata.amountGrams(from: event)
    }

    private func mealName(for date: Date) -> String {
        FeedRuleMetadata.mealName(for: date)
    }

    private func scheduleDisplayTitle(for event: Event) -> String {
        let grams = parseScheduleGrams(from: event)
        let name = FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) ? "自动喂食器" : mealName(for: event.startDate)
        return grams > 0 ? "\(name) \(formattedFoodWeight(grams))" : name
    }

    private var plannedSchedulesDailyTotalGrams: Double {
        feedScheduleEvents.reduce(0) { $0 + parseScheduleGrams(from: $1) }
    }

    private var currentFoodRunOutDate: Date? {
        stockSnapshot.runOutDate
    }

    private var hasSavedCasualStockInfo: Bool {
        pet.foodTrackingMode == .casual && pet.casualOpenDate != nil && pet.casualDurationDays > 0
    }

    private var sortedFoodRecords: [PetFoodRecord] {
        pet.foodRecords.sorted { $0.startDate > $1.startDate }
    }

    private var foodStockReminderEvents: [Event] {
        allEvents.filter {
            $0.relatedEntityType == "pet_food_stock" &&
            $0.relatedEntityId == pet.id.uuidString
        }
    }

    private var currentFoodReminderDate: Date? {
        guard pet.foodReminderEnabled,
              let runOut = currentFoodRunOutDate else { return nil }
        let raw = Calendar.current.date(byAdding: .day, value: -pet.foodReminderAdvanceDays, to: runOut) ?? runOut
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: raw) ?? raw
    }

    private var todayStockAmountText: String {
        if selectedStockMode == .casual {
            if let openDate = pet.casualOpenDate {
                return openDate.formatted(.dateTime.month().day())
            }
            return l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
        }
        if stockSnapshot.remainingGrams > 0 {
            return formattedFoodWeight(stockSnapshot.remainingGrams)
        }
        if pet.restockWeight > 0 {
            return formattedFoodWeight(pet.restockWeight * 1000)
        }
        return l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
    }

    private var todayStockReminderText: String {
        guard pet.foodReminderEnabled else {
            return l.tr(zh: "未开", en: "Off", de: "Aus")
        }
        if let date = currentFoodReminderDate {
            return date.formatted(.dateTime.month().day())
        }
        return l.tr(zh: "已开", en: "On", de: "Ein")
    }

    private var stockEstimateExplanation: String {
        switch stockSnapshot.estimatedDailyBasis {
        case .recentAverage:
            return "剩余天数按近 7 天实际主粮日均 \(formattedFoodWeight(stockSnapshot.estimatedDailyGrams)) 估算；零食不扣主粮库存。"
        case .autoRules:
            return "暂缺近期记录，按自动喂食器每日 \(formattedFoodWeight(stockSnapshot.estimatedDailyGrams)) 估算。"
        case .defaultPortion:
            return "暂缺近期记录，按默认每餐 \(formattedFoodWeight(stockSnapshot.estimatedDailyGrams)) 估算。"
        case .unavailable:
            return "记录主粮或设置自动喂食器后，会自动估算剩余天数。"
        }
    }

    // MARK: - Feeding Tab
    private var feedingTab: some View {
        VStack(spacing: 16) {
            quickAmountSection
            primaryFeedCTA
            treatAmountSection
            manualFeedingPlanSection
            todayLogList
        }
    }

    private var primaryFeedCTA: some View {
        Button { commitSmartFeed() } label: {
            HStack(spacing: 8) {
                Image(systemName: feedTodayState.nextPendingReminder == nil ? "fork.knife" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(feedTodayState.nextPendingReminder == nil
                     ? l.tr(zh: "记录主粮", en: "Log main food", de: "Hauptfutter eintragen")
                     : l.tr(zh: "完成下一餐", en: "Complete next meal", de: "Nächste Mahlzeit erledigen"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(themeColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var manualFeedingPlanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !manualTodayFeedLogs.isEmpty {
                feedModeSideNote(
                    icon: "fork.knife.circle",
                    title: "今日已有 \(manualTodayFeedLogs.count) 条手动记录",
                    message: "手动记录会保留为加餐或补记；按计划打卡会单独完成对应提醒。"
                )
            }

            HStack {
                Text("每日喂食计划")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    newRuleKind = .manualReminder
                    showAddSchedule = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(themeColor)
                }
            }

            if plannedSchedulesDailyTotalGrams > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "sum")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeColor)
                    Text("计划主粮 \(formattedFoodWeight(plannedSchedulesDailyTotalGrams))/天")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if feedScheduleEvents.isEmpty {
                Text("还没有每日喂食计划\n可以先用每日目标餐数，也可以添加具体提醒时间")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                manualGoalCard
            } else {
                ruleGroupTitle("手动提醒")
                ForEach(feedScheduleEvents) { event in
                    scheduleRow(event)
                }
            }

            if showAddSchedule && newRuleKind == .manualReminder {
                addScheduleForm()
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Auto Tab
    private var autoTab: some View {
        VStack(spacing: 16) {
            autoFocusCard
            autoFeederSection
        }
    }

    private var autoFocusCard: some View {
        let dailyTotal = Int(feedRuleState.autoDailyTotalGrams.rounded())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.goTeal.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: FeedRuleKind.autoFeeder.iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.goTeal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动喂食器")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(autoFeederEvents.isEmpty ? "还没有自动规则" : "每日自动主粮 \(formattedFoodWeight(Double(dailyTotal)))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(autoFeederEvents.isEmpty ? "--" : "\(autoFeederEvents.count)条")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
            }
            Text("这里只放自动喂食器规则。到点后，打开 app 或喂食页会补齐自动主粮日志并扣减粮仓。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var autoFeederSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("自动规则")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    newRuleKind = .autoFeeder
                    showAddSchedule = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goTeal)
                }
                .buttonStyle(.plain)
            }

            if autoFeederEvents.isEmpty {
                Text("还没有自动喂食器规则\n添加后会按时间和克数自动补齐日志")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(autoFeederEvents) { event in
                    scheduleRow(event)
                }
            }

            if showAddSchedule && newRuleKind == .autoFeeder {
                addScheduleForm()
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func feedModeSideNote(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeColor)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.75))
                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(themeColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func ruleGroupTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.secondary)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func scheduleRow(_ event: Event) -> some View {
        let isAuto = FeedRuleMetadata.isAutoFeederEvent(event, pet: pet)
        let todayReminders = event.reminders.filter { Calendar.current.isDateInToday($0.scheduledAt) }
        let reminder = todayReminders.sorted { $0.scheduledAt < $1.scheduledAt }.first
        let isDone = todayReminders.contains { $0.isCompleted }
        let isOverdue = reminder?.isFailed == true || (reminder?.isPending == true && (reminder?.scheduledAt ?? event.startDate) < Date())
        let statusText = isDone
            ? l.tr(zh: "已完成", en: "Done", de: "Erledigt")
            : (isOverdue
                ? l.tr(zh: "已逾期", en: "Overdue", de: "Überfällig")
                : (isAuto ? l.tr(zh: "自动写入", en: "Auto log", de: "Auto") : (reminder != nil ? l.tr(zh: "待完成", en: "Pending", de: "Offen") : l.tr(zh: "未来", en: "Upcoming", de: "Später"))))
        let statusColor: Color = isAuto ? .goTeal : (isDone ? .goTeal : (isOverdue ? .goRed : (reminder != nil ? themeColor : Color.secondary)))
        return HStack(spacing: 12) {
            Image(systemName: isAuto ? FeedRuleKind.autoFeeder.iconName : FeedRuleKind.manualReminder.iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(statusColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduleDisplayTitle(for: event))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone)
                HStack(spacing: 6) {
                    Text((reminder?.scheduledAt ?? event.startDate), style: .time)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(statusText)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }
            }
            Spacer()
            if isAuto {
                Text(formattedFoodWeight(FeedRuleMetadata.amountGrams(from: event)))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.goTeal.opacity(0.12), in: Capsule())
            } else if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(themeColor)
            } else {
                Button {
                    completeScheduledFeed(event: event)
                } label: {
                    Text(l.tr(zh: "打卡", en: "Done", de: "Fertig"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {
                schedulePendingDelete = event
                showingDeleteScheduleConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private func addScheduleForm(allowsKindPicker: Bool = false) -> some View {
        VStack(spacing: 12) {
            if allowsKindPicker {
                HStack(spacing: 8) {
                    ruleKindChip(.manualReminder, title: "手动提醒")
                    ruleKindChip(.autoFeeder, title: "自动喂食器")
                }
            } else {
                HStack(spacing: 8) {
                    Label(newRuleKind == .manualReminder ? "手动提醒" : "自动喂食器", systemImage: newRuleKind.iconName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(newRuleKind == .manualReminder ? themeColor : Color.goTeal)
                    Spacer()
                }
            }
            HStack(spacing: 12) {
                DatePicker("时间", selection: $newScheduleTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(themeColor)
                GoDraftTextField(
                    "克数",
                    text: $newScheduleAmount,
                    keyboardType: .decimalPad,
                    capitalization: .never
                )
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                Text("g").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    showAddSchedule = false
                    newScheduleAmount = ""
                } label: {
                    Text("取消")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                Button { saveSchedule() } label: {
                    Text("添加")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text(newRuleKind == .manualReminder
                 ? "到点提醒，用户点完成后才写入主粮喂食记录。"
                 : "打开 app 或喂食页时，自动补齐已到点的主粮喂食记录。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private func ruleKindChip(_ kind: FeedRuleKind, title: String) -> some View {
        let isSelected = newRuleKind == kind
        return Button {
            newRuleKind = kind
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: kind.iconName)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .goSelectableSurface(isSelected: isSelected, tint: themeColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stock Tab
    private var stockTab: some View {
        VStack(spacing: 16) {
            foodStockStatusCard
            stockSection
            calculatorSection
        }
    }

    private var foodStockStatusCard: some View {
        let status = currentFoodRunOutStatus
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(status.tint.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(status.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.foodBrand.isEmpty ? l.tr(zh: "未设置粮食品牌", en: "No food brand", de: "Keine Futtermarke") : pet.foodBrand)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(status.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(status.value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(status.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                stockStatusPill(
                    title: l.tr(zh: "按真实消耗", en: "Actual use", de: "Echter Verbrauch"),
                    icon: "scalemass.fill",
                    tint: themeColor
                )
                stockStatusPill(
                    title: pet.foodReminderEnabled ? l.tr(zh: "已开提醒", en: "Reminder on", de: "Erinnerung an") : l.tr(zh: "未开提醒", en: "No reminder", de: "Keine Erinnerung"),
                    icon: pet.foodReminderEnabled ? "bell.badge.fill" : "bell.slash.fill",
                    tint: pet.foodReminderEnabled ? .goTeal : .secondary
                )
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func stockStatusPill(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
    }

    // MARK: - Stock Mode Picker (casual vs precise)
    private var stockModePicker: some View {
        VStack(spacing: 10) {
            HStack {
                Text("粮仓管理")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4)).tracking(3)
                Spacer()
            }
            Picker("追踪模式", selection: $selectedStockMode) {
                ForEach(FoodTrackingMode.allCases, id: \.self) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedStockMode) { _, newMode in
                pet.foodTrackingMode = newMode
                modelContext.safeSave()
                rebuildFoodStockReminder()
            }
            Text(selectedStockMode == .casual
                 ? "忽略每日喂食量，用开包日期和预估时长计算断粮日 🐾"
                 : "按实际喂食克数扣减库存，实时计算剩余天数 📊")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Casual Section
    private var casualSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("粮食估算", systemImage: "leaf.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(themeColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("开包日期")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                DatePicker("", selection: $casualOpenDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(themeColor)
                    .onChange(of: casualOpenDate) { _, d in
                        pet.casualOpenDate = d
                        modelContext.safeSave()
                        rebuildFoodStockReminder()
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("预估能吃多久")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(durationOptions, id: \.1) { label, days in
                            Button {
                                casualDurationDays = days
                                pet.casualDurationDays = days
                                modelContext.safeSave()
                                rebuildFoodStockReminder()
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(casualDurationDays == days ? Color.arkInk : .primary)
                                    .padding(.horizontal, 16).padding(.vertical, 9)
                                    .background(casualDurationDays == days ? themeColor : .clear, in: Capsule())
                                    .goSelectableSurface(isSelected: casualDurationDays == days, tint: themeColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            GoDashedDivider()
            if hasSavedCasualStockInfo {
                casualStockSummary
            }
            stockEditForm(includeDailyPortion: false)
            foodReminderSection
            foodUsageRecordSection

            GoDashedDivider()
            if let runOut = pet.casualEstimatedRunOutDate {
                let remaining = pet.casualRemainingDays ?? 0
                let accent: Color = remaining <= 7 ? .goRed : remaining <= 14 ? .goYellow : themeColor
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(remaining > 0 ? "大概还能吃到 \(runOut, format: .dateTime.month().day())" : "粮食快断啦，该补货了！")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                        Text(remaining > 0 ? "约剩 \(remaining) 天" : "请尽快补充粮食 🚨")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(12)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("设置开包日期和预估时长，即可查看耗尽提醒 ✨")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Stock Section (precise)
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("当前主粮", systemImage: "shippingbox.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goOrange)
                Spacer()
                Button { withAnimation { editingStock.toggle() } } label: {
                    Text(editingStock ? "完成" : "编辑")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(themeColor.opacity(0.12), in: Capsule())
                }
            }

            if editingStock {
                stockEditForm(includeDailyPortion: true)
            } else {
                stockReadOnlyView
            }
            foodReminderSection
            foodUsageRecordSection
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var casualStockSummary: some View {
        HStack(spacing: 0) {
            stockStatCell(
                label: "开包日期",
                value: pet.casualOpenDate.map { $0.formatted(.dateTime.month().day()) } ?? "--",
                accent: themeColor
            )
            Divider().frame(height: 40)
            stockStatCell(label: "预估时长", value: "\(pet.casualDurationDays)天", accent: .goYellow)
            Divider().frame(height: 40)
            stockStatCell(
                label: "品牌",
                value: pet.foodBrand.isEmpty ? "未设置" : pet.foodBrand,
                accent: .goOrange
            )
        }
        .padding(.vertical, 10)
        .goGlassBackground(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func stockEditForm(includeDailyPortion: Bool) -> some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("粮食品牌")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                Picker("品牌", selection: $selectedBrand) {
                    ForEach(knownFoodBrands, id: \.self) { brand in
                        Text(brand).tag(brand)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.goOrange)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .goGlassBackground(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: selectedBrand) { _, _ in
                    dismissFeedKeyboard()
                }
                if selectedBrand == "自定义品牌" {
                    GoDraftTextField(
                        "输入自定义品牌名",
                        text: $customBrandInput,
                        capitalization: .words
                    )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeColor)
                    .frame(width: 20)
                Text("开始日期")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 90, alignment: .leading)
                Spacer()
                DatePicker("", selection: $casualOpenDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(themeColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .goGlassBackground(RoundedRectangle(cornerRadius: 12, style: .continuous))

            stockWeightInputRow()
            if includeDailyPortion {
                stockInputRow(icon: "fork.knife", label: "默认每餐(g)", color: .goYellow, placeholder: pet.dailyPortionGrams > 0 ? String(format: "%.0f", pet.dailyPortionGrams) : "50", text: $dailyGramsInput)
            }
            stockInputRow(icon: "\(AppCurrency.systemIconName).fill", label: "购买价格(\(AppCurrency.symbol))", color: themeColor, placeholder: "选填", text: $stockPriceInput)

            if !stockPriceInput.isEmpty, let _ = Double(stockPriceInput.replacingOccurrences(of: ",", with: ".")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("支付人")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allHumans) { human in
                                Button { stockPayerId = human.id.uuidString } label: {
                                    HStack(spacing: 5) {
                                        Text(human.avatarEmoji).font(.system(size: 14))
                                        Text(human.name)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(stockPayerId == human.id.uuidString ? Color.arkInk : .primary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(stockPayerId == human.id.uuidString ? themeColor : .clear, in: Capsule())
                                    .goSelectableSurface(isSelected: stockPayerId == human.id.uuidString, tint: themeColor, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Button { saveStockAfterKeyboardDismiss() } label: {
                Text("保存当前主粮")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(themeColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var stockReadOnlyView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                stockStatCell(label: "品牌", value: pet.foodBrand.isEmpty ? "未设置" : pet.foodBrand, accent: .goOrange)
                Divider().frame(height: 40)
                stockStatCell(label: "剩余天数", value: stockSnapshot.remainingDays > 0 ? "\(stockSnapshot.remainingDays)天" : "--",
                              accent: stockSnapshot.remainingDays <= 7 && stockSnapshot.remainingDays > 0 ? .goRed : .primary)
                Divider().frame(height: 40)
                stockStatCell(label: "已用主粮", value: stockSnapshot.consumedGrams > 0 ? formattedFoodWeight(stockSnapshot.consumedGrams) : "--", accent: .goYellow)
            }
            .padding(.vertical, 10)
            .goGlassBackground(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if stockSnapshot.totalGrams > 0 {
                VStack(spacing: 4) {
                    HStack {
                    Text("剩余 \(formattedFoodWeight(stockSnapshot.remainingGrams)) / 共 \(formattedFoodWeight(stockSnapshot.totalGrams))")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.primary.opacity(0.5))
                        Spacer()
                        if let runOut = stockSnapshot.runOutDate {
                            Text("预计 \(runOut, format: .dateTime.month().day()) 断粮")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(stockSnapshot.remainingDays <= 7 ? Color.goRed : .primary.opacity(0.4))
                        }
                    }
                    Text(stockEstimateExplanation)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ProgressView(value: stockSnapshot.totalGrams > 0 ? min(1, stockSnapshot.remainingGrams / stockSnapshot.totalGrams) : 0)
                        .tint(stockSnapshot.remainingDays <= 7 ? Color.goRed : Color.goTeal)
                        .scaleEffect(y: 1.4)
                }
            }
        }
    }

    private var foodReminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { pet.foodReminderEnabled },
                set: { enabled in
                    pet.foodReminderEnabled = enabled
                    modelContext.safeSave()
                    rebuildFoodStockReminder()
                }
            )) {
                Label("断粮提醒", systemImage: "bell.badge.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .tint(themeColor)

            if pet.foodReminderEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(foodReminderAdvanceOptions, id: \.self) { days in
                            Button {
                                pet.foodReminderAdvanceDays = days
                                modelContext.safeSave()
                                rebuildFoodStockReminder()
                            } label: {
                                Text("提前 \(days) 天")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(pet.foodReminderAdvanceDays == days ? Color.arkInk : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(pet.foodReminderAdvanceDays == days ? themeColor : .clear, in: Capsule())
                                    .goSelectableSurface(isSelected: pet.foodReminderAdvanceDays == days, tint: themeColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let date = currentFoodReminderDate {
                    Text(date > Date()
                         ? "将在 \(date, format: .dateTime.month().day().hour().minute()) 提醒补粮"
                         : "提醒日期已过，请调整开包信息或提前天数")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(date > Date() ? .secondary : Color.goRed)
                } else {
                    Text("设置断粮日期后才能创建提醒")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var foodUsageRecordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showingFoodUsageRecords.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Label("用粮记录", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(sortedFoodRecords.isEmpty ? "暂无" : "\(sortedFoodRecords.count)条")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: showingFoodUsageRecords ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if let latest = sortedFoodRecords.first, !showingFoodUsageRecords {
                foodUsageRecordRow(latest, isLatest: true)
                    .transition(.opacity)
            }

            if showingFoodUsageRecords {
                if sortedFoodRecords.isEmpty {
                    Text("保存一次开包或库存信息后，这里会显示所有历史用粮记录。")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(sortedFoodRecords) { record in
                            foodUsageRecordRow(record, isLatest: record.id == sortedFoodRecords.first?.id)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func foodUsageRecordRow(_ record: PetFoodRecord, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(record.brand.isEmpty ? "未命名粮食" : record.brand)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if isLatest {
                    Text("当前")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeColor, in: Capsule())
                }
                Spacer()
                Text(record.startDate, format: .dateTime.year().month().day())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Button {
                    beginEditingFoodRecord(record)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(themeColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                Button {
                    foodRecordPendingDelete = record
                    showingDeleteFoodRecordConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.goRed.opacity(0.78))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                if record.dailyGrams > 0 {
                    Label("\(formattedFoodWeight(record.dailyGrams))/天", systemImage: "fork.knife")
                }
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)

            if editingFoodRecord?.id == record.id {
                foodRecordEditForm(record)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }

    private func foodRecordEditForm(_ record: PetFoodRecord) -> some View {
        VStack(spacing: 10) {
            GoDraftTextField(
                "粮食品牌",
                text: $editFoodRecordBrand,
                capitalization: .words
            )
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                DatePicker("开始日期", selection: $editFoodRecordStartDate, displayedComponents: .date)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .labelsHidden()
                    .tint(themeColor)
                GoDraftTextField(
                    "g/天",
                    text: $editFoodRecordDailyGrams,
                    keyboardType: .decimalPad,
                    capitalization: .never
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
                .frame(width: 76)
                Text("g/天")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))

            GoDraftTextField(
                "备注",
                text: $editFoodRecordNotes,
                capitalization: .sentences
            )
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    editingFoodRecord = nil
                } label: {
                    Text("取消")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    saveFoodRecordEdit(record)
                } label: {
                    Text("保存")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func feedLogEditForm(_ log: PetCareLog) -> some View {
        let badge = feedLogBadge(for: log)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                DatePicker("时间", selection: $editFeedLogDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(themeColor)
                GoDraftTextField(
                    "克数",
                    text: $editFeedLogGrams,
                    keyboardType: .decimalPad,
                    capitalization: .never
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
                .frame(width: 76)
                Text("g")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(badge.tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    editingFeedLog = nil
                } label: {
                    Text("取消")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    saveFeedLogEdit(log)
                } label: {
                    Text("保存")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(badge.tint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(badge.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Calculator
    private var calculatorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { showingCalculator.toggle() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(themeColor.opacity(0.2)).frame(width: 32, height: 32)
                        Image(systemName: "function")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeColor)
                    }
                    Text("推荐喂食量计算器")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showingCalculator ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if showingCalculator {
                Divider().opacity(0.1).padding(.horizontal, 14)
                calculatorBody
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear {
                        if let latest = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                            calcWeightKg = String(format: "%.1f", latest.weightInKg)
                        }
                        if pet.isNeutered { calcLifeStage = 3 }
                    }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showingCalculator)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var calculatorBody: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Text("当前体重")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    GoDraftTextField(
                        "0.0",
                        text: $calcWeightKg,
                        keyboardType: .decimalPad,
                        capitalization: .never
                    )
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("生命阶段")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lifeStageLabels.indices, id: \.self) { i in
                            Button { calcLifeStage = i } label: {
                                Text(lifeStageLabels[i])
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(calcLifeStage == i ? Color.arkInk : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(calcLifeStage == i ? themeColor : Color.primary.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let result = rerResult {
                VStack(spacing: 8) {
                    Text(String(format: "%.0f–%.0f", result.low, result.high))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(themeColor)
                    Text("g / 天（干粮参考）")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                Text("基于 RER = 70 × 体重^0.75 × \(String(format: "%.1f", lifeStageFactors[calcLifeStage])) 系数，干粮以 3500 kcal/kg 换算，仅供参考。")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
            } else {
                Text("输入体重后即可得到推荐范围")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func feedLogBadge(for log: PetCareLog) -> (title: String, tint: Color, icon: String) {
        switch FeedLogMetadata.source(for: log) ?? .manualMain {
        case .manualMain:
            return (l.tr(zh: "手动", en: "Manual", de: "Manuell"), themeColor, "hand.tap.fill")
        case .manualReminder:
            return (l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"), Color.goTeal, "bell.badge.fill")
        case .autoMain:
            return (l.tr(zh: "自动", en: "Auto", de: "Auto"), Color.goTeal, FeedRuleKind.autoFeeder.iconName)
        case .treat:
            return (l.tr(zh: "零食", en: "Treat", de: "Snack"), Color.goYellow, "birthday.cake.fill")
        }
    }

    private func feedLogDisplayGrams(for log: PetCareLog) -> Double {
        FeedLogMetadata.isMainFoodLog(log)
            ? FeedStockCalculator.effectiveMainFoodAmount(for: log, pet: pet)
            : max(0, log.amountGrams)
    }

    // MARK: - Today's Log List
    private var todayLogList: some View {
        let logs = feedTodayState.allTodayLogs
        return VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "今日喂食记录", en: "Today records", de: "Heutige Einträge"))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if logs.isEmpty {
                Text(l.tr(zh: "今天还没有喂食记录", en: "No feeding records today", de: "Heute keine Fütterungseinträge"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(logs) { log in
                    let badge = feedLogBadge(for: log)
                    let grams = feedLogDisplayGrams(for: log)
                    VStack(spacing: 6) {
                        HStack {
                            Label(badge.title, systemImage: badge.icon)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(badge.tint.opacity(0.85), in: Capsule())
                            Text(log.date, style: .time)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.6))
                            if grams > 0 {
                                Text(formattedFoodWeight(grams))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(badge.tint)
                            }
                            Spacer()
                            Button {
                                beginEditingFeedLog(log)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(themeColor)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            Button {
                                if editingFeedLog?.id == log.id {
                                    editingFeedLog = nil
                                }
                                modelContext.delete(log)
                                modelContext.safeSave()
                                rebuildFoodStockReminder()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.goRed.opacity(0.78))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                        }

                        if editingFeedLog?.id == log.id {
                            feedLogEditForm(log)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
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

    private func stockStatCell(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private func stockWeightInputRow() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 20)
                Text("总量")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 90, alignment: .leading)
                GoDraftTextField(
                    stockWeightUnit.placeholder,
                    text: $stockKgInput,
                    keyboardType: .decimalPad,
                    capitalization: .never
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                Text(stockWeightUnit.label)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 24, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Spacer()
                ForEach(FoodWeightUnit.allCases, id: \.rawValue) { unit in
                    let isSelected = stockWeightUnit == unit
                    Button {
                        changeStockWeightUnit(to: unit)
                    } label: {
                        Text(unit.label)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? Color.arkInk : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .goSelectableSurface(isSelected: isSelected, tint: Color.goTeal, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .goGlassBackground(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stockInputRow(icon: String, label: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(color).frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary.opacity(0.7))
                .frame(width: 90, alignment: .leading)
            GoDraftTextField(
                placeholder,
                text: text,
                keyboardType: .decimalPad,
                capitalization: .never
            )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .goGlassBackground(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var todayFeedHeadline: String {
        let state = feedTodayState
        if state.hasOverduePlan {
            return l.tr(zh: "有一餐已逾期", en: "A meal is overdue", de: "Eine Mahlzeit ist überfällig")
        }
        if let next = state.nextPendingReminder {
            return l.tr(
                zh: "下一餐 \(next.scheduledAt.formatted(date: .omitted, time: .shortened))",
                en: "Next at \(next.scheduledAt.formatted(date: .omitted, time: .shortened))",
                de: "Nächste um \(next.scheduledAt.formatted(date: .omitted, time: .shortened))"
            )
        }
        if state.isComplete {
            return l.tr(zh: "今日喂食已完成", en: "Feeding done today", de: "Fütterung heute erledigt")
        }
        let left = max(0, state.targetCount - state.completedCount)
        return l.tr(zh: "还差 \(left) 餐", en: "\(left) meals left", de: "\(left) Mahlz. offen")
    }

    private var todayFeedSubtitle: String {
        let state = feedTodayState
        let mainGrams = state.todayMainFoodGrams > 0 ? formattedFoodWeight(state.todayMainFoodGrams) : "--"
        let treatGrams = state.todayTreatGrams > 0 ? formattedFoodWeight(state.todayTreatGrams) : "--"
        if state.hasTodayPlan {
            return l.tr(
                zh: "按手动提醒判断完成：\(state.completedCount)/\(state.targetCount)，主粮 \(mainGrams) · 零食 \(treatGrams)",
                en: "Using manual reminders: \(state.completedCount)/\(state.targetCount), main \(mainGrams) · treats \(treatGrams)",
                de: "Manuelle Erinnerungen: \(state.completedCount)/\(state.targetCount), Hauptfutter \(mainGrams) · Snacks \(treatGrams)"
            )
        }
        return l.tr(
            zh: "按每日目标餐数判断，主粮 \(mainGrams) · 零食 \(treatGrams)",
            en: "Using daily meal goal, main \(mainGrams) · treats \(treatGrams)",
            de: "Tagesziel zählt, Hauptfutter \(mainGrams) · Snacks \(treatGrams)"
        )
    }

    private var quickFeedGramOptions: [Double] {
        var values: [Double] = []
        func append(_ value: Double) {
            let rounded = value.rounded()
            guard rounded > 0, !values.contains(where: { Int($0) == Int(rounded) }) else { return }
            values.append(rounded)
        }

        append(pet.dailyPortionGrams)
        if let event = feedTodayState.nextPendingReminder?.event {
            append(parseScheduleGrams(from: event))
        }
        feedTodayState.todayPlanReminders
            .compactMap(\.event)
            .forEach { append(parseScheduleGrams(from: $0)) }
        pet.careLogs
            .filter { $0.careType == .feeding && $0.amountGrams > 0 && FeedLogMetadata.isMainFoodLog($0) }
            .sorted { $0.date > $1.date }
            .prefix(8)
            .forEach { append($0.amountGrams) }
        return Array(values.prefix(5))
    }

    private func isSelectedQuickAmount(_ grams: Double) -> Bool {
        guard let selected = Double(portionText.replacingOccurrences(of: ",", with: ".")) else { return false }
        return Int(selected.rounded()) == Int(grams.rounded())
    }

    private var stockWeightInputGrams: Double? {
        guard let value = Double(stockKgInput.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch stockWeightUnit {
        case .grams:
            return value
        case .kilograms:
            return value * 1000
        }
    }

    private func changeStockWeightUnit(to unit: FoodWeightUnit) {
        guard stockWeightUnit != unit else { return }
        let currentGrams = stockWeightInputGrams ?? (pet.restockWeight > 0 ? pet.restockWeight * 1000 : 0)
        stockWeightUnit = unit
        if currentGrams > 0 {
            stockKgInput = formattedStockWeightInput(totalGrams: currentGrams, unit: unit)
        } else {
            stockKgInput = ""
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func formattedStockWeightInput(totalGrams: Double, unit: FoodWeightUnit) -> String {
        let value = unit == .kilograms ? totalGrams / 1000 : totalGrams
        if abs(value.rounded() - value) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: unit == .kilograms ? "%.2f" : "%.0f", value)
    }

    private func formattedFoodWeight(_ grams: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(grams)
    }

    private var currentFoodRunOutStatus: (value: String, message: String, tint: Color) {
        guard stockSnapshot.totalGrams > 0 else {
            return (
                "--",
                l.tr(zh: "补粮后显示剩余天数", en: "Restock to estimate days left", de: "Nachfüllen für Resttage"),
                Color.secondary
            )
        }
        let days = stockSnapshot.remainingDays
        let tint: Color = days <= 3 ? .goRed : (days <= 7 ? .goYellow : .goTeal)
        let message: String
        if let runOut = stockSnapshot.runOutDate {
            message = l.tr(
                zh: "预计 \(runOut.formatted(.dateTime.month().day())) 断粮 · 剩 \(formattedFoodWeight(stockSnapshot.remainingGrams))",
                en: "Runs out around \(runOut.formatted(.dateTime.month().day())) · \(formattedFoodWeight(stockSnapshot.remainingGrams)) left",
                de: "Reicht bis ca. \(runOut.formatted(.dateTime.month().day())) · \(formattedFoodWeight(stockSnapshot.remainingGrams)) übrig"
            )
        } else {
            message = l.tr(zh: "记录主粮或设置自动喂食器后，会估算断粮日", en: "Log main food or add auto rules to estimate run-out", de: "Hauptfutter oder Auto-Regeln erfassen, um den Vorrat zu schätzen")
        }
        return (days > 0 ? "\(days)天" : l.tr(zh: "断粮", en: "Empty", de: "Leer"), message, tint)
    }

    private func plannedReminderRow(_ reminder: Reminder) -> some View {
        let isDone = reminder.isCompleted
        let isOverdue = reminder.isFailed || (reminder.isPending && reminder.scheduledAt < Date())
        let tint: Color = isDone ? .goTeal : (isOverdue ? .goRed : themeColor)
        let status = isDone ? l.tr(zh: "已完成", en: "Done", de: "Erledigt") : (isOverdue ? l.tr(zh: "已逾期", en: "Overdue", de: "Überfällig") : l.tr(zh: "待完成", en: "Pending", de: "Offen"))
        let grams = reminder.event.map { parseScheduleGrams(from: $0) } ?? 0

        return HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(grams > 0 ? "\(mealName(for: reminder.scheduledAt)) \(formattedFoodWeight(grams))" : mealName(for: reminder.scheduledAt))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(reminder.scheduledAt, style: .time)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
            if (reminder.isPending || reminder.isFailed), let event = reminder.event {
                Button { completeScheduledFeed(event: event) } label: {
                    Text(l.tr(zh: "打卡", en: "Done", de: "Fertig"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
    }

    // MARK: - Actions

    private func commitSmartFeed() {
        if let event = feedTodayState.nextPendingReminder?.event {
            completeScheduledFeed(event: event)
        } else {
            commitManualFeed()
        }
    }

    private func beginEditingFeedLog(_ log: PetCareLog) {
        editingFeedLog = log
        editFeedLogDate = log.date
        let grams = feedLogDisplayGrams(for: log)
        editFeedLogGrams = grams > 0 ? String(format: "%.0f", grams) : ""
        dismissFeedKeyboard()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func saveFeedLogEdit(_ log: PetCareLog) {
        log.date = editFeedLogDate
        if let grams = Double(editFeedLogGrams.replacingOccurrences(of: ",", with: ".")) {
            log.amountGrams = max(0, grams)
        }
        editingFeedLog = nil
        modelContext.safeSave()
        rebuildFoodStockReminder()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func beginEditingFoodRecord(_ record: PetFoodRecord) {
        editingFoodRecord = record
        editFoodRecordBrand = record.brand
        editFoodRecordDailyGrams = record.dailyGrams > 0 ? String(format: "%.0f", record.dailyGrams) : ""
        editFoodRecordNotes = record.notes
        editFoodRecordStartDate = record.startDate
        dismissFeedKeyboard()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func saveFoodRecordEdit(_ record: PetFoodRecord) {
        record.brand = editFoodRecordBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        record.startDate = editFoodRecordStartDate
        if let grams = Double(editFoodRecordDailyGrams.replacingOccurrences(of: ",", with: ".")) {
            record.dailyGrams = max(0, grams)
        }
        record.notes = editFoodRecordNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        if record.id == sortedFoodRecords.first?.id {
            if !record.brand.isEmpty { pet.foodBrand = record.brand }
            if record.dailyGrams > 0 { pet.dailyPortionGrams = record.dailyGrams }
            pet.restockDate = record.startDate
            casualOpenDate = record.startDate
            selectedBrand = knownFoodBrands.contains(record.brand) ? record.brand : (record.brand.isEmpty ? selectedBrand : "自定义品牌")
            customBrandInput = record.brand
            if record.dailyGrams > 0 {
                dailyGramsInput = String(format: "%.0f", record.dailyGrams)
            }
        }

        editingFoodRecord = nil
        modelContext.safeSave()
        rebuildFoodStockReminder()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteFoodRecord(_ record: PetFoodRecord) {
        if editingFoodRecord?.id == record.id {
            editingFoodRecord = nil
        }
        modelContext.delete(record)
        modelContext.safeSave()
        rebuildFoodStockReminder()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteSchedule(_ event: Event) {
        for reminder in event.reminders {
            NotificationManager.shared.cancel(notificationId: reminder.notificationId)
            modelContext.delete(reminder)
        }
        modelContext.delete(event)
        modelContext.safeSave()
        rebuildFoodStockReminder()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func commitManualFeed() {
        let grams = Double(portionText.replacingOccurrences(of: ",", with: ".")) ?? pet.dailyPortionGrams
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }

        // 质量判定：精准克数（用户显式输入且非默认）视为 precise；暂未支持备注/拍照
        let isPrecise = !portionText.isEmpty && Double(portionText.replacingOccurrences(of: ",", with: ".")) != nil
        let quality = QuestManager.QualityBonus.compose(
            precise: isPrecise,
            hasNote: false,
            hasPhoto: false
        )

        let performFeed = {
            _ = CareEventService.recordManualFeed(
                pet: self.pet,
                amountGrams: grams,
                context: self.modelContext,
                executorId: currentUserId,
                quality: quality
            )
            self.rebuildFoodStockReminder()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.checkOverdoseManualTotal()
        }
        
        if let warning = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .feeding, thresholdMinutes: 120, currentUserId: currentUserId, in: allHumans) {
            antiRepeatTitle = "重复喂食提醒"
            antiRepeatMessage = "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name) ，确定要再喂一次吗？"
            pendingRepeatAction = performFeed
            showingAntiRepeatAlert = true
        } else {
            performFeed()
        }
    }

    private func commitTreatFeed() {
        let grams = Double(treatText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard grams > 0 else { return }
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        _ = CareEventService.recordTreatFeed(
            pet: pet,
            amountGrams: grams,
            context: modelContext,
            executorId: currentUserId
        )
        treatText = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func completeScheduledFeed(event: Event) {
        guard FeedRuleMetadata.isManualReminderEvent(event, pet: pet) else { return }
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        // 按计划喂食 = 完整精准模式
        let quality = QuestManager.QualityBonus.precise
        let performFeed = {
            guard let reminder = event.reminders.first(where: { Calendar.current.isDateInToday($0.scheduledAt) && ($0.isPending || $0.isFailed) })
                    ?? event.reminders.first(where: { Calendar.current.isDateInToday($0.scheduledAt) }) else { return }
            _ = CareEventService.completePlannedFeed(
                pet: self.pet,
                reminder: reminder,
                context: self.modelContext,
                quality: quality,
                executorId: currentUserId
            )
            self.rebuildFoodStockReminder()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.checkOverdoseManualTotal()
        }
        
        if let warning = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .feeding, thresholdMinutes: 120, currentUserId: currentUserId, in: allHumans) {
            antiRepeatTitle = "重复喂食提醒"
            antiRepeatMessage = "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name) ，确定要再按计划喂一次吗？"
            pendingRepeatAction = performFeed
            showingAntiRepeatAlert = true
        } else {
            performFeed()
        }
    }

    private func saveSchedule() {
        let amount = Double(newScheduleAmount.replacingOccurrences(of: ",", with: "."))
        let grams = amount ?? pet.dailyPortionGrams
        let title = FeedRuleMetadata.title(kind: newRuleKind, date: newScheduleTime, amountGrams: grams)
        let event = Event(
            title: title, startDate: newScheduleTime,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: newRuleKind == .autoFeeder ? FeedRuleMetadata.autoFeederEntityType : EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        modelContext.insert(event)
        if newRuleKind == .manualReminder {
            let reminder = Reminder(event: event, scheduledAt: newScheduleTime)
            modelContext.insert(reminder)
            modelContext.safeSave()
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: modelContext, source: .detail)
            }
        } else {
            modelContext.safeSave()
            let inserted = FeedAutoLogMaterializer.materializeDueLogs(
                pet: pet,
                allEvents: allEvents + [event],
                context: modelContext
            )
            if inserted > 0 {
                rebuildFoodStockReminder()
            }
        }
        showAddSchedule = false
        newScheduleAmount = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func materializeAutoFeedLogs() {
        let inserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: allEvents,
            context: modelContext
        )
        if inserted > 0 {
            rebuildFoodStockReminder()
        }
    }

    private func rebuildFoodStockReminder() {
        for event in foodStockReminderEvents {
            for reminder in event.reminders {
                NotificationManager.shared.cancel(notificationId: reminder.notificationId)
                modelContext.delete(reminder)
            }
            modelContext.delete(event)
        }

        guard pet.foodReminderEnabled,
              let reminderDate = currentFoodReminderDate,
              reminderDate > Date() else {
            modelContext.safeSave()
            return
        }

        let event = Event(
            title: "\(pet.name) 快要断粮了，记得补充粮仓",
            startDate: reminderDate,
            isAllDay: false,
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: "pet_food_stock",
            relatedEntityId: pet.id.uuidString
        )
        modelContext.insert(event)
        let reminder = Reminder(event: event, scheduledAt: reminderDate)
        modelContext.insert(reminder)
        modelContext.safeSave()
        Task { @MainActor in
            await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: modelContext, source: .detail)
        }
    }

    private func saveStock() {
        let finalBrand = selectedBrand == "自定义品牌" ? customBrandInput : selectedBrand
        pet.foodTrackingMode = .precise
        pet.casualOpenDate = casualOpenDate
        if !finalBrand.isEmpty { pet.foodBrand = finalBrand }
        if let grams = stockWeightInputGrams {
            pet.restockWeight = max(0, grams) / 1000
        }
        if let g = Double(dailyGramsInput.replacingOccurrences(of: ",", with: ".")) { pet.dailyPortionGrams = g }
        pet.restockDate = casualOpenDate
        if let price = Double(stockPriceInput.replacingOccurrences(of: ",", with: ".")), price > 0 {
            let payerId = stockPayerId.isEmpty
                ? UserDefaults.standard.string(forKey: "currentActiveHumanId")
                : stockPayerId
            let brandNote = finalBrand.isEmpty ? "粮食" : finalBrand
            let expenseLog = PetExpenseLog(
                date: Date(), amount: price, category: .food,
                note: "购买 \(brandNote)", pet: pet, executorId: payerId
            )
            modelContext.insert(expenseLog)
        }
        insertFoodUsageRecord(brand: finalBrand)
        modelContext.safeSave()
        rebuildFoodStockReminder()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stockPriceInput = ""
        stockPayerId = ""
        withAnimation { editingStock = false }
    }

    private func saveStockAfterKeyboardDismiss() {
        dismissFeedKeyboard()
        DispatchQueue.main.async {
            saveStock()
        }
    }

    private func dismissFeedKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func insertFoodUsageRecord(brand: String) {
        let dailyGrams = Double(dailyGramsInput.replacingOccurrences(of: ",", with: ".")) ?? pet.dailyPortionGrams
        let startDate = pet.restockDate ?? casualOpenDate
        let record = PetFoodRecord(
            brand: brand.isEmpty ? pet.foodBrand : brand,
            dailyGrams: dailyGrams,
            startDate: startDate,
            pet: pet,
            executorId: stockPayerId.isEmpty ? UserDefaults.standard.string(forKey: "currentActiveHumanId") : stockPayerId
        )

        var noteParts: [String] = []
        noteParts.append("当前主粮")
        if let grams = stockWeightInputGrams, grams > 0 {
            noteParts.append(formattedFoodWeight(grams))
        }
        if let price = Double(stockPriceInput.replacingOccurrences(of: ",", with: ".")), price > 0 {
            noteParts.append(AppCurrency.format(price, fractionDigits: 0))
        }
        record.notes = noteParts.joined(separator: " · ")
        modelContext.insert(record)
    }

    /// 在插入并 save 后调用：只统计今日手动记录克数
    private func checkOverdoseManualTotal() {
        let newTotal = manualTodayFeedGrams
        if pet.dailyPortionGrams > 0 && newTotal > pet.dailyPortionGrams * 1.1 {
            triggerToast(success: false)
        } else if pet.dailyPortionGrams > 0 && newTotal >= pet.dailyPortionGrams {
            triggerToast(success: true)
        }
    }

    private func triggerToast(success: Bool) {
        overdoseIsSuccess = success
        toastTask?.cancel()
        withAnimation { showOverdoseToast = true }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { self.showOverdoseToast = false } }
        }
    }
}
