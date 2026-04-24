//
//  QuickFeedDetailSheet.swift
//  Ohana
//
//  喂食详情 Sheet — 手动/按计划 + 粮仓管理（佛系/精准） + 计算器 + 历史
//

import SwiftUI
import SwiftData
import Charts

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

    // Feed mode
    @State private var mode: FeedMode = .manual
    @State private var portionText = ""
    @State private var goalCount = 3
    @State private var newScheduleTime = Date()
    @State private var newScheduleAmount = ""
    @State private var showAddSchedule = false
    @State private var newScheduleTitle = "早餐"
    @State private var newScheduleGrams = ""

    // Stock tracking mode
    @State private var selectedStockMode: FoodTrackingMode = .casual
    @State private var casualOpenDate: Date = Date()
    @State private var casualDurationDays: Int = 30
    private let durationOptions: [(String, Int)] = [
        ("1个月", 30), ("2个月", 60), ("3个月", 90), ("半年", 180)
    ]

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
    @State private var dailyGramsInput: String = ""
    @State private var stockPriceInput: String = ""
    @State private var stockPayerId: String = ""

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

    enum FeedMode: String, CaseIterable {
        case manual = "手动记录"
        case planned = "按计划"
    }

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    /// 今日仅「手动记录」喂食（与按计划互斥统计）
    private var manualTodayFeedLogs: [PetCareLog] {
        pet.careLogs
            .filter {
                $0.type == CareType.feeding.rawValue
                    && Calendar.current.isDateInToday($0.date)
                    && $0.isManualFeedLogEntry
            }
            .sorted { $0.date > $1.date }
    }

    /// 今日仅「按计划」打卡产生的喂食记录
    private var plannedTodayFeedLogs: [PetCareLog] {
        pet.careLogs
            .filter {
                $0.type == CareType.feeding.rawValue
                    && Calendar.current.isDateInToday($0.date)
                    && $0.isPlannedFeedLogEntry
            }
            .sorted { $0.date > $1.date }
    }

    private var manualTodayFeedGrams: Double {
        manualTodayFeedLogs.reduce(0) { $0 + $1.amountGrams }
    }

    private var feedScheduleEvents: [Event] {
        allEvents.filter {
            ($0.relatedEntityType == EntityKind.pet.rawValue || $0.relatedEntityType == "pet") &&
            $0.relatedEntityId == pet.id.uuidString &&
            $0.eventType == EventType.foodChange.rawValue
        }
    }

    private var savedGoal: Int {
        let key = "feedGoal_\(pet.id.uuidString)"
        let v = UserDefaults.standard.integer(forKey: key)
        return v > 0 ? v : 3
    }

    private var last7FeedCounts: [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.careLogs.filter {
                $0.type == CareType.feeding.rawValue && cal.isDate($0.date, inSameDayAs: date)
            }.count
        }
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
                        feedModePicker
                        feedModeHint
                        if mode == .manual {
                            manualSection
                        } else {
                            plannedSection
                        }

                        stockModePicker
                        if selectedStockMode == .casual {
                            casualSection
                        } else {
                            stockSection
                        }

                        calculatorSection

                        todayLogList
                        historySection
                        removeQuickActionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
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
            }
        }
        .onAppear {
            mode = HomeFeedRecordMode.storedRaw(for: pet.id) == HomeFeedRecordMode.planned.rawValue ? .planned : .manual
            goalCount = savedGoal
            if pet.dailyPortionGrams > 0 {
                portionText = String(format: "%.0f", pet.dailyPortionGrams)
            }
            selectedStockMode = pet.foodTrackingMode
            casualOpenDate = pet.casualOpenDate ?? Date()
            if pet.casualDurationDays > 0 { casualDurationDays = pet.casualDurationDays }
            selectedBrand = knownFoodBrands.contains(pet.foodBrand) ? pet.foodBrand : (pet.foodBrand.isEmpty ? knownFoodBrands[0] : "自定义品牌")
            customBrandInput = pet.foodBrand
            if pet.restockWeight > 0 { stockKgInput = String(format: "%.1f", pet.restockWeight) }
            if pet.dailyPortionGrams > 0 { dailyGramsInput = String(format: "%.0f", pet.dailyPortionGrams) }
        }
        .onChange(of: mode) { _, newVal in
            HomeFeedRecordMode.set(pet.id, mode: newVal == .planned ? .planned : .manual)
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

    // MARK: - Feed Mode Picker
    private var feedModePicker: some View {
        HStack(spacing: 0) {
            ForEach(FeedMode.allCases, id: \.rawValue) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(mode == m ? Color.arkInk : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            mode == m ? themeColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var feedModeHint: some View {
        Text(mode == .manual
             ? "手动模式：圆环与「打卡喂食」只统计手动记录；首页喂食按钮按餐数目标打卡。"
             : "计划模式：在下方计划行打卡；首页红点仅提示计划待办，点击会完成对应一餐。")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Manual Mode
    private var manualSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.15), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: min(1, Double(manualTodayFeedLogs.count) / Double(goalCount)))
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(manualTodayFeedLogs.count)/\(goalCount)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("手动 · 今日")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(response: 0.4), value: manualTodayFeedLogs.count)
            }
            .padding(.vertical, 8)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("默认份量")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("克数", text: $portionText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        Text("g")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 48)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("每日目标")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Stepper(value: $goalCount, in: 1...10) {
                        Text("\(goalCount) 餐")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    .onChange(of: goalCount) { _, newVal in
                        UserDefaults.standard.set(newVal, forKey: "feedGoal_\(pet.id.uuidString)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button { commitManualFeed() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .bold))
                    Text("手动打卡喂食")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(themeColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// 从计划标题中解析克数（与计划打卡逻辑一致）
    private func parseScheduleGrams(from event: Event) -> Double {
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? 0
    }

    private var plannedSchedulesDailyTotalGrams: Double {
        feedScheduleEvents.reduce(0) { $0 + parseScheduleGrams(from: $1) }
    }

    // MARK: - Planned Mode
    private var plannedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("喂食计划")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button { showAddSchedule = true } label: {
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
                    Text("每日总喂食量约 \(Int(plannedSchedulesDailyTotalGrams))g")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if feedScheduleEvents.isEmpty {
                Text("还没有喂食计划\n点击 + 添加定时喂食")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(feedScheduleEvents) { event in
                    scheduleRow(event)
                }
            }

            if showAddSchedule {
                addScheduleForm
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scheduleRow(_ event: Event) -> some View {
        let todayReminders = event.reminders.filter { Calendar.current.isDateInToday($0.scheduledAt) }
        let isDone = todayReminders.contains { $0.isCompleted }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone)
                Text(event.startDate, style: .time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(themeColor)
            } else {
                Button {
                    completeScheduledFeed(event: event)
                } label: {
                    Text("打卡")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {
                for r in event.reminders {
                    NotificationManager.shared.cancel(notificationId: r.notificationId)
                    modelContext.delete(r)
                }
                modelContext.delete(event)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var addScheduleForm: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                DatePicker("时间", selection: $newScheduleTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(themeColor)
                TextField("克数", text: $newScheduleAmount)
                    .keyboardType(.decimalPad)
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
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
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
            }
            Text(selectedStockMode == .casual
                 ? "只记录大概吃多久，喂食打卡不扣克数 🐾"
                 : "精确追踪库存克数，动态计算剩余天数 📊")
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
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(casualDurationDays == days ? Color.arkInk : .primary)
                                    .padding(.horizontal, 16).padding(.vertical, 9)
                                    .background(casualDurationDays == days ? themeColor : .clear, in: Capsule())
                                    .glassEffect(casualDurationDays == days ? .regular.tint(themeColor.opacity(0.2)) : .regular, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Stock Section (precise)
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("粮食库存", systemImage: "shippingbox.fill")
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
                stockEditForm
            } else {
                stockReadOnlyView
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var stockEditForm: some View {
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
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if selectedBrand == "自定义品牌" {
                    TextField("输入自定义品牌名", text: $customBrandInput)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            stockInputRow(icon: "scalemass.fill", label: "规格(kg)", color: .goTeal, placeholder: pet.restockWeight > 0 ? String(format: "%.1f", pet.restockWeight) : "10.0", text: $stockKgInput)
            stockInputRow(icon: "fork.knife", label: "每日份量(g)", color: .goYellow, placeholder: pet.dailyPortionGrams > 0 ? String(format: "%.0f", pet.dailyPortionGrams) : "200", text: $dailyGramsInput)
            stockInputRow(icon: "yensign.circle.fill", label: "购买价格(¥)", color: themeColor, placeholder: "选填", text: $stockPriceInput)

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
                                    .glassEffect(stockPayerId == human.id.uuidString ? .regular.tint(themeColor.opacity(0.2)) : .regular, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Button { saveStock() } label: {
                Text("保存库存信息")
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
                stockStatCell(label: "剩余天数", value: pet.remainingFoodDays > 0 ? "\(pet.remainingFoodDays)天" : "--",
                              accent: pet.remainingFoodDays <= 7 && pet.remainingFoodDays > 0 ? .goRed : .primary)
                Divider().frame(height: 40)
                stockStatCell(label: "每日份量", value: pet.dailyPortionGrams > 0 ? "\(Int(pet.dailyPortionGrams))g" : "--", accent: .goYellow)
            }
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if pet.remainingFoodDays > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("剩余 \(Int(pet.remainingFoodGrams))g")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.primary.opacity(0.5))
                        Spacer()
                        if let runOut = pet.estimatedRunOutDate {
                            Text("预计 \(runOut, format: .dateTime.month().day()) 断粮")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(pet.remainingFoodDays <= 7 ? Color.goRed : .primary.opacity(0.4))
                        }
                    }
                    ProgressView(value: pet.remainingFoodPercent)
                        .tint(pet.remainingFoodDays <= 7 ? Color.goRed : Color.goTeal)
                        .scaleEffect(y: 1.4)
                }
            }
        }
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var calculatorBody: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Text("当前体重")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("0.0", text: $calcWeightKg)
                        .keyboardType(.decimalPad)
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

    // MARK: - Today's Log List（按当前模式只展示对应来源，避免混在一起）
    private var todayLogList: some View {
        let logs = mode == .manual ? manualTodayFeedLogs : plannedTodayFeedLogs
        let title = mode == .manual ? "今日手动记录" : "今日计划打卡"
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            if logs.isEmpty {
                Text(mode == .manual ? "暂无手动记录" : "今日尚未完成计划打卡")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(logs) { log in
                    HStack {
                        Text(mode == .planned ? "计划" : "手动")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(mode == .planned ? Color.goTeal.opacity(0.85) : themeColor.opacity(0.85), in: Capsule())
                        Text(log.date, style: .time)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                        if log.amountGrams > 0 {
                            Text("\(String(format: "%.0f", log.amountGrams))g")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor)
                        }
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

    // MARK: - History
    @ViewBuilder
    private var historySection: some View {
        let feedLogs = Array(pet.careLogs.filter { $0.type == CareType.feeding.rawValue }
            .sorted { $0.date > $1.date }.prefix(15))
        if !feedLogs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("喂食历史")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(themeColor.opacity(0.85)).tracking(2)

                let counts = last7FeedCounts
                if !counts.allSatisfy({ $0 == 0 }) {
                    MiniBarChart(values: counts.map { Double($0) }, labels: [], accentColor: themeColor)
                        .frame(height: 32)
                }

                ForEach(feedLogs) { log in
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeColor)
                        Text(log.isPlannedFeedLogEntry ? "计划" : "手动")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        Text(log.amountGrams > 0 ? "\(Int(log.amountGrams))g" : "快速打卡")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                        Spacer()
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 11)).foregroundStyle(.primary.opacity(0.4))
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func stockInputRow(icon: String, label: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(color).frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary.opacity(0.7))
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func commitManualFeed() {
        let grams = Double(portionText) ?? pet.dailyPortionGrams
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }

        // 质量判定：精准克数（用户显式输入且非默认）视为 precise；暂未支持备注/拍照
        let isPrecise = !portionText.isEmpty && Double(portionText) != nil
        let quality = QuestManager.QualityBonus.compose(
            precise: isPrecise,
            hasNote: false,
            hasPhoto: false
        )

        let performFeed = {
            let log = PetCareLog(
                date: Date(),
                type: .feeding,
                amountGrams: grams,
                note: PetCareLog.manualFeedNoteMarker,
                pet: self.pet,
                executorId: currentUserId
            )
            self.modelContext.insert(log)
            self.modelContext.safeSave()
            QuestManager.shared.recordFirstMeal()
            _ = QuestManager.shared.awardAction(type: .feed, pet: self.pet, context: self.modelContext, quality: quality)
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

    private func completeScheduledFeed(event: Event) {
        let currentUserId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        // 按计划喂食 = 完整精准模式
        let quality = QuestManager.QualityBonus.precise
        let performFeed = {
            let log = PetCareLog(
                date: Date(),
                type: .feeding,
                amountGrams: self.parseScheduleGrams(from: event),
                note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
                pet: self.pet,
                executorId: currentUserId
            )
            self.modelContext.insert(log)
            
            for reminder in event.reminders where Calendar.current.isDateInToday(reminder.scheduledAt) {
                reminder.statusEnum = .completed
                NotificationManager.shared.cancel(notificationId: reminder.notificationId)
            }
            self.modelContext.safeSave()
            QuestManager.shared.recordFirstMeal()
            _ = QuestManager.shared.awardAction(type: .feed, pet: self.pet, context: self.modelContext, quality: quality)
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
        let title = newScheduleGrams.isEmpty ? newScheduleTitle : "\(newScheduleTitle) \(newScheduleGrams)g"
        let event = Event(
            title: title, startDate: newScheduleTime,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        modelContext.insert(event)
        let reminder = Reminder(event: event, scheduledAt: newScheduleTime)
        modelContext.insert(reminder)
        modelContext.safeSave()
        NotificationManager.shared.schedule(reminder: reminder)
        showAddSchedule = false
        newScheduleAmount = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveStock() {
        let finalBrand = selectedBrand == "自定义品牌" ? customBrandInput : selectedBrand
        if !finalBrand.isEmpty { pet.foodBrand = finalBrand }
        if let kg = Double(stockKgInput.replacingOccurrences(of: ",", with: ".")) { pet.restockWeight = kg }
        if let g = Double(dailyGramsInput.replacingOccurrences(of: ",", with: ".")) { pet.dailyPortionGrams = g }
        pet.restockDate = Date()
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
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stockKgInput = ""
        dailyGramsInput = ""
        stockPriceInput = ""
        stockPayerId = ""
        withAnimation { editingStock = false }
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
