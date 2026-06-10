import Foundation
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AppWorkloadPolicyTests {
    @Test func thermalStateDowngradesRuntimeBudgets() async {
        let notificationCenter = NotificationCenter()
        var thermalState = ProcessInfo.ThermalState.nominal
        let policy = AppWorkloadPolicy(
            notificationCenter: notificationCenter,
            lowPowerModeProvider: { false },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { thermalState }
        )

        #expect(policy.thermalState == .nominal)
        #expect(policy.interactionMotionBudget() == .full)
        #expect(policy.ambientMotionBudget() == .full)
        #expect(policy.refreshBudget() == .live)

        thermalState = .fair
        notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        await Task.yield()
        await Task.yield()
        #expect(policy.thermalState == .fair)
        #expect(policy.interactionMotionBudget() == .full)
        #expect(policy.ambientMotionBudget() == .full)
        #expect(policy.refreshBudget() == .live)

        thermalState = .serious
        notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        await Task.yield()
        await Task.yield()
        #expect(policy.thermalState == .serious)
        #expect(policy.interactionMotionBudget() == .efficient)
        #expect(policy.ambientMotionBudget() == .efficient)
        #expect(policy.refreshBudget() == .throttled)

        thermalState = .critical
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
