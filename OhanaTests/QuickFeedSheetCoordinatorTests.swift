import CoreGraphics
import Testing
@testable import Ohana

@MainActor
struct QuickFeedSheetCoordinatorTests {
    @Test func inlineSheetOpenedFromSystemSheetBecomesNestedRoute() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.feedingOverview)
        coordinator.open(.manual)

        #expect(coordinator.activeSheet == .feedingOverview)
        #expect(coordinator.nestedInlineSheet == .manual)
        #expect(coordinator.activeInlineSheet == .manual)
        #expect(coordinator.inlineOverlayBlocksBackground)
    }

    @Test func closeActiveReturnsThroughNestedAndRootStacks() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.feedingOverview)
        coordinator.open(.stockOverview)
        coordinator.open(.manual)
        coordinator.open(.stock)

        #expect(coordinator.activeSheet == .stockOverview)
        #expect(coordinator.nestedInlineSheet == .stock)

        coordinator.closeActive()
        #expect(coordinator.nestedInlineSheet == .manual)

        coordinator.closeActive()
        #expect(coordinator.nestedInlineSheet == nil)
        #expect(coordinator.activeSheet == .stockOverview)

        coordinator.closeActive()
        #expect(coordinator.activeSheet == .feedingOverview)

        coordinator.closeActive()
        #expect(coordinator.activeSheet == nil)
    }

    @Test func activeSheetResetClearsInlinePresentationForSystemSheet() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.manual)
        coordinator.inlineSheetVisible = true
        coordinator.inlineKeyboardHeight = 240
        coordinator.openRoot(.history)
        coordinator.resetForActiveSheetChange()

        #expect(coordinator.activeSheet == .history)
        #expect(coordinator.inlineSheetVisible == false)
        #expect(coordinator.inlineKeyboardHeight == 0)
        #expect(coordinator.adaptiveSheetHeight == ActiveFeedSheet.history.defaultAdaptiveHeight)
    }

    @Test func inlineDismissFinishesMatchingRouteAndReleasesShieldWhenIdle() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.manual)
        let dismissingSheetID = coordinator.beginInlineDismiss()

        #expect(dismissingSheetID == ActiveFeedSheet.manual.id)
        #expect(coordinator.inlineSheetDismissGestureShield)
        #expect(coordinator.inlineSheetVisible == false)

        coordinator.finishInlineDismiss(dismissingSheetID: dismissingSheetID)
        coordinator.clearInlineDismissShieldIfIdle()

        #expect(coordinator.activeSheet == nil)
        #expect(coordinator.inlineSheetDismissGestureShield == false)
    }
}
