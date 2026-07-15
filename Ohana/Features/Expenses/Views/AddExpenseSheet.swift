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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)

            AsyncDecodedImageView(
                data: data,
                cacheID: "expense-receipt-thumbnail",
                maxPixel: 120
            ) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            } placeholder: {
                Image(systemName: "photo.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct ExpenseReceiptPreviewViewer: View {
    let receipt: ExpenseReceiptAttachment
    let onClose: () -> Void

    @Environment(\.ohanaAppLanguageCode) var appLanguage

    var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // ui-v4: allow receipt preview full-screen black viewer

            AsyncDecodedImageView(
                data: receipt.isImage ? receipt.data : nil,
                cacheID: "expense-receipt-preview",
                maxPixel: 2200
            ) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } placeholder: {
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
    }
}

struct AddExpenseSheetContent: View {
    let pet: Pet
    let humans: [Human]
    var allPets: [Pet] = []
    let routeExpenseLogs: [PetExpenseLog]
    let routeInsurances: [PetInsurance]
    var preselectedPayerId: String?
    var onSaved: (() -> Void)?
    var onRewarded: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage(AppCountry.storageKey) var appCountry = AppCountry.detectedCode
    @FocusState var inputFocused: Bool

    @State var amountInput = ""
    @State var selectedCategory: ExpenseCategory = .food
    @State var noteInput = ""
    @State var date = Date()
    @State var selectedPayerId: String? = nil
    @State var selectedRecorderID: UUID?
    @State var requiresRecorderSelection = false
    @State var selectedSharedExpensePetIds: Set<UUID> = []
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
    @State var saveErrorMessage: String? = nil
    @StateObject var commandQueue = DeferredDomainCommandQueue()

    // 报销申请快捷入口
    @State var savedExpenseId: String? = nil
    @State var showClaimSheet = false

    init(
        pet: Pet,
        humans: [Human],
        allPets: [Pet] = [],
        routeExpenseLogs: [PetExpenseLog] = [],
        routeInsurances: [PetInsurance] = [],
        preselectedPayerId: String? = nil,
        onSaved: (() -> Void)? = nil,
        onRewarded: ((Int) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.pet = pet
        self.humans = humans
        self.allPets = allPets
        self.routeExpenseLogs = routeExpenseLogs
        self.routeInsurances = routeInsurances
        self.preselectedPayerId = preselectedPayerId
        self.onSaved = onSaved
        self.onRewarded = onRewarded
        self.onDismiss = onDismiss
    }

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
        isAmountValid && !isSaving && !hasSavedMedicalExpense && !sharedExpenseReceiptBlocked &&
            !requiresRecorderSelection
    }

    var hasSavedMedicalExpense: Bool {
        savedExpenseId != nil
    }

    // 该宠物的活跃保单（用于报销快捷入口）
    var activeInsurances: [PetInsurance] {
        routeInsurances.filter(\.isActive)
    }

    var activeExpenseHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    var sameSpeciesExpensePets: [Pet] {
        let sourceSpecies = SharedPetTargetResolver.normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && SharedPetTargetResolver.normalizedSpecies($0.species) == sourceSpecies }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var selectedExpenseTargets: [Pet] {
        let selectedTargets = sameSpeciesExpensePets.filter { selectedSharedExpensePetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(selectedTargets, fallback: pet)
    }

    var isSharedExpense: Bool {
        selectedExpenseTargets.count > 1
    }

    var sharedExpenseReceiptBlocked: Bool {
        isSharedExpense && !receiptAttachments.isEmpty
    }

    var quickAmounts: [Double] {
        var values: [Double] = []
        let positiveLogs = routeExpenseLogs
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(pet.name)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    amountEntry
                    quickAmountStrip
                    categoryStrip
                    sharedExpenseTargetSection
                    payerSection
                    QuickCareActionHumanPickerContainer(
                        selectedHumanID: $selectedRecorderID,
                        requiresSelection: $requiresRecorderSelection,
                        role: .recorder,
                        tint: sheetTint
                    )
                    .padding(.horizontal, 20)
                    receiptSection
                    if selectedCategory == .insurancePremium {
                        insurancePolicyNotice
                    }
                    moreSection

                    if hasSavedMedicalExpense {
                        claimHintCard
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(l.tr(zh: "添加花费", en: "Add Expense", de: "Ausgabe hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { closeSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasSavedMedicalExpense {
                        Button(l.quickExpenseApplyClaim) {
                            inputFocused = false
                            GoKeyboard.dismiss()
                            showClaimSheet = true
                        }
                    } else {
                        Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { saveExpense() }
                            .disabled(!canSave || isSaving)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .sheet(isPresented: $showClaimSheet) {
            if let firstInsurance = activeInsurances.first {
                AddInsuranceClaimSheet(
                    insurance: firstInsurance,
                    pet: pet,
                    allExpenses: routeExpenseLogs,
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
        .alert(
            l.tr(zh: "无法保存费用", en: "Could not save expense", de: "Ausgabe konnte nicht gespeichert werden"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onAppear {
            configureInitialPayer()
            selectedSharedExpensePetIds = SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "expense.shared",
                candidates: sameSpeciesExpensePets,
                defaultToAll: false
            )
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
