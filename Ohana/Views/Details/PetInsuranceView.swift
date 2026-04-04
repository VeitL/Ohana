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
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var selectedInsurance: PetInsurance?
    @State private var insuranceToEdit: PetInsurance?

    private var sorted: [PetInsurance] {
        pet.insurances.sorted { $0.renewalDate > $1.renewalDate }
    }

    var body: some View {
        Group {
            if embedded {
                embeddedContent
                    .sheet(isPresented: $showingAdd) { AddPetInsuranceSheet(pet: pet) }
                    .sheet(item: $insuranceToEdit) { ins in
                        AddPetInsuranceSheet(pet: pet, existing: ins)
                    }
                    .sheet(item: $selectedInsurance) { ins in
                        InsurancePolicyDetailSheet(insurance: ins, pet: pet)
                    }
            } else {
                NavigationStack {
                    ZStack {
                        ArkBackgroundView()
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
                                Image(systemName: "plus.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.goPrimary).font(.system(size: 22))
                            }
                        }
                    }
                    .sheet(isPresented: $showingAdd) { AddPetInsuranceSheet(pet: pet) }
                    .sheet(item: $insuranceToEdit) { ins in
                        AddPetInsuranceSheet(pet: pet, existing: ins)
                    }
                    .sheet(item: $selectedInsurance) { ins in
                        InsurancePolicyDetailSheet(insurance: ins, pet: pet)
                    }
                }
            }
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("保险")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
                .buttonStyle(.plain)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Button { showingAdd = true } label: {
                Text("添加保单")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🛡️").font(.system(size: 56))
            Text("暂无保险记录").font(.system(size: 17, weight: .black, design: .rounded))
            Text("记录宠物保险保单，轻松追踪续期日期").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { showingAdd = true } label: {
                Text("添加保单").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.black)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
            }.buttonStyle(.plain)
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
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(ins.renewalStatusLabel)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: ins.renewalStatusColor), in: Capsule())
                            }
                            if !ins.companyName.isEmpty {
                                Text(ins.companyName)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 36)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 0) {
                        statCell(label: "年费",
                                 value: ins.annualPremium > 0 ? String(format: "¥%.0f", ins.annualPremium) : "—")
                        Divider().frame(height: 32).opacity(0.2)
                        statCell(label: "保额",
                                 value: ins.coverageAmount > 0 ? String(format: "¥%.0f", ins.coverageAmount) : "—")
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
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(16)
                .goTranslucentCard(cornerRadius: 18)
            }
            .buttonStyle(.plain)

            Menu {
                Button { insuranceToEdit = ins } label: {
                    Label("编辑保单", systemImage: "pencil")
                }
                Button { selectedInsurance = ins } label: {
                    Label("查看详情", systemImage: "info.circle")
                }
                Divider()
                Button(role: .destructive) {
                    modelContext.delete(ins)
                    modelContext.safeSave()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 14, weight: .black, design: .rounded))
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Add / Edit Sheet

struct AddPetInsuranceSheet: View {
    let pet: Pet
    var existing: PetInsurance? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
        let raw = Double(premiumInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch premiumMode {
        case .annual:   return raw
        case .monthly:  return raw * 12
        }
    }

    /// 每期保费（含其他费用）
    private var periodTotal: Double {
        let base = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble)
        let other = Double(otherFeeInput.replacingOccurrences(of: ",", with: ".")) ?? 0
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
                ArkBackgroundView()
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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(productName.isEmpty ? Color.primary.opacity(0.15) : Color.goPrimary,
                                            in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).disabled(productName.isEmpty)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
            }
            .navigationTitle(isEdit ? "编辑保单" : "添加保单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(.secondary)
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .tint(Color.goPrimary)
            if enablePolicyNumber {
                field("保单号", text: $policyNumber)
            }

            Toggle(isOn: $enableCoverage) {
                Text("填写保额")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                Text("¥")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                TextField("0.00", text: $premiumInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                Text(premiumMode == .annual ? "/ 年" : "/ 月")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            // 等价提示
            if annualPremiumDouble > 0 {
                let other = Double(otherFeeInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                let basePerPeriod = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble)
                VStack(alignment: .leading, spacing: 3) {
                    if premiumMode == .monthly {
                        Text("年总保费：¥\(String(format: "%.2f", annualPremiumDouble))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("每期缴纳：¥\(String(format: "%.2f", basePerPeriod + other))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        if other > 0 {
                            Text("（含其他费用 ¥\(String(format: "%.2f", other))）")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 其他费用折叠行
            Button {
                withAnimation(.spring(response: 0.3)) { showOtherFee.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showOtherFee ? "minus.circle" : "plus.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(showOtherFee ? "收起其他费用" : "添加其他费用（服务费等）")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showOtherFee {
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("¥")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $otherFeeInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 100)

                    TextField("费用说明（如：服务费）", text: $otherFeeNote)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(premiumMode == mode ? Color.arkInk : .primary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(premiumMode == mode ? Color.goPrimary : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
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
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(paymentFrequency == .monthly
                             ? "每月 \(paymentDay) 日扣款"
                             : "每季度 \(paymentDay) 日扣款")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if paymentDay > 1 { paymentDay -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.goPrimary)
                        }
                        Text("\(paymentDay)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .frame(minWidth: 28)
                        Button {
                            if paymentDay < 28 { paymentDay += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.goPrimary)
                        }
                    }
                    .buttonStyle(.plain)
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tint(Color.goPrimary)
                    Text(paymentFrequency == .once
                         ? "一次性：仅按该日生成一笔保费记录。"
                         : "按年：每年与此日同月同日生成扣款，直至续期日前。")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 14)
    }

    private func frequencyGridCell(_ freq: InsurancePaymentFrequency) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) { paymentFrequency = freq }
        } label: {
            Text(freq.rawValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
        .buttonStyle(.plain)
    }

    // MARK: - 自动生成选项区域

    private var autoGenSection: some View {
        VStack(spacing: 0) {
            // 自动生成花费记录
            Toggle(isOn: $autoGenExpenses) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动生成全部付款记录")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    let other = Double(otherFeeInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let perPeriod = paymentFrequency.periodAmount(fromAnnual: annualPremiumDouble) + other
                    Text("每期 ¥\(String(format: "%.2f", perPeriod)) · 按\(paymentFrequency.rawValue)写入花费")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.goPrimary)
            .padding(14)

            Divider().padding(.horizontal, 14).opacity(0.2)

            // 在日历中显示
            Toggle(isOn: $showInCalendar) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("在日历中显示缴费提醒")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("为每期付款日创建日历事件")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
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
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.45))
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        TextField(placeholder, text: text, axis: axis)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .lineLimit(axis == .vertical ? 3 : 1)
            .padding(14)
            .goTranslucentCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func fieldNum(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .padding(14)
            .goTranslucentCard(cornerRadius: 14)
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
        let savedPolicyNumber = enablePolicyNumber ? policyNumber : ""
        let coverageDouble = enableCoverage
            ? (Double(coverageAmount.replacingOccurrences(of: ",", with: ".")) ?? 0)
            : 0
        let otherDouble = Double(otherFeeInput.replacingOccurrences(of: ",", with: ".")) ?? 0

        if let ins = existing {
            ins.productName         = productName
            ins.companyName         = companyName
            ins.policyNumber        = savedPolicyNumber
            ins.annualPremium       = annualPremiumDouble
            ins.coverageAmount      = coverageDouble
            ins.startDate           = startDate
            ins.renewalDate         = renewalDate
            ins.notes               = notes
            ins.paymentFrequencyRaw = paymentFrequency.rawValue
            ins.paymentDayOfMonth   = paymentDay
            ins.showInCalendar      = showInCalendar
            ins.otherFeeAmount      = otherDouble
            ins.otherFeeNote        = otherFeeNote
        } else {
            let ins = PetInsurance(
                companyName: companyName,
                policyNumber: savedPolicyNumber,
                productName: productName,
                annualPremium: annualPremiumDouble,
                coverageAmount: coverageDouble,
                startDate: startDate,
                renewalDate: renewalDate,
                notes: notes,
                paymentFrequency: paymentFrequency,
                paymentDayOfMonth: paymentDay,
                showInCalendar: showInCalendar,
                otherFeeAmount: otherDouble,
                otherFeeNote: otherFeeNote,
                pet: pet
            )
            modelContext.insert(ins)

            // 生成全期付款计划（花费记录 + 可选日历事件）
            if autoGenExpenses && annualPremiumDouble > 0 {
                generatePaymentSchedule(for: ins)
            }
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    /// 按频次生成从 startDate 到 renewalDate 的全部付款记录
    private func generatePaymentSchedule(for ins: PetInsurance) {
        let cal = Calendar.current
        let otherDouble = Double(otherFeeInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        let perPeriodBase = ins.paymentFrequency.periodAmount(fromAnnual: ins.annualPremium)
        let perPeriod = perPeriodBase + otherDouble
        let name = ins.productName.isEmpty ? ins.companyName : ins.productName

        // 计算所有付款日期
        let dates = paymentDates(for: ins, calendar: cal)

        for (index, payDate) in dates.enumerated() {
            // 花费记录
            let expNote = index == 0
                ? "\(name) 首期保费\(otherDouble > 0 ? "（含\(ins.otherFeeNote.isEmpty ? "其他费用" : ins.otherFeeNote)）" : "")"
                : "\(name) 保费\(otherDouble > 0 ? "（含\(ins.otherFeeNote.isEmpty ? "其他费用" : ins.otherFeeNote)）" : "")"
            let expense = PetExpenseLog(
                date: payDate,
                amount: perPeriod,
                category: .insurancePremium,
                note: expNote,
                pet: pet
            )
            modelContext.insert(expense)

            // 日历事件
            if ins.showInCalendar {
                let event = Event(
                    title: "🛡️ \(name) 缴费",
                    startDate: payDate,
                    isAllDay: true,
                    eventType: EventType.insurancePremium.rawValue,
                    relatedEntityType: "pet_insurance",
                    relatedEntityId: ins.id.uuidString
                )
                modelContext.insert(event)
            }
        }
    }

    /// 计算从 startDate 到 renewalDate 的所有付款日期
    private func paymentDates(for ins: PetInsurance, calendar cal: Calendar) -> [Date] {
        var dates: [Date] = []
        let end = ins.renewalDate

        switch ins.paymentFrequency {
        case .once:
            dates.append(ins.startDate)

        case .annual:
            var d = ins.startDate
            while d <= end {
                dates.append(d)
                d = cal.date(byAdding: .year, value: 1, to: d) ?? d
            }

        case .monthly:
            // 找到 startDate 当月或次月的 paymentDay
            var d = firstPaymentDate(from: ins.startDate, day: ins.paymentDayOfMonth, calendar: cal, component: .month, componentValue: 1)
            while d <= end {
                dates.append(d)
                d = cal.date(byAdding: .month, value: 1, to: d) ?? d
            }

        case .quarterly:
            var d = firstPaymentDate(from: ins.startDate, day: ins.paymentDayOfMonth, calendar: cal, component: .month, componentValue: 3)
            while d <= end {
                dates.append(d)
                d = cal.date(byAdding: .month, value: 3, to: d) ?? d
            }
        }
        return dates
    }

    /// 找到从 referenceDate 起第一个满足「当月或之后最近一期 paymentDay 日」的日期
    private func firstPaymentDate(from reference: Date, day: Int, calendar cal: Calendar, component: Calendar.Component, componentValue: Int) -> Date {
        var comps = cal.dateComponents([.year, .month], from: reference)
        comps.day = day
        if let candidate = cal.date(from: comps), candidate >= reference {
            return candidate
        }
        // 当月付款日已过，往后推一期
        comps.month = (comps.month ?? 1) + componentValue
        return cal.date(from: comps) ?? reference
    }
}

// MARK: - Premium Input Mode

private enum PremiumInputMode {
    case annual, monthly
}
