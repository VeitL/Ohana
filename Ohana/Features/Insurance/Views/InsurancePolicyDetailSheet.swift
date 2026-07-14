//
//  InsurancePolicyDetailSheet.swift
//  Ohana
//
//  V4 insurance policy detail page.
//

import SwiftData
import SwiftUI

struct InsurancePolicyDetailSheet: View {
    let insurance: PetInsurance
    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showEdit = false
    @State private var showAddClaim = false
    @State private var showDeleteConfirm = false
    @State private var pendingPolicyCommand = false
    @State private var pendingClaimIDs: Set<UUID> = []

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
        }
        .sheet(isPresented: $showEdit) {
            ProtectionInsurancePopup(pet: pet, existing: insurance) {
                showEdit = false
            }
        }
        .sheet(isPresented: $showAddClaim) {
            InsuranceClaimPopup(insurance: insurance, pet: pet) {
                showAddClaim = false
            }
        }
        .alert(l.tr(zh: "删除保单？", en: "Delete policy?", de: "Police löschen?"), isPresented: $showDeleteConfirm) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                deletePolicy()
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
            Image(systemName: "shield.lefthalf.filled").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(Color.goPurple)
                .frame(width: 48, height: 48)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
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
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
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
                    RoundedRectangle(cornerRadius: OhanaRadius.tiny, style: .continuous)
                        .fill(Color.ohanaControlFill)
                    RoundedRectangle(cornerRadius: OhanaRadius.tiny, style: .continuous)
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
                    Image(systemName: "plus").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 38, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
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
                .frame(width: 10, height: 10) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.

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
                Text(claim.claimStatus.localizedLabel(l))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color(hex: claim.claimStatus.colorHex))
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .contextMenu {
            ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                if status != claim.claimStatus {
                    Button {
                        updateClaimStatus(claim, to: status)
                    } label: {
                        Label(l.tr(
                            zh: "标记为：\(status.localizedLabel(l))",
                            en: "Mark as: \(status.localizedLabel(l))",
                            de: "Markieren als: \(status.localizedLabel(l))"
                        ), systemImage: status.sfSymbol)
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                deleteClaim(claim)
            } label: {
                Label(l.tr(zh: "删除", en: "Delete", de: "Loeschen"), systemImage: "trash")
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
                setPolicyActive(!insurance.isActive)
            } label: {
                Image(systemName: insurance.isActive ? "pause.fill" : "play.fill")
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 52, height: 48)
                    .background(Color.ohanaCardSurface, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Image(systemName: "trash.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 52, height: 48)
                    .background(Color.ohanaCardSurface, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @MainActor
    private func updateClaimStatus(_ claim: InsuranceClaim, to status: ClaimStatus) {
        guard !pendingClaimIDs.contains(claim.id) else { return }
        pendingClaimIDs.insert(claim.id)
        let command = DomainCommand.insuranceClaim(
            petID: pet.id,
            policyID: insurance.id,
            claimID: claim.id,
            action: "status.\(status.rawValue)"
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).updateClaimStatus(
                    claim,
                    to: status,
                    insurance: insurance,
                    pet: pet,
                    executorId: activeExecutorID(),
                    note: "insurance.claim.status"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            pendingClaimIDs.remove(claim.id)
        }
    }

    private func deleteClaim(_ claim: InsuranceClaim) {
        guard !pendingClaimIDs.contains(claim.id) else { return }
        pendingClaimIDs.insert(claim.id)
        let command = DomainCommand.insuranceClaim(
            petID: pet.id,
            policyID: insurance.id,
            claimID: claim.id,
            action: "delete"
        )

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).deleteClaim(
                    claim,
                    insurance: insurance,
                    pet: pet,
                    note: "insurance.claim.delete"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            pendingClaimIDs.remove(claim.id)
        }
    }

    private func setPolicyActive(_ isActive: Bool) {
        guard !pendingPolicyCommand else { return }
        pendingPolicyCommand = true
        let command = DomainCommand.insurancePolicy(
            petID: pet.id,
            policyID: insurance.id,
            action: isActive ? "activate" : "deactivate"
        )

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).setPolicyActive(
                    insurance,
                    isActive: isActive,
                    pet: pet,
                    note: "insurance.policy.active"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            pendingPolicyCommand = false
        }
    }

    private func deletePolicy() {
        guard !pendingPolicyCommand else { return }
        pendingPolicyCommand = true
        let command = DomainCommand.insurancePolicy(
            petID: pet.id,
            policyID: insurance.id,
            action: "delete"
        )

        OhanaFeedback.light()
        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).deletePolicy(
                    insurance,
                    pet: pet,
                    note: "insurance.policy.delete"
                )
                dismiss()
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            pendingPolicyCommand = false
        }
    }

    private func activeExecutorID() -> String? {
        appServices.activeHumanSelection.currentHumanId
    }
}

private struct InsuranceClaimPopup: View {
    let insurance: PetInsurance
    let pet: Pet
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var incidentDate = Date()
    @State private var totalExpenseInput = ""
    @State private var claimedAmountInput = ""
    @State private var noteInput = ""
    @State private var initialStatus: ClaimStatus = .submitted
    @State private var isSaving = false

    private var l: L10n { L10n(appLanguage) }
    private var totalExpense: Double { CountryDecimalInput.parse(totalExpenseInput, countryCode: AppCountry.code) ?? 0 }
    private var claimedAmount: Double { CountryDecimalInput.parse(claimedAmountInput, countryCode: AppCountry.code) ?? 0 }
    private var canSave: Bool {
        !isSaving && totalExpense > 0 && claimedAmount > 0 && claimedAmount <= totalExpense
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        l.tr(zh: "就诊日期", en: "Visit date", de: "Besuchsdatum"),
                        selection: $incidentDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    TextField(l.tr(zh: "本次总花费", en: "Total expense", de: "Gesamtkosten"), text: $totalExpenseInput)
                        .keyboardType(.decimalPad)
                    TextField(l.tr(zh: "申请金额", en: "Claim amount", de: "Beantragter Betrag"), text: $claimedAmountInput)
                        .keyboardType(.decimalPad)
                    if claimedAmount > totalExpense, totalExpense > 0 {
                        Label(
                            l.tr(zh: "报销金额不能超过总花费", en: "Claim cannot exceed total", de: "Betrag darf Kosten nicht übersteigen"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(Color.goRed)
                    }
                } header: {
                    Text(insurance.productName.isEmpty ? pet.name : insurance.productName)
                }

                Section {
                    Picker(l.tr(zh: "状态", en: "Status", de: "Status"), selection: $initialStatus) {
                        ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField(l.tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)"), text: $noteInput, axis: .vertical)
                        .lineLimit(2 ... 4)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(l.tr(zh: "新增报销", en: "Add Claim", de: "Erstattung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel, action: close)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern"), action: save)
                        .disabled(!canSave)
                }
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
                                .frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            Text(status.rawValue)
                                .font(OhanaFont.caption(.black))
                                .lineLimit(1)
                        }
                        .foregroundStyle(initialStatus == status ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(initialStatus == status ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func popupBlock(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func close() {
        GoKeyboard.dismiss()
        onClose()
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        let now = Date()
        let executorId = appServices.activeHumanSelection.currentHumanId
        let input = InsuranceClaimCommandInput(
            claimDate: now,
            incidentDate: incidentDate,
            totalExpense: totalExpense,
            claimedAmount: claimedAmount,
            status: initialStatus,
            note: noteInput,
            executorId: executorId,
            approvedAt: initialStatus == .approved ? now : nil
        )
        let command = DomainCommand.insuranceClaim(
            petID: pet.id,
            policyID: insurance.id,
            claimID: nil,
            action: "create"
        )

        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).createClaim(
                    insurance: insurance,
                    pet: pet,
                    input: input,
                    note: "insurance.claim.create"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                close()
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }
}
