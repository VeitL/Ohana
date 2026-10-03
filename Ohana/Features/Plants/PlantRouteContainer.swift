//
//  PlantRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for plant destinations.
//

import SwiftData
import SwiftUI

enum AppPlantRouteDestination: Hashable {
    case detail
    case basicInfo
}

struct AppPlantRouteContainer: View {
    @Query private var plants: [Plant]
    let destination: AppPlantRouteDestination
    let onCreateCareTask: ((TaskCreationPreset) -> Void)?
    let onDismiss: () -> Void
    let onChanged: () -> Void

    init(
        id: UUID,
        destination: AppPlantRouteDestination = .detail,
        onCreateCareTask: ((TaskCreationPreset) -> Void)? = nil,
        onDismiss: @escaping () -> Void = {},
        onChanged: @escaping () -> Void = {}
    ) {
        _plants = Query(filter: #Predicate<Plant> { plant in
            plant.id == id
        })
        self.destination = destination
        self.onCreateCareTask = onCreateCareTask
        self.onDismiss = onDismiss
        self.onChanged = onChanged
    }

    var body: some View {
        if let plant = plants.first {
            switch destination {
            case .detail:
                PlantDetailView(plant: plant, onCreateCareTask: onCreateCareTask)
            case .basicInfo:
                NavigationStack {
                    PlantBasicInfoDetailView(
                        plant: plant,
                        onClose: onDismiss,
                        onChanged: onChanged
                    )
                }
            }
        } else {
            PlantRouteMissingEntityView(kind: "plant")
                .onAppear(perform: onDismiss)
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
