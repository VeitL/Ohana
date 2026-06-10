// Audit fixture: policy-gated runtime work; audit-runtime-guardrails must report
// zero warnings. Mentioning AppWorkloadPolicy marks the file as policy-aware, which
// is exactly the gating behavior the audit rewards.
import SwiftUI

struct RuntimeGoodFixture: View {
    @ObservedObject var policy: AppWorkloadPolicy = .shared

    var body: some View {
        Group {
            if policy.isForeground {
                TimelineView(.animation) { _ in
                    Circle().scaleEffect(1.05)
                }
            } else {
                Circle()
            }
        }
    }
}
