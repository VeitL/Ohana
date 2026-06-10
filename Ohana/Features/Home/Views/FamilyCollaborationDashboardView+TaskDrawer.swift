//
//  FamilyCollaborationDashboardView+TaskDrawer.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    var taskDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: drawerIcon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(drawerTint)
                Text(drawerTitle)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }

            if drawerRows.isEmpty {
                compactEmpty(icon: "checkmark.seal.fill", text: emptyDrawerText)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(drawerRows.prefix(4))) { row in
                        collaborationTaskRow(row)
                    }
                }
            }

            Button {
                openMoreCollaboration()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    Text(l.tr(zh: "更多", en: "More", de: "Mehr"))
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.top, 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    var drawerIcon: String {
        switch selectedTaskScope {
        case .mine: "person.crop.circle.badge.clock"
        case .pet: "pawprint.fill"
        case .bounty: "target"
        }
    }

    var drawerTint: Color {
        switch selectedTaskScope {
        case .mine: Color.goPurple
        case .pet: Color.goYellow
        case .bounty: Color.goTeal
        }
    }

    var drawerTitle: String {
        switch selectedTaskScope {
        case .mine:
            l.tr(zh: "发给我的任务", en: "Assigned to me", de: "Meine Aufgaben")
        case .pet:
            selectedPet.map { l.tr(zh: "\($0.name) 的待办", en: "\($0.name)'s tasks", de: "\($0.name): Aufgaben") }
                ?? l.tr(zh: "宠物待办", en: "Pet tasks", de: "Tieraufgaben")
        case .bounty:
            l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämien")
        }
    }

    var emptyDrawerText: String {
        switch selectedTaskScope {
        case .mine:
            l.tr(zh: "已清空", en: "All clear", de: "Alles klar")
        case .pet:
            l.tr(zh: "已照顾", en: "Covered", de: "Versorgt")
        case .bounty:
            l.tr(zh: "暂无悬赏", en: "No bounty", de: "Keine Prämie")
        }
    }

    enum CollaborationRow: Identifiable {
        case reminder(Reminder)
        case task(FamilyCollaborationTask)

        var id: String {
            switch self {
            case let .reminder(reminder): "reminder-\(reminder.id.uuidString)"
            case let .task(task): "task-\(task.id.uuidString)"
            }
        }
    }

    var drawerRows: [CollaborationRow] {
        switch selectedTaskScope {
        case .mine:
            return assignedFamilyTasks.map { .task($0) }
        case .bounty:
            return bountyFamilyTasks.map { .task($0) }
        case .pet:
            guard let pet = selectedPet else { return [] }
            let taskRows = familyTasks(for: pet).map { CollaborationRow.task($0) }
            let assignedReminderIds = Set(taskRows.compactMap { row -> String? in
                if case let .task(task) = row { return task.relatedReminderId }
                return nil
            })
            let reminderRows = openReminders(for: pet)
                .filter { !assignedReminderIds.contains($0.id.uuidString) }
                .map { CollaborationRow.reminder($0) }
            return taskRows + reminderRows
        }
    }

    func collaborationTaskRow(_ row: CollaborationRow) -> some View {
        switch row {
        case let .reminder(reminder):
            return AnyView(reminderAssignmentRow(reminder))
        case let .task(task):
            return AnyView(familyTaskRow(task))
        }
    }

    func reminderAssignmentRow(_ reminder: Reminder) -> some View {
        let assignTitle = l.tr(zh: "分配", en: "Assign", de: "Zuweisen")
        return HStack(spacing: 12) {
            Image(systemName: reminder.event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.event?.title ?? l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                presentEditor(.assignReminder(reminder.id))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(assignTitle)
                        .font(OhanaFont.caption(.black))
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(assignTitle)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .onTapGesture {
            presentEditor(.assignReminder(reminder.id))
        }
    }

    func familyTaskRow(_ task: FamilyCollaborationTask) -> some View {
        HStack(spacing: 12) {
            Text(task.emoji)
                .font(OhanaFont.title3(.black))
                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(taskSubtitle(task))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if task.rewardCoconuts > 0 {
                Text("+\(task.rewardCoconuts)🥥")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.goYellow, in: Capsule())
                    .ohanaPing(
                        trigger: "\(task.id.uuidString)-\(task.statusRaw)",
                        accent: Color.goYellow,
                        isEnabled: task.status == .pendingReview
                    )
                    .ohanaShine(trigger: task.statusRaw, cornerRadius: OhanaRadius.row, isEnabled: task.status == .pendingReview)
            }
            taskPrimaryAction(task)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .onTapGesture {
            presentEditor(.editTask(task.id))
        }
    }

    @ViewBuilder
    func taskPrimaryAction(_ task: FamilyCollaborationTask) -> some View {
        if task.status == .pendingReview, task.createdById == activeHumanId {
            HStack(spacing: 6) {
                smallAction(title: l.tr(zh: "退回", en: "Redo", de: "Zurück"), color: Color.goRed) {
                    runFamilyTaskCommand {
                        commandExecutor.rejectCompletion(task, by: currentHuman)
                    }
                }
                smallAction(title: l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), color: Color.goPrimary) {
                    runFamilyTaskCommand {
                        commandExecutor.confirmCompletion(task, by: currentHuman)
                    }
                }
            }
        } else if task.status == .pendingReview {
            Text(l.tr(zh: "待确认", en: "Review", de: "Prüfung"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goYellow)
        } else if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            smallAction(title: l.tr(zh: "完成", en: "Done", de: "Fertig"), color: Color.goPrimary) {
                runFamilyTaskCommand {
                    commandExecutor.complete(task, by: currentHuman)
                }
            }
        } else if task.isOpen, let human = currentHuman {
            smallAction(title: l.tr(zh: "接手", en: "Take", de: "Nehmen"), color: Color.goTeal) {
                runFamilyTaskCommand {
                    commandExecutor.claim(task, by: human)
                }
            }
        } else if task.createdById == activeHumanId {
            Text(l.tr(zh: "编辑", en: "Edit", de: "Bearb."))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    func taskSubtitle(_ task: FamilyCollaborationTask) -> String {
        if task.status == .pendingReview {
            let performer = task.completedByName ?? l.tr(zh: "对方", en: "someone", de: "jemand")
            if task.createdById == activeHumanId {
                return l.tr(
                    zh: "\(performer) 已提交，等你确认",
                    en: "\(performer) submitted it, awaiting your confirmation",
                    de: "\(performer) hat eingereicht, wartet auf deine Bestätigung"
                )
            }
            return l.tr(
                zh: "已提交，等待 \(task.createdByName) 确认",
                en: "Submitted, waiting for \(task.createdByName)",
                de: "Eingereicht, wartet auf \(task.createdByName)"
            )
        }
        let target = task.assignedToName ?? task.claimedByName ?? l.tr(zh: "全家可接", en: "open", de: "offen")
        let due = task.dueAt.map { " · \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
        return "\(task.createdByName) → \(target)\(due)"
    }

    func runFamilyTaskCommand(_ command: @escaping @MainActor () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        OhanaFrameScheduler.runAfterNextFrame {
            command()
        }
    }

    func openMoreCollaboration() {
        activeSheetRoute = .moreCollaboration
    }

    func dismissMoreCollaboration() {
        if activeSheetRoute == .moreCollaboration {
            activeSheetRoute = nil
        }
    }

    func familyTasks(for pet: Pet) -> [FamilyCollaborationTask] {
        activeFamilyTasks.filter { $0.relatedPetId == pet.id.uuidString }
    }

    func assignedTasks(for pet: Pet) -> [FamilyCollaborationTask] {
        familyTasks(for: pet).filter { $0.assignedToId == activeHumanId || $0.claimedById == activeHumanId }
    }

    func petTaskCount(_ pet: Pet?) -> Int {
        guard let pet else { return 0 }
        return familyTasks(for: pet).count + openReminders(for: pet).count
    }
}
