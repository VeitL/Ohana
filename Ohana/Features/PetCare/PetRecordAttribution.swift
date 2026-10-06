import SwiftData
import SwiftUI

/// Resolve the existing local default even while the optional picker is collapsed.
private struct PetRecordAttributionModifier: ViewModifier {
    @Binding var selectedHumanID: UUID?
    @Binding var requiresSelection: Bool
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var currentLocalHumanIDRaw = ""
    @State private var humans: [ActionHumanOption] = []
    @State private var hasLoaded = false

    func body(content: Content) -> some View {
        content
            .task(id: currentLocalHumanIDRaw) {
                requiresSelection = true
                humans = ActionHumanOptionLoader.load(context: modelContext)
                hasLoaded = true
                reconcileSelection()
            }
            .onChange(of: selectedHumanID) { _, _ in reconcileSelection() }
    }

    private func reconcileSelection() {
        guard hasLoaded else { return }
        let resolvedID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: selectedHumanID,
            currentLocalHumanID: UUID(uuidString: currentLocalHumanIDRaw),
            humans: humans
        )
        selectedHumanID = resolvedID
        requiresSelection = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans).count > 1 && resolvedID == nil
    }
}

extension View {
    func petRecordAttribution(selectedHumanID: Binding<UUID?>, requiresSelection: Binding<Bool>) -> some View {
        modifier(PetRecordAttributionModifier(selectedHumanID: selectedHumanID, requiresSelection: requiresSelection))
    }
}
