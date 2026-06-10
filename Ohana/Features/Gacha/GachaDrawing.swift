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

    func draw(
        seriesId: String,
        human: Human?,
        context: ModelContext
    ) throws -> GachaDrawOutcome
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

    func draw(
        seriesId: String,
        human: Human?,
        context: ModelContext
    ) throws -> GachaDrawOutcome {
        try GachaDrawService.draw(
            seriesId: seriesId,
            human: human,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }
}
