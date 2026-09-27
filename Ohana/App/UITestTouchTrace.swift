#if DEBUG
import ObjectiveC
import OSLog
import UIKit

/// Opt-in observation of received touches. Input synthesis and dispatch stay unchanged.
@MainActor
enum OhanaUITestTouchTrace {
    private static let logger = Logger(subsystem: "com.guanchen.li.Ohana", category: "UITestTouchTrace")
    private static var installed = false

    static func installIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard !installed,
              arguments.contains("-OHANA_UI_TESTS"),
              arguments.contains("-OHANA_UI_TEST_TRACE_TOUCHES"),
              let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let observation = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.ohana_observeTouchEvent(_:))) else {
            return
        }
        method_exchangeImplementations(original, observation)
        installed = true
        logger.notice("Received-touch observation installed")
    }

    static func record(_ message: String) {
        guard installed else { return }
        logger.notice("\(message, privacy: .public)")
    }
}

private extension UIWindow {
    @objc dynamic func ohana_observeTouchEvent(_ event: UIEvent) {
        // Capture values before UIKit can update them, but dispatch the original
        // event exactly once before formatting or logging the observation.
        let samples = (event.allTouches ?? []).compactMap { touch -> (UITouch, Int, TimeInterval, CGPoint)? in
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled else { return nil }
            return (touch, touch.phase.rawValue, touch.timestamp, touch.location(in: self))
        }
        ohana_observeTouchEvent(event)
        for (touch, phase, timestamp, point) in samples {
            let receiver = touch.view.map { String(describing: type(of: $0)) } ?? "nil"
            OhanaUITestTouchTrace.record(
                "touch=\(ObjectIdentifier(touch)) phase=\(phase) timestamp=\(timestamp) "
                    + "point=\(point) window=\(ObjectIdentifier(self)) receiver=\(receiver)"
            )
        }
    }
}
#endif
