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
    var onCancel: (() -> Void)? = nil
    var onPetSaved: ((Pet) -> Void)? = nil

    @State private var memberCreationSessionId = UUID()

    var body: some View {
        MemberCardCreationView(
            kind: .pet,
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved,
            recoverySessionId: memberCreationSessionId
        )
    }
}

#Preview {
    AddPetWizardView(onComplete: {})
        .modelContainer(SharedModelContainer.make())
}
