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

    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "今年"
        case all = "全部"
    }

    @State private var selectedRange: TimeRange = .month
    @State private var showAddSheet = false
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
            ArkBackgroundView()

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
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddExpenseSheet(pet: pet, preselectedPayerId: UserDefaults.standard.string(forKey: "currentActiveHumanId"))
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
                        .foregroundStyle(.primary.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥\(Int(rangeTotal))")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
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
                            .glassEffect(selectedRange == range ? .regular.tint(Color.goYellow.opacity(0.3)) : .regular, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // 饼图 + 图例
            if categoryBreakdown.isEmpty {
                Text("暂无花费记录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
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
                                    .foregroundStyle(.primary.opacity(0.8))
                                Spacer()
                                Text("\(pct)%")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Text("¥\(Int(amount))")
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
                                Text("-¥\(Int(rangeTotalReimbursed))")
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
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text("花费记录")
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
                            expenseRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有花费记录\n点击右上角 + 开始记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.35))
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

    private func expenseRow(log: PetExpenseLog) -> some View {
        let cat = ExpenseCategory(rawValue: log.category) ?? .other
        let isReimbursement = log.amount < 0
        let accentColor: Color = isReimbursement ? Color(hex: "4ECDC4") : Color.goYellow

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

            VStack(alignment: .leading, spacing: 2) {
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
                        .foregroundStyle(.primary.opacity(0.4))
                    if !log.note.isEmpty {
                        Text(log.note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(isReimbursement ? "-¥\(Int(abs(log.amount)))" : "¥\(Int(log.amount))")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)

            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(isReimbursement ? .regular.tint(accentColor.opacity(0.08)) : .regular,
                     in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Add Expense Sheet
    private var addExpenseSheet: some View {
        VStack(spacing: 0) {
            // 把手
            Capsule()
                .fill(.primary.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("记录花费")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    // 金额大输入框
                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("¥")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goYellow)
                            TextField("0", text: $newAmount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 20)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 24)
                        Text("金额 (元)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }

                    // 分类选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("分类")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                    Button { newCategory = cat } label: {
                                        HStack(spacing: 6) {
                                            Text(cat.emoji)
                                            Text(cat.rawValue)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(newCategory == cat ? Color.arkInk : .primary.opacity(0.7))
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(newCategory == cat ? Color.goYellow : .clear, in: Capsule())
                                        .glassEffect(newCategory == cat ? .regular.tint(Color.goYellow.opacity(0.3)) : .regular, in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注（可选）")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        TextField("例如：定期疫苗", text: $newNote)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)

                    // 日期
                    HStack {
                        Text("日期")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        DatePicker("", selection: $newDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(Color.goYellow)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 24)

                    // 支付人选择
                    if !allHumans.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("支付人")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 24)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button { selectedPayerId = nil } label: {
                                        Text("未指定")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .primary.opacity(0.6))
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedPayerId == nil ? Color.goYellow : .clear, in: Capsule())
                                            .glassEffect(selectedPayerId == nil ? .regular.tint(Color.goYellow.opacity(0.3)) : .regular, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    ForEach(allHumans) { human in
                                        Button { selectedPayerId = human.id.uuidString } label: {
                                            HStack(spacing: 5) {
                                                Text(human.avatarEmoji).font(.system(size: 14))
                                                Text(human.name)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundStyle(selectedPayerId == human.id.uuidString ? Color.arkInk : .primary.opacity(0.6))
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedPayerId == human.id.uuidString ? Color.goYellow : .clear, in: Capsule())
                                            .glassEffect(selectedPayerId == human.id.uuidString ? .regular.tint(Color.goYellow.opacity(0.3)) : .regular, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // 保存按钮
                    Button {
                        if let amount = Double(newAmount.replacingOccurrences(of: ",", with: ".")) {
                            let log = PetExpenseLog(
                                date: newDate,
                                amount: amount,
                                category: newCategory,
                                note: newNote,
                                pet: pet,
                                executorId: selectedPayerId
                            )
                            modelContext.insert(log)
                            modelContext.safeSave()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            newAmount = ""; newNote = ""; showAddSheet = false
                        }
                    } label: {
                        Text("保存记录")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.goYellow, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(Double(newAmount.replacingOccurrences(of: ",", with: ".")) == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }
}
