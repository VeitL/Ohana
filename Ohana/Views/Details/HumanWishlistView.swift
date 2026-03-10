//
//  HumanWishlistView.swift
//  Ohana
//
//  模块1：椰子心愿单商城

import SwiftUI
import SwiftData

struct HumanWishlistView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistItem.createdAt, order: .reverse) private var allItems: [WishlistItem]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    @State private var showAddSheet = false
    @State private var showConfetti = false
    @State private var newTitle = ""
    @State private var newCost = 10

    private var myItems: [WishlistItem] {
        allItems.filter { $0.creatorId == human.id.uuidString }
    }
    private var pendingItems: [WishlistItem] { myItems.filter { !$0.isRedeemed } }
    private var redeemedItems: [WishlistItem] { myItems.filter { $0.isRedeemed } }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 头部余额卡
                    balanceCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if pendingItems.isEmpty && redeemedItems.isEmpty {
                        emptyState.padding(.top, 60)
                    } else {
                        if !pendingItems.isEmpty {
                            sectionHeader("🎁 待兑换心愿")
                                .padding(.horizontal, 20)
                            ForEach(pendingItems) { item in
                                wishCard(item: item, redeemed: false)
                                    .padding(.horizontal, 20)
                            }
                        }
                        if !redeemedItems.isEmpty {
                            sectionHeader("✅ 已兑换")
                                .padding(.horizontal, 20)
                            ForEach(redeemedItems) { item in
                                wishCard(item: item, redeemed: true)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    Spacer(minLength: 100)
                }
            }

            // FAB
            Button { showAddSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .black))
                    Text("许一个愿")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(Color.goLime, in: Capsule())
                .shadow(color: Color.goLime.opacity(0.45), radius: 14, y: 5)
            }
            .padding(.bottom, 28)
        }
        .confettiOverlay(isShowing: $showConfetti)
        .navigationTitle("🎁 心愿单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { addWishSheet }
    }

    // MARK: - Balance Card
    private var balanceCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("我的椰子余额")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("🥥")
                        .font(.system(size: 28))
                    Text("\(human.coconutBalance)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                        .contentTransition(.numericText())
                }
                Text("许愿消耗椰子，需攒够才能兑换")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(pendingItems.count)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("个待兑换")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
            }
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }

    // MARK: - Wish Card
    private func wishCard(item: WishlistItem, redeemed: Bool) -> some View {
        HStack(spacing: 14) {
            // 椰子数量徽章
            VStack(spacing: 2) {
                Text("🥥")
                    .font(.system(size: 22))
                Text("\(item.cost)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(redeemed ? .white.opacity(0.3) : Color.goYellow)
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(redeemed ? .white.opacity(0.4) : .white)
                    .strikethrough(redeemed)
                Text(item.createdAt, format: .dateTime.month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
            }
            Spacer()

            if !redeemed {
                // 兑换按钮
                Button {
                    redeem(item: item)
                } label: {
                    Text("兑换")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(human.coconutBalance >= item.cost ? .black : .white.opacity(0.3))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            human.coconutBalance >= item.cost ? Color.goYellow : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                }
                .disabled(human.coconutBalance < item.cost)
                .buttonStyle(.plain)

                // 删除
                Button {
                    modelContext.delete(item)
                    modelContext.safeSave()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.2))
                }
                .buttonStyle(.plain)
            } else {
                Text("已兑换 ✓")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.05), in: Capsule())
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 18)
    }

    // MARK: - Section Header
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.primary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌟").font(.system(size: 56))
            Text("还没有心愿")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text("许下你想要的礼物\n让家人帮你兑换！")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Wish Sheet
    private var addWishSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            Text("许一个愿 🌟")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                // 心愿标题
                TextField("心愿内容（例如：新耳机）", text: $newTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1), lineWidth: 1))

                // 椰子费用
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("兑换费用")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("🥥 \(newCost)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goYellow)
                        }
                    }
                    Slider(value: Binding(
                        get: { Double(newCost) },
                        set: { newCost = Int($0) }
                    ), in: 5...500, step: 5)
                    .tint(Color.goYellow)
                    HStack {
                        Text("5 🥥").font(.caption).foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                        Text("500 🥥").font(.caption).foregroundStyle(.primary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, 24).padding(.top, 20)

            Spacer()

            Button {
                let item = WishlistItem(title: newTitle, cost: newCost,
                                       creatorId: human.id.uuidString)
                modelContext.insert(item)
                modelContext.safeSave()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newTitle = ""; newCost = 10
                showAddSheet = false
            } label: {
                Text("保存心愿")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.goLime, in: RoundedRectangle(cornerRadius: 18))
            }
            .disabled(newTitle.isEmpty)
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .background(Color.goDeepNavy)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Redeem Logic
    private func redeem(item: WishlistItem) {
        guard human.coconutBalance >= item.cost else { return }
        human.coconutBalance -= item.cost
        item.isRedeemed = true

        // 获取当前用户 id
        let currentId = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        item.redeemedById = currentId.isEmpty ? nil : currentId

        // 日志
        QuestManager.shared.addCoconuts(
            -item.cost,
            emoji: "🎁",
            title: "兑换「\(item.title)」",
            actorId: human.id.uuidString,
            actorName: human.name
        )
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // 撒花🎉
        withAnimation { showConfetti = true }
    }
}
