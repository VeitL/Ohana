//
//  HomeFabSharedControls.swift
//  Ohana
//
//  Small shared FAB controls used outside the deleted legacy home FAB menu.
//

import SwiftUI

enum HomeFabShortcutCatalog {
    static var primaryShortcuts: [HomeFabFunctionShortcut] {
        [
            HomeFabFunctionShortcut(label: PetFeature.food.title, icon: PetFeature.food.icon, destination: .featureAggregate(.food)),
            HomeFabFunctionShortcut(label: PetFeature.hygiene.title, icon: PetFeature.hygiene.icon, destination: .featureAggregate(.hygiene)),
            HomeFabFunctionShortcut(label: PetFeature.health.title, icon: PetFeature.health.icon, destination: .featureAggregate(.health)),
            HomeFabFunctionShortcut(label: PetFeature.weight.title, icon: PetFeature.weight.icon, destination: .featureAggregate(.weight)),
            HomeFabFunctionShortcut(label: PetFeature.expense.title, icon: PetFeature.expense.icon, destination: .featureAggregate(.expense)),
            HomeFabFunctionShortcut(label: "更多", icon: "ellipsis.circle.fill", destination: nil),
        ]
    }
}

struct HomeFabActionRow: View {
    var item: HomeFabFunctionShortcut
    var rowHeight: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(item.label)
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let badge = item.badge {
                    Text(badge)
                        .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.goPrimary.opacity(0.14), in: Capsule())
                }
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.ohanaCardSurface.opacity(item.isAvailable ? 0.9 : 0.45), in: Capsule())

            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(item.isAvailable ? 1 : 0.35))
                    .frame(width: rowHeight, height: rowHeight)
                Image(systemName: item.icon)
                    .font(.system(size: rowHeight >= 48 ? 16 : 15, weight: .semibold))
                    .foregroundStyle(Color.ohanaPrimaryActionText.opacity(item.isAvailable ? 1 : 0.5))
            }
        }
        .opacity(item.isAvailable ? 1 : 0.55)
    }
}

struct HomeFabMainButton: View {
    var isExpanded: Bool
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary)
                    .frame(width: 56, height: 56)
                Image(systemName: isExpanded ? "xmark" : "square.grid.2x2.fill")
                    .font(OhanaFont.adaptive(size: 18, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(HeroAnim.buttonSpring, value: isExpanded)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("点击展开常用功能")
    }
}
