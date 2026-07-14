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
            Button("tap") {}
            OhanaMotionScene(role: .sheet) { Text("custom sheet") } // rule: native-custom-sheet-scene
        }
        .sheet(isPresented: .constant(false)) {
            Text("sheet").presentationDetents([.large])
        }
        .sheet(isPresented: .constant(false)) {
            Text("sized").presentationDetents([.height(340)]) // rule: hardcoded-detent-height
        }
        .presentationBackground(.clear) // rule: native-sheet-chrome
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {} // rule: hardcoded-motion
        }
    }

    var rawInput: some View {
        TextField("name", text: .constant(""))
            .background(RoundedRectangle(cornerRadius: 18)) // rule: hardcoded-corner-radius
    }

    var searchField: some View { Text("custom search") } // rule: native-custom-search
    var customToggle: some View { shopTogglePill(isOn: true) } // rule: native-manual-toggle
    var customSegment: some View { plantViewSwitcherButton(.list) } // rule: native-custom-segment
    var customSettings: some View { SettingsSectionCard() } // rule: native-settings-card
    var inlinePresentation: some View { OhanaInlinePageRouteHost(routeID: "bad", onClose: {}) { _ in Text("bad") } } // rule: native-inline-presentation
    var legacyOverlay: some View { inlineFeedSheetOverlay(.manual) } // rule: native-legacy-overlay-call
    var inlinePopupMode: some View { AddPetMedicationSheet(pet: pet, isInlinePopup: true, onClose: {}, onSaved: {}) } // rule: native-inline-popup-mode
}
