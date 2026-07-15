import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HouseholdStarterJourneyServiceTests {
    @Test func catalogAndSnapshotStaySmallAndAnchorCurrentHumanAndFirstPet() throws {
        #expect(HouseholdStarterJourneyPolicy.totalRewardCoconuts == 400)
        #expect(HouseholdStarterJourneyTask.humanProfile.rewardCoconuts == 100)
        #expect(HouseholdStarterJourneyTask.petProfile.rewardCoconuts == 100)
        #expect(HouseholdStarterJourneyTask.identityProtection.rewardCoconuts == 60)
        #expect(HouseholdStarterJourneyTask.healthProtection.rewardCoconuts == 80)
        #expect(HouseholdStarterJourneyTask.carePlan.rewardCoconuts == 40)
        #expect(HouseholdStarterJourneyTask.firstCare.rewardCoconuts == 20)
        #expect(HouseholdStarterJourneyCheckpoint.petIdentityDocuments.allowedResolutions.contains(.preferNotToSay))
        #expect(HouseholdStarterJourneyCheckpoint.petHealthProtection.allowedResolutions.contains(.preferNotToSay))

        let firstHuman = Human(name: "First")
        firstHuman.createdAt = Date(timeIntervalSince1970: 1)
        firstHuman.birthday = Date(timeIntervalSince1970: 1)
        firstHuman.avatarImageSignature = "custom"
        let activeHuman = Human(name: "Active")
        activeHuman.createdAt = Date(timeIntervalSince1970: 2)
        let firstPet = Pet(name: "First pet", species: "cat")
        firstPet.createdAt = Date(timeIntervalSince1970: 1)
        let laterPet = Pet(name: "Later pet", species: "dog")
        laterPet.createdAt = Date(timeIntervalSince1970: 2)
        laterPet.birthday = Date()
        laterPet.gender = "female"
        laterPet.avatarImageSignature = "custom"

        let snapshot = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: activeHuman.id.uuidString,
            humans: [firstHuman, activeHuman],
            pets: [laterPet, firstPet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: laterPet.id,
                hasProtectionDocument: true,
                hasInsurance: true,
                hasPreventiveHealthRecord: true,
                hasExplicitCarePlan: true,
                hasDefaultRecommendedCarePlan: true
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )

        #expect(snapshot.activeHumanID == activeHuman.id)
        #expect(snapshot.state(for: .humanProfile)?.targetID == activeHuman.id)
        #expect(snapshot.state(for: .petProfile)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .identityProtection)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .healthProtection)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .carePlan)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .firstCare)?.targetID == firstPet.id)
        #expect(snapshot.state(for: .petProfile)?.completedCheckpointCount == 0)
        #expect(snapshot.state(for: .firstCare)?.status == .actionRequired)
        #expect(snapshot.visibleTaskStates.count == 3)
    }

    @Test func resolutionsAreWhitelistedIdempotentAndDoNotPersistProfileValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Sensitive name")
        context.insert(human)
        try context.save()
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)

        let first = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        let duplicate = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        let invalid = HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .preferNotToSay,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )

        #expect(first.didSucceed)
        #expect(duplicate == .unchanged(task: .humanProfile, checkpoint: .humanAppearance, resolution: .reviewed))
        #expect(invalid == .invalidCheckpoint)
        let markers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.checkpointActionType
        }
        #expect(markers.count == 1)
        #expect(!markers[0].metadataJSON.contains(human.name))
    }

    @Test func carePlanResolutionNeedsARealRecommendedPlanAndFirstCareNeedsARealCareFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let unavailable = HouseholdStarterJourneyService.recordResolution(
            task: .carePlan,
            checkpoint: .acceptedRecommendedCarePlan,
            resolution: .reviewed,
            subjectID: pet.id,
            context: context,
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        )
        #expect(unavailable == .invalidCheckpoint)

        let base = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: pet.id,
                hasProtectionDocument: false,
                hasInsurance: false,
                hasPreventiveHealthRecord: false,
                hasExplicitCarePlan: false,
                hasDefaultRecommendedCarePlan: true
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )
        #expect(base.state(for: .carePlan)?.availableResolutionCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(base.state(for: .firstCare)?.status == .actionRequired)

        let unrelated = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "weight"
        )
        let care = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: "feeding"
        )
        let withoutCare = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: [unrelated],
            coconutLedgerEntries: []
        )
        let withCare = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: .empty,
            careLedgerEvents: [unrelated, care],
            coconutLedgerEntries: []
        )
        #expect(withoutCare.state(for: .firstCare)?.status == .actionRequired)
        #expect(withCare.state(for: .firstCare)?.status == .claimable)
    }

    @Test func claimIsGatedAtomicAndHouseholdIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        context.insert(human)
        try context.save()
        let selection = FixedActiveHumanSelection(currentHumanId: human.id.uuidString)
        qualifyHumanProfile(human: human, context: context, selection: selection)

        let blockedDefaults = try makeDefaults()
        blockedDefaults.set(true, forKey: "ohana_has_onboarded")
        blockedDefaults.set(true, forKey: StarterGiftStorageKey.pending)
        let blocked = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            activeHumanSelection: selection,
            defaults: blockedDefaults
        )
        #expect(blocked == .notEligible(task: .humanProfile))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)

        let enabledDefaults = try makeDefaults()
        enabledDefaults.set(true, forKey: "ohana_has_onboarded")
        let observingWallet = ObservingWallet()
        let claimed = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            wallet: observingWallet,
            activeHumanSelection: selection,
            defaults: enabledDefaults
        )
        let retry = HouseholdStarterJourneyService.claim(
            task: .humanProfile,
            context: context,
            wallet: observingWallet,
            activeHumanSelection: selection,
            defaults: enabledDefaults
        )

        #expect(claimed == .claimed(task: .humanProfile, humanID: human.id, amount: 100))
        #expect(retry == .alreadyClaimed(task: .humanProfile, amount: 100))
        #expect(observingWallet.calls.count == 1)
        #expect(observingWallet.calls.first?.0 == false)
        #expect(observingWallet.calls.first?.1 == false)
        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].transactionKey == HouseholdStarterJourneyService.rewardTransactionKey(for: .humanProfile))
        #expect(!entries[0].transactionKey.contains(human.id.uuidString))
        let rewardEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.actionType == HouseholdStarterJourneyService.rewardActionType
        }
        #expect(rewardEvents.count == 1)
    }

    private func qualifyHumanProfile(
        human: Human,
        context: ModelContext,
        selection: FixedActiveHumanSelection
    ) {
        _ = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanAppearance,
            resolution: .reviewed,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
        _ = HouseholdStarterJourneyService.recordResolution(
            task: .humanProfile,
            checkpoint: .humanOptionalDetails,
            resolution: .preferNotToSay,
            subjectID: human.id,
            context: context,
            activeHumanSelection: selection
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ArkSchemaV91.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "HouseholdStarterJourneyServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private struct FixedActiveHumanSelection: ActiveHumanSelecting {
        let currentHumanId: String?
        var currentHumanIdRaw: String { currentHumanId ?? "" }
    }

    private final class ObservingWallet: CoconutWalletManaging {
        private let wrapped = SwiftDataCoconutWalletManager()
        var calls: [(Bool, Bool)] = []

        func apply(
            deltas: [CoconutWalletDelta],
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            updatesProjection: Bool,
            projectionManager: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            calls.append((postsRewardFeedback, updatesProjection))
            return try wrapped.apply(
                deltas: deltas,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                updatesProjection: updatesProjection,
                projectionManager: projectionManager
            )
        }

        func applyActorDelta(
            amount: Int,
            emoji: String,
            title: String,
            actorId: String?,
            actorName: String?,
            entryKind: CoconutWalletEntryKind,
            source: CoconutWalletSource,
            context: ModelContext,
            save: Bool,
            postsRewardFeedback: Bool,
            projectionManager: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            try wrapped.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
                entryKind: entryKind,
                source: source,
                context: context,
                save: save,
                postsRewardFeedback: postsRewardFeedback,
                projectionManager: projectionManager
            )
        }

        func totalBalance(context: ModelContext) -> Int { wrapped.totalBalance(context: context) }
        func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int {
            wrapped.balance(accountKey: accountKey, context: context, fallback: fallback)
        }
        func balance(for human: Human, context: ModelContext) -> Int { wrapped.balance(for: human, context: context) }
        func balance(for pet: Pet, context: ModelContext) -> Int { wrapped.balance(for: pet, context: context) }
        func legacySystemBalance(context: ModelContext, fallback: Int) -> Int {
            wrapped.legacySystemBalance(context: context, fallback: fallback)
        }
        func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
            wrapped.setDeveloperOverrideBalance(amount: amount, for: human, displayName: displayName, context: context)
        }
        func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?) {
            wrapped.refreshQuestProjection(context: context, manager: manager)
        }
        func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
            try wrapped.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
        }
    }
}
