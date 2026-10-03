import Testing
@testable import Ohana

@MainActor
@Suite("Human lab import presentation state")
struct HumanLabImportPresentationStateTests {
    @Test("Cancellation is a normal return to idle")
    func cancellationReturnsToIdle() {
        var state = HumanLabImportPresentationState()

        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.cancelRecognition()

        #expect(state.phase == .idle)
        #expect(state.failureOperation == nil)
        #expect(state.failureDescription == nil)
    }

    @Test("Recognition failure can be retried without a stale draft")
    func recognitionRetry() {
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.failRecognition("Unreadable")

        #expect(state.phase == .failed)
        #expect(state.failureOperation == .recognition)
        #expect(state.draft == nil)
        let didBeginRetry = state.beginRecognition()
        #expect(didBeginRetry)
        #expect(state.phase == .recognizing)
    }

    @Test("Save failure retains the exact reviewed draft")
    func saveFailureRetainsDraft() throws {
        var state = HumanLabImportPresentationState()
        let candidate = selectedCandidate()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)
        selectConclusion(.normal, in: &state)
        let pendingDraft = state.beginSaving()
        let draft = try #require(pendingDraft)

        state.completeSaving(.failed("Disk unavailable"))

        #expect(state.phase == .failed)
        #expect(state.failureOperation == .saving)
        #expect(state.draft == draft)
        #expect(state.keepsReviewDraft)
    }

    @Test("Successful save releases the volatile review draft")
    func saveSuccessReleasesDraft() throws {
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [selectedCandidate()], sourcePageCount: 1)
        selectConclusion(.normal, in: &state)
        let pendingDraft = state.beginSaving()
        _ = try #require(pendingDraft)

        state.completeSaving(.persisted(importedCount: 1))

        #expect(state.phase == .completed)
        #expect(state.importedCount == 1)
        #expect(state.draft == nil)
    }

    @Test("A scan conclusion must be chosen explicitly")
    func conclusionIsRequired() {
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [selectedCandidate()], sourcePageCount: 1)

        #expect(state.draft?.conclusion == nil)
        let pendingDraft = state.beginSaving()
        #expect(pendingDraft == nil)
        #expect(state.phase == .review)
    }

    @Test("A truncated parser outcome cannot be saved")
    func truncationBlocksSaving() {
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(
            candidates: [selectedCandidate()],
            sourcePageCount: 1,
            sourceWasTruncated: true
        )
        selectConclusion(.attention, in: &state)

        #expect(state.draft?.sourceWasTruncated == true)
        let pendingDraft = state.beginSaving()
        #expect(pendingDraft == nil)
        #expect(state.phase == .review)
    }

    @Test("An unreviewed selected candidate cannot be saved")
    func unreviewedSelectionCannotSave() {
        var candidate = selectedCandidate()
        candidate.hasBeenReviewed = false
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)
        selectConclusion(.attention, in: &state)

        #expect(state.draft?.selectedCandidateCount == 0)
        let pendingDraft = state.beginSaving()
        #expect(pendingDraft == nil)
        #expect(state.phase == .review)
    }

    @Test("A reviewed candidate that still requires editing cannot be saved")
    func unresolvedReviewCannotSave() {
        var candidate = selectedCandidate()
        candidate.requiresReview = true
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)
        selectConclusion(.attention, in: &state)

        #expect(state.draft?.selectedCandidateCount == 0)
        let pendingDraft = state.beginSaving()
        #expect(pendingDraft == nil)
    }

    @Test("A structurally invalid reviewed candidate cannot be saved")
    func invalidReviewedCandidateCannotSave() {
        var candidate = selectedCandidate()
        candidate.unitCode = "unsupported_unit"
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)
        selectConclusion(.attention, in: &state)

        #expect(state.draft?.selectedCandidateCount == 0)
        let pendingDraft = state.beginSaving()
        #expect(pendingDraft == nil)
    }

    @Test("The only batch action cannot confirm candidates")
    func batchDeselectDoesNotConfirmCandidates() throws {
        var candidate = selectedCandidate()
        candidate.hasBeenReviewed = false
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)

        state.deselectAllCandidates()

        let pendingCandidate = try #require(state.draft?.candidates.first)
        #expect(!pendingCandidate.isSelected)
        #expect(!pendingCandidate.hasBeenReviewed)
    }

    @Test("Normal conclusion with selected H or L flag needs explicit confirmation")
    func normalFlagConflictNeedsConfirmation() throws {
        var candidate = selectedCandidate()
        candidate.reportedFlag = .high
        var state = HumanLabImportPresentationState()
        let didBeginRecognition = state.beginRecognition()
        #expect(didBeginRecognition)
        state.completeRecognition(candidates: [candidate], sourcePageCount: 1)
        selectConclusion(.normal, in: &state)

        #expect(state.draft?.requiresNormalConclusionConfirmation == true)
        let unconfirmedDraft = state.beginSaving()
        #expect(unconfirmedDraft == nil)
        let confirmedDraft = state.beginSaving(allowingNormalConclusionConflict: true)
        _ = try #require(confirmedDraft)
        #expect(state.phase == .saving)
    }

    private func selectConclusion(
        _ conclusion: ReportConclusion,
        in state: inout HumanLabImportPresentationState
    ) {
        guard var draft = state.draft else { return }
        draft.conclusion = conclusion
        state.updateDraft(draft)
    }

    private func selectedCandidate() -> HumanLabResultCandidate {
        HumanLabResultCandidate(
            sourceText: "TSH 2.4 mIU/L",
            sourceLabel: "TSH",
            metricKey: "tsh",
            value: 2.4,
            unitCode: "mIU_L",
            confidence: 0.99,
            isSelected: true,
            hasBeenReviewed: true,
            requiresReview: false
        )
    }
}
