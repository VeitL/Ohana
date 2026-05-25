//
//  AchievementWallView.swift
//  Ohana
//
//  成就徽章墙 — V4 游戏化进度与领取
//

import SwiftUI
import SwiftData

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
        let foreground = cardForeground(for: state)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if state == .claimable {
                pendingClaimAchievement = badge
            } else {
                selectedAchievement = badge
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    badgeGlyph(badge, state: state)
                    Spacer()
                    stateMark(state, tint: badge.color)
                }

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
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(cardBackground(for: state, tint: badge.color), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func badgeGlyph(_ badge: Achievement, state: AchievementRewardState) -> some View {
        Text(badge.emoji)
            .font(.system(size: 28))
            .opacity(state == .locked ? 0.32 : 1)
            .grayscale(state == .locked ? 1 : 0)
            .frame(width: 42, height: 42)
            .background(glyphBackground(for: state, tint: badge.color), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func stateMark(_ state: AchievementRewardState, tint: Color) -> some View {
        switch state {
        case .claimable:
            Image(systemName: "gift.fill")
                .foregroundStyle(Color.arkInk)
        case .claimed:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.ohanaPrimaryText)
        case .unlocked:
            Image(systemName: "seal.fill")
                .foregroundStyle(Color.ohanaPrimaryText)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func cardBackground(for state: AchievementRewardState, tint: Color) -> Color {
        switch state {
        case .claimable: return Color.goPrimary
        case .claimed, .unlocked: return Color.ohanaCardSurfaceElevated
        case .locked: return Color.ohanaCardSurface
        }
    }

    private func glyphBackground(for state: AchievementRewardState, tint: Color) -> Color {
        switch state {
        case .claimable: return Color.arkInk.opacity(0.18)
        case .claimed, .unlocked: return tint
        case .locked: return Color.ohanaControlFill
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
        let info = progress(for: badge)
        let state = rewardState(for: badge)

        return ZStack(alignment: .bottom) {
            Color.ohanaPrimaryText.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { closePopup() }

            VStack(spacing: 0) {
                OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 16)
                            .onEnded { value in
                                if value.translation.height > 48 { closePopup() }
                            }
                    )

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Text(badge.emoji)
                            .font(.system(size: 42))
                            .frame(width: 66, height: 66)
                            .background(badge.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(badge.title)
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(statusTitle(for: state))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(state == .claimable ? Color.goPrimary : Color.ohanaSecondaryText)
                        }
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { closePopup() }
                    }

                    Text(badge.description)
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(info.actionTitle)
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Spacer()
                            Text(info.summary)
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(badge.color)
                        }
                        progressBar(info.fraction, tint: badge.color)
                    }
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if state == .claimable {
                        Button {
                            closePopup()
                            pendingClaimAchievement = badge
                        } label: {
                            Text(l.tr(zh: "领取 +\(rewardPerAchievement)🥥", en: "Claim +\(rewardPerAchievement)🥥", de: "+\(rewardPerAchievement)🥥 abholen"))
                                .font(OhanaFont.subheadline(.black))
                                .foregroundStyle(Color.ohanaPrimaryActionText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        }
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
