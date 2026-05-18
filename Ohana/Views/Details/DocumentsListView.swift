//
//  DocumentsListView.swift
//  Ohana
//
//  V4 protection cockpit for documents, vaccine passport, and insurance.
//

import SwiftUI
import SwiftData

struct DocumentsListView: View {
    let pet: Pet
    var showsCloseButton: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: ProtectionSection = .documents
    @State private var showingAddDocument = false
    @State private var showingAddVaccine = false
    @State private var showingAddInsurance = false
    @State private var editingDoc: PetDocument?
    @State private var detailDoc: PetDocument?
    @State private var selectedInsurance: PetInsurance?
    @State private var editingInsurance: PetInsurance?
    @State private var deleteDocument: PetDocument?
    @State private var deleteInsurance: PetInsurance?

    private var l: L10n { L10n() }
    private var state: PetProtectionDashboardState { PetProtectionDashboardState(pet: pet) }

    private var sortedDocs: [PetDocument] {
        pet.documents.sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var vaccineLogs: [PetHealthLog] {
        pet.healthLogs
            .filter { $0.healthLogType == .vaccine }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
    }

    private var sortedInsurances: [PetInsurance] {
        pet.insurances.sorted { $0.renewalDate < $1.renewalDate }
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
            .disabled(showingAddDocument)
            .blur(radius: showingAddDocument ? 1.1 : 0)

            if showingAddDocument {
                ProtectionDocumentPopup(pet: pet) {
                    withAnimation(GoMotion.page) { showingAddDocument = false }
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddVaccine) {
            AddVaccineSheet(pet: pet)
        }
        .sheet(isPresented: $showingAddInsurance) {
            AddPetInsuranceSheet(pet: pet)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, pet: pet)
        }
        .sheet(item: $detailDoc) { doc in
            DocumentDetailSheet(doc: doc, pet: pet, onEdit: { editingDoc = doc })
        }
        .sheet(item: $selectedInsurance) { insurance in
            InsurancePolicyDetailSheet(insurance: insurance, pet: pet)
        }
        .sheet(item: $editingInsurance) { insurance in
            AddPetInsuranceSheet(pet: pet, existing: insurance)
        }
        .alert("删除证件？", isPresented: Binding(
            get: { deleteDocument != nil },
            set: { if !$0 { deleteDocument = nil } }
        )) {
            Button("取消", role: .cancel) { deleteDocument = nil }
            Button("删除", role: .destructive) {
                if let deleteDocument {
                    modelContext.delete(deleteDocument)
                    modelContext.safeSave()
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
                if let deleteInsurance {
                    modelContext.delete(deleteInsurance)
                    modelContext.safeSave()
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
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            statusMetric(title: "状态", value: overallRisk.label, tint: overallRisk.color)
            statusMetric(title: "证件", value: "\(state.documentCount)", tint: ProtectionSection.documents.tint)
            statusMetric(title: "疫苗", value: "\(state.vaccineCount)", tint: ProtectionSection.vaccines.tint)
            statusMetric(title: "保单", value: "\(state.insuranceCount)", tint: ProtectionSection.insurance.tint)
        }
    }

    private var overallRisk: ProtectionRiskLevel {
        let risks = [state.documentsRisk, state.vaccineRisk, state.insuranceRisk]
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
                Button { openAdd(for: selectedSection) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 38, height: 34)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
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
                            onEdit: { editingDoc = doc },
                            onDelete: { deleteDocument = doc }
                        )
                    }
                }
            case .vaccines:
                if vaccineLogs.isEmpty {
                    ProtectionEmptyState(
                        icon: "syringe",
                        title: "还没有疫苗记录",
                        actionTitle: "添加疫苗",
                        tint: selectedSection.tint
                    ) { openAdd(for: .vaccines) }
                } else {
                    ForEach(vaccineLogs) { log in
                        ProtectionVaccineRow(log: log) {
                            modelContext.delete(log)
                            modelContext.safeSave()
                        }
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
                            onEdit: { editingInsurance = insurance },
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
            showingAddDocument = true
        case .vaccines:
            showingAddVaccine = true
        case .insurance:
            showingAddInsurance = true
        }
    }
}
