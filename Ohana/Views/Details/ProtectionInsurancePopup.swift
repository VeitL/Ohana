//
//  ProtectionInsurancePopup.swift
//  Ohana
//
//  Inline V4 popup for creating and editing pet insurance policies.
//

import SwiftUI
import SwiftData

struct ProtectionInsurancePopup: View {
    let pet: Pet
    var existing: PetInsurance?
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var visible = false
    @State private var dragOffset: CGFloat = 0
    @State private var productName = ""
    @State private var companyName = ""
    @State private var policyNumber = ""
    @State private var hasPolicyNumber = false
    @State private var premiumInput = ""
    @State private var premiumMode: ProtectionPremiumMode = .annual
    @State private var coverageInput = ""
    @State private var hasCoverage = false
    @State private var startDate = Date()
    @State private var renewalDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var paymentFrequency: InsurancePaymentFrequency = .annual
    @State private var paymentDay = 1
    @State private var autoGenExpenses = true
    @State private var showInCalendar = false
    @State private var notes = ""

    private var isEdit: Bool { existing != nil }
    private var animation: Animation { GoMotion.page }
    private var hiddenOffset: CGFloat { 780 }
    private var canSave: Bool { !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var annualPremium: Double {
        let raw = CountryDecimalInput.parse(premiumInput, countryCode: AppCountry.code) ?? 0
        return premiumMode == .monthly ? raw * 12 : raw
    }
    private var coverageAmount: Double {
        hasCoverage ? (CountryDecimalInput.parse(coverageInput, countryCode: AppCountry.code) ?? 0) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: visible) {
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.black.opacity(0.34)], // ui-v4: allow popup scrimGradient
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .padding(.top, 8)
                        .gesture(handleDrag)

                    HStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 48, height: 48)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEdit ? "编辑保险" : "添加保险")
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(pet.name)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: close)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            basicBlock
                            premiumBlock
                            frequencyBlock
                            dateBlock
                            optionsBlock
                            popupBlock {
                                TextField("备注", text: $notes, axis: .vertical)
                                    .font(OhanaFont.subheadline(.bold))
                                    .lineLimit(2...4)
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxHeight: min(proxy.size.height * 0.62, 590))

                    Button(action: save) {
                        Text(isEdit ? "保存" : "添加")
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .background { OhanaPopupGlassSurface(cornerRadius: 52) }
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(color: Color.black.opacity(0.54), radius: 46, x: 0, y: -16) // ui-v4: allow popup liftedAlert shadow
                .shadow(color: Color(hex: "0B102C").opacity(0.38), radius: 26, x: 0, y: 12) // ui-v4: allow popup liftedAlert shadow
                .padding(.horizontal, 6)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                .offset(y: visible ? dragOffset : hiddenOffset)
            }
            .animation(animation, value: dragOffset)
        }
        .onAppear {
            prefill()
            withAnimation(animation) { visible = true }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var handleDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in dragOffset = max(0, value.translation.height) }
            .onEnded { value in
                if value.translation.height > 54 {
                    close()
                } else {
                    withAnimation(animation) { dragOffset = 0 }
                }
            }
    }

    private var basicBlock: some View {
        popupBlock {
            TextField("产品名称", text: $productName)
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            TextField("保险公司", text: $companyName)
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Toggle("保单号", isOn: $hasPolicyNumber)
                .font(OhanaFont.caption(.bold))
                .tint(Color.goPrimary)
            if hasPolicyNumber {
                TextField("保单号", text: $policyNumber)
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
    }

    private var premiumBlock: some View {
        popupBlock {
            HStack(spacing: 0) {
                modeTab("年费", mode: .annual)
                modeTab("月费", mode: .monthly)
            }
            .background(Color.ohanaControlFill, in: Capsule())

            InlineNumericInput(
                text: $premiumInput,
                placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                unit: AppCurrency.symbol,
                countryCode: AppCountry.code,
                maxFractionDigits: 2,
                accent: Color.goPrimary,
                step: 10,
                valueFont: .system(size: 28, weight: .black, design: .rounded),
                valueAlignment: .leading,
                fill: Color.ohanaCardSurfaceElevated,
                usesMiniKeypad: true
            )

            Toggle("保额", isOn: $hasCoverage)
                .font(OhanaFont.caption(.bold))
                .tint(Color.goPrimary)
            if hasCoverage {
                InlineNumericInput(
                    text: $coverageInput,
                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                    unit: AppCurrency.symbol,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    step: 100,
                    valueAlignment: .leading,
                    fill: Color.ohanaCardSurfaceElevated,
                    usesMiniKeypad: true
                )
            }
        }
    }

    private var frequencyBlock: some View {
        popupBlock {
            Text("缴费")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(InsurancePaymentFrequency.allCases, id: \.rawValue) { frequency in
                    Button {
                        withAnimation(GoMotion.feedback) { paymentFrequency = frequency }
                    } label: {
                        Text(frequency.rawValue)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(paymentFrequency == frequency ? Color.arkInk : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(paymentFrequency == frequency ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if paymentFrequency == .monthly || paymentFrequency == .quarterly {
                HStack {
                    Text("付款日")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Button { if paymentDay > 1 { paymentDay -= 1 } } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    Text("\(paymentDay)")
                        .font(OhanaFont.headline(.black))
                        .frame(minWidth: 28)
                    Button { if paymentDay < 28 { paymentDay += 1 } } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .foregroundStyle(Color.goPrimary)
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var dateBlock: some View {
        popupBlock {
            DatePicker("生效日期", selection: $startDate, displayedComponents: .date)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
            DatePicker("续期日期", selection: $renewalDate, in: startDate..., displayedComponents: .date)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
        }
    }

    private var optionsBlock: some View {
        popupBlock {
            Toggle("写入保费记录", isOn: $autoGenExpenses)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
                .disabled(isEdit)
            Toggle("日历提醒", isOn: $showInCalendar)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
        }
    }

    private func modeTab(_ title: String, mode: ProtectionPremiumMode) -> some View {
        Button {
            withAnimation(GoMotion.feedback) { premiumMode = mode }
        } label: {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(premiumMode == mode ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(premiumMode == mode ? Color.goPrimary : Color.clear, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func popupBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func prefill() {
        guard let existing else { return }
        productName = existing.productName
        companyName = existing.companyName
        policyNumber = existing.policyNumber
        hasPolicyNumber = !existing.policyNumber.isEmpty
        premiumInput = existing.annualPremium > 0 ? String(format: "%.2f", existing.annualPremium) : ""
        premiumMode = .annual
        coverageInput = existing.coverageAmount > 0 ? String(format: "%.2f", existing.coverageAmount) : ""
        hasCoverage = existing.coverageAmount > 0
        startDate = existing.startDate
        renewalDate = existing.renewalDate
        paymentFrequency = existing.paymentFrequency
        paymentDay = existing.paymentDayOfMonth
        showInCalendar = existing.showInCalendar
        notes = existing.notes
    }

    private func close() {
        GoKeyboard.dismiss()
        withAnimation(animation) {
            visible = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }

    private func save() {
        let savedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPolicyNumber = hasPolicyNumber ? policyNumber : ""
        if let existing {
            existing.productName = savedProduct
            existing.companyName = companyName
            existing.policyNumber = savedPolicyNumber
            existing.annualPremium = annualPremium
            existing.coverageAmount = coverageAmount
            existing.startDate = startDate
            existing.renewalDate = renewalDate
            existing.paymentFrequencyRaw = paymentFrequency.rawValue
            existing.paymentDayOfMonth = paymentDay
            existing.showInCalendar = showInCalendar
            existing.notes = notes
        } else {
            let insurance = PetInsurance(
                companyName: companyName,
                policyNumber: savedPolicyNumber,
                productName: savedProduct,
                annualPremium: annualPremium,
                coverageAmount: coverageAmount,
                startDate: startDate,
                renewalDate: renewalDate,
                notes: notes,
                paymentFrequency: paymentFrequency,
                paymentDayOfMonth: paymentDay,
                showInCalendar: showInCalendar,
                pet: pet
            )
            modelContext.insert(insurance)
            if autoGenExpenses && annualPremium > 0 {
                generatePaymentSchedule(for: insurance)
            }
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        close()
    }

    private func generatePaymentSchedule(for insurance: PetInsurance) {
        let dates = InsurancePaymentSchedule.dates(for: insurance, calendar: .current)
        let payerId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let name = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let perPeriod = insurance.paymentFrequency.periodAmount(fromAnnual: insurance.annualPremium)

        for (index, payDate) in dates.enumerated() {
            modelContext.insert(PetExpenseLog(
                date: payDate,
                amount: perPeriod,
                category: .insurancePremium,
                note: index == 0 ? "\(name) 首期保费" : "\(name) 保费",
                pet: pet,
                executorId: payerId
            ))

            if insurance.showInCalendar {
                modelContext.insert(Event(
                    title: "🛡️ \(name) 缴费",
                    startDate: payDate,
                    isAllDay: true,
                    eventType: EventType.insurancePremium.rawValue,
                    relatedEntityType: "pet_insurance",
                    relatedEntityId: insurance.id.uuidString
                ))
            }
        }
    }
}

private enum ProtectionPremiumMode {
    case annual
    case monthly
}
