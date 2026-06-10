//
//  AddHumanWizardView.swift
//  Ohana
//
//  Thin compatibility wrapper around the shared member creation flow.
//

import SwiftUI

struct AddHumanWizardContentView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)? = nil
    var onHumanSaved: ((Human) -> Void)? = nil

    @State private var memberCreationSessionId = UUID()

    var body: some View {
        MemberCardCreationView(
            kind: .human,
            onComplete: onComplete,
            onCancel: onCancel,
            onHumanSaved: onHumanSaved,
            recoverySessionId: memberCreationSessionId
        )
    }
}
