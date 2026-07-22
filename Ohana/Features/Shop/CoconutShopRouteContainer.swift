import SwiftData
import SwiftUI

struct CoconutShopRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = CoconutShopRouteData()
    @State private var dataState = CoconutShopDataState.loading
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var didRunEntryRecovery = false

    let initialCategory: ShopItem.ShopCategory

    init(initialCategory: ShopItem.ShopCategory = .appIcon) {
        self.initialCategory = initialCategory
    }

    var body: some View {
        CoconutShopView(
            initialCategory: initialCategory,
            humans: routeData.humans,
            pets: routeData.pets,
            purchaseRecords: routeData.purchaseRecords,
            exchangeRequests: CoconutExchangeFeatureGate.isEnabled ? routeData.exchangeRequests : [],
            humanBalances: routeData.humanBalances,
            purchaseSettlements: routeData.purchaseSettlements,
            purchaseSettlementReasons: routeData.purchaseSettlementReasons,
            dataState: dataState,
            retryDataLoad: retryRouteDataLoad,
            refreshData: refreshRouteData,
            retryPurchaseRecovery: retryPurchaseRecovery
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            if !didRunEntryRecovery {
                didRunEntryRecovery = true
                _ = ShopPurchaseRecoveryService.settleRecoverable(
                    context: modelContext,
                    services: appServices
                )
            }
            do {
                routeData = try CoconutShopRouteData.load(
                    from: modelContext,
                    wallet: appServices.coconutWallet
                )
                dataState = .loaded
            } catch {
                OhanaLog.warning(
                    "Shop route data load failed: \(error.localizedDescription)",
                    category: "Shop"
                )
                if !routeData.hasLoaded {
                    dataState = .failed
                }
            }
            dataLoadTask = nil
        }
    }

    private func retryRouteDataLoad() {
        guard dataLoadTask == nil else { return }
        dataState = .loading
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
    }

    private func refreshRouteData() {
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
    }

    private func retryPurchaseRecovery(itemID: String) -> ShopPurchaseManualRecoveryResult {
        let result = ShopPurchaseRecoveryService.retryManualReview(
            itemID: itemID,
            context: modelContext,
            services: appServices
        )
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
        return result
    }
}

private struct CoconutShopRouteData {
    var humans: [Human] = []
    var pets: [Pet] = []
    var exchangeRequests: [CoconutExchangeRequest] = []
    var purchaseRecords: [ShopPurchaseRecord] = []
    var humanBalances: [UUID: Int] = [:]
    var purchaseSettlements: [String: ShopPurchaseSettlementState] = [:]
    var purchaseSettlementReasons: [String: String] = [:]
    var hasLoaded = false

    static func load(
        from context: ModelContext,
        wallet: CoconutWalletManaging
    ) throws -> CoconutShopRouteData {
        let humans: [Human] = try fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Human"
        )
        let balances = Dictionary(uniqueKeysWithValues: humans.map { human in
            (human.id, wallet.balance(for: human, context: context))
        })
        let fulfilled = ShopPurchaseAttemptState.fulfilled.rawValue
        let refunded = ShopPurchaseAttemptState.refunded.rawValue
        var attemptDescriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.stateRaw != fulfilled && attempt.stateRaw != refunded
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        attemptDescriptor.fetchLimit = 128
        let attempts = try fetch(attemptDescriptor, context: context, name: "ShopPurchaseAttempt")
        var settlements: [String: ShopPurchaseSettlementState] = [:]
        var settlementReasons: [String: String] = [:]
        for attempt in attempts where settlements[attempt.itemId] == nil {
            settlements[attempt.itemId] = switch attempt.state {
            case .purchased, .fulfilling: .pending
            case .refundPending: .refunding
            case .manualReview: .needsAttention
            case .fulfilled, .refunded: nil
            }
            if attempt.state == .manualReview, let lastError = attempt.lastError {
                settlementReasons[attempt.itemId] = lastError
            }
        }
        return CoconutShopRouteData(
            humans: humans,
            pets: try fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            exchangeRequests: CoconutExchangeFeatureGate.isEnabled
                ? try fetch(
                    FetchDescriptor<CoconutExchangeRequest>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                    context: context,
                    name: "CoconutExchangeRequest"
                )
                : [],
            purchaseRecords: try fetch(
                FetchDescriptor<ShopPurchaseRecord>(sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)]),
                context: context,
                name: "ShopPurchaseRecord"
            ),
            humanBalances: balances,
            purchaseSettlements: settlements,
            purchaseSettlementReasons: settlementReasons,
            hasLoaded: true
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) throws -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            throw CoconutShopRouteDataError.fetchFailed(name: name, message: error.localizedDescription)
        }
    }
}

private enum CoconutShopRouteDataError: LocalizedError {
    case fetchFailed(name: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .fetchFailed(name, message):
            "\(name): \(message)"
        }
    }
}
