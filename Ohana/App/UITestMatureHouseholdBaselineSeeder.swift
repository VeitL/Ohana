//
//  UITestMatureHouseholdBaselineSeeder.swift
//  Ohana
//
//  DEBUG-only completed-first-day fixture for disposable UI tests.
//

import Foundation
import SwiftData

#if DEBUG
struct UITestMatureHouseholdBaselineRequest: Equatable {
    enum Species: String, Equatable {
        case cat
        case dog
    }

    let petName: String
    let species: Species
}

@MainActor
enum UITestMatureHouseholdBaselineSeeder {
    enum SeedResult: Equatable {
        case notRequested
        case seeded(humanID: UUID, petID: UUID)
        case rejected
    }

    @discardableResult
    static func seedIfRequested(
        modelContainer: ModelContainer,
        services: AppServices,
        human: Human
    ) -> SeedResult {
        guard OhanaUITestLaunchOptions.requestsMatureHouseholdBaseline else {
            return .notRequested
        }
        guard OhanaUITestLaunchOptions.isRunningUITests,
              OhanaUITestLaunchOptions.resetsPersistentState,
              OhanaUITestLaunchOptions.requestedHumanBaselineName != nil,
              !OhanaUITestLaunchOptions.requestsMemberCardBaseline,
              !OhanaUITestLaunchOptions.requestsSparsePetProfileBaseline,
              let request = OhanaUITestLaunchOptions.requestedMatureHouseholdBaseline else {
            reject("Mature household UI-test baseline requires UI tests, reset, Human baseline, and valid Pet arguments.")
            return .rejected
        }

        let context = modelContainer.mainContext
        do {
            let existingPets = try context.fetch(FetchDescriptor<Pet>())
            guard existingPets.isEmpty else {
                reject("Mature household UI-test baseline requires an empty Pet store.")
                return .rejected
            }

            let humans = try context.fetch(FetchDescriptor<Human>())
            guard humans.count == 1,
                  humans.first?.id == human.id else {
                reject("Mature household UI-test baseline requires exactly its one seeded Human.")
                return .rejected
            }

            guard let profile = petProfile(for: request.species) else {
                reject("Mature household UI-test baseline could not resolve a valid Pet profile.")
                return .rejected
            }

            var draft = MemberCreationDraft(kind: .pet)
            draft.name = request.petName
            draft.species = request.species.rawValue
            draft.breed = profile.breed
            draft.petGender = "boy"
            draft.coatColor = profile.coatColor

            // Match the persisted branch taken when the person chooses to add
            // a Pet instead of deferring the optional step.
            services.onboardingJourney.markPetCreationStarted()
            let saveResult = try services.memberCreation.save(
                draft: draft,
                existingPets: [],
                existingHumans: humans,
                context: context,
                countryCode: "US"
            )
            guard let pet = saveResult.pet else {
                reject("Mature household UI-test baseline did not create its Pet through MemberCreationService.")
                return .rejected
            }

            let giftResult = StarterGiftService.claimStarterGift(
                activeHumanID: human.id.uuidString,
                context: context,
                careLedger: services.careLedger,
                wallet: services.coconutWallet,
                projectionManager: services.questManager
            )
            guard case let .claimed(recipient, amount) = giftResult,
                  recipient == .island,
                  amount == StarterGiftPolicy.giftAmount else {
                reject("Mature household UI-test baseline did not persist the real starter gift exactly once.")
                return .rejected
            }

            services.onboardingJourney.markStarterCeremonySeen()
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: StarterGiftStorageKey.claimed),
                  !defaults.bool(forKey: StarterGiftStorageKey.pending),
                  defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen) else {
                reject("Mature household UI-test baseline did not reach a completed starter-gift state.")
                return .rejected
            }

            // This fixture represents a settled existing user, not the one-time
            // post-ceremony prompt. Later starter-journey checkpoints and rewards
            // remain untouched so their UI journeys still test real transitions.
            defaults.set(false, forKey: StarterGiftStorageKey.oasisTabPromptPending)
            defaults.set(true, forKey: "ohana_has_onboarded")
            return .seeded(humanID: human.id, petID: pet.id)
        } catch {
            context.rollback()
            reject("Mature household UI-test baseline failed: \(error.localizedDescription)")
            return .rejected
        }
    }

    private static func petProfile(
        for species: UITestMatureHouseholdBaselineRequest.Species
    ) -> (breed: String, coatColor: String)? {
        guard let breed = PetBreedDatabase.breeds(for: species.rawValue)
            .first(where: { $0.name != "其他" }) else {
            return nil
        }
        return (breed.name, breed.coatColors.first?.name ?? "")
    }

    private static func reject(_ message: String) {
        OhanaLog.warning(message, category: "Startup")
    }
}
#endif
