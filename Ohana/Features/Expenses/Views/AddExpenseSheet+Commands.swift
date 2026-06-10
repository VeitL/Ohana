//
//  AddExpenseSheet+Commands.swift
//  Ohana
//

import SwiftUI
import SwiftData
import Foundation
import PhotosUI
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
        let command = DomainCommand.expenseEntry(entityID: pet.id, entityKind: EntityKind.pet.rawValue)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        commandQueue.enqueue(command) {
            let result = DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordPetExpense(
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
            onSaved?()
            onRewarded?(result.coconutDelta)

            if savedCategory == .medical, hasActiveInsurance {
                savedExpenseId = result.logID.uuidString
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
