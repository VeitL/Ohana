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
            ShopItem(id: "boost_double",        emoji: "⚡️", name: "双倍椰子券",   description: "下次打卡奖励 ×2（单次有效）",          cost: 30,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_streak",        emoji: "🛡️", name: "Streak 保护盾", description: "漏打卡 1 天不断 Streak（24 小时有效）",  cost: 50,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_tree",          emoji: "🌳", name: "生命树加速",   description: "立即为生命之树注入 30 点额外能量",        cost: 25,  category: .boost, isConsumable: true),
            ShopItem(id: "boost_backdate_pack", emoji: "📅", name: "补打卡包",     description: "获得 3 张昨日补打卡券，放入物品栏",      cost: 120, category: .boost, isConsumable: true),
            ShopItem(id: "boost_cooldown_reset",emoji: "⏱️", name: "冷却重置券",   description: "立即重置全部宠物打卡冷却（单次有效）",   cost: 80,  category: .boost, isConsumable: true),
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
                ArkBackgroundView()
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
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
            .fill(.ultraThinMaterial)
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
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - 商品卡片
    private func shopItemCard(_ item: ShopItem) -> some View {
        let canAfford = questManager.coconutCount >= item.cost
        let purchased = item.isPurchased
        let activeStatus = activeConsumableStatus(for: item)

        return Button {
            if purchased { return }
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
                        Text("已兑换")
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
        .buttonStyle(.plain)
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
        case "boost_tree":
            // 立即为生命之树注入 30 点额外能量（不额外扣椰子）
            OasisTreeManager.shared.injectedEnergy += 30
            OasisTreeManager.shared.checkAndRewardLevelUp()

        case "boost_double":
            // 下次打卡奖励 ×2，用 UserDefaults 标记，QuestManager 在下次 addCoconuts 时消耗
            UserDefaults.standard.set(true, forKey: "shop_boostDoubleActive")

        case "boost_streak":
            // Streak 保护盾，标记有效期（24 小时内漏打不断 Streak）
            UserDefaults.standard.set(Date().addingTimeInterval(86400), forKey: "shop_streakShieldExpiry")

        case "boost_backdate_pack":
            // 补打卡包：增加 3 张补签券库存
            let key = "inventory_backdate_1day_count"
            let cur = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(cur + 3, forKey: key)

        case "boost_cooldown_reset":
            // 冷却重置券：清空所有宠物的冷却记录
            UserDefaults.standard.removeObject(forKey: "quest_cooldownLogs")

        default:
            break
        }
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
        default:
            return nil
        }
    }
}
