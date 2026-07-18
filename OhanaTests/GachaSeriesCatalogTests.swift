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
            #expect(series.commonProbabilityBasisPoints == 3800)
            #expect(series.hiddenProbabilityBasisPoints == 200)
            #expect(series.instantResultProbabilityBasisPoints == 6000)
            #expect(series.instantResults.first { $0.id == GachaSeriesCatalog.coconutGrandBundleResultId }?.probabilityBasisPoints == 200)
            #expect(series.instantResults.first { $0.id == GachaSeriesCatalog.coconutGrandBundleResultId }?.coconutDelta == 500)
        }
    }

    @Test func shopCatalogPricesMatchEconomyPolicy() throws {
        #expect(try #require(ShopCatalog.item(id: "boost_double")).cost == 80)
        #expect(try #require(ShopCatalog.item(id: "boost_streak")).cost == 180)
        #expect(try #require(ShopCatalog.item(id: "boost_backdate_single")).cost == 240)
        #expect(try #require(ShopCatalog.item(id: "boost_backdate_pack")).cost == 580)
        #expect(try #require(ShopCatalog.item(id: Avatar2DAccess.shopItemId)).cost == 1200)
    }

    @Test func hiddenExchangeOptionsKeepLinearRates() throws {
        let jpy = CoconutExchangeOption.options(for: "JP")
        #expect(jpy.map(\.coconutCost) == [500, 1000, 2000])
        #expect(jpy.map(\.localAmount) == [75, 150, 300])

        let cny = CoconutExchangeOption.options(for: "CN")
        #expect(cny.map(\.coconutCost) == [500, 1000, 2000])
        #expect(cny.map(\.localAmount) == [2.5, 5, 10])
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
        #expect(GachaDrawService.roll(in: series, forcedRoll: 0, allowsHidden: false).item?.rarity == .common)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 200).item?.rarity == .common)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 3999).item?.rarity == .common)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 4000).instantResult?.coconutDelta == 5)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5749).instantResult?.coconutDelta == 10)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5750).instantResult?.id == GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5949).instantResult?.id == GachaSeriesCatalog.coconutGrandBundleResultId)
        #expect(GachaDrawService.roll(in: series, forcedRoll: 5950).instantResult?.id != GachaSeriesCatalog.coconutGrandBundleResultId)
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
            forcedRoll: 4000
        )
        #expect(instant.item == nil)
        #expect(instant.ownedItem == nil)

        let ownedItems = try context.fetch(FetchDescriptor<GachaOwnedItem>())
        #expect(ownedItems.count == 1)
        #expect(ownedItems[0].ownedCount == 3)
        let stardust = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
            .first { $0.catalogId == OasisCompanionCurrency.stardustCatalogID }
        #expect(stardust?.amount == 40)
        #expect(collectible.log.stardustDelta == 20)
        #expect(secondCollectible.log.stardustDelta == 20)
    }

    @MainActor
    @Test func drawUsesIslandCofundingWhenBuyerBalanceIsShort() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let buyer = Human(name: "Ava")
        buyer.coconutBalance = 10
        let contributor = Human(name: "Guan")
        contributor.coconutBalance = 100
        contributor.createdAt = buyer.createdAt.addingTimeInterval(1)
        context.insert(buyer)
        context.insert(contributor)
        try context.save()

        let preview = GachaDrawService.fundingPreview(human: buyer, context: context)
        do {
            _ = try GachaDrawService.draw(
                seriesId: series.id,
                human: buyer,
                context: context,
                now: Date(timeIntervalSince1970: 349),
                forcedRoll: 200
            )
            #expect(Bool(false))
        } catch let error as GachaDrawError {
            #expect(error == .fundingConfirmationRequired)
        }
        #expect(buyer.coconutBalance == 10)
        #expect(contributor.coconutBalance == 100)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: buyer,
            context: context,
            now: Date(timeIntervalSince1970: 350),
            forcedRoll: 200,
            approvedFunding: preview
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(outcome.log.ownerHumanId == buyer.id.uuidString)
        #expect(buyer.coconutBalance == 0)
        #expect(contributor.coconutBalance == 30)
        #expect(walletEntries.count(where: { $0.ownerId == buyer.id.uuidString && $0.delta == -10 }) == 1)
        #expect(walletEntries.count(where: { $0.ownerId == contributor.id.uuidString && $0.delta == -70 }) == 1)
        #expect(walletEntries.allSatisfy { $0.balanceAfter >= 0 })
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
            forcedRoll: 4000
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
            forcedRoll: 5750
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
        #expect(lockedOutcome.item?.rarity == .common)
        #expect(lockedOutcome.log.outcomeKind == .collectible)
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

    @Test func commonHitPrefersMissingPoolForSeventyFivePercentBand() {
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let missing = [series.commonItems[7]]

        let preferred = GachaDrawService.roll(
            in: series,
            forcedRoll: 200,
            missingCommonItems: missing,
            forcedCommonPreferenceRoll: 7499,
            forcedCommonItemIndex: 0
        )
        let allPool = GachaDrawService.roll(
            in: series,
            forcedRoll: 200,
            missingCommonItems: missing,
            forcedCommonPreferenceRoll: 7500,
            forcedCommonItemIndex: 0
        )

        #expect(preferred.item?.id == missing[0].id)
        #expect(allPool.item?.id == series.commonItems[0].id)
    }

    @Test func guaranteesIgnoreLegacyAndNonPaidHistory() {
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let ownerID = UUID().uuidString
        let logs = (0 ..< 5).map { index in
            GachaDrawLog(
                ownerHumanId: ownerID,
                seriesId: series.id,
                outcomeKind: .message,
                oddsVersion: index < 3 ? nil : 2,
                drawDate: Date(timeIntervalSince1970: TimeInterval(index))
            )
        } + [
            GachaDrawLog(
                ownerHumanId: ownerID,
                seriesId: series.id,
                outcomeKind: .message,
                costCoconuts: 0,
                oddsVersion: 2,
                drawDate: Date(timeIntervalSince1970: 10)
            )
        ]

        let status = GachaDrawService.guaranteeStatus(
            humanId: ownerID,
            series: series,
            ownedItems: [],
            logs: logs
        )

        #expect(status.newCommonMisses == 2)
        #expect(status.drawsUntilNewCommonGuarantee == 4)
    }

    @MainActor
    @Test func sixthPaidV2MissForcesMissingCommonItem() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 80
        context.insert(human)
        for item in series.commonItems.dropLast() {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                itemId: item.id,
                rarity: .common,
                firstObtainedAt: Date(timeIntervalSince1970: 0)
            ))
        }
        for index in 0 ..< 5 {
            context.insert(GachaDrawLog(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                outcomeKind: .message,
                oddsVersion: 2,
                drawDate: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 1000),
            forcedRoll: 4000,
            forcedCommonItemIndex: 0
        )

        #expect(outcome.item?.id == series.commonItems.last?.id)
        #expect(outcome.log.guaranteeKind == .newCommonPity)
        #expect(outcome.log.oddsVersion == 2)
    }

    @MainActor
    @Test func fortiethEligiblePaidV2DrawForcesHiddenItem() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 80
        context.insert(human)
        for item in series.commonItems {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                itemId: item.id,
                rarity: .common,
                firstObtainedAt: Date(timeIntervalSince1970: 0)
            ))
        }
        for index in 0 ..< 39 {
            context.insert(GachaDrawLog(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                outcomeKind: .message,
                oddsVersion: 2,
                drawDate: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 1000),
            forcedRoll: 4000
        )

        #expect(outcome.item?.isHidden == true)
        #expect(outcome.log.guaranteeKind == .hiddenHardPity)
    }

    @MainActor
    @Test func completedSeriesSixthNonCollectibleForcesCommonDuplicateAndStardust() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 80
        context.insert(human)
        for item in series.items {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                itemId: item.id,
                rarity: item.rarity,
                isHidden: item.isHidden,
                firstObtainedAt: Date(timeIntervalSince1970: 0)
            ))
        }
        for index in 0 ..< 5 {
            context.insert(GachaDrawLog(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                outcomeKind: .message,
                oddsVersion: 2,
                drawDate: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 1000),
            forcedRoll: 4000,
            forcedCommonItemIndex: 0
        )

        #expect(outcome.item?.rarity == .common)
        #expect(outcome.log.guaranteeKind == .completedCollectionPity)
        #expect(outcome.log.stardustDelta == 20)
        #expect(GachaDrawService.stardustBalance(context: context) == 20)
    }

    @MainActor
    @Test func hiddenDuplicateAwardsOneHundredStardustAndKeepsCount() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 80
        context.insert(human)
        for item in series.items {
            context.insert(GachaOwnedItem(
                ownerHumanId: human.id.uuidString,
                seriesId: series.id,
                itemId: item.id,
                rarity: item.rarity,
                isHidden: item.isHidden,
                firstObtainedAt: Date(timeIntervalSince1970: 0)
            ))
        }
        try context.save()

        let outcome = try GachaDrawService.draw(
            seriesId: series.id,
            human: human,
            context: context,
            now: Date(timeIntervalSince1970: 1000),
            forcedRoll: 0
        )

        #expect(outcome.item?.isHidden == true)
        #expect(outcome.ownedItem?.ownedCount == 2)
        #expect(outcome.log.stardustDelta == 100)
        #expect(GachaDrawService.stardustBalance(context: context) == 100)
    }

    @MainActor
    @Test func unknownSeriesFailsClosedWithoutChargingWallet() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        human.coconutBalance = 100
        context.insert(human)
        try context.save()

        do {
            _ = try GachaDrawService.draw(
                seriesId: "unknown_series",
                human: human,
                context: context
            )
            #expect(Bool(false))
        } catch let error as GachaDrawError {
            #expect(error == .invalidSeries)
        }

        #expect(human.coconutBalance == 100)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func approvedCofundingIsRevalidatedBeforeAnyWrite() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let buyer = Human(name: "Ava")
        buyer.coconutBalance = 10
        let contributor = Human(name: "Guan")
        contributor.coconutBalance = 100
        contributor.createdAt = buyer.createdAt.addingTimeInterval(1)
        context.insert(buyer)
        context.insert(contributor)
        try context.save()
        let preview = GachaDrawService.fundingPreview(human: buyer, context: context)
        #expect(preview.requiresCofundingConfirmation)

        contributor.coconutBalance = 60
        try context.save()
        do {
            _ = try GachaDrawService.draw(
                human: buyer,
                context: context,
                approvedFunding: preview
            )
            #expect(Bool(false))
        } catch let error as GachaDrawError {
            #expect(error == .fundingChanged)
        }

        #expect(buyer.coconutBalance == 10)
        #expect(contributor.coconutBalance == 60)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
    }

    @MainActor
    @Test func fundingPreviewRequiresConfirmationWhenOnlyAnotherMemberPays() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let buyer = Human(name: "Ava")
        buyer.coconutBalance = 0
        let contributor = Human(name: "Guan")
        contributor.coconutBalance = 80
        context.insert(buyer)
        context.insert(contributor)
        try context.save()

        let preview = GachaDrawService.fundingPreview(human: buyer, context: context)

        #expect(preview.missing == 0)
        #expect(preview.contributions.count == 1)
        #expect(preview.contributions.first?.humanID == contributor.id)
        #expect(preview.requiresCofundingConfirmation)
    }

    @MainActor
    @Test func walletFailureRollsBackCollectionStardustLedgerAndLog() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let series = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let human = Human(name: "Ava")
        human.coconutBalance = 80
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

        do {
            _ = try GachaDrawService.draw(
                seriesId: series.id,
                human: human,
                context: context,
                forcedRoll: 200,
                wallet: FailingWallet()
            )
            #expect(Bool(false))
        } catch let error as GachaDrawError {
            #expect(error == .persistenceFailed)
        }

        #expect(existing.ownedCount == 1)
        #expect(human.coconutBalance == 80)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func activePersistenceFenceRejectsDrawWithoutAnyWrite() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        human.coconutBalance = 80
        context.insert(human)
        try context.save()

        let observed = PersistenceWriteFence.withExclusiveAccess(
            context: context,
            unavailable: { GachaDrawError.persistenceFailed },
            operation: {
                do {
                    _ = try GachaDrawService.draw(human: human, context: context)
                    return GachaDrawError.persistenceFailed
                } catch let error as GachaDrawError {
                    return error
                } catch {
                    return GachaDrawError.persistenceFailed
                }
            }
        )

        #expect(observed == .backupOrRestoreInProgress)
        #expect(human.coconutBalance == 80)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @MainActor
    @Test func duplicateDrawRequestReturnsOriginalOutcomeWithoutChargingAgain() async throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        human.coconutBalance = 160
        context.insert(human)
        try context.save()
        let request = GachaDrawRequest(
            id: UUID(),
            ownerHumanID: human.id,
            seriesID: GachaSeriesCatalog.defaultSeriesId
        )
        let drawer = StaticGachaDrawer()

        let first = try await drawer.draw(request: request, human: human, context: context)
        let balanceAfterFirst = human.coconutBalance
        let logsAfterFirst = try context.fetch(FetchDescriptor<GachaDrawLog>()).count
        let ledgerAfterFirst = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count
        let ownedCountAfterFirst = try context.fetch(FetchDescriptor<GachaOwnedItem>())
            .reduce(0) { $0 + $1.ownedCount }

        let second = try await drawer.draw(request: request, human: human, context: context)

        #expect(second == first)
        #expect(first.drawLogID == request.id)
        #expect(human.coconutBalance == balanceAfterFirst)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).count == logsAfterFirst)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count == ledgerAfterFirst)
        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).reduce(0) { $0 + $1.ownedCount } == ownedCountAfterFirst)
    }

    @MainActor
    @Test func fragmentRestoreMergesSameCatalogBalanceAcrossDifferentUUIDs() throws {
        let container = try makeGachaContainer()
        let context = container.mainContext
        let existing = OasisCritterFragmentBalance(
            id: UUID(),
            catalogId: OasisCompanionCurrency.stardustCatalogID,
            amount: 20,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        context.insert(existing)
        try context.save()

        let restored = try DomainGeneralRehydrateWriter.insertOasisCritterFragmentIfNeeded(
            snapshot: DomainOasisCritterFragmentRehydrateSnapshot(
                id: UUID(),
                catalogId: OasisCompanionCurrency.stardustCatalogID,
                amount: 100,
                updatedAt: Date(timeIntervalSince1970: 200)
            ),
            source: .backupRestore,
            context: context
        )

        #expect(!restored.inserted)
        #expect(restored.model?.id == existing.id)
        #expect(existing.amount == 100)
        #expect(try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()).count == 1)
    }

    @MainActor
    private func makeGachaContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private final class FailingWallet: CoconutWalletManaging {
        enum Failure: Error { case forced }

        func apply(
            deltas _: [CoconutWalletDelta],
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            updatesProjection _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func applyActorDelta(
            amount _: Int,
            emoji _: String,
            title _: String,
            actorId _: String?,
            actorName _: String?,
            entryKind _: CoconutWalletEntryKind,
            source _: CoconutWalletSource,
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func totalBalance(context _: ModelContext) -> Int { 0 }
        func balance(accountKey _: String, context _: ModelContext, fallback: Int) -> Int { fallback }
        func balance(for human: Human, context _: ModelContext) -> Int { human.coconutBalance }
        func balance(for pet: Pet, context _: ModelContext) -> Int { pet.coconutBalance }
        func legacySystemBalance(context _: ModelContext, fallback: Int) -> Int { fallback }
        func setDeveloperOverrideBalance(amount _: Int, for _: Human?, displayName _: String, context _: ModelContext) {}
        func refreshQuestProjection(context _: ModelContext, manager _: CoconutProjectionManaging?) {}
        func bootstrapIfNeeded(context _: ModelContext, projectionManager _: CoconutProjectionManaging?) throws {}
    }
}
