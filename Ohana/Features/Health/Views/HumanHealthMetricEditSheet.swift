//
//  HumanHealthMetricEditSheet.swift
//  Ohana
//
//  A lightweight editor that submits metric changes through the domain command boundary.
//

import SwiftData
import SwiftUI
import UIKit

struct HumanHealthMetricEditSheet: View {
    let human: Human
    let metric: HealthMetric
    let log: HumanHealthMetricLog
    let onSaved: (HumanHealthMetricUpdateCommandResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var valueText: String
    @State private var selectedUnitCode: String
    @State private var selectedDate: Date
    @State private var notes: String
    @State private var isSaving = false
    @State private var showingError = false

    private var copy: HumanHealthMetricEditCopy {
        HumanHealthMetricEditCopy(l: L10n(appLanguage))
    }
    private var tint: Color { metric.category.color }
    private var parsedValue: Double? {
        CountryDecimalInput.parse(valueText, countryCode: appCountry)
    }
    private var isValid: Bool {
        guard metric.unit(for: selectedUnitCode) != nil,
              let parsedValue else { return false }
        return parsedValue > 0 && parsedValue.isFinite
    }

    init(
        human: Human,
        metric: HealthMetric,
        log: HumanHealthMetricLog,
        onSaved: @escaping (HumanHealthMetricUpdateCommandResult) -> Void
    ) {
        self.human = human
        self.metric = metric
        self.log = log
        self.onSaved = onSaved
        _valueText = State(initialValue: CountryDecimalInput.format(
            log.value,
            countryCode: AppCountry.code,
            maxFractionDigits: 8
        ))
        _selectedUnitCode = State(initialValue: log.unitCode)
        _selectedDate = State(initialValue: log.date)
        _notes = State(initialValue: log.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                valueSection
                detailsSection
                if log.sourceReportID != nil {
                    provenanceSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(OhanaAppBackground())
            .navigationTitle(copy.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n(appLanguage).cancel, role: .cancel) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy.saveTitle, action: save)
                        .disabled(!isValid || isSaving || human.hasPassedAway)
                        .accessibilityIdentifier("human-health-metric-edit-save-action")
                }
            }
        }
        .tint(tint)
        .environment(\.locale, AppLanguage.effectiveLocale)
        .interactiveDismissDisabled(isSaving)
        .accessibilityIdentifier("human-health-metric-edit-sheet-\(metric.key)")
        .onChange(of: valueText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(
                newValue,
                countryCode: appCountry,
                maxFractionDigits: 8
            )
            if sanitized != newValue {
                valueText = sanitized
            }
        }
        .onChange(of: selectedUnitCode) { previousUnitCode, nextUnitCode in
            valueText = HumanHealthMetricUnitChangePolicy.valueText(
                afterChangingFrom: previousUnitCode,
                to: nextUnitCode,
                currentValueText: valueText
            )
        }
        .onDisappear {
            commandQueue.cancelAll()
            isSaving = false
        }
        .alert(copy.saveFailureTitle, isPresented: $showingError) {
            Button(copy.okTitle, role: .cancel) {}
        } message: {
            Text(copy.saveFailureMessage)
        }
    }

    private var valueSection: some View {
        Section(copy.valueTitle) {
            TextField(copy.valueTitle, text: $valueText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("human-health-metric-edit-value-input")
            if log.sourceReportID != nil {
                LabeledContent(
                    copy.unitTitle,
                    value: metric.unit(for: selectedUnitCode)?.label ?? selectedUnitCode
                )
            } else {
                Picker(copy.unitTitle, selection: $selectedUnitCode) {
                    ForEach(metric.units) { unit in
                        Text(unit.label).tag(unit.code)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Section {
            if log.sourceReportID != nil {
                LabeledContent(copy.dateTitle) {
                    Text(log.date, format: .dateTime.year().month().day().hour().minute())
                }
            } else {
                DatePicker(
                    copy.dateTitle,
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            TextField(copy.notesTitle, text: $notes, axis: .vertical)
                .lineLimit(2 ... 5)
                .accessibilityIdentifier("human-health-metric-edit-notes-input")
        }
    }

    private var provenanceSection: some View {
        Section(copy.sourceTitle) {
            Label(copy.importedTitle, systemImage: "doc.text.viewfinder")
            if !log.sourceLabel.isEmpty {
                LabeledContent(copy.sourceItemTitle, value: log.sourceLabel)
            }
            Text(copy.provenanceMessage)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    @MainActor
    private func save() {
        guard !isSaving,
              !human.hasPassedAway,
              let value = parsedValue,
              value > 0,
              value.isFinite else { return }
        isSaving = true
        let input = HumanHealthMetricUpdateInput(
            unitCode: selectedUnitCode,
            value: value,
            date: min(selectedDate, Date()),
            notes: notes
        )

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.humanHealthMetricUpdate(
            humanID: human.id,
            metricKey: log.metricKey,
            logID: log.id
        )) {
            let result = HumanCareCommandExecutor(
                context: modelContext,
                services: appServices
            ).updateHealthMetric(
                log,
                human: human,
                input: input,
                note: "humanHealthMetric.update"
            )
            isSaving = false
            guard result.didPersist else {
                showingError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            onSaved(result)
            dismiss()
        }
    }
}
