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
        case .manual: return "manual"
        case .treat: return "treat"
        case .plan(let kind): return "plan-\(kind.rawValue)"
        case .stock: return "stock"
        case .stockManage: return "stockManage"
        case .manage: return "manage"
        case .history: return "history"
        case .stockRecords: return "stockRecords"
        case .editLog: return "editLog"
        case .feedingOverview: return "feedingOverview"
        case .feedModeHistory: return "feedModeHistory"
        case .stockOverview: return "stockOverview"
        case .treatOverview: return "treatOverview"
        }
    }

    var defaultAdaptiveHeight: CGFloat {
        switch self {
        case .manual:
            return 390
        case .treat:
            return 420
        case .stockManage:
            return 620
        case .manage:
            return 360
        case .editLog:
            return 390
        case .stock:
            return 620
        case .plan:
            return 620
        case .history, .stockRecords:
            return 720
        case .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return 720
        }
    }

    var usesInlineOverlay: Bool {
        switch self {
        case .manual, .treat, .plan, .stock, .stockManage, .manage, .editLog:
            return true
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return false
        }
    }

    var needsFullCareLogs: Bool {
        switch self {
        case .manage, .history, .feedingOverview, .feedModeHistory, .treatOverview, .stockOverview, .stockManage, .stockRecords, .editLog:
            return true
        case .manual, .treat, .plan, .stock:
            return false
        }
    }

    var needsFullFoodRecords: Bool {
        switch self {
        case .manage, .stock, .stockManage, .stockRecords, .stockOverview:
            return true
        case .manual, .treat, .plan, .history, .editLog, .feedingOverview, .feedModeHistory, .treatOverview:
            return false
        }
    }

    var inlineOverlayMinHeight: CGFloat {
        switch self {
        case .manual, .manage, .editLog:
            return 300
        case .treat:
            return 330
        case .stock, .stockManage:
            return 430
        case .plan:
            return 500
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return defaultAdaptiveHeight
        }
    }

    var inlineOverlayMaxHeight: CGFloat {
        switch self {
        case .manual, .treat, .editLog:
            return 580
        case .manage:
            return 520
        case .stock, .stockManage:
            return 820
        case .plan:
            return 860
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return 780
        }
    }

    var inlineOverlayChromeReduction: CGFloat {
        switch self {
        case .stock, .stockManage, .plan:
            return 58
        case .manual, .treat, .manage, .editLog:
            return 50
        case .history, .stockRecords, .feedingOverview, .feedModeHistory, .stockOverview, .treatOverview:
            return 0
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

enum FeedOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .days7: return l.tr(zh: "7 天", en: "7 days", de: "7 Tage")
        case .days30: return l.tr(zh: "30 天", en: "30 days", de: "30 Tage")
        case .days90: return l.tr(zh: "90 天", en: "90 days", de: "90 Tage")
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
    let autoLog: PetCareLog?

    var isCompleted: Bool {
        reminder?.isCompleted == true || autoLog != nil
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
                        .font(.system(size: 10, weight: .black, design: .rounded))
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
                            .font(.system(size: 13, weight: (day.isToday || isSelected) ? .black : .bold, design: .rounded))
                            .foregroundStyle(textColor)
                            .frame(width: 30, height: 24)
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
                                    .font(.system(size: 7, weight: .black, design: .rounded))
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
            return Color.goPrimary
        case .missed:
            return Color.goRed
        case .pending:
            return secondaryTextColor.opacity(0.34)
        case .planned:
            return secondaryTextColor.opacity(0.22)
        }
    }
}

struct FeedStockTrendPoint: Identifiable {
    var id: String { "\(foodKind.rawValue)-\(Int(date.timeIntervalSinceReferenceDate / 86_400))" }
    let date: Date
    let value: Double
    let foodKind: FeedFoodKind
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
