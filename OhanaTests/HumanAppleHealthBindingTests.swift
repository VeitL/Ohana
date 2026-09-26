import Foundation
import Testing
@testable import Ohana

struct HumanAppleHealthBindingTests {
    @Test func bindingStateAllowsLiveReadsOnlyForTheExactLivingHuman() {
        let first = UUID()
        let second = UUID()

        #expect(HumanAppleHealthBindingPolicy.state(
            boundHumanID: nil,
            viewedHumanID: first,
            viewedHumanHasPassedAway: false
        ) == .unbound)
        #expect(HumanAppleHealthBindingPolicy.state(
            boundHumanID: first,
            viewedHumanID: first,
            viewedHumanHasPassedAway: false
        ).allowsLiveHealthRead)
        #expect(HumanAppleHealthBindingPolicy.state(
            boundHumanID: first,
            viewedHumanID: second,
            viewedHumanHasPassedAway: false
        ) == .boundToOtherHuman(first))
        #expect(!HumanAppleHealthBindingPolicy.state(
            boundHumanID: first,
            viewedHumanID: first,
            viewedHumanHasPassedAway: true
        ).allowsLiveHealthRead)
    }

    @Test func deviceLocalBindingSupportsRebindUnbindAndTargetedInvalidation() throws {
        let fixture = try makeDefaults()
        let defaults = fixture.defaults
        defer { defaults.removePersistentDomain(forName: fixture.suiteName) }
        let first = UUID()
        let second = UUID()

        #expect(HumanAppleHealthBindingStore.bind(to: first, defaults: defaults))
        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == first)
        #expect(!HumanAppleHealthBindingStore.invalidateIfBound(to: second, defaults: defaults))
        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == first)

        #expect(HumanAppleHealthBindingStore.bind(to: second, defaults: defaults))
        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == second)
        #expect(HumanAppleHealthBindingStore.invalidateIfBound(to: second, defaults: defaults))
        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == nil)
        #expect(!HumanAppleHealthBindingStore.unbind(defaults: defaults))
    }

    @Test func memorialHumanCannotBecomeTheAppleHealthBinding() throws {
        let fixture = try makeDefaults()
        let defaults = fixture.defaults
        defer { defaults.removePersistentDomain(forName: fixture.suiteName) }

        #expect(!HumanAppleHealthBindingStore.bind(
            to: UUID(),
            humanHasPassedAway: true,
            defaults: defaults
        ))
        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == nil)
    }

    @Test func invalidStoredBindingIsSelfHealed() throws {
        let fixture = try makeDefaults()
        let defaults = fixture.defaults
        defer { defaults.removePersistentDomain(forName: fixture.suiteName) }
        defaults.set("not-a-uuid", forKey: HumanAppleHealthBindingStore.storageKey)

        #expect(HumanAppleHealthBindingStore.boundHumanID(defaults: defaults) == nil)
        #expect(defaults.object(forKey: HumanAppleHealthBindingStore.storageKey) == nil)
    }

    @Test func workoutSurfaceAndLifecycleUseTheExplicitBindingBoundary() throws {
        let rootURL = repositoryRootURL()
        let bindingSource = try source("Ohana/Features/Workouts/HumanAppleHealthBinding.swift", rootURL: rootURL)
        let summarySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift", rootURL: rootURL)
        let deletionSource = try source("Ohana/Features/Members/MemberDeletionCommands.swift", rootURL: rootURL)
        let lifecycleSource = try source("Ohana/Features/Members/MemberInteractionCommands.swift", rootURL: rootURL)
        let backupSource = try source("Ohana/Domain/Services/DataBackupManager.swift", rootURL: rootURL)
        let backupDTOSource = try source("Ohana/Domain/Services/DataBackupDTOs.swift", rootURL: rootURL)

        #expect(!bindingSource.contains("currentActiveHumanId"))
        #expect(summarySource.contains("if canReadLiveAppleHealth"))
        #expect(summarySource.contains("guard canReadLiveAppleHealth else"))
        #expect(summarySource.contains(".task(id: workoutHistoryTaskID)"))
        #expect(deletionSource.contains("HumanAppleHealthBindingStore.invalidateIfBound(to: humanID"))
        #expect(lifecycleSource.contains("HumanAppleHealthBindingStore.invalidateIfBound(to: human.id"))
        #expect(!backupSource.contains(HumanAppleHealthBindingStore.storageKey))
        #expect(!backupDTOSource.contains(HumanAppleHealthBindingStore.storageKey))
    }

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "HumanAppleHealthBindingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
