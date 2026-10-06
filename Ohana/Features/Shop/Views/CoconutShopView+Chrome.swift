//
//  CoconutShopView+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                spendableMetric
                inventoryMetric
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
            label: l.text(ShopShelfCopy.availableBalance),
            value: "\(islandSpendableHumanBalance)",
            suffix: "🥥",
            tint: Color.goYellow,
            accessibilityIdentifier: "coconut-shop-island-spendable-balance"
        )
    }

    var personalBalanceMetric: some View {
        metric(
            label: l.tr(
                zh: "当前成员",
                en: "Current member",
                de: "Aktuelles Mitglied",
                es: "Miembro actual",
                pt: "Membro atual",
                fr: "Membre actuel",
                ja: "現在のメンバー",
                ko: "현재 구성원",
                it: "Membro attuale"
            ),
            value: "\(currentHumanBalance)",
            suffix: "🥥",
            tint: Color.goTeal,
            accessibilityIdentifier: "coconut-shop-current-human-balance"
        )
    }

    var inventoryMetric: some View {
        Button {
            showInventory = true
        } label: {
            Label(l.tr(zh: "百宝箱", en: "Treasure box", de: "Schatzkiste"), systemImage: "shippingbox")
                .font(OhanaFont.caption(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("coconut-shop-owned-count")
        .accessibilityHint(l.tr(zh: "打开百宝箱管理已拥有内容", en: "Opens your owned items for management", de: "Öffnet deine gekauften Inhalte zur Verwaltung"))
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
                            ? l.text(ShopShelfCopy.settlementAttention)
                            : l.text(ShopShelfCopy.settlementPending)
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
        guard let currentHuman else { return l.text(ShopShelfCopy.chooseBuyer) }
        return "\(l.text(ShopShelfCopy.payingMember)): \(currentHuman.name)"
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

    func shopShelfSection(_ section: ShopShelfSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title(l))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("coconut-shop-section-\(section.id)")

            if section == .oasis {
                Text(l.text(ShopShelfCopy.plantCosmetic))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: shopGridColumns, spacing: 12) {
                ForEach(allItems.filter(section.contains)) { item in
                    shopItemCard(item)
                }
            }
        }
    }
}
