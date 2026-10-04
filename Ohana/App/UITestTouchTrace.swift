#if DEBUG
import ObjectiveC
import OSLog
import SwiftUI
import UIKit

/// Opt-in diagnostics. Window observation adds work around dispatch and can
/// perturb timing; action-boundary observation leaves dispatch and bindings alone.
@MainActor
enum OhanaUITestTouchTrace {
    private static let logger = Logger(subsystem: "com.guanchen.li.Ohana", category: "UITestTouchTrace")
    private static var touchObservationInstalled = false
    private static var controlStateObservationEnabled = false
    private static var actionBoundaryObservationEnabled = false

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
        if arguments.contains("-OHANA_UI_TEST_TRACE_ACTION_BOUNDARIES"), !actionBoundaryObservationEnabled {
            actionBoundaryObservationEnabled = true
            logger.notice("Action-boundary observation enabled; no window hook or binding wrapper")
        }
    }

    static func record(_ message: @autoclosure () -> String) {
        guard touchObservationInstalled || controlStateObservationEnabled || actionBoundaryObservationEnabled else { return }
        let value = message()
        logger.notice("\(value, privacy: .public)")
    }

    /// Forward the real setter once. Unobserved controls retain their original
    /// binding; the diagnostic never substitutes an expected state or action.
    static func observingToggle(_ binding: Binding<Bool>, identifier: String) -> Binding<Bool> {
        // The action-boundary diagnostic must keep the original native binding.
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
        // Read only UIKit's actual recipient and public state. A second hitTest
        // would re-enter input routing and could disturb the observed event.
        // Dispatch the original event exactly once.
        var samples: [(
            touch: UITouch,
            phase: String,
            timestamp: TimeInterval,
            point: CGPoint,
            touchType: Int,
            assignedGestures: String,
            recipient: UIView?,
            recipientPath: String
        )] = []
        for touch in event.allTouches ?? [] {
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled else { continue }
            let point = touch.location(in: self)
            let recipient = touch.view
            let recipientPath = ohana_viewPath(recipient)
            samples.append((
                touch,
                String(describing: touch.phase.rawValue),
                touch.timestamp,
                point,
                touch.type.rawValue,
                (touch.gestureRecognizers ?? []).map {
                    "\(type(of: $0))(state=\($0.state.rawValue),enabled=\($0.isEnabled))"
                }.joined(separator: ","),
                recipient,
                recipientPath
            ))
        }
        ohana_observeTouchEvent(event)
        for (touch, phase, timestamp, point, touchType, assignedGestures, recipient, recipientPath) in samples {
            let receiver = touch.view.map { String(describing: type(of: $0)) } ?? "nil"
            let recipientPathAfter = ohana_viewPath(recipient)
            // Unified logging can truncate this diagnostic's long message.
            // Keep the real recipient and native state ahead of optional
            // gesture details so a crowded Form still identifies the input.
            OhanaUITestTouchTrace.record(
                "touch=\(ObjectIdentifier(touch)) phase=\(phase) timestamp=\(timestamp) "
                    + "point=\(point) type=\(touchType) "
                    + "window=\(ObjectIdentifier(self)) receiverAfter=\(receiver) "
                    + "recipientPathBefore=\(recipientPath) recipientPathAfter=\(recipientPathAfter) "
                    + "assignedGesturesBefore=[\(assignedGestures)]"
            )
        }
    }

    func ohana_viewPath(_ view: UIView?) -> String {
        var nodes: [String] = []
        var current = view
        while let node = current {
            let identifier = node.accessibilityIdentifier ?? ""
            var state = (node as? UISwitch).map { " isOn=\($0.isOn)" } ?? ""
            if let control = node as? UIControl {
                state += " enabled=\(control.isEnabled) tracking=\(control.isTracking) inside=\(control.isTouchInside) highlighted=\(control.isHighlighted)"
            }
            if let field = node as? UITextField {
                state += " editing=\(field.isEditing) firstResponder=\(field.isFirstResponder)"
            }
            if let scroll = node as? UIScrollView {
                state += " tracking=\(scroll.isTracking) dragging=\(scroll.isDragging) decelerating=\(scroll.isDecelerating) delayBegan=\(scroll.delaysContentTouches) cancelContent=\(scroll.canCancelContentTouches)"
            }
            let gestures = (node.gestureRecognizers ?? []).map {
                "\(type(of: $0))(state=\($0.state.rawValue),enabled=\($0.isEnabled),cancel=\($0.cancelsTouchesInView),delayBegan=\($0.delaysTouchesBegan),delayEnded=\($0.delaysTouchesEnded))"
            }.joined(separator: ",")
            if !gestures.isEmpty { state += " gestures=[\(gestures)]" }
            nodes.append("\(type(of: node))[id=\(identifier)]\(state)")
            current = node.superview
        }
        return nodes.joined(separator: " < ")
    }
}
#endif
