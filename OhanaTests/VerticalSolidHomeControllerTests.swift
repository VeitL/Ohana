@testable import Ohana
import Testing

@MainActor
struct VerticalSolidHomeControllerTests {
    @Test func selectingUnpreparedTabMovesImmediatelyIntoPreparingState() {
        let controller = VerticalSolidHomeController(
            initialSnapshot: .empty,
            initialSignature: "initial"
        )

        controller.select(.oasis)

        #expect(controller.selectedTab == .oasis)
        #expect(controller.outgoingTab == .home)
        #expect(controller.preparingTab == .oasis)
        #expect(controller.preparedTabs == Set([.home]))

        controller.cancel()
    }

    @Test func selectingPreparedTabDoesNotEnterPreparingState() {
        let controller = VerticalSolidHomeController(
            initialSnapshot: .empty,
            initialSignature: "initial"
        )

        controller.select(.oasis)
        controller.cancel()
        controller.select(.home)

        #expect(controller.selectedTab == .home)
        #expect(controller.outgoingTab == .oasis)
        #expect(controller.preparingTab == nil)

        controller.cancel()
    }

    @Test func snapshotRefreshGateSchedulesImmediatelyWhenHeroIsIdle() {
        var gate = HomeSnapshotRefreshGate()

        let request = gate.dataDidChange(
            signature: "signature-a",
            isHeroAnimating: false
        )

        #expect(request?.signature == "signature-a")
        #expect(request?.delayMilliseconds == HomeSnapshotRefreshGate.normalDelayMilliseconds)
        #expect(gate.pendingSignature == nil)
    }

    @Test func snapshotRefreshGateDefersDataChangeDuringHeroAnimation() {
        var gate = HomeSnapshotRefreshGate()

        let request = gate.dataDidChange(
            signature: "signature-b",
            isHeroAnimating: true
        )

        #expect(request == nil)
        #expect(gate.pendingSignature == "signature-b")
    }

    @Test func snapshotRefreshGateFlushesLatestSignatureAfterHeroAnimation() {
        var gate = HomeSnapshotRefreshGate()

        _ = gate.dataDidChange(signature: "signature-old", isHeroAnimating: true)
        _ = gate.dataDidChange(signature: "signature-new", isHeroAnimating: true)

        let requestWhileAnimating = gate.heroAnimationDidChange(isAnimating: true)
        #expect(requestWhileAnimating == nil)
        #expect(gate.pendingSignature == "signature-new")

        let request = gate.heroAnimationDidChange(isAnimating: false)
        #expect(request?.signature == "signature-new")
        #expect(request?.delayMilliseconds == HomeSnapshotRefreshGate.postHeroDelayMilliseconds)
        #expect(gate.pendingSignature == nil)
    }
}
