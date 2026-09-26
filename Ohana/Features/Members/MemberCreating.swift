import SwiftData

@MainActor
protocol MemberCreating {
    var avatarPassCost: Int { get }

    func currentHuman(in humans: [Human]) -> Human?
    func creationAccessDenial(
        kind: MemberCreationKind,
        context: ModelContext
    ) throws -> PersonalFreeLimitDenial?
    func purchaseAvatarPassForCurrentDraft(humans: [Human], context: ModelContext, l: L10n) throws
    func save(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
    ) throws -> MemberCreationSaveResult
}
