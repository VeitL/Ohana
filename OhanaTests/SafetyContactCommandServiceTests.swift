import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct SafetyContactCommandServiceTests {
    @Test func newPhoneContactsAreDisabledForEveryPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for plan in OhanaPlanLevel.allCases {
            #expect(throws: SafetyContactCommandError.contactLimitReached(limit: 0)) {
                try SafetyContactCommandService.create(
                    name: "Legacy contact",
                    phoneNumber: "+49 111",
                    capabilities: .make(for: plan),
                    context: context
                )
            }
        }
        #expect(try SafetyContactCommandService.snapshots(context: context).isEmpty)
    }

    @Test func legacyContactsRemainEditableAndDeletableButCannotGrow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let legacyContact = SafetyContact(
            name: "Legacy",
            phoneNumber: "111",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        context.insert(legacyContact)
        try context.save()

        let edited = try SafetyContactCommandService.update(
            id: legacyContact.id,
            name: "Legacy updated",
            phoneNumber: "999",
            isEnabled: false,
            context: context
        )
        #expect(edited.name == "Legacy updated")
        #expect(!edited.isEnabled)
        #expect(try SafetyContactCommandService.snapshots(context: context).count == 1)
        #expect(throws: SafetyContactCommandError.contactLimitReached(limit: 0)) {
            try SafetyContactCommandService.create(
                name: "Blocked",
                phoneNumber: "444",
                capabilities: .make(for: .free),
                context: context
            )
        }
        try SafetyContactCommandService.delete(id: legacyContact.id, context: context)
        #expect(try SafetyContactCommandService.snapshots(context: context).isEmpty)
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
