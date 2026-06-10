//
//  PetInsuranceView.swift
//  Ohana
//
//  ArkSchemaV25：宠物保险记录页
//

import SwiftUI
import SwiftData

struct PetInsuranceView: View {
    let pet: Pet
    /// 嵌入「证件与保障」页时为 true：无 NavigationStack、无关闭按钮，内容不套外层 ScrollView
    var embedded: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var selectedInsurance: PetInsurance?
    @State private var insuranceToEdit: PetInsurance?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var sorted: [PetInsurance] {
        pet.insurances.sorted { $0.renewalDate > $1.renewalDate }
    }

    var body: some View {
        ZStack {
            if embedded {
                embeddedContent
                    .sheet(item: $selectedInsurance) { ins in
                        InsurancePolicyDetailSheet(insurance: ins, pet: pet)
                    }
            } else {
                NavigationStack {
                    ZStack {
                        OhanaAppBackground()
                        standaloneScroll
                    }
                    .navigationTitle("🛡️ \(pet.name)的保险")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { dismiss() }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showingAdd = true } label: {
                                Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.goPrimary).font(OhanaFont.adaptive(size: 22))
                            }
                        }
                    }
                    .sheet(item: $selectedInsurance) { ins in
                        InsurancePolicyDetailSheet(insurance: ins, pet: pet)
                    }
                }
            }

            if showingAdd || insuranceToEdit != nil {
                ProtectionInsurancePopup(pet: pet, existing: insuranceToEdit) {
                    withAnimation(GoMotion.page) {
                        showingAdd = false
                        insuranceToEdit = nil
                    }
                }
                .zIndex(40)
            }
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("保险")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 20, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            if sorted.isEmpty {
                embeddedEmpty
            } else {
                ForEach(sorted) { ins in
                    insuranceCard(ins)
                }
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var standaloneScroll: some View {
        ScrollView {
            VStack(spacing: 16) {
                if sorted.isEmpty {
                    emptyState
                } else {
                    ForEach(sorted) { ins in
                        insuranceCard(ins)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private var embeddedEmpty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("暂无保单，可记录续期与保额")
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Button { showingAdd = true } label: {
                Text("添加保单")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🛡️").font(OhanaFont.adaptive(size: 56))
            Text("暂无保险记录").font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
            Text("记录宠物保险保单，轻松追踪续期日期").font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText).multilineTextAlignment(.center)
            Button { showingAdd = true } label: {
                Text("添加保单").font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)).foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
            }.buttonStyle(ScaleButtonStyle())
        }.padding(.top, 60)
    }

    // MARK: - Insurance Card
    private func insuranceCard(_ ins: PetInsurance) -> some View {
        ZStack(alignment: .topTrailing) {
            Button { selectedInsurance = ins } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(ins.productName.isEmpty ? "未命名保单" : ins.productName)
                                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(ins.renewalStatusLabel)
                                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.arkInk)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: ins.renewalStatusColor), in: Capsule())
                            }
                            if !ins.companyName.isEmpty {
                                Text(ins.companyName)
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        }
                        Spacer(minLength: 36)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 0) {
                        statCell(label: "年费",
                                 value: ins.annualPremium > 0 ? AppCurrency.format(ins.annualPremium, fractionDigits: 0) : "—")
                        Divider().frame(height: 32).opacity(0.2)
                        statCell(label: "保额",
                                 value: ins.coverageAmount > 0 ? AppCurrency.format(ins.coverageAmount, fractionDigits: 0) : "—")
                        Divider().frame(height: 32).opacity(0.2)
                        statCell(label: "续期",
                                 value: ins.renewalDate.formatted(.dateTime.year().month().day()))
                        if !ins.claims.isEmpty {
                            Divider().frame(height: 32).opacity(0.2)
                            statCell(label: "报销",
                                     value: "\(ins.claims.count) 条")
                        }
                    }

                    if !ins.notes.isEmpty {
                        Text(ins.notes)
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(16)
                .goTranslucentCard(cornerRadius: 18)
            }
            .buttonStyle(ScaleButtonStyle())

            Menu {
                Button { insuranceToEdit = ins } label: {
                    Label("编辑保单", systemImage: "pencil")
                }
                Button { selectedInsurance = ins } label: {
                    Label("查看详情", systemImage: "info.circle")
                }
                Divider()
                Button(role: .destructive) {
                    deletePolicy(ins)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(10)
            }
        }
    }

    private func deletePolicy(_ insurance: PetInsurance) {
        let command = DomainCommand.insurancePolicy(
            petID: pet.id,
            policyID: insurance.id,
            action: "delete"
        )
        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            InsuranceCommandExecutor(context: modelContext, services: appServices).deletePolicy(
                insurance,
                pet: pet,
                note: "insurance.policy.delete"
            )
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            Text(label).font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Add / Edit Sheet

struct AddPetInsuranceSheet: View {
    let pet: Pet
    var existing: PetInsurance? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var isSaving = false

    // ── 基本信息 ──
    @State private var productName = ""
    @State private var companyName = ""
    @State private var policyNumber = ""
    @State private var coverageAmount = ""
    @State private var enablePolicyNumber = false
    @State private var enableCoverage = false
    @State private var startDate = Date()
    @State private var renewalDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes = ""

    // ── 费用 ──
    @State private var premiumInput = ""           // 用户输入的金额
    @State private var premiumMode: PremiumInputMode = .annual   // 年费 or 月费
    @State private var otherFeeInput = ""          // 其他费用金额
    @State private var otherFeeNote = ""           // 其他费用说明
    @State private var showOtherFee = false        // 展开其他费用行

    // ── 付款频次 + 付款日 ──
    @State private var paymentFrequency: InsurancePaymentFrequency = .annual
    @State private var paymentDay: Int = 1         // 每月/季付款日（1-28）

    // ── 自动生成选项 ──
    @State private var autoGenExpenses = true      // 自动生成全期花费记录
    @State private var showInCalendar = false      // 在日历中显示付款提醒

    private var isEdit: Bool { existing != nil }

    /// 用户输入金额 → 始终转为年费存储
    private var annualPremiumDouble: Double {
        let raw = CountryDecimalInput.parse(premiumInput, countryCode: AppCountry.code) ?? 0
        switch premiumMode {
        case .annual:   return raw
        case .monthly:  return raw * 12
        }
    }

    /// 每期保费（含其他费用）
    private var periodTotal: Double {
        let base = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble)
        let other = CountryDecimalInput.parse(otherFeeInput, countryCode: AppCountry.code) ?? 0
        return base + other
    }

    /// 月/季：每月（季）几日扣款
    private var showPaymentDay: Bool {
        paymentFrequency == .monthly || paymentFrequency == .quarterly
    }

    /// 按年/一次性：在频次卡片内选择生效与首期缴费日
    private var showAnnualOrOncePaymentPicker: Bool {
        paymentFrequency == .annual || paymentFrequency == .once
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        // 产品名称
                        field("产品名称（如：平安宠物险）*", text: $productName)
                        field("保险公司", text: $companyName)

                        optionalFieldSection

                        // ── 费用区域 ──
                        premiumSection

                        // ── 付款频次 + 付款日 / 按年·一次性缴费日 ──
                        frequencySection

                        // ── 日期（月/季含生效日；按年/一次性仅续期，生效日在频次卡片内）──
                        Group {
                            if paymentFrequency == .monthly || paymentFrequency == .quarterly {
                                DatePicker("生效日期", selection: $startDate, displayedComponents: .date)
                            }
                            DatePicker("续期日期", selection: $renewalDate, in: startDate..., displayedComponents: .date)
                        }
                        .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded))
                        .tint(Color.goPrimary)
                        .padding(14)
                        .goTranslucentCard(cornerRadius: 14)

                        // ── 自动生成选项 ──
                        if !isEdit && annualPremiumDouble > 0 {
                            autoGenSection
                        }

                        // 备注
                        field("备注（承保范围、排除项等）", text: $notes, axis: .vertical)

                        // 保存按钮
                        Button { save() } label: {
                            Text(isEdit ? "保存修改" : "添加保单")
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(productName.isEmpty ? Color.primary.opacity(0.15) : Color.goPrimary,
                                            in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle()).disabled(productName.isEmpty || isSaving)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
            }
            .navigationTitle(isEdit ? "编辑保单" : "添加保单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - 可选：保单号 / 保额（开关展开）

    private var optionalFieldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $enablePolicyNumber) {
                Text("填写保单号")
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
            }
            .tint(Color.goPrimary)
            if enablePolicyNumber {
                field("保单号", text: $policyNumber)
            }

            Toggle(isOn: $enableCoverage) {
                Text("填写保额")
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
            }
            .tint(Color.goPrimary)
            if enableCoverage {
                fieldNum("保额（元）", text: $coverageAmount)
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 14)
    }

    // MARK: - 费用区域

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 年费 / 月费 模式切换
            HStack(spacing: 0) {
                modeTab("年费", mode: .annual)
                modeTab("月费", mode: .monthly)
            }
            .background(Color.primary.opacity(0.06), in: Capsule())

            // 金额输入行
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(AppCurrency.symbol)
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                InlineNumericInput(
                    text: $premiumInput,
                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    step: 10,
                    valueFont: .system(size: 28, weight: .black, design: .rounded),
                    fill: Color.ohanaControlFill,
                    cornerRadius: 16,
                    horizontalPadding: 10,
                    verticalPadding: 8
                )
                Text(premiumMode == .annual ? "/ 年" : "/ 月")
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.vertical, 4)

            // 等价提示
            if annualPremiumDouble > 0 {
                let other = CountryDecimalInput.parse(otherFeeInput, countryCode: AppCountry.code) ?? 0
                let basePerPeriod = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble)
                VStack(alignment: .leading, spacing: 3) {
                    if premiumMode == .monthly {
                        Text("年总保费：\(AppCurrency.format(annualPremiumDouble, fractionDigits: 2))")
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    HStack(spacing: 4) {
                        Text("每期缴纳：\(AppCurrency.format(basePerPeriod + other, fractionDigits: 2))")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        if other > 0 {
                            Text("（含其他费用 \(AppCurrency.format(other, fractionDigits: 2))）")
                                .font(OhanaFont.adaptive(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }

            // 其他费用折叠行
            Button {
                withAnimation(GoMotion.feedback) { showOtherFee.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showOtherFee ? "minus.circle" : "plus.circle")
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(showOtherFee ? "收起其他费用" : "添加其他费用（服务费等）")
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            if showOtherFee {
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(AppCurrency.symbol)
                            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        InlineNumericInput(
                            text: $otherFeeInput,
                            placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                            maxFractionDigits: 2,
                            accent: Color.goPrimary,
                            step: 5,
                            valueFont: .system(size: 15, weight: .semibold, design: .rounded),
                            fill: Color.clear,
                            cornerRadius: 10,
                            horizontalPadding: 4,
                            verticalPadding: 0
                        )
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 100)

                    TextField("费用说明（如：服务费）", text: $otherFeeNote)
                        .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded))
                        .padding(10)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 14)
    }

    private func modeTab(_ title: String, mode: PremiumInputMode) -> some View {
        Button { premiumMode = mode } label: {
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(premiumMode == mode ? Color.arkInk : .primary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(premiumMode == mode ? Color.goPrimary : .clear, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 付款频次 + 付款日区域

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("付款频次")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(InsurancePaymentFrequency.allCases, id: \.rawValue) { freq in
                    frequencyGridCell(freq)
                }
            }

            // 月/季：每月（季）几日
            if showPaymentDay {
                Divider().opacity(0.2)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("付款日")
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        Text(paymentFrequency == .monthly
                             ? "每月 \(paymentDay) 日扣款"
                             : "每季度 \(paymentDay) 日扣款")
                            .font(OhanaFont.adaptive(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if paymentDay > 1 { paymentDay -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 22))
                                .foregroundStyle(Color.goPrimary)
                        }
                        Text("\(paymentDay)")
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                            .frame(minWidth: 28)
                        Button {
                            if paymentDay < 28 { paymentDay += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 22))
                                .foregroundStyle(Color.goPrimary)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 按年 / 一次性：指定首期缴费日（与生成计划锚点一致）
            if showAnnualOrOncePaymentPicker {
                Divider().opacity(0.2)
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("缴费日期")
                    DatePicker(
                        "生效与首期缴费",
                        selection: $startDate,
                        in: Date.distantPast...Date.distantFuture,
                        displayedComponents: .date
                    )
                    .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded))
                    .tint(Color.goPrimary)
                    Text(paymentFrequency == .once
                         ? "一次性：仅按该日生成一笔保费记录。"
                         : "按年：每年与此日同月同日生成扣款，直至续期日前。")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 14)
    }

    private func frequencyGridCell(_ freq: InsurancePaymentFrequency) -> some View {
        Button {
            withAnimation(GoMotion.feedback) { paymentFrequency = freq }
        } label: {
            Text(freq.rawValue)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(paymentFrequency == freq ? Color.arkInk : .primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 6)
                .background(
                    paymentFrequency == freq ? Color.goPrimary : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 自动生成选项区域

    private var autoGenSection: some View {
        VStack(spacing: 0) {
            // 自动生成花费记录
            Toggle(isOn: $autoGenExpenses) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动生成全部付款记录")
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    let other = CountryDecimalInput.parse(otherFeeInput, countryCode: AppCountry.code) ?? 0
                    let perPeriod = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble) + other
                    Text("每期 \(AppCurrency.format(perPeriod, fractionDigits: 2)) · 按\(paymentFrequency.rawValue)写入花费")
                        .font(OhanaFont.adaptive(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .tint(Color.goPrimary)
            .padding(14)

            Divider().padding(.horizontal, 14).opacity(0.2)

            // 在日历中显示
            Toggle(isOn: $showInCalendar) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("在日历中显示缴费提醒")
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    Text("为每期付款日创建日历事件")
                        .font(OhanaFont.adaptive(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .tint(Color.goPrimary)
            .padding(14)
        }
        .goTranslucentCard(cornerRadius: 14)
    }

    // MARK: - Sub-views

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        TextField(placeholder, text: text, axis: axis)
            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
            .lineLimit(axis == .vertical ? 3 : 1)
            .padding(14)
            .goTranslucentCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func fieldNum(_ placeholder: String, text: Binding<String>) -> some View {
        InlineNumericInput(
            text: text,
            placeholder: placeholder,
            maxFractionDigits: 2,
            accent: Color.goPrimary,
            step: 100,
            valueFont: .system(size: 15, weight: .semibold, design: .rounded),
            valueAlignment: .leading,
            fill: Color.ohanaControlFill,
            cornerRadius: 14,
            horizontalPadding: 14,
            verticalPadding: 10
        )
    }

    // MARK: - Logic

    private func prefill() {
        guard let ins = existing else { return }
        productName       = ins.productName
        companyName       = ins.companyName
        policyNumber      = ins.policyNumber
        enablePolicyNumber = !ins.policyNumber.isEmpty
        coverageAmount    = ins.coverageAmount > 0 ? String(format: "%.2f", ins.coverageAmount) : ""
        enableCoverage    = ins.coverageAmount > 0
        startDate         = ins.startDate
        renewalDate       = ins.renewalDate
        notes             = ins.notes
        paymentFrequency  = ins.paymentFrequency
        paymentDay        = ins.paymentDayOfMonth
        showInCalendar    = ins.showInCalendar
        otherFeeNote      = ins.otherFeeNote
        if ins.otherFeeAmount > 0 {
            otherFeeInput = String(format: "%.2f", ins.otherFeeAmount)
            showOtherFee = true
        }
        // 回填时以年费模式展示
        premiumMode = .annual
        premiumInput = ins.annualPremium > 0 ? String(format: "%.2f", ins.annualPremium) : ""
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let existingID = existing?.id
        let command = DomainCommand.insurancePolicy(
            petID: pet.id,
            policyID: existingID ?? UUID(),
            action: existing == nil ? "create" : "update"
        )
        let input = makePolicyInput()
        commandQueue.enqueue(command) {
            InsuranceCommandExecutor(context: modelContext, services: appServices).savePolicy(
                existing: existing,
                pet: pet,
                input: input,
                note: existing == nil ? "insurance.policy.create" : "insurance.policy.update"
            )
            isSaving = false
            dismiss()
        }
    }

    private func makePolicyInput() -> InsurancePolicySaveCommandInput {
        InsurancePolicySaveCommandInput(
            companyName: companyName,
            policyNumber: enablePolicyNumber ? policyNumber : "",
            productName: productName,
            annualPremium: annualPremiumDouble,
            coverageAmount: enableCoverage
                ? (CountryDecimalInput.parse(coverageAmount, countryCode: AppCountry.code) ?? 0)
                : 0,
            startDate: startDate,
            renewalDate: renewalDate,
            notes: notes,
            paymentFrequency: paymentFrequency,
            paymentDayOfMonth: paymentDay,
            showInCalendar: showInCalendar,
            otherFeeAmount: CountryDecimalInput.parse(otherFeeInput, countryCode: AppCountry.code) ?? 0,
            otherFeeNote: otherFeeNote,
            autoGeneratesPayments: existing == nil && autoGenExpenses,
            executorId: appServices.activeHumanSelection.currentHumanId
        )
    }

}

// MARK: - Premium Input Mode

private enum PremiumInputMode {
    case annual, monthly
}
