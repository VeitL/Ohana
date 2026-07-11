//
//  HumanDetailView+RemindersActions.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension HumanDetailView {
    var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.goOrange)
                Text(l.tr(zh: "待办提醒", en: "Pending Reminders", de: "Ausstehende Erinnerungen"))
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                Spacer()
                if !humanReminders.isEmpty {
                    Text("\(humanReminders.count)")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.goOrange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.goOrange.opacity(0.15), in: Capsule())
                }
            }

            if humanReminders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(OhanaFont.metric(size: 28)).foregroundStyle(Color(hex: "6B82C4").opacity(0.35)) // a11y: allow decorative icon covered by surrounding text or control
                        Text(l.tr(zh: "暂无待办提醒", en: "No pending reminders", de: "Keine ausstehenden Erinnerungen"))
                            .font(OhanaFont.callout())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(Array(humanReminders.enumerated()), id: \.element.id) { idx, reminder in
                    if idx > 0 {
                        Rectangle().fill(Color.ohanaDivider).frame(height: 1)
                    }
                    reminderRow(reminder)
                }
            }
        }
        .padding(16)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .padding(.horizontal, 16)
    }

    func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌").font(OhanaFont.title3())
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.event?.title ?? l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                Text(reminder.scheduledAt, style: .date)
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color(hex: "6B82C4"))
            }
            Spacer()
            if let event = reminder.event,
               let assignee = MemberLifecycleActiveScheduleResolver.humanAssignee(for: event, humans: allHumans),
               assignee.id != human.id {
                NudgeButton(targetHuman: assignee)
            }
            Button { completeReminder(reminder) } label: {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            Button { skipReminder(reminder) } label: {
                Image(systemName: "forward.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goYellow)
            }
        }
    }

    // MARK: - Notes Section
    var notesSection: some View {
        Group {
            if human.isPrivate(.note, viewedBy: activeHumanId) {
                privacyPlaceholderCard(label: l.tr(zh: "备注", en: "Notes", de: "Notizen"))
            } else if !human.notes.isEmpty {
                VStack(spacing: 10) {
                    HumanPrivateDataNotice(human: human, field: .note)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(Color.goPrimary)
                            Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                                .font(OhanaFont.headline(.bold))
                                .foregroundStyle(Color(hex: "1E3A8A"))
                        }
                        Text(human.notes)
                            .font(OhanaFont.body())
                            .foregroundStyle(Color(hex: "475569"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Lifecycle & Danger Zone
    var humanLifecycleDangerZone: some View {
        HumanLifecycleDangerZone(
            human: human,
            onMarkPassedAway: markHumanPassedAway,
            onUndoPassedAway: undoHumanPassedAway,
            onDelete: deleteHumanAndReturnHome
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    func humanChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
    }

    func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: OhanaRadius.hairline)
                .fill(Color.goPrimary)
                .frame(width: 3, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(text)
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Actions
    func completeReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.reminderCompletion(reminderID: reminder.id)) {
            ReminderCommandExecutor(context: modelContext, services: appServices).complete(
                reminder,
                by: human.id.uuidString,
                note: "human.detail.reminder.complete"
            )
        }
    }

    func skipReminder(_ reminder: Reminder) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.reminderCompletion(reminderID: reminder.id)) {
            ReminderCommandExecutor(context: modelContext, services: appServices).skip(
                reminder,
                by: human.id.uuidString,
                note: "human.detail.reminder.skip"
            )
        }
    }

    func deleteHumanAndReturnHome() {
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: human.id, kind: EntityKind.human.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                human,
                activeHumanID: activeHumanID,
                note: "human.detail.delete"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            if case .pending = result.attachmentCleanup {
                appServices.islandToasts.show(l.tr(
                    zh: "成员已删除，但其本地备注附件未能完全清理。请联系支持。",
                    en: "The member was deleted, but local note attachments could not be fully removed. Contact support.",
                    de: "Das Mitglied wurde gelöscht, aber lokale Notizanhänge konnten nicht vollständig entfernt werden. Kontaktiere den Support."
                ))
            }
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
        }
    }

    func markHumanPassedAway(date: Date) {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: date,
                note: "human.detail.passed.mark"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func undoHumanPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.undo"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "human.detail.passed.undo"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }
}
