//
//  AppRuntimePolicy.swift
//  Ohana
//
//  Central runtime guardrails for performance, energy, and debug observability.
//

import Combine
import Foundation
import OSLog
import SwiftUI
import UIKit

enum AppPerformanceMode {
    static let powerSavingKey = "appPowerSavingMode"
    static let reducedVisualEffectsKey = "appReducedVisualEffectsExperiment"

    static var systemPrefersReducedWork: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || UIAccessibility.isReduceMotionEnabled
    }

    static var userPrefersReducedVisualEffects: Bool {
        UserDefaults.standard.bool(forKey: reducedVisualEffectsKey)
            || ProcessInfo.processInfo.arguments.contains("-OHANA_REDUCED_VISUAL_EFFECTS")
    }
}

enum OhanaMotionBudget: Equatable {
    case full
    case efficient
    case `static`

    var allowsMotion: Bool { self != .static }
    var usesFullMotion: Bool { self == .full }
}

enum OhanaRefreshBudget: Equatable {
    case live
    case throttled
    case paused
}

enum OhanaVisualEffectsBudget: Equatable {
    case full
    case efficient

    var usesFullEffects: Bool { self == .full }
}

/// A small, Sendable work contract passed from the app runtime policy to
/// maintenance actors and deferred media work. It prevents a background queue
/// from inventing its own power or thermal policy and gives long scans one
/// bounded batch to finish before persisting a continuation cursor.
nonisolated struct OhanaBackgroundWorkBudget: Sendable, Equatable {
    let operation: String
    let maximumItemCount: Int
    let maximumWallClockSeconds: TimeInterval
    let allowsExpensiveWork: Bool
    let isDeferred: Bool

    var hasWorkCapacity: Bool {
        !isDeferred && maximumItemCount > 0
    }

    func hasTimeRemaining(since startedAt: Date = Date()) -> Bool {
        guard hasWorkCapacity else { return false }
        return Date().timeIntervalSince(startedAt) < maximumWallClockSeconds
    }
}

enum OhanaFrameScheduler {
    @MainActor
    @discardableResult
    static func runAfterNextFrame(
        milliseconds: UInt64 = 0,
        _ operation: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            await waitAfterNextFrame(milliseconds: milliseconds)
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    static func waitAfterNextFrame(milliseconds: UInt64 = 0) async {
        await Task.yield()
        guard !Task.isCancelled else { return }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
        guard !Task.isCancelled else { return }
        if milliseconds > 0 {
            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
        }
    }
}

enum OnboardingHomeJoinHandoffGate {
    private static let completedAtKey = "ohana_onboarding_home_join_handoff_completed_at"
    private static let recentWindowSeconds: TimeInterval = 6
    private static let rootBootstrapDelayMilliseconds: UInt64 = 900
    private static let homeReadModelDelayMilliseconds: UInt64 = 240
    private static let homeAppearDelayMilliseconds: UInt64 = 180
    private static let homeVisualEffectDelayMilliseconds: UInt64 = 0
    private static let postHomeEffectDelayMilliseconds: UInt64 = 3400

    static func markCompleted(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(now.timeIntervalSince1970, forKey: completedAtKey)
    }

    static func remainingRootBootstrapDelayMilliseconds(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> UInt64 {
        remainingDelay(milliseconds: rootBootstrapDelayMilliseconds, now: now, defaults: defaults)
    }

    static func remainingHomeReadModelDelayMilliseconds(
        defaultDelayMilliseconds: UInt64,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> UInt64 {
        max(
            defaultDelayMilliseconds,
            remainingDelay(milliseconds: homeReadModelDelayMilliseconds, now: now, defaults: defaults)
        )
    }

    static func remainingHomeAppearDelayMilliseconds(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> UInt64 {
        remainingDelay(milliseconds: homeAppearDelayMilliseconds, now: now, defaults: defaults)
    }

    static func remainingHomeVisualEffectDelayMilliseconds(
        defaultDelayMilliseconds: UInt64 = 0,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> UInt64 {
        max(
            defaultDelayMilliseconds,
            remainingDelay(milliseconds: homeVisualEffectDelayMilliseconds, now: now, defaults: defaults)
        )
    }

    static func remainingPostHomeEffectDelayMilliseconds(
        defaultDelayMilliseconds: UInt64 = 0,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> UInt64 {
        max(
            defaultDelayMilliseconds,
            remainingDelay(milliseconds: postHomeEffectDelayMilliseconds, now: now, defaults: defaults)
        )
    }

    static func consume(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedAtKey)
    }

    private static func remainingDelay(
        milliseconds: UInt64,
        now: Date,
        defaults: UserDefaults
    ) -> UInt64 {
        let completedAt = defaults.double(forKey: completedAtKey)
        guard completedAt > 0 else { return 0 }
        let elapsedSeconds = now.timeIntervalSince1970 - completedAt
        guard elapsedSeconds >= 0, elapsedSeconds < recentWindowSeconds else { return 0 }
        let elapsedMilliseconds = UInt64(elapsedSeconds * 1000)
        guard elapsedMilliseconds < milliseconds else { return 0 }
        return milliseconds - elapsedMilliseconds
    }
}

@MainActor
final class AppWorkloadPolicy: ObservableObject {
    static let shared = AppWorkloadPolicy()

    @Published private(set) var isForeground: Bool
    @Published private(set) var isLowPowerModeEnabled: Bool
    @Published private(set) var isReduceMotionEnabled: Bool
    @Published private(set) var isUserPowerSavingMode: Bool
    @Published private(set) var isUserReducedVisualEffectsMode: Bool
    @Published private(set) var thermalState: ProcessInfo.ThermalState
    @Published private(set) var lastReductionReason = "foreground"

    var hasRunningWalkProvider: @MainActor () -> Bool = { false }

    private let lowPowerModeProvider: @MainActor () -> Bool
    private let reduceMotionProvider: @MainActor () -> Bool
    private let userPowerSavingProvider: @MainActor () -> Bool
    private let userReducedVisualEffectsProvider: @MainActor () -> Bool
    private let thermalStateProvider: @MainActor () -> ProcessInfo.ThermalState
    private var cancellables: Set<AnyCancellable> = []

    init(
        notificationCenter: NotificationCenter = .default,
        lowPowerModeProvider: (@MainActor () -> Bool)? = nil,
        reduceMotionProvider: (@MainActor () -> Bool)? = nil,
        userPowerSavingProvider: (@MainActor () -> Bool)? = nil,
        userReducedVisualEffectsProvider: (@MainActor () -> Bool)? = nil,
        thermalStateProvider: (@MainActor () -> ProcessInfo.ThermalState)? = nil
    ) {
        let lowPowerModeProvider = lowPowerModeProvider ?? { ProcessInfo.processInfo.isLowPowerModeEnabled }
        let reduceMotionProvider = reduceMotionProvider ?? { UIAccessibility.isReduceMotionEnabled }
        let userPowerSavingProvider = userPowerSavingProvider ?? {
            UserDefaults.standard.bool(forKey: AppPerformanceMode.powerSavingKey)
        }
        let userReducedVisualEffectsProvider = userReducedVisualEffectsProvider ?? {
            AppPerformanceMode.userPrefersReducedVisualEffects
        }
        let thermalStateProvider = thermalStateProvider ?? { ProcessInfo.processInfo.thermalState }

        self.lowPowerModeProvider = lowPowerModeProvider
        self.reduceMotionProvider = reduceMotionProvider
        self.userPowerSavingProvider = userPowerSavingProvider
        self.userReducedVisualEffectsProvider = userReducedVisualEffectsProvider
        self.thermalStateProvider = thermalStateProvider
        isForeground = true
        isLowPowerModeEnabled = lowPowerModeProvider()
        isReduceMotionEnabled = reduceMotionProvider()
        isUserPowerSavingMode = userPowerSavingProvider()
        isUserReducedVisualEffectsMode = userReducedVisualEffectsProvider()
        thermalState = thermalStateProvider()

        notificationCenter.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isLowPowerModeEnabled = self?.lowPowerModeProvider() ?? false
                    self?.recordPolicySample(reason: "powerStateChanged")
                }
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isReduceMotionEnabled = self?.reduceMotionProvider() ?? false
                    self?.recordPolicySample(reason: "reduceMotionChanged")
                }
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.thermalState = self?.thermalStateProvider() ?? .nominal
                    self?.recordPolicySample(reason: "thermalStateChanged")
                }
            }
            .store(in: &cancellables)
    }

    var userPowerSavingMode: Bool {
        isUserPowerSavingMode
    }

    var hasRunningWalk: Bool {
        hasRunningWalkProvider()
    }

    func updateScenePhase(_ phase: ScenePhase) {
        let nextForeground = phase == .active
        if isForeground != nextForeground {
            isForeground = nextForeground
            recordPolicySample(reason: nextForeground ? "foreground" : "background")
        }
    }

    func refresh(reason: String) {
        isLowPowerModeEnabled = lowPowerModeProvider()
        isReduceMotionEnabled = reduceMotionProvider()
        isUserPowerSavingMode = userPowerSavingProvider()
        isUserReducedVisualEffectsMode = userReducedVisualEffectsProvider()
        thermalState = thermalStateProvider()
        recordPolicySample(reason: reason)
    }

    func shouldReduceWork(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> Bool {
        reductionReason(isVisible: isVisible, allowDuringActiveWalk: allowDuringActiveWalk) != nil
    }

    func shouldRunTimer(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> Bool {
        refreshBudget(isVisible: isVisible, allowDuringActiveWalk: allowDuringActiveWalk) == .live
    }

    func shouldRunRepeatingAnimation(isVisible: Bool = true) -> Bool {
        ambientMotionBudget(isVisible: isVisible).allowsMotion
    }

    func shouldAnimate(isVisible: Bool = true) -> Bool {
        shouldRunRepeatingAnimation(isVisible: isVisible)
    }

    func shouldRunInteractionAnimation(isVisible: Bool = true) -> Bool {
        interactionMotionBudget(isVisible: isVisible).allowsMotion
    }

    func shouldPlayFeedback(isVisible: Bool = true) -> Bool {
        guard isVisible, isForeground else { return false }
        guard !isLowPowerModeEnabled else { return false }
        return thermalState != .critical
    }

    func interactionMotionBudget(isVisible: Bool = true) -> OhanaMotionBudget {
        guard isVisible else { return .static }
        guard isForeground else { return .static }
        let base: OhanaMotionBudget = isReduceMotionEnabled ? .efficient : .full
        return stricterMotionBudget(base, thermalInteractionMotionBudget)
    }

    func ambientMotionBudget(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> OhanaMotionBudget {
        guard isVisible else { return .static }
        guard isForeground || (allowDuringActiveWalk && hasRunningWalk) else { return .static }
        let base: OhanaMotionBudget = if isLowPowerModeEnabled || isReduceMotionEnabled || userPowerSavingMode {
            .static
        } else {
            .full
        }
        return stricterMotionBudget(base, thermalAmbientMotionBudget)
    }

    func refreshBudget(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> OhanaRefreshBudget {
        guard isVisible else { return .paused }
        let base: OhanaRefreshBudget = if !isForeground {
            allowDuringActiveWalk && hasRunningWalk ? .throttled : .paused
        } else if isLowPowerModeEnabled || isReduceMotionEnabled || userPowerSavingMode {
            .throttled
        } else {
            .live
        }
        return stricterRefreshBudget(base, thermalRefreshBudget)
    }

    func visualEffectsBudget(isVisible: Bool = true) -> OhanaVisualEffectsBudget {
        guard isVisible, isForeground else { return .efficient }
        if isLowPowerModeEnabled ||
            isReduceMotionEnabled ||
            userPowerSavingMode ||
            isUserReducedVisualEffectsMode {
            return .efficient
        }
        switch thermalState {
        case .serious, .critical:
            return .efficient
        case .nominal, .fair:
            return .full
        @unknown default:
            return .efficient
        }
    }

    func refreshInterval(
        default liveInterval: TimeInterval,
        throttled throttledInterval: TimeInterval = 60,
        paused pausedInterval: TimeInterval = 60,
        isVisible: Bool = true,
        allowDuringActiveWalk: Bool = false
    ) -> TimeInterval {
        switch refreshBudget(isVisible: isVisible, allowDuringActiveWalk: allowDuringActiveWalk) {
        case .live: liveInterval
        case .throttled: throttledInterval
        case .paused: pausedInterval
        }
    }

    /// Produces one explicit, finite batch for deferred work. Callers must
    /// persist a continuation cursor when `maximumItemCount` is exhausted;
    /// they must not loop until completion while the app is hidden.
    func backgroundWorkBudget(
        operation: String,
        requestedItemCount: Int,
        allowWhileBackground: Bool = false
    ) -> OhanaBackgroundWorkBudget {
        let requestedItemCount = max(1, requestedItemCount)
        let isCritical = thermalState == .critical
        let mustDefer = isCritical || (!isForeground && !allowWhileBackground)
        guard !mustDefer else {
            return OhanaBackgroundWorkBudget(
                operation: operation,
                maximumItemCount: 0,
                maximumWallClockSeconds: 0,
                allowsExpensiveWork: false,
                isDeferred: true
            )
        }

        let constrained = isLowPowerModeEnabled ||
            isUserPowerSavingMode ||
            thermalState == .serious ||
            isReduceMotionEnabled
        if constrained {
            return OhanaBackgroundWorkBudget(
                operation: operation,
                maximumItemCount: min(requestedItemCount, 12),
                maximumWallClockSeconds: 3,
                allowsExpensiveWork: false,
                isDeferred: false
            )
        }

        return OhanaBackgroundWorkBudget(
            operation: operation,
            maximumItemCount: min(requestedItemCount, 64),
            maximumWallClockSeconds: 10,
            allowsExpensiveWork: true,
            isDeferred: false
        )
    }

    private func reductionReason(isVisible: Bool, allowDuringActiveWalk: Bool) -> String? {
        if !isVisible { return "notVisible" }
        if !isForeground, !(allowDuringActiveWalk && hasRunningWalk) { return "background" }
        if thermalState == .critical { return "thermalCritical" }
        if thermalState == .serious { return "thermalSerious" }
        if isLowPowerModeEnabled { return "lowPowerMode" }
        if isReduceMotionEnabled { return "reduceMotion" }
        if userPowerSavingMode { return "appPowerSaving" }
        return nil
    }

    private var thermalInteractionMotionBudget: OhanaMotionBudget {
        switch thermalState {
        case .serious, .critical:
            return .efficient
        case .nominal, .fair:
            return .full
        @unknown default:
            return .efficient
        }
    }

    private var thermalAmbientMotionBudget: OhanaMotionBudget {
        switch thermalState {
        case .critical:
            return .static
        case .serious:
            return .efficient
        case .nominal, .fair:
            return .full
        @unknown default:
            return .efficient
        }
    }

    private var thermalRefreshBudget: OhanaRefreshBudget {
        switch thermalState {
        case .critical:
            return .paused
        case .serious:
            return .throttled
        case .nominal, .fair:
            return .live
        @unknown default:
            return .throttled
        }
    }

    private func stricterMotionBudget(_ first: OhanaMotionBudget, _ second: OhanaMotionBudget) -> OhanaMotionBudget {
        motionSeverity(first) >= motionSeverity(second) ? first : second
    }

    private func stricterRefreshBudget(_ first: OhanaRefreshBudget, _ second: OhanaRefreshBudget) -> OhanaRefreshBudget {
        refreshSeverity(first) >= refreshSeverity(second) ? first : second
    }

    private func motionSeverity(_ budget: OhanaMotionBudget) -> Int {
        switch budget {
        case .full: 0
        case .efficient: 1
        case .static: 2
        }
    }

    private func refreshSeverity(_ budget: OhanaRefreshBudget) -> Int {
        switch budget {
        case .live: 0
        case .throttled: 1
        case .paused: 2
        }
    }

    private func recordPolicySample(reason: String) {
        AppPerformanceMonitor.shared.record(
            "能耗策略",
            valueMS: 0,
            note: "reason=\(reason), foreground=\(isForeground), lowPower=\(isLowPowerModeEnabled), reduceMotion=\(isReduceMotionEnabled), appPowerSaving=\(userPowerSavingMode), reducedVisualEffects=\(isUserReducedVisualEffectsMode), thermal=\(thermalState), walk=\(hasRunningWalk)"
        )
    }
}

@MainActor
final class AppPerformanceMonitor: ObservableObject {
    struct Sample: Identifiable {
        let id = UUID()
        let name: String
        let valueMS: Double
        let timestamp: Date
        let note: String?
    }

    static let shared = AppPerformanceMonitor()

    @Published private(set) var samples: [Sample] = []
    private var starts: [String: CFAbsoluteTime] = [:]

    private init() {}

    func markStart(_ key: String) {
        starts[key] = CFAbsoluteTimeGetCurrent()
    }

    func markEnd(_ key: String, name: String, note: String? = nil) {
        guard let startedAt = starts.removeValue(forKey: key) else { return }
        record(name, startedAt: startedAt, note: note)
    }

    func record(_ name: String, startedAt: CFAbsoluteTime, note: String? = nil) {
        let elapsed = max(0, (CFAbsoluteTimeGetCurrent() - startedAt) * 1000)
        record(name, valueMS: elapsed, note: note)
    }

    func record(_ name: String, valueMS: Double, note: String? = nil) {
        AppPerformanceSignposts.recordSample(name, valueMS: valueMS, note: note)
        samples.insert(Sample(name: name, valueMS: valueMS, timestamp: Date(), note: note), at: 0)
        if samples.count > 80 {
            samples.removeLast(samples.count - 80)
        }
    }

    func clear() {
        starts.removeAll()
        samples.removeAll()
    }
}

enum AppPerformanceFlows {
    static let homeCardExpand = "flow.home.card_expand"
    static let homeCardCollapse = "flow.home.card_collapse"
    static let homeTabSwitch = "flow.home.tab_switch"
    static let quickCareCommand = "flow.quick_care.command"
    static let calendarOpen = "flow.calendar.open"
    static let calendarModeSwitch = "flow.calendar.mode_switch"
    static let calendarFilter = "flow.calendar.filter"
    static let calendarAddEventSheet = "flow.calendar.add_event_sheet"
    static let oasisOpen = "flow.oasis.open"
    static let backupExport = "flow.backup.export"
    static let walkSession = "flow.walk.session"
}

enum AppPerformancePhases {
    static let flowStart = "flow_start"
    static let firstFrame = "first_frame"
    static let shellReady = "shell_ready"
    static let contentMounted = "content_mounted"
    static let dataReady = "data_ready"
    static let stateSubmitted = "state_submitted"
    static let animationComplete = "animation_complete"
    static let writeSuccess = "write_success"
    static let writeFailure = "write_failure"
    static let noop = "noop"
    static let routeDismiss = "route_dismiss"
    static let outgoingUnmounted = "outgoing_unmounted"
    static let sessionPaused = "session_paused"
    static let sessionResumed = "session_resumed"
    static let locationReady = "location_ready"
}

@MainActor
enum AppFlowPerformance {
    @discardableResult
    static func start(_ flow: String, note: [String: String] = [:]) -> CFAbsoluteTime {
        let startedAt = CFAbsoluteTimeGetCurrent()
        mark(flow, AppPerformancePhases.flowStart, note: note)
        return startedAt
    }

    static func mark(
        _ flow: String,
        _ phase: String,
        startedAt: CFAbsoluteTime? = nil,
        note: [String: String] = [:]
    ) {
        let sampleName = "\(flow).\(phase)"
        let noteString = formattedNote(note)
        if let startedAt {
            let elapsedMS = max(0, (CFAbsoluteTimeGetCurrent() - startedAt) * 1000)
            AppPerformanceSignposts.recordFlow(flow, phase: phase, valueMS: elapsedMS, note: noteString)
            AppPerformanceMonitor.shared.record(sampleName, valueMS: elapsedMS, note: noteString)
        } else {
            AppPerformanceSignposts.recordFlow(flow, phase: phase, valueMS: 0, note: noteString)
            AppPerformanceMonitor.shared.record(sampleName, valueMS: 0, note: noteString)
        }
    }

    static func markFailure(_ flow: String, startedAt: CFAbsoluteTime? = nil, error: Error) {
        mark(
            flow,
            AppPerformancePhases.writeFailure,
            startedAt: startedAt,
            note: ["errorType": String(describing: type(of: error))]
        )
    }

    private static func formattedNote(_ note: [String: String]) -> String? {
        guard !note.isEmpty else { return nil }
        return note.keys.sorted().map { key in
            "\(key)=\(note[key] ?? "")"
        }.joined(separator: ", ")
    }
}

@MainActor
private enum AppPerformanceSignposts {
    private static let signposter = OSSignposter(subsystem: "com.guanchen.li.Ohana", category: "PerformanceProbes")

    static func recordSample(_ name: String, valueMS: Double, note: String?) {
        switch name {
        case "launch_shell_ready":
            emit("launch_shell_ready", phase: "sample", valueMS: valueMS, note: note)
        case "first_render":
            emit("first_render", phase: "sample", valueMS: valueMS, note: note)
        case "home_first_render":
            emit("home_first_render", phase: "sample", valueMS: valueMS, note: note)
        case "metrickit_metrics":
            emit("metrickit_metrics", phase: "sample", valueMS: valueMS, note: note)
        default:
            break
        }
    }

    static func recordFlow(_ flow: String, phase: String, valueMS: Double, note: String?) {
        switch flow {
        case AppPerformanceFlows.homeCardExpand:
            emit("flow.home.card_expand", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.homeCardCollapse:
            emit("flow.home.card_collapse", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.homeTabSwitch:
            emit("flow.home.tab_switch", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.quickCareCommand:
            emit("flow.quick_care.command", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.calendarOpen:
            emit("flow.calendar.open", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.calendarModeSwitch:
            emit("flow.calendar.mode_switch", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.calendarFilter:
            emit("flow.calendar.filter", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.calendarAddEventSheet:
            emit("flow.calendar.add_event_sheet", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.oasisOpen:
            emit("flow.oasis.open", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.backupExport:
            emit("flow.backup.export", phase: phase, valueMS: valueMS, note: note)
        case AppPerformanceFlows.walkSession:
            emit("flow.walk.session", phase: phase, valueMS: valueMS, note: note)
        default:
            break
        }
    }

    private static func emit(_ name: StaticString, phase: String, valueMS: Double, note: String?) {
        let elapsed = String(format: "%.2f", valueMS)
        let note = note ?? ""
        signposter.emitEvent(
            name,
            "phase=\(phase, privacy: .public), elapsed_ms=\(elapsed, privacy: .public), note=\(note, privacy: .private)"
        )
    }
}
