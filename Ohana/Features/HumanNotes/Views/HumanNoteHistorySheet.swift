//
//  HumanNoteHistorySheet.swift
//  Ohana
//
//  V4 human note history.
//

import SwiftData
import SwiftUI
import UIKit

struct HumanNoteEntry: Identifiable {
    let id: UUID
    let date: Date
    let dateString: String
    let text: String
    let attachments: [HumanNoteAttachmentReference]
    let rawString: String
    let recordedByHumanId: String?
}

struct HumanNoteHistoryContent: View {
    let human: Human
    let humans: [Human]
    let noteRecords: [HumanNoteRecord]
    let onRecordsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var showAddSheet = false
    @State private var noteRevision = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.note, viewedBy: activeHumanId) }
    private var noteEntries: [HumanNoteEntry] {
        _ = noteRevision
        return parseNotes()
    }

    init(
        human: Human,
        humans: [Human],
        noteRecords: [HumanNoteRecord],
        onRecordsChanged: @escaping () -> Void
    ) {
        self.human = human
        self.humans = humans
        self.noteRecords = noteRecords
        self.onRecordsChanged = onRecordsChanged
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                OhanaAppBackground().ignoresSafeArea()

                if isPrivacyLocked {
                    privacyLockedView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            HumanPrivateDataNotice(human: human, field: .note)
                            metricStrip
                            notesSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 110)
                    }

                    addButton
                        .padding(.trailing, 18)
                        .padding(.bottom, 24)
                }

                if showAddSheet {
                    QuickHumanNoteSheet(
                        human: human,
                        onSaved: {
                            noteRevision += 1
                            onRecordsChanged()
                        },
                        onDismiss: { showAddSheet = false }
                    )
                    .zIndex(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                commandQueue.cancelAll()
            }
        }
    }

    private var header: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "备注记录", en: "Notes", de: "Notizen"),
            subtitle: human.name,
            onClose: { dismiss() }
        ) {
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .note)
            }
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "时间线", en: "Timeline", de: "Zeitlinie"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if noteEntries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(noteEntries) { entry in
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
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                if humans.count > 1, let recorderName = recorderName(for: entry) {
                    Text("· \(recorderName)")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        deleteNote(entry)
                    }
                } label: {
                    Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "删除备注", en: "Delete note", de: "Notiz löschen"))
                .accessibilityIdentifier("human-note-delete-action")
            }

            Text(entry.text)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

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
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPurple)
                Text(attachment.fileName)
                    .font(OhanaFont.caption(.black))
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
                .font(OhanaFont.adaptive(size: 38, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "还没有备注", en: "No notes yet", de: "Noch keine Notizen"))
                .font(OhanaFont.title3(.black))
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
        let cal = Calendar.current
        if cal.isDateInToday(latest.date) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        if cal.isDateInYesterday(latest.date) { return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern") }
        return latest.date.formatted(date: .abbreviated, time: .omitted)
    }

    private static let noteDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func parseNotes() -> [HumanNoteEntry] {
        guard !human.notes.isEmpty else { return [] }
        let parts = human.notes.components(separatedBy: "\n\n")
        let recordsBySequence = Dictionary(uniqueKeysWithValues: noteRecords.map { ($0.sequence, $0) })
        return parts.enumerated().compactMap { sequence, part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let record = recordsBySequence[sequence]
            if trimmed.hasPrefix("["),
               let bracketEnd = trimmed.firstIndex(of: "]") {
                let dateStr = String(trimmed[trimmed.index(after: trimmed.startIndex) ..< bracketEnd])
                let rest = String(trimmed[trimmed.index(after: bracketEnd)...])
                    .trimmingCharacters(in: .whitespaces)
                if let date = Self.noteDateFormatter.date(from: dateStr) {
                    let parsed = HumanNoteAttachmentStore.visibleTextAndAttachments(from: rest)
                    return HumanNoteEntry(
                        id: record?.id ?? UUID(),
                        date: date,
                        dateString: dateStr,
                        text: parsed.text,
                        attachments: parsed.attachments,
                        rawString: trimmed,
                        recordedByHumanId: record?.recordedByHumanId
                    )
                }
            }
            let parsed = HumanNoteAttachmentStore.visibleTextAndAttachments(from: trimmed)
            return HumanNoteEntry(
                id: record?.id ?? UUID(),
                date: .distantPast,
                dateString: "",
                text: parsed.text,
                attachments: parsed.attachments,
                rawString: trimmed,
                recordedByHumanId: record?.recordedByHumanId
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func recorderName(for entry: HumanNoteEntry) -> String? {
        guard let id = entry.recordedByHumanId else { return nil }
        return humans.first { $0.id.uuidString == id }?.name
    }

    private func deleteNote(_ entry: HumanNoteEntry) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let command = DomainCommand.humanNote(humanID: human.id)
        commandQueue.enqueue(command) {
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).deleteNote(
                human: human,
                rawString: entry.rawString,
                recordID: entry.id
            )
            if case .pending = result.attachmentCleanup {
                appServices.islandToasts.show(l.tr(
                    zh: "备注已删除，但本地附件未能完全清理。请联系支持。",
                    en: "The note was deleted, but its local attachment could not be fully removed. Contact support.",
                    de: "Die Notiz wurde gelöscht, aber der lokale Anhang konnte nicht vollständig entfernt werden. Kontaktiere den Support."
                ))
            }
            noteRevision += 1
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
                        .font(OhanaFont.callout(.black))
                        .accessibilityHidden(true)
                    Text(fileName)
                        .font(OhanaFont.caption2(.black))
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
