import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var treatOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                overviewRangePicker(tint: treatTint)
                treatOverviewHero
                treatKindFilterBar

                treatFrequencyPulseChart(
                    title: treatFrequencyTitle,
                    points: filteredTreatChartPoints,
                    tint: treatTint,
                    emptyText: l.tr(zh: "记录零食后会显示频率", en: "Log treats to see frequency", de: "Snack eintragen, dann erscheint die Frequenz")
                )

                let logs = Array(filteredTreatLogsInRange.prefix(4))
                if logs.isEmpty {
                    emptyInlineState(icon: "birthday.cake", text: l.tr(zh: "还没有零食记录", en: "No treat logs yet", de: "Noch keine Snack-Einträge"))
                } else {
                    Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    ForEach(logs) { log in
                        feedLogRow(log, compact: true)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }
}
