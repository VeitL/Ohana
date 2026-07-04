import SwiftData
import SwiftUI

struct RouteFirstFrameGoodRouteContainer: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(initialData: [PersistentIdentifier](), load: {
            let actor = RouteFirstFrameGoodRouteDataActor(modelContainer: modelContext.container)
            return (try? await actor.loadPetIDs()) ?? []
        }) { petIDs in
            Text("\(petIDs.count)")
        }
    }
}

@ModelActor
private actor RouteFirstFrameGoodRouteDataActor {
    func loadPetIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<Pet>()
        return try modelContext.fetchIdentifiers(descriptor)
    }
}
