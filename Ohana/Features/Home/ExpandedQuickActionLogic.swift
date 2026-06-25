//
//  ExpandedQuickActionLogic.swift
//  Ohana
//
//  State and routing decisions for expanded-card quick actions.
//

import Foundation
import SwiftUI

nonisolated enum ExpandedPetQuickTapRoute {
    case perform(String)
    case waterManagement
    case weight
    case expense
    case moment
    case health
    case none
}

nonisolated enum ExpandedPetQuickLongPressRoute {
    case feedDetail
    case waterManagement
    case walk
    case playDetail
    case pottyDetail
    case hygiene
    case health
    case medication
    case weightDetail
    case expenseDetail
    case momentHistory
    case none
}

nonisolated enum ExpandedHumanQuickRoute {
    case privacyAlert
    case weightQuick
    case workoutQuick
    case medicationAdd
    case noteQuick
    case expenseQuick
    case weightDetail
    case workoutDetail
    case medicationDetail
    case noteDetail
    case expenseDetail
    case allFeatures
    case selectHuman
    case none
}

nonisolated struct ExpandedQuickMenuPolicy: Equatable {
    let showsMenu: Bool
    let showsQuickButton: Bool

    static let none = ExpandedQuickMenuPolicy(showsMenu: false, showsQuickButton: false)
    static let detailOnly = ExpandedQuickMenuPolicy(showsMenu: true, showsQuickButton: false)
    static let quickWithDetail = ExpandedQuickMenuPolicy(showsMenu: true, showsQuickButton: true)
}

nonisolated struct HomeFeedQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let date: Date
    let amountGrams: Double
    let source: FeedLogSource
}

nonisolated struct HomeCareQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let actionType: String
    let date: Date
    let amountValue: Double
}

nonisolated struct HomeHygieneQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let hygieneType: HygieneType
    let date: Date
}

nonisolated struct HomeWalkQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let startDate: Date
    let distanceMeters: Double
}

nonisolated struct HomePottyQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let date: Date
    let pottyType: PottyType
}

nonisolated struct HomePetExpenseQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let date: Date
    let amount: Double
}

nonisolated struct HomePetWeightQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let date: Date
    let weightKg: Double
}

nonisolated struct HomePetMomentQuickActionEntry: Equatable, Identifiable {
    let id: UUID
    let petId: UUID
    let date: Date
}

private nonisolated struct HomeFeedQuickActionState {
    let rules: FeedRuleState
    let todayEntries: [HomeFeedQuickActionEntry]
    let todayPlanReminders: [Reminder]
    let catchUpPlanReminders: [Reminder]
    let expiredMissedPlanReminders: [Reminder]

    init(
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) {
        rules = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        todayEntries = feedingLedgerEntries
            .filter { entry in
                entry.petId == pet.id &&
                    entry.source != .treat &&
                    calendar.isDate(entry.date, inSameDayAs: now)
            }
        todayPlanReminders = rules.todayManualReminders
        catchUpPlanReminders = rules.catchUpManualReminders
        expiredMissedPlanReminders = rules.expiredMissedManualReminders
    }

    var operatingMode: FeedOperatingMode { rules.operatingMode }
    var manualMainCount: Int { todayEntries.count { $0.source == .manualMain } }
    var autoMainCount: Int { todayEntries.count { $0.source == .autoMain } }
    var completedTodayPlanCount: Int { todayPlanReminders.count(where: \.isCompleted) }
    var todayManualPlanTotalCount: Int { max(todayPlanReminders.count, rules.manualReminderEvents.count, 1) }
    var todayManualPlanMissedCount: Int { expiredMissedPlanReminders.isEmpty ? catchUpPlanReminders.count : 0 }
    var hasMissedManualPlan: Bool { expiredMissedPlanReminders.isEmpty && !catchUpPlanReminders.isEmpty }
    var lastExpiredManualPlanDate: Date? { expiredMissedPlanReminders.map(\.scheduledAt).max() }
    var nextManualReminder: Reminder? { rules.nextPendingManualReminder }
}

enum ExpandedQuickActionLogic {
    static func feedDashboard(
        for pet: Pet,
        allEvents: [Event],
        now: Date
    ) -> FeedingDashboardState {
        let goal = FeedGoalPreferences.manualGoalCount(for: pet.id, default: 3)
        return FeedingDashboardState(pet: pet, allEvents: allEvents, manualGoalCount: goal, careLogs: [], now: now)
    }

    nonisolated static func waterRuleState(for pet: Pet, allEvents: [Event], now: Date = Date()) -> WaterRuleState {
        WaterRuleState(pet: pet, allEvents: allEvents, now: now)
    }

    nonisolated static func playPlanEvent(for pet: Pet, allEvents: [Event]) -> Event? {
        let title = "\(pet.name) 陪玩计划"
        return allEvents
            .filter {
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet($0, petId: pet.id.uuidString) &&
                    $0.title == title
            }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    nonisolated static func defaultWaterAmountMl(for pet: Pet) -> Double? {
        let key = pet.id.uuidString
        let settings = WaterCareSettingsStore.snapshot(petKey: key)
        return settings.waterAmountEnabled ? settings.waterAmountMl : nil
    }

    static func pendingFeedReminder(
        for pet: Pet,
        allEvents: [Event],
        now: Date
    ) -> Reminder? {
        feedDashboard(for: pet, allEvents: allEvents, now: now).nextManualReminder
    }

    nonisolated static func feedAppearsComplete(
        for pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        now: Date,
        calendar cal: Calendar = .current
    ) -> Bool {
        let state = HomeFeedQuickActionState(
            pet: pet,
            allEvents: allEvents,
            feedingLedgerEntries: feedingLedgerEntries,
            now: now,
            calendar: cal
        )
        switch state.operatingMode {
        case .manual:
            return state.manualMainCount > 0
        case .manualReminder:
            return state.completedTodayPlanCount >= state.todayManualPlanTotalCount
        case .autoFeeder:
            return state.autoMainCount >= max(state.rules.autoFeederEvents.count, 1)
        }
    }

    nonisolated static func showsAttentionDot(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        careLedgerEntries: [HomeCareQuickActionEntry],
        walkLedgerEntries _: [HomeWalkQuickActionEntry],
        pottyLedgerEntries _: [HomePottyQuickActionEntry],
        now: Date
    ) -> Bool {
        let waterCycleSnapshot = waterCycleLogSnapshot(for: pet, careLedgerEntries: careLedgerEntries)
        switch item.actionType {
        case "waterChange":
            if WaterCareCycleStatusCalculator.waterChangeStatus(for: pet, now: now, logSnapshot: waterCycleSnapshot)?.isOverdue == true {
                return true
            }
        case "filterClean":
            if WaterCareCycleStatusCalculator.filterCleanStatus(for: pet, now: now, logSnapshot: waterCycleSnapshot)?.isOverdue == true ||
                WaterCareCycleStatusCalculator.filterReplaceStatus(for: pet, now: now, logSnapshot: waterCycleSnapshot)?.isOverdue == true {
                return true
            }
        case "water" where WaterQuickActionPolicy.isAquatic(species: pet.species):
            if WaterCareCycleStatusCalculator.mostUrgentWaterWarning(for: pet, now: now, logSnapshot: waterCycleSnapshot) != nil {
                return true
            }
        case "feed":
            let state = HomeFeedQuickActionState(
                pet: pet,
                allEvents: allEvents,
                feedingLedgerEntries: feedingLedgerEntries,
                now: now,
                calendar: .current
            )
            return state.operatingMode == .manualReminder && state.hasMissedManualPlan
        default:
            break
        }

        if CarePlanOverdueStatusCalculator.warning(
            for: item.actionType,
            pet: pet,
            events: allEvents,
            now: now,
            waterCycleLogSnapshot: waterCycleSnapshot
        ) != nil {
            return true
        }

        if item.actionType == "play", let event = playPlanEvent(for: pet, allEvents: allEvents) {
            let cal = Calendar.current
            let todayDone = todayCareEntryCount(
                .play,
                pet: pet,
                careLedgerEntries: careLedgerEntries,
                now: now,
                calendar: cal
            ) > 0
            return !todayDone && cal.startOfDay(for: event.startDate) <= cal.startOfDay(for: now)
        }
        return false
    }

    nonisolated static func isCompleted(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        careLedgerEntries: [HomeCareQuickActionEntry],
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry] = [],
        walkLedgerEntries: [HomeWalkQuickActionEntry],
        pottyLedgerEntries: [HomePottyQuickActionEntry],
        petWeightLedgerEntries: [HomePetWeightQuickActionEntry] = [],
        now: Date,
        calendar cal: Calendar = .current
    ) -> Bool {
        switch item.actionType {
        case "feed":
            return feedAppearsComplete(
                for: pet,
                allEvents: allEvents,
                feedingLedgerEntries: feedingLedgerEntries,
                now: now,
                calendar: cal
            )
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                return todayCareEntryCount(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0 ||
                    todayCareEntryCount(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
            }
            let waterState = waterRuleState(for: pet, allEvents: allEvents)
            if waterState.operatingMode == .reminder {
                return !waterState.todayPlanReminders.isEmpty && waterState.pendingTodayPlanReminders.isEmpty
            }
            return todayCareEntryCount(.watering, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "waterChange":
            return todayCareEntryCount(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "walk":
            return todayWalkEntries(for: pet, walkLedgerEntries: walkLedgerEntries, now: now, calendar: cal).isEmpty == false
        case "potty":
            return todayPottyEntries(for: pet, pottyLedgerEntries: pottyLedgerEntries, now: now, calendar: cal).isEmpty == false
        case "litter":
            return todayCareEntryCount(.litter, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "play":
            return todayCareEntryCount(.play, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "groom":
            return todayHygieneEntries(for: pet, hygieneLedgerEntries: hygieneLedgerEntries, now: now, calendar: cal).isEmpty == false
        case "medication":
            let activeMeds = pet.medications.filter(\.isActiveToday)
            let planned = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: now, for: $1) }
            guard planned > 0 else { return false }
            let done = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: $1.id) }
            return done >= planned
        case "filterClean":
            return todayCareEntryCount(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "cageCleaning":
            return todayCareEntryCount(.cageCleaning, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "freeFlight":
            return todayCareEntryCount(.freeFlight, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "misting":
            return todayCareEntryCount(.misting, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "substrateChange":
            return todayCareEntryCount(.substrateChange, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal) > 0
        case "weight":
            return todayWeightEntries(for: pet, weightLedgerEntries: petWeightLedgerEntries, now: now, calendar: cal).isEmpty == false
        default:
            return false
        }
    }

    nonisolated static func countText(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        careLedgerEntries: [HomeCareQuickActionEntry],
        hygieneLedgerEntries _: [HomeHygieneQuickActionEntry] = [],
        walkLedgerEntries: [HomeWalkQuickActionEntry],
        pottyLedgerEntries: [HomePottyQuickActionEntry],
        petExpenseLedgerEntries: [HomePetExpenseQuickActionEntry] = [],
        petWeightLedgerEntries: [HomePetWeightQuickActionEntry] = [],
        petMomentEntries: [HomePetMomentQuickActionEntry] = [],
        now: Date,
        calendar cal: Calendar = .current,
        l: L10n = .current
    ) -> String? {
        let waterCycleSnapshot = waterCycleLogSnapshot(for: pet, careLedgerEntries: careLedgerEntries)
        switch item.actionType {
        case "feed":
            let state = HomeFeedQuickActionState(
                pet: pet,
                allEvents: allEvents,
                feedingLedgerEntries: feedingLedgerEntries,
                now: now,
                calendar: cal
            )
            switch state.operatingMode {
            case .manual:
                let count = state.manualMainCount
                if count > 0 { return "手动 \(count)餐" }
                return pet.dailyPortionGrams > 0 ? "\(Int(pet.dailyPortionGrams.rounded()))g" : "待设置"
            case .manualReminder:
                if state.hasMissedManualPlan {
                    return "未打卡 \(state.todayManualPlanMissedCount)餐"
                }
                if let lastExpired = state.lastExpiredManualPlanDate {
                    let time = quickPlanTimeText(lastExpired, now: now, calendar: cal)
                    return l.tr(zh: "最后逾期 \(time)", en: "Last missed \(time)", de: "Zuletzt überfällig \(time)")
                }
                if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                    return overdue
                }
                return "计划 \(state.completedTodayPlanCount)/\(state.todayManualPlanTotalCount)"
            case .autoFeeder:
                return "自动 \(state.autoMainCount)次"
            }
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                if let warning = WaterCareCycleStatusCalculator.mostUrgentWaterWarning(for: pet, now: now, calendar: cal, logSnapshot: waterCycleSnapshot) {
                    return waterCycleOverdueText(title: warning.title, days: warning.status.overdueDays, l: l)
                }
                return aquaticWaterStatusText(for: pet, careLedgerEntries: careLedgerEntries, calendar: cal, now: now)
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            let waterState = waterRuleState(for: pet, allEvents: allEvents)
            if waterState.operatingMode == .reminder {
                if waterState.missedCount > 0 {
                    return "待补 \(waterState.missedCount)次"
                }
                return "计划 \(waterState.completionText)"
            }
            let count = todayCareEntryCount(.watering, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal)
            if count > 0 { return "今日 \(count)次" }
            if let amount = defaultWaterAmountMl(for: pet) {
                return "\(Int(amount.rounded()))ml"
            }
            return "只记录次数"
        case "waterChange":
            if let status = WaterCareCycleStatusCalculator.waterChangeStatus(for: pet, now: now, calendar: cal, logSnapshot: waterCycleSnapshot) {
                if status.isOverdue { return status.compactDueText(l: l) }
                if status.isDueToday { return l.tr(zh: "今天应换", en: "Due today", de: "Heute fällig") }
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            if let last = latestCareEntry(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries) {
                let days = cal.dateComponents([.day], from: last.date, to: now).day ?? 0
                return days == 0 ? "今天已换" : "\(days)天前"
            }
            return nil
        case "walk":
            let walks = todayWalkEntries(for: pet, walkLedgerEntries: walkLedgerEntries, now: now, calendar: cal)
            guard !walks.isEmpty else { return "今日未遛" }
            let dist = walks.reduce(0.0) { $0 + $1.distanceMeters }
            let distText = dist >= 1000 ? String(format: "%.1fkm", dist / 1000) : String(format: "%.0fm", dist)
            return "今日 \(walks.count)次 · \(distText)"
        case "potty":
            let count = todayPottyEntries(for: pet, pottyLedgerEntries: pottyLedgerEntries, now: now, calendar: cal).count
            if count > 0 { return "今日 \(count)次" }
            if let last = latestPottyEntry(for: pet, pottyLedgerEntries: pottyLedgerEntries),
               last.pottyType == .softPoop || last.pottyType == .liquidPoop {
                return "最近异常"
            }
            return nil
        case "litter":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            let count = todayCareEntryCount(.litter, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal)
            if count > 0 { return "今日已铲" }
            return scoopQuickStatusText(for: pet, careLedgerEntries: careLedgerEntries, calendar: cal, now: now, l: l)
        case "play":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            let count = todayCareEntryCount(.play, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal)
            if count > 0 { return "今日陪玩 \(count)次" }
            if let event = playPlanEvent(for: pet, allEvents: allEvents) {
                let eventDay = cal.startOfDay(for: event.startDate)
                let today = cal.startOfDay(for: now)
                if eventDay <= today { return "计划待陪" }
                return "计划 \(relativeFutureDayText(for: event.startDate, calendar: cal))"
            }
            return "今日未陪"
        case "weight":
            if let last = latestWeightEntry(for: pet, weightLedgerEntries: petWeightLedgerEntries) {
                return String(format: "%.1fkg", last.weightKg)
            }
            return nil
        case "medication":
            let activeMeds = pet.medications.filter(\.isActiveToday)
            guard !activeMeds.isEmpty else { return "待设置" }
            let planned = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: now, for: $1) }
            let done = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: $1.id) }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            return planned > 0 ? "今日 \(min(done, planned))/\(planned)" : "\(activeMeds.count)种药"
        case "expense":
            let total = petExpenseLedgerEntries
                .filter { entry in
                    entry.petId == pet.id &&
                        cal.isDate(entry.date, equalTo: now, toGranularity: .month)
                }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "本月 \(AppCurrency.format(total, fractionDigits: 0))" : nil
        case "moment":
            let todayCount = todayMomentEntries(
                for: pet,
                momentEntries: petMomentEntries,
                now: now,
                calendar: cal
            ).count
            if todayCount > 0 {
                return l.tr(zh: "今天 \(todayCount) 条", en: "Today \(todayCount)", de: "Heute \(todayCount)")
            }
            if let last = latestMomentEntry(for: pet, momentEntries: petMomentEntries) {
                return l.tr(
                    zh: "最近：\(momentAgeText(for: last.date, now: now, calendar: cal, l: l))",
                    en: "Last: \(momentAgeText(for: last.date, now: now, calendar: cal, l: l))",
                    de: "Zuletzt: \(momentAgeText(for: last.date, now: now, calendar: cal, l: l))"
                )
            }
            return l.tr(zh: "还没有记录", en: "No moments yet", de: "Noch keine Momente")
        case "filterClean":
            if let replaceStatus = WaterCareCycleStatusCalculator.filterReplaceStatus(for: pet, now: now, calendar: cal, logSnapshot: waterCycleSnapshot),
               replaceStatus.isOverdue {
                return waterCycleOverdueText(title: "更换", days: replaceStatus.overdueDays, l: l)
            }
            if let status = WaterCareCycleStatusCalculator.filterCleanStatus(for: pet, now: now, calendar: cal, logSnapshot: waterCycleSnapshot) {
                if status.isOverdue { return waterCycleOverdueText(title: "清洗", days: status.overdueDays, l: l) }
                if status.isDueToday { return l.tr(zh: "今天应清", en: "Due today", de: "Heute fällig") }
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            if let last = latestCareEntry(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries) {
                let days = cal.dateComponents([.day], from: last.date, to: now).day ?? 0
                return days == 0 ? "今天已清" : "\(days)天前"
            }
            return nil
        case "cageCleaning":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            return latestCareAgeText(
                .cageCleaning,
                pet: pet,
                careLedgerEntries: careLedgerEntries,
                calendar: cal,
                now: now,
                todayDone: "今天已清"
            )
        case "freeFlight":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            let count = todayCareEntryCount(.freeFlight, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal)
            return count > 0 ? "今日 \(count)次" : nil
        case "misting":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            let count = todayCareEntryCount(.misting, pet: pet, careLedgerEntries: careLedgerEntries, now: now, calendar: cal)
            return count > 0 ? "今日 \(count)次" : nil
        case "substrateChange":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l) {
                return overdue
            }
            return latestCareAgeText(
                .substrateChange,
                pet: pet,
                careLedgerEntries: careLedgerEntries,
                calendar: cal,
                now: now,
                todayDone: "今天已换"
            )
        case "groom", "health":
            return overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, careLedgerEntries: careLedgerEntries, now: now, calendar: cal, l: l)
        default:
            return nil
        }
    }

    static func singleUseLabel(for actionType: String) -> String? {
        switch actionType {
        case "litter": "铲屎"
        case "waterChange": "换水"
        case "filterClean": "清理滤材"
        case "cageCleaning": "清理鸟笼"
        case "substrateChange": "换垫材"
        default: nil
        }
    }

    nonisolated static func petMenuPolicy(
        for item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        now: Date
    ) -> ExpandedQuickMenuPolicy {
        switch item.actionType {
        case "feed":
            return feedQuickCheckInAvailable(
                for: pet,
                allEvents: allEvents,
                feedingLedgerEntries: feedingLedgerEntries,
                now: now
            ) ? .quickWithDetail : .none
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                return .detailOnly
            }
            return waterQuickCheckInAvailable(for: pet, allEvents: allEvents, now: now) ? .quickWithDetail : .none
        case "walk", "play", "litter", "cageCleaning", "freeFlight", "misting", "substrateChange":
            return .quickWithDetail
        case "medication":
            return medicationQuickCheckInAvailable(for: pet, allEvents: allEvents, now: now) ? .quickWithDetail : .none
        case "groom", "potty", "health":
            return .detailOnly
        case "weight", "expense", "moment":
            return .quickWithDetail
        case "waterChange", "filterClean":
            return .detailOnly
        default:
            return .none
        }
    }

    nonisolated static func humanMenuPolicy(actionType: String) -> ExpandedQuickMenuPolicy {
        switch actionType {
        case "humanWeight", "humanWorkout", "humanMedication", "humanNote", "humanExpense":
            .quickWithDetail
        case "humanAllFeatures":
            .detailOnly
        default:
            .none
        }
    }

    nonisolated static func feedQuickCheckInAvailable(
        for pet: Pet,
        allEvents: [Event],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        now: Date,
        calendar cal: Calendar = .current
    ) -> Bool {
        let state = HomeFeedQuickActionState(
            pet: pet,
            allEvents: allEvents,
            feedingLedgerEntries: feedingLedgerEntries,
            now: now,
            calendar: cal
        )
        switch state.operatingMode {
        case .manual:
            return pet.dailyPortionGrams > 0
        case .manualReminder:
            return state.nextManualReminder != nil
        case .autoFeeder:
            return false
        }
    }

    nonisolated static func waterQuickCheckInAvailable(for pet: Pet, allEvents: [Event], now: Date) -> Bool {
        guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else { return false }
        let state = waterRuleState(for: pet, allEvents: allEvents, now: now)
        switch state.operatingMode {
        case .manual:
            return true
        case .reminder:
            return state.nextPendingReminder != nil
        }
    }

    nonisolated static func medicationQuickCheckInAvailable(for pet: Pet, allEvents: [Event], now: Date) -> Bool {
        pet.medications
            .filter(\.isActiveToday)
            .contains { medication in
                let required = PetMedicationDoseLogging.requiredDoses(on: now, for: medication)
                if required == 0 { return true }
                let done = PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: medication.id)
                return done < required
            }
    }

    static func petTapRoute(for item: QuickActionItem, pet: Pet) -> ExpandedPetQuickTapRoute {
        switch item.actionType {
        case "feed", "walk", "play", "litter", "cageCleaning", "freeFlight", "misting", "substrateChange", "medication":
            .perform(item.actionType)
        case "water":
            WaterQuickActionPolicy.isAquatic(species: pet.species) ? .waterManagement : .perform("water")
        case "waterChange", "filterClean":
            .waterManagement
        case "weight":
            .weight
        case "expense":
            .expense
        case "moment":
            .moment
        case "health":
            .health
        default:
            .none
        }
    }

    static func petLongPressRoute(for item: QuickActionItem) -> ExpandedPetQuickLongPressRoute {
        switch item.actionType {
        case "feed": .feedDetail
        case "water", "waterChange", "filterClean": .waterManagement
        case "walk": .walk
        case "play": .playDetail
        case "potty", "litter": .pottyDetail
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange": .hygiene
        case "health": .health
        case "medication": .medication
        case "weight": .weightDetail
        case "expense": .expenseDetail
        case "moment": .momentHistory
        default: .none
        }
    }

    static func humanTapRoute(actionType: String, isLocked: Bool) -> ExpandedHumanQuickRoute {
        guard !isLocked else { return .privacyAlert }
        switch actionType {
        case "humanWeight": return .weightQuick
        case "humanWorkout": return .workoutQuick
        case "humanMedication": return .medicationAdd
        case "humanNote": return .noteQuick
        case "humanExpense": return .expenseQuick
        case "humanAllFeatures": return .allFeatures
        default: return .selectHuman
        }
    }

    static func humanLongPressRoute(actionType: String, isLocked: Bool) -> ExpandedHumanQuickRoute {
        guard !isLocked else { return .privacyAlert }
        switch actionType {
        case "humanWeight": return .weightDetail
        case "humanWorkout": return .workoutDetail
        case "humanMedication": return .medicationDetail
        case "humanNote": return .noteDetail
        case "humanExpense": return .expenseDetail
        case "humanAllFeatures": return .allFeatures
        default: return .selectHuman
        }
    }

    nonisolated static func humanCompleted(
        item: QuickActionItem,
        human: Human,
        isLocked: Bool,
        todayMedicationLogs: [HumanMedicationLog],
        expenses: [HomeExpensePreviewEntry] = [],
        calendar cal: Calendar = .current
    ) -> Bool {
        guard !isLocked else { return false }
        switch item.actionType {
        case "humanWeight":
            return human.weightLogs.contains { cal.isDateInToday($0.date) }
        case "humanWorkout":
            return human.workoutLogs.contains { cal.isDateInToday($0.date) }
        case "humanMedication":
            let humanId = human.id.uuidString
            return todayMedicationLogs.contains {
                $0.humanId == humanId &&
                    cal.isDateInToday($0.scheduledTime) &&
                    $0.status == .taken
            }
        case "humanExpense":
            return latestHumanExpenseDate(for: human, in: expenses).map { cal.isDateInToday($0) } ?? false
        default:
            return false
        }
    }

    nonisolated static func humanCountText(
        item: QuickActionItem,
        human: Human,
        isLocked: Bool,
        activeMedications: [HumanMedication],
        todayMedicationLogs: [HumanMedicationLog],
        expenses: [HomeExpensePreviewEntry] = [],
        calendar cal: Calendar = .current
    ) -> String? {
        guard !isLocked else { return nil }
        switch item.actionType {
        case "humanWeight":
            if let last = human.weightLogs.max(by: { $0.date < $1.date }) {
                return "\(relativeDayText(for: last.date, calendar: cal)) \(String(format: "%.1fkg", last.weight))"
            }
            return "还没有记录"
        case "humanWorkout":
            if let last = human.workoutLogs.max(by: { $0.date < $1.date }) {
                return "\(WorkoutType(rawValue: last.typeRaw)?.rawValue ?? "运动") · \(relativeDayText(for: last.date, calendar: cal))"
            }
            return "还没有记录"
        case "humanMedication":
            let humanId = human.id.uuidString
            let meds = activeMedications.filter {
                $0.humanId == humanId && $0.isActive && $0.isActiveToday
            }
            guard !meds.isEmpty else { return "还没有药物" }
            if let nextDose = meds
                .flatMap({ HumanMedicationSchedulePlan.futureDoses(for: $0, days: 7) })
                .sorted(by: { $0.scheduledTime < $1.scheduledTime })
                .first {
                return "下次 \(nextDose.scheduledTime.formatted(date: .omitted, time: .shortened))"
            }
            let takenToday = todayMedicationLogs.count(where: {
                $0.humanId == humanId &&
                    cal.isDateInToday($0.scheduledTime) &&
                    $0.status == .taken
            })
            let plannedToday = HumanMedicationSchedulePlan.plannedDoseCount(on: Date(), medications: meds, calendar: cal)
            return plannedToday > 0 ? "今日已服 \(takenToday)/\(plannedToday)" : "按需记录"
        case "humanNote":
            if let last = latestHumanNoteDate(for: human) {
                return "上次 \(relativeDayText(for: last, calendar: cal))"
            }
            return human.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "还没有备注" : "已有备注"
        case "humanExpense":
            let myExpenses = expenses.filter { $0.actorId == human.id.uuidString }
            if let latest = myExpenses.max(by: { $0.date < $1.date }) {
                let totalThisMonth = myExpenses
                    .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                    .reduce(0.0) { $0 + $1.amount }
                if totalThisMonth > 0 {
                    return "本月 \(AppCurrency.format(totalThisMonth, fractionDigits: 0))"
                }
                return "上次 \(relativeDayText(for: latest.date, calendar: cal))"
            }
            return "还没有花费"
        case "humanAllFeatures":
            return "全部入口"
        default:
            return nil
        }
    }

    static func humanPrivacyField(for actionType: String) -> HumanPrivateField? {
        switch actionType {
        case "humanWeight", "weight":
            .weight
        case "humanWorkout", "workout":
            .workout
        case "humanMedication", "medication":
            .medication
        case "humanNote", "note":
            .note
        case "humanWishlist", "wish", "wishlist":
            .wishlist
        case "humanExpense", "expense":
            .expense
        default:
            nil
        }
    }

    static func humanPrivacyIconName(for item: QuickActionItem, human: Human) -> String? {
        guard let field = humanPrivacyField(for: item.actionType) else { return nil }
        return human.privateFields.contains(field.rawValue) ? "lock.fill" : "lock.open.fill"
    }

    static func humanPrivacyIconTint(for item: QuickActionItem, human: Human) -> Color {
        guard let field = humanPrivacyField(for: item.actionType),
              human.privateFields.contains(field.rawValue) else {
            return Color.ohanaSecondaryText
        }
        return Color.goYellow
    }

    static func quickActionTitle(_ raw: String) -> String {
        switch raw.uppercased() {
        case "FEED": "喂食"
        case "WALK": "出行"
        case "WATER": "喂水"
        case "POTTY": "便便"
        case "LITTER": "铲屎"
        case "PLAY": "逗玩"
        case "FILTER": "滤材"
        case "CAGE": "清笼"
        case "FLIGHT": "放飞"
        case "MIST": "喷水"
        case "SUBSTRATE": "换垫"
        case "TEMP": "温湿"
        case "WEIGHT": "体重"
        case "WORKOUT": "运动"
        case "NOTE": "记录"
        default: raw.capitalized
        }
    }

    private nonisolated static func scoopQuickStatusText(
        for pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry],
        calendar: Calendar,
        now: Date,
        l: L10n = .current
    ) -> String? {
        let key = pet.id.uuidString
        let settings = LitterCareSettingsStore.snapshot(petKey: key, calendar: calendar)
        let interval = settings.scoopIntervalDays
        let anchor = settings.scoopAnchorDate
        let lastScoop = latestCareEntry(.litter, pet: pet, careLedgerEntries: careLedgerEntries)?.date
        let base = calendar.startOfDay(for: lastScoop ?? anchor)
        let next = calendar.date(byAdding: .day, value: interval, to: base) ?? base
        let today = calendar.startOfDay(for: now)
        let daysUntil = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day ?? 0

        if daysUntil < 0 {
            return l.tr(zh: "逾期 \(abs(daysUntil))天", en: "\(abs(daysUntil))d overdue", de: "\(abs(daysUntil)) T. überfällig")
        }
        if daysUntil == 0 {
            return l.tr(zh: "今天应铲", en: "Due today", de: "Heute fällig")
        }
        return l.tr(zh: "每\(interval)天", en: "Every \(interval)d", de: "Alle \(interval) T.")
    }

    private nonisolated static func overdueQuickStatusText(
        for actionType: String,
        pet: Pet,
        allEvents: [Event],
        careLedgerEntries: [HomeCareQuickActionEntry],
        now: Date,
        calendar cal: Calendar,
        l: L10n = .current
    ) -> String? {
        guard let warning = CarePlanOverdueStatusCalculator.warning(
            for: actionType,
            pet: pet,
            events: allEvents,
            now: now,
            calendar: cal,
            waterCycleLogSnapshot: waterCycleLogSnapshot(for: pet, careLedgerEntries: careLedgerEntries)
        ) else {
            return nil
        }
        return warning.compactText(l: l)
    }

    private nonisolated static func waterCycleOverdueText(title: String, days: Int, l: L10n) -> String {
        let localizedTitle = waterCycleTitle(title, l: l)
        return l.tr(
            zh: "\(localizedTitle)逾期\(days)天",
            en: "\(localizedTitle) \(days)d overdue",
            de: "\(localizedTitle) \(days) T. überfällig"
        )
    }

    private nonisolated static func waterCycleTitle(_ title: String, l: L10n) -> String {
        switch title {
        case "换水":
            l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case "滤芯":
            l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case "更换":
            l.tr(zh: "更换", en: "Replacement", de: "Wechsel")
        case "清洗":
            l.tr(zh: "清洗", en: "Cleaning", de: "Reinigung")
        default:
            title
        }
    }

    private nonisolated static func quickPlanTimeText(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private nonisolated static func latestCareAgeText(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry],
        calendar cal: Calendar,
        now: Date,
        todayDone: String
    ) -> String? {
        guard let last = latestCareEntry(type, pet: pet, careLedgerEntries: careLedgerEntries) else {
            return nil
        }
        let days = cal.dateComponents([.day], from: last.date, to: now).day ?? 0
        return days == 0 ? todayDone : "\(days)天前"
    }

    private nonisolated static func aquaticWaterStatusText(
        for pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry],
        calendar cal: Calendar,
        now: Date
    ) -> String? {
        if let last = careEntries(
            for: pet,
            actionTypes: [CareType.waterChange.rawValue, CareType.filterClean.rawValue],
            careLedgerEntries: careLedgerEntries
        ).max(by: { $0.date < $1.date }) {
            let days = cal.dateComponents([.day], from: last.date, to: now).day ?? 0
            if last.actionType == CareType.filterClean.rawValue {
                return days == 0 ? "今天清滤芯" : "\(days)天前滤芯"
            }
            return days == 0 ? "今天已换水" : "\(days)天前换水"
        }
        return "长按管理"
    }

    private nonisolated static func waterCycleLogSnapshot(
        for pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> WaterCareCycleLogSnapshot {
        WaterCareCycleLogSnapshot(
            latestWaterChangeDate: latestCareEntry(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries)?.date,
            latestFilterCleanDate: latestCareEntry(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries)?.date
        )
    }

    private nonisolated static func todayCareEntryCount(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> Int {
        careEntries(for: pet, actionTypes: [type.rawValue], careLedgerEntries: careLedgerEntries)
            .count { cal.isDate($0.date, inSameDayAs: now) }
    }

    private nonisolated static func latestCareEntry(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> HomeCareQuickActionEntry? {
        careEntries(for: pet, actionTypes: [type.rawValue], careLedgerEntries: careLedgerEntries)
            .max(by: { $0.date < $1.date })
    }

    private nonisolated static func careEntries(
        for pet: Pet,
        actionTypes: Set<String>,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> [HomeCareQuickActionEntry] {
        careLedgerEntries.filter { entry in
            entry.petId == pet.id && actionTypes.contains(entry.actionType)
        }
    }

    private nonisolated static func todayHygieneEntries(
        for pet: Pet,
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> [HomeHygieneQuickActionEntry] {
        hygieneLedgerEntries.filter { entry in
            entry.petId == pet.id && cal.isDate(entry.date, inSameDayAs: now)
        }
    }

    private nonisolated static func todayWalkEntries(
        for pet: Pet,
        walkLedgerEntries: [HomeWalkQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> [HomeWalkQuickActionEntry] {
        walkLedgerEntries.filter { entry in
            entry.petId == pet.id && cal.isDate(entry.startDate, inSameDayAs: now)
        }
    }

    private nonisolated static func todayPottyEntries(
        for pet: Pet,
        pottyLedgerEntries: [HomePottyQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> [HomePottyQuickActionEntry] {
        pottyLedgerEntries.filter { entry in
            entry.petId == pet.id && cal.isDate(entry.date, inSameDayAs: now)
        }
    }

    private nonisolated static func latestPottyEntry(
        for pet: Pet,
        pottyLedgerEntries: [HomePottyQuickActionEntry]
    ) -> HomePottyQuickActionEntry? {
        pottyLedgerEntries
            .filter { $0.petId == pet.id }
            .max(by: { $0.date < $1.date })
    }

    private nonisolated static func todayWeightEntries(
        for pet: Pet,
        weightLedgerEntries: [HomePetWeightQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> [HomePetWeightQuickActionEntry] {
        weightLedgerEntries.filter { entry in
            entry.petId == pet.id && cal.isDate(entry.date, inSameDayAs: now)
        }
    }

    private nonisolated static func latestWeightEntry(
        for pet: Pet,
        weightLedgerEntries: [HomePetWeightQuickActionEntry]
    ) -> HomePetWeightQuickActionEntry? {
        weightLedgerEntries
            .filter { $0.petId == pet.id }
            .max(by: { $0.date < $1.date })
    }

    private nonisolated static func todayMomentEntries(
        for pet: Pet,
        momentEntries: [HomePetMomentQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> [HomePetMomentQuickActionEntry] {
        momentEntries.filter { entry in
            entry.petId == pet.id && cal.isDate(entry.date, inSameDayAs: now)
        }
    }

    private nonisolated static func latestMomentEntry(
        for pet: Pet,
        momentEntries: [HomePetMomentQuickActionEntry]
    ) -> HomePetMomentQuickActionEntry? {
        momentEntries
            .filter { $0.petId == pet.id }
            .max(by: { $0.date < $1.date })
    }

    private nonisolated static func momentAgeText(for date: Date, now: Date, calendar: Calendar, l: L10n) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 0 { return l.tr(zh: "今天", en: "today", de: "heute") }
        if days == 1 { return l.tr(zh: "昨天", en: "yesterday", de: "gestern") }
        return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    private nonisolated static func latestHumanNoteDate(for human: Human) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return human.notes
            .components(separatedBy: "\n\n")
            .compactMap { part -> Date? in
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("["),
                      let bracketEnd = trimmed.firstIndex(of: "]") else {
                    return nil
                }
                let dateText = String(trimmed[trimmed.index(after: trimmed.startIndex) ..< bracketEnd])
                return formatter.date(from: dateText)
            }
            .max()
    }

    private nonisolated static func latestHumanExpenseDate(for human: Human, in expenses: [HomeExpensePreviewEntry]) -> Date? {
        expenses
            .filter { $0.actorId == human.id.uuidString }
            .map(\.date)
            .max()
    }

    private nonisolated static func relativeDayText(for date: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "昨天" }
        return "\(days)天前"
    }

    private nonisolated static func relativeFutureDayText(for date: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "明天" }
        if days == 2 { return "后天" }
        return "\(days)天后"
    }
}
