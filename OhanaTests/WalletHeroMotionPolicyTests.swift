import CoreGraphics
import Testing
@testable import Ohana

struct WalletHeroMotionPolicyTests {
    @Test func activeWalletCardStaysForegroundWhileCollapsing() {
        #expect(WalletHeroLayeringPolicy.activeZIndex(
            collapsedZIndex: 2,
            progress: 0.8,
            direction: -1
        ) == WalletHeroLayeringPolicy.activeForegroundZIndex)

        #expect(WalletHeroLayeringPolicy.activeZIndex(
            collapsedZIndex: 2,
            progress: 0.05,
            direction: -1
        ) == WalletHeroLayeringPolicy.activeForegroundZIndex)
    }

    @Test func activeWalletCardReturnsToCollapsedLayerOnlyAtRest() {
        #expect(WalletHeroLayeringPolicy.activeZIndex(
            collapsedZIndex: 2,
            progress: 0,
            direction: 1
        ) == 2)

        #expect(WalletHeroLayeringPolicy.activeZIndex(
            collapsedZIndex: 2,
            progress: 0.02,
            direction: -1
        ) == 2)
    }
}
