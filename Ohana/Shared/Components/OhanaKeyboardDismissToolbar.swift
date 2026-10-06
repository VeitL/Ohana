import SwiftUI

private struct OhanaKeyboardDismissToolbar: ViewModifier {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n(appLanguage).done) { GoKeyboard.dismiss() }
                    .accessibilityIdentifier("ohana-keyboard-dismiss-action")
            }
        }
    }
}

extension View {
    /// Ends editing without submitting, saving, or dismissing the surrounding editor.
    func ohanaKeyboardDismissToolbar() -> some View {
        modifier(OhanaKeyboardDismissToolbar())
    }
}
