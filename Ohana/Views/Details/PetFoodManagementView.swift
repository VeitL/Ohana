//
//  PetFoodManagementView.swift
//  Ohana
//
//  饮食与排泄管理 — Phase 40 重构
//  - 品牌 Picker（内置中德主流品牌）
//  - 喂食默认克数 + 余粮联动扣除 + 超量拦截 Toast
//  - 喂水默认毫升设置
//  - 长按唤起 AddReminderSheet（自动预填）
//  - 整合噗噗概览入口
//

import SwiftUI
import SwiftData

// MARK: - 品牌数据
private let knownFoodBrands: [String] = [
    "Royal Canin 皇家", "Orijen 渴望", "Acana 爱肯拿", "Ziwi 巅峰",
    "Hill's 希尔斯", "Purina Pro Plan 冠能", "Josera", "Wolfsblut", "Animonda",
    "MAC's", "Myfoodie 麦富迪", "NetEase 严选", "自定义品牌"
]

// MARK: - 内嵌提醒 Sheet
private struct FoodReminderSheet: View {
    let pet: Pet
    let prefillTitle: String
    let prefillType: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var isAllDay: Bool = false
    @State private var hasStartTime: Bool = true
    @State private var hasEndTime: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var recurrenceDays: Int = 1

    private let recurrenceOptions: [(String, Int)] = [
        ("不重复", 0), ("每天", 1), ("每2天", 2), ("每周", 7), ("每月", 30)
    ]

    init(pet: Pet, prefillTitle: String, prefillType: String) {
        self.pet = pet
        self.prefillTitle = prefillTitle
        self.prefillType = prefillType
        _title = State(initialValue: prefillTitle)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.primary.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 标题行
                    HStack(spacing: 10) {
                        Text(prefillType == "喂食" ? "🍖" : "💧").font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加提醒")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("\(pet.name) · \(prefillType)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    // 提醒标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提醒标题")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        TextField("标题", text: $title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 24)
                    }

                    // 全天开关
                    HStack {
                        Label("全天", systemImage: "sun.max.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Toggle("", isOn: $isAllDay)
                            .tint(Color.goLime)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)

                    // 开始时间（可选）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("开始时间")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("", isOn: $hasStartTime)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }
                        .padding(.horizontal, 24)
                        if hasStartTime {
                            DatePicker("", selection: $startDate,
                                       displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                                .padding(.horizontal, 24)
                        }
                    }

                    // 结束时间（可选）
                    if !isAllDay {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("结束时间")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Toggle("", isOn: $hasEndTime)
                                    .tint(Color.goPrimary)
                                    .labelsHidden()
                                    .scaleEffect(0.8)
                            }
                            .padding(.horizontal, 24)
                            if hasEndTime {
                                DatePicker("", selection: $endDate, in: startDate...,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(Color.goPrimary)
                                    .labelsHidden()
                                    .padding(.horizontal, 24)
                            }
                        }
                    }

                    // 重复频率
                    VStack(alignment: .leading, spacing: 10) {
                        Text("重复频率")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recurrenceOptions, id: \.1) { label, days in
                                    Button { recurrenceDays = days } label: {
                                        Text(label)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(recurrenceDays == days ? Color.arkInk : .primary.opacity(0.7))
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(recurrenceDays == days ? Color.goLime : .clear, in: Capsule())
                                            .glassEffect(recurrenceDays == days ? .regular.tint(Color.goLime.opacity(0.2)) : .regular, in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // 保存按钮
                    Button { saveReminder(); dismiss() } label: {
                        Text("添加到日历")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.goLime, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }

    private func saveReminder() {
        let fireDate: Date
        if hasStartTime {
            fireDate = startDate
        } else {
            fireDate = Calendar.current.startOfDay(for: Date())
        }
        let event = Event(
            title: title,
            startDate: fireDate,
            endDate: (hasEndTime && !isAllDay) ? endDate : nil,
            isAllDay: isAllDay,
            eventType: EventType.daily.rawValue,
            relatedEntityType: "pet",
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = recurrenceDays
        let reminder = Reminder(event: event, scheduledAt: fireDate)
        event.reminders.append(reminder)
        modelContext.insert(event)
        // 如果重复，生成多个提醒（最多12个）
        if recurrenceDays > 0 {
            for i in 1...12 {
                guard let nextDate = Calendar.current.date(byAdding: .day, value: recurrenceDays * i, to: fireDate) else { break }
                let r = Reminder(event: event, scheduledAt: nextDate)
                r.status = "pending"
                modelContext.insert(r)
            }
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Main View
struct PetFoodManagementView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 双轨模式切换
    @State private var selectedMode: FoodTrackingMode = .casual

    // 佛系模式
    @State private var casualOpenDate: Date = Date()
    @State private var casualDurationDays: Int = 30
    private let durationOptions: [(String, Int)] = [
        ("1个月", 30), ("2个月", 60), ("3个月", 90), ("半年", 180)
    ]

    // 库存编辑（精准模式）
    @State private var editingStock = false
    @State private var selectedBrand: String = ""
    @State private var customBrandInput: String = ""
    @State private var showBrandPicker = false
    @State private var stockKgInput: String = ""
    @State private var dailyGramsInput: String = ""
    // 任务四：价格记账
    @State private var stockPriceInput: String = ""
    @State private var stockPayerId: String = ""
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    // 喂食
    @State private var showFeedInput = false
    @State private var feedGramsInput: String = ""
    @State private var setAsDefault = false
    @State private var showOverdoseToast = false
    @State private var overdoseIsSuccess = false   // C3: true=达标, false=超量
    @State private var showFeedReminder = false

    // 喂水
    @State private var showWaterInput = false
    @State private var waterMlInput: String = ""
    @State private var setWaterAsDefault = false
    @State private var showWaterReminder = false

    // Toast 自动消失
    @State private var toastTask: Task<Void, Never>? = nil

    @AppStorage("defaultFeedGrams") private var defaultFeedGrams: Double = 0
    @AppStorage("defaultWaterMl")   private var defaultWaterMl:   Double = 250

    private var todayFeedLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.feeding.rawValue && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }
    private var todayFeedGrams: Double {
        todayFeedLogs.reduce(0) { $0 + $1.amountGrams }
    }
    private var todayWaterLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
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
    private var effectiveFeedGrams: Double {
        let d = Double(feedGramsInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        return d > 0 ? d : (defaultFeedGrams > 0 ? defaultFeedGrams : pet.dailyPortionGrams)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // ── 顶部模式切换
                        modePicker

                        // ── 佛系模式：开包日期 + 预估时长
                        if selectedMode == .casual {
                            casualSection
                        } else {
                            // ── 精准模式：包装规格 + 每日份量（原有逻辑）
                            stockSection
                        }

                        // 喂食 + 喂水（两种模式均显示）
                        feedSection
                        waterSection
                        historySection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }

                // C3: 达标 / 超量 Toast
                if showOverdoseToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: overdoseIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(overdoseIsSuccess ? Color.goLime : Color.goYellow)
                            Text(overdoseIsSuccess ? "今日份量已达标 🎉" : "超出今日额定份量 注意过量")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(overdoseIsSuccess ? Color.goLime : Color.goYellow, in: Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                    .zIndex(99)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showOverdoseToast)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMode)
            .navigationTitle("\(pet.name) · 饮食管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                // 从宠物数据初始化模式状态
                selectedMode = pet.foodTrackingMode
                casualOpenDate = pet.casualOpenDate ?? Date()
                if pet.casualDurationDays > 0 { casualDurationDays = pet.casualDurationDays }
                selectedBrand = knownFoodBrands.contains(pet.foodBrand) ? pet.foodBrand : (pet.foodBrand.isEmpty ? knownFoodBrands[0] : "自定义品牌")
                customBrandInput = pet.foodBrand
                // FIX 5-C: 初始化精准模式输入框
                if pet.restockWeight > 0 { stockKgInput = String(format: "%.1f", pet.restockWeight) }
                if pet.dailyPortionGrams > 0 { dailyGramsInput = String(format: "%.0f", pet.dailyPortionGrams) }
            }
        }
        .sheet(isPresented: $showWaterReminder) {
            FoodReminderSheet(pet: pet,
                              prefillTitle: "喂水 \(Int(defaultWaterMl))ml",
                              prefillType: "喂水")
        }
    }

    // MARK: - 模式切换 Picker
    private var modePicker: some View {
        VStack(spacing: 10) {
            Picker("追踪模式", selection: $selectedMode) {
                ForEach(FoodTrackingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedMode) { _, newMode in
                // 持久化模式选择到 Pet 模型
                pet.foodTrackingMode = newMode
                modelContext.safeSave()
            }

            Text(selectedMode == .casual
                 ? "只记录大概吃多久，喂食打卡不扣克数 🐾"
                 : "精确追踪库存克数，动态计算剩余天数 📊")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 佛系模式卡
    private var casualSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("粮食估算", systemImage: "leaf.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goLime)
                Spacer()
            }

            // 开包日期
            VStack(alignment: .leading, spacing: 6) {
                Text("开包日期")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                DatePicker("", selection: $casualOpenDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.goLime)
                    .onChange(of: casualOpenDate) { _, d in
                        pet.casualOpenDate = d
                        modelContext.safeSave()
                    }
            }

            // 预估时长 (Segmented Picker)
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
                                    .background(casualDurationDays == days ? Color.goLime : .clear, in: Capsule())
                                    .glassEffect(casualDurationDays == days ? .regular.tint(Color.goLime.opacity(0.2)) : .regular, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 耗尽日期展示
            GoDashedDivider()
            if let runOut = pet.casualEstimatedRunOutDate {
                let remaining = pet.casualRemainingDays ?? 0
                HStack(spacing: 8) {
                    Text("🍖")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        let accent: Color = remaining <= 7 ? .goRed : remaining <= 14 ? .goYellow : .goLime
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
                .background(
                    (remaining <= 7 ? Color.goRed : remaining <= 14 ? Color.goYellow : Color.goLime).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            } else {
                Text("设置开包日期和预估时长，即可查看耗尽提醒 ✨")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 库存卡（品牌 Picker）
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
                        .foregroundStyle(Color.goLime)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.goLime.opacity(0.12), in: Capsule())
                }
            }

            if editingStock {
                VStack(spacing: 10) {
                    // 品牌 Picker
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
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    inputRow(icon: "scalemass.fill", label: "规格(kg)", color: .goTeal) {
                        TextField(pet.restockWeight > 0 ? String(format: "%.1f", pet.restockWeight) : "10.0",
                                  text: $stockKgInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    inputRow(icon: "fork.knife", label: "每日份量(g)", color: .goYellow) {
                        TextField(pet.dailyPortionGrams > 0 ? String(format: "%.0f", pet.dailyPortionGrams) : "200",
                                  text: $dailyGramsInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    inputRow(icon: "yensign.circle.fill", label: "购买价格(¥)", color: Color.goLime) {
                        TextField("选填", text: $stockPriceInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
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
                                            .background(stockPayerId == human.id.uuidString ? Color.goLime : .clear, in: Capsule())
                                            .glassEffect(stockPayerId == human.id.uuidString ? .regular.tint(Color.goLime.opacity(0.2)) : .regular, in: Capsule())
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
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.goLime, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 0) {
                    stockStatCell(label: "品牌",
                                  value: pet.foodBrand.isEmpty ? "未设置" : pet.foodBrand,
                                  accent: .goOrange)
                    Divider().frame(height: 40)
                    stockStatCell(label: "剩余天数",
                                  value: pet.remainingFoodDays > 0 ? "\(pet.remainingFoodDays)天" : "--",
                                  accent: pet.remainingFoodDays <= 7 && pet.remainingFoodDays > 0 ? .goRed : .primary)
                    Divider().frame(height: 40)
                    stockStatCell(label: "每日份量",
                                  value: pet.dailyPortionGrams > 0 ? "\(Int(pet.dailyPortionGrams))g" : "--",
                                  accent: .goYellow)
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
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 喂食打卡卡
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("喂食记录", systemImage: "fork.knife.circle.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goOrange)
                Spacer()
                Text("今日 \(todayFeedLogs.count) 次 · \(Int(todayFeedGrams))g")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goOrange.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.goOrange.opacity(0.12), in: Capsule())
            }

            let counts = last7FeedCounts
            if !counts.allSatisfy({ $0 == 0 }) {
                MiniBarChart(values: counts.map { Double($0) }, labels: [], accentColor: Color.goOrange)
                    .frame(height: 32)
            }

            // C5fix: 快速喂食 + 独立提醒按钮
            HStack(spacing: 8) {
                Button { quickFeed(grams: effectiveFeedGrams) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife").font(.system(size: 12, weight: .bold))
                        let label = effectiveFeedGrams > 0 ? "喂 \(Int(effectiveFeedGrams))g" : "快速打卡"
                        Text(label).font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.goOrange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // C5fix: 独立提醒按钮
                Button { showFeedReminder = true } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.goOrange)
                        .frame(width: 44, height: 44)
                        .background(Color.goOrange.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button { withAnimation { showFeedInput.toggle() } } label: {
                    Image(systemName: showFeedInput ? "minus.circle" : "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.goOrange)
                        .frame(width: 44, height: 44)
                        .background(Color.goOrange.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            // 自定义克数输入
            if showFeedInput {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("克数", text: $feedGramsInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("g").font(.system(size: 13, weight: .bold)).foregroundStyle(.primary.opacity(0.4))
                        Button {
                            let g = Double(feedGramsInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                            if g > 0 { quickFeed(grams: g) }
                            if setAsDefault && g > 0 { defaultFeedGrams = g }
                            feedGramsInput = ""
                            withAnimation { showFeedInput = false }
                        } label: {
                            Text("记录").font(.system(size: 13, weight: .black)).foregroundStyle(.black)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.goLime, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    // 设为默认 checkbox
                    Button { setAsDefault.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: setAsDefault ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14)).foregroundStyle(setAsDefault ? Color.goLime : .primary.opacity(0.3))
                            Text("设为默认单次喂食量")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // 今日喂食记录
            if !todayFeedLogs.isEmpty {
                GoDashedDivider()
                ForEach(todayFeedLogs.prefix(5)) { log in
                    HStack {
                        Text("🍽️").font(.system(size: 13))
                        Text(log.amountGrams > 0 ? "\(Int(log.amountGrams))g" : "快速打卡")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                        Spacer()
                        Text(log.date, style: .time)
                            .font(.system(size: 11)).foregroundStyle(.primary.opacity(0.4))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 喂水卡
    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("喂水记录", systemImage: "drop.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                Spacer()
                Text("今日 \(todayWaterLogs.count) 次")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goTeal.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.goTeal.opacity(0.12), in: Capsule())
            }

            // C5fix: 快速加水 + 独立提醒按钮
            HStack(spacing: 8) {
                Button { quickWater(ml: defaultWaterMl) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill").font(.system(size: 12, weight: .bold))
                        Text("加水 \(Int(defaultWaterMl))ml")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // C5fix: 独立提醒按钮
                Button { showWaterReminder = true } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.goTeal.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button { withAnimation { showWaterInput.toggle() } } label: {
                    Image(systemName: showWaterInput ? "minus.circle" : "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.goTeal.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if showWaterInput {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("毫升数", text: $waterMlInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("ml").font(.system(size: 13, weight: .bold)).foregroundStyle(.primary.opacity(0.4))
                        Button {
                            let ml = Double(waterMlInput) ?? 0
                            if ml > 0 { quickWater(ml: ml) }
                            if setWaterAsDefault && ml > 0 { defaultWaterMl = ml }
                            waterMlInput = ""
                            withAnimation { showWaterInput = false }
                        } label: {
                            Text("记录").font(.system(size: 13, weight: .black)).foregroundStyle(.black)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.goLime, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button { setWaterAsDefault.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: setWaterAsDefault ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14)).foregroundStyle(setWaterAsDefault ? Color.goLime : .primary.opacity(0.3))
                            Text("设为默认加水量")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !todayWaterLogs.isEmpty {
                GoDashedDivider()
                ForEach(todayWaterLogs.prefix(4)) { log in
                    HStack {
                        Text("💧").font(.system(size: 13))
                        Text(log.amountMl > 0 ? "\(Int(log.amountMl)) ml" : "加水")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                        Spacer()
                        Text(log.date, style: .time)
                            .font(.system(size: 11)).foregroundStyle(.primary.opacity(0.4))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }


    // MARK: - 历史记录
    private var historySection: some View {
        let feedLogs = Array(pet.careLogs.filter { $0.type == CareType.feeding.rawValue }
            .sorted { $0.date > $1.date }.prefix(15))
        guard !feedLogs.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("喂食历史")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4)).tracking(2)
                ForEach(feedLogs) { log in
                    HStack {
                        Text("🍽️").font(.system(size: 13))
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
        )
    }

    // MARK: - 辅助组件

    private func stockStatCell(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private func inputRow<V: View>(icon: String, label: String, color: Color, @ViewBuilder field: () -> V) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(color).frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary.opacity(0.7))
                .frame(width: 90, alignment: .leading)
            field().foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 数据操作

    private func saveStock() {
        let finalBrand = selectedBrand == "自定义品牌" ? customBrandInput : selectedBrand
        if !finalBrand.isEmpty { pet.foodBrand = finalBrand }
        if let kg = Double(stockKgInput.replacingOccurrences(of: ",", with: ".")) { pet.restockWeight = kg }
        if let g = Double(dailyGramsInput.replacingOccurrences(of: ",", with: ".")) { pet.dailyPortionGrams = g }
        pet.restockDate = Date()
        // 任务四：如填写了价格，同步创建 PetExpenseLog
        if let price = Double(stockPriceInput.replacingOccurrences(of: ",", with: ".")), price > 0 {
            let payerId = stockPayerId.isEmpty
                ? UserDefaults.standard.string(forKey: "currentActiveHumanId")
                : stockPayerId
            let brandNote = finalBrand.isEmpty ? "粮食" : finalBrand
            let expenseLog = PetExpenseLog(
                date: Date(),
                amount: price,
                category: .food,
                note: "购买 \(brandNote)",
                pet: pet,
                executorId: payerId
            )
            modelContext.insert(expenseLog)
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // FIX 5-B: 清空输入框，防止下次重新打开 edit 时残留旧值
        stockKgInput = ""
        dailyGramsInput = ""
        stockPriceInput = ""
        stockPayerId = ""
        withAnimation { editingStock = false }
    }

    private func quickFeed(grams: Double) {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: Date(), type: .feeding, amountGrams: grams, pet: pet, executorId: eid)
        modelContext.insert(log)
        // C3: 余粮联动扣除
        if pet.dailyPortionGrams > 0 && pet.restockWeight > 0 && grams > 0 {
            let extraDays = grams / max(1, pet.dailyPortionGrams)
            pet.restockDate = Calendar.current.date(byAdding: .second, value: -Int(extraDays * 86400),
                                                     to: pet.restockDate ?? Date())
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // 首次喂食走 recordFirstMeal（内含 +15 椰子），之后每次 +1
        if !QuestManager.shared.isFirstMealRecorded {
            QuestManager.shared.recordFirstMeal()
        }
        QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
        // 超量提示（仍然允许喂食，仅显示警告）
        let newTotal = todayFeedGrams + grams
        if pet.dailyPortionGrams > 0 && newTotal > pet.dailyPortionGrams * 1.1 {
            showOverdoseToast(isSuccess: false)  // false = 超量（橙色警告）
        } else if pet.dailyPortionGrams > 0 && newTotal >= pet.dailyPortionGrams {
            showOverdoseToast(isSuccess: true)   // true = 达标（绿色提示）
        }
    }

    private func quickWater(ml: Double) {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: Date(), type: .watering, amountMl: ml, pet: pet, executorId: eid)
        modelContext.insert(log)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
    }

    // FIX 5-A: 修正参数语义，isSuccess=true 表示达标（绿），false 表示超量（橙）
    private func showOverdoseToast(isSuccess: Bool) {
        overdoseIsSuccess = isSuccess
        toastTask?.cancel()
        withAnimation { showOverdoseToast = true }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation { self.showOverdoseToast = false }
            }
        }
    }
}
