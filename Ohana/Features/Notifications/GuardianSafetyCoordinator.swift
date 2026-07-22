//
//  GuardianSafetyCoordinator.swift
//  Ohana
//
//  App-facing orchestration for account, minimal remote projections, device
//  reachability, and reliable Presence signal delivery.
//

import Foundation
import Observation
import SwiftData
import UserNotifications

nonisolated enum GuardianSafetyDashboardState: Equatable, Sendable {
    case unavailable
    case signedOut
    case loading
    case loaded
    case failed(message: String)
}

@MainActor
protocol GuardianSafetyManaging: AnyObject {
    var dashboardState: GuardianSafetyDashboardState { get }
    var dashboard: GuardianSafetyDashboardSnapshot { get }
    var accountState: GuardianAccountState { get }
    var latestInvitation: GuardianInvitationSnapshot? { get }

    func start() async
    func signIn() async
    func signOut() async
    func refresh() async
    func syncFamilyEntitlement() async
    func createInvitation() async
    func acceptInvitation(code: String) async
    func updatePolicy(_ request: GuardianPolicyUpdateRequest, ownerHumanID: UUID) async
    func acknowledgeIncident(id: String) async
    func markIncidentOpened(id: String) async
    func revokeRelationship(id: String) async
    func registerAPNSToken(_ token: Data) async
    func notificationReachabilityChanged() async
    func flushOutbox() async
    func stopMonitoringForEntitlementLoss() async
    func deleteOnlineAccount() async
    func deleteLegacySafetyContacts() throws -> Int
}

@MainActor
@Observable
final class GuardianSafetyCoordinator: GuardianSafetyManaging {
    private(set) var dashboardState: GuardianSafetyDashboardState
    private(set) var dashboard = GuardianSafetyDashboardSnapshot.empty
    private(set) var latestInvitation: GuardianInvitationSnapshot?
    private(set) var accountState: GuardianAccountState

    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private let commerce: CommerceEntitlementService
    @ObservationIgnored private let notifications: any UserNotificationManaging
    @ObservationIgnored private let configuration: GuardianSafetyConfiguration?
    @ObservationIgnored private let account: GuardianAccountService
    @ObservationIgnored private let api: GuardianSafetyAPIClient?
    @ObservationIgnored private let deviceID: String
    @ObservationIgnored private var apnsToken: Data?
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var isFlushingOutbox = false

    init(
        modelContainer: ModelContainer,
        commerce: CommerceEntitlementService,
        notifications: any UserNotificationManaging,
        configuration: GuardianSafetyConfiguration? = .current,
        account: GuardianAccountService? = nil,
        api: GuardianSafetyAPIClient? = nil,
        deviceID: String = GuardianDeviceIdentityStore.shared.identifier()
    ) {
        self.modelContainer = modelContainer
        self.commerce = commerce
        self.notifications = notifications
        self.configuration = configuration
        self.deviceID = deviceID
        let accountService = account ?? GuardianAccountService(configuration: configuration)
        self.account = accountService
        if let api {
            self.api = api
        } else if let configuration {
            self.api = GuardianSafetyAPIClient(configuration: configuration)
        } else {
            self.api = nil
        }
        accountState = accountService.state
        dashboardState = configuration == nil ? .unavailable : .signedOut
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        await account.restore()
        accountState = account.state
        guard account.isSignedIn else {
            dashboardState = configuration == nil ? .unavailable : .signedOut
            return
        }
        await flushOutbox()
        await refresh()
    }

    func signIn() async {
        do {
            try await account.signIn()
            accountState = account.state
            await registerCurrentDeviceIfPossible()
            await flushOutbox()
            await refresh()
        } catch {
            accountState = account.state
            dashboardState = .failed(message: error.localizedDescription)
        }
    }

    func signOut() async {
        if account.isSignedIn, let api {
            do {
                let token = try await account.validAccessToken()
                try await api.unregisterDevice(
                    GuardianDeviceRemovalRequest(deviceID: deviceID),
                    accessToken: token
                )
            } catch {
                dashboardState = .failed(message: error.localizedDescription)
                return
            }
        }
        clearLocalSession()
    }

    private func clearLocalSession() {
        account.signOut()
        accountState = account.state
        dashboard = .empty
        latestInvitation = nil
        dashboardState = configuration == nil ? .unavailable : .signedOut
    }

    func refresh() async {
        guard let api else {
            dashboardState = .unavailable
            return
        }
        guard account.isSignedIn else {
            accountState = account.state
            dashboardState = .signedOut
            return
        }
        dashboardState = .loading
        do {
            let token = try await account.validAccessToken()
            var snapshot = try await api.dashboard(accessToken: token)
            if let policy = snapshot.policy,
               policy.isEnabled,
               policy.timeZoneIdentifier != TimeZone.current.identifier,
               commerce.hasFamilyEntitlement {
                snapshot = try await api.updatePolicy(
                    GuardianPolicyUpdateRequest(
                        isEnabled: true,
                        weekdays: policy.weekdays,
                        deadlineHour: policy.deadlineHour,
                        deadlineMinute: policy.deadlineMinute,
                        gracePeriodMinutes: policy.gracePeriodMinutes,
                        pauseUntil: policy.pauseUntil,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        scheduleRevision: policy.scheduleRevision + 1
                    ),
                    accessToken: token
                )
            }
            try apply(snapshot)
            dashboard = snapshot
            accountState = account.state
            dashboardState = .loaded
        } catch {
            accountState = account.state
            dashboardState = .failed(message: error.localizedDescription)
        }
    }

    func createInvitation() async {
        guard commerce.hasFamilyEntitlement else {
            dashboardState = .failed(message: String(localized: "guardian.family.required", defaultValue: "Ohana Family is required to invite guardians."))
            return
        }
        await syncFamilyEntitlement()
        if case .failed = dashboardState { return }
        await perform { api, token in
            let invitation = try await api.createInvitation(accessToken: token)
            self.latestInvitation = invitation
        }
    }

    func acceptInvitation(code: String) async {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else { return }
        await performAndApply { api, token in
            try await api.acceptInvitation(code: cleanCode, accessToken: token)
        }
    }

    func updatePolicy(_ request: GuardianPolicyUpdateRequest, ownerHumanID: UUID) async {
        guard commerce.hasFamilyEntitlement else {
            await stopMonitoringForEntitlementLoss()
            dashboardState = .failed(message: String(localized: "guardian.family.required", defaultValue: "Ohana Family is required for App guardian alerts."))
            return
        }
        await syncFamilyEntitlement()
        if case .failed = dashboardState { return }
        if request.isEnabled {
            let granted = await notifications.requestPermission()
            guard granted else {
                dashboardState = .failed(message: String(localized: "guardian.notifications.required", defaultValue: "Enable notifications before turning on Family guardian alerts."))
                return
            }
        }
        await performAndApply(ownerHumanID: ownerHumanID) { api, token in
            try await api.updatePolicy(request, accessToken: token)
        }
        await registerCurrentDeviceIfPossible()
    }

    func acknowledgeIncident(id: String) async {
        await performAndApply { api, token in
            try await api.acknowledgeIncident(id: id, accessToken: token)
        }
    }

    func syncFamilyEntitlement() async {
        guard commerce.hasFamilyEntitlement else { return }
        guard let signedTransactionInfo = commerce.latestVerifiedFamilyTransactionJWS else {
            dashboardState = .failed(message: String(
                localized: "guardian.entitlement.verification-needed",
                defaultValue: "Ohana Family must be verified with the App Store before online guarding can start."
            ))
            return
        }
        await performAndApply { api, token in
            try await api.verifyFamilyEntitlement(
                GuardianEntitlementVerificationRequest(signedTransactionInfo: signedTransactionInfo),
                accessToken: token
            )
        }
    }

    func markIncidentOpened(id: String) async {
        await performAndApply { api, token in
            try await api.markIncidentOpened(id: id, accessToken: token)
        }
    }

    func revokeRelationship(id: String) async {
        await performAndApply { api, token in
            try await api.revokeRelationship(id: id, accessToken: token)
        }
    }

    func registerAPNSToken(_ token: Data) async {
        apnsToken = token
        await registerCurrentDeviceIfPossible()
    }

    func notificationReachabilityChanged() async {
        await registerCurrentDeviceIfPossible()
        await refresh()
    }

    func flushOutbox() async {
        guard !isFlushingOutbox, account.isSignedIn, let api else { return }
        isFlushingOutbox = true
        defer { isFlushingOutbox = false }
        let context = modelContainer.mainContext
        let now = Date()
        var descriptor = FetchDescriptor<GuardianSafetySyncOutbox>(
            predicate: #Predicate {
                ($0.stateRaw == "pending" || $0.stateRaw == "failed" || $0.stateRaw == "sending")
                    && $0.nextAttemptAt <= now
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 50
        let events: [GuardianSafetySyncOutbox]
        do {
            events = try context.fetch(descriptor)
        } catch {
            return
        }
        guard !events.isEmpty else { return }

        for event in events {
            event.state = .sending
            event.updatedAt = now
            event.nextAttemptAt = now.addingTimeInterval(300)
        }
        guard context.safeSaveResult(publishFailureEvent: true).didSave else {
            context.rollback()
            return
        }

        do {
            let token = try await account.validAccessToken()
            let response = try await api.uploadSignals(
                GuardianSignalBatchRequest(signals: events.map(Self.signalUpload)),
                accessToken: token
            )
            let accepted = Set(response.acceptedEventKeys)
            for event in events {
                if accepted.contains(event.eventKey) {
                    event.state = .sent
                    event.lastErrorCode = nil
                } else {
                    event.state = .failed
                    event.lastErrorCode = response.rejectedEventKeys[event.eventKey] ?? "rejected"
                    scheduleRetry(event, now: now)
                }
                event.updatedAt = Date()
            }
        } catch {
            for event in events {
                event.state = .failed
                event.lastErrorCode = "transport"
                scheduleRetry(event, now: now)
                event.updatedAt = Date()
            }
        }
        if !context.safeSaveResult(publishFailureEvent: true).didSave {
            context.rollback()
        }
    }

    func stopMonitoringForEntitlementLoss() async {
        let context = modelContainer.mainContext
        guard let ownerID = UserDefaultsPresenceOwnerSelection().ownerHumanId else { return }
        do {
            try LiveGuardianSafetyOutboxStager().stageMonitoringStopped(
                ownerHumanId: ownerID,
                reason: .entitlementLost,
                occurredAt: Date(),
                timeZone: .current,
                context: context
            )
            guard context.safeSaveResult(publishFailureEvent: true).didSave else {
                context.rollback()
                return
            }
            await flushOutbox()
        } catch {
            context.rollback()
        }
    }

    func deleteOnlineAccount() async {
        guard account.isSignedIn, let api else {
            clearLocalSession()
            return
        }
        let context = modelContainer.mainContext
        if let ownerID = UserDefaultsPresenceOwnerSelection().ownerHumanId {
            try? LiveGuardianSafetyOutboxStager().stageMonitoringStopped(
                ownerHumanId: ownerID,
                reason: .accountDeleted,
                occurredAt: Date(),
                timeZone: .current,
                context: context
            )
            _ = context.safeSaveResult(publishFailureEvent: true)
        }
        do {
            let token = try await account.validAccessToken()
            try? await api.unregisterDevice(
                GuardianDeviceRemovalRequest(deviceID: deviceID),
                accessToken: token
            )
            try await api.deleteAccount(accessToken: token)
            purgeRemoteProjections(context: context)
            GuardianDeviceIdentityStore.shared.clear()
            clearLocalSession()
        } catch {
            dashboardState = .failed(message: error.localizedDescription)
        }
    }

    func deleteLegacySafetyContacts() throws -> Int {
        let context = modelContainer.mainContext
        let contacts = try context.fetch(FetchDescriptor<SafetyContact>())
        for contact in contacts {
            context.delete(contact) // derived-state: allow retired device-local data excluded from backup and CloudSync
        }
        guard context.safeSaveResult(publishFailureEvent: true).didSave else {
            context.rollback()
            throw GuardianSafetyAPIError.invalidResponse
        }
        return contacts.count
    }

    private func perform(
        _ operation: (GuardianSafetyAPIClient, String) async throws -> Void
    ) async {
        guard let api else {
            dashboardState = .unavailable
            return
        }
        do {
            let token = try await account.validAccessToken()
            try await operation(api, token)
            accountState = account.state
            dashboardState = .loaded
        } catch {
            accountState = account.state
            dashboardState = .failed(message: error.localizedDescription)
        }
    }

    private func performAndApply(
        ownerHumanID: UUID? = nil,
        _ operation: (GuardianSafetyAPIClient, String) async throws -> GuardianSafetyDashboardSnapshot
    ) async {
        guard let api else {
            dashboardState = .unavailable
            return
        }
        dashboardState = .loading
        do {
            let token = try await account.validAccessToken()
            let snapshot = try await operation(api, token)
            try apply(snapshot, ownerHumanID: ownerHumanID)
            dashboard = snapshot
            accountState = account.state
            dashboardState = .loaded
        } catch {
            accountState = account.state
            dashboardState = .failed(message: error.localizedDescription)
        }
    }

    private func registerCurrentDeviceIfPossible() async {
        guard let tokenData = apnsToken, account.isSignedIn else { return }
        let status = await notifications.authorizationStatus()
        let request = GuardianDeviceRegistrationRequest(
            deviceID: deviceID,
            apnsToken: tokenData.map { String(format: "%02x", $0) }.joined(),
            environment: Self.apnsEnvironment,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            notificationsAuthorized: status == .authorized || status == .provisional || status == .ephemeral
        )
        await perform { api, token in
            try await api.registerDevice(request, accessToken: token)
        }
    }

    private func apply(
        _ snapshot: GuardianSafetyDashboardSnapshot,
        ownerHumanID explicitOwnerHumanID: UUID? = nil
    ) throws {
        let context = modelContainer.mainContext
        let ownerHumanID = explicitOwnerHumanID ?? UserDefaultsPresenceOwnerSelection().ownerHumanId

        if let remote = snapshot.policy, let ownerHumanID {
            let key = GuardianSafetyPolicyProjection.key(ownerHumanId: ownerHumanID)
            var descriptor = FetchDescriptor<GuardianSafetyPolicyProjection>(
                predicate: #Predicate { $0.policyKey == key }
            )
            descriptor.fetchLimit = 1
            let local = try context.fetch(descriptor).first ?? GuardianSafetyPolicyProjection(
                ownerHumanId: ownerHumanID
            )
            if local.modelContext == nil { context.insert(local) }
            local.serverPolicyId = remote.id
            local.isEnabled = remote.isEnabled
            local.status = remote.status
            local.weekdays = Set(remote.weekdays)
            local.deadlineHour = remote.deadlineHour
            local.deadlineMinute = remote.deadlineMinute
            local.gracePeriodMinutes = remote.gracePeriodMinutes
            local.pauseUntil = remote.pauseUntil
            local.timeZoneIdentifier = remote.timeZoneIdentifier
            local.scheduleRevision = remote.scheduleRevision
            local.acceptedGuardianCount = remote.acceptedGuardianCount
            local.reachableGuardianCount = remote.reachableGuardianCount
            local.lastSyncedAt = Date()
            local.updatedAt = remote.updatedAt
        }

        for remote in snapshot.relationships {
            let identifier = remote.id
            var descriptor = FetchDescriptor<GuardianRelationshipProjection>(
                predicate: #Predicate { $0.serverRelationshipId == identifier }
            )
            descriptor.fetchLimit = 1
            let local = try context.fetch(descriptor).first ?? GuardianRelationshipProjection(
                serverRelationshipId: identifier,
                ownerHumanId: remote.currentUserIsGuardian ? nil : ownerHumanID,
                displayName: remote.displayLabel,
                status: remote.status,
                currentUserIsGuardian: remote.currentUserIsGuardian,
                createdAt: remote.acceptedAt ?? remote.updatedAt
            )
            if local.modelContext == nil { context.insert(local) }
            local.ownerHumanIdRaw = remote.currentUserIsGuardian ? nil : ownerHumanID?.uuidString
            local.displayName = remote.displayLabel
            local.status = remote.status
            local.reachability = remote.reachability
            local.currentUserIsGuardian = remote.currentUserIsGuardian
            local.acceptedAt = remote.acceptedAt
            local.revokedAt = remote.revokedAt
            local.lastOpenedAt = remote.lastOpenedAt
            local.lastAcknowledgedAt = remote.lastAcknowledgedAt
            local.latestNotificationState = remote.latestNotificationState
            local.latestNotificationUpdatedAt = remote.latestNotificationUpdatedAt
            local.protectedPolicyStatus = remote.protectedPolicyStatus
            local.protectedPauseUntil = remote.protectedPauseUntil
            local.updatedAt = remote.updatedAt
        }

        for remote in snapshot.incidents {
            let identifier = remote.id
            var descriptor = FetchDescriptor<GuardianIncidentProjection>(
                predicate: #Predicate { $0.serverIncidentId == identifier }
            )
            descriptor.fetchLimit = 1
            let local = try context.fetch(descriptor).first ?? GuardianIncidentProjection(
                serverIncidentId: identifier,
                serverPolicyId: remote.policyID,
                ownerHumanId: ownerHumanID,
                status: remote.status,
                lastGuardDayKey: remote.lastGuardDayKey,
                consecutiveMisses: remote.consecutiveMisses,
                createdAt: remote.createdAt
            )
            if local.modelContext == nil { context.insert(local) }
            local.serverPolicyId = remote.policyID
            local.status = remote.status
            local.lastGuardDayKey = remote.lastGuardDayKey
            local.consecutiveMisses = remote.consecutiveMisses
            local.initialSubmittedAt = remote.initialSubmittedAt
            local.followUpSubmittedAt = remote.followUpSubmittedAt
            local.acknowledgedAt = remote.acknowledgedAt
            local.recoveredAt = remote.recoveredAt
            local.updatedAt = remote.updatedAt
        }

        guard context.safeSaveResult(publishFailureEvent: true).didSave else {
            context.rollback()
            throw GuardianSafetyAPIError.invalidResponse
        }
    }

    private func scheduleRetry(_ event: GuardianSafetySyncOutbox, now: Date) {
        event.attemptCount += 1
        let seconds = min(pow(2, Double(min(event.attemptCount, 8))) * 30, 21600)
        event.nextAttemptAt = now.addingTimeInterval(seconds)
    }

    private func purgeRemoteProjections(context: ModelContext) {
        do {
            for policy in try context.fetch(FetchDescriptor<GuardianSafetyPolicyProjection>()) {
                context.delete(policy) // derived-state: allow local-only API projection after remote account deletion
            }
            for relationship in try context.fetch(FetchDescriptor<GuardianRelationshipProjection>()) {
                context.delete(relationship) // derived-state: allow local-only API projection after remote account deletion
            }
            for incident in try context.fetch(FetchDescriptor<GuardianIncidentProjection>()) {
                context.delete(incident) // derived-state: allow local-only API projection after remote account deletion
            }
            for event in try context.fetch(FetchDescriptor<GuardianSafetySyncOutbox>()) {
                context.delete(event) // derived-state: allow local-only delivered outbox after remote account deletion
            }
            if !context.safeSaveResult(publishFailureEvent: true).didSave {
                context.rollback()
            }
        } catch {
            context.rollback()
        }
    }

    private static func signalUpload(_ event: GuardianSafetySyncOutbox) -> GuardianSignalUpload {
        GuardianSignalUpload(
            eventKey: event.eventKey,
            kind: event.eventKind,
            dayKey: event.dayKey,
            occurredAt: event.occurredAt,
            timeZoneIdentifier: event.timeZoneIdentifier,
            stopReason: event.stopReason
        )
    }

    private static var apnsEnvironment: String {
        #if DEBUG
            "sandbox"
        #else
            "production"
        #endif
    }
}

@MainActor
@Observable
final class DisabledGuardianSafetyCoordinator: GuardianSafetyManaging {
    private(set) var dashboardState: GuardianSafetyDashboardState = .unavailable
    private(set) var dashboard = GuardianSafetyDashboardSnapshot.empty
    private(set) var accountState: GuardianAccountState = .unavailable
    private(set) var latestInvitation: GuardianInvitationSnapshot?

    func start() async {}
    func signIn() async {}
    func signOut() async {}
    func refresh() async {}
    func syncFamilyEntitlement() async {}
    func createInvitation() async {}
    func acceptInvitation(code _: String) async {}
    func updatePolicy(_: GuardianPolicyUpdateRequest, ownerHumanID _: UUID) async {}
    func acknowledgeIncident(id _: String) async {}
    func markIncidentOpened(id _: String) async {}
    func revokeRelationship(id _: String) async {}
    func registerAPNSToken(_: Data) async {}
    func notificationReachabilityChanged() async {}
    func flushOutbox() async {}
    func stopMonitoringForEntitlementLoss() async {}
    func deleteOnlineAccount() async {}
    func deleteLegacySafetyContacts() throws -> Int { 0 }
}
