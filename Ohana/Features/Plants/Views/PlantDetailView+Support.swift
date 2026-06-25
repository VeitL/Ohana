//
//  PlantDetailView+Support.swift
//  Ohana
//
//  Small presentational helpers for PlantDetailView.
//

import SwiftUI

extension PlantDetailContentView {
    func detailHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.goLime)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
            Spacer()
        }
    }

    func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 16)
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var wateringIntervalText: String {
        if wateringIntervalDays != plant.wateringIntervalDays {
            return "学习后 \(wateringIntervalDays) 天"
        }
        return "周期 \(wateringIntervalDays) 天"
    }

    var fertilizingIntervalText: String {
        if fertilizingIntervalDays != plant.fertilizingIntervalDays {
            return "调整后 \(fertilizingIntervalDays) 天"
        }
        return "周期 \(fertilizingIntervalDays) 天"
    }
}
