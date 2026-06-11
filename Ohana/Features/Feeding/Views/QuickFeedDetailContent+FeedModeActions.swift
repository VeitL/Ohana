import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func savePlan(_ kind: FeedRuleKind) {
        guard !draftStore.isSavingFeedPlan else { return }
        dismissFeedKeyboard()
        let normalizedMeals = FeedPlanDraft.normalizedMeals(draftStore.planMeals, count: draftStore.planCount)
        guard normalizedMeals.allSatisfy({ $0.grams > 0 }) else {
            draftStore.inputError = l.tr(zh: "请为每餐填写克数。", en: "Enter grams for every meal.", de: "Gramm für jede Mahlzeit eingeben.")
            return
        }
        let draft = FeedPlanDraft(kind: kind, meals: normalizedMeals)
        let targets = selectedPlanTargets
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        let savingTint = kind == .manualReminder ? Color.goPurple : Color.goTeal
        SharedPetSelectionMemory.saveSelection(
            Set(targets.map(\.id)),
            sourcePet: pet,
            scope: "feeding.plan.\(kind.rawValue)",
            candidates: sameSpeciesFeedPets
        )

        draftStore.inputError = nil
        draftStore.isSavingFeedPlan = true
        feedPlanSaveTask?.cancel()
        collapseEmbeddedPanel()
        closeActiveFeedSheet()
        performFeedModeUpdatesWithoutAnimation {
            feedHomeController.setModeImmediately(targetMode, pet: pet)
        }
        UISelectionFeedbackGenerator().selectionChanged()

        feedPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: feedPlanSaveDelayMilliseconds) {
            let sourceEvents = targets.count > 1 ? latestAllEvents() : allEvents
            let result = FeedHomePerformance.measure("plan.save") {
                commandExecutor.savePlan(
                    pet: pet,
                    targets: targets,
                    kind: kind,
                    draft: draft,
                    allEvents: sourceEvents
                )
            }

            if kind == .manualReminder {
                scheduleReminders(result.planReminders)
            }
            scheduleStockReminders(result.stockReminders)
            var refreshRequest: QuickFeedRefreshRequest = [
                .reloadSnapshots,
                .syncDisplayedMode,
                .forceDisplayedMode
            ]
            if kind == .manualReminder {
                refreshRequest.insert(.ensurePlanReminders)
            }
            scheduleDeferredFeedRefresh(refreshRequest, milliseconds: feedPlanPostSaveRefreshDelayMilliseconds)
            triggerToast(feedPlanSavedMessage(kind: kind, targetCount: result.targetCount), tint: savingTint)
            draftStore.isSavingFeedPlan = false
            feedPlanSaveTask = nil
        }
    }

    var feedPlanSaveDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    var feedPlanPostSaveRefreshDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 110 : 40
    }

    func feedPlanSavedMessage(kind: FeedRuleKind, targetCount: Int) -> String {
        if targetCount > 1 {
            return kind == .manualReminder
                ? l.tr(zh: "共同计划已保存 · \(targetCount)只", en: "Shared plan saved · \(targetCount)", de: "Gemeinsamer Plan · \(targetCount)")
                : l.tr(zh: "共同自动记录已保存 · \(targetCount)只", en: "Shared auto saved · \(targetCount)", de: "Gemeinsame Auto-Regel · \(targetCount)")
        }
        return kind == .manualReminder
            ? l.tr(zh: "喂食计划已保存", en: "Plan saved", de: "Plan gespeichert")
            : l.tr(zh: "自动记录已保存", en: "Auto feeder saved", de: "Automat gespeichert")
    }

    func switchToManualFeedMode() {
        guard activeFeedingMode != .manual else {
            closeActiveFeedSheet()
            return
        }
        commandExecutor.setFeedMode(.manual, pet: pet)
        beginFeedModeVisualTransition(to: .manual) {
            scheduleSettledFeedModeMaintenance(for: .manual)
        }
        closeActiveFeedSheet()
    }

    func activateExistingFeedRuleMode(_ kind: FeedRuleKind) {
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        guard activeFeedingMode != targetMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        commandExecutor.setFeedMode(targetMode, pet: pet)
        beginFeedModeVisualTransition(to: targetMode) {
            scheduleSettledFeedModeMaintenance(for: targetMode)
        }
        closeActiveFeedSheet()
    }

    func eventsReplacingFeedRules(kind: FeedRuleKind, with replacement: [Event]) -> [Event] {
        allEvents.filter { event in
            switch kind {
            case .manualReminder:
                !FeedRuleMetadata.isManualReminderEvent(event, pet: pet)
            case .autoFeeder:
                !FeedRuleMetadata.isAutoFeederEvent(event, pet: pet)
            }
        } + replacement
    }

    func setActiveFeedMode(_ mode: FeedOperatingMode) {
        performFeedModeUpdatesWithoutAnimation {
            feedHomeController.setModeImmediately(mode, pet: pet)
            commitFeedModeSideEffects(mode)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func commitFeedModeSideEffects(_ mode: FeedOperatingMode) {
        commandExecutor.setFeedMode(mode, pet: pet)
    }

    func beginFeedModeVisualTransition(
        to targetMode: FeedOperatingMode,
        commitAfterAnimation: @escaping @MainActor () -> Void
    ) {
        let fromMode = activeFeedingMode
        guard fromMode != targetMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        feedModeTransitionTask?.cancel()
        feedModeMaintenanceTask?.cancel()
        guard let transitionID = feedHomeController.beginOptimisticModeTransition(to: targetMode, pet: pet) else { return }

        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(feedModeTransitionAnimation) {
            feedHomeController.updateModeTransition(id: transitionID, progress: 1)
        }

        scheduleFeedModeSideEffectsAfterAnimation(transitionID: transitionID, commit: commitAfterAnimation)
    }

    var feedModeTransitionAnimation: Animation {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? GoMotion.page : GoMotion.reduced
    }

    var feedModeTransitionDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 340 : 130
    }

    func scheduleFeedModeSideEffectsAfterAnimation(
        transitionID: UUID,
        commit: @escaping @MainActor () -> Void
    ) {
        feedModeTransitionTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: feedModeTransitionDelayMilliseconds)
            guard !Task.isCancelled,
                  feedHomeController.modeTransition?.id == transitionID else { return }

            performFeedModeUpdatesWithoutAnimation {
                FeedHomePerformance.measure("mode.sideEffects") {
                    commit()
                }
            }

            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled,
                  feedHomeController.modeTransition?.id == transitionID else { return }

            performFeedModeUpdatesWithoutAnimation {
                feedHomeController.finishModeTransition(id: transitionID)
            }
            scheduleDeferredFeedRefresh([.reloadSnapshots])
            feedModeTransitionTask = nil
        }
    }

    func scheduleSettledFeedModeMaintenance(for mode: FeedOperatingMode) {
        feedModeMaintenanceTask?.cancel()
        feedModeMaintenanceTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: feedModeMaintenanceDelayMilliseconds)
            guard !Task.isCancelled,
                  feedHomeController.modeTransition == nil,
                  activeFeedingMode == mode,
                  !pet.hasPassedAway
            else { return }

            performFeedModeUpdatesWithoutAnimation {
                FeedHomePerformance.measure("mode.maintenance") {
                    runSettledFeedModeMaintenance(for: mode)
                }
            }
            scheduleDeferredFeedRefresh([.reloadSnapshots])
            feedModeMaintenanceTask = nil
        }
    }

    var feedModeMaintenanceDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 850 : 300
    }

    func runSettledFeedModeMaintenance(for mode: FeedOperatingMode) {
        let currentEvents = latestAllEvents()
        switch mode {
        case .manual:
            commandExecutor.switchToManual(
                pet: pet,
                allEvents: currentEvents
            )
        case .manualReminder:
            let result = commandExecutor.activateExistingRule(
                pet: pet,
                kind: .manualReminder,
                allEvents: currentEvents
            )
            switch result {
            case let .switched(reminders):
                scheduleReminders(reminders)
            case .missingPlan:
                commandExecutor.setFeedMode(.manual, pet: pet)
                feedHomeController.setModeImmediately(.manual, pet: pet)
            }
        case .autoFeeder:
            let result = commandExecutor.activateExistingRule(
                pet: pet,
                kind: .autoFeeder,
                allEvents: currentEvents
            )
            if case .missingPlan = result {
                commandExecutor.setFeedMode(.manual, pet: pet)
                feedHomeController.setModeImmediately(.manual, pet: pet)
            }
        }
    }

    func performFeedModeUpdatesWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    func latestAllEvents() -> [Event] {
        commandExecutor.latestAllEvents(fallback: allEvents)
    }

    func deletePlan(_ kind: FeedRuleKind) {
        guard !draftStore.isSavingFeedPlan else { return }
        draftStore.isSavingFeedPlan = true
        feedPlanSaveTask?.cancel()
        collapseEmbeddedPanel()
        closeActiveFeedSheet()
        UISelectionFeedbackGenerator().selectionChanged()

        feedPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: feedPlanSaveDelayMilliseconds) {
            let result = FeedHomePerformance.measure("plan.delete") {
                commandExecutor.deletePlan(
                    pet: pet,
                    kind: kind,
                    activeMode: activeFeedingMode,
                    allEvents: allEvents
                )
            }
            scheduleStockReminders(result.stockReminders)
            if result.shouldSwitchToManual {
                setActiveFeedMode(.manual)
            }
            scheduleDeferredFeedRefresh([.reloadSnapshots, .syncDisplayedMode])
            triggerToast(l.tr(zh: "计划已删除", en: "Plan deleted", de: "Plan gelöscht"), tint: Color.goRed)
            draftStore.isSavingFeedPlan = false
            feedPlanSaveTask = nil
        }
    }
}
