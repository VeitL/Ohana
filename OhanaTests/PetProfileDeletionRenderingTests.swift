import SwiftData
import SwiftUI
import Testing
@testable import Ohana

@MainActor
struct PetProfileDeletionRenderingTests {
    @Test func retainedProfileStopsReadingPetAfterCommittedDeletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Retained profile")
        context.insert(pet)
        try context.save()
        let profile = PetBasicInfoDetailView(pet: pet)
        #expect(renderedSize(of: profile, in: container).height > 0)

        context.delete(pet)
        try context.save()

        #expect(pet.modelContext == nil)
        #expect(try context.fetchCount(FetchDescriptor<Pet>()) == 0)
        // SwiftUI can re-evaluate a dismissed view while its transition is retained.
        // Rendering that view must not fault the deleted model's stored properties.
        #expect(renderedSize(of: profile, in: container) == .zero)
    }

    @Test func retainedProfileRendersAgainAfterDeletionRollback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Keep profile")
        context.insert(pet)
        try context.save()
        let profile = PetBasicInfoDetailView(pet: pet)

        context.delete(pet)
        #expect(renderedSize(of: profile, in: container) == .zero)
        context.rollback()

        #expect(try context.fetchCount(FetchDescriptor<Pet>()) == 1)
        #expect(pet.name == "Keep profile")
        #expect(renderedSize(of: profile, in: container).height > 0)
    }

    @Test func unsavedProfileDraftRemainsReadable() throws {
        let container = try makeContainer()
        let pet = Pet(name: "Profile draft")

        #expect(pet.modelContext == nil)
        #expect(renderedSize(of: PetBasicInfoDetailView(pet: pet), in: container).height > 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(ArkSchemaV99.models),
            configurations: [configuration]
        )
    }

    private func renderedSize(of profile: PetBasicInfoDetailView, in container: ModelContainer) -> CGSize {
        let host = UIHostingController(rootView: profile
            .environment(AppServices(modelContainer: container))
            .modelContainer(container))
        return host.sizeThatFits(in: CGSize(width: 393, height: 852))
    }
}
