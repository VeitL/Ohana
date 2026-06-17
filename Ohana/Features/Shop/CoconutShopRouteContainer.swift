import SwiftData
import SwiftUI

struct CoconutShopRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = CoconutShopRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

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
            exchangeRequests: CoconutExchangeFeatureGate.isEnabled ? routeData.exchangeRequests : []
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
            routeData = CoconutShopRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct CoconutShopRouteData {
    var humans: [Human] = []
    var pets: [Pet] = []
    var exchangeRequests: [CoconutExchangeRequest] = []
    var purchaseRecords: [ShopPurchaseRecord] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> CoconutShopRouteData {
        CoconutShopRouteData(
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            exchangeRequests: fetch(
                FetchDescriptor<CoconutExchangeRequest>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                context: context,
                name: "CoconutExchangeRequest"
            ),
            purchaseRecords: fetch(
                FetchDescriptor<ShopPurchaseRecord>(sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)]),
                context: context,
                name: "ShopPurchaseRecord"
            ),
            hasLoaded: true
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Shop route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Shop"
            )
            return []
        }
    }
}
