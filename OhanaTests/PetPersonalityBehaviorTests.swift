import Testing
@testable import Ohana

struct PetPersonalityBehaviorTests {
    @Test func energeticPlayfulPetsPreferPlayAndWalkActions() {
        let pet = Pet(name: "Mochi", species: "狗")
        pet.personalityTagsRaw = "energetic,playful"

        #expect(PetPersonalityBehavior.priorityBonus(for: "play", pet: pet) > 0)
        #expect(PetPersonalityBehavior.priorityBonus(for: "walk", pet: pet) > 0)
        #expect(PetPersonalityBehavior.priorityBonus(for: "play", pet: pet) > PetPersonalityBehavior.priorityBonus(for: "weight", pet: pet))
    }

    @Test func preferredPetUsesPersonalityBeforeOriginalOrder() {
        let quiet = Pet(name: "Quiet", species: "猫")
        quiet.personalityTagsRaw = "quiet"
        let playful = Pet(name: "Playful", species: "猫")
        playful.personalityTagsRaw = "toy,playful"

        let selected = PetPersonalityBehavior.preferredPet(from: [quiet, playful], actionType: "play", isAlreadyDone: { _ in false })
        #expect(selected?.id == playful.id)
    }
}
