//
//  WalkLiveActivityPresenter.swift
//  Ohana
//
//  ActivityKit adapter for the existing PetWalkingManager owner flow.
//

import ActivityKit
import Foundation

@MainActor
protocol WalkActivityPresenting: AnyObject {
    func dismissStaleActivities()
    func start(attributes: WalkActivityAttributes, state: WalkActivityAttributes.ContentState)
    func restore(attributes: WalkActivityAttributes, state: WalkActivityAttributes.ContentState)
    func update(_ state: WalkActivityAttributes.ContentState, force: Bool)
    func end(_ state: WalkActivityAttributes.ContentState, immediate: Bool)
    func endSession(_ sessionID: UUID, immediate: Bool)
    func endAll(immediate: Bool)
}

@MainActor
final class LiveWalkActivityPresenter: WalkActivityPresenting {
    private static let staleInterval: TimeInterval = 60 * 60 * 4

    private let workloadPolicy: AppWorkloadPolicy
    private var sessionID: UUID?
    private var lastSubmittedState: WalkActivityAttributes.ContentState?
    private var operationTask: Task<Void, Never>?

    init(workloadPolicy: AppWorkloadPolicy? = nil) {
        self.workloadPolicy = workloadPolicy ?? AppWorkloadPolicy.shared
    }

    func dismissStaleActivities() {
        enqueue {
            let now = Date()
            for activity in Activity<WalkActivityAttributes>.activities {
                let staleDate = activity.content.staleDate
                    ?? activity.attributes.startedAt.addingTimeInterval(Self.staleInterval)
                guard staleDate <= now else { continue }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func start(
        attributes: WalkActivityAttributes,
        state: WalkActivityAttributes.ContentState
    ) {
        sessionID = attributes.sessionID
        lastSubmittedState = state
        enqueue { [weak self] in
            guard let self else { return }
            await self.endActivities(except: attributes.sessionID, immediate: true)
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                _ = try Activity<WalkActivityAttributes>.request(
                    attributes: attributes,
                    content: self.content(for: state),
                    pushType: nil
                )
            } catch {
                OhanaLog.warning(
                    "Unable to start walk Live Activity: \(error.localizedDescription)",
                    category: "SystemSurfaces"
                )
            }
        }
    }

    func restore(
        attributes: WalkActivityAttributes,
        state: WalkActivityAttributes.ContentState
    ) {
        sessionID = attributes.sessionID
        lastSubmittedState = state
        enqueue { [weak self] in
            guard let self else { return }
            await self.endActivities(except: attributes.sessionID, immediate: true)
            if let activity = self.activity(for: attributes.sessionID) {
                await activity.update(self.content(for: state))
                return
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                _ = try Activity<WalkActivityAttributes>.request(
                    attributes: attributes,
                    content: self.content(for: state),
                    pushType: nil
                )
            } catch {
                OhanaLog.warning(
                    "Unable to restore walk Live Activity: \(error.localizedDescription)",
                    category: "SystemSurfaces"
                )
            }
        }
    }

    func update(_ state: WalkActivityAttributes.ContentState, force: Bool) {
        guard let sessionID else { return }
        guard force || shouldSubmit(state) else { return }
        lastSubmittedState = state
        enqueue { [weak self] in
            guard let self, let activity = self.activity(for: sessionID) else { return }
            await activity.update(self.content(for: state))
        }
    }

    func end(_ state: WalkActivityAttributes.ContentState, immediate: Bool) {
        guard let sessionID else { return }
        lastSubmittedState = state
        enqueue { [weak self] in
            guard let self else { return }
            if let activity = self.activity(for: sessionID) {
                let policy: ActivityUIDismissalPolicy = immediate
                    ? .immediate
                    : .after(Date().addingTimeInterval(30))
                await activity.end(self.content(for: state), dismissalPolicy: policy)
            }
            if self.sessionID == sessionID {
                self.sessionID = nil
                self.lastSubmittedState = nil
            }
        }
    }

    func endSession(_ requestedSessionID: UUID, immediate: Bool) {
        if sessionID == requestedSessionID {
            sessionID = nil
            lastSubmittedState = nil
        }
        enqueue { [weak self] in
            guard let self, let activity = self.activity(for: requestedSessionID) else { return }
            let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .default
            await activity.end(nil, dismissalPolicy: policy)
        }
    }

    func endAll(immediate: Bool) {
        sessionID = nil
        lastSubmittedState = nil
        enqueue { [weak self] in
            await self?.endActivities(except: nil, immediate: immediate)
        }
    }

    private func shouldSubmit(_ state: WalkActivityAttributes.ContentState) -> Bool {
        guard let previous = lastSubmittedState else { return true }
        let budget = workloadPolicy.walkLiveActivityUpdateBudget()
        guard budget.allowsAutomaticUpdates else { return false }
        if state.phase != previous.phase || state.poopCount != previous.poopCount {
            return true
        }
        if abs(state.distanceMeters - previous.distanceMeters) >= budget.minimumDistanceDeltaMeters {
            return true
        }
        return state.updatedAt.timeIntervalSince(previous.updatedAt) >= budget.maximumUpdateInterval
    }

    private func activity(for sessionID: UUID) -> Activity<WalkActivityAttributes>? {
        Activity<WalkActivityAttributes>.activities.first { $0.attributes.sessionID == sessionID }
    }

    private func content(
        for state: WalkActivityAttributes.ContentState
    ) -> ActivityContent<WalkActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(Self.staleInterval),
            relevanceScore: state.phase == .finished ? 0 : 1
        )
    }

    private func endActivities(except keptSessionID: UUID?, immediate: Bool) async {
        for activity in Activity<WalkActivityAttributes>.activities
            where activity.attributes.sessionID != keptSessionID {
            let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .default
            await activity.end(nil, dismissalPolicy: policy)
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = operationTask
        operationTask = Task { @MainActor in
            if let previous {
                await previous.value
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
}

@MainActor
final class NoopWalkActivityPresenter: WalkActivityPresenting {
    func dismissStaleActivities() {}
    func start(attributes _: WalkActivityAttributes, state _: WalkActivityAttributes.ContentState) {}
    func restore(attributes _: WalkActivityAttributes, state _: WalkActivityAttributes.ContentState) {}
    func update(_: WalkActivityAttributes.ContentState, force _: Bool) {}
    func end(_: WalkActivityAttributes.ContentState, immediate _: Bool) {}
    func endSession(_: UUID, immediate _: Bool) {}
    func endAll(immediate _: Bool) {}
}
