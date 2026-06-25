import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HomeExpensePreviewStoreTests {
    @Test func expandedFeedQuickActionUsesLedgerEntriesForManualStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        pet.dailyPortionGrams = 45
        FeedOperatingMode.set(pet.id, mode: .manual)
        let item = QuickActionItem(
            label: "喂食",
            icon: "fork.knife",
            colorHex: "FFDD44",
            petId: pet.id,
            actionType: "feed",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeFeedQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            date: now,
            amountGrams: 45,
            source: .manualMain
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [entry],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [entry],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "手动 1餐")
        #expect(isCompleted == true)
    }

    @Test func expandedPlayQuickActionUsesCareLedgerEntriesForStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 10)))
        let pet = Pet(name: "Milo", species: "猫")
        let item = QuickActionItem(
            label: "逗玩",
            icon: "tennisball",
            colorHex: "77CCFF",
            petId: pet.id,
            actionType: "play",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeCareQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            actionType: CareType.play.rawValue,
            date: now,
            amountValue: 0
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [entry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [entry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "今日陪玩 1次")
        #expect(isCompleted == true)
    }

    @Test func expandedWalkQuickActionUsesLedgerDistanceForStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 11)))
        let pet = Pet(name: "Milo", species: "狗")
        let item = QuickActionItem(
            label: "出行",
            icon: "figure.walk",
            colorHex: "22CC88",
            petId: pet.id,
            actionType: "walk",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomeWalkQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            startDate: now,
            distanceMeters: 1200
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [entry],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [entry],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(countText == "今日 1次 · 1.2km")
        #expect(isCompleted == true)
    }

    @Test func expandedPottyQuickActionUsesLedgerEntriesForRecentAbnormalStatus() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 12)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 18)))
        let pet = Pet(name: "Milo", species: "猫")
        let item = QuickActionItem(
            label: "便便",
            icon: "seal.fill",
            colorHex: "AA7744",
            petId: pet.id,
            actionType: "potty",
            entityId: pet.id,
            entityKind: .pet
        )
        let entry = HomePottyQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            date: yesterday,
            pottyType: .softPoop
        )

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [entry],
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [entry],
            now: now,
            calendar: calendar
        )

        #expect(countText == "最近异常")
        #expect(isCompleted == false)
    }

    @Test func expandedPetExpenseQuickActionUsesLedgerEntriesForMonthlyTotal() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 13)))
        let currentMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9)))
        let currentMonthLater = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 18)))
        let previousMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 18)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "支出",
            icon: "creditcard",
            colorHex: "66CCAA",
            petId: pet.id,
            actionType: "expense",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: currentMonth, amount: 12),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: currentMonthLater, amount: 30),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: pet.id, date: previousMonth, amount: 80),
            HomePetExpenseQuickActionEntry(id: UUID(), petId: otherPet.id, date: currentMonth, amount: 99)
        ]

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petExpenseLedgerEntries: entries,
            now: now,
            calendar: calendar
        )

        #expect(countText == "本月 \(AppCurrency.format(42, fractionDigits: 0))")
    }

    @Test func expandedPetWeightQuickActionUsesLedgerEntriesForLatestAndCompletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 14)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let previous = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "体重",
            icon: "scalemass.fill",
            colorHex: "66AADD",
            petId: pet.id,
            actionType: "weight",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomePetWeightQuickActionEntry(id: UUID(), petId: pet.id, date: previous, weightKg: 4.2),
            HomePetWeightQuickActionEntry(id: UUID(), petId: pet.id, date: today, weightKg: 4.8),
            HomePetWeightQuickActionEntry(id: UUID(), petId: otherPet.id, date: today, weightKg: 8.1)
        ]

        let countText = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petWeightLedgerEntries: entries,
            now: now,
            calendar: calendar
        )
        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petWeightLedgerEntries: entries,
            now: now,
            calendar: calendar
        )

        #expect(countText == "4.8kg")
        #expect(isCompleted == true)
    }

    @Test func expandedMomentQuickActionUsesReadModelEntriesInsteadOfPetRelationshipLogs() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 14)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let relationshipLog = PetPhotoLog(imageData: Data([1, 2, 3]), date: today, pet: pet)
        pet.photoLogs.append(relationshipLog)
        let item = QuickActionItem(
            label: "记录",
            icon: "camera.circle.fill",
            colorHex: "FF6B9D",
            petId: pet.id,
            actionType: "moment",
            entityId: pet.id,
            entityKind: .pet
        )

        let emptyStatus = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petMomentEntries: [],
            now: now,
            calendar: calendar,
            l: L10n("zh")
        )
        let readModelStatus = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            petMomentEntries: [
                HomePetMomentQuickActionEntry(id: UUID(), petId: otherPet.id, date: today),
                HomePetMomentQuickActionEntry(id: UUID(), petId: pet.id, date: today)
            ],
            now: now,
            calendar: calendar,
            l: L10n("zh")
        )

        #expect(emptyStatus == "还没有记录")
        #expect(readModelStatus == "今天 1 条")
    }

    @Test func expandedWaterCycleUsesReadModelEntriesInsteadOfPetCareLogRelationship() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 14)))
        let oldWaterChange = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9)))
        let pet = Pet(name: "Nemo", species: "鱼")
        WaterCareSettingsStore.saveWaterSettings(
            petKey: pet.id.uuidString,
            intervalDays: 3,
            reminderOn: true,
            cycleAnchor: now
        )
        pet.careLogs.append(PetCareLog(date: oldWaterChange, type: .waterChange, pet: pet))
        let item = QuickActionItem(
            label: "换水",
            icon: "drop.circle.fill",
            colorHex: "5AC8FA",
            petId: pet.id,
            actionType: "waterChange",
            entityId: pet.id,
            entityKind: .pet
        )
        let readModelEntry = HomeCareQuickActionEntry(
            id: UUID(),
            petId: pet.id,
            actionType: CareType.waterChange.rawValue,
            date: oldWaterChange,
            amountValue: 0
        )

        let emptyStatus = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar,
            l: L10n("zh")
        )
        let readModelStatus = ExpandedQuickActionLogic.countText(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [readModelEntry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar,
            l: L10n("zh")
        )
        let emptyAttention = ExpandedQuickActionLogic.showsAttentionDot(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now
        )
        let readModelAttention = ExpandedQuickActionLogic.showsAttentionDot(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [readModelEntry],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now
        )

        #expect(emptyStatus == nil)
        #expect(readModelStatus == "逾期2天")
        #expect(emptyAttention == false)
        #expect(readModelAttention == true)
    }

    @Test func waterCareCycleStatusIgnoresLegacyCareLogRelationshipWithoutSnapshot() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 14)))
        let recentAnchor = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let oldWaterChange = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9)))
        let pet = Pet(name: "Nemo", species: "鱼")
        WaterCareSettingsStore.saveWaterSettings(
            petKey: pet.id.uuidString,
            intervalDays: 3,
            reminderOn: true,
            cycleAnchor: recentAnchor
        )
        pet.careLogs.append(PetCareLog(date: oldWaterChange, type: .waterChange, pet: pet))

        let implicitStatus = try #require(WaterCareCycleStatusCalculator.waterChangeStatus(
            for: pet,
            now: now,
            calendar: calendar
        ))
        let readModelStatus = try #require(WaterCareCycleStatusCalculator.waterChangeStatus(
            for: pet,
            now: now,
            calendar: calendar,
            logSnapshot: WaterCareCycleLogSnapshot(
                latestWaterChangeDate: oldWaterChange,
                latestFilterCleanDate: nil
            )
        ))

        #expect(implicitStatus.isOverdue == false)
        #expect(readModelStatus.isOverdue == true)
        #expect(readModelStatus.overdueDays == 2)
    }

    @Test func expandedGroomQuickActionUsesHygieneLedgerEntriesForCompletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 15)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let item = QuickActionItem(
            label: "护理",
            icon: "scissors",
            colorHex: "FF9966",
            petId: pet.id,
            actionType: "groom",
            entityId: pet.id,
            entityKind: .pet
        )
        let entries = [
            HomeHygieneQuickActionEntry(id: UUID(), petId: pet.id, hygieneType: .brushing, date: yesterday),
            HomeHygieneQuickActionEntry(id: UUID(), petId: pet.id, hygieneType: .bath, date: today),
            HomeHygieneQuickActionEntry(id: UUID(), petId: otherPet.id, hygieneType: .bath, date: today)
        ]

        let isCompleted = ExpandedQuickActionLogic.isCompleted(
            item: item,
            pet: pet,
            allEvents: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            hygieneLedgerEntries: entries,
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            now: now,
            calendar: calendar
        )

        #expect(isCompleted == true)
    }

    @Test func petHygieneDetailEntriesFilterSortAndKeepLegacyDeleteId() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let legacyLogId = UUID()
        let older = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.brushing.rawValue,
            legacyModelName: "PetHygieneLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newer = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.bath.rawValue
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.bath.rawValue
        )
        let wrongKind = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: HygieneType.bath.rawValue
        )
        let invalidType = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: "not-a-hygiene-type"
        )

        let entries = PetHygieneLedgerEntry.entries(
            from: [older, wrongPet, wrongKind, invalidType, newer],
            petID: pet.id
        )

        #expect(entries.map(\.id) == [newer.id, older.id])
        #expect(entries.map(\.type) == [.bath, .brushing])
        #expect(entries[1].legacyLogId == legacyLogId)
    }

    @Test func islandHygieneDashboardEntriesFilterSortAndKeepCareMaintenanceRows() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let middleDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let hygiene = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.bath.rawValue
        )
        let waterChange = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.waterChange.rawValue
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: middleDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.brushing.rawValue
        )
        let nonHygieneCare = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        )
        let wrongSubject = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .human,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.bath.rawValue
        )
        let invalidHygiene = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: "not-a-hygiene-type"
        )

        let entries = HygieneDashboardLedgerEntry.entries(
            from: [hygiene, waterChange, wrongPet, nonHygieneCare, wrongSubject, invalidHygiene]
        )

        #expect(entries.map(\.id) == [waterChange.id, wrongPet.id, hygiene.id])
        #expect(entries.map(\.petId) == [pet.id, otherPet.id, pet.id])
        #expect(entries.map(\.eventKind) == [.care, .hygiene, .hygiene])
        #expect(entries.map(\.actionType) == [
            CareType.waterChange.rawValue,
            HygieneType.brushing.rawValue,
            HygieneType.bath.rawValue
        ])
    }

    @Test func quickPlayDetailEntriesFilterSortAndKeepLegacyDeleteId() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let legacyLogId = UUID()
        let older = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue,
            legacyModelName: "PetCareLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newer = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )
        let wrongKind = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: CareType.play.rawValue
        )
        let wrongAction = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        )

        let entries = QuickPlayLedgerEntry.entries(
            from: [older, wrongPet, wrongKind, wrongAction, newer],
            petID: pet.id
        )

        #expect(entries.map(\.id) == [newer.id, older.id])
        #expect(entries[1].legacyLogId == legacyLogId)
    }

    @Test func quickWaterDetailEntriesFilterSortClampAndKeepLegacyDeleteId() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let legacyLogId = UUID()
        let olderWater = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue,
            amountValue: -25,
            legacyModelName: "PetCareLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newerFilter = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.filterClean.rawValue,
            amountValue: 90
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue
        )
        let wrongKind = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: CareType.watering.rawValue
        )
        let wrongAction = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )

        let entries = QuickWaterLedgerEntry.entries(
            from: [olderWater, wrongPet, wrongKind, wrongAction, newerFilter],
            petID: pet.id
        )

        #expect(entries.map(\.id) == [newerFilter.id, olderWater.id])
        #expect(entries.map(\.careType) == [.filterClean, .watering])
        #expect(entries[0].amountMl == 0)
        #expect(entries[1].amountMl == 0)
        #expect(entries[1].legacyLogId == legacyLogId)
    }

    @Test func quickPottyDetailEntriesFilterSortAndKeepLegacyDeleteId() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let legacyLogId = UUID()
        let olderPotty = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newerPotty = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.softPoop.rawValue
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue
        )
        let wrongKind = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: PottyType.perfectPoop.rawValue
        )
        let invalidType = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: "not-a-potty-type"
        )

        let entries = PoopPottyLedgerEntry.entries(
            from: [olderPotty, wrongPet, wrongKind, invalidType, newerPotty],
            petID: pet.id
        )

        #expect(entries.map(\.id) == [newerPotty.id, olderPotty.id])
        #expect(entries.map(\.pottyType) == [.softPoop, .perfectPoop])
        #expect(entries[1].legacyLogId == legacyLogId)
    }

    @Test func quickPottyLitterEntriesFilterSortAndKeepLegacyDeleteId() throws {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let newerDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let pet = Pet(name: "Milo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let legacyLogId = UUID()
        let olderLitter = CareLedgerEvent(
            occurredAt: olderDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.litter.rawValue,
            legacyModelName: "PetCareLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newerLitter = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.litter.rawValue
        )
        let wrongPet = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.litter.rawValue
        )
        let wrongKind = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: CareType.litter.rawValue
        )
        let wrongAction = CareLedgerEvent(
            occurredAt: newerDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )

        let entries = PoopLitterLedgerEntry.entries(
            from: [olderLitter, wrongPet, wrongKind, wrongAction, newerLitter],
            petID: pet.id
        )

        #expect(entries.map(\.id) == [newerLitter.id, olderLitter.id])
        #expect(entries[1].legacyLogId == legacyLogId)
    }

    @Test func fetchExpenseEntriesFiltersToCurrentMonthAndActor() throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        container.mainContext.insert(human)
        container.mainContext.insert(otherHuman)

        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let current = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))),
            amount: 12,
            actorId: human.id.uuidString
        )
        let older = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))),
            amount: 20,
            actorId: human.id.uuidString
        )
        let otherActor = try expenseLedger(
            date: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))),
            amount: 30,
            actorId: otherHuman.id.uuidString
        )
        let unrelatedKind = try CareLedgerEvent(
            occurredAt: #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 6))),
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        )
        container.mainContext.insert(current)
        container.mainContext.insert(older)
        container.mainContext.insert(otherActor)
        container.mainContext.insert(unrelatedKind)
        try container.mainContext.save()

        let entries = HomeExpensePreviewStore.fetchExpenseEntries(
            context: container.mainContext,
            humanID: human.id,
            now: now
        )

        #expect(entries == [
            HomeExpensePreviewEntry(
                id: current.id,
                date: current.occurredAt,
                actorId: human.id.uuidString,
                amount: current.amountValue
            )
        ])
    }

    @Test func quickCareDeleteBridgesUseActionTimeIdFetches() throws {
        let rootURL = repositoryRootURL()
        let routeContainer = try source("Ohana/Features/QuickCare/QuickCareRouteContainer.swift", rootURL: rootURL)
        let playSheet = try source("Ohana/Features/QuickCare/Views/QuickPlayDetailSheet.swift", rootURL: rootURL)
        let waterSheet = try source("Ohana/Features/QuickCare/Views/QuickWaterDetailSheet.swift", rootURL: rootURL)
        let waterLogic = try source("Ohana/Features/QuickCare/Views/QuickWaterDetailSheet+Logic.swift", rootURL: rootURL)
        let pottySheet = try source("Ohana/Features/QuickCare/Views/QuickPottyDetailSheet.swift", rootURL: rootURL)
        let pottyLogic = try source("Ohana/Features/QuickCare/Views/QuickPottyDetailSheet+Logic.swift", rootURL: rootURL)
        let hygieneContainer = try source("Ohana/Features/Hygiene/PetHygieneDetailDataContainer.swift", rootURL: rootURL)
        let hygieneView = try source("Ohana/Features/Hygiene/Views/PetHygieneDetailView.swift", rootURL: rootURL)

        #expect(!routeContainer.contains("legacyPlayDeleteLogs"))
        #expect(!routeContainer.contains("legacyWaterDeleteLogs"))
        #expect(!routeContainer.contains("legacyPottyDeleteLogs"))
        #expect(!routeContainer.contains("legacyLitterDeleteLogs"))

        #expect(!playSheet.contains("legacyPlayDeleteLogs"))
        #expect(!playSheet.contains("legacyPlayDeleteLog(for"))
        #expect(playSheet.contains("executor.careLog(id: legacyLogId)"))

        #expect(!waterSheet.contains("legacyWaterDeleteLogs"))
        #expect(!waterLogic.contains("legacyWaterDeleteLog(for"))
        #expect(waterLogic.contains("deleteLogBusiness(id:"))
        #expect(waterLogic.contains("commandExecutor.careLog(id: id)"))

        #expect(!pottySheet.contains("legacyPottyDeleteLogs"))
        #expect(!pottySheet.contains("legacyLitterDeleteLogs"))
        #expect(!pottyLogic.contains("legacyPottyDeleteLog(for"))
        #expect(!pottyLogic.contains("legacyLitterDeleteLog(for"))
        #expect(pottyLogic.contains("executor.pottyLog(id: logId)"))
        #expect(pottyLogic.contains("executor.careLog(id: logId)"))

        #expect(!hygieneContainer.contains("legacyDeleteLogs"))
        #expect(!hygieneContainer.contains("@Query private var legacyDeleteLogs"))
        #expect(!hygieneView.contains("legacyDeleteLogs"))
        #expect(hygieneView.contains("executor.hygieneLog(id: logId)"))
    }

    @Test func quickPottyUnknownClaimUsesRoutePureEntriesAndActionTimeFetches() throws {
        let rootURL = repositoryRootURL()
        let routeContainer = try source("Ohana/Features/QuickCare/QuickCareRouteContainer.swift", rootURL: rootURL)
        let pottySheet = try source("Ohana/Features/QuickCare/Views/QuickPottyDetailSheet.swift", rootURL: rootURL)
        let pottyLogic = try source("Ohana/Features/QuickCare/Views/QuickPottyDetailSheet+Logic.swift", rootURL: rootURL)
        let pottyComponents = try source("Ohana/Features/QuickCare/Views/QuickPottyDetailComponents.swift", rootURL: rootURL)
        let unknownStore = try source("Ohana/Features/QuickCare/QuickPottyUnknownClaimStore.swift", rootURL: rootURL)

        #expect(routeContainer.contains("unknownPottyEntries: QuickPottyUnknownClaimStore.entries"))
        #expect(pottySheet.contains("let unknownPottyEntries: [PoopUnknownPottyEntry]"))
        #expect(pottySheet.contains("unknownPottyEntries.map(PoopLogItem.unknownPotty)"))
        #expect(!pottySheet.contains("QuickPottyUnknownClaimStore.items"))
        #expect(!pottySheet.contains("items(for: pet, context: modelContext)"))

        #expect(pottyComponents.contains("case unknownPotty(PoopUnknownPottyEntry)"))
        #expect(!pottyComponents.contains("case unknownPotty(PetPottyLog"))
        #expect(!pottyComponents.contains("var claimablePottyLog: PetPottyLog?"))
        #expect(pottyComponents.contains("var claimablePottyLogId: UUID?"))
        #expect(pottyComponents.contains("var onClaim: ((UUID, Pet) -> Void)?"))

        #expect(unknownStore.contains("static func entries(for petID: UUID"))
        #expect(unknownStore.contains("PoopUnknownPottyEntry("))
        #expect(pottyLogic.contains("func claimUnknownPotty(_ logId: UUID, target: Pet)"))
        #expect(pottyLogic.contains("executor.pottyLog(id: logId)"))
        #expect(pottyLogic.contains("executor.pottyLog(id: entry.id)"))
    }

    private func expenseLedger(date: Date, amount: Double, actorId: String) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: date,
            actorKind: .human,
            actorId: actorId,
            subjectKind: .human,
            subjectId: actorId,
            eventKind: .expense,
            actionType: ExpenseCategory.other.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            source: .service,
            legacyModelName: "PetExpenseLog"
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
