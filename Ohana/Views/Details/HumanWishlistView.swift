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
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
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
    private var isPrivacyLocked: Bool {
        human.isPrivate(.wishlist, viewedBy: UUID(uuidString: activeHumanIdStr))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView().ignoresSafeArea()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                wishlistContent
            }

            // FAB — iOS 26 Primary CTA
            if !isPrivacyLocked {
                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(OhanaFont.callout(.black))
                        Text("许一个愿")
                            .font(OhanaFont.callout(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.45), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
        }
        .confettiOverlay(isShowing: $showConfetti)
        .navigationTitle("🎁 心愿单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { addWishSheet }
    }

    private var wishlistContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                balanceCard

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
    }

    private var balanceCard: some View {
        UltimateGlassCard {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的椰子余额")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.primary.opacity(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("🥥")
                            .font(OhanaFont.title2())
                        Text("\(human.coconutBalance)")
                            .font(OhanaFont.metric(size: 44))
                            .foregroundStyle(Color.goPrimary)
                            .contentTransition(.numericText())
                    }
                    Text("许愿消耗椰子，需攒够才能兑换")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.primary.opacity(0.35))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(pendingItems.count)")
                        .font(OhanaFont.metric(size: 32))
                        .foregroundStyle(.primary)
                    Text("个待兑换")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var privacyLockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.goYellow)
            Text("椰子资产仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(.primary)
            Text("当前家庭成员无权查看余额、心愿和兑换记录。")
                .font(OhanaFont.callout())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .ohanaStandardCard(cornerRadius: 24)
        .padding(.horizontal, 24)
    }

    // MARK: - Balance Card (inner)
    private func wishCard(item: WishlistItem, redeemed: Bool) -> some View {
        UltimateGlassCard {
            HStack(spacing: 14) {
                // 椰子数量徽章
                VStack(spacing: 2) {
                    Text("🥥")
                        .font(OhanaFont.title3())
                    Text("\(item.cost)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(redeemed ? .primary.opacity(0.3) : Color.goYellow)
                }
                .frame(width: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(redeemed ? Color.primary.opacity(0.4) : Color.primary)
                        .strikethrough(redeemed)
                    Text(item.createdAt, format: .dateTime.month().day())
                        .font(OhanaFont.caption())
                        .foregroundStyle(.primary.opacity(0.3))
                }
                Spacer()

                if !redeemed {
                    Button { redeem(item: item) } label: {
                        Text("兑换")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(human.coconutBalance >= item.cost ? Color.arkInk : .primary.opacity(0.3))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                human.coconutBalance >= item.cost ? Color.goYellow : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .disabled(human.coconutBalance < item.cost)
                    .buttonStyle(.plain)

                    Button {
                        modelContext.delete(item)
                        modelContext.safeSave()
                    } label: {
                        Image(systemName: "trash")
                            .font(OhanaFont.footnote())
                            .foregroundStyle(.primary.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("已兑换 ✓")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(.primary.opacity(0.25))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.06), in: Capsule())
                }
            }
            .padding(16)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.footnote(.black))
            .foregroundStyle(.primary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌟").font(OhanaFont.metric(size: 56))
            Text("还没有心愿")
                .font(OhanaFont.headline(.black))
                .foregroundStyle(.primary)
            Text("许下你想要的礼物\n让家人帮你兑换！")
                .font(OhanaFont.callout())
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Wish Sheet
    private var addWishSheet: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 20)

                Text("许一个愿 🌟")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    // 心愿标题
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.primary.opacity(0.3))
                        TextField("心愿内容（例如：新耳机）", text: $newTitle)
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))

                    // 椰子费用
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("兑换费用")
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text("🥥 \(newCost)")
                                    .font(OhanaFont.headline(.black))
                                    .foregroundStyle(Color.goYellow)
                            }
                        }
                        Slider(value: Binding(
                            get: { Double(newCost) },
                            set: { newCost = Int($0) }
                        ), in: 5...500, step: 5)
                        .tint(Color.goYellow)
                        HStack {
                            Text("5 🥥").font(OhanaFont.caption2()).foregroundStyle(.primary.opacity(0.4))
                            Spacer()
                            Text("500 🥥").font(OhanaFont.caption2()).foregroundStyle(.primary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
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
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(newTitle.isEmpty ? Color.goPrimary.opacity(0.4) : Color.goPrimary,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(newTitle.isEmpty)
                .buttonStyle(.plain)
                .padding(.horizontal, 24).padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Redeem Logic
    private func redeem(item: WishlistItem) {
        guard human.coconutBalance >= item.cost else { return }
        human.coconutBalance -= item.cost
        item.isRedeemed = true

        let currentId = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        item.redeemedById = currentId.isEmpty ? nil : currentId

        QuestManager.shared.addCoconuts(
            -item.cost,
            emoji: "🎁",
            title: "兑换「\(item.title)」",
            actorId: human.id.uuidString,
            actorName: human.name
        )
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showConfetti = true }
    }
}
