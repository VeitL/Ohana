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
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var ledgerEvents: [CareLedgerEvent]

    var onClose: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)?

    init(
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.date(byAdding: .day, value: -7, to: Date())
            ?? Date()
        _ledgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= weekStart
            },
            sort: \.occurredAt,
            order: .reverse
        )
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentCoconutShop = onPresentCoconutShop
    }

    var body: some View {
        DailyStreakDetailView(
            pets: pets,
            humans: humans,
            ledgerEvents: ledgerEvents,
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            onPresentCoconutShop: onPresentCoconutShop
        )
    }
}
