// Audit fixture: every line below must trigger the named audit-ui-v4 rule.
// This file is never compiled; it exists so scripts/tests/run-audit-fixture-tests.sh
// can prove the audit still catches each pattern.
import SwiftUI

struct UiV4BadFixture: View {
    var body: some View {
        VStack {
            ArkBackgroundView() // rule: background
            Text("hello").foregroundStyle(.primary) // rule: system-text-color
            Text("hi").foregroundColor(.white) // rule: hardcoded-white-black
            Text("lime").foregroundStyle(Color.goLime) // rule: direct-go-lime
            RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial) // rule: material
            Text("card").shadow(radius: 4) // rule: shadow
            Button("tap") {}.buttonStyle(.plain) // rule: plain-button
        }
        .sheet(isPresented: .constant(false)) {
            Text("sheet").presentationDetents([.large]) // rule: regular-sheet
        }
        .sheet(isPresented: .constant(false)) {
            Text("sized").presentationDetents([.height(340)]) // rule: hardcoded-detent-height
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {} // rule: hardcoded-motion
        }
    }

    var rawInput: some View {
        TextField("name", text: .constant("")) // rule: raw-textfield
            .background(RoundedRectangle(cornerRadius: 18)) // rule: hardcoded-corner-radius
    }
}
