//
//  CoconutShopView+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CoconutShopView {
    var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokosnuss-Shop"))
                        .font(OhanaFont.title(.black))
                        .foregroundStyle(primaryText)
                    Text(l.tr(zh: "买断外观、植物装饰、称号和 App Icon。", en: "Unlock looks, plant decor, titles, and App Icons.", de: "Schalte Looks, Pflanzendeko, Titel und App Icons frei."))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }

            HStack(spacing: 18) {
                metric(label: l.tr(zh: "本人余额", en: "My balance", de: "Mein Guthaben"), value: "\(currentHumanBalance)", suffix: "🥥", tint: Color.goYellow)
                metric(label: l.tr(zh: "已拥有", en: "Owned", de: "Besitzt"), value: "\(ownedCount)", suffix: "", tint: Color.goPrimary)
                if CoconutExchangeFeatureGate.isEnabled {
                    metric(label: l.tr(zh: "待确认", en: "Pending", de: "Offen"), value: "\(incomingPendingExchanges.count)", suffix: "", tint: Color.goTeal)
                }
            }
        }
    }

    func metric(label: String, value: String, suffix: String, tint: Color) -> some View {
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
    }

    var selectedAppIconShortName: String {
        guard let item = ShopCatalog.item(id: selectedAppIcon, purchasedSet: purchasedSet) else {
            return "Ohana"
        }
        return item.name(l)
    }

    var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopItem.ShopCategory.visibleCases) { category in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            selectedCategory = category
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
                        .padding(.vertical, 9)
                        .background(selectedCategory == category ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
