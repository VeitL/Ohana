//
//  AddPetWizardView.swift
//  Ohana
//
//  Thin compatibility wrapper around the shared member creation flow.
//

import SwiftData
import SwiftUI

struct AddPetWizardContentView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var presentationStyle: MemberCreationPresentationStyle = .standard
    var onHomeJoinHandoffPreflight: (() -> Void)?
    var onHomeJoinHandoffStarted: (() -> Void)?
    var onHomeJoinHandoffEnded: (() -> Void)?

    @State private var memberCreationSessionId = UUID()

    var body: some View {
        MemberCardCreationView(
            kind: .pet,
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved,
            recoverySessionId: memberCreationSessionId,
            presentationStyle: presentationStyle,
            onHomeJoinHandoffPreflight: onHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: onHomeJoinHandoffStarted,
            onHomeJoinHandoffEnded: onHomeJoinHandoffEnded
        )
    }
}

#Preview {
    if let modelContainer = try? SharedModelContainer.makePreview() {
        AddPetWizardView(onComplete: {})
            .modelContainer(modelContainer)
    }
}
