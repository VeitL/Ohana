//
//  HumanLabResultImportView.swift
//  Ohana
//
//  On-device document capture, recognition, review, and atomic import flow.
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

typealias HumanLabImportSaveAction = @MainActor (HumanLabImportDraft) async -> HumanLabImportSaveOutcome

private struct HumanLabCandidateEditorRoute: Identifiable {
    var candidate: HumanLabResultCandidate
    var id: UUID { candidate.id }
}

@MainActor
struct HumanLabResultImportView: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var flow = HumanLabImportPresentationState()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingDocumentCamera = false
    @State private var showingPDFImporter = false
    @State private var editorRoute: HumanLabCandidateEditorRoute?
    @State private var requiresRecorderSelection = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var recognitionOperationID: UUID?
    @State private var showingNormalConclusionConflictConfirmation = false

    private let recognitionClient: HumanLabDocumentRecognitionClient
    private let imagePageProcessor: HumanLabImagePageProcessingClient
    private let pdfPageLoader: HumanLabPDFPageLoadingClient
    private let parser: HumanLabResultParser
    private let saveAction: HumanLabImportSaveAction?

    init(human: Human) {
        self.init(
            human: human,
            recognitionClient: .live,
            imagePageProcessor: .live,
            pdfPageLoader: .live,
            parser: HumanLabResultParser(),
            saveAction: nil
        )
    }

    init(
        human: Human,
        recognitionClient: HumanLabDocumentRecognitionClient,
        imagePageProcessor: HumanLabImagePageProcessingClient = .live,
        pdfPageLoader: HumanLabPDFPageLoadingClient = .live,
        parser: HumanLabResultParser,
        saveAction: HumanLabImportSaveAction? = nil
    ) {
        self.human = human
        self.recognitionClient = recognitionClient
        self.imagePageProcessor = imagePageProcessor
        self.pdfPageLoader = pdfPageLoader
        self.parser = parser
        self.saveAction = saveAction
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaSheetPageScaffold(
            title: HumanLabScanCopy.text(.scanLabReport, l: l),
            subtitle: phaseSubtitle,
            onClose: close,
            leading: { EmptyView() },
            trailing: { toolbarAction },
            content: { phaseContent },
            floating: { EmptyView() }
        )
        .interactiveDismissDisabled(flow.isBusy)
        .fullScreenCover(isPresented: $showingDocumentCamera) {
            HumanLabDocumentCameraView(
                onFinish: finishDocumentScan,
                onCancel: { showingDocumentCamera = false },
                onFailure: failDocumentScan
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingPDFImporter,
            allowedContentTypes: [.pdf]
        ) { result in
            handlePDFImportResult(result)
        }
        .sheet(item: $editorRoute) { route in
            HumanLabCandidateEditorView(
                candidate: route.candidate,
                countryCode: appCountry,
                onSave: updateCandidate
            )
            .ohanaSheetPagePresentation(detents: OhanaSheetDetents.overview)
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            beginPhotoRecognition(items)
        }
        .onDisappear(perform: releaseVolatileState)
        .alert(
            HumanLabScanCopy.text(.conclusionConflictTitle, l: l),
            isPresented: $showingNormalConclusionConflictConfirmation
        ) {
            Button(HumanLabScanCopy.text(.reviewAgain, l: l), role: .cancel) {}
            Button(HumanLabScanCopy.text(.saveAsNormalAnyway, l: l)) {
                beginSaving(allowingNormalConclusionConflict: true)
            }
        } message: {
            Text(HumanLabScanCopy.text(.conclusionConflictMessage, l: l))
        }
        .accessibilityIdentifier("human-lab-result-import-sheet")
    }

    private var phaseSubtitle: String? {
        switch flow.phase {
        case .idle:
            HumanLabScanCopy.text(.processedOnDevice, l: l)
        case .recognizing:
            HumanLabScanCopy.text(.recognizingStatus, l: l)
        case .review:
            HumanLabScanCopy.text(.reviewBeforeSaving, l: l)
        case .failed where flow.failureOperation == .saving:
            HumanLabScanCopy.text(.reviewBeforeSaving, l: l)
        case .saving:
            HumanLabScanCopy.text(.savingStatus, l: l)
        case .completed:
            HumanLabScanCopy.text(.importCompleteStatus, l: l)
        case .failed:
            HumanLabScanCopy.text(.retryStatus, l: l)
        }
    }

    @ViewBuilder
    private var toolbarAction: some View {
        switch flow.phase {
        case .review:
            saveToolbarButton(title: HumanLabScanCopy.text(.save, l: l))
        case .failed where flow.failureOperation == .saving:
            saveToolbarButton(title: HumanLabScanCopy.text(.retrySave, l: l))
        case .saving:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(HumanLabScanCopy.text(.savingStatus, l: l))
        case .completed:
            Button(HumanLabScanCopy.text(.done, l: l)) { close() }
                .font(OhanaFont.callout(.bold))
        default:
            EmptyView()
        }
    }

    private func saveToolbarButton(title: String) -> some View {
        Button(title) { saveDraft() }
            .font(OhanaFont.callout(.bold))
            .disabled(
                selectedSavableCount == 0
                    || requiresRecorderSelection
                    || flow.draft?.conclusion == nil
                    || flow.draft?.sourceWasTruncated == true
            )
            .accessibilityIdentifier("human-lab-import-save-action")
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch flow.phase {
        case .idle:
            HumanLabImportIdleView(
                selectedPhotoItems: $selectedPhotoItems,
                onScanPaperReport: { showingDocumentCamera = true },
                onChoosePDF: { showingPDFImporter = true }
            )
        case .recognizing:
            HumanLabImportRecognizingView(onCancel: cancelRecognition)
        case .review, .saving:
            reviewContent
        case .completed:
            HumanLabImportCompletedView(importedCount: flow.importedCount)
        case .failed:
            if flow.failureOperation == .saving {
                reviewContent
            } else {
                HumanLabImportRecognitionFailureView(
                    failureDescription: flow.failureDescription,
                    onRetry: { flow.reset() }
                )
            }
        }
    }

    @ViewBuilder
    private var reviewContent: some View {
        if let draft = flow.draft {
            VStack(alignment: .leading, spacing: 16) {
                if flow.failureOperation == .saving {
                    savingFailureNotice
                }
                if draft.sourceWasTruncated {
                    truncationBlockingNotice
                }
                reviewSafetyNotice
                reportDetails(draft)
                candidateReviewSection(draft)
            }
            .disabled(flow.phase == .saving)
        }
    }

    private var reviewSafetyNotice: some View {
        HumanLabImportCard {
            Label {
                Text(HumanLabScanCopy.text(.reviewSafetyDetail, l: l))
                .font(OhanaFont.callout(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.shield.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goTeal)
            }
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(16)
        }
    }

    private var truncationBlockingNotice: some View {
        HumanLabImportCard {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HumanLabScanCopy.text(.truncationTitle, l: l))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        Text(HumanLabScanCopy.text(.truncationDetail, l: l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.octagon.fill") // a11y: allow decorative warning icon; adjacent text explains the blocked save
                        .accessibilityHidden(true)
                        .foregroundStyle(Color.goRed)
                }

                Button {
                    restartImport()
                } label: {
                    Label(
                        HumanLabScanCopy.text(.chooseAnotherReport, l: l),
                        systemImage: "arrow.clockwise"
                    )
                    .font(OhanaFont.caption(.bold))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.goRed)
                .accessibilityIdentifier("human-lab-import-truncation-retry-action")
            }
            .padding(16)
        }
        .accessibilityIdentifier("human-lab-import-truncation-blocking-notice")
    }

    private var savingFailureNotice: some View {
        HumanLabImportCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goRed)
                VStack(alignment: .leading, spacing: 4) {
                    Text(HumanLabScanCopy.text(.saveFailureTitle, l: l))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(HumanLabImportFailureCopy.saving(flow.failureDescription, l: l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .accessibilityIdentifier("human-lab-import-save-failure-notice")
    }

    private func reportDetails(_ draft: HumanLabImportDraft) -> some View {
        HumanLabImportCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(HumanLabScanCopy.text(.reportDetails, l: l), systemImage: "doc.text.fill")
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)

                HStack {
                    Text(HumanLabScanCopy.text(.reportDate, l: l))
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    DatePicker(
                        "",
                        selection: draftBinding(\.reportDate, fallback: draft.reportDate),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                Picker(
                    HumanLabScanCopy.text(.conclusion, l: l),
                    selection: draftBinding(\.conclusion, fallback: draft.conclusion)
                ) {
                    Text(HumanLabScanCopy.text(.choose, l: l))
                        .tag(nil as ReportConclusion?)
                    ForEach(ReportConclusion.allCases) { conclusion in
                        Text(HumanLabScanCatalogCopy.conclusionTitle(conclusion, l: l))
                            .tag(Optional(conclusion))
                    }
                }
                .accessibilityIdentifier("human-lab-import-conclusion-picker")

                if draft.conclusion == nil {
                    Label(
                        HumanLabScanCopy.text(.conclusionRequiredDetail, l: l),
                        systemImage: "checkmark.circle"
                    )
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goOrange)
                    .fixedSize(horizontal: false, vertical: true)
                } else if draft.requiresNormalConclusionConfirmation {
                    Label(
                        HumanLabScanCopy.text(.normalConclusionWarning, l: l),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goOrange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.hospitalOptional, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(
                        placeholder: HumanLabScanCopy.text(.hospitalName, l: l),
                        text: draftBinding(\.hospitalName, fallback: draft.hospitalName)
                    )
                    .textContentType(.organizationName)
                    .accessibilityIdentifier("human-lab-import-hospital-input")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.doctorOptional, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(
                        placeholder: HumanLabScanCopy.text(.doctorName, l: l),
                        text: draftBinding(\.doctorName, fallback: draft.doctorName)
                    )
                    .textContentType(.name)
                    .accessibilityIdentifier("human-lab-import-doctor-input")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.summaryOptional, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(
                        placeholder: HumanLabScanCopy.text(.summaryPlaceholder, l: l),
                        text: draftBinding(\.summary, fallback: draft.summary)
                    )
                    .accessibilityIdentifier("human-lab-import-summary-input")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(HumanLabScanCopy.text(.notesOptional, l: l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    OhanaTextField(
                        placeholder: HumanLabScanCopy.text(.notesPlaceholder, l: l),
                        text: draftBinding(\.notes, fallback: draft.notes)
                    )
                    .accessibilityIdentifier("human-lab-import-notes-input")
                }

                QuickCareActionHumanPickerContainer(
                    selectedHumanID: draftBinding(\.recordedByHumanID, fallback: draft.recordedByHumanID),
                    requiresSelection: $requiresRecorderSelection,
                    role: .recorder,
                    tint: .goTeal
                )
            }
            .padding(16)
        }
    }

    private func candidateReviewSection(_ draft: HumanLabImportDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HumanLabScanCopy.text(.recognizedResults, l: l))
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.text(HumanLabScanCopy.recognizedResultsSummary(
                        pageCount: draft.sourcePageCount,
                        selectedCount: draft.selectedCandidateCount,
                        totalCount: draft.candidates.count
                    )))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                Button(HumanLabScanCopy.text(.deselectAll, l: l)) {
                    deselectAllCandidates()
                }
                .font(OhanaFont.caption(.bold))
                .disabled(selectedSavableCount == 0)
                .accessibilityIdentifier("human-lab-import-deselect-all-action")
            }

            ForEach(draft.candidates) { candidate in
                candidateRow(candidate)
            }
        }
    }

    private func candidateRow(_ candidate: HumanLabResultCandidate) -> some View {
        let metric = candidate.metricKey.flatMap(HealthMetricCatalog.metric(forKey:))
        let unit = metric.flatMap { metric in
            candidate.unitCode.flatMap(metric.unit(for:))
        }
        let isStructurallySavable = HumanLabImportCandidateEligibility.isStructurallySavable(candidate)
        let canConfirmWithToggle = isStructurallySavable && !candidate.requiresReview

        return HumanLabImportCard {
            HStack(alignment: .top, spacing: 10) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: {
                            candidate.isSelected
                                && candidate.hasBeenReviewed
                                && canConfirmWithToggle
                        },
                        set: { setCandidateSelected(candidate.id, selected: $0) }
                    )
                )
                .labelsHidden()
                .disabled(!canConfirmWithToggle)
                .tint(Color.goTeal)
                .accessibilityLabel(HumanLabScanCopy.text(.includeInImport, l: l))

                Button {
                    editorRoute = HumanLabCandidateEditorRoute(candidate: candidate)
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(metric.map { HumanLabScanCatalogCopy.metricName($0, l: l) }
                                    ?? HumanLabScanCopy.text(.unmappedMetric, l: l))
                                    .font(OhanaFont.callout(.bold))
                                    .foregroundStyle(metric == nil ? Color.goOrange : Color.ohanaPrimaryText)
                                    .lineLimit(2)
                                if !candidate.hasBeenReviewed
                                    || candidate.requiresReview
                                    || !isStructurallySavable {
                                    Text(HumanLabScanCopy.text(.needsReview, l: l))
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(Color.arkInk)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.goYellow, in: Capsule())
                                }
                            }

                            Text(candidate.sourceLabel.isEmpty ? candidate.sourceText : candidate.sourceLabel)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Text(candidateValueLabel(candidate, unit: unit))
                                    .font(OhanaFont.headline(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                if candidate.reportedFlag != .unknown {
                                    Text(flagLabel(candidate.reportedFlag))
                                        .font(OhanaFont.caption2(.black))
                                        .foregroundStyle(flagColor(candidate.reportedFlag))
                                }
                            }

                            if let reference = candidate.referenceRangeText, !reference.isEmpty {
                                Text(l.text(HumanLabScanCopy.reportRange(reference)))
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaTertiaryText)
                                .lineLimit(2)
                            }

                            HStack(spacing: 6) {
                                Text(l.text(HumanLabScanCopy.pageNumber(candidate.pageIndex + 1)))
                                if let observedAt = candidate.observedAt {
                                    Text("•")
                                    Text(observedAt, format: .dateTime.year().month().day())
                                }
                            }
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaTertiaryText)
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidateAccessibilityLabel(candidate, metric: metric, unit: unit))
                .accessibilityHint(HumanLabScanCopy.text(.openItemReview, l: l))
            }
            .padding(14)
        }
        .accessibilityIdentifier("human-lab-import-candidate-\(candidate.id.uuidString)")
    }

    private func draftBinding<Value>(
        _ keyPath: WritableKeyPath<HumanLabImportDraft, Value>,
        fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: { flow.draft?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                updateDraft { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var selectedSavableCount: Int {
        flow.draft?.candidates.count(where: HumanLabImportCandidateEligibility.isReadyForImport) ?? 0
    }

    private func deselectAllCandidates() {
        flow.deselectAllCandidates()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func setCandidateSelected(_ candidateID: UUID, selected: Bool) {
        updateDraft { draft in
            guard let index = draft.candidates.firstIndex(where: { $0.id == candidateID }) else { return }
            guard !draft.candidates[index].requiresReview,
                  HumanLabImportCandidateEligibility.isStructurallySavable(draft.candidates[index]) else {
                draft.candidates[index].isSelected = false
                return
            }
            draft.candidates[index].hasBeenReviewed = true
            draft.candidates[index].isSelected = selected
        }
    }

    private func updateCandidate(_ candidate: HumanLabResultCandidate) {
        updateDraft { draft in
            guard let index = draft.candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
            var reviewedCandidate = candidate
            reviewedCandidate.hasBeenReviewed = true
            reviewedCandidate.requiresReview = false
            if !HumanLabImportCandidateEligibility.isStructurallySavable(reviewedCandidate) {
                reviewedCandidate.isSelected = false
            }
            draft.candidates[index] = reviewedCandidate
        }
    }

    private func updateDraft(_ mutation: (inout HumanLabImportDraft) -> Void) {
        guard var draft = flow.draft else { return }
        mutation(&draft)
        flow.updateDraft(draft)
    }

    private func candidateValueLabel(
        _ candidate: HumanLabResultCandidate,
        unit: HealthMetricUnit?
    ) -> String {
        guard let value = candidate.value else {
            return HumanLabScanCopy.text(.noValue, l: l)
        }
        let qualifier = switch candidate.valueQualifier {
        case .exact: ""
        case .lessThan: "< "
        case .greaterThan: "> "
        }
        let number = CountryDecimalInput.format(value, countryCode: appCountry, maxFractionDigits: 4)
        let unitLabel = unit?.label ?? candidate.sourceUnit ?? ""
        return [qualifier + number, unitLabel].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func flagLabel(_ flag: HumanLabResultFlag) -> String {
        switch flag {
        case .normal: HumanLabScanCopy.text(.normal, l: l)
        case .low: HumanLabScanCopy.text(.low, l: l)
        case .high: HumanLabScanCopy.text(.high, l: l)
        case .unknown: ""
        }
    }

    private func flagColor(_ flag: HumanLabResultFlag) -> Color {
        switch flag {
        case .normal: .goTeal
        case .low: .goCardCyan
        case .high: .goOrange
        case .unknown: .ohanaTertiaryText
        }
    }

    private func candidateAccessibilityLabel(
        _ candidate: HumanLabResultCandidate,
        metric: HealthMetric?,
        unit: HealthMetricUnit?
    ) -> String {
        let name = metric.map { HumanLabScanCatalogCopy.metricName($0, l: l) }
            ?? HumanLabScanCopy.text(.unmappedMetric, l: l)
        return "\(name), \(candidateValueLabel(candidate, unit: unit)), \(flagLabel(candidate.reportedFlag))"
    }

    private func completeRecognition(
        _ pages: [HumanLabOCRPage],
        operationID: UUID
    ) throws {
        let parseOutcome = parser.parse(pages: pages)
        try ensureCurrentRecognitionOperation(operationID)
        guard !parseOutcome.candidates.isEmpty else {
            throw parseOutcome.wasTruncated
                ? HumanLabImportRecognitionError.truncatedWithoutCandidates
                : HumanLabImportRecognitionError.noCandidates
        }
        flow.completeRecognition(
            candidates: parseOutcome.candidates,
            sourcePageCount: pages.count,
            sourceWasTruncated: parseOutcome.wasTruncated
        )
    }

    private func cancelRecognition() {
        recognitionOperationID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        selectedPhotoItems = []
        flow.cancelRecognition()
    }

    private func beginRecognitionOperation() -> UUID {
        recognitionOperationID = nil
        recognitionTask?.cancel()
        let operationID = UUID()
        recognitionOperationID = operationID
        return operationID
    }

    private func ensureCurrentRecognitionOperation(_ operationID: UUID) throws {
        try Task.checkCancellation()
        guard recognitionOperationID == operationID else { throw CancellationError() }
    }

    private func finishRecognitionOperation(_ operationID: UUID) {
        guard recognitionOperationID == operationID else { return }
        recognitionOperationID = nil
        recognitionTask = nil
    }

    private func saveDraft() {
        guard let draft = flow.draft else { return }
        if draft.requiresNormalConclusionConfirmation {
            showingNormalConclusionConflictConfirmation = true
            return
        }
        beginSaving(allowingNormalConclusionConflict: false)
    }

    private func beginSaving(allowingNormalConclusionConflict: Bool) {
        guard let draft = flow.beginSaving(
            allowingNormalConclusionConflict: allowingNormalConclusionConflict
        ) else { return }
        Task { @MainActor in
            let outcome = await performSave(draft)
            flow.completeSaving(outcome)
            if outcome.didPersist {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func performSave(_ draft: HumanLabImportDraft) async -> HumanLabImportSaveOutcome {
        guard let conclusion = draft.conclusion else { return .failed() }
        var confirmedDraft = draft
        confirmedDraft.candidates = draft.candidates.filter(
            HumanLabImportCandidateEligibility.isReadyForImport
        )
        guard !confirmedDraft.candidates.isEmpty else { return .failed() }
        if let saveAction {
            return await saveAction(confirmedDraft)
        }

        let metrics = confirmedDraft.candidates.compactMap { candidate -> HumanLabMetricImportInput? in
            guard let metricKey = candidate.metricKey,
                  let unitCode = candidate.unitCode,
                  let value = candidate.value else { return nil }
            return HumanLabMetricImportInput(
                logID: candidate.id,
                measuredAt: min(candidate.observedAt ?? confirmedDraft.reportDate, Date()),
                metricKey: metricKey,
                unitCode: unitCode,
                value: value,
                sourceLabel: candidate.sourceLabel,
                referenceLow: candidate.referenceLow,
                referenceHigh: candidate.referenceHigh,
                referenceRangeText: candidate.referenceRangeText ?? "",
                reportedFlag: persistedFlag(candidate.reportedFlag)
            )
        }
        guard !metrics.isEmpty else { return .failed() }

        let input = HumanLabReportImportInput(
            reportID: draft.reportID,
            reportType: .bloodTest,
            conclusion: conclusion,
            hospitalName: draft.hospitalName,
            doctorName: draft.doctorName,
            reportDate: min(draft.reportDate, Date()),
            summary: draft.summary,
            notes: draft.notes,
            recordedByHumanId: draft.recordedByHumanID?.uuidString,
            metrics: metrics
        )
        let result = HumanLabReportImportCommandExecutor(
            context: modelContext,
            services: appServices
        ).importReport(
            human: human,
            input: input,
            note: "human.labReport.import"
        )
        guard result.didPersist else {
            return .failed(result.persistenceErrorDescription)
        }
        return .persisted(importedCount: result.logIDs.count)
    }

    private func persistedFlag(_ flag: HumanLabResultFlag) -> HumanHealthMetricReportedFlag {
        switch flag {
        case .normal: .normal
        case .low: .low
        case .high: .high
        case .unknown: .unknown
        }
    }

    private func close() {
        guard flow.phase != .saving else { return }
        releaseVolatileState()
        dismiss()
    }

    private func releaseVolatileState() {
        recognitionOperationID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        selectedPhotoItems = []
        showingPDFImporter = false
        editorRoute = nil
        showingNormalConclusionConflictConfirmation = false
        flow.reset()
    }

    private func restartImport() {
        recognitionOperationID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        selectedPhotoItems = []
        showingPDFImporter = false
        editorRoute = nil
        requiresRecorderSelection = false
        showingNormalConclusionConflictConfirmation = false
        flow.reset()
    }

    private var pageLimitExceededDescription: String {
        let maximum = HumanLabDocumentCameraView.maximumPageCount
        return l.text(HumanLabScanCopy.pageLimitExceeded(maximum: maximum))
    }
}

private extension HumanLabResultImportView {
    func handlePDFImportResult(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            beginPDFRecognition(url)
        case let .failure(error):
            guard !isFileImporterCancellation(error), flow.beginRecognition() else { return }
            flow.failRecognition(HumanLabImportFailureCopy.recognition(error, l: l))
        }
    }

    func beginPDFRecognition(_ url: URL) {
        guard flow.beginRecognition() else { return }
        selectedPhotoItems = []
        let pageLoader = pdfPageLoader
        let documentRecognizer = recognitionClient
        let operationID = beginRecognitionOperation()
        recognitionTask = Task { @MainActor in
            defer { finishRecognitionOperation(operationID) }
            await Task.yield()
            do {
                let pages = try await pageLoader.mapRenderedPages(from: url) {
                    pageIndex,
                    imageData in
                    try Task.checkCancellation()
                    return try await documentRecognizer.recognizePage(
                        imageData,
                        pageIndex: pageIndex
                    )
                }
                try ensureCurrentRecognitionOperation(operationID)
                try completeRecognition(pages, operationID: operationID)
            } catch is CancellationError {
                guard recognitionOperationID == operationID else { return }
                flow.cancelRecognition()
            } catch {
                guard recognitionOperationID == operationID else { return }
                flow.failRecognition(HumanLabImportFailureCopy.recognition(error, l: l))
            }
        }
    }

    func isFileImporterCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain
            && cocoaError.code == CocoaError.Code.userCancelled.rawValue
    }

    func beginPhotoRecognition(_ items: [PhotosPickerItem]) {
        guard flow.beginRecognition() else { return }
        selectedPhotoItems = []
        guard items.count <= HumanLabDocumentCameraView.maximumPageCount else {
            flow.failRecognition(pageLimitExceededDescription)
            return
        }
        let photoItems = items
        let documentRecognizer = recognitionClient
        let operationID = beginRecognitionOperation()
        recognitionTask = Task { @MainActor in
            defer { finishRecognitionOperation(operationID) }
            do {
                let pages = try await HumanLabSequentialPageRecognizer.recognizePhotoPages(
                    pageCount: photoItems.count,
                    loadPage: { pageIndex in
                        guard let transferredPage = try await photoItems[pageIndex]
                            .loadTransferable(type: HumanLabPhotoPickerPageTransfer.self) else {
                            return nil
                        }
                        return try transferredPage.normalizedData(for: pageIndex)
                    },
                    recognitionClient: documentRecognizer
                )
                try ensureCurrentRecognitionOperation(operationID)
                try completeRecognition(pages, operationID: operationID)
            } catch is CancellationError {
                guard recognitionOperationID == operationID else { return }
                flow.cancelRecognition()
            } catch {
                guard recognitionOperationID == operationID else { return }
                flow.failRecognition(HumanLabImportFailureCopy.recognition(error, l: l))
            }
        }
    }

    func finishDocumentScan(_ capture: HumanLabDocumentScanCapture) {
        showingDocumentCamera = false
        guard flow.beginRecognition() else {
            capture.release()
            return
        }
        let processor = imagePageProcessor
        let documentRecognizer = recognitionClient
        let operationID = beginRecognitionOperation()
        recognitionTask = Task { @MainActor in
            defer {
                capture.release()
                finishRecognitionOperation(operationID)
            }
            await Task.yield()
            do {
                let pages = try await HumanLabSequentialPageRecognizer.recognizeCameraPages(
                    pageCount: capture.pageCount,
                    loadPage: { pageIndex in
                        capture.page(at: pageIndex)
                    },
                    processor: processor,
                    recognitionClient: documentRecognizer
                )
                try ensureCurrentRecognitionOperation(operationID)
                try completeRecognition(pages, operationID: operationID)
            } catch is CancellationError {
                guard recognitionOperationID == operationID else { return }
                flow.cancelRecognition()
            } catch {
                guard recognitionOperationID == operationID else { return }
                flow.failRecognition(HumanLabImportFailureCopy.recognition(error, l: l))
            }
        }
    }

    func failDocumentScan(_ error: Error) {
        showingDocumentCamera = false
        guard flow.beginRecognition() else { return }
        flow.failRecognition(HumanLabImportFailureCopy.recognition(error, l: l))
    }
}

nonisolated enum HumanLabImportRecognitionError: Error {
    case noCandidates
    case truncatedWithoutCandidates
}
