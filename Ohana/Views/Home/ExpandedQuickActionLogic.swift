//
//  ExpandedQuickActionLogic.swift
//  Ohana
//
//  State and routing decisions for expanded-card quick actions.
//

import Foundation
import SwiftUI

enum ExpandedPetQuickTapRoute {
    case perform(String)
    case waterManagement
    case weight
    case expense
    case moment
    case health
    case none
}

enum ExpandedPetQuickLongPressRoute {
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

enum ExpandedHumanQuickRoute {
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

enum ExpandedLegacyQuickActionRoute {
    case selectHuman
    case recordFeed
    case recordWater
    case startWalk
    case recordPotty
    case recordLitter
    case specialCare(CareType)
    case waterManagement
    case selectPetOverview
    case none
}

enum ExpandedQuickActionLogic {
    static func feedDashboard(
        for pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date
    ) -> FeedingDashboardState {
        let storedGoal = UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)")
        let goal = storedGoal > 0 ? storedGoal : 3
        let feedLogs = allFeedCareLogs.filter { $0.pet?.id == pet.id }
        return FeedingDashboardState(pet: pet, allEvents: allEvents, manualGoalCount: goal, careLogs: feedLogs, now: now)
    }

    static func waterRuleState(for pet: Pet, allEvents: [Event]) -> WaterRuleState {
        WaterRuleState(pet: pet, allEvents: allEvents)
    }

    static func playPlanEvent(for pet: Pet, allEvents: [Event]) -> Event? {
        let key = pet.id.uuidString
        let title = "\(pet.name) 陪玩计划"
        return allEvents
            .filter { $0.relatedEntityId == key && $0.title == title }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    static func defaultWaterAmountMl(for pet: Pet) -> Double? {
        let key = pet.id.uuidString
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "waterAmountEnabled_\(key)") == nil
            ? true
            : defaults.bool(forKey: "waterAmountEnabled_\(key)")
        guard enabled else { return nil }
        let storedAmount = defaults.double(forKey: "waterAmountMl_\(key)")
        return storedAmount > 0 ? storedAmount : 250
    }

    static func pendingFeedReminder(
        for pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date
    ) -> Reminder? {
        feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: now).nextManualReminder
    }

    static func feedAppearsComplete(
        for pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date
    ) -> Bool {
        let dashboard = feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: now)
        switch dashboard.operatingMode {
        case .manual:
            return dashboard.today.manualTodayLogs.count > 0
        case .manualReminder:
            return dashboard.today.isComplete
        case .autoFeeder:
            return dashboard.todayAutoFeedCount >= max(dashboard.autoFeederEvents.count, 1)
        }
    }

    static func showsAttentionDot(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date
    ) -> Bool {
        switch item.actionType {
        case "waterChange":
            if WaterCareCycleStatusCalculator.waterChangeStatus(for: pet, now: now)?.isOverdue == true {
                return true
            }
        case "filterClean":
            if WaterCareCycleStatusCalculator.filterCleanStatus(for: pet, now: now)?.isOverdue == true ||
                WaterCareCycleStatusCalculator.filterReplaceStatus(for: pet, now: now)?.isOverdue == true {
                return true
            }
        case "water" where WaterQuickActionPolicy.isAquatic(species: pet.species):
            if WaterCareCycleStatusCalculator.mostUrgentWaterWarning(for: pet, now: now) != nil {
                return true
            }
        case "feed":
            let dashboard = feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: now)
            return dashboard.operatingMode == .manualReminder && dashboard.hasMissedManualPlan
        default:
            break
        }

        if CarePlanOverdueStatusCalculator.warning(for: item.actionType, pet: pet, events: allEvents, now: now) != nil {
            return true
        }

        if item.actionType == "play", let event = playPlanEvent(for: pet, allEvents: allEvents) {
            let cal = Calendar.current
            let todayDone = pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
            return !todayDone && cal.startOfDay(for: event.startDate) <= cal.startOfDay(for: now)
        }
        return false
    }

    static func isCompleted(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date,
        calendar cal: Calendar = .current
    ) -> Bool {
        switch item.actionType {
        case "feed":
            return feedAppearsComplete(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: now)
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                return pet.careLogs.contains {
                    ($0.type == CareType.waterChange.rawValue || $0.type == CareType.filterClean.rawValue) &&
                    cal.isDateInToday($0.date)
                }
            }
            let waterState = waterRuleState(for: pet, allEvents: allEvents)
            if waterState.operatingMode == .reminder {
                return !waterState.todayPlanReminders.isEmpty && waterState.pendingTodayPlanReminders.isEmpty
            }
            return pet.careLogs.contains { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }
        case "waterChange":
            return pet.careLogs.contains { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }
        case "walk":
            return pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        case "potty":
            return pet.pottyLogs.contains { cal.isDateInToday($0.date) }
        case "litter":
            return pet.careLogs.contains { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }
        case "play":
            return pet.careLogs.contains { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }
        case "groom":
            return pet.hygieneLogs.contains { cal.isDateInToday($0.date) }
        case "medication":
            let activeMeds = pet.medications.filter(\.isActiveToday)
            let planned = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: now, for: $1) }
            guard planned > 0 else { return false }
            let done = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: $1.id) }
            return done >= planned
        case "filterClean":
            return pet.careLogs.contains { $0.type == CareType.filterClean.rawValue && cal.isDateInToday($0.date) }
        case "cageCleaning":
            return pet.careLogs.contains { $0.type == CareType.cageCleaning.rawValue && cal.isDateInToday($0.date) }
        case "freeFlight":
            return pet.careLogs.contains { $0.type == CareType.freeFlight.rawValue && cal.isDateInToday($0.date) }
        case "misting":
            return pet.careLogs.contains { $0.type == CareType.misting.rawValue && cal.isDateInToday($0.date) }
        case "substrateChange":
            return pet.careLogs.contains { $0.type == CareType.substrateChange.rawValue && cal.isDateInToday($0.date) }
        case "weight":
            return pet.weightLogs.contains { cal.isDateInToday($0.date) }
        default:
            return false
        }
    }

    static func countText(
        item: QuickActionItem,
        pet: Pet,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        now: Date,
        calendar cal: Calendar = .current
    ) -> String? {
        switch item.actionType {
        case "feed":
            let dashboard = feedDashboard(for: pet, allEvents: allEvents, allFeedCareLogs: allFeedCareLogs, now: now)
            switch dashboard.operatingMode {
            case .manual:
                let count = pet.careLogs.filter {
                    $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) && $0.isManualFeedLogEntry
                }.count
                if count > 0 { return "手动 \(count)餐" }
                return pet.dailyPortionGrams > 0 ? "\(Int(pet.dailyPortionGrams.rounded()))g" : "待设置"
            case .manualReminder:
                if dashboard.hasMissedManualPlan {
                    return "未打卡 \(dashboard.todayManualPlanMissedCount)餐"
                }
                if let lastExpired = dashboard.lastExpiredManualPlanDate {
                    return "最后逾期 \(quickPlanTimeText(lastExpired, now: now, calendar: cal))"
                }
                if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                    return overdue
                }
                return "计划 \(dashboard.todayManualPlanCompletionText)"
            case .autoFeeder:
                return "自动 \(dashboard.todayAutoFeedCount)次"
            }
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                if let warning = WaterCareCycleStatusCalculator.mostUrgentWaterWarning(for: pet, now: now, calendar: cal) {
                    return "\(warning.title)逾期\(warning.status.overdueDays)天"
                }
                return aquaticWaterStatusText(for: pet, calendar: cal)
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            let waterState = waterRuleState(for: pet, allEvents: allEvents)
            if waterState.operatingMode == .reminder {
                if waterState.missedCount > 0 {
                    return "待补 \(waterState.missedCount)次"
                }
                return "计划 \(waterState.completionText)"
            }
            let count = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            if count > 0 { return "今日 \(count)次" }
            if let amount = defaultWaterAmountMl(for: pet) {
                return "\(Int(amount.rounded()))ml"
            }
            return "只记录次数"
        case "waterChange":
            if let status = WaterCareCycleStatusCalculator.waterChangeStatus(for: pet, now: now, calendar: cal) {
                if status.isOverdue { return "逾期\(status.overdueDays)天" }
                if status.isDueToday { return "今天应换" }
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            if let last = pet.careLogs.filter({ $0.type == CareType.waterChange.rawValue }).max(by: { $0.date < $1.date }) {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已换" : "\(days)天前"
            }
            return nil
        case "walk":
            let walks = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }
            guard !walks.isEmpty else { return "今日未遛" }
            let dist = walks.reduce(0.0) { $0 + $1.distanceMeters }
            let distText = dist >= 1000 ? String(format: "%.1fkm", dist / 1000) : String(format: "%.0fm", dist)
            return "今日 \(walks.count)次 · \(distText)"
        case "potty":
            let count = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            if count > 0 { return "今日 \(count)次" }
            if let last = pet.pottyLogs.max(by: { $0.date < $1.date }),
               last.pottyType == .softPoop || last.pottyType == .liquidPoop {
                return "最近异常"
            }
            return nil
        case "litter":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            let count = pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            if count > 0 { return "今日已铲" }
            return scoopQuickStatusText(for: pet, calendar: cal)
        case "play":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            let count = pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
            if count > 0 { return "今日陪玩 \(count)次" }
            if let event = playPlanEvent(for: pet, allEvents: allEvents) {
                let eventDay = cal.startOfDay(for: event.startDate)
                let today = cal.startOfDay(for: now)
                if eventDay <= today { return "计划待陪" }
                return "计划 \(relativeFutureDayText(for: event.startDate, calendar: cal))"
            }
            return "今日未陪"
        case "weight":
            if let last = pet.weightLogs.max(by: { $0.date < $1.date }) {
                return String(format: "%.1fkg", last.weight)
            }
            return nil
        case "medication":
            let activeMeds = pet.medications.filter(\.isActiveToday)
            guard !activeMeds.isEmpty else { return "待设置" }
            let planned = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: now, for: $1) }
            let done = activeMeds.reduce(0) { $0 + PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: $1.id) }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            return planned > 0 ? "今日 \(min(done, planned))/\(planned)" : "\(activeMeds.count)种药"
        case "expense":
            let total = pet.expenseLogs
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "本月 \(AppCurrency.format(total, fractionDigits: 0))" : nil
        case "moment":
            let todayCount = pet.photoLogs.filter { cal.isDateInToday($0.date) }.count
            if todayCount > 0 { return "今天 \(todayCount) 条" }
            if let last = pet.photoLogs.max(by: { $0.date < $1.date }) {
                return "最近：\(relativeDayText(for: last.date, calendar: cal))"
            }
            return "还没有记录"
        case "filterClean":
            if let replaceStatus = WaterCareCycleStatusCalculator.filterReplaceStatus(for: pet, now: now, calendar: cal),
               replaceStatus.isOverdue {
                return "更换逾期\(replaceStatus.overdueDays)天"
            }
            if let status = WaterCareCycleStatusCalculator.filterCleanStatus(for: pet, now: now, calendar: cal) {
                if status.isOverdue { return "清洗逾期\(status.overdueDays)天" }
                if status.isDueToday { return "今天应清" }
            }
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            if let last = pet.careLogs.filter({ $0.type == CareType.filterClean.rawValue }).max(by: { $0.date < $1.date }) {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return days == 0 ? "今天已清" : "\(days)天前"
            }
            return nil
        case "cageCleaning":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            return latestCareAgeText(.cageCleaning, pet: pet, calendar: cal, todayDone: "今天已清")
        case "freeFlight":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            let count = pet.careLogs.filter { $0.type == CareType.freeFlight.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "misting":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            let count = pet.careLogs.filter { $0.type == CareType.misting.rawValue && cal.isDateInToday($0.date) }.count
            return count > 0 ? "今日 \(count)次" : nil
        case "substrateChange":
            if let overdue = overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal) {
                return overdue
            }
            return latestCareAgeText(.substrateChange, pet: pet, calendar: cal, todayDone: "今天已换")
        case "groom", "health":
            return overdueQuickStatusText(for: item.actionType, pet: pet, allEvents: allEvents, now: now, calendar: cal)
        default:
            return nil
        }
    }

    static func singleUseLabel(for actionType: String) -> String? {
        switch actionType {
        case "litter": return "铲屎"
        case "waterChange": return "换水"
        case "filterClean": return "清理滤材"
        case "cageCleaning": return "清理鸟笼"
        case "substrateChange": return "换垫材"
        default: return nil
        }
    }

    static func petTapRoute(for item: QuickActionItem, pet: Pet) -> ExpandedPetQuickTapRoute {
        switch item.actionType {
        case "feed", "walk", "play", "litter", "cageCleaning", "freeFlight", "misting", "substrateChange", "medication":
            return .perform(item.actionType)
        case "water":
            return WaterQuickActionPolicy.isAquatic(species: pet.species) ? .waterManagement : .perform("water")
        case "waterChange", "filterClean":
            return .waterManagement
        case "weight":
            return .weight
        case "expense":
            return .expense
        case "moment":
            return .moment
        case "health":
            return .health
        default:
            return .none
        }
    }

    static func petLongPressRoute(for item: QuickActionItem) -> ExpandedPetQuickLongPressRoute {
        switch item.actionType {
        case "feed": return .feedDetail
        case "water", "waterChange", "filterClean": return .waterManagement
        case "walk": return .walk
        case "play": return .playDetail
        case "potty", "litter": return .pottyDetail
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange": return .hygiene
        case "health": return .health
        case "medication": return .medication
        case "weight": return .weightDetail
        case "expense": return .expenseDetail
        case "moment": return .momentHistory
        default: return .none
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

    static func humanCompleted(
        item: QuickActionItem,
        human: Human,
        isLocked: Bool,
        todayMedicationLogs: [HumanMedicationLog],
        expenses: [PetExpenseLog] = [],
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

    static func humanCountText(
        item: QuickActionItem,
        human: Human,
        isLocked: Bool,
        activeMedications: [HumanMedication],
        todayMedicationLogs: [HumanMedicationLog],
        expenses: [PetExpenseLog] = [],
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
            let takenToday = todayMedicationLogs.filter {
                $0.humanId == humanId &&
                cal.isDateInToday($0.scheduledTime) &&
                $0.status == .taken
            }.count
            let plannedToday = HumanMedicationSchedulePlan.plannedDoseCount(on: Date(), medications: meds, calendar: cal)
            return plannedToday > 0 ? "今日已服 \(takenToday)/\(plannedToday)" : "按需记录"
        case "humanNote":
            if let last = latestHumanNoteDate(for: human) {
                return "上次 \(relativeDayText(for: last, calendar: cal))"
            }
            return human.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "还没有备注" : "已有备注"
        case "humanExpense":
            let myExpenses = expenses.filter { $0.executorId == human.id.uuidString }
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
        PrivacyService.field(forHumanAction: actionType)
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
        case "FEED": return "喂食"
        case "WALK": return "出行"
        case "WATER": return "喂水"
        case "POTTY": return "便便"
        case "LITTER": return "铲屎"
        case "PLAY": return "逗玩"
        case "FILTER": return "滤材"
        case "CAGE": return "清笼"
        case "FLIGHT": return "放飞"
        case "MIST": return "喷水"
        case "SUBSTRATE": return "换垫"
        case "TEMP": return "温湿"
        case "WEIGHT": return "体重"
        case "WORKOUT": return "运动"
        case "NOTE": return "记录"
        default: return raw.capitalized
        }
    }

    static func legacyRoute(action: FocusCard.Action, card: FocusCard, pet: Pet?) -> ExpandedLegacyQuickActionRoute {
        if card.isHuman { return .selectHuman }
        guard card.isReal, pet != nil else { return .none }

        switch action.label.uppercased() {
        case "FEED": return .recordFeed
        case "WATER":
            if let pet, WaterQuickActionPolicy.isAquatic(species: pet.species) {
                return .waterManagement
            }
            return .recordWater
        case "WALK": return .startWalk
        case "POTTY": return .recordPotty
        case "LITTER": return .recordLitter
        case "PLAY": return .specialCare(.play)
        case "FILTER": return .waterManagement
        case "CAGE": return .specialCare(.cageCleaning)
        case "FLIGHT": return .specialCare(.freeFlight)
        case "MIST": return .specialCare(.misting)
        case "SUBSTRATE": return .specialCare(.substrateChange)
        default: return .selectPetOverview
        }
    }

    private static func scoopQuickStatusText(for pet: Pet, calendar: Calendar) -> String? {
        let key = pet.id.uuidString
        let defaults = UserDefaults.standard
        let storedInterval = defaults.integer(forKey: "scoopIntervalDays_\(key)")
        let interval = max(storedInterval > 0 ? storedInterval : 1, 1)
        let storedAnchor = defaults.double(forKey: "scoopAnchorDate_\(key)")
        let anchor = storedAnchor > 0 ? Date(timeIntervalSince1970: storedAnchor) : Date()
        let lastScoop = pet.careLogs
            .filter { $0.type == CareType.litter.rawValue }
            .max(by: { $0.date < $1.date })?
            .date
        let base = calendar.startOfDay(for: lastScoop ?? anchor)
        let next = calendar.date(byAdding: .day, value: interval, to: base) ?? base
        let today = calendar.startOfDay(for: Date())
        let daysUntil = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day ?? 0

        if daysUntil < 0 {
            return "逾期 \(abs(daysUntil))天"
        }
        if daysUntil == 0 {
            return "今天应铲"
        }
        return "每\(interval)天"
    }

    private static func overdueQuickStatusText(
        for actionType: String,
        pet: Pet,
        allEvents: [Event],
        now: Date,
        calendar cal: Calendar
    ) -> String? {
        guard let warning = CarePlanOverdueStatusCalculator.warning(
            for: actionType,
            pet: pet,
            events: allEvents,
            now: now,
            calendar: cal
        ) else {
            return nil
        }
        return warning.compactText
    }

    private static func quickPlanTimeText(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func latestCareAgeText(_ type: CareType, pet: Pet, calendar cal: Calendar, todayDone: String) -> String? {
        guard let last = pet.careLogs.filter({ $0.type == type.rawValue }).max(by: { $0.date < $1.date }) else {
            return nil
        }
        let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
        return days == 0 ? todayDone : "\(days)天前"
    }

    private static func aquaticWaterStatusText(for pet: Pet, calendar cal: Calendar) -> String? {
        if let last = pet.careLogs
            .filter({ $0.type == CareType.waterChange.rawValue || $0.type == CareType.filterClean.rawValue })
            .max(by: { $0.date < $1.date }) {
            let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            if last.type == CareType.filterClean.rawValue {
                return days == 0 ? "今天清滤芯" : "\(days)天前滤芯"
            }
            return days == 0 ? "今天已换水" : "\(days)天前换水"
        }
        return "长按管理"
    }

    private static func latestHumanNoteDate(for human: Human) -> Date? {
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
                let dateText = String(trimmed[trimmed.index(after: trimmed.startIndex)..<bracketEnd])
                return formatter.date(from: dateText)
            }
            .max()
    }

    private static func latestHumanExpenseDate(for human: Human, in expenses: [PetExpenseLog]) -> Date? {
        expenses
            .filter { $0.executorId == human.id.uuidString }
            .map(\.date)
            .max()
    }

    private static func relativeDayText(for date: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "昨天" }
        return "\(days)天前"
    }

    private static func relativeFutureDayText(for date: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "明天" }
        if days == 2 { return "后天" }
        return "\(days)天后"
    }
}
