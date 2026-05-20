//
//  InsurancePolicyDetailSheet.swift
//  Ohana
//
//  V4 insurance policy detail page.
//

import SwiftUI
import SwiftData

struct InsurancePolicyDetailSheet: View {
    let insurance: PetInsurance
    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var showEdit = false
    @State private var showAddClaim = false
    @State private var showDeleteConfirm = false

    private var l: L10n { L10n(appLanguage) }

    private var sortedClaims: [InsuranceClaim] {
        insurance.claims.sorted { $0.claimDate > $1.claimDate }
    }

    private var totalApproved: Double {
        insurance.totalApprovedReimbursement
    }

    private var totalClaimed: Double {
        insurance.claims.reduce(0) { $0 + $1.claimedAmount }
    }

    private var coverageProgress: Double {
        let total = insurance.renewalDate.timeIntervalSince(insurance.startDate)
        let elapsed = Date().timeIntervalSince(insurance.startDate)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    private var daysLabel: String {
        let d = insurance.daysUntilRenewal
        if d < 0 { return l.tr(zh: "逾期 \(-d) 天", en: "\(-d)d overdue", de: "\(-d) T. überfällig") }
        if d == 0 { return l.tr(zh: "今日续期", en: "Renew today", de: "Heute fällig") }
        return l.tr(zh: "\(d) 天", en: "\(d)d", de: "\(d) T.")
    }

    private var hasPopup: Bool {
        showEdit || showAddClaim
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    policyStatus
                    metricStrip
                    claimsSection
                    actionRow
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
            .disabled(hasPopup)
            .blur(radius: hasPopup ? 1.1 : 0)

            if showEdit {
                ProtectionInsurancePopup(pet: pet, existing: insurance) {
                    withAnimation(GoMotion.page) { showEdit = false }
                }
                .transition(.opacity)
                .zIndex(30)
            }

            if showAddClaim {
                InsuranceClaimPopup(insurance: insurance, pet: pet) {
                    withAnimation(GoMotion.page) { showAddClaim = false }
                }
                .transition(.opacity)
                .zIndex(31)
            }
        }
        .alert(l.tr(zh: "删除保单？", en: "Delete policy?", de: "Police löschen?"), isPresented: $showDeleteConfirm) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                modelContext.delete(insurance)
                modelContext.safeSave()
                dismiss()
            }
        } message: {
            Text(l.tr(
                zh: "删除后该保单及所有报销记录将无法恢复。",
                en: "This policy and all claims will be deleted permanently.",
                de: "Diese Police und alle Erstattungen werden dauerhaft gelöscht."
            ))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.goPurple)
                .frame(width: 48, height: 48)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(insurance.productName.isEmpty ? l.tr(zh: "保单详情", en: "Policy", de: "Police") : insurance.productName)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(insurance.companyName.isEmpty ? pet.name : insurance.companyName)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var policyStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(insurance.renewalStatusLabel)
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color(hex: insurance.renewalStatusColor))
                Spacer()
                Text(daysLabel)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color(hex: insurance.renewalStatusColor))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(hex: insurance.renewalStatusColor).opacity(0.16), in: Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.ohanaControlFill)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: insurance.renewalStatusColor))
                        .frame(width: geo.size.width * coverageProgress)
                }
            }
            .frame(height: 10)

            HStack {
                Text(insurance.startDate.formatted(.dateTime.year().month().day()))
                Spacer()
                Text(insurance.renewalDate.formatted(.dateTime.year().month().day()))
            }
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 12) {
            metric(l.tr(zh: "保费", en: "Premium", de: "Prämie"), insurance.annualPremium > 0 ? AppCurrency.format(insurance.annualPremium, fractionDigits: 0) : "—", Color.goPrimary)
            metric(l.tr(zh: "保额", en: "Coverage", de: "Deckung"), insurance.coverageAmount > 0 ? AppCurrency.format(insurance.coverageAmount, fractionDigits: 0) : "—", Color.goTeal)
            metric(l.tr(zh: "报销", en: "Paid", de: "Erstattet"), totalApproved > 0 ? AppCurrency.format(totalApproved, fractionDigits: 0) : "—", Color.goPurple)
        }
    }

    private func metric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var claimsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(l.tr(zh: "报销", en: "Claims", de: "Erstattungen"), systemImage: "arrow.down.circle.fill")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button { withAnimation(GoMotion.page) { showAddClaim = true } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 38, height: 34)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if sortedClaims.isEmpty {
                ProtectionEmptyState(
                    icon: "arrow.down.doc.fill",
                    title: l.tr(zh: "还没有报销", en: "No claims yet", de: "Noch keine Erstattung"),
                    actionTitle: l.tr(zh: "新增报销", en: "Add claim", de: "Hinzufügen"),
                    tint: Color.goPurple
                ) { withAnimation(GoMotion.page) { showAddClaim = true } }
            } else {
                HStack(spacing: 12) {
                    metric(l.tr(zh: "申请", en: "Claimed", de: "Beantragt"), AppCurrency.format(totalClaimed, fractionDigits: 0), Color.goYellow)
                    metric(l.tr(zh: "到账", en: "Approved", de: "Genehmigt"), AppCurrency.format(totalApproved, fractionDigits: 0), Color.goTeal)
                }
                ForEach(sortedClaims) { claim in
                    claimRow(claim)
                }
            }
        }
    }

    private func claimRow(_ claim: InsuranceClaim) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: claim.claimStatus.colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(claim.incidentDate.formatted(.dateTime.year().month().day()))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !claim.note.isEmpty {
                    Text(claim.note)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(AppCurrency.format(claim.claimedAmount, fractionDigits: 0))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(claim.claimStatus.rawValue)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color(hex: claim.claimStatus.colorHex))
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                if status != claim.claimStatus {
                    Button {
                        updateClaimStatus(claim, to: status)
                    } label: {
                        Label("标记为：\(status.rawValue)", systemImage: status.sfSymbol)
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(claim)
                modelContext.safeSave()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { withAnimation(GoMotion.page) { showEdit = true } } label: {
                Label(l.tr(zh: "编辑保单", en: "Edit", de: "Bearbeiten"), systemImage: "pencil")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                insurance.isActive.toggle()
                modelContext.safeSave()
            } label: {
                Image(systemName: insurance.isActive ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 52, height: 48)
                    .background(Color.ohanaCardSurface, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 52, height: 48)
                    .background(Color.ohanaCardSurface, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @MainActor
    private func updateClaimStatus(_ claim: InsuranceClaim, to status: ClaimStatus) {
        claim.statusRaw = status.rawValue
        if status == .approved && claim.approvedAmount == 0 {
            claim.approvedAmount = claim.claimedAmount
            let approvedDate = Date()
            claim.approvedAt = approvedDate
            writeReimbursementIfNeeded(amount: claim.approvedAmount, approvedDate: approvedDate)
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func writeReimbursementIfNeeded(amount: Double, approvedDate: Date) {
        guard amount > 0, let claimPet = insurance.pet else { return }
        let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: productName)
        let payerId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        if InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: claimPet.expenseLogs,
            date: approvedDate,
            amount: amount,
            note: note
        ) {
            modelContext.insert(PetExpenseLog(
                date: approvedDate,
                amount: -amount,
                category: .insurancePremium,
                note: note,
                pet: claimPet,
                executorId: payerId
            ))
        }
    }
}

private struct InsuranceClaimPopup: View {
    let insurance: PetInsurance
    let pet: Pet
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var visible = false
    @State private var dragOffset: CGFloat = 0
    @State private var incidentDate = Date()
    @State private var totalExpenseInput = ""
    @State private var claimedAmountInput = ""
    @State private var noteInput = ""
    @State private var initialStatus: ClaimStatus = .submitted

    private var l: L10n { L10n(appLanguage) }
    private var animation: Animation { GoMotion.page }
    private var hiddenOffset: CGFloat { 740 }
    private var totalExpense: Double { CountryDecimalInput.parse(totalExpenseInput, countryCode: AppCountry.code) ?? 0 }
    private var claimedAmount: Double { CountryDecimalInput.parse(claimedAmountInput, countryCode: AppCountry.code) ?? 0 }
    private var canSave: Bool { totalExpense > 0 && claimedAmount > 0 && claimedAmount <= totalExpense }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
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
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 48, height: 48)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "新增报销", en: "Add Claim", de: "Erstattung"))
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(insurance.productName.isEmpty ? pet.name : insurance.productName)
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
                            popupBlock {
                                DatePicker(l.tr(zh: "就诊日期", en: "Visit date", de: "Besuchsdatum"), selection: $incidentDate, in: ...Date(), displayedComponents: .date)
                                    .font(OhanaFont.subheadline(.bold))
                                    .tint(Color.goPrimary)
                            }
                            popupBlock {
                                InlineNumericInput(
                                    text: $totalExpenseInput,
                                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                                    unit: AppCurrency.symbol,
                                    countryCode: AppCountry.code,
                                    maxFractionDigits: 2,
                                    accent: Color.goPrimary,
                                    step: 10,
                                    valueFont: .system(size: 26, weight: .black, design: .rounded),
                                    valueAlignment: .leading,
                                    fill: Color.ohanaCardSurfaceElevated,
                                    usesMiniKeypad: true
                                )
                                Text(l.tr(zh: "本次总花费", en: "Total expense", de: "Gesamtkosten"))
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            popupBlock {
                                InlineNumericInput(
                                    text: $claimedAmountInput,
                                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                                    unit: AppCurrency.symbol,
                                    countryCode: AppCountry.code,
                                    maxFractionDigits: 2,
                                    accent: Color.goPrimary,
                                    step: 10,
                                    valueFont: .system(size: 26, weight: .black, design: .rounded),
                                    valueAlignment: .leading,
                                    fill: Color.ohanaCardSurfaceElevated,
                                    usesMiniKeypad: true
                                )
                                Text(l.tr(zh: "申请金额", en: "Claim amount", de: "Beantragter Betrag"))
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                if claimedAmount > totalExpense && totalExpense > 0 {
                                    Text(l.tr(zh: "报销金额不能超过总花费", en: "Claim cannot exceed total", de: "Betrag darf Kosten nicht übersteigen"))
                                        .font(OhanaFont.caption2(.black))
                                        .foregroundStyle(Color.goRed)
                                }
                            }
                            statusBlock
                            popupBlock {
                                TextField(l.tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)"), text: $noteInput, axis: .vertical)
                                    .font(OhanaFont.subheadline(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(2...4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxHeight: min(proxy.size.height * 0.62, 590))

                    Button(action: save) {
                        Text(l.tr(zh: "保存", en: "Save", de: "Sichern"))
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
            .animation(animation, value: visible)
            .animation(animation, value: dragOffset)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            withAnimation(animation) { visible = true }
        }
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

    private var statusBlock: some View {
        popupBlock {
            Text(l.tr(zh: "状态", en: "Status", de: "Status"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                    Button {
                        withAnimation(GoMotion.feedback) { initialStatus = status }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: status.colorHex))
                                .frame(width: 7, height: 7)
                            Text(status.rawValue)
                                .font(OhanaFont.caption(.black))
                                .lineLimit(1)
                        }
                        .foregroundStyle(initialStatus == status ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(initialStatus == status ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func popupBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        let claim = InsuranceClaim(
            claimDate: Date(),
            incidentDate: incidentDate,
            totalExpense: totalExpense,
            claimedAmount: claimedAmount,
            approvedAmount: initialStatus == .approved ? claimedAmount : 0,
            status: initialStatus,
            note: noteInput,
            insurance: insurance
        )
        if initialStatus == .approved {
            claim.approvedAt = Date()
        }
        modelContext.insert(claim)

        if initialStatus == .approved, claimedAmount > 0 {
            let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
            let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: productName)
            let payerId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
            if InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
                existingLogs: pet.expenseLogs,
                date: Date(),
                amount: claimedAmount,
                note: note
            ) {
                modelContext.insert(PetExpenseLog(
                    date: Date(),
                    amount: -claimedAmount,
                    category: .insurancePremium,
                    note: note,
                    pet: pet,
                    executorId: payerId
                ))
            }
        }

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        close()
    }
}
