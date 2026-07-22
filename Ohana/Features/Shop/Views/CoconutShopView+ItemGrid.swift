//
//  CoconutShopView+ItemGrid.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    func shopItemCard(_ item: ShopItem) -> some View {
        let state = itemState(item)
        return VStack(alignment: .leading, spacing: 10) {
            itemPreview(item, isEquipped: state.isEquipped)
                .frame(height: previewHeight(for: item))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name(l))
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(primaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    if state.isEquipped {
                        Image(systemName: "checkmark.seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                    }
                }

                Text(item.description(l))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            shopItemAction(item, state: state)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : (item.category == .appIcon ? 214 : 198), alignment: .topLeading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(state.isEquipped ? Color.goPrimary.opacity(0.52) : Color.clear, lineWidth: 1.5)
        }
        .opacity(state.isDisabled ? 0.58 : 1)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    func itemPreview(_ item: ShopItem, isEquipped: Bool) -> some View {
        if let icon = item.appIcon {
            AppIconPreview(descriptor: icon, isSelected: isEquipped)
        } else {
            ShopAppliedPreview(
                item: item,
                human: currentHuman,
                pet: pets.first,
                isEquipped: isEquipped,
                appLanguage: appLanguage
            )
        }
    }

    func previewHeight(for item: ShopItem) -> CGFloat {
        switch item.category {
        case .appIcon:
            108
        case .avatar2d, .effect, .plantDecor, .title_, .boost:
            96
        case .cashExchange:
            92
        }
    }

    struct ItemState {
        var label: String
        var tint: Color
        var showCost: Bool = false
        var isEquipped: Bool = false
        var isDisabled: Bool = false
    }

    @ViewBuilder
    func shopItemAction(_ item: ShopItem, state: ItemState) -> some View {
        Button {
            guard !state.isDisabled else { return }
            handleItemTap(item)
        } label: {
            HStack(spacing: 8) {
                Text(state.label)
                    .font(OhanaFont.caption(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                if state.showCost {
                    Text("🥥 \(item.cost)")
                        .font(OhanaFont.caption(.semibold))
                } else if item.isPurchased, item.appIcon == nil {
                    Image(systemName: "chevron.forward") // a11y: allow decorative disclosure symbol; the button label names the action.
                        .font(OhanaFont.caption2(.black))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(state.tint)
        .disabled(state.isDisabled)
        .accessibilityLabel("\(item.name(l)), \(state.label)")
        .accessibilityHint(
            purchaseSettlements[item.id] == .needsAttention
                ? purchaseRecoverySafetyHint
                : item.description(l)
        )
        .accessibilityIdentifier("coconut-shop-item-\(item.id)")
    }

    func itemState(_ item: ShopItem) -> ItemState {
        if let settlement = purchaseSettlements[item.id] {
            switch settlement {
            case .pending:
                return .init(
                    label: l.tr(zh: "正在完成兑换", en: "Finalizing", de: "Wird abgeschlossen"),
                    tint: Color.goTeal,
                    isDisabled: true
                )
            case .refunding:
                return .init(
                    label: l.tr(zh: "退款处理中", en: "Refunding", de: "Erstattung läuft"),
                    tint: Color.goOrange,
                    isDisabled: true
                )
            case .needsAttention:
                let canRetry = ShopManualRecoveryActionPolicy.canRetry(
                    reasonCode: purchaseSettlementReasons[item.id]
                )
                return .init(
                    label: recoveryInFlightItemID == item.id
                        ? l.tr(zh: "正在检查…", en: "Checking…", de: "Wird geprüft…")
                        : canRetry
                        ? l.tr(zh: "重新尝试恢复", en: "Retry recovery", de: "Wiederherstellung erneut versuchen")
                        : l.tr(zh: "需要安全检查", en: "Safety review needed", de: "Sicherheitsprüfung nötig"),
                    tint: Color.goOrange,
                    isDisabled: !canRetry || recoveryInFlightItemID != nil
                )
            }
        }
        if blockedPurchaseItemIDs.contains(item.id) {
            return .init(
                label: l.tr(zh: "正在读取恢复状态", en: "Checking recovery state", de: "Wiederherstellungsstatus wird geprüft"),
                tint: Color.goOrange,
                isDisabled: true
            )
        }
        if let appIcon = item.appIcon {
            if !appIcon.isDefault, !appServices.appIcons.supportsAlternateIcons {
                return .init(label: l.tr(zh: "设备不支持", en: "Unsupported", de: "Nicht unterstützt"), tint: tertiaryText, isDisabled: true)
            }
            let isCurrent = appServices.appIcons.currentDescriptor.itemId == appIcon.itemId
            if isCurrent {
                return .init(
                    label: l.tr(zh: "使用中", en: "In use", de: "Aktiv"),
                    tint: Color.goPrimary,
                    isEquipped: true,
                    isDisabled: true
                )
            }
            if item.isPurchased {
                return .init(label: l.tr(zh: "设为当前图标", en: "Use this icon", de: "Dieses Symbol verwenden"), tint: Color.goTeal)
            }
            return purchaseItemState(item)
        }

        if item.id == Avatar2DAccess.shopItemId, Avatar2DAccess.extraPassCount > 0 {
            return .init(
                label: l.tr(
                    zh: "库存 \(Avatar2DAccess.extraPassCount) 张",
                    en: "\(Avatar2DAccess.extraPassCount) available",
                    de: "\(Avatar2DAccess.extraPassCount) verfügbar"
                ),
                tint: Color.goPrimary,
                isEquipped: true
            )
        }

        if item.isPurchased {
            let equipped = isOwnedItemEquipped(item)
            return .init(
                label: equipped
                    ? l.tr(zh: "已拥有 · 使用中", en: "Owned · In use", de: "Besitzt · Aktiv")
                    : l.tr(zh: "已拥有 · 管理", en: "Owned · Manage", de: "Besitzt · Verwalten"),
                tint: Color.goPrimary,
                isEquipped: equipped
            )
        }

        if let status = activeConsumableStatus(for: item) {
            return .init(label: status, tint: Color.goPrimary)
        }

        return purchaseItemState(item)
    }

    func purchaseItemState(_ item: ShopItem) -> ItemState {
        switch purchaseReadiness(for: item) {
        case .ready:
            .init(label: l.tr(zh: "兑换", en: "Redeem", de: "Einlösen"), tint: Color.goYellow, showCost: true)
        case let .insufficient(missing):
            .init(
                label: l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥", de: "Noch \(missing)🥥"),
                tint: tertiaryText,
                showCost: true,
                isDisabled: true
            )
        case .walletFrozen:
            .init(label: l.tr(zh: "钱包已冻结", en: "Wallet frozen", de: "Wallet eingefroren"), tint: Color.goOrange, isDisabled: true)
        case .missingBuyer:
            .init(label: l.tr(zh: "先选择成员", en: "Choose a member", de: "Mitglied wählen"), tint: tertiaryText, isDisabled: true)
        case .loading:
            .init(label: l.tr(zh: "读取中", en: "Loading", de: "Wird geladen"), tint: tertiaryText, isDisabled: true)
        }
    }

    func purchaseReadiness(for item: ShopItem) -> ShopPurchaseReadiness {
        ShopPurchaseReadiness.resolve(
            dataState: dataState,
            hasBuyer: currentHuman != nil,
            buyerCanWrite: currentHuman.map { EconomyWalletWritePolicy.canWrite($0) } ?? false,
            spendableBalance: islandSpendableHumanBalance,
            cost: item.cost
        )
    }

    func handleItemTap(_ item: ShopItem) {
        if purchaseSettlements[item.id] == .needsAttention {
            if ShopManualRecoveryActionPolicy.canRetry(
                reasonCode: purchaseSettlementReasons[item.id]
            ) {
                retryRecovery(for: item.id)
            }
            return
        }
        if let appIcon = item.appIcon {
            handleAppIconTap(item, descriptor: appIcon)
            return
        }

        if item.isPurchased {
            showInventory = true
            return
        }

        if item.id == Avatar2DAccess.shopItemId, Avatar2DAccess.extraPassCount > 0 {
            openAvatarUpgradeTargetPicker()
            return
        }

        if activeConsumableStatus(for: item) != nil {
            showToast(l.tr(zh: "这个道具已经生效。", en: "This boost is already active.", de: "Dieser Boost ist bereits aktiv."), icon: "checkmark.circle.fill", tint: Color.goTeal)
            return
        }

        guard purchaseReadiness(for: item) == .ready else {
            showReadinessFailure(for: item)
            return
        }

        pendingPurchaseItem = item
    }

    func handleAppIconTap(_ item: ShopItem, descriptor: AppIconShopDescriptor) {
        if item.isPurchased {
            applyAppIcon(descriptor, successMessage: l.tr(zh: "App Icon 已切换", en: "App Icon changed", de: "App Icon geändert"))
            return
        }

        guard appServices.appIcons.supportsAlternateIcons else {
            showToast(l.tr(zh: "当前设备不支持切换 App Icon", en: "This device cannot change App Icons", de: "Dieses Gerät kann App Icons nicht ändern"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }

        guard purchaseReadiness(for: item) == .ready else {
            showReadinessFailure(for: item)
            return
        }

        pendingPurchaseItem = item
    }

    func showReadinessFailure(for item: ShopItem) {
        OhanaFeedback.error()
        let message: String = switch purchaseReadiness(for: item) {
        case let .insufficient(missing):
            l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig")
        case .walletFrozen:
            l.tr(zh: "当前成员的钱包已冻结。", en: "The current member's wallet is frozen.", de: "Das Wallet des aktuellen Mitglieds ist eingefroren.")
        case .missingBuyer:
            l.tr(zh: "请先选择一位在世家庭成员。", en: "Choose an active family member first.", de: "Wähle zuerst ein aktives Familienmitglied.")
        case .loading:
            l.tr(zh: "商店仍在读取，请稍候。", en: "The shop is still loading.", de: "Der Shop wird noch geladen.")
        case .ready:
            l.tr(zh: "暂时无法兑换。", en: "This cannot be redeemed right now.", de: "Dies kann gerade nicht eingelöst werden.")
        }
        showToast(message, icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
    }
}
