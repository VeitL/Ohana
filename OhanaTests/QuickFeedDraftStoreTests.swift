import Foundation
@testable import Ohana
import Testing

@MainActor
struct QuickFeedDraftStoreTests {
    @Test func resetTreatDraftClearsErrorAndInput() {
        let store = QuickFeedDraftStore()
        store.inputError = "bad"
        store.selectedTreatKind = .jerky
        store.treatGramsText = "12"

        store.resetTreatDraft()

        #expect(store.inputError == nil)
        #expect(store.selectedTreatKind == .lickable)
        #expect(store.treatGramsText.isEmpty)
    }

    @Test func resetStockExpenseUsesExpenseWhenPresent() {
        let store = QuickFeedDraftStore()
        let pet = Pet(name: "Momo", species: "猫")
        let expense = PetExpenseLog(amount: 19.5, category: .food, pet: pet, executorId: "human-1")

        store.resetStockExpense(currentUserId: "human-2", expense: expense)

        #expect(store.stockExpensePayerId == "human-1")
        #expect(store.stockExpenseAmountText == "19.50")
        #expect(store.stockExpenseAmountKeypadVisible == false)
    }

    @Test func resetNewStockDraftClearsEditingState() {
        let store = QuickFeedDraftStore()
        let pet = Pet(name: "Momo", species: "猫")
        store.editingFoodRecord = PetFoodRecord(brand: "Old", totalGrams: 1000, startDate: Date(), pet: pet)
        store.stockBrandText = "Old"
        store.stockWeightText = "1000"
        store.stockExpenseAmountKeypadVisible = true

        store.resetNewStockDraft(foodKind: .wet, currentUserId: "human-1")

        #expect(store.editingFoodRecord == nil)
        #expect(store.selectedStockFoodKind == .wet)
        #expect(store.stockBrandText.isEmpty)
        #expect(store.stockWeightText.isEmpty)
        #expect(store.stockExpensePayerId == "human-1")
        #expect(store.stockExpenseAmountKeypadVisible == false)
    }
}
