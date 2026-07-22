import Foundation
import SwiftData

@MainActor
protocol GachaDrawing {
    var costPerDraw: Int { get }

    func collectionProgress(
        humanId: String,
        seriesId: String,
        ownedItems: [GachaOwnedItem]
    ) -> (owned: Int, total: Int)

    func isSeriesUnlocked(
        seriesId: String,
        humanId: String,
        ownedItems: [GachaOwnedItem]
    ) -> Bool

    func guaranteeStatus(
        humanId: String,
        series: GachaSeriesEntry,
        ownedItems: [GachaOwnedItem],
        logs: [GachaDrawLog]
    ) -> GachaGuaranteeStatus

    func fundingPreview(human: Human, context: ModelContext) -> GachaFundingPreview
    func stardustBalance(context: ModelContext) -> Int

    func draw(
        seriesId: String,
        human: Human?,
        context: ModelContext,
        approvedFunding: GachaFundingPreview?
    ) throws -> GachaDrawOutcome

    func draw(
        request: GachaDrawRequest,
        human: Human?,
        context: ModelContext
    ) async throws -> GachaDrawOutcomeDTO
}

@MainActor
final class StaticGachaDrawer: GachaDrawing {
    private let wallet: CoconutWalletManaging
    private let careLedger: CareLedgerRecording
    private let questManager: QuestManager

    convenience init() {
        self.init(
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            questManager: QuestManager()
        )
    }

    init(wallet: CoconutWalletManaging, careLedger: CareLedgerRecording, questManager: QuestManager) {
        self.wallet = wallet
        self.careLedger = careLedger
        self.questManager = questManager
    }

    var costPerDraw: Int { GachaDrawService.costPerDraw }

    func collectionProgress(
        humanId: String,
        seriesId: String,
        ownedItems: [GachaOwnedItem]
    ) -> (owned: Int, total: Int) {
        GachaDrawService.collectionProgress(
            humanId: humanId,
            seriesId: seriesId,
            ownedItems: ownedItems
        )
    }

    func isSeriesUnlocked(
        seriesId: String,
        humanId: String,
        ownedItems: [GachaOwnedItem]
    ) -> Bool {
        GachaDrawService.isSeriesUnlocked(
            seriesId: seriesId,
            humanId: humanId,
            ownedItems: ownedItems
        )
    }

    func guaranteeStatus(
        humanId: String,
        series: GachaSeriesEntry,
        ownedItems: [GachaOwnedItem],
        logs: [GachaDrawLog]
    ) -> GachaGuaranteeStatus {
        GachaDrawService.guaranteeStatus(
            humanId: humanId,
            series: series,
            ownedItems: ownedItems,
            logs: logs
        )
    }

    func fundingPreview(human: Human, context: ModelContext) -> GachaFundingPreview {
        GachaDrawService.fundingPreview(human: human, context: context)
    }

    func stardustBalance(context: ModelContext) -> Int {
        GachaDrawService.stardustBalance(context: context)
    }

    func draw(
        seriesId: String,
        human: Human?,
        context: ModelContext,
        approvedFunding: GachaFundingPreview? = nil
    ) throws -> GachaDrawOutcome {
        let outcome = try GachaDrawService.draw(
            seriesId: seriesId,
            human: human,
            context: context,
            approvedFunding: approvedFunding,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
        if let human {
            publishDrawMutation(humanID: human.id, seriesID: seriesId, drawID: outcome.log.id)
        }
        return outcome
    }

    func draw(
        request: GachaDrawRequest,
        human: Human?,
        context: ModelContext
    ) async throws -> GachaDrawOutcomeDTO {
        guard let human else { throw GachaDrawError.missingHuman }
        guard request.oddsVersion == GachaDrawService.oddsVersion,
              request.ownerHumanID == human.id else {
            throw GachaDrawError.fundingChanged
        }
        let wasAlreadyPersisted = try GachaDrawService.hasPersistedDraw(
            id: request.id,
            context: context
        )
        let outcome = try GachaDrawService.draw(
            seriesId: request.seriesID,
            human: human,
            context: context,
            requestID: request.id,
            approvedFunding: request.approvedFunding,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
        if !wasAlreadyPersisted {
            publishDrawMutation(humanID: human.id, seriesID: request.seriesID, drawID: outcome.log.id)
        }
        return GachaDrawService.outcomeDTO(outcome)
    }

    private func publishDrawMutation(humanID: UUID, seriesID: String, drawID: UUID) {
        questManager.revisions.publish(
            DomainMutationResult(
                command: .command("gacha", "draw", ["seriesID": seriesID]),
                affectedEntityIDs: [humanID],
                wroteBusinessFact: true,
                note: "gacha.draw.\(drawID.uuidString)"
            )
        )
    }
}
