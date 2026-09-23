import Foundation
import Testing
@testable import Ohana

@MainActor
struct HomeSurfaceInvalidationTests {
    @Test func careMutationPublishesAggregateHomeTokenWithDomainAndEntities() {
        let center = ReadModelRevisionCenter()
        let petID = UUID()
        let humanID = UUID()

        center.publish(
            DomainMutationResult(
                command: .quickCare(entityID: petID, action: "feed"),
                affectedEntityIDs: [petID, humanID],
                note: "test.home.surface.care"
            )
        )

        let token = center.homeSurfaceInvalidation
        #expect(token.surface == .home)
        #expect(token.value == 1)
        #expect(token.domains == Set([.care, .health]))
        #expect(token.domainRevisions == [.care: 1, .health: 1])
        #expect(token.affectedEntityIDs == Set([petID, humanID]))
        #expect(token.requiresFullRefresh)
        #expect(token.isRelevant(toVisibleEntityIDs: []))
    }

    @Test func presentationMutationUsesEntityScopeInsteadOfInvalidatingOtherHomeCards() {
        let center = ReadModelRevisionCenter()
        let changedID = UUID()
        let otherVisibleID = UUID()

        center.publish(
            DomainMutationResult(
                command: .memberProfile(entityID: changedID, kind: "pet"),
                affectedEntityIDs: [changedID],
                note: "test.home.surface.profile"
            )
        )

        let token = center.homeSurfaceInvalidation
        #expect(token.domains == Set([.appearance]))
        #expect(token.domainRevisions == [.appearance: 1])
        #expect(!token.requiresFullRefresh)
        #expect(token.isRelevant(toVisibleEntityIDs: [changedID]))
        #expect(!token.isRelevant(toVisibleEntityIDs: [otherVisibleID]))
    }

    @Test func unrelatedRecordMutationLeavesScopedHomeTokenUntouchedWhileLegacyRevisionRemainsAvailable() {
        let center = ReadModelRevisionCenter()

        center.publish(
            DomainMutationResult(
                command: .petPhotoCreate(petID: UUID()),
                affectedEntityIDs: [UUID()],
                note: "test.home.surface.photo"
            )
        )

        #expect(center.homeSurfaceInvalidation == .empty)
        #expect(center.homeRevision.value == 1)
    }

    @Test func coveredSurfaceTokensMergeIntoOneLatestRefresh() {
        let firstID = UUID()
        let secondID = UUID()
        let first = HomeSurfaceInvalidationToken(
            surface: .home,
            value: 4,
            domains: [.appearance],
            affectedEntityIDs: [firstID],
            requiresFullRefresh: false,
            changedAt: Date(timeIntervalSince1970: 10),
            lastCommand: .memberProfile(entityID: firstID, kind: "pet")
        )
        let second = HomeSurfaceInvalidationToken(
            surface: .home,
            value: 7,
            domains: [.care],
            affectedEntityIDs: [secondID],
            requiresFullRefresh: true,
            changedAt: Date(timeIntervalSince1970: 20),
            lastCommand: .quickCare(entityID: secondID, action: "water")
        )

        let merged = first.merging(second)

        #expect(merged.value == 7)
        #expect(merged.domains == Set([.appearance, .care]))
        #expect(merged.domainRevisions == [.appearance: 4, .care: 7])
        #expect(merged.affectedEntityIDs == Set([firstID, secondID]))
        #expect(merged.requiresFullRefresh)
        #expect(merged.lastCommand == second.lastCommand)
    }

    @Test func coveredSurfacePolicyNeverStartsAReadModelRefresh() {
        #expect(
            !HomeSurfaceRefreshPolicy.allowsReadModelRefresh(
                isHomeSurfaceVisible: false,
                isRuntimeRefreshAllowed: true
            )
        )
        #expect(
            !HomeSurfaceRefreshPolicy.allowsReadModelRefresh(
                isHomeSurfaceVisible: true,
                isRuntimeRefreshAllowed: false
            )
        )
        #expect(
            HomeSurfaceRefreshPolicy.allowsReadModelRefresh(
                isHomeSurfaceVisible: true,
                isRuntimeRefreshAllowed: true
            )
        )
    }

    @Test func visibleInitialSnapshotRemainsAvailableWhenRoutineRefreshIsPaused() {
        let policy = AppWorkloadPolicy()

        #expect(policy.allowsEssentialInitialSnapshotRead(isVisible: true, isLive: true, hasSnapshot: false))
        #expect(!policy.allowsEssentialInitialSnapshotRead(isVisible: false, isLive: true, hasSnapshot: false))
        #expect(!policy.allowsEssentialInitialSnapshotRead(isVisible: true, isLive: false, hasSnapshot: false))
        #expect(!policy.allowsEssentialInitialSnapshotRead(isVisible: true, isLive: true, hasSnapshot: true))
    }

    @Test func suspendingAnUnresolvedHomeSnapshotRetainsAForcedRefresh() {
        #expect(
            HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuspension(
                snapshotIsReady: false,
                wasPending: false
            )
        )
        #expect(
            HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuspension(
                snapshotIsReady: true,
                wasPending: true
            )
        )
        #expect(
            !HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuspension(
                snapshotIsReady: true,
                wasPending: false
            )
        )
    }

    @Test func suppressedRefreshRequestAlwaysQueuesAForcedRefreshForResume() {
        #expect(
            HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuppressedRequest(
                requestWasSuppressed: true,
                wasPending: false
            )
        )
        #expect(
            HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuppressedRequest(
                requestWasSuppressed: true,
                wasPending: true
            )
        )
        #expect(
            !HomeSurfaceRefreshPolicy.pendingForcedRefreshAfterSuppressedRequest(
                requestWasSuppressed: false,
                wasPending: false
            )
        )
    }
}
