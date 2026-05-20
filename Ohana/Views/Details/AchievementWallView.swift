//
//  AchievementWallView.swift
//  Ohana
//
//  成就徽章墙 — V4 游戏化进度与领取
//

import SwiftUI

struct AchievementWallView: View {
    let pet: Pet
    var allPets: [Pet] = []

    @Environment(\.dismiss) private var dismiss
    @AppStorage("achievement_claimedRewardIDs") private var claimedRewardRaw: String = ""
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.fallbackCode

    @State private var selectedPetId: UUID?
    @State private var selectedFilter: AchievementFilter = .all
    @State private var selectedAchievement: Achievement?

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

    private var activePet: Pet {
        pets.first(where: { $0.id == selectedPetId }) ?? pet
    }

    private var achievements: [Achievement] {
        AchievementManager.compute(for: activePet)
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
                    if pets.count > 1 { petSelector }
                    progressHero
                    filterChips
                    achievementGrid
                    Color.clear.frame(height: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .blur(radius: selectedAchievement == nil ? 0 : 1.2)
            .allowsHitTesting(selectedAchievement == nil)

            if let selectedAchievement {
                achievementPopup(selectedAchievement)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(4)
            }
        }
        .tint(Color.goPrimary)
        .onAppear {
            if selectedPetId == nil { selectedPetId = pet.id }
        }
        .animation(GoMotion.sheet, value: selectedAchievement?.id)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "成就解锁", en: "Badges", de: "Abzeichen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(activePet.name)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
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

    private var petSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pets) { item in
                    let isSelected = selectedPetId == item.id
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedPetId = item.id
                        }
                    } label: {
                        VStack(spacing: 5) {
                            PetAvatarPortraitView(
                                pet: item,
                                size: 44,
                                backgroundOpacity: isSelected ? 0.22 : 0.12,
                                transparentScale: 0.76,
                                transparentYOffset: 0.04
                            )
                            Text(item.name)
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
                petAvatar(size: 58)
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

        return Button { selectedAchievement = badge } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    badgeGlyph(badge, state: state)
                    Spacer()
                    stateMark(state, tint: badge.color)
                }

                Text(badge.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(state == .locked ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(stateText(for: badge, state: state, info: info))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(state == .claimable ? Color.goPrimary : Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                progressBar(info.fraction, tint: state == .locked ? badge.color.opacity(0.72) : Color.goPrimary)
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
            .background((state == .locked ? Color.ohanaControlFill : badge.color.opacity(0.14)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func stateMark(_ state: AchievementRewardState, tint: Color) -> some View {
        switch state {
        case .claimable:
            Image(systemName: "gift.fill")
                .foregroundStyle(Color.goPrimary)
        case .claimed:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(tint)
        case .unlocked:
            Image(systemName: "seal.fill")
                .foregroundStyle(tint)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func cardBackground(for state: AchievementRewardState, tint: Color) -> Color {
        switch state {
        case .claimable: return Color.goPrimary.opacity(0.18)
        case .claimed, .unlocked: return tint.opacity(0.15)
        case .locked: return Color.ohanaCardSurface
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

    private func progressBar(_ value: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ohanaControlFill)
                Capsule()
                    .fill(tint)
                    .frame(width: max(6, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
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
                            claimReward(for: badge)
                            closePopup()
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
    private func petAvatar(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            pet: activePet,
            size: size,
            backgroundOpacity: 0.16,
            transparentScale: 0.76,
            transparentYOffset: 0.04
        )
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

    private func progress(for badge: Achievement) -> ProgressInfo {
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
        "\(activePet.id.uuidString)_\(badge.id)"
    }

    private var claimedRewardIDs: Set<String> {
        Set(claimedRewardRaw.split(separator: ",").map(String.init))
    }

    private func isRewardClaimed(_ badge: Achievement) -> Bool {
        claimedRewardIDs.contains(rewardKey(for: badge))
    }

    private func claimReward(for badge: Achievement) {
        guard badge.isUnlocked, !isRewardClaimed(badge) else { return }
        var ids = claimedRewardIDs
        ids.insert(rewardKey(for: badge))
        claimedRewardRaw = ids.sorted().joined(separator: ",")
        QuestManager.shared.addCoconuts(
            rewardPerAchievement,
            emoji: badge.emoji,
            title: l.tr(zh: "成就奖励 · \(badge.title)", en: "Badge reward · \(badge.title)", de: "Abzeichen-Belohnung · \(badge.title)"),
            actorId: activePet.id.uuidString,
            actorName: activePet.name
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func claimAllRewards() {
        claimable.forEach { claimReward(for: $0) }
    }
}
