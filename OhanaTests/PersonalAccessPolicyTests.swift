import Foundation
import Testing
@testable import Ohana

struct PersonalAccessPolicyTests {
    @Test func paidLocalFeaturesUseOneSemanticCapabilityMapping() {
        for feature in PersonalFeature.allCases {
            #expect(!PersonalFeatureAccessPolicy.allows(feature, level: .free))
            #expect(PersonalFeatureAccessPolicy.allows(feature, level: .personal))
        }
    }

    @Test func currentFreeLimitsMatchTheApprovedCommercialContract() {
        let limits = PersonalFreeLimits.current

        #expect(limits.activePets == 1)
        #expect(limits.activeHumans == 2)
        #expect(limits.activePlants == 5)
        #expect(limits.ordinaryActivePlans == 3)
    }

    @Test func freeAllowsEachActiveResourceUpToItsLimit() {
        let cases: [(PersonalUsageSnapshot, PersonalAccessRequest, PersonalLimitedResource, Int)] = [
            (.init(activePetCount: 0), .addActivePet(), .activePet, 1),
            (.init(activeHumanCount: 1), .addActiveHuman(), .activeHuman, 2),
            (.init(activePlantCount: 4), .addActivePlant(), .activePlant, 5),
            (
                .init(ordinaryActivePlanCount: 2),
                .createPlan(.ordinary),
                .ordinaryActivePlan,
                3
            )
        ]

        for (usage, request, resource, resultingCount) in cases {
            let disposition = PersonalAccessPolicy.disposition(
                level: .free,
                usage: usage,
                request: request
            )

            #expect(
                disposition.allowance == .withinFreeLimit(
                    resource: resource,
                    resultingCount: resultingCount,
                    limit: PersonalFreeLimits.current.limit(for: resource)
                )
            )
        }
    }

    @Test func freeDenialCarriesExactReasonAndRecoveryActions() throws {
        let usage = PersonalUsageSnapshot(
            activePetCount: 1,
            activeHumanCount: 2,
            activePlantCount: 5,
            ordinaryActivePlanCount: 3
        )

        for resource in PersonalLimitedResource.allCases {
            let disposition = PersonalAccessPolicy.disposition(
                level: .free,
                usage: usage,
                request: .changeLimitedUsage(.adding(resource))
            )
            let denial = try #require(disposition.denial)
            let reason = try #require(freeLimitDenial(from: denial.reason))

            #expect(!disposition.isAllowed)
            #expect(reason.resource == resource)
            #expect(reason.currentCount == PersonalFreeLimits.current.limit(for: resource))
            #expect(reason.attemptedCount == reason.currentCount + 1)
            #expect(reason.limit == reason.currentCount)
            #expect(!reason.preservesGrandfatheredData)
            #expect(denial.primaryNextAction == .offerPersonalUpgrade)
            #expect(denial.secondaryNextAction == .reviewActiveItems(resource))
        }
    }

    @Test func personalNeverAppliesFreeQuantityLimits() {
        let usage = PersonalUsageSnapshot(
            activePetCount: 200,
            activeHumanCount: 200,
            activePlantCount: 200,
            ordinaryActivePlanCount: 200
        )

        for resource in PersonalLimitedResource.allCases {
            let disposition = PersonalAccessPolicy.disposition(
                level: .personal,
                usage: usage,
                request: .changeLimitedUsage(.adding(resource, count: 100))
            )
            #expect(disposition.allowance == .personalUnlimited)
        }
    }

    @Test func grandfatheredHouseholdsKeepExistingDataAndMayReduceUsage() {
        let usage = PersonalUsageSnapshot(
            activePetCount: 4,
            activeHumanCount: 5,
            activePlantCount: 9,
            ordinaryActivePlanCount: 8
        )

        #expect(usage.grandfatheredResources() == Set(PersonalLimitedResource.allCases))

        for operation in PersonalExistingDataOperation.allCases {
            let disposition = PersonalAccessPolicy.disposition(
                level: .free,
                usage: usage,
                request: .useExistingData(operation)
            )
            #expect(disposition.allowance == .protectedExistingData(operation))
        }

        for resource in PersonalLimitedResource.allCases {
            let currentCount = usage.count(for: resource)
            let disposition = PersonalAccessPolicy.disposition(
                level: .free,
                usage: usage,
                request: .changeLimitedUsage(.removing(resource))
            )

            #expect(
                disposition.allowance == .nonIncreasingFreeUsage(
                    resource: resource,
                    currentCount: currentCount,
                    resultingCount: currentCount - 1,
                    limit: PersonalFreeLimits.current.limit(for: resource),
                    preservesGrandfatheredData: true
                )
            )
        }
    }

    @Test func grandfatheringBlocksOnlyFurtherGrowth() throws {
        let usage = PersonalUsageSnapshot(activePetCount: 3)
        let noGrowth = PersonalAccessPolicy.disposition(
            level: .free,
            usage: usage,
            request: .changeLimitedUsage(.init(resource: .activePet, countDelta: 0))
        )
        let growth = PersonalAccessPolicy.disposition(
            level: .free,
            usage: usage,
            request: .addActivePet()
        )

        #expect(noGrowth.isAllowed)
        let denial = try #require(growth.denial)
        let reason = denial.reason
        let limitDenial = try #require(freeLimitDenial(from: reason))
        #expect(limitDenial.currentCount == 3)
        #expect(limitDenial.attemptedCount == 4)
        #expect(limitDenial.limit == 1)
        #expect(limitDenial.preservesGrandfatheredData)
    }

    @Test func healthCriticalPlansRemainFreeAtAnyOrdinaryPlanCount() {
        let usage = PersonalUsageSnapshot(
            ordinaryActivePlanCount: 20,
            healthCriticalActivePlanCount: 100
        )
        let critical = PersonalAccessPolicy.disposition(
            level: .free,
            usage: usage,
            request: .createPlan(.healthCritical)
        )
        let ordinary = PersonalAccessPolicy.disposition(
            level: .free,
            usage: usage,
            request: .createPlan(.ordinary)
        )

        #expect(critical.allowance == .healthCriticalPlanExemption)
        #expect(!ordinary.isAllowed)
        #expect(usage.totalActivePlanCount == 120)
    }

    @Test func structuredHealthEventsAreExemptWithoutTitleHeuristics() {
        let exempt: [EventType] = [
            .health,
            .vaccine,
            .externalDeworming,
            .internalDeworming,
            .vetVisit,
            .medication,
            .petMedication,
            .petMedicationDose
        ]
        let ordinary = EventType.allCases.filter { !exempt.contains($0) }

        #expect(exempt.allSatisfy { PersonalPlanQuotaClassifier.quotaClass(for: $0) == .healthCritical })
        #expect(ordinary.allSatisfy { PersonalPlanQuotaClassifier.quotaClass(for: $0) == .ordinary })
    }

    @Test func snapshotNormalizesImpossibleNegativeCounts() {
        let usage = PersonalUsageSnapshot(
            activePetCount: -1,
            activeHumanCount: -2,
            activePlantCount: -3,
            ordinaryActivePlanCount: -4,
            healthCriticalActivePlanCount: -5
        )

        #expect(usage == PersonalUsageSnapshot())
    }

    private func freeLimitDenial(
        from reason: PersonalAccessDenialReason
    ) -> PersonalFreeLimitDenial? {
        if case let .wouldExceedFreeLimit(denial) = reason { return denial }
        return nil
    }
}
