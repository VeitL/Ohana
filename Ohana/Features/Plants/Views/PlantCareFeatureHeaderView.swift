//
//  PlantCareFeatureHeaderView.swift
//  Ohana
//
//  State-independent header for plant care feature routes.
//

import SwiftUI

struct PlantCareFeatureHeaderView: View {
    let plant: Plant?
    let feature: PlantCareFeatureDestination
    let pageTitle: String
    let aggregateSubtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let plant {
                Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: plant.themeColorHex).opacity(0.16), in: Circle())
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: feature.icon)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(feature.tint)
                    .frame(width: 46, height: 46)
                    .background(feature.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plant?.name ?? pageTitle)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(plant == nil ? aggregateSubtitle : pageTitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-header")
    }
}

nonisolated enum PlantCareFeatureAccessibility {
    static func rootID(feature: PlantCareFeatureDestination, focusedPlantID: UUID?) -> String {
        guard let focusedPlantID else {
            return "plant-care-feature-\(feature.rawValue)-aggregate"
        }
        return "plant-care-feature-\(feature.rawValue)-\(focusedPlantID.uuidString)"
    }
}
