//
//  InsurancePolicyDetailSheet.swift
//  Ohana
//
//  保险保单详情页：保单信息、续期进度、报销记录列表、今日打卡报销
//

import SwiftUI
import SwiftData

struct InsurancePolicyDetailSheet: View {
    let insurance: PetInsurance
    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showAddClaim = false
    @State private var showDeleteConfirm = false

    private var sortedClaims: [InsuranceClaim] {
        insurance.claims.sorted { $0.claimDate > $1.claimDate }
    }

    private var totalApproved: Double {
        insurance.totalApprovedReimbursement
    }

    private var totalClaimed: Double {
        insurance.claims.reduce(0) { $0 + $1.claimedAmount }
    }

    // 保障期进度（0~1，仅保障中时有意义）
    private var coverageProgress: Double {
        let total = insurance.renewalDate.timeIntervalSince(insurance.startDate)
        let elapsed = Date().timeIntervalSince(insurance.startDate)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    private var daysLabel: String {
        let d = insurance.daysUntilRenewal
        if d < 0 { return "已过期 \(-d) 天" }
        if d == 0 { return "今日到期" }
        return "还有 \(d) 天续期"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 16) {
                        // 顶部保单头
                        headerSection
                        // Bento 信息格
                        bentoSection
                        // 报销记录
                        claimsSection
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(insurance.productName.isEmpty ? "保单详情" : insurance.productName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showEdit = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.goPrimary)
                        }
                        Menu {
                            Button {
                                insurance.isActive.toggle()
                                modelContext.safeSave()
                            } label: {
                                Label(insurance.isActive ? "停用保单" : "恢复保单",
                                      systemImage: insurance.isActive ? "pause.circle" : "play.circle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("删除保单", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddPetInsuranceSheet(pet: pet, existing: insurance)
            }
            .sheet(isPresented: $showAddClaim) {
                AddInsuranceClaimSheet(insurance: insurance, pet: pet)
            }
            .confirmationDialog("删除保单", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    modelContext.delete(insurance)
                    modelContext.safeSave()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后该保单及所有报销记录将无法恢复")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(insurance.productName.isEmpty ? "未命名保单" : insurance.productName)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text(insurance.renewalStatusLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color(hex: insurance.renewalStatusColor), in: Capsule())
                    }
                    if !insurance.companyName.isEmpty {
                        Text(insurance.companyName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !insurance.isActive {
                    Text("已停用")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.6), in: Capsule())
                }
            }

            // 续期进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(insurance.startDate.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(daysLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: insurance.renewalStatusColor))
                    Spacer()
                    Text(insurance.renewalDate.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: insurance.renewalStatusColor))
                            .frame(width: geo.size.width * coverageProgress, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 18)
    }

    // MARK: - Bento

    private var bentoSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            bentoCell(icon: "creditcard.fill", label: "年费",
                      value: insurance.annualPremium > 0
                        ? String(format: "¥%.0f", insurance.annualPremium) : "—",
                      accent: "4FC3F7")
            bentoCell(icon: "shield.fill", label: "保额",
                      value: insurance.coverageAmount > 0
                        ? String(format: "¥%.0f", insurance.coverageAmount) : "—",
                      accent: "81C784")
            bentoCell(icon: "repeat.circle.fill", label: "付款频次",
                      value: insurance.paymentFrequency.rawValue,
                      accent: "FFB74D")
            bentoCell(icon: "arrow.down.circle.fill", label: "已报销",
                      value: totalApproved > 0
                        ? String(format: "¥%.0f", totalApproved) : "暂无",
                      accent: "4ECDC4")
        }
    }

    private func bentoCell(icon: String, label: String, value: String, accent: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: accent))
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(minHeight: 90)
        .goTranslucentCard(cornerRadius: 16)
    }

    // MARK: - Claims Section

    private var claimsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("报销记录")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                if !insurance.claims.isEmpty {
                    Text("\(insurance.claims.count) 条")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
                Button { showAddClaim = true } label: {
                    Label("新增申请", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
            }

            if sortedClaims.isEmpty {
                claimsEmpty
            } else {
                // 汇总行
                HStack(spacing: 16) {
                    summaryPill(label: "已申请", value: String(format: "¥%.0f", totalClaimed), hex: "FFD93D")
                    summaryPill(label: "已到账", value: String(format: "¥%.0f", totalApproved), hex: "4ECDC4")
                }
                ForEach(sortedClaims) { claim in
                    claimRow(claim)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 18)
    }

    private var claimsEmpty: some View {
        VStack(spacing: 8) {
            Text("暂无报销记录")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("就诊后可新增报销申请，追踪报销进度")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func summaryPill(label: String, value: String, hex: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color(hex: hex)).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
        }
    }

    private func claimRow(_ claim: InsuranceClaim) -> some View {
        HStack(spacing: 12) {
            // 状态圆点
            Circle()
                .fill(Color(hex: claim.claimStatus.colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(claim.incidentDate.formatted(.dateTime.month().day()))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                    Text("就诊")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if !claim.note.isEmpty {
                    Text(claim.note)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "¥%.0f", claim.claimedAmount))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(claim.claimStatus.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color(hex: claim.claimStatus.colorHex), in: Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            // 状态更新
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

    // MARK: - Logic

    @MainActor
    private func updateClaimStatus(_ claim: InsuranceClaim, to status: ClaimStatus) {
        claim.statusRaw = status.rawValue
        if status == .approved && claim.approvedAmount == 0 {
            claim.approvedAmount = claim.claimedAmount
            claim.approvedAt = Date()
            // 写入负值 PetExpenseLog 代表报销到账
            if let claimPet = insurance.pet {
                let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
                let payerId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
                let expense = PetExpenseLog(
                    date: Date(),
                    amount: -claim.approvedAmount,
                    category: .insurancePremium,
                    note: "保险报销到账：\(productName)",
                    pet: claimPet,
                    executorId: payerId
                )
                modelContext.insert(expense)
            }
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
