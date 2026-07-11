//
//  UITestPlantBaselineSeeder.swift
//  Ohana
//
//  DEBUG-only launch seeding for UI tests.
//

import Foundation
import SwiftData

#if DEBUG
enum OhanaUITestLaunchOptions {
    static var isRunningUITests: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || arguments.contains("-OHANA_UI_TESTS")
    }

    static var resetsPersistentState: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return isRunningUITests && arguments.contains("-OHANA_RESET_PERSISTENT_STATE")
    }

    static var disablesAnimations: Bool {
        shouldDisableAnimations(arguments: ProcessInfo.processInfo.arguments)
    }

    static var forcesReduceMotion: Bool {
        shouldForceReduceMotion(
            arguments: ProcessInfo.processInfo.arguments,
            isRunningUITests: isRunningUITests
        )
    }

    static func shouldDisableAnimations(arguments: [String]) -> Bool {
        // Unit-test hosts also expose XCTest environment keys. Requiring the
        // explicit app launch marker keeps unit tests on production budgets.
        arguments.contains("-OHANA_UI_TESTS")
            && !arguments.contains("-OHANA_UI_TEST_ENABLE_ANIMATIONS")
    }

    static func shouldForceReduceMotion(
        arguments: [String],
        isRunningUITests: Bool
    ) -> Bool {
        isRunningUITests && arguments.contains("-OHANA_UI_TEST_REDUCE_MOTION")
    }

    static var requestsSingleStoreOpenFailure: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TEST_FAIL_STORE_OPEN_ONCE")
    }

    static var requestedPlantBaselineSeedCount: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isRunningUITests,
              arguments.contains("-OHANA_UI_TEST_SEED_PLANT_BASELINE")
                || arguments.contains("-OHANA_UI_TEST_PLANT_BASELINE_COUNT") else {
            return nil
        }
        return plantBaselineSeedCount(defaultCount: 1)
    }

    static var requestedCoconutBalanceSeedAmount: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isRunningUITests,
              arguments.contains("-OHANA_UI_TEST_SEED_COCONUT_BALANCE")
                || arguments.contains("-OHANA_UI_TEST_COCONUT_BALANCE_AMOUNT") else {
            return nil
        }
        return coconutBalanceSeedAmount(defaultAmount: 1000)
    }

    static var requestedHumanBaselineName: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isRunningUITests,
              arguments.contains("-OHANA_UI_TEST_SEED_HUMAN_BASELINE") else {
            return nil
        }
        guard let flagIndex = arguments.firstIndex(of: "-OHANA_UI_TEST_HUMAN_BASELINE_NAME"),
              arguments.indices.contains(arguments.index(after: flagIndex)) else {
            return "Codex Human Baseline"
        }
        let name = arguments[arguments.index(after: flagIndex)]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((name.isEmpty ? "Codex Human Baseline" : name).prefix(80))
    }

    static var requestsRewardTierUnlock: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TEST_UNLOCK_REWARD_TIER")
    }

    static var requestsEconomyBudgetReset: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TEST_RESET_ECONOMY_BUDGET")
    }

    static func plantBaselineSeedCount(defaultCount: Int) -> Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-OHANA_UI_TEST_PLANT_BASELINE_COUNT"),
              arguments.indices.contains(arguments.index(after: flagIndex)),
              let count = Int(arguments[arguments.index(after: flagIndex)]) else {
            return defaultCount
        }
        return min(max(count, 1), 12)
    }

    static func coconutBalanceSeedAmount(defaultAmount: Int) -> Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-OHANA_UI_TEST_COCONUT_BALANCE_AMOUNT"),
              arguments.indices.contains(arguments.index(after: flagIndex)),
              let amount = Int(arguments[arguments.index(after: flagIndex)]) else {
            return defaultAmount
        }
        return min(max(amount, 0), 100_000)
    }
}

@MainActor
enum UITestHumanBaselineSeeder {
    static func seedIfRequested(modelContainer: ModelContainer, services: AppServices) {
        guard let name = OhanaUITestLaunchOptions.requestedHumanBaselineName else { return }
        let context = modelContainer.mainContext
        do {
            var descriptor = FetchDescriptor<Human>(
                predicate: #Predicate<Human> { human in
                    human.name == name
                }
            )
            descriptor.fetchLimit = 1
            let human: Human
            if let existing = try context.fetch(descriptor).first {
                human = existing
            } else {
                human = Human(name: name)
                context.insert(human)
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    return
                }
                services.domainRevisions.publishMemberCreation(
                    entityID: human.id,
                    kind: EntityKind.human.rawValue,
                    note: "startup.human.uiTestBaseline"
                )
            }
            UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
            // Module UI tests start with a Human baseline but still exercise the
            // real Pet-first onboarding. Preserve the fresh-journey checkpoint
            // that production establishes before its first member is written.
            UserDefaults.standard.set(true, forKey: StarterGiftStorageKey.pending)
        } catch {
            context.rollback()
            OhanaLog.warning(
                "UI test Human baseline seed failed: \(error.localizedDescription)",
                category: "Startup"
            )
        }
    }
}

@MainActor
enum UITestPlantBaselineSeeder {
    static func seedIfRequested(modelContainer: ModelContainer, services: AppServices) {
        guard let desiredCount = OhanaUITestLaunchOptions.requestedPlantBaselineSeedCount else { return }
        seed(
            modelContext: modelContainer.mainContext,
            services: services,
            desiredCount: desiredCount,
            revisionNote: "startup.plant.uiTestBaseline"
        )
    }

    static func seed(
        modelContext: ModelContext,
        services: AppServices,
        desiredCount: Int,
        revisionNote: String
    ) {
        let desiredCount = min(max(desiredCount, 1), 12)
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<Plant>(
                    predicate: #Predicate<Plant> { plant in
                        plant.notes == "Seeded by UI tests"
                    },
                    sortBy: [SortDescriptor(\.createdAt)]
                )
            )
            guard existing.count < desiredCount else {
                PlantUnlockPolicy.noteExistingPlantData()
                return
            }

            var createdPlantIDs: [UUID] = []
            for index in existing.count ..< desiredCount {
                let plant = makeSeedPlant(index: index)
                modelContext.insert(plant)
                createdPlantIDs.append(plant.id)
            }

            let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                modelContext.rollback()
                return
            }

            PlantUnlockPolicy.noteExistingPlantData()
            for plantID in createdPlantIDs {
                services.domainRevisions.publishMemberCreation(
                    entityID: plantID,
                    kind: EntityKind.plant.rawValue,
                    note: revisionNote
                )
            }
        } catch {
            modelContext.rollback()
            OhanaLog.warning(
                "UI test plant baseline seed failed: \(error.localizedDescription)",
                category: "Startup"
            )
        }
    }

    private static func makeSeedPlant(index: Int) -> Plant {
        let ordinal = index + 1
        let isLivingRoom = index.isMultiple(of: 2)
        let plant = Plant(
            name: "Codex Pothos Seed-\(ordinal)",
            species: "Epipremnum aureum",
            location: isLivingRoom ? "South window" : "Balcony shelf",
            avatarEmoji: "🪴",
            wateringIntervalDays: 7,
            fertilizingIntervalDays: 30,
            roomNameRaw: isLivingRoom ? "Living room" : "Balcony",
            potDiameterCm: 12,
            potMaterialRaw: "Ceramic",
            soilTypeRaw: "Well-draining potting mix",
            isIndoor: true,
            windowDirection: .south,
            lightLevel: .brightIndirect,
            currentHeightCm: 18,
            currentSpreadCm: 22,
            catalogSpeciesId: "epipremnum-aureum",
            remindersEnabled: true
        )
        plant.notes = "Seeded by UI tests"
        return plant
    }
}
#endif
