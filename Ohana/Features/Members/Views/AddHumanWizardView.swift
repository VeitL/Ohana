//
//  AddHumanWizardView.swift
//  Ohana
//
//  Thin compatibility wrapper around the shared member creation flow.
//

import SwiftUI

struct AddHumanWizardContentView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    var presentationStyle: MemberCreationPresentationStyle = .standard
    var onHomeJoinHandoffPreflight: (() -> Void)?
    var onHomeJoinHandoffStarted: (() -> Void)?
    var onHomeJoinHandoffEnded: (() -> Void)?

    @State private var memberCreationSessionId = UUID()

    var body: some View {
        MemberCardCreationView(
            kind: .human,
            onComplete: onComplete,
            onCancel: onCancel,
            onHumanSaved: onHumanSaved,
            recoverySessionId: memberCreationSessionId,
            presentationStyle: presentationStyle,
            onHomeJoinHandoffPreflight: onHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: onHomeJoinHandoffStarted,
            onHomeJoinHandoffEnded: onHomeJoinHandoffEnded
        )
    }
}
