import Combine
import Foundation

@MainActor
protocol DomainRevisionPublishing {
    var homeRevision: HomeRevision { get }
    var lastMutation: DomainMutationResult? { get }
    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> { get }
    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> { get }

    func publish(_ result: DomainMutationResult)
    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String
    )
    func publishCoconutRewardFeedback(_ event: OhanaCoconutRewardEvent)
    func publishFailure(command: DomainCommand, error: Error)
    func publishSettingsActiveHumanSwitch(_ result: SettingsActiveHumanSwitchCommandResult, note: String)
    func publishSettingsCoconutBalance(_ result: SettingsCoconutBalanceCommandResult, note: String)
    func publishHumanPrivacy(_ result: HumanPrivacyCommandResult, note: String)
    func publishMemberCreation(_ result: PlantCreationCommandResult, note: String)
    func publishMemberDeletion(_ result: MemberDeletionCommandResult, note: String)
    func publishMemberProfile(_ result: MemberProfileCommandResult, note: String)
    func publishMemberProfileChange(entityID: UUID, kind: String, note: String)
    func publishMemberHomeVisibility(_ result: MemberHomeVisibilityCommandResult, note: String)
    func publishMemberLifecycle(_ result: MemberLifecycleCommandResult, note: String)
    func publishPetCareRecord(_ result: PetCareTrackingCommandResult, note: String)
    func publishPetCareDelete(_ result: PetCareTrackingDeleteCommandResult, note: String)
    func publishPetPottyDelete(_ result: PetPottyDeleteCommandResult, note: String)
    func publishCatCareRecord(_ result: CatCareCommandResult, note: String)
    func publishCatCareUndo(_ result: CatCareUndoCommandResult, note: String)
    func publishPetWalkGoal(_ result: PetWalkGoalCommandResult, note: String)
    func publishPetWalkSummary(_ result: PetWalkSummaryCommandResult, note: String)
    func publishPlantCare(_ result: PlantCareCommandResult, note: String)
    func publishCalendarEventPlan(_ result: CalendarEventPlanCommandResult, relatedEntityId: String, note: String)
    func publishCalendarEventCompletion(_ result: CalendarEventCompletionResult, note: String)
    func publishCalendarEventDeletion(
        _ outcome: CalendarEventDeletionOutcome,
        scope: CalendarEventDeletionScope,
        note: String
    )
    func publishQuickMoment(_ result: MomentCommandResult, petID: UUID?, note: String)
    func publishTodayFocusDailyCompletion(note: String)
    func publishHumanWishlistCreate(_ result: HumanWishlistCommandResult, note: String)
    func publishHumanWishlistRedeem(_ result: HumanWishlistCommandResult, note: String)
    func publishHumanWishlistDelete(_ result: HumanWishlistDeleteCommandResult, note: String)
    func publishPetBondVaultUnlock(_ result: PetBondVaultUnlockCommandResult, note: String)
    func publishShopPurchase(_ result: ShopPurchaseCommandResult, note: String)
    func publishAchievementReward(_ result: AchievementRewardCommandResult, note: String)
    func publishBackdateCheckIn(_ result: BackdateCheckInCommandResult, note: String)
    func publishPetCardAppearance(_ result: PetCardAppearanceCommandResult, note: String)
    func publishAvatar2DUpgrade(_ result: Avatar2DUpgradeCommandResult, note: String)
    func publishWeightEntry(command: DomainCommand, subjectID: UUID, result: WeightCommandResult, note: String)
    func publishWeightDelete(_ result: DashboardRecordDeleteCommandResult, note: String)
    func publishExpenseEntry(command: DomainCommand, subjectID: UUID, result: ExpenseCommandResult, note: String)
    func publishExpenseDelete(_ result: DashboardRecordDeleteCommandResult, note: String)
    func publishHumanWorkout(_ result: WorkoutCommandResult, command: DomainCommand, note: String)
    func publishHumanWorkoutDelete(_ result: WorkoutDeleteCommandResult, command: DomainCommand, note: String)
    func publishQuickHumanMedication(_ result: HumanMedicationCommandResult, note: String)
    func publishHumanMedicationPlan(
        _ result: HumanMedicationPlanCommandResult,
        commandMedicationID: UUID?,
        note: String
    )
    func publishHumanMedicationPlanActivation(_ result: HumanMedicationPlanActivationCommandResult, note: String)
    func publishHumanMedicationPlanDelete(_ result: HumanMedicationPlanDeleteCommandResult, note: String)
    func publishHumanMedicationDose(
        _ result: HumanMedicationDoseCommandResult,
        scheduledMinute: Int,
        note: String
    )
    func publishHumanHealthMetric(_ result: HumanHealthMetricCommandResult, note: String)
    func publishHumanHealthMetricDelete(_ result: HumanHealthMetricDeleteCommandResult, note: String)
    func publishHumanHealthReport(_ result: HumanHealthReportCommandResult, action: String, note: String)
    func publishHumanNote(_ result: HumanNoteCommandResult, note: String)
    func publishHumanNoteDelete(_ result: HumanNoteDeleteResult, note: String)
    func publishPetHealthRecord(_ result: PetHealthCommandResult, type: String, note: String)
    func publishPetSymptom(_ result: PetSymptomCommandResult, note: String)
    func publishPetHeatCycle(_ result: PetHeatCycleCommandResult, note: String)
    func publishPetHealthDelete(_ result: PetHealthDeleteResult, note: String)
    func publishPetMedicationPlan(_ result: PetMedicationPlanCommandResult, note: String)
    func publishPetMedicationPlanDelete(_ result: PetMedicationPlanDeleteCommandResult, note: String)
    func publishPetMedicationPlanActivation(_ result: PetMedicationPlanActivationCommandResult, note: String)
    func publishPetMedicationDose(_ result: PetMedicationDoseCommandResult, note: String)
    func publishPetHygieneRecord(_ result: PetHygieneCheckInCommandResult, note: String)
    func publishPetHygieneDelete(_ result: PetHygieneDeleteCommandResult, note: String)
    func publishPetHygienePlan(_ result: PetHygienePlanCommandResult, note: String)
    func publishPetDocumentCreate(_ result: PetDocumentCommandResult, category: DocumentCategory, note: String)
    func publishPetDocumentUpdate(_ result: PetDocumentCommandResult, note: String)
    func publishPetDocumentDelete(_ result: PetDocumentDeleteCommandResult, note: String)
    func publishPetMilestoneSeed(_ result: PetMilestoneCommandResult, note: String)
    func publishPetMilestoneRecord(_ result: PetMilestoneCommandResult, note: String)
    func publishPetMilestoneDelete(_ result: PetMilestoneDeleteCommandResult, note: String)
    func publishInsurancePolicy(_ result: InsurancePolicyCommandResult, action: String, note: String)
    func publishInsuranceClaim(_ result: InsuranceClaimCommandResult, action: String, note: String)
    func publishPetPhotoCreate(_ result: PetPhotoAlbumCreateResult, note: String)
    func publishPetPhotoUpdate(_ result: PetPhotoAlbumUpdateResult, note: String)
    func publishPetPhotoDelete(_ result: PetPhotoAlbumDeleteResult, note: String)
}

@MainActor
final class SharedDomainRevisionPublisher: DomainRevisionPublishing {
    private let center: ReadModelRevisionCenter

    init() {
        center = ReadModelRevisionCenter()
    }

    init(center: ReadModelRevisionCenter) {
        self.center = center
    }

    var homeRevision: HomeRevision {
        center.homeRevision
    }

    var lastMutation: DomainMutationResult? {
        center.lastMutation
    }

    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> {
        center.homeRevisionUpdates
    }

    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> {
        center.coconutRewardEvents
    }

    func publish(_ result: DomainMutationResult) {
        center.publish(result)
    }

    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String
    ) {
        center.publishDomainMutation(
            command: command,
            affectedEntityIDs: affectedEntityIDs,
            wroteBusinessFact: wroteBusinessFact,
            note: note
        )
    }

    func publishCoconutRewardFeedback(_ event: OhanaCoconutRewardEvent) {
        center.publishCoconutRewardFeedback(event)
    }

    func publishFailure(command: DomainCommand, error: Error) {
        center.publishFailure(command: command, error: error)
    }

    func publishSettingsActiveHumanSwitch(_ result: SettingsActiveHumanSwitchCommandResult, note: String) {
        center.publishSettingsActiveHumanSwitch(result, note: note)
    }

    func publishSettingsCoconutBalance(_ result: SettingsCoconutBalanceCommandResult, note: String) {
        center.publishSettingsCoconutBalance(result, note: note)
    }

    func publishHumanPrivacy(_ result: HumanPrivacyCommandResult, note: String) {
        center.publishHumanPrivacy(result, note: note)
    }

    func publishMemberCreation(_ result: PlantCreationCommandResult, note: String) {
        center.publishMemberCreation(result, note: note)
    }

    func publishMemberDeletion(_ result: MemberDeletionCommandResult, note: String) {
        center.publishMemberDeletion(result, note: note)
    }

    func publishMemberProfile(_ result: MemberProfileCommandResult, note: String) {
        center.publishMemberProfile(result, note: note)
    }

    func publishMemberProfileChange(entityID: UUID, kind: String, note: String) {
        center.publishMemberProfileChange(entityID: entityID, kind: kind, note: note)
    }

    func publishMemberHomeVisibility(_ result: MemberHomeVisibilityCommandResult, note: String) {
        center.publishMemberHomeVisibility(result, note: note)
    }

    func publishMemberLifecycle(_ result: MemberLifecycleCommandResult, note: String) {
        center.publishMemberLifecycle(result, note: note)
    }

    func publishPetCareRecord(_ result: PetCareTrackingCommandResult, note: String) {
        center.publishPetCareRecord(result, note: note)
    }

    func publishPetCareDelete(_ result: PetCareTrackingDeleteCommandResult, note: String) {
        center.publishPetCareDelete(result, note: note)
    }

    func publishPetPottyDelete(_ result: PetPottyDeleteCommandResult, note: String) {
        center.publishPetPottyDelete(result, note: note)
    }

    func publishCatCareRecord(_ result: CatCareCommandResult, note: String) {
        center.publishCatCareRecord(result, note: note)
    }

    func publishCatCareUndo(_ result: CatCareUndoCommandResult, note: String) {
        center.publishCatCareUndo(result, note: note)
    }

    func publishPetWalkGoal(_ result: PetWalkGoalCommandResult, note: String) {
        center.publishPetWalkGoal(result, note: note)
    }

    func publishPetWalkSummary(_ result: PetWalkSummaryCommandResult, note: String) {
        center.publishPetWalkSummary(result, note: note)
    }

    func publishPlantCare(_ result: PlantCareCommandResult, note: String) {
        center.publishPlantCare(result, note: note)
    }

    func publishCalendarEventPlan(_ result: CalendarEventPlanCommandResult, relatedEntityId: String, note: String) {
        center.publishCalendarEventPlan(result, relatedEntityId: relatedEntityId, note: note)
    }

    func publishCalendarEventCompletion(_ result: CalendarEventCompletionResult, note: String) {
        center.publishCalendarEventCompletion(result, note: note)
    }

    func publishCalendarEventDeletion(
        _ outcome: CalendarEventDeletionOutcome,
        scope: CalendarEventDeletionScope,
        note: String
    ) {
        center.publishCalendarEventDeletion(outcome, scope: scope, note: note)
    }

    func publishQuickMoment(_ result: MomentCommandResult, petID: UUID?, note: String) {
        center.publishQuickMoment(result, petID: petID, note: note)
    }

    func publishTodayFocusDailyCompletion(note: String) {
        center.publishDomainMutation(
            command: .todayFocus(entityID: UUID(), action: "dailyCompletionReward"),
            affectedEntityIDs: [],
            wroteBusinessFact: true,
            note: note
        )
    }

    func publishHumanWishlistCreate(_ result: HumanWishlistCommandResult, note: String) {
        center.publishHumanWishlistCreate(result, note: note)
    }

    func publishHumanWishlistRedeem(_ result: HumanWishlistCommandResult, note: String) {
        center.publishHumanWishlistRedeem(result, note: note)
    }

    func publishHumanWishlistDelete(_ result: HumanWishlistDeleteCommandResult, note: String) {
        center.publishHumanWishlistDelete(result, note: note)
    }

    func publishPetBondVaultUnlock(_ result: PetBondVaultUnlockCommandResult, note: String) {
        center.publishPetBondVaultUnlock(result, note: note)
    }

    func publishShopPurchase(_ result: ShopPurchaseCommandResult, note: String) {
        center.publishShopPurchase(result, note: note)
    }

    func publishAchievementReward(_ result: AchievementRewardCommandResult, note: String) {
        center.publishAchievementReward(result, note: note)
    }

    func publishBackdateCheckIn(_ result: BackdateCheckInCommandResult, note: String) {
        center.publishBackdateCheckIn(result, note: note)
    }

    func publishPetCardAppearance(_ result: PetCardAppearanceCommandResult, note: String) {
        center.publishPetCardAppearance(result, note: note)
    }

    func publishAvatar2DUpgrade(_ result: Avatar2DUpgradeCommandResult, note: String) {
        center.publishAvatar2DUpgrade(result, note: note)
    }

    func publishWeightEntry(command: DomainCommand, subjectID: UUID, result: WeightCommandResult, note: String) {
        center.publishWeightEntry(command: command, subjectID: subjectID, result: result, note: note)
    }

    func publishWeightDelete(_ result: DashboardRecordDeleteCommandResult, note: String) {
        center.publishWeightDelete(result, note: note)
    }

    func publishExpenseEntry(command: DomainCommand, subjectID: UUID, result: ExpenseCommandResult, note: String) {
        center.publishExpenseEntry(command: command, subjectID: subjectID, result: result, note: note)
    }

    func publishExpenseDelete(_ result: DashboardRecordDeleteCommandResult, note: String) {
        center.publishExpenseDelete(result, note: note)
    }

    func publishHumanWorkout(_ result: WorkoutCommandResult, command: DomainCommand, note: String) {
        center.publishHumanWorkout(result, command: command, note: note)
    }

    func publishHumanWorkoutDelete(_ result: WorkoutDeleteCommandResult, command: DomainCommand, note: String) {
        center.publishHumanWorkoutDelete(result, command: command, note: note)
    }

    func publishQuickHumanMedication(_ result: HumanMedicationCommandResult, note: String) {
        center.publishQuickHumanMedication(result, note: note)
    }

    func publishHumanMedicationPlan(
        _ result: HumanMedicationPlanCommandResult,
        commandMedicationID: UUID?,
        note: String
    ) {
        center.publishHumanMedicationPlan(result, commandMedicationID: commandMedicationID, note: note)
    }

    func publishHumanMedicationPlanActivation(_ result: HumanMedicationPlanActivationCommandResult, note: String) {
        center.publishHumanMedicationPlanActivation(result, note: note)
    }

    func publishHumanMedicationPlanDelete(_ result: HumanMedicationPlanDeleteCommandResult, note: String) {
        center.publishHumanMedicationPlanDelete(result, note: note)
    }

    func publishHumanMedicationDose(
        _ result: HumanMedicationDoseCommandResult,
        scheduledMinute: Int,
        note: String
    ) {
        center.publishHumanMedicationDose(result, scheduledMinute: scheduledMinute, note: note)
    }

    func publishHumanHealthMetric(_ result: HumanHealthMetricCommandResult, note: String) {
        center.publishHumanHealthMetric(result, note: note)
    }

    func publishHumanHealthMetricDelete(_ result: HumanHealthMetricDeleteCommandResult, note: String) {
        center.publishHumanHealthMetricDelete(result, note: note)
    }

    func publishHumanHealthReport(_ result: HumanHealthReportCommandResult, action: String, note: String) {
        center.publishHumanHealthReport(result, action: action, note: note)
    }

    func publishHumanNote(_ result: HumanNoteCommandResult, note: String) {
        center.publishHumanNote(result, note: note)
    }

    func publishHumanNoteDelete(_ result: HumanNoteDeleteResult, note: String) {
        center.publishHumanNoteDelete(result, note: note)
    }

    func publishPetHealthRecord(_ result: PetHealthCommandResult, type: String, note: String) {
        center.publishPetHealthRecord(result, type: type, note: note)
    }

    func publishPetSymptom(_ result: PetSymptomCommandResult, note: String) {
        center.publishPetSymptom(result, note: note)
    }

    func publishPetHeatCycle(_ result: PetHeatCycleCommandResult, note: String) {
        center.publishPetHeatCycle(result, note: note)
    }

    func publishPetHealthDelete(_ result: PetHealthDeleteResult, note: String) {
        center.publishPetHealthDelete(result, note: note)
    }

    func publishPetMedicationPlan(_ result: PetMedicationPlanCommandResult, note: String) {
        center.publishPetMedicationPlan(result, note: note)
    }

    func publishPetMedicationPlanDelete(_ result: PetMedicationPlanDeleteCommandResult, note: String) {
        center.publishPetMedicationPlanDelete(result, note: note)
    }

    func publishPetMedicationPlanActivation(_ result: PetMedicationPlanActivationCommandResult, note: String) {
        center.publishPetMedicationPlanActivation(result, note: note)
    }

    func publishPetMedicationDose(_ result: PetMedicationDoseCommandResult, note: String) {
        center.publishPetMedicationDose(result, note: note)
    }

    func publishPetHygieneRecord(_ result: PetHygieneCheckInCommandResult, note: String) {
        center.publishPetHygieneRecord(result, note: note)
    }

    func publishPetHygieneDelete(_ result: PetHygieneDeleteCommandResult, note: String) {
        center.publishPetHygieneDelete(result, note: note)
    }

    func publishPetHygienePlan(_ result: PetHygienePlanCommandResult, note: String) {
        center.publishPetHygienePlan(result, note: note)
    }

    func publishPetDocumentCreate(_ result: PetDocumentCommandResult, category: DocumentCategory, note: String) {
        center.publishPetDocumentCreate(result, category: category, note: note)
    }

    func publishPetDocumentUpdate(_ result: PetDocumentCommandResult, note: String) {
        center.publishPetDocumentUpdate(result, note: note)
    }

    func publishPetDocumentDelete(_ result: PetDocumentDeleteCommandResult, note: String) {
        center.publishPetDocumentDelete(result, note: note)
    }

    func publishPetMilestoneSeed(_ result: PetMilestoneCommandResult, note: String) {
        center.publishPetMilestoneSeed(result, note: note)
    }

    func publishPetMilestoneRecord(_ result: PetMilestoneCommandResult, note: String) {
        center.publishPetMilestoneRecord(result, note: note)
    }

    func publishPetMilestoneDelete(_ result: PetMilestoneDeleteCommandResult, note: String) {
        center.publishPetMilestoneDelete(result, note: note)
    }

    func publishInsurancePolicy(_ result: InsurancePolicyCommandResult, action: String, note: String) {
        center.publishInsurancePolicy(result, action: action, note: note)
    }

    func publishInsuranceClaim(_ result: InsuranceClaimCommandResult, action: String, note: String) {
        center.publishInsuranceClaim(result, action: action, note: note)
    }

    func publishPetPhotoCreate(_ result: PetPhotoAlbumCreateResult, note: String) {
        center.publishPetPhotoCreate(result, note: note)
    }

    func publishPetPhotoUpdate(_ result: PetPhotoAlbumUpdateResult, note: String) {
        center.publishPetPhotoUpdate(result, note: note)
    }

    func publishPetPhotoDelete(_ result: PetPhotoAlbumDeleteResult, note: String) {
        center.publishPetPhotoDelete(result, note: note)
    }
}
