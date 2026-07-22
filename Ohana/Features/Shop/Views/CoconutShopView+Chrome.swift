//
//  CoconutShopView+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        spendableMetric
                        inventoryMetric
                        if CoconutExchangeFeatureGate.isEnabled {
                            pendingExchangeMetric
                        }
                    }
                } else {
                    HStack(spacing: 18) {
                        spendableMetric
                        inventoryMetric
                        if CoconutExchangeFeatureGate.isEnabled {
                            pendingExchangeMetric
                        }
                    }
                }
            }

            buyerSummaryControl
                .accessibilityIdentifier("coconut-shop-screen")
        }
    }

    @ViewBuilder
    var buyerSummaryControl: some View {
        if activeHumans.count > 1 {
            Menu {
                ForEach(activeHumans) { human in
                    Button {
                        shopBuyerID = human.id
                        OhanaFeedback.selection()
                    } label: {
                        if currentHuman?.id == human.id {
                            Label(human.name, systemImage: "checkmark")
                        } else {
                            Text(human.name)
                        }
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    buyerSummaryLabel
                    Image(systemName: "chevron.up.chevron.down") // a11y: allow decorative menu affordance; the menu label names the selected buyer.
                        .font(OhanaFont.caption2(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(l.tr(zh: "为本次商店会话选择付款成员", en: "Chooses the paying member for this shop session", de: "Wählt das zahlende Mitglied für diese Shop-Sitzung"))
        } else {
            buyerSummaryLabel
        }
    }

    var buyerSummaryLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: currentHuman == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle")
                .foregroundStyle(currentHuman == nil ? Color.goOrange : Color.goTeal)
                .accessibilityHidden(true)
            Text(currentHumanSummary)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var spendableMetric: some View {
        metric(
            label: l.tr(zh: "全岛可兑换", en: "Island spendable", de: "Inselweit verfügbar"),
            value: "\(islandSpendableHumanBalance)",
            suffix: "🥥",
            tint: Color.goYellow,
            accessibilityIdentifier: "coconut-shop-current-human-balance"
        )
    }

    var inventoryMetric: some View {
        Button {
            showInventory = true
        } label: {
            metric(
                label: l.tr(zh: "百宝箱", en: "Treasure box", de: "Schatzkiste"),
                value: "\(ownedCount)",
                suffix: "",
                tint: Color.goPrimary,
                accessibilityIdentifier: nil
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("coconut-shop-owned-count")
        .accessibilityHint(l.tr(zh: "打开百宝箱管理已拥有内容", en: "Opens your owned items for management", de: "Öffnet deine gekauften Inhalte zur Verwaltung"))
    }

    var pendingExchangeMetric: some View {
        metric(
            label: l.tr(zh: "待确认", en: "Pending", de: "Offen"),
            value: "\(incomingPendingExchanges.count)",
            suffix: "",
            tint: Color.goTeal,
            accessibilityIdentifier: nil
        )
    }

    @ViewBuilder
    var purchaseSettlementNotice: some View {
        let needsAttention = purchaseSettlements.values.contains(.needsAttention)
            || !blockedPurchaseItemIDs.isEmpty
        let recoveryItemID = allItems.first {
            purchaseSettlements[$0.id] == .needsAttention
        }?.id ?? purchaseSettlements.first { $0.value == .needsAttention }?.key
        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        needsAttention
                            ? l.tr(
                                zh: "有一笔兑换尚未安全完成或退款。它不会再次扣款，保留本机数据即可继续恢复。",
                                en: "A redemption has not safely completed or refunded. It cannot be charged again; keep the local data to continue recovery.",
                                de: "Eine Einlösung wurde noch nicht sicher abgeschlossen oder erstattet. Sie wird nicht erneut belastet; behalte die lokalen Daten für die Wiederherstellung."
                            )
                            : l.tr(
                                zh: "上一笔兑换或退款仍在安全结算；对应商品暂时不会再次扣款。",
                                en: "A previous redemption or refund is still settling safely. That item cannot be charged again.",
                                de: "Eine frühere Einlösung oder Erstattung wird noch sicher verarbeitet. Dieser Artikel wird nicht erneut belastet."
                            )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    if let recoveryItemID,
                       let reason = purchaseSettlementReasons[recoveryItemID] {
                        Text(purchaseRecoveryReasonMessage(reason))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } icon: {
                Image(systemName: needsAttention ? "exclamationmark.triangle.fill" : "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .accessibilityHidden(true)
            }

            if let recoveryItemID,
               ShopManualRecoveryActionPolicy.canRetry(
                   reasonCode: purchaseSettlementReasons[recoveryItemID]
               ) {
                Button {
                    retryRecovery(for: recoveryItemID)
                } label: {
                    if recoveryInFlightItemID == recoveryItemID {
                        Label(
                            l.tr(zh: "正在检查…", en: "Checking…", de: "Wird geprüft…"),
                            systemImage: "clock"
                        )
                    } else {
                        Label(
                            l.tr(zh: "重新尝试恢复", en: "Retry recovery", de: "Wiederherstellung erneut versuchen"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(recoveryInFlightItemID != nil)
                .accessibilityIdentifier("coconut-shop-retry-recovery")
                .accessibilityHint(purchaseRecoverySafetyHint)
            }
        }
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(needsAttention ? Color.goOrange : Color.goTeal)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (needsAttention ? Color.goOrange : Color.goTeal).opacity(0.12),
            in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
        )
        .accessibilityIdentifier("coconut-shop-settlement-notice")
    }

    var currentHumanSummary: String {
        guard let currentHuman else {
            return l.tr(
                zh: "先选择一位在世家庭成员，才能发起兑换。",
                en: "Choose an active family member before redeeming.",
                de: "Wähle vor dem Einlösen ein aktives Familienmitglied."
            )
        }
        guard EconomyWalletWritePolicy.canWrite(currentHuman) else {
            return l.tr(
                zh: "当前成员：\(currentHuman.name) · 纪念钱包已冻结",
                en: "Current member: \(currentHuman.name) · memorial wallet frozen",
                de: "Aktuelles Mitglied: \(currentHuman.name) · Gedenk-Wallet eingefroren"
            )
        }
        return l.tr(
            zh: "当前成员：\(currentHuman.name) · 不足时由其他在世成员共同补足",
            en: "Current member: \(currentHuman.name) · active members can cofund a shortfall",
            de: "Aktuelles Mitglied: \(currentHuman.name) · aktive Mitglieder können gemeinsam ergänzen"
        )
    }

    func metric(label: String, value: String, suffix: String, tint: Color, accessibilityIdentifier: String?) -> some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)\(suffix)")
        .accessibilityIdentifier(accessibilityIdentifier ?? "coconut-shop-metric-\(label)")
    }

    var categoryRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShopItem.ShopCategory.visibleCases) { category in
                        Button {
                            OhanaFeedback.selection()
                            withAnimation(GoMotion.feedback) {
                                selectedCategory = category
                                proxy.scrollTo(category.id, anchor: .center)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(category.title(l))
                                    .font(OhanaFont.caption(.black))
                            }
                            .foregroundStyle(selectedCategory == category ? Color.ohanaPrimaryActionText : primaryText)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 44)
                            .background(selectedCategory == category ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("coconut-shop-category-\(category.rawValue)")
                        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                        .id(category.id)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                proxy.scrollTo(effectiveSelectedCategory.id, anchor: .center)
            }
            .onChange(of: effectiveSelectedCategory) { _, category in
                withAnimation(GoMotion.feedback) {
                    proxy.scrollTo(category.id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    var categoryIntro: some View {
        if effectiveSelectedCategory == .plantDecor {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "leaf.circle.fill") // a11y: allow decorative category marker; nearby copy names the shelf
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "植物装饰只影响绿洲外观", en: "Plant decor is cosmetic", de: "Pflanzendeko ist kosmetisch"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(primaryText)
                    Text(l.tr(
                        zh: "添加植物、护理计划、资料库和提醒仍然免费；这里兑换的是场景、盆器和岛屿氛围。",
                        en: "Adding plants, care plans, catalog, and reminders stay free. This shelf unlocks scenes, pot skins, and island ambience.",
                        de: "Pflanzen, Pflegepläne, Katalog und Erinnerungen bleiben kostenlos. Dieses Regal schaltet Szenen, Topf-Skins und Inselstimmung frei."
                    ))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.goTeal.opacity(0.22), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
