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
            itemPreview(item)
                .frame(height: previewHeight(for: item))
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name(l))
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    if state.isEquipped {
                        Image(systemName: "checkmark.seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                    }
                }

                Text(item.description(l))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                guard !state.isDisabled else { return }
                handleItemTap(item)
            } label: {
                HStack(spacing: 8) {
                    Text(state.label)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(state.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    if showsShopSwitch(for: item) {
                        shopTogglePill(isOn: state.isEquipped)
                    } else if state.showCost {
                        Text("🥥 \(item.cost)")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(canAfford(item) ? Color.goYellow : tertiaryText)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    state.tint.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(state.isDisabled)
            .accessibilityIdentifier("coconut-shop-item-\(item.id)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: item.category == .appIcon ? 214 : 198, alignment: .topLeading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(state.isEquipped ? Color.goPrimary.opacity(0.52) : Color.clear, lineWidth: 1.5)
        }
        .ohanaMarchingBorder(accent: state.tint, cornerRadius: OhanaRadius.cardSoft, isActive: state.isEquipped)
        .ohanaShine(trigger: state.isEquipped, cornerRadius: OhanaRadius.cardSoft, isEnabled: state.isEquipped)
        .opacity(state.isDisabled ? 0.58 : 1)
    }

    @ViewBuilder
    func itemPreview(_ item: ShopItem) -> some View {
        if let icon = item.appIcon {
            AppIconPreview(descriptor: icon, isSelected: itemState(item).isEquipped)
        } else {
            ShopAppliedPreview(
                item: item,
                human: currentHuman,
                pet: pets.first,
                isEquipped: itemState(item).isEquipped,
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

    func itemState(_ item: ShopItem) -> ItemState {
        if let appIcon = item.appIcon {
            if !appIcon.isDefault, !appServices.appIcons.supportsAlternateIcons {
                return .init(label: l.tr(zh: "设备不支持", en: "Unsupported", de: "Nicht unterstützt"), tint: tertiaryText, isDisabled: true)
            }
            let isCurrent = appServices.appIcons.currentDescriptor.itemId == appIcon.itemId
            if isCurrent {
                return .init(label: l.tr(zh: "使用中", en: "In use", de: "Aktiv"), tint: Color.goPrimary, isEquipped: true)
            }
            if item.isPurchased {
                return .init(label: l.tr(zh: "点击切换", en: "Tap to switch", de: "Zum Wechseln tippen"), tint: Color.goTeal)
            }
            let missing = max(0, item.cost - islandSpendableHumanBalance)
            return .init(label: canAfford(item) ? l.tr(zh: "买断", en: "Unlock", de: "Freischalten") : l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥", de: "Noch \(missing)🥥"), tint: canAfford(item) ? Color.goYellow : tertiaryText, showCost: true)
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
            return .init(label: ownedItemStatus(for: item), tint: Color.goPrimary, isEquipped: isOwnedItemEquipped(item))
        }

        if let status = activeConsumableStatus(for: item) {
            return .init(label: status, tint: Color.goPrimary)
        }

        return .init(label: canAfford(item) ? l.tr(zh: "兑换", en: "Redeem", de: "Einlösen") : l.tr(zh: "不足", en: "Not enough", de: "Zu wenig"), tint: canAfford(item) ? Color.goYellow : tertiaryText, showCost: true)
    }

    func canAfford(_ item: ShopItem) -> Bool {
        item.cost <= 0 || islandSpendableHumanBalance >= item.cost
    }

    func handleItemTap(_ item: ShopItem) {
        if let appIcon = item.appIcon {
            handleAppIconTap(item, descriptor: appIcon)
            return
        }

        if item.isPurchased {
            toggleOwnedItem(item)
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

        guard canAfford(item) else {
            let missing = max(0, item.cost - islandSpendableHumanBalance)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
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

        guard canAfford(item) else {
            let missing = max(0, item.cost - islandSpendableHumanBalance)
            showToast(l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig"), icon: "exclamationmark.triangle.fill", tint: Color.goOrange)
            return
        }

        pendingPurchaseItem = item
    }
}
