//
//  DocumentsListView.swift
//  Ohana
//
//  N9: 证件详情页 — 浏览宠物所有证件
//

import SwiftUI
import SwiftData

struct DocumentsListView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var showingInsurance = false
    @State private var editingDoc: PetDocument? = nil
    @State private var detailDoc: PetDocument? = nil

    private var sortedDocs: [PetDocument] {
        pet.documents.sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    var body: some View {
        ZStack {
            Color(hex: "0D0638").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    sectionHeader("证件")
                    if sortedDocs.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedDocs) { doc in
                            DocumentDetailRow(doc: doc,
                                onDetail: { detailDoc = doc },
                                onEdit: { editingDoc = doc },
                                onDelete: {
                                    modelContext.delete(doc)
                                    modelContext.safeSave()
                                })
                        }
                    }

                    insuranceEntryCard

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationTitle("证件与保障")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goCardCyan)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddDocumentSheet(pet: pet)
        }
        .sheet(isPresented: $showingInsurance) {
            PetInsuranceView(pet: pet)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, pet: pet)
        }
        .sheet(item: $detailDoc) { doc in
            DocumentDetailSheet(doc: doc, pet: pet, onEdit: { editingDoc = doc })
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
            Spacer()
        }
    }

    private var insuranceEntryCard: some View {
        Button { showingInsurance = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.goPrimary.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("保险保单")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(insuranceSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
            }
            .padding(14)
            .goGlassBackground(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var insuranceSummary: String {
        let count = pet.insurances.count
        guard count > 0 else { return "暂无保单，可记录续期、保额和报销" }
        let active = pet.insurances.filter { $0.isActive && $0.renewalDate >= Date() }.count
        if active > 0 { return "\(active)份生效中 · 共\(count)份保单" }
        return "\(count)份保单 · 暂无生效中"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("📄").font(.system(size: 48))
            Text("还没有证件记录")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
            Text("点击右上角 + 添加第一份证件")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Document Detail Row
private struct DocumentDetailRow: View {
    let doc: PetDocument
    let onDetail: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingPreview = false

    private var expiryColor: Color {
        if doc.isExpired { return Color.goRed }
        if doc.isExpiringSoon { return Color.goYellow }
        return Color.goTeal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部行
            HStack(spacing: 12) {
                Text(doc.documentCategory.emoji)
                    .font(.system(size: 26))
                    .frame(width: 40, height: 40)
                    .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.title.isEmpty ? doc.category : doc.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(doc.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }

                Spacer()

                if doc.isExpired {
                    Text("已过期").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.goRed)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.goRed.opacity(0.15), in: Capsule())
                } else if doc.isExpiringSoon {
                    Text("即将到期").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.goYellow.opacity(0.15), in: Capsule())
                }
            }

            // 详情行
            HStack(spacing: 16) {
                if let issue = doc.issueDate {
                    infoChip(icon: "calendar", text: issue.formatted(.dateTime.year().month().day()))
                }
                if let expiry = doc.expiryDate {
                    infoChip(icon: "clock", text: expiry.formatted(.dateTime.year().month().day()), color: expiryColor)
                }
                if doc.cost > 0 {
                    infoChip(icon: AppCurrency.systemIconName, text: AppCurrency.format(doc.cost, fractionDigits: 0))
                }
            }

            if !doc.issuingAuthority.isEmpty {
                infoChip(icon: "building.2", text: doc.issuingAuthority)
            }

            if !doc.notes.isEmpty {
                Text(doc.notes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    .lineLimit(2)
            }

            // 附件预览
            if let data = doc.attachmentData, let ui = UIImage(data: data) {
                Button { showingPreview = true } label: {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(ScaleButtonStyle())
            } else if !doc.attachmentFilename.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill").foregroundStyle(Color.goPrimary)
                    Text(doc.attachmentFilename)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .lineLimit(1)
                }
                .padding(10)
                .goGlassBackground(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { onDetail() }
        .contextMenu {
            Button { onDetail() } label: {
                Label("查看详情", systemImage: "doc.text.magnifyingglass")
            }
            Button { onEdit() } label: {
                Label("编辑证件", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("删除证件", systemImage: "trash")
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let data = doc.attachmentData, let ui = UIImage(data: data) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: ui).resizable().scaledToFit().ignoresSafeArea()
                    VStack {
                        HStack {
                            Spacer()
                            Button { showingPreview = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Color.ohanaPrimaryText).shadow(radius: 4)
                            }.padding(16)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func infoChip(icon: String, text: String, color: Color = .primary.opacity(0.4)) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
        }
    }
}
