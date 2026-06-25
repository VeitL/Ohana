import SwiftData
import SwiftUI

struct CoHealthDashboardFullView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var snapshot = CoHealthDashboardSnapshot.empty
    @State private var snapshotLoadTask: Task<Void, Never>?

    var body: some View {
        CoHealthDashboardFullContentView(
            human: human,
            snapshot: snapshot
        )
        .onAppear {
            scheduleSnapshotLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleSnapshotLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            snapshotLoadTask?.cancel()
            snapshotLoadTask = nil
        }
    }

    private func scheduleSnapshotLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        guard snapshotLoadTask == nil else { return }
        snapshotLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            snapshot = CoHealthDashboardSnapshot.load(human: human, context: modelContext)
            snapshotLoadTask = nil
        }
    }
}
