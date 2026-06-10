//
//  AddExpenseSheet+Components.swift
//  Ohana
//

import SwiftUI
import SwiftData
import Foundation
import PhotosUI
import UniformTypeIdentifiers

extension AddExpenseSheet {
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .background(sheetTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func primaryActionContent(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.arkInk)
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
            .foregroundStyle(isSelected ? Color.arkInk : primaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .quickExpenseSolidSelectionSurface(isSelected: isSelected, tint: sheetTint, in: Capsule())
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
    }

    func payerChip<Avatar: View>(
        id: String?,
        name: String,
        color: Color,
        @ViewBuilder avatar: () -> Avatar
    ) -> some View {
        let isSelected = selectedPayerId == id
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedPayerId = id
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
            .foregroundStyle(isSelected ? Color.arkInk : primaryText)
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .padding(.vertical, 8)
            .quickExpenseSolidSelectionSurface(isSelected: isSelected, tint: sheetTint, in: Capsule())
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
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

    func infoRow<Trailing: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> Trailing
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    func petAvatar(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            imageData: pet.avatarImageData,
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
