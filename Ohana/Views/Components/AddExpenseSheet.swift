//
//  AddExpenseSheet.swift
//  Ohana
//
//  花费快捷添加 Sheet — Go Focus 快速记账
//

import SwiftUI
import SwiftData
import Foundation
import PhotosUI
import UniformTypeIdentifiers

private struct ExpenseReceiptAttachment: Identifiable, Equatable {
    let id = UUID()
    var data: Data
    var filename: String
    var isImage: Bool
}

struct AddExpenseSheet: View {
    let pet: Pet
    var preselectedPayerId: String? = nil
    var onSaved: (() -> Void)? = nil
    var onRewarded: ((Int) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @FocusState private var inputFocused: Bool

    @State private var amountInput = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var noteInput = ""
    @State private var date = Date()
    @State private var selectedPayerId: String? = nil
    @State private var showMore = false
    @State private var isSaving = false
    @State private var receiptAttachments: [ExpenseReceiptAttachment] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var showingFilePicker = false
    @State private var pendingCapturedImage: UIImage? = nil
    @State private var previewReceipt: ExpenseReceiptAttachment? = nil
    @State private var adaptiveSheetHeight: CGFloat = 660
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var popupDragOffset: CGFloat = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    // 报销申请快捷入口
    @State private var savedExpenseId: String? = nil
    @State private var showClaimSheet = false

    private var l: L10n { L10n(appLanguage) }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    private var petThemeColor: Color {
        Color(hex: pet.safeThemeColorHex)
    }

    private var sheetTint: Color {
        Color.goPrimary
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.62)
    }

    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.46) : .black.opacity(0.42)
    }

    private var cardSurface: Color {
        Color.ohanaCardSurface
    }

    private var parsedAmount: Double? {
        CountryDecimalInput.parse(amountInput, countryCode: appCountry)
    }

    private var isAmountValid: Bool {
        guard let v = parsedAmount, v > 0 else { return false }
        return true
    }

    private var canSave: Bool {
        isAmountValid && !isSaving && !hasSavedMedicalExpense
    }

    private var hasSavedMedicalExpense: Bool {
        savedExpenseId != nil
    }

    // 该宠物的活跃保单（用于报销快捷入口）
    private var activeInsurances: [PetInsurance] {
        pet.insurances.filter { $0.isActive }
    }

    private var quickAmounts: [Double] {
        var values: [Double] = []
        let positiveLogs = pet.expenseLogs
            .filter { $0.amount > 0 }
            .sorted { $0.date > $1.date }

        appendUniqueAmounts(
            positiveLogs
                .filter { $0.expenseCategory == selectedCategory }
                .map { roundedCurrency($0.amount) },
            into: &values
        )
        appendUniqueAmounts(
            positiveLogs
                .map { roundedCurrency($0.amount) },
            into: &values
        )
        appendUniqueAmounts(defaultAmounts(for: selectedCategory), into: &values)
        return Array(values.prefix(4))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let maxPanelHeight = max(430, proxy.size.height * 0.92)
            let scrollMaxHeight = max(250, maxPanelHeight - 166)
            let panelHeightEstimate = min(maxPanelHeight, max(adaptiveSheetHeight, 430))
            let hiddenOffset = panelHeightEstimate + 72

            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: popupVisible) {
                popupBackdrop
                    .opacity(popupVisible ? 1 : 0)

                VStack(spacing: 0) {
                    popupDragHandle
                        .padding(.top, 4)
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            amountEntry
                            quickAmountStrip
                            categoryStrip
                            payerSection
                            receiptSection
                            if selectedCategory == .insurancePremium {
                                insurancePolicyNotice
                            }
                            moreSection

                            if hasSavedMedicalExpense {
                                claimHintCard
                            }
                        }
                        .padding(.bottom, 18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxHeight: scrollMaxHeight)

                    bottomActionBar
                }
                .background { OhanaPopupGlassSurface(cornerRadius: 52) }
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(color: Color.black.opacity(0.56), radius: 48, x: 0, y: -18) // ui-v4: allow confirmed inline popup liftedAlert shadow token
                .shadow(color: Color(hex: "0B102C").opacity(0.46), radius: 28, x: 0, y: 12) // ui-v4: allow confirmed inline popup liftedAlert shadow token
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .offset(y: popupVisible ? popupDragOffset : hiddenOffset)
                .frame(maxHeight: maxPanelHeight, alignment: .bottom)
                .ohanaAdaptiveSheetContentHeight(
                    $adaptiveSheetHeight,
                    minHeight: 430,
                    maxHeight: maxPanelHeight,
                    chromePadding: 18
                )
            }
        }
        .allowsHitTesting(popupVisible && !isClosing)
        .animation(popupAnimation, value: popupVisible)
        .presentationBackground(.clear)
        .presentationDetents([.height(adaptiveSheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationContentInteraction(.scrolls)
        .sheet(isPresented: $showClaimSheet) {
            if let firstInsurance = activeInsurances.first {
                AddInsuranceClaimSheet(
                    insurance: firstInsurance,
                    pet: pet,
                    prelinkedExpenseId: savedExpenseId
                )
            }
        }
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if let image = pendingCapturedImage {
                appendReceiptImage(image)
                pendingCapturedImage = nil
            }
        }) {
            PetCameraPickerView { image in
                pendingCapturedImage = image
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
        .fullScreenCover(item: $previewReceipt) { receipt in
            if let image = UIImage(data: receipt.data) {
                ZStack {
                    Color.black.ignoresSafeArea() // ui-v4: allow receipt preview full-screen black viewer
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                    VStack {
                        HStack {
                            Spacer()
                            Button { previewReceipt = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white) // ui-v4: allow receipt preview close control on black viewer
                                    .padding(16)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]
        ) { result in
            handleReceiptFileImport(result)
        }
        .alert(l.quickExpenseCameraUnavailable, isPresented: $showCameraPermissionAlert) {
            Button(l.done, role: .cancel) {}
        } message: {
            Text(l.quickExpenseCameraPermissionMessage)
        }
        .onAppear {
            configureInitialPayer()
            popupVisible = false
            isClosing = false
            DispatchQueue.main.async {
                withAnimation(popupAnimation) {
                    popupVisible = true
                }
            }
        }
        .onChange(of: amountInput) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(newValue, countryCode: appCountry, maxFractionDigits: 2)
            if sanitized != newValue {
                amountInput = sanitized
            }
        }
        .animation(GoMotion.feedback, value: selectedCategory)
        .animation(GoMotion.feedback, value: showMore)
        .animation(GoMotion.feedback, value: hasSavedMedicalExpense)
    }

    // MARK: - Sections

    private var popupDragHandle: some View {
        OhanaPopupDragHandle(tint: primaryText.opacity(0.22))
            .gesture(popupHandleDragGesture)
    }

    private var popupHandleDragGesture: some Gesture {
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

    private var popupBackdrop: some View {
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

    private var header: some View {
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

    private var amountEntry: some View {
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
            .background(cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var quickAmountStrip: some View {
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

    private var categoryStrip: some View {
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
    private var payerSection: some View {
        if humans.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(icon: "person.fill", title: l.quickExpensePayer)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        payerChip(id: nil, name: l.quickExpenseUnspecified, color: sheetTint) {
                            Image(systemName: "questionmark")
                                .font(.system(size: 13, weight: .black))
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

    private var receiptSection: some View {
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

    private var insurancePolicyNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(sheetTint)
                .frame(width: 30, height: 30)
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var moreSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(GoMotion.feedback) {
                    showMore.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tertiaryText)
                    Text(l.quickExpenseMore)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text(moreSummary)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(tertiaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(tertiaryText)
                        .rotationEffect(.degrees(showMore ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(hasSavedMedicalExpense)
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)

            if showMore {
                VStack(spacing: 10) {
                    infoRow(icon: "calendar", label: l.quickExpenseDate) {
                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(sheetTint)
                            .disabled(hasSavedMedicalExpense)
                    }

                    infoRow(icon: "note.text", label: l.quickExpenseNote) {
                        GoDraftTextField(
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var claimHintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.goTeal)
                .frame(width: 34, height: 34)
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var bottomActionBar: some View {
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

    private func receiptActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            receiptActionContent(icon: icon, title: title)
        }
        .disabled(hasSavedMedicalExpense)
        .buttonStyle(ScaleButtonStyle())
    }

    private func receiptActionContent(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
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

    private func receiptAttachmentChip(_ receipt: ExpenseReceiptAttachment) -> some View {
        HStack(spacing: 8) {
            if receipt.isImage, let image = UIImage(data: receipt.data) {
                Button { previewReceipt = receipt } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(sheetTint)
                    .frame(width: 34, height: 34)
                    .background(sheetTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
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

    private func primaryActionContent(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(sheetTint, in: Capsule())
    }

    private func categoryChip(_ category: ExpenseCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: category.systemIconName)
                    .font(.system(size: 13, weight: .black))
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

    private func payerChip<Avatar: View>(
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
                    .frame(width: 24, height: 24)
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

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tertiaryText)
            Text(title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(tertiaryText)
        }
    }

    private func infoRow<Trailing: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
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
    private func petAvatar(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
            themeColor: petThemeColor,
            size: size,
            backgroundOpacity: 0.22
        )
    }

    @ViewBuilder
    private func humanAvatar(_ human: Human, size: CGFloat) -> some View {
        if let data = human.avatarImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(human.avatarEmoji)
                .font(.system(size: size * 0.62))
                .frame(width: size, height: size)
        }
    }

    // MARK: - Helpers

    private var moreSummary: String {
        if noteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Calendar.current.isDateInToday(date) ? l.quickExpenseToday : date.formatted(.dateTime.month().day())
        }
        return l.quickExpenseHasNote
    }

    private var bottomSaveTitle: String {
        return l.quickExpenseSave
    }

    private func configureInitialPayer() {
        guard !humans.isEmpty else {
            selectedPayerId = nil
            return
        }
        if let pid = preselectedPayerId, humans.contains(where: { $0.id.uuidString == pid }) {
            selectedPayerId = pid
        } else {
            let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
            selectedPayerId = (!stored.isEmpty && humans.contains(where: { $0.id.uuidString == stored }))
                ? stored
                : humans.first?.id.uuidString
        }
    }

    private func applyQuickAmount(_ amount: Double) {
        guard !hasSavedMedicalExpense else { return }
        amountInput = amountInputString(amount)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func isQuickAmountSelected(_ amount: Double) -> Bool {
        guard let parsedAmount else { return false }
        return abs(roundedCurrency(parsedAmount) - roundedCurrency(amount)) < 0.01
    }

    private func defaultAmounts(for category: ExpenseCategory) -> [Double] {
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

    private func appendUniqueAmounts(_ candidates: [Double], into values: inout [Double]) {
        for amount in candidates where amount > 0 {
            let rounded = roundedCurrency(amount)
            if !values.contains(where: { abs($0 - rounded) < 0.01 }) {
                values.append(rounded)
            }
            if values.count >= 4 { return }
        }
    }

    private func roundedCurrency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }

    private func displayAmount(_ amount: Double) -> String {
        let rounded = roundedCurrency(amount)
        let fractionDigits = abs(rounded - rounded.rounded()) < 0.01 ? 0 : 2
        return CountryDecimalInput.format(rounded, countryCode: appCountry, maxFractionDigits: fractionDigits)
    }

    private func amountInputString(_ amount: Double) -> String {
        displayAmount(amount)
    }

    private func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        return hex.count == 6 ? Color(hex: hex) : Color.goPrimary
    }

    private func receiptLabel(_ receipt: ExpenseReceiptAttachment) -> String {
        let cleaned = receipt.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        return receipt.isImage ? l.quickExpenseImage : l.quickExpenseFile
    }

    private func receiptDrafts() -> [ExpenseReceiptAttachmentDraft] {
        receiptAttachments.map {
            ExpenseReceiptAttachmentDraft(data: $0.data, filename: $0.filename, isImage: $0.isImage)
        }
    }

    private func presentCamera() {
        guard !hasSavedMedicalExpense else { return }
        inputFocused = false
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }

    private func appendReceiptImage(_ image: UIImage) {
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
    private func handleReceiptPhotoItems(_ items: [PhotosPickerItem]) async {
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

    private func handleReceiptFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        inputFocused = false
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
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

    private func receiptDocumentCategory() -> DocumentCategory {
        switch selectedCategory {
        case .medical:
            return .medical
        case .insurancePremium:
            return .insurance
        default:
            return .other
        }
    }

    private func receiptDocumentTitle(note: String) -> String {
        if !note.isEmpty { return note }
        return "\(pet.name) · \(l.expenseCategoryTitle(selectedCategory)) \(l.quickExpenseReceipt)"
    }

    private func saveExpense() {
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
            let result = DashboardRecordCommandExecutor(context: modelContext).recordPetExpense(
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

    private func closeSheet() {
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

private extension View {
    func quickExpenseSolidSelectionSurface<S: InsettableShape>(
        isSelected: Bool,
        tint: Color,
        in shape: S
    ) -> some View {
        background(isSelected ? tint : Color.ohanaCardSurfaceElevated, in: shape)
    }
}
