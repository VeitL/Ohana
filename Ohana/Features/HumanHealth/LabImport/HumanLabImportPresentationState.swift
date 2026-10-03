//
//  HumanLabImportPresentationState.swift
//  Ohana
//
//  Value-only draft and state reducer for the on-device lab report import flow.
//

import Foundation

nonisolated enum HumanLabImportPhase: Equatable, Sendable {
    case idle
    case recognizing
    case review
    case saving
    case completed
    case failed
}

nonisolated enum HumanLabImportFailureOperation: Equatable, Sendable {
    case recognition
    case saving
}

@MainActor
enum HumanLabImportCandidateEligibility {
    static func isStructurallySavable(_ candidate: HumanLabResultCandidate) -> Bool {
        guard candidate.valueQualifier == .exact,
              let metricKey = candidate.metricKey,
              let unitCode = candidate.unitCode,
              let value = candidate.value else { return false }
        return HumanHealthMetricImportValidationPolicy.isValid(
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            referenceLow: candidate.referenceLow,
            referenceHigh: candidate.referenceHigh,
            sourceLabel: candidate.sourceLabel,
            referenceRangeText: candidate.referenceRangeText ?? ""
        )
    }

    static func isReadyForImport(_ candidate: HumanLabResultCandidate) -> Bool {
        candidate.isSelected
            && candidate.hasBeenReviewed
            && !candidate.requiresReview
            && isStructurallySavable(candidate)
    }
}

nonisolated struct HumanLabImportDraft: Equatable {
    let reportID: UUID
    var reportDate: Date
    var conclusion: ReportConclusion?
    var hospitalName: String
    var doctorName: String
    var summary: String
    var notes: String
    var recordedByHumanID: UUID?
    var sourcePageCount: Int
    var sourceWasTruncated: Bool
    var candidates: [HumanLabResultCandidate]

    init(
        reportID: UUID = UUID(),
        reportDate: Date = Date(),
        conclusion: ReportConclusion? = nil,
        hospitalName: String = "",
        doctorName: String = "",
        summary: String = "",
        notes: String = "",
        recordedByHumanID: UUID? = nil,
        sourcePageCount: Int,
        sourceWasTruncated: Bool = false,
        candidates: [HumanLabResultCandidate]
    ) {
        self.reportID = reportID
        self.reportDate = reportDate
        self.conclusion = conclusion
        self.hospitalName = hospitalName
        self.doctorName = doctorName
        self.summary = summary
        self.notes = notes
        self.recordedByHumanID = recordedByHumanID
        self.sourcePageCount = sourcePageCount
        self.sourceWasTruncated = sourceWasTruncated
        self.candidates = candidates
    }

    @MainActor
    var selectedCandidateCount: Int {
        candidates.count(where: HumanLabImportCandidateEligibility.isReadyForImport)
    }

    @MainActor
    var requiresNormalConclusionConfirmation: Bool {
        conclusion == .normal && candidates.contains { candidate in
            HumanLabImportCandidateEligibility.isReadyForImport(candidate)
                && (candidate.reportedFlag == .low || candidate.reportedFlag == .high)
        }
    }

    @MainActor
    var isReadyToSave: Bool {
        conclusion != nil && selectedCandidateCount > 0 && !sourceWasTruncated
    }
}

nonisolated struct HumanLabImportSaveOutcome: Equatable, Sendable {
    let didPersist: Bool
    let importedCount: Int
    let errorDescription: String?

    static func persisted(importedCount: Int) -> HumanLabImportSaveOutcome {
        HumanLabImportSaveOutcome(
            didPersist: true,
            importedCount: importedCount,
            errorDescription: nil
        )
    }

    static func failed(_ errorDescription: String? = nil) -> HumanLabImportSaveOutcome {
        HumanLabImportSaveOutcome(
            didPersist: false,
            importedCount: 0,
            errorDescription: errorDescription
        )
    }
}

nonisolated struct HumanLabImportPresentationState: Equatable {
    private(set) var phase: HumanLabImportPhase = .idle
    private(set) var draft: HumanLabImportDraft?
    private(set) var failureOperation: HumanLabImportFailureOperation?
    private(set) var failureDescription: String?
    private(set) var importedCount = 0

    var isBusy: Bool {
        phase == .recognizing || phase == .saving
    }

    var keepsReviewDraft: Bool {
        draft != nil && (phase == .review || phase == .saving || failureOperation == .saving)
    }

    @discardableResult
    mutating func beginRecognition() -> Bool {
        guard phase == .idle || (phase == .failed && failureOperation == .recognition) else {
            return false
        }
        phase = .recognizing
        draft = nil
        failureOperation = nil
        failureDescription = nil
        importedCount = 0
        return true
    }

    mutating func cancelRecognition() {
        guard phase == .recognizing else { return }
        phase = .idle
        failureOperation = nil
        failureDescription = nil
    }

    mutating func completeRecognition(
        candidates: [HumanLabResultCandidate],
        sourcePageCount: Int,
        sourceWasTruncated: Bool = false
    ) {
        guard phase == .recognizing else { return }
        let recognizedReportDate = candidates.compactMap(\.observedAt).max() ?? Date()
        draft = HumanLabImportDraft(
            reportDate: min(recognizedReportDate, Date()),
            sourcePageCount: sourcePageCount,
            sourceWasTruncated: sourceWasTruncated,
            candidates: candidates
        )
        phase = .review
        failureOperation = nil
        failureDescription = nil
    }

    mutating func failRecognition(_ description: String?) {
        guard phase == .recognizing else { return }
        phase = .failed
        draft = nil
        failureOperation = .recognition
        failureDescription = description
    }

    mutating func updateDraft(_ updatedDraft: HumanLabImportDraft) {
        guard draft?.reportID == updatedDraft.reportID,
              keepsReviewDraft else { return }
        draft = updatedDraft
    }

    mutating func deselectAllCandidates() {
        guard var draft, keepsReviewDraft else { return }
        for index in draft.candidates.indices {
            draft.candidates[index].isSelected = false
        }
        self.draft = draft
    }

    @discardableResult
    @MainActor
    mutating func beginSaving(
        allowingNormalConclusionConflict: Bool = false
    ) -> HumanLabImportDraft? {
        guard let draft,
              draft.isReadyToSave,
              allowingNormalConclusionConflict || !draft.requiresNormalConclusionConfirmation,
              phase == .review || (phase == .failed && failureOperation == .saving) else {
            return nil
        }
        phase = .saving
        failureOperation = nil
        failureDescription = nil
        return draft
    }

    mutating func completeSaving(_ outcome: HumanLabImportSaveOutcome) {
        guard phase == .saving else { return }
        if outcome.didPersist {
            phase = .completed
            draft = nil
            failureOperation = nil
            failureDescription = nil
            importedCount = outcome.importedCount
        } else {
            phase = .failed
            failureOperation = .saving
            failureDescription = outcome.errorDescription
        }
    }

    mutating func reset() {
        phase = .idle
        draft = nil
        failureOperation = nil
        failureDescription = nil
        importedCount = 0
    }
}
