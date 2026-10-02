import SwiftData
import SwiftUI

/// Resolve only the recorded participants and hand value data to the views.
struct WalkExecutorNamesDataContainer<Content: View>: View {
    let executorIds: [String]
    private let content: ([UUID: String]) -> Content
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var memberRevision = 0

    init(executorIds: [String], @ViewBuilder content: @escaping ([UUID: String]) -> Content) {
        self.executorIds = executorIds
        self.content = content
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: [UUID: String]?.none,
            refreshToken: RefreshToken(executorIds: executorIds, memberRevision: memberRevision),
            shouldLoad: { $0 == nil },
            load: loadNames
        ) { names in
            if let names {
                content(names)
            } else {
                ProgressView().frame(maxWidth: .infinity).accessibilityHidden(true)
            }
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            guard revision.lastCommand?.feature == "members" else { return }
            memberRevision = revision.value
        }
    }

    private func loadNames() -> [UUID: String]? {
        do {
            let walkers = try modelContext.fetch(WalkExecutorDisplay.descriptor(for: executorIds)) // route-first-frame: allow deferred-fetch
            return Dictionary(uniqueKeysWithValues: walkers.map { ($0.id, $0.name) })
        } catch {
            OhanaLog.warning("Walk executor names could not be read: \(error.localizedDescription)", category: "Walks")
            return nil
        }
    }

    private struct RefreshToken: Hashable {
        let executorIds: [String]
        let memberRevision: Int
    }
}
