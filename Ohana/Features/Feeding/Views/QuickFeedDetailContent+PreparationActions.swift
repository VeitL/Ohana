import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func syncDisplayedFeedMode(animated: Bool = false, force: Bool = false) {
        guard force || feedHomeController.modeTransition == nil else { return }
        let resolvedMode = FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: clockTick)
        feedHomeController.syncDisplayedMode(resolvedMode, pet: pet, animated: animated, force: force)
    }

    func refreshFeedHomeSnapshot(force: Bool = false) {
        feedHomeController.rebuild(input: feedHomeSnapshotInput, force: force)
    }

    func bootstrap() {
        feedHomeController.setAuxiliaryReady(false)
        if draftStore.manualGramsText.isEmpty, let grams = currentPortionAmount {
            draftStore.manualGramsText = String(format: "%.0f", grams)
        }
        draftStore.stockBrandText = pet.foodBrand
        draftStore.stockWeightText = pet.restockWeight > 0 ? String(format: "%.0f", pet.restockWeight * 1000) : ""
        draftStore.stockHasPurchaseDate = false
        draftStore.stockPurchaseDate = Date()
        draftStore.stockHasOpenDate = pet.restockDate != nil
        draftStore.stockOpenDate = pet.restockDate ?? Date()
        draftStore.stockCalculationMode = defaultStockCalculationMode
        configureStockExpenseFields(for: nil)
        draftStore.stockReminderEnabled = pet.foodReminderEnabled
        draftStore.stockReminderAdvanceDays = pet.foodReminderAdvanceDays
        reloadFeedSnapshots()
        syncDisplayedFeedMode()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            feedHomeController.setAuxiliaryReady(true, animated: true)
        }

        if !didScheduleBootstrapMaintenance {
            didScheduleBootstrapMaintenance = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !pet.hasPassedAway else { return }
                materializeAutoFeedLogs()
                ensureUpcomingPlanReminders()
                reloadFeedSnapshots()
            }
        }

        if opensManualSheetOnAppear, !didApplyInitialSheet {
            didApplyInitialSheet = true
            Task { @MainActor in
                prepareManualSheet(settingsOnly: pet.dailyPortionGrams <= 0)
                openFeedSheet(.manual)
            }
        }
    }

    func prepareManualSheet(settingsOnly: Bool = false) {
        draftStore.inputError = nil
        draftStore.manualFeedSheetMode = settingsOnly ? .settingsOnly : .log
        draftStore.manualFoodKindDraft = pet.mainFoodKind
        draftStore.selectedSharedFeedPetIds = settingsOnly
            ? Set([pet.id])
            : SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "feeding.manual",
                candidates: sameSpeciesFeedPets,
                defaultToAll: true
            )
        if let grams = currentPortionAmount ?? (defaultFeedGrams > 0 ? defaultFeedGrams : nil) {
            draftStore.manualGramsText = String(format: "%.0f", grams)
        } else {
            draftStore.manualGramsText = "50"
        }
        draftStore.manualDefaultEnabled = pet.dailyPortionGrams > 0 || !settingsOnly
        draftStore.saveManualAsDefault = !settingsOnly
    }

    func prepareTreatSheet() {
        draftStore.inputError = nil
        draftStore.selectedTreatKind = .lickable
        draftStore.treatGramsText = ""
    }

    func prepareStockSheet(foodKind: FeedFoodKind = .dry, record: PetFoodRecord? = nil) {
        draftStore.inputError = nil
        draftStore.editingFoodRecord = record
        draftStore.selectedStockFoodKind = record?.foodKind ?? foodKind
        if let record {
            draftStore.stockBrandText = record.brand
            draftStore.stockWeightText = String(format: "%.0f", stockSnapshot.totalGrams(for: record))
            draftStore.stockHasPurchaseDate = record.purchaseDate != nil
            draftStore.stockPurchaseDate = record.purchaseDate ?? Date()
            draftStore.stockHasOpenDate = true
            draftStore.stockOpenDate = record.startDate
            draftStore.stockCalculationMode = FeedStockRecordMetadata.calculationMode(for: record)
            configureStockExpenseFields(for: record)
        } else {
            draftStore.stockBrandText = ""
            draftStore.stockWeightText = ""
            draftStore.stockHasPurchaseDate = false
            draftStore.stockPurchaseDate = Date()
            draftStore.stockHasOpenDate = false
            draftStore.stockOpenDate = Date()
            draftStore.stockCalculationMode = defaultStockCalculationMode
            configureStockExpenseFields(for: nil)
        }
        draftStore.stockReminderEnabled = pet.foodReminderEnabled
        draftStore.stockReminderAdvanceDays = pet.foodReminderAdvanceDays
    }

    func prepareStockManageSheet() {
        draftStore.inputError = nil
        draftStore.editingFoodRecord = nil
        draftStore.stockReminderEnabled = pet.foodReminderEnabled
        draftStore.stockReminderAdvanceDays = pet.foodReminderAdvanceDays
        prepareStockCorrectionText()
    }

    var defaultStockCalculationMode: FeedStockCalculationMode {
        activeFeedingMode == .autoFeeder ? .autoFeeder : .manualOrPlan
    }

    func prepareStockCorrectionText() {
        guard let record = managedActiveStockRecord else {
            draftStore.stockCorrectionText = ""
            return
        }
        let snapshot = stockSnapshot.stock(for: record.foodKind)
        draftStore.stockCorrectionText = snapshot.remainingGrams > 0 ? String(format: "%.0f", snapshot.remainingGrams) : ""
    }

    func openPlanEditor(_ kind: FeedRuleKind) {
        draftStore.inputError = nil
        preparePlanEditorDraft(kind)
        openFeedSheet(.plan(kind))
    }

    func preparePlanEditorDraft(_ kind: FeedRuleKind) {
        let events = FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents)
        draftStore.selectedSharedPlanPetIds = SharedPetSelectionMemory.restoredSelection(
            sourcePet: pet,
            scope: "feeding.plan.\(kind.rawValue)",
            candidates: sameSpeciesFeedPets,
            defaultToAll: true
        )
        if events.isEmpty {
            draftStore.planCount = 3
            let grams = currentPortionAmount ?? 50
            draftStore.planTimes = FeedPlanDraft.suggestedTimes(for: draftStore.planCount)
            draftStore.planMeals = draftStore.planTimes.map { FeedPlanMealDraft(time: $0, foodKind: pet.mainFoodKind, grams: grams) }
        } else {
            draftStore.planCount = min(max(events.count, 1), 6)
            let grams = FeedRuleMetadata.amountGrams(from: events.first!, fallback: currentPortionAmount ?? 50)
            draftStore.planTimes = FeedPlanDraft.normalizedTimes(events.map(\.startDate), count: draftStore.planCount)
            draftStore.planMeals = FeedPlanDraft.normalizedMeals(
                events.map { FeedPlanMealDraft(time: $0.startDate, foodKind: $0.foodKind, grams: FeedRuleMetadata.amountGrams(from: $0, fallback: grams)) },
                count: draftStore.planCount
            )
        }
    }

    func syncPlanTimesCount(_ count: Int) {
        draftStore.planTimes = FeedPlanDraft.normalizedTimes(draftStore.planTimes, count: count)
        draftStore.planMeals = FeedPlanDraft.normalizedMeals(draftStore.planMeals, count: count)
    }
}
