import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func saveStock() {
        dismissFeedKeyboard()
        guard validateActionHumanSelection() else { return }
        guard let totalGrams = parsePositiveDouble(draftStore.stockWeightText), totalGrams > 0 else {
            draftStore.inputError = l.tr(zh: "请输入购买重量。", en: "Enter stock weight.", de: "Vorratsgewicht eingeben.")
            return
        }
        let previousExpenseId = draftStore.editingFoodRecord.flatMap { FeedStockExpenseLink.expenseId(for: $0) }
        let expenseAmountText = draftStore.stockExpenseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let expenseAmount = expenseAmountText.isEmpty ? nil : parsePositiveDouble(expenseAmountText)
        if !expenseAmountText.isEmpty, (expenseAmount ?? 0) <= 0 {
            draftStore.inputError = l.tr(zh: "请输入有效金额，或留空。", en: "Enter a valid amount or leave it blank.", de: "Gültigen Betrag eingeben oder leer lassen.")
            return
        }
        do {
            let result = try commandExecutor.saveStock(
                pet: pet,
                brand: draftStore.stockBrandText,
                totalGrams: totalGrams,
                purchaseDate: draftStore.stockHasPurchaseDate ? draftStore.stockPurchaseDate : nil,
                openDate: draftStore.stockHasOpenDate ? draftStore.stockOpenDate : nil,
                foodKind: draftStore.selectedStockFoodKind,
                calculationMode: draftStore.stockCalculationMode,
                reminderEnabled: draftStore.stockReminderEnabled,
                reminderAdvanceDays: draftStore.stockReminderAdvanceDays,
                executorId: selectedActionExecutorId,
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
        } catch {
            handleFeedCommandFailure(error, command: .feedStock(petID: pet.id, action: draftStore.editingFoodRecord == nil ? "create" : "update"))
        }
    }

    func configureStockExpenseFields(for record: PetFoodRecord?) {
        draftStore.stockExpensePayerId = currentUserId
        draftStore.stockExpenseAmountText = ""
        draftStore.stockExpenseAmountKeypadVisible = false
        guard let record,
              let expenseId = FeedStockExpenseLink.expenseId(for: record),
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
        do {
            let result = try commandExecutor.saveStockReminderSettings(
                pet: pet,
                enabled: draftStore.stockReminderEnabled,
                advanceDays: draftStore.stockReminderAdvanceDays,
                allEvents: allEvents
            )
            scheduleStockReminders(result.stockReminders)
            triggerToast(l.tr(zh: "余粮提醒已更新", en: "Stock reminder updated", de: "Vorratserinnerung aktualisiert"), tint: stockTint)
        } catch {
            handleFeedCommandFailure(error, command: .feedStock(petID: pet.id, action: "reminder_settings"))
        }
    }

    func correctStock(_ record: PetFoodRecord) {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(draftStore.stockCorrectionText), grams >= 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效余量。", en: "Enter valid remaining stock.", de: "Gültigen Restbestand eingeben.")
            return
        }
        do {
            let result = try commandExecutor.correctStock(
                pet: pet,
                record: record,
                remainingGrams: grams,
                allEvents: allEvents
            )
            reloadFeedSnapshots()
            prepareStockCorrectionText()
            scheduleStockReminders(result.stockReminders)
            triggerToast(l.tr(zh: "余量已修正", en: "Stock corrected", de: "Vorrat korrigiert"), tint: stockTint)
        } catch {
            handleFeedCommandFailure(error, command: .feedStock(petID: pet.id, action: "correct"))
        }
    }

    func beginEditingFeedLog(id: UUID) {
        guard let log = commandExecutor.feedLog(id: id) else {
            draftStore.editingFeedLogId = nil
            triggerToast(l.tr(zh: "记录已不存在", en: "Log no longer exists", de: "Eintrag existiert nicht mehr"), tint: Color.goYellow)
            return
        }
        draftStore.editingFeedLogId = log.id
        draftStore.editFeedLogDate = log.date
        draftStore.editFeedLogGrams = String(format: "%.0f", feedLogDisplayGrams(for: log))
        draftStore.inputError = nil
        openFeedSheet(.editLog)
    }

    func saveFeedLogEdit() {
        dismissFeedKeyboard()
        guard let logId = draftStore.editingFeedLogId else {
            closeActiveFeedSheet()
            return
        }
        guard let grams = parsePositiveDouble(draftStore.editFeedLogGrams), grams >= 0 else {
            draftStore.inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        guard let log = commandExecutor.feedLog(id: logId) else {
            draftStore.editingFeedLogId = nil
            closeActiveFeedSheet()
            triggerToast(l.tr(zh: "记录已不存在", en: "Log no longer exists", de: "Eintrag existiert nicht mehr"), tint: Color.goYellow)
            return
        }
        do {
            let result = try commandExecutor.updateLog(
                log,
                grams: grams,
                date: draftStore.editFeedLogDate,
                pet: pet,
                allEvents: allEvents
            )
            reloadFeedSnapshots()
            scheduleStockReminders(result.stockReminders)
            draftStore.editingFeedLogId = nil
            closeActiveFeedSheet()
            triggerToast(l.tr(zh: "记录已更新", en: "Log updated", de: "Eintrag aktualisiert"), tint: mainFoodTint)
        } catch {
            handleFeedCommandFailure(error, command: .feedLog(petID: pet.id, source: "update"))
        }
    }

    func deleteFeedLog(id: UUID) {
        guard let log = commandExecutor.feedLog(id: id) else {
            triggerToast(l.tr(zh: "记录已不存在", en: "Log no longer exists", de: "Eintrag existiert nicht mehr"), tint: Color.goYellow)
            return
        }
        do {
            let result = try commandExecutor.deleteLog(
                log,
                pet: pet,
                allEvents: allEvents
            )
            if draftStore.editingFeedLogId == id { draftStore.editingFeedLogId = nil }
            reloadFeedSnapshots()
            scheduleStockReminders(result.stockReminders)
            triggerToast(l.tr(zh: "记录已删除", en: "Log deleted", de: "Eintrag gelöscht"), tint: Color.goRed)
        } catch {
            handleFeedCommandFailure(error, command: .feedLog(petID: pet.id, source: "delete"))
        }
    }

    func deleteFoodRecord(_ record: PetFoodRecord) {
        do {
            let result = try commandExecutor.deleteFoodRecord(
                record,
                pet: pet,
                allEvents: allEvents
            )
            if draftStore.editingFoodRecord?.id == record.id { draftStore.editingFoodRecord = nil }
            reloadFeedSnapshots()
            prepareStockCorrectionText()
            scheduleStockReminders(result.stockReminders)
            triggerToast(l.tr(zh: "补粮记录已删除", en: "Stock record deleted", de: "Vorratseintrag gelöscht"), tint: Color.goRed)
        } catch {
            handleFeedCommandFailure(error, command: .feedStock(petID: pet.id, action: "delete_record"))
        }
    }
}
