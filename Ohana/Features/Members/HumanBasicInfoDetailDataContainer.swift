import SwiftUI

struct HumanBasicInfoDetailView: View {
    let human: Human
    var startsEditing = false
    var onSave: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HumanBasicInfoDetailContentView(
            human: human,
            startsEditing: startsEditing,
            onSave: onSave,
            onClose: onClose
        )
    }
}
