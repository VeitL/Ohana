//
//  HumanWishlistView.swift
//  Ohana
//
//  模块1：椰子心愿单商城

import SwiftUI
import SwiftData

struct HumanWishlistContentView: View {
    let human: Human
    let myItems: [WishlistItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var showAddSheet = false
    @State private var showConfetti = false
    @State private var newTitle = ""
    @State private var newCost = 10
    @State private var redeemingItemIDs: Set<UUID> = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(human: Human, myItems: [WishlistItem]) {
        self.human = human
        self.myItems = myItems
    }

    private var pendingItems: [WishlistItem] { myItems.filter { !$0.isRedeemed } }
    private var redeemedItems: [WishlistItem] { myItems.filter { $0.isRedeemed } }
    private var isPrivacyLocked: Bool {
        human.isPrivate(.wishlist, viewedBy: UUID(uuidString: activeHumanIdStr))
    }
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                wishlistContent
            }

            // FAB — iOS 26 Primary CTA
            if !isPrivacyLocked {
                HumanModuleFloatingActionButton(
                    title: l.tr(zh: "许愿", en: "Wish", de: "Wunsch"),
                    icon: "plus"
                ) {
                    showAddSheet = true
                }
                .padding(.bottom, 28)
            }
        }
        .confettiOverlay(isShowing: $showConfetti)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) { addWishSheet }
        .onDisappear { commandQueue.cancelAll() }
    }

    private var wishlistContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                metricStrip
                    .padding(.horizontal, 20)

                HumanPrivateDataNotice(human: human, field: .wishlist)
                    .padding(.horizontal, 20)

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

    private var header: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "椰子资产", en: "Coconuts", de: "Kokosnüsse"),
            subtitle: human.name,
            onClose: { dismiss() }
        )
    }

    private var metricStrip: some View {
        HumanModuleMetricStrip(metrics: [
            FeatureHubMetric(
                id: "balance",
                title: l.tr(zh: "余额", en: "Balance", de: "Saldo"),
                value: "\(human.coconutBalance)🥥"
            ),
            FeatureHubMetric(
                id: "pending",
                title: l.tr(zh: "待兑换", en: "Pending", de: "Offen"),
                value: "\(pendingItems.count)"
            )
        ])
    }

    private var privacyLockedView: some View {
        HumanModulePrivacyLockedView(
            title: l.tr(zh: "椰子资产仅本人可见", en: "Coconuts are private", de: "Kokosnüsse sind privat"),
            message: l.tr(zh: "当前家庭成员无权查看余额、心愿和兑换记录。", en: "This family member cannot view balance, wishes, or redemptions.", de: "Dieses Familienmitglied kann Saldo, Wünsche oder Einlösungen nicht sehen.")
        )
    }

    // MARK: - Balance Card (inner)
    private func wishCard(item: WishlistItem, redeemed: Bool) -> some View {
        wishlistSurface {
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
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                }
                Spacer()

                if !redeemed {
                    let isRedeeming = redeemingItemIDs.contains(item.id)
                    let canRedeem = human.coconutBalance >= item.cost && !isRedeeming
                    Button { redeem(item: item) } label: {
                        Text(isRedeeming ? "兑换中" : "兑换")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(canRedeem ? Color.arkInk : .primary.opacity(0.3))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                canRedeem ? Color.goYellow : Color.ohanaControlFill,
                                in: Capsule()
                            )
                    }
                    .disabled(!canRedeem)
                    .buttonStyle(ScaleButtonStyle())

                    Button { delete(item: item) } label: {
                        Image(systemName: "trash").accessibilityHidden(true)
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
                    }
                    .buttonStyle(ScaleButtonStyle())
                } else {
                    Text("已兑换 ✓")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
            }
            .padding(16)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.footnote(.black))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌟").font(OhanaFont.metric(size: 56))
            Text("还没有心愿")
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text("许下你想要的礼物\n让家人帮你兑换！")
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Wish Sheet
    private var addWishSheet: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.ohanaDivider)
                    .frame(width: 40, height: 4) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .padding(.top, 12).padding(.bottom, 20)

                Text("许一个愿 🌟")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    // 心愿标题
                    HStack {
                        Image(systemName: "sparkles").accessibilityHidden(true)
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        TextField("心愿内容（例如：新耳机）", text: $newTitle)
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.ohanaCardStroke, lineWidth: 1))

                    // 椰子费用
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("兑换费用")
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(Color.ohanaPrimaryText)
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
                            Text("5 🥥").font(OhanaFont.caption2()).foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            Spacer()
                            Text("500 🥥").font(OhanaFont.caption2()).foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.ohanaCardStroke, lineWidth: 1))
                }
                .padding(.horizontal, 24).padding(.top, 20)

                Spacer()

                Button {
                    createWish()
                } label: {
                    Text("保存心愿")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(newTitle.isEmpty ? Color.goPrimary.opacity(0.4) : Color.goPrimary,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(newTitle.isEmpty)
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Command Intents

    private func createWish() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let cost = newCost
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        newTitle = ""
        newCost = 10
        showAddSheet = false

        let command = DomainCommand.humanWishlistCreate(humanID: human.id)
        commandQueue.enqueue(command) {
            do {
                try HumanWishlistCommandExecutor(context: modelContext, services: appServices).createItem(
                    input: HumanWishlistCommandInput(title: title, cost: cost),
                    for: human,
                    note: "humanWishlist.create"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func delete(item: WishlistItem) {
        let command = DomainCommand.humanWishlistDelete(humanID: human.id, itemID: item.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            do {
                try HumanWishlistCommandExecutor(context: modelContext, services: appServices).deleteItem(
                    item,
                    for: human,
                    note: "humanWishlist.delete"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func redeem(item: WishlistItem) {
        guard human.coconutBalance >= item.cost, !redeemingItemIDs.contains(item.id) else { return }
        redeemingItemIDs.insert(item.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let command = DomainCommand.humanWishlistRedeem(humanID: human.id, itemID: item.id)
        let redeemerId = activeHumanIdStr
        commandQueue.enqueue(command) {
            defer { redeemingItemIDs.remove(item.id) }
            do {
                try HumanWishlistCommandExecutor(context: modelContext, services: appServices).redeemItem(
                    item,
                    for: human,
                    redeemedById: redeemerId,
                    note: "humanWishlist.redeem"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { showConfetti = true }
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func wishlistSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}
