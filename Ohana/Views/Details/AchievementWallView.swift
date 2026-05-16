//
//  AchievementWallView.swift
//  Ohana
//
//  成就解锁页 — 真实进度、宠物切换、解锁奖励领取
//

import SwiftUI

struct AchievementWallView: View {
    let pet: Pet
    var allPets: [Pet] = []

    @Environment(\.dismiss) private var dismiss
    @AppStorage("achievement_claimedRewardIDs") private var claimedRewardRaw: String = ""

    @State private var selectedPetId: UUID?
    @State private var selectedFilter: AchievementFilter = .all
    @State private var selectedAchievement: Achievement?

    private enum AchievementFilter: String, CaseIterable {
        case all = "全部"
        case unlocked = "已解锁"
        case locked = "进行中"
    }

    private let rewardPerAchievement = 10
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

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

    private var displayedAchievements: [Achievement] {
        achievements
            .filter { badge in
                switch selectedFilter {
                case .all: return true
                case .unlocked: return badge.isUnlocked
                case .locked: return !badge.isUnlocked
                }
            }
            .sorted { lhs, rhs in
                if lhs.isUnlocked != rhs.isUnlocked { return lhs.isUnlocked && !rhs.isUnlocked }
                return progress(for: lhs).fraction > progress(for: rhs).fraction
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if pets.count > 1 {
                            petSelector
                        }
                        progressHeader
                        nextUnlockCard
                        filterChips
                        achievementGrid
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("成就解锁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .tint(Color.goPrimary)
        .onAppear {
            if selectedPetId == nil { selectedPetId = pet.id }
        }
        .sheet(item: $selectedAchievement) { badge in
            achievementDetailSheet(badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var petSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pets) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedPetId = item.id
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(item.avatarEmoji.isEmpty ? item.speciesEmoji : item.avatarEmoji)
                            Text(item.name)
                                .lineLimit(1)
                        }
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selectedPetId == item.id ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedPetId == item.id ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var progressHeader: some View {
        let total = max(achievements.count, 1)
        let percent = Double(unlocked.count) / Double(total)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                petAvatar(size: 54)
                VStack(alignment: .leading, spacing: 5) {
                    Text(activePet.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text("\(unlocked.count)/\(achievements.count) 已解锁 · \(claimable.count) 个奖励待领取")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * percent)
                }
            }
            .frame(height: 9)

            if !claimable.isEmpty {
                Button { claimAllRewards() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                        Text("领取全部 +\(claimable.count * rewardPerAchievement)🥥")
                    }
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
    }

    private var nextUnlockCard: some View {
        let locked = achievements
            .filter { !$0.isUnlocked }
            .sorted { progress(for: $0).fraction > progress(for: $1).fraction }

        return Group {
            if let next = locked.first {
                let progress = progress(for: next)
                Button { selectedAchievement = next } label: {
                    HStack(spacing: 12) {
                        Text(next.emoji)
                            .font(.system(size: 28))
                            .frame(width: 46, height: 46)
                            .background(next.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("下一枚成就")
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.goPrimary)
                            Text(next.title)
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            ProgressView(value: progress.fraction)
                                .tint(next.color)
                            Text(progress.summary)
                                .font(OhanaFont.caption2(.bold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                HStack(spacing: 12) {
                    Text("🏆").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("全部成就已解锁")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("继续记录生活，新的成就体系会优先从这些数据扩展")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(AchievementFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selectedFilter == filter ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedFilter == filter ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            Spacer()
        }
    }

    private var achievementGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedAchievements) { badge in
                achievementCard(badge)
            }
        }
    }

    private func achievementCard(_ badge: Achievement) -> some View {
        let progress = progress(for: badge)
        let claimed = isRewardClaimed(badge)

        return Button { selectedAchievement = badge } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(badge.emoji)
                        .font(.system(size: 26))
                        .opacity(badge.isUnlocked ? 1 : 0.35)
                        .grayscale(badge.isUnlocked ? 0 : 1)
                    Spacer()
                    if badge.isUnlocked {
                        Image(systemName: claimed ? "checkmark.seal.fill" : "gift.fill")
                            .foregroundStyle(claimed ? badge.color : Color.goPrimary)
                    } else {
                        Text("\(Int(progress.fraction * 100))%")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .monospacedDigit()
                    }
                }

                Text(badge.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(badge.isUnlocked ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(badge.isUnlocked ? (claimed ? "奖励已领取" : "可领取 +\(rewardPerAchievement)🥥") : progress.summary)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(badge.isUnlocked ? Color.goPrimary : Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: progress.fraction)
                    .tint(badge.isUnlocked ? Color.goPrimary : badge.color)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                badge.isUnlocked
                ? badge.color.opacity(0.16)
                : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(badge.isUnlocked ? badge.color.opacity(0.35) : Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func achievementDetailSheet(_ badge: Achievement) -> some View {
        let progress = progress(for: badge)
        let claimed = isRewardClaimed(badge)

        return ZStack {
            OhanaAppBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Text(badge.emoji)
                        .font(.system(size: 42))
                        .frame(width: 64, height: 64)
                        .background(badge.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(badge.title)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(badge.isUnlocked ? "已解锁" : "进行中")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(badge.isUnlocked ? Color.goPrimary : Color.ohanaSecondaryText)
                    }
                    Spacer()
                }

                Text(badge.description)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress.actionTitle)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(progress.summary)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(badge.color)
                    }
                    ProgressView(value: progress.fraction)
                        .tint(badge.color)
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if badge.isUnlocked && !claimed {
                    Button { claimReward(for: badge) } label: {
                        Text("领取 +\(rewardPerAchievement)🥥")
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Spacer()
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func petAvatar(size: CGFloat) -> some View {
        if let data = activePet.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(activePet.avatarEmoji.isEmpty ? activePet.speciesEmoji : activePet.avatarEmoji)
                .font(.system(size: size * 0.52))
                .frame(width: size, height: size)
                .background(Color(hex: activePet.themeColorHex).opacity(0.18), in: Circle())
        }
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
            title: "成就奖励 · \(badge.title)",
            actorId: activePet.id.uuidString,
            actorName: activePet.name
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func claimAllRewards() {
        claimable.forEach { claimReward(for: $0) }
    }
}
