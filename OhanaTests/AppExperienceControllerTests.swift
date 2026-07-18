import Foundation
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AppExperienceControllerTests {
    @Test func freshInstallRequiresAChoiceBeforeOnboarding() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = AppExperienceController(
            defaults: defaults,
            hasCompletedOnboarding: false
        )

        #expect(controller.mode == .standard)
        #expect(controller.requiresInitialSelection)

        controller.selectInitialMode(.zen)

        #expect(controller.mode == .zen)
        #expect(!controller.requiresInitialSelection)
        #expect(defaults.string(forKey: AppExperienceMode.storageKey) == AppExperienceMode.zen.rawValue)
    }

    @Test func existingUserWithoutAStoredModeKeepsStandardWithoutBlocking() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = AppExperienceController(
            defaults: defaults,
            hasCompletedOnboarding: true
        )

        #expect(controller.mode == .standard)
        #expect(!controller.requiresInitialSelection)
        #expect(controller.shouldOfferZenIntroduction)
        #expect(defaults.string(forKey: AppExperienceMode.storageKey) == AppExperienceMode.standard.rawValue)

        let relaunchedBeforeDismissal = AppExperienceController(
            defaults: defaults,
            hasCompletedOnboarding: true
        )
        #expect(relaunchedBeforeDismissal.shouldOfferZenIntroduction)

        controller.dismissZenIntroduction()

        #expect(!controller.shouldOfferZenIntroduction)
        #expect(defaults.bool(forKey: AppExperienceMode.zenIntroductionSeenKey))
    }

    @Test func oneLivingHumanBindsAutomaticallyAndMultipleRequireAChoice() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)
        let first = choice(name: "First", createdAt: 100)
        let second = choice(name: "Second", createdAt: 200)

        controller.reconcileZenOwner(with: [first])

        #expect(controller.zenOwnerBindingState == .ready(first.id))
        #expect(controller.zenOwnerHumanID == first.id.uuidString)

        defaults.removeObject(forKey: AppExperienceMode.zenOwnerHumanIDKey)
        let unbound = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)
        unbound.reconcileZenOwner(with: [second, first])

        #expect(unbound.zenOwnerBindingState == .requiresSelection([first, second]))
    }

    @Test func missingOrMemorializedOwnerStopsZenUntilRebound() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        defaults.set(UUID().uuidString, forKey: AppExperienceMode.zenOwnerHumanIDKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)

        controller.reconcileZenOwner(with: [])

        #expect(controller.zenOwnerBindingState == .unavailable)
        #expect(controller.zenOwnerHumanID.isEmpty)
        #expect(defaults.object(forKey: AppExperienceMode.zenOwnerHumanIDKey) == nil)
    }

    @Test func invalidOwnerNeverSilentlyMovesToTheOnlyRemainingHuman() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        defaults.set(UUID().uuidString, forKey: AppExperienceMode.zenOwnerHumanIDKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)
        let remaining = choice(name: "Remaining", createdAt: 100)

        controller.reconcileZenOwner(with: [remaining])
        controller.reconcileZenOwner(with: [remaining])

        #expect(controller.zenOwnerBindingState == .requiresSelection([remaining]))
        #expect(controller.zenOwnerHumanID.isEmpty)
    }

    @Test func appResetRestoresTheInitialChoiceGate() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)

        controller.prepareForFreshOnboardingAfterReset()

        #expect(controller.mode == .standard)
        #expect(controller.requiresInitialSelection)
        #expect(defaults.object(forKey: AppExperienceMode.storageKey) == nil)
    }

    @Test func settingsSwitchRebuildsOnlyTheShellAndPreservesTheOwnerBinding() async throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let ownerID = UUID()
        defaults.set(AppExperienceMode.standard.rawValue, forKey: AppExperienceMode.storageKey)
        defaults.set(ownerID.uuidString, forKey: AppExperienceMode.zenOwnerHumanIDKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)
        let originalShellIdentity = controller.shellIdentity

        controller.switchAfterRouteDismissal(to: .zen, delayMilliseconds: 0)
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(controller.mode == .zen)
        #expect(controller.shellIdentity != originalShellIdentity)
        #expect(controller.zenOwnerHumanID == ownerID.uuidString)
        #expect(defaults.string(forKey: AppExperienceMode.storageKey) == AppExperienceMode.zen.rawValue)
    }

    @Test func anExplicitOwnerChangeUpdatesTheLocalBindingWithoutChangingMode() throws {
        let (suite, defaults) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        let controller = AppExperienceController(defaults: defaults, hasCompletedOnboarding: true)
        let ownerID = UUID()

        controller.bindZenOwner(ownerID)

        #expect(controller.mode == .zen)
        #expect(controller.zenOwnerBindingState == .ready(ownerID))
        #expect(defaults.string(forKey: AppExperienceMode.zenOwnerHumanIDKey) == ownerID.uuidString)
    }

    private func choice(name: String, createdAt: TimeInterval) -> AppExperienceHumanChoice {
        AppExperienceHumanChoice(
            id: UUID(),
            name: name,
            avatarEmoji: "👤",
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    private func makeDefaults() throws -> (String, UserDefaults) {
        let suite = "AppExperienceControllerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return (suite, defaults)
    }
}
