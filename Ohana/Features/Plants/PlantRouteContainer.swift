//
//  PlantRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for plant destinations.
//

import SwiftData
import SwiftUI

struct AppPlantRouteContainer: View {
    @Query private var plants: [Plant]
    let onOpenCalendar: (UUID) -> Void

    init(id: UUID, onOpenCalendar: @escaping (UUID) -> Void = { _ in }) {
        self.onOpenCalendar = onOpenCalendar
        _plants = Query(filter: #Predicate<Plant> { plant in
            plant.id == id
        })
    }

    var body: some View {
        if let plant = plants.first {
            PlantDetailView(
                plant: plant,
                onOpenCalendar: onOpenCalendar
            )
        } else {
            PlantRouteMissingEntityView(kind: "plant")
        }
    }
}

private struct PlantRouteMissingEntityView: View {
    let kind: String
    private var l: L10n { .current }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(l.tr(zh: "内容已不可用", en: "Content is no longer available", de: "Inhalt ist nicht mehr verfügbar"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
