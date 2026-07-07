//
//  DocumentsListView.swift
//  Ohana
//
//  V4 protection cockpit for documents and insurance.
//

import SwiftData
import SwiftUI

struct DocumentsListContentView: View {
    let pet: Pet
    var showsCloseButton: Bool = true

    let routeDocuments: [PetDocument]
    let routeInsurances: [PetInsurance]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedSection: ProtectionSection = .documents
    @State private var activePopup: ActiveProtectionPopup?
    @State private var detailDoc: PetDocument?
    @State private var selectedInsurance: PetInsurance?
    @State private var deleteDocument: PetDocument?
    @State private var deleteInsurance: PetInsurance?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var state: PetProtectionDashboardState {
        PetProtectionDashboardState(documents: sortedDocs, insurances: sortedInsurances)
    }

    init(
        pet: Pet,
        showsCloseButton: Bool = true,
        routeDocuments: [PetDocument],
        routeInsurances: [PetInsurance]
    ) {
        self.pet = pet
        self.showsCloseButton = showsCloseButton
        self.routeDocuments = routeDocuments
        self.routeInsurances = routeInsurances
    }

    private var sortedDocs: [PetDocument] {
        routeDocuments
            .filter { $0.documentCategory != .vaccine && $0.documentCategory != .insurance }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var sortedInsurances: [PetInsurance] {
        routeInsurances.sorted { $0.renewalDate < $1.renewalDate }
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
                case let .editDocument(doc):
                    ProtectionDocumentPopup(pet: pet, existing: doc) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(30)
                case .addInsurance:
                    ProtectionInsurancePopup(pet: pet, existing: nil) {
                        withAnimation(GoMotion.page) { self.activePopup = nil }
                    }
                    .zIndex(31)
                case let .editInsurance(insurance):
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
        .alert(l.tr(zh: "删除证件？", en: "Delete document?", de: "Dokument löschen?"), isPresented: Binding(
            get: { deleteDocument != nil },
            set: { if !$0 { deleteDocument = nil } }
        )) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { deleteDocument = nil }
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                if let target = deleteDocument {
                    let command = DomainCommand.petDocumentDelete(petID: pet.id, documentID: target.id)
                    commandQueue.enqueue(command) {
                        do {
                            try PetDocumentCommandExecutor(context: modelContext, services: appServices).deleteDocument(
                                target,
                                pet: pet,
                                note: "petDocument.delete"
                            )
                        } catch {
                            appServices.domainRevisions.publishFailure(command: command, error: error)
                        }
                    }
                }
                deleteDocument = nil
            }
        }
        .alert(l.tr(zh: "删除保单？", en: "Delete policy?", de: "Police löschen?"), isPresented: Binding(
            get: { deleteInsurance != nil },
            set: { if !$0 { deleteInsurance = nil } }
        )) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { deleteInsurance = nil }
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                if let target = deleteInsurance {
                    let command = DomainCommand.insurancePolicy(
                        petID: pet.id,
                        policyID: target.id,
                        action: "delete"
                    )
                    commandQueue.enqueue(command) {
                        do {
                            try InsuranceCommandExecutor(context: modelContext, services: appServices).deletePolicy(
                                target,
                                pet: pet,
                                note: "insurance.policy.delete"
                            )
                        } catch {
                            appServices.domainRevisions.publishFailure(command: command, error: error)
                        }
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
                Text(l.tr(zh: "证件保障", en: "Documents and protection", de: "Dokumente und Schutz"))
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
            statusMetric(title: l.tr(zh: "状态", en: "Status", de: "Status"), value: overallRisk.label(l), tint: overallRisk.color)
            statusMetric(title: ProtectionSection.documents.title(l), value: "\(state.documentCount)", tint: ProtectionSection.documents.tint)
            statusMetric(title: l.tr(zh: "保单", en: "Policies", de: "Policen"), value: "\(state.insuranceCount)", tint: ProtectionSection.insurance.tint)
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
                Label(selectedSection.title(l), systemImage: selectedSection.icon)
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }

            switch selectedSection {
            case .documents:
                if sortedDocs.isEmpty {
                    ProtectionEmptyState(
                        icon: "doc.badge.plus",
                        title: l.tr(zh: "还没有证件", en: "No documents yet", de: "Noch keine Dokumente"),
                        actionTitle: l.tr(zh: "添加证件", en: "Add document", de: "Dokument hinzufügen"),
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
                        title: l.tr(zh: "还没有保单", en: "No policies yet", de: "Noch keine Policen"),
                        actionTitle: l.tr(zh: "添加保单", en: "Add policy", de: "Police hinzufügen"),
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
            "addDocument"
        case let .editDocument(doc):
            "editDocument-\(doc.id.uuidString)"
        case .addInsurance:
            "addInsurance"
        case let .editInsurance(insurance):
            "editInsurance-\(insurance.id.uuidString)"
        }
    }
}
