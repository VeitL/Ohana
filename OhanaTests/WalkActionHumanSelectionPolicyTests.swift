import Testing
@testable import Ohana

struct WalkActionHumanSelectionPolicyTests {
    @Test func defaultsToCurrentHumanAndKeepsAnExplicitSwitch() {
        let eligible = ["current", "other"]

        #expect(WalkActionHumanSelectionPolicy.reconciledSelection(
            selectedIDs: [],
            eligibleIDs: eligible,
            currentHumanID: "current"
        ) == ["current"])
        #expect(WalkActionHumanSelectionPolicy.reconciledSelection(
            selectedIDs: ["other"],
            eligibleIDs: eligible,
            currentHumanID: "current"
        ) == ["other"])
    }

    @Test func soleHumanNeedsNoVisibleChoiceAndInvalidMultiHumanSelectionCannotStart() {
        #expect(WalkActionHumanSelectionPolicy.reconciledSelection(
            selectedIDs: [],
            eligibleIDs: ["only"],
            currentHumanID: nil
        ) == ["only"])
        #expect(!WalkActionHumanSelectionPolicy.canStart(
            eligibleIDs: ["first", "second"],
            selectedIDs: []
        ))
        #expect(WalkActionHumanSelectionPolicy.canStart(
            eligibleIDs: ["first", "second"],
            selectedIDs: ["second"]
        ))
        #expect(WalkActionHumanSelectionPolicy.canStart(
            eligibleIDs: [],
            selectedIDs: []
        ))
    }
}
