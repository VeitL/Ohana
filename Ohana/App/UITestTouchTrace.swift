#if DEBUG
import ObjectiveC
import OSLog
import SwiftUI
import UIKit

/// Opt-in observation of received touches. Input synthesis and dispatch stay unchanged.
@MainActor
enum OhanaUITestTouchTrace {
    private static let logger = Logger(subsystem: "com.guanchen.li.Ohana", category: "UITestTouchTrace")
    private static var touchObservationInstalled = false
    private static var controlStateObservationEnabled = false

    static func installIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-OHANA_UI_TESTS") else { return }

        if arguments.contains("-OHANA_UI_TEST_TRACE_TOUCHES"), !touchObservationInstalled,
           let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
           let observation = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.ohana_observeTouchEvent(_:))) {
            method_exchangeImplementations(original, observation)
            touchObservationInstalled = true
            logger.notice("Received-touch observation installed")
        }

        if arguments.contains("-OHANA_UI_TEST_TRACE_CONTROL_STATE"), !controlStateObservationEnabled {
            controlStateObservationEnabled = true
            logger.notice("Control-state observation enabled")
        }
    }

    static func record(_ message: String) {
        guard touchObservationInstalled || controlStateObservationEnabled else { return }
        logger.notice("\(message, privacy: .public)")
    }

    /// Forward the real setter once. Unobserved controls retain their original
    /// binding; the diagnostic never substitutes an expected state or action.
    static func observingToggle(_ binding: Binding<Bool>, identifier: String) -> Binding<Bool> {
        guard touchObservationInstalled || controlStateObservationEnabled else { return binding }
        return Binding(
            get: { binding.wrappedValue },
            set: { value, transaction in
                record("\(identifier) setter requested=\(value) previous=\(binding.wrappedValue)")
                binding.transaction(transaction).wrappedValue = value
                record("\(identifier) setter returned=\(binding.wrappedValue)")
            }
        )
    }
}

private extension UIWindow {
    @objc dynamic func ohana_observeTouchEvent(_ event: UIEvent) {
        // Capture the hit-test and touch-recipient paths before UIKit updates
        // the event, then dispatch the original event exactly once.
        var samples: [(
            touch: UITouch,
            phase: String,
            timestamp: TimeInterval,
            point: CGPoint,
            recipientPath: String,
            hitTestPath: String
        )] = []
        for touch in event.allTouches ?? [] {
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled else { continue }
            let point = touch.location(in: self)
            let recipientPath = ohana_viewPath(touch.view)
            let hitTestPath = ohana_viewPath(hitTest(point, with: event))
            samples.append((
                touch,
                String(describing: touch.phase.rawValue),
                touch.timestamp,
                point,
                recipientPath,
                hitTestPath
            ))
        }
        ohana_observeTouchEvent(event)
        for (touch, phase, timestamp, point, recipientPath, hitTestPath) in samples {
            let receiver = touch.view.map { String(describing: type(of: $0)) } ?? "nil"
            OhanaUITestTouchTrace.record(
                "touch=\(ObjectIdentifier(touch)) phase=\(phase) timestamp=\(timestamp) "
                    + "point=\(point) window=\(ObjectIdentifier(self)) receiverAfter=\(receiver) "
                    + "recipientPathBefore=\(recipientPath) hitTestPathBefore=\(hitTestPath)"
            )
        }
    }

    func ohana_viewPath(_ view: UIView?) -> String {
        var nodes: [String] = []
        var current = view
        while let node = current {
            let identifier = node.accessibilityIdentifier ?? ""
            let controlState = (node as? UISwitch).map { " isOn=\($0.isOn)" } ?? ""
            nodes.append("\(type(of: node))[id=\(identifier)]\(controlState)")
            current = node.superview
        }
        return nodes.joined(separator: " < ")
    }
}
#endif
