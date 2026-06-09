//
//  DocumentDetailSheet.swift
//  Ohana
//
//  V4 document detail page.
//

import SwiftUI
import SwiftData

struct DocumentDetailSheet: View {
    let doc: PetDocument
    let pet: Pet
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var previewImageData: Data?
    @State private var showingDeleteAlert = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }

    private var title: String {
        doc.title.isEmpty ? doc.category : doc.title
    }

    private var expiryColor: Color {
        if doc.isExpired { return Color.goRed }
        if doc.isExpiringSoon { return Color.goYellow }
        return Color.goTeal
    }

    private var statusText: String {
        if doc.isExpired { return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen") }
        if doc.isExpiringSoon { return l.tr(zh: "即将到期", en: "Expiring", de: "Läuft bald ab") }
        if doc.expiryDate != nil { return l.tr(zh: "保障中", en: "Protected", de: "Geschützt") }
        return l.tr(zh: "长期", en: "Long-term", de: "Langfristig")
    }

    private var imageAttachments: [Data] {
        var result = doc.attachments.filter { $0.isImage }.map(\.data)
        if result.isEmpty, let legacy = doc.attachmentData {
            result.append(legacy)
        }
        return result
    }

    private var fileAttachments: [(data: Data, name: String)] {
        doc.attachments.filter { !$0.isImage }.map { ($0.data, $0.filename) }
    }

    private var visibleNotes: String {
        ExpenseReceiptMetadata.visibleNotes(from: doc.notes)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusStrip
                    infoRows
                    attachmentSection
                    actionRow
                    Spacer(minLength: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }

            if let previewImageData, let ui = UIImage(data: previewImageData) {
                imagePreview(ui)
                    .zIndex(20)
            }
        }
        .alert(l.tr(zh: "删除证件？", en: "Delete document?", de: "Dokument löschen?"), isPresented: $showingDeleteAlert) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                let command = DomainCommand.petDocumentDelete(petID: pet.id, documentID: doc.id)
                commandQueue.enqueue(command) {
                    PetDocumentCommandExecutor(context: modelContext).deleteDocument(
                        doc,
                        pet: pet,
                        note: "petDocument.delete"
                    )
                    dismiss()
                }
            }
        } message: {
            Text(l.tr(
                zh: "「\(title)」将被永久删除。",
                en: "\"\(title)\" will be deleted permanently.",
                de: "\"\(title)\" wird dauerhaft gelöscht."
            ))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(doc.documentCategory.emoji)
                .font(.system(size: 26))
                .frame(width: 48, height: 48)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(doc.category)
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

    private var statusStrip: some View {
        HStack(spacing: 12) {
            metric(title: l.tr(zh: "状态", en: "Status", de: "Status"), value: statusText, tint: expiryColor)
            metric(title: l.tr(zh: "附件", en: "Files", de: "Anhänge"), value: "\(imageAttachments.count + fileAttachments.count)", tint: Color.goPrimary)
            metric(title: l.tr(zh: "花费", en: "Cost", de: "Kosten"), value: doc.cost > 0 ? AppCurrency.format(doc.cost, fractionDigits: 0) : "—", tint: Color.goTeal)
        }
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
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

    private var infoRows: some View {
        VStack(spacing: 8) {
            if let issue = doc.issueDate {
                detailRow(icon: "calendar", label: l.tr(zh: "签发日期", en: "Issue", de: "Ausgestellt"), value: issue.formatted(.dateTime.year().month().day()))
            }
            if let expiry = doc.expiryDate {
                detailRow(icon: "clock", label: l.tr(zh: "到期日期", en: "Expiry", de: "Ablauf"), value: expiry.formatted(.dateTime.year().month().day()), tint: expiryColor)
            }
            if !doc.issuingAuthority.isEmpty {
                detailRow(icon: "building.2.fill", label: l.tr(zh: "机构", en: "Authority", de: "Behörde"), value: doc.issuingAuthority)
            }
            if !visibleNotes.isEmpty {
                detailRow(icon: "note.text", label: l.tr(zh: "备注", en: "Notes", de: "Notizen"), value: visibleNotes)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String, tint: Color = Color.ohanaPrimaryText) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 24)
            Text(label)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var attachmentSection: some View {
        if !imageAttachments.isEmpty || !fileAttachments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(zh: "附件", en: "Attachments", de: "Anhänge"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                if !imageAttachments.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(imageAttachments.enumerated()), id: \.offset) { _, data in
                            if let ui = UIImage(data: data) {
                                Button { previewImageData = data } label: {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 128)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }

                ForEach(Array(fileAttachments.enumerated()), id: \.offset) { _, attachment in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                        Text(attachment.name)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    onEdit()
                }
            } label: {
                Label(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"), systemImage: "pencil")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 52, height: 48)
                    .background(Color.ohanaCardSurface, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
        }
        .padding(.top, 4)
    }

    private func imagePreview(_ ui: UIImage) -> some View {
        ZStack {
            Color.arkInk.opacity(0.94)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(GoMotion.page) { previewImageData = nil } }
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .padding(18)
            VStack {
                HStack {
                    Spacer()
                    Button { withAnimation(GoMotion.page) { previewImageData = nil } } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(16)
                }
                Spacer()
            }
        }
    }
}
