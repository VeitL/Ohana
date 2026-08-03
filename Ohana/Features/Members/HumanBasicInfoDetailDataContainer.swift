import SwiftUI

struct HumanBasicInfoDetailView: View {
    let human: Human
    var startsEditing = false
    var requiresStarterProfileFields = false
    var onSave: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HumanBasicInfoDetailContentView(
            human: human,
            startsEditing: startsEditing,
            requiresStarterProfileFields: requiresStarterProfileFields,
            onSave: onSave,
            onClose: onClose
        )
    }
}
