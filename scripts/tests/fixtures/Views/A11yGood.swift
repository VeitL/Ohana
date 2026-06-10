// Audit fixture: accessible view; audit-accessibility must report zero warnings.
import SwiftUI

struct A11yGoodFixture: View {
    var body: some View {
        VStack {
            Image(systemName: "gearshape").accessibilityLabel(Text("Settings"))
            Image(systemName: "sparkles").accessibilityHidden(true)
            Circle().frame(width: 44, height: 44)
            Text("body copy").font(OhanaFont.body)
        }
    }
}
