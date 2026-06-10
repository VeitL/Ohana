//
//  AddExpenseSheet.swift
//  Ohana
//
//  花费快捷添加 Sheet — Go Focus 快速记账
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ExpenseReceiptAttachment: Identifiable, Equatable {
    let id = UUID()
    var data: Data
    var filename: String
    var isImage: Bool
}

struct ExpenseReceiptThumbnail: View {
    let data: Data
    let tint: Color

    @State var image: UIImage?

    var signature: String {
        FocusWalletAvatarCache.signature(for: data)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            } else {
                Image(systemName: "photo.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .task(id: signature) {
            let decoded = await AttachmentImageDecoder.decode(data)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                image = decoded
            }
        }
    }
}

struct ExpenseReceiptPreviewViewer: View {
    let receipt: ExpenseReceiptAttachment
    let onClose: () -> Void

    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @State var image: UIImage?

    var l: L10n { L10n(appLanguage) }

    var signature: String {
        FocusWalletAvatarCache.signature(for: receipt.data)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // ui-v4: allow receipt preview full-screen black viewer

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                Image(systemName: receipt.isImage ? "photo.fill" : "doc.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.72)) // ui-v4: allow receipt preview placeholder on black viewer
                    .accessibilityHidden(true)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Color.white) // ui-v4: allow receipt preview close control on black viewer
                            .padding(16)
                    }
                    .accessibilityLabel(l.tr(zh: "关闭预览", en: "Close preview", de: "Vorschau schließen"))
                }
                Spacer()
            }
        }
        .task(id: signature) {
            guard receipt.isImage else { return }
            let decoded = await AttachmentImageDecoder.decode(receipt.data)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                image = decoded
            }
        }
    }
}

struct AddExpenseSheet: View {
    let pet: Pet
    let humans: [Human]
    var preselectedPayerId: String?
    var onSaved: (() -> Void)?
    var onRewarded: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) var appCountry = AppCountry.detectedCode
    @FocusState var inputFocused: Bool

    @State var amountInput = ""
    @State var selectedCategory: ExpenseCategory = .food
    @State var noteInput = ""
    @State var date = Date()
    @State var selectedPayerId: String? = nil
    @State var showMore = false
    @State var isSaving = false
    @State var receiptAttachments: [ExpenseReceiptAttachment] = []
    @State var photoPickerItems: [PhotosPickerItem] = []
    @State var showingCamera = false
    @State var showCameraPermissionAlert = false
    @State var showingFilePicker = false
    @State var pendingCapturedImage: UIImage? = nil
    @State var previewReceipt: ExpenseReceiptAttachment? = nil
    @State var adaptiveSheetHeight: CGFloat = 660
    @State var popupVisible = false
    @State var isClosing = false
    @State var popupDragOffset: CGFloat = 0
    @StateObject var commandQueue = DeferredDomainCommandQueue()

    // 报销申请快捷入口
    @State var savedExpenseId: String? = nil
    @State var showClaimSheet = false

    var l: L10n { L10n(appLanguage) }

    var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var petThemeColor: Color {
        Color(hex: pet.safeThemeColorHex)
    }

    var sheetTint: Color {
        Color.goPrimary
    }

    var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }

    var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.62)
    }

    var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.46) : .black.opacity(0.42)
    }

    var cardSurface: Color {
        Color.ohanaCardSurface
    }

    var parsedAmount: Double? {
        CountryDecimalInput.parse(amountInput, countryCode: appCountry)
    }

    var isAmountValid: Bool {
        guard let v = parsedAmount, v > 0 else { return false }
        return true
    }

    var canSave: Bool {
        isAmountValid && !isSaving && !hasSavedMedicalExpense
    }

    var hasSavedMedicalExpense: Bool {
        savedExpenseId != nil
    }

    // 该宠物的活跃保单（用于报销快捷入口）
    var activeInsurances: [PetInsurance] {
        pet.insurances.filter(\.isActive)
    }

    var quickAmounts: [Double] {
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
                .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.inlinePopup) }
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.inlinePopup, style: .continuous))
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
                    allExpenses: pet.expenseLogs,
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
            ExpenseReceiptPreviewViewer(receipt: receipt) {
                previewReceipt = nil
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
}

extension View {
    func quickExpenseSolidSelectionSurface(
        isSelected: Bool,
        tint: Color,
        in shape: some InsettableShape
    ) -> some View {
        background(isSelected ? tint : Color.ohanaCardSurfaceElevated, in: shape)
    }
}
