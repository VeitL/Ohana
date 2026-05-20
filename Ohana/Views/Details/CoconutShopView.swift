import SwiftUI
import SwiftData

struct CoconutShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \CoconutExchangeRequest.createdAt, order: .reverse) private var exchangeRequests: [CoconutExchangeRequest]

    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("purchasedShopItems") private var purchasedRaw = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""
    @AppStorage("shop_equipped_title") private var equippedTitle = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow = false
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow = false
    @AppStorage("shop_equip_fx_rainbow_poop") private var equipFxRainbowPoop = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard = true
    @AppStorage("shop_equip_fx_stars") private var equipFxStars = false
    @AppStorage("shop_equip_fx_firework") private var equipFxFirework = false
    @AppStorage(AppIconCatalog.selectedIconKey) private var selectedAppIcon = AppIconCatalog.defaultItemId

    @State private var questManager = QuestManager.shared
    @State private var selectedCategory: ShopItem.ShopCategory
    @State private var pendingPurchaseItem: ShopItem?
    @State private var activePicker: ShopPicker?
    @State private var equipPopoutPet: Pet?
    @State private var toast: ShopToast?
    @State private var toastTask: Task<Void, Never>?
    @State private var confettiItems: [ConfettiDrop] = []
    @State private var exchangeReceiverId = ""
    @State private var exchangeOptionId = ""
    @State private var exchangeNote = ""

    init(initialCategory: ShopItem.ShopCategory = .appIcon) {
        _selectedCategory = State(initialValue: initialCategory)
    }

    private enum ShopPicker: Identifiable {
        case avatarTarget
        case popoutPet
        case cashExchange

        var id: String {
            switch self {
            case .avatarTarget: return "avatarTarget"
            case .popoutPet: return "popoutPet"
            case .cashExchange: return "cashExchange"
            }
        }
    }

    private struct ShopToast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let icon: String
        let tint: Color
    }

    private struct ConfettiDrop: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let delay: Double
    }

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }

    private var purchasedSet: Set<String> {
        Set(purchasedRaw.split(separator: ",").map(String.init))
    }

    private var allItems: [ShopItem] {
        ShopCatalog.allItems(purchasedSet: purchasedSet)
    }

    private var filteredItems: [ShopItem] {
        allItems.filter { $0.category == selectedCategory }
    }

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId } ?? humans.first
    }

    private var otherHumans: [Human] {
        guard let currentHuman else { return [] }
        return humans.filter { $0.id != currentHuman.id }
    }

    private var currentHumanBalance: Int {
        currentHuman?.coconutBalance ?? 0
    }

    private var exchangeOptions: [CoconutExchangeOption] {
        CoconutExchangeOption.options()
    }

    private var selectedExchangeOption: CoconutExchangeOption? {
        exchangeOptions.first { $0.id == exchangeOptionId } ?? exchangeOptions.first
    }

    private var selectedExchangeReceiver: Human? {
        otherHumans.first { $0.id.uuidString == exchangeReceiverId } ?? otherHumans.first
    }

    private var incomingPendingExchanges: [CoconutExchangeRequest] {
        guard let currentHuman else { return [] }
        return exchangeRequests.filter { $0.status == .pending && $0.receiverId == currentHuman.id.uuidString }
    }

    private var outgoingPendingExchanges: [CoconutExchangeRequest] {
        guard let currentHuman else { return [] }
        return exchangeRequests.filter { $0.status == .pending && $0.senderId == currentHuman.id.uuidString }
    }

    private var ownedCount: Int {
        purchasedSet.count + Avatar2DAccess.extraPassCount
    }

    private var isPopupActive: Bool {
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
                    if selectedCategory == .cashExchange {
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
                    .font(.system(size: 24))
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
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            selectedAppIcon = AppIconService.currentDescriptor.itemId
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokosnuss-Shop"))
                        .font(OhanaFont.title(.black))
                        .foregroundStyle(primaryText)
                    Text(l.tr(zh: "买断外观、称号和 App Icon。", en: "Unlock looks, titles, and App Icons.", de: "Schalte Looks, Titel und App Icons frei."))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }

            HStack(spacing: 18) {
                metric(label: l.tr(zh: "本人余额", en: "My balance", de: "Mein Guthaben"), value: "\(currentHumanBalance)", suffix: "🥥", tint: Color.goYellow)
                metric(label: l.tr(zh: "已拥有", en: "Owned", de: "Besitzt"), value: "\(ownedCount)", suffix: "", tint: Color.goPrimary)
                metric(label: l.tr(zh: "待确认", en: "Pending", de: "Offen"), value: "\(incomingPendingExchanges.count)", suffix: "", tint: Color.goTeal)
            }
        }
    }

    private func metric(label: String, value: String, suffix: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(tertiaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 22, .black))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                    .animation(GoMotion.feedback, value: value)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedAppIconShortName: String {
        guard let item = ShopCatalog.item(id: selectedAppIcon, purchasedSet: purchasedSet) else {
            return "Ohana"
        }
        return item.name(l)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopItem.ShopCategory.allCases) { category in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, weight: .black))
                            Text(category.title(l))
                                .font(OhanaFont.caption(.black))
                        }
                        .foregroundStyle(selectedCategory == category ? Color.ohanaPrimaryActionText : primaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(selectedCategory == category ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var cashExchangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                openCashExchangeForm()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.goYellow.opacity(colorScheme == .dark ? 0.2 : 0.16))
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(Color.goYellow)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "家庭线下兑现", en: "Family cash note", de: "Familien-Auszahlung"))
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(primaryText)
                        Text(l.tr(
                            zh: "只记录谁兑换给谁，不处理真实支付。",
                            en: "Records who should pay whom offline. No real payment in app.",
                            de: "Notiert nur, wer offline zahlt. Keine echte Zahlung in der App."
                        ))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .ohanaSymbolPulse(trigger: activePicker?.id ?? "")
                        .ohanaPing(
                            trigger: incomingPendingExchanges.count,
                            accent: Color.goYellow,
                            isEnabled: !incomingPendingExchanges.isEmpty
                        )
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if !incomingPendingExchanges.isEmpty {
                exchangeList(
                    title: l.tr(zh: "待你确认", en: "Waiting for you", de: "Wartet auf dich"),
                    requests: incomingPendingExchanges,
                    mode: .incoming
                )
            }

            if !outgoingPendingExchanges.isEmpty {
                exchangeList(
                    title: l.tr(zh: "已发出", en: "Sent", de: "Gesendet"),
                    requests: outgoingPendingExchanges,
                    mode: .outgoing
                )
            }

            if incomingPendingExchanges.isEmpty && outgoingPendingExchanges.isEmpty {
                Text(l.tr(
                    zh: "暂无待处理兑换。兑换是家庭内部的线下兑现记录，确认收到后才完成。",
                    en: "No pending exchanges. Exchanges are offline family notes and finish after the receiver confirms.",
                    de: "Keine offenen Tausche. Sie sind Offline-Notizen und werden erst nach Bestätigung abgeschlossen."
                ))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private enum ExchangeListMode {
        case incoming
        case outgoing
    }

    private func exchangeList(title: String, requests: [CoconutExchangeRequest], mode: ExchangeListMode) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(tertiaryText)
            ForEach(requests) { request in
                exchangeRow(request, mode: mode)
            }
        }
    }

    private func exchangeRow(_ request: CoconutExchangeRequest, mode: ExchangeListMode) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(request.senderName) → \(request.receiverName)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(primaryText)
                Text("\(CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)) · \(request.coconutCost)🥥")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            switch mode {
            case .incoming:
                Button {
                    confirmExchange(request)
                } label: {
                    Text(l.tr(zh: "已收到", en: "Received", de: "Erhalten"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            case .outgoing:
                Button {
                    cancelExchange(request)
                } label: {
                    Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func shopItemCard(_ item: ShopItem) -> some View {
        let state = itemState(item)
        return Button {
            handleItemTap(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                itemPreview(item)
                    .frame(height: previewHeight(for: item))
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name(l))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        if state.isEquipped {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color.goPrimary)
                        }
                    }

                    Text(item.description(l))
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(state.label)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(state.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    if showsShopSwitch(for: item) {
                        shopTogglePill(isOn: state.isEquipped)
                    } else if state.showCost {
                        Text("🥥 \(item.cost)")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(canAfford(item) ? Color.goYellow : tertiaryText)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: item.category == .appIcon ? 214 : 198, alignment: .topLeading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(state.isEquipped ? Color.goPrimary.opacity(0.52) : Color.clear, lineWidth: 1.5)
            }
            .ohanaMarchingBorder(accent: state.tint, cornerRadius: 22, isActive: state.isEquipped)
            .ohanaShine(trigger: state.isEquipped, cornerRadius: 22, isEnabled: state.isEquipped)
            .opacity(state.isDisabled ? 0.58 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(itemState(item).isDisabled)
    }

    @ViewBuilder
    private func itemPreview(_ item: ShopItem) -> some View {
        if let icon = item.appIcon {
            AppIconPreview(descriptor: icon, isSelected: itemState(item).isEquipped)
        } else {
            ShopAppliedPreview(
                item: item,
                human: currentHuman,
                pet: pets.first,
                isEquipped: itemState(item).isEquipped,
                appLanguage: appLanguage
            )
        }
    }

    private func previewHeight(for item: ShopItem) -> CGFloat {
        switch item.category {
        case .appIcon:
            return 108
        case .avatar2d, .effect, .title_, .boost:
            return 96
        case .cashExchange:
            return 92
        }
    }

    private struct ItemState {
        var label: String
        var tint: Color
        var showCost: Bool = false
        var isEquipped: Bool = false
        var isDisabled: Bool = false
    }

    private func itemState(_ item: ShopItem) -> ItemState {
        if let appIcon = item.appIcon {
            if !appIcon.isDefault && !AppIconService.supportsAlternateIcons {
                return .init(label: l.tr(zh: "设备不支持", en: "Unsupported", de: "Nicht unterstützt"), tint: tertiaryText, isDisabled: true)
            }
            let isCurrent = AppIconService.currentDescriptor.itemId == appIcon.itemId
            if isCurrent {
                return .init(label: l.tr(zh: "使用中", en: "In use", de: "Aktiv"), tint: Color.goPrimary, isEquipped: true)
            }
            if item.isPurchased {
                return .init(label: l.tr(zh: "点击切换", en: "Tap to switch", de: "Zum Wechseln tippen"), tint: Color.goTeal)
            }
            let missing = max(0, item.cost - currentHumanBalance)
            return .init(label: canAfford(item) ? l.tr(zh: "买断", en: "Unlock", de: "Freischalten") : l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥", de: "Noch \(missing)🥥"), tint: canAfford(item) ? Color.goYellow : tertiaryText, showCost: true)
        }

        if item.id == Avatar2DAccess.shopItemId, Avatar2DAccess.extraPassCount > 0 {
            return .init(
                label: l.tr(
                    zh: "库存 \(Avatar2DAccess.extraPassCount) 张",
                    en: "\(Avatar2DAccess.extraPassCount) available",
                    de: "\(Avatar2DAccess.extraPassCount) verfügbar"
                ),
                tint: Color.goPrimary,
                isEquipped: true
            )
        }

        if item.isPurchased {
            return .init(label: ownedItemStatus(for: item), tint: Color.goPrimary, isEquipped: isOwnedItemEquipped(item))
        }

        if let status = activeConsumableStatus(for: item) {
            return .init(label: status, tint: Color.goPrimary)
        }

        return .init(label: canAfford(item) ? l.tr(zh: "兑换", en: "Redeem", de: "Einlösen") : l.tr(zh: "不足", en: "Not enough", de: "Zu wenig"), tint: canAfford(item) ? Color.goYellow : tertiaryText, showCost: true)
    }

    private func canAfford(_ item: ShopItem) -> Bool {
        item.cost <= 0 || currentHumanBalance >= item.cost
    }

    private func handleItemTap(_ item: ShopItem) {
        if let appIcon = item.appIcon {
            handleAppIconTap(item, descriptor: appIcon)
            return
        }

        if item.isPurchased {
            toggleOwnedItem(item)
            return
        }

        if item.id == Avatar2DAccess.shopItemId, Avatar2DAccess.extraPassCount > 0 {
            openAvatarUpgradeTargetPicker()
            return
        }

        if activeConsumableStatus(for: item) != nil {
            showToast(l.tr(zh: "这个道具已经生效。", en: "This boost is already active.", de: "Dieser Boost ist bereits aktiv."), icon: "checkmark.circle.fill", tint: Color.goTeal)
            return
        }

        guard canAfford(item) else {
            let missing = max(0, item.cost - currentHumanBalance)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }

        pendingPurchaseItem = item
    }

    private func handleAppIconTap(_ item: ShopItem, descriptor: AppIconShopDescriptor) {
        if item.isPurchased {
            applyAppIcon(descriptor, successMessage: l.tr(zh: "App Icon 已切换", en: "App Icon changed", de: "App Icon geändert"))
            return
        }

        guard AppIconService.supportsAlternateIcons else {
            showToast(l.tr(zh: "当前设备不支持切换 App Icon", en: "This device cannot change App Icons", de: "Dieses Gerät kann App Icons nicht ändern"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }

        guard canAfford(item) else {
            let missing = max(0, item.cost - currentHumanBalance)
            showToast(l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }

        pendingPurchaseItem = item
    }

    private func purchaseConfirmation(item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            popupHeader(
                icon: item.appIcon == nil ? item.emoji : "",
                sfSymbol: item.appIcon?.previewSymbol,
                title: l.tr(zh: "确认兑换", en: "Confirm unlock", de: "Einlösen bestätigen"),
                subtitle: item.name(l)
            ) {
                pendingPurchaseItem = nil
            }

            HStack(spacing: 12) {
                itemPreview(item)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.description(l))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                    Text(l.tr(zh: "将消耗 \(item.cost) 个椰子。", en: "Costs \(item.cost) coconuts.", de: "Kostet \(item.cost) Kokosnüsse."))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goYellow)
                }
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button {
                confirmPurchase(item)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(l.tr(zh: "兑换 / 使用", en: "Unlock / Use", de: "Einlösen / Nutzen"))
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func pickerContent(_ picker: ShopPicker) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch picker {
            case .avatarTarget:
                popupHeader(icon: "🖼️", sfSymbol: nil, title: l.tr(zh: "选择头像对象", en: "Choose avatar target", de: "Avatar-Ziel wählen"), subtitle: l.tr(zh: "库存 \(Avatar2DAccess.extraPassCount) 张", en: "\(Avatar2DAccess.extraPassCount) available", de: "\(Avatar2DAccess.extraPassCount) verfügbar")) {
                    activePicker = nil
                }
                targetList
            case .popoutPet:
                popupHeader(icon: "🃏", sfSymbol: nil, title: l.tr(zh: "绑定破框卡片", en: "Bind popout card", de: "Popout-Karte binden"), subtitle: l.tr(zh: "选择一个宠物", en: "Choose one pet", de: "Wähle ein Tier")) {
                    activePicker = nil
                }
                petPickerList
            case .cashExchange:
                popupHeader(icon: "💱", sfSymbol: nil, title: l.tr(zh: "货币兑换", en: "Cash exchange", de: "Geldtausch"), subtitle: l.tr(zh: "家庭内部线下兑现记录", en: "Offline family note", de: "Offline-Familiennotiz")) {
                    activePicker = nil
                }
                cashExchangeForm
            }
        }
    }

    private var targetList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if Avatar2DAccess.extraPassCount <= 0 {
                    emptyPickerText(l.tr(zh: "暂无可用头像券。", en: "No avatar passes available.", de: "Keine Avatarpässe verfügbar."))
                } else if humans.isEmpty && pets.isEmpty {
                    emptyPickerText(l.tr(zh: "请先创建一个人类或宠物成员。", en: "Create a human or pet first.", de: "Erstelle zuerst einen Menschen oder ein Tier."))
                } else {
                    ForEach(humans) { human in
                        targetRow(icon: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji, title: human.name, subtitle: l.tr(zh: "人类", en: "Human", de: "Mensch")) {
                            upgradeHumanTo2DAvatar(human)
                        }
                    }
                    ForEach(pets) { pet in
                        targetRow(icon: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji, title: pet.name, subtitle: l.tr(zh: "宠物", en: "Pet", de: "Tier")) {
                            upgradePetTo2DAvatar(pet)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private var petPickerList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if pets.isEmpty {
                    emptyPickerText(l.tr(zh: "还没有宠物可以绑定。", en: "No pet to bind yet.", de: "Noch kein Tier zum Binden."))
                } else {
                    ForEach(pets) { pet in
                        targetRow(icon: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji, title: pet.name, subtitle: pet.species) {
                            activePicker = nil
                            equipPopoutPet = pet
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 340)
    }

    private var cashExchangeForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            if currentHuman == nil {
                emptyPickerText(l.tr(zh: "请先创建当前人类账户。", en: "Create a current human account first.", de: "Erstelle zuerst ein aktuelles Menschenkonto."))
            } else if otherHumans.isEmpty {
                emptyPickerText(l.tr(zh: "需要至少另一位家庭成员才能兑换。", en: "Add another family member before exchanging.", de: "Füge zuerst ein weiteres Familienmitglied hinzu."))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "接收人", en: "Receiver", de: "Empfänger"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tertiaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(otherHumans) { human in
                                exchangeChip(
                                    title: human.name,
                                    isSelected: exchangeReceiverId == human.id.uuidString || (exchangeReceiverId.isEmpty && selectedExchangeReceiver?.id == human.id)
                                ) {
                                    withAnimation(GoMotion.feedback) {
                                        exchangeReceiverId = human.id.uuidString
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "档位", en: "Amount", de: "Betrag"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tertiaryText)
                    ForEach(exchangeOptions) { option in
                        Button {
                            withAnimation(GoMotion.feedback) {
                                exchangeOptionId = option.id
                            }
                        } label: {
                            HStack {
                                Text("\(option.coconutCost)🥥")
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(primaryText)
                                Spacer()
                                Text(option.formattedAmount)
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(exchangeOptionId == option.id || (exchangeOptionId.isEmpty && selectedExchangeOption?.id == option.id) ? Color.goPrimary : secondaryText)
                            }
                            .padding(12)
                            .background(
                                exchangeOptionId == option.id || (exchangeOptionId.isEmpty && selectedExchangeOption?.id == option.id)
                                ? Color.goPrimary.opacity(colorScheme == .dark ? 0.2 : 0.14)
                                : Color.ohanaCardSurface,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                TextField(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"), text: $exchangeNote, axis: .vertical)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(primaryText)
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    createExchange()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(exchangeConfirmTitle)
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canCreateExchange ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canCreateExchange)
            }
        }
    }

    private var exchangeConfirmTitle: String {
        guard let option = selectedExchangeOption else {
            return l.tr(zh: "确认兑换", en: "Confirm exchange", de: "Tausch bestätigen")
        }
        return l.tr(
            zh: "消耗 \(option.coconutCost)🥥",
            en: "Spend \(option.coconutCost)🥥",
            de: "\(option.coconutCost)🥥 ausgeben"
        )
    }

    private var canCreateExchange: Bool {
        guard let option = selectedExchangeOption else { return false }
        return selectedExchangeReceiver != nil && currentHumanBalance >= option.coconutCost
    }

    private func exchangeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : primaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isSelected ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func targetRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(tertiaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(tertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func emptyPickerText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func popupHeader(icon: String, sfSymbol: String?, title: String, subtitle: String, close: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.ohanaControlFill)
                if let sfSymbol {
                    Image(systemName: sfSymbol)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                } else {
                    Text(icon)
                        .font(.system(size: 24))
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            OhanaPopupCloseButton(tint: primaryText, action: close)
        }
    }

    private func inlinePopup<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12), Color.black.opacity(colorScheme == .dark ? 0.46 : 0.24)], // ui-v4: allow modal scrim
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    pendingPurchaseItem = nil
                    activePicker = nil
                }

                VStack(spacing: 0) {
                    OhanaPopupDragHandle(tint: primaryText.opacity(0.24))
                        .padding(.top, 8)
                        .gesture(
                            DragGesture(minimumDistance: 12).onEnded { value in
                                if value.translation.height > 32 {
                                    withAnimation(GoMotion.page) {
                                        pendingPurchaseItem = nil
                                        activePicker = nil
                                    }
                                }
                            }
                        )
                    VStack(spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .background { OhanaPopupGlassSurface(cornerRadius: 54) }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.22), radius: 34, x: 0, y: -10) // ui-v4: allow lifted overlay shadow
                .padding(.horizontal, 6)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .bottom)))
            }
            .animation(GoMotion.page, value: pendingPurchaseItem?.id)
            .animation(GoMotion.page, value: activePicker?.id)
        }
    }

    private func toastView(_ toast: ShopToast) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: toast.icon)
                    .font(.system(size: 15, weight: .black))
                    .ohanaSymbolPulse(trigger: toast.id)
                Text(toast.message)
                    .font(OhanaFont.callout(.black))
                    .lineLimit(2)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(toast.tint, in: Capsule())
            .shadow(color: toast.tint.opacity(0.32), radius: 18, x: 0, y: 8) // ui-v4: allow toast elevation
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func openCashExchangeForm() {
        if exchangeReceiverId.isEmpty {
            exchangeReceiverId = otherHumans.first?.id.uuidString ?? ""
        }
        if exchangeOptionId.isEmpty {
            exchangeOptionId = exchangeOptions.first?.id ?? ""
        }
        activePicker = .cashExchange
    }

    private func createExchange() {
        guard let sender = currentHuman, let receiver = selectedExchangeReceiver, let option = selectedExchangeOption else { return }
        do {
            try CoconutExchangeService.createRequest(
                sender: sender,
                receiver: receiver,
                option: option,
                note: exchangeNote,
                context: modelContext
            )
            activePicker = nil
            exchangeNote = ""
            showToast(l.tr(zh: "兑换申请已发出", en: "Exchange sent", de: "Tausch gesendet"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    private func confirmExchange(_ request: CoconutExchangeRequest) {
        guard let currentHuman else { return }
        do {
            try CoconutExchangeService.confirm(request, by: currentHuman, context: modelContext)
            showToast(l.tr(zh: "已确认收到", en: "Marked received", de: "Erhalt bestätigt"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    private func cancelExchange(_ request: CoconutExchangeRequest) {
        guard let currentHuman else { return }
        do {
            try CoconutExchangeService.cancel(request, by: currentHuman, context: modelContext)
            showToast(l.tr(zh: "已取消并退回椰子", en: "Cancelled and refunded", de: "Abgebrochen und erstattet"), icon: "arrow.uturn.backward.circle.fill", tint: Color.goTeal)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(exchangeErrorMessage(error), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
        }
    }

    private func exchangeErrorMessage(_ error: Error) -> String {
        guard let exchangeError = error as? CoconutExchangeError else {
            return error.localizedDescription
        }
        switch exchangeError {
        case .sameReceiver:
            return l.tr(zh: "不能发给自己。", en: "You cannot send this to yourself.", de: "Du kannst es nicht an dich selbst senden.")
        case .insufficientBalance:
            return l.tr(zh: "椰子余额不足。", en: "Not enough coconuts.", de: "Nicht genug Kokosnüsse.")
        case .invalidReceiver:
            return l.tr(zh: "请选择一个家庭成员。", en: "Choose a family member.", de: "Wähle ein Familienmitglied.")
        case .notPending:
            return l.tr(zh: "这个兑换已经处理。", en: "This exchange was already handled.", de: "Dieser Tausch wurde bereits bearbeitet.")
        case .notSender:
            return l.tr(zh: "只有发起人可以取消。", en: "Only the sender can cancel.", de: "Nur der Absender kann abbrechen.")
        case .notReceiver:
            return l.tr(zh: "只有接收人可以确认。", en: "Only the receiver can confirm.", de: "Nur der Empfänger kann bestätigen.")
        }
    }

    private func confirmPurchase(_ item: ShopItem) {
        if let descriptor = item.appIcon {
            purchaseAndApplyAppIcon(item, descriptor: descriptor)
        } else {
            purchase(item)
        }
    }

    private func purchaseAndApplyAppIcon(_ item: ShopItem, descriptor: AppIconShopDescriptor) {
        guard canAfford(item) else { return }
        AppIconService.setIcon(descriptor) { result in
            switch result {
            case .success:
                guard spendCoconuts(item) else { return }
                markPurchased(item)
                selectedAppIcon = descriptor.itemId
                pendingPurchaseItem = nil
                showPurchaseSuccess(item)
            case .failure(let error):
                pendingPurchaseItem = nil
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            }
        }
    }

    private func applyAppIcon(_ descriptor: AppIconShopDescriptor, successMessage: String) {
        AppIconService.setIcon(descriptor) { result in
            switch result {
            case .success:
                selectedAppIcon = descriptor.itemId
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast(successMessage, icon: "checkmark.circle.fill", tint: Color.goPrimary)
            case .failure(let error):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            }
        }
    }

    private func purchase(_ item: ShopItem) {
        guard spendCoconuts(item) else { return }
        if item.isConsumable {
            activateBoost(item)
        } else {
            markPurchased(item)
            activateOwnedItem(item)
        }

        pendingPurchaseItem = nil
        showPurchaseSuccess(item)

        if item.id == "fx_popout_card" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openPopoutPetPicker()
            }
        } else if item.id == Avatar2DAccess.shopItemId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openAvatarUpgradeTargetPicker()
            }
        }
    }

    @discardableResult
    private func spendCoconuts(_ item: ShopItem) -> Bool {
        guard item.cost > 0 else { return true }
        guard let currentHuman, currentHuman.coconutBalance >= item.cost else {
            let missing = max(0, item.cost - currentHumanBalance)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return false
        }
        currentHuman.coconutBalance -= item.cost
        questManager.recordCoconutDelta(
            -item.cost,
            emoji: item.emoji,
            title: l.tr(zh: "兑换「\(item.name(l))」", en: "Redeemed \(item.name(l))", de: "\(item.name(l)) eingelöst"),
            actorId: currentHuman.id.uuidString,
            actorName: currentHuman.name
        )
        CareLedgerService.record(
            actorKind: .human,
            actorId: currentHuman.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "shopPurchase",
            note: item.name(l),
            source: .economy,
            coconutDelta: -item.cost,
            metadataJSON: "{\"shopItemId\":\"\(item.id)\"}",
            context: modelContext,
            save: false
        )
        modelContext.safeSave()
        return true
    }

    private func markPurchased(_ item: ShopItem) {
        guard !item.isConsumable else { return }
        var current = purchasedSet
        current.insert(item.id)
        purchasedRaw = current.sorted().joined(separator: ",")
    }

    private func showPurchaseSuccess(_ item: ShopItem) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        spawnConfetti()
        let message = item.isConsumable
            ? l.tr(zh: "「\(item.name(l))」已生效", en: "\(item.name(l)) is active", de: "\(item.name(l)) ist aktiv")
            : l.tr(zh: "「\(item.name(l))」已加入百宝箱", en: "\(item.name(l)) unlocked", de: "\(item.name(l)) freigeschaltet")
        showToast(message, icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }

    private func showToast(_ message: String, icon: String, tint: Color) {
        toastTask?.cancel()
        withAnimation(GoMotion.feedback) {
            toast = ShopToast(message: message, icon: icon, tint: tint)
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            await MainActor.run {
                withAnimation(GoMotion.feedback) {
                    toast = nil
                }
            }
        }
    }

    private func spawnConfetti() {
        confettiItems = (0..<12).map { index in
            ConfettiDrop(emoji: ["🥥", "✦", "●", "✨"].randomElement() ?? "🥥", x: CGFloat.random(in: 36...360), delay: Double(index) * 0.025)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            confettiItems.removeAll()
        }
    }

    private func activateBoost(_ item: ShopItem) {
        switch item.id {
        case "boost_tree", "boost_tree_large":
            OasisTreeManager.shared.injectedEnergy += item.id == "boost_tree_large" ? 110 : 30
            OasisTreeManager.shared.checkAndRewardLevelUp(modelContext: modelContext)
        case "boost_double":
            UserDefaults.standard.set(true, forKey: "shop_boostDoubleActive")
        case "boost_streak":
            UserDefaults.standard.set(Date().addingTimeInterval(172800), forKey: "shop_streakShieldExpiry")
        case "boost_backdate_single", "boost_backdate_pack":
            let key = "inventory_backdate_1day_count"
            let cur = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(cur + (item.id == "boost_backdate_pack" ? 3 : 1), forKey: key)
        case Avatar2DAccess.shopItemId:
            Avatar2DAccess.addExtraPasses(1)
        default:
            break
        }
    }

    private func activateOwnedItem(_ item: ShopItem) {
        switch item.id {
        case "fx_lime_glow":
            equipFxLimeGlow = true
        case "fx_rainbow":
            equipFxRainbow = true
        case "fx_rainbow_poop":
            equipFxRainbowPoop = true
        case "fx_popout_card":
            equipFxPopoutCard = true
        case "fx_stars":
            equipFxStars = true
        case "fx_firework":
            equipFxFirework = true
        case "title_guardian", "title_pioneer", "title_chef":
            equippedTitle = item.id
        default:
            break
        }
    }

    private func toggleOwnedItem(_ item: ShopItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item.id {
        case "fx_lime_glow":
            equipFxLimeGlow.toggle()
        case "fx_rainbow":
            equipFxRainbow.toggle()
        case "fx_rainbow_poop":
            equipFxRainbowPoop.toggle()
        case "fx_popout_card":
            equipFxPopoutCard.toggle()
            if equipFxPopoutCard && !pets.contains(where: { $0.cardStyleRaw == "popout" }) {
                openPopoutPetPicker()
            }
        case "fx_stars":
            equipFxStars.toggle()
        case "fx_firework":
            equipFxFirework.toggle()
        case "title_guardian", "title_pioneer", "title_chef":
            equippedTitle = equippedTitle == item.id ? "" : item.id
        default:
            break
        }
        showToast(ownedItemStatus(for: item), icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }

    private func ownedItemStatus(for item: ShopItem) -> String {
        switch item.id {
        case "fx_lime_glow":
            return equipFxLimeGlow ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_rainbow":
            return equipFxRainbow ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_rainbow_poop":
            return equipFxRainbowPoop ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_popout_card":
            if !equipFxPopoutCard {
                return l.tr(zh: "未启用", en: "Off", de: "Aus")
            }
            return pets.contains { $0.cardStyleRaw == "popout" }
                ? l.tr(zh: "已启用 · 可更换", en: "On · Change", de: "Aktiv · Ändern")
                : l.tr(zh: "选择宠物/素材", en: "Choose pet/asset", de: "Tier/Motiv wählen")
        case "fx_stars":
            return equipFxStars ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "fx_firework":
            return equipFxFirework ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus")
        case "title_guardian", "title_pioneer", "title_chef":
            return equippedTitle == item.id ? l.tr(zh: "已装备", en: "Equipped", de: "Ausgerüstet") : l.tr(zh: "未装备", en: "Not equipped", de: "Nicht ausgerüstet")
        default:
            return item.isPurchased ? l.tr(zh: "已拥有", en: "Owned", de: "Besitzt") : ""
        }
    }

    private func isOwnedItemEquipped(_ item: ShopItem) -> Bool {
        switch item.id {
        case "fx_lime_glow": return equipFxLimeGlow
        case "fx_rainbow": return equipFxRainbow
        case "fx_rainbow_poop": return equipFxRainbowPoop
        case "fx_popout_card": return equipFxPopoutCard && pets.contains { $0.cardStyleRaw == "popout" }
        case "fx_stars": return equipFxStars
        case "fx_firework": return equipFxFirework
        case "title_guardian", "title_pioneer", "title_chef": return equippedTitle == item.id
        default: return false
        }
    }

    private func showsShopSwitch(for item: ShopItem) -> Bool {
        if item.id == Avatar2DAccess.shopItemId {
            return Avatar2DAccess.extraPassCount > 0
        }
        if item.category == .title_ {
            return item.isPurchased
        }
        return item.isPurchased && isToggleableEffect(item)
    }

    private func isToggleableEffect(_ item: ShopItem) -> Bool {
        switch item.id {
        case "fx_lime_glow", "fx_rainbow", "fx_rainbow_poop", "fx_popout_card", "fx_stars", "fx_firework":
            return true
        default:
            return false
        }
    }

    private func shopTogglePill(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? Color.goPrimary : Color.ohanaControlFill)
            .frame(width: 46, height: 26)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.58))
                    .frame(width: 18, height: 18)
                    .padding(.horizontal, 4)
            }
            .animation(GoMotion.selection, value: isOn)
            .accessibilityLabel(isOn ? l.tr(zh: "已启用", en: "On", de: "Aktiv") : l.tr(zh: "未启用", en: "Off", de: "Aus"))
    }

    private func activeConsumableStatus(for item: ShopItem) -> String? {
        switch item.id {
        case "boost_double":
            return UserDefaults.standard.bool(forKey: "shop_boostDoubleActive") ? l.tr(zh: "已激活", en: "Active", de: "Aktiv") : nil
        case "boost_streak":
            if let expiry = UserDefaults.standard.object(forKey: "shop_streakShieldExpiry") as? Date, expiry > Date() {
                return l.tr(zh: "保护中", en: "Protected", de: "Geschützt")
            }
            return nil
        case Avatar2DAccess.shopItemId:
            let count = Avatar2DAccess.extraPassCount
            return count > 0 ? l.tr(zh: "库存 \(count) 张", en: "\(count) available", de: "\(count) verfügbar") : nil
        default:
            return nil
        }
    }

    private func openAvatarUpgradeTargetPicker() {
        guard Avatar2DAccess.extraPassCount > 0 else {
            showToast(l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass available.", de: "Kein 2,5D-Avatarpass verfügbar."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        activePicker = .avatarTarget
    }

    private func openPopoutPetPicker() {
        if pets.count == 1 {
            equipPopoutPet = pets.first
        } else {
            activePicker = .popoutPet
        }
    }

    private func upgradeHumanTo2DAvatar(_ human: Human) {
        let rawGender = HumanProfileOptions.normalizedGender(human.genderRaw)
        let avatarGender: String
        switch rawGender {
        case "男", "女", "非二元":
            avatarGender = rawGender
        default:
            avatarGender = "非二元"
        }
        guard let data = HumanAvatarAssetCatalog.avatarData(gender: avatarGender, birthday: human.birthday) else {
            showToast(l.tr(zh: "请先补充性别或生日资料后再试。", en: "Add gender or birthday details first.", de: "Ergänze zuerst Geschlecht oder Geburtstag."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            showToast(l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass available.", de: "Kein 2,5D-Avatarpass verfügbar."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        human.avatarImageData = data
        human.avatarEmoji = HumanGenderIdentity.fallbackAvatarEmoji(for: avatarGender)
        modelContext.safeSave()
        activePicker = nil
        showToast(l.tr(zh: "\(human.name) 已升级 2.5D 头像", en: "\(human.name) now has a 2.5D avatar", de: "\(human.name) hat jetzt einen 2,5D-Avatar"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }

    private func upgradePetTo2DAvatar(_ pet: Pet) {
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor,
            eyeColor: pet.eyeColor
        ) else {
            showToast(l.tr(zh: "请先补充物种或品种资料后再试。", en: "Add species or breed details first.", de: "Ergänze zuerst Art oder Rasse."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            showToast(l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass available.", de: "Kein 2,5D-Avatarpass verfügbar."), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }
        pet.avatarImageData = data
        modelContext.safeSave()
        activePicker = nil
        showToast(l.tr(zh: "\(pet.name) 已升级 2.5D 头像", en: "\(pet.name) now has a 2.5D avatar", de: "\(pet.name) hat jetzt einen 2,5D-Avatar"), icon: "checkmark.circle.fill", tint: Color.goPrimary)
    }
}

private struct ShopAppliedPreview: View {
    let item: ShopItem
    let human: Human?
    let pet: Pet?
    let isEquipped: Bool
    let appLanguage: String

    @State private var animate = false

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color {
        switch item.category {
        case .appIcon: return Color.goPrimary
        case .avatar2d: return Color.goTeal
        case .cashExchange: return Color.goYellow
        case .effect: return Color.goPurple
        case .title_: return Color.goYellow
        case .boost: return Color.goOrange
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.22),
                            Color.ohanaControlFill,
                            Color.ohanaCardSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            switch item.category {
            case .avatar2d:
                avatarPassPreview
            case .effect:
                effectPreview
            case .title_:
                titlePreview
            case .boost:
                boostPreview
            case .cashExchange:
                cashPreview
            case .appIcon:
                EmptyView()
            }

            if isEquipped {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear {
            withAnimation(GoMotion.page) {
                animate = true
            }
        }
    }

    private var avatarPassPreview: some View {
        HStack(spacing: 9) {
            VStack(spacing: 3) {
                memberAvatar(size: 36)
                Text(l.tr(zh: "当前", en: "Now", de: "Jetzt"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(accent)
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 48, height: 42)
                    petAvatar(size: 54)
                        .offset(y: animate ? -4 : 2)
                }
                Text("2.5D")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var effectPreview: some View {
        switch item.id {
        case "fx_popout_card":
            popoutCardPreview
        case "fx_lime_glow":
            limeGlowPreview
        case "fx_rainbow":
            rainbowRoutePreview
        case "fx_rainbow_poop":
            rainbowPoopPreview
        case "fx_stars":
            stardustPreview
        case "fx_firework":
            fireworkPreview
        default:
            stardustPreview
        }
    }

    private var popoutCardPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: pet?.safeThemeColorHex ?? "5A67D8").opacity(0.34))
                .frame(height: 58)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            popoutSubject(size: 92)
                .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0), anchor: .bottomLeading, perspective: 0.55)
                .shadow(color: Color.arkInk.opacity(0.28), radius: 14, x: 0, y: 9) // ui-v4: allow popout preview depth
                .offset(x: 16, y: animate ? -18 : -7)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet?.name ?? l.tr(zh: "宠物", en: "Pet", de: "Tier"))
                    .font(OhanaFont.caption(.black))
                Text(l.tr(zh: "破框悬浮", en: "Popout", de: "Popout"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.leading, 86)
            .padding(.bottom, 24)
        }
    }

    private var limeGlowPreview: some View {
        HStack(spacing: 10) {
            petAvatar(size: 50)
                .padding(5)
                .background(Color.goPrimary.opacity(0.22), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.goPrimary.opacity(animate ? 0.82 : 0.28), lineWidth: 2)
                        .scaleEffect(animate ? 1.10 : 0.88)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "打卡完成", en: "Check-in done", de: "Check-in fertig"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("+2🥥")
                    .font(OhanaFont.metric(size: 20, .black))
                    .foregroundStyle(Color.goPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var rainbowRoutePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "遛狗路线", en: "Walk route", de: "Gassi-Route"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("1.8 km")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            HStack(spacing: 0) {
                ForEach([Color.goRed, .goOrange, .goYellow, .goTeal, .goPurple], id: \.description) { color in
                    Capsule()
                        .fill(color)
                        .frame(height: 7)
                        .scaleEffect(x: animate ? 1 : 0.45, anchor: .leading)
                }
            }
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
    }

    private var rainbowPoopPreview: some View {
        HStack(spacing: 12) {
            RainbowPoopPin(isRainbow: true, isFlowing: animate, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "路线事件", en: "Route event", de: "Routenereignis"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "便便标记发光", en: "Poop marker glows", de: "Kotmarker leuchtet"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var stardustPreview: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "每日委托", en: "Daily quest", de: "Tagesquest"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "星尘反馈", en: "Stardust feedback", de: "Sternenstaub"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: 9 + CGFloat(index), weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : Color.goPurple)
                    .offset(x: CGFloat(index * 18 - 26), y: animate ? CGFloat(-22 + index * 3) : 4)
                    .opacity(animate ? 1 : 0)
            }
        }
    }

    private var fireworkPreview: some View {
        ZStack {
            VStack(spacing: 4) {
                Image(systemName: "rosette")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .scaleEffect(animate ? 1 : 0.72)
                Text(l.tr(zh: "里程碑庆典", en: "Milestone", de: "Meilenstein"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill([Color.goYellow, .goOrange, .goPurple, .goTeal][index % 4])
                    .frame(width: 5, height: 5)
                    .offset(
                        x: animate ? cos(CGFloat(index) * .pi / 4) * 42 : 0,
                        y: animate ? sin(CGFloat(index) * .pi / 4) * 28 : 0
                    )
            }
        }
    }

    private var titlePreview: some View {
        HStack(spacing: 10) {
            memberAvatar(size: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(human?.name ?? l.tr(zh: "当前用户", en: "Current user", de: "Aktueller Nutzer"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(item.name(l))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.goYellow, in: Capsule())
                    .scaleEffect(animate ? 1 : 0.86)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var boostPreview: some View {
        switch item.id {
        case "boost_double":
            rewardBoostPreview(from: "+2🥥", to: "+4🥥", icon: "bolt.fill")
        case "boost_streak":
            streakShieldPreview
        case "boost_tree", "boost_tree_large":
            treeEnergyPreview
        case "boost_backdate_single", "boost_backdate_pack":
            backdatePreview
        default:
            rewardBoostPreview(from: "+2🥥", to: "+4🥥", icon: "bolt.fill")
        }
    }

    private func rewardBoostPreview(from: String, to: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.goOrange)
                .frame(width: 38, height: 38)
                .background(Color.goOrange.opacity(0.16), in: Circle())
            Text(from)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(to)
                .font(OhanaFont.metric(size: 21, .black))
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var streakShieldPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundStyle(Color.goTeal)
                Text(l.tr(zh: "连击保护", en: "Streak shield", de: "Streak-Schutz"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(index == 4 ? Color.goTeal : Color.goPrimary.opacity(0.72))
                        .frame(height: 18)
                        .overlay {
                            if index == 4 {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(Color.arkInk)
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private var treeEnergyPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "tree.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Color.goTeal)
            VStack(alignment: .leading, spacing: 8) {
                Text(l.tr(zh: "生命树能量", en: "Tree energy", de: "Baumenergie"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.ohanaCardSurface)
                        Capsule()
                            .fill(Color.goPrimary)
                            .frame(width: proxy.size.width * (animate ? 0.72 : 0.36))
                    }
                }
                .frame(height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var backdatePreview: some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(l.tr(zh: "昨天", en: "Yest.", de: "Gest."))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text("✓")
                    .font(OhanaFont.metric(size: 24, .black))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 54, height: 58)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "补签入库", en: "Backdate pass", de: "Nachtragspass"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.id == "boost_backdate_pack" ? "×3" : "×1")
                    .font(OhanaFont.metric(size: 22, .black))
                    .foregroundStyle(Color.goYellow)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var cashPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.goYellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("1000🥥 → \(CoconutExchangeOption.options().dropFirst().first?.formattedAmount ?? "$1")")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "家庭线下确认", en: "Offline confirm", de: "Offline bestätigen"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func memberAvatar(size: CGFloat) -> some View {
        if let human, let data = human.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(human?.avatarEmoji ?? "👤")
                .font(.system(size: size * 0.58))
                .frame(width: size, height: size)
                .background(Color.ohanaCardSurface, in: Circle())
        }
    }

    @ViewBuilder
    private func petAvatar(size: CGFloat) -> some View {
        if let pet, let data = pet.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let pet {
            PetSilhouetteView(
                species: pet.species,
                coatColor: Color(hex: pet.coatColor.isEmpty ? "E8C49A" : pet.coatColor),
                eyeColor: Color(hex: pet.eyeColor.isEmpty ? "6B3A2A" : pet.eyeColor),
                isAnimationEnabled: false
            )
            .frame(width: size, height: size)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(accent)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func popoutSubject(size: CGFloat) -> some View {
        if let pet,
           let data = pet.cardPopoutImageData ?? pet.avatarImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size * 1.12, alignment: .bottom)
        } else {
            petAvatar(size: size)
        }
    }
}

private struct AppIconPreview: View {
    let descriptor: AppIconShopDescriptor
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: descriptor.gradientHex.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: descriptor.previewSymbol)
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(descriptor.itemId == "appicon_minimal_o" ? Color.arkInk : Color.ohanaPrimaryActionText)
            }

            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var assetName: String {
        descriptor.alternateIconName ?? "AppIcon"
    }
}
