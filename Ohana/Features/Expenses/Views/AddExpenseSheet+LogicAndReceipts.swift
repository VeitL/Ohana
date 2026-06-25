//
//  AddExpenseSheet+LogicAndReceipts.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension AddExpenseSheetContent {
    var moreSummary: String {
        if noteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Calendar.current.isDateInToday(date) ? l.quickExpenseToday : date.formatted(.dateTime.month().day())
        }
        return l.quickExpenseHasNote
    }

    var bottomSaveTitle: String {
        l.quickExpenseSave
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
        ExpenseAmountPresets.defaults(for: category)
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
        ExpenseAmountPresets.roundedCurrency(amount)
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
        let data = AttachmentPrivacySanitizer.sanitizedImageData(
            from: image,
            compressionQuality: 0.85
        ) ?? Data()
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
                let filename = "receipt_\(receiptAttachments.count + 1).jpg"
                let attachment = ExpenseReceiptAttachment(
                    data: AttachmentPrivacySanitizer.sanitizedData(
                        data,
                        filename: filename,
                        isImage: true
                    ),
                    filename: filename,
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
        guard case let .success(url) = result else { return }
        inputFocused = false

        guard let data = SecurityScopedFileDataReader.read(url) else { return }
        let type = UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) ?? false
        let attachment = ExpenseReceiptAttachment(
            data: AttachmentPrivacySanitizer.sanitizedData(
                data,
                filename: url.lastPathComponent,
                isImage: isImage
            ),
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
            .medical
        case .insurancePremium:
            .insurance
        default:
            .other
        }
    }

    func receiptDocumentTitle(note: String) -> String {
        if !note.isEmpty { return note }
        return "\(pet.name) · \(l.expenseCategoryTitle(selectedCategory)) \(l.quickExpenseReceipt)"
    }
}
