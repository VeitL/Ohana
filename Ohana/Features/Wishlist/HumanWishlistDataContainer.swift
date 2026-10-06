import SwiftData
import SwiftUI

struct HumanWishlistView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = HumanWishlistRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        HumanWishlistContentView(
            human: human,
            myItems: routeData.items
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
        let humanID = human.id.uuidString
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = HumanWishlistRouteData.load(humanID: humanID, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct HumanWishlistRouteData {
    var items: [WishlistItem] = []
    var hasLoaded = false

    static func load(humanID: String, from context: ModelContext) -> HumanWishlistRouteData {
        let descriptor = FetchDescriptor<WishlistItem>(
            predicate: #Predicate<WishlistItem> { $0.creatorId == humanID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return HumanWishlistRouteData(
                items: try context.fetch(descriptor), // route-first-frame: allow deferred-fetch
                hasLoaded: true
            )
        } catch {
            OhanaLog.warning(
                "Human wishlist route data fetch failed: \(error.localizedDescription)",
                category: "Wishlist"
            )
            return HumanWishlistRouteData(hasLoaded: true)
        }
    }
}
