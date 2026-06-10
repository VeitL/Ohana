//
//  HumanDetailView+RemindersActions.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension HumanDetailView {
    var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.goOrange)
                Text("待办提醒")
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
                        Text("暂无待办提醒").font(OhanaFont.callout()).foregroundStyle(Color(hex: "6B82C4"))
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
        .goIslandModuleCard(cornerRadius: 24)
        .padding(.horizontal, 16)
    }

    func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌").font(OhanaFont.title3())
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.event?.title ?? "提醒")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                Text(reminder.scheduledAt, style: .date)
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color(hex: "6B82C4"))
            }
            Spacer()
            if let assigneeId = reminder.event?.assigneeId,
               let assignee = allHumans.first(where: { $0.id.uuidString == assigneeId }),
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
                privacyPlaceholderCard(label: "备注")
            } else if !human.notes.isEmpty {
                VStack(spacing: 10) {
                    HumanPrivateDataNotice(human: human, field: .note)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(Color.goPrimary)
                            Text("备注")
                                .font(OhanaFont.headline(.bold))
                                .foregroundStyle(Color(hex: "1E3A8A"))
                        }
                        Text(human.notes)
                            .font(OhanaFont.body())
                            .foregroundStyle(Color(hex: "475569"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .goIslandModuleCard(cornerRadius: 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Delete Section
    var deleteSection: some View {
        Button(role: .destructive) { showingDeleteConfirm = true } label: {
            Label("删除成员", systemImage: "trash")
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1))
        }
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
            RoundedRectangle(cornerRadius: 2)
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
        let command = DomainCommand.memberDeletion(entityID: human.id, kind: EntityKind.human.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                human,
                activeHumanID: activeHumanIdStr,
                note: "human.detail.delete"
            )
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
            dismiss()
        }
    }
}
