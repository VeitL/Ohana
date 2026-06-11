import Foundation
import SwiftData
import Testing
@testable import Ohana

struct GachaSeriesCatalogTests {
    @Test func gachaSeriesProbabilitiesSumToOneHundredPercent() {
        #expect(GachaSeriesCatalog.validateProbabilities())
        #expect(GachaSeriesCatalog.allSeries.count >= 2)
        for series in GachaSeriesCatalog.allSeries {
            #expect(series.probabilityTotalBasisPoints == 10000)
            #expect(series.commonItems.count == 8)
            #expect(series.items.filter(\.isHidden).count == 1)
            #expect(series.commonProbabilityBasisPoints == 2000)
            #expect(series.hiddenProbabilityBasisPoints == 200)
            #expect(series.instantResultProbabilityBasisPoints == 7800)
            #expect(series.instantResults.first { $0.id == GachaSeriesCatalog.coconutGrandBundleResultId }?.probabilityBasisPoints == 500)
            #expect(series.instantResults.first { $0.id == GachaSeriesCatalog.coconutGrandBundleResultId }?.coconutDelta == 500)
        }
    }

    @Test func gachaCollectibleAssetsAreConfigured() {
        let allItems = GachaSeriesCatalog.allSeries.flatMap(\.items)

        #expect(GachaSeriesCatalog.validateStaticAssets())
        #expect(allItems.allSatisfy { !$0.imageAssetName.isEmpty })
        #expect(allItems.allSatisfy { !$0.silhouetteAssetName.isEmpty })
        #expect(allItems.allSatisfy { !$0.boxAssetName.isEmpty })
        #expect(allItems.allSatisfy { !($0.motto.translations["zh"] ?? "").isEmpty })
        #expect(allItems.allSatisfy { !($0.personality.translations["zh"] ?? "").isEmpty })
        #expect(Set(allItems.map(\.imageAssetName)).count == allItems.count)
        #expect(Set(allItems.map(\.silhouetteAssetName)).count == allItems.count)
        #expect(Set(allItems.map(\.boxAssetName)).contains("GachaNanaBlindBox"))
        #expect(Set(allItems.map(\.boxAssetName)).contains("GachaNoirAtelierBlindBox"))
    }

    @Test func deterministicRollUsesExpectedProbabilityBands() {
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)

        #expect(GachaDrawService.roll(in: series, forcedRoll: 0).item?.rarity == .hidden)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 199).item?.rarity == .hidden)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 0, allowsHidden: false).kind != .collectible)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 200).item?.rarity == .common)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 2199).item?.rarity == .common)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 2200).kind != .collectible)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5000).instantResult?.id == GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5499).instantResult?.id == GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5500).instantResult?.id != GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 9999).kind != .collectible)
    }

    @Test func consecutiveBasicBandRollsRemainIndependent() {
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let first = GachaDrawService.roll(in: series, forcedRoll: 200)
        let second = GachaDrawService.roll(in: series, forcedRoll: 200)

        #expect(first.kind == .collectible)
        #expect(first.item?.rarity == .common)
        #expect(second.kind == .collectible)
        #expect(second.item?.rarity == .common)
    }

    @Test func dailySequenceCountsOnlyCurrentHumanAndCurrentDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 19, hour: 12))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let logs = [
            GachaDrawLog(ownerHumanId: "A", seriesId: "s", itemId: "i", drawDate: now),
            GachaDrawLog(ownerHumanId: "A", seriesId: "s", itemId: "i", drawDate: now.addingTimeInterval(60)),
            GachaDrawLog(ownerHumanId: "B", seriesId: "s", itemId: "i", drawDate: now),
            GachaDrawLog(ownerHumanId: "A", seriesId: "s", itemId: "i", drawDate: yesterday)
        ]

        #expect(GachaDrawService.dailyDrawCount(for: "A", in: logs, now: now, calendar: calendar) == 2)
        #expect(GachaDrawService.dailyDrawCount(for: "B", in: logs, now: now, calendar: calendar) == 1)
    }

    @MainActor
    @Test func drawAllowsMoreThanThreePlaysWhenCoconutsAreAvailable() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = GachaDrawService.costPerDraw * 4
        context.insert(human)
        try context.save()

        for index in 0 ..< 4 {
            _ = try GachaDrawService.draw(
                seriesId: series.id,
                human: human,
                context: context,
                now: Date(timeIntervalSince1970: TimeInterval(index)),
                forcedRoll: 200
            )
        }

        let logs = try context.fetch(FetchDescriptor<GachaDrawLog>())
        #expect(logs.count == 4)
        #expect(Set(logs.map(\.dailySequence)) == Set([1, 2, 3, 4]))
        #expect(human.coconutBalance == 0)
    }

    @MainActor
    @Test func drawDuplicatesCollectiblesButDoesNotCollectInstantResults() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 500
        let existing = GachaOwnedItem(
            ownerHumanId: human.id.uuidString,
            seriesId: series.id,
            itemId: series.commonItems[0].id,
            rarity: .common,
            ownedCount: 1
        )
        context.insert(human)
        context.insert(existing)
        try context.save()

        let collectible = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 100),
            forcedRoll: 200
        )
        #expect(collectible.item?.id == series.commonItems[0].id)
        #expect(collectible.ownedItem?.ownedCount == 2)

        let secondCollectible = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 200),
            forcedRoll: 200
        )
        #expect(secondCollectible.item?.id == series.commonItems[0].id)
        #expect(secondCollectible.ownedItem?.ownedCount == 3)

        let instant = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 300),
            forcedRoll: 2500
        )
        #expect(instant.item == nil)
        #expect(instant.ownedItem == nil)

        let ownedItems = try context.fetch(FetchDescriptor<GachaOwnedItem>())
        #expect(ownedItems.count == 1)
        #expect(ownedItems[0].ownedCount == 3)
    }

    @MainActor
    @Test func instantCoconutRewardRecordsSpendAndRewardSeparately() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 100
        context.insert(human)
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 400),
            forcedRoll: 2500
        )

        #expect(outcome.log.instantCoconutDelta == 5)
        #expect(human.coconutBalance == 25)

        let events = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let costEvents = events.filter { $0.actionType == "gachaDrawCost" }
        let rewardEvents = events.filter { $0.actionType == "gachaInstantReward" }
        #expect(costEvents.count == 1)
        #expect(rewardEvents.count == 1)
        #expect(costEvents.first?.coconutDelta == -GachaDrawService.costPerDraw)
        #expect(rewardEvents.first?.coconutDelta == 5)
    }

    @MainActor
    @Test func coconutGrandBundleAwardsFiveHundredCoconuts() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 100
        context.insert(human)
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 450),
            forcedRoll: 5000
        )

        #expect(outcome.item == nil)
        #expect(outcome.instantResult?.id == GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(outcome.log.instantCoconutDelta == 500)
        #expect(human.coconutBalance == 520)

        let events = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let costEvents = events.filter { $0.actionType == "gachaDrawCost" }
        let rewardEvents = events.filter { $0.actionType == "gachaInstantReward" }
        #expect(costEvents.first?.coconutDelta == -GachaDrawService.costPerDraw)
        #expect(rewardEvents.first?.coconutDelta == 500)
    }

    @MainActor
    @Test func hiddenCollectibleRequiresAllCommonItemsOwned() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 200
        context.insert(human)
        try context.save()

        let lockedOutcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 500),
            forcedRoll: 0
        )
        #expect(lockedOutcome.item == nil)
        #expect(lockedOutcome.log.outcomeKind != .collectible)
        #expect(!lockedOutcome.log.isHidden)

        for item in series.commonItems {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                itemId: item.id,
                rarity: item.rarity,
                ownedCount: 1
            ))
        }
        human.coconutBalance = 200
        try context.save()

        let unlockedOutcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 600),
            forcedRoll: 0
        )
        #expect(unlockedOutcome.item?.isHidden == true)
        #expect(unlockedOutcome.ownedItem?.isHidden == true)
        #expect(unlockedOutcome.log.isHidden)
    }

    @MainActor
    @Test func secondSeriesRequiresFirstSeriesRegularCompletion() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let firstSeries = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let secondSeries = GachaSeriesCatalog.series(id: GachaSeriesCatalog.noirSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 300
        context.insert(human)
        try context.save()

        do {
            _ = try GachaDrawService.draw(
                seriesId: secondSeries.id,
                human: human,
                context: context,
                now: Date(timeIntervalSince1970: 700),
                forcedRoll: 200
            )
            #expect(Bool(false))
        } catch let error as GachaDrawError {
            #expect(error == .lockedSeries)
        }

        for item in firstSeries.commonItems {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: firstSeries.id,
                itemId: item.id,
                rarity: item.rarity,
                ownedCount: 1
            ))
        }
        try context.save()

        let unlockedOutcome = try GachaDrawService.draw(
            seriesId: secondSeries.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 800),
            forcedRoll: 200
        )

        #expect(unlockedOutcome.item?.seriesId == secondSeries.id)
        #expect(unlockedOutcome.item?.rarity == .common)
    }

    @MainActor
    private func makeGachaContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV63.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
