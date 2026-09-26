import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct QuestManagerCooldownHistoryTests {
    @Test func legacyScalarTimestampRemainsReadableAndMigratesOnWrite() {
        let manager = QuestManager()
        let subjectID = UUID()
        let key = manager.cooldownKey(petId: subjectID, type: .plantWatering)
        let restore = isolateCooldownValue(forKey: key)
        defer { restore() }

        let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)
        setCooldownValue(legacyDate.timeIntervalSince1970, forKey: key)

        #expect(manager.isOnCooldown(
            petId: subjectID,
            type: .plantWatering,
            at: legacyDate.addingTimeInterval(60 * 60)
        ))

        let laterDate = legacyDate.addingTimeInterval(6 * 60 * 60)
        manager.recordCooldown(
            petId: subjectID,
            type: .plantWatering,
            occurredAt: laterDate
        )

        #expect(storedCooldownHistory(forKey: key) == [
            legacyDate.timeIntervalSince1970,
            laterDate.timeIntervalSince1970
        ])
    }

    @Test func laterTimestampDoesNotChangeHistoricalCooldownDecision() {
        let manager = QuestManager()
        let subjectID = UUID()
        let key = manager.cooldownKey(petId: subjectID, type: .plantWatering)
        let restore = isolateCooldownValue(forKey: key)
        defer { restore() }

        let pendingOperationDate = Date(timeIntervalSince1970: 1_800_100_000)
        let priorRewardDate = pendingOperationDate.addingTimeInterval(-60 * 60)
        let laterRewardDate = pendingOperationDate.addingTimeInterval(5 * 60 * 60)
        manager.recordCooldown(
            petId: subjectID,
            type: .plantWatering,
            occurredAt: priorRewardDate
        )
        manager.recordCooldown(
            petId: subjectID,
            type: .plantWatering,
            occurredAt: laterRewardDate
        )

        #expect(manager.isOnCooldown(
            petId: subjectID,
            type: .plantWatering,
            at: pendingOperationDate
        ))
        #expect(!manager.isOnCooldown(
            petId: subjectID,
            type: .plantWatering,
            at: pendingOperationDate.addingTimeInterval(4 * 60 * 60)
        ))
        #expect(manager.isOnCooldown(
            petId: subjectID,
            type: .plantWatering,
            at: laterRewardDate.addingTimeInterval(60 * 60)
        ))
    }

    @Test func outOfOrderRecordingKeepsAUniqueMonotonicHistory() {
        let manager = QuestManager()
        let subjectID = UUID()
        let key = manager.cooldownKey(petId: subjectID, type: .plantFertilizing)
        let restore = isolateCooldownValue(forKey: key)
        defer { restore() }

        let earlierDate = Date(timeIntervalSince1970: 1_800_200_000)
        let laterDate = earlierDate.addingTimeInterval(5 * 60 * 60)
        manager.recordCooldown(
            petId: subjectID,
            type: .plantFertilizing,
            occurredAt: laterDate
        )
        manager.recordCooldown(
            petId: subjectID,
            type: .plantFertilizing,
            occurredAt: earlierDate
        )
        manager.recordCooldown(
            petId: subjectID,
            type: .plantFertilizing,
            occurredAt: laterDate
        )

        #expect(storedCooldownHistory(forKey: key) == [
            earlierDate.timeIntervalSince1970,
            laterDate.timeIntervalSince1970
        ])
    }

    @Test func cooldownHistoryKeepsOnlyTheNewestBoundedWindow() {
        let manager = QuestManager()
        let subjectID = UUID()
        let key = manager.cooldownKey(petId: subjectID, type: .plantWatering)
        let restore = isolateCooldownValue(forKey: key)
        defer { restore() }

        let baseDate = Date(timeIntervalSince1970: 1_800_300_000)
        let timestamps = (0 ..< QuestManager.cooldownHistoryLimit + 7).map { index in
            baseDate.addingTimeInterval(Double(index) * 60).timeIntervalSince1970
        }
        for timestamp in timestamps {
            manager.recordCooldown(
                petId: subjectID,
                type: .plantWatering,
                occurredAt: Date(timeIntervalSince1970: timestamp)
            )
        }

        #expect(storedCooldownHistory(forKey: key) == Array(
            timestamps.suffix(QuestManager.cooldownHistoryLimit)
        ))
    }

    @Test func singleAwardUsesOperationDateForCooldownEvaluation() throws {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let manager = QuestManager()
        let human = Human(name: "Cooldown Keeper")
        let plantID = UUID()
        context.insert(human)
        try context.save()

        let operationDate = Date().addingTimeInterval(-48 * 60 * 60)
        let priorRewardDate = operationDate.addingTimeInterval(-60 * 60)
        let laterRewardDate = operationDate.addingTimeInterval(5 * 60 * 60)
        let key = manager.cooldownKey(petId: plantID, type: .plantWatering)
        let restoreCooldown = isolateCooldownValue(forKey: key)
        let boostKey = "shop_boostDoubleActive"
        let previousBoost = UserDefaults.standard.object(forKey: boostKey)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let memberKey = human.id.uuidString
        let careObjectKeys = ["plant.\(plantID.uuidString)"]
        let restoreBudgetDefaults = snapshotDefaults(withPrefix: "economyV2.dailyBudget.")
        defer {
            restoreCooldown()
            restoreDefault(previousBoost, forKey: boostKey)
            restoreBudgetDefaults()
        }
        UserDefaults.standard.set(false, forKey: boostKey)
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            date: operationDate
        )
        manager.recordCooldown(
            petId: plantID,
            type: .plantWatering,
            occurredAt: priorRewardDate
        )
        manager.recordCooldown(
            petId: plantID,
            type: .plantWatering,
            occurredAt: laterRewardDate
        )

        let reward = manager.awardAction(
            type: .plantWatering,
            pet: nil,
            context: context,
            date: operationDate,
            executorId: human.id.uuidString,
            careObjectKey: plantID
        )

        #expect(reward.humanGot + reward.petGot == 0)
        #expect(manager.lastEconomyRewardResult?.isOnCooldown == true)
    }

    private func isolateCooldownValue(forKey key: String) -> () -> Void {
        let defaults = UserDefaults.standard
        let originalDictionary = defaults.dictionary(forKey: QuestManager.Keys.cooldownLogs)
        let originalValue = originalDictionary?[key]
        var isolatedDictionary = originalDictionary ?? [:]
        isolatedDictionary.removeValue(forKey: key)
        persistCooldownDictionary(isolatedDictionary, removeWhenEmpty: originalDictionary == nil)

        return {
            var currentDictionary = defaults.dictionary(forKey: QuestManager.Keys.cooldownLogs) ?? [:]
            if let originalValue {
                currentDictionary[key] = originalValue
            } else {
                currentDictionary.removeValue(forKey: key)
            }
            if currentDictionary.isEmpty, originalDictionary == nil {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.set(currentDictionary, forKey: QuestManager.Keys.cooldownLogs)
            }
        }
    }

    private func setCooldownValue(_ value: Any, forKey key: String) {
        var dictionary = UserDefaults.standard.dictionary(forKey: QuestManager.Keys.cooldownLogs) ?? [:]
        dictionary[key] = value
        UserDefaults.standard.set(dictionary, forKey: QuestManager.Keys.cooldownLogs)
    }

    private func storedCooldownHistory(forKey key: String) -> [TimeInterval] {
        let value = UserDefaults.standard.dictionary(forKey: QuestManager.Keys.cooldownLogs)?[key]
        if let number = value as? NSNumber { return [number.doubleValue] }
        if let numbers = value as? [NSNumber] { return numbers.map(\.doubleValue) }
        if let values = value as? [Double] { return values }
        return []
    }

    private func persistCooldownDictionary(
        _ dictionary: [String: Any],
        removeWhenEmpty: Bool
    ) {
        if dictionary.isEmpty, removeWhenEmpty {
            UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        } else {
            UserDefaults.standard.set(dictionary, forKey: QuestManager.Keys.cooldownLogs)
        }
    }

    private func restoreDefault(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func snapshotDefaults(withPrefix prefix: String) -> () -> Void {
        let defaults = UserDefaults.standard
        let originalValues = defaults.dictionaryRepresentation().filter { key, _ in
            key.hasPrefix(prefix)
        }
        return {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in originalValues {
                defaults.set(value, forKey: key)
            }
        }
    }
}
