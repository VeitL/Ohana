//
//  CoconutGachaRevealPreview.swift
//  Ohana
//
//  Preview fixtures for gacha reveal surfaces.
//

import SwiftUI

#Preview("Gacha Reveal") {
    let item = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId).commonItems[0]
    let hidden = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId).hiddenItem!

    return VStack(spacing: 18) {
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: item.placeholderSymbol,
            rarity: item.rarity,
            trigger: 1,
            collectibleItem: item,
            revealCardPhase: .revealed,
            isNewCollectible: true
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: hidden.placeholderSymbol,
            rarity: hidden.rarity,
            trigger: 2,
            collectibleItem: hidden,
            revealCardPhase: .secretBurst,
            isNewCollectible: true
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: item.placeholderSymbol,
            rarity: item.rarity,
            trigger: 4,
            collectibleItem: item,
            revealCardPhase: .toyReady
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: "🥥",
            rarity: .rare,
            trigger: 3
        )
    }
    .padding()
    .background(OhanaAppBackground())
}
