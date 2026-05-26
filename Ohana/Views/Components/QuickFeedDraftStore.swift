//
//  QuickFeedDraftStore.swift
//  Ohana
//
//  Mutable draft state for QuickFeed forms and overview filters.
//

import Combine
import Foundation

@MainActor
final class QuickFeedDraftStore: ObservableObject {
    @Published var overviewRange: FeedOverviewRange = .days7
    @Published var feedPlanCalendarMonth = Date()
    @Published var feedPlanCalendarSelectedDate = Date()
    @Published var showFeedPlanMonthPicker = false
    @Published var feedPlanCalendarMonthSlideDirection = 1

    @Published var selectedStockFoodKind: FeedFoodKind = .dry
    @Published var selectedTreatKind: FeedTreatKind = .lickable
    @Published var selectedTreatOverviewKind: FeedTreatKind?

    @Published var manualFeedSheetMode: ManualFeedSheetMode = .log
    @Published var manualFoodKindDraft: FeedFoodKind = .dry
    @Published var manualGramsText = ""
    @Published var saveManualAsDefault = true
    @Published var selectedSharedFeedPetIds: Set<UUID> = []
    @Published var selectedSharedPlanPetIds: Set<UUID> = []

    @Published var treatGramsText = ""

    @Published var planCount = 3
    @Published var planTimes: [Date] = []
    @Published var planMeals: [FeedPlanMealDraft] = []

    @Published var stockBrandText = ""
    @Published var stockWeightText = ""
    @Published var stockPurchaseDate = Date()
    @Published var stockOpenDate = Date()
    @Published var stockHasPurchaseDate = false
    @Published var stockHasOpenDate = false
    @Published var stockExpenseAmountText = ""
    @Published var stockExpensePayerId: String?
    @Published var stockExpenseAmountKeypadVisible = false
    @Published var stockReminderEnabled = false
    @Published var stockReminderAdvanceDays = 7
    @Published var editingFoodRecord: PetFoodRecord?
    @Published var stockCorrectionText = ""

    @Published var inputError: String?
    @Published var editingFeedLog: PetCareLog?
    @Published var editFeedLogGrams = ""
    @Published var editFeedLogDate = Date()

    func resetTreatDraft() {
        inputError = nil
        selectedTreatKind = .lickable
        treatGramsText = ""
    }

    func resetStockExpense(currentUserId: String?, expense: PetExpenseLog?) {
        stockExpensePayerId = expense?.executorId ?? currentUserId
        stockExpenseAmountText = expense.map { String(format: "%.2f", $0.amount) } ?? ""
        stockExpenseAmountKeypadVisible = false
    }

    func resetNewStockDraft(foodKind: FeedFoodKind, currentUserId: String?) {
        inputError = nil
        editingFoodRecord = nil
        selectedStockFoodKind = foodKind
        stockBrandText = ""
        stockWeightText = ""
        stockHasPurchaseDate = false
        stockPurchaseDate = Date()
        stockHasOpenDate = false
        stockOpenDate = Date()
        resetStockExpense(currentUserId: currentUserId, expense: nil)
    }
}
