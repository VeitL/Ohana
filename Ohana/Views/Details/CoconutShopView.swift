//
//  CoconutShopView.swift
//  Ohana
//
//  椰子兑换商店 — 消耗椰子换取道具/特效/称号
//

import SwiftUI
import SwiftData

// MARK: - 商品模型
struct ShopItem: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    /// 消耗品=每次购买后立即激活、不持久标记；永久/称号=标记已购
    var isConsumable: Bool = false
    var isPurchased: Bool = false

    enum ShopCategory: String, CaseIterable {
        case effect    = "特效"
        case title_    = "称号"
        case boost     = "加成"
    }
}

// MARK: - 商店 View
struct CoconutShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("purchasedShopItems") private var purchasedRaw: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow: Bool = false
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @AppStorage("shop_equip_fx_firework") private var equipFxFirework: Bool = false
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @State private var questManager = QuestManager.shared
    @State private var selectedCategory: ShopItem.ShopCategory = .effect
    @State private var showPurchaseAlert = false
    @State private var pendingItem: ShopItem? = nil
    @State private var purchaseSuccessItem: ShopItem? = nil
    @State private var showSuccess = false
    @State private var confettiItems: [ConfettiDrop] = []
    @State private var showEquipPopout = false
    @State private var showPetPickerForPopout = false
    @State private var equipPopoutPet: Pet? = nil
    @State private var showAvatarUpgradeTargetPicker = false
    @State private var avatarUpgradeErrorMessage = ""
    @State private var showAvatarUpgradeError = false

    init(initialCategory: ShopItem.ShopCategory = .effect) {
        _selectedCategory = State(initialValue: initialCategory)
    }

    // MARK: - 深浅色文字（UIRules）
    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.58) }
    private var tertiaryText: Color { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }

    private struct ConfettiDrop: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let delay: Double
    }

    private var purchasedSet: Set<String> {
        Set(purchasedRaw.split(separator: ",").map(String.init))
    }

    private var allItems: [ShopItem] {
        [
            ShopItem(id: "fx_popout_card", emoji: "🃏", name: "3D 破框卡片",  description: "宠物主体从卡片破框悬浮而出，需配合透明抠图使用", cost: 150, category: .effect),
            ShopItem(id: "fx_lime_glow",   emoji: "💚", name: "青柠光晕",   description: "打卡时宠物卡片发出青柠光芒特效",          cost: 50,  category: .effect),
            ShopItem(id: "fx_rainbow",     emoji: "🌈", name: "彩虹轨迹",   description: "遛狗路线地图显示彩虹轨迹风格",            cost: 80,  category: .effect),
            ShopItem(id: "fx_stars",       emoji: "⭐️", name: "星尘落雨",   description: "完成每日委托时触发星尘粒子特效",           cost: 60,  category: .effect),
            ShopItem(id: "fx_firework",    emoji: "🎆", name: "烟花庆典",   description: "达成里程碑时升级烟花动画",                cost: 100, category: .effect),
            ShopItem(id: "title_guardian", emoji: "🛡️", name: "守护者",     description: "称号 · 显示在首页头像旁",                  cost: 120, category: .title_),
            ShopItem(id: "title_pioneer",  emoji: "🚀", name: "先行者",     description: "称号 · 解锁岛屿探索徽章",                  cost: 150, category: .title_),
            ShopItem(id: "title_chef",     emoji: "👨‍🍳", name: "首席厨师",   description: "称号 · 喂食打卡额外 +1🥥",               cost: 200, category: .title_),
            ShopItem(id: "boost_double",          emoji: "⚡️", name: "双倍椰子券",     description: "下次获得椰子时奖励翻倍，触发后自动消耗", cost: 40,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_streak",          emoji: "🛡️", name: "Streak 保护盾",  description: "48 小时内漏签 1 天也不断连胜",          cost: 80,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_tree",            emoji: "🌱", name: "生命树能量 +30", description: "立即为生命之树注入 30 点能量",          cost: 30,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_tree_large",      emoji: "🌳", name: "生命树能量 +110",description: "批量注入 110 点能量，比小包更划算",      cost: 95,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_backdate_single", emoji: "📅", name: "补签券 ×1",      description: "获得 1 张昨日补签券，放入百宝箱",        cost: 45,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_backdate_pack",   emoji: "🗓️", name: "补签券 ×3",      description: "获得 3 张昨日补签券，适合连续补签",      cost: 120, category: .boost, isConsumable: true),
            ShopItem(id: Avatar2DAccess.shopItemId, emoji: "🖼️", name: "2.5D 头像券", description: "购买后指定 1 位人类或宠物升级 2.5D 头像", cost: 320, category: .boost, isConsumable: true),
        ].map { item in
            var copy = item
            if !item.isConsumable {
                copy.isPurchased = purchasedSet.contains(item.id)
            }
            return copy
        }
    }

    private var filteredItems: [ShopItem] {
        allItems.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                // 庆典粒子
                ForEach(confettiItems) { c in
                    Text(c.emoji)
                        .font(.system(size: 22))
                        .position(x: c.x, y: -20)
                        .animation(.linear(duration: 1.4).delay(c.delay), value: showSuccess)
                }

                VStack(spacing: 0) {
                    // 余额 Header
                    balanceHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // 分类 Chip
                    categoryChips
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // 商品列表
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredItems) { item in
                                shopItemCard(item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("椰子商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ohanaCardSurface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
        }
        .tint(Color.goPrimary)
        .alert("确认兑换", isPresented: $showPurchaseAlert, presenting: pendingItem) { item in
            Button("兑换 \(item.cost)🥥", role: .none) { purchase(item) }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("消耗 \(item.cost) 个椰子兑换「\(item.name)」？")
        }
        .confirmationDialog("选择要激活的宠物", isPresented: $showPetPickerForPopout, titleVisibility: .visible) {
            ForEach(pets) { pet in
                Button(pet.name) {
                    equipPopoutPet = pet
                    showEquipPopout = true
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("选择 2.5D 头像对象", isPresented: $showAvatarUpgradeTargetPicker, titleVisibility: .visible) {
            if Avatar2DAccess.extraPassCount <= 0 {
                Button("暂无可用头像券", role: .cancel) {}
            } else {
                ForEach(humans) { human in
                    Button("人类 · \(human.name)") {
                        upgradeHumanTo2DAvatar(human)
                    }
                }
                ForEach(pets) { pet in
                    Button("宠物 · \(pet.name)") {
                        upgradePetTo2DAvatar(pet)
                    }
                }
                Button("稍后再用", role: .cancel) {}
            }
        } message: {
            Text("每张券可为一个成员生成 2.5D 头像，保存后首页、详情页和所有头像位置会一起更新。")
        }
        .alert("无法升级 2.5D 头像", isPresented: $showAvatarUpgradeError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(avatarUpgradeErrorMessage)
        }
        .sheet(item: $equipPopoutPet) { pet in
            EquipPopoutCardSheet(pet: pet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if showSuccess, let item = purchaseSuccessItem {
                successToast(item)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }

    // MARK: - 余额 Header
    private var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("我的余额")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(tertiaryText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("🥥")
                        .font(.system(size: 24))
                    Text("\(questManager.coconutCount)")
                        .font(OhanaFont.metric(size: 36, .black))
                        .foregroundStyle(Color.goYellow)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: questManager.coconutCount)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("已兑换")
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(tertiaryText)
                Text("\(purchasedSet.count) 件")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goTeal)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(balanceHeaderBackground)
    }

    private var balanceHeaderBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.ohanaCardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(colorScheme == .dark ? 0.38 : 0.32), lineWidth: 1)
            )
    }

    // MARK: - 分类 Chip
    private var categoryChips: some View {
        HStack(spacing: 8) {
            ForEach(ShopItem.ShopCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = cat
                    }
                } label: {
                    Text(cat.rawValue)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(selectedCategory == cat ? Color.arkInk : secondaryText)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(
                            selectedCategory == cat
                                ? Color.goPrimary
                                : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    selectedCategory == cat ? Color.clear : Color.primary.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            Spacer()
        }
    }

    // MARK: - 商品卡片
    private func shopItemCard(_ item: ShopItem) -> some View {
        let canAfford = questManager.coconutCount >= item.cost
        let purchased = item.isPurchased
        let activeStatus = activeConsumableStatus(for: item)
        let ownedStatus = ownedItemStatus(for: item)

        return Button {
            if purchased {
                toggleOwnedItem(item)
                return
            }
            if item.id == Avatar2DAccess.shopItemId, Avatar2DAccess.extraPassCount > 0 {
                openAvatarUpgradeTargetPicker()
                return
            }
            if activeStatus != nil { return }
            if canAfford {
                pendingItem = item
                showPurchaseAlert = true
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.emoji)
                        .font(.system(size: 30))
                    Spacer()
                    if purchased {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.goPrimary)
                    }
                }

                Text(item.name)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)

                Text(item.description)
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack {
                    if purchased {
                        Text(ownedStatus ?? "已兑换")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goPrimary)
                    } else if let status = activeStatus {
                        Text(status)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goPrimary)
                    } else {
                        HStack(spacing: 3) {
                            Text("🥥")
                                .font(.system(size: 12))
                            Text("\(item.cost)")
                                .font(OhanaFont.subheadline(.black))
                                .foregroundStyle(canAfford ? Color.goYellow : tertiaryText)
                        }
                    }
                    Spacer()
                    if !purchased && !canAfford {
                        Text("不足")
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(tertiaryText)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(shopCardBackground(purchased: purchased, canAfford: canAfford))
            .opacity((!canAfford && !purchased) ? 0.65 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func shopCardBackground(purchased: Bool, canAfford: Bool) -> some View {
        let fillColor: Color = purchased
            ? Color.goPrimary.opacity(colorScheme == .dark ? 0.12 : 0.1)
            : (canAfford
                ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
                : Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.035))
        let strokeColor: Color = purchased
            ? Color.goPrimary.opacity(0.35)
            : (canAfford
                ? Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.12)
                : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.08))
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }

    // MARK: - 成功 Toast
    private func successToast(_ item: ShopItem) -> some View {
        VStack {
            HStack(spacing: 10) {
                Text(item.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("兑换成功！")
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.arkInk)
                    Text(item.isConsumable ? "「\(item.name)」已生效" : "「\(item.name)」已加入百宝箱")
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(Color.arkInk.opacity(0.72))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.goPrimary.opacity(0.45), radius: 16, x: 0, y: 4)
            .padding(.horizontal, 24)
            .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - 购买逻辑
    private func purchase(_ item: ShopItem) {
        guard questManager.coconutCount >= item.cost else { return }
        questManager.addCoconuts(
            -item.cost,
            emoji: item.emoji,
            title: "兑换「\(item.name)」",
            actorId: activeHumanId.isEmpty ? nil : activeHumanId,
            actorName: humans.first(where: { $0.id.uuidString == activeHumanId })?.name
        )

        if item.isConsumable {
            // 消耗品立即激活效果
            activateBoost(item)
        } else {
            // 永久道具/称号标记已购
            var current = purchasedSet
            current.insert(item.id)
            purchasedRaw = current.sorted().joined(separator: ",")
            activateOwnedItem(item)
        }

        // 破框卡片：购买后弹出宠物选择器 → EquipPopoutCardSheet
        if item.id == "fx_popout_card" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if pets.count == 1 {
                    equipPopoutPet = pets.first
                } else if pets.count > 1 {
                    showPetPickerForPopout = true
                }
            }
        }
        if item.id == Avatar2DAccess.shopItemId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                openAvatarUpgradeTargetPicker()
            }
        }

        purchaseSuccessItem = item
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.4)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - 消耗品立即激活
    private func activateBoost(_ item: ShopItem) {
        switch item.id {
        case "boost_tree", "boost_tree_large":
            // 立即为生命之树注入额外能量（不额外扣椰子）
            OasisTreeManager.shared.injectedEnergy += item.id == "boost_tree_large" ? 110 : 30
            OasisTreeManager.shared.checkAndRewardLevelUp()

        case "boost_double":
            // 下次打卡奖励 ×2，用 UserDefaults 标记，QuestManager 在下次 addCoconuts 时消耗
            UserDefaults.standard.set(true, forKey: "shop_boostDoubleActive")

        case "boost_streak":
            // Streak 保护盾，标记有效期（48 小时内漏打不断 Streak）
            UserDefaults.standard.set(Date().addingTimeInterval(172800), forKey: "shop_streakShieldExpiry")

        case "boost_backdate_single", "boost_backdate_pack":
            // 补签券：增加补签库存
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
        case "fx_stars":
            equipFxStars.toggle()
        case "fx_firework":
            equipFxFirework.toggle()
        case "title_guardian", "title_pioneer", "title_chef":
            equippedTitle = equippedTitle == item.id ? "" : item.id
        case "fx_popout_card":
            if pets.count == 1 {
                equipPopoutPet = pets.first
            } else if pets.count > 1 {
                showPetPickerForPopout = true
            }
        default:
            break
        }
    }

    private func ownedItemStatus(for item: ShopItem) -> String? {
        switch item.id {
        case "fx_lime_glow":
            return equipFxLimeGlow ? "已启用" : "未启用"
        case "fx_rainbow":
            return equipFxRainbow ? "已启用" : "未启用"
        case "fx_stars":
            return equipFxStars ? "已启用" : "未启用"
        case "fx_firework":
            return equipFxFirework ? "已启用" : "未启用"
        case "title_guardian", "title_pioneer", "title_chef":
            return equippedTitle == item.id ? "已装备" : "未装备"
        case "fx_popout_card":
            return "点按绑定"
        default:
            return nil
        }
    }

    private func openAvatarUpgradeTargetPicker() {
        guard Avatar2DAccess.extraPassCount > 0 else {
            avatarUpgradeErrorMessage = "当前没有可用的 2.5D 头像券。"
            showAvatarUpgradeError = true
            return
        }
        guard !humans.isEmpty || !pets.isEmpty else {
            avatarUpgradeErrorMessage = "请先创建一个人类或宠物成员，再使用 2.5D 头像券。"
            showAvatarUpgradeError = true
            return
        }
        showAvatarUpgradeTargetPicker = true
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
            avatarUpgradeErrorMessage = "暂时无法为 \(human.name) 生成 2.5D 头像，请先补充性别或生日资料后再试。"
            showAvatarUpgradeError = true
            return
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            avatarUpgradeErrorMessage = "当前没有可用的 2.5D 头像券。"
            showAvatarUpgradeError = true
            return
        }
        human.avatarImageData = data
        human.avatarEmoji = HumanGenderIdentity.fallbackAvatarEmoji(for: avatarGender)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func upgradePetTo2DAvatar(_ pet: Pet) {
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor,
            eyeColor: pet.eyeColor
        ) else {
            avatarUpgradeErrorMessage = "暂时无法为 \(pet.name) 生成 2.5D 头像，请先补充物种或品种资料后再试。"
            showAvatarUpgradeError = true
            return
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            avatarUpgradeErrorMessage = "当前没有可用的 2.5D 头像券。"
            showAvatarUpgradeError = true
            return
        }
        pet.avatarImageData = data
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func activeConsumableStatus(for item: ShopItem) -> String? {
        switch item.id {
        case "boost_double":
            return UserDefaults.standard.bool(forKey: "shop_boostDoubleActive") ? "已激活" : nil
        case "boost_streak":
            if let expiry = UserDefaults.standard.object(forKey: "shop_streakShieldExpiry") as? Date,
               expiry > Date() {
                return "保护中"
            }
            return nil
        case Avatar2DAccess.shopItemId:
            let count = Avatar2DAccess.extraPassCount
            return count > 0 ? "库存 \(count) 张" : nil
        default:
            return nil
        }
    }
}
