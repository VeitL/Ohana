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

    @Test func reduceMotionMinimizesMotionWithoutThrottlingWorkOrInteraction() {
        let policy = AppWorkloadPolicy(
            lowPowerModeProvider: { false },
            reduceMotionProvider: { true },
            userPowerSavingProvider: { false },
            userReducedVisualEffectsProvider: { false },
            thermalStateProvider: { .nominal }
        )

        #expect(policy.interactionMotionBudget() == .minimal)
        #expect(policy.ambientMotionBudget() == .minimal)
        #expect(!policy.interactionMotionBudget().allowsMotion)
        #expect(policy.interactionMotionBudget().allowsEssentialFeedback)
        #expect(policy.refreshBudget() == .live)
        #expect(policy.visualEffectsBudget() == .full)
        #expect(!policy.shouldReduceWork())
        #expect(policy.shouldRunTimer())
        #expect(!policy.shouldRunRepeatingAnimation())
        #expect(!policy.shouldRunInteractionAnimation())
        #expect(policy.shouldPlayFeedback())

        let backgroundBudget = policy.backgroundWorkBudget(
            operation: "reduce-motion-test",
            requestedItemCount: 200
        )
        #expect(backgroundBudget.maximumItemCount == 64)
        #expect(backgroundBudget.allowsExpensiveWork)

        let surfaceGate = policy.surfaceGate(isVisible: true)
        #expect(surfaceGate.allowsInteraction)
        #expect(!surfaceGate.allowsAmbientMotion)
        #expect(surfaceGate.allowsRefresh)
    }

    @Test func lowPowerStillConstrainsWorkSeparatelyFromReduceMotion() {
        let policy = AppWorkloadPolicy(
            lowPowerModeProvider: { true },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            userReducedVisualEffectsProvider: { false },
            thermalStateProvider: { .nominal }
        )

        #expect(policy.interactionMotionBudget() == .efficient)
        #expect(policy.ambientMotionBudget() == .static)
        #expect(policy.refreshBudget() == .throttled)
        #expect(policy.visualEffectsBudget() == .efficient)
        #expect(policy.shouldReduceWork())
        #expect(!policy.shouldPlayFeedback())

        let backgroundBudget = policy.backgroundWorkBudget(
            operation: "low-power-test",
            requestedItemCount: 200
        )
        #expect(backgroundBudget.maximumItemCount == 12)
        #expect(!backgroundBudget.allowsExpensiveWork)
    }

    @Test func reduceMotionComposesWithCriticalThermalState() {
        let policy = AppWorkloadPolicy(
            lowPowerModeProvider: { false },
            reduceMotionProvider: { true },
            userPowerSavingProvider: { false },
            userReducedVisualEffectsProvider: { false },
            thermalStateProvider: { .critical }
        )

        #expect(policy.interactionMotionBudget() == .minimal)
        #expect(policy.ambientMotionBudget() == .static)
        #expect(policy.refreshBudget() == .paused)
        #expect(!policy.shouldPlayFeedback())
    }

    @Test func backgroundWorkBudgetBoundsAndDefersMaintenanceByRuntimeState() {
        let normal = AppWorkloadPolicy(
            lowPowerModeProvider: { false },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { .nominal }
        )
        let normalBudget = normal.backgroundWorkBudget(
            operation: "test",
            requestedItemCount: 200
        )
        #expect(normalBudget.hasWorkCapacity)
        #expect(normalBudget.maximumItemCount == 64)
        #expect(normalBudget.allowsExpensiveWork)

        let lowPower = AppWorkloadPolicy(
            lowPowerModeProvider: { true },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { .nominal }
        )
        let lowPowerBudget = lowPower.backgroundWorkBudget(
            operation: "test",
            requestedItemCount: 200
        )
        #expect(lowPowerBudget.hasWorkCapacity)
        #expect(lowPowerBudget.maximumItemCount == 12)
        #expect(!lowPowerBudget.allowsExpensiveWork)

        let critical = AppWorkloadPolicy(
            lowPowerModeProvider: { false },
            reduceMotionProvider: { false },
            userPowerSavingProvider: { false },
            thermalStateProvider: { .critical }
        )
        let criticalBudget = critical.backgroundWorkBudget(
            operation: "test",
            requestedItemCount: 1
        )
        #expect(!criticalBudget.hasWorkCapacity)
        #expect(criticalBudget.isDeferred)
    }
}

private final class ThermalStateProbe {
    var value = ProcessInfo.ThermalState.nominal
}
