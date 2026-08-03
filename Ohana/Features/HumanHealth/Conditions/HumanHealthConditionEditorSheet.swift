//
//  HumanHealthConditionEditorSheet.swift
//  Ohana
//

import SwiftData
import SwiftUI

private struct HumanHealthConditionEditorDraft: Equatable {
    let name: String
    let category: HumanHealthConditionCategory
    let trackingStatus: HumanHealthTrackingStatus
    let hasStartDate: Bool
    let startedOn: Date?
    let carePlan: String
    let notes: String
    let selectedMedicationIDs: Set<UUID>
    let selectedMetricKeys: Set<String>
}

struct HumanHealthConditionEditorSheet: View {
    let human: Human
    let condition: HumanHealthCondition?
    let medications: [HumanMedication]
    let canViewMedication: Bool
    let onSaved: () -> Void
    let onDeleted: () -> Void
    @State private var initialDraft: HumanHealthConditionEditorDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var name: String
    @State private var category: HumanHealthConditionCategory
    @State private var trackingStatus: HumanHealthTrackingStatus
    @State private var hasStartDate: Bool
    @State private var startedOn: Date
    @State private var carePlan: String
    @State private var notes: String
    @State private var selectedMedicationIDs: Set<UUID>
    @State private var selectedMetricKeys: Set<String>
    @State private var isSaving = false
    @State private var showsDeleteConfirmation = false
    @State private var showsDiscardConfirmation = false
    @State private var errorMessage: String?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        human: Human,
        condition: HumanHealthCondition?,
        medications: [HumanMedication],
        canViewMedication: Bool,
        onSaved: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.human = human
        self.condition = condition
        self.medications = medications
        self.canViewMedication = canViewMedication
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        let draft = HumanHealthConditionEditorDraft(
            name: condition?.name ?? "",
            category: condition?.category ?? .mentalHealth,
            trackingStatus: condition?.trackingStatus ?? .active,
            hasStartDate: condition?.startedOn != nil,
            startedOn: condition?.startedOn,
            carePlan: condition?.carePlan ?? "",
            notes: condition?.notes ?? "",
            selectedMedicationIDs: canViewMedication
                ? Set(condition?.linkedMedicationIDs ?? [])
                : [],
            selectedMetricKeys: Set(condition?.linkedMetricKeys ?? [])
        )
        _initialDraft = State(initialValue: draft)
        _name = State(initialValue: draft.name)
        _category = State(initialValue: draft.category)
        _trackingStatus = State(initialValue: draft.trackingStatus)
        _hasStartDate = State(initialValue: draft.hasStartDate)
        _startedOn = State(initialValue: draft.startedOn ?? Date())
        _carePlan = State(initialValue: draft.carePlan)
        _notes = State(initialValue: draft.notes)
        _selectedMedicationIDs = State(initialValue: draft.selectedMedicationIDs)
        _selectedMetricKeys = State(initialValue: draft.selectedMetricKeys)
    }

    private var l: L10n { L10n(appLanguage) }
    private var title: String {
        condition == nil
            ? l.tr(zh: "添加健康状况", en: "Add Health Condition", de: "Gesundheitszustand hinzufügen")
            : l.tr(zh: "编辑健康状况", en: "Edit Health Condition", de: "Gesundheitszustand bearbeiten")
    }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasDraftChanges
            && !isSaving
    }
    private var currentDraft: HumanHealthConditionEditorDraft {
        HumanHealthConditionEditorDraft(
            name: name,
            category: category,
            trackingStatus: trackingStatus,
            hasStartDate: hasStartDate,
            startedOn: hasStartDate ? startedOn : nil,
            carePlan: carePlan,
            notes: notes,
            selectedMedicationIDs: selectedMedicationIDs,
            selectedMetricKeys: selectedMetricKeys
        )
    }
    private var hasDraftChanges: Bool { currentDraft != initialDraft }
    private var selectableMedications: [HumanMedication] {
        medications.sorted {
            if $0.isActive != $1.isActive { return $0.isActive && !$1.isActive }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        l.tr(zh: "例如：季节性过敏", en: "For example: Seasonal allergy", de: "Zum Beispiel: Saisonale Allergie"),
                        text: $name
                    )
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("human-condition-name-input")

                    Picker(l.tr(zh: "类别", en: "Category", de: "Kategorie"), selection: $category) {
                        ForEach(HumanHealthConditionCategory.allCases) { item in
                            Label(item.displayName(l), systemImage: item.systemImage)
                                .tag(item)
                        }
                    }

                    Picker(l.tr(zh: "追踪状态", en: "Tracking status", de: "Tracking-Status"), selection: $trackingStatus) {
                        ForEach(HumanHealthTrackingStatus.allCases) { item in
                            Text(item.displayName(l)).tag(item)
                        }
                    }
                } header: {
                    Text(l.tr(zh: "基本信息", en: "Basics", de: "Grundlagen"))
                } footer: {
                    Text(l.tr(
                        zh: "名称和状态由你记录，不代表 Ohana 作出的诊断。",
                        en: "Names and states are your records, not diagnoses made by Ohana.",
                        de: "Name und Status sind deine Einträge, keine Diagnose von Ohana."
                    ))
                }

                Section(l.tr(zh: "时间", en: "Timeline", de: "Zeitraum")) {
                    Toggle(l.tr(zh: "记录开始日期", en: "Record start date", de: "Startdatum erfassen"), isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker(
                            l.tr(zh: "开始日期", en: "Start date", de: "Startdatum"),
                            selection: $startedOn,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section(l.tr(zh: "照护计划", en: "Care plan", de: "Versorgungsplan")) {
                    TextField(
                        l.tr(zh: "复诊、日常行动或医生建议", en: "Follow-up, daily actions, or clinician advice", de: "Kontrolle, Alltag oder ärztlicher Rat"),
                        text: $carePlan,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 7)
                }

                Section {
                    if !canViewMedication {
                        Label(
                            l.tr(zh: "用药信息已锁定", en: "Medication information is locked", de: "Medikamenteninformationen sind gesperrt"),
                            systemImage: "lock.fill"
                        )
                        .foregroundStyle(Color.ohanaSecondaryText)
                    } else if selectableMedications.isEmpty {
                        Text(l.tr(zh: "暂无可关联药物。可先在用药模块添加计划。", en: "No medication plans to link. Add one in Medication first.", de: "Keine Medikamentenpläne zum Verknüpfen. Lege zuerst einen Plan an."))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    } else {
                        ForEach(selectableMedications) { medication in
                            selectionRow(
                                title: medication.name,
                                subtitle: "\(medication.dosage) · \(medication.frequency.displayTitle(l: l))",
                                isSelected: selectedMedicationIDs.contains(medication.id)
                            ) {
                                toggle(medication.id, in: &selectedMedicationIDs)
                            }
                        }
                    }
                } header: {
                    Text(l.tr(zh: "关联用药", en: "Linked medication", de: "Verknüpfte Medikamente"))
                } footer: {
                    Text(l.tr(zh: "关联只用于同页查看计划完成情况和主观反应。", en: "Links only place plan completion and self-reported responses on the same page.", de: "Verknüpfungen zeigen nur Planerfüllung und selbst berichtete Reaktionen auf derselben Seite."))
                }

                Section {
                    if !category.defaultMetricKeys.isEmpty {
                        Button {
                            selectedMetricKeys.formUnion(category.defaultMetricKeys)
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(
                                l.tr(zh: "选择该类别的常用指标", en: "Select common metrics for this category", de: "Übliche Werte dieser Kategorie auswählen"),
                                systemImage: "wand.and.stars"
                            )
                        }
                    }

                    DisclosureGroup(l.tr(zh: "选择体检指标", en: "Choose checkup metrics", de: "Check-up-Werte auswählen")) {
                        ForEach(HealthMetricCatalog.all) { metric in
                            selectionRow(
                                title: metric.displayName(l),
                                subtitle: metric.category.displayName(l),
                                isSelected: selectedMetricKeys.contains(metric.key)
                            ) {
                                toggle(metric.key, in: &selectedMetricKeys)
                            }
                        }
                    }
                } header: {
                    Text(l.tr(zh: "关联体检指标", en: "Linked checkup metrics", de: "Verknüpfte Check-up-Werte"))
                } footer: {
                    Text(l.tr(zh: "关联不会判断指标和症状是否相关。", en: "Linking does not decide whether a metric and symptom are related.", de: "Die Verknüpfung bewertet keinen Zusammenhang zwischen Wert und Symptom."))
                }

                Section(l.tr(zh: "备注", en: "Notes", de: "Notizen")) {
                    TextField(
                        l.tr(zh: "其他需要保留的信息", en: "Anything else worth keeping", de: "Weitere wichtige Informationen"),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 8)
                }

                if condition != nil {
                    Section {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label(l.tr(zh: "删除状况及状态记录", en: "Delete condition and state logs", de: "Zustand und Status-Einträge löschen"), systemImage: "trash")
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("human-condition-delete-action")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, action: cancelEditing)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(l.save)
                        }
                    }
                        .fontWeight(.bold)
                        .disabled(!isValid)
                        .accessibilityIdentifier("human-condition-save-action")
                }
            }
            .interactiveDismissDisabled(hasDraftChanges || isSaving)
        }
        .accessibilityIdentifier("human-condition-editor-sheet")
        .onDisappear { commandQueue.cancelAll() }
        .confirmationDialog(
            l.tr(zh: "放弃未保存的修改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?"),
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(l.tr(zh: "放弃修改", en: "Discard Changes", de: "Änderungen verwerfen"), role: .destructive) {
                dismiss()
            }
            Button(l.tr(zh: "继续编辑", en: "Keep Editing", de: "Weiter bearbeiten"), role: .cancel) {}
        }
        .alert(
            l.tr(zh: "删除健康状况？", en: "Delete health condition?", de: "Gesundheitszustand löschen?"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(l.cancel, role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) { deleteCondition() }
                .accessibilityIdentifier("human-condition-delete-confirm-action")
        } message: {
            Text(l.tr(zh: "这会同时删除该状况下的全部状态记录，且无法撤销。", en: "This also deletes every state log under this condition and cannot be undone.", de: "Dadurch werden auch alle Status-Einträge dieses Zustands unwiderruflich gelöscht."))
        }
        .alert(
            l.tr(zh: "无法保存", en: "Couldn’t save", de: "Speichern nicht möglich"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(l.confirm, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func selectionRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? category.tint : Color.ohanaTertiaryText)
                    .font(OhanaFont.adaptive(size: 19, weight: .bold))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt") : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt"))
    }

    private func toggle<T: Hashable>(_ value: T, in selection: inout Set<T>) {
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func cancelEditing() {
        guard hasDraftChanges else {
            dismiss()
            return
        }
        showsDiscardConfirmation = true
    }

    @MainActor
    private func save() {
        guard isValid else { return }
        isSaving = true
        let input = HumanHealthConditionCommandInput(
            name: name,
            category: category,
            trackingStatus: trackingStatus,
            startedOn: hasStartDate ? startedOn : nil,
            carePlan: carePlan,
            notes: notes,
            linkedMedicationIDs: canViewMedication
                ? selectedMedicationIDs.sorted { $0.uuidString < $1.uuidString }
                : nil,
            linkedMetricKeys: selectedMetricKeys.sorted(),
            recordedByHumanId: activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
        )
        let commandID = condition?.id ?? UUID()
        let command = DomainCommand.humanHealthCondition(
            humanID: human.id,
            conditionID: commandID,
            action: condition == nil ? "create" : "update"
        )

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let executor = HumanHealthConditionCommandExecutor(context: modelContext, services: appServices)
            let result: HumanHealthConditionCommandResult = if let condition {
                executor.updateCondition(
                    condition,
                    human: human,
                    input: input,
                    note: "human.health.condition.updated"
                )
            } else {
                executor.createCondition(
                    human: human,
                    input: input,
                    note: "human.health.condition.created"
                )
            }
            guard result.didChange else {
                isSaving = false
                errorMessage = result.persistenceErrorDescription
                    ?? l.tr(zh: "请检查内容后重试。", en: "Check the details and try again.", de: "Prüfe die Angaben und versuche es erneut.")
                return
            }
            onSaved()
            dismiss()
        }
    }

    @MainActor
    private func deleteCondition() {
        guard !isSaving, let condition else { return }
        isSaving = true
        let command = DomainCommand.humanHealthCondition(
            humanID: human.id,
            conditionID: condition.id,
            action: "delete"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = HumanHealthConditionCommandExecutor(context: modelContext, services: appServices)
                .deleteCondition(condition, human: human, note: "human.health.condition.deleted")
            guard result.didChange else {
                isSaving = false
                errorMessage = result.persistenceErrorDescription
                    ?? l.tr(zh: "无法删除这条记录。", en: "This record couldn’t be deleted.", de: "Dieser Eintrag konnte nicht gelöscht werden.")
                return
            }
            onDeleted()
            dismiss()
        }
    }
}
