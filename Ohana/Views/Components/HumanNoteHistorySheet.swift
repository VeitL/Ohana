//
//  HumanNoteHistorySheet.swift
//  Ohana
//
//  V4 human note history.
//

import SwiftUI
import SwiftData

struct HumanNoteEntry: Identifiable {
    let id: UUID
    let date: Date
    let dateString: String
    let text: String
    let rawString: String
}

struct HumanNoteHistorySheet: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var showAddSheet = false

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.note, viewedBy: activeHumanId) }
    private var noteEntries: [HumanNoteEntry] { parseNotes() }

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
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                QuickHumanNoteSheet(human: human)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: human.avatarImageData,
                emoji: human.avatarEmoji,
                fallback: "👤",
                tint: Color(hex: human.safeThemeColorHex)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "备注记录", en: "Notes", de: "Notizen"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(human.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .note)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 10) {
            metric(
                title: l.tr(zh: "总记录", en: "Total", de: "Gesamt"),
                value: "\(noteEntries.count)"
            )
            metric(
                title: l.tr(zh: "最近", en: "Latest", de: "Letzte"),
                value: latestNoteText
            )
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        deleteNote(entry)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "删除备注", en: "Delete note", de: "Notiz löschen"))
            }

            Text(entry.text)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 38, weight: .black))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                Text(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 22)
            .frame(height: 54)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var privacyLockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(PrivacyService.lockedMessage(for: .note))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "当前家庭成员无权查看这些备注。",
                en: "This family member cannot view these notes.",
                de: "Dieses Familienmitglied kann diese Notizen nicht sehen."
            ))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
        }
        .padding(24)
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
        return parts.compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("["),
               let bracketEnd = trimmed.firstIndex(of: "]") {
                let dateStr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<bracketEnd])
                let rest = String(trimmed[trimmed.index(after: bracketEnd)...])
                    .trimmingCharacters(in: .whitespaces)
                if let date = Self.noteDateFormatter.date(from: dateStr) {
                    return HumanNoteEntry(
                        id: UUID(),
                        date: date,
                        dateString: dateStr,
                        text: rest,
                        rawString: trimmed
                    )
                }
            }
            return HumanNoteEntry(
                id: UUID(),
                date: .distantPast,
                dateString: "",
                text: trimmed,
                rawString: trimmed
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func deleteNote(_ entry: HumanNoteEntry) {
        let parts = human.notes.components(separatedBy: "\n\n")
        let remaining = parts.filter { part in
            part.trimmingCharacters(in: .whitespacesAndNewlines) != entry.rawString
        }
        human.notes = remaining
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
