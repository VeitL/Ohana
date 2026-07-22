import SwiftData
import SwiftUI

nonisolated enum CoconutShopDataState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated enum ShopPurchaseReadiness: Equatable {
    case loading
    case missingBuyer
    case walletFrozen
    case insufficient(missing: Int)
    case ready

    static func resolve(
        dataState: CoconutShopDataState,
        hasBuyer: Bool,
        buyerCanWrite: Bool,
        spendableBalance: Int,
        cost: Int
    ) -> ShopPurchaseReadiness {
        guard dataState == .loaded else { return .loading }
        guard hasBuyer else { return .missingBuyer }
        guard buyerCanWrite else { return .walletFrozen }
        let missing = max(0, cost - max(0, spendableBalance))
        return missing == 0 ? .ready : .insufficient(missing: missing)
    }
}

nonisolated enum ShopPurchaseSettlementState: Equatable, Sendable {
    case pending
    case refunding
    case needsAttention
}

nonisolated enum ShopManualRecoveryActionPolicy {
    static func canRetry(reasonCode: String?) -> Bool {
        switch reasonCode {
        case "catalogItemMissing",
             "missingFundingSnapshot",
             "invalidFundingSnapshot",
             "missingOrFrozenRefundRecipient",
             "manualRecoveryPersistenceFailed":
            true
        default:
            false
        }
    }
}

struct CoconutShopView: View {
    let humans: [Human]
    let pets: [Pet]
    let purchaseRecords: [ShopPurchaseRecord]
    let exchangeRequests: [CoconutExchangeRequest]
    let humanBalances: [UUID: Int]
    let purchaseSettlements: [String: ShopPurchaseSettlementState]
    let purchaseSettlementReasons: [String: String]
    let dataState: CoconutShopDataState
    let retryDataLoad: () -> Void
    let refreshData: () -> Void
    let retryPurchaseRecovery: (String) -> ShopPurchaseManualRecoveryResult

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.hasSupporterPackEntitlement) var hasSupporterPack
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(AppServices.self) var appServices

    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage("currentActiveHumanId") var activeHumanId = ""
    @AppStorage("shop_equipped_title") var equippedTitle = ""
    @AppStorage("shop_equip_fx_lime_glow") var equipFxLimeGlow = false
    @AppStorage("shop_equip_fx_rainbow") var equipFxRainbow = false
    @AppStorage("shop_equip_fx_rainbow_poop") var equipFxRainbowPoop = false
    @AppStorage("shop_equip_fx_popout_card") var equipFxPopoutCard = true
    @AppStorage("shop_equip_fx_stars") var equipFxStars = false
    @AppStorage("shop_equip_fx_firework") var equipFxFirework = false
    @AppStorage(OasisPlantDecorStore.equippedSceneKey) var equippedPlantDecorScene = ""
    @AppStorage(OasisPlantDecorStore.equippedPotSkinKey) var equippedPlantPotSkin = ""
    @AppStorage(AppIconCatalog.selectedIconKey) var selectedAppIcon = AppIconCatalog.defaultItemId

    @State var selectedCategory: ShopItem.ShopCategory
    @State var pendingPurchaseItem: ShopItem?
    @State var activePicker: ShopPicker?
    @State var equipPopoutPet: Pet?
    @State var showInventory = false
    @State var toast: ShopToast?
    @State var toastTask: Task<Void, Never>?
    @State var purchaseInFlightItemID: String?
    @State var purchaseErrorMessage: String?
    @State var purchaseRetryBlocked = false
    @State var blockedPurchaseItemIDs: Set<String> = []
    @State var recoveryInFlightItemID: String?
    @State var shopBuyerID: UUID?
    @State var exchangeReceiverId = ""
    @State var exchangeOptionId = ""
    @State var exchangeNote = ""

    init(
        initialCategory: ShopItem.ShopCategory = .appIcon,
        humans: [Human] = [],
        pets: [Pet] = [],
        purchaseRecords: [ShopPurchaseRecord] = [],
        exchangeRequests: [CoconutExchangeRequest] = [],
        humanBalances: [UUID: Int] = [:],
        purchaseSettlements: [String: ShopPurchaseSettlementState] = [:],
        purchaseSettlementReasons: [String: String] = [:],
        dataState: CoconutShopDataState = .loaded,
        retryDataLoad: @escaping () -> Void = {},
        refreshData: @escaping () -> Void = {},
        retryPurchaseRecovery: @escaping (String) -> ShopPurchaseManualRecoveryResult = { itemID in
            ShopPurchaseManualRecoveryResult(
                itemID: itemID,
                disposition: .stillNeedsAttention,
                reasonCode: "manualReviewAttemptUnavailable"
            )
        }
    ) {
        self.humans = humans
        self.pets = pets
        self.purchaseRecords = purchaseRecords
        self.exchangeRequests = exchangeRequests
        self.humanBalances = humanBalances
        self.purchaseSettlements = purchaseSettlements
        self.purchaseSettlementReasons = purchaseSettlementReasons
        self.dataState = dataState
        self.retryDataLoad = retryDataLoad
        self.refreshData = refreshData
        self.retryPurchaseRecovery = retryPurchaseRecovery
        _selectedCategory = State(initialValue: initialCategory.isVisibleInFirstRelease ? initialCategory : .appIcon)
    }

    enum ShopPicker: Identifiable {
        case avatarTarget
        case popoutPet
        case cashExchange

        var id: String {
            switch self {
            case .avatarTarget: "avatarTarget"
            case .popoutPet: "popoutPet"
            case .cashExchange: "cashExchange"
            }
        }
    }

    struct ShopToast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let icon: String
        let tint: Color
    }

    @StateObject var commandQueue = DeferredDomainCommandQueue()

    var l: L10n { L10n(appLanguage) }
    var primaryText: Color { Color.ohanaPrimaryText }
    var secondaryText: Color { Color.ohanaSecondaryText }
    var tertiaryText: Color { Color.ohanaTertiaryText }

    var purchasedSet: Set<String> {
        var ownedIDs = ShopPurchaseRecordStore.ownedItemIDs(from: purchaseRecords)
        if hasSupporterPack {
            ownedIDs.insert(SupporterPackCatalog.supporterIconItemID)
        }
        return ownedIDs
    }

    var allItems: [ShopItem] {
        ShopCatalog.allItems(purchasedSet: purchasedSet)
    }

    var filteredItems: [ShopItem] {
        allItems.filter { $0.category == effectiveSelectedCategory }
    }

    var effectiveSelectedCategory: ShopItem.ShopCategory {
        selectedCategory.isVisibleInFirstRelease ? selectedCategory : .appIcon
    }

    var selectedActiveHuman: Human? {
        if let shopBuyerID {
            return activeHumans.first { $0.id == shopBuyerID }
        }
        return activeHumans.first { $0.id.uuidString == activeHumanId }
    }

    var currentHuman: Human? {
        if let selectedActiveHuman {
            return selectedActiveHuman
        }
        return activeHumans.count == 1 ? activeHumans.first : nil
    }

    var otherHumans: [Human] {
        guard let currentHuman else { return [] }
        return activeHumans.filter { $0.id != currentHuman.id }
    }

    var activeHumans: [Human] {
        humans.filter(EconomyWalletWritePolicy.canWrite)
    }

    var activePets: [Pet] {
        pets.filter(EconomyWalletWritePolicy.canWrite)
    }

    var currentHumanBalance: Int {
        guard let currentHuman else { return 0 }
        return max(0, humanBalances[currentHuman.id] ?? currentHuman.coconutBalance)
    }

    var islandSpendableHumanBalance: Int {
        activeHumans.reduce(0) { partial, human in
            partial + max(0, humanBalances[human.id] ?? human.coconutBalance)
        }
    }

    var exchangeOptions: [CoconutExchangeOption] {
        guard CoconutExchangeFeatureGate.isEnabled else { return [] }
        return CoconutExchangeOption.options()
    }

    var selectedExchangeOption: CoconutExchangeOption? {
        exchangeOptions.first { $0.id == exchangeOptionId } ?? exchangeOptions.first
    }

    var selectedExchangeReceiver: Human? {
        otherHumans.first { $0.id.uuidString == exchangeReceiverId } ?? otherHumans.first
    }

    var incomingPendingExchanges: [CoconutExchangeRequest] {
        guard CoconutExchangeFeatureGate.isEnabled else { return [] }
        guard let currentHuman else { return [] }
        return exchangeRequests.filter { $0.status == .pending && $0.receiverId == currentHuman.id.uuidString }
    }

    var outgoingPendingExchanges: [CoconutExchangeRequest] {
        guard CoconutExchangeFeatureGate.isEnabled else { return [] }
        guard let currentHuman else { return [] }
        return exchangeRequests.filter { $0.status == .pending && $0.senderId == currentHuman.id.uuidString }
    }

    var ownedCount: Int {
        let consumables = appServices.shopInventory.consumableSnapshot()
        return purchasedSet.count
            + consumables.avatar2DExtraPassCount
            + consumables.backdatePassCount
            + (consumables.isDoubleRewardBoostActive ? 1 : 0)
            + ((consumables.streakShieldExpiry ?? .distantPast) > Date() ? 1 : 0)
    }

    var shopGridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                switch dataState {
                case .loading:
                    shopLoadingState
                case .failed:
                    shopFailureState
                case .loaded:
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 14)

                        categoryRail
                            .padding(.bottom, 12)

                        categoryIntro
                            .padding(.horizontal, 20)
                            .padding(.bottom, effectiveSelectedCategory == .plantDecor ? 12 : 0)

                        if !purchaseSettlements.isEmpty || !blockedPurchaseItemIDs.isEmpty {
                            purchaseSettlementNotice
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                        }

                        ScrollView {
                            if effectiveSelectedCategory == .cashExchange {
                                cashExchangeSection
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 36)
                            } else {
                                LazyVGrid(columns: shopGridColumns, spacing: 12) {
                                    ForEach(filteredItems) { item in
                                        shopItemCard(item)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 36)
                            }
                        }
                    }
                }

                if let toast {
                    toastView(toast)
                        .transition(.ohanaPop)
                        .zIndex(20)
                }
            }
            .navigationTitle(l.tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokosnuss-Shop"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) { dismiss() }
                }
            }
        }
        .tint(Color.goPrimary)
        .sheet(isPresented: $showInventory) {
            InventoryView()
                .ohanaSheetPagePresentation()
        }
        .sheet(item: $equipPopoutPet) { pet in
            EquipPopoutCardSheet(pet: pet)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $pendingPurchaseItem) { item in
            NavigationStack {
                ScrollView {
                    purchaseConfirmation(item: item)
                        .padding(20)
                }
                    .navigationTitle(l.tr(zh: "确认兑换", en: "Confirm redemption", de: "Einlösen bestätigen"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(l.cancel) {
                                pendingPurchaseItem = nil
                            }
                            .disabled(purchaseInFlightItemID != nil)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(purchaseInFlightItemID != nil)
        }
        .sheet(item: $activePicker) { picker in
            NavigationStack {
                pickerContent(picker)
                    .navigationTitle(pickerTitle(picker))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(l.cancel) { activePicker = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if !selectedCategory.isVisibleInFirstRelease {
                selectedCategory = .appIcon
            }
            selectedAppIcon = appServices.appIcons.currentDescriptor.itemId
        }
        .onChange(of: pendingPurchaseItem?.id) { _, itemID in
            purchaseErrorMessage = nil
            purchaseRetryBlocked = false
            if itemID == nil { purchaseInFlightItemID = nil }
        }
        .onDisappear {
            toastTask?.cancel()
            toastTask = nil
        }
    }

    var shopLoadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(l.tr(zh: "正在读取可用椰子与已购内容…", en: "Loading spendable coconuts and purchases…", de: "Verfügbare Kokosnüsse und Käufe werden geladen…"))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: shopGridColumns, spacing: 12) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .fill(Color.ohanaCardSurface)
                        .frame(height: 190)
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("coconut-shop-loading")
    }

    var shopFailureState: some View {
        ContentUnavailableView {
            Label(
                l.tr(zh: "商店暂时无法读取", en: "Shop data is unavailable", de: "Shop-Daten sind nicht verfügbar"),
                systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
            )
        } description: {
            Text(l.tr(zh: "你的余额和已购内容没有被当作空数据处理。请重试。", en: "Your balance and purchases were not treated as empty. Please try again.", de: "Guthaben und Käufe wurden nicht als leer behandelt. Bitte versuche es erneut."))
        } actions: {
            Button(l.tr(zh: "重新加载", en: "Reload", de: "Neu laden"), action: retryDataLoad)
                .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("coconut-shop-load-failed")
    }
}
