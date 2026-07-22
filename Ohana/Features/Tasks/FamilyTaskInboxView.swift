//
//  FamilyTaskInboxView.swift
//  Ohana
//
//  Recipient-scoped local collaboration inbox for household tasks.
//

import Foundation
import SwiftUI

enum FamilyTaskActivityText {
    static func title(_ activity: FamilyTaskActivitySnapshot, l: L10n) -> String {
        let actor = activity.actorHumanName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = actor.isEmpty
            ? l.tr(zh: "家人", en: "A household member", de: "Ein Familienmitglied")
            : actor
        switch activity.kind {
        case .assigned:
            return l.tr(zh: "\(name) 分配了任务", en: "\(name) assigned a task", de: "\(name) hat eine Aufgabe zugewiesen")
        case .declined:
            return l.tr(zh: "\(name) 拒绝了任务", en: "\(name) declined the task", de: "\(name) hat die Aufgabe abgelehnt")
        case .completed:
            return l.tr(zh: "\(name) 完成了任务", en: "\(name) completed the task", de: "\(name) hat die Aufgabe erledigt")
        case .submittedForReview:
            return l.tr(zh: "\(name) 提交了完成结果", en: "\(name) submitted the task", de: "\(name) hat die Aufgabe eingereicht")
        case .postponed:
            return l.tr(zh: "\(name) 延期了任务", en: "\(name) postponed the task", de: "\(name) hat die Aufgabe verschoben")
        case .commented:
            return l.tr(zh: "\(name) 留下了备注", en: "\(name) added a note", de: "\(name) hat eine Notiz hinzugefügt")
        case .edited:
            return l.tr(zh: "\(name) 更新了任务", en: "\(name) updated the task", de: "\(name) hat die Aufgabe aktualisiert")
        case .cancelled:
            return l.tr(zh: "\(name) 撤销了任务", en: "\(name) cancelled the task", de: "\(name) hat die Aufgabe abgebrochen")
        case .approved:
            return l.tr(zh: "\(name) 确认了完成", en: "\(name) approved completion", de: "\(name) hat den Abschluss bestätigt")
        case .rewarded:
            return l.tr(zh: "\(name) 确认并发放了奖励", en: "\(name) approved and released the reward", de: "\(name) hat bestätigt und die Belohnung freigegeben")
        case .returnedForRedo:
            return l.tr(zh: "\(name) 退回了任务", en: "\(name) sent the task back", de: "\(name) hat die Aufgabe zurückgegeben")
        case .missedSummary:
            return l.tr(zh: "有任务未按时完成", en: "Tasks were missed", de: "Aufgaben wurden verpasst")
        }
    }

    static func detail(
        _ activity: FamilyTaskActivitySnapshot,
        l: L10n,
        localizedDate: (Date) -> String
    ) -> String? {
        let body = activity.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return body }
        if activity.kind == .postponed, let newDueAt = activity.newDueAt {
            return l.tr(
                zh: "新的截止时间：\(localizedDate(newDueAt))",
                en: "New due date: \(localizedDate(newDueAt))",
                de: "Neue Fälligkeit: \(localizedDate(newDueAt))"
            )
        }
        if activity.kind == .missedSummary, activity.countValue > 0 {
            return l.tr(
                zh: "共 \(activity.countValue) 次",
                en: "\(activity.countValue) occurrences",
                de: "\(activity.countValue) Termine"
            )
        }
        return nil
    }

    static func symbol(_ kind: FamilyTaskActivityKind) -> String {
        switch kind {
        case .assigned: "person.fill.badge.plus"
        case .declined: "hand.raised.slash.fill"
        case .completed: "checkmark.circle.fill"
        case .submittedForReview: "paperplane.fill"
        case .postponed: "calendar.badge.clock"
        case .commented: "text.bubble.fill"
        case .edited: "pencil.circle.fill"
        case .cancelled: "xmark.circle.fill"
        case .approved: "checkmark.seal.fill"
        case .rewarded: "gift.fill"
        case .returnedForRedo: "arrow.uturn.backward.circle.fill"
        case .missedSummary: "exclamationmark.calendar.fill"
        }
    }

    static func tint(_ kind: FamilyTaskActivityKind) -> Color {
        switch kind {
        case .completed, .approved, .rewarded: .goTeal
        case .declined, .cancelled, .returnedForRedo, .missedSummary: .goRed
        case .postponed: .goPurple
        case .assigned, .submittedForReview, .commented, .edited: .goPrimary
        }
    }
}

struct FamilyTaskInboxView: View {
    let activities: [FamilyTaskActivitySnapshot]
    let unreadCount: Int
    let memberName: String
    let onOpen: (FamilyTaskActivitySnapshot) -> Void
    let onMarkAllRead: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView {
                        Label(
                            l.tr(zh: "没有协作消息", en: "No collaboration messages", de: "Keine Nachrichten"),
                            systemImage: "tray"
                        )
                    } description: {
                        Text(l.tr(
                            zh: "分配、完成、拒绝、延期和备注会按家庭成员显示在这里。",
                            en: "Assignments, completions, declines, postponements, and notes appear here for each household member.",
                            de: "Zuweisungen, Abschlüsse, Ablehnungen, Verschiebungen und Notizen erscheinen hier pro Familienmitglied."
                        ))
                    }
                    .accessibilityIdentifier("family-task-inbox-empty")
                } else {
                    List {
                        Section {
                            ForEach(activities) { activity in
                                activityRow(activity)
                            }
                        } header: {
                            Text(l.tr(
                                zh: "\(memberName) 的消息",
                                en: "Messages for \(memberName)",
                                de: "Nachrichten für \(memberName)"
                            ))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(l.tr(zh: "协作消息", en: "Collaboration", de: "Zusammenarbeit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("family-task-inbox-close")
                }

                if unreadCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button(l.tr(zh: "全部已读", en: "Mark all read", de: "Alle gelesen")) {
                            onMarkAllRead()
                            OhanaFeedback.selection()
                        }
                        .accessibilityLabel(l.tr(
                            zh: "将 \(unreadCount) 条协作消息全部标为已读",
                            en: "Mark all \(unreadCount) collaboration messages as read",
                            de: "Alle \(unreadCount) Nachrichten als gelesen markieren"
                        ))
                        .accessibilityIdentifier("family-task-inbox-mark-all-read")
                    }
                }
            }
        }
        .accessibilityIdentifier("family-task-inbox")
    }

    private func activityRow(_ activity: FamilyTaskActivitySnapshot) -> some View {
        Button {
            OhanaFeedback.light()
            onOpen(activity)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: activitySymbol(activity.kind))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(activityTint(activity.kind))
                    .frame(width: 38, height: 38) // a11y: allow decorative glyph inside the full-width message row button
                    .background(activityTint(activity.kind).opacity(0.13), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(activityTitle(activity))
                            .font(OhanaFont.callout(activity.isUnread ? .black : .bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Text(localizedDate(activity.createdAt))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    Text(activity.taskTitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(activityTint(activity.kind))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let detail = activityDetail(activity) {
                        Text(detail)
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }

                if activity.isUnread {
                    Circle()
                        .fill(Color.goPrimary)
                        .frame(width: 9, height: 9) // a11y: allow decorative unread dot inside the full-width message row button
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activityAccessibilityLabel(activity))
        .accessibilityHint(activity.taskID == nil
            ? l.tr(zh: "标记为已读", en: "Mark as read", de: "Als gelesen markieren")
            : l.tr(zh: "标记为已读并打开任务", en: "Mark as read and open the task", de: "Als gelesen markieren und Aufgabe öffnen"))
        .accessibilityIdentifier("family-task-inbox-activity-\(activity.id.uuidString)")
    }

    private func activityTitle(_ activity: FamilyTaskActivitySnapshot) -> String {
        FamilyTaskActivityText.title(activity, l: l)
    }

    private func activityDetail(_ activity: FamilyTaskActivitySnapshot) -> String? {
        FamilyTaskActivityText.detail(activity, l: l, localizedDate: localizedDate)
    }

    private func activitySymbol(_ kind: FamilyTaskActivityKind) -> String {
        FamilyTaskActivityText.symbol(kind)
    }

    private func activityTint(_ kind: FamilyTaskActivityKind) -> Color {
        FamilyTaskActivityText.tint(kind)
    }

    private func localizedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.option(for: appLanguage).localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func activityAccessibilityLabel(_ activity: FamilyTaskActivitySnapshot) -> String {
        [
            activity.isUnread ? l.tr(zh: "未读", en: "Unread", de: "Ungelesen") : nil,
            activityTitle(activity),
            activity.taskTitle,
            activityDetail(activity),
            localizedDate(activity.createdAt)
        ]
        .compactMap(\.self)
        .joined(separator: ". ")
    }
}
