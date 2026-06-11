//
//  FamilyCollaborationDashboardView+Overview.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "今日协作", en: "Today care", de: "Pflege heute"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(openFocusCount == 0
                        ? l.tr(zh: "全家照护节奏很稳。", en: "The family rhythm is steady.", de: "Der Familienrhythmus ist stabil.")
                        : l.tr(zh: "还有 \(openFocusCount) 个协作点。", en: "\(openFocusCount) care points remain.", de: "\(openFocusCount) Pflegepunkte offen."))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(Int(boardProgress * 100))%")
                    .font(OhanaFont.metric(size: 28, .black))
                    .foregroundStyle(Color.goPrimary)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.goPrimary, Color.goTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * boardProgress))
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .animation(GoMotion.feedback, value: boardProgress)
        }
    }

    var taskBoardSection: some View {
        VStack(spacing: 10) {
            taskSlot(
                icon: "person.crop.circle.badge.clock",
                title: l.tr(zh: "待我", en: "Mine", de: "Meine"),
                count: todayAssignedReminders.count,
                subtitle: assignedSlotSubtitle,
                tint: Color.goPurple,
                actionTitle: todayAssignedReminders.isEmpty
                    ? l.tr(zh: "稳", en: "Clear", de: "Frei")
                    : l.tr(zh: "查看", en: "View", de: "Ansehen"),
                action: { openMoreCollaboration() }
            )

            taskSlot(
                icon: "pawprint.fill",
                title: l.tr(zh: "缺口", en: "Gaps", de: "Lücken"),
                count: careGapPets.count,
                subtitle: gapSlotSubtitle,
                tint: Color.goYellow,
                actionTitle: careGapPets.isEmpty
                    ? l.tr(zh: "完成", en: "Done", de: "Fertig")
                    : l.tr(zh: "补上", en: "Cover", de: "Erledigen"),
                action: {
                    if let pet = careGapPets.first {
                        onOpenPetActivity(pet)
                    } else {
                        openMoreCollaboration()
                    }
                }
            )

            taskSlot(
                icon: "target",
                title: l.tr(zh: "悬赏", en: "Bounty", de: "Prämie"),
                count: bountyFamilyTasks.count,
                subtitle: bountySlotSubtitle,
                tint: Color.goTeal,
                actionTitle: bountySlotActionTitle,
                action: { performPrimaryBountyAction() }
            )
        }
    }

    var assignedSlotSubtitle: String {
        guard let reminder = todayAssignedReminders.first else {
            return l.tr(zh: "没有指派给你的任务", en: "Nothing assigned to you", de: "Dir ist nichts zugewiesen")
        }
        return reminderTitle(reminder, fallback: reminderSubtitle(reminder))
    }

    var gapSlotSubtitle: String {
        guard let pet = careGapPets.first else {
            return l.tr(zh: "今天照护已补齐", en: "Care is covered today", de: "Heute ist alles erledigt")
        }
        return "\(pet.name) · \(careGapLabels(for: pet).prefix(2).joined(separator: " · "))"
    }

    var bountySlotSubtitle: String {
        guard let task = bountyFamilyTasks.first else {
            return l.tr(zh: "发布一个奖励任务", en: "Post a reward task", de: "Prämienaufgabe erstellen")
        }
        return task.rewardCoconuts > 0
            ? "\(task.emoji) \(task.title) · +\(task.rewardCoconuts)🥥"
            : "\(task.emoji) \(task.title)"
    }

    var bountySlotActionTitle: String {
        guard let task = bountyFamilyTasks.first else {
            return l.tr(zh: "发布", en: "Post", de: "Erstellen")
        }
        if task.status == .pendingReview, task.createdById == activeHumanId {
            return l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
        }
        if task.createdById == activeHumanId {
            return l.tr(zh: "管理", en: "Manage", de: "Verwalten")
        }
        if task.status == .pendingReview {
            return l.tr(zh: "待确认", en: "Review", de: "Prüfung")
        }
        if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            return l.tr(zh: "完成", en: "Done", de: "Fertig")
        }
        if task.isOpen {
            return l.tr(zh: "接手", en: "Take", de: "Übernehmen")
        }
        return l.tr(zh: "查看", en: "View", de: "Ansehen")
    }

    func taskSlot(icon: String, title: String, count: Int, subtitle: String, tint: Color, actionTitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .fill(tint.opacity(0.16))
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("\(count)")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tint, in: Capsule())
                    }
                    Text(subtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(actionTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func performPrimaryBountyAction() {
        guard let task = bountyFamilyTasks.first else {
            presentEditor(.create)
            return
        }
        if task.status == .pendingReview, task.createdById == activeHumanId {
            runFamilyTaskCommand {
                commandExecutor.confirmCompletion(task, by: currentHuman)
            }
        } else if task.createdById == activeHumanId {
            openMoreCollaboration()
        } else if task.status == .pendingReview {
            openMoreCollaboration()
        } else if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            runFamilyTaskCommand {
                commandExecutor.complete(task, by: currentHuman)
            }
        } else if task.isOpen, let human = currentHuman {
            runFamilyTaskCommand {
                commandExecutor.claim(task, by: human)
            }
        } else {
            openMoreCollaboration()
        }
    }

    var myWorkSection: some View {
        collaborationSection(
            title: l.tr(zh: "待我处理", en: "Assigned to me", de: "Mir zugewiesen"),
            icon: "person.crop.circle.badge.clock",
            count: todayAssignedReminders.count
        ) {
            if todayAssignedReminders.isEmpty {
                compactEmpty(
                    icon: "checkmark.seal.fill",
                    text: l.tr(zh: "你今天没有被指派的任务。", en: "Nothing assigned to you today.", de: "Heute ist dir nichts zugewiesen.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(todayAssignedReminders.prefix(3)) { reminder in
                        reminderTaskRow(reminder, role: .mine)
                    }
                }
            }
        }
    }

    var careGapSection: some View {
        collaborationSection(
            title: l.tr(zh: "今日缺口", en: "Today gaps", de: "Heutige Lücken"),
            icon: "exclamationmark.circle.fill",
            count: careGapPets.count
        ) {
            if careGapPets.isEmpty {
                compactEmpty(
                    icon: "checkmark.circle.fill",
                    text: l.tr(zh: "今天的照护缺口已经补齐。", en: "Today's care gaps are covered.", de: "Die heutigen Lücken sind geschlossen.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(careGapPets.prefix(4)) { pet in
                        petCareGapRow(pet)
                    }
                }
            }
        }
    }

    var bountySection: some View {
        collaborationSection(
            title: l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämienaufgaben"),
            icon: "target",
            count: bountyFamilyTasks.count,
            trailing: {
                Button {
                    presentEditor(.create)
                } label: {
                    Label(l.tr(zh: "发布", en: "Post", de: "Erstellen"), systemImage: "plus")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        ) {
            if bountyFamilyTasks.isEmpty {
                compactEmpty(
                    icon: "sparkles",
                    text: l.tr(zh: "发布一个带椰子奖励的任务。", en: "Post a task with coconut rewards.", de: "Erstelle eine Aufgabe mit Kokosnuss-Belohnung.")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(bountyFamilyTasks.prefix(3)) { task in
                        familyTaskRow(task)
                    }
                }
            }
        }
    }

    var moreCollaborationEntry: some View {
        Button {
            openMoreCollaboration()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ellipsis.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "更多协作", en: "More collaboration", de: "Mehr Zusammenarbeit"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "完整宠物状态、今日动态和家庭周报", en: "Full pet status, activity, and weekly report", de: "Tierstatus, Aktivität und Wochenbericht"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var moreCollaborationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                dismissMoreCollaboration()
                onOpenWeeklyReport()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goPrimary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "家庭周报", en: "Family weekly report", de: "Familien-Wochenbericht"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "看本周分工和贡献", en: "Review this week's contribution", de: "Diese Woche ansehen"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            collaborationSection(
                title: l.tr(zh: "发给我的任务", en: "Assigned to me", de: "Meine Aufgaben"),
                icon: "person.crop.circle.badge.clock",
                count: assignedFamilyTasks.count
            ) {
                if assignedFamilyTasks.isEmpty {
                    compactEmpty(icon: "checkmark.seal.fill", text: l.tr(zh: "当前没有发给你的任务。", en: "Nothing assigned to you right now.", de: "Dir ist gerade nichts zugewiesen."))
                } else {
                    VStack(spacing: 8) {
                        ForEach(assignedFamilyTasks) { task in
                            familyTaskRow(task)
                        }
                    }
                }
            }

            collaborationSection(
                title: l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämien"),
                icon: "target",
                count: bountyFamilyTasks.count,
                trailing: {
                    Button {
                        dismissMoreCollaboration()
                        presentEditor(.create)
                    } label: {
                        Label(l.tr(zh: "发布", en: "Post", de: "Erstellen"), systemImage: "plus")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            ) {
                if bountyFamilyTasks.isEmpty {
                    compactEmpty(icon: "sparkles", text: l.tr(zh: "还没有带椰子奖励的任务。", en: "No reward tasks yet.", de: "Noch keine Prämien."))
                } else {
                    VStack(spacing: 8) {
                        ForEach(bountyFamilyTasks) { task in
                            familyTaskRow(task)
                        }
                    }
                }
            }

            petCareStatusSection
            activitySection
        }
    }
}
