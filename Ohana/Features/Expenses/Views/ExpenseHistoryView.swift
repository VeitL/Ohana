//
//  ExpenseHistoryView.swift
//  Ohana
//
//  花费历史页 (C8b) - 上部图表 + 下部前置layer记录列表
//

import SwiftData
import SwiftUI

struct ExpenseHistoryContentView: View {
    let pet: Pet
    let expenseLogs: [PetExpenseLog]
    let allHumans: [Human]
    let allPets: [Pet]
    let allSharedCareSessions: [SharedCareSession]
    var onRemove: (() -> Void)?
    var showsCloseButton: Bool = true
    var onDataChanged: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "今年"
        case all = "全部"
    }

    @State private var selectedRange: TimeRange = .month
    @State private var showingExpensePopup = false
    @State private var isInlineExpenseComposerVisible = false
    @State private var newAmount = ""
    @State private var newCategory: ExpenseCategory = .food
    @State private var newNote = ""
    @State private var newDate = Date()
    @State private var selectedPayerId: String? = nil
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var filteredLogs: [PetExpenseLog] {
        let cal = Calendar.current
        let now = Date()
        return expenseLogs.filter { log in
            switch selectedRange {
            case .week:
                cal.isDate(log.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                cal.isDate(log.date, equalTo: now, toGranularity: .month)
            case .year:
                cal.isDate(log.date, equalTo: now, toGranularity: .year)
            case .all:
                true
            }
        }.sorted { $0.date > $1.date }
    }

    private var sortedLogs: [PetExpenseLog] { filteredLogs }

    private var currentActiveHumanId: String? {
        appServices.activeHumanSelection.currentHumanId
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
        (0 ..< 6).map { offset in
            guard let month = Calendar.current.date(byAdding: .month, value: -(5 - offset), to: Date()) else { return ("", 0) }
            let total = expenseLogs.filter {
                Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(0.0) { $0 + $1.amount }
            let label = month.formatted(.dateTime.month(.abbreviated))
            return (label, total)
        }
    }

    var body: some View {
        ZStack {
            PetExpenseDashboardContent(
                pet: pet,
                expenseLogs: expenseLogs,
                allHumans: allHumans,
                allSharedCareSessions: allSharedCareSessions,
                showsCloseButton: showsCloseButton,
                onClose: { dismiss() },
                onAdd: {
                    selectedPayerId = currentActiveHumanId
                    withAnimation(GoMotion.feedback) {
                        showingExpensePopup = true
                    }
                },
                onRemove: onRemove
            )

            if showingExpensePopup {
                AddExpenseSheet(
                    pet: pet,
                    humans: allHumans,
                    allPets: allPets,
                    preselectedPayerId: selectedPayerId ?? currentActiveHumanId,
                    onSaved: {
                        onDataChanged?()
                    },
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            showingExpensePopup = false
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(AppCurrency.format(rangeTotal, fractionDigits: 0))
                            .font(OhanaFont.adaptive(size: 44, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .contentTransition(.numericText())
                            .animation(GoMotion.feedback, value: rangeTotal)
                    }
                }
                Spacer()
                PetAvatarPortraitView(
                    imageData: pet.avatarImageData,
                    fallbackText: pet.avatarEmoji,
                    themeColor: Color(hex: pet.safeThemeColorHex),
                    size: 48,
                    backgroundOpacity: 0.18
                )
                .overlay(Circle().strokeBorder(Color.ohanaSecondaryText.opacity(0.2), lineWidth: 2))
                if showsCloseButton {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .contentShape(Circle())
                    .accessibilityLabel("关闭")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 时间范围选择器
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button { withAnimation(GoMotion.feedback) { selectedRange = range } } label: {
                        Text(range.rawValue)
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                    .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(categoryBreakdown.prefix(4), id: \.0) { cat, amount in
                        let pct = rangeTotal > 0 ? Int(amount / rangeTotal * 100) : 0
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(cat.emoji).font(OhanaFont.adaptive(size: 13)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(cat.rawValue)
                                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                                Spacer()
                                Text("\(pct)%")
                                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                Text(AppCurrency.format(amount, fractionDigits: 0))
                                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goYellow)
                            }
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                                    .fill(Color.ohanaControlFill.opacity(0.55))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                                            .fill(Color.goYellow)
                                            .frame(width: max(5, proxy.size.width * CGFloat(max(0, min(1, amount / max(rangeTotal, 1))))))
                                    }
                            }
                            .frame(height: 6)
                        }
                    }
                    // 报销净节省行
                    if rangeTotalReimbursed > 0 {
                        HStack(spacing: 6) {
                            Text("🛡️").font(OhanaFont.adaptive(size: 13)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text("保险报销")
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color(hex: "4ECDC4"))
                            Spacer()
                            Text(AppCurrency.format(-rangeTotalReimbursed, fractionDigits: 0))
                                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color(hex: "4ECDC4"))
                        }
                    }
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
            RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text("花费记录")
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                                .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
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

    private var inlineExpenseComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "creditcard.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速记账")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("金额、日期和备注都在本页完成")
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        isInlineExpenseComposerVisible = false
                    }
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("金额")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AppCurrency.symbol)
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                    Text(newAmount.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry) : newAmount)
                        .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(newAmount.isEmpty ? Color.ohanaSecondaryText.opacity(0.55) : Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(AppCurrency.code)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))

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

            TextField("备注（可选）", text: $newNote) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .textInputAutocapitalization(.never)
                .submitLabel(.done)

            Button(action: saveInlineExpense) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    Text("保存记录")
                }
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSaveInlineExpense ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .disabled(!canSaveInlineExpense)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                Image(systemName: "calendar") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                Text("日期")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                        Image(systemName: "person.crop.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 24)
                        Text("支付人")
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(selectedPayerName)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                        Image(systemName: "chevron.down") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func expenseRow(log: PetExpenseLog) -> some View {
        let cat = ExpenseCategory(rawValue: log.category) ?? .other
        let isReimbursement = log.amount < 0
        let accentColor: Color = isReimbursement ? Color(hex: "4ECDC4") : Color.goYellow
        let payer = payer(for: log)
        let payerLabel = isReimbursement ? "到账" : "支付者"
        let payerName = payer?.name ?? (isReimbursement ? "保险" : "未指定")
        let visibleNote = SharedCareMetadata.visibleNote(log.note)

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(accentColor.opacity(0.15)).frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                if isReimbursement {
                    Image(systemName: "arrow.down.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 18, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(accentColor)
                } else {
                    Text(cat.emoji).font(OhanaFont.adaptive(size: 18)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(expenseTitle(log, isReimbursement: isReimbursement))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(isReimbursement ? accentColor : .primary)
                    if isReimbursement {
                        Text("到账")
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accentColor, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(log.date, format: .dateTime.year().month().day())
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    if !visibleNote.isEmpty {
                        Text(visibleNote)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: isReimbursement ? "arrow.down.circle.fill" : "person.crop.circle.fill")
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("\(payerLabel)：\(payerName)")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .lineLimit(1)
                }
                .foregroundStyle(accentColor.opacity(payer == nil && !isReimbursement ? 0.65 : 1))
            }

            Spacer()

            Text(AppCurrency.format(log.amount, fractionDigits: 0))
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(accentColor)

            Button {
                let command = DomainCommand.expenseDelete(
                    entityID: pet.id,
                    entityKind: EntityKind.pet.rawValue,
                    recordID: log.id
                )
                commandQueue.enqueue(command) {
                    DashboardRecordCommandExecutor(context: modelContext, services: appServices).deletePetExpense(
                        log,
                        pet: pet,
                        note: "dashboard.expense.delete.\(EntityKind.pet.rawValue)"
                    )
                }
            } label: {
                Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .goSelectableSurface(isSelected: isReimbursement, tint: accentColor, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func expenseTitle(_ log: PetExpenseLog, isReimbursement: Bool) -> String {
        guard !isReimbursement, !log.sharedSessionId.isEmpty else {
            return isReimbursement ? "保险报销" : log.category
        }
        let session = sharedCareSession(for: log.sharedSessionId)
        let countSuffix = SharedCareMetadata.targetCount(session: session, legacyNote: log.note).map { " · \($0)只" } ?? ""
        return "共同花费\(countSuffix)"
    }

    private func sharedCareSession(for id: String) -> SharedCareSession? {
        guard !id.isEmpty else { return nil }
        return allSharedCareSessions.first { $0.id.uuidString == id }
    }

    private func payer(for log: PetExpenseLog) -> Human? {
        guard let executorId = log.executorId else { return nil }
        return allHumans.first { $0.id.uuidString == executorId }
    }

    private func saveInlineExpense() {
        guard let amount = parsedNewAmount, amount > 0 else { return }
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedDate = newDate
        let savedCategory = newCategory
        let savedPayerId = selectedPayerId
        let command = DomainCommand.expenseEntry(entityID: pet.id, entityKind: EntityKind.pet.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) {
            newAmount = ""
            newNote = ""
            newDate = Date()
            selectedPayerId = currentActiveHumanId
            isInlineExpenseComposerVisible = false
        }
        commandQueue.enqueue(command) {
            DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordPetExpense(
                pet: pet,
                amount: amount,
                date: savedDate,
                category: savedCategory,
                note: note,
                executorId: savedPayerId,
                source: .detail,
                command: command,
                revisionNote: "dashboard.expense.entry"
            )
            onDataChanged?()
        }
    }
}
