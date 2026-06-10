// Audit fixture: every marked line must trigger the named audit-accessibility rule.
// Note: the icon-only-button pattern anchors on end-of-line, so that line must
// not carry a trailing comment.
import SwiftUI

struct A11yBadFixture: View {
    var body: some View {
        VStack {
            // rule: icon-only-button (next line)
            Button { Image(systemName: "xmark") }
            Image(systemName: "gearshape") // rule: image-needs-label-or-hidden
            Circle().frame(width: 20, height: 20) // rule: small-hit-target
            Text("tiny").font(.system(size: 11)) // rule: fixed-font-size
            // status-color-only — rule: color-only-meaning
        }
    }
}
