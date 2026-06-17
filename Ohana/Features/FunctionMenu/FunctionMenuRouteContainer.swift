import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = FunctionMenuRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let destination: FMDest
    @Binding var parentPath: NavigationPath

    var body: some View {
        FunctionMenuDestinationRouter(
            destination: destination,
            parentPath: $parentPath,
            pets: routeData.pets,
            humans: routeData.humans,
            plants: []
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
            routeData = FunctionMenuRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct FunctionMenuRootRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = FunctionMenuRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    var body: some View {
        FunctionMenuRootView(
            appLanguage: appLanguage,
            onSelect: onSelect,
            onClose: onClose,
            pets: routeData.pets,
            humans: routeData.humans
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
            routeData = FunctionMenuRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct FunctionMenuRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> FunctionMenuRouteData {
        FunctionMenuRouteData(
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.name)]),
                context: context,
                name: "Human"
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
                "Function menu route data fetch failed for \(name): \(error.localizedDescription)",
                category: "FunctionMenu"
            )
            return []
        }
    }
}
