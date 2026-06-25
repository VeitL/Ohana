import SwiftData
import SwiftUI

struct BountyBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @State private var careLedgerEntries: [FamilyCareLedgerEntry] = []
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        BountyBoardContentView(
            humans: humans,
            pets: pets,
            careLedgerEntries: careLedgerEntries
        )
        .onAppear {
            scheduleDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || careLedgerEntries.isEmpty else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            careLedgerEntries = FamilyCareLedgerEntry.fetchPetEntries(
                since: FamilyCareLedgerEntry.weekStart(),
                context: modelContext
            )
            dataLoadTask = nil
        }
    }
}
