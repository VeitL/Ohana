import Foundation
import Testing
@testable import Ohana

struct OhanaModalInteractionTests {
    @Test func emptyEditorCanCloseWithoutConfirmation() {
        #expect(OhanaEditorDismissalDecision.resolve(hasChanges: false, isSaving: false) == .dismiss)
    }

    @Test func editedOrFailedDraftRequiresExplicitDiscard() {
        #expect(OhanaEditorDismissalDecision.resolve(hasChanges: true, isSaving: false) == .confirmDiscard)
    }

    @Test func pendingSaveCannotBeDismissedEvenWithoutAChangedDraft() {
        #expect(OhanaEditorDismissalDecision.resolve(hasChanges: false, isSaving: true) == .keepSaving)
        #expect(OhanaEditorDismissalDecision.resolve(hasChanges: true, isSaving: true) == .keepSaving)
    }

    @MainActor @Test func singlePlantShortcutSkipsOnlyTheRedundantSubjectChoice() {
        let plant = HomeToolbarQuickRecordTarget(entityID: UUID(), name: "Plant", kind: .plant, quickActions: [])
        let pet = HomeToolbarQuickRecordTarget(entityID: UUID(), name: "Pet", kind: .pet, quickActions: [])
        #expect(HomeNativeQuickRecordPolicy.singleDirectTarget([]) == nil)
        #expect(HomeNativeQuickRecordPolicy.singleDirectTarget([pet]) == nil)
        #expect(HomeNativeQuickRecordPolicy.singleDirectTarget([plant, pet]) == nil)
        #expect(HomeNativeQuickRecordPolicy.singleDirectTarget([plant]) == plant)
    }
}
