//
//  FamilyCollaborationDashboardView+Overview.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    var householdCollaborationHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.badge.gearshape.fill") // a11y: allow decorative section icon hidden below
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "本机家庭分工", en: "On-device household tasks", de: "Familienaufgaben auf diesem Gerät"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "以人类档案记录任务归属，不会发送远程通知。",
                        en: "Human profiles record attribution; no remote notifications are sent.",
                        de: "Personenprofile speichern die Zuordnung; es werden keine Remote-Mitteilungen gesendet."
                    ))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "当前发布者", en: "Current publisher", de: "Aktueller Ersteller"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(currentHuman?.name ?? l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Label("\(max(0, currentHuman?.coconutBalance ?? 0))", systemImage: "wallet.bifold.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.goYellow, in: Capsule())
                    .accessibilityLabel(l.tr(
                        zh: "当前发布者余额 \(max(0, currentHuman?.coconutBalance ?? 0)) 个椰子",
                        en: "Current publisher balance: \(max(0, currentHuman?.coconutBalance ?? 0)) coconuts",
                        de: "Guthaben des Erstellers: \(max(0, currentHuman?.coconutBalance ?? 0)) Kokosnüsse"
                    ))
            }

            Button {
                presentEditor(.create)
            } label: {
                Label(
                    l.tr(zh: "发布奖励任务", en: "Post reward task", de: "Prämienaufgabe erstellen"),
                    systemImage: "plus.circle.fill"
                )
                .font(OhanaFont.callout(.black))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .disabled(currentHuman == nil || humans.count(where: { !$0.hasPassedAway }) < 2)
            .accessibilityIdentifier("family-collaboration-create-task")

            Text(l.tr(
                zh: "每个任务必须设置椰子奖励；发布时验证余额，完成后由发布者确认转账。",
                en: "Every task needs a coconut reward. Balance is checked when posted; transfer happens after publisher confirmation.",
                de: "Jede Aufgabe braucht eine Kokosprämie. Das Guthaben wird beim Erstellen geprüft; die Übertragung folgt nach Bestätigung."
            ))
            .font(OhanaFont.caption2(.bold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    var householdTaskSummary: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            householdMetric(
                value: assignedFamilyTasks.count,
                title: l.tr(zh: "待我处理", en: "For me", de: "Für mich"),
                icon: "person.crop.circle.badge.clock",
                tint: Color.goPurple
            )
            householdMetric(
                value: pendingHouseholdReviewCount,
                title: l.tr(zh: "待我确认", en: "My reviews", de: "Meine Prüfungen"),
                icon: "checkmark.seal.fill",
                tint: Color.goPrimary
            )
            householdMetric(
                value: activeHouseholdRewardTotal,
                title: l.tr(zh: "进行中奖励", en: "Active rewards", de: "Aktive Prämien"),
                icon: "circle.hexagongrid.fill",
                tint: Color.goYellow
            )
        }
    }

    func householdMetric(value: Int, title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text("\(value)")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .monospacedDigit()
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    var householdUnassignedCare: some View {
        if !openReminders.isEmpty {
            collaborationSection(
                title: l.tr(zh: "待分配的照护", en: "Unassigned care", de: "Nicht zugewiesene Pflege"),
                icon: "person.crop.circle.badge.plus",
                count: openReminders.count
            ) {
                VStack(spacing: 8) {
                    ForEach(openReminders.prefix(4)) { reminder in
                        reminderAssignmentRow(reminder)
                    }
                }
            }
        }
    }

    var householdTaskList: some View {
        collaborationSection(
            title: l.tr(zh: "进行中的任务", en: "Active tasks", de: "Aktive Aufgaben"),
            icon: "checklist",
            count: activeFamilyTasks.count,
            trailing: {
                if !activeFamilyTasks.isEmpty {
                    Button(l.tr(zh: "全部", en: "All", de: "Alle")) {
                        openMoreCollaboration()
                    }
                    .font(OhanaFont.caption(.black))
                }
            }
        ) {
            if householdPrioritizedTasks.isEmpty {
                compactEmpty(
                    icon: "checkmark.seal.fill",
                    text: l.tr(zh: "当前没有进行中的家庭任务。", en: "There are no active household tasks.", de: "Es gibt keine aktiven Familienaufgaben.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(householdPrioritizedTasks.prefix(6)) { task in
                        familyTaskRow(task)
                    }
                }
            }
        }
    }

    var householdSecondaryActions: some View {
        VStack(spacing: 8) {
            householdNavigationRow(
                title: l.tr(zh: "任务、宠物状态与家庭动态", en: "Tasks, pet status, and activity", de: "Aufgaben, Tierstatus und Aktivität"),
                icon: "list.bullet.rectangle.portrait.fill"
            ) {
                openMoreCollaboration()
            }

            householdNavigationRow(
                title: l.tr(zh: "查看家庭周报", en: "View family weekly report", de: "Familien-Wochenbericht ansehen"),
                icon: "chart.bar.doc.horizontal"
            ) {
                onOpenWeeklyReport()
            }
        }
    }

    func householdNavigationRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right") // a11y: allow decorative disclosure icon hidden below
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var pendingHouseholdReviewCount: Int {
        activeFamilyTasks.count {
            $0.status == .pendingReview && $0.createdById == currentHumanRecordID
        }
    }

    var activeHouseholdRewardTotal: Int {
        activeFamilyTasks.reduce(0) { $0 + max(0, $1.rewardCoconuts) }
    }

    var householdPrioritizedTasks: [FamilyCollaborationTask] {
        activeFamilyTasks.sorted { lhs, rhs in
            let lhsPriority = householdTaskPriority(lhs)
            let rhsPriority = householdTaskPriority(rhs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return (lhs.dueAt ?? lhs.createdAt) < (rhs.dueAt ?? rhs.createdAt)
        }
    }

    func householdTaskPriority(_ task: FamilyCollaborationTask) -> Int {
        if task.status == .pendingReview, task.createdById == currentHumanRecordID { return 0 }
        if task.assignedToId == currentHumanRecordID || task.claimedById == currentHumanRecordID { return 1 }
        if task.createdById == currentHumanRecordID { return 2 }
        return 3
    }

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
            ? "\(task.title) · +\(task.rewardCoconuts)🥥"
            : task.title
    }

    var bountySlotActionTitle: String {
        guard let task = bountyFamilyTasks.first else {
            return l.tr(zh: "发布", en: "Post", de: "Erstellen")
        }
        if task.status == .pendingReview, task.createdById == currentHumanRecordID {
            return l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
        }
        if task.createdById == currentHumanRecordID {
            return l.tr(zh: "管理", en: "Manage", de: "Verwalten")
        }
        if task.status == .pendingReview {
            return l.tr(zh: "待确认", en: "Review", de: "Prüfung")
        }
        if task.assignedToId == currentHumanRecordID || task.claimedById == currentHumanRecordID {
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
        if task.status == .pendingReview, task.createdById == currentHumanRecordID {
            runFamilyTaskCommand {
                commandExecutor.confirmCompletion(task, by: currentHuman)
            }
        } else if task.createdById == currentHumanRecordID {
            openMoreCollaboration()
        } else if task.status == .pendingReview {
            openMoreCollaboration()
        } else if task.assignedToId == currentHumanRecordID || task.claimedById == currentHumanRecordID {
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
                dismissMoreCollaboration(then: .openWeeklyReport)
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
                        dismissMoreCollaboration(then: .presentEditor(.create))
                    } label: {
                        Label(l.tr(zh: "发布", en: "Post", de: "Erstellen"), systemImage: "plus")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.goPrimary, in: Capsule())
                            .frame(minWidth: 44, minHeight: 44)
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
