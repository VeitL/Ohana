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
                .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
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
