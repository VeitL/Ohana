//
//  HumanLabCandidateEditorView.swift
//  Ohana
//
//  Draft-scoped editor for one recognized lab result candidate.
//

import SwiftUI

@MainActor
struct HumanLabCandidateEditorView: View {
    let countryCode: String
    let onSave: (HumanLabResultCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var candidate: HumanLabResultCandidate
    @State private var valueText: String
    @State private var referenceLowText: String
    @State private var referenceHighText: String

    init(
        candidate: HumanLabResultCandidate,
        countryCode: String,
        onSave: @escaping (HumanLabResultCandidate) -> Void
    ) {
        self.countryCode = countryCode
        self.onSave = onSave
        _candidate = State(initialValue: candidate)
        _valueText = State(initialValue: candidate.value.map {
            CountryDecimalInput.format($0, countryCode: countryCode, maxFractionDigits: 4)
        } ?? "")
        _referenceLowText = State(initialValue: candidate.referenceLow.map {
            CountryDecimalInput.format($0, countryCode: countryCode, maxFractionDigits: 4)
        } ?? "")
        _referenceHighText = State(initialValue: candidate.referenceHigh.map {
            CountryDecimalInput.format($0, countryCode: countryCode, maxFractionDigits: 4)
        } ?? "")
    }

    private var l: L10n { L10n(appLanguage) }
    private var selectedMetric: HealthMetric? {
        candidate.metricKey.flatMap(HealthMetricCatalog.metric(forKey:))
    }
    private var parsedValue: Double? {
        CountryDecimalInput.parse(valueText, countryCode: countryCode)
    }
    private var isStructurallySavable: Bool {
        guard candidate.valueQualifier == .exact,
              let metricKey = candidate.metricKey,
              let selectedMetric,
              let unitCode = candidate.unitCode,
              selectedMetric.unit(for: unitCode) != nil,
              let parsedValue else { return false }
        return HumanHealthMetricImportValidationPolicy.isValid(
            metricKey: metricKey,
            unitCode: unitCode,
            value: parsedValue,
            referenceLow: CountryDecimalInput.parse(referenceLowText, countryCode: countryCode),
            referenceHigh: CountryDecimalInput.parse(referenceHighText, countryCode: countryCode),
            sourceLabel: candidate.sourceLabel,
            referenceRangeText: candidate.referenceRangeText ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                mappingSection
                reportReferenceSection
                inclusionSection
            }
            .scrollContentBackground(.hidden)
            .background(OhanaAppBackground())
            .navigationTitle(HumanLabScanCopy.text(.reviewResult, l: l))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(HumanLabScanCopy.text(.apply, l: l)) { apply() }
                        .font(OhanaFont.callout(.bold))
                        .accessibilityIdentifier("human-lab-candidate-editor-apply-action")
                }
            }
        }
        .accessibilityIdentifier("human-lab-candidate-editor")
    }

    private var sourceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(HumanLabScanCopy.text(.originalLabel, l: l))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                OhanaTextField(
                    placeholder: HumanLabScanCopy.text(.metricLabel, l: l),
                    text: $candidate.sourceLabel
                )
                .accessibilityIdentifier("human-lab-candidate-source-label-input")
            }

            if !candidate.sourceText.isEmpty,
               candidate.sourceText != candidate.sourceLabel {
                LabeledContent(HumanLabScanCopy.text(.recognizedRow, l: l)) {
                    Text(candidate.sourceText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(4)
                }
            }

            LabeledContent(HumanLabScanCopy.text(.source, l: l)) {
                Text(l.text(HumanLabScanCopy.sourcePageOnDevice(candidate.pageIndex + 1)))
                .foregroundStyle(Color.ohanaSecondaryText)
            }

            if candidate.observedAt != nil {
                DatePicker(
                    HumanLabScanCopy.text(.reportDate, l: l),
                    selection: Binding(
                        get: { candidate.observedAt ?? Date() },
                        set: { candidate.observedAt = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("human-lab-candidate-observed-date")
            }
        } header: {
            Text(HumanLabScanCopy.text(.originalReport, l: l))
        }
    }

    private var mappingSection: some View {
        Section {
            Picker(
                HumanLabScanCopy.text(.metric, l: l),
                selection: $candidate.metricKey
            ) {
                Text(HumanLabScanCopy.text(.notMapped, l: l))
                    .tag(String?.none)
                ForEach(HealthMetricCategory.allCases) { category in
                    Section(HumanLabScanCatalogCopy.categoryName(category, l: l)) {
                        ForEach(HealthMetricCatalog.metrics(in: category)) { metric in
                            Text(HumanLabScanCatalogCopy.metricName(metric, l: l))
                                .tag(Optional(metric.key))
                        }
                    }
                }
            }
            .accessibilityIdentifier("human-lab-candidate-metric-picker")
            .onChange(of: candidate.metricKey) { _, newMetricKey in
                reconcileUnit(metricKey: newMetricKey)
            }

            Picker(
                HumanLabScanCopy.text(.valueQualifier, l: l),
                selection: $candidate.valueQualifier
            ) {
                Text(HumanLabScanCopy.text(.exact, l: l))
                    .tag(HumanLabValueQualifier.exact)
                Text(HumanLabScanCopy.text(.lessThan, l: l))
                    .tag(HumanLabValueQualifier.lessThan)
                Text(HumanLabScanCopy.text(.greaterThan, l: l))
                    .tag(HumanLabValueQualifier.greaterThan)
            }
            .accessibilityIdentifier("human-lab-candidate-qualifier-picker")

            VStack(alignment: .leading, spacing: 6) {
                Text(HumanLabScanCopy.text(.value, l: l))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                OhanaTextField(
                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: countryCode),
                    text: $valueText
                )
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("human-lab-candidate-value-input")
            }

            if let selectedMetric {
                Picker(
                    HumanLabScanCopy.text(.savedUnit, l: l),
                    selection: $candidate.unitCode
                ) {
                    Text(HumanLabScanCopy.text(.chooseUnit, l: l))
                        .tag(String?.none)
                    ForEach(selectedMetric.units) { unit in
                        Text(unit.label).tag(Optional(unit.code))
                    }
                }
                .accessibilityIdentifier("human-lab-candidate-unit-picker")
            }

            if let sourceUnit = candidate.sourceUnit, !sourceUnit.isEmpty {
                LabeledContent(HumanLabScanCopy.text(.originalUnit, l: l)) {
                    Text(sourceUnit)
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        } header: {
            Text(HumanLabScanCopy.text(.metricAndValue, l: l))
        } footer: {
            if candidate.valueQualifier != .exact {
                Text(HumanLabScanCopy.text(.exactValueGuidance, l: l))
            }
        }
    }

    private var reportReferenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(HumanLabScanCopy.text(.reportRangeText, l: l))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                OhanaTextField(
                    placeholder: HumanLabScanCopy.text(.reportRangePlaceholder, l: l),
                    text: Binding(
                        get: { candidate.referenceRangeText ?? "" },
                        set: { candidate.referenceRangeText = $0.isEmpty ? nil : $0 }
                    )
                )
                .accessibilityIdentifier("human-lab-candidate-reference-text-input")
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.lowerBound, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(placeholder: "—", text: $referenceLowText, style: .compactCapsule)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("human-lab-candidate-reference-low-input")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.upperBound, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(placeholder: "—", text: $referenceHighText, style: .compactCapsule)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("human-lab-candidate-reference-high-input")
                }
            }

            Picker(
                HumanLabScanCopy.text(.reportFlag, l: l),
                selection: $candidate.reportedFlag
            ) {
                Text(HumanLabScanCopy.text(.notMarked, l: l))
                    .tag(HumanLabResultFlag.unknown)
                Text(HumanLabScanCopy.text(.normal, l: l))
                    .tag(HumanLabResultFlag.normal)
                Text(HumanLabScanCopy.text(.low, l: l))
                    .tag(HumanLabResultFlag.low)
                Text(HumanLabScanCopy.text(.high, l: l))
                    .tag(HumanLabResultFlag.high)
            }
            .accessibilityIdentifier("human-lab-candidate-flag-picker")
        } header: {
            Text(HumanLabScanCopy.text(.reportReference, l: l))
        } footer: {
            Text(HumanLabScanCopy.text(.referenceDisclaimer, l: l))
        }
    }

    private var inclusionSection: some View {
        Section {
            Toggle(
                HumanLabScanCopy.text(.includeThisImport, l: l),
                isOn: $candidate.isSelected
            )
            .disabled(!isStructurallySavable)
            .tint(Color.goTeal)
            .accessibilityIdentifier("human-lab-candidate-include-toggle")
        } footer: {
            if !isStructurallySavable {
                Text(HumanLabScanCopy.text(.includeRequirements, l: l))
            }
        }
    }

    private func reconcileUnit(metricKey: String?) {
        guard let metricKey,
              let metric = HealthMetricCatalog.metric(forKey: metricKey) else {
            candidate.unitCode = nil
            candidate.isSelected = false
            return
        }
        if let unitCode = candidate.unitCode,
           metric.unit(for: unitCode) != nil {
            return
        }
        candidate.unitCode = metric.defaultUnit(for: countryCode).code
    }

    private func apply() {
        candidate.value = parsedValue
        candidate.referenceLow = CountryDecimalInput.parse(referenceLowText, countryCode: countryCode)
        candidate.referenceHigh = CountryDecimalInput.parse(referenceHighText, countryCode: countryCode)
        candidate.sourceLabel = candidate.sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.sourceLabel.isEmpty {
            candidate.sourceLabel = candidate.sourceText
        }
        candidate.referenceRangeText = candidate.referenceRangeText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.referenceRangeText?.isEmpty == true {
            candidate.referenceRangeText = nil
        }
        candidate.hasBeenReviewed = true
        candidate.requiresReview = false
        if !isStructurallySavable {
            candidate.isSelected = false
        }
        onSave(candidate)
        dismiss()
    }
}
