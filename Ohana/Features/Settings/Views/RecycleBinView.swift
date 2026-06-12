//
//  RecycleBinView.swift
//  Ohana
//
//  Recoverable deletion surface for launch-safe local data.
//

import SwiftData
import SwiftUI

struct RecycleBinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var items: [RecycleBinListItem] = []
    @State private var statusMessage = ""

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaStaticAppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        header
                        if items.isEmpty {
                            emptyState
                        } else {
                            itemList
                        }
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .padding(.horizontal, 2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refresh)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "回收站", en: "Recycle Bin", de: "Papierkorb"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "删除的成员、珍贵档案、健康记录和批量清空记录会保留 30 天。",
                    en: "Deleted members, precious archives, health records, and bulk-cleared records stay here for 30 days.",
                    de: "Gelöschte Mitglieder, Archive und geleerte Einträge bleiben 30 Tage hier."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative close glyph; button has explicit accessibility label
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Capsule())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative status glyph; text below announces empty state
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(l.tr(zh: "没有待恢复项目", en: "Nothing to restore", de: "Nichts wiederherzustellen"))
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "之后删除成员、照片、证件、里程碑、保单或清空宠物记录时，会出现在这里。",
                en: "Deleted members, photos, documents, milestones, policies, and bulk-cleared pet records will appear here.",
                de: "Gelöschte Mitglieder, Fotos, Dokumente, Meilensteine, Policen und geleerte Tierdaten erscheinen hier."
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.tr(zh: "可恢复项目", en: "Recoverable Items", de: "Wiederherstellbare Elemente"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .tracking(1.2)
                Spacer()
                Button(l.tr(zh: "清理过期", en: "Clean Expired", de: "Abgelaufene löschen")) {
                    purgeExpired()
                }
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goRed)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        OhanaDashedDivider(color: Color.ohanaDivider).padding(.leading, 46)
                    }
                    row(for: item)
                }
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
    }

    private func row(for item: RecycleBinListItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: item.kind))
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive glyph frame; restore button owns the row action
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(subtitle(for: item))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button(l.tr(zh: "恢复", en: "Restore", de: "Wiederherstellen")) {
                restore(item)
            }
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.goPrimary)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(Color.goPrimary.opacity(0.12), in: Capsule())
        }
        .frame(minHeight: 54)
    }

    private func iconName(for kind: RecycleBinEntryKind) -> String {
        switch kind {
        case .pet: "pawprint.fill"
        case .human: "person.fill"
        case .plant: "leaf.fill"
        case .petPhoto: "photo.fill"
        case .petMilestone: "sparkles"
        case .petDocument: "doc.text.fill"
        case .petInsurance: "shield.fill"
        case .petHealthLog: "heart.text.clipboard.fill"
        case .symptomLog: "exclamationmark.triangle.fill"
        case .heatCycleLog: "heart.text.square.fill"
        case .petActivityClearBatch: "tray.full.fill"
        }
    }

    private func subtitle(for item: RecycleBinListItem) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: item.trashExpiresAt).day ?? 0)
        let prefix = item.subtitle.isEmpty ? kindTitle(for: item.kind) : item.subtitle
        return l.tr(
            zh: "\(prefix) · 约 \(days) 天后清理",
            en: "\(prefix) · cleans in about \(days) days",
            de: "\(prefix) · wird in etwa \(days) Tagen gelöscht"
        )
    }

    private func kindTitle(for kind: RecycleBinEntryKind) -> String {
        switch kind {
        case .pet: l.tr(zh: "宠物", en: "Pet", de: "Tier")
        case .human: l.tr(zh: "人类成员", en: "Human", de: "Mensch")
        case .plant: l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        case .petPhoto: l.tr(zh: "照片", en: "Photo", de: "Foto")
        case .petMilestone: l.tr(zh: "里程碑", en: "Milestone", de: "Meilenstein")
        case .petDocument: l.tr(zh: "证件", en: "Document", de: "Dokument")
        case .petInsurance: l.tr(zh: "保单", en: "Policy", de: "Police")
        case .petHealthLog: l.tr(zh: "健康记录", en: "Health record", de: "Gesundheitseintrag")
        case .symptomLog: l.tr(zh: "症状记录", en: "Symptom record", de: "Symptomeintrag")
        case .heatCycleLog: l.tr(zh: "发情记录", en: "Heat cycle record", de: "Läufigkeitseintrag")
        case .petActivityClearBatch: l.tr(zh: "批量清空记录", en: "Bulk-cleared records", de: "Geleerte Einträge")
        }
    }

    private func refresh() {
        items = RecycleBinService.listItems(context: modelContext)
    }

    private func restore(_ item: RecycleBinListItem) {
        let result = RecycleBinService.restoreItem(item, context: modelContext)
        statusMessage = result.didChange
            ? l.tr(zh: "已恢复", en: "Restored", de: "Wiederhergestellt")
            : l.tr(zh: "项目已不可用", en: "Item is no longer available", de: "Element ist nicht mehr verfügbar")
        refresh()
    }

    private func purgeExpired() {
        let result = RecycleBinService.purgeExpired(context: modelContext)
        statusMessage = result.didChange
            ? l.tr(
                zh: "已清理 \(result.purgedSourceCount + result.purgedBatchCount) 项过期内容",
                en: "Cleaned \(result.purgedSourceCount + result.purgedBatchCount) expired items",
                de: "\(result.purgedSourceCount + result.purgedBatchCount) abgelaufene Elemente gelöscht"
            )
            : l.tr(zh: "没有过期项目", en: "No expired items", de: "Keine abgelaufenen Elemente")
        refresh()
    }
}
