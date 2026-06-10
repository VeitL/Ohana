import SwiftUI

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)? = nil
    var onHumanSaved: ((Human) -> Void)? = nil

    var body: some View {
        AddHumanWizardContentView(
            onComplete: onComplete,
            onCancel: onCancel,
            onHumanSaved: onHumanSaved
        )
    }
}
