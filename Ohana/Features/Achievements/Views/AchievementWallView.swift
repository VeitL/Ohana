//
//  AchievementWallView.swift
//  Ohana
//
//  成就徽章墙 — V4 游戏化进度与领取
//

import SwiftData
import SwiftUI
import UIKit

struct AchievementWallContentView: View {
    let pet: Pet
    var allPets: [Pet] = []
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    let electronicPets: [OasisElectronicPet]
    let critterFragments: [OasisCritterFragmentBalance]
    let critterActionLogs: [OasisCritterActionLog]
    let gachaOwnedItems: [GachaOwnedItem]
    let gachaDrawLogs: [GachaDrawLog]
    let allHumans: [Human]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let allExpenseLogs: [PetExpenseLog]
    let careLedgerEvents: [CareLedgerEvent]
    let petActivitySummaries: [UUID: AchievementPetActivitySummary]
    var achievementSnapshot: AchievementWallSnapshot = .empty

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @AppStorage("achievement_claimedRewardIDs") var claimedRewardRaw: String = ""
    @Environment(\.ohanaAppLanguageCode) var appLanguageRaw

    @State var selectedSubject: AchievementSubject?
    @State var selectedFilter: AchievementFilter = .all
    @State var selectedAchievement: Achievement?
    @State var pendingClaimAchievement: Achievement?
    @State var showRewardAnimation = false
    @State var rewardAnimationAmount = 0
    @State var rewardAnimationLabel: String?
    @State var achievementShareImage: UIImage?
    @State var showingAchievementShareSheet = false
    @State var isRenderingAchievementShareImage = false
    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @ObservedObject var avatarPipeline = AvatarPipelineRegistry.current
    @State var humanAvatarSignatures: [UUID: String] = [:]
    @State var humanAvatarCacheKey = "achievement-wall-human-avatar-empty"
    @State var humanActivityIndex = AchievementHumanActivityIndex.empty

    enum AchievementSubject: Hashable, Identifiable {
        case pet(UUID)
        case human(UUID)

        var id: String {
            switch self {
            case let .pet(id): "pet:\(id.uuidString)"
            case let .human(id): "human:\(id.uuidString)"
            }
        }
    }

    enum AchievementFilter: String, CaseIterable {
        case all
        case claimable
        case unlocked
        case inProgress

        func title(_ l: L10n) -> String {
            switch self {
            case .all: l.tr(zh: "全部", en: "All", de: "Alle")
            case .claimable: l.tr(zh: "可领取", en: "Claim", de: "Abholen")
            case .unlocked: l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
            case .inProgress: l.tr(zh: "进行中", en: "Progress", de: "In Arbeit")
            }
        }
    }

    enum AchievementRewardState {
        case claimable
        case claimed
        case unlocked
        case locked
    }

    struct AchievementHumanActivityIndex {
        var medicationsByHumanId: [String: [HumanMedication]]
        var medicationLogsByHumanId: [String: [HumanMedicationLog]]
        var expensesByHumanId: [String: [PetExpenseLog]]

        static let empty = AchievementHumanActivityIndex(
            medicationsByHumanId: [:],
            medicationLogsByHumanId: [:],
            expensesByHumanId: [:]
        )

        static func make(
            medications: [HumanMedication],
            medicationLogs: [HumanMedicationLog],
            expenses: [PetExpenseLog]
        ) -> AchievementHumanActivityIndex {
            let groupedExpenses = Dictionary(
                grouping: expenses.compactMap { expense in
                    expense.executorId.map { ($0, expense) }
                },
                by: \.0
            )
            return AchievementHumanActivityIndex(
                medicationsByHumanId: Dictionary(grouping: medications, by: \.humanId),
                medicationLogsByHumanId: Dictionary(grouping: medicationLogs, by: \.humanId),
                expensesByHumanId: groupedExpenses.mapValues { pairs in pairs.map(\.1) }
            )
        }

        func medications(for human: Human) -> [HumanMedication] {
            medicationsByHumanId[human.id.uuidString] ?? []
        }

        func medicationLogs(for human: Human) -> [HumanMedicationLog] {
            medicationLogsByHumanId[human.id.uuidString] ?? []
        }

        func expenses(for human: Human) -> [PetExpenseLog] {
            expensesByHumanId[human.id.uuidString] ?? []
        }
    }

    let rewardPerAchievement = 10
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    let achievementArtworkAspectRatio: CGFloat = 520.0 / 444.0
    let achievementPopupMaxImageWidth: CGFloat = 520
    static let achievementBackgroundNames: [String: String] = [
        "iron_gut": "AchievementBgIronGut",
        "iron_paw": "AchievementBgIronPaw",
        "walk_streak": "AchievementBgWalkStreak",
        "health_hero": "AchievementBgHealthHero",
        "nutritionist": "AchievementBgNutritionist",
        "happy_birthday": "AchievementBgHappyBirthday",
        "hundred_days": "AchievementBgHundredDays",
        "first_record": "AchievementBgFirstRecord",
        "day_one_checkin": "AchievementBgDayOneCheckin",
        "old_friend": "AchievementBgOldFriend",
        "long_runner": "AchievementBgLongRunner",
        "medication_complete": "AchievementBgMedicationComplete",
        "photo_enthusiast": "AchievementBgPhotoEnthusiast",
        "expense_tracker": "AchievementBgExpenseTracker",
        "weight_manager": "AchievementBgWeightManager",
        "hydration_buddy": "AchievementBgHydrationBuddy",
        "play_champion": "AchievementBgPlayChampion",
        "clean_keeper": "AchievementBgCleanKeeper",
        "treat_scout": "AchievementBgTreatScout",
        "food_kind_explorer": "AchievementBgFoodKindExplorer",
        "auto_feeder_pilot": "AchievementBgAutoFeederPilot",
        "stock_keeper": "AchievementBgStockKeeper",
        "protection_ready": "AchievementBgProtectionReady",
        "vaccine_keeper": "AchievementBgVaccineKeeper",
        "symptom_watcher": "AchievementBgSymptomWatcher",
        "care_streak_keeper": "AchievementBgCareStreakKeeper",
        "meal_archivist": "AchievementBgMealArchivist",
        "water_guardian": "AchievementBgWaterGuardian",
        "memory_collector": "AchievementBgMemoryCollector",
        "weight_rhythm": "AchievementBgWeightRhythm",
        "year_companion": "AchievementBgYearCompanion",
        "global_island_crew": "AchievementBgGlobalIslandCrew",
        "global_first_critter": "AchievementBgGlobalFirstCritter",
        "global_legendary_critter": "AchievementBgGlobalLegendaryCritter",
        "global_critter_collector": "AchievementBgGlobalCritterCollector",
        "global_critter_star": "AchievementBgGlobalCritterStar",
        "global_critter_caretaker": "AchievementBgGlobalCritterCaretaker",
        "global_first_blind_box": "AchievementBgGlobalFirstBlindBox",
        "global_blind_box_collector": "AchievementBgGlobalBlindBoxCollector",
        "global_secret_blind_box": "AchievementBgGlobalSecretBlindBox",
        "global_gacha_series_complete": "AchievementBgGlobalGachaSeriesComplete",
        "global_gacha_jackpot": "AchievementBgGlobalGachaJackpot",
        "human_profile_ready": "AchievementBgHumanProfileReady",
        "human_first_record": "AchievementBgHumanFirstRecord",
        "human_weight_starter": "AchievementBgHumanWeightStarter",
        "human_weight_keeper": "AchievementBgHumanWeightKeeper",
        "human_expense_tracker": "AchievementBgHumanExpenseTracker",
        "human_medication_setup": "AchievementBgHumanMedicationSetup",
        "human_medication_keeper": "AchievementBgHumanMedicationKeeper",
        "human_workout_starter": "AchievementBgHumanWorkoutStarter",
        "human_workout_rhythm": "AchievementBgHumanWorkoutRhythm",
        "human_workout_hero": "AchievementBgHumanWorkoutHero",
        "human_coconut_saver": "AchievementBgHumanCoconutSaver",
        "human_coconut_elite": "AchievementBgHumanCoconutElite",
        "human_old_friend": "AchievementBgHumanOldFriend",
        "human_year_friend": "AchievementBgHumanYearFriend"
    ]
    var l: L10n { L10n(appLanguageRaw) }

    var pets: [Pet] {
        var seen = Set<UUID>()
        return ([pet] + allPets).filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return !item.hasPassedAway
        }
    }

    var humans: [Human] {
        allHumans.filter { !$0.hasPassedAway }
    }

    var subjects: [AchievementSubject] {
        pets.map { .pet($0.id) } + humans.map { .human($0.id) }
    }

    var humanAvatarSourceKey: String {
        let key = humans
            .map { "\($0.id.uuidString):\($0.avatarThumbnailSignature)" }
            .joined(separator: "|")
        return key.isEmpty ? "achievement-wall-human-avatar-empty" : key
    }

    var humanActivitySourceKey: String {
        [
            "med:\(humanMedications.count):\(Int(humanMedications.first?.createdAt.timeIntervalSince1970 ?? 0))",
            "log:\(humanMedicationLogs.count):\(Int(humanMedicationLogs.first?.createdAt.timeIntervalSince1970 ?? 0))",
            "expense:\(allExpenseLogs.count):\(Int(allExpenseLogs.first?.date.timeIntervalSince1970 ?? 0))",
            "ledger:\(careLedgerEvents.count):\(Int(careLedgerEvents.first?.occurredAt.timeIntervalSince1970 ?? 0))",
            "activity:\(petActivitySummaries.count):\(petActivitySummaries.keys.map(\.uuidString).sorted().joined(separator: ","))"
        ].joined(separator: "|")
    }

    var activeSubject: AchievementSubject {
        selectedSubject ?? .pet(pet.id)
    }

    var activePet: Pet {
        if case let .pet(id) = activeSubject {
            return pets.first(where: { $0.id == id }) ?? pet
        }
        return pet
    }

    var activeHuman: Human? {
        guard case let .human(id) = activeSubject else { return nil }
        return humans.first(where: { $0.id == id })
    }

    var activeMemberName: String {
        activeHuman?.name ?? activePet.name
    }

    var activeCoconutBalance: Int {
        activeHuman?.coconutBalance ?? activePet.coconutBalance
    }

    var activeCoconutLogSubject: CoconutLogSubject {
        if let human = activeHuman {
            return .human(human.id)
        }
        return .pet(activePet.id)
    }

    var activeCareLedgerSummary: AchievementCareLedgerSummary {
        AchievementCareLedgerSummary(events: careLedgerEvents, petID: activePet.id)
    }

    var activePetActivitySummary: AchievementPetActivitySummary {
        petActivitySummaries[activePet.id] ?? .empty
    }

    var achievementContext: AchievementComputationContext {
        AchievementComputationContext(
            allPets: pets,
            allHumans: humans,
            electronicPets: electronicPets,
            critterFragments: critterFragments,
            critterActionLogs: critterActionLogs,
            gachaOwnedItems: gachaOwnedItems,
            gachaDrawLogs: gachaDrawLogs,
            careLedgerEvents: careLedgerEvents,
            petActivitySummaries: petActivitySummaries
        )
    }

    var screenModel: AchievementWallScreenModel {
        AchievementWallScreenModel(
            context: achievementContext,
            gachaOwnedItems: gachaOwnedItems
        )
    }

    var achievements: [Achievement] {
        let computed: [Achievement]
        if let human = activeHuman {
            computed = humanAchievements(for: human)
        } else {
            computed = screenModel.petAchievements(for: activePet)
        }
        return computed.map { badge in
            let scope = screenModel.isGlobalAchievement(badge)
                ? AchievementScopeReference.island
                : activeAchievementScope
            guard let unlockedAt = achievementSnapshot.items.first(where: {
                $0.definitionID == badge.id && $0.scope == scope
            })?.unlockedAt else { return badge }
            var durable = badge
            durable.isUnlocked = true
            durable.unlockedAt = unlockedAt
            return durable
        }
    }

    private var activeAchievementScope: AchievementScopeReference {
        if let human = activeHuman { return .human(human.id) }
        return .pet(activePet.id)
    }

    var unlocked: [Achievement] {
        achievements.filter(\.isUnlocked)
    }

    var claimable: [Achievement] {
        unlocked.filter { !isRewardClaimed($0) }
    }

    var nextAchievement: Achievement? {
        achievements
            .filter { !$0.isUnlocked }
            .sorted { progress(for: $0).fraction > progress(for: $1).fraction }
            .first
    }

    var displayedAchievements: [Achievement] {
        achievements
            .filter { badge in
                switch selectedFilter {
                case .all: true
                case .claimable: badge.isUnlocked && !isRewardClaimed(badge)
                case .unlocked: badge.isUnlocked
                case .inProgress: !badge.isUnlocked
                }
            }
            .sorted { lhs, rhs in
                let leftState = sortRank(for: lhs)
                let rightState = sortRank(for: rhs)
                if leftState != rightState { return leftState < rightState }
                return progress(for: lhs).fraction > progress(for: rhs).fraction
            }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if subjects.count > 1 { memberSelector }
                    progressHero
                    filterChips
                    achievementGrid
                    Color.clear.frame(height: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .blur(radius: selectedAchievement == nil && pendingClaimAchievement == nil ? 0 : 1.2)
            .allowsHitTesting(selectedAchievement == nil && pendingClaimAchievement == nil)

            if let selectedAchievement {
                achievementPopup(selectedAchievement)
                    .zIndex(4)
            }

            if let pendingClaimAchievement {
                claimConfirmPopup(pendingClaimAchievement)
                    .zIndex(5)
            }
        }
        .tint(Color.goPrimary)
        .onAppear {
            if selectedSubject == nil { selectedSubject = .pet(pet.id) }
        }
        .task(id: humanAvatarSourceKey) {
            await prepareHumanAvatars()
        }
        .task(id: humanActivitySourceKey) {
            await prepareHumanActivityIndex()
        }
        .onDisappear {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
        }
        .coconutRewardOverlay(
            trigger: $showRewardAnimation,
            amount: rewardAnimationAmount,
            label: rewardAnimationLabel
        )
        .sheet(isPresented: $showingAchievementShareSheet) {
            if let achievementShareImage {
                ShareSheet(image: achievementShareImage)
            }
        }
        .animation(GoMotion.sheet, value: selectedAchievement?.id)
        .animation(GoMotion.sheet, value: pendingClaimAchievement?.id)
    }
}
