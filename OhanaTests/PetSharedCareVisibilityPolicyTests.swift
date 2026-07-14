import Testing
@testable import Ohana

struct PetSharedCareVisibilityPolicyTests {
    @Test func hidesSharedActionsWithoutASameSpeciesPair() {
        #expect(!PetSharedCareVisibilityPolicy.shouldShow(forSpecies: []))
        #expect(!PetSharedCareVisibilityPolicy.shouldShow(forSpecies: ["cat"]))
        #expect(!PetSharedCareVisibilityPolicy.shouldShow(forSpecies: ["cat", "dog"]))
    }

    @Test func showsSharedActionsForAnyCanonicalSameSpeciesPair() {
        #expect(PetSharedCareVisibilityPolicy.shouldShow(forSpecies: ["cat", "猫"]))
        #expect(PetSharedCareVisibilityPolicy.shouldShow(forSpecies: ["dog", "犬", "bird"]))
        #expect(PetSharedCareVisibilityPolicy.shouldShow(forSpecies: ["rabbit", "bird", "birds"]))
    }
}
