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
        guard !activeExpenseHumans.isEmpty else {
            selectedPayerId = nil
            selectedPayerIDs = []
            payerAmountInputs = [:]
            return
        }
        let primaryID: String
        if let pid = preselectedPayerId,
           activeExpenseHumans.contains(where: { $0.id.uuidString == pid }) {
            primaryID = pid
        } else {
            let stored = appServices.activeHumanSelection.currentHumanIdRaw
            primaryID = (!stored.isEmpty && activeExpenseHumans.contains(where: { $0.id.uuidString == stored }))
                ? stored
                : activeExpenseHumans[0].id.uuidString
        }
        selectedPayerId = primaryID
        selectedPayerIDs = activeExpenseHumans.count > 1
            ? [primaryID] + activeExpenseHumans.map(\.id.uuidString).filter { $0 != primaryID }
            : [primaryID]
        resetPayerAmountsToEqual()
    }

    func togglePayer(_ id: String?) {
        guard !hasSavedMedicalExpense else { return }
        if let id {
            if selectedPayerIDs.contains(id) {
                selectedPayerIDs.removeAll { $0 == id }
            } else if activeExpenseHumans.contains(where: { $0.id.uuidString == id }) {
                selectedPayerIDs.append(id)
            }
        } else {
            selectedPayerIDs = []
        }
        selectedPayerId = selectedPayerIDs.first
        resetPayerAmountsToEqual()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func resetPayerAmountsToEqual() {
        activePayerAmountID = nil
        guard selectedPayerIDs.count > 1,
              let total = parsedAmount,
              let contributions = try? ExpensePayerContributionPolicy.equalSplit(
                  total: total,
                  humanIDs: selectedPayerIDs.compactMap { UUID(uuidString: $0) }
              ),
              contributions.count == selectedPayerIDs.count
        else {
            payerAmountInputs = [:]
            return
        }
        payerAmountInputs = Dictionary(uniqueKeysWithValues: contributions.compactMap { contribution in
            guard let humanID = contribution.humanID else { return nil }
            return (
                humanID.uuidString,
                CountryDecimalInput.format(
                    contribution.amount,
                    countryCode: appCountry,
                    maxFractionDigits: 2
                )
            )
        })
    }

    func payerAmountBinding(for humanID: String) -> Binding<String> {
        Binding(
            get: { payerAmountInputs[humanID] ?? "" },
            set: { newValue in
                payerAmountInputs[humanID] = CountryDecimalInput.sanitize(
                    newValue,
                    countryCode: appCountry,
                    maxFractionDigits: 2
                )
                syncAmountFromPayerInputs()
            }
        )
    }

    var payerInputsMatchCurrentAmount: Bool {
        guard selectedPayerIDs.count > 1,
              let amount = parsedAmount,
              let amountUnits = ExpensePayerContributionPolicy.minorUnits(amount),
              let contributions = draftedPayerContributions,
              let payerTotal = try? ExpensePayerContributionPolicy.totalAmount(of: contributions),
              let payerUnits = ExpensePayerContributionPolicy.minorUnits(payerTotal)
        else {
            return false
        }
        return amountUnits == payerUnits
    }

    func syncAmountFromPayerInputs() {
        guard selectedPayerIDs.count > 1,
              let contributions = draftedPayerContributions,
              let total = try? ExpensePayerContributionPolicy.totalAmount(of: contributions)
        else {
            return
        }
        let updatedAmount = CountryDecimalInput.format(
            total,
            countryCode: appCountry,
            maxFractionDigits: 2
        )
        if amountInput != updatedAmount {
            amountInput = updatedAmount
        }
    }

    var payerSplitValidationText: String? {
        guard selectedPayerIDs.count > 1,
              let total = parsedAmount,
              payerContributionsForSave == nil,
              let totalUnits = ExpensePayerContributionPolicy.minorUnits(total)
        else {
            return nil
        }
        if totalUnits < Int64(selectedPayerIDs.count) {
            return l.tr(
                zh: "总额不足以分给每位支付人",
                en: "The total is too small for every payer",
                de: "Die Summe ist für alle Zahlenden zu klein",
                es: "El total es demasiado pequeño para todas las personas",
                pt: "O total é demasiado baixo para todas as pessoas",
                fr: "Le total est trop faible pour toutes les personnes",
                ja: "全員に分けるには合計額が小さすぎます",
                ko: "모든 결제자에게 나누기에는 총액이 너무 적습니다",
                it: "Il totale è troppo basso per tutte le persone"
            )
        }
        let enteredUnits = selectedPayerIDs.reduce(into: Int64(0)) { result, id in
            guard let input = payerAmountInputs[id],
                  let amount = CountryDecimalInput.parse(input, countryCode: appCountry),
                  let units = ExpensePayerContributionPolicy.minorUnits(amount),
                  units > 0,
                  result <= Int64.max - units
            else {
                return
            }
            result += units
        }
        let difference = totalUnits - enteredUnits
        if difference > 0 {
            let value = AppCurrency.format(Double(difference) / 100, fractionDigits: 2)
            return l.tr(
                zh: "还差 \(value)",
                en: "\(value) remaining",
                de: "Noch \(value)",
                es: "Faltan \(value)",
                pt: "Faltam \(value)",
                fr: "Il manque \(value)",
                ja: "あと \(value)",
                ko: "\(value) 남음",
                it: "Mancano \(value)"
            )
        }
        if difference < 0 {
            let value = AppCurrency.format(Double(-difference) / 100, fractionDigits: 2)
            return l.tr(
                zh: "超出 \(value)",
                en: "\(value) over",
                de: "\(value) zu viel",
                es: "Sobran \(value)",
                pt: "Excedeu \(value)",
                fr: "Dépassement de \(value)",
                ja: "\(value) 超過",
                ko: "\(value) 초과",
                it: "\(value) in eccesso"
            )
        }
        return l.tr(
            zh: "每位支付人的金额需大于 0",
            en: "Each payer amount must be above zero",
            de: "Jeder Zahlbetrag muss größer als null sein",
            es: "Cada importe debe ser mayor que cero",
            pt: "Cada valor deve ser maior que zero",
            fr: "Chaque montant doit être supérieur à zéro",
            ja: "各支払額は 0 より大きくしてください",
            ko: "각 결제 금액은 0보다 커야 합니다",
            it: "Ogni importo deve essere maggiore di zero"
        )
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
        let payload = AttachmentPrivacySanitizer.sanitizedAttachment(
            data,
            filename: url.lastPathComponent,
            isImage: isImage,
            fallbackFilename: "receipt_\(receiptAttachments.count + 1).jpg"
        )
        let attachment = ExpenseReceiptAttachment(
            data: payload.data,
            filename: payload.filename,
            isImage: payload.isImage
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
