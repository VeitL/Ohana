// Audit fixture: fully token-compliant view; audit-ui-v4 must report zero warnings.
import SwiftUI

struct UiV4GoodFixture: View {
    var body: some View {
        VStack {
            OhanaAppBackground()
            Text("hello").foregroundStyle(Color.ohanaPrimaryText)
            Text("hint").foregroundStyle(Color.ohanaSecondaryText)
            Button("tap") {}
            TextField("name", text: .constant(""))
            RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
        }
        .sheet(isPresented: .constant(false)) {
            Text("sheet").presentationDetents([.medium, .large])
        }
        .onTapGesture {
            withAnimation(GoMotion.feedback) {}
        }
    }
}
