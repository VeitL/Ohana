import Testing
@testable import Ohana

struct VerticalHomeQuickActionReorderPolicyTests {
    private let order = ["A", "B", "C", "D"]

    @Test func movingForwardAccountsForRemovalBeforeInsertion() {
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "A", before: "D"
        ) == "C")
    }

    @Test func movingBackwardUsesTheDestinationItem() {
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "D", before: "B"
        ) == "B")
    }

    @Test func movingToEndUsesTheLastOriginalItem() {
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "B", before: nil
        ) == "D")
    }

    @Test func noOpDestinationsDoNotPersist() {
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "A", before: "B"
        ) == nil)
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "D", before: nil
        ) == nil)
        #expect(VerticalHomeQuickActionReorderPolicy.moveTargetID(
            order: order, fromID: "missing", before: "A"
        ) == nil)
    }
}
