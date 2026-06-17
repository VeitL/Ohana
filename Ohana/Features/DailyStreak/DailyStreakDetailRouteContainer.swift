import SwiftData
import SwiftUI

struct AppStreakDetailRouteContainer: View {
    let onClose: () -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void
    let onPresentCoconutShop: (ShopItem.ShopCategory) -> Void

    var body: some View {
        DailyStreakDetailRouteContainer(
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            onPresentCoconutShop: onPresentCoconutShop
        )
    }
}

struct DailyStreakDetailRouteContainer: View {
    @Environment(\.modelContext) private var modelContext

    var onClose: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)?

    init(
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentCoconutShop = onPresentCoconutShop
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: DailyStreakRouteData(),
            loadDelayMilliseconds: 140,
            shouldLoad: { !$0.hasLoaded },
            load: { DailyStreakRouteData.load(from: modelContext) }
        ) { data in
            DailyStreakDetailView(
                pets: data.pets,
                humans: data.humans,
                ledgerEvents: data.ledgerEvents,
                onClose: onClose,
                onPresentCoconutLog: onPresentCoconutLog,
                onPresentCoconutShop: onPresentCoconutShop
            )
        }
    }
}

private struct DailyStreakRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var ledgerEvents: [CareLedgerEvent] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> DailyStreakRouteData {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.date(byAdding: .day, value: -7, to: Date())
            ?? Date()

        return DailyStreakRouteData(
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            ledgerEvents: fetch(
                FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.occurredAt >= weekStart
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                ),
                context: context,
                name: "CareLedgerEvent"
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
                "Daily streak route data fetch failed for \(name): \(error.localizedDescription)",
                category: "DailyStreak"
            )
            return []
        }
    }
}
