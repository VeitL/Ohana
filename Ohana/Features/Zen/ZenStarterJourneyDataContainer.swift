//
//  ZenStarterJourneyDataContainer.swift
//  Ohana
//
//  Bounded SwiftData lookup for the Zen starter-profile editor route.
//

import SwiftData
import SwiftUI

@MainActor
struct ZenStarterHumanProfileEditorDataContainer: View {
    @Environment(\.modelContext) private var modelContext
    let humanID: UUID
    let onSaved: () -> Void

    init(humanID: UUID, onSaved: @escaping () -> Void) {
        self.humanID = humanID
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            RouteFirstFrameDeferredLoad(
                initialData: ZenStarterHumanProfileRouteData(),
                loadDelayMilliseconds: 24,
                shouldLoad: { !$0.hasLoaded },
                load: {
                    ZenStarterHumanProfileRouteData.load(
                        humanID: humanID,
                        from: modelContext
                    )
                }
            ) { routeData in
                if let human = routeData.human {
                    HumanBasicInfoDetailView(
                        human: human,
                        startsEditing: true,
                        requiresStarterProfileFields: true,
                        onSave: onSaved,
                        onClose: onSaved
                    )
                } else {
                    ProgressView()
                        .onAppear {
                            if routeData.hasLoaded {
                                onSaved()
                            }
                        }
                }
            }
        }
    }
}

private struct ZenStarterHumanProfileRouteData {
    var human: Human?
    var hasLoaded = false

    static func load(
        humanID: UUID,
        from context: ModelContext
    ) -> ZenStarterHumanProfileRouteData {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == humanID
            }
        )
        descriptor.fetchLimit = 1

        do {
            return ZenStarterHumanProfileRouteData(
                human: try context.fetch(descriptor).first, // route-first-frame: allow deferred-fetch
                hasLoaded: true
            )
        } catch {
            OhanaLog.warning(
                "Zen starter Human fetch failed: \(error.localizedDescription)",
                category: "Zen"
            )
            return ZenStarterHumanProfileRouteData(hasLoaded: true)
        }
    }
}
