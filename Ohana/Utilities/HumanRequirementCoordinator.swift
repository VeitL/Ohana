//
//  HumanRequirementCoordinator.swift
//  Ohana
//
//  Narrow SwiftData gate for required human account state.
//

import Foundation
import SwiftData

enum HumanRequirementResolution: Equatable {
    case notOnboarded
    case needsRequiredProfile
    case preserveAccountSwitch
    case activateHuman(String)
    case ready
}

enum HumanRequirementCoordinator {
    @MainActor
    static func resolve(
        hasOnboarded: Bool,
        currentActiveHumanId: String,
        isAccountSwitchPresented: Bool,
        context: ModelContext
    ) -> HumanRequirementResolution {
        guard hasOnboarded else {
            return .notOnboarded
        }

        guard let firstHuman = firstHuman(context: context) else {
            return .needsRequiredProfile
        }

        if isAccountSwitchPresented {
            return .preserveAccountSwitch
        }

        guard let activeID = UUID(uuidString: currentActiveHumanId),
              humanExists(id: activeID, context: context) else {
            return .activateHuman(firstHuman.id.uuidString)
        }

        return .ready
    }

    @MainActor
    private static func firstHuman(context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func humanExists(id: UUID, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.first) != nil
    }
}

@MainActor
protocol HumanRequirementResolving {
    func resolve(
        hasOnboarded: Bool,
        currentActiveHumanId: String,
        isAccountSwitchPresented: Bool,
        context: ModelContext
    ) -> HumanRequirementResolution
}

struct LiveHumanRequirementResolver: HumanRequirementResolving {
    func resolve(
        hasOnboarded: Bool,
        currentActiveHumanId: String,
        isAccountSwitchPresented: Bool,
        context: ModelContext
    ) -> HumanRequirementResolution {
        HumanRequirementCoordinator.resolve(
            hasOnboarded: hasOnboarded,
            currentActiveHumanId: currentActiveHumanId,
            isAccountSwitchPresented: isAccountSwitchPresented,
            context: context
        )
    }
}
