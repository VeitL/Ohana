//
//  InventoryView.swift
//  Ohana
//
//  椰子百宝箱 — 查看并装备已拥有的道具/特效/称号
//

import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("purchasedShopItems") private var purchasedRaw: String = ""
    
    // Equip states
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow: Bool = false
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @AppStorage("shop_equip_fx_firework") private var equipFxFirework: Bool = false
    
    // Inventory states
    @AppStorage("inventory_backdate_1day_count") private var backdatePacks: Int = 0
    @AppStorage("shop_streakShieldExpiry") private var streakShieldExpiry: Double = 0
    
    // All items reference (mirrors CoconutShopView)
    private var allEffectsAndTitles: [ShopItem] {
        [
            ShopItem(id: "fx_popout_card", emoji: "🃏", name: "3D 破框卡片",  description: "宠物主体从卡片破框悬浮而出（前往商城进行绑定）", cost: 0, category: .effect),
            ShopItem(id: "fx_lime_glow",   emoji: "💚", name: "青柠光晕",   description: "打卡时宠物卡片发出青柠光芒特效",          cost: 0,  category: .effect),
            ShopItem(id: "fx_rainbow",     emoji: "🌈", name: "彩虹轨迹",   description: "遛狗路线地图显示彩虹轨迹风格",            cost: 0,  category: .effect),
            ShopItem(id: "fx_stars",       emoji: "⭐️", name: "星尘落雨",   description: "完成每日委托时触发星尘粒子特效",           cost: 0,  category: .effect),
            ShopItem(id: "fx_firework",    emoji: "🎆", name: "烟花庆典",   description: "达成里程碑时升级烟花动画",                cost: 0, category: .effect),
            
            ShopItem(id: "title_guardian", emoji: "🛡️", name: "守护者",     description: "称号 · 显示在首页头像旁",                  cost: 0, category: .title_),
            ShopItem(id: "title_pioneer",  emoji: "🚀", name: "先行者",     description: "称号 · 解锁岛屿探索徽章",                  cost: 0, category: .title_),
            ShopItem(id: "title_chef",     emoji: "👨‍🍳", name: "首席厨师",   description: "称号 · 喂食打卡额外 +1🥥",               cost: 0, category: .title_)
        ]
    }
    
    private var purchasedSet: Set<String> {
        Set(purchasedRaw.split(separator: ",").map(String.init))
    }
    
    private var myEffects: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .effect && purchasedSet.contains($0.id) }
    }
    
    private var myTitles: [ShopItem] {
        allEffectsAndTitles.filter { $0.category == .title_ && purchasedSet.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
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
                        let isShieldActive = Date().timeIntervalSince1970 < streakShieldExpiry
                        if backdatePacks > 0 || isShieldActive {
                            inventorySection(title: "消耗品状态", icon: "bag") {
                                if backdatePacks > 0 {
                                    consumableRow(emoji: "📅", name: "昨日补签卡", count: backdatePacks)
                                }
                                if isShieldActive {
                                    consumableRow(emoji: "🛡️", name: "Streak 保护盾", count: 1, suffix: "使用中")
                                }
                            }
                        }
                        
                        if myTitles.isEmpty && myEffects.isEmpty && backdatePacks == 0 && !isShieldActive {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.primary.opacity(0.2))
                                Text("百宝箱空空如也")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Text("前往椰子商店兑换更多有趣的道具吧！")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.3))
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
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
    }
    
    // MARK: - Section Helper
    private func inventorySection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
    }
    
    // MARK: - Title Row
    private func titleRow(_ item: ShopItem) -> some View {
        let isEquipped = (equippedTitle == item.id)
        return HStack(spacing: 14) {
            Text(item.emoji)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if isEquipped {
                    equippedTitle = ""
                } else {
                    equippedTitle = item.id
                }
            } label: {
                Text(isEquipped ? "卸下" : "装备")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isEquipped ? Color.goDarkBlue : Color.goPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(isEquipped ? Color.goPrimary : Color.goPrimary.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(.white.opacity(0.1)).padding(.leading, 60)
        }
    }
    
    // MARK: - Effect Row
    private func effectRow(_ item: ShopItem) -> some View {
        let isActive = Binding<Bool>(
            get: {
                switch item.id {
                case "fx_lime_glow": return equipFxLimeGlow
                case "fx_rainbow": return equipFxRainbow
                case "fx_stars": return equipFxStars
                case "fx_firework": return equipFxFirework
                case "fx_popout_card": return true // Popout card is always considered active if owned, it's bound via shop
                default: return false
                }
            },
            set: { val in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                switch item.id {
                case "fx_lime_glow": equipFxLimeGlow = val
                case "fx_rainbow": equipFxRainbow = val
                case "fx_stars": equipFxStars = val
                case "fx_firework": equipFxFirework = val
                default: break
                }
            }
        )
        
        return HStack(spacing: 14) {
            Text(item.emoji)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            Spacer()
            
            if item.id == "fx_popout_card" {
                Text("已绑定")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
            } else {
                Toggle("", isOn: isActive)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(.white.opacity(0.1)).padding(.leading, 60)
        }
    }
    
    // MARK: - Consumable Row
    private func consumableRow(emoji: String, name: String, count: Int, suffix: String? = nil) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
            Text(name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            if let suf = suffix {
                Text(suf)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
            } else {
                Text("x\(count)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().background(.white.opacity(0.1)).padding(.leading, 60)
        }
    }
}
