import SwiftData
import SwiftUI

struct RouteFirstFrameBadRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pets: [Pet]
    @Query private var humans: [Human]
    @Query private var reminders: [Reminder]
    @Query private var events: [Event]

    var body: some View {
        let descriptor = FetchDescriptor<Pet>()
        let pets = (try? modelContext.fetch(descriptor)) ?? []
        let balance = rewards.currentHumanBalance(context: modelContext)
        Text("\(pets.count)")
        Text("\(balance)")
    }
}

@ModelActor
private actor RouteFirstFrameBadRouteDataActor {
    func loadPets() throws -> [Pet] {
        try modelContext.fetch(FetchDescriptor<Pet>())
    }
}
