import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct SafetyContactCommandServiceTests {
    @Test func freeAllowsOneContactAndPersonalAllowsThree() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let first = try SafetyContactCommandService.create(
            name: "Alex",
            phoneNumber: "+49 111",
            capabilities: .make(for: .free),
            context: context
        )
        #expect(first.sortOrder == 0)
        #expect(throws: SafetyContactCommandError.contactLimitReached(limit: 1)) {
            try SafetyContactCommandService.create(
                name: "Sam",
                phoneNumber: "+49 222",
                capabilities: .make(for: .free),
                context: context
            )
        }

        _ = try SafetyContactCommandService.create(
            name: "Sam",
            phoneNumber: "+49 222",
            capabilities: .make(for: .personal),
            context: context
        )
        _ = try SafetyContactCommandService.create(
            name: "Jo",
            phoneNumber: "+49 333",
            capabilities: .make(for: .personal),
            context: context
        )
        #expect(try SafetyContactCommandService.snapshots(context: context).count == 3)
        #expect(throws: SafetyContactCommandError.contactLimitReached(limit: 3)) {
            try SafetyContactCommandService.create(
                name: "Fourth",
                phoneNumber: "+49 444",
                capabilities: .make(for: .personal),
                context: context
            )
        }
    }

    @Test func downgradeKeepsAndAllowsEditingExistingContactsButBlocksGrowth() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let personal = OhanaPlanCapabilities.make(for: .personal)
        let first = try SafetyContactCommandService.create(
            name: "First",
            phoneNumber: "111",
            capabilities: personal,
            context: context
        )
        _ = try SafetyContactCommandService.create(
            name: "Second",
            phoneNumber: "222",
            capabilities: personal,
            context: context
        )
        _ = try SafetyContactCommandService.create(
            name: "Third",
            phoneNumber: "333",
            capabilities: personal,
            context: context
        )

        let edited = try SafetyContactCommandService.update(
            id: first.id,
            name: "First updated",
            phoneNumber: "999",
            isEnabled: false,
            context: context
        )
        #expect(edited.name == "First updated")
        #expect(!edited.isEnabled)
        #expect(try SafetyContactCommandService.snapshots(context: context).count == 3)
        #expect(throws: SafetyContactCommandError.contactLimitReached(limit: 1)) {
            try SafetyContactCommandService.create(
                name: "Blocked",
                phoneNumber: "444",
                capabilities: .make(for: .free),
                context: context
            )
        }
    }

    @Test func invalidFieldsAndMissingRowsFailWithoutPersisting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        #expect(throws: SafetyContactCommandError.invalidName) {
            try SafetyContactCommandService.create(
                name: "   ",
                phoneNumber: "111",
                capabilities: .make(for: .free),
                context: context
            )
        }
        #expect(throws: SafetyContactCommandError.invalidPhoneNumber) {
            try SafetyContactCommandService.create(
                name: "Alex",
                phoneNumber: "   ",
                capabilities: .make(for: .free),
                context: context
            )
        }
        #expect(throws: SafetyContactCommandError.contactNotFound) {
            try SafetyContactCommandService.delete(id: UUID(), context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<SafetyContact>()) == 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
