import SwiftData

nonisolated enum CoconutExchangeFeatureGate {
    static let isEnabled = false
}

nonisolated enum EconomyWalletWritePolicy {
    static func canWrite(_ human: Human) -> Bool {
        !human.hasPassedAway && human.trashedAt == nil
    }

    static func canWrite(_ pet: Pet) -> Bool {
        !pet.hasPassedAway && pet.trashedAt == nil
    }
}

@MainActor
protocol CoconutExchangeManaging {
    @discardableResult
    func createRequest(
        sender: Human,
        receiver: Human,
        option: CoconutExchangeOption,
        note: String,
        context: ModelContext
    ) throws -> CoconutExchangeRequest

    func confirm(_ request: CoconutExchangeRequest, by receiver: Human, context: ModelContext) throws
    func cancel(_ request: CoconutExchangeRequest, by sender: Human, context: ModelContext) throws
}

@MainActor
final class StaticCoconutExchangeManager: CoconutExchangeManaging {
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

    @discardableResult
    func createRequest(
        sender: Human,
        receiver: Human,
        option: CoconutExchangeOption,
        note: String,
        context: ModelContext
    ) throws -> CoconutExchangeRequest {
        try CoconutExchangeService.createRequest(
            sender: sender,
            receiver: receiver,
            option: option,
            note: note,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }

    func confirm(_ request: CoconutExchangeRequest, by receiver: Human, context: ModelContext) throws {
        try CoconutExchangeService.confirm(request, by: receiver, context: context, careLedger: careLedger)
    }

    func cancel(_ request: CoconutExchangeRequest, by sender: Human, context: ModelContext) throws {
        try CoconutExchangeService.cancel(
            request,
            by: sender,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }
}
