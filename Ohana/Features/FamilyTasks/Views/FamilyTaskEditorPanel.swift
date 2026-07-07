//
//  FamilyTaskEditorPanel.swift
//  Ohana
//
//  Inline family task editor used by FamilyCollaborationDashboardView.
//

import Foundation
import SwiftUI

struct FamilyTaskEditorPanel: View {
    let context: FamilyCollaborationEditorContext
    let humans: [Human]
    let currentHuman: Human?
    let pets: [Pet]
    var onClose: () -> Void
    var onAssignReminder: (Reminder, Human, Int, String) -> Void
    var onCreateTask: (String, String, Human?, Int, Date?, String) -> Void
    var onUpdateTask: (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Void
    var onDeleteTask: (FamilyCollaborationTask) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var title: String
    @State private var note: String
    @State private var selectedHumanId: String
    @State private var reward: Int
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var emoji: String

    private var l: L10n { L10n(appLanguage) }
    private let rewardOptions = [0, 20, 50, 100, 200, 500]
    private let emojiOptions = ["🎯", "🧹", "🌱", "🐾", "🛒", "💊", "🧺", "🔧"]
    private var route: FamilyCollaborationEditorRoute { context.route }

    init(
        context: FamilyCollaborationEditorContext,
        humans: [Human],
        currentHuman: Human?,
        pets: [Pet],
        onClose: @escaping () -> Void,
        onAssignReminder: @escaping (Reminder, Human, Int, String) -> Void,
        onCreateTask: @escaping (String, String, Human?, Int, Date?, String) -> Void,
        onUpdateTask: @escaping (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Void,
        onDeleteTask: @escaping (FamilyCollaborationTask) -> Void
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

        switch context.route {
        case .assignReminder:
            let reminder = context.reminder
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            _title = State(initialValue: Self.reminderTitle(reminder, l: L10n()))
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: 0)
            _hasDueDate = State(initialValue: true)
            _dueAt = State(initialValue: reminder?.scheduledAt ?? Date())
            _emoji = State(initialValue: reminder?.event?.emoji ?? "🐾")
        case .editTask:
            let task = context.task
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            let existingAssigneeId = task?.assignedToId ?? task?.claimedById ?? ""
            let isExistingAssignable = humans.contains { human in
                human.id.uuidString == existingAssigneeId && human.id.uuidString != currentHumanId
            }
            _title = State(initialValue: task?.title ?? "")
            _note = State(initialValue: task?.note ?? "")
            _selectedHumanId = State(initialValue: isExistingAssignable ? existingAssigneeId : firstAssignableId)
            _reward = State(initialValue: task?.rewardCoconuts ?? 0)
            _hasDueDate = State(initialValue: task?.dueAt != nil)
            _dueAt = State(initialValue: task?.dueAt ?? Date())
            _emoji = State(initialValue: task?.emoji ?? "🎯")
        case .create:
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            _title = State(initialValue: "")
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: 20)
            _hasDueDate = State(initialValue: false)
            _dueAt = State(initialValue: Date())
            _emoji = State(initialValue: "🎯")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if case .assignReminder = route, let reminder = context.reminder {
                reminderSummary(reminder)
            } else {
                textFieldBlock(
                    title: l.tr(zh: "任务", en: "Task", de: "Aufgabe"),
                    placeholder: l.tr(zh: "例如：周末拖地", en: "e.g. mop this weekend", de: "z. B. am Wochenende wischen"),
                    text: $title
                )
            }
            textFieldBlock(
                title: l.tr(zh: "说明", en: "Note", de: "Notiz"),
                placeholder: l.tr(zh: "可选", en: "Optional", de: "Optional"),
                text: $note
            )
            assigneePicker
            rewardPicker
            dueDateBlock
            if case .create = route {
                emojiPicker
            } else if case .editTask = route {
                emojiPicker
            }
            saveButton
            if case .editTask = route, let task = context.task {
                deleteButton(task)
            }
        }
        .padding(20)
    }

    private var navigationTitle: String {
        switch route {
        case .assignReminder: l.tr(zh: "分配待办", en: "Assign task", de: "Aufgabe zuweisen")
        case .editTask: l.tr(zh: "任务详情", en: "Task details", de: "Aufgabendetails")
        case .create: l.tr(zh: "发布任务", en: "Post task", de: "Aufgabe erstellen")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(navigationTitle)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "选择其他家人，可选椰子悬赏。",
                en: "Choose another family member and optional reward.",
                de: "Anderes Familienmitglied wählen, Prämie optional."
            ))
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func reminderSummary(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.reminderTitle(reminder, l: l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private static func reminderTitle(_ reminder: Reminder?, l: L10n) -> String {
        guard let event = reminder?.event else {
            return l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe")
        }
        return FeedRuleMetadata.localizedTitle(for: event, l: l)
    }

    private func textFieldBlock(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(placeholder, text: text, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1 ... 3)
                .padding(13)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
    }

    private var assigneePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "分配给", en: "Assign to", de: "Zuweisen an"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            if assignableHumans.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.slash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(
                        zh: "还没有可分配的其他家人",
                        en: "No other family member to assign",
                        de: "Kein anderes Familienmitglied verfügbar"
                    ))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(assignableHumans) { human in
                            assigneeChip(id: human.id.uuidString, title: human.name, emoji: human.avatarEmoji)
                        }
                    }
                }
            }
        }
    }

    private func assigneeChip(id: String, title: String, emoji: String) -> some View {
        let selected = selectedHumanId == id
        return Button {
            withAnimation(GoMotion.feedback) { selectedHumanId = id }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title)
                    .lineLimit(1)
            }
            .font(OhanaFont.caption(.black))
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(selected ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var rewardPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "椰子悬赏", en: "Coconut reward", de: "Kokos-Prämie"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 8) {
                ForEach(rewardOptions, id: \.self) { value in
                    Button {
                        withAnimation(GoMotion.feedback) { reward = value }
                    } label: {
                        Text(value == 0 ? l.tr(zh: "无", en: "None", de: "Keine") : "\(value)🥥")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(reward == value ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(reward == value ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var dueDateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDueDate.animation(GoMotion.feedback)) {
                Text(l.tr(zh: "截止时间", en: "Due time", de: "Fällig"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .tint(Color.goPrimary)
            if hasDueDate {
                DatePicker("", selection: $dueAt)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "图标", en: "Icon", de: "Icon"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 8) {
                ForEach(emojiOptions, id: \.self) { item in
                    Button {
                        withAnimation(GoMotion.feedback) { emoji = item }
                    } label: {
                        Text(item)
                            .font(OhanaFont.title3(.black))
                            .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(emoji == item ? Color.goPrimary : Color.ohanaCardSurface, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .disabled(!canSave)
        .buttonStyle(ScaleButtonStyle())
    }

    private func deleteButton(_ task: FamilyCollaborationTask) -> some View {
        Button {
            onDeleteTask(task)
            onClose()
        } label: {
            Text(l.tr(zh: "删除任务", en: "Delete task", de: "Aufgabe löschen"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var selectedHuman: Human? {
        assignableHumans.first { $0.id.uuidString == selectedHumanId }
    }

    private var assignableHumans: [Human] {
        guard let currentHumanId = currentHuman?.id.uuidString else {
            return humans
        }
        return humans.filter { $0.id.uuidString != currentHumanId }
    }

    private var canSave: Bool {
        switch route {
        case .assignReminder:
            selectedHuman != nil
        case .create, .editTask:
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedHuman != nil
        }
    }

    private func save() {
        let due = hasDueDate ? dueAt : nil
        switch route {
        case .assignReminder:
            guard let reminder = context.reminder else { return }
            guard let selectedHuman else { return }
            onAssignReminder(reminder, selectedHuman, reward, note)
        case .create:
            onCreateTask(title, note, selectedHuman, reward, due, emoji)
        case .editTask:
            guard let task = context.task else { return }
            onUpdateTask(task, title, note, selectedHuman, reward, due, emoji)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose()
    }
}
