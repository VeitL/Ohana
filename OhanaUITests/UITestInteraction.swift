import XCTest

/// Shared interaction preconditions. A successful tap means one input was sent;
/// the journey must separately assert its destination or committed result.
enum UITestInteraction {
    enum AuthorizationKind: Equatable {
        case notifications
        case location
    }

    /// Only Ohana's known OS prompts belong to routine journey fixtures.
    /// Permission-denial/delivery acceptance remains a separate device journey.
    static func authorizationKind(text: String) -> AuthorizationKind? {
        guard ["\"Ohana\"", "“Ohana”", "„Ohana“", "「Ohana」"].contains(where: text.contains) else { return nil }
        if ["notifications", "Mitteilungen", "通知"].contains(where: text.localizedCaseInsensitiveContains) {
            return .notifications
        }
        if ["location", "Standort", "位置"].contains(where: text.localizedCaseInsensitiveContains) {
            return .location
        }
        return nil
    }

    @MainActor
    static func installAuthorizationMonitor(on testCase: XCTestCase) {
        // XCTest invokes monitors only for an interrupted input and removes
        // them at case completion. Expected prompts are still handled explicitly.
        testCase.addUIInterruptionMonitor(withDescription: "Ohana routine journey system permissions") { alert in
            MainActor.assumeIsolated {
                guard let kind = authorizationKind(of: alert) else { return false }
                return respond(to: alert, kind: kind, assertDismissal: true)
            }
        }
    }

    @MainActor
    private static func authorizationKind(of alert: XCUIElement) -> AuthorizationKind? {
        guard alert.exists, let snapshot = try? alert.snapshot() else { return nil }
        var labels = [snapshot.label]
        var remaining = snapshot.children
        while let child = remaining.popLast() {
            if child.elementType == .staticText { labels.append(child.label) }
            remaining.append(contentsOf: child.children)
        }
        return authorizationKind(text: labels.joined(separator: " "))
    }

    @MainActor
    @discardableResult
    static func respondToPendingAuthorization(
        kind expectedKind: AuthorizationKind? = nil,
        timeout: TimeInterval = 0,
        assertDismissal: Bool = true
    ) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        var kind: AuthorizationKind?
        guard wait(timeout: timeout, condition: {
            kind = authorizationKind(of: alert)
            return kind != nil && (expectedKind == nil || kind == expectedKind)
        }), let kind else { return false }
        return respond(to: alert, kind: kind, assertDismissal: assertDismissal)
    }

    @MainActor
    private static func respond(to alert: XCUIElement, kind: AuthorizationKind, assertDismissal: Bool) -> Bool {
        let labels = kind == .notifications
            ? ["Allow", "Zulassen", "允许"]
            : ["Allow While Using App", "Beim Verwenden der App", "使用App时允许", "使用期间允许"]
        let button = alert.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        guard wait(timeout: 8, condition: { button.exists && button.isEnabled }) else {
            recordFailure("Ohana system permission has no expected response", element: alert)
            if assertDismissal { XCTFail("Ohana system permission did not expose its declared response.") }
            return false
        }
        XCTContext.runActivity(named: "Respond once to Ohana system permission: \(kind)") { activity in
            let attachment = XCTAttachment(string: snapshotDescription(of: alert))
            attachment.name = "System permission starting state"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
            button.tap()
        }
        // A failed AX snapshot must not be mistaken for a dismissed prompt.
        let dismissed = wait(timeout: 8) { !alert.exists }
        if !dismissed {
            recordFailure("Ohana system permission remained after its single response", element: alert)
            if assertDismissal { XCTFail("Ohana system permission stayed open after its single response.") }
        }
        return dismissed
    }

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
    static func tap(
        _ element: XCUIElement,
        in app: XCUIApplication? = nil,
        timeout: TimeInterval
    ) -> Bool {
        let application = app ?? XCUIApplication()
        let windowFrame = application.frame
        // iOS 27 can report an off-screen lazy Menu as hittable. Observe its
        // enabled state and geometry together, then leave input to XCTest.
        // A rejected target lets the caller reveal it through normal scrolling.
        guard wait(timeout: timeout, condition: {
            guard element.exists, let snapshot = try? element.snapshot(), snapshot.isEnabled,
                  let visibleFrame = visibleFrame(for: snapshot.frame, in: windowFrame),
                  visibleFrame.contains(CGPoint(x: snapshot.frame.midX, y: snapshot.frame.midY)) else {
                return false
            }
            return element.isHittable
        }) else {
            recordFailure("Semantic tap target did not become ready", element: element)
            return false
        }
        element.tap()
        return true
    }

    /// Explicit coordinate path for documented XCTest activation gaps: native
    /// menus, clipped keyboard/text-selection controls, and transformed Home
    /// quick-action targets. Never use it as a semantic-tap fallback.
    @MainActor
    static func tapFrame(
        _ element: XCUIElement,
        in app: XCUIApplication? = nil,
        offset: CGVector = CGVector(dx: 0.5, dy: 0.5),
        timeout: TimeInterval,
        usesPointerClick: Bool = false,
        validatedFrame: CGRect? = nil
    ) -> Bool {
        guard offset.dx.isFinite, offset.dy.isFinite,
              (0 ... 1).contains(offset.dx), (0 ... 1).contains(offset.dy),
              let frame = validatedFrame ?? stableFrame(of: element, in: app, timeout: timeout),
              isUsable(frame) else {
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

    /// Returns geometry only for the current observation. Callers must obtain a
    /// fresh frame after scrolling, keyboard changes, or route transitions.
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
                  element.exists,
                  let snapshot = try? element.snapshot(), snapshot.isEnabled else {
                previousFrame = nil
                return false
            }
            let frame = snapshot.frame
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

    struct VisibleFrameObservation {
        let frame: CGRect
        let visibleFrame: CGRect
    }

    @MainActor
    static func visibleFrameObservation(
        of element: XCUIElement,
        in app: XCUIApplication,
        minimumVisibleSize: CGFloat = 1
    ) -> VisibleFrameObservation? {
        guard element.exists, let snapshot = try? element.snapshot(),
              let visibleFrame = visibleFrame(
                  for: snapshot.frame,
                  in: app.frame,
                  minimumVisibleSize: minimumVisibleSize
              ) else { return nil }
        return VisibleFrameObservation(frame: snapshot.frame, visibleFrame: visibleFrame)
    }

    static func visibleFrame(
        for frame: CGRect,
        in windowFrame: CGRect,
        minimumVisibleSize: CGFloat = 1
    ) -> CGRect? {
        guard minimumVisibleSize.isFinite, minimumVisibleSize > 0,
              isUsable(frame), isUsable(windowFrame) else { return nil }
        let visibleFrame = frame.intersection(windowFrame)
        guard !visibleFrame.isNull,
              visibleFrame.width > minimumVisibleSize,
              visibleFrame.height > minimumVisibleSize else { return nil }
        return visibleFrame
    }

    @MainActor
    static func switchControl(_ element: XCUIElement) -> XCUIElement {
        let nested = element.descendants(matching: .switch).firstMatch
        return nested.exists ? nested : element
    }

    @MainActor
    static func toggleState(_ element: XCUIElement) -> Bool? {
        guard element.exists,
              let snapshot = try? switchControl(element).snapshot(),
              let value = snapshot.value else { return nil }
        let raw = String(describing: value)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return switch raw {
        case "1", "true", "on", "yes", "enabled", "selected": true
        case "0", "false", "off", "no", "disabled", "unselected": false
        default: nil
        }
    }

    @MainActor
    static func setToggle(_ element: XCUIElement, enabled: Bool, timeout: TimeInterval) -> Bool {
        var initial: Bool?
        guard wait(timeout: timeout, condition: {
            initial = toggleState(element)
            return initial != nil
        }), let initial else {
            recordFailure("Switch has no readable state", element: element)
            return false
        }
        if initial == enabled { return true }
        guard tap(switchControl(element), timeout: timeout) else { return false }
        // A second tap could undo a delayed first transition. Observe the one
        // requested action and let an unchanged state fail the journey.
        func label(_ state: Bool?) -> String {
            guard let state else { return "unreadable" }
            return state ? "on" : "off"
        }
        var observedStates = [label(initial)]
        let changed = wait(timeout: timeout) {
            let state = toggleState(element)
            let current = label(state)
            if observedStates.last != current { observedStates.append(current) }
            return state == enabled
        }
        if !changed {
            XCTContext.runActivity(named: "One-tap switch state observation") { activity in
                let attachment = XCTAttachment(
                    string: "initial=\(label(initial)); expected=\(label(enabled)); observed=\(observedStates.joined(separator: " → "))"
                )
                attachment.name = "Switch state after one tap"
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
            recordFailure("Switch did not reach requested state after one tap", element: element)
        }
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
        // Keyboard focus can place the field under its accessory toolbar.
        // Observe geometry before revealing it; require hittability afterward.
        // Focus has already been established. One current observation is
        // sufficient for a semantic long press; two geometry samples can
        // consume the whole deadline on a slower accessibility server.
        guard let observation = visibleFrameObservation(of: field, in: app) else {
            recordFailure("Focused text field has no usable reveal geometry", element: field)
            return false
        }
        let frame = observation.frame
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
        guard wait(timeout: 4, condition: {
            guard let revealed = visibleFrameObservation(of: field, in: app) else { return false }
            return revealed.frame.maxY < keyboardTop - 16 && field.isHittable
        }) else {
            recordFailure("Text field remains covered by keyboard toolbar", element: field)
            return false
        }
        return true
    }

    @MainActor
    static func dismissKeyboard(in app: XCUIApplication, returnKeyIsSafe: Bool = false) -> Bool {
        // iOS can retain a focused keyboard in AX after sliding it entirely
        // below the window. Its keys still exist, but none can be tapped.
        if isKeyboardDismissed(in: app) { return true }
        let actionIDs = [
            "ohana-keyboard-dismiss-action",
            "task-center-pet-profile-inline-keyboard-done",
            "add-event-keyboard-dismiss-action"
        ]
        let labels = ["Done", "done", "完成", "Fertig", "Hide keyboard", "隐藏键盘", "Tastatur ausblenden"] +
            (returnKeyIsSafe ? ["return", "Return", "换行"] : [])
        var action: XCUIElement?
        var actionFrame: CGRect?
        var isToolbarAction = false
        guard wait(timeout: 4, condition: {
            action = actionIDs.map { app.buttons[$0].firstMatch }
                .first {
                    guard $0.exists, let snapshot = try? $0.snapshot(), snapshot.isEnabled else { return false }
                    let frame = snapshot.frame
                    guard isUsable(frame) else { return false }
                    actionFrame = frame
                    return true
                }
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
            ? tapFrame(action, in: app, timeout: 4, validatedFrame: actionFrame)
            : tap(action, timeout: 4)
        guard sent else { return false }
        let dismissed = wait(timeout: 4) { isKeyboardDismissed(in: app) }
        if !dismissed { recordFailure("Keyboard stayed visible after dismissal", element: action) }
        return dismissed
    }

    @MainActor
    private static func isKeyboardDismissed(in app: XCUIApplication) -> Bool {
        // Done can remove the keyboard between separate exists/frame queries.
        // Observe presence and geometry from one application snapshot instead.
        // An unreadable snapshot must never count as successful dismissal.
        guard let snapshot = try? app.snapshot(), isUsable(snapshot.frame) else { return false }
        var remaining = snapshot.children
        while let element = remaining.popLast() {
            if element.elementType == .keyboard {
                guard isUsable(element.frame), !element.frame.intersects(snapshot.frame) else { return false }
            }
            remaining.append(contentsOf: element.children)
        }
        return true
    }

    @MainActor
    static func captureFailureSnapshot() {
        let app = XCUIApplication()
        let state = app.state
        XCTContext.runActivity(named: "Final failed journey state") { activity in
            // Preserve the screen before AX diagnostics, which can themselves
            // fail when the runner has lost accessibility responsiveness.
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Final failed journey screen"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
            let hierarchy = state == .runningForeground ? app.debugDescription : "App is not running in foreground; AX query omitted."
            let text = XCTAttachment(string: "appState=\(state.rawValue)\n\(hierarchy)")
            text.name = "Final failed journey AX"
            text.lifetime = .keepAlways
            activity.add(text)
        }
    }

    @MainActor
    static func snapshotDescription(of element: XCUIElement) -> String {
        do {
            let snapshot = try element.snapshot()
            return "id=\(snapshot.identifier) enabled=\(snapshot.isEnabled) frame=\(snapshot.frame) label=\(snapshot.label) value=\(String(describing: snapshot.value ?? "nil"))"
        } catch {
            return "element snapshot unreadable: \(error)"
        }
    }

    @MainActor
    static func recordFailure(_ reason: String, element: XCUIElement) {
        // Do not ask isHittable while diagnosing it: native menus can throw
        // from that getter. One snapshot also avoids resolving a disappearing
        // element separately for every diagnostic attribute.
        let state = snapshotDescription(of: element)
        XCTContext.runActivity(named: reason) { activity in
            let attachment = XCTAttachment(string: "\(reason)\n\(state)")
            attachment.name = "Interaction precondition"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }
}
