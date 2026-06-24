import Foundation
import Testing
@testable import Ohana

struct ActiveHumanSelectionPolicyTests {
    @Test func creatingFirstHumanSetsActiveHumanWhenSelectionIsEmpty() {
        let createdHumanId = UUID()

        let result = ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman(
            currentHumanIdRaw: "",
            createdHumanId: createdHumanId
        )

        #expect(result == createdHumanId.uuidString)
    }

    @Test func creatingAdditionalHumanKeepsCurrentActiveHumanSelection() {
        let currentHumanId = UUID().uuidString
        let createdHumanId = UUID()

        let result = ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman(
            currentHumanIdRaw: currentHumanId,
            createdHumanId: createdHumanId
        )

        #expect(result == currentHumanId)
    }
}
