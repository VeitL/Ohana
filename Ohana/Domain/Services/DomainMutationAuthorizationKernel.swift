//
//  DomainMutationAuthorizationKernel.swift
//  Ohana
//
//  Feature-neutral subject resolution and capability issuance for domain writes.
//

import Foundation
import SwiftData

nonisolated enum DomainMutationScope: Equatable {
    case schedule
    case careFact
    case ledger
    case economy
    case task
    case memberProfile
    case memberContent
    case deletion
    case rehydrate
    case effect
    case infrastructure
}

nonisolated enum DomainMutationSourceKind: Equatable {
    case userCommand
    case domainService
    case restore
    case cloudApply
    case system
}

nonisolated enum DomainUnresolvedAssigneePolicy: Equatable {
    case deny
    case drop
}

nonisolated struct DomainSubjectResolutionRequest: Equatable {
    let link: DomainEntityLink
    let assigneeId: String?

    init(
        relatedEntityType: String = "",
        relatedEntityId: String = "",
        assigneeId: String? = nil
    ) {
        self.link = DomainEntityLink(rawType: relatedEntityType, rawId: relatedEntityId)
        self.assigneeId = assigneeId
    }

    init(link: DomainEntityLink, assigneeId: String? = nil) {
        self.link = link
        self.assigneeId = assigneeId
    }

    init(event: Event) {
        self.init(link: DomainEntityLink(event: event), assigneeId: event.assigneeId)
    }

    func droppingAssignee() -> DomainSubjectResolutionRequest {
        DomainSubjectResolutionRequest(link: link, assigneeId: nil)
    }
}

nonisolated struct DomainSubjectResolution: Equatable {
    let link: DomainEntityLink
    let role: DomainEntityLinkRole
    let owner: DomainMemberReference?
    let assignee: DomainMemberReference?
    let displayTarget: DomainMemberReference?
    let effectTargets: [DomainMemberReference]
    let unresolvedOwner: Bool
    let unresolvedAssignee: Bool
    let unregisteredType: String?

    var hasUnregisteredLinkType: Bool {
        unregisteredType != nil
    }

    var lifecycleTargets: [DomainMemberReference] {
        DomainSubjectResolution.uniqueTargets([owner, assignee] + effectTargets.map(Optional.some))
    }

    var affectedEntityIDs: Set<UUID> {
        var ids = Set(lifecycleTargets.map(\.id))
        if let linkId = DomainEntityLinkRegistry.affectedEntityId(for: link, role: role) {
            ids.insert(linkId)
        }
        return ids
    }

    private static func uniqueTargets(_ candidates: [DomainMemberReference?]) -> [DomainMemberReference] {
        var targets: [DomainMemberReference] = []
        for candidate in candidates {
            guard let candidate, !targets.contains(candidate) else { continue }
            targets.append(candidate)
        }
        return targets
    }
}

nonisolated struct DomainResolvedSubjectKey: Equatable, Hashable, CustomStringConvertible {
    let rawValue: String

    init(resolution: DomainSubjectResolution) {
        if let displayTarget = resolution.displayTarget {
            rawValue = "\(displayTarget.rawKind):\(displayTarget.id.uuidString)"
        } else if resolution.role == .unscoped {
            rawValue = "unscoped"
        } else {
            rawValue = "\(resolution.link.normalizedType):\(Self.fallbackId(for: resolution.link))"
        }
    }

    var description: String { rawValue }

    private static func fallbackId(for link: DomainEntityLink) -> String {
        link.trimmedId.split(separator: ":", maxSplits: 1).first.map(String.init) ?? link.trimmedId
    }
}

nonisolated struct DomainSubjectResolutionCatalog {
    let pets: [Pet]
    let petMedications: [PetMedication]
    let humanMedications: [HumanMedication]
    let insurances: [PetInsurance]
    let humans: [Human]

    init(
        pets: [Pet] = [],
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        insurances: [PetInsurance] = [],
        humans: [Human] = []
    ) {
        self.pets = pets
        self.petMedications = petMedications
        self.humanMedications = humanMedications
        self.insurances = insurances
        self.humans = humans
    }
}

nonisolated struct DomainMutationAuthorizationRequest: Equatable {
    let scope: DomainMutationScope
    let source: DomainMutationSourceKind
    let subjectRequest: DomainSubjectResolutionRequest
    let writeKind: MemberWriteKind
    let unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy
    let assigneeWriteKind: MemberWriteKind

    init(
        scope: DomainMutationScope,
        source: DomainMutationSourceKind,
        subjectRequest: DomainSubjectResolutionRequest,
        writeKind: MemberWriteKind,
        unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy = .deny,
        assigneeWriteKind: MemberWriteKind = .care
    ) {
        self.scope = scope
        self.source = source
        self.subjectRequest = subjectRequest
        self.writeKind = writeKind
        self.unresolvedAssigneePolicy = unresolvedAssigneePolicy
        self.assigneeWriteKind = assigneeWriteKind
    }
}

nonisolated struct DomainMutationToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedMutationPlan {
    fileprivate let token: DomainMutationToken
    let scope: DomainMutationScope
    let source: DomainMutationSourceKind
    let subjectRequest: DomainSubjectResolutionRequest
    let subject: DomainSubjectResolution
    let writeKind: MemberWriteKind
    let disposition: MemberWriteDisposition

    fileprivate init(
        scope: DomainMutationScope,
        source: DomainMutationSourceKind,
        subjectRequest: DomainSubjectResolutionRequest,
        subject: DomainSubjectResolution,
        writeKind: MemberWriteKind,
        disposition: MemberWriteDisposition
    ) {
        self.token = DomainMutationToken()
        self.scope = scope
        self.source = source
        self.subjectRequest = subjectRequest
        self.subject = subject
        self.writeKind = writeKind
        self.disposition = disposition
    }

    func consumeAuthorization() {
        _ = token
    }

    var writesContent: Bool {
        disposition.writesContent
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }

    var allowsCareFactWrite: Bool {
        disposition.allowsCareFactWrite
    }

    var allowsEconomyDerivation: Bool {
        disposition.allowsEconomyDerivation
    }

    var allowsRevisionPublish: Bool {
        disposition.allowsRevisionPublish
    }
}

nonisolated enum DomainSubjectResolver {
    static func resolve(
        request: DomainSubjectResolutionRequest,
        context: ModelContext
    ) -> DomainSubjectResolution {
        let link = request.link
        let role = DomainEntityLinkRegistry.role(for: link)
        let owner = ownerReference(for: link, role: role, context: context)
        let assignee = assigneeReference(assigneeId: request.assigneeId, context: context)
        let displayTarget = owner ?? assignee
        let effectTargets = uniqueTargets([owner, assignee])
        return DomainSubjectResolution(
            link: link,
            role: role,
            owner: owner,
            assignee: assignee,
            displayTarget: displayTarget,
            effectTargets: effectTargets,
            unresolvedOwner: role.isMemberScoped && owner == nil,
            unresolvedAssignee: hasExplicitAssignee(request.assigneeId) && assignee == nil,
            unregisteredType: role.unregisteredType
        )
    }

    static func resolve(
        request: DomainSubjectResolutionRequest,
        catalog: DomainSubjectResolutionCatalog
    ) -> DomainSubjectResolution {
        let link = request.link
        let role = DomainEntityLinkRegistry.role(for: link)
        let owner = ownerReference(for: link, role: role, catalog: catalog)
        let assignee = assigneeReference(assigneeId: request.assigneeId, humans: catalog.humans)
        let displayTarget = owner ?? assignee
        let effectTargets = uniqueTargets([owner, assignee])
        return DomainSubjectResolution(
            link: link,
            role: role,
            owner: owner,
            assignee: assignee,
            displayTarget: displayTarget,
            effectTargets: effectTargets,
            unresolvedOwner: role.isMemberScoped && owner == nil,
            unresolvedAssignee: hasExplicitAssignee(request.assigneeId) && assignee == nil,
            unregisteredType: role.unregisteredType
        )
    }

    private static func ownerReference(
        for link: DomainEntityLink,
        role: DomainEntityLinkRole,
        context: ModelContext
    ) -> DomainMemberReference? {
        switch role {
        case .directPet, .petAutoFeeder, .petWaterPlan:
            return petReference(id: UUID(uuidString: link.trimmedId), context: context)
        case .petFoodStock:
            return petReference(id: DomainEntityLinkRegistry.petIdFromCompoundStockId(link.trimmedId), context: context)
        case .petInsurance:
            guard let insuranceId = UUID(uuidString: link.trimmedId),
                  let insurance = fetchPetInsurance(id: insuranceId, context: context),
                  let petId = insurance.pet?.id else {
                return nil
            }
            return petReference(id: petId, context: context)
        case .petMedicationPlan, .petMedicationDose:
            guard let medicationId = UUID(uuidString: link.trimmedId),
                  let medication = fetchPetMedication(id: medicationId, context: context),
                  let petId = medication.pet?.id else {
                return nil
            }
            return petReference(id: petId, context: context)
        case .directHuman, .humanNote:
            return humanReference(id: UUID(uuidString: link.trimmedId), context: context)
        case .humanMedicationPlan:
            guard let medicationId = UUID(uuidString: link.trimmedId),
                  let medication = fetchHumanMedication(id: medicationId, context: context),
                  let humanId = UUID(uuidString: medication.humanId) else {
                return nil
            }
            return humanReference(id: humanId, context: context)
        case .directPlant, .plantScoped, .unscoped, .unknown:
            return nil
        }
    }

    private static func ownerReference(
        for link: DomainEntityLink,
        role: DomainEntityLinkRole,
        catalog: DomainSubjectResolutionCatalog
    ) -> DomainMemberReference? {
        switch role {
        case .directPet, .petAutoFeeder, .petWaterPlan:
            return petReference(id: UUID(uuidString: link.trimmedId), pets: catalog.pets)
        case .petFoodStock:
            return petReference(id: DomainEntityLinkRegistry.petIdFromCompoundStockId(link.trimmedId), pets: catalog.pets)
        case .petInsurance:
            guard let insurance = catalog.insurances.first(where: { $0.id.uuidString == link.trimmedId }),
                  let petId = insurance.pet?.id else {
                return nil
            }
            return petReference(id: petId, pets: catalog.pets)
        case .petMedicationPlan, .petMedicationDose:
            guard let medication = catalog.petMedications.first(where: { $0.id.uuidString == link.trimmedId }),
                  let petId = medication.pet?.id else {
                return nil
            }
            return petReference(id: petId, pets: catalog.pets)
        case .directHuman, .humanNote:
            return humanReference(id: UUID(uuidString: link.trimmedId), humans: catalog.humans)
        case .humanMedicationPlan:
            guard let medication = catalog.humanMedications.first(where: { $0.id.uuidString == link.trimmedId }),
                  let humanId = UUID(uuidString: medication.humanId) else {
                return nil
            }
            return humanReference(id: humanId, humans: catalog.humans)
        case .directPlant, .plantScoped, .unscoped, .unknown:
            return nil
        }
    }

    private static func petReference(id: UUID?, context: ModelContext) -> DomainMemberReference? {
        guard let id, fetchPet(id: id, context: context) != nil else { return nil }
        return .pet(id)
    }

    private static func petReference(id: UUID?, pets: [Pet]) -> DomainMemberReference? {
        guard let id else { return nil }
        guard pets.isEmpty || pets.contains(where: { $0.id == id }) else { return nil }
        return .pet(id)
    }

    private static func humanReference(id: UUID?, context: ModelContext) -> DomainMemberReference? {
        guard let id, fetchHuman(id: id, context: context) != nil else { return nil }
        return .human(id)
    }

    private static func humanReference(id: UUID?, humans: [Human]) -> DomainMemberReference? {
        guard let id else { return nil }
        guard humans.isEmpty || humans.contains(where: { $0.id == id }) else { return nil }
        return .human(id)
    }

    private static func assigneeReference(assigneeId: String?, context: ModelContext) -> DomainMemberReference? {
        guard let assigneeId,
              !assigneeId.isEmpty,
              let id = UUID(uuidString: assigneeId) else {
            return nil
        }
        guard fetchHuman(id: id, context: context) != nil else { return nil }
        return .human(id)
    }

    private static func assigneeReference(assigneeId: String?, humans: [Human]) -> DomainMemberReference? {
        guard let assigneeId,
              !assigneeId.isEmpty,
              let id = UUID(uuidString: assigneeId) else {
            return nil
        }
        guard humans.isEmpty || humans.contains(where: { $0.id == id }) else { return nil }
        return .human(id)
    }

    private static func hasExplicitAssignee(_ assigneeId: String?) -> Bool {
        guard let assigneeId else { return false }
        return !assigneeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func uniqueTargets(_ candidates: [DomainMemberReference?]) -> [DomainMemberReference] {
        var targets: [DomainMemberReference] = []
        for candidate in candidates {
            guard let candidate, !targets.contains(candidate) else { continue }
            targets.append(candidate)
        }
        return targets
    }

    private static func fetchPetMedication(id: UUID, context: ModelContext) -> PetMedication? {
        var descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchHumanMedication(id: UUID, context: ModelContext) -> HumanMedication? {
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchPetInsurance(id: UUID, context: ModelContext) -> PetInsurance? {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchPet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

nonisolated enum DomainPolicyAuthorizer {
    static func authorize(
        _ request: DomainMutationAuthorizationRequest,
        context: ModelContext
    ) -> AuthorizedMutationPlan? {
        let authorizationInput = normalizedAuthorizationInput(request, context: context)
        guard let disposition = authorizedDisposition(
            subject: authorizationInput.subject,
            writeKind: authorizationInput.request.writeKind,
            assigneeWriteKind: authorizationInput.request.assigneeWriteKind,
            context: context
        ) else { return nil }

        return AuthorizedMutationPlan(
            scope: authorizationInput.request.scope,
            source: authorizationInput.request.source,
            subjectRequest: authorizationInput.request.subjectRequest,
            subject: authorizationInput.subject,
            writeKind: authorizationInput.request.writeKind,
            disposition: disposition
        )
    }

    private static func normalizedAuthorizationInput(
        _ request: DomainMutationAuthorizationRequest,
        context: ModelContext
    ) -> (request: DomainMutationAuthorizationRequest, subject: DomainSubjectResolution) {
        let subject = DomainSubjectResolver.resolve(request: request.subjectRequest, context: context)
        guard subject.unresolvedAssignee,
              request.unresolvedAssigneePolicy == .drop,
              subject.owner != nil else {
            return (request, subject)
        }

        let normalizedRequest = DomainMutationAuthorizationRequest(
            scope: request.scope,
            source: request.source,
            subjectRequest: request.subjectRequest.droppingAssignee(),
            writeKind: request.writeKind,
            unresolvedAssigneePolicy: request.unresolvedAssigneePolicy,
            assigneeWriteKind: request.assigneeWriteKind
        )
        return (
            normalizedRequest,
            DomainSubjectResolver.resolve(request: normalizedRequest.subjectRequest, context: context)
        )
    }

    private static func authorizedDisposition(
        subject: DomainSubjectResolution,
        writeKind: MemberWriteKind,
        assigneeWriteKind: MemberWriteKind,
        context: ModelContext
    ) -> MemberWriteDisposition? {
        guard !subject.hasUnregisteredLinkType else { return nil }
        guard !subject.unresolvedOwner else { return nil }
        guard !subject.unresolvedAssignee else { return nil }

        var disposition = MemberLifecycleGate.activeDisposition(writeKind: writeKind)
        if let ownerDisposition = memberDisposition(for: subject.owner, writeKind: writeKind, context: context) {
            disposition = ownerDisposition
        }
        guard disposition.writesContent else { return nil }

        if let assigneeDisposition = memberDisposition(for: subject.assignee, writeKind: assigneeWriteKind, context: context),
           !assigneeDisposition.allowsDerivedEffects {
            return nil
        }
        return disposition
    }

    private static func memberDisposition(
        for reference: DomainMemberReference?,
        writeKind: MemberWriteKind,
        context: ModelContext
    ) -> MemberWriteDisposition? {
        guard let reference else { return nil }
        switch reference {
        case let .pet(id):
            guard let pet = fetchPet(id: id, context: context) else { return .missingMemberTarget }
            return MemberLifecycleGate.disposition(pet: pet, writeKind: writeKind)
        case let .human(id):
            guard let human = fetchHuman(id: id, context: context) else { return .missingMemberTarget }
            return MemberLifecycleGate.disposition(human: human, writeKind: writeKind)
        }
    }

    private static func fetchPet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
