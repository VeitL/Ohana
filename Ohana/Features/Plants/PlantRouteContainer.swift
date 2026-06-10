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

    init(id: UUID) {
        _plants = Query(filter: #Predicate<Plant> { plant in
            plant.id == id
        })
    }

    var body: some View {
        if let plant = plants.first {
            PlantDetailView(plant: plant)
        } else {
            PlantRouteMissingEntityView(kind: "plant")
        }
    }
}

private struct PlantRouteMissingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text("内容已不可用")
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
