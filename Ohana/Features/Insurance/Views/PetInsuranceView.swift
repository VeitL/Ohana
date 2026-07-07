//
//  PetInsuranceView.swift
//  Ohana
//
//  ArkSchemaV25：宠物保险记录页
//

import SwiftData
import SwiftUI

struct PetInsuranceContentView: View {
    let pet: Pet
    /// 嵌入「证件与保障」页时为 true：无 NavigationStack、无关闭按钮，内容不套外层 ScrollView
    var embedded: Bool = false
    let routeInsurances: [PetInsurance]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var showingAdd = false
    @State private var selectedInsurance: PetInsurance?
    @State private var insuranceToEdit: PetInsurance?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(pet: Pet, embedded: Bool = false, routeInsurances: [PetInsurance]) {
        self.pet = pet
        self.embedded = embedded
        self.routeInsurances = routeInsurances
    }

    private var sorted: [PetInsurance] {
        routeInsurances.sorted { $0.renewalDate > $1.renewalDate }
    }

    private var l: L10n { L10n(appLanguage) }

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
                    .navigationTitle(l.tr(zh: "🛡️ \(pet.name)的保险", en: "🛡️ \(pet.name)'s insurance", de: "🛡️ Versicherung von \(pet.name)"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) { dismiss() }
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
                Text(l.tr(zh: "保险", en: "Insurance", de: "Versicherung"))
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
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
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
            Text(l.tr(zh: "暂无保单，可记录续期与保额", en: "No policies yet. Track renewals and coverage.", de: "Noch keine Police. Erneuerung und Deckung erfassen."))
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Button { showingAdd = true } label: {
                Text(l.tr(zh: "添加保单", en: "Add policy", de: "Police hinzufügen"))
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
            Text(l.tr(zh: "暂无保险记录", en: "No insurance records", de: "Keine Versicherungen"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
            Text(l.tr(zh: "记录宠物保险保单，轻松追踪续期日期", en: "Save policies and keep renewal dates easy to track.", de: "Policen speichern und Erneuerungen im Blick behalten."))
                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
            Button { showingAdd = true } label: {
                Text(l.tr(zh: "添加保单", en: "Add policy", de: "Police hinzufügen"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
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
                                Text(ins.productName.isEmpty ? l.tr(zh: "未命名保单", en: "Untitled policy", de: "Unbenannte Police") : ins.productName)
                                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(renewalStatusLabel(for: ins))
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
                        statCell(label: l.tr(zh: "年费", en: "Annual", de: "Jährlich"),
                                 value: ins.annualPremium > 0 ? AppCurrency.format(ins.annualPremium, fractionDigits: 0) : "—")
                        Divider().frame(height: 32).opacity(0.2)
                        statCell(label: l.tr(zh: "保额", en: "Coverage", de: "Deckung"),
                                 value: ins.coverageAmount > 0 ? AppCurrency.format(ins.coverageAmount, fractionDigits: 0) : "—")
                        Divider().frame(height: 32).opacity(0.2)
                        statCell(label: l.tr(zh: "续期", en: "Renewal", de: "Erneuerung"),
                                 value: ins.renewalDate.formatted(.dateTime.year().month().day()))
                        if !ins.claims.isEmpty {
                            Divider().frame(height: 32).opacity(0.2)
                            statCell(label: l.tr(zh: "报销", en: "Claims", de: "Erstattungen"),
                                     value: l.tr(zh: "\(ins.claims.count) 条", en: "\(ins.claims.count)", de: "\(ins.claims.count)"))
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
                .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
            }
            .buttonStyle(ScaleButtonStyle())

            Menu {
                Button { insuranceToEdit = ins } label: {
                    Label(l.tr(zh: "编辑保单", en: "Edit policy", de: "Police bearbeiten"), systemImage: "pencil")
                }
                Button { selectedInsurance = ins } label: {
                    Label(l.tr(zh: "查看详情", en: "View details", de: "Details ansehen"), systemImage: "info.circle")
                }
                Divider()
                Button(role: .destructive) {
                    deletePolicy(ins)
                } label: {
                    Label(l.tr(zh: "删除", en: "Delete", de: "Löschen"), systemImage: "trash")
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
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).deletePolicy(
                    insurance,
                    pet: pet,
                    note: "insurance.policy.delete"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            Text(label).font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
        }.frame(maxWidth: .infinity)
    }

    private func renewalStatusLabel(for insurance: PetInsurance) -> String {
        let days = insurance.daysUntilRenewal
        if days < 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if days <= 30 {
            return l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig")
        }
        return l.tr(zh: "保障中", en: "Covered", de: "Aktiv")
    }
}
