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
        let suggestedReward = min(20, max(1, currentHuman?.coconutBalance ?? 1))

        switch context.route {
        case .assignReminder:
            _title = State(initialValue: Self.reminderTitle(context.reminder, l: L10n()))
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: suggestedReward)
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
            _reward = State(initialValue: min(
                FamilyTaskService.rewardCap,
                max(0, task?.rewardCoconuts ?? suggestedReward)
            ))
            _hasDueDate = State(initialValue: task?.dueAt != nil)
            _dueAt = State(initialValue: task?.dueAt ?? Date())
            _emoji = State(initialValue: task?.emoji ?? "🎯")
        case .create:
            _title = State(initialValue: "")
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: suggestedReward)
            _hasDueDate = State(initialValue: false)
            _dueAt = State(initialValue: Date())
            _emoji = State(initialValue: "🎯")
        }
    }

    var body: some View {
        Form {
            publisherSection
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

    private var publisherSection: some View {
        Section {
            LabeledContent {
                Text(currentHuman?.name ?? l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt"))
            } label: {
                Label(l.tr(zh: "发布者", en: "Publisher", de: "Ersteller"), systemImage: "person.crop.circle")
            }

            LabeledContent {
                Text("\(availableBalance)🥥")
                    .monospacedDigit()
            } label: {
                Label(l.tr(zh: "可用余额", en: "Available", de: "Verfügbar"), systemImage: "wallet.bifold.fill")
            }
        } header: {
            Text(l.tr(zh: "当前记录归属", en: "Current attribution", de: "Aktuelle Zuordnung"))
        } footer: {
            Text(l.tr(
                zh: "任务只记录在本机。奖励可为 0；设置奖励时，执行者提交后由发布者确认并转账。",
                en: "Tasks stay on this device. A reward is optional; when offered, it transfers after the publisher approves the submission.",
                de: "Aufgaben bleiben auf diesem Gerät. Eine Prämie ist optional und wird erst nach Bestätigung übertragen."
            ))
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

            LabeledContent {
                TextField(
                    "0–\(FamilyTaskService.rewardCap)",
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
                    l.tr(zh: "奖励椰子", en: "Coconut reward", de: "Kokosprämie"),
                    systemImage: "circle.hexagongrid.fill"
                )
            }

            if reward < 0 || reward > FamilyTaskService.rewardCap {
                Label(
                    l.tr(
                        zh: "奖励必须在 0 到 \(FamilyTaskService.rewardCap) 之间。",
                        en: "The reward must be between 0 and \(FamilyTaskService.rewardCap).",
                        de: "Die Prämie muss zwischen 0 und \(FamilyTaskService.rewardCap) liegen."
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goRed)
            }

            if reward > availableBalance {
                Label(
                    l.tr(zh: "发布者椰子余额不足。", en: "The publisher does not have enough coconuts.", de: "Der Ersteller hat nicht genug Kokosnüsse."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goRed)
            }
        } header: {
            Text(l.tr(zh: "分工与奖励", en: "Assignment and reward", de: "Zuweisung und Prämie"))
        } footer: {
            Text(l.tr(
                zh: "0 表示普通分工，可直接完成；正数奖励需要提交并由发布者审核。",
                en: "Zero creates a regular assignment that can be completed directly; a positive reward requires submission and approval.",
                de: "Null erstellt eine normale Aufgabe; eine positive Prämie erfordert Einreichung und Bestätigung."
            ))
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
        case .assignReminder: l.tr(zh: "发布指派", en: "Post assignment", de: "Zuweisung erstellen")
        case .editTask: l.tr(zh: "保存任务", en: "Save task", de: "Aufgabe speichern")
        case .create: l.tr(zh: "发布任务", en: "Post task", de: "Aufgabe erstellen")
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

    private var canSave: Bool {
        guard currentHuman != nil,
              selectedHuman != nil,
              reward >= 0,
              reward <= FamilyTaskService.rewardCap,
              reward <= availableBalance
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
            didSave = onAssignReminder(reminder, selectedHuman, reward, note)
        case .create:
            didSave = onCreateTask(title, note, selectedHuman, reward, due, emoji)
        case .editTask:
            guard let task = context.task else { return }
            didSave = onUpdateTask(task, title, note, selectedHuman, reward, due, emoji)
        }

        guard didSave else {
            saveErrorMessage = l.tr(
                zh: "任务没有保存。请确认发布者余额、成员状态和任务归属后重试。",
                en: "The task was not saved. Check the publisher balance, member status, and task ownership, then try again.",
                de: "Die Aufgabe wurde nicht gespeichert. Prüfe Guthaben, Mitgliedsstatus und Zuordnung und versuche es erneut."
            )
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose()
    }

    private func delete(_ task: FamilyCollaborationTask) {
        guard onDeleteTask(task) else {
            saveErrorMessage = l.tr(
                zh: "任务无法删除，请确认当前档案是发布者。",
                en: "The task could not be deleted. Make sure the current profile is the publisher.",
                de: "Die Aufgabe konnte nicht gelöscht werden. Das aktuelle Profil muss der Ersteller sein."
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
        if reward < 0 || reward > FamilyTaskService.rewardCap {
            return l.tr(
                zh: "奖励必须在 0 到 \(FamilyTaskService.rewardCap) 之间。",
                en: "The reward must be between 0 and \(FamilyTaskService.rewardCap).",
                de: "Die Prämie muss zwischen 0 und \(FamilyTaskService.rewardCap) liegen."
            )
        }
        if reward > availableBalance {
            return l.tr(zh: "发布者椰子余额不足。", en: "The publisher does not have enough coconuts.", de: "Der Ersteller hat nicht genug Kokosnüsse.")
        }
        return l.tr(zh: "请填写任务名称。", en: "Add a task name.", de: "Füge einen Aufgabennamen hinzu.")
    }
}
