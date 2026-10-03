//
//  AddExpenseSheet+Components.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension AddExpenseSheetContent {
    func receiptActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            receiptActionContent(icon: icon, title: title)
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
    }

    func receiptActionContent(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.caption(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    func receiptAttachmentChip(_ receipt: ExpenseReceiptAttachment) -> some View {
        HStack(spacing: 8) {
            if receipt.isImage {
                Button { previewReceipt = receipt } label: {
                    ExpenseReceiptThumbnail(data: receipt.data, tint: sheetTint)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Image(systemName: "doc.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(sheetTint)
                    .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(sheetTint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                    .accessibilityHidden(true)
            }

            Text(receiptLabel(receipt))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .frame(maxWidth: 130, alignment: .leading)

            Button {
                withAnimation(GoMotion.feedback) {
                    receiptAttachments.removeAll { $0.id == receipt.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            .accessibilityLabel(l.quickExpenseRemoveReceipt)
            .buttonStyle(ScaleButtonStyle())
            .disabled(hasSavedMedicalExpense)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    func primaryActionContent(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(sheetTint, in: Capsule())
    }

    func categoryChip(_ category: ExpenseCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: category.systemIconName)
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.expenseCategoryTitle(category))
                    .font(OhanaFont.subheadline(.black))
            }
            .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : primaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .quickExpenseSolidSelectionSurface(isSelected: isSelected, tint: sheetTint, in: Capsule())
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
    }

    func payerChip(
        id: String?,
        name: String,
        color _: Color,
        @ViewBuilder avatar: () -> some View
    ) -> some View {
        let isSelected = id.map { selectedPayerIDs.contains($0) } ?? selectedPayerIDs.isEmpty
        return Button {
            withAnimation(GoMotion.feedback) {
                togglePayer(id)
            }
        } label: {
            HStack(spacing: 7) {
                avatar()
                    .frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaCardSurface, in: Circle())
                Text(name)
                    .font(OhanaFont.subheadline(.black))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : primaryText)
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .padding(.vertical, 8)
            .quickExpenseSolidSelectionSurface(isSelected: isSelected, tint: sheetTint, in: Capsule())
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(
            id == nil && isSelected ? "" : payerSelectionAccessibilityHint(name: name, isSelected: isSelected)
        )
        .accessibilityIdentifier(id.map { "expense-payer-\($0)" } ?? "expense-payer-unspecified")
    }

    func payerContributionRow(_ human: Human) -> some View {
        let id = human.id.uuidString
        let isActive = activePayerAmountID == id
        let amount = payerAmountInputs[id] ?? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry)
        return Button {
            withAnimation(GoMotion.feedback) {
                activePayerAmountID = isActive ? nil : id
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            humanAvatar(human, size: 28)
                                .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            Text(human.name)
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(primaryText)
                                .lineLimit(2)
                        }
                        payerAmountPill(amount, isActive: isActive)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    HStack(spacing: 10) {
                        humanAvatar(human, size: 28)
                            .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        Text(human.name)
                            .font(OhanaFont.subheadline(.bold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        Spacer()
                        payerAmountPill(amount, isActive: isActive)
                    }
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(hasSavedMedicalExpense)
        .accessibilityLabel(payerAmountAccessibilityLabel(name: human.name))
        .accessibilityValue("\(AppCurrency.symbol)\(amount)")
        .accessibilityHint(payerAmountAccessibilityHint(isActive: isActive))
        .accessibilityIdentifier("expense-payer-amount-\(id)")
    }

    func payerAmountPill(_ amount: String, isActive: Bool) -> some View {
        Text("\(AppCurrency.symbol)\(amount)")
            .font(OhanaFont.subheadline(.black))
            .foregroundStyle(isActive ? Color.ohanaPrimaryActionText : primaryText)
            .monospacedDigit()
            .padding(.horizontal, 11)
            .frame(minHeight: 36)
            .background(isActive ? sheetTint : Color.ohanaCardSurfaceElevated, in: Capsule())
    }

    func payerSelectionAccessibilityHint(name: String, isSelected: Bool) -> String {
        isSelected
            ? l.tr(
                zh: "取消选择 \(name)",
                en: "Deselect \(name)",
                de: "\(name) abwählen",
                es: "Anular selección de \(name)",
                pt: "Desmarcar \(name)",
                fr: "Désélectionner \(name)",
                ja: "\(name) の選択を解除",
                ko: "\(name) 선택 해제",
                it: "Deseleziona \(name)"
            )
            : l.tr(
                zh: "选择 \(name)",
                en: "Select \(name)",
                de: "\(name) auswählen",
                es: "Seleccionar \(name)",
                pt: "Selecionar \(name)",
                fr: "Sélectionner \(name)",
                ja: "\(name) を選択",
                ko: "\(name) 선택",
                it: "Seleziona \(name)"
            )
    }

    func payerAmountAccessibilityLabel(name: String) -> String {
        l.tr(
            zh: "\(name) 支付金额",
            en: "Amount paid by \(name)",
            de: "Zahlbetrag von \(name)",
            es: "Importe pagado por \(name)",
            pt: "Valor pago por \(name)",
            fr: "Montant payé par \(name)",
            ja: "\(name) の支払額",
            ko: "\(name) 결제 금액",
            it: "Importo pagato da \(name)"
        )
    }

    func payerAmountAccessibilityHint(isActive: Bool) -> String {
        if isActive {
            return l.tr(
                zh: "数字键盘已展开，轻点收起", en: "Number pad expanded. Tap to close it.",
                de: "Ziffernblock geöffnet. Zum Schließen tippen.",
                es: "Teclado numérico abierto. Toca para cerrarlo.",
                pt: "Teclado numérico aberto. Toque para fechar.",
                fr: "Pavé numérique ouvert. Touchez pour le fermer.",
                ja: "数字キーパッドを表示中。タップして閉じます。",
                ko: "숫자 키패드 펼쳐짐. 탭하여 닫기.",
                it: "Tastierino numerico aperto. Tocca per chiuderlo."
            )
        }
        return l.tr(
            zh: "轻点后用数字键盘输入", en: "Tap to enter with the number pad", de: "Tippen, um den Betrag einzugeben",
            es: "Toca para introducir el importe", pt: "Toque para inserir o valor", fr: "Touchez pour saisir le montant",
            ja: "タップして金額を入力", ko: "탭하여 금액 입력", it: "Tocca per inserire l’importo"
        )
    }

    func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tertiaryText)
            Text(title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(tertiaryText)
        }
    }

    func infoRow(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tertiaryText)
            Text(label)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(primaryText)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    func petAvatar(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            pet: pet,
            fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
            themeColor: petThemeColor,
            size: size,
            backgroundOpacity: 0.22
        )
    }

    @ViewBuilder
    func humanAvatar(_ human: Human, size: CGFloat) -> some View {
        HumanAvatarPipelineView(
            human: human,
            size: size,
            fallbackScale: 0.62,
            showsBackground: false
        )
    }

    // MARK: - Helpers
}
