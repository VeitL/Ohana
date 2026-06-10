//
//  AppRuntimePolicy.swift
//  Ohana
//
//  Central runtime guardrails for performance, energy, and debug observability.
//

import Combine
import Foundation
import SwiftUI
import UIKit

enum AppPerformanceMode {
    static let powerSavingKey = "appPowerSavingMode"

    static var systemPrefersReducedWork: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || UIAccessibility.isReduceMotionEnabled
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
        if milliseconds > 0 {
            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
        }
    }
}

@MainActor
final class AppWorkloadPolicy: ObservableObject {
    static let shared = AppWorkloadPolicy()

    @Published private(set) var isForeground = true
    @Published private(set) var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published private(set) var isUserPowerSavingMode = UserDefaults.standard.bool(forKey: AppPerformanceMode.powerSavingKey)
    @Published private(set) var lastReductionReason = "foreground"

    var hasRunningWalkProvider: @MainActor () -> Bool = { false }

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                    self?.recordPolicySample(reason: "powerStateChanged")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
                    self?.recordPolicySample(reason: "reduceMotionChanged")
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
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isUserPowerSavingMode = UserDefaults.standard.bool(forKey: AppPerformanceMode.powerSavingKey)
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

    func interactionMotionBudget(isVisible: Bool = true) -> OhanaMotionBudget {
        guard isVisible else { return .static }
        guard isForeground else { return .static }
        if isReduceMotionEnabled { return .efficient }
        return .full
    }

    func ambientMotionBudget(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> OhanaMotionBudget {
        guard isVisible else { return .static }
        guard isForeground || (allowDuringActiveWalk && hasRunningWalk) else { return .static }
        if isLowPowerModeEnabled || isReduceMotionEnabled || userPowerSavingMode { return .static }
        return .full
    }

    func refreshBudget(isVisible: Bool = true, allowDuringActiveWalk: Bool = false) -> OhanaRefreshBudget {
        guard isVisible else { return .paused }
        guard isForeground else {
            return allowDuringActiveWalk && hasRunningWalk ? .throttled : .paused
        }
        if isLowPowerModeEnabled || isReduceMotionEnabled || userPowerSavingMode { return .throttled }
        return .live
    }

    func refreshInterval(
        default liveInterval: TimeInterval,
        throttled throttledInterval: TimeInterval = 60,
        paused pausedInterval: TimeInterval = 60,
        isVisible: Bool = true,
        allowDuringActiveWalk: Bool = false
    ) -> TimeInterval {
        switch refreshBudget(isVisible: isVisible, allowDuringActiveWalk: allowDuringActiveWalk) {
        case .live: return liveInterval
        case .throttled: return throttledInterval
        case .paused: return pausedInterval
        }
    }

    private func reductionReason(isVisible: Bool, allowDuringActiveWalk: Bool) -> String? {
        if !isVisible { return "notVisible" }
        if !isForeground && !(allowDuringActiveWalk && hasRunningWalk) { return "background" }
        if isLowPowerModeEnabled { return "lowPowerMode" }
        if isReduceMotionEnabled { return "reduceMotion" }
        if userPowerSavingMode { return "appPowerSaving" }
        return nil
    }

    private func recordPolicySample(reason: String) {
        AppPerformanceMonitor.shared.record(
            "能耗策略",
            valueMS: 0,
            note: "reason=\(reason), foreground=\(isForeground), lowPower=\(isLowPowerModeEnabled), reduceMotion=\(isReduceMotionEnabled), appPowerSaving=\(userPowerSavingMode), walk=\(hasRunningWalk)"
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
        let elapsed = max(0, (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000)
        record(name, valueMS: elapsed, note: note)
    }

    func record(_ name: String, valueMS: Double, note: String? = nil) {
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
            AppPerformanceMonitor.shared.record(sampleName, startedAt: startedAt, note: noteString)
        } else {
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
