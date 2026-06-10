//
//  FeedPlanDraft.swift
//  Ohana
//

import Foundation
import SwiftData

struct FeedPlanMealDraft: Equatable {
    var time: Date
    var foodKind: FeedFoodKind
    var grams: Double
}

struct FeedPlanDraft: Equatable {
    var kind: FeedRuleKind
    var dailyCount: Int
    var meals: [FeedPlanMealDraft]

    var gramsPerMeal: Double {
        meals.first?.grams ?? 0
    }

    var times: [Date]

    init(
        kind: FeedRuleKind,
        dailyCount: Int,
        gramsPerMeal: Double,
        times: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.kind = kind
        self.dailyCount = min(max(dailyCount, 1), 6)
        self.times = Self.normalizedTimes(times, count: self.dailyCount, now: now, calendar: calendar)
        meals = self.times.map {
            FeedPlanMealDraft(time: $0, foodKind: .dry, grams: max(0, gramsPerMeal))
        }
    }

    init(
        kind: FeedRuleKind,
        meals: [FeedPlanMealDraft],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.kind = kind
        dailyCount = min(max(meals.count, 1), 6)
        self.meals = Self.normalizedMeals(meals, count: dailyCount, now: now, calendar: calendar)
        times = self.meals.map(\.time)
    }

    static func suggestedTimes(for count: Int, on date: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let hours: [Int] = switch clamped {
        case 1: [8]
        case 2: [8, 18]
        case 3: [8, 13, 19]
        case 4: [7, 12, 17, 21]
        case 5: [7, 11, 15, 19, 22]
        default: [7, 10, 13, 16, 19, 22]
        }
        return hours.map {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: date) ?? date
        }
    }

    static func normalizedTimes(_ times: [Date], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        var normalized = Array(times.prefix(count))
        if normalized.count < count {
            normalized += suggestedTimes(for: count, on: now, calendar: calendar).dropFirst(normalized.count)
        }
        return normalized
            .map { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                return calendar.date(
                    bySettingHour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: now
                ) ?? date
            }
            .sorted()
    }

    static func normalizedMeals(_ meals: [FeedPlanMealDraft], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [FeedPlanMealDraft] {
        let clamped = min(max(count, 1), 6)
        let normalizedTimes = normalizedTimes(meals.map(\.time), count: clamped, now: now, calendar: calendar)
        return normalizedTimes.enumerated().map { index, time in
            let source = index < meals.count ? meals[index] : FeedPlanMealDraft(time: time, foodKind: .dry, grams: 50)
            return FeedPlanMealDraft(time: time, foodKind: source.foodKind, grams: max(0, source.grams))
        }
    }
}
