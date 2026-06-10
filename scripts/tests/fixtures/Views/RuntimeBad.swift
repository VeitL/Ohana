// Audit fixture: every marked line must trigger the named audit-runtime-guardrails rule.
// This file must NOT mention the workload-policy type by name anywhere except this
// sentence's regex-safe paraphrase, because the audit skips timer rules in files
// that already reference the policy.
import CoreLocation
import SwiftUI
import UIKit

final class RuntimeBadFixture: NSObject {
    let manager = CLLocationManager() // rule: location-manager

    func start() {
        manager.allowsBackgroundLocationUpdates = true // rule: background-location
        manager.requestAlwaysAuthorization() // rule: always-location-request
        UIApplication.shared.isIdleTimerDisabled = true // rule: idle-timer
        _ = Timer.publish(every: 1, on: .main, in: .common) // rule: raw-timer-publisher
    }
}

struct RuntimeBadFixtureView: View {
    var body: some View {
        TimelineView(.animation) { _ in // rule: timeline-animation
            Circle().scaleEffect(1.1)
        }
        .animation(.linear.repeatForever(autoreverses: true), value: true) // rule: repeat-forever
    }
}
