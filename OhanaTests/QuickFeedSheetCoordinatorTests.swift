import CoreGraphics
import Testing
@testable import Ohana

@MainActor
struct QuickFeedSheetCoordinatorTests {
    @Test func systemSheetOpenedFromSystemSheetUsesOneReturnStack() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.feedingOverview)
        coordinator.open(.manual)

        #expect(coordinator.activeSheet == .manual)
        #expect(coordinator.nestedInlineSheet == nil)
        #expect(coordinator.activeInlineSheet == nil)
        #expect(!coordinator.inlineOverlayBlocksBackground)
    }

    @Test func closeActiveReturnsThroughSystemSheetStack() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.feedingOverview)
        coordinator.open(.stockOverview)
        coordinator.open(.manual)
        coordinator.open(.stock)

        #expect(coordinator.activeSheet == .stock)
        #expect(coordinator.nestedInlineSheet == nil)

        coordinator.closeActive()
        #expect(coordinator.activeSheet == .manual)

        coordinator.closeActive()
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

    @Test func inlineDismissIsNoOpForSystemSheet() {
        let coordinator = QuickFeedSheetCoordinator()

        coordinator.openRoot(.manual)
        let dismissingSheetID = coordinator.beginInlineDismiss()

        #expect(dismissingSheetID == nil)
        #expect(!coordinator.inlineSheetDismissGestureShield)
        #expect(coordinator.inlineSheetVisible == false)

        coordinator.finishInlineDismiss(dismissingSheetID: dismissingSheetID)
        coordinator.clearInlineDismissShieldIfIdle()

        #expect(coordinator.activeSheet == .manual)
        #expect(!coordinator.inlineSheetDismissGestureShield)
    }
}
