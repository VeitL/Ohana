//
//  AchievementWallContentView+CompletionDates.swift
//  Ohana
//

import SwiftUI

extension AchievementWallContentView {
    func achievementCompletionDate(for badge: Achievement) -> Date? {
        if let unlockedAt = badge.unlockedAt { return unlockedAt }
        if let human = activeHuman { return humanAchievementCompletionDate(for: badge, human: human) }

        switch badge.id {
        case "iron_gut", "walk_streak", "health_hero":
            return badge.isUnlocked ? Date() : nil
        case "iron_paw":
            return cumulativeWalkDate(targetMeters: 100_000)
        case "nutritionist":
            return latestDate(from: feedingRecordDates())
        case "happy_birthday", "day_one_checkin":
            return badge.isUnlocked ? Date() : nil
        case "hundred_days":
            return Calendar.current.date(byAdding: .day, value: 100, to: activePet.createdAt)
        case "first_record":
            return earliestDate(from: petRecordDates())
        case "old_friend":
            return Calendar.current.date(byAdding: .day, value: 7, to: activePet.createdAt)
        case "long_runner":
            return activePet.walkLogs
                .filter { $0.distanceMeters >= 5000 }
                .map(\.startDate)
                .min()
        case "medication_complete":
            return activePet.medications.compactMap(\.endDate).filter { $0 <= Date() }.min()
        case "photo_enthusiast":
            return thresholdDate(from: activePet.photoLogs.map(\.date), target: 20)
        case "expense_tracker":
            return thresholdDate(from: activePet.expenseLogs.map(\.date), target: 10)
        case "weight_manager":
            return thresholdDate(from: activePet.weightLogs.map(\.date), target: 7)
        case "hydration_buddy":
            return thresholdDate(from: activePet.careLogs.filter { $0.careType == .watering }.map(\.date), target: 14)
        case "play_champion":
            return thresholdDate(from: activePet.careLogs.filter { $0.careType == .play }.map(\.date), target: 20)
        case "clean_keeper":
            return thresholdDate(from: cleaningRecordDates(), target: 20)
        case "treat_scout":
            return thresholdDate(from: activePet.careLogs.filter { FeedLogMetadata.isTreatLog($0) }.map(\.date), target: 10)
        case "food_kind_explorer":
            return latestDate(from: mainFeedLogs().map(\.date))
        case "auto_feeder_pilot":
            return thresholdDate(from: mainFeedLogs().filter(\.isAutoFeedLogEntry).map(\.date), target: 3)
        case "stock_keeper":
            return thresholdDate(from: activePet.foodRecords.map(\.startDate), target: 2)
        case "protection_ready":
            return earliestDate(from: activePet.insurances.map(\.createdAt) + activePet.documents.compactMap(\.issueDate))
        case "vaccine_keeper":
            return activePet.healthLogs
                .filter {
                    $0.type == "vaccine"
                        || $0.type == "vaccination"
                        || $0.note.localizedCaseInsensitiveContains("疫苗")
                        || $0.note.localizedCaseInsensitiveContains("vaccine")
                        || $0.note.localizedCaseInsensitiveContains("impf")
                }
                .map(\.date)
                .min()
        case "symptom_watcher":
            return thresholdDate(from: activePet.symptomLogs.map(\.date), target: 3)
        case "care_streak_keeper":
            return badge.isUnlocked ? Date() : nil
        case "meal_archivist":
            return thresholdDate(from: mainFeedLogs().map(\.date), target: 50)
        case "water_guardian":
            return thresholdDate(from: waterCareRecordDates(), target: 50)
        case "memory_collector":
            return thresholdDate(from: activePet.photoLogs.map(\.date), target: 50)
        case "weight_rhythm":
            return thresholdDate(from: activePet.weightLogs.map(\.date), target: 14)
        case "year_companion":
            return Calendar.current.date(byAdding: .day, value: 365, to: activePet.createdAt)
        case "global_island_crew":
            return thresholdDate(from: pets.map(\.createdAt), target: 2)
        case "global_first_critter":
            return electronicPets.map(\.obtainedAt).min()
        case "global_legendary_critter":
            return electronicPets.filter { $0.rarity == .legendary }.map(\.obtainedAt).min()
        case "global_critter_collector":
            return uniqueThresholdDate(
                items: electronicPets,
                key: { $0.catalogId },
                date: { $0.obtainedAt },
                target: 3
            )
        case "global_critter_star":
            return electronicPets.filter { $0.starLevel >= 2 }.map(\.obtainedAt).min()
        case "global_critter_caretaker":
            return thresholdDate(from: critterActionLogs.filter { $0.action != .careEcho }.map(\.createdAt), target: 10)
        case "global_first_blind_box":
            return gachaDrawLogs.map(\.drawDate).min()
        case "global_blind_box_collector":
            return uniqueThresholdDate(
                items: gachaOwnedItems,
                key: { "\($0.seriesId)#\($0.itemId)" },
                date: { $0.latestObtainedAt },
                target: 8
            )
        case "global_secret_blind_box":
            return gachaOwnedItems.filter(\.isHidden).map(\.latestObtainedAt).min()
        case "global_gacha_series_complete":
            return gachaOwnedItems.map(\.latestObtainedAt).max()
        case "global_gacha_jackpot":
            return gachaDrawLogs.filter { $0.instantCoconutDelta >= 500 }.map(\.drawDate).min()
        default:
            return nil
        }
    }

    func humanAchievementCompletionDate(for badge: Achievement, human: Human) -> Date? {
        switch badge.id {
        case "human_profile_ready":
            human.createdAt
        case "human_first_record":
            earliestDate(from: humanRecordDates(human))
        case "human_weight_starter":
            human.weightLogs.map(\.date).min()
        case "human_weight_keeper":
            thresholdDate(from: human.weightLogs.map(\.date), target: 7)
        case "human_expense_tracker":
            thresholdDate(from: expenses(for: human).map(\.date), target: 5)
        case "human_medication_setup":
            medications(for: human).map(\.createdAt).min()
        case "human_medication_keeper":
            thresholdDate(
                from: medicationLogs(for: human)
                    .filter { $0.status == .taken }
                    .map { $0.recordedTime ?? $0.createdAt },
                target: 7
            )
        case "human_workout_starter":
            human.workoutLogs.map(\.date).min()
        case "human_workout_rhythm":
            thresholdDate(from: human.workoutLogs.map(\.date), target: 10)
        case "human_workout_hero":
            thresholdDate(from: human.workoutLogs.map(\.date), target: 30)
        case "human_coconut_elite":
            nil
        case "human_old_friend":
            Calendar.current.date(byAdding: .day, value: 7, to: human.createdAt)
        case "human_year_friend":
            Calendar.current.date(byAdding: .day, value: 365, to: human.createdAt)
        default:
            nil
        }
    }

    func thresholdDate(from dates: [Date], target: Int) -> Date? {
        let sorted = dates.sorted()
        guard sorted.count >= target, target > 0 else { return nil }
        return sorted[target - 1]
    }

    func earliestDate(from dates: [Date]) -> Date? {
        dates.min()
    }

    func latestDate(from dates: [Date]) -> Date? {
        dates.max()
    }

    func uniqueThresholdDate<Item, Key: Hashable>(
        items: [Item],
        key: (Item) -> Key,
        date: (Item) -> Date,
        target: Int
    ) -> Date? {
        var seen = Set<Key>()
        for item in items.sorted(by: { date($0) < date($1) }) {
            seen.insert(key(item))
            if seen.count >= target { return date(item) }
        }
        return nil
    }

    func cumulativeWalkDate(targetMeters: Double) -> Date? {
        var total = 0.0
        for log in activePet.walkLogs.sorted(by: { $0.startDate < $1.startDate }) {
            total += log.distanceMeters
            if total >= targetMeters { return log.startDate }
        }
        return nil
    }

    func petRecordDates() -> [Date] {
        activePet.healthLogs.map(\.date)
            + activePet.pottyLogs.map(\.date)
            + activePet.walkLogs.map(\.startDate)
            + activePet.hygieneLogs.map(\.date)
            + activePet.careLogs.map(\.date)
            + activePet.foodRecords.map(\.startDate)
            + activePet.expenseLogs.map(\.date)
            + activePet.weightLogs.map(\.date)
            + activePet.photoLogs.map(\.date)
            + activePet.milestones.map(\.date)
    }

    func feedingRecordDates() -> [Date] {
        activePet.foodRecords.map(\.startDate)
            + activePet.careLogs.filter { $0.careType == .feeding }.map(\.date)
    }

    func cleaningRecordDates() -> [Date] {
        activePet.hygieneLogs.map(\.date)
            + activePet.careLogs.filter {
                [.litter, .waterChange, .filterClean, .cageCleaning, .substrateChange].contains($0.careType)
            }.map(\.date)
    }

    func waterCareRecordDates() -> [Date] {
        activePet.careLogs.filter { [.watering, .waterChange].contains($0.careType) }.map(\.date)
    }

    func humanRecordDates(_ human: Human) -> [Date] {
        human.weightLogs.map(\.date)
            + human.workoutLogs.map(\.date)
            + medications(for: human).map(\.createdAt)
            + medicationLogs(for: human).map { $0.recordedTime ?? $0.createdAt }
            + expenses(for: human).map(\.date)
    }
}
