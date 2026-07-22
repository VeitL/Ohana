//
//  InventoryView.swift
//  Ohana
//
//  椰子百宝箱 — 查看并装备已拥有的道具/特效/称号
//

import SwiftData
import SwiftUI

struct InventoryContentView: View {
    let pets: [Pet]
    let humans: [Human]
    let purchaseRecords: [ShopPurchaseRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.hasSupporterPackEntitlement) private var hasSupporterPack
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Equip states
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow: Bool = false
    @AppStorage("shop_equip_fx_rainbow_poop") private var equipFxRainbowPoop: Bool = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @AppStorage("shop_equip_fx_firework") private var equipFxFirework: Bool = false
    @AppStorage(OasisPlantDecorStore.equippedSceneKey) private var equippedPlantDecorScene = ""
    @AppStorage(OasisPlantDecorStore.equippedPotSkinKey) private var equippedPlantPotSkin = ""
    @AppStorage(AppIconCatalog.selectedIconKey) private var selectedAppIcon: String = AppIconCatalog.defaultItemId

    // Inventory states
    @State private var backdatePacks: Int = 0
    @State private var avatarPasses: Int = 0
    @State private var doubleBoostActive: Bool = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var streakShieldExpiry: Date? = nil
    @State private var showPetPickerForPopout = false
    @State private var showAvatarTargetPicker = false
    @State private var equipPopoutPet: Pet? = nil
    @State private var appIconApplyingID: String?
    @State private var inventoryAlert: InventoryAlert?

    private struct InventoryAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    // All items reference (shared with CoconutShopView)
    private var allEffectsAndTitles: [ShopItem] {
        ShopCatalog.allItems(purchasedSet: purchasedSet)
    }

    private var purchasedSet: Set<String> {
        var ownedIDs = ShopPurchaseRecordStore.ownedItemIDs(from: purchaseRecords)
        if hasSupporterPack {
            ownedIDs.insert(SupporterPackCatalog.supporterIconItemID)
        }
        return ownedIDs
    }

    private var l: L10n { L10n(appLanguage) }

    private var activeHumans: [Human] {
        humans.filter(EconomyWalletWritePolicy.canWrite)
    }

    private var activePets: [Pet] {
        pets.filter(EconomyWalletWritePolicy.canWrite)
    }

    private var myEffects: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .effect && purchasedSet.contains($0.id) }
    }

    private var myPlantDecor: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .plantDecor && purchasedSet.contains($0.id) }
    }

    private var myTitles: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .title_ && purchasedSet.contains($0.id) }
    }

    private var myAppIcons: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .appIcon && $0.isPurchased }
    }

    private var acquiredAppIcons: [ShopItem] {
        myAppIcons.filter { $0.id != AppIconCatalog.defaultItemId }
    }

    var body: some View {
        let isShieldActive = streakShieldExpiry.map { Date() < $0 } ?? false
        let hasAcquiredExtras = !acquiredAppIcons.isEmpty
            || !myTitles.isEmpty
            || !myEffects.isEmpty
            || !myPlantDecor.isEmpty
            || avatarPasses > 0
            || backdatePacks > 0
            || isShieldActive
            || doubleBoostActive

        NavigationStack {
            List {
                Section {
                    ForEach(myAppIcons) { item in
                        appIconRow(item)
                    }
                } header: {
                    sectionHeader(title: l.tr(zh: "App 图标", en: "App Icons", de: "App-Symbole"), icon: "app.badge.fill")
                } footer: {
                    Text(l.tr(zh: "默认图标属于基础外观，不计入已兑换内容。", en: "The default icon is a base appearance and does not count as a redeemed item.", de: "Das Standardsymbol gehört zur Grundausstattung und zählt nicht als eingelöster Artikel."))
                }

                if avatarPasses > 0 {
                    Section {
                        avatarPassRow
                    } header: {
                        sectionHeader(title: l.tr(zh: "2.5D 头像", en: "2.5D Avatar", de: "2,5D-Avatar"), icon: "person.crop.square.fill")
                    }
                }

                if !myTitles.isEmpty {
                    Section {
                        ForEach(myTitles) { item in
                            titleRow(item)
                        }
                    } header: {
                        sectionHeader(title: l.tr(zh: "我的称号", en: "My titles", de: "Meine Titel"), icon: "rosette")
                    }
                }

                if !myEffects.isEmpty {
                    Section {
                        ForEach(myEffects) { item in
                            effectRow(item)
                        }
                    } header: {
                        sectionHeader(title: l.tr(zh: "外观与特效", en: "Looks and effects", de: "Looks und Effekte"), icon: "wand.and.stars")
                    }
                }

                if !myPlantDecor.isEmpty {
                    Section {
                        ForEach(myPlantDecor) { item in
                            plantDecorRow(item)
                        }
                    } header: {
                        sectionHeader(title: l.tr(zh: "绿洲植物装饰", en: "Oasis plant decor", de: "Oasis-Pflanzendeko"), icon: "leaf.fill")
                    }
                }

                if backdatePacks > 0 || isShieldActive || doubleBoostActive {
                    Section {
                        if doubleBoostActive {
                            consumableRow(
                                emoji: "⚡️",
                                name: l.tr(zh: "金色幸运券", en: "Golden Luck", de: "Goldenes Glück"),
                                count: 1,
                                suffix: l.tr(zh: "下次普通照护生效", en: "Next regular care reward", de: "Bei der nächsten normalen Pflege")
                            )
                        }
                        if backdatePacks > 0 {
                            consumableRow(
                                emoji: "📅",
                                name: l.tr(zh: "昨日补签卡", en: "Yesterday make-up card", de: "Nachtragskarte für gestern"),
                                count: backdatePacks
                            )
                        }
                        if isShieldActive {
                            consumableRow(
                                emoji: "🛡️",
                                name: l.tr(zh: "Streak 保护盾", en: "Streak shield", de: "Streak-Schild"),
                                count: 1,
                                suffix: l.tr(zh: "使用中", en: "In use", de: "Aktiv")
                            )
                        }
                    } header: {
                        sectionHeader(title: l.tr(zh: "消耗品状态", en: "Consumables", de: "Verbrauchsartikel"), icon: "bag")
                    }
                }

                if !hasAcquiredExtras {
                    Section {
                        ContentUnavailableView(
                            l.tr(zh: "还没有兑换内容", en: "No redeemed items yet", de: "Noch keine eingelösten Artikel"),
                            systemImage: "shippingbox",
                            description: Text(l.tr(zh: "在椰子商店兑换的外观和道具会出现在这里。", en: "Looks and items redeemed in the Coconut Shop appear here.", de: "Im Kokosnuss-Shop eingelöste Looks und Artikel erscheinen hier."))
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(OhanaAppBackground().ignoresSafeArea())
            .accessibilityIdentifier("inventory-screen")
            .navigationTitle(l.tr(zh: "我的百宝箱", en: "My treasure box", de: "Meine Schatzkiste"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) { dismiss() }
                }
            }
        }
        .onAppear { loadConsumableInventory() }
        .confirmationDialog(l.tr(zh: "选择要绑定破框卡片的宠物", en: "Choose a pet for the popout card", de: "Wähle ein Haustier für die Popout-Karte"), isPresented: $showPetPickerForPopout, titleVisibility: .visible) {
            ForEach(activePets) { pet in
                Button(pet.name) { equipPopoutPet = pet }
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        }
        .confirmationDialog(l.tr(zh: "选择要升级 2.5D 头像的成员", en: "Choose who gets the 2.5D avatar", de: "Wähle das 2,5D-Avatar-Ziel"), isPresented: $showAvatarTargetPicker, titleVisibility: .visible) {
            ForEach(activeHumans) { human in
                Button(human.name) { upgradeHumanTo2DAvatar(human) }
            }
            ForEach(activePets) { pet in
                Button(pet.name) { upgradePetTo2DAvatar(pet) }
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        }
        .sheet(item: $equipPopoutPet) { pet in
            EquipPopoutCardSheet(pet: pet)
                .presentationDetents([.medium, .large])
        }
        .alert(item: $inventoryAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(l.tr(zh: "好", en: "OK", de: "OK")))
            )
        }
    }

    private var avatarPassRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    avatarPassLabel
                    avatarPassAction
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 14) {
                    avatarPassLabel
                    Spacer()
                    avatarPassAction
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var avatarPassLabel: some View {
        HStack(spacing: 14) {
            Text("🖼️")
                .font(OhanaFont.adaptive(size: 28))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "库存 ×\(avatarPasses) · 选择一位成员使用", en: "×\(avatarPasses) available · choose a member", de: "×\(avatarPasses) verfügbar · Mitglied wählen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var avatarPassAction: some View {
        Button {
            OhanaFeedback.light()
            showAvatarTargetPicker = true
        } label: {
            Text(
                activeHumans.isEmpty
                    ? l.tr(zh: "暂无可用成员", en: "No eligible member", de: "Kein verfügbares Mitglied")
                    : l.tr(zh: "指定成员", en: "Assign", de: "Zuweisen")
            )
                .font(OhanaFont.caption(.bold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(avatarPasses <= 0 || activeHumans.isEmpty)
        .accessibilityHint(
            activeHumans.isEmpty
                ? l.tr(zh: "纪念成员不能使用头像券", en: "Avatar passes cannot be assigned to memorial members", de: "Avatarpässe können Gedenkmitgliedern nicht zugewiesen werden")
                : l.tr(zh: "选择一位在世家庭成员使用头像券", en: "Choose an active family member to use the pass", de: "Wähle ein aktives Familienmitglied für den Avatarpass")
        )
    }

    @ViewBuilder
    private func appIconRow(_ item: ShopItem) -> some View {
        let descriptor = item.appIcon ?? AppIconCatalog.icons[0]
        let isActive = appServices.appIcons.currentDescriptor.itemId == descriptor.itemId
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                appIconLabel(item, descriptor: descriptor, isActive: isActive)
                appIconAction(item, descriptor: descriptor, isActive: isActive)
            }
        } else {
            HStack(spacing: 14) {
                appIconLabel(item, descriptor: descriptor, isActive: isActive)
                Spacer()
                appIconAction(item, descriptor: descriptor, isActive: isActive)
            }
        }
    }

    private func appIconLabel(_ item: ShopItem, descriptor: AppIconShopDescriptor, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            AppIconInventoryPreview(descriptor: descriptor)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name(l))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isActive ? l.tr(zh: "当前使用中", en: "Currently active", de: "Aktuell aktiv") : l.tr(zh: "可随时切换", en: "Ready to switch", de: "Bereit zum Wechseln"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func appIconAction(_ item: ShopItem, descriptor: AppIconShopDescriptor, isActive: Bool) -> some View {
        Button {
            appIconApplyingID = item.id
            appServices.appIcons.setIcon(descriptor) { result in
                appIconApplyingID = nil
                switch result {
                case .success:
                    selectedAppIcon = descriptor.itemId
                    OhanaFeedback.success()
                case let .failure(error):
                    OhanaFeedback.error()
                    inventoryAlert = InventoryAlert(
                        title: l.tr(zh: "无法切换 App Icon", en: "Could not change App Icon", de: "App-Symbol konnte nicht geändert werden"),
                        message: error.localizedDescription
                    )
                }
            }
        } label: {
            if appIconApplyingID == item.id {
                ProgressView()
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Text(isActive ? l.tr(zh: "使用中", en: "In use", de: "Aktiv") : l.tr(zh: "切换", en: "Switch", de: "Wechseln"))
                    .font(OhanaFont.caption(.bold))
                    .frame(minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
        .tint(isActive ? Color.goPrimary : Color.goTeal)
        .disabled(isActive || appIconApplyingID != nil)
        .accessibilityLabel(
            "\(item.name(l)), \(isActive ? l.tr(zh: "使用中", en: "In use", de: "Aktiv") : l.tr(zh: "切换", en: "Switch", de: "Wechseln"))"
        )
        .accessibilityHint(l.tr(zh: "将这个图标设为当前 App Icon", en: "Sets this as the current App Icon", de: "Legt dieses Symbol als aktuelles App-Symbol fest"))
    }

    // MARK: - Section Helper
    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.goPrimary)
    }

    // MARK: - Title Row
    private func titleRow(_ item: ShopItem) -> some View {
        let isEquipped = (equippedTitle == item.id)
        return Toggle(isOn: Binding(
                get: { isEquipped },
                set: { val in
                    OhanaFeedback.light()
                    equippedTitle = val ? item.id : ""
                }
            )) {
                HStack(spacing: 14) {
                    Text(item.emoji)
                        .font(OhanaFont.adaptive(size: 28))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name(l))
                            .font(OhanaFont.subheadline(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(item.description(l))
                            .font(OhanaFont.caption(.medium))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(Color.goPrimary)
            .accessibilityHint(l.tr(zh: "装备或卸下这个称号", en: "Equips or removes this title", de: "Rüstet diesen Titel aus oder ab"))
        }

    // MARK: - Effect Row
    private func effectRow(_ item: ShopItem) -> some View {
        let isActive = Binding<Bool>(
            get: {
                switch item.id {
                case "fx_lime_glow": equipFxLimeGlow
                case "fx_rainbow": equipFxRainbow
                case "fx_rainbow_poop": equipFxRainbowPoop
                case "fx_popout_card":
                    equipFxPopoutCard && activePets.contains { $0.cardStyleRaw == "popout" }
                case "fx_stars": equipFxStars
                case "fx_firework": equipFxFirework
                default: false
                }
            },
            set: { val in
                OhanaFeedback.light()
                switch item.id {
                case "fx_lime_glow": equipFxLimeGlow = val
                case "fx_rainbow": equipFxRainbow = val
                case "fx_rainbow_poop": equipFxRainbowPoop = val
                case "fx_popout_card":
                    guard val else {
                        equipFxPopoutCard = false
                        return
                    }
                    guard !activePets.isEmpty else {
                        equipFxPopoutCard = false
                        inventoryAlert = InventoryAlert(
                            title: l.tr(zh: "还没有可用素材", en: "No asset available", de: "Kein Motiv verfügbar"),
                            message: l.tr(zh: "先添加一位在世宠物，再启用破框卡片。", en: "Add an active pet before enabling the popout card.", de: "Füge zuerst ein aktives Haustier hinzu, bevor du die Popout-Karte aktivierst.")
                        )
                        return
                    }
                    equipFxPopoutCard = true
                    if !activePets.contains(where: { $0.cardStyleRaw == "popout" }) {
                        if activePets.count == 1 {
                            equipPopoutPet = activePets.first
                        } else {
                            showPetPickerForPopout = true
                        }
                    }
                case "fx_stars": equipFxStars = val
                case "fx_firework": equipFxFirework = val
                default: break
                }
            }
        )

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    effectLabel(item)
                    effectControls(item, isActive: isActive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 14) {
                    effectLabel(item)
                    Spacer()
                    effectControls(item, isActive: isActive)
                }
            }
        }
    }

    private func effectLabel(_ item: ShopItem) -> some View {
        HStack(spacing: 14) {
            Text(item.emoji)
                .font(OhanaFont.adaptive(size: 28))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name(l))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.description(l))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func effectControls(_ item: ShopItem, isActive: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            if item.id == "fx_popout_card" {
                Button {
                    if activePets.count == 1 {
                        equipPopoutPet = activePets.first
                    } else if activePets.count > 1 {
                        showPetPickerForPopout = true
                    }
                } label: {
                    Text(l.tr(zh: "选择素材", en: "Choose asset", de: "Motiv wählen"))
                        .font(OhanaFont.caption(.bold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(activePets.isEmpty)
                .accessibilityHint(l.tr(zh: "选择用于破框卡片的宠物", en: "Chooses the pet used by the popout card", de: "Wählt das Haustier für die Popout-Karte"))
            }

            Toggle(item.name(l), isOn: isActive)
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .labelsHidden()
                .accessibilityLabel(item.name(l))
                .accessibilityIdentifier("coconut-inventory-effect-\(item.id)")
                .accessibilityHint(l.tr(zh: "开启或关闭这个特效", en: "Turns this effect on or off", de: "Schaltet diesen Effekt ein oder aus"))
        }
    }

    // MARK: - Plant Decor Row
    private func plantDecorRow(_ item: ShopItem) -> some View {
        let isActive = Binding<Bool>(
            get: {
                OasisPlantDecorStore.isEquipped(
                    item.id,
                    equippedSceneID: equippedPlantDecorScene,
                    equippedPotSkinID: equippedPlantPotSkin
                )
            },
            set: { val in
                OhanaFeedback.light()
                switch OasisPlantDecorID.slot(for: item.id) {
                case .scene:
                    equippedPlantDecorScene = val ? item.id : ""
                case .potSkin:
                    equippedPlantPotSkin = val ? item.id : ""
                case nil:
                    break
                }
            }
        )

        return Toggle(isOn: isActive) {
            HStack(spacing: 14) {
                Image(systemName: OasisPlantDecorID.symbolName(for: item.id))
                    .font(OhanaFont.adaptive(size: 24, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 42, height: 42) // a11y: allow decorative row symbol; toggle owns the interaction.
                    .background(Color.goTeal.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name(l))
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(item.description(l))
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Color.goPrimary)
        .accessibilityHint(l.tr(zh: "布置或收起这个植物装饰", en: "Places or removes this plant decor", de: "Platziert oder entfernt diese Pflanzendeko"))
    }

    // MARK: - Consumable Row
    @ViewBuilder
    private func consumableRow(emoji: String, name: String, count: Int, suffix: String? = nil) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                consumableLabel(emoji: emoji, name: name)
                consumableValue(count: count, suffix: suffix)
            }
        } else {
            HStack(spacing: 14) {
                consumableLabel(emoji: emoji, name: name)
                Spacer()
                consumableValue(count: count, suffix: suffix)
            }
        }
    }

    private func consumableLabel(emoji: String, name: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(OhanaFont.adaptive(size: 28))
                .accessibilityHidden(true)
            Text(name)
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func consumableValue(count: Int, suffix: String?) -> some View {
        Text(suffix ?? "×\(count)")
            .font(OhanaFont.caption(.black))
            .foregroundStyle(suffix == nil ? Color.ohanaPrimaryText : Color.goPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func loadConsumableInventory() {
        let snapshot = appServices.shopInventory.consumableSnapshot()
        backdatePacks = snapshot.backdatePassCount
        avatarPasses = snapshot.avatar2DExtraPassCount
        doubleBoostActive = snapshot.isDoubleRewardBoostActive
        streakShieldExpiry = snapshot.streakShieldExpiry
    }

    private func upgradeHumanTo2DAvatar(_ human: Human) {
        OhanaFeedback.medium()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradeHumanTo2DAvatar(
                human,
                note: "inventory.avatar2D.human"
            )
            guard handleAvatarUpgradeResult(result) else { return }
            loadConsumableInventory()
            notifyMemberProfileChanged(id: human.id, kind: EntityKind.human.rawValue)
            showAvatarTargetPicker = false
        }
    }

    private func upgradePetTo2DAvatar(_ pet: Pet) {
        OhanaFeedback.medium()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradePetTo2DAvatar(
                pet,
                note: "inventory.avatar2D.pet"
            )
            guard handleAvatarUpgradeResult(result) else { return }
            loadConsumableInventory()
            notifyMemberProfileChanged(id: pet.id, kind: EntityKind.pet.rawValue)
            showAvatarTargetPicker = false
        }
    }

    private func handleAvatarUpgradeResult(_ result: Avatar2DUpgradeCommandResult) -> Bool {
        guard result.didUpgrade else {
            OhanaFeedback.error()
            let message: String = switch result.failure {
            case .missingProfile:
                result.kind == EntityKind.human.rawValue
                    ? l.tr(zh: "请先补充性别或生日资料后再试。", en: "Add gender or birthday details first.", de: "Ergänze zuerst Geschlecht oder Geburtstag.")
                    : l.tr(zh: "请先补充物种或品种资料后再试。", en: "Add species or breed details first.", de: "Ergänze zuerst Art oder Rasse.")
            case .noPass, nil:
                l.tr(zh: "当前没有可用的 2.5D 头像券。", en: "No 2.5D avatar pass is available.", de: "Kein 2,5D-Avatarpass verfügbar.")
            case .memberInactive:
                l.tr(zh: "纪念成员不能再升级头像。", en: "Memorial members cannot upgrade avatars.", de: "Gedenkmitglieder können Avatare nicht mehr aktualisieren.")
            case .persistenceFailed:
                l.tr(zh: "头像保存失败，请稍后重试。", en: "Could not save the avatar. Try again later.", de: "Der Avatar konnte nicht gespeichert werden. Bitte später erneut versuchen.")
            }
            inventoryAlert = InventoryAlert(
                title: l.tr(zh: "无法使用头像券", en: "Could not use avatar pass", de: "Avatarpass konnte nicht verwendet werden"),
                message: message
            )
            return false
        }
        OhanaFeedback.success()
        return true
    }

    private func notifyMemberProfileChanged(id: UUID, kind: String) {
        appServices.domainRevisions.publishMemberProfileChange(
            entityID: id,
            kind: kind,
            note: "inventory.avatar2D.member"
        )
    }
}

private struct AppIconInventoryPreview: View {
    let descriptor: AppIconShopDescriptor

    var body: some View {
        AppIconArtwork(descriptor: descriptor)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }
}
