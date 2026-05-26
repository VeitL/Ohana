import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func saveStock() {
        dismissFeedKeyboard()
        guard let totalGrams = parsePositiveDouble(draftStore.stockWeightText), totalGrams > 0 else {
            draftStore.inputError = l.tr(zh: "请输入购买重量。", en: "Enter stock weight.", de: "Vorratsgewicht eingeben.")
            return
        }
        let previousExpenseId = draftStore.editingFoodRecord.flatMap { FeedStockExpenseLink.expenseId(from: $0.notes) }
        let expenseAmountText = draftStore.stockExpenseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let expenseAmount = expenseAmountText.isEmpty ? nil : parsePositiveDouble(expenseAmountText)
        if !expenseAmountText.isEmpty, (expenseAmount ?? 0) <= 0 {
            draftStore.inputError = l.tr(zh: "请输入有效金额，或留空。", en: "Enter a valid amount or leave it blank.", de: "Gültigen Betrag eingeben oder leer lassen.")
            return
        }
        let result = commandExecutor.saveStock(
            pet: pet,
            brand: draftStore.stockBrandText,
            totalGrams: totalGrams,
            purchaseDate: draftStore.stockHasPurchaseDate ? draftStore.stockPurchaseDate : nil,
            openDate: draftStore.stockHasOpenDate ? draftStore.stockOpenDate : nil,
            foodKind: draftStore.selectedStockFoodKind,
            reminderEnabled: draftStore.stockReminderEnabled,
            reminderAdvanceDays: draftStore.stockReminderAdvanceDays,
            executorId: currentUserId,
            allEvents: allEvents,
            recordToUpdate: draftStore.editingFoodRecord,
            previousExpenseId: previousExpenseId,
            expenseAmount: expenseAmount,
            expensePayerId: draftStore.stockExpensePayerId,
            expenseDate: draftStore.stockHasPurchaseDate ? draftStore.stockPurchaseDate : Date(),
            expenseNote: stockExpenseNote()
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        draftStore.editingFoodRecord = nil
        dismissInlineFeedSheet()
        triggerToast(l.tr(zh: "余粮已更新", en: "Stock updated", de: "Vorrat aktualisiert"), tint: stockTint)
    }

    func configureStockExpenseFields(for record: PetFoodRecord?) {
        draftStore.stockExpensePayerId = currentUserId
        draftStore.stockExpenseAmountText = ""
        draftStore.stockExpenseAmountKeypadVisible = false
        guard let record,
              let expenseId = FeedStockExpenseLink.expenseId(from: record.notes),
              let expense = commandExecutor.stockExpense(id: expenseId)
        else { return }
        draftStore.stockExpensePayerId = expense.executorId
        draftStore.stockExpenseAmountText = String(format: "%.2f", expense.amount)
    }

    func stockExpenseNote() -> String {
        let cleanBrand = draftStore.stockBrandText.trimmingCharacters(in: .whitespacesAndNewlines)
        let kindTitle = draftStore.selectedStockFoodKind.title(l)
        let note = cleanBrand.isEmpty
            ? l.tr(zh: "\(pet.name) \(kindTitle)补粮", en: "\(pet.name) \(kindTitle) restock", de: "\(pet.name) \(kindTitle) Nachfüllung")
            : l.tr(zh: "\(pet.name) \(kindTitle)补粮 · \(cleanBrand)", en: "\(pet.name) \(kindTitle) restock · \(cleanBrand)", de: "\(pet.name) \(kindTitle) Nachfüllung · \(cleanBrand)")
        return note
    }

    func saveStockReminderSettings() {
        let result = commandExecutor.saveStockReminderSettings(
            pet: pet,
            enabled: draftStore.stockReminderEnabled,
            advanceDays: draftStore.stockReminderAdvanceDays,
            allEvents: allEvents
        )
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "余粮提醒已更新", en: "Stock reminder updated", de: "Vorratserinnerung aktualisiert"), tint: stockTint)
    }

    func correctStock(_ record: PetFoodRecord) {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(draftStore.stockCorrectionText), grams >= 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效余量。", en: "Enter valid remaining stock.", de: "Gültigen Restbestand eingeben.")
            return
        }
        let result = commandExecutor.correctStock(
            pet: pet,
            record: record,
            remainingGrams: grams,
            allEvents: allEvents
        )
        reloadFeedSnapshots()
        prepareStockCorrectionText()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "余量已修正", en: "Stock corrected", de: "Vorrat korrigiert"), tint: stockTint)
    }

    func beginEditingFeedLog(_ log: PetCareLog) {
        draftStore.editingFeedLog = log
        draftStore.editFeedLogDate = log.date
        draftStore.editFeedLogGrams = String(format: "%.0f", feedLogDisplayGrams(for: log))
        draftStore.inputError = nil
        openFeedSheet(.editLog)
    }

    func saveFeedLogEdit() {
        dismissFeedKeyboard()
        guard let log = draftStore.editingFeedLog else {
            closeActiveFeedSheet()
            return
        }
        guard let grams = parsePositiveDouble(draftStore.editFeedLogGrams), grams >= 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        let result = commandExecutor.updateLog(
            log,
            grams: grams,
            date: draftStore.editFeedLogDate,
            pet: pet,
            allEvents: allEvents
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        closeActiveFeedSheet()
        triggerToast(l.tr(zh: "记录已更新", en: "Log updated", de: "Eintrag aktualisiert"), tint: mainFoodTint)
    }

    func deleteFeedLog(_ log: PetCareLog) {
        if draftStore.editingFeedLog?.id == log.id { draftStore.editingFeedLog = nil }
        let result = commandExecutor.deleteLog(
            log,
            pet: pet,
            allEvents: allEvents
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "记录已删除", en: "Log deleted", de: "Eintrag gelöscht"), tint: Color.goRed)
    }

    func deleteFoodRecord(_ record: PetFoodRecord) {
        if draftStore.editingFoodRecord?.id == record.id { draftStore.editingFoodRecord = nil }
        let result = commandExecutor.deleteFoodRecord(
            record,
            pet: pet,
            allEvents: allEvents
        )
        reloadFeedSnapshots()
        prepareStockCorrectionText()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "补粮记录已删除", en: "Stock record deleted", de: "Vorratseintrag gelöscht"), tint: Color.goRed)
    }
}
