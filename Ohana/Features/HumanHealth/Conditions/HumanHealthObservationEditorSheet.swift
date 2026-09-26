//
//  HumanHealthObservationEditorSheet.swift
//  Ohana
//

import Foundation
import SwiftData
import SwiftUI

private struct HumanHealthObservationEditorDraft: Equatable {
    let recordedAt: Date
    let severity: Double
    let moodScore: Int?
    let sleepHours: Double?
    let tagsText: String
    let possibleTriggers: String
    let careActions: String
    let medicationResponse: HumanMedicationResponse
    let sideEffects: String
    let notes: String
}

struct HumanHealthObservationEditorSheet: View {
    let human: Human
    let condition: HumanHealthCondition
    let observation: HumanHealthObservation?
    let canViewMedication: Bool
    let onSaved: () -> Void
    let onDeleted: () -> Void
    @State private var initialDraft: HumanHealthObservationEditorDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var recordedAt: Date
    @State private var severity: Double
    @State private var recordsMood: Bool
    @State private var moodScore: Int
    @State private var recordsSleep: Bool
    @State private var sleepHours: Double
    @State private var tagsText: String
    @State private var possibleTriggers: String
    @State private var careActions: String
    @State private var medicationResponse: HumanMedicationResponse
    @State private var sideEffects: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var showsDeleteConfirmation = false
    @State private var showsDiscardConfirmation = false
    @State private var errorMessage: String?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        human: Human,
        condition: HumanHealthCondition,
        observation: HumanHealthObservation?,
        canViewMedication: Bool,
        onSaved: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.human = human
        self.condition = condition
        self.observation = observation
        self.canViewMedication = canViewMedication
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        let draft = HumanHealthObservationEditorDraft(
            recordedAt: observation?.recordedAt ?? Date(),
            severity: Double(observation?.severity ?? 3),
            moodScore: observation?.moodScore,
            sleepHours: observation?.sleepHours,
            tagsText: observation?.symptomTags.joined(separator: ", ") ?? "",
            possibleTriggers: observation?.possibleTriggers ?? "",
            careActions: observation?.careActions ?? "",
            medicationResponse: canViewMedication
                ? observation?.medicationResponse ?? .unknown
                : .unknown,
            sideEffects: canViewMedication ? observation?.sideEffects ?? "" : "",
            notes: observation?.notes ?? ""
        )
        _initialDraft = State(initialValue: draft)
        _recordedAt = State(initialValue: draft.recordedAt)
        _severity = State(initialValue: draft.severity)
        _recordsMood = State(initialValue: draft.moodScore != nil)
        _moodScore = State(initialValue: draft.moodScore ?? 5)
        _recordsSleep = State(initialValue: draft.sleepHours != nil)
        _sleepHours = State(initialValue: draft.sleepHours ?? 7)
        _tagsText = State(initialValue: draft.tagsText)
        _possibleTriggers = State(initialValue: draft.possibleTriggers)
        _careActions = State(initialValue: draft.careActions)
        _medicationResponse = State(initialValue: draft.medicationResponse)
        _sideEffects = State(initialValue: draft.sideEffects)
        _notes = State(initialValue: draft.notes)
    }

    private var l: L10n { L10n(appLanguage) }
    private var appLocale: Locale { AppLanguage.effectiveLocale }
    private var severityValue: Int { Int(severity.rounded()) }
    private var currentDraft: HumanHealthObservationEditorDraft {
        HumanHealthObservationEditorDraft(
            recordedAt: recordedAt,
            severity: severity,
            moodScore: recordsMood ? moodScore : nil,
            sleepHours: recordsSleep ? sleepHours : nil,
            tagsText: tagsText,
            possibleTriggers: possibleTriggers,
            careActions: careActions,
            medicationResponse: medicationResponse,
            sideEffects: sideEffects,
            notes: notes
        )
    }
    private var hasDraftChanges: Bool { currentDraft != initialDraft }
    private var canSave: Bool { !isSaving && (observation == nil || hasDraftChanges) }
    private var title: String {
        observation == nil
            ? l.tr(zh: "记录状态", en: "Log State", de: "Status erfassen")
            : l.tr(zh: "编辑状态记录", en: "Edit State Log", de: "Status-Eintrag bearbeiten")
    }
    private var parsedTags: [String] {
        tagsText
            .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, tag in
                guard !result.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else { return }
                result.append(tag)
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        l.tr(zh: "记录时间", en: "Time", de: "Zeitpunkt"),
                        selection: $recordedAt,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                severityTitle
                                Spacer(minLength: 8)
                                severityValueLabel
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                severityTitle
                                severityValueLabel
                            }
                        }
                        Slider(value: $severity, in: 0 ... 10, step: 1)
                            .tint(condition.category.tint)
                            .accessibilityLabel(l.tr(zh: "自评严重度", en: "Self-reported severity", de: "Selbst eingeschätzte Stärke"))
                            .accessibilityValue("\(severityValue) / 10")
                            .accessibilityIdentifier("human-condition-observation-severity-input")
                    }
                } header: {
                    Text(condition.name)
                } footer: {
                    Text(l.tr(zh: "0 表示没有不适，10 表示对当下影响很强。", en: "0 means no impact; 10 means very high impact right now.", de: "0 bedeutet keine, 10 eine sehr starke aktuelle Belastung."))
                }

                Section {
                    Toggle(l.tr(zh: "记录心情自评", en: "Record mood rating", de: "Stimmung erfassen"), isOn: $recordsMood)
                    if recordsMood {
                        Stepper(value: $moodScore, in: 1 ... 10) {
                            HStack {
                                Text(l.tr(zh: "心情", en: "Mood", de: "Stimmung"))
                                Spacer()
                                Text("\(moodScore)/10")
                                    .fontWeight(.bold)
                            }
                        }
                    }

                    Toggle(l.tr(zh: "记录睡眠", en: "Record sleep", de: "Schlaf erfassen"), isOn: $recordsSleep)
                    if recordsSleep {
                        Stepper(value: $sleepHours, in: 0 ... 24, step: 0.5) {
                            let value = sleepHours.formatted(
                                .number.precision(.fractionLength(1)).locale(appLocale)
                            )
                            HStack {
                                Text(l.tr(zh: "睡眠时长", en: "Sleep duration", de: "Schlafdauer"))
                                Spacer()
                                Text(l.tr(zh: "\(value) 小时", en: "\(value) hr", de: "\(value) Std."))
                                    .fontWeight(.bold)
                            }
                        }
                    }
                } header: {
                    Text(l.tr(zh: "可选状态", en: "Optional state", de: "Optionaler Status"))
                }

                Section {
                    let suggestions = condition.category.suggestedTags(l)
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { tag in
                                    Button {
                                        toggleSuggestedTag(tag)
                                    } label: {
                                        Text(tag)
                                            .font(OhanaFont.caption(.black))
                                            .foregroundStyle(parsedTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) ? Color.arkInk : condition.category.tint)
                                            .padding(.horizontal, 10)
                                            .frame(minHeight: 44)
                                            .background(
                                                parsedTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
                                                    ? condition.category.tint
                                                    : condition.category.tint.opacity(0.12),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(isSuggestedTagSelected(tag) ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    TextField(
                        l.tr(zh: "用逗号分隔，例如：鼻塞、眼痒", en: "Comma-separated, for example: congestion, itchy eyes", de: "Mit Kommas trennen, z. B. Nase zu, juckende Augen"),
                        text: $tagsText,
                        axis: .vertical
                    )
                    .lineLimit(2 ... 5)
                } header: {
                    Text(l.tr(zh: "症状或状态标签", en: "Symptom or state tags", de: "Symptom- oder Status-Tags"))
                }

                Section(l.tr(zh: "上下文", en: "Context", de: "Kontext")) {
                    TextField(
                        l.tr(zh: "可能的诱因或暴露（不作因果判断）", en: "Possible triggers or exposure (not a causal claim)", de: "Mögliche Auslöser oder Exposition (keine Kausalaussage)"),
                        text: $possibleTriggers,
                        axis: .vertical
                    )
                    .lineLimit(2 ... 6)
                    TextField(
                        l.tr(zh: "采取了什么行动", en: "Actions taken", de: "Ergriffene Maßnahmen"),
                        text: $careActions,
                        axis: .vertical
                    )
                    .lineLimit(2 ... 6)
                }

                if canViewMedication {
                    Section {
                        Picker(l.tr(zh: "主观用药反应", en: "Self-reported medication response", de: "Selbst berichtete Medikamentenreaktion"), selection: $medicationResponse) {
                            ForEach(HumanMedicationResponse.allCases) { response in
                                Text(response.displayName(l)).tag(response)
                            }
                        }

                        TextField(
                            l.tr(zh: "副作用或其他不适", en: "Side effects or other discomfort", de: "Nebenwirkungen oder andere Beschwerden"),
                            text: $sideEffects,
                            axis: .vertical
                        )
                        .lineLimit(2 ... 6)
                    } header: {
                        Text(l.tr(zh: "用药观察", en: "Medication observation", de: "Medikamentenbeobachtung"))
                    } footer: {
                        Text(l.tr(zh: "这里只记录主观感受，不用于判断药物疗效或安全性。", en: "This records personal experience only; it does not assess effectiveness or safety.", de: "Hier wird nur die persönliche Wahrnehmung erfasst; Wirksamkeit oder Sicherheit werden nicht bewertet."))
                    }
                }

                Section(l.tr(zh: "备注", en: "Notes", de: "Notizen")) {
                    TextField(
                        l.tr(zh: "其他细节", en: "Other details", de: "Weitere Details"),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 8)
                    .accessibilityIdentifier("human-condition-observation-notes-input")
                }

                if observation != nil {
                    Section {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label(l.tr(zh: "删除状态记录", en: "Delete state log", de: "Status-Eintrag löschen"), systemImage: "trash")
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("human-condition-observation-delete-action")
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
                    .disabled(!canSave)
                        .accessibilityIdentifier("human-condition-observation-save-action")
                }
            }
            .interactiveDismissDisabled(hasDraftChanges || isSaving)
        }
        .accessibilityIdentifier("human-condition-status-entry-sheet")
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
            l.tr(zh: "删除状态记录？", en: "Delete state log?", de: "Status-Eintrag löschen?"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(l.cancel, role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) { deleteObservation() }
                .accessibilityIdentifier("human-condition-observation-delete-confirm-action")
        } message: {
            Text(l.tr(zh: "删除后无法撤销。", en: "This cannot be undone.", de: "Dies kann nicht rückgängig gemacht werden."))
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

    private func toggleSuggestedTag(_ tag: String) {
        var tags = parsedTags
        if let index = tags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
        tagsText = tags.joined(separator: ", ")
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func isSuggestedTagSelected(_ tag: String) -> Bool {
        parsedTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private var severityTitle: some View {
        Text(l.tr(zh: "自评严重度", en: "Self-reported severity", de: "Selbst eingeschätzte Stärke"))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var severityValueLabel: some View {
        Text("\(severityValue)/10 · \(HumanHealthSeverityLabel.text(for: severityValue, l: l))")
            .font(OhanaFont.callout(.black))
            .foregroundStyle(condition.category.tint)
            .contentTransition(.numericText())
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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
        guard canSave else { return }
        isSaving = true
        let input = HumanHealthObservationCommandInput(
            recordedAt: recordedAt,
            severity: severityValue,
            moodScore: recordsMood ? moodScore : nil,
            sleepHours: recordsSleep ? sleepHours : nil,
            symptomTags: parsedTags,
            possibleTriggers: possibleTriggers,
            careActions: careActions,
            medicationResponse: canViewMedication ? medicationResponse : nil,
            sideEffects: canViewMedication ? sideEffects : nil,
            notes: notes,
            recordedByHumanId: activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
        )
        let observationID = observation?.id ?? UUID()
        let command = DomainCommand.humanHealthObservation(
            humanID: human.id,
            conditionID: condition.id,
            observationID: observationID,
            action: observation == nil ? "record" : "update"
        )

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let executor = HumanHealthConditionCommandExecutor(context: modelContext, services: appServices)
            let result: HumanHealthObservationCommandResult = if let observation {
                executor.updateObservation(
                    observation,
                    condition: condition,
                    human: human,
                    input: input,
                    note: "human.health.observation.updated"
                )
            } else {
                executor.recordObservation(
                    condition: condition,
                    human: human,
                    input: input,
                    note: "human.health.observation.recorded"
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
    private func deleteObservation() {
        guard !isSaving, let observation else { return }
        isSaving = true
        let command = DomainCommand.humanHealthObservation(
            humanID: human.id,
            conditionID: condition.id,
            observationID: observation.id,
            action: "delete"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = HumanHealthConditionCommandExecutor(context: modelContext, services: appServices)
                .deleteObservation(
                    observation,
                    condition: condition,
                    human: human,
                    note: "human.health.observation.deleted"
                )
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
