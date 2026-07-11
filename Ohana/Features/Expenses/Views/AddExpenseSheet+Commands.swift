//
//  AddExpenseSheet+Commands.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension AddExpenseSheetContent {
    func saveExpense() {
        guard canSave, let amount = parsedAmount, amount > 0 else { return }
        isSaving = true
        inputFocused = false
        GoKeyboard.dismiss()

        let payerId = selectedPayerId.flatMap { id in
            humans.contains(where: { $0.id.uuidString == id }) ? id : nil
        }
        let cleanNote = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedDate = date
        let savedCategory = selectedCategory
        let savedReceiptTitle = receiptDocumentTitle(note: cleanNote)
        let savedReceiptCategory = receiptDocumentCategory()
        let savedReceiptDrafts = receiptDrafts()
        let hasActiveInsurance = !activeInsurances.isEmpty
        let savedTargets = selectedExpenseTargets
        let command = DomainCommand.expenseEntry(entityID: pet.id, entityKind: EntityKind.pet.rawValue)

        commandQueue.enqueue(command) {
            let executor = DashboardRecordCommandExecutor(context: modelContext, services: appServices)
            let coconutDelta: Int
            let savedLogID: UUID?
            do {
                if savedTargets.count > 1 {
                    let result = try executor.recordSharedPetExpense(
                        sourcePet: pet,
                        targets: savedTargets,
                        amount: amount,
                        date: savedDate,
                        category: savedCategory,
                        note: cleanNote,
                        executorId: payerId,
                        source: .detail,
                        command: command,
                        revisionNote: "dashboard.expense.sharedEntry"
                    )
                    guard result.didWriteFact else {
                        isSaving = false
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        return
                    }
                    coconutDelta = result.coconutDelta
                    savedLogID = result.expenseLogIDs.first
                } else {
                    let result = try executor.recordPetExpense(
                        pet: pet,
                        amount: amount,
                        date: savedDate,
                        category: savedCategory,
                        note: cleanNote,
                        executorId: payerId,
                        source: .detail,
                        receiptTitle: savedReceiptTitle,
                        receiptCategory: savedReceiptCategory,
                        receiptAttachments: savedReceiptDrafts,
                        command: command,
                        revisionNote: "dashboard.expense.entry"
                    )
                    coconutDelta = result.coconutDelta
                    savedLogID = result.logID
                }
            } catch {
                saveErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? l.tr(
                        zh: "费用保存失败，请检查金额后重试。",
                        en: "Could not save the expense. Check the amount and try again.",
                        de: "Die Ausgabe konnte nicht gespeichert werden. Prüfe den Betrag und versuche es erneut."
                    )
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            SharedPetSelectionMemory.saveSelection(
                Set(savedTargets.map(\.id)),
                sourcePet: pet,
                scope: "expense.shared",
                candidates: sameSpeciesExpensePets
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved?()
            onRewarded?(coconutDelta)

            if savedTargets.count == 1, savedCategory == .medical, hasActiveInsurance, let savedLogID {
                savedExpenseId = savedLogID.uuidString
                isSaving = false
            } else {
                closeSheet()
            }
        }
    }

    func closeSheet() {
        if let onDismiss {
            guard !isClosing else { return }
            isClosing = true
            withAnimation(popupAnimation) {
                popupVisible = false
                popupDragOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                onDismiss()
            }
        } else {
            dismiss()
        }
    }
}
