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
    let planConfiguration: FamilyTaskPlanEditorSnapshot?
    var onClose: () -> Void
    var onAssignReminder: (Reminder, Human, Int, String) -> Bool
    var onCreateTask: (String, String, Human?, Int, Date?, String) -> Bool
    var onCreatePlan: ((FamilyTaskPlanDraft) async -> Bool)?
    var onUpdateTask: (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Bool
    var onDeleteTask: (FamilyCollaborationTask) -> Bool
    var onUpdatePlan: ((UUID, Date, FamilyTaskPlanDraft) async -> Bool)?
    var onCancelPlan: ((UUID, Date) async -> Bool)?

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
    @State private var recurrenceKind: FamilyTaskRecurrenceKind
    @State private var intervalDays: Int
    @State private var selectedWeekdays: Set<FamilyTaskWeekday>
    @State private var monthlyDay: Int
    @State private var isAllDay: Bool
    @State private var hasStartDate: Bool
    @State private var startsAt: Date
    @State private var hasEndDate: Bool
    @State private var endsAt: Date
    @State private var hasReminder: Bool
    @State private var reminderLeadMinutes: Int
    @State private var isSaving = false
    @State private var editScope: FamilyTaskEditScope
    @State private var planSubjectName: String
    @State private var planTimeZoneIdentifier: String
    @State private var planEventTypeRaw: String
    @State private var planTaskCareKindRaw: String
    @State private var planScheduleVersion: Int?
    @State private var pendingCancellationTaskID: UUID?

    private var l: L10n { L10n(appLanguage) }
    private var route: FamilyCollaborationEditorRoute { context.route }

    init(
        context: FamilyCollaborationEditorContext,
        humans: [Human],
        currentHuman: Human?,
        pets: [Pet],
        planConfiguration: FamilyTaskPlanEditorSnapshot?,
        onClose: @escaping () -> Void,
        onAssignReminder: @escaping (Reminder, Human, Int, String) -> Bool,
        onCreateTask: @escaping (String, String, Human?, Int, Date?, String) -> Bool,
        onCreatePlan: ((FamilyTaskPlanDraft) async -> Bool)? = nil,
        onUpdateTask: @escaping (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Bool,
        onDeleteTask: @escaping (FamilyCollaborationTask) -> Bool,
        onUpdatePlan: ((UUID, Date, FamilyTaskPlanDraft) async -> Bool)? = nil,
        onCancelPlan: ((UUID, Date) async -> Bool)? = nil
    ) {
        self.context = context
        self.humans = humans
        self.currentHuman = currentHuman
        self.pets = pets
        self.planConfiguration = planConfiguration
        self.onClose = onClose
        self.onAssignReminder = onAssignReminder
        self.onCreateTask = onCreateTask
        self.onCreatePlan = onCreatePlan
        self.onUpdateTask = onUpdateTask
        self.onDeleteTask = onDeleteTask
        self.onUpdatePlan = onUpdatePlan
        self.onCancelPlan = onCancelPlan

        let currentHumanId = currentHuman?.id.uuidString
        let firstAssignableId = humans.first {
            !$0.hasPassedAway && $0.id.uuidString != currentHumanId
        }?.id.uuidString ?? ""
        let seedDate = context.task?.dueAt ?? context.reminder?.resolvedOccurrenceAt ?? Date()
        let weekday = FamilyTaskWeekday(rawValue: Calendar.current.component(.weekday, from: seedDate)) ?? .monday
        let recurrenceRule = planConfiguration?.recurrenceRule ?? .once
        let anchorAt = planConfiguration?.anchorAt ?? seedDate
        let selectedWeekdays = recurrenceRule.weekdays.isEmpty ? [weekday] : recurrenceRule.weekdays
        _recurrenceKind = State(initialValue: recurrenceRule.kind)
        _intervalDays = State(initialValue: recurrenceRule.intervalDays)
        _selectedWeekdays = State(initialValue: selectedWeekdays)
        _monthlyDay = State(initialValue: max(1, recurrenceRule.monthDay))
        _isAllDay = State(initialValue: planConfiguration?.isAllDay ?? true)
        _hasStartDate = State(initialValue: planConfiguration?.startsAt != nil)
        _startsAt = State(initialValue: planConfiguration?.startsAt ?? anchorAt)
        _hasEndDate = State(initialValue: planConfiguration?.endsAt != nil)
        _endsAt = State(
            initialValue: planConfiguration?.endsAt
                ?? (Calendar.current.date(byAdding: .month, value: 3, to: anchorAt) ?? anchorAt)
        )
        _hasReminder = State(initialValue: planConfiguration?.reminderLeadMinutes != nil)
        _reminderLeadMinutes = State(initialValue: planConfiguration?.reminderLeadMinutes ?? 30)
        _editScope = State(initialValue: .onlyThis)
        _planSubjectName = State(initialValue: planConfiguration?.subjectName ?? "")
        _planTimeZoneIdentifier = State(initialValue: planConfiguration?.timeZoneIdentifier ?? TimeZone.current.identifier)
        _planEventTypeRaw = State(initialValue: planConfiguration?.eventTypeRaw ?? EventType.task.rawValue)
        _planTaskCareKindRaw = State(initialValue: planConfiguration?.taskCareKindRaw ?? "")
        _planScheduleVersion = State(
            initialValue: planConfiguration?.scheduleVersion
                ?? ((context.task?.scheduleVersion ?? 0) > 0 ? context.task?.scheduleVersion : nil)
        )
        _pendingCancellationTaskID = State(initialValue: nil)
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
        .confirmationDialog(
            cancellationConfirmationTitle,
            isPresented: Binding(
                get: { pendingCancellationTaskID != nil },
                set: { if !$0 { pendingCancellationTaskID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(cancellationActionTitle, role: .destructive) {
                guard let task = context.task, task.id == pendingCancellationTaskID else { return }
                pendingCancellationTaskID = nil
                cancel(task)
            }
            Button(l.cancel, role: .cancel) {
                pendingCancellationTaskID = nil
            }
        } message: {
            Text(cancellationConfirmationMessage)
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
                        usesPlanRewardSnapshot
                            ? l.tr(
                                zh: "可以先保存；确认完成时若余额不足，任务会继续等待确认。",
                                en: "You can save it now. If the balance is short at approval, the task will keep waiting for review.",
                                de: "Du kannst jetzt speichern. Reicht das Guthaben bei der Bestätigung nicht, bleibt die Aufgabe in Prüfung."
                            )
                            : l.tr(zh: "当前成员的椰子余额不足。", en: "The current member does not have enough coconuts.", de: "Das aktuelle Mitglied hat nicht genug Kokosnüsse."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(usesPlanRewardSnapshot ? Color.goYellow : Color.goRed)
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
            if isRecurringTaskEdit {
                Picker(
                    l.tr(zh: "修改范围", en: "Edit scope", de: "Bearbeitungsumfang"),
                    selection: $editScope
                ) {
                    Text(l.tr(zh: "仅本次", en: "Only this occurrence", de: "Nur dieses Mal"))
                        .tag(FamilyTaskEditScope.onlyThis)
                    Text(l.tr(zh: "本次及以后", en: "This and future", de: "Dieses und folgende"))
                        .tag(FamilyTaskEditScope.thisAndFuture)
                }
            }
            Toggle(l.tr(zh: "设置截止时间", en: "Set due time", de: "Fälligkeit festlegen"), isOn: $hasDueDate)
                .tint(Color.goPrimary)
                .disabled(isPlanBackedTask)
            if hasDueDate {
                if showsPlanScheduleControls {
                    Toggle(
                        l.tr(zh: "全天任务", en: "All-day task", de: "Ganztägige Aufgabe"),
                        isOn: $isAllDay
                    )
                    .tint(Color.goPrimary)
                }
                DatePicker(
                    l.tr(zh: "截止时间", en: "Due", de: "Fällig"),
                    selection: $dueAt,
                    displayedComponents: isAllDay && showsPlanScheduleControls ? [.date] : [.date, .hourAndMinute]
                )

                if showsPlanScheduleControls {
                    recurrenceControls
                    reminderControls
                }
            }
        }
    }

    private var isRecurringTaskEdit: Bool {
        guard case .editTask = route else { return false }
        return context.task?.planId.flatMap(UUID.init(uuidString:)) != nil && onUpdatePlan != nil
    }

    private var isPlanBackedTask: Bool {
        context.task?.planId.flatMap(UUID.init(uuidString:)) != nil
    }

    private var showsPlanScheduleControls: Bool {
        if case .create = route { return onCreatePlan != nil }
        return isRecurringTaskEdit && editScope == .thisAndFuture
    }

    @ViewBuilder
    private var recurrenceControls: some View {
        Picker(
            l.tr(zh: "重复", en: "Repeat", de: "Wiederholen"),
            selection: $recurrenceKind
        ) {
            Text(l.tr(zh: "不重复", en: "Does not repeat", de: "Einmalig"))
                .tag(FamilyTaskRecurrenceKind.once)
            Text(l.tr(zh: "每隔几天", en: "Every few days", de: "Alle paar Tage"))
                .tag(FamilyTaskRecurrenceKind.everyNDays)
            Text(l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich"))
                .tag(FamilyTaskRecurrenceKind.weekly)
            Text(l.tr(zh: "每月某日", en: "Monthly on a date", de: "Monatlich an einem Tag"))
                .tag(FamilyTaskRecurrenceKind.monthlyDay)
            Text(l.tr(zh: "每月最后一天", en: "Last day monthly", de: "Monatlich am letzten Tag"))
                .tag(FamilyTaskRecurrenceKind.monthlyLastDay)
        }
        .onChange(of: recurrenceKind) { _, kind in
            guard kind != .once else { return }
            hasDueDate = true
        }

        switch recurrenceKind {
        case .once:
            EmptyView()
        case .everyNDays:
            Stepper(value: $intervalDays, in: 1 ... 365) {
                Text(l.tr(
                    zh: "每 \(intervalDays) 天",
                    en: "Every \(intervalDays) days",
                    de: "Alle \(intervalDays) Tage"
                ))
            }
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "星期", en: "Weekdays", de: "Wochentage"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                HStack(spacing: 6) {
                    ForEach(FamilyTaskWeekday.allCases) { weekday in
                        Button {
                            if selectedWeekdays.contains(weekday) {
                                selectedWeekdays.remove(weekday)
                            } else {
                                selectedWeekdays.insert(weekday)
                            }
                        } label: {
                            Text(shortWeekdayTitle(weekday))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedWeekdays.contains(weekday) ? Color.goPrimary : Color.ohanaSecondaryText)
                        .accessibilityValue(
                            selectedWeekdays.contains(weekday)
                                ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                                : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
                        )
                    }
                }
            }
        case .monthlyDay:
            Picker(
                l.tr(zh: "每月日期", en: "Day of month", de: "Tag im Monat"),
                selection: $monthlyDay
            ) {
                ForEach(1 ... 31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
        case .monthlyLastDay:
            Text(l.tr(
                zh: "将在每个月的最后一天创建实例。",
                en: "An occurrence will be created on the last day of each month.",
                de: "Am letzten Tag jedes Monats wird eine Aufgabe erstellt."
            ))
            .font(OhanaFont.caption())
            .foregroundStyle(Color.ohanaSecondaryText)
        }

        if recurrenceKind != .once {
            Toggle(
                l.tr(zh: "设置开始日期", en: "Set start date", de: "Startdatum festlegen"),
                isOn: $hasStartDate
            )
            .tint(Color.goPrimary)
            if hasStartDate {
                DatePicker(
                    l.tr(zh: "开始日期", en: "Starts", de: "Beginn"),
                    selection: $startsAt,
                    displayedComponents: [.date]
                )
            }
            Toggle(
                l.tr(zh: "设置结束日期", en: "Set end date", de: "Enddatum festlegen"),
                isOn: $hasEndDate
            )
            .tint(Color.goPrimary)
            if hasEndDate {
                DatePicker(
                    l.tr(zh: "结束日期（含当天）", en: "Ends (inclusive)", de: "Ende (einschließlich)"),
                    selection: $endsAt,
                    in: (hasStartDate ? startsAt : dueAt) ... Date.distantFuture,
                    displayedComponents: [.date]
                )
            }
        }
    }

    @ViewBuilder
    private var reminderControls: some View {
        Toggle(
            l.tr(zh: "提醒我", en: "Remind me", de: "Mich erinnern"),
            isOn: $hasReminder
        )
        .tint(Color.goPrimary)
        if hasReminder {
            Picker(
                l.tr(zh: "提前", en: "Before", de: "Vorher"),
                selection: $reminderLeadMinutes
            ) {
                Text(l.tr(zh: "到期时", en: "At due time", de: "Zur Fälligkeit")).tag(0)
                Text(l.tr(zh: "10 分钟", en: "10 minutes", de: "10 Minuten")).tag(10)
                Text(l.tr(zh: "30 分钟", en: "30 minutes", de: "30 Minuten")).tag(30)
                Text(l.tr(zh: "1 小时", en: "1 hour", de: "1 Stunde")).tag(60)
                Text(l.tr(zh: "1 天", en: "1 day", de: "1 Tag")).tag(1440)
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label(saveActionTitle, systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .disabled(!canSave || isSaving)
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
                    pendingCancellationTaskID = task.id
                } label: {
                    Label(
                        l.tr(zh: "撤销任务", en: "Cancel task", de: "Aufgabe abbrechen"),
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

    private var usesPlanRewardSnapshot: Bool {
        if context.task?.planId != nil { return true }
        if case .create = route {
            return hasDueDate && onCreatePlan != nil
        }
        return false
    }

    private var canSave: Bool {
        guard currentHuman != nil,
              selectedHuman != nil,
              !includesReward || (
                      reward > 0 &&
                      reward <= FamilyTaskRewardPolicy.cap &&
                      (usesPlanRewardSnapshot || reward <= availableBalance)
              )
        else { return false }

        if showsPlanScheduleControls {
            if recurrenceKind == .weekly && selectedWeekdays.isEmpty {
                return false
            }
            if hasEndDate && endsAt < (hasStartDate ? startsAt : dueAt) {
                return false
            }
        }

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
        if case .editTask = route,
           editScope == .thisAndFuture,
           let task = context.task,
           let rawPlanID = task.planId,
           let planID = UUID(uuidString: rawPlanID),
           let nominalAt = task.nominalAt,
           let onUpdatePlan,
           let draft = planDraft {
            isSaving = true
            Task { @MainActor in
                let didSave = await onUpdatePlan(planID, nominalAt, draft)
                isSaving = false
                finishSave(didSave)
            }
            return
        }
        if case .create = route,
           hasDueDate,
           let onCreatePlan,
           let draft = planDraft {
            isSaving = true
            Task { @MainActor in
                let didSave = await onCreatePlan(draft)
                isSaving = false
                finishSave(didSave)
            }
            return
        }
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

        finishSave(didSave)
    }

    private func finishSave(_ didSave: Bool) {
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

    private var planDraft: FamilyTaskPlanDraft? {
        guard let currentHuman, let selectedHuman else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: planTimeZoneIdentifier) ?? .current
        let anchorAt = isAllDay ? calendar.startOfDay(for: dueAt) : dueAt
        let editedTask = context.task
        return FamilyTaskPlanDraft(
            title: title,
            note: note,
            emoji: emoji,
            subjectKind: editedTask?.subjectKind ?? .household,
            subjectID: editedTask?.resolvedSubjectId.flatMap(UUID.init(uuidString:)),
            subjectName: planSubjectName,
            creatorID: currentHuman.id,
            assigneeID: selectedHuman.id,
            rewardCoconuts: effectiveReward,
            recurrenceRule: recurrenceRule,
            anchorAt: anchorAt,
            startsAt: hasStartDate ? startsAt : nil,
            endsAt: hasEndDate ? endsAt : nil,
            timeZoneIdentifier: planTimeZoneIdentifier,
            isAllDay: isAllDay,
            reminderLeadMinutes: hasReminder ? reminderLeadMinutes : nil,
            eventTypeRaw: planEventTypeRaw,
            taskCareKindRaw: planTaskCareKindRaw,
            expectedScheduleVersion: isRecurringTaskEdit ? planScheduleVersion : nil
        )
    }

    private var recurrenceRule: FamilyTaskRecurrenceRule {
        switch recurrenceKind {
        case .once:
            .once
        case .everyNDays:
            .everyNDays(intervalDays)
        case .weekly:
            .weekly(selectedWeekdays)
        case .monthlyDay:
            .monthlyDay(monthlyDay)
        case .monthlyLastDay:
            .monthlyLastDay
        }
    }

    private func shortWeekdayTitle(_ weekday: FamilyTaskWeekday) -> String {
        let index = max(0, min(Calendar.current.shortWeekdaySymbols.count - 1, weekday.rawValue - 1))
        return String(Calendar.current.shortWeekdaySymbols[index].prefix(2))
    }

    private func cancel(_ task: FamilyCollaborationTask) {
        if editScope == .thisAndFuture,
           let rawPlanID = task.planId,
           let planID = UUID(uuidString: rawPlanID),
           let nominalAt = task.nominalAt,
           let onCancelPlan {
            isSaving = true
            Task { @MainActor in
                let didCancel = await onCancelPlan(planID, nominalAt)
                isSaving = false
                finishCancellation(didCancel)
            }
            return
        }
        finishCancellation(onDeleteTask(task))
    }

    private func finishCancellation(_ didCancel: Bool) {
        guard didCancel else {
            saveErrorMessage = l.tr(
                zh: "任务无法撤销。请确认当前成员和任务状态后重试。",
                en: "The task could not be cancelled. Check the current member and task state, then try again.",
                de: "Die Aufgabe konnte nicht abgebrochen werden. Prüfe Mitglied und Aufgabenstatus und versuche es erneut."
            )
            return
        }
        onClose()
    }

    private var cancellationConfirmationTitle: String {
        editScope == .thisAndFuture
            ? l.tr(zh: "撤销本次及以后？", en: "Cancel this and future occurrences?", de: "Dieses und folgende Vorkommen abbrechen?")
            : l.tr(zh: "撤销这次任务？", en: "Cancel this task?", de: "Diese Aufgabe abbrechen?")
    }

    private var cancellationActionTitle: String {
        editScope == .thisAndFuture
            ? l.tr(zh: "撤销本次及以后", en: "Cancel this and future", de: "Dieses und folgende abbrechen")
            : l.tr(zh: "撤销本次", en: "Cancel this occurrence", de: "Dieses Vorkommen abbrechen")
    }

    private var cancellationConfirmationMessage: String {
        if context.task?.status == .pendingReview {
            return l.tr(
                zh: "这次任务正在等待确认。撤销后不会发放奖励，历史动态会保留。",
                en: "This task is awaiting review. Cancelling will not pay the reward, and its activity history will remain.",
                de: "Diese Aufgabe wartet auf Prüfung. Beim Abbruch wird keine Prämie ausgezahlt; der Verlauf bleibt erhalten."
            )
        }
        return l.tr(
            zh: "撤销会保留历史记录，但任务将不能再完成。",
            en: "The history will remain, but the task can no longer be completed.",
            de: "Der Verlauf bleibt erhalten, aber die Aufgabe kann nicht mehr abgeschlossen werden."
        )
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
        if includesReward && reward > availableBalance && !usesPlanRewardSnapshot {
            return l.tr(zh: "当前成员的椰子余额不足。", en: "The current member does not have enough coconuts.", de: "Das aktuelle Mitglied hat nicht genug Kokosnüsse.")
        }
        return l.tr(zh: "请填写任务名称。", en: "Add a task name.", de: "Füge einen Aufgabennamen hinzu.")
    }
}
