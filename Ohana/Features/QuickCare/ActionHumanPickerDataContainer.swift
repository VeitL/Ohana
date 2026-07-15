//
//  ActionHumanPickerDataContainer.swift
//  Ohana
//
//  Deferred, bounded Human loading for draft-scoped action attribution.
//

import SwiftData
import SwiftUI

/// Reading the local Human supplies only the initial default. Picking another
/// Human changes this action draft and never switches the device-wide member.
struct QuickCareActionHumanPickerContainer: View {
    let role: ActionHumanRole
    var tint: Color = .goPrimary
    var compact = true

    @Binding private var selectedHumanID: UUID?
    @Binding private var requiresSelection: Bool
    @Environment(\.modelContext) private var modelContext

    init(
        selectedHumanID: Binding<UUID?>,
        requiresSelection: Binding<Bool>,
        role: ActionHumanRole = .executor,
        tint: Color = .goPrimary,
        compact: Bool = true
    ) {
        _selectedHumanID = selectedHumanID
        _requiresSelection = requiresSelection
        self.role = role
        self.tint = tint
        self.compact = compact
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: ActionHumanPickerRouteData(),
            loadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                ActionHumanPickerRouteData(
                    humans: ActionHumanOptionLoader.load(context: modelContext),
                    hasLoaded: true
                )
            }
        ) { data in
            LoadedActionHumanPicker(
                humans: data.humans,
                isLoaded: data.hasLoaded,
                selectedHumanID: $selectedHumanID,
                requiresSelection: $requiresSelection,
                role: role,
                tint: tint,
                compact: compact
            )
        }
    }
}

private struct LoadedActionHumanPicker: View {
    let humans: [ActionHumanOption]
    let isLoaded: Bool
    let role: ActionHumanRole
    let tint: Color
    let compact: Bool

    @Binding var selectedHumanID: UUID?
    @Binding var requiresSelection: Bool
    @AppStorage("currentActiveHumanId") private var currentLocalHumanIDRaw = ""

    init(
        humans: [ActionHumanOption],
        isLoaded: Bool,
        selectedHumanID: Binding<UUID?>,
        requiresSelection: Binding<Bool>,
        role: ActionHumanRole,
        tint: Color,
        compact: Bool
    ) {
        self.humans = humans
        self.isLoaded = isLoaded
        _selectedHumanID = selectedHumanID
        _requiresSelection = requiresSelection
        self.role = role
        self.tint = tint
        self.compact = compact
    }

    var body: some View {
        Group {
            if isLoaded {
                ActionHumanPicker(
                    humans: humans,
                    currentLocalHumanID: currentLocalHumanID,
                    selectedHumanID: $selectedHumanID,
                    role: role,
                    tint: tint,
                    compact: compact
                )
            }
        }
        .onAppear(perform: reconcileSelectionRequirement)
        .onChange(of: selectionContext) { _, _ in
            reconcileSelectionRequirement()
        }
    }

    private var currentLocalHumanID: UUID? {
        UUID(uuidString: currentLocalHumanIDRaw)
    }

    private var selectionContext: ActionHumanPickerSelectionContext {
        ActionHumanPickerSelectionContext(
            humanIDs: humans.map(\.id),
            deceasedHumanIDs: humans.filter(\.isDeceased).map(\.id),
            isLoaded: isLoaded,
            currentLocalHumanID: currentLocalHumanID,
            selectedHumanID: selectedHumanID
        )
    }

    private func reconcileSelectionRequirement() {
        guard isLoaded else {
            if !requiresSelection {
                requiresSelection = true
            }
            return
        }
        let resolvedID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: selectedHumanID,
            currentLocalHumanID: currentLocalHumanID,
            humans: humans
        )
        if resolvedID != selectedHumanID {
            selectedHumanID = resolvedID
        }
        let isRequired = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans).count > 1 &&
            resolvedID == nil
        if isRequired != requiresSelection {
            requiresSelection = isRequired
        }
    }
}

private struct ActionHumanPickerRouteData {
    var humans: [ActionHumanOption] = []
    var hasLoaded = false
}

private nonisolated struct ActionHumanPickerSelectionContext: Hashable {
    let humanIDs: [UUID]
    let deceasedHumanIDs: [UUID]
    let isLoaded: Bool
    let currentLocalHumanID: UUID?
    let selectedHumanID: UUID?
}
