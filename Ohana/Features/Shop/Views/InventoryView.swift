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
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"

    // Equip states
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow: Bool = false
    @AppStorage("shop_equip_fx_rainbow_poop") private var equipFxRainbowPoop: Bool = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @AppStorage("shop_equip_fx_firework") private var equipFxFirework: Bool = false
    @AppStorage(AppIconCatalog.selectedIconKey) private var selectedAppIcon: String = AppIconCatalog.defaultItemId

    // Inventory states
    @State private var backdatePacks: Int = 0
    @State private var doubleBoostActive: Bool = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var streakShieldExpiry: Date? = nil
    @State private var showPetPickerForPopout = false
    @State private var showAvatarTargetPicker = false
    @State private var equipPopoutPet: Pet? = nil

    // All items reference (shared with CoconutShopView)
    private var allEffectsAndTitles: [ShopItem] {
        ShopCatalog.allItems(purchasedSet: purchasedSet)
    }

    private var purchasedSet: Set<String> {
        ShopPurchaseRecordStore.ownedItemIDs(from: purchaseRecords)
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

    private var myTitles: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .title_ && purchasedSet.contains($0.id) }
    }

    private var myAppIcons: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .appIcon && $0.isPurchased }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        if !myAppIcons.isEmpty {
                            inventorySection(title: "App Icon", icon: "app.badge.fill") {
                                ForEach(myAppIcons) { item in
                                    appIconRow(item)
                                }
                            }
                        }

                        if Avatar2DAccess.extraPassCount > 0 {
                            inventorySection(title: l.tr(zh: "2.5D 头像", en: "2.5D Avatar", de: "2,5D-Avatar"), icon: "person.crop.square.fill") {
                                avatarPassRow
                            }
                        }

                        // 1. 称号区
                        if !myTitles.isEmpty {
                            inventorySection(title: "我的称号", icon: "rosette") {
                                ForEach(myTitles) { item in
                                    titleRow(item)
                                }
                            }
                        }

                        // 2. 特效区
                        if !myEffects.isEmpty {
                            inventorySection(title: "外观与特效", icon: "wand.and.stars") {
                                ForEach(myEffects) { item in
                                    effectRow(item)
                                }
                            }
                        }

                        // 3. 消耗区
                        let isShieldActive = streakShieldExpiry.map { Date() < $0 } ?? false
                        if backdatePacks > 0 || isShieldActive || doubleBoostActive {
                            inventorySection(title: "消耗品状态", icon: "bag") {
                                if doubleBoostActive {
                                    consumableRow(emoji: "⚡️", name: "双倍椰子券", count: 1, suffix: "下次打卡生效")
                                }
                                if backdatePacks > 0 {
                                    consumableRow(emoji: "📅", name: "昨日补签卡", count: backdatePacks)
                                }
                                if isShieldActive {
                                    consumableRow(emoji: "🛡️", name: "Streak 保护盾", count: 1, suffix: "使用中")
                                }
                            }
                        }

                        if myAppIcons.isEmpty, myTitles.isEmpty, myEffects.isEmpty, Avatar2DAccess.extraPassCount == 0, backdatePacks == 0, !isShieldActive, !doubleBoostActive {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 40))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
                                Text("百宝箱空空如也")
                                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                Text("前往椰子商店兑换更多有趣的道具吧！")
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("我的百宝箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear { loadConsumableInventory() }
        .confirmationDialog("选择要绑定破框卡片的宠物", isPresented: $showPetPickerForPopout, titleVisibility: .visible) {
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
                .presentationDragIndicator(.hidden)
        }
    }

    private var avatarPassRow: some View {
        HStack(spacing: 14) {
            Text("🖼️")
                .font(OhanaFont.adaptive(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "库存 x\(Avatar2DAccess.extraPassCount) · 开关后指定成员", en: "x\(Avatar2DAccess.extraPassCount) available · toggle to assign", de: "x\(Avatar2DAccess.extraPassCount) verfügbar · Schalter zum Zuweisen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAvatarTargetPicker = true
            } label: {
                inventorySwitch(isOn: Avatar2DAccess.extraPassCount > 0)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(Avatar2DAccess.extraPassCount <= 0)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.ohanaPrimaryText.opacity(0.1)).padding(.leading, 60)
        }
    }

    private func appIconRow(_ item: ShopItem) -> some View {
        let descriptor = item.appIcon ?? AppIconCatalog.icons[0]
        let isActive = appServices.appIcons.currentDescriptor.itemId == descriptor.itemId
        return HStack(spacing: 14) {
            AppIconInventoryPreview(descriptor: descriptor)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isActive ? l.tr(zh: "当前使用中", en: "Currently active", de: "Aktuell aktiv") : l.tr(zh: "可随时切换", en: "Ready to switch", de: "Bereit zum Wechseln"))
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()

            Button {
                appServices.appIcons.setIcon(descriptor) { result in
                    if case .success = result {
                        selectedAppIcon = descriptor.itemId
                    }
                }
            } label: {
                Text(isActive ? l.tr(zh: "使用中", en: "In use", de: "Aktiv") : l.tr(zh: "切换", en: "Switch", de: "Wechseln"))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Color.goDarkBlue : Color.ohanaPrimaryText)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(isActive ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isActive)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.ohanaPrimaryText.opacity(0.1)).padding(.leading, 60)
        }
    }

    // MARK: - Section Helper
    private func inventorySection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous).strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Title Row
    private func titleRow(_ item: ShopItem) -> some View {
        let isEquipped = (equippedTitle == item.id)
        return HStack(spacing: 14) {
            Text(item.emoji)
                .font(OhanaFont.adaptive(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.description)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()

            Toggle("", isOn: Binding(
                get: { isEquipped },
                set: { val in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    equippedTitle = val ? item.id : ""
                }
            ))
            .toggleStyle(OhanaPillToggleStyle())
            .labelsHidden()
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.ohanaPrimaryText.opacity(0.1)).padding(.leading, 60)
        }
    }

    // MARK: - Effect Row
    private func effectRow(_ item: ShopItem) -> some View {
        let isActive = Binding<Bool>(
            get: {
                switch item.id {
                case "fx_lime_glow": equipFxLimeGlow
                case "fx_rainbow": equipFxRainbow
                case "fx_rainbow_poop": equipFxRainbowPoop
                case "fx_popout_card": equipFxPopoutCard
                case "fx_stars": equipFxStars
                case "fx_firework": equipFxFirework
                default: false
                }
            },
            set: { val in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                switch item.id {
                case "fx_lime_glow": equipFxLimeGlow = val
                case "fx_rainbow": equipFxRainbow = val
                case "fx_rainbow_poop": equipFxRainbowPoop = val
                case "fx_popout_card":
                    equipFxPopoutCard = val
                    if val, !activePets.contains(where: { $0.cardStyleRaw == "popout" }) {
                        if activePets.count == 1 {
                            equipPopoutPet = activePets.first
                        } else if activePets.count > 1 {
                            showPetPickerForPopout = true
                        }
                    }
                case "fx_stars": equipFxStars = val
                case "fx_firework": equipFxFirework = val
                default: break
                }
            }
        )

        return HStack(spacing: 14) {
            Text(item.emoji)
                .font(OhanaFont.adaptive(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.description)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()

            HStack(spacing: 10) {
                if item.id == "fx_popout_card" {
                    Button {
                        if activePets.count == 1 {
                            equipPopoutPet = activePets.first
                        } else if activePets.count > 1 {
                            showPetPickerForPopout = true
                        }
                    } label: {
                        Text(l.tr(zh: "素材", en: "Asset", de: "Motiv"))
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goDarkBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Toggle("", isOn: isActive)
                    .toggleStyle(OhanaPillToggleStyle())
                    .labelsHidden()
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.ohanaPrimaryText.opacity(0.1)).padding(.leading, 60)
        }
    }

    // MARK: - Consumable Row
    private func consumableRow(emoji: String, name: String, count: Int, suffix: String? = nil) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(OhanaFont.adaptive(size: 28))
            Text(name)
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            if let suf = suffix {
                Text(suf)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
            } else {
                Text("x\(count)")
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.ohanaPrimaryText.opacity(0.1)).padding(.leading, 60)
        }
    }

    private func loadConsumableInventory() {
        let snapshot = appServices.shopInventory.consumableSnapshot()
        backdatePacks = snapshot.backdatePassCount
        doubleBoostActive = snapshot.isDoubleRewardBoostActive
        streakShieldExpiry = snapshot.streakShieldExpiry
    }

    private func inventorySwitch(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? Color.goPrimary : Color.ohanaControlFill)
            .frame(width: 50, height: 28)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.ohanaPrimaryText)
                    .frame(width: 22, height: 22) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .padding(3)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? Color.goPrimary.opacity(0.55) : Color.ohanaGlassStroke.opacity(0.9), lineWidth: 1)
            }
            .animation(GoMotion.selection, value: isOn)
    }

    private func upgradeHumanTo2DAvatar(_ human: Human) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradeHumanTo2DAvatar(
                human,
                note: "inventory.avatar2D.human"
            )
            guard result.didUpgrade else { return }
            notifyMemberProfileChanged(id: human.id, kind: EntityKind.human.rawValue)
            showAvatarTargetPicker = false
        }
    }

    private func upgradePetTo2DAvatar(_ pet: Pet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.avatar2DUpgrade(entityID: pet.id, kind: EntityKind.pet.rawValue)) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).upgradePetTo2DAvatar(
                pet,
                note: "inventory.avatar2D.pet"
            )
            guard result.didUpgrade else { return }
            notifyMemberProfileChanged(id: pet.id, kind: EntityKind.pet.rawValue)
            showAvatarTargetPicker = false
        }
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
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: descriptor.gradientHex.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: descriptor.previewSymbol)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(descriptor.itemId == "appicon_minimal_o" ? Color.arkInk : Color.white) // ui-v4: allow asset-specific icon ink
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }
}
