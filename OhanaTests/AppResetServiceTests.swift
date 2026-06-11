import SwiftData
import XCTest
@testable import Ohana

@MainActor
final class AppResetServiceTests: XCTestCase {
    func testResetClearsDataAndReturnsToOnboardingState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaultsSuiteName = "AppResetServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }

        let pet = Pet(name: "Miso")
        let human = Human(name: "Guan")
        let careLog = PetCareLog(type: .feeding, amountGrams: 42, pet: pet, executorId: human.id.uuidString)
        context.insert(pet)
        context.insert(human)
        context.insert(careLog)
        try context.save()

        defaults.set(true, forKey: "ohana_has_onboarded")
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.set("en", forKey: "appLanguage")
        defaults.set("DE", forKey: AppCountry.storageKey)
        defaults.set("{}", forKey: "quickActionItems_v2")
        defaults.set(12, forKey: "quest_coconutCount")
        defaults.set(AppBackgroundStyle.customPhoto.rawValue, forKey: "appBackgroundStyle")

        try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: AppResetService.Options(
                cancelPendingNotifications: false,
                deleteCustomBackground: false,
                resetSharedRuntimeState: false
            )
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        XCTAssertFalse(defaults.bool(forKey: "ohana_has_onboarded"))
        XCTAssertEqual(defaults.string(forKey: "currentActiveHumanId"), "")
        XCTAssertNil(defaults.object(forKey: "quickActionItems_v2"))
        XCTAssertNil(defaults.object(forKey: "quest_coconutCount"))
        XCTAssertNil(defaults.object(forKey: "appBackgroundStyle"))
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "en")
        XCTAssertEqual(defaults.string(forKey: AppCountry.storageKey), "DE")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
