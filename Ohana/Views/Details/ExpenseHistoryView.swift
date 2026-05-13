//
//  ExpenseHistoryView.swift
//  Ohana
//
//  花费历史页 (C8b) - 上部图表 + 下部前置layer记录列表
//

import SwiftUI
import SwiftData
import Charts

struct ExpenseHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "今年"
        case all = "全部"
    }

    @State private var selectedRange: TimeRange = .month
    @State private var isInlineExpenseComposerVisible = false
    @State private var newAmount = ""
    @State private var newCategory: ExpenseCategory = .food
    @State private var newNote = ""
    @State private var newDate = Date()
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @State private var selectedPayerId: String? = nil

    private var filteredLogs: [PetExpenseLog] {
        let cal = Calendar.current
        let now = Date()
        return pet.expenseLogs.filter { log in
            switch selectedRange {
            case .week:
                return cal.isDate(log.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(log.date, equalTo: now, toGranularity: .month)
            case .year:
                return cal.isDate(log.date, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }.sorted { $0.date > $1.date }
    }

    private var sortedLogs: [PetExpenseLog] { filteredLogs }

    private var currentActiveHumanId: String? {
        let raw = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        return raw.isEmpty ? nil : raw
    }

    private var parsedNewAmount: Double? {
        CountryDecimalInput.parse(newAmount, countryCode: appCountry)
    }

    private var canSaveInlineExpense: Bool {
        (parsedNewAmount ?? 0) > 0
    }

    private var selectedPayerName: String {
        guard let selectedPayerId,
              let human = allHumans.first(where: { $0.id.uuidString == selectedPayerId })
        else { return "未指定" }
        return human.name
    }

    /// 实际总支出（不含报销负值，避免汇总变负数产生误导）
    private var rangeTotal: Double {
        filteredLogs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }
    /// 报销合计（绝对值）
    private var rangeTotalReimbursed: Double {
        filteredLogs.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }
    /// 医疗净自费 = 医疗支出 - 报销到账
    private var medicalNetCost: Double {
        let spent = filteredLogs.filter {
            $0.amount > 0 && ($0.expenseCategory == .medical || $0.expenseCategory == .insurancePremium)
        }.reduce(0) { $0 + $1.amount }
        return spent - rangeTotalReimbursed
    }

    private var categoryBreakdown: [(ExpenseCategory, Double)] {
        var dict: [ExpenseCategory: Double] = [:]
        for log in filteredLogs where log.amount > 0 {
            let cat = ExpenseCategory(rawValue: log.category) ?? .other
            dict[cat, default: 0] += log.amount
        }
        return dict.sorted { $0.value > $1.value }
    }

    private var last6MonthsData: [(String, Double)] {
        (0..<6).map { offset in
            guard let month = Calendar.current.date(byAdding: .month, value: -(5 - offset), to: Date()) else { return ("", 0) }
            let total = pet.expenseLogs.filter {
                Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(0.0) { $0 + $1.amount }
            let label = month.formatted(.dateTime.month(.abbreviated))
            return (label, total)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground()

            VStack(spacing: 0) {
                chartSection.frame(maxHeight: .infinity)
                recordListLayer.frame(height: 420)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("花费记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(GoMotion.feedback) {
                        isInlineExpenseComposerVisible.toggle()
                    }
                    if isInlineExpenseComposerVisible, selectedPayerId == nil {
                        selectedPayerId = currentActiveHumanId
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .onAppear {
            if selectedPayerId == nil {
                selectedPayerId = currentActiveHumanId
            }
        }
        .onChange(of: newAmount) { _, value in
            let sanitized = CountryDecimalInput.sanitize(value, countryCode: appCountry, maxFractionDigits: 2)
            if sanitized != value {
                newAmount = sanitized
            }
        }
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：宠物头像 + 总金额
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedRange.rawValue + "花费")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(AppCurrency.format(rangeTotal, fractionDigits: 0))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: rangeTotal)
                    }
                }
                Spacer()
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 48, height: 48).clipShape(Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 2))
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 36))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 时间范围选择器
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button { withAnimation(.spring(response: 0.3)) { selectedRange = range } } label: {
                        Text(range.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedRange == range ? Color.arkInk : .primary.opacity(0.5))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(selectedRange == range ? Color.goYellow : .clear, in: Capsule())
                            .goSelectableSurface(isSelected: selectedRange == range, tint: Color.goYellow, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // 饼图 + 图例
            if categoryBreakdown.isEmpty {
                Text("暂无花费记录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                HStack(spacing: 20) {
                    // SectorMark 饼图
                    Chart(categoryBreakdown, id: \.0) { cat, amount in
                        SectorMark(
                            angle: .value("金额", amount),
                            innerRadius: .ratio(0.52),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("分类", cat.rawValue))
                        .cornerRadius(4)
                    }
                    .chartForegroundStyleScale(
                        domain: ExpenseCategory.allCases.map { $0.rawValue },
                        range: [Color.goYellow, Color.goTeal, Color.goOrange,
                                Color.goPrimary, Color.goCardCyan, Color(hex: "06B6D4"), Color.goRed]
                    )
                    .chartLegend(.hidden)
                    .frame(width: 110, height: 110)

                    // 图例列表
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(categoryBreakdown.prefix(4), id: \.0) { cat, amount in
                            let pct = rangeTotal > 0 ? Int(amount / rangeTotal * 100) : 0
                            HStack(spacing: 6) {
                                Text(cat.emoji).font(.system(size: 13))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                                Spacer()
                                Text("\(pct)%")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                Text(AppCurrency.format(amount, fractionDigits: 0))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.goYellow)
                            }
                        }
                        // 报销净节省行
                        if rangeTotalReimbursed > 0 {
                            HStack(spacing: 6) {
                                Text("🛡️").font(.system(size: 13))
                                Text("保险报销")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "4ECDC4"))
                                Spacer()
                                Text(AppCurrency.format(-rangeTotalReimbursed, fractionDigits: 0))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(hex: "4ECDC4"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Record List Layer
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text("花费记录")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        if isInlineExpenseComposerVisible {
                            inlineExpenseComposer
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        ForEach(sortedLogs) { log in
                            expenseRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有花费记录\n点击右上角 + 在这里记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
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
                                .buttonStyle(ScaleButtonStyle())
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

    private var inlineExpenseComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速记账")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("金额、日期和备注都在本页完成")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        isInlineExpenseComposerVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("金额")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AppCurrency.symbol)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                    Text(newAmount.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry) : newAmount)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(newAmount.isEmpty ? Color.ohanaSecondaryText.opacity(0.55) : Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(AppCurrency.code)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                EmbeddedDecimalKeypad(
                    text: $newAmount,
                    countryCode: appCountry,
                    maxFractionDigits: 2,
                    accent: .goPrimary,
                    isMini: true,
                    showsSubmitButton: false
                )
            }

            inlineExpenseCategoryStrip
            inlineExpenseMetadataRows

            TextField("备注（可选）", text: $newNote)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .textInputAutocapitalization(.never)
                .submitLabel(.done)

            Button(action: saveInlineExpense) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("保存记录")
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSaveInlineExpense ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .disabled(!canSaveInlineExpense)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var inlineExpenseCategoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            newCategory = cat
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(cat.emoji)
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(newCategory == cat ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.72))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(newCategory == cat ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var inlineExpenseMetadataRows: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                Text("日期")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DatePicker("", selection: $newDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }

            if !allHumans.isEmpty {
                Menu {
                    Button("未指定") { selectedPayerId = nil }
                    ForEach(allHumans) { human in
                        Button("\(human.avatarEmoji) \(human.name)") {
                            selectedPayerId = human.id.uuidString
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 24)
                        Text("支付人")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(selectedPayerName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func expenseRow(log: PetExpenseLog) -> some View {
        let cat = ExpenseCategory(rawValue: log.category) ?? .other
        let isReimbursement = log.amount < 0
        let accentColor: Color = isReimbursement ? Color(hex: "4ECDC4") : Color.goYellow
        let payer = payer(for: log)
        let payerLabel = isReimbursement ? "到账" : "支付者"
        let payerName = payer?.name ?? (isReimbursement ? "保险" : "未指定")

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(accentColor.opacity(0.15)).frame(width: 36, height: 36)
                if isReimbursement {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                } else {
                    Text(cat.emoji).font(.system(size: 18))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isReimbursement ? "保险报销" : log.category)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isReimbursement ? accentColor : .primary)
                    if isReimbursement {
                        Text("到账")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accentColor, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(log.date, format: .dateTime.year().month().day())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    if !log.note.isEmpty {
                        Text(log.note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: isReimbursement ? "arrow.down.circle.fill" : "person.crop.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(payerLabel)：\(payerName)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(accentColor.opacity(payer == nil && !isReimbursement ? 0.65 : 1))
            }

            Spacer()

            Text(AppCurrency.format(log.amount, fractionDigits: 0))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)

            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .goSelectableSurface(isSelected: isReimbursement, tint: accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func payer(for log: PetExpenseLog) -> Human? {
        guard let executorId = log.executorId else { return nil }
        return allHumans.first { $0.id.uuidString == executorId }
    }

    private func saveInlineExpense() {
        guard let amount = parsedNewAmount, amount > 0 else { return }
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: newDate,
            amount: amount,
            category: newCategory,
            note: note,
            pet: pet,
            executorId: selectedPayerId
        )
        modelContext.insert(log)
        modelContext.safeSave()
        let reward = QuestManager.shared.awardAction(type: .expense, pet: pet, context: modelContext)
        let rewardDelta = CareLedgerService.rewardDelta(reward)
        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: selectedPayerId == nil ? .unknown : .human,
            actorId: selectedPayerId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: newCategory.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            note: note,
            source: .detail,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: rewardDelta,
            context: modelContext,
            save: true
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) {
            newAmount = ""
            newNote = ""
            newDate = Date()
            selectedPayerId = currentActiveHumanId
            isInlineExpenseComposerVisible = false
        }
    }
}
