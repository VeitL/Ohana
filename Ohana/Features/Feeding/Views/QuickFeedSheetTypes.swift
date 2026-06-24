//
//  QuickFeedSheetTypes.swift
//  Ohana
//
//  Route, range, and calendar support types for the feeding sheet.
//

import SwiftUI

enum ActiveFeedSheet: Identifiable, Equatable {
    case manual
    case treat
    case plan(FeedRuleKind)
    case stock
    case stockManage
    case manage
    case history
    case stockRecords
    case editLog
    case feedingOverview
    case feedModeHistory
    case stockOverview
    case treatOverview

    static let defaultAdaptiveHeight: CGFloat = 390

    var id: String {
        switch self {
        case .manual: "manual"
        case .treat: "treat"
        case let .plan(kind): "plan-\(kind.rawValue)"
        case .stock: "stock"
        case .stockManage: "stockManage"
        case .manage: "manage"
        case .history: "history"
        case .stockRecords: "stockRecords"
        case .editLog: "editLog"
        case .feedingOverview: "feedingOverview"
        case .feedModeHistory: "feedModeHistory"
        case .stockOverview: "stockOverview"
        case .treatOverview: "treatOverview"
        }
    }

    var defaultAdaptiveHeight: CGFloat {
        switch self {
        case .manual:
            390
        case .treat:
            420
        case .stockManage:
            620
        case .manage:
            360
        case .editLog:
            390
        case .stock:
            620
        case .plan:
            620
        case .history, .stockRecords:
            720
        case .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            720
        }
    }

    var usesInlineOverlay: Bool {
        switch self {
        case .manual, .treat, .plan, .stock, .stockManage, .manage, .editLog:
            true
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            false
        }
    }

    var needsFullCareLogs: Bool {
        switch self {
        case .manage, .history, .feedingOverview, .feedModeHistory, .treatOverview, .stockOverview, .stockManage, .stockRecords, .editLog:
            true
        case .manual, .treat, .plan, .stock:
            false
        }
    }

    var needsFullFoodRecords: Bool {
        switch self {
        case .manage, .stock, .stockManage, .stockRecords, .stockOverview:
            true
        case .manual, .treat, .plan, .history, .editLog, .feedingOverview, .feedModeHistory, .treatOverview:
            false
        }
    }

    var inlineOverlayMinHeight: CGFloat {
        switch self {
        case .manual, .manage, .editLog:
            300
        case .treat:
            330
        case .stock, .stockManage:
            430
        case .plan:
            500
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            defaultAdaptiveHeight
        }
    }

    var inlineOverlayMaxHeight: CGFloat {
        switch self {
        case .manual, .treat, .editLog:
            580
        case .manage:
            520
        case .stock, .stockManage:
            820
        case .plan:
            860
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            780
        }
    }

    var inlineOverlayChromeReduction: CGFloat {
        switch self {
        case .stock, .stockManage, .plan:
            58
        case .manual, .treat, .manage, .editLog:
            50
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            0
        }
    }

    func detents(measuredHeight: CGFloat) -> Set<PresentationDetent> {
        let height = max(280, min(measuredHeight, 780))
        switch self {
        case .manual, .treat, .manage, .editLog:
            return [.height(height)]
        case .stock, .stockManage, .plan:
            return [.height(height), .large]
        case .history, .stockRecords:
            return [.large]
        case .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return [.large]
        }
    }
}

enum ActiveFeedEmbeddedPanel: Equatable {
    case modeSettings(FeedOperatingMode)
    case treat
}

enum FeedOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .days7: 7
        case .days30: 30
        case .days90: 90
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .days7: l.tr(zh: "7 天", en: "7 days", de: "7 Tage")
        case .days30: l.tr(zh: "30 天", en: "30 days", de: "30 Tage")
        case .days90: l.tr(zh: "90 天", en: "90 days", de: "90 Tage")
        }
    }
}

struct FeedOverviewChartPoint: Identifiable {
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    let date: Date
    let value: Double
}

struct FeedPlanCalendarOccurrence: Identifiable {
    var id: String { "\(event.id.uuidString)-\(Int(date.timeIntervalSince1970 / 60))" }
    let date: Date
    let event: Event
    let reminder: Reminder?
    let autoLedgerEntry: QuickFeedLedgerEntry?

    var isCompleted: Bool {
        reminder?.isCompleted == true || autoLedgerEntry != nil
    }
}

struct FeedPlanCalendarDaySummary: Identifiable {
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let markers: [FeedPlanCalendarMarker]
}

struct FeedPlanCalendarMarker: Identifiable {
    enum Status {
        case completed
        case missed
        case pending
        case planned
    }

    let id = UUID()
    let status: Status
}

struct FeedPlanMonthlyCalendarView: View {
    let weekdayTitles: [String]
    let days: [FeedPlanCalendarDaySummary]
    let tint: Color
    let textColor: Color
    let secondaryTextColor: Color
    let selectedDate: Date
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(_ day: FeedPlanCalendarDaySummary) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
        return Group {
            if day.isInDisplayedMonth {
                Button {
                    onSelectDate(day.date)
                } label: {
                    VStack(spacing: 5) {
                        Text("\(day.dayNumber)")
                            .font(OhanaFont.adaptive(size: 13, weight: (day.isToday || isSelected) ? .black : .bold, design: .rounded))
                            .foregroundStyle(textColor)
                            .frame(width: 30, height: 24) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(tint.opacity(0.24))
                                } else if day.isToday {
                                    Capsule()
                                        .strokeBorder(tint.opacity(0.42), lineWidth: 1)
                                }
                            }

                        HStack(spacing: 2.5) {
                            ForEach(Array(day.markers.prefix(6))) { marker in
                                markerShape(marker.status)
                            }
                            if day.markers.count > 6 {
                                Text("+")
                                    .font(OhanaFont.adaptive(size: 7, weight: .black, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
        }
    }

    @ViewBuilder
    private func markerShape(_ status: FeedPlanCalendarMarker.Status) -> some View {
        switch status {
        case .planned:
            Capsule()
                .fill(markerColor(status))
                .frame(width: 7, height: 2.5)
        case .completed, .missed, .pending:
            Circle()
                .fill(markerColor(status))
                .frame(width: 4.5, height: 4.5)
        }
    }

    private func markerColor(_ status: FeedPlanCalendarMarker.Status) -> Color {
        switch status {
        case .completed:
            Color.goPrimary
        case .missed:
            Color.goRed
        case .pending:
            secondaryTextColor.opacity(0.34)
        case .planned:
            secondaryTextColor.opacity(0.22)
        }
    }
}

enum FeedInputField: Hashable {
    case manualGrams
    case treatGrams
    case planGrams
    case planMealGrams(Int)
    case stockBrand
    case stockWeight
    case stockExpenseAmount
    case stockDaily
    case stockCorrection
    case editLogGrams
}
