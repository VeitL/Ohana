import SwiftUI

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    var presentationStyle: MemberCreationPresentationStyle = .standard

    var body: some View {
        AddHumanWizardContentView(
            onComplete: onComplete,
            onCancel: onCancel,
            onHumanSaved: onHumanSaved,
            presentationStyle: presentationStyle
        )
    }
}
