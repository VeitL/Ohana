import Foundation
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AppWorkloadPolicyTests {
    @Test func thermalStateDowngradesRuntimeBudgets() async {
        let notificationCenter = NotificationCenter()
        let thermalState = ThermalStateProbe()
        let policy = AppWorkloadPolicy(
            notificationCenter: notificationCenter,
            lowPowerModeProvider: { false },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { thermalState.value }
        )

        #expect(policy.thermalState == .nominal)
        #expect(policy.interactionMotionBudget() == .full)
        #expect(policy.ambientMotionBudget() == .full)
        #expect(policy.refreshBudget() == .live)

        thermalState.value = .fair
        notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        await Task.yield()
        await Task.yield()
        #expect(policy.thermalState == .fair)
        #expect(policy.interactionMotionBudget() == .full)
        #expect(policy.ambientMotionBudget() == .full)
        #expect(policy.refreshBudget() == .live)

        thermalState.value = .serious
        notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        await Task.yield()
        await Task.yield()
        #expect(policy.thermalState == .serious)
        #expect(policy.interactionMotionBudget() == .efficient)
        #expect(policy.ambientMotionBudget() == .efficient)
        #expect(policy.refreshBudget() == .throttled)

        thermalState.value = .critical
        notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        await Task.yield()
        await Task.yield()
        #expect(policy.thermalState == .critical)
        #expect(policy.interactionMotionBudget() == .efficient)
        #expect(policy.ambientMotionBudget() == .static)
        #expect(policy.refreshBudget() == .paused)
    }

    @Test func thermalStateComposesWithExistingStrictBudgets() {
        let policy = AppWorkloadPolicy(
            lowPowerModeProvider: { true },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { .serious }
        )

        #expect(policy.interactionMotionBudget() == .efficient)
        #expect(policy.ambientMotionBudget() == .static)
        #expect(policy.refreshBudget() == .throttled)
    }
}

private final class ThermalStateProbe {
    var value = ProcessInfo.ThermalState.nominal
}
