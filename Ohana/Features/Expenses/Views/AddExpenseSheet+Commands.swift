//
//  AddExpenseSheet+Commands.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension AddExpenseSheet {
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        commandQueue.enqueue(command) {
            let executor = DashboardRecordCommandExecutor(context: modelContext, services: appServices)
            let coconutDelta: Int
            let savedLogID: UUID?
            if savedTargets.count > 1 {
                let result = executor.recordSharedPetExpense(
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
                coconutDelta = result.coconutDelta
                savedLogID = result.expenseLogIDs.first
            } else {
                let result = executor.recordPetExpense(
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
