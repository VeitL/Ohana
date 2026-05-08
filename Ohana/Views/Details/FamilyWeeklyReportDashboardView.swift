//
//  FamilyWeeklyReportDashboardView.swift
//  Ohana
//
//  Family-wide weekly report across pets, members, and assigned tasks.
//

import SwiftUI
import SwiftData

struct FamilyWeeklyReportDashboardView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]

    private var weekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Date().addingTimeInterval(-6 * 86_400), duration: 7 * 86_400)
    }

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var allEntries: [ReportEntry] {
        activePets.flatMap { pet in
            entries(for: pet, in: weekInterval)
        }
        .sorted { $0.date > $1.date }
    }

    private var rankedMembers: [MemberStat] {
        var dict: [String: MemberStat] = [:]
        for entry in allEntries {
            let id = entry.actorId ?? "unknown"
            let human = humans.first { $0.id.uuidString == id }
            let name = human?.name ?? "未指定"
            let emoji = human?.avatarEmoji ?? "👤"
            var stat = dict[id] ?? MemberStat(id: id, name: name, emoji: emoji, count: 0, coconuts: 0)
            stat.count += 1
            stat.coconuts += entry.coconuts
            dict[id] = stat
        }
        return dict.values.sorted {
            if $0.count == $1.count { return $0.coconuts > $1.coconuts }
            return $0.count > $1.count
        }
    }

    private var topPet: (name: String, count: Int)? {
        let grouped = Dictionary(grouping: allEntries, by: \.petName)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }.first
    }

    private var mostActiveDay: ActiveDayStat? {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: allEntries) { cal.startOfDay(for: $0.date) }
        return grouped
            .map { ActiveDayStat(date: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count { return $0.date > $1.date }
                return $0.count > $1.count
            }
            .first
    }

    private var weekPhotoMemories: [PhotoMemory] {
        activePets.flatMap { pet in
            pet.photoLogs
                .filter { weekInterval.contains($0.date) }
                .map {
                    PhotoMemory(
                        id: $0.id,
                        petName: pet.name,
                        imageData: $0.imageData,
                        note: $0.note,
                        date: $0.date
                    )
                }
        }
        .sorted { $0.date > $1.date }
    }

    private var weekWeightTrends: [WeightTrend] {
        activePets.compactMap { pet in
            let logs = pet.weightLogs
                .filter { $0.date < weekInterval.end }
                .sorted { $0.date < $1.date }
            guard let latest = logs.last else { return nil }
            let baseline = logs.last { $0.date < weekInterval.start } ?? logs.dropLast().last
            guard let baseline else { return nil }
            let days = max(1, Calendar.current.dateComponents([.day], from: baseline.date, to: latest.date).day ?? 1)
            return WeightTrend(
                id: pet.id,
                petName: pet.name,
                latestKg: latest.weight,
                deltaKg: latest.weight - baseline.weight,
                days: days
            )
        }
    }

    private var healthAlerts: [HealthAlert] {
        PetHealthAlertEngine.shared.scanAlerts(pets: activePets)
    }

    private var storyHeadline: String {
        if allEntries.isEmpty { return "这周还在等待第一条照护故事" }
        if let pet = topPet { return "\(pet.name) 这周被好好照顾了 \(pet.count) 次" }
        return "这周的家庭照护已经留下记录"
    }

    private var storyBody: String {
        guard !allEntries.isEmpty else {
            return "完成一次喂食、陪玩、照片或健康记录后，周报会自动整理成可分享的家庭故事。"
        }
        let leader = rankedMembers.first.map { "\($0.name) 照顾最多" } ?? "照护记录已同步"
        let day = mostActiveDay.map { "\($0.date.formatted(.dateTime.weekday(.wide))) 最活跃" } ?? "每天都有记录"
        return "\(leader)，\(day)。\(weightStoryText) \(photoStoryText) \(healthStoryText)"
    }

    private var weightStoryText: String {
        guard let trend = weekWeightTrends.max(by: { abs($0.deltaKg) < abs($1.deltaKg) }) else {
            return "体重趋势还缺少连续记录。"
        }
        if abs(trend.deltaKg) < 0.05 {
            return "\(trend.petName) 体重稳定在 \(String(format: "%.1fkg", trend.latestKg))。"
        }
        let sign = trend.deltaKg > 0 ? "+" : ""
        return "\(trend.petName) 近 \(trend.days) 天体重 \(sign)\(String(format: "%.1fkg", trend.deltaKg))。"
    }

    private var photoStoryText: String {
        guard let memory = weekPhotoMemories.first else {
            return "本周还没有照片回忆。"
        }
        return "最新回忆是 \(memory.petName) 的照片。"
    }

    private var healthStoryText: String {
        guard let first = healthAlerts.first else {
            return "健康提醒正常。"
        }
        let urgentCount = healthAlerts.filter { $0.severity == .urgent }.count
        if urgentCount > 0 {
            return "\(urgentCount) 项紧急健康提醒：\(first.title)。"
        }
        return "\(healthAlerts.count) 项健康提醒待留意：\(first.title)。"
    }

    private var shareText: String {
        let leader = rankedMembers.first.map { "\($0.emoji) \($0.name) \($0.count) 次" } ?? "暂无"
        let petLine = topPet.map { "\($0.name) 被照顾 \($0.count) 次" } ?? "暂无宠物记录"
        return "Ohana 本周家庭周报\n\(storyHeadline)\n\(storyBody)\n总照护 \(allEntries.count) 次\n本周之星：\(leader)\n最受关注：\(petLine)"
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    weeklyStoryCard
                    memberRankingCard
                    petCoverageCard
                    memoryAndHealthCard
                    recentActivityCard
                    previousWeeksCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("家庭周报")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本周 Ohana")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("\(weekInterval.start.formatted(.dateTime.month().day())) - \(weekInterval.end.formatted(.dateTime.month().day()))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: shareText) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
            }

            HStack(spacing: 10) {
                metric("照护", "\(allEntries.count)", .goPrimary)
                metric("成员", "\(rankedMembers.filter { $0.id != "unknown" }.count)", .goTeal)
                metric("椰子", "\(allEntries.reduce(0) { $0 + $1.coconuts })", .goYellow)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var weeklyStoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("本周故事", icon: "sparkles.rectangle.stack.fill")
            VStack(alignment: .leading, spacing: 6) {
                Text(storyHeadline)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(storyBody)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                storyPill(
                    icon: "crown.fill",
                    title: rankedMembers.first?.name ?? "暂无",
                    subtitle: "照顾最多",
                    color: .goPrimary
                )
                storyPill(
                    icon: "calendar.badge.clock",
                    title: mostActiveDay.map { $0.date.formatted(.dateTime.weekday(.abbreviated)) } ?? "暂无",
                    subtitle: "最活跃日",
                    color: .goTeal
                )
                storyPill(
                    icon: "photo.fill",
                    title: "\(weekPhotoMemories.count)",
                    subtitle: "照片回忆",
                    color: .goYellow
                )
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var memberRankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("成员贡献排行", icon: "person.2.fill")
            if rankedMembers.isEmpty {
                emptyText("本周还没有家庭协作记录")
            } else {
                ForEach(Array(rankedMembers.prefix(5).enumerated()), id: \.element.id) { index, stat in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 24, height: 24)
                            .background(index == 0 ? Color.goPrimary : Color.primary.opacity(0.08), in: Circle())
                        Text(stat.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.name).font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("\(stat.count) 次照护 · +\(stat.coconuts)🥥").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var memoryAndHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("成长回忆与健康提醒", icon: "heart.text.square.fill")
            if let memory = weekPhotoMemories.first {
                HStack(spacing: 12) {
                    if let image = UIImage(data: memory.imageData), image.size != .zero {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 58, height: 58)
                            .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(memory.petName) 的本周回忆")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text(memory.note.isEmpty ? memory.date.formatted(.dateTime.weekday().hour().minute()) : memory.note)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            } else {
                emptyText("本周还没有照片回忆，下一次记录照片后会出现在这里")
            }

            if healthAlerts.isEmpty {
                statusLine(icon: "checkmark.seal.fill", text: "本周没有紧急健康提醒", color: .goTeal)
            } else {
                ForEach(healthAlerts.prefix(3)) { alert in
                    statusLine(
                        icon: alert.severity == .urgent ? "exclamationmark.triangle.fill" : "bell.badge.fill",
                        text: "\(alert.petName)：\(alert.title)",
                        color: alert.severity == .urgent ? .goRed : .goOrange
                    )
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var petCoverageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("宠物照护覆盖", icon: "pawprint.fill")
            ForEach(activePets) { pet in
                let count = entries(for: pet, in: weekInterval).count
                HStack {
                    FMPetAvatar(pet: pet, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name).font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(count > 0 ? "本周 \(count) 次记录" : "本周暂无记录").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(count > 0 ? "已照顾" : "待关注")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(count > 0 ? Color.goPrimary : Color.goOrange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((count > 0 ? Color.goPrimary : Color.goOrange).opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近发生了什么", icon: "clock.arrow.circlepath")
            if allEntries.isEmpty {
                emptyText("完成一次快捷打卡后，这里会出现全家动态")
            } else {
                ForEach(allEntries.prefix(8)) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(entry.color)
                            .frame(width: 28, height: 28)
                            .background(entry.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.actorName) · \(entry.title)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("\(entry.petName) · \(entry.date.formatted(.dateTime.weekday().hour().minute()))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var previousWeeksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("近 4 周趋势", icon: "chart.bar.fill")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(lastFourWeeks(), id: \.label) { week in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.goPrimary.opacity(0.75))
                            .frame(height: CGFloat(max(8, min(90, week.count * 8))))
                        Text(week.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func storyPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusLine(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func entries(for pet: Pet, in interval: DateInterval) -> [ReportEntry] {
        let ledgerEntries = CareLedgerStatsService.reportEntries(
            events: ledgerEvents,
            pets: [pet],
            humans: humans,
            interval: interval
        )
        if !ledgerEntries.isEmpty {
            return ledgerEntries
        }
        // Fallback keeps older local data visible before ledger backfill has run.
        var entries: [ReportEntry] = []
        for log in pet.careLogs where interval.contains(log.date) {
            entries.append(entry(date: log.date, actorId: log.executorId, pet: pet, title: log.careType.rawValue, icon: log.careType.systemIconName, color: Color(hex: log.careType.accentColorHex), coconuts: 1))
        }
        for log in pet.pottyLogs where interval.contains(log.date) {
            entries.append(entry(date: log.date, actorId: log.executorId, pet: pet, title: log.pottyType.rawValue, icon: log.pottyType.systemIconName, color: .goOrange, coconuts: 1))
        }
        for log in pet.walkLogs where interval.contains(log.startDate) {
            entries.append(entry(date: log.startDate, actorId: log.executorId, pet: pet, title: "遛狗", icon: "figure.walk", color: .goTeal, coconuts: log.coconutsEarned))
        }
        for log in pet.expenseLogs where interval.contains(log.date) {
            entries.append(entry(date: log.date, actorId: log.executorId, pet: pet, title: log.expenseCategory.rawValue, icon: log.expenseCategory.systemIconName, color: .goYellow, coconuts: 0))
        }
        return entries
    }

    private func entry(date: Date, actorId: String?, pet: Pet, title: String, icon: String, color: Color, coconuts: Int) -> ReportEntry {
        let human = actorId.flatMap { id in humans.first { $0.id.uuidString == id } }
        return ReportEntry(date: date, actorId: actorId, actorName: human?.name ?? "未指定", petName: pet.name, title: title, icon: icon, color: color, coconuts: max(coconuts, 0))
    }

    private func lastFourWeeks() -> [(label: String, count: Int)] {
        (0..<4).map { offset in
            let base = Calendar.current.date(byAdding: .weekOfYear, value: -(3 - offset), to: Date()) ?? Date()
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: base) ?? weekInterval
            let count = activePets.flatMap { entries(for: $0, in: interval) }.count
            return ("W\(offset + 1)", count)
        }
    }
}

private typealias ReportEntry = CareLedgerStatsService.ReportEntry

private struct MemberStat: Identifiable {
    let id: String
    let name: String
    let emoji: String
    var count: Int
    var coconuts: Int
}

private struct ActiveDayStat {
    let date: Date
    let count: Int
}

private struct WeightTrend: Identifiable {
    let id: UUID
    let petName: String
    let latestKg: Double
    let deltaKg: Double
    let days: Int
}

private struct PhotoMemory: Identifiable {
    let id: UUID
    let petName: String
    let imageData: Data
    let note: String
    let date: Date
}
