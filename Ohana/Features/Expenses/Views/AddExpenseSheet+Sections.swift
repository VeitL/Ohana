//
//  AddExpenseSheet+Sections.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension AddExpenseSheetContent {
    var popupDragHandle: some View {
        OhanaPopupDragHandle(tint: primaryText.opacity(0.22))
            .gesture(popupHandleDragGesture)
    }

    var popupHandleDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                popupDragOffset = value.translation.height
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 56 || value.predictedEndTranslation.height > 108
                if shouldDismiss {
                    closeSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        popupDragOffset = 0
                    }
                }
            }
    }

    var popupBackdrop: some View {
        ZStack {
            Color.black.opacity(0.14) // ui-v4: allow inline popup scrimGradient token
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.22) // ui-v4: allow inline popup scrimGradient token
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { closeSheet() }
    }

    var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                petAvatar(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.quickExpenseTitle)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(primaryText)
                    Text(pet.name)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(secondaryText)
                }
            }
            Spacer()
            OhanaPopupCloseButton(tint: primaryText) { closeSheet() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    var amountEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(icon: "\(AppCurrency.systemIconName).fill", title: l.quickExpenseAmount)
                .padding(.horizontal, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(AppCurrency.symbol)
                    .font(OhanaFont.metric(size: 28, .black))
                    .foregroundStyle(sheetTint)
                Text(amountInput.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry) : amountInput)
                    .font(OhanaFont.metric(size: 52, .black))
                    .foregroundStyle(amountInput.isEmpty ? tertiaryText : primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.45)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .padding(.horizontal, 20)

            if !hasSavedMedicalExpense {
                EmbeddedDecimalKeypad(
                    text: $amountInput,
                    countryCode: appCountry,
                    maxFractionDigits: 2,
                    accent: sheetTint,
                    isEnabled: !isSaving,
                    isMini: true,
                    showsSubmitButton: false,
                    onSubmit: {
                        if canSave { saveExpense() }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, -2)
            }
        }
    }

    var quickAmountStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(icon: "bolt.fill", title: l.quickExpenseCommonAmounts)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.self) { amount in
                        Button {
                            applyQuickAmount(amount)
                        } label: {
                            Text("\(AppCurrency.symbol)\(displayAmount(amount))")
                                .font(OhanaFont.subheadline(.black))
                                .foregroundStyle(isQuickAmountSelected(amount) ? Color.arkInk : primaryText)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .quickExpenseSolidSelectionSurface(
                                    isSelected: isQuickAmountSelected(amount),
                                    tint: sheetTint,
                                    in: Capsule()
                                )
                        }
                        .disabled(hasSavedMedicalExpense)
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    var categoryStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(icon: "tag.fill", title: l.quickExpenseCategory)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases, id: \.rawValue) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    var sharedExpenseTargetSection: some View {
        if sameSpeciesExpensePets.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                SharedCareTargetPicker(
                    title: l.tr(zh: "共同花费", en: "Shared expense", de: "Gemeinsame Ausgabe"),
                    subtitle: selectedExpenseTargets.count > 1
                        ? l.tr(
                            zh: "\(selectedExpenseTargets.count)只宠物平摊",
                            en: "\(selectedExpenseTargets.count) pets split this",
                            de: "\(selectedExpenseTargets.count) Tiere teilen diese Ausgabe"
                        )
                        : l.tr(zh: "仅记录给 \(pet.name)", en: "Only \(pet.name)", de: "Nur \(pet.name)"),
                    pets: sameSpeciesExpensePets,
                    selectedPetIds: $selectedSharedExpensePetIds,
                    tint: sheetTint,
                    fixedPetId: pet.id
                )
                .padding(.horizontal, 20)

                if sharedExpenseReceiptBlocked {
                    sharedExpenseReceiptNotice
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    var sharedExpenseReceiptNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "paperclip") // a11y: allow decorative icon; notice text carries the message.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(sheetTint)
                .frame(width: 18)
            Text(l.tr(
                zh: "带收据的花费暂时只能保存到单只宠物；取消其他宠物或先移除收据。",
                en: "Expenses with receipts are saved to one pet for now. Deselect the others or remove the receipt.",
                de: "Ausgaben mit Beleg werden vorerst nur einem Tier zugeordnet. Wähle die anderen ab oder entferne den Beleg."
            ))
            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(sheetTint.opacity(0.10), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    @ViewBuilder
    var payerSection: some View {
        if humans.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(icon: "person.fill", title: l.quickExpensePayer)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        payerChip(id: nil, name: l.quickExpenseUnspecified, color: sheetTint) {
                            Image(systemName: "questionmark") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(selectedPayerId == nil ? Color.arkInk : secondaryText)
                        }
                        ForEach(humans) { human in
                            payerChip(
                                id: human.id.uuidString,
                                name: human.name,
                                color: humanThemeColor(human)
                            ) {
                                humanAvatar(human, size: 24)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        } else if let human = humans.first {
            infoRow(icon: "creditcard.fill", label: l.quickExpensePayer) {
                HStack(spacing: 6) {
                    humanAvatar(human, size: 24)
                    Text(human.name)
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(primaryText)
                }
            }
        }
    }

    var receiptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sectionLabel(icon: "paperclip", title: l.quickExpenseReceipt)
                if !receiptAttachments.isEmpty {
                    Text(l.quickExpenseReceiptCount(receiptAttachments.count))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(sheetTint)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                receiptActionButton(icon: "camera.fill", title: l.quickExpenseCamera) {
                    presentCamera()
                }

                PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 6, matching: .images) {
                    receiptActionContent(icon: "photo.fill", title: l.quickExpensePhotos)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(hasSavedMedicalExpense)
                .onChange(of: photoPickerItems) { _, items in
                    Task { await handleReceiptPhotoItems(items) }
                }

                receiptActionButton(icon: "doc.fill", title: l.quickExpenseFile) {
                    showingFilePicker = true
                }
            }
            .padding(.horizontal, 20)

            if !receiptAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(receiptAttachments) { receipt in
                            receiptAttachmentChip(receipt)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var insurancePolicyNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 15, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(sheetTint)
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(sheetTint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(l.quickExpenseInsuranceSingleTitle)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(primaryText)
                Text(activeInsurances.isEmpty ? l.quickExpenseInsuranceSingleNoPolicy : l.quickExpenseInsuranceSingleWithPolicy)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .padding(.horizontal, 20)
    }

    var moreSection: some View {
        DisclosureGroup(isExpanded: $showMore) {
            VStack(spacing: 10) {
                infoRow(icon: "calendar", label: l.quickExpenseDate) {
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(sheetTint)
                        .disabled(hasSavedMedicalExpense)
                }

                infoRow(icon: "note.text", label: l.quickExpenseNote) {
                    GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                        l.quickExpenseOptional,
                        text: $noteInput
                    )
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .disabled(hasSavedMedicalExpense)
                }
            }
        } label: {
            Label(l.quickExpenseMore, systemImage: "ellipsis.circle.fill")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(primaryText)
                .badge(moreSummary)
        }
        .disabled(hasSavedMedicalExpense)
        .padding(.horizontal, 20)
    }

    var claimHintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goTeal)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goTeal.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(l.quickExpenseMedicalRecorded)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(primaryText)
                Text(l.quickExpenseSubmitToInsurer(activeInsurances.first?.productName ?? l.quickExpenseInsuranceCompany))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .padding(.horizontal, 20)
    }

    var bottomActionBar: some View {
        VStack(spacing: 8) {
            if hasSavedMedicalExpense {
                Button {
                    inputFocused = false
                    GoKeyboard.dismiss()
                    showClaimSheet = true
                } label: {
                    primaryActionContent(icon: "shield.checkered", title: l.quickExpenseApplyClaim)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button {
                    GoKeyboard.dismiss()
                    DispatchQueue.main.async {
                        saveExpense()
                    }
                } label: {
                    primaryActionContent(icon: "checkmark.circle.fill", title: isSaving ? l.quickExpenseSaving : bottomSaveTitle)
                        .opacity(canSave ? 1 : 0.45)
                }
                .disabled(!canSave)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Reusable Views
}
