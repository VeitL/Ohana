//
//  DocumentsListView.swift
//  Ohana
//
//  V4 protection cockpit for documents and insurance.
//

import SwiftUI
import SwiftData

struct DocumentsListView: View {
    let pet: Pet
    var showsCloseButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: ProtectionSection = .documents
    @State private var activePopup: ActiveProtectionPopup?
    @State private var detailDoc: PetDocument?
    @State private var selectedInsurance: PetInsurance?
    @State private var deleteDocument: PetDocument?
    @State private var deleteInsurance: PetInsurance?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n() }
    private var state: PetProtectionDashboardState { PetProtectionDashboardState(pet: pet) }

    private var sortedDocs: [PetDocument] {
        pet.documents
            .filter { $0.documentCategory != .vaccine && $0.documentCategory != .insurance }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var sortedInsurances: [PetInsurance] {
        pet.insurances.sorted { $0.renewalDate < $1.renewalDate }
    }

    private var showingInlinePopup: Bool {
        activePopup != nil
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusStrip
                    coreCards
                    selectedSectionList
                    Spacer(minLength: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
            .disabled(showingInlinePopup)
            .blur(radius: showingInlinePopup ? 1.1 : 0)

            if let activePopup {
                switch activePopup {
                case .addDocument:
                    ProtectionDocumentPopup(pet: pet, existing: nil) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(30)
                case .editDocument(let doc):
                    ProtectionDocumentPopup(pet: pet, existing: doc) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(30)
                case .addInsurance:
                    ProtectionInsurancePopup(pet: pet, existing: nil) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(31)
                case .editInsurance(let insurance):
                    ProtectionInsurancePopup(pet: pet, existing: insurance) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(31)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detailDoc) { doc in
            DocumentDetailSheet(doc: doc, pet: pet, onEdit: { activePopup = .editDocument(doc) })
        }
        .sheet(item: $selectedInsurance) { insurance in
            InsurancePolicyDetailSheet(insurance: insurance, pet: pet)
        }
        .alert("删除证件？", isPresented: Binding(
            get: { deleteDocument != nil },
            set: { if !$0 { deleteDocument = nil } }
        )) {
            Button("取消", role: .cancel) { deleteDocument = nil }
            Button("删除", role: .destructive) {
                if let target = deleteDocument {
                    let command = DomainCommand.petDocumentDelete(petID: pet.id, documentID: target.id)
                    commandQueue.enqueue(command) {
                        PetDocumentCommandExecutor(context: modelContext, services: appServices).deleteDocument(
                            target,
                            pet: pet,
                            note: "petDocument.delete"
                        )
                    }
                }
                deleteDocument = nil
            }
        }
        .alert("删除保单？", isPresented: Binding(
            get: { deleteInsurance != nil },
            set: { if !$0 { deleteInsurance = nil } }
        )) {
            Button("取消", role: .cancel) { deleteInsurance = nil }
            Button("删除", role: .destructive) {
                if let target = deleteInsurance {
                    let command = DomainCommand.insurancePolicy(
                        petID: pet.id,
                        policyID: target.id,
                        action: "delete"
                    )
                    commandQueue.enqueue(command) {
                        InsuranceCommandExecutor(context: modelContext, services: appServices).deletePolicy(
                            target,
                            pet: pet,
                            note: "insurance.policy.delete"
                        )
                    }
                }
                deleteInsurance = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ProtectionPetAvatar(pet: pet, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("证件保障")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if showsCloseButton {
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
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            statusMetric(title: "状态", value: overallRisk.label, tint: overallRisk.color)
            statusMetric(title: "证件", value: "\(state.documentCount)", tint: ProtectionSection.documents.tint)
            statusMetric(title: "保单", value: "\(state.insuranceCount)", tint: ProtectionSection.insurance.tint)
        }
    }

    private var overallRisk: ProtectionRiskLevel {
        let risks = [state.documentsRisk, state.insuranceRisk]
        if risks.contains(.expired) { return .expired }
        if risks.contains(.soon) { return .soon }
        if risks.allSatisfy({ $0 == .empty }) { return .empty }
        return .protected
    }

    private func statusMetric(title: String, value: String, tint: Color) -> some View {
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

    private var coreCards: some View {
        HStack(spacing: 10) {
            ForEach(ProtectionSection.allCases) { section in
                ProtectionCoreCard(
                    section: section,
                    count: state.count(for: section),
                    risk: state.risk(for: section),
                    nextDate: state.nextDate(for: section),
                    isSelected: selectedSection == section,
                    onSelect: {
                        withAnimation(GoMotion.page) { selectedSection = section }
                    },
                    onAdd: {
                        withAnimation(GoMotion.page) {
                            selectedSection = section
                            openAdd(for: section)
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var selectedSectionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(selectedSection.title, systemImage: selectedSection.icon)
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }

            switch selectedSection {
            case .documents:
                if sortedDocs.isEmpty {
                    ProtectionEmptyState(
                        icon: "doc.badge.plus",
                        title: "还没有证件",
                        actionTitle: "添加证件",
                        tint: selectedSection.tint
                    ) { openAdd(for: .documents) }
                } else {
                    ForEach(sortedDocs) { doc in
                        DocumentDetailRow(
                            doc: doc,
                            onDetail: { detailDoc = doc },
                            onEdit: { activePopup = .editDocument(doc) },
                            onDelete: { deleteDocument = doc }
                        )
                    }
                }
            case .insurance:
                if sortedInsurances.isEmpty {
                    ProtectionEmptyState(
                        icon: "shield",
                        title: "还没有保单",
                        actionTitle: "添加保单",
                        tint: selectedSection.tint
                    ) { openAdd(for: .insurance) }
                } else {
                    ForEach(sortedInsurances) { insurance in
                        ProtectionInsuranceRow(
                            insurance: insurance,
                            onDetail: { selectedInsurance = insurance },
                            onEdit: { activePopup = .editInsurance(insurance) },
                            onDelete: { deleteInsurance = insurance }
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func openAdd(for section: ProtectionSection) {
        switch section {
        case .documents:
            activePopup = .addDocument
        case .insurance:
            activePopup = .addInsurance
        }
    }
}

private enum ActiveProtectionPopup: Identifiable {
    case addDocument
    case editDocument(PetDocument)
    case addInsurance
    case editInsurance(PetInsurance)

    var id: String {
        switch self {
        case .addDocument:
            return "addDocument"
        case .editDocument(let doc):
            return "editDocument-\(doc.id.uuidString)"
        case .addInsurance:
            return "addInsurance"
        case .editInsurance(let insurance):
            return "editInsurance-\(insurance.id.uuidString)"
        }
    }
}
