//
//  DocumentDetailSheet.swift
//  Ohana
//
//  证件详情页：显示证件完整信息 + 所有附件（支持多附件 + 兼容旧单附件）
//

import SwiftUI
import SwiftData

struct DocumentDetailSheet: View {
    let doc: PetDocument
    let pet: Pet
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var previewImageData: Data? = nil
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false

    private var expiryColor: Color {
        if doc.isExpired { return Color.goRed }
        if doc.isExpiringSoon { return Color.goYellow }
        return Color.goTeal
    }

    // Combined attachments: new multi-attach + old single-attach legacy
    private var imageAttachments: [Data] {
        var result: [Data] = doc.attachments.filter { $0.isImage }.map { $0.data }
        // Fall-back to legacy single attachment
        if result.isEmpty, let legacy = doc.attachmentData {
            result.append(legacy)
        }
        return result
    }

    private var fileAttachments: [(data: Data, name: String)] {
        doc.attachments.filter { !$0.isImage }.map { ($0.data, $0.filename) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D0638").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── 标题区
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.goCardCyan.opacity(0.12))
                                    .frame(width: 72, height: 72)
                                Text(doc.documentCategory.emoji)
                                    .font(.system(size: 40))
                            }
                            Text(doc.title.isEmpty ? doc.category : doc.title)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            Text(doc.category)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                        .padding(.top, 8)

                        // ── 状态胶囊
                        if doc.isExpired {
                            Label("已过期", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.goRed)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color.goRed.opacity(0.15), in: Capsule())
                        } else if doc.isExpiringSoon {
                            Label("即将到期", systemImage: "clock.badge.exclamationmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.goYellow)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color.goYellow.opacity(0.15), in: Capsule())
                        }

                        // ── 信息卡片
                        VStack(spacing: 0) {
                            if let issue = doc.issueDate {
                                infoRow(icon: "calendar", label: "签发日期", value: issue.formatted(.dateTime.year().month().day()))
                                Divider().background(.white.opacity(0.08))
                            }
                            if let expiry = doc.expiryDate {
                                infoRow(icon: "clock", label: "到期日期", value: expiry.formatted(.dateTime.year().month().day()), valueColor: expiryColor)
                                Divider().background(.white.opacity(0.08))
                            }
                            if !doc.issuingAuthority.isEmpty {
                                infoRow(icon: "building.2", label: "签发机构", value: doc.issuingAuthority)
                                Divider().background(.white.opacity(0.08))
                            }
                            if doc.cost > 0 {
                                infoRow(icon: "yensign.circle", label: "花费", value: String(format: "¥%.2f", doc.cost))
                                Divider().background(.white.opacity(0.08))
                            }
                            if !doc.notes.isEmpty {
                                infoRow(icon: "note.text", label: "备注", value: doc.notes)
                            }
                        }
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))

                        // ── 图片附件（支持多附件）
                        if !imageAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("附件图片", systemImage: "photo.stack.fill")
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                    ForEach(Array(imageAttachments.enumerated()), id: \.offset) { _, data in
                                        if let ui = UIImage(data: data) {
                                            Button { previewImageData = data } label: {
                                                Image(uiImage: ui)
                                                    .resizable().scaledToFill()
                                                    .frame(maxWidth: .infinity).frame(height: 140)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // ── 文件附件
                        if !fileAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("文件附件", systemImage: "doc.fill")
                                ForEach(Array(fileAttachments.enumerated()), id: \.offset) { _, att in
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.goCardCyan)
                                        Text(att.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary.opacity(0.7))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }

                // ── 全屏图片预览
                if let data = previewImageData, let ui = UIImage(data: data) {
                    ZStack {
                        Color.black.opacity(0.9).ignoresSafeArea()
                            .onTapGesture { previewImageData = nil }
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .ignoresSafeArea(edges: .all)
                        VStack {
                            HStack {
                                Spacer()
                                Button { previewImageData = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.primary).padding(16)
                                }
                            }
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("证件详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.goRed)
                        }
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onEdit() }
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goCardCyan)
                        }
                    }
                }
            }
            .alert("删除证件？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    modelContext.delete(doc)
                    modelContext.safeSave()
                    dismiss()
                }
            } message: { Text("「\(doc.title.isEmpty ? doc.category : doc.title)」将被永久删除。") }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.goCardCyan.opacity(0.7))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.goCardCyan)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
        }
    }
}
