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
        guard !didSaveExpense, !isSaving, canSave,
              let amount = parsedAmount,
              amount > 0,
              let payerContributions = payerContributionsForSave
        else {
            return
        }
        isSaving = true
        inputFocused = false
        GoKeyboard.dismiss()

        let payerId = selectedPayerId.flatMap { id in
            activeExpenseHumans.contains(where: { $0.id.uuidString == id }) ? id : nil
        }
        let cleanNote = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let recorderId = selectedRecorderID?.uuidString
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
            let reference: PetRecordReference?
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
                        recordedByHumanId: recorderId,
                        payerContributions: payerContributions,
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
                    reference = result.recordReference(for: pet.id, ids: result.expenseLogIDs, filter: .expense)
                    savedLogID = reference?.recordID
                } else {
                    let result = try executor.recordPetExpense(
                        pet: pet,
                        amount: amount,
                        date: savedDate,
                        category: savedCategory,
                        note: cleanNote,
                        executorId: payerId,
                        recordedByHumanId: recorderId,
                        payerContributions: payerContributions,
                        source: .detail,
                        receiptTitle: savedReceiptTitle,
                        receiptCategory: savedReceiptCategory,
                        receiptAttachments: savedReceiptDrafts,
                        command: command,
                        revisionNote: "dashboard.expense.entry"
                    )
                    coconutDelta = result.coconutDelta
                    savedLogID = result.logID
                    reference = PetRecordReference(petID: pet.id, recordID: result.logID, filter: .expense)
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
            savedRecord = reference
            didSaveExpense = true
            selectedSharedExpensePetIds = [pet.id]
            isSaving = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved?()
            onRewarded?(coconutDelta)

            if savedTargets.count == 1, savedCategory == .medical, hasActiveInsurance, let savedLogID {
                savedExpenseId = savedLogID.uuidString
                isSaving = false
            }
        }
    }

    func closeSheet() {
        if let onDismiss {
            guard !isClosing else { return }
            isClosing = true
            onDismiss()
        } else {
            dismiss()
        }
    }
}
