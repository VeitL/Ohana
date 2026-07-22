//
//  FamilyTaskDetailView.swift
//  Ohana
//
//  Role-aware, value-only detail surface for Task Center family tasks.
//

import Foundation
import SwiftUI

enum TaskCenterFamilyTaskViewerRole: Equatable {
    case creator
    case assignee
    case familyMember
}

struct TaskCenterFamilyTaskDetailSnapshot {
    let taskID: UUID
    let title: String
    let note: String
    let emoji: String
    let creatorName: String
    let assigneeName: String?
    let viewerRole: TaskCenterFamilyTaskViewerRole
    let capabilities: FamilyTaskCapabilities
    let status: FamilyCollaborationTaskStatus
    let dueAt: Date?
    let isAllDay: Bool
    let isRecurring: Bool
    let allowsThisAndFutureCancellation: Bool
    let rewardCoconuts: Int
    let availableActions: Set<TaskCenterAvailableAction>
    let isLinkedToCalendar: Bool
    let activities: [FamilyTaskActivitySnapshot]
}

nonisolated struct FamilyTaskCancellationPresentationPolicy: Equatable {
    let availableScopes: [FamilyTaskEditScope]
    let requiresDestructiveConfirmation: Bool
    let showsPendingReviewWarning: Bool

    static func resolve(
        allowsThisAndFuture: Bool,
        status: FamilyCollaborationTaskStatus
    ) -> Self {
        FamilyTaskCancellationPresentationPolicy(
            availableScopes: allowsThisAndFuture ? [.onlyThis, .thisAndFuture] : [.onlyThis],
            requiresDestructiveConfirmation: true,
            showsPendingReviewWarning: status == .pendingReview
        )
    }
}

private enum FamilyTaskDetailComposerRoute: String, Identifiable {
    case decline
    case postpone
    case comment

    var id: String { rawValue }
}

struct FamilyTaskDetailView: View {
    let snapshot: TaskCenterFamilyTaskDetailSnapshot
    let onEdit: (() -> Void)?
    let onTaskAction: (TaskCenterAvailableAction) -> Bool
    let onDecline: (String) -> Bool
    let onPostpone: (Date) -> Bool
    let onComment: (String) -> Bool
    let onCancel: (FamilyTaskEditScope) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var composerRoute: FamilyTaskDetailComposerRoute?
    @State private var performingAction: TaskCenterAvailableAction?
    @State private var showsActionFailure = false
    @State private var showsEditConfirmation = false
    @State private var showsCancelScopeSelection = false
    @State private var showsCancelConfirmation = false
    @State private var pendingCancelScope: FamilyTaskEditScope?
    @State private var isCancelling = false
}

extension FamilyTaskDetailView {
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                heroSection
                collaborationSection
                scheduleSection
                noteSection
                activitySection
                linkedCalendarSection
                taskActionSection
                collaborationActionSection
                creatorManagementSection
            }
            .navigationTitle(l.tr(zh: "任务详情", en: "Task details", de: "Aufgabendetails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("family-task-detail-close")
                }

                if snapshot.capabilities.canEdit, onEdit != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            requestEdit()
                        } label: {
                            Label(
                                l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
                                systemImage: "pencil"
                            )
                        }
                        .accessibilityHint(l.tr(
                            zh: "打开发布者的任务编辑器，可修改内容或重新分配",
                            en: "Open the publisher's editor to update or reassign the task",
                            de: "Editor des Erstellers öffnen, um die Aufgabe zu ändern oder neu zuzuweisen"
                        ))
                        .accessibilityIdentifier("family-task-detail-edit")
                    }
                }
            }
        }
        .sheet(item: $composerRoute) { route in
            switch route {
            case .decline:
                FamilyTaskTextComposerSheet(
                    mode: .decline,
                    taskTitle: snapshot.title,
                    onSubmit: submitDecline
                )
                .presentationDetents([.medium])
            case .postpone:
                FamilyTaskPostponeSheet(
                    taskTitle: snapshot.title,
                    currentDueAt: snapshot.dueAt ?? Date(),
                    onSubmit: submitPostpone
                )
                .presentationDetents([.medium])
            case .comment:
                FamilyTaskTextComposerSheet(
                    mode: .comment,
                    taskTitle: snapshot.title,
                    onSubmit: submitComment
                )
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog(
            l.tr(
                zh: "编辑待审核任务？",
                en: "Edit the task awaiting review?",
                de: "Aufgabe in Prüfung bearbeiten?"
            ),
            isPresented: $showsEditConfirmation,
            titleVisibility: .visible
        ) {
            Button(l.tr(zh: "继续编辑", en: "Continue editing", de: "Weiter bearbeiten")) {
                editTask()
            }
            Button(l.tr(zh: "保持待审核", en: "Keep awaiting review", de: "In Prüfung lassen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "保存修改后，当前完成结果会被退回，任务重新进入执行中。",
                en: "Saving changes sends the current completion back and returns the task to in progress.",
                de: "Beim Speichern wird der aktuelle Abschluss zurückgegeben und die Aufgabe wieder geöffnet."
            ))
        }
        .confirmationDialog(
            l.tr(zh: "撤销哪些任务？", en: "Which tasks should be cancelled?", de: "Welche Aufgaben abbrechen?"),
            isPresented: $showsCancelScopeSelection,
            titleVisibility: .visible
        ) {
            Button(
                l.tr(zh: "仅撤销本次", en: "Cancel this occurrence only", de: "Nur dieses Vorkommen abbrechen"),
                role: .destructive
            ) {
                selectCancelScope(.onlyThis, followsScopeSelection: true)
            }
            Button(
                l.tr(zh: "撤销本次及以后", en: "Cancel this and future occurrences", de: "Dieses und folgende Vorkommen abbrechen"),
                role: .destructive
            ) {
                selectCancelScope(.thisAndFuture, followsScopeSelection: true)
            }
            Button(l.tr(zh: "保留任务", en: "Keep task", de: "Aufgabe behalten"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "这是重复任务。已完成的历史记录不会改变。",
                en: "This is a repeating task. Completed history will not change.",
                de: "Dies ist eine wiederkehrende Aufgabe. Abgeschlossene Einträge bleiben unverändert."
            ))
        }
        .confirmationDialog(
            cancelConfirmationTitle,
            isPresented: $showsCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                cancelConfirmationActionTitle,
                role: .destructive
            ) {
                confirmCancellation()
            }
            Button(l.tr(zh: "保留任务", en: "Keep task", de: "Aufgabe behalten"), role: .cancel) {}
        } message: {
            Text(cancelConfirmationMessage)
        }
        .alert(
            l.tr(zh: "操作未完成", en: "Could not complete", de: "Aktion nicht abgeschlossen"),
            isPresented: $showsActionFailure
        ) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "任务状态可能已经变化。请关闭详情并重试。",
                en: "The task may have changed. Close the details and try again.",
                de: "Die Aufgabe hat sich möglicherweise geändert. Schließe die Details und versuche es erneut."
            ))
        }
        .accessibilityIdentifier("family-task-detail-\(snapshot.taskID.uuidString)")
    }

    private var heroSection: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                Text(snapshot.emoji.isEmpty ? "🎯" : snapshot.emoji)
                    .font(OhanaFont.adaptive(size: 30, weight: .bold))
                    .frame(width: 52, height: 52)
                    .background(statusTint.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text(snapshot.title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        Label(statusTitle, systemImage: statusSymbol)
                        Text("·")
                            .accessibilityHidden(true)
                        Text(roleTitle)
                    }
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(statusTint)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snapshot.title). \(statusTitle). \(roleTitle)")
        }
    }

    private var collaborationSection: some View {
        Section {
            LabeledContent {
                Text(snapshot.creatorName)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label(
                    l.tr(zh: "发布者", en: "Publisher", de: "Erstellt von"),
                    systemImage: "person.crop.circle.badge.checkmark"
                )
            }

            LabeledContent {
                Text(snapshot.assigneeName ?? l.tr(
                    zh: "等待领取",
                    en: "Open to claim",
                    de: "Zur Übernahme offen"
                ))
                .multilineTextAlignment(.trailing)
            } label: {
                Label(
                    l.tr(zh: "执行者", en: "Assignee", de: "Zugewiesen an"),
                    systemImage: "person.crop.circle"
                )
            }

            Label(roleExplanation, systemImage: roleSymbol)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(l.tr(zh: "家庭分工", en: "Household roles", de: "Aufgabenverteilung"))
        }
    }

    private var scheduleSection: some View {
        Section(l.tr(zh: "安排", en: "Schedule", de: "Planung")) {
            if let dueAt = snapshot.dueAt {
                LabeledContent {
                    Text(localizedDueDate(dueAt))
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label(
                        l.tr(zh: "截止时间", en: "Due", de: "Fällig"),
                        systemImage: "calendar"
                    )
                }
            } else {
                LabeledContent {
                    Text(l.tr(zh: "未排期", en: "Unscheduled", de: "Ohne Termin"))
                } label: {
                    Label(
                        l.tr(zh: "截止时间", en: "Due", de: "Fällig"),
                        systemImage: "calendar.badge.minus"
                    )
                }
            }

            LabeledContent {
                Text(rewardTitle)
            } label: {
                Label(
                    l.tr(zh: "奖励", en: "Reward", de: "Belohnung"),
                    systemImage: "circle.hexagongrid.fill"
                )
            }

            if snapshot.isRecurring {
                Label(
                    l.tr(
                        zh: "当前操作只影响这一次任务",
                        en: "Current actions affect only this occurrence",
                        de: "Aktuelle Aktionen gelten nur für diesen Termin"
                    ),
                    systemImage: "repeat"
                )
                .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    @ViewBuilder
    private var noteSection: some View {
        let normalizedNote = snapshot.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedNote.isEmpty {
            Section(l.tr(zh: "任务说明", en: "Instructions", de: "Beschreibung")) {
                Text(normalizedNote)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var linkedCalendarSection: some View {
        if snapshot.isLinkedToCalendar {
            Section(l.tr(zh: "关联事项", en: "Linked item", de: "Verknüpfter Eintrag")) {
                Label(linkedCalendarExplanation, systemImage: "calendar.badge.clock")
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("family-task-detail-linked-calendar-readonly")
            }
        }
    }

    @ViewBuilder
    private var taskActionSection: some View {
        let actions = orderedActions
        if !actions.isEmpty {
            Section {
                ForEach(actions, id: \.self) { action in
                    taskActionButton(action)
                }
            } header: {
                Text(taskActionSectionTitle)
            } footer: {
                Text(taskActionExplanation)
            }
        } else if snapshot.viewerRole == .assignee, snapshot.status == .pendingReview {
            Section {
                Label(
                    l.tr(
                        zh: "已提交，正在等待发布者确认",
                        en: "Submitted and waiting for the publisher",
                        de: "Eingereicht und wartet auf die Bestätigung des Erstellers"
                    ),
                    systemImage: "hourglass"
                )
                .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    @ViewBuilder
    private var collaborationActionSection: some View {
        if snapshot.capabilities.canDecline ||
            snapshot.capabilities.canPostpone ||
            snapshot.capabilities.canComment {
            Section(l.tr(zh: "协作", en: "Collaborate", de: "Zusammenarbeit")) {
                if snapshot.capabilities.canDecline {
                    collaborationButton(
                        title: l.tr(zh: "拒绝任务", en: "Decline task", de: "Aufgabe ablehnen"),
                        symbol: "hand.raised.slash.fill",
                        tint: .goRed,
                        identifier: "decline"
                    ) {
                        composerRoute = .decline
                    }
                }

                if snapshot.capabilities.canPostpone {
                    collaborationButton(
                        title: l.tr(zh: "延期", en: "Postpone", de: "Verschieben"),
                        symbol: "calendar.badge.clock",
                        tint: .goPurple,
                        identifier: "postpone"
                    ) {
                        composerRoute = .postpone
                    }
                }

                if snapshot.capabilities.canComment {
                    collaborationButton(
                        title: l.tr(zh: "填写备注", en: "Add note", de: "Notiz hinzufügen"),
                        symbol: "text.bubble.fill",
                        tint: .goPrimary,
                        identifier: "comment"
                    ) {
                        composerRoute = .comment
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var creatorManagementSection: some View {
        if snapshot.capabilities.canCancel {
            Section {
                Button(role: .destructive) {
                    requestCancellation()
                } label: {
                    Label(
                        l.tr(zh: "撤销任务", en: "Cancel task", de: "Aufgabe abbrechen"),
                        systemImage: "xmark.circle"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityHint(l.tr(
                    zh: snapshot.allowsThisAndFutureCancellation
                        ? "选择仅撤销本次或撤销本次及以后"
                        : "保留协作记录并停止这项任务",
                    en: snapshot.allowsThisAndFutureCancellation
                        ? "Choose whether to cancel this occurrence or this and future occurrences"
                        : "Keep the collaboration history and stop this task",
                    de: snapshot.allowsThisAndFutureCancellation
                        ? "Auswählen, ob nur dieses oder auch folgende Vorkommen abgebrochen werden"
                        : "Verlauf behalten und diese Aufgabe beenden"
                ))
                .disabled(isCancelling)
                .accessibilityIdentifier("family-task-detail-cancel")
            } header: {
                Text(l.tr(zh: "发布者管理", en: "Publisher controls", de: "Verwaltung"))
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if !snapshot.activities.isEmpty {
            Section {
                ForEach(snapshot.activities) { activity in
                    activityRow(activity)
                }
            } header: {
                Text(l.tr(zh: "本次动态", en: "Occurrence activity", de: "Aktivität dieses Vorkommens"))
            } footer: {
                Text(l.tr(
                    zh: "这里只显示本次任务最近 100 条协作记录。",
                    en: "This shows up to the 100 most recent collaboration records for this occurrence.",
                    de: "Hier werden bis zu 100 aktuelle Einträge für dieses Vorkommen angezeigt."
                ))
            }
        }
    }

    private func activityRow(_ activity: FamilyTaskActivitySnapshot) -> some View {
        let title = FamilyTaskActivityText.title(activity, l: l)
        let detail = FamilyTaskActivityText.detail(
            activity,
            l: l,
            localizedDate: localizedActivityDate
        )
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: FamilyTaskActivityText.symbol(activity.kind))
                .font(OhanaFont.adaptive(size: 14, weight: .bold))
                .foregroundStyle(FamilyTaskActivityText.tint(activity.kind))
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive activity icon; the row exposes a text label
                .background(FamilyTaskActivityText.tint(activity.kind).opacity(0.13), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(localizedActivityDate(activity.createdAt))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [title, detail, localizedActivityDate(activity.createdAt)]
                .compactMap(\.self)
                .joined(separator: ". ")
        )
        .accessibilityIdentifier("family-task-detail-activity-\(activity.id.uuidString)")
    }

    private func taskActionButton(_ action: TaskCenterAvailableAction) -> some View {
        let isPerforming = performingAction == action
        return Button {
            perform(action)
        } label: {
            HStack(spacing: 10) {
                if isPerforming {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: actionSymbol(action))
                        .accessibilityHidden(true)
                }
                Text(actionTitle(action))
                    .font(OhanaFont.callout(.bold))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(actionTint(action))
        .disabled(performingAction != nil)
        .accessibilityLabel(actionTitle(action))
        .accessibilityIdentifier("family-task-detail-action-\(action.rawValue)-\(snapshot.taskID.uuidString)")
    }

    private func collaborationButton(
        title: String,
        symbol: String,
        tint: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("family-task-detail-\(identifier)")
    }

    private var orderedActions: [TaskCenterAvailableAction] {
        let order: [TaskCenterAvailableAction] = [.approve, .reject, .claim, .submitForReview, .complete]
        return order.filter(snapshot.availableActions.contains)
    }

    private var statusTitle: String {
        switch snapshot.status {
        case .active:
            l.tr(zh: "待处理", en: "To do", de: "Offen")
        case .claimed:
            l.tr(zh: "进行中", en: "In progress", de: "In Bearbeitung")
        case .declined:
            l.tr(zh: "已拒绝", en: "Declined", de: "Abgelehnt")
        case .pendingReview:
            l.tr(zh: "待发布者确认", en: "Awaiting review", de: "Wartet auf Prüfung")
        case .completed:
            l.tr(zh: "已完成", en: "Completed", de: "Erledigt")
        case .cancelled:
            l.tr(zh: "已撤销", en: "Cancelled", de: "Abgebrochen")
        }
    }

    private var statusSymbol: String {
        switch snapshot.status {
        case .active: "circle"
        case .claimed: "figure.walk.motion"
        case .declined: "hand.raised.slash.fill"
        case .pendingReview: "hourglass"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var statusTint: Color {
        switch snapshot.status {
        case .declined, .cancelled: .goRed
        case .pendingReview: .goYellow
        case .completed: .goTeal
        case .active, .claimed: .goPrimary
        }
    }

    private var roleTitle: String {
        switch snapshot.viewerRole {
        case .creator:
            l.tr(zh: "你是发布者", en: "You are the publisher", de: "Du hast die Aufgabe erstellt")
        case .assignee:
            l.tr(zh: "你是执行者", en: "You are the assignee", de: "Du führst die Aufgabe aus")
        case .familyMember:
            l.tr(zh: "只读查看", en: "Read only", de: "Nur lesen")
        }
    }

    private var roleExplanation: String {
        switch snapshot.viewerRole {
        case .creator where snapshot.status == .declined:
            l.tr(
                zh: "执行者已拒绝。你可以编辑并重新分配，或撤销任务。",
                en: "The assignee declined. You can edit and reassign the task, or cancel it.",
                de: "Die Aufgabe wurde abgelehnt. Du kannst sie bearbeiten, neu zuweisen oder abbrechen."
            )
        case .creator:
            l.tr(
                zh: "你可以编辑或撤销任务；提交完成后，也由你确认并发放奖励。",
                en: "You can edit or cancel this task and review submitted work before its reward is released.",
                de: "Du kannst die Aufgabe bearbeiten oder abbrechen und eingereichte Arbeit vor der Belohnung prüfen."
            )
        case .assignee:
            l.tr(
                zh: "你不能修改发布内容，只能使用当前允许的完成、拒绝、延期和备注操作。",
                en: "You cannot edit the publisher's task. You can only complete, decline, postpone, or add notes when available.",
                de: "Du kannst die Aufgabe nicht bearbeiten, sondern sie nur erledigen, ablehnen, verschieben oder kommentieren."
            )
        case .familyMember:
            l.tr(
                zh: "这项任务没有分配给你，因此当前只能查看。",
                en: "This task is not assigned to you, so it is read only.",
                de: "Diese Aufgabe ist dir nicht zugewiesen und kann daher nur gelesen werden."
            )
        }
    }

    private var roleSymbol: String {
        switch snapshot.viewerRole {
        case .creator: "person.badge.key.fill"
        case .assignee: "person.fill.checkmark"
        case .familyMember: "eye.fill"
        }
    }

    private var linkedCalendarExplanation: String {
        if snapshot.viewerRole == .creator {
            return l.tr(
                zh: "这项家庭任务关联了日历事项。请使用右上角“编辑”调整任务分工。",
                en: "This household task is linked to a calendar item. Use Edit to adjust the assignment.",
                de: "Diese Haushaltsaufgabe ist mit einem Kalendereintrag verknüpft. Über „Bearbeiten“ lässt sich die Zuweisung ändern."
            )
        }
        return l.tr(
            zh: "这项家庭任务关联了日历事项。执行者可以查看和处理任务，但不能编辑关联事项。",
            en: "This household task is linked to a calendar item. Assignees can view and act on it but cannot edit the linked item.",
            de: "Diese Haushaltsaufgabe ist mit einem Kalendereintrag verknüpft. Ausführende können sie bearbeiten, aber den Eintrag nicht ändern."
        )
    }

    private var rewardTitle: String {
        guard snapshot.rewardCoconuts > 0 else {
            return l.tr(zh: "无椰子奖励", en: "No coconut reward", de: "Keine Kokosnuss-Belohnung")
        }
        return "+\(snapshot.rewardCoconuts) 🥥"
    }

    private var taskActionSectionTitle: String {
        switch snapshot.viewerRole {
        case .creator:
            l.tr(zh: "审核", en: "Review", de: "Prüfung")
        case .assignee:
            l.tr(zh: "执行任务", en: "Task actions", de: "Aufgabe bearbeiten")
        case .familyMember:
            l.tr(zh: "可用操作", en: "Available actions", de: "Verfügbare Aktionen")
        }
    }

    private var taskActionExplanation: String {
        if snapshot.availableActions.contains(.submitForReview) {
            return l.tr(
                zh: "提交完成后，任务会等待发布者确认并发放椰子。",
                en: "After submission, the task waits for the publisher to confirm it and release the coconuts.",
                de: "Nach dem Einreichen wartet die Aufgabe auf Bestätigung und Freigabe der Kokosnüsse."
            )
        }
        if snapshot.availableActions.contains(.approve) {
            return l.tr(
                zh: "确认完成后，预设的椰子奖励会发给执行者；退回则继续等待执行。",
                en: "Confirming releases the preset reward; sending it back returns the task to the assignee.",
                de: "Bestätigen gibt die Belohnung frei; Zurückgeben weist die Aufgabe erneut zu."
            )
        }
        return l.tr(
            zh: "这里只显示当前身份和任务状态允许的操作。",
            en: "Only actions allowed for your current role and task state appear here.",
            de: "Hier erscheinen nur Aktionen, die für deine aktuelle Rolle und den Aufgabenstatus zulässig sind."
        )
    }

    private func actionTitle(_ action: TaskCenterAvailableAction) -> String {
        switch action {
        case .complete:
            l.tr(zh: "标记完成", en: "Mark complete", de: "Als erledigt markieren")
        case .claim:
            l.tr(zh: "领取任务", en: "Claim task", de: "Aufgabe übernehmen")
        case .submitForReview:
            l.tr(zh: "标记完成并提交", en: "Complete and submit", de: "Erledigen und einreichen")
        case .approve:
            l.tr(zh: "确认完成并发放奖励", en: "Confirm and release reward", de: "Bestätigen und Belohnung freigeben")
        case .reject:
            l.tr(zh: "退回重做", en: "Send back for redo", de: "Zur Überarbeitung zurückgeben")
        }
    }

    private func actionSymbol(_ action: TaskCenterAvailableAction) -> String {
        switch action {
        case .complete: "checkmark.circle.fill"
        case .claim: "hand.raised.fill"
        case .submitForReview: "paperplane.fill"
        case .approve: "checkmark.seal.fill"
        case .reject: "arrow.uturn.backward.circle.fill"
        }
    }

    private func actionTint(_ action: TaskCenterAvailableAction) -> Color {
        switch action {
        case .complete, .approve: .goTeal
        case .claim, .submitForReview: .goPrimary
        case .reject: .goRed
        }
    }

    private func localizedDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.option(for: appLanguage).localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = snapshot.isAllDay ? .none : .short
        return formatter.string(from: date)
    }

    private func localizedActivityDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.option(for: appLanguage).localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func perform(_ action: TaskCenterAvailableAction) {
        guard performingAction == nil else { return }
        performingAction = action
        OhanaFeedback.light()
        guard onTaskAction(action) else {
            performingAction = nil
            showsActionFailure = true
            OhanaFeedback.error()
            return
        }
        OhanaFeedback.success()
        dismiss()
    }

    private func submitDecline(_ reason: String) -> Bool {
        finishNestedMutation(onDecline(reason))
    }

    private func submitPostpone(_ date: Date) -> Bool {
        finishNestedMutation(onPostpone(date))
    }

    private func submitComment(_ body: String) -> Bool {
        finishNestedMutation(onComment(body))
    }

    private func finishNestedMutation(_ didSucceed: Bool) -> Bool {
        guard didSucceed else { return false }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            dismiss()
        }
        return true
    }

    private var cancellationPolicy: FamilyTaskCancellationPresentationPolicy {
        FamilyTaskCancellationPresentationPolicy.resolve(
            allowsThisAndFuture: snapshot.allowsThisAndFutureCancellation,
            status: snapshot.status
        )
    }

    private var cancelConfirmationTitle: String {
        pendingCancelScope == .thisAndFuture
            ? l.tr(
                zh: "确认撤销本次及以后？",
                en: "Cancel this and future occurrences?",
                de: "Dieses und folgende Vorkommen abbrechen?"
            )
            : l.tr(zh: "确认撤销本次？", en: "Cancel this occurrence?", de: "Dieses Vorkommen abbrechen?")
    }

    private var cancelConfirmationActionTitle: String {
        pendingCancelScope == .thisAndFuture
            ? l.tr(
                zh: "撤销本次及以后",
                en: "Cancel this and future",
                de: "Dieses und folgende abbrechen"
            )
            : l.tr(zh: "仅撤销本次", en: "Cancel this occurrence", de: "Dieses Vorkommen abbrechen")
    }

    private var cancelConfirmationMessage: String {
        if cancellationPolicy.showsPendingReviewWarning {
            return pendingCancelScope == .thisAndFuture
                ? l.tr(
                    zh: "本次任务正在等待确认。撤销后不会发放奖励，并会停止此系列之后的任务；历史动态会保留。",
                    en: "This task is awaiting review. Cancelling will not pay its reward and will stop future occurrences; activity history remains.",
                    de: "Diese Aufgabe wartet auf Prüfung. Es wird keine Belohnung ausgezahlt und folgende Vorkommen werden beendet; der Verlauf bleibt erhalten."
                )
                : l.tr(
                    zh: "本次任务正在等待确认。撤销后不会发放奖励，历史动态会保留。",
                    en: "This task is awaiting review. Cancelling will not pay its reward, and its activity history remains.",
                    de: "Diese Aufgabe wartet auf Prüfung. Es wird keine Belohnung ausgezahlt; der Verlauf bleibt erhalten."
                )
        }
        return pendingCancelScope == .thisAndFuture
            ? l.tr(
                zh: "本次及之后未结束的任务将停止，已完成历史不会改变。",
                en: "This and future unfinished occurrences will stop; completed history will not change.",
                de: "Dieses und folgende offene Vorkommen werden beendet; abgeschlossene Einträge bleiben unverändert."
            )
            : l.tr(
                zh: "任务会保留在协作消息中，但执行者将不再需要处理本次任务。",
                en: "The task remains in collaboration history, but the assignee will no longer need to handle this occurrence.",
                de: "Die Aufgabe bleibt im Verlauf, muss für dieses Vorkommen aber nicht mehr bearbeitet werden."
            )
    }

    private func requestCancellation() {
        let scopes = cancellationPolicy.availableScopes
        if scopes.count > 1 {
            showsCancelScopeSelection = true
        } else if let scope = scopes.first {
            selectCancelScope(scope, followsScopeSelection: false)
        }
    }

    private func selectCancelScope(
        _ scope: FamilyTaskEditScope,
        followsScopeSelection: Bool
    ) {
        guard cancellationPolicy.availableScopes.contains(scope) else { return }
        showsCancelScopeSelection = false
        pendingCancelScope = scope
        if cancellationPolicy.requiresDestructiveConfirmation {
            if followsScopeSelection {
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
                    guard pendingCancelScope == scope else { return }
                    showsCancelConfirmation = true
                }
            } else {
                showsCancelConfirmation = true
            }
        } else {
            runCancellation(scope: scope)
        }
    }

    private func confirmCancellation() {
        guard let scope = pendingCancelScope else { return }
        runCancellation(scope: scope)
    }

    private func runCancellation(scope: FamilyTaskEditScope) {
        guard !isCancelling else { return }
        isCancelling = true
        OhanaFeedback.light()
        Task { @MainActor in
            let didCancel = await onCancel(scope)
            isCancelling = false
            guard didCancel else {
                showsActionFailure = true
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.success()
            dismiss()
        }
    }

    private func editTask() {
        guard let onEdit else { return }
        OhanaFeedback.light()
        dismiss()
        onEdit()
    }

    private func requestEdit() {
        if snapshot.status == .pendingReview {
            showsEditConfirmation = true
        } else {
            editTask()
        }
    }
}

private enum FamilyTaskTextComposerMode {
    case decline
    case comment
}

private struct FamilyTaskTextComposerSheet: View {
    let mode: FamilyTaskTextComposerMode
    let taskTitle: String
    let onSubmit: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var text = ""
    @State private var isSubmitting = false
    @State private var showsFailure = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(taskTitle)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)

                    TextField(prompt, text: $text, axis: .vertical)
                        .lineLimit(3 ... 7)
                        .accessibilityLabel(fieldLabel)
                        .accessibilityIdentifier("family-task-\(identifier)-text")
                } footer: {
                    Text(footer)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, role: mode == .decline ? .destructive : nil) {
                        submit()
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .accessibilityIdentifier("family-task-\(identifier)-submit")
                }
            }
        }
        .alert(
            l.tr(zh: "操作未完成", en: "Could not complete", de: "Aktion nicht abgeschlossen"),
            isPresented: $showsFailure
        ) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        }
    }

    private var title: String {
        switch mode {
        case .decline: l.tr(zh: "拒绝任务", en: "Decline task", de: "Aufgabe ablehnen")
        case .comment: l.tr(zh: "填写备注", en: "Add note", de: "Notiz hinzufügen")
        }
    }

    private var fieldLabel: String {
        switch mode {
        case .decline: l.tr(zh: "拒绝原因", en: "Reason for declining", de: "Grund der Ablehnung")
        case .comment: l.tr(zh: "任务备注", en: "Task note", de: "Aufgabennotiz")
        }
    }

    private var prompt: String {
        switch mode {
        case .decline: l.tr(zh: "原因（可选）", en: "Reason (optional)", de: "Grund (optional)")
        case .comment: l.tr(zh: "写下进度或需要说明的情况", en: "Share progress or context", de: "Fortschritt oder Hinweise notieren")
        }
    }

    private var footer: String {
        switch mode {
        case .decline:
            l.tr(
                zh: "发布者会在协作消息中看到拒绝结果和原因。",
                en: "The publisher will see the decline and its reason in collaboration messages.",
                de: "Der Ersteller sieht die Ablehnung und den Grund in den Nachrichten."
            )
        case .comment:
            l.tr(
                zh: "备注会追加到协作消息，不会覆盖发布者的任务说明。",
                en: "The note is appended to collaboration messages and does not replace the publisher's instructions.",
                de: "Die Notiz wird dem Verlauf hinzugefügt und ersetzt nicht die Beschreibung des Erstellers."
            )
        }
    }

    private var submitTitle: String {
        switch mode {
        case .decline: l.tr(zh: "确认拒绝", en: "Decline", de: "Ablehnen")
        case .comment: l.tr(zh: "发送备注", en: "Send note", de: "Notiz senden")
        }
    }

    private var identifier: String {
        switch mode {
        case .decline: "decline"
        case .comment: "comment"
        }
    }

    private var canSubmit: Bool {
        mode == .decline || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        guard onSubmit(text) else {
            isSubmitting = false
            showsFailure = true
            OhanaFeedback.error()
            return
        }
        OhanaFeedback.success()
        dismiss()
    }
}

private struct FamilyTaskPostponeSheet: View {
    let taskTitle: String
    let currentDueAt: Date
    let onSubmit: (Date) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var newDueAt: Date
    @State private var isSubmitting = false
    @State private var showsFailure = false

    private var l: L10n { L10n(appLanguage) }

    init(taskTitle: String, currentDueAt: Date, onSubmit: @escaping (Date) -> Bool) {
        self.taskTitle = taskTitle
        self.currentDueAt = currentDueAt
        self.onSubmit = onSubmit
        let baseline = max(currentDueAt, Date())
        _newDueAt = State(initialValue: baseline.addingTimeInterval(24 * 60 * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(taskTitle)
                        .font(OhanaFont.callout(.bold))
                    DatePicker(
                        l.tr(zh: "新的截止时间", en: "New due date", de: "Neue Fälligkeit"),
                        selection: $newDueAt,
                        in: minimumDueAt ... Date.distantFuture,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("family-task-postpone-date")
                } footer: {
                    Text(l.tr(
                        zh: "延期会立即生效，并在协作消息中通知发布者。重复任务只影响当前这一次。",
                        en: "The new time takes effect immediately and appears in the publisher's collaboration messages. Repeating tasks change only this occurrence.",
                        de: "Der neue Termin gilt sofort und erscheint in den Nachrichten des Erstellers. Bei Wiederholungen wird nur dieser Termin geändert."
                    ))
                }
            }
            .navigationTitle(l.tr(zh: "延期", en: "Postpone", de: "Verschieben"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) {
                        submit()
                    }
                    .disabled(isSubmitting || newDueAt < minimumDueAt)
                    .accessibilityIdentifier("family-task-postpone-submit")
                }
            }
        }
        .alert(
            l.tr(zh: "延期未保存", en: "Could not postpone", de: "Verschieben fehlgeschlagen"),
            isPresented: $showsFailure
        ) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        }
    }

    private var minimumDueAt: Date {
        max(currentDueAt, Date()).addingTimeInterval(60)
    }

    private func submit() {
        guard !isSubmitting, newDueAt >= minimumDueAt else { return }
        isSubmitting = true
        guard onSubmit(newDueAt) else {
            isSubmitting = false
            showsFailure = true
            OhanaFeedback.error()
            return
        }
        OhanaFeedback.success()
        dismiss()
    }
}
