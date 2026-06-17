import SwiftData
import SwiftUI

struct RouteFirstFrameGoodRouteContainer: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(initialData: [Pet](), load: {
            let descriptor = FetchDescriptor<Pet>()
            return (try? modelContext.fetch(descriptor)) ?? [] // route-first-frame: allow deferred-fetch
        }) { pets in
            Text("\(pets.count)")
        }
    }
}
