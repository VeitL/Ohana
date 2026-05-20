//
//  WeightLineChart.swift
//  Ohana
//
//  Small reusable weight sparkline.
//

import SwiftUI

struct WeightLineChart: View {
    let logs: [PetWeightLog]

    private var points: [OhanaMinimalChartPoint] {
        logs
            .sorted { $0.date < $1.date }
            .map { OhanaMinimalChartPoint(date: $0.date, value: $0.weight, id: $0.id.uuidString) }
    }

    var body: some View {
        OhanaMinimalTrendChart(points: points, tint: .goTeal)
    }
}
