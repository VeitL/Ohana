//
//  AddExpenseSheet+LogicAndReceipts.swift
//  Ohana
//

import SwiftUI
import SwiftData
import Foundation
import PhotosUI
import UniformTypeIdentifiers

extension AddExpenseSheet {
    var moreSummary: String {
        if noteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Calendar.current.isDateInToday(date) ? l.quickExpenseToday : date.formatted(.dateTime.month().day())
        }
        return l.quickExpenseHasNote
    }

    var bottomSaveTitle: String {
        return l.quickExpenseSave
    }

    func configureInitialPayer() {
        guard !humans.isEmpty else {
            selectedPayerId = nil
            return
        }
        if let pid = preselectedPayerId, humans.contains(where: { $0.id.uuidString == pid }) {
            selectedPayerId = pid
        } else {
            let stored = appServices.activeHumanSelection.currentHumanIdRaw
            selectedPayerId = (!stored.isEmpty && humans.contains(where: { $0.id.uuidString == stored }))
                ? stored
                : humans.first?.id.uuidString
        }
    }

    func applyQuickAmount(_ amount: Double) {
        guard !hasSavedMedicalExpense else { return }
        amountInput = amountInputString(amount)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func isQuickAmountSelected(_ amount: Double) -> Bool {
        guard let parsedAmount else { return false }
        return abs(roundedCurrency(parsedAmount) - roundedCurrency(amount)) < 0.01
    }

    func defaultAmounts(for category: ExpenseCategory) -> [Double] {
        switch category {
        case .food: return [20, 50, 100]
        case .treats: return [10, 20, 50]
        case .medical: return [100, 300, 800]
        case .grooming: return [80, 150, 300]
        case .toys: return [20, 50, 100]
        case .insurancePremium: return [60, 120, 300]
        case .other: return [20, 100, 300]
        }
    }

    func appendUniqueAmounts(_ candidates: [Double], into values: inout [Double]) {
        for amount in candidates where amount > 0 {
            let rounded = roundedCurrency(amount)
            if !values.contains(where: { abs($0 - rounded) < 0.01 }) {
                values.append(rounded)
            }
            if values.count >= 4 { return }
        }
    }

    func roundedCurrency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }

    func displayAmount(_ amount: Double) -> String {
        let rounded = roundedCurrency(amount)
        let fractionDigits = abs(rounded - rounded.rounded()) < 0.01 ? 0 : 2
        return CountryDecimalInput.format(rounded, countryCode: appCountry, maxFractionDigits: fractionDigits)
    }

    func amountInputString(_ amount: Double) -> String {
        displayAmount(amount)
    }

    func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        return hex.count == 6 ? Color(hex: hex) : Color.goPrimary
    }

    func receiptLabel(_ receipt: ExpenseReceiptAttachment) -> String {
        let cleaned = receipt.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        return receipt.isImage ? l.quickExpenseImage : l.quickExpenseFile
    }

    func receiptDrafts() -> [ExpenseReceiptAttachmentDraft] {
        receiptAttachments.map {
            ExpenseReceiptAttachmentDraft(data: $0.data, filename: $0.filename, isImage: $0.isImage)
        }
    }

    func presentCamera() {
        guard !hasSavedMedicalExpense else { return }
        inputFocused = false
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }

    func appendReceiptImage(_ image: UIImage) {
        let data = image.jpegData(compressionQuality: 0.85) ?? Data()
        let attachment = ExpenseReceiptAttachment(
            data: data,
            filename: "receipt_\(receiptAttachments.count + 1).jpg",
            isImage: true
        )
        withAnimation(GoMotion.feedback) {
            receiptAttachments.append(attachment)
        }
    }

    @MainActor
    func handleReceiptPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let attachment = ExpenseReceiptAttachment(
                    data: data,
                    filename: "receipt_\(receiptAttachments.count + 1).jpg",
                    isImage: true
                )
                withAnimation(GoMotion.feedback) {
                    receiptAttachments.append(attachment)
                }
            }
        }
        photoPickerItems = []
    }

    func handleReceiptFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        inputFocused = false

        guard let data = SecurityScopedFileDataReader.read(url) else { return }
        let type = UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) ?? false
        let attachment = ExpenseReceiptAttachment(
            data: data,
            filename: url.lastPathComponent,
            isImage: isImage
        )
        withAnimation(GoMotion.feedback) {
            receiptAttachments.append(attachment)
        }
    }

    func receiptDocumentCategory() -> DocumentCategory {
        switch selectedCategory {
        case .medical:
            return .medical
        case .insurancePremium:
            return .insurance
        default:
            return .other
        }
    }

    func receiptDocumentTitle(note: String) -> String {
        if !note.isEmpty { return note }
        return "\(pet.name) · \(l.expenseCategoryTitle(selectedCategory)) \(l.quickExpenseReceipt)"
    }
}
