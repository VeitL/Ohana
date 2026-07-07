//
//  HomeFabSharedControls.swift
//  Ohana
//
//  Small shared FAB controls used outside the deleted legacy home FAB menu.
//

import SwiftUI

enum HomeFabShortcutCatalog {
    static var primaryShortcuts: [HomeFabFunctionShortcut] {
        primaryShortcuts(l: L10n("zh"))
    }

    static func primaryShortcuts(l: L10n) -> [HomeFabFunctionShortcut] {
        [
            HomeFabFunctionShortcut(
                label: l.tr(zh: "添加成员", en: "Add member", de: "Mitglied hinzufügen"),
                icon: "person.badge.plus.fill",
                action: .submenu(.addMember)
            ),
            allPetFeaturesShortcut(l: l)
        ]
    }

    static func addMemberShortcuts(l: L10n) -> [HomeFabFunctionShortcut] {
        [
            HomeFabFunctionShortcut(
                label: l.tr(zh: "添加宠物", en: "Add pet", de: "Tier hinzufügen"),
                icon: EntityType.pet.icon,
                entityToAdd: .pet
            ),
            HomeFabFunctionShortcut(
                label: l.tr(zh: "添加人类", en: "Add human", de: "Mensch hinzufügen"),
                icon: EntityType.human.icon,
                entityToAdd: .human
            )
        ]
    }

    static func plantShortcuts(l: L10n, dueTaskCount: Int) -> [HomeFabFunctionShortcut] {
        [
            HomeFabFunctionShortcut(
                label: l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"),
                icon: "plus",
                destination: nil,
                entityToAdd: .plant
            ),
            allPlantFeaturesShortcut(l: l, dueTaskCount: dueTaskCount)
        ]
    }

    private static func allPetFeaturesShortcut(l: L10n) -> HomeFabFunctionShortcut {
        HomeFabFunctionShortcut(
            label: l.tr(zh: "全部", en: "All", de: "Alle"),
            icon: "square.grid.2x2.fill",
            destination: .petFeatureCollection
        )
    }

    private static func allPlantFeaturesShortcut(l: L10n, dueTaskCount: Int) -> HomeFabFunctionShortcut {
        HomeFabFunctionShortcut(
            label: l.tr(zh: "全部", en: "All", de: "Alle"),
            icon: "square.grid.2x2.fill",
            badge: dueTaskCount > 0 ? "\(dueTaskCount)" : nil,
            destination: .plantFeatureCollection
        )
    }
}

struct HomeFabActionRow: View {
    var item: HomeFabFunctionShortcut
    var rowHeight: CGFloat
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(homeShortcut: item)
        }()

        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(item.label)
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if showsNewFeature {
                    GrowthNewFeatureDot(size: 8)
                } else if let badge = item.badge {
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
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

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
        .accessibilityHint(l.tr(zh: "点击展开常用功能", en: "Tap to open shortcuts", de: "Tippen, um Kurzbefehle zu oeffnen"))
    }
}
