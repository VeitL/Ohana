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
    case readyWithoutHuman
    case ready
}

enum HumanRequirementCoordinator {
    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "HumanRequirementCoordinator failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

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
            return .readyWithoutHuman
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
    static func firstLivingHumanID(context: ModelContext) -> UUID? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.passedAwayDate == nil
            },
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch first living human"
        ).first?.id
    }

    @MainActor
    private static func firstHuman(context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch first human").first
    }

    @MainActor
    private static func humanExists(id: UUID, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch active human").first != nil
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

    func firstLivingHumanID(context: ModelContext) -> UUID?
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

    func firstLivingHumanID(context: ModelContext) -> UUID? {
        HumanRequirementCoordinator.firstLivingHumanID(context: context)
    }
}
