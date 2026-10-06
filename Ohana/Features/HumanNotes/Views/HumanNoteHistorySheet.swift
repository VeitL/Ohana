//
//  HumanNoteHistorySheet.swift
//  Ohana
//
//  V4 human note history. Native searchable navigation + existing Human metric/record rows.
//  Search/filter are local view state; timeline parsing happens once in the route container.
//  Empty, loading, private and no-match states preserve access to normal note commands.
//

import SwiftData
import SwiftUI
import UIKit

struct HumanNoteHistoryContent: View {
    let human: Human
    let humans: [Human]
    let noteEntries: [HumanNoteEntry]
    let isLoading: Bool
    let showsCloseButton: Bool
    let onRecordsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var timeRange: HumanNoteTimeRange = .all
    @State private var attachmentsOnly = false
    @State private var pendingDeletion: HumanNoteEntry?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.note, viewedBy: activeHumanId) }
    init(
        human: Human,
        humans: [Human],
        noteEntries: [HumanNoteEntry],
        isLoading: Bool = false,
        showsCloseButton: Bool = true,
        onRecordsChanged: @escaping () -> Void
    ) {
        self.human = human
        self.humans = humans
        self.noteEntries = noteEntries
        self.isLoading = isLoading
        self.showsCloseButton = showsCloseButton
        self.onRecordsChanged = onRecordsChanged
    }

    var body: some View {
        OhanaNavigationContainer(ownsNavigationStack: showsCloseButton) {
            ZStack(alignment: .bottomTrailing) {
                OhanaAppBackground().ignoresSafeArea()

                if isPrivacyLocked {
                    privacyLockedView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(human.name)
                                .font(OhanaFont.title3(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            HumanPrivateDataNotice(human: human, field: .note)
                            if !isLoading {
                                metricStrip
                                HumanNoteTimelineFilters(timeRange: $timeRange, attachmentsOnly: $attachmentsOnly)
                            }
                            notesSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 110)
                    }
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n(appLanguage).tr(
                        zh: "搜索备注、附件或记录人", en: "Search notes, files or recorder",
                        de: "Notizen, Dateien oder Person suchen",
                        es: "Buscar notas, archivos o autor", pt: "Buscar notas, arquivos ou autor",
                        fr: "Rechercher notes, fichiers ou auteur", ja: "メモ・添付・記録者を検索",
                        ko: "메모, 첨부 파일 또는 기록자 검색", it: "Cerca note, file o autore"
                    ))

                    addButton
                        .padding(.trailing, 18)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle(l.tr(zh: "备注记录", en: "Notes", de: "Notizen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    OhanaModalToolbar(onClose: { dismiss() }, closeIdentifier: "human-module-close-action")
                }
                ToolbarItem(placement: .primaryAction) {
                    if isViewingOwnProfile {
                        HumanPrivacyToggleButton(human: human, field: .note)
                    }
                }
            }
            .confirmationDialog(
                l.tr(
                    zh: "删除这条备注？", en: "Delete this note?", de: "Diese Notiz löschen?",
                    es: "¿Eliminar esta nota?", pt: "Excluir esta nota?", fr: "Supprimer cette note ?",
                    ja: "このメモを削除しますか？", ko: "이 메모를 삭제할까요?", it: "Eliminare questa nota?"
                ),
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { entry in
                Button(l.tr(
                    zh: "删除", en: "Delete", de: "Löschen", es: "Eliminar", pt: "Excluir",
                    fr: "Supprimer", ja: "削除", ko: "삭제", it: "Elimina"
                ), role: .destructive) {
                    deleteNote(entry)
                    pendingDeletion = nil
                }
                Button(l.cancel, role: .cancel) { pendingDeletion = nil }
            }
            .sheet(isPresented: $showAddSheet) {
                QuickHumanNoteSheet(
                    human: human,
                    onSaved: {
                        onRecordsChanged()
                    }
                )
            }
            .onDisappear {
                commandQueue.cancelAll()
            }
        }
        .environment(\.locale, AppLanguage.effectiveLocale)
    }

    private var metricStrip: some View {
        HumanModuleMetricStrip(metrics: [
            FeatureHubMetric(
                id: "total",
                title: l.tr(zh: "总记录", en: "Total", de: "Gesamt"),
                value: "\(noteEntries.count)"
            ),
            FeatureHubMetric(
                id: "latest",
                title: l.tr(zh: "最近", en: "Latest", de: "Letzte"),
                value: latestNoteText
            )
        ])
    }

    private var notesSection: some View {
        let visibleEntries = HumanNoteTimelineBuilder.filtered(
            noteEntries, query: searchText, timeRange: timeRange,
            attachmentsOnly: attachmentsOnly,
            recorderNames: Dictionary(uniqueKeysWithValues: humans.map { ($0.id, $0.name) })
        )
        return VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "时间线", en: "Timeline", de: "Zeitlinie"))
                .font(OhanaFont.headline(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if noteEntries.isEmpty {
                emptyState
            } else if visibleEntries.isEmpty {
                HumanNoteTimelineNoResults {
                    searchText = ""
                    timeRange = .all
                    attachmentsOnly = false
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleEntries) { entry in
                        noteRow(entry)
                    }
                }
            }
        }
    }

    private func noteRow(_ entry: HumanNoteEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(noteDateText(entry.date))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goPrimary)
                if humans.count > 1, let recorderName = recorderName(for: entry) {
                    Text("· \(recorderName)")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    pendingDeletion = entry
                } label: {
                    Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "删除备注", en: "Delete note", de: "Notiz löschen"))
                .accessibilityIdentifier("human-note-delete-action")
            }

            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.attachments.isEmpty {
                attachmentStrip(entry.attachments)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func attachmentStrip(_ attachments: [HumanNoteAttachmentReference]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    attachmentPreview(attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: HumanNoteAttachmentReference) -> some View {
        if attachment.isImage, let url = HumanNoteAttachmentStore.url(for: attachment) {
            HumanNoteAttachmentImagePreview(url: url, fileName: attachment.fileName)
        } else {
            HStack(spacing: 7) {
                Image(systemName: attachment.isImage ? "photo.fill" : "doc.fill")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPurple)
                Text(attachment.fileName)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.ohanaControlFill, in: Capsule())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 38, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "还没有备注", en: "No notes yet", de: "Noch keine Notizen"))
                .font(OhanaFont.title3(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "记录一句想法、身体感受或重要提醒。",
                en: "Save a thought, body note, or reminder.",
                de: "Speichere einen Gedanken, Körperhinweis oder eine Erinnerung."
            ))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var addButton: some View {
        HumanModuleFloatingActionButton(
            title: l.tr(zh: "添加", en: "Add", de: "Hinzufügen"),
            icon: "plus"
        ) {
            showAddSheet = true
        }
        .accessibilityIdentifier("human-note-add-action")
    }

    private var privacyLockedView: some View {
        HumanModulePrivacyLockedView(
            title: appServices.privacy.lockedMessage(for: .note),
            message: l.tr(
                zh: "当前家庭成员无权查看这些备注。",
                en: "This family member cannot view these notes.",
                de: "Dieses Familienmitglied kann diese Notizen nicht sehen."
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var latestNoteText: String {
        guard let latest = noteEntries.first else { return l.tr(zh: "无", en: "None", de: "Keine") }
        return noteDateText(latest.date)
    }

    private func noteDateText(_ date: Date?) -> String {
        guard let date else {
            return l.tr(
                zh: "未注明日期", en: "Undated", de: "Ohne Datum",
                es: "Sin fecha", pt: "Sem data", fr: "Sans date",
                ja: "日付なし", ko: "날짜 없음", it: "Senza data"
            )
        }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        if cal.isDateInYesterday(date) { return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern") }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLanguage.effectiveLocale))
    }

    private func recorderName(for entry: HumanNoteEntry) -> String? {
        guard let id = entry.recordedByHumanId else { return nil }
        return humans.first { $0.id == UUID(uuidString: id) }?.name
    }

    private func deleteNote(_ entry: HumanNoteEntry) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let command = DomainCommand.humanNote(humanID: human.id)
        commandQueue.enqueue(command) {
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).deleteNote(
                human: human,
                rawString: entry.rawString,
                recordID: entry.recordID
            )
            guard result.didDelete, result.didPersist else {
                appServices.islandToasts.show(l.tr(
                    zh: "备注未能删除，请重试。", en: "The note could not be deleted. Try again.",
                    de: "Die Notiz konnte nicht gelöscht werden. Bitte erneut versuchen.",
                    es: "No se pudo eliminar la nota. Inténtalo de nuevo.", pt: "Não foi possível excluir a nota. Tente novamente.",
                    fr: "La note n’a pas pu être supprimée. Réessayez.", ja: "メモを削除できませんでした。再試行してください。",
                    ko: "메모를 삭제할 수 없습니다. 다시 시도해 주세요.", it: "Impossibile eliminare la nota. Riprova."
                ))
                return
            }
            if case .pending = result.attachmentCleanup {
                appServices.islandToasts.show(l.tr(
                    zh: "备注已删除，但本地附件未能完全清理。请联系支持。",
                    en: "The note was deleted, but its local attachment could not be fully removed. Contact support.",
                    de: "Die Notiz wurde gelöscht, aber der lokale Anhang konnte nicht vollständig entfernt werden. Kontaktiere den Support."
                ))
            }
            onRecordsChanged()
        }
    }
}

private struct HumanNoteAttachmentImagePreview: View {
    let url: URL
    let fileName: String

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(Color.goPurple.opacity(0.12))
                .frame(width: 74, height: 74)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            } else {
                VStack(spacing: 5) {
                    Image(systemName: "photo.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.callout(.semibold))
                        .accessibilityHidden(true)
                    Text(fileName)
                        .font(OhanaFont.caption2(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.goPurple)
                .padding(8)
            }
        }
        .task(id: url.path) {
            image = await AttachmentImageDecoder.decodeFile(url)
        }
    }
}
