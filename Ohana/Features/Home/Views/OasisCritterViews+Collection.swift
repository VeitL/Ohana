//
//  OasisCritterViews+Collection.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension OasisCritterCodexView {
    var collectionStrip: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            ForEach(OasisUpgradeRewardCatalog.critters) { entry in
                let critter = ownedCritter(entry.id)
                let owned = critter != nil
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedCatalogId = entry.id
                        focusedCodexCatalogId = entry.id
                        lastInteractionOutcome = nil
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            OasisCritterIllustration(catalogId: entry.id, locked: !owned, size: 88, critter: critter)
                                .scaleEffect(pulseCatalogId == entry.id ? 1.06 : 1)
                            if critter?.isFeaturedOnOasis == true {
                                Image(systemName: "house.fill") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .frame(width: 22, height: 22) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                    .background(Color.goPrimary, in: Circle())
                            }
                        }
                        Text(entry.name(l))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(collectionStatus(for: entry, owned: owned))
                            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(owned ? Color.goPrimary : Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 154)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(owned ? Color.goPrimary.opacity(0.34) : Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityHint(l.tr(zh: "点按查看这个电子宠物的详细信息", en: "Tap to view this critter's details", de: "Tippen, um Details zu diesem Begleiter zu sehen"))
            }
        }
    }
}
