import Foundation
import SwiftData

@MainActor
protocol TodayFocusManaging {
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        humans: [Human],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date
    ) -> [IslandQuest]

    func quest(_ quest: IslandQuest, matchesCompletedEntity entityId: UUID) -> Bool
    func completeEvent(_ event: Event, on date: Date, context: ModelContext) -> TodayFocusEventCompletionCommandResult
    func awardDailyCompletionIfNeeded(context: ModelContext, executorId: String?) -> EconomyRewardResult?
    func ensureTodayCheckIn(activeHumanId: String, rewardTitle: String)
    func currentStreak(activeHumanId: String) -> Int
}

@MainActor
final class StaticTodayFocusManager: TodayFocusManaging {
    private let questManager: QuestManager
    private let careLedger: CareLedgerRecording
    private let revisions: DomainRevisionPublishing

    convenience init() {
        let revisions = SharedDomainRevisionPublisher()
        self.init(
            questManager: QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: revisions),
            careLedger: CareLedgerService(),
            revisions: revisions
        )
    }

    init(
        questManager: QuestManager,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.questManager = questManager
        self.careLedger = careLedger
        self.revisions = revisions
    }

    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        humans: [Human],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date
    ) -> [IslandQuest] {
        TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questManager: questManager
        )
    }

    func quest(_ quest: IslandQuest, matchesCompletedEntity entityId: UUID) -> Bool {
        TodayFocusService.quest(quest, matchesCompletedEntity: entityId)
    }

    func completeEvent(_ event: Event, on date: Date, context: ModelContext) -> TodayFocusEventCompletionCommandResult {
        TodayFocusCommandService.completeEvent(event, on: date, context: context)
    }

    func awardDailyCompletionIfNeeded(context: ModelContext, executorId: String?) -> EconomyRewardResult? {
        TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: executorId,
            questManager: questManager,
            careLedger: careLedger,
            revisions: revisions
        )
    }

    func ensureTodayCheckIn(activeHumanId: String, rewardTitle: String) {
        FocusHomeDailyCheckInService.ensureTodayCheckIn(
            activeHumanId: activeHumanId,
            rewardTitle: rewardTitle,
            questManager: questManager,
            revisions: revisions
        )
    }

    func currentStreak(activeHumanId: String) -> Int {
        FocusHomeDailyCheckInService.currentStreak(activeHumanId: activeHumanId)
    }
}
