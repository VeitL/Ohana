//
//  FamilyTaskEditorPanel.swift
//  Ohana
//
//  Native household task editor. Rewards are optional; rewarded work transfers
//  only after the publisher confirms completion.
//

import Foundation
import SwiftUI

struct FamilyTaskEditorPanel: View {
    let context: FamilyCollaborationEditorContext
    let humans: [Human]
    let currentHuman: Human?
    let pets: [Pet]
    var onClose: () -> Void
    var onAssignReminder: (Reminder, Human, Int, String) -> Bool
    var onCreateTask: (String, String, Human?, Int, Date?, String) -> Bool
    var onUpdateTask: (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Bool
    var onDeleteTask: (FamilyCollaborationTask) -> Bool

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var title: String
    @State private var note: String
    @State private var selectedHumanId: String
    @State private var includesReward: Bool
    @State private var reward: Int
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var emoji: String
    @State private var saveErrorMessage: String?

    private var l: L10n { L10n(appLanguage) }
    private var route: FamilyCollaborationEditorRoute { context.route }

    init(
        context: FamilyCollaborationEditorContext,
        humans: [Human],
        currentHuman: Human?,
        pets: [Pet],
        onClose: @escaping () -> Void,
        onAssignReminder: @escaping (Reminder, Human, Int, String) -> Bool,
        onCreateTask: @escaping (String, String, Human?, Int, Date?, String) -> Bool,
        onUpdateTask: @escaping (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Bool,
        onDeleteTask: @escaping (FamilyCollaborationTask) -> Bool
    ) {
        self.context = context
        self.humans = humans
        self.currentHuman = currentHuman
        self.pets = pets
        self.onClose = onClose
        self.onAssignReminder = onAssignReminder
        self.onCreateTask = onCreateTask
        self.onUpdateTask = onUpdateTask
        self.onDeleteTask = onDeleteTask

        let currentHumanId = currentHuman?.id.uuidString
        let firstAssignableId = humans.first {
            !$0.hasPassedAway && $0.id.uuidString != currentHumanId
        }?.id.uuidString ?? ""
        switch context.route {
        case .assignReminder:
            _title = State(initialValue: Self.reminderTitle(context.reminder, l: L10n()))
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _includesReward = State(initialValue: false)
            _reward = State(initialValue: 0)
            _hasDueDate = State(initialValue: true)
            _dueAt = State(initialValue: context.reminder?.resolvedOccurrenceAt ?? Date())
            _emoji = State(initialValue: context.reminder?.event?.emoji ?? "🐾")
        case .editTask:
            let task = context.task
            let existingAssigneeId = task?.assignedToId ?? task?.claimedById ?? ""
            let isExistingAssignable = humans.contains { human in
                !human.hasPassedAway
                    && human.id.uuidString == existingAssigneeId
                    && human.id.uuidString != currentHumanId
            }
            _title = State(initialValue: task?.title ?? "")
            _note = State(initialValue: task?.note ?? "")
            _selectedHumanId = State(initialValue: isExistingAssignable ? existingAssigneeId : firstAssignableId)
            let existingReward = min(
                FamilyTaskRewardPolicy.cap,
                max(0, task?.rewardCoconuts ?? 0)
            )
            _includesReward = State(initialValue: FamilyTaskRewardDraftPolicy.isExpanded(existingReward: existingReward))
            _reward = State(initialValue: existingReward)
            _hasDueDate = State(initialValue: task?.dueAt != nil)
            _dueAt = State(initialValue: task?.dueAt ?? Date())
            _emoji = State(initialValue: task?.emoji ?? "🎯")
        case .create:
            _title = State(initialValue: "")
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _includesReward = State(initialValue: false)
            _reward = State(initialValue: 0)
            _hasDueDate = State(initialValue: false)
            _dueAt = State(initialValue: Date())
            _emoji = State(initialValue: "🎯")
        }
    }

    var body: some View {
        Form {
            taskSection
            assignmentSection
            scheduleSection
            saveSection
            deleteSection
        }
        .scrollDismissesKeyboard(.interactively)
        .alert(
            l.tr(zh: "操作未完成", en: "Could not complete", de: "Aktion nicht abgeschlossen"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        Section(l.tr(zh: "任务内容", en: "Task", de: "Aufgabe")) {
            if case .assignReminder = route, let reminder = context.reminder {
                LabeledContent {
                    Text(Self.reminderTitle(reminder, l: l))
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label(l.tr(zh: "照护待办", en: "Care reminder", de: "Pflegeerinnerung"), systemImage: reminder.event?.silhouetteListSymbol ?? "checklist")
                }
            } else {
                TextField(
                    l.tr(zh: "例如：周末拖地", en: "e.g. mop this weekend", de: "z. B. am Wochenende wischen"),
                    text: $title
                )
                .accessibilityLabel(l.tr(zh: "任务名称", en: "Task name", de: "Aufgabenname"))
            }

            TextField(
                l.tr(zh: "说明（可选）", en: "Note (optional)", de: "Notiz (optional)"),
                text: $note,
                axis: .vertical
            )
            .lineLimit(2 ... 5)
        }
    }

    private var assignmentSection: some View {
        Section {
            if assignableHumans.isEmpty {
                Label(
                    l.tr(zh: "还没有可指派的其他家人", en: "No other household member is available", de: "Kein weiteres Familienmitglied verfügbar"),
                    systemImage: "person.2.slash"
                )
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                Picker(l.tr(zh: "指派给", en: "Assign to", de: "Zuweisen an"), selection: $selectedHumanId) {
                    ForEach(assignableHumans) { human in
                        Text("\(human.avatarEmoji) \(human.name)")
                            .tag(human.id.uuidString)
                    }
                }
            }

            Toggle(isOn: $includesReward) {
                Label(
                    l.tr(zh: "添加椰子奖励", en: "Add a coconut reward", de: "Kokosprämie hinzufügen"),
                    systemImage: "gift.fill"
                )
            }
            .tint(Color.goPrimary)
            .accessibilityIdentifier("family-task-reward-toggle")
            .onChange(of: includesReward) { _, isEnabled in
                if isEnabled {
                    if reward <= 0 {
                        reward = FamilyTaskRewardDraftPolicy.suggestedReward(
                            availableBalance: availableBalance
                        )
                    }
                } else {
                    reward = 0
                }
            }

            if includesReward {
                LabeledContent {
                    TextField(
                        "1–\(FamilyTaskRewardPolicy.cap)",
                        value: $reward,
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 72)
                    .accessibilityLabel(l.tr(
                        zh: "奖励椰子数量",
                        en: "Coconut reward amount",
                        de: "Höhe der Kokosprämie"
                    ))
                } label: {
                    Label(
                        l.tr(zh: "奖励数量", en: "Reward amount", de: "Prämienhöhe"),
                        systemImage: "circle.hexagongrid.fill"
                    )
                }

                if reward <= 0 || reward > FamilyTaskRewardPolicy.cap {
                    Label(
                        l.tr(
                            zh: "奖励必须在 1 到 \(FamilyTaskRewardPolicy.cap) 之间。",
                            en: "The reward must be between 1 and \(FamilyTaskRewardPolicy.cap).",
                            de: "Die Prämie muss zwischen 1 und \(FamilyTaskRewardPolicy.cap) liegen."
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goRed)
                }

                if reward > availableBalance {
                    Label(
                        l.tr(zh: "当前成员的椰子余额不足。", en: "The current member does not have enough coconuts.", de: "Das aktuelle Mitglied hat nicht genug Kokosnüsse."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goRed)
                }
            }
        } header: {
            Text(l.tr(zh: "分给谁", en: "Who should do it", de: "Wer soll es erledigen"))
        } footer: {
            if includesReward {
                Text(l.tr(
                    zh: "奖励任务完成后会请你确认一次，再转出椰子。当前可用 \(availableBalance)🥥。",
                    en: "When this rewarded task is done, you will confirm it once before the coconuts transfer. \(availableBalance)🥥 available.",
                    de: "Nach Abschluss bestätigst du die Prämienaufgabe einmal, bevor die Kokosnüsse übertragen werden. \(availableBalance)🥥 verfügbar."
                ))
            }
        }
    }

    private var scheduleSection: some View {
        Section(l.tr(zh: "时间", en: "Schedule", de: "Zeitplan")) {
            Toggle(l.tr(zh: "设置截止时间", en: "Set due time", de: "Fälligkeit festlegen"), isOn: $hasDueDate)
                .tint(Color.goPrimary)
            if hasDueDate {
                DatePicker(
                    l.tr(zh: "截止时间", en: "Due", de: "Fällig"),
                    selection: $dueAt
                )
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                save()
            } label: {
                Label(saveActionTitle, systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .disabled(!canSave)
            .accessibilityIdentifier("family-task-save-action")
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if case .editTask = route,
           let task = context.task,
           task.createdById == currentHuman?.id.uuidString {
            Section {
                Button(role: .destructive) {
                    delete(task)
                } label: {
                    Label(
                        l.tr(zh: "删除任务", en: "Delete task", de: "Aufgabe löschen"),
                        systemImage: "trash"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private var saveActionTitle: String {
        switch route {
        case .assignReminder: l.tr(zh: "分配任务", en: "Assign task", de: "Aufgabe zuweisen")
        case .editTask: l.tr(zh: "保存任务", en: "Save task", de: "Aufgabe speichern")
        case .create: l.tr(zh: "创建任务", en: "Create task", de: "Aufgabe erstellen")
        }
    }

    private static func reminderTitle(_ reminder: Reminder?, l: L10n) -> String {
        guard let event = reminder?.event else {
            return l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe")
        }
        return FeedRuleMetadata.localizedTitle(for: event, l: l)
    }

    private var selectedHuman: Human? {
        assignableHumans.first { $0.id.uuidString == selectedHumanId }
    }

    private var assignableHumans: [Human] {
        guard let currentHumanId = currentHuman?.id.uuidString else { return [] }
        return humans.filter { !$0.hasPassedAway && $0.id.uuidString != currentHumanId }
    }

    private var availableBalance: Int {
        max(0, currentHuman?.coconutBalance ?? 0)
    }

    private var effectiveReward: Int {
        FamilyTaskRewardDraftPolicy.effectiveReward(
            isEnabled: includesReward,
            draftReward: reward
        )
    }

    private var canSave: Bool {
        guard currentHuman != nil,
              selectedHuman != nil,
              !includesReward || (
                  reward > 0 &&
                      reward <= FamilyTaskRewardPolicy.cap &&
                      reward <= availableBalance
              )
        else { return false }

        switch route {
        case .assignReminder:
            return context.reminder != nil
        case .create:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .editTask:
            guard let task = context.task else { return false }
            return task.createdById == currentHuman?.id.uuidString
                && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        guard canSave else {
            saveErrorMessage = validationFailureMessage
            return
        }

        let due = hasDueDate ? dueAt : nil
        let didSave: Bool
        switch route {
        case .assignReminder:
            guard let reminder = context.reminder, let selectedHuman else { return }
            didSave = onAssignReminder(reminder, selectedHuman, effectiveReward, note)
        case .create:
            didSave = onCreateTask(title, note, selectedHuman, effectiveReward, due, emoji)
        case .editTask:
            guard let task = context.task else { return }
            didSave = onUpdateTask(task, title, note, selectedHuman, effectiveReward, due, emoji)
        }

        guard didSave else {
            saveErrorMessage = l.tr(
                zh: "任务没有保存。请检查成员状态、任务归属和奖励余额后重试。",
                en: "The task was not saved. Check the members, assignment, and reward balance, then try again.",
                de: "Die Aufgabe wurde nicht gespeichert. Prüfe Mitglieder, Zuordnung und Prämienguthaben und versuche es erneut."
            )
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose()
    }

    private func delete(_ task: FamilyCollaborationTask) {
        guard onDeleteTask(task) else {
            saveErrorMessage = l.tr(
                zh: "任务无法删除。请先切换到创建这项任务的成员。",
                en: "The task could not be deleted. Switch to the member who created it first.",
                de: "Die Aufgabe konnte nicht gelöscht werden. Wechsle zuerst zu dem Mitglied, das sie erstellt hat."
            )
            return
        }
        onClose()
    }

    private var validationFailureMessage: String {
        if currentHuman == nil {
            return l.tr(zh: "请先选择当前人类档案。", en: "Select a current human profile first.", de: "Wähle zuerst ein aktuelles Personenprofil.")
        }
        if selectedHuman == nil {
            return l.tr(zh: "请选择其他家人。", en: "Choose another household member.", de: "Wähle ein anderes Familienmitglied.")
        }
        if includesReward && (reward <= 0 || reward > FamilyTaskRewardPolicy.cap) {
            return l.tr(
                zh: "奖励必须在 1 到 \(FamilyTaskRewardPolicy.cap) 之间。",
                en: "The reward must be between 1 and \(FamilyTaskRewardPolicy.cap).",
                de: "Die Prämie muss zwischen 1 und \(FamilyTaskRewardPolicy.cap) liegen."
            )
        }
        if includesReward && reward > availableBalance {
            return l.tr(zh: "当前成员的椰子余额不足。", en: "The current member does not have enough coconuts.", de: "Das aktuelle Mitglied hat nicht genug Kokosnüsse.")
        }
        return l.tr(zh: "请填写任务名称。", en: "Add a task name.", de: "Füge einen Aufgabennamen hinzu.")
    }
}
