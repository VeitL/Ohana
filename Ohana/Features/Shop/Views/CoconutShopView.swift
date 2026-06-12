import SwiftData
import SwiftUI

struct CoconutShopView: View {
    let humans: [Human]
    let pets: [Pet]
    let exchangeRequests: [CoconutExchangeRequest]

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices

    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage("purchasedShopItems") var purchasedRaw = ""
    @AppStorage("currentActiveHumanId") var activeHumanId = ""
    @AppStorage("shop_equipped_title") var equippedTitle = ""
    @AppStorage("shop_equip_fx_lime_glow") var equipFxLimeGlow = false
    @AppStorage("shop_equip_fx_rainbow") var equipFxRainbow = false
    @AppStorage("shop_equip_fx_rainbow_poop") var equipFxRainbowPoop = false
    @AppStorage("shop_equip_fx_popout_card") var equipFxPopoutCard = true
    @AppStorage("shop_equip_fx_stars") var equipFxStars = false
    @AppStorage("shop_equip_fx_firework") var equipFxFirework = false
    @AppStorage(AppIconCatalog.selectedIconKey) var selectedAppIcon = AppIconCatalog.defaultItemId

    @State var selectedCategory: ShopItem.ShopCategory
    @State var pendingPurchaseItem: ShopItem?
    @State var activePicker: ShopPicker?
    @State var equipPopoutPet: Pet?
    @State var toast: ShopToast?
    @State var toastTask: Task<Void, Never>?
    @State var confettiItems: [ConfettiDrop] = []
    @State var exchangeReceiverId = ""
    @State var exchangeOptionId = ""
    @State var exchangeNote = ""

    init(
        initialCategory: ShopItem.ShopCategory = .appIcon,
        humans: [Human] = [],
        pets: [Pet] = [],
        exchangeRequests: [CoconutExchangeRequest] = []
    ) {
        self.humans = humans
        self.pets = pets
        self.exchangeRequests = exchangeRequests
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

    struct ConfettiDrop: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let delay: Double
    }

    @StateObject var commandQueue = DeferredDomainCommandQueue()

    var l: L10n { L10n(appLanguage) }
    var primaryText: Color { Color.ohanaPrimaryText }
    var secondaryText: Color { Color.ohanaSecondaryText }
    var tertiaryText: Color { Color.ohanaTertiaryText }

    var purchasedSet: Set<String> {
        Set(purchasedRaw.split(separator: ",").map(String.init))
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

    var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId } ?? humans.first
    }

    var otherHumans: [Human] {
        guard let currentHuman else { return [] }
        return humans.filter { $0.id != currentHuman.id }
    }

    var currentHumanBalance: Int {
        currentHuman?.coconutBalance ?? 0
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
        purchasedSet.count + Avatar2DAccess.extraPassCount
    }

    var isPopupActive: Bool {
        pendingPurchaseItem != nil || activePicker != nil
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                categoryRail
                    .padding(.bottom, 12)

                ScrollView {
                    if effectiveSelectedCategory == .cashExchange {
                        cashExchangeSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 36)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredItems) { item in
                                shopItemCard(item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 36)
                    }
                }
            }
            .disabled(isPopupActive)
            .blur(radius: isPopupActive ? 1.2 : 0)

            ForEach(confettiItems) { item in
                Text(item.emoji)
                    .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .position(x: item.x, y: -20)
                    .opacity(toast == nil ? 0 : 1)
                    .animation(GoMotion.feedback.delay(item.delay), value: toast)
            }

            if let toast {
                toastView(toast)
                    .transition(.ohanaPop)
                    .zIndex(20)
            }

            if let pendingPurchaseItem {
                inlinePopup {
                    purchaseConfirmation(item: pendingPurchaseItem)
                }
                .zIndex(40)
            }

            if let activePicker {
                inlinePopup {
                    pickerContent(activePicker)
                }
                .zIndex(40)
            }
        }
        .tint(Color.goPrimary)
        .sheet(item: $equipPopoutPet) { pet in
            EquipPopoutCardSheet(pet: pet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            if !selectedCategory.isVisibleInFirstRelease {
                selectedCategory = .appIcon
            }
            selectedAppIcon = appServices.appIcons.currentDescriptor.itemId
        }
    }
}
