//
//  OhanaTests.swift
//  OhanaTests
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData
import Testing
@testable import Ohana

struct OhanaTests {

    @MainActor
    @Test func coconutLedgerAuditReconcilesRollingLog() async throws {
        let logs = [
            CoconutLogEntry(emoji: "🥥", title: "奖励", amount: 8),
            CoconutLogEntry(emoji: "🎁", title: "兑换", amount: -3)
        ]

        let audit = CoconutLedgerAudit.evaluate(
            islandCount: 5,
            logs: logs,
            petBalances: [2],
            humanBalances: [3]
        )

        #expect(audit.rollingLogDelta == 5)
        #expect(audit.rollingLogReconciles == true)
        #expect(audit.isHealthy)
    }

    @MainActor
    @Test func coconutLedgerAuditDetectsNegativeAccounts() async throws {
        let audit = CoconutLedgerAudit.evaluate(
            islandCount: 1,
            logs: [CoconutLogEntry(emoji: "🥥", title: "奖励", amount: 1)],
            petBalances: [-1],
            humanBalances: [2]
        )

        #expect(audit.hasNegativeAccount)
        #expect(!audit.isHealthy)
    }

    @MainActor
    @Test func coconutEconomyV2FeedRewardUsesGrowthXPAndLedgerMetadata() async throws {
        let userKey = "policy-feed-\(UUID().uuidString)"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(userKey: userKey, date: date)

        let result = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: userKey,
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(result.growthXP == 6)
        #expect(result.humanCoconuts == 2)
        #expect(result.petCoconuts == 1)
        #expect(result.totalCoconuts == 3)
        #expect(result.bonusCoconuts == 0)
        #expect(result.metadataJSON.contains("\"economyVersion\":2"))
        #expect(CoconutEconomyPolicyV2.metadataValue(named: "growthXP", in: result.metadataJSON) == 6)
    }

    @MainActor
    @Test func coconutEconomyV2CooldownRecordsDataButReducesReward() async throws {
        let userKey = "policy-cooldown-\(UUID().uuidString)"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(userKey: userKey, date: date)

        let result = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: true,
            userKey: userKey,
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(result.growthXP == 2)
        #expect(result.totalCoconuts == 0)
        #expect(result.budgetMultiplier == 0.2)
        #expect(result.reason == "cooldownReduced")
    }

    @MainActor
    @Test func coconutEconomyV2DailyBudgetUsesFatigueBeforeRecordOnly() async throws {
        let userKey = "policy-budget-\(UUID().uuidString)"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(userKey: userKey, date: date)

        for _ in 0 ..< 11 {
            let result = CoconutEconomyPolicyV2.reward(
                for: .feed,
                quality: .none,
                isOnCooldown: false,
                userKey: userKey,
                careObjectCount: 1,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: date,
                forcedLuck: EconomyLuckTier.none
            )
            EconomyDailyBudgetStore.commit(result, userKey: userKey, date: date)
        }

        let fatigue = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: userKey,
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(fatigue.totalCoconuts == 2)
        #expect(fatigue.growthXP == 3)
        #expect(fatigue.budgetStage == .fatigue)
        #expect(fatigue.reason == "dailyBudgetFatigue")

        EconomyDailyBudgetStore.commit(fatigue, userKey: userKey, date: date)
        for _ in 0 ..< 12 {
            let result = CoconutEconomyPolicyV2.reward(
                for: .feed,
                quality: .none,
                isOnCooldown: false,
                userKey: userKey,
                careObjectCount: 1,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: date,
                forcedLuck: EconomyLuckTier.none
            )
            EconomyDailyBudgetStore.commit(result, userKey: userKey, date: date)
        }

        let recordOnly = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: userKey,
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(recordOnly.totalCoconuts == 0)
        #expect(recordOnly.growthXP == 2)
        #expect(recordOnly.budgetStage == .recordOnly)
        #expect(recordOnly.reason == "dailyBudgetRecordOnly")
    }

    @MainActor
    @Test func coconutEconomyV2SharedCareScalesButDoesNotExplodeForThreePets() async throws {
        let userKey = "policy-family-\(UUID().uuidString)"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(userKey: userKey, date: date)

        let result = CoconutEconomyPolicyV2.sharedReward(
            for: .feed,
            targetCount: 3,
            quality: .none,
            isOnCooldown: false,
            userKey: userKey,
            careObjectCount: 3,
            hasHumanAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(result.growthXP == 12)
        #expect(result.totalCoconuts == 5)
        #expect(result.totalCoconuts < 9)
        #expect(EconomyDailyBudgetStore.coconutBudget(careObjectCount: 3) == 48)
        #expect(EconomyDailyBudgetStore.fatigueCoconutBudget(careObjectCount: 3) == 72)
    }

    @MainActor
    @Test func coconutEconomyV2HouseholdBudgetPreventsActiveMemberSwitchBypass() async throws {
        let householdKey = "household-budget-\(UUID().uuidString)"
        let memberA = "member-a-\(UUID().uuidString)"
        let memberB = "member-b-\(UUID().uuidString)"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberA, date: date)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberB, date: date)

        for _ in 0 ..< 8 {
            let result = CoconutEconomyPolicyV2.reward(
                for: .health,
                quality: .none,
                isOnCooldown: false,
                userKey: householdKey,
                memberKey: memberA,
                careObjectCount: 1,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: date,
                forcedLuck: EconomyLuckTier.none
            )
            EconomyDailyBudgetStore.commit(result, householdKey: householdKey, memberKey: memberA, date: date)
        }

        let switchedMemberReward = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: householdKey,
            memberKey: memberB,
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(switchedMemberReward.budgetStage == .recordOnly)
        #expect(switchedMemberReward.totalCoconuts == 0)
        #expect(switchedMemberReward.reason == "dailyBudgetRecordOnly")
    }

    @MainActor
    @Test func coconutEconomyV2CareObjectBudgetProtectsNaturalFrequencyWithoutPunishingOtherPets() async throws {
        let householdKey = "object-budget-\(UUID().uuidString)"
        let memberA = "object-member-a-\(UUID().uuidString)"
        let memberB = "object-member-b-\(UUID().uuidString)"
        let petA = "pet.object.a"
        let petB = "pet.object.b"
        let date = dateForTest(year: 2026, month: 6, day: 9)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberA, careObjectKeys: [petA, petB], date: date)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberB, careObjectKeys: [petA, petB], date: date)

        for _ in 0 ..< 4 {
            let result = CoconutEconomyPolicyV2.reward(
                for: .health,
                quality: .none,
                isOnCooldown: false,
                userKey: householdKey,
                memberKey: memberA,
                careObjectKeys: [petA],
                careObjectCount: 3,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: date,
                forcedLuck: EconomyLuckTier.none
            )
            EconomyDailyBudgetStore.commit(result, householdKey: householdKey, memberKey: memberA, careObjectKeys: [petA], date: date)
        }

        let samePetFromDifferentMember = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: householdKey,
            memberKey: memberB,
            careObjectKeys: [petA],
            careObjectCount: 3,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )
        let otherPetFromDifferentMember = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: householdKey,
            memberKey: memberB,
            careObjectKeys: [petB],
            careObjectCount: 3,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(samePetFromDifferentMember.budgetStage == .fatigue)
        #expect(samePetFromDifferentMember.growthXP == 3)
        #expect(samePetFromDifferentMember.totalCoconuts == 2)
        #expect(otherPetFromDifferentMember.budgetStage == .normal)
        #expect(otherPetFromDifferentMember.growthXP == 6)
        #expect(otherPetFromDifferentMember.totalCoconuts == 3)
    }

    @MainActor
    @Test func oasisTreeEnergyReadsGrowthXPFromLedgerMetadata() async throws {
        UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
        OasisTreePreferenceStore.clearLedgerEnergyCache()
        defer {
            UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
            OasisTreePreferenceStore.clearLedgerEnergyCache()
        }
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(CareLedgerEvent(
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: "pet-1",
            eventKind: .care,
            actionType: "feeding",
            metadataJSON: "{\"economyVersion\":2,\"growthXP\":120}"
        ))
        try context.save()

        TestOasisTreeManagerProjection.manager.refreshPreviewEnergy(modelContext: context, pets: [], humans: [])

        #expect(TestOasisTreeManagerProjection.manager.islandEnergy == 120)
        #expect(OasisTreeManager.treeLevel(forTotalEnergy: 120) == .lv2)
    }

    @MainActor
    @Test func oasisTreeInjectedEnergyCanBeRecoveredFromLedgerMetadata() async throws {
        UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
        UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
        OasisTreePreferenceStore.clearLedgerEnergyCache()
        defer {
            UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
            UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
            OasisTreePreferenceStore.clearLedgerEnergyCache()
        }

        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(CareLedgerEvent(
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "treeInjection",
            metadataJSON: "{\"economyVersion\":2,\"injectedXP\":40,\"reason\":\"treeInjection\"}"
        ))
        try context.save()

        let manager = OasisTreeManager()
        manager.refreshPreviewEnergy(modelContext: context, pets: [], humans: [])

        #expect(manager.islandEnergy == 0)
        #expect(manager.injectedEnergy == 40)
        #expect(manager.totalEnergy == 40)
    }

    @MainActor
    @Test func oasisTreeEnergyCacheInvalidatesAcrossLedgerStoresWithSameCount() async throws {
        UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
        UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
        OasisTreePreferenceStore.clearLedgerEnergyCache()
        defer {
            UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
            UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
            OasisTreePreferenceStore.clearLedgerEnergyCache()
        }

        let occurredAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstContainer = try makeInMemoryContainer()
        firstContainer.mainContext.insert(CareLedgerEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID(),
            occurredAt: occurredAt,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: "pet-1",
            eventKind: .care,
            actionType: "feeding",
            metadataJSON: "{\"economyVersion\":2,\"growthXP\":120}"
        ))
        try firstContainer.mainContext.save()

        let firstManager = OasisTreeManager()
        firstManager.refreshPreviewEnergy(modelContext: firstContainer.mainContext, pets: [], humans: [])
        #expect(firstManager.islandEnergy == 120)

        UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
        let secondContainer = try makeInMemoryContainer()
        secondContainer.mainContext.insert(CareLedgerEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202") ?? UUID(),
            occurredAt: occurredAt,
            actorKind: .human,
            actorId: "human-2",
            subjectKind: .pet,
            subjectId: "pet-2",
            eventKind: .care,
            actionType: "feeding",
            metadataJSON: "{\"economyVersion\":2,\"growthXP\":40}"
        ))
        try secondContainer.mainContext.save()

        let secondManager = OasisTreeManager()
        secondManager.refreshPreviewEnergy(modelContext: secondContainer.mainContext, pets: [], humans: [])
        #expect(secondManager.islandEnergy == 40)
    }

    @MainActor
    @Test func oasisTreeEnergyCacheAccumulatesNewLedgerEvents() async throws {
        UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
        UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
        OasisTreePreferenceStore.clearLedgerEnergyCache()
        defer {
            UserDefaults.standard.removeObject(forKey: "oasis_injectedEnergy")
            UserDefaults.standard.removeObject(forKey: "oasis_v2LegacyBaselineXP")
            OasisTreePreferenceStore.clearLedgerEnergyCache()
        }

        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: "pet-1",
            eventKind: .care,
            actionType: "feeding",
            metadataJSON: "{\"economyVersion\":2,\"growthXP\":30}"
        ))
        try context.save()

        let manager = OasisTreeManager()
        manager.refreshPreviewEnergy(modelContext: context, pets: [], humans: [])
        #expect(manager.islandEnergy == 30)
        #expect(manager.injectedEnergy == 0)

        context.insert(CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 1_800_000_060),
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "treeInjection",
            metadataJSON: "{\"economyVersion\":2,\"growthXP\":12,\"injectedXP\":5}"
        ))
        try context.save()

        manager.refreshPreviewEnergy(modelContext: context, pets: [], humans: [])
        #expect(manager.islandEnergy == 42)
        #expect(manager.injectedEnergy == 5)
    }

    @MainActor
    @Test func todayFocusDailyCompletionAwardsV2OncePerDay() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Focus Owner")
        let pet = Pet(name: "Momo", species: "猫")
        let date = dateForTest(year: 2026, month: 6, day: 19)
        let weightLog = HumanWeightLog(date: date, weight: 68, human: human)
        human.weightLogs.append(weightLog)
        let playLog = PetCareLog(date: date, type: .play, pet: pet)
        let petWeightLog = PetWeightLog(date: date, weight: 4.8, pet: pet)
        let photoLog = PetPhotoLog(imageData: Data([1, 2, 3]), date: date, note: "today", pet: pet)
        pet.careLogs.append(playLog)
        pet.weightLogs.append(petWeightLog)
        pet.photoLogs.append(photoLog)
        context.insert(human)
        context.insert(pet)
        context.insert(weightLog)
        context.insert(playLog)
        context.insert(petWeightLog)
        context.insert(photoLog)
        try context.save()

        let userKey = human.id.uuidString
        let visibleQuests = [
            IslandQuest(
                id: "q_human_weight_\(human.id.uuidString)",
                emoji: "✅",
                title: "体重",
                subtitle: "",
                isCompleted: true,
                targetPetId: nil,
                targetPlantId: nil
            )
        ]
        let oldActiveHuman = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let manager = TestQuestManagerProjection.manager
        let oldCount = manager.coconutCount
        let oldLogs = manager.coconutLogs
        let oldLastReward = manager.lastEconomyRewardResult
        let oldPetWizard = manager.isPetWizardCompleted
        let oldFirstMeal = manager.isFirstMealRecorded
        let oldThemeColor = manager.isThemeColorSet
        defer {
            if let oldActiveHuman {
                UserDefaults.standard.set(oldActiveHuman, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            manager.coconutCount = oldCount
            manager.coconutLogs = oldLogs
            manager.lastEconomyRewardResult = oldLastReward
            manager.isPetWizardCompleted = oldPetWizard
            manager.isFirstMealRecorded = oldFirstMeal
            manager.isThemeColorSet = oldThemeColor
            manager.persistQuestFlags()
        }

        manager.isPetWizardCompleted = true
        manager.isFirstMealRecorded = true
        manager.isThemeColorSet = true
        manager.persistQuestFlags()
        UserDefaults.standard.set(userKey, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.reset(householdKey: CoconutEconomyPolicyV2.householdBudgetKey(), memberKey: userKey, date: date)
        TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: date)

        let first = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: visibleQuests,
            now: date,
            questManager: manager
        )
        let second = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: visibleQuests,
            now: date,
            questManager: manager
        )
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        let awardedXP = first?.growthXP ?? 0
        let awardedCoconuts = first?.totalCoconuts ?? 0
        #expect((18 ... 33).contains(awardedXP))
        #expect((8 ... 16).contains(awardedCoconuts))
        #expect(second == nil)
        #expect(human.coconutBalance == awardedCoconuts)
        let focusLedger = ledger.first { $0.actionType == "todayFocusDailyCompletion" }
        let focusLedgerGrowthXP = focusLedger.map {
            CoconutEconomyPolicyV2.metadataValue(named: "growthXP", in: $0.metadataJSON)
        } ?? 0
        #expect(focusLedger != nil)
        #expect(focusLedgerGrowthXP == awardedXP)
    }

    @MainActor
    @Test func todayFocusDailyCompletionRequiresVisibleQuestsCompleted() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Focus Owner")
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let userKey = human.id.uuidString
        let date = dateForTest(year: 2026, month: 6, day: 9)
        let visibleQuests = [
            IslandQuest(
                id: "q_feed_\(pet.id.uuidString)",
                emoji: "🍽️",
                title: "喂食",
                subtitle: "今天还缺喂食",
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            )
        ]
        TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: date)

        let reward = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: visibleQuests,
            now: date
        )

        #expect(reward == nil)
    }

    @MainActor
    @Test func todayFocusDailyCompletionWaitsForVisibleNonQuestCards() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Focus Owner")
        let date = dateForTest(year: 2026, month: 6, day: 9)
        let weightLog = HumanWeightLog(date: date, weight: 68, human: human)
        human.weightLogs.append(weightLog)
        context.insert(human)
        context.insert(weightLog)
        try context.save()

        let userKey = human.id.uuidString
        let visibleQuests = [
            IslandQuest(
                id: "q_human_weight_\(human.id.uuidString)",
                emoji: "✅",
                title: "Weight",
                subtitle: "",
                isCompleted: true,
                targetPetId: nil,
                targetPlantId: nil
            )
        ]
        let familyTask = FamilyCollaborationTask(
            title: "Review groceries",
            kind: .householdTask,
            status: .active,
            createdById: "other",
            createdByName: "Other",
            assignedToId: userKey,
            assignedToName: human.name
        )
        let visibleSnapshot = TodayFocusSnapshot(
            dayToken: TodayFocusSnapshot.dayToken(for: date),
            pets: [],
            plants: [],
            humans: [TodayFocusHumanSnapshot(human: human)],
            refreshedQuests: visibleQuests,
            assignedFamilyTasks: [TodayFocusFamilyTaskSnapshot(task: familyTask)],
            pendingExchangeRequests: [],
            negativeSignals: []
        )
        let manager = TestQuestManagerProjection.manager
        let oldPetWizard = manager.isPetWizardCompleted
        let oldFirstMeal = manager.isFirstMealRecorded
        let oldThemeColor = manager.isThemeColorSet
        defer {
            manager.isPetWizardCompleted = oldPetWizard
            manager.isFirstMealRecorded = oldFirstMeal
            manager.isThemeColorSet = oldThemeColor
            manager.persistQuestFlags()
        }

        manager.isPetWizardCompleted = true
        manager.isFirstMealRecorded = true
        manager.isThemeColorSet = true
        manager.persistQuestFlags()
        EconomyDailyBudgetStore.reset(householdKey: CoconutEconomyPolicyV2.householdBudgetKey(), memberKey: userKey, date: date)
        TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: date)

        let reward = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: visibleQuests,
            visibleSnapshot: visibleSnapshot,
            now: date
        )

        #expect(reward == nil)
    }

    @Test func todayFocusClearHiddenStateRestoresSkippedAndClosedSignals() async throws {
        let suiteName = "todayFocus.hidden.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let date = dateForTest(year: 2026, month: 6, day: 9)

        TodayFocusHiddenStateStore.save(
            skippedFocusKeys: ["quest:q_feed"],
            closedNegativeKeys: ["negative:pet:warning"],
            date: date,
            defaults: defaults
        )
        TodayFocusHiddenStateStore.clearHiddenFocusKeys(date: date, defaults: defaults)

        #expect(TodayFocusHiddenStateStore.loadSkippedFocusKeys(date: date, defaults: defaults).isEmpty)
        #expect(TodayFocusHiddenStateStore.loadClosedNegativeKeys(date: date, defaults: defaults).isEmpty)
    }

    @MainActor
    @Test func todayFocusDailyCompletionWaitsForRegeneratedQuestDeck() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Focus Owner")
        let pet = Pet(name: "Momo", species: "猫")
        let date = dateForTest(year: 2026, month: 6, day: 9)
        let feedLog = PetCareLog(date: date, type: .feeding, amountGrams: 20, pet: pet)
        context.insert(human)
        context.insert(pet)
        context.insert(feedLog)
        try context.save()

        let userKey = human.id.uuidString
        let visibleQuests = [
            IslandQuest(
                id: "q_feed_\(pet.id.uuidString)",
                emoji: "🍽️",
                title: "喂食",
                subtitle: "今天还缺喂食",
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            )
        ]
        let manager = TestQuestManagerProjection.manager
        let oldPetWizard = manager.isPetWizardCompleted
        let oldFirstMeal = manager.isFirstMealRecorded
        let oldThemeColor = manager.isThemeColorSet
        defer {
            manager.isPetWizardCompleted = oldPetWizard
            manager.isFirstMealRecorded = oldFirstMeal
            manager.isThemeColorSet = oldThemeColor
            manager.persistQuestFlags()
        }

        manager.isPetWizardCompleted = true
        manager.isFirstMealRecorded = true
        manager.isThemeColorSet = true
        manager.persistQuestFlags()
        TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: date)

        let reward = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: visibleQuests,
            now: date
        )

        #expect(reward == nil)
    }

    @MainActor
    @Test func privacyServiceMapsHumanQuickActions() async throws {
        let owner = Human(name: "Owner")
        let viewer = Human(name: "Viewer")
        owner.setPrivate(.weight, true)

        let item = QuickActionItem(
            label: "体重",
            icon: "scalemass",
            colorHex: "00D4AA",
            actionType: "humanWeight",
            entityId: owner.id,
            entityKind: .human
        )

        #expect(PrivacyService.field(forHumanAction: "humanWeight") == .weight)
        #expect(PrivacyService.isHumanQuickActionLocked(item, human: owner, viewedBy: viewer.id))
        #expect(!PrivacyService.isHumanQuickActionLocked(item, human: owner, viewedBy: owner.id))
        #expect(PrivacyService.badgeText(for: .weight, human: owner, viewedBy: viewer.id) == "仅自己")
    }

    @MainActor
    @Test func humanPasscodeValidatesHashesAndLocksAfterFailures() async throws {
        let human = Human(name: "Private")
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!HumanPasscodeService.isValidPin("123"))
        #expect(!HumanPasscodeService.isValidPin("12a4"))
        #expect(HumanPasscodeService.isValidPin("1234"))

        try HumanPasscodeService.setPasscode("1234", for: human)
        #expect(HumanPasscodeService.hasPasscode(human))
        #expect(human.pinHash != "1234")
        #expect(!human.pinSalt.isEmpty)

        if case let .incorrect(remaining) = HumanPasscodeService.verify("0000", for: human, now: now) {
            #expect(remaining == 4)
        } else {
            Issue.record("Expected first incorrect passcode")
        }

        _ = HumanPasscodeService.verify("0000", for: human, now: now)
        _ = HumanPasscodeService.verify("0000", for: human, now: now)
        _ = HumanPasscodeService.verify("0000", for: human, now: now)
        if case let .locked(until) = HumanPasscodeService.verify("0000", for: human, now: now) {
            #expect(until.timeIntervalSince(now) == HumanPasscodeService.lockoutDuration)
        } else {
            Issue.record("Expected lockout after five failures")
        }

        if case .locked = HumanPasscodeService.verify("1234", for: human, now: now.addingTimeInterval(1)) {
            // Expected: correct passcode should remain locked during cooldown.
        } else {
            Issue.record("Expected correct passcode to remain locked during cooldown")
        }

        #expect(HumanPasscodeService.verify("1234", for: human, now: now.addingTimeInterval(31)) == .success)
        #expect(human.pinFailedAttempts == 0)
        #expect(human.pinLockedUntil == nil)
    }

    @MainActor
    @Test func humanPasscodeIsNotIncludedInBackupAndRestore() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Backup Owner")
        try HumanPasscodeService.setPasscode("2468", for: human)
        sourceContext.insert(human)
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let exported = try String(contentsOf: url, encoding: .utf8)
        #expect(!exported.contains("pinHash"))
        #expect(!exported.contains("pinSalt"))
        #expect(!exported.contains(human.pinHash))

        let target = try makeInMemoryContainer()
        try await TestDataBackupManagerProjection.manager.importJSON(from: url, context: target.mainContext)
        let restored = try target.mainContext.fetch(FetchDescriptor<Human>()).first
        #expect(restored?.name == "Backup Owner")
        #expect(restored.map { !HumanPasscodeService.hasPasscode($0) } ?? false)
    }

    @MainActor
    @Test func encryptedBackupRequiresPasswordAndRestoresData() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Sensitive Ava")
        human.notes = "private health note"
        sourceContext.insert(human)
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(
            container: source,
            password: "correct horse battery"
        )
        let encryptedData = try Data(contentsOf: url)
        let exported = try #require(String(data: encryptedData, encoding: .utf8))
        #expect(DataBackupEncryption.isEncryptedBackup(encryptedData))
        #expect(!exported.contains("Sensitive Ava"))
        #expect(!exported.contains("private health note"))

        let wrongTarget = try makeInMemoryContainer()
        var wrongPasswordRejected = false
        do {
            try await TestDataBackupManagerProjection.manager.importJSON(
                from: url,
                context: wrongTarget.mainContext,
                password: "wrong password"
            )
            Issue.record("Expected encrypted backup import to reject the wrong password")
        } catch BackupError.invalidBackupPassword {
            wrongPasswordRejected = true
        } catch {
            Issue.record("Expected invalidBackupPassword, got \(error)")
        }
        #expect(wrongPasswordRejected)

        let target = try makeInMemoryContainer()
        try await TestDataBackupManagerProjection.manager.importJSON(
            from: url,
            context: target.mainContext,
            password: "correct horse battery"
        )
        let restored = try target.mainContext.fetch(FetchDescriptor<Human>()).first
        #expect(restored?.name == "Sensitive Ava")
        #expect(restored?.notes == "private health note")
    }

    @MainActor
    @Test func backupOmitsDormantAppleIdentifierAndMovesHumanGenderOutOfNotes() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Legacy Human")
        human.appleUserIdentifier = "apple-user-secret"
        human.notes = "性别:女｜visible note"
        sourceContext.insert(human)
        try sourceContext.save()

        let data = try TestDataBackupManagerProjection.manager.encode(
            TestDataBackupManagerProjection.manager.buildBackup(context: sourceContext)
        )
        let exported = try #require(String(data: data, encoding: .utf8))
        let backup = try JSONDecoder().decode(OhanaBackup.self, from: data)

        #expect(!exported.contains("apple-user-secret"))
        #expect(!exported.contains("appleUserIdentifier"))
        #expect(!exported.contains("性别:"))
        #expect(backup.humans.first?.genderIdentityRaw == "女")
        #expect(backup.humans.first?.notes == "visible note")

        let target = try makeInMemoryContainer()
        try await TestDataBackupManagerProjection.manager.importJSON(
            from: writeTemporaryBackup(data),
            context: target.mainContext
        )
        let restored = try target.mainContext.fetch(FetchDescriptor<Human>()).first
        #expect(restored?.appleUserIdentifier == "")
        #expect(restored?.genderRaw == "女")
        #expect(restored?.notes == "visible note")
    }

    @MainActor
    @Test func backupRestoresPaidConsumableInventory() async throws {
        let suiteName = "OhanaTests.BackupInventory.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataBackupManager(defaults: defaults)

        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(3, forKey: CheckInStreakStore.makeupPackKey)
        defaults.set(2, forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
        defaults.set(true, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
        defaults.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)

        let source = try makeInMemoryContainer()
        let encoded = try manager.encode(manager.buildBackup(context: source.mainContext))
        let backup = try JSONDecoder().decode(OhanaBackup.self, from: encoded)
        #expect(backup.appState.shopConsumableInventory?.doubleRewardBoostActive == true)

        defaults.set(99, forKey: CheckInStreakStore.makeupPackKey)
        defaults.set(99, forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
        defaults.set(false, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
        defaults.removeObject(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)

        let target = try makeInMemoryContainer()
        try manager.applyBackup(backup, context: target.mainContext, projectionManager: nil)

        #expect(defaults.integer(forKey: CheckInStreakStore.makeupPackKey) == 3)
        #expect(defaults.integer(forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory) == 2)
        #expect(defaults.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost))
        #expect(defaults.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) as? Date == expiry)
    }

    @MainActor
    @Test func reminderCompletionServiceCompletesAndSkips() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reminder = Reminder(scheduledAt: Date())
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)
        #expect(reminder.statusEnum == ReminderStatus.completed)
        #expect(reminder.completedAt != nil)
        #expect(reminder.completedBy == "human-1")

        ReminderCompletionService.skip(reminder, by: "human-2", context: context)
        #expect(reminder.statusEnum == ReminderStatus.skipped)
        #expect(reminder.completedAt == nil)
        #expect(reminder.completedBy == "human-2")
    }

    @MainActor
    @Test func careEventServiceRecordsManualFeed() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        CareEventService.recordManualFeed(pet: pet, amountGrams: 42, context: context, executorId: "human-1")

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 42)
        #expect(logs.first?.executorId == "human-1")

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.eventKindEnum == .care)
        #expect(ledger.first?.legacyModelName == "PetCareLog")
        #expect(ledger.first?.legacyModelId == logs.first?.id.uuidString)
    }

    @MainActor
    @Test func reminderCompletionServiceWritesLedgerEvent() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "喂药", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date())
        context.insert(event)
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
        #expect(ledger.first?.eventKindEnum == .reminder)
        #expect(ledger.first?.actionType == "complete")
        #expect(ledger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceSkipsPastDueAndWritesLedger() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "过期提醒", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(-60))
        context.insert(event)
        context.insert(reminder)

        let result = await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: context)

        #expect(result == .skippedPastDue)
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.first?.actionType == "scheduleSkippedPastDue")
        #expect(ledger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceDeduplicatesEventAndScheduledMinute() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "重复提醒", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let rawScheduledAt = Date().addingTimeInterval(3600)
        let scheduledAt = Date(timeIntervalSince1970: floor(rawScheduledAt.timeIntervalSince1970 / 60) * 60)
        let first = Reminder(event: event, scheduledAt: scheduledAt)
        let duplicate = Reminder(event: event, scheduledAt: scheduledAt.addingTimeInterval(10))
        context.insert(event)
        context.insert(first)
        context.insert(duplicate)
        try context.save()

        let kept = ReminderSchedulingService.deduplicate(reminders: [duplicate, first], context: context)

        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(kept.count == 1)
        #expect(reminders.count == 1)
        #expect(reminders.first?.id == first.id)
        #expect(ledger.first?.actionType == "dedupeRemoved")
        #expect(ledger.first?.sourceReminderId == duplicate.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceCompensatesOverdueReminders() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let petId = UUID().uuidString
        let foodEvent = Event(title: "早餐", eventType: EventType.foodChange.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let taskEvent = Event(title: "清洁", eventType: EventType.grooming.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let foodReminder = Reminder(event: foodEvent, scheduledAt: Date().addingTimeInterval(-3600))
        let taskReminder = Reminder(event: taskEvent, scheduledAt: Date().addingTimeInterval(-3600))
        context.insert(foodEvent)
        context.insert(taskEvent)
        context.insert(foodReminder)
        context.insert(taskReminder)

        ReminderSchedulingService.compensate(reminders: [foodReminder, taskReminder], context: context)

        #expect(foodReminder.statusEnum == ReminderStatus.failed)
        #expect(taskReminder.statusEnum == ReminderStatus.skipped)
        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("compensateFailed"))
        #expect(actions.contains("compensateSkipped"))
    }

    @MainActor
    @Test func reminderCompletionServiceReopenAndSnoozeWriteLedgerEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "服药", relatedEntityType: EntityKind.human.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3600))
        context.insert(event)
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)
        ReminderCompletionService.reopen(reminder, by: "human-1", context: context, reschedule: false)
        ReminderCompletionService.snoozeOneDay(reminder, by: "human-1", context: context, reschedule: false)

        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("complete"))
        #expect(actions.contains("reopen"))
        #expect(actions.contains("snoozeOneDay"))
        #expect(reminder.statusEnum == ReminderStatus.pending)
        #expect(reminder.scheduledAt > Date())
    }

    @MainActor
    @Test func plannedFeedCompletionArchivesReminderAndActualCareLog() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐 45g",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(-60))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)

        CareEventService.completePlannedFeed(pet: pet, reminder: reminder, context: context, executorId: "human-1")

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(reminder.statusEnum == ReminderStatus.completed)
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
        #expect(ledger.contains { $0.actionType == "completePlannedCare" && $0.sourceReminderId == reminder.id.uuidString })
        #expect(ledger.contains { $0.eventKindEnum == .care && $0.sourceEventId == event.id.uuidString && $0.sourceReminderId == reminder.id.uuidString })
    }

    @MainActor
    @Test func plannedFeedCatchUpWithinSixHoursDoesNotAwardCoconuts() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let previousCoconutCount = TestQuestManagerProjection.manager.coconutCount
        let previousFirstMeal = TestQuestManagerProjection.manager.isFirstMealRecorded
        let previousLogs = TestQuestManagerProjection.manager.coconutLogs
        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.isFirstMealRecorded = false
        TestQuestManagerProjection.manager.coconutLogs = []
        defer {
            TestQuestManagerProjection.manager.coconutCount = previousCoconutCount
            TestQuestManagerProjection.manager.isFirstMealRecorded = previousFirstMeal
            TestQuestManagerProjection.manager.coconutLogs = previousLogs
        }

        let pet = Pet(name: "Momo", species: "猫")
        let scheduledAt = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let completedAt = dateForTest(year: 2026, month: 5, day: 8, hour: 10)
        let event = Event(
            title: "早餐 45g",
            startDate: scheduledAt,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)

        let reward = CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: context,
            executorId: "human-1",
            date: completedAt
        )

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(reward?.humanGot == 0)
        #expect(reward?.petGot == 0)
        #expect(TestQuestManagerProjection.manager.coconutCount == 0)
        #expect(!TestQuestManagerProjection.manager.isFirstMealRecorded)
        #expect(pet.coconutBalance == 0)
        #expect(ledger.contains { $0.eventKindEnum == .care && $0.sourceReminderId == reminder.id.uuidString && $0.coconutDelta == 0 })
        #expect(reminder.statusEnum == .completed)
    }

    @MainActor
    @Test func plannedFeedCatchUpAfterSixHoursIsRejected() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let scheduledAt = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let completedAt = dateForTest(year: 2026, month: 5, day: 8, hour: 15)
        let event = Event(
            title: "早餐 45g",
            startDate: scheduledAt,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)

        let reward = CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: context,
            executorId: "human-1",
            date: completedAt
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(reward?.humanGot == nil)
        #expect(logs.isEmpty)
        #expect(reminder.statusEnum == .pending)
        #expect(!event.isOccurrenceMarkedComplete(on: scheduledAt))
    }

    @MainActor
    @Test func feedTodayStateUsesManualGoalWhenNoPlanExists() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        context.insert(PetCareLog(date: now.addingTimeInterval(-3600), type: .feeding, amountGrams: 30, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        context.insert(PetCareLog(date: now.addingTimeInterval(-1800), type: .feeding, amountGrams: 40, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        try context.save()

        let state = FeedTodayState(pet: pet, allEvents: [], manualGoalCount: 3, now: now, calendar: calendar)

        #expect(!state.hasTodayPlan)
        #expect(state.completedCount == 2)
        #expect(state.targetCount == 3)
        #expect(!state.isComplete)
        #expect(state.todayFeedGrams == 70)
    }

    @MainActor
    @Test func petMainFoodKindDrivesManualFeedKind() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        #expect(pet.mainFoodKind == .dry)
        pet.mainFoodKind = .wet
        _ = CareEventService.recordManualFeed(
            pet: pet,
            amountGrams: 85,
            context: context,
            executorId: "human-1",
            foodKind: pet.mainFoodKind
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.foodKind == .wet)
        #expect(logs.first?.amountGrams == 85)
    }

    @MainActor
    @Test func feedTodayStateUsesPlanProgressAndKeepsOverduePlanActionable() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        let breakfast = Event(
            title: "早餐 35g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let dinner = Event(
            title: "晚餐 45g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 11),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let completedBreakfast = Reminder(event: breakfast, scheduledAt: breakfast.startDate)
        completedBreakfast.statusEnum = .completed
        let failedDinner = Reminder(event: dinner, scheduledAt: dinner.startDate)
        failedDinner.statusEnum = .failed
        context.insert(pet)
        context.insert(breakfast)
        context.insert(dinner)
        context.insert(completedBreakfast)
        context.insert(failedDinner)
        context.insert(PetCareLog(date: now, type: .feeding, amountGrams: 20, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        try context.save()

        let state = FeedTodayState(pet: pet, allEvents: [breakfast, dinner], manualGoalCount: 1, now: now, calendar: calendar)

        #expect(state.hasTodayPlan)
        #expect(state.completedCount == 1)
        #expect(state.targetCount == 2)
        #expect(!state.isComplete)
        #expect(state.nextPendingReminder?.id == failedDinner.id)
        #expect(state.hasOverduePlan)
        #expect(state.manualTodayLogs.count == 1)
    }

    @MainActor
    @Test func careLedgerBackfillIsIdempotent() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetCareLog(date: Date(), type: .watering, amountMl: 200, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(log)
        try context.save()

        try CareLedgerBackfillService.backfill(context: context)
        try CareLedgerBackfillService.backfill(context: context)

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.legacyModelName == "PetCareLog")
        #expect(ledger.first?.legacyModelId == log.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresHumanFieldsAndLogRelationships() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Ava", avatarEmoji: "A")
        let passedAwayDate = dateForTest(year: 2026, month: 5, day: 20, hour: 9)
        let metricDate = dateForTest(year: 2026, month: 5, day: 10, hour: 8)
        human.mbti = "INTJ"
        human.themeColorHex = "FF8800"
        human.heightCm = 168
        human.setPrivate(.weight, true)
        human.avatarImageData = Data([1, 2, 3])
        human.passedAwayDate = passedAwayDate
        let metricLog = HumanHealthMetricLog(
            metricKey: "hba1c",
            unitCode: "percent",
            value: 5.4,
            date: metricDate,
            notes: "annual check",
            human: human
        )
        sourceContext.insert(human)
        sourceContext.insert(HumanWeightLog(weight: 55, human: human))
        sourceContext.insert(HumanWorkoutLog(type: .running, durationMinutes: 30, human: human))
        sourceContext.insert(metricLog)
        CareLedgerService.record(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .weight,
            actionType: "humanWeight",
            amountValue: 55,
            amountUnit: "kg",
            source: .service,
            legacyModelName: "HumanWeightLog",
            legacyModelId: "weight-log",
            context: sourceContext,
            save: false
        )
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await TestDataBackupManagerProjection.manager.importJSON(from: url, context: targetContext)

        let restoredHumans = try targetContext.fetch(FetchDescriptor<Human>())
        let restored = try #require(restoredHumans.first)
        #expect(restored.mbti == "INTJ")
        #expect(restored.themeColorHex == "FF8800")
        #expect(restored.heightCm == 168)
        #expect(restored.isPrivate(.weight, viewedBy: UUID()))
        #expect(restored.avatarImageData == Data([1, 2, 3]))
        #expect(restored.passedAwayDate == passedAwayDate)

        let weights = try targetContext.fetch(FetchDescriptor<HumanWeightLog>())
        let workouts = try targetContext.fetch(FetchDescriptor<HumanWorkoutLog>())
        let healthMetrics = try targetContext.fetch(FetchDescriptor<HumanHealthMetricLog>())
        #expect(weights.first?.human?.id == restored.id)
        #expect(workouts.first?.human?.id == restored.id)
        #expect(healthMetrics.first?.human?.id == restored.id)
        #expect(healthMetrics.first?.metricKey == "hba1c")
        #expect(healthMetrics.first?.unitCode == "percent")
        #expect(healthMetrics.first?.value == 5.4)
        #expect(healthMetrics.first?.date == metricDate)
        #expect(healthMetrics.first?.notes == "annual check")

        let ledger = try targetContext.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.first?.eventKindEnum == .weight)
        #expect(ledger.first?.subjectId == restored.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresReminderAndLedgerArchiveRelationship() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let petId = UUID().uuidString
        let event = Event(title: "晚餐", eventType: EventType.foodChange.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3600))
        sourceContext.insert(event)
        sourceContext.insert(reminder)
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "scheduleSuccess",
            actorId: nil,
            source: .service,
            context: sourceContext
        )
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await TestDataBackupManagerProjection.manager.importJSON(from: url, context: targetContext)

        let restoredEvents = try targetContext.fetch(FetchDescriptor<Event>())
        let restoredReminders = try targetContext.fetch(FetchDescriptor<Reminder>())
        let restoredLedger = try targetContext.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(restoredEvents.count == 1)
        #expect(restoredReminders.first?.event?.id == restoredEvents.first?.id)
        #expect(restoredLedger.first?.sourceEventId == event.id.uuidString)
        #expect(restoredLedger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresFoodStockDatesAndCorrection() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let purchaseDate = dateForTest(year: 2026, month: 5, day: 1)
        let openDate = dateForTest(year: 2026, month: 5, day: 5)
        let correctionDate = dateForTest(year: 2026, month: 5, day: 7, hour: 10)
        let record = PetFoodRecord(
            brand: "Backup Food",
            dailyGrams: 50,
            totalGrams: 1200,
            foodKind: .dry,
            purchaseDate: purchaseDate,
            startDate: openDate,
            pet: pet,
            executorId: "human-1"
        )
        record.remainingCorrectionGrams = 700
        record.remainingCorrectionDate = correctionDate
        sourceContext.insert(pet)
        sourceContext.insert(record)
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await TestDataBackupManagerProjection.manager.importJSON(from: url, context: targetContext)

        let restored = try #require(try targetContext.fetch(FetchDescriptor<PetFoodRecord>()).first)
        #expect(restored.purchaseDate == purchaseDate)
        #expect(restored.startDate == openDate)
        #expect(restored.remainingCorrectionGrams == 700)
        #expect(restored.remainingCorrectionDate == correctionDate)
    }

    @MainActor
    @Test func backupRestoresRetentionAndMedicationModels() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Ava", avatarEmoji: "A")
        sourceContext.insert(pet)
        sourceContext.insert(human)

        sourceContext.insert(PetPhotoLog(imageData: Data([9, 8, 7]), note: "first photo", pet: pet, locationLatitude: 1.2, locationLongitude: 3.4, locationPlacename: "Home"))

        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        document.issueDate = Date()
        document.issuingAuthority = "Vet"
        document.notes = "with attachment"
        let attachment = PetDocumentAttachment(data: Data([1, 1, 2]), filename: "pass.png", isImage: true)
        document.attachments.append(attachment)
        sourceContext.insert(document)
        sourceContext.insert(attachment)

        let insurance = PetInsurance(companyName: "SafePet", policyNumber: "P1", productName: "Care", annualPremium: 120, coverageAmount: 1000, pet: pet)
        let claim = InsuranceClaim(totalExpense: 200, claimedAmount: 100, approvedAmount: 80, status: .approved, note: "claim", insurance: insurance)
        sourceContext.insert(insurance)
        sourceContext.insert(claim)

        let petMedication = PetMedication(name: "Meds", dosage: "1 pill", frequency: .weekly, pet: pet)
        petMedication.customFrequencyNote = "Sunday"
        petMedication.remainingAmount = 6
        sourceContext.insert(petMedication)

        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin", dosage: "1", frequency: .daily)
        sourceContext.insert(humanMedication)
        sourceContext.insert(HumanMedicationLog(humanId: human.id.uuidString, medicationId: humanMedication.id.uuidString, scheduledTime: Date(), status: .taken, recordedTime: Date()))

        sourceContext.insert(SymptomLog(category: .skin, symptomName: "itch", severity: .moderate, note: "watch", photoData: Data([4, 5]), pet: pet))
        sourceContext.insert(HeatCycleLog(status: .estrus, note: "normal", isMated: true, pet: pet))
        try sourceContext.save()

        let url = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await TestDataBackupManagerProjection.manager.importJSON(from: url, context: targetContext)

        #expect(try targetContext.fetch(FetchDescriptor<PetPhotoLog>()).first?.imageData == Data([9, 8, 7]))
        #expect(try targetContext.fetch(FetchDescriptor<PetDocument>()).first?.attachments.first?.data == Data([1, 1, 2]))
        #expect(try targetContext.fetch(FetchDescriptor<PetInsurance>()).first?.claims.first?.approvedAmount == 80)
        #expect(try targetContext.fetch(FetchDescriptor<PetMedication>()).first?.customFrequencyNote == "Sunday")
        #expect(try targetContext.fetch(FetchDescriptor<PetMedication>()).first?.remainingAmount == 6)
        #expect(try targetContext.fetch(FetchDescriptor<HumanMedication>()).first?.name == "Vitamin")
        #expect(try targetContext.fetch(FetchDescriptor<HumanMedicationLog>()).first?.status == .taken)
        #expect(try targetContext.fetch(FetchDescriptor<SymptomLog>()).first?.photoData == Data([4, 5]))
        #expect(try targetContext.fetch(FetchDescriptor<HeatCycleLog>()).first?.isMated == true)
    }

    @MainActor
    @Test func reminderSchedulingServiceSkipsMissingEventAndDuplicateNotification() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let orphan = Reminder(scheduledAt: Date().addingTimeInterval(3600))
        context.insert(orphan)
        let missingResult = await ReminderSchedulingService.scheduleIfNeeded(reminder: orphan, context: context)
        #expect(missingResult == .missingEvent)

        let event = Event(title: "喂水", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let duplicate = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3600))
        context.insert(event)
        context.insert(duplicate)
        let duplicateResult = await ReminderSchedulingService.scheduleIfNeeded(
            reminder: duplicate,
            context: context,
            existingNotificationIds: [duplicate.notificationId]
        )
        #expect(duplicateResult == .skippedDuplicate)

        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("scheduleMissingEvent"))
        #expect(actions.contains("scheduleDuplicate"))
    }

    @MainActor
    @Test func careLedgerServiceRecordsCoconutAndPetCareAmounts() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let feed = PetCareLog(type: .feeding, amountGrams: 36, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(feed)

        CareLedgerService.recordPetCare(log: feed, pet: pet, source: .quickAction, coconutDelta: 3, context: context)
        CareLedgerService.recordCoconut(delta: 2, title: "奖励", actorId: "human-1", actorName: "Ava", source: .economy, context: context)

        let events = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(CareLedgerService.rewardDelta((humanGot: -1, petGot: 4)) == 4)
        #expect(events.contains { $0.eventKindEnum == .care && $0.actionType == CareType.feeding.rawValue && $0.amountValue == 36 && $0.amountUnit == "g" })
        #expect(events.contains { $0.eventKindEnum == .coconut && $0.coconutDelta == 2 && $0.note.contains("Ava") })
    }

    @MainActor
    @Test func privacyServiceCoversHumanSensitiveActions() async throws {
        let owner = Human(name: "Owner")
        let viewer = Human(name: "Viewer")
        owner.setPrivate(.workout, true)
        owner.setPrivate(.medication, true)
        owner.setPrivate(.wishlist, true)
        owner.setPrivate(.expense, true)

        #expect(PrivacyService.field(forHumanAction: "humanWorkout") == .workout)
        #expect(PrivacyService.field(forHumanAction: "medication") == .medication)
        #expect(PrivacyService.field(forHumanAction: "wishlist") == .wishlist)
        #expect(PrivacyService.field(forHumanAction: "humanExpense") == .expense)
        #expect(PrivacyService.badgeText(for: .medication, human: owner, viewedBy: viewer.id) == "仅自己")
        #expect(PrivacyService.badgeText(for: .expense, human: owner, viewedBy: owner.id) == "公开")
        #expect(PrivacyService.lockedMessage(for: .workout) == "运动数据仅本人可见")
    }

    @MainActor
    @Test func quickActionLimitCountsOnlyTargetPetItems() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "狗")
        let petItems = (0 ..< 8).map { index in
            QuickActionItem(label: "动作\(index)", icon: "pawprint", colorHex: "C8FF00", petId: pet.id, actionType: "action\(index)")
        }
        let humanItem = QuickActionItem(label: "体重", icon: "scalemass", colorHex: "80FFEA", petId: pet.id, actionType: "humanWeight", entityId: UUID(), entityKind: .human)
        let otherPetItem = QuickActionItem(label: "喂食", icon: "fork.knife", colorHex: "FFDD44", petId: otherPet.id, actionType: "feed")

        #expect(QuickActionLimit.maxItemsPerEntity == 8)
        #expect(QuickActionLimit.count(for: pet, in: petItems + [humanItem, otherPetItem]) == 8)
        #expect(QuickActionLimit.count(for: otherPet, in: petItems + [otherPetItem]) == 1)
    }

    @MainActor
    @Test func waterQuickActionsFoldLegacyWaterButtons() async throws {
        let fish = Pet(name: "Bubbles", species: "金鱼")
        let legacyItems = [
            QuickActionItem(label: "喂食", icon: "fork.knife", colorHex: "FFDD44", petId: fish.id, actionType: "feed"),
            QuickActionItem(label: "换水", icon: "drop.circle.fill", colorHex: "4ECDC4", petId: fish.id, actionType: "waterChange"),
            QuickActionItem(label: "清滤芯", icon: "sparkles", colorHex: "A78BFA", petId: fish.id, actionType: "filterClean")
        ]

        let normalized = WaterQuickActionPolicy.normalizedItems(
            legacyItems,
            for: fish,
            waterLabel: "喂水",
            managementLabel: "水管理"
        )

        #expect(normalized.contains { $0.actionType == "water" })
        #expect(!normalized.contains { $0.actionType == "waterChange" })
        #expect(!normalized.contains { $0.actionType == "filterClean" })

        let waterItem = try #require(normalized.first { $0.actionType == "water" })
        #expect(WaterQuickActionPolicy.titleOverride(for: waterItem, pet: fish, managementLabel: "水管理") == "水管理")
        #expect(WaterQuickActionPolicy.iconOverride(for: waterItem, pet: fish) == "water.waves")
    }

    @MainActor
    @Test func quickActionPickerDoesNotOfferIndependentWaterMaintenance() async throws {
        let cat = Pet(name: "Momo", species: "猫")

        let options = QuickActionPickerCatalog.available(for: cat, existingActionTypes: [])

        #expect(options.contains { $0.id == "water" })
        #expect(!options.contains { $0.id == "waterChange" })
        #expect(!options.contains { $0.id == "filterClean" })
    }

    @MainActor
    @Test func defaultCarePlansDoNotCreateDailyPlayPlan() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let startDate = dateForTest(year: 2026, month: 5, day: 10)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let legacyDefaultPlay = Event(
            title: "Momo 陪玩",
            startDate: startDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        legacyDefaultPlay.recurrenceDays = 1
        context.insert(legacyDefaultPlay)
        try context.save()

        let petKey = pet.id.uuidString
        defer { clearCareCalendarDefaults(petKey: petKey, kinds: ["play"]) }

        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: startDate)

        let events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(!events.contains { $0.title == "Momo 陪玩" })
        #expect(!events.contains { $0.title == "Momo 互动" })
        #expect(!events.contains { $0.title == "Momo 放飞互动" })
    }

    @MainActor
    @Test func explicitPlayPlanCanBeAddedFromPlaySettings() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let startDate = dateForTest(year: 2026, month: 5, day: 10)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let petKey = pet.id.uuidString
        defer {
            clearCareCalendarDefaults(petKey: petKey, kinds: ["play"])
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_play_\(petKey)")
        }

        CarePlanCalendarSync.syncPlayPlan(
            pet: pet,
            context: context,
            intervalDays: 3,
            enabled: true,
            anchor: startDate
        )

        let events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        let plan = try #require(events.first { $0.title == "Momo 陪玩计划" })
        #expect(plan.recurrenceDays == 3)
        #expect(plan.reminders.count == 1)
    }

    @MainActor
    @Test func waterPlanWriterCreatesDailyPlanAndSuppressesDefaultDrinkPlan() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 10, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        let defaultDrink = Event(
            title: "Momo 补充饮水",
            startDate: now,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(defaultDrink)
        try context.save()

        let petKey = pet.id.uuidString
        defer { clearCareCalendarDefaults(petKey: petKey, kinds: ["drink"]) }

        let reminders = WaterPlanWriter.replacePlan(
            pet: pet,
            times: WaterPlanWriter.suggestedTimes(count: 3, now: now, calendar: calendar),
            allEvents: [defaultDrink],
            context: context,
            now: now,
            calendar: calendar
        )

        let events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(events.count(where: { $0.relatedEntityType == WaterPlanWriter.entityType }) == 3)
        #expect(!events.contains { $0.title == "Momo 补充饮水" })
        #expect(reminders.count >= 3)
        #expect(events.filter { $0.relatedEntityType == WaterPlanWriter.entityType }.allSatisfy { $0.recurrenceDays == 1 && $0.eventType == EventType.daily.rawValue })
    }

    @MainActor
    @Test func waterPlanWriterDeletesPlanForManualMode() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 10, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        _ = WaterPlanWriter.replacePlan(
            pet: pet,
            times: WaterPlanWriter.suggestedTimes(count: 2, now: now),
            allEvents: [],
            context: context,
            now: now
        )
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.contains { $0.relatedEntityType == WaterPlanWriter.entityType })

        WaterPlanWriter.deletePlan(pet: pet, allEvents: events, context: context)
        events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(!events.contains { $0.relatedEntityType == WaterPlanWriter.entityType })
        #expect(reminders.isEmpty)
    }

    @MainActor
    @Test func waterPlanManualModeKeepsPlanButHidesCalendarAndCancelsFutureReminders() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 10, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        _ = WaterPlanWriter.replacePlan(
            pet: pet,
            times: WaterPlanWriter.suggestedTimes(count: 2, now: now, calendar: calendar),
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(WaterPlanWriter.planEvents(pet: pet, allEvents: events).count == 2)
        var reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(reminders.contains { $0.scheduledAt > now && $0.isPending })

        WaterOperatingMode.set(pet.id, mode: .manual)
        WaterPlanWriter.deactivateReminderOperations(pet: pet, allEvents: events, context: context, now: now)
        events = try context.fetch(FetchDescriptor<Event>())
        reminders = try context.fetch(FetchDescriptor<Reminder>())
        let planEvent = try #require(WaterPlanWriter.planEvents(pet: pet, allEvents: events).first)

        #expect(WaterPlanWriter.planEvents(pet: pet, allEvents: events).count == 2)
        #expect(!reminders.contains { $0.scheduledAt > now && $0.isPending })
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(planEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))

        WaterOperatingMode.set(pet.id, mode: .reminder)
        #expect(CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(planEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))
    }

    @MainActor
    @Test func completePlannedWaterWritesWaterLogAndCompletesReminder() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 喂水",
            startDate: Date().addingTimeInterval(-60),
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        _ = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: 180,
            context: context,
            executorId: "human-1"
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let log = try #require(logs.first)
        #expect(log.careType == .watering)
        #expect(log.amountMl == 180)
        #expect(log.note.hasPrefix(PetCareLog.plannedWaterNotePrefix))
        #expect(log.executorId == "human-1")
        #expect(reminder.statusEnum == .completed)
        #expect(reminder.completedBy == "human-1")
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
    }

    @MainActor
    @Test func quickCareCompletionCanCatchUpOlderPetPlanReminder() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 11)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 陪玩计划",
            startDate: dateForTest(year: 2026, month: 5, day: 7, hour: 9),
            isAllDay: true,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let completed = QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
            pet: pet,
            type: .play,
            context: context,
            executorId: "human-1",
            now: now
        )

        #expect(completed?.id == reminder.id)
        #expect(reminder.statusEnum == .completed)
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
    }

    @MainActor
    @Test func filterPlanSyncDeduplicatesCleanAndReplaceEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Bubbles", species: "金鱼")
        context.insert(pet)
        context.insert(PetCareLog(date: Date().addingTimeInterval(-5 * 86400), type: .filterClean, pet: pet))
        try context.save()

        let petKey = pet.id.uuidString
        defer {
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_filterClean_\(petKey)")
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_filterReplace_\(petKey)")
        }

        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: 14,
            replaceIntervalDays: 90,
            enabled: true
        )
        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: 7,
            replaceIntervalDays: 60,
            enabled: true
        )

        let events = try context.fetch(FetchDescriptor<Event>())
            .filter { $0.relatedEntityId == petKey && $0.title.contains("滤芯") }
        let reminders = try context.fetch(FetchDescriptor<Reminder>())

        #expect(events.count == 2)
        #expect(reminders.count == 2)
        #expect(events.contains { $0.title.contains("清洗滤芯") && $0.recurrenceDays == 7 })
        #expect(events.contains { $0.title.contains("更换滤芯") && $0.recurrenceDays == 60 })

        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: 7,
            replaceIntervalDays: 60,
            enabled: false
        )

        let remaining = try context.fetch(FetchDescriptor<Event>())
            .filter { $0.relatedEntityId == petKey && $0.title.contains("滤芯") }
        #expect(remaining.isEmpty)
    }

    @MainActor
    @Test func customScoopPlanSuppressesDefaultDailyLitterPlan() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let startDate = dateForTest(year: 2026, month: 5, day: 10)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let petKey = pet.id.uuidString
        defer {
            clearCareCalendarDefaults(petKey: petKey, kinds: ["litter"])
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_scoop_\(petKey)")
        }

        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: startDate)
        var events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(events.contains { $0.title == "Momo 铲屎" && $0.recurrenceDays == 1 })

        CarePlanCalendarSync.syncScoopPlan(
            pet: pet,
            context: context,
            intervalDays: 4,
            enabled: true,
            anchor: startDate
        )
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: startDate)

        events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(!events.contains { $0.title == "Momo 铲屎" })
        let scoop = try #require(events.first { $0.title == "Momo 铲屎计划" })
        #expect(scoop.recurrenceDays == 4)
    }

    @MainActor
    @Test func customWaterAndFilterPlansSuppressDefaultAquaticPlans() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let startDate = dateForTest(year: 2026, month: 5, day: 10)
        let pet = Pet(name: "Bubbles", species: "金鱼")
        context.insert(pet)
        try context.save()

        let petKey = pet.id.uuidString
        defer {
            clearCareCalendarDefaults(petKey: petKey, kinds: ["waterChange", "filter"])
            for kind in ["waterChange", "filterClean", "filterReplace"] {
                UserDefaults.standard.removeObject(forKey: "careCalendarEventId_\(kind)_\(petKey)")
            }
        }

        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: startDate)
        var events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(events.contains { $0.title == "Bubbles 换水" })
        #expect(events.contains { $0.title == "Bubbles 过滤检查" })

        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: 10,
            enabled: true,
            cycleAnchor: startDate
        )
        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: 21,
            replaceIntervalDays: 90,
            enabled: true
        )
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: startDate)

        events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(events.count(where: { $0.title == "Bubbles 换水" }) == 1)
        #expect(events.first { $0.title == "Bubbles 换水" }?.recurrenceDays == 10)
        #expect(!events.contains { $0.title == "Bubbles 过滤检查" })
        #expect(events.contains { $0.title == "Bubbles 清洗滤芯" && $0.recurrenceDays == 21 })
        #expect(events.contains { $0.title == "Bubbles 更换滤芯" && $0.recurrenceDays == 90 })
    }

    @MainActor
    @Test func customFeedPlanSuppressesDefaultDailyFeedPlan() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 10, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let petKey = pet.id.uuidString
        defer {
            clearCareCalendarDefaults(petKey: petKey, kinds: ["feed"])
        }

        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: now)
        var events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(events.contains { $0.title == "Momo 喂食" && $0.feedRuleKindRaw.isEmpty })

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            dailyCount: 2,
            gramsPerMeal: 50,
            times: FeedPlanDraft.suggestedTimes(for: 2, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(
            pet: pet,
            draft: draft,
            allEvents: events,
            context: context,
            now: now,
            calendar: calendar
        )
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context, startDate: now)

        events = try context.fetch(FetchDescriptor<Event>()).filter { $0.relatedEntityId == petKey }
        #expect(!events.contains { $0.title == "Momo 喂食" && $0.feedRuleKindRaw.isEmpty })
        #expect(events.count(where: { $0.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue }) == 2)
    }

    @MainActor
    @Test func petFoodStockUsesActualFeedAmountsAfterRestock() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let restock = Date().addingTimeInterval(-86400)
        pet.foodTrackingMode = .precise
        pet.restockDate = restock
        pet.restockWeight = 1
        pet.dailyPortionGrams = 50
        context.insert(pet)
        context.insert(PetCareLog(date: restock.addingTimeInterval(-60), type: .feeding, amountGrams: 500, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(60), type: .feeding, amountGrams: 120, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(120), type: .feeding, amountGrams: 0, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(180), type: .feeding, amountGrams: 10, note: FeedLogMetadata.treatFeedNoteMarker, pet: pet))
        try context.save()

        #expect(pet.foodConsumedSinceRestock == 170)
        #expect(pet.remainingFoodGrams == 830)
        #expect(pet.remainingFoodDays == 4)
    }

    @MainActor
    @Test func foodStockManualPlanModeUsesActualCheckInsOnly() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let openDate = dateForTest(year: 2026, month: 5, day: 1, hour: 8)
        let now = dateForTest(year: 2026, month: 5, day: 2, hour: 12)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 100
        context.insert(pet)

        let record = FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Manual Stock",
            totalGrams: 1000,
            purchaseDate: openDate,
            openDate: openDate,
            dailyGrams: nil,
            foodKind: .dry,
            calculationMode: .manualOrPlan,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 2, hour: 8), type: .feeding, amountGrams: 100, pet: pet))
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 2, hour: 9), type: .feeding, amountGrams: 40, note: FeedLogMetadata.autoNote(eventId: UUID(), scheduledAt: now), pet: pet))
        try context.save()

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let snapshot = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, careLogs: logs, now: now, calendar: calendar)

        #expect(FeedStockRecordMetadata.calculationMode(for: record) == .manualOrPlan)
        #expect(snapshot.consumedGrams == 100)
        #expect(snapshot.remainingGrams == 900)
    }

    @MainActor
    @Test func foodStockAutoModeDeductsAutoLogsAndStopsWhenAutoModeCloses() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let openDate = dateForTest(year: 2026, month: 5, day: 1, hour: 7)
        let firstNow = dateForTest(year: 2026, month: 5, day: 1, hour: 10)
        let secondNow = dateForTest(year: 2026, month: 5, day: 2, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 100
        context.insert(pet)

        let autoEvent = Event(
            title: "自动喂食器 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 1, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        autoEvent.recurrenceDays = 1
        autoEvent.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        autoEvent.foodKindRaw = FeedFoodKind.dry.rawValue
        autoEvent.feedAmountGrams = 50
        context.insert(autoEvent)

        let record = FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Auto Stock",
            totalGrams: 1000,
            purchaseDate: openDate,
            openDate: openDate,
            dailyGrams: nil,
            foodKind: .dry,
            calculationMode: .autoFeeder,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [autoEvent],
            context: context,
            now: firstNow,
            calendar: calendar
        )
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 1, hour: 9), type: .feeding, amountGrams: 100, pet: pet))
        try context.save()

        FeedOperatingMode.set(pet.id, mode: .autoFeeder)
        let inserted = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [autoEvent], context: context, now: firstNow, calendar: calendar)
        var logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let autoSnapshot = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, events: [autoEvent], careLogs: logs, now: firstNow, calendar: calendar)

        #expect(FeedStockRecordMetadata.calculationMode(for: record) == .autoFeeder)
        #expect(inserted == 1)
        #expect(autoSnapshot.consumedGrams == 50)
        #expect(autoSnapshot.remainingGrams == 950)

        FeedOperatingMode.set(pet.id, mode: .manual)
        let insertedAfterManual = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [autoEvent], context: context, now: secondNow, calendar: calendar)
        logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let stoppedSnapshot = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, events: [autoEvent], careLogs: logs, now: secondNow, calendar: calendar)

        #expect(insertedAfterManual == 0)
        #expect(logs.count(where: { FeedLogMetadata.source(for: $0) == .autoMain }) == 1)
        #expect(stoppedSnapshot.consumedGrams == 50)
        #expect(stoppedSnapshot.remainingGrams == 950)
    }

    @MainActor
    @Test func feedStockCalculatorUsesRecentMainFoodAverageBeforeFallbacks() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let restock = dateForTest(year: 2026, month: 5, day: 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        pet.restockDate = restock
        pet.restockWeight = 2
        pet.dailyPortionGrams = 60
        context.insert(pet)
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 7, hour: 8), type: .feeding, amountGrams: 100, pet: pet))
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 8, hour: 8), type: .feeding, amountGrams: 50, pet: pet))
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 8, hour: 9), type: .feeding, amountGrams: 10, note: FeedLogMetadata.treatFeedNoteMarker, pet: pet))
        let auto = Event(
            title: "自动喂食器 40g",
            startDate: now,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(auto)
        try context.save()

        let snapshot = FeedStockCalculator.snapshot(for: pet, events: [auto], now: now, calendar: calendar)

        #expect(snapshot.consumedGrams == 150)
        #expect(snapshot.remainingGrams == 1850)
        #expect(snapshot.estimatedDailyBasis == .recentAverage)
        #expect(abs(snapshot.estimatedDailyGrams - 75) < 0.001)
    }

    @MainActor
    @Test func feedStockCalculatorFallsBackToAutoRulesThenDefaultPortion() async throws {
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let pet = Pet(name: "Momo", species: "猫")
        pet.restockDate = dateForTest(year: 2026, month: 5, day: 8)
        pet.restockWeight = 2
        pet.dailyPortionGrams = 60
        let auto = Event(
            title: "自动喂食器 40g",
            startDate: now,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )

        let autoEstimate = FeedStockCalculator.snapshot(for: pet, events: [auto], now: now)
        let defaultEstimate = FeedStockCalculator.snapshot(for: pet, events: [], now: now)

        #expect(autoEstimate.estimatedDailyBasis == .autoRules)
        #expect(autoEstimate.estimatedDailyGrams == 40)
        #expect(defaultEstimate.estimatedDailyBasis == .defaultPortion)
        #expect(defaultEstimate.estimatedDailyGrams == 60)
    }

    @MainActor
    @Test func autoFeederMaterializesDueLogsIdempotently() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 21)
        let pet = Pet(name: "Momo", species: "猫")
        let auto = Event(
            title: "自动喂食器 湿粮",
            startDate: dateForTest(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        auto.recurrenceDays = 1
        auto.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        auto.foodKindRaw = FeedFoodKind.wet.rawValue
        auto.feedAmountGrams = 35
        context.insert(pet)
        context.insert(auto)
        try context.save()

        let first = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [auto], context: context, now: now, calendar: calendar)
        let second = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [auto], context: context, now: now, calendar: calendar)
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(first == 2)
        #expect(second == 0)
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.isAutoFeedLogEntry && $0.amountGrams == 35 && $0.foodKind == .wet })
    }

    @MainActor
    @Test func autoFeederLogsDeductMatchingFoodKindStock() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 21)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Wet Test",
            totalGrams: 600,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 7, hour: 0),
            dailyGrams: nil,
            foodKind: .wet,
            calculationMode: .autoFeeder,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )

        let auto = Event(
            title: "自动喂食器 湿粮",
            startDate: dateForTest(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        auto.recurrenceDays = 1
        auto.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        auto.foodKindRaw = FeedFoodKind.wet.rawValue
        auto.feedAmountGrams = 35
        context.insert(auto)
        try context.save()

        _ = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [auto], context: context, now: now, calendar: calendar)
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let records = try context.fetch(FetchDescriptor<PetFoodRecord>())
        let wet = FeedStockCalculator.snapshot(for: pet, foodKind: .wet, careLogs: logs, foodRecords: records, now: now, calendar: calendar)

        #expect(wet.totalGrams == 600)
        #expect(wet.consumedGrams == 70)
        #expect(wet.remainingGrams == 530)
    }

    @MainActor
    @Test func feedingPlanWriterKeepsManualAndAutoPlansWhileCalendarShowsActiveMode() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: [], context: context, now: now, calendar: calendar)
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count(where: { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }) == 1)

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 9), foodKind: .wet, grams: 80),
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 19), foodKind: .dry, grams: 35)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: events, context: context, now: now, calendar: calendar)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count(where: { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }) == 1)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }) == 2)

        let manualEvent = try #require(events.first { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) })
        let autoEvent = try #require(events.first { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) })

        FeedOperatingMode.set(pet.id, mode: .manualReminder)
        #expect(CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(manualEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(autoEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))

        FeedOperatingMode.set(pet.id, mode: .autoFeeder)
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(manualEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))
        #expect(CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(autoEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))

        FeedOperatingMode.set(pet.id, mode: .manual)
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(manualEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(autoEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))
        #expect(FeedMaintenanceCommand.ensureUpcomingPlanReminders(pet: pet, allEvents: events, context: context, now: now, calendar: calendar).isEmpty)
        events = try context.fetch(FetchDescriptor<Event>())
        let remainingFeedReminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(!remainingFeedReminders.contains { $0.scheduledAt > now && $0.isPending })

        let autoAgainDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 7), foodKind: .dry, grams: 50)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoAgainDraft, allEvents: events, context: context, now: now, calendar: calendar)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }) == 2)
        #expect(events.count(where: { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }) == 1)
    }

    @MainActor
    @Test func autoFeederCalendarHidesPastOccurrencesInsteadOfShowingOverdue() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: [], context: context, now: now, calendar: calendar)
        let events = try context.fetch(FetchDescriptor<Event>())
        let autoEvent = try #require(events.first { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) })

        FeedOperatingMode.set(pet.id, mode: .autoFeeder)
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(autoEvent, occurrenceDate: now, allEvents: events, pets: [pet], now: now, calendar: calendar))

        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(autoEvent, occurrenceDate: tomorrow, allEvents: events, pets: [pet], now: now, calendar: calendar))
    }

    @MainActor
    @Test func feedOverdueAndCalendarVisibilityFollowActiveOperatingMode() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let setupNow = dateForTest(year: 2026, month: 5, day: 8, hour: 7)
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let scheduledAt = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: scheduledAt, foodKind: .dry, grams: 45)
            ],
            now: setupNow,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: [], context: context, now: setupNow, calendar: calendar)
        let events = try context.fetch(FetchDescriptor<Event>())
        let manualEvent = try #require(events.first { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) })

        FeedOperatingMode.set(pet.id, mode: .manual)
        #expect(CarePlanOverdueStatusCalculator.warning(for: "feed", pet: pet, events: events, now: now, calendar: calendar) == nil)
        #expect(!CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(manualEvent, occurrenceDate: scheduledAt, allEvents: events, pets: [pet], now: now, calendar: calendar))

        FeedOperatingMode.set(pet.id, mode: .manualReminder)
        let warning = try #require(CarePlanOverdueStatusCalculator.warning(for: "feed", pet: pet, events: events, now: now, calendar: calendar))
        #expect(warning.actionType == "feed")
        #expect(warning.scheduledAt == scheduledAt)
        #expect(CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(manualEvent, occurrenceDate: scheduledAt, allEvents: events, pets: [pet], now: now, calendar: calendar))
    }

    @MainActor
    @Test func expiredFeedPlanMissDoesNotLeakIntoGlobalOverdueWarning() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let setupNow = dateForTest(year: 2026, month: 5, day: 8, hour: 7)
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 15)
        let scheduledAt = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: scheduledAt, foodKind: .dry, grams: 45)
            ],
            now: setupNow,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: [], context: context, now: setupNow, calendar: calendar)
        let events = try context.fetch(FetchDescriptor<Event>())

        FeedOperatingMode.set(pet.id, mode: .manualReminder)
        #expect(CarePlanOverdueStatusCalculator.warning(for: "feed", pet: pet, events: events, now: now, calendar: calendar) == nil)

        let dashboard = FeedingDashboardState(pet: pet, allEvents: events, now: now, calendar: calendar)
        #expect(!dashboard.hasMissedManualPlan)
        #expect(dashboard.lastExpiredManualPlanDate == scheduledAt)
    }

    @MainActor
    @Test func feedStockEstimateUsesOnlyActiveOperatingModePlan() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 50)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: [], context: context, now: now, calendar: calendar)
        var events = try context.fetch(FetchDescriptor<Event>())

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 9), foodKind: .dry, grams: 80),
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 18), foodKind: .dry, grams: 40)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: events, context: context, now: now, calendar: calendar)
        events = try context.fetch(FetchDescriptor<Event>())

        FeedOperatingMode.set(pet.id, mode: .manualReminder)
        let manualPlanEstimate = FeedStockCalculator.estimatedDailyMainFoodGrams(for: pet, events: events, now: now, calendar: calendar)
        #expect(manualPlanEstimate.0 == 120)

        FeedOperatingMode.set(pet.id, mode: .autoFeeder)
        let autoPlanEstimate = FeedStockCalculator.estimatedDailyMainFoodGrams(for: pet, events: events, now: now, calendar: calendar)
        #expect(autoPlanEstimate.0 == 50)

        FeedOperatingMode.set(pet.id, mode: .manual)
        let manualEstimate = FeedStockCalculator.estimatedDailyMainFoodGrams(for: pet, events: events, now: now, calendar: calendar)
        #expect(manualEstimate.0 == 80)
    }

    @MainActor
    @Test func switchingFeedModeAwayFromAutoDeletesAutoFeederEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: [], context: context, now: now, calendar: calendar)
        var events = try context.fetch(FetchDescriptor<Event>())
        FeedOperatingMode.set(pet.id, mode: .autoFeeder)

        SwitchFeedModeCommand.switchToManual(pet: pet, allEvents: events, context: context)

        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }.isEmpty)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar) == .manual)
    }

    @MainActor
    @Test func switchingFeedModeFromAutoToManualPlanDeletesAutoFeederEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: [], context: context, now: now, calendar: calendar)
        var events = try context.fetch(FetchDescriptor<Event>())

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 9), foodKind: .wet, grams: 80)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: events, context: context, now: now, calendar: calendar)
        events = try context.fetch(FetchDescriptor<Event>())
        FeedOperatingMode.set(pet.id, mode: .autoFeeder)

        let result = SwitchFeedModeCommand.activateExistingRule(pet: pet, kind: .manualReminder, allEvents: events, context: context)

        events = try context.fetch(FetchDescriptor<Event>())
        if case .missingPlan = result {
            Issue.record("Expected an existing manual plan to activate")
        }
        #expect(events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }.isEmpty)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }) == 1)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar) == .manualReminder)
    }

    @MainActor
    @Test func savingManualFeedPlanFromAutoDeletesAutoFeederEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45)
            ],
            now: now,
            calendar: calendar
        )
        _ = SaveFeedPlanCommand.run(pet: pet, targets: [], kind: .autoFeeder, draft: autoDraft, allEvents: [], context: context)
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count(where: { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }) == 1)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar) == .autoFeeder)

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 9), foodKind: .wet, grams: 80)
            ],
            now: now,
            calendar: calendar
        )
        _ = SaveFeedPlanCommand.run(pet: pet, targets: [], kind: .manualReminder, draft: manualDraft, allEvents: events, context: context)

        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }.isEmpty)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }) == 1)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: events, now: now, calendar: calendar) == .manualReminder)
    }

    @MainActor
    @Test func feedingPlanWriterClearsPlansForManualMode() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 40)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: [], context: context, now: now, calendar: calendar)
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar).operatingMode == .manualReminder)

        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 12), foodKind: .wet, grams: 70)
            ],
            now: now,
            calendar: calendar
        )
        _ = FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: events, context: context, now: now, calendar: calendar)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar).operatingMode == .autoFeeder)

        FeedingPlanWriter.clearFeedModePlans(pet: pet, allEvents: events, context: context)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar).operatingMode == .manual)
        #expect(events.filter { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }.isEmpty)
        #expect(events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }.isEmpty)
    }

    @MainActor
    @Test func legacyPlannedFeedEventsStayManualReminders() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐 45g",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        let state = FeedRuleState(pet: pet, allEvents: [event])

        #expect(state.manualReminderEvents.count == 1)
        #expect(state.autoFeederEvents.isEmpty)
    }

    @MainActor
    @Test func feedingPlanWriterCreatesDailyManualPlanWithUpcomingReminders() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            dailyCount: 3,
            gramsPerMeal: 50,
            times: FeedPlanDraft.suggestedTimes(for: 3, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        let result = FeedingPlanWriter.replacePlan(
            pet: pet,
            draft: draft,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())

        #expect(result.events.count == 3)
        #expect(events.count == 3)
        #expect(events.allSatisfy { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) })
        #expect(events.allSatisfy { $0.recurrenceDays == 1 })
        #expect(events.allSatisfy { FeedRuleMetadata.amountGrams(from: $0) == 50 })
        #expect(reminders.count(where: { calendar.isDate($0.scheduledAt, inSameDayAs: now) }) == 3)
        #expect(result.reminders.count >= 3)
    }

    @MainActor
    @Test func feedingTodayStateFlagsMissedPlanMeals() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let missedEvent = Event(
            title: "早餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        missedEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        missedEvent.feedAmountGrams = 50
        let futureEvent = Event(
            title: "午餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 12),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        futureEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        futureEvent.feedAmountGrams = 50
        context.insert(missedEvent)
        context.insert(futureEvent)
        context.insert(Reminder(event: missedEvent, scheduledAt: missedEvent.startDate))
        context.insert(Reminder(event: futureEvent, scheduledAt: futureEvent.startDate))
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        let state = FeedTodayState(pet: pet, allEvents: events, manualGoalCount: 1, now: now, calendar: calendar)
        let dashboard = FeedingDashboardState(pet: pet, allEvents: events, now: now, calendar: calendar)

        #expect(state.hasOverduePlan)
        #expect(state.missedTodayPlanReminders.count == 1)
        #expect(dashboard.hasMissedManualPlan)
        #expect(dashboard.todayManualPlanMissedCount == 1)
        #expect(dashboard.todayManualPlanCompletionText == "0/2")
    }

    @MainActor
    @Test func plannedFeedCompletionIsPerReminderOccurrence() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 13)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let event = Event(
            title: "早餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        event.feedAmountGrams = 50
        let completedReminder = Reminder(event: event, scheduledAt: event.startDate)
        completedReminder.statusEnum = .completed
        completedReminder.completedAt = dateForTest(year: 2026, month: 5, day: 8, hour: 8, minute: 5)
        let pendingReminder = Reminder(event: event, scheduledAt: dateForTest(year: 2026, month: 5, day: 8, hour: 12))
        let log = PetCareLog(
            date: now,
            type: .feeding,
            amountGrams: 50,
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
            foodKind: .dry,
            pet: pet
        )
        context.insert(event)
        context.insert(completedReminder)
        context.insert(pendingReminder)
        context.insert(log)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let dashboard = FeedingDashboardState(pet: pet, allEvents: events, careLogs: logs, now: now, calendar: calendar)

        #expect(dashboard.todayManualPlanCompletedCount == 1)
        #expect(dashboard.todayManualPlanMissedCount == 1)
        #expect(dashboard.todayManualPlanCompletionText == "1/2")
        #expect(dashboard.nextManualReminder?.id == pendingReminder.id)
    }

    @MainActor
    @Test func feedingPlanCatchUpPrioritizesRecentMissedReminder() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let missedEvent = Event(
            title: "今天早餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        missedEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        missedEvent.feedAmountGrams = 50
        let todayEvent = Event(
            title: "今天午餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 12),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        todayEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        todayEvent.feedAmountGrams = 50
        let missedReminder = Reminder(event: missedEvent, scheduledAt: missedEvent.startDate)
        let todayReminder = Reminder(event: todayEvent, scheduledAt: todayEvent.startDate)
        context.insert(missedEvent)
        context.insert(todayEvent)
        context.insert(missedReminder)
        context.insert(todayReminder)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        let dashboard = FeedingDashboardState(pet: pet, allEvents: events, now: now, calendar: calendar)
        let homeSnapshot = FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: events,
            careLogs: [],
            foodRecords: [],
            now: now,
            todayLabel: "今天",
            calendar: calendar
        ))
        let overviewSnapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: dashboard.manualPlanEvents,
            careLogs: [],
            range: .days7,
            activeMode: .manualReminder,
            now: now,
            calendar: calendar
        )

        #expect(dashboard.hasMissedManualPlan)
        #expect(dashboard.nextManualReminder?.id == missedReminder.id)
        #expect(homeSnapshot.hasMissedManualPlan)
        #expect(homeSnapshot.hasNextManualReminder)
        #expect(overviewSnapshot.nextPendingManualReminder?.id == missedReminder.id)
    }

    @MainActor
    @Test func feedingPlanExpiredMissBlocksQuickCatchUpAndExposesLastOverdueTime() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 16)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let missedEvent = Event(
            title: "早餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        missedEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        missedEvent.feedAmountGrams = 50
        let futureEvent = Event(
            title: "晚餐 干粮 50g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 18),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        futureEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        futureEvent.feedAmountGrams = 50
        let missedReminder = Reminder(event: missedEvent, scheduledAt: missedEvent.startDate)
        let futureReminder = Reminder(event: futureEvent, scheduledAt: futureEvent.startDate)
        context.insert(missedEvent)
        context.insert(futureEvent)
        context.insert(missedReminder)
        context.insert(futureReminder)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        let dashboard = FeedingDashboardState(pet: pet, allEvents: events, now: now, calendar: calendar)
        let homeSnapshot = FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: events,
            careLogs: [],
            foodRecords: [],
            now: now,
            todayLabel: "今天",
            calendar: calendar
        ))
        let overviewSnapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: dashboard.manualPlanEvents,
            careLogs: [],
            range: .days7,
            activeMode: .manualReminder,
            now: now,
            calendar: calendar
        )

        #expect(!dashboard.hasMissedManualPlan)
        #expect(dashboard.todayManualPlanMissedCount == 0)
        #expect(dashboard.lastExpiredManualPlanDate == missedReminder.scheduledAt)
        #expect(dashboard.nextManualReminder == nil)
        #expect(!homeSnapshot.hasMissedManualPlan)
        #expect(!homeSnapshot.hasNextManualReminder)
        #expect(homeSnapshot.lastExpiredManualPlanDate == missedReminder.scheduledAt)
        #expect(overviewSnapshot.nextPendingManualReminder == nil)
    }

    @MainActor
    @Test func feedingPlanWriterCreatesPerMealKindsAndAmounts() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 6)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 8), foodKind: .dry, grams: 45),
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 13), foodKind: .wet, grams: 80),
                FeedPlanMealDraft(time: dateForTest(year: 2026, month: 5, day: 8, hour: 19), foodKind: .dry, grams: 35)
            ],
            now: now,
            calendar: calendar
        )

        let result = FeedingPlanWriter.replacePlan(
            pet: pet,
            draft: draft,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        let events = try context.fetch(FetchDescriptor<Event>()).sorted { $0.startDate < $1.startDate }

        #expect(result.events.count == 3)
        #expect(events.map(\.foodKindRaw) == [FeedFoodKind.dry.rawValue, FeedFoodKind.wet.rawValue, FeedFoodKind.dry.rawValue])
        #expect(events.map(\.feedAmountGrams) == [45, 80, 35])
        #expect(events.allSatisfy { $0.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue })
        #expect(events.allSatisfy { FeedRuleMetadata.amountGrams(from: $0) == $0.feedAmountGrams })
    }

    @MainActor
    @Test func feedingPlanWriterPurchaseTracksMainFoodButNotTreats() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Test Food",
            totalGrams: 1000,
            purchaseDate: now,
            dailyGrams: 50,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: "human-1",
            allEvents: [],
            context: context,
            now: now
        )
        CareEventService.recordManualFeed(pet: pet, amountGrams: 120, context: context, executorId: "human-1", date: now.addingTimeInterval(60))
        CareEventService.recordTreatFeed(pet: pet, amountGrams: 20, context: context, executorId: "human-1", date: now.addingTimeInterval(120))

        let snapshot = FeedStockCalculator.snapshot(for: pet, now: now.addingTimeInterval(180))
        let records = try context.fetch(FetchDescriptor<PetFoodRecord>())

        #expect(records.count == 1)
        #expect(pet.foodTrackingMode == .precise)
        #expect(pet.restockWeight == 1)
        #expect(records.first?.totalGrams == 1000)
        #expect(records.first?.foodKind == .dry)
        #expect(snapshot.consumedGrams == 120)
        #expect(snapshot.remainingGrams == 880)
    }

    @MainActor
    @Test func feedStockSeparatesDryWetAndTreatsDoNotDeductStock() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Dry Test",
            totalGrams: 1000,
            purchaseDate: now,
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now
        )
        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Wet Test",
            totalGrams: 600,
            purchaseDate: now,
            dailyGrams: nil,
            foodKind: .wet,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now
        )
        CareEventService.recordManualFeed(pet: pet, amountGrams: 120, context: context, date: now.addingTimeInterval(60), foodKind: .dry)
        CareEventService.recordManualFeed(pet: pet, amountGrams: 80, context: context, date: now.addingTimeInterval(120), foodKind: .wet)
        CareEventService.recordTreatFeed(pet: pet, amountGrams: 25, context: context, date: now.addingTimeInterval(180), treatKind: .lickable)

        let dry = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: now.addingTimeInterval(240))
        let wet = FeedStockCalculator.snapshot(for: pet, foodKind: .wet, now: now.addingTimeInterval(240))

        #expect(dry.totalGrams == 1000)
        #expect(dry.consumedGrams == 120)
        #expect(dry.remainingGrams == 880)
        #expect(wet.totalGrams == 600)
        #expect(wet.consumedGrams == 80)
        #expect(wet.remainingGrams == 520)
    }

    @MainActor
    @Test func foodStockDeductsOnlyFromOpenDate() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Dry Test",
            totalGrams: 1000,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 1),
            openDate: dateForTest(year: 2026, month: 5, day: 5),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        CareEventService.recordManualFeed(pet: pet, amountGrams: 300, context: context, date: dateForTest(year: 2026, month: 5, day: 4, hour: 12), foodKind: .dry)
        CareEventService.recordManualFeed(pet: pet, amountGrams: 120, context: context, date: dateForTest(year: 2026, month: 5, day: 5, hour: 8), foodKind: .dry)

        let snapshot = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: now)
        let record = try #require(try context.fetch(FetchDescriptor<PetFoodRecord>()).first)

        #expect(record.purchaseDate == dateForTest(year: 2026, month: 5, day: 1))
        #expect(record.startDate == dateForTest(year: 2026, month: 5, day: 5))
        #expect(snapshot.consumedGrams == 120)
        #expect(snapshot.remainingGrams == 880)
    }

    @MainActor
    @Test func futureOpenStockDoesNotReplaceCurrentStock() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Current",
            totalGrams: 1000,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 1),
            openDate: dateForTest(year: 2026, month: 5, day: 1),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Future",
            totalGrams: 2000,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 2),
            openDate: dateForTest(year: 2026, month: 5, day: 10),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )

        let current = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: now)
        let future = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: dateForTest(year: 2026, month: 5, day: 10, hour: 12))

        #expect(current.totalGrams == 1000)
        #expect(current.remainingGrams == 1000)
        #expect(future.totalGrams == 2000)

        let futureOnlyPet = Pet(name: "Luna", species: "猫")
        context.insert(futureOnlyPet)
        FeedingPlanWriter.saveFoodPurchase(
            pet: futureOnlyPet,
            brand: "Future Only",
            totalGrams: 1500,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 2),
            openDate: dateForTest(year: 2026, month: 5, day: 10),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        let inactiveFutureOnly = FeedStockCalculator.snapshot(for: futureOnlyPet, foodKind: .dry, now: now)
        #expect(inactiveFutureOnly.totalGrams == 0)
    }

    @MainActor
    @Test func foodStockManualCorrectionBecomesNewRemainingBaseline() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let correctionTime = dateForTest(year: 2026, month: 5, day: 3, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Dry Test",
            totalGrams: 1000,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 1),
            openDate: dateForTest(year: 2026, month: 5, day: 1),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        let record = try #require(try context.fetch(FetchDescriptor<PetFoodRecord>()).first)
        CareEventService.recordManualFeed(pet: pet, amountGrams: 100, context: context, date: dateForTest(year: 2026, month: 5, day: 2, hour: 8), foodKind: .dry)
        CareEventService.recordManualFeed(pet: pet, amountGrams: 200, context: context, date: dateForTest(year: 2026, month: 5, day: 3, hour: 8), foodKind: .dry)
        FeedingPlanWriter.correctFoodStock(record: record, remainingGrams: 700, allEvents: [], context: context, now: correctionTime)
        CareEventService.recordManualFeed(pet: pet, amountGrams: 50, context: context, date: dateForTest(year: 2026, month: 5, day: 3, hour: 18), foodKind: .dry)

        let snapshot = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: now)

        #expect(record.remainingCorrectionGrams == 700)
        #expect(record.remainingCorrectionDate == correctionTime)
        #expect(snapshot.consumedGrams == 50)
        #expect(snapshot.remainingGrams == 650)
    }

    @MainActor
    @Test func deletingActiveFoodStockFallsBackToPreviousOpenedRecord() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Old",
            totalGrams: 1000,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 1),
            openDate: dateForTest(year: 2026, month: 5, day: 1),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Current",
            totalGrams: 800,
            purchaseDate: dateForTest(year: 2026, month: 5, day: 2),
            openDate: dateForTest(year: 2026, month: 5, day: 2),
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now,
            calendar: calendar
        )
        let active = try #require(FeedStockCalculator.activeStockRecord(for: pet, foodKind: .dry, now: now))
        #expect(active.brand == "Current")

        context.delete(active)
        try context.save()
        let fallback = FeedStockCalculator.snapshot(for: pet, foodKind: .dry, now: now)

        #expect(fallback.totalGrams == 1000)
    }

    @MainActor
    @Test func feedStockSnapshotUsesObservedQueryLogsForCurrentPetOnly() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 8)
        let momo = Pet(name: "Momo", species: "猫")
        let luna = Pet(name: "Luna", species: "猫")
        context.insert(momo)
        context.insert(luna)

        FeedingPlanWriter.saveFoodPurchase(
            pet: momo,
            brand: "Momo Dry",
            totalGrams: 1000,
            purchaseDate: now,
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now
        )
        FeedingPlanWriter.saveFoodPurchase(
            pet: luna,
            brand: "Luna Dry",
            totalGrams: 1000,
            purchaseDate: now,
            dailyGrams: nil,
            foodKind: .dry,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            now: now
        )
        CareEventService.recordManualFeed(pet: momo, amountGrams: 100, context: context, date: now.addingTimeInterval(60), foodKind: .dry)
        CareEventService.recordManualFeed(pet: luna, amountGrams: 300, context: context, date: now.addingTimeInterval(60), foodKind: .dry)

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let records = try context.fetch(FetchDescriptor<PetFoodRecord>())
        let snapshot = FeedStockCalculator.snapshot(
            for: momo,
            foodKind: .dry,
            careLogs: logs,
            foodRecords: records,
            now: now.addingTimeInterval(120)
        )

        #expect(snapshot.totalGrams == 1000)
        #expect(snapshot.consumedGrams == 100)
        #expect(snapshot.remainingGrams == 900)
    }

    @MainActor
    @Test func treatKindAndOptionalGramsArePreserved() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        let noGramTreat = CareEventService.recordTreatFeed(pet: pet, amountGrams: 0, context: context, date: now, treatKind: .dentalNeck)
        let gramTreat = CareEventService.recordTreatFeed(pet: pet, amountGrams: 14, context: context, date: now.addingTimeInterval(60), treatKind: .freezeDried)

        let state = FeedTodayState(pet: pet, allEvents: [], manualGoalCount: 1, now: now, calendar: calendar)

        #expect(noGramTreat.treatKind == .dentalNeck)
        #expect(gramTreat.treatKind == .freezeDried)
        #expect(state.treatTodayLogs.count == 2)
        #expect(state.todayTreatGrams == 14)
    }

    @Test func petFoodBrandCatalogReturnsCountryAndTypeSpecificBrands() async throws {
        let chinaDry = PetFoodBrandCatalog.brands(countryCode: "CN", foodKind: .dry)
        let chinaWet = PetFoodBrandCatalog.brands(countryCode: "CN", foodKind: .wet)
        let usDry = PetFoodBrandCatalog.brands(countryCode: "US", foodKind: .dry)

        #expect(chinaDry.contains("皇家"))
        #expect(chinaWet.contains("巅峰"))
        #expect(usDry.contains("Purina Pro Plan"))
        #expect(chinaDry != chinaWet)
    }

    @MainActor
    @Test func todayFocusServiceRefreshesAndPrioritizesContent() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let feedQuest = IslandQuest(id: "q_feed_\(pet.id.uuidString)", emoji: "🍖", title: "喂食", subtitle: "今天还没喂", isCompleted: false, targetPetId: pet.id, targetPlantId: nil)
        let feedLog = PetCareLog(type: .feeding, amountGrams: 20, pet: pet)

        let refreshed = TodayFocusService.refreshedQuests([feedQuest], careLogs: [feedLog], walkLogs: [], pottyLogs: [])
        #expect(refreshed.first?.isCompleted == true)
        #expect(refreshed.first?.emoji == "✅")

        func renderCards(
            quests: [IslandQuest] = [],
            pets: [TodayFocusPetSnapshot] = [],
            plants: [TodayFocusPlantSnapshot] = [],
            humans: [TodayFocusHumanSnapshot] = []
        ) -> [TodayFocusContent] {
            TodayFocusCard.TodayFocusRenderDeck.make(
                snapshot: TodayFocusSnapshot(
                    dayToken: TodayFocusSnapshot.dayToken(for: Date()),
                    pets: pets,
                    plants: plants,
                    humans: humans,
                    refreshedQuests: quests,
                    assignedFamilyTasks: [],
                    pendingExchangeRequests: [],
                    negativeSignals: []
                ),
                skippedFocusKeys: [],
                closedNegativeKeys: []
            ).cards
        }

        let pending = IslandQuest(id: "q_custom", emoji: "!", title: "待办", subtitle: "优先", isCompleted: false, targetPetId: nil, targetPlantId: nil)
        if case let .quest(selected) = renderCards(quests: [pending]).first {
            #expect(selected.id == "q_custom")
        } else {
            Issue.record("未完成委托应优先成为 Today Focus")
        }

        let done = IslandQuest(id: "q_done", emoji: "✅", title: "已完成", subtitle: "", isCompleted: true, targetPetId: nil, targetPlantId: nil)
        if case .celebrate = renderCards(quests: [done]).first {
        } else {
            Issue.record("全部完成后应进入庆祝态")
        }

        if case .welcome = renderCards().first {
        } else {
            Issue.record("没有任务和历史时应进入欢迎态")
        }

        if case .celebrate = renderCards(pets: [TodayFocusPetSnapshot(pet: pet)]).first {
        } else {
            Issue.record("有成员但没有任务时应显示恭喜提示")
        }
    }

    @MainActor
    @Test func todayFocusTreatsWalkAsPlayCompletion() async throws {
        let pet = Pet(name: "Momo", species: "狗")
        let playQuest = IslandQuest(
            id: "q_play_\(pet.id.uuidString)",
            emoji: "🎾",
            title: "陪 Momo 玩一会儿",
            subtitle: "",
            isCompleted: false,
            targetPetId: pet.id,
            targetPlantId: nil
        )
        let walkLog = PetWalkLog(pet: pet)

        let refreshed = TodayFocusService.refreshedQuests([playQuest], pets: [pet], careLogs: [], walkLogs: [walkLog], pottyLogs: [])

        #expect(refreshed.first?.isCompleted == true)
    }

    @MainActor
    @Test func islandNegativeFeedbackDoesNotWarnAfterTodayCareCheckIn() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.currentStreak = 0
        pet.lastCheckInDate = nil
        context.insert(pet)
        context.insert(PetCareLog(type: .watering, amountMl: 250, pet: pet))
        try context.save()

        let signals = IslandNegativeFeedback.signals(pets: [pet], healthAlerts: EmptyPetHealthAlerts())
        #expect(!signals.contains { $0.iconName == "cloud.fill" })
    }

    @MainActor
    @Test func islandQuestEngineDefaultsToLightweightNewPetTasks() async throws {
        let pet = Pet(name: "Momo", species: "猫")

        let quests = IslandQuestEngine.todayQuests(pets: [pet], reminders: [])
        let ids = quests.map(\.id)

        #expect(ids.contains("q_play_\(pet.id.uuidString)"))
        #expect(ids.contains("q_weight_\(pet.id.uuidString)"))
        #expect(ids.contains("q_moment_\(pet.id.uuidString)"))
        #expect(!ids.contains { $0.hasPrefix("q_feed_") })
        #expect(!ids.contains { $0.hasPrefix("q_water_") })
    }

    @MainActor
    @Test func islandQuestEnginePrioritizesFirstPetWhenNoActivePets() async throws {
        let human = Human(name: "Li")
        let completedIntroProgress = TodayFocusQuestProgress(
            isPetWizardCompleted: true,
            isFirstMealRecorded: true,
            isThemeColorSet: true
        )

        let quests = IslandQuestEngine.todayQuests(
            pets: [],
            reminders: [],
            humans: [human],
            questProgress: completedIntroProgress
        )

        #expect(quests.first?.id == IslandQuestEngine.oasisPetWizardQuestId)
        #expect(quests.first?.emoji == "🐾")
        #expect(quests.first?.isCompleted == false)

        let refreshed = TodayFocusService.refreshedQuests(
            quests,
            pets: [],
            humans: [human],
            careLogs: [],
            walkLogs: [],
            pottyLogs: [],
            questProgress: completedIntroProgress
        )

        #expect(refreshed.first?.id == IslandQuestEngine.oasisPetWizardQuestId)
        #expect(refreshed.first?.isCompleted == false)
    }

    @MainActor
    @Test func islandQuestEngineDoesNotCreatePlayTaskForEveryPetAfterInteraction() async throws {
        let momo = Pet(name: "Momo", species: "狗")
        let lilo = Pet(name: "Lilo", species: "猫")
        momo.walkLogs.append(PetWalkLog(pet: momo))

        let quests = IslandQuestEngine.todayQuests(pets: [momo, lilo], reminders: [])

        #expect(!quests.contains { $0.id.hasPrefix("q_play_") })
    }

    @MainActor
    @Test func islandQuestEngineUsesPerPetCarePlanIds() async throws {
        let momo = Pet(name: "Momo", species: "狗")
        let lilo = Pet(name: "Lilo", species: "狗")
        let momoWalk = Event(
            title: "遛狗",
            startDate: Date(),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: momo.id.uuidString
        )
        let liloWalk = Event(
            title: "遛狗",
            startDate: Date(),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: lilo.id.uuidString
        )

        let quests = IslandQuestEngine.todayQuests(pets: [momo, lilo], reminders: [], events: [momoWalk, liloWalk])
        let ids = quests.map(\.id)

        #expect(ids.contains { $0.hasPrefix("q_walk_\(momo.id.uuidString)_") && IslandQuestEngine.carePlanEventId(fromQuestId: $0) == momoWalk.id })
        #expect(ids.contains { $0.hasPrefix("q_walk_\(lilo.id.uuidString)_") && IslandQuestEngine.carePlanEventId(fromQuestId: $0) == liloWalk.id })
    }

    @MainActor
    @Test func islandQuestEngineUsesEventScopedCarePlanCompletion() async throws {
        let date = dateForTest(year: 2026, month: 6, day: 9, hour: 8)
        let pet = Pet(name: "Momo", species: "狗")
        let breakfast = Event(
            title: "喂食",
            startDate: date,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let dinner = Event(
            title: "喂食",
            startDate: dateForTest(year: 2026, month: 6, day: 9, hour: 18),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        let initial = IslandQuestEngine.todayQuests(
            pets: [pet],
            reminders: [],
            events: [breakfast, dinner],
            now: date
        )
        let feedIds = initial.map(\.id).filter { $0.hasPrefix("q_feed_\(pet.id.uuidString)_") }
        #expect(Set(feedIds.compactMap { IslandQuestEngine.carePlanEventId(fromQuestId: $0) }) == Set([breakfast.id, dinner.id]))

        breakfast.setOccurrenceMarkedComplete(true, on: date)
        let remaining = IslandQuestEngine.todayQuests(
            pets: [pet],
            reminders: [],
            events: [breakfast, dinner],
            now: date
        )
        let remainingEventIds = Set(remaining.map(\.id).compactMap { IslandQuestEngine.carePlanEventId(fromQuestId: $0) })

        #expect(!remainingEventIds.contains(breakfast.id))
        #expect(remainingEventIds.contains(dinner.id))
    }

    @MainActor
    @Test func islandQuestEngineIncludesRecurringCarePlanAfterStartDate() async throws {
        let start = dateForTest(year: 2026, month: 6, day: 1, hour: 8)
        let today = dateForTest(year: 2026, month: 6, day: 10, hour: 8)
        let pet = Pet(name: "Momo", species: "狗")
        let walk = Event(
            title: "遛狗",
            startDate: start,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        walk.recurrenceDays = 1

        let quests = IslandQuestEngine.todayQuests(
            pets: [pet],
            reminders: [],
            events: [walk],
            now: today
        )

        #expect(quests.contains { $0.id.hasPrefix("q_walk_\(pet.id.uuidString)_") })
    }

    @MainActor
    @Test func todayFocusCompletesEventScopedWalkFromWalkLog() async throws {
        let date = dateForTest(year: 2026, month: 6, day: 10, hour: 8)
        let pet = Pet(name: "Momo", species: "狗")
        let walk = Event(
            title: "遛狗",
            startDate: date,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let quest = IslandQuest(
            id: "q_walk_\(pet.id.uuidString)_\(walk.id.uuidString)",
            emoji: "🚶",
            title: "遛狗",
            subtitle: "",
            isCompleted: false,
            targetPetId: pet.id,
            targetPlantId: nil
        )
        let walkLog = PetWalkLog(startDate: date, pet: pet)

        let refreshed = TodayFocusService.refreshedQuests(
            [quest],
            pets: [pet],
            events: [walk],
            careLogs: [],
            walkLogs: [walkLog],
            pottyLogs: [],
            calendar: .current,
            now: date
        )

        #expect(refreshed.first?.isCompleted == true)
    }

    @MainActor
    @Test func todayFocusRenderDeckKeyChangesWhenRenderedCopyChanges() async throws {
        let questA = IslandQuest(
            id: "q_test",
            emoji: "✅",
            title: "Check Momo",
            subtitle: "First",
            isCompleted: false,
            targetPetId: nil,
            targetPlantId: nil
        )
        let questB = IslandQuest(
            id: "q_test",
            emoji: "✅",
            title: "Check Lilo",
            subtitle: "Second",
            isCompleted: false,
            targetPetId: nil,
            targetPlantId: nil
        )
        let snapshotA = TodayFocusSnapshot(
            dayToken: TodayFocusSnapshot.dayToken(for: Date()),
            pets: [],
            plants: [],
            humans: [],
            refreshedQuests: [questA],
            assignedFamilyTasks: [],
            pendingExchangeRequests: [],
            negativeSignals: []
        )
        let snapshotB = TodayFocusSnapshot(
            dayToken: TodayFocusSnapshot.dayToken(for: Date()),
            pets: [],
            plants: [],
            humans: [],
            refreshedQuests: [questB],
            assignedFamilyTasks: [],
            pendingExchangeRequests: [],
            negativeSignals: []
        )

        #expect(TodayFocusCard.snapshotDeckDependencyKey(snapshotA) != TodayFocusCard.snapshotDeckDependencyKey(snapshotB))
    }

    @MainActor
    @Test func homeSnapshotSignatureTracksRecurringOccurrenceCompletion() async throws {
        let date = dateForTest(year: 2026, month: 6, day: 10, hour: 8)
        let pet = Pet(name: "Momo", species: "狗")
        let walk = Event(
            title: "遛狗",
            startDate: date,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        walk.recurrenceDays = 1
        let source = VerticalSolidHomeSourceState(
            pets: [pet],
            humans: [],
            plants: [],
            electronicPets: [],
            events: [walk],
            pendingReminders: [],
            humanMedications: [],
            humanMedicationLogs: [],
            careLogs: [],
            walkLogs: [],
            pottyLogs: [],
            humanWeightLogs: [],
            familyTasks: [],
            exchangeRequests: [],
            activeHumanIdRaw: "",
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: 0,
            equippedTitleRaw: "",
            language: "en"
        )
        let before = VerticalSolidHomeSnapshotBuilder.signature(for: source, now: date)

        walk.setOccurrenceMarkedComplete(true, on: date)
        let after = VerticalSolidHomeSnapshotBuilder.signature(for: source, now: date)

        #expect(before != after)
    }

    @MainActor
    @Test func todayFocusNegativeSkipKeyTracksSignalRevisionAndPlantIdentity() async throws {
        let petId = UUID()
        let first = IslandNegativeSignal(
            iconName: "scalemass.fill",
            emoji: "⚖️",
            title: "Momo weight",
            detail: "warning",
            severity: .warning,
            petId: petId,
            healthAlertType: .weightLossAlert
        )
        let escalated = IslandNegativeSignal(
            iconName: "scalemass.fill",
            emoji: "⚖️",
            title: "Momo weight",
            detail: "critical",
            severity: .critical,
            petId: petId,
            healthAlertType: .weightLossAlert
        )

        #expect(TodayFocusCard.negativeSkipKey(for: first) != TodayFocusCard.negativeSkipKey(for: escalated))

        let plant = Plant(name: "Fern")
        plant.lastWateredDate = Date(timeIntervalSinceNow: -9 * 86400)
        let plantSignal = IslandNegativeFeedback.signals(pets: [], plants: [plant], clinicalAlerts: [])
            .first { $0.plantId == plant.id }

        #expect(plantSignal?.plantId == plant.id)
        #expect(plantSignal?.routeHint == .plant)
        #expect(plantSignal.map { TodayFocusCard.negativeSkipKey(for: $0).contains("plant:\(plant.id.uuidString)") } == true)
    }

    @MainActor
    @Test func todayFocusNegativeSignalCarriesRouteTargetForMissedCheckIn() async throws {
        let pet = Pet(name: "Momo", species: "狗")

        let signal = IslandNegativeFeedback.signals(pets: [pet], plants: [], clinicalAlerts: [])
            .first { $0.iconName == "cloud.fill" }

        #expect(signal?.petId == pet.id)
        #expect(signal?.routeHint == .petOverview)
    }

    @Test func humanMedicationScheduleMetadataRoundTripsAndHidesNotes() async throws {
        let metadata = HumanMedicationScheduleMetadata(doseMinutes: [20 * 60, 8 * 60, 8 * 60], weeklyWeekday: 5)
        let notes = HumanMedicationScheduleMetadata.composeNotes(visibleNotes: "饭后服用", metadata: metadata)
        let parsed = HumanMedicationScheduleMetadata.parse(from: notes)

        #expect(parsed?.doseMinutes == [8 * 60, 20 * 60])
        #expect(parsed?.weeklyWeekday == 5)
        #expect(HumanMedicationScheduleMetadata.visibleNotes(from: notes) == "饭后服用")
        #expect(!HumanMedicationScheduleMetadata.visibleNotes(from: notes).contains("ohana-human-medication-schedule"))
    }

    @Test func humanMedicationScheduleGeneratesFixedWeeklyAndManualDoses() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let thursday = dateForTest(year: 2026, month: 5, day: 7, hour: 10, minute: 0)

        let twice = HumanMedication(
            humanId: UUID().uuidString,
            name: "Vitamin",
            dosage: "1",
            frequency: .twiceDaily,
            startDate: thursday
        )
        twice.notes = HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: "",
            metadata: HumanMedicationScheduleMetadata(doseMinutes: [8 * 60, 20 * 60])
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: twice, calendar: calendar).count == 2)

        let weekly = HumanMedication(
            humanId: UUID().uuidString,
            name: "Weekly",
            dosage: "1",
            frequency: .weekly,
            startDate: thursday
        )
        weekly.notes = HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: "",
            metadata: HumanMedicationScheduleMetadata(doseMinutes: [9 * 60], weeklyWeekday: 5)
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: weekly, calendar: calendar).count == 1)
        #expect(HumanMedicationSchedulePlan.doses(on: dateForTest(year: 2026, month: 5, day: 8), for: weekly, calendar: calendar).isEmpty)

        let manual = HumanMedication(
            humanId: UUID().uuidString,
            name: "As needed",
            dosage: "1",
            frequency: .asNeeded,
            startDate: thursday
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: manual, calendar: calendar).isEmpty)
    }

    @Test func humanMedicationScheduleFallsBackToLegacyFirstDoseTime() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = dateForTest(year: 2026, month: 5, day: 7)
        let firstDose = dateForTest(year: 2026, month: 5, day: 7, hour: 9, minute: 30)
        let med = HumanMedication(
            humanId: UUID().uuidString,
            name: "Legacy",
            dosage: "1",
            frequency: .twiceDaily,
            firstDoseTime: firstDose,
            startDate: day
        )

        #expect(HumanMedicationSchedulePlan.doseMinutes(for: med, calendar: calendar) == [9 * 60 + 30, 21 * 60 + 30])
    }

    @MainActor
    @Test func humanMedicationDoseLogStoreUpsertsScheduledMinute() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let humanId = UUID().uuidString
        let medicationId = UUID().uuidString
        let scheduled = dateForTest(year: 2026, month: 5, day: 7, hour: 8, minute: 0)

        let first = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled,
            status: .taken,
            existingLogs: [],
            context: context
        )
        #expect(first.didChange)
        #expect(first.shouldRecordLedgerEvent)
        try context.save()

        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let second = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled.addingTimeInterval(12),
            status: .taken,
            existingLogs: logs,
            context: context
        )
        #expect(!second.didChange)
        #expect(!second.shouldRecordLedgerEvent)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).count == 1)

        let third = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled,
            status: .skipped,
            existingLogs: logs,
            context: context
        )
        #expect(third.didChange)
        #expect(third.shouldRecordLedgerEvent)
        #expect(third.log?.status == .skipped)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).count == 1)
    }

    @MainActor
    @Test func humanMedicationDisplayGroupsAndFrequencyLocalization() async throws {
        let now = dateForTest(year: 2026, month: 5, day: 7)
        let humanId = UUID().uuidString
        let current = HumanMedication(humanId: humanId, name: "Current", frequency: .daily, startDate: now)
        let future = HumanMedication(humanId: humanId, name: "Future", frequency: .daily, startDate: dateForTest(year: 2026, month: 5, day: 8))
        let ended = HumanMedication(humanId: humanId, name: "Ended", frequency: .daily, startDate: dateForTest(year: 2026, month: 5, day: 1), endDate: dateForTest(year: 2026, month: 5, day: 2))
        let stopped = HumanMedication(humanId: humanId, name: "Stopped", frequency: .daily, startDate: now)
        stopped.isActive = false
        let manual = HumanMedication(humanId: humanId, name: "Manual", frequency: .asNeeded, startDate: now)

        #expect(HumanMedicationSchedulePlan.displayGroup(for: current, now: now) == .current)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: future, now: now) == .notStarted)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: ended, now: now) == .ended)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: stopped, now: now) == .stopped)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: manual, now: now) == .manual)
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("zh")) == "每天两次")
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("en")) == "Twice daily")
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("de")) == "Zweimal täglich")
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsBasicInfoForEmptyProfile() async throws {
        let pet = Pet(name: "Momo", species: "猫")

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 0)
        #expect(snapshot.nextStep.kind == .basicInfo)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsDocumentsAfterBasicInfo() async throws {
        let pet = archiveReadyPet()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 1)
        #expect(snapshot.nextStep.kind == .documents)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsMomentsAfterProtection() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        context.insert(pet)
        context.insert(PetDocument(title: "疫苗本", category: .vaccine, pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 2)
        #expect(snapshot.nextStep.kind == .moments)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsWeightAfterMemory() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        context.insert(pet)
        context.insert(PetInsurance(companyName: "Ohana Care", pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), note: "first photo", pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 3)
        #expect(snapshot.nextStep.kind == .weight)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsRetentionWhenComplete() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        pet.currentStreak = 3
        context.insert(pet)
        context.insert(PetDocument(title: "疫苗本", category: .vaccine, pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), note: "first photo", pet: pet))
        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 5)
        #expect(snapshot.nextStep.kind == .retention)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV63.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func writeTemporaryBackup(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaTests.Backup.\(UUID().uuidString).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private func clearCareCalendarDefaults(petKey: String, kinds: [String]) {
        for kind in kinds {
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_default_\(kind)_\(petKey)")
            UserDefaults.standard.removeObject(forKey: "careCalendarDefaultSuppressed_\(kind)_\(petKey)")
        }
    }

    private func archiveReadyPet() -> Pet {
        Pet(
            name: "Momo",
            species: "猫",
            breed: "狸花猫",
            birthday: dateForTest(year: 2023, month: 4, day: 2),
            homeDate: dateForTest(year: 2024, month: 1, day: 3)
        )
    }

    private func dateForTest(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
