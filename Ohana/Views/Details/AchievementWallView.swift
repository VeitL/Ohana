//
//  AchievementWallView.swift
//  Ohana
//
//  成就徽章墙 — V4 游戏化进度与领取
//

import SwiftUI
import SwiftData
import UIKit

struct AchievementWallView: View {
    let pet: Pet
    var allPets: [Pet] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("achievement_claimedRewardIDs") private var claimedRewardRaw: String = ""
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.fallbackCode
    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt, order: .reverse) private var critterFragments: [OasisCritterFragmentBalance]
    @Query(sort: \OasisCritterActionLog.createdAt, order: .reverse) private var critterActionLogs: [OasisCritterActionLog]
    @Query(sort: \GachaOwnedItem.latestObtainedAt, order: .reverse) private var gachaOwnedItems: [GachaOwnedItem]
    @Query(sort: \GachaDrawLog.drawDate, order: .reverse) private var gachaDrawLogs: [GachaDrawLog]
    @Query(sort: \Human.createdAt, order: .reverse) private var allHumans: [Human]
    @Query(sort: \HumanMedication.createdAt, order: .reverse) private var humanMedications: [HumanMedication]
    @Query(sort: \HumanMedicationLog.createdAt, order: .reverse) private var humanMedicationLogs: [HumanMedicationLog]
    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenseLogs: [PetExpenseLog]

    @State private var selectedSubject: AchievementSubject?
    @State private var selectedFilter: AchievementFilter = .all
    @State private var selectedAchievement: Achievement?
    @State private var pendingClaimAchievement: Achievement?
    @State private var showingCoconutLog = false
    @State private var showRewardAnimation = false
    @State private var rewardAnimationAmount = 0
    @State private var rewardAnimationLabel: String?
    @State private var achievementShareImage: UIImage?
    @State private var showingAchievementShareSheet = false
    @State private var isRenderingAchievementShareImage = false

    private enum AchievementSubject: Hashable, Identifiable {
        case pet(UUID)
        case human(UUID)

        var id: String {
            switch self {
            case .pet(let id): return "pet:\(id.uuidString)"
            case .human(let id): return "human:\(id.uuidString)"
            }
        }
    }

    private enum AchievementFilter: String, CaseIterable {
        case all
        case claimable
        case unlocked
        case inProgress

        func title(_ l: L10n) -> String {
            switch self {
            case .all: return l.tr(zh: "全部", en: "All", de: "Alle")
            case .claimable: return l.tr(zh: "可领取", en: "Claim", de: "Abholen")
            case .unlocked: return l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
            case .inProgress: return l.tr(zh: "进行中", en: "Progress", de: "In Arbeit")
            }
        }
    }

    private enum AchievementRewardState {
        case claimable
        case claimed
        case unlocked
        case locked
    }

    private let rewardPerAchievement = 10
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let achievementArtworkAspectRatio: CGFloat = 520.0 / 444.0
    private let achievementPopupMaxImageWidth: CGFloat = 520
    private static let achievementBackgroundNames: [String: String] = [
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
        "human_coconut_saver": "AchievementBgHumanCoconutSaver",
        "human_old_friend": "AchievementBgHumanOldFriend"
    ]
    private var l: L10n { L10n(appLanguageRaw) }

    private var pets: [Pet] {
        var seen = Set<UUID>()
        return ([pet] + allPets).filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return !item.hasPassedAway
        }
    }

    private var humans: [Human] {
        allHumans.filter { !$0.hasPassedAway }
    }

    private var subjects: [AchievementSubject] {
        pets.map { .pet($0.id) } + humans.map { .human($0.id) }
    }

    private var activeSubject: AchievementSubject {
        selectedSubject ?? .pet(pet.id)
    }

    private var activePet: Pet {
        if case .pet(let id) = activeSubject {
            return pets.first(where: { $0.id == id }) ?? pet
        }
        return pet
    }

    private var activeHuman: Human? {
        guard case .human(let id) = activeSubject else { return nil }
        return humans.first(where: { $0.id == id })
    }

    private var activeMemberName: String {
        activeHuman?.name ?? activePet.name
    }

    private var activeCoconutBalance: Int {
        activeHuman?.coconutBalance ?? activePet.coconutBalance
    }

    private var activeCoconutLogSubject: CoconutLogSubject {
        if let human = activeHuman {
            return .human(human.id)
        }
        return .pet(activePet.id)
    }

    private var achievementContext: AchievementComputationContext {
        AchievementComputationContext(
            allPets: pets,
            electronicPets: electronicPets,
            critterFragments: critterFragments,
            critterActionLogs: critterActionLogs,
            gachaOwnedItems: gachaOwnedItems,
            gachaDrawLogs: gachaDrawLogs
        )
    }

    private var achievements: [Achievement] {
        if let human = activeHuman {
            return humanAchievements(for: human)
        }
        return AchievementManager.compute(for: activePet, context: achievementContext)
    }

    private var unlocked: [Achievement] {
        achievements.filter(\.isUnlocked)
    }

    private var claimable: [Achievement] {
        unlocked.filter { !isRewardClaimed($0) }
    }

    private var nextAchievement: Achievement? {
        achievements
            .filter { !$0.isUnlocked }
            .sorted { progress(for: $0).fraction > progress(for: $1).fraction }
            .first
    }

    private var displayedAchievements: [Achievement] {
        achievements
            .filter { badge in
                switch selectedFilter {
                case .all: return true
                case .claimable: return badge.isUnlocked && !isRewardClaimed(badge)
                case .unlocked: return badge.isUnlocked
                case .inProgress: return !badge.isUnlocked
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
        .coconutRewardOverlay(
            trigger: $showRewardAnimation,
            amount: rewardAnimationAmount,
            label: rewardAnimationLabel
        )
        .fullScreenCover(isPresented: $showingCoconutLog) {
            CoconutLogView(subject: activeCoconutLogSubject)
        }
        .sheet(isPresented: $showingAchievementShareSheet) {
            if let achievementShareImage {
                ShareSheet(image: achievementShareImage)
            }
        }
        .animation(GoMotion.sheet, value: selectedAchievement?.id)
        .animation(GoMotion.sheet, value: pendingClaimAchievement?.id)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "成就解锁", en: "Badges", de: "Abzeichen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(activeMemberName)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            CoconutBalanceCapsule(
                balance: activeCoconutBalance,
                showsDeltaAnimation: true,
                deltaAnimationContext: "achievementWall:\(activeSubject.id)"
            ) {
                showingCoconutLog = true
            }
            .accessibilityLabel(l.tr(zh: "椰子历史", en: "Coconut history", de: "Kokosnuss-Verlauf"))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(subjects) { subject in
                    let isSelected = activeSubject == subject
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedSubject = subject
                        }
                    } label: {
                        VStack(spacing: 5) {
                            memberAvatar(for: subject, size: 44, isSelected: isSelected)
                            Text(memberName(for: subject))
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaSecondaryText)
                                .lineLimit(1)
                                .frame(width: 58)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var progressHero: some View {
        let total = max(achievements.count, 1)
        let percent = Double(unlocked.count) / Double(total)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                activeMemberAvatar(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(unlocked.count)/\(achievements.count)")
                        .font(OhanaFont.metric(size: 42))
                        .foregroundStyle(Color.goPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(l.tr(zh: "已解锁", en: "unlocked", de: "freigeschaltet"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(percent * 100))%")
                        .font(OhanaFont.metric(size: 30))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(l.tr(zh: "\(claimable.count) 个可领取", en: "\(claimable.count) rewards", de: "\(claimable.count) Belohnungen"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(claimable.isEmpty ? Color.ohanaSecondaryText : Color.goPrimary)
                }
            }

            progressBar(percent, tint: Color.goPrimary)

            if let next = nextAchievement {
                Button { selectedAchievement = next } label: {
                    nextTargetRow(next)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                completedRow
            }

            if !claimable.isEmpty {
                Button { claimAllRewards() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                        Text(l.tr(
                            zh: "领取全部 +\(claimable.count * rewardPerAchievement)🥥",
                            en: "Claim all +\(claimable.count * rewardPerAchievement)🥥",
                            de: "Alle abholen +\(claimable.count * rewardPerAchievement)🥥"
                        ))
                    }
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .animation(GoMotion.stateChange, value: unlocked.count)
        .animation(GoMotion.stateChange, value: claimable.count)
    }

    private func nextTargetRow(_ badge: Achievement) -> some View {
        let info = progress(for: badge)
        return HStack(spacing: 12) {
            Text(badge.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(badge.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(zh: "下一枚", en: "Next badge", de: "Nächstes Abzeichen"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
                Text(badge.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                progressBar(info.fraction, tint: badge.color)
                Text(info.summary)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var completedRow: some View {
        HStack(spacing: 12) {
            Text("🏆").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "全部成就已解锁", en: "All badges unlocked", de: "Alle Abzeichen freigeschaltet"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "继续记录，新的徽章会从这些故事里长出来", en: "Keep logging; future badges grow from these stories", de: "Weitere Abzeichen wachsen aus euren Geschichten"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementFilter.allCases, id: \.self) { filter in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(selectedFilter == filter ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selectedFilter == filter ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var achievementGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedAchievements) { badge in
                achievementCard(badge)
            }
        }
        .animation(GoMotion.stateChange, value: selectedFilter)
    }

    private func achievementCard(_ badge: Achievement) -> some View {
        let info = progress(for: badge)
        let state = rewardState(for: badge)
        let backgroundName = achievementBackgroundName(for: badge)
        let usesArtwork = backgroundName != nil
        let foreground = usesArtwork ? artworkCardForeground(for: state) : cardForeground(for: state)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.sheet) {
                selectedAchievement = badge
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                achievementArtworkBackground(backgroundName, state: state, tint: badge.color)

                stateMark(state, tint: badge.color, foreground: foreground.primary)
                    .padding(14)
                    .shadow(color: Color.arkInk.opacity(usesArtwork ? 0.24 : 0), radius: 4, x: 0, y: 2) // ui-v4: allow artwork icon readability without image wash

                VStack(alignment: .leading, spacing: 9) {
                    Spacer(minLength: 0)
                    Text(badge.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(foreground.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(stateText(for: badge, state: state, info: info))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(foreground.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    progressBar(info.fraction, tint: foreground.progressTint, track: foreground.progressTrack)
                }
                .padding(14)
                .shadow(color: Color.arkInk.opacity(usesArtwork ? 0.34 : 0), radius: 5, x: 0, y: 2) // ui-v4: allow artwork text readability without image wash
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.arkInk.opacity(usesArtwork ? 0.08 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func stateMark(_ state: AchievementRewardState, tint: Color, foreground: Color? = nil) -> some View {
        let resolvedForeground = foreground ?? Color.ohanaPrimaryText
        switch state {
        case .claimable:
            Image(systemName: "gift.fill")
                .foregroundStyle(foreground ?? Color.arkInk)
        case .claimed:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(resolvedForeground)
        case .unlocked:
            Image(systemName: "seal.fill")
                .foregroundStyle(resolvedForeground)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(foreground ?? Color.ohanaSecondaryText)
        }
    }

    private func achievementBackgroundName(for badge: Achievement) -> String? {
        Self.achievementBackgroundNames[badge.id]
    }

    @ViewBuilder
    private func achievementArtworkBackground(_ imageName: String?, state: AchievementRewardState, tint: Color) -> some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .saturation(state == .locked ? 0.24 : 1)
                .opacity(state == .locked ? 0.58 : 1)
                .overlay {
                    if state == .locked {
                        artworkReadabilityWash(for: state)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            cardBackground(for: state, tint: tint)
        }
    }

    private func artworkReadabilityWash(for state: AchievementRewardState) -> LinearGradient {
        let top = state == .locked ? 0.84 : 0.64
        let middle = state == .claimable ? 0.44 : 0.54
        let bottom = state == .locked ? 0.30 : 0.16
        return LinearGradient(
            colors: [
                Color.goCardWhite.opacity(top),
                Color.goCardWhite.opacity(middle),
                Color.arkInk.opacity(bottom)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func cardBackground(for state: AchievementRewardState, tint: Color) -> Color {
        switch state {
        case .claimable: return Color.goPrimary
        case .claimed, .unlocked: return Color.ohanaCardSurfaceElevated
        case .locked: return Color.ohanaCardSurface
        }
    }

    private func cardForeground(for state: AchievementRewardState) -> (primary: Color, secondary: Color, progressTint: Color, progressTrack: Color) {
        switch state {
        case .claimable:
            return (
                Color.arkInk,
                Color.arkInk.opacity(0.74),
                Color.arkInk,
                Color.arkInk.opacity(0.18)
            )
        case .claimed, .unlocked:
            return (
                Color.ohanaPrimaryText,
                Color.ohanaSecondaryText,
                Color.goPrimary,
                Color.ohanaControlFill
            )
        case .locked:
            return (
                Color.ohanaSecondaryText,
                Color.ohanaTertiaryText,
                Color.ohanaSecondaryText,
                Color.ohanaControlFill
            )
        }
    }

    private func artworkCardForeground(for state: AchievementRewardState) -> (primary: Color, secondary: Color, progressTint: Color, progressTrack: Color) {
        switch state {
        case .claimable, .claimed, .unlocked:
            return (
                Color.goCardWhite,
                Color.goCardWhite.opacity(0.82),
                Color.goCardWhite,
                Color.goCardWhite.opacity(0.28)
            )
        case .locked:
            return (
                Color.arkInk.opacity(0.62),
                Color.arkInk.opacity(0.48),
                Color.arkInk.opacity(0.45),
                Color.arkInk.opacity(0.10)
            )
        }
    }

    private func stateText(for badge: Achievement, state: AchievementRewardState, info: ProgressInfo) -> String {
        switch state {
        case .claimable:
            return l.tr(zh: "可领取 +\(rewardPerAchievement)🥥", en: "Claim +\(rewardPerAchievement)🥥", de: "+\(rewardPerAchievement)🥥 abholen")
        case .claimed:
            return l.tr(zh: "奖励已领取", en: "Reward claimed", de: "Belohnung abgeholt")
        case .unlocked:
            return l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        case .locked:
            return info.summary
        }
    }

    private func achievementMomentLine(for badge: Achievement) -> String {
        switch badge.id {
        case "iron_gut": return l.tr(zh: "这是一段稳定又安心的照护节奏。", en: "A steady care rhythm worth keeping.", de: "Ein ruhiger Pflegerhythmus, der bleibt.")
        case "iron_paw": return l.tr(zh: "一步一步，你们把日常走成了远方。", en: "Step by step, ordinary walks became distance.", de: "Schritt für Schritt wurde Alltag zu Strecke.")
        case "walk_streak": return l.tr(zh: "连续出门的日子，会慢慢变成习惯。", en: "Daily walks quietly turn into a habit.", de: "Tägliche Wege werden leise zur Gewohnheit.")
        case "health_hero": return l.tr(zh: "平稳健康，是最值得庆祝的小事。", en: "Steady health is a quiet thing to celebrate.", de: "Stabile Gesundheit ist ein leiser Grund zum Feiern.")
        case "nutritionist": return l.tr(zh: "每一餐都被认真记住了。", en: "Every meal was remembered with care.", de: "Jede Mahlzeit wurde achtsam festgehalten.")
        case "happy_birthday": return l.tr(zh: "今天属于这个被爱着的小生命。", en: "Today belongs to this well-loved little life.", de: "Heute gehört diesem geliebten kleinen Leben.")
        case "hundred_days": return l.tr(zh: "一百天的小事，已经长成一段陪伴。", en: "A hundred small days have become companionship.", de: "Hundert kleine Tage wurden zu Begleitung.")
        case "first_record": return l.tr(zh: "第一条记录，是你们故事的起点。", en: "The first record is where the story begins.", de: "Der erste Eintrag ist der Anfang eurer Geschichte.")
        case "day_one_checkin": return l.tr(zh: "今天也被好好照顾到了。", en: "Today got its little act of care.", de: "Auch heute gab es diesen kleinen Moment Fürsorge.")
        case "old_friend": return l.tr(zh: "熟悉感，是每天都回来一次。", en: "Familiarity is coming back, day after day.", de: "Vertrautheit heißt, jeden Tag wiederzukommen.")
        case "long_runner": return l.tr(zh: "这一次，你们真的走了很远。", en: "This time, you really went the distance.", de: "Diesmal seid ihr wirklich weit gegangen.")
        case "medication_complete": return l.tr(zh: "坚持到最后，是温柔也可靠的照护。", en: "Finishing the course is care that follows through.", de: "Bis zum Ende dranzubleiben ist verlässliche Fürsorge.")
        case "photo_enthusiast": return l.tr(zh: "镜头里留下了好多被爱的瞬间。", en: "So many loved moments made it into the frame.", de: "So viele geliebte Momente blieben im Bild.")
        case "expense_tracker": return l.tr(zh: "爱也有账本，清楚一点更安心。", en: "Care has a ledger too, and clarity feels good.", de: "Auch Fürsorge hat ein kleines Kassenbuch.")
        case "weight_manager": return l.tr(zh: "变化被看见，身体就更容易被照顾。", en: "When change is visible, care gets easier.", de: "Wenn Veränderung sichtbar wird, wird Fürsorge leichter.")
        case "hydration_buddy": return l.tr(zh: "一碗清水，也是一件被放在心上的事。", en: "A fresh bowl of water is care in its simplest form.", de: "Eine frische Schale Wasser ist Fürsorge ganz schlicht.")
        case "play_champion": return l.tr(zh: "玩耍不是奖励，是关系本身。", en: "Play is not a bonus; it is part of the bond.", de: "Spiel ist kein Extra, sondern Teil der Bindung.")
        case "clean_keeper": return l.tr(zh: "干净舒适的角落，藏着很多认真。", en: "A clean corner holds a lot of quiet effort.", de: "Eine saubere Ecke trägt viel stille Mühe.")
        case "treat_scout": return l.tr(zh: "小零食有小快乐，也有认真记录。", en: "Tiny treats carry tiny joy and careful notes.", de: "Kleine Snacks tragen kleine Freude und gute Notizen.")
        case "food_kind_explorer": return l.tr(zh: "口味被照顾到，日子也更丰富。", en: "Different tastes make daily care richer.", de: "Unterschiedliche Vorlieben machen den Alltag reicher.")
        case "auto_feeder_pilot": return l.tr(zh: "自动喂养也被纳入了照护节奏。", en: "Automated feeding joined the care rhythm.", de: "Automatisches Füttern gehört nun zum Rhythmus.")
        case "stock_keeper": return l.tr(zh: "粮仓有余，心里就更稳。", en: "A stocked pantry makes care feel ready.", de: "Ein gefüllter Vorrat macht Fürsorge gelassen.")
        case "protection_ready": return l.tr(zh: "重要的保障，已经被妥善收好。", en: "The important safeguards are now in place.", de: "Wichtige Absicherung ist gut aufgehoben.")
        case "vaccine_keeper": return l.tr(zh: "健康本里，多了一份安心。", en: "The health record now carries more peace of mind.", de: "Im Gesundheitsheft steckt nun mehr Sicherheit.")
        case "symptom_watcher": return l.tr(zh: "异常被看见，本身就是一种保护。", en: "Noticing what is unusual is protection too.", de: "Auffälligkeiten zu bemerken ist auch Schutz.")
        case "global_island_crew": return l.tr(zh: "这不是一个人的岛，是一家人的小队。", en: "This island belongs to the whole crew.", de: "Diese Insel gehört der ganzen Crew.")
        case "global_first_critter": return l.tr(zh: "第一个 Oasis 伙伴醒来了。", en: "The first Oasis companion has awakened.", de: "Der erste Oasis-Begleiter ist erwacht.")
        case "global_legendary_critter": return l.tr(zh: "稀有的相遇，也被故事收下了。", en: "A rare meeting found its place in the story.", de: "Eine seltene Begegnung fand ihren Platz.")
        case "global_critter_collector": return l.tr(zh: "小伙伴越来越多，岛也更热闹了。", en: "More companions make the island feel alive.", de: "Mehr Begleiter machen die Insel lebendig.")
        case "global_critter_star": return l.tr(zh: "成长发光的时候，一眼就看得见。", en: "Growth has a way of shining through.", de: "Wachstum beginnt sichtbar zu leuchten.")
        case "global_critter_caretaker": return l.tr(zh: "轻轻互动，也会养出默契。", en: "Small interactions grow into familiarity.", de: "Kleine Interaktionen wachsen zu Vertrautheit.")
        case "global_first_blind_box": return l.tr(zh: "第一份惊喜，正式打开。", en: "The first surprise has officially opened.", de: "Die erste Überraschung ist geöffnet.")
        case "global_blind_box_collector": return l.tr(zh: "收藏架上，开始有了自己的宇宙。", en: "The collection shelf is becoming its own universe.", de: "Das Sammlerregal bekommt sein eigenes Universum.")
        case "global_secret_blind_box": return l.tr(zh: "隐藏款出现的瞬间，运气也有了形状。", en: "A secret pull gave luck a shape.", de: "Ein geheimer Fund gab dem Glück eine Form.")
        case "global_gacha_series_complete": return l.tr(zh: "一整个系列，被你完整收进故事里。", en: "A whole series now lives in your story.", de: "Eine ganze Serie lebt nun in deiner Geschichte.")
        case "global_gacha_jackpot": return l.tr(zh: "这一次，椰子像阳光一样落下来。", en: "This time, coconuts landed like sunlight.", de: "Diesmal fielen Kokosnüsse wie Sonnenlicht.")
        case "human_profile_ready": return l.tr(zh: "你的身份卡，让 Ohana 更懂边界和照顾。", en: "Your profile helps Ohana care with better context.", de: "Dein Profil hilft Ohana, achtsamer zu begleiten.")
        case "human_first_record": return l.tr(zh: "自己的第一条记录，也值得被纪念。", en: "Your first record deserves to be remembered too.", de: "Auch dein erster Eintrag verdient Erinnerung.")
        case "human_weight_starter": return l.tr(zh: "建立基线，是照顾自己的第一步。", en: "A baseline is a gentle first step in self-care.", de: "Eine Basislinie ist ein sanfter erster Schritt.")
        case "human_weight_keeper": return l.tr(zh: "趋势被看见，身体的声音就更清楚。", en: "Seeing the trend makes the body's signals clearer.", de: "Der Trend macht Körpersignale klarer.")
        case "human_expense_tracker": return l.tr(zh: "家庭里的花费，也开始有迹可循。", en: "Household spending now has a clearer trail.", de: "Familienausgaben werden nun nachvollziehbarer.")
        case "human_medication_setup": return l.tr(zh: "计划建好了，照顾就少一点慌张。", en: "With a plan in place, care feels calmer.", de: "Mit Plan fühlt sich Fürsorge ruhiger an.")
        case "human_medication_keeper": return l.tr(zh: "按时完成的小事，最能托住日常。", en: "Small on-time routines can hold the day together.", de: "Pünktliche kleine Routinen tragen den Alltag.")
        case "human_workout_starter": return l.tr(zh: "开始活动，就是身体收到的第一封回信。", en: "Starting to move is the body's first reply.", de: "Loszugehen ist die erste Antwort des Körpers.")
        case "human_workout_rhythm": return l.tr(zh: "运动有了节奏，生活也跟着顺起来。", en: "Once movement has rhythm, life follows more easily.", de: "Wenn Bewegung Rhythmus findet, folgt der Alltag.")
        case "human_coconut_saver": return l.tr(zh: "一点点攒起来，也会变成看得见的底气。", en: "Saved bit by bit, confidence becomes visible.", de: "Stück für Stück wird Rückhalt sichtbar.")
        case "human_old_friend": return l.tr(zh: "你也和 Ohana 变熟了。", en: "You and Ohana have become familiar now.", de: "Du und Ohana seid vertrauter geworden.")
        default: return badge.description
        }
    }

    private func achievementCompletionText(for badge: Achievement, state: AchievementRewardState) -> String {
        guard badge.isUnlocked else {
            return l.tr(zh: "尚未完成", en: "Not completed yet", de: "Noch nicht abgeschlossen")
        }

        if let date = achievementCompletionDate(for: badge) {
            let formatted = date.formatted(.dateTime.year().month().day())
            return l.tr(zh: "完成于 \(formatted)", en: "Completed \(formatted)", de: "Abgeschlossen \(formatted)")
        }

        return l.tr(zh: "已完成", en: "Completed", de: "Abgeschlossen")
    }

    private func achievementCompletionDate(for badge: Achievement) -> Date? {
        if let unlockedAt = badge.unlockedAt { return unlockedAt }
        if let human = activeHuman { return humanAchievementCompletionDate(for: badge, human: human) }

        switch badge.id {
        case "iron_gut", "walk_streak", "health_hero":
            return badge.isUnlocked ? Date() : nil
        case "iron_paw":
            return cumulativeWalkDate(targetMeters: 100_000)
        case "nutritionist":
            return latestDate(from: feedingRecordDates())
        case "happy_birthday", "day_one_checkin":
            return badge.isUnlocked ? Date() : nil
        case "hundred_days":
            return Calendar.current.date(byAdding: .day, value: 100, to: activePet.createdAt)
        case "first_record":
            return earliestDate(from: petRecordDates())
        case "old_friend":
            return Calendar.current.date(byAdding: .day, value: 7, to: activePet.createdAt)
        case "long_runner":
            return activePet.walkLogs
                .filter { $0.distanceMeters >= 5_000 }
                .map(\.startDate)
                .min()
        case "medication_complete":
            return activePet.medications.compactMap(\.endDate).filter { $0 <= Date() }.min()
        case "photo_enthusiast":
            return thresholdDate(from: activePet.photoLogs.map(\.date), target: 20)
        case "expense_tracker":
            return thresholdDate(from: activePet.expenseLogs.map(\.date), target: 10)
        case "weight_manager":
            return thresholdDate(from: activePet.weightLogs.map(\.date), target: 7)
        case "hydration_buddy":
            return thresholdDate(from: activePet.careLogs.filter { $0.careType == .watering }.map(\.date), target: 14)
        case "play_champion":
            return thresholdDate(from: activePet.careLogs.filter { $0.careType == .play }.map(\.date), target: 20)
        case "clean_keeper":
            return thresholdDate(from: cleaningRecordDates(), target: 20)
        case "treat_scout":
            return thresholdDate(from: activePet.careLogs.filter { FeedLogMetadata.isTreatLog($0) }.map(\.date), target: 10)
        case "food_kind_explorer":
            return latestDate(from: mainFeedLogs().map(\.date))
        case "auto_feeder_pilot":
            return thresholdDate(from: mainFeedLogs().filter(\.isAutoFeedLogEntry).map(\.date), target: 3)
        case "stock_keeper":
            return thresholdDate(from: activePet.foodRecords.map(\.startDate), target: 2)
        case "protection_ready":
            return earliestDate(from: activePet.insurances.map(\.createdAt) + activePet.documents.compactMap(\.issueDate))
        case "vaccine_keeper":
            return activePet.healthLogs
                .filter {
                    $0.type == "vaccine"
                    || $0.type == "vaccination"
                    || $0.note.localizedCaseInsensitiveContains("疫苗")
                    || $0.note.localizedCaseInsensitiveContains("vaccine")
                    || $0.note.localizedCaseInsensitiveContains("impf")
                }
                .map(\.date)
                .min()
        case "symptom_watcher":
            return thresholdDate(from: activePet.symptomLogs.map(\.date), target: 3)
        case "global_island_crew":
            return thresholdDate(from: pets.map(\.createdAt), target: 2)
        case "global_first_critter":
            return electronicPets.map(\.obtainedAt).min()
        case "global_legendary_critter":
            return electronicPets.filter { $0.rarity == .legendary }.map(\.obtainedAt).min()
        case "global_critter_collector":
            return uniqueThresholdDate(
                items: electronicPets,
                key: { $0.catalogId },
                date: { $0.obtainedAt },
                target: 3
            )
        case "global_critter_star":
            return electronicPets.filter { $0.starLevel >= 2 }.map(\.obtainedAt).min()
        case "global_critter_caretaker":
            return thresholdDate(from: critterActionLogs.filter { $0.action != .careEcho }.map(\.createdAt), target: 10)
        case "global_first_blind_box":
            return gachaDrawLogs.map(\.drawDate).min()
        case "global_blind_box_collector":
            return uniqueThresholdDate(
                items: gachaOwnedItems,
                key: { "\($0.seriesId)#\($0.itemId)" },
                date: { $0.latestObtainedAt },
                target: 8
            )
        case "global_secret_blind_box":
            return gachaOwnedItems.filter(\.isHidden).map(\.latestObtainedAt).min()
        case "global_gacha_series_complete":
            return gachaOwnedItems.map(\.latestObtainedAt).max()
        case "global_gacha_jackpot":
            return gachaDrawLogs.filter { $0.instantCoconutDelta >= 500 }.map(\.drawDate).min()
        default:
            return nil
        }
    }

    private func humanAchievementCompletionDate(for badge: Achievement, human: Human) -> Date? {
        switch badge.id {
        case "human_profile_ready":
            return human.createdAt
        case "human_first_record":
            return earliestDate(from: humanRecordDates(human))
        case "human_weight_starter":
            return human.weightLogs.map(\.date).min()
        case "human_weight_keeper":
            return thresholdDate(from: human.weightLogs.map(\.date), target: 7)
        case "human_expense_tracker":
            return thresholdDate(from: expenses(for: human).map(\.date), target: 5)
        case "human_medication_setup":
            return medications(for: human).map(\.createdAt).min()
        case "human_medication_keeper":
            return thresholdDate(
                from: medicationLogs(for: human)
                    .filter { $0.status == .taken }
                    .map { $0.recordedTime ?? $0.createdAt },
                target: 7
            )
        case "human_workout_starter":
            return human.workoutLogs.map(\.date).min()
        case "human_workout_rhythm":
            return thresholdDate(from: human.workoutLogs.map(\.date), target: 10)
        case "human_old_friend":
            return Calendar.current.date(byAdding: .day, value: 7, to: human.createdAt)
        default:
            return nil
        }
    }

    private func thresholdDate(from dates: [Date], target: Int) -> Date? {
        let sorted = dates.sorted()
        guard sorted.count >= target, target > 0 else { return nil }
        return sorted[target - 1]
    }

    private func earliestDate(from dates: [Date]) -> Date? {
        dates.min()
    }

    private func latestDate(from dates: [Date]) -> Date? {
        dates.max()
    }

    private func uniqueThresholdDate<Item, Key: Hashable>(
        items: [Item],
        key: (Item) -> Key,
        date: (Item) -> Date,
        target: Int
    ) -> Date? {
        var seen = Set<Key>()
        for item in items.sorted(by: { date($0) < date($1) }) {
            seen.insert(key(item))
            if seen.count >= target { return date(item) }
        }
        return nil
    }

    private func cumulativeWalkDate(targetMeters: Double) -> Date? {
        var total = 0.0
        for log in activePet.walkLogs.sorted(by: { $0.startDate < $1.startDate }) {
            total += log.distanceMeters
            if total >= targetMeters { return log.startDate }
        }
        return nil
    }

    private func petRecordDates() -> [Date] {
        activePet.healthLogs.map(\.date)
        + activePet.pottyLogs.map(\.date)
        + activePet.walkLogs.map(\.startDate)
        + activePet.hygieneLogs.map(\.date)
        + activePet.careLogs.map(\.date)
        + activePet.foodRecords.map(\.startDate)
        + activePet.expenseLogs.map(\.date)
        + activePet.weightLogs.map(\.date)
        + activePet.photoLogs.map(\.date)
        + activePet.milestones.map(\.date)
    }

    private func feedingRecordDates() -> [Date] {
        activePet.foodRecords.map(\.startDate)
        + activePet.careLogs.filter { $0.careType == .feeding }.map(\.date)
    }

    private func cleaningRecordDates() -> [Date] {
        activePet.hygieneLogs.map(\.date)
        + activePet.careLogs.filter {
            [.litter, .waterChange, .filterClean, .cageCleaning, .substrateChange].contains($0.careType)
        }.map(\.date)
    }

    private func humanRecordDates(_ human: Human) -> [Date] {
        human.weightLogs.map(\.date)
        + human.workoutLogs.map(\.date)
        + medications(for: human).map(\.createdAt)
        + medicationLogs(for: human).map { $0.recordedTime ?? $0.createdAt }
        + expenses(for: human).map(\.date)
    }

    private var achievementProgressFill: LinearGradient {
        LinearGradient(
            colors: [Color.goPrimaryLight, Color.goPrimary, Color.goPrimaryDark],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func progressBar(_ value: Double, tint _: Color, track: Color = Color.ohanaControlFill) -> some View {
        let progress = min(max(value, 0), 1)

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if progress > 0 {
                    Capsule()
                        .fill(achievementProgressFill)
                        .frame(width: max(6, proxy.size.width * progress))
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.ohanaPrimaryActionText.opacity(0.24), Color.ohanaPrimaryActionText.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                }
            }
        }
        .frame(height: 8)
        .animation(GoMotion.stateChange, value: progress)
    }

    private func achievementPopup(_ badge: Achievement) -> some View {
        let state = rewardState(for: badge)
        let completionText = achievementCompletionText(for: badge, state: state)

        return ZStack {
            Color.arkInk.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture { closePopup() }

            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    achievementPopupArtwork(for: badge, state: state)

                    VStack(alignment: .leading, spacing: 8) {
                        Spacer(minLength: 0)

                        Text(badge.title)
                            .font(OhanaFont.title2(.black))
                            .foregroundStyle(Color.goCardWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(statusTitle(for: state))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goCardWhite.opacity(0.82))

                        Text(achievementMomentLine(for: badge))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.goCardWhite.opacity(0.92))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(completionText)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goCardWhite.opacity(0.78))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .shadow(color: Color.arkInk.opacity(0.48), radius: 6, x: 0, y: 2) // ui-v4: allow enlarged artwork text readability without image wash

                    HStack(spacing: 8) {
                        achievementPopupIconButton(
                            systemName: isRenderingAchievementShareImage ? "hourglass" : "square.and.arrow.down",
                            label: l.tr(zh: "下载", en: "Download", de: "Laden")
                        ) {
                            Task { await renderAndShareAchievement(badge) }
                        }
                        .disabled(isRenderingAchievementShareImage)

                        achievementPopupIconButton(
                            systemName: "xmark",
                            label: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
                            action: closePopup
                        )
                    }
                    .padding(12)
                }
                .frame(maxWidth: achievementPopupMaxImageWidth)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                if state == .claimable {
                    Button {
                        pendingClaimAchievement = badge
                    } label: {
                        Text(l.tr(zh: "领取 +\(rewardPerAchievement)🥥", en: "Claim +\(rewardPerAchievement)🥥", de: "+\(rewardPerAchievement)🥥 abholen"))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .frame(maxWidth: achievementPopupMaxImageWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func achievementPopupArtwork(for badge: Achievement, state: AchievementRewardState) -> some View {
        let backgroundName = achievementBackgroundName(for: badge)

        ZStack(alignment: .bottomLeading) {
            if let backgroundName {
                Image(backgroundName)
                    .resizable()
                    .scaledToFill()
                    .saturation(state == .locked ? 0.34 : 1)
            } else {
                badge.color
            }
        }
        .aspectRatio(achievementArtworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func achievementPopupIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 44, height: 44)
                .background(Color.goCardWhite.opacity(0.78), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.arkInk.opacity(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }

    @MainActor
    private func renderAndShareAchievement(_ badge: Achievement) async {
        guard !isRenderingAchievementShareImage else { return }
        isRenderingAchievementShareImage = true
        defer { isRenderingAchievementShareImage = false }

        let renderer = ImageRenderer(
            content: achievementDownloadCard(for: badge)
                .frame(width: achievementPopupMaxImageWidth, height: achievementPopupMaxImageWidth / achievementArtworkAspectRatio)
        )
        renderer.scale = 2
        if let image = renderer.uiImage {
            achievementShareImage = image
            showingAchievementShareSheet = true
        }
    }

    private func achievementDownloadCard(for badge: Achievement) -> some View {
        let state = rewardState(for: badge)
        let completionText = achievementCompletionText(for: badge, state: state)

        return ZStack(alignment: .bottomLeading) {
            achievementPopupArtwork(for: badge, state: state)

            VStack(alignment: .leading, spacing: 8) {
                Text(badge.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite)

                Text(statusTitle(for: state))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.82))

                Text(achievementMomentLine(for: badge))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.92))
                    .lineLimit(2)

                Text(completionText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.78))
            }
            .padding(22)
            .shadow(color: Color.arkInk.opacity(0.48), radius: 6, x: 0, y: 2) // ui-v4: allow exported artwork text readability without image wash
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func closePopup() {
        withAnimation(GoMotion.sheet) {
            selectedAchievement = nil
        }
    }

    @ViewBuilder
    private func claimConfirmPopup(_ badge: Achievement) -> some View {
        ZStack {
            Color.ohanaPrimaryText.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { pendingClaimAchievement = nil }

            VStack(spacing: 14) {
                Text(badge.emoji)
                    .font(.system(size: 44))
                    .frame(width: 70, height: 70)
                    .background(badge.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 5) {
                    Text(badge.title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(l.tr(zh: "领取成就奖励", en: "Claim badge reward", de: "Abzeichen-Belohnung abholen"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Text("+\(rewardPerAchievement)🥥")
                    .font(OhanaFont.metric(size: 34))
                    .foregroundStyle(Color.goPrimary)
                    .contentTransition(.numericText())

                HStack(spacing: 10) {
                    Button {
                        pendingClaimAchievement = nil
                    } label: {
                        Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        _ = claimReward(for: badge)
                        pendingClaimAchievement = nil
                    } label: {
                        Text(l.tr(zh: "确认", en: "Claim", de: "Abholen"))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.ohanaPrimaryText.opacity(0.16), radius: 24, x: 0, y: 14) // ui-v4: allow centered confirmation popup needs lifted overlay
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func activeMemberAvatar(size: CGFloat) -> some View {
        switch activeSubject {
        case .human(let id):
            if let human = humans.first(where: { $0.id == id }) {
                humanAvatar(human, size: size, isSelected: true)
            }
        case .pet:
            PetAvatarPortraitView(
                pet: activePet,
                size: size,
                backgroundOpacity: 0.16,
                transparentScale: 0.76,
                transparentYOffset: 0.04
            )
        }
    }

    @ViewBuilder
    private func memberAvatar(for subject: AchievementSubject, size: CGFloat, isSelected: Bool) -> some View {
        switch subject {
        case .pet(let id):
            if let item = pets.first(where: { $0.id == id }) {
                PetAvatarPortraitView(
                    pet: item,
                    size: size,
                    backgroundOpacity: isSelected ? 0.22 : 0.12,
                    transparentScale: 0.76,
                    transparentYOffset: 0.04
                )
            }
        case .human(let id):
            if let human = humans.first(where: { $0.id == id }) {
                humanAvatar(human, size: size, isSelected: isSelected)
            }
        }
    }

    private func memberName(for subject: AchievementSubject) -> String {
        switch subject {
        case .pet(let id):
            return pets.first(where: { $0.id == id })?.name ?? ""
        case .human(let id):
            return humans.first(where: { $0.id == id })?.name ?? ""
        }
    }

    @ViewBuilder
    private func humanAvatar(_ human: Human, size: CGFloat, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                .fill(Color(hex: human.safeThemeColorHex).opacity(isSelected ? 0.24 : 0.14))

            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.82, height: size * 0.82)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else {
                Text(String(human.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .frame(width: size, height: size)
    }

    private struct ProgressInfo {
        let current: Double
        let target: Double
        let unit: String
        let actionTitle: String

        var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1, max(0, current / target))
        }

        var summary: String {
            "\(formatted(current))/\(formatted(target))\(unit)"
        }

        private func formatted(_ value: Double) -> String {
            if value.rounded() == value { return "\(Int(value))" }
            return String(format: "%.1f", value)
        }
    }

    private func humanAchievements(for human: Human) -> [Achievement] {
        let profileScore = humanProfileScore(human)
        let medicationCount = medications(for: human).count
        let takenMedicationCount = medicationLogs(for: human).filter { $0.status == .taken }.count
        let expenseCount = expenses(for: human).count
        let accountDays = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0

        return [
            Achievement(
                id: "human_profile_ready",
                emoji: "👤",
                title: "身份卡完成",
                description: "补全本人档案，让 Ohana 的任务和隐私边界更准确",
                color: Color.goCardBlue,
                isUnlocked: profileScore >= 3
            ),
            Achievement(
                id: "human_first_record",
                emoji: "📝",
                title: "第一条记录",
                description: "完成任意一条体重、花费、运动或用药记录",
                color: Color.goCardCyan,
                isUnlocked: hasAnyHumanRecord(human)
            ),
            Achievement(
                id: "human_weight_starter",
                emoji: "⚖️",
                title: "体重起点",
                description: "记录第一条体重，建立自己的身体基线",
                color: Color.goMint,
                isUnlocked: !human.weightLogs.isEmpty
            ),
            Achievement(
                id: "human_weight_keeper",
                emoji: "📈",
                title: "趋势观察员",
                description: "累计记录 7 次体重，看见真实变化",
                color: Color.goTeal,
                isUnlocked: human.weightLogs.count >= 7
            ),
            Achievement(
                id: "human_expense_tracker",
                emoji: "💳",
                title: "记账上手",
                description: "记录 5 笔家庭或宠物相关花费",
                color: Color.goOrange,
                isUnlocked: expenseCount >= 5
            ),
            Achievement(
                id: "human_medication_setup",
                emoji: "💊",
                title: "用药计划",
                description: "建立至少一个用药计划",
                color: Color.goPurple,
                isUnlocked: medicationCount >= 1
            ),
            Achievement(
                id: "human_medication_keeper",
                emoji: "✅",
                title: "按时吃药",
                description: "累计完成 7 次用药打卡",
                color: Color.goLime,
                isUnlocked: takenMedicationCount >= 7
            ),
            Achievement(
                id: "human_workout_starter",
                emoji: "🏃",
                title: "开始活动",
                description: "记录第一条运动",
                color: Color.goYellow,
                isUnlocked: !human.workoutLogs.isEmpty
            ),
            Achievement(
                id: "human_workout_rhythm",
                emoji: "🔥",
                title: "运动节奏",
                description: "累计记录 10 次运动",
                color: Color.goRed,
                isUnlocked: human.workoutLogs.count >= 10
            ),
            Achievement(
                id: "human_coconut_saver",
                emoji: "🥥",
                title: "椰子小金库",
                description: "个人椰子余额达到 500",
                color: Color.goYellow,
                isUnlocked: human.coconutBalance >= 500
            ),
            Achievement(
                id: "human_old_friend",
                emoji: "🤝",
                title: "Ohana 老朋友",
                description: "本人档案建立满 7 天",
                color: Color.goPrimary,
                isUnlocked: accountDays >= 7
            )
        ]
    }

    private func progress(for badge: Achievement) -> ProgressInfo {
        if let human = activeHuman {
            return humanProgress(for: badge, human: human)
        }
        switch badge.id {
        case "iron_gut":
            return .init(current: Double(consecutivePerfectPoopDays()), target: 7, unit: "天", actionTitle: "连续记录完美便便")
        case "iron_paw":
            return .init(current: totalWalkKm(), target: 100, unit: "km", actionTitle: "累计遛狗距离")
        case "walk_streak":
            return .init(current: Double(consecutiveWalkDays()), target: 7, unit: "天", actionTitle: "连续遛狗记录")
        case "health_hero":
            let hasHealth = !activePet.healthLogs.isEmpty
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
            let hasRecentEmergency = activePet.healthLogs.contains {
                $0.date >= cutoff && ($0.type == "emergency" || $0.type == "surgery")
            }
            return .init(current: hasHealth && !hasRecentEmergency ? 1 : 0, target: 1, unit: "项", actionTitle: "添加健康记录并保持稳定")
        case "nutritionist":
            return .init(current: Double(feedingSpanDays()), target: 14, unit: "天", actionTitle: "持续记录饮食")
        case "happy_birthday":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "次", actionTitle: "生日当天打开 Ohana")
        case "hundred_days":
            return .init(current: Double(max(0, activePet.daysTogether)), target: 100, unit: "天", actionTitle: "共同生活天数")
        case "first_record":
            return .init(current: hasAnyRecord() ? 1 : 0, target: 1, unit: "条", actionTitle: "完成任意一条记录")
        case "day_one_checkin":
            return .init(current: hasAnyTodayRecord() ? 1 : 0, target: 1, unit: "次", actionTitle: "今天完成一次打卡")
        case "old_friend":
            let days = Calendar.current.dateComponents([.day], from: activePet.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: "天", actionTitle: "使用 Ohana 的天数")
        case "long_runner":
            return .init(current: maxSingleWalkKm(), target: 5, unit: "km", actionTitle: "单次遛狗距离")
        case "medication_complete":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "个疗程", actionTitle: "完成一个用药疗程")
        case "photo_enthusiast":
            return .init(current: Double(activePet.photoLogs.count), target: 20, unit: "张", actionTitle: "添加宠物照片")
        case "expense_tracker":
            return .init(current: Double(activePet.expenseLogs.count), target: 10, unit: "条", actionTitle: "记录宠物花费")
        case "weight_manager":
            return .init(current: Double(activePet.weightLogs.count), target: 7, unit: "条", actionTitle: "记录体重")
        case "hydration_buddy":
            return .init(current: Double(activePet.careLogs.filter { $0.careType == .watering }.count), target: 14, unit: "次", actionTitle: "累计喂水")
        case "play_champion":
            return .init(current: Double(activePet.careLogs.filter { $0.careType == .play }.count), target: 20, unit: "次", actionTitle: "累计陪玩")
        case "clean_keeper":
            return .init(current: Double(cleaningRecordCount()), target: 20, unit: "次", actionTitle: "累计清洁照护")
        case "treat_scout":
            return .init(current: Double(activePet.careLogs.filter { FeedLogMetadata.isTreatLog($0) }.count), target: 10, unit: "次", actionTitle: "累计记录零食")
        case "food_kind_explorer":
            return .init(current: Double(recordedFoodKindCount()), target: 2, unit: "种", actionTitle: "干粮湿粮都记录")
        case "auto_feeder_pilot":
            return .init(current: Double(mainFeedLogs().filter(\.isAutoFeedLogEntry).count), target: 3, unit: "次", actionTitle: "自动猫粮机记录")
        case "stock_keeper":
            return .init(current: Double(activePet.foodRecords.count), target: 2, unit: "次", actionTitle: "添加余粮")
        case "protection_ready":
            return .init(current: (!activePet.documents.isEmpty || !activePet.insurances.isEmpty) ? 1 : 0, target: 1, unit: "项", actionTitle: "添加证件或保险")
        case "vaccine_keeper":
            return .init(current: hasVaccineRecord() ? 1 : 0, target: 1, unit: "针", actionTitle: "记录疫苗")
        case "symptom_watcher":
            return .init(current: Double(activePet.symptomLogs.count), target: 3, unit: "次", actionTitle: "记录症状")
        case "global_island_crew":
            return .init(current: Double(pets.count), target: 2, unit: "位", actionTitle: "建立成员档案")
        case "global_first_critter":
            return .init(current: Double(electronicPets.count), target: 1, unit: "只", actionTitle: "获得电子宠物")
        case "global_legendary_critter":
            return .init(current: electronicPets.contains { $0.rarity == .legendary } ? 1 : 0, target: 1, unit: "只", actionTitle: "获得传说电子宠物")
        case "global_critter_collector":
            return .init(current: Double(Set(electronicPets.map(\.catalogId)).count), target: 3, unit: "只", actionTitle: "收集电子宠物")
        case "global_critter_star":
            return .init(current: Double(electronicPets.map(\.starLevel).max() ?? 0), target: 2, unit: "星", actionTitle: "电子宠物升星")
        case "global_critter_caretaker":
            return .init(current: Double(critterActionLogs.filter { $0.action != .careEcho }.count), target: 10, unit: "次", actionTitle: "电子宠物互动")
        case "global_first_blind_box":
            return .init(current: Double(gachaDrawLogs.count), target: 1, unit: "抽", actionTitle: "使用扭蛋机")
        case "global_blind_box_collector":
            return .init(current: Double(uniqueGachaItemCount()), target: 8, unit: "款", actionTitle: "收集盲盒款式")
        case "global_secret_blind_box":
            return .init(current: gachaOwnedItems.contains(where: \.isHidden) ? 1 : 0, target: 1, unit: "款", actionTitle: "抽中隐藏款")
        case "global_gacha_series_complete":
            return .init(current: Double(AchievementManager.completedGachaSeriesCount(gachaOwnedItems)), target: 1, unit: "套", actionTitle: "集齐盲盒系列")
        case "global_gacha_jackpot":
            return .init(current: gachaDrawLogs.contains { $0.instantCoconutDelta >= 500 } ? 1 : 0, target: 1, unit: "次", actionTitle: "抽到椰子大礼包")
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "项", actionTitle: "完成条件")
        }
    }

    private func humanProgress(for badge: Achievement, human: Human) -> ProgressInfo {
        switch badge.id {
        case "human_profile_ready":
            return .init(current: Double(humanProfileScore(human)), target: 3, unit: "项", actionTitle: "补全本人档案")
        case "human_first_record":
            return .init(current: hasAnyHumanRecord(human) ? 1 : 0, target: 1, unit: "条", actionTitle: "完成任意记录")
        case "human_weight_starter":
            return .init(current: Double(human.weightLogs.count), target: 1, unit: "条", actionTitle: "记录体重")
        case "human_weight_keeper":
            return .init(current: Double(human.weightLogs.count), target: 7, unit: "条", actionTitle: "累计体重记录")
        case "human_expense_tracker":
            return .init(current: Double(expenses(for: human).count), target: 5, unit: "笔", actionTitle: "记录花费")
        case "human_medication_setup":
            return .init(current: Double(medications(for: human).count), target: 1, unit: "个", actionTitle: "添加用药计划")
        case "human_medication_keeper":
            return .init(current: Double(medicationLogs(for: human).filter { $0.status == .taken }.count), target: 7, unit: "次", actionTitle: "完成用药打卡")
        case "human_workout_starter":
            return .init(current: Double(human.workoutLogs.count), target: 1, unit: "条", actionTitle: "记录运动")
        case "human_workout_rhythm":
            return .init(current: Double(human.workoutLogs.count), target: 10, unit: "次", actionTitle: "累计运动记录")
        case "human_coconut_saver":
            return .init(current: Double(human.coconutBalance), target: 500, unit: "🥥", actionTitle: "积累个人椰子")
        case "human_old_friend":
            let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: "天", actionTitle: "使用 Ohana 的天数")
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "项", actionTitle: "完成条件")
        }
    }

    private func consecutivePerfectPoopDays() -> Int {
        consecutiveDays { day in
            activePet.pottyLogs.contains {
                Calendar.current.isDate($0.date, inSameDayAs: day) && $0.pottyType == .perfectPoop
            }
        }
    }

    private func consecutiveWalkDays() -> Int {
        consecutiveDays { day in
            activePet.walkLogs.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
        }
    }

    private func consecutiveDays(hasRecord: (Date) -> Bool) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var count = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if hasRecord(day) { count += 1 } else { break }
        }
        return count
    }

    private func totalWalkKm() -> Double {
        activePet.walkLogs.reduce(0.0) { $0 + $1.distanceMeters / 1000.0 }
    }

    private func maxSingleWalkKm() -> Double {
        activePet.walkLogs.map { $0.distanceMeters / 1000.0 }.max() ?? 0
    }

    private func feedingSpanDays() -> Int {
        let dates = activePet.foodRecords.map(\.startDate)
            + activePet.careLogs.filter { $0.careType == .feeding }.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    }

    private func hasAnyRecord() -> Bool {
        !activePet.healthLogs.isEmpty || !activePet.pottyLogs.isEmpty || !activePet.walkLogs.isEmpty
        || !activePet.hygieneLogs.isEmpty || !activePet.careLogs.isEmpty || !activePet.foodRecords.isEmpty
        || !activePet.expenseLogs.isEmpty || !activePet.weightLogs.isEmpty || !activePet.photoLogs.isEmpty
        || !activePet.milestones.isEmpty
    }

    private func hasAnyTodayRecord() -> Bool {
        let calendar = Calendar.current
        return activePet.healthLogs.contains { calendar.isDateInToday($0.date) }
        || activePet.hygieneLogs.contains { calendar.isDateInToday($0.date) }
        || activePet.pottyLogs.contains { calendar.isDateInToday($0.date) }
        || activePet.walkLogs.contains { calendar.isDateInToday($0.startDate) }
        || activePet.careLogs.contains { calendar.isDateInToday($0.date) }
        || activePet.weightLogs.contains { calendar.isDateInToday($0.date) }
    }

    private func mainFeedLogs() -> [PetCareLog] {
        activePet.careLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
    }

    private func cleaningRecordCount() -> Int {
        let careCount = activePet.careLogs.filter {
            [.litter, .waterChange, .filterClean, .cageCleaning, .substrateChange].contains($0.careType)
        }.count
        return activePet.hygieneLogs.count + careCount
    }

    private func recordedFoodKindCount() -> Int {
        Set(mainFeedLogs().map(\.foodKindRaw).filter { !$0.isEmpty }).count
    }

    private func hasVaccineRecord() -> Bool {
        activePet.healthLogs.contains {
            $0.type == "vaccine"
            || $0.type == "vaccination"
            || $0.note.localizedCaseInsensitiveContains("疫苗")
            || $0.note.localizedCaseInsensitiveContains("vaccine")
            || $0.note.localizedCaseInsensitiveContains("impf")
        }
    }

    private func uniqueGachaItemCount() -> Int {
        Set(gachaOwnedItems.map { "\($0.seriesId)#\($0.itemId)" }).count
    }

    private func humanProfileScore(_ human: Human) -> Int {
        [
            human.birthday != nil,
            human.heightCm > 0,
            !human.bloodType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !human.mbti.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !human.nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !human.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ].filter { $0 }.count
    }

    private func medications(for human: Human) -> [HumanMedication] {
        humanMedications.filter { $0.humanId == human.id.uuidString }
    }

    private func medicationLogs(for human: Human) -> [HumanMedicationLog] {
        humanMedicationLogs.filter { $0.humanId == human.id.uuidString }
    }

    private func expenses(for human: Human) -> [PetExpenseLog] {
        allExpenseLogs.filter { $0.executorId == human.id.uuidString }
    }

    private func hasAnyHumanRecord(_ human: Human) -> Bool {
        !human.weightLogs.isEmpty
        || !human.workoutLogs.isEmpty
        || !medications(for: human).isEmpty
        || !medicationLogs(for: human).isEmpty
        || !expenses(for: human).isEmpty
    }

    private func rewardState(for badge: Achievement) -> AchievementRewardState {
        guard badge.isUnlocked else { return .locked }
        if isRewardClaimed(badge) { return .claimed }
        return .claimable
    }

    private func sortRank(for badge: Achievement) -> Int {
        switch rewardState(for: badge) {
        case .claimable: return 0
        case .unlocked: return 1
        case .claimed: return 2
        case .locked: return 3
        }
    }

    private func statusTitle(for state: AchievementRewardState) -> String {
        switch state {
        case .claimable: return l.tr(zh: "可领取", en: "Ready to claim", de: "Bereit")
        case .claimed: return l.tr(zh: "已领取", en: "Claimed", de: "Abgeholt")
        case .unlocked: return l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        case .locked: return l.tr(zh: "进行中", en: "In progress", de: "In Arbeit")
        }
    }

    private func rewardKey(for badge: Achievement) -> String {
        if AchievementManager.isGlobalAchievement(badge) {
            return "global::\(badge.id)"
        }
        if let human = activeHuman {
            return "\(human.id.uuidString)_\(badge.id)"
        }
        return "\(activePet.id.uuidString)_\(badge.id)"
    }

    private var claimedRewardIDs: Set<String> {
        Set(claimedRewardRaw.split(separator: ",").map(String.init))
    }

    private func isRewardClaimed(_ badge: Achievement) -> Bool {
        claimedRewardIDs.contains(rewardKey(for: badge))
    }

    @discardableResult
    private func claimReward(for badge: Achievement, playFeedback: Bool = true) -> Int {
        guard badge.isUnlocked, !isRewardClaimed(badge) else { return 0 }
        var ids = claimedRewardIDs
        ids.insert(rewardKey(for: badge))
        claimedRewardRaw = ids.sorted().joined(separator: ",")

        let actor = creditActiveAccount(amount: rewardPerAchievement)
        QuestManager.shared.recordCoconutDelta(
            rewardPerAchievement,
            emoji: badge.emoji,
            title: l.tr(zh: "成就奖励 · \(badge.title)", en: "Badge reward · \(badge.title)", de: "Abzeichen-Belohnung · \(badge.title)"),
            actorId: actor.id,
            actorName: actor.name
        )
        modelContext.safeSave()

        if playFeedback {
            showReward(
                rewardPerAchievement,
                label: l.tr(
                    zh: "成就奖励",
                    en: "Badge reward",
                    de: "Abzeichen-Belohnung"
                )
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        return rewardPerAchievement
    }

    private func claimAllRewards() {
        let total = claimable.reduce(0) { partial, badge in
            partial + claimReward(for: badge, playFeedback: false)
        }
        guard total > 0 else { return }
        showReward(
            total,
            label: l.tr(
                zh: "成就奖励",
                en: "Badge reward",
                de: "Abzeichen-Belohnung"
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func showReward(_ amount: Int, label: String?) {
        guard amount > 0 else { return }
        rewardAnimationAmount = amount
        rewardAnimationLabel = label
        showRewardAnimation = false
        DispatchQueue.main.async {
            showRewardAnimation = true
        }
    }

    private func creditActiveAccount(amount: Int) -> (id: String, name: String) {
        if let human = activeHuman {
            human.coconutBalance += amount
            return (human.id.uuidString, human.name)
        }
        activePet.coconutBalance += amount
        return (activePet.id.uuidString, activePet.name)
    }
}
