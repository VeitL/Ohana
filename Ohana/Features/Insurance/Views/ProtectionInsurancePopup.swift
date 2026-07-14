//
//  ProtectionInsurancePopup.swift
//  Ohana
//
//  Native sheet form for creating and editing pet insurance policies.
//

import SwiftData
import SwiftUI

struct ProtectionInsurancePopup: View {
    let pet: Pet
    var existing: PetInsurance?
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
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
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isEdit: Bool { existing != nil }
    private var l: L10n { L10n(appLanguage) }
    private var canSave: Bool { !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var annualPremium: Double {
        let raw = CountryDecimalInput.parse(premiumInput, countryCode: AppCountry.code) ?? 0
        return premiumMode == .monthly ? raw * 12 : raw
    }

    private var coverageAmount: Double {
        hasCoverage ? (CountryDecimalInput.parse(coverageInput, countryCode: AppCountry.code) ?? 0) : 0
    }

    private var primaryButtonTitle: String {
        if isSaving {
            return l.tr(zh: "保存中", en: "Saving", de: "Speichern")
        }
        return isEdit
            ? l.tr(zh: "保存", en: "Save", de: "Speichern")
            : l.tr(zh: "添加", en: "Add", de: "Hinzufuegen")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(l.tr(zh: "产品名称", en: "Product name", de: "Produktname"), text: $productName)
                    TextField(l.tr(zh: "保险公司", en: "Insurance company", de: "Versicherer"), text: $companyName)
                    Toggle(l.tr(zh: "保单号", en: "Policy number", de: "Policennummer"), isOn: $hasPolicyNumber)
                        .tint(Color.goPrimary)
                    if hasPolicyNumber {
                        TextField(l.tr(zh: "保单号", en: "Policy number", de: "Policennummer"), text: $policyNumber)
                    }
                } header: {
                    Text(pet.name)
                }

                Section {
                    Picker(l.tr(zh: "保费模式", en: "Premium mode", de: "Prämienmodus"), selection: $premiumMode) {
                        Text(l.tr(zh: "年费", en: "Annual", de: "Jährlich")).tag(ProtectionPremiumMode.annual)
                        Text(l.tr(zh: "月费", en: "Monthly", de: "Monatlich")).tag(ProtectionPremiumMode.monthly)
                    }
                    .pickerStyle(.segmented)
                    TextField(l.tr(zh: "保费", en: "Premium", de: "Prämie"), text: $premiumInput)
                        .keyboardType(.decimalPad)
                    Toggle(l.tr(zh: "保额", en: "Coverage amount", de: "Deckungssumme"), isOn: $hasCoverage)
                        .tint(Color.goPrimary)
                    if hasCoverage {
                        TextField(l.tr(zh: "保额", en: "Coverage amount", de: "Deckungssumme"), text: $coverageInput)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text(l.tr(zh: "保障", en: "Coverage", de: "Deckung"))
                }

                Section {
                    Picker(l.tr(zh: "缴费频率", en: "Payment frequency", de: "Zahlungsintervall"), selection: $paymentFrequency) {
                        ForEach(InsurancePaymentFrequency.allCases, id: \.rawValue) { frequency in
                            Text(frequency.localizedLabel(l)).tag(frequency)
                        }
                    }
                    if paymentFrequency == .monthly || paymentFrequency == .quarterly {
                        Stepper(
                            l.tr(zh: "付款日 \(paymentDay)", en: "Payment day \(paymentDay)", de: "Zahlungstag \(paymentDay)"),
                            value: $paymentDay,
                            in: 1 ... 28
                        )
                    }
                }

                Section {
                    DatePicker(l.tr(zh: "生效日期", en: "Start date", de: "Startdatum"), selection: $startDate, displayedComponents: .date)
                    DatePicker(l.tr(zh: "续期日期", en: "Renewal date", de: "Verlängerungsdatum"), selection: $renewalDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    Toggle(l.tr(zh: "写入保费记录", en: "Create premium record", de: "Prämienausgabe erfassen"), isOn: $autoGenExpenses)
                        .tint(Color.goPrimary)
                        .disabled(isEdit)
                    Toggle(l.tr(zh: "日历提醒", en: "Calendar reminder", de: "Kalendererinnerung"), isOn: $showInCalendar)
                        .tint(Color.goPrimary)
                }

                Section {
                    TextField(l.tr(zh: "备注", en: "Notes", de: "Notizen"), text: $notes, axis: .vertical)
                        .lineLimit(2 ... 4)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEdit
                ? l.tr(zh: "编辑保险", en: "Edit insurance", de: "Versicherung bearbeiten")
                : l.tr(zh: "添加保险", en: "Add insurance", de: "Versicherung hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel, action: close)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryButtonTitle, action: save)
                        .disabled(!canSave || isSaving)
                }
            }
        }
        .onAppear(perform: prefill)
    }

    private var basicBlock: some View {
        popupBlock {
            TextField(l.tr(zh: "产品名称", en: "Product name", de: "Produktname"), text: $productName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            TextField(l.tr(zh: "保险公司", en: "Insurance company", de: "Versicherer"), text: $companyName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Toggle(l.tr(zh: "保单号", en: "Policy number", de: "Policennummer"), isOn: $hasPolicyNumber)
                .font(OhanaFont.caption(.bold))
                .tint(Color.goPrimary)
            if hasPolicyNumber {
                TextField(l.tr(zh: "保单号", en: "Policy number", de: "Policennummer"), text: $policyNumber) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
    }

    private var premiumBlock: some View {
        popupBlock {
            HStack(spacing: 0) {
                modeTab(l.tr(zh: "年费", en: "Annual", de: "Jaehrlich"), mode: .annual)
                modeTab(l.tr(zh: "月费", en: "Monthly", de: "Monatlich"), mode: .monthly)
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

            Toggle(l.tr(zh: "保额", en: "Coverage amount", de: "Deckungssumme"), isOn: $hasCoverage)
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
            Text(l.tr(zh: "缴费", en: "Payment", de: "Zahlung"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(InsurancePaymentFrequency.allCases, id: \.rawValue) { frequency in
                    Button {
                        withAnimation(GoMotion.feedback) { paymentFrequency = frequency }
                    } label: {
                        Text(frequency.localizedLabel(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(paymentFrequency == frequency ? Color.arkInk : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(paymentFrequency == frequency ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if paymentFrequency == .monthly || paymentFrequency == .quarterly {
                HStack {
                    Text(l.tr(zh: "付款日", en: "Payment day", de: "Zahlungstag"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Button { if paymentDay > 1 { paymentDay -= 1 } } label: {
                        Image(systemName: "minus.circle.fill").accessibilityHidden(true)
                    }
                    Text("\(paymentDay)")
                        .font(OhanaFont.headline(.black))
                        .frame(minWidth: 28)
                    Button { if paymentDay < 28 { paymentDay += 1 } } label: {
                        Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                    }
                }
                .foregroundStyle(Color.goPrimary)
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var dateBlock: some View {
        popupBlock {
            DatePicker(l.tr(zh: "生效日期", en: "Start date", de: "Startdatum"), selection: $startDate, displayedComponents: .date)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
            DatePicker(l.tr(zh: "续期日期", en: "Renewal date", de: "Verlaengerungsdatum"), selection: $renewalDate, in: startDate..., displayedComponents: .date)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
        }
    }

    private var optionsBlock: some View {
        popupBlock {
            Toggle(l.tr(zh: "写入保费记录", en: "Create premium record", de: "Praemienausgabe erfassen"), isOn: $autoGenExpenses)
                .font(OhanaFont.subheadline(.bold))
                .tint(Color.goPrimary)
                .disabled(isEdit)
            Toggle(l.tr(zh: "日历提醒", en: "Calendar reminder", de: "Kalendererinnerung"), isOn: $showInCalendar)
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

    private func popupBlock(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
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
        onClose()
    }

    private func save() {
        guard !isSaving else { return }
        let savedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPolicyNumber = hasPolicyNumber ? policyNumber : ""
        let existingID = existing?.id
        let command = DomainCommand.insurancePolicy(
            petID: pet.id,
            policyID: existingID ?? UUID(),
            action: existing == nil ? "create" : "update"
        )
        let input = InsurancePolicySaveCommandInput(
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
            otherFeeAmount: 0,
            otherFeeNote: "",
            autoGeneratesPayments: existing == nil && autoGenExpenses,
            executorId: appServices.activeHumanSelection.currentHumanId
        )
        isSaving = true
        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).savePolicy(
                    existing: existing,
                    pet: pet,
                    input: input,
                    note: existing == nil ? "insurance.policy.create" : "insurance.policy.update"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                close()
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            isSaving = false
        }
    }
}

private enum ProtectionPremiumMode: Hashable {
    case annual
    case monthly
}
