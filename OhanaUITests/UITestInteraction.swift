import XCTest

/// Shared interaction preconditions. A successful tap means one input was sent;
/// the journey must separately assert its destination or committed result.
enum UITestInteraction {
    static func wait(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            if condition() { return true }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(min(0.2, remaining)))
        } while true
    }

    @MainActor
    static func tap(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        // Semantic taps resolve their own hit point. Requiring two extra frame
        // snapshots can exhaust the deadline on CI before a ready control is tapped.
        guard wait(timeout: timeout, condition: { element.exists && element.isEnabled && element.isHittable }) else {
            recordFailure("Semantic tap target did not become ready", element: element)
            return false
        }
        element.tap()
        return true
    }

    /// Explicit frame interaction for native menus whose AX activation point
    /// cannot be queried. Never use this as an implicit semantic-tap fallback.
    @MainActor
    static func tapFrame(
        _ element: XCUIElement,
        in app: XCUIApplication? = nil,
        offset: CGVector = CGVector(dx: 0.5, dy: 0.5),
        timeout: TimeInterval,
        usesPointerClick: Bool = false
    ) -> Bool {
        guard offset.dx.isFinite, offset.dy.isFinite,
              (0 ... 1).contains(offset.dx), (0 ... 1).contains(offset.dy),
              let frame = stableFrame(of: element, in: app, timeout: timeout) else {
            recordFailure("Frame tap target did not stabilize", element: element)
            return false
        }
        let point = CGPoint(x: frame.minX + frame.width * offset.dx, y: frame.minY + frame.height * offset.dy)
        if let app, !app.frame.contains(point) { return false }
        let coordinate: XCUICoordinate = if let app {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY))
        } else {
            element.coordinate(withNormalizedOffset: offset)
        }
        if usesPointerClick, XCUIDevice.shared.supportsPointerInteraction {
            coordinate.click()
        } else {
            coordinate.tap()
        }
        return true
    }

    @MainActor
    static func stableFrame(
        of element: XCUIElement,
        in app: XCUIApplication? = nil,
        timeout: TimeInterval,
        requiresHittable: Bool = false
    ) -> CGRect? {
        var previousFrame: CGRect?
        var result: CGRect?
        let ready = wait(timeout: timeout) {
            guard app.map({ $0.state == .runningForeground }) ?? true,
                  element.exists, element.isEnabled else {
                previousFrame = nil
                return false
            }
            let frame = element.frame
            guard isUsable(frame),
                  app.map({ $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }) ?? true,
                  !requiresHittable || element.isHittable else {
                previousFrame = nil
                return false
            }
            defer { previousFrame = frame }
            guard let previousFrame,
                  abs(previousFrame.minX - frame.minX) <= 0.75,
                  abs(previousFrame.minY - frame.minY) <= 0.75,
                  abs(previousFrame.width - frame.width) <= 0.75,
                  abs(previousFrame.height - frame.height) <= 0.75 else { return false }
            result = frame
            return true
        }
        return ready ? result : nil
    }

    static func isUsable(_ frame: CGRect) -> Bool {
        frame.minX.isFinite && frame.minY.isFinite &&
            frame.width.isFinite && frame.height.isFinite &&
            frame.midX.isFinite && frame.midY.isFinite &&
            frame.width > 1 && frame.height > 1
    }

    @MainActor
    static func switchControl(_ element: XCUIElement) -> XCUIElement {
        let nested = element.descendants(matching: .switch).firstMatch
        return nested.exists ? nested : element
    }

    @MainActor
    static func toggleState(_ element: XCUIElement) -> Bool? {
        guard element.exists else { return nil }
        let control = switchControl(element)
        let raw = String(describing: control.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return switch raw {
        case "1", "true", "on", "yes", "enabled", "selected": true
        case "0", "false", "off", "no", "disabled", "unselected": false
        default: nil
        }
    }

    @MainActor
    static func setToggle(_ element: XCUIElement, enabled: Bool, timeout: TimeInterval) -> Bool {
        guard wait(timeout: timeout, condition: { toggleState(element) != nil }),
              let initial = toggleState(element) else {
            recordFailure("Switch has no readable state", element: element)
            return false
        }
        if initial == enabled { return true }
        guard tap(switchControl(element), timeout: timeout) else { return false }
        // A second tap could undo a delayed first transition. Observe the one
        // requested action and let an unchanged state fail the journey.
        let changed = wait(timeout: timeout) { toggleState(element) == enabled }
        if !changed { recordFailure("Switch did not reach requested state after one tap", element: element) }
        return changed
    }

    @MainActor
    static func clearTextField(_ field: XCUIElement, in app: XCUIApplication) -> Bool {
        guard tap(field, timeout: 8),
              wait(timeout: 4, condition: { app.keyboards.firstMatch.exists }) else {
            recordFailure("Text field did not receive keyboard focus", element: field)
            return false
        }
        if let value = field.value as? String, value.isEmpty || value == field.placeholderValue {
            return true
        }
        // A focused field can still sit beneath the keyboard accessory toolbar.
        // Reveal it before opening the text menu; hittability alone misses this.
        guard revealTextFieldAboveKeyboard(field, in: app) else { return false }
        field.press(forDuration: 1)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
        guard tapFrame(selectAll, in: app, timeout: 4) else { return false }
        let copy = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        guard wait(timeout: 4, condition: { copy.exists && !selectAll.exists }) else {
            recordFailure("Text selection menu did not confirm selection", element: field)
            return false
        }
        let deleteKey = app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", "delete")).firstMatch
        guard tap(deleteKey, timeout: 4) else { return false }
        let cleared = wait(timeout: 4) {
            guard field.exists, let value = field.value as? String else { return false }
            return value.isEmpty || value == field.placeholderValue
        }
        if !cleared { recordFailure("Text field stayed populated after Select All and Delete", element: field) }
        return cleared
    }

    @MainActor
    private static func revealTextFieldAboveKeyboard(_ field: XCUIElement, in app: XCUIApplication) -> Bool {
        guard let frame = stableFrame(of: field, in: app, timeout: 4, requiresHittable: true) else { return false }
        var keyboardTop = app.keyboards.firstMatch.frame.minY
        for identifier in ["ohana-keyboard-dismiss-action", "task-center-pet-profile-inline-keyboard-done", "add-event-keyboard-dismiss-action"] {
            let toolbar = app.toolbars.containing(.button, identifier: identifier).firstMatch
            if toolbar.exists, isUsable(toolbar.frame) {
                keyboardTop = min(keyboardTop, toolbar.frame.minY)
            }
        }
        guard frame.maxY > keyboardTop - 16 else { return true }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let startY = keyboardTop - 24
        let distance = min(frame.maxY - keyboardTop + 96, startY - app.frame.minY - 160)
        guard distance > 0 else { return false }
        let start = origin.withOffset(CGVector(dx: app.frame.width / 2, dy: startY - app.frame.minY))
        let end = start.withOffset(CGVector(dx: 0, dy: -distance))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        guard let revealed = stableFrame(of: field, in: app, timeout: 4, requiresHittable: true),
              revealed.maxY < keyboardTop - 16 else {
            recordFailure("Text field remains covered by keyboard toolbar", element: field)
            return false
        }
        return true
    }

    @MainActor
    static func dismissKeyboard(in app: XCUIApplication, returnKeyIsSafe: Bool = false) -> Bool {
        guard app.keyboards.firstMatch.exists else { return true }
        let actionIDs = [
            "ohana-keyboard-dismiss-action",
            "task-center-pet-profile-inline-keyboard-done",
            "add-event-keyboard-dismiss-action"
        ]
        let labels = ["Done", "done", "完成", "Fertig", "Hide keyboard", "隐藏键盘", "Tastatur ausblenden"] +
            (returnKeyIsSafe ? ["return", "Return", "换行"] : [])
        var action: XCUIElement?
        var isToolbarAction = false
        guard wait(timeout: 4, condition: {
            action = actionIDs.map { app.buttons[$0].firstMatch }
                .first { $0.exists && $0.isEnabled && isUsable($0.frame) }
            isToolbarAction = action != nil
            if action == nil {
                action = labels.map { app.keyboards.buttons[$0].firstMatch }
                    .first { $0.exists && $0.isEnabled && $0.isHittable }
            }
            return action != nil
        }), let action else {
            recordFailure("Keyboard has no explicit dismissal control", element: app.keyboards.firstMatch)
            return false
        }
        // Native keyboard toolbar AX clipping can report an infinite visible
        // frame for a visible, enabled Done button. Scope this frame path to
        // known toolbar identifiers; ordinary keyboard keys stay semantic.
        let sent = isToolbarAction
            ? tapFrame(action, in: app, timeout: 4)
            : tap(action, timeout: 4)
        guard sent else { return false }
        let dismissed = wait(timeout: 4) { !app.keyboards.firstMatch.exists }
        if !dismissed { recordFailure("Keyboard stayed visible after dismissal", element: action) }
        return dismissed
    }

    @MainActor
    static func captureFailureSnapshot() {
        let app = XCUIApplication()
        let state = app.state
        XCTContext.runActivity(named: "Final failed journey state") { activity in
            let hierarchy = state == .runningForeground ? app.debugDescription : "App is not running in foreground; AX query omitted."
            let text = XCTAttachment(string: "appState=\(state.rawValue)\n\(hierarchy)")
            text.name = "Final failed journey AX"
            text.lifetime = .keepAlways
            activity.add(text)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Final failed journey screen"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
        }
    }

    @MainActor
    static func recordFailure(_ reason: String, element: XCUIElement) {
        // Do not ask isHittable while diagnosing it: native menus can throw
        // from that getter. Missing elements likewise have no queryable frame.
        let state = element.exists
            ? "id=\(element.identifier) enabled=\(element.isEnabled) frame=\(element.frame) value=\(String(describing: element.value ?? "nil"))"
            : "element missing"
        XCTContext.runActivity(named: reason) { activity in
            let attachment = XCTAttachment(string: "\(reason)\n\(state)")
            attachment.name = "Interaction precondition"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }
}
