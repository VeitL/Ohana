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

    private var shareText: String {
        let leader = rankedMembers.first.map { "\($0.emoji) \($0.name) \($0.count) 次" } ?? "暂无"
        let petLine = topPet.map { "\($0.name) 被照顾 \($0.count) 次" } ?? "暂无宠物记录"
        return "Ohana 本周家庭周报\n总照护 \(allEntries.count) 次\n本周之星：\(leader)\n最受关注：\(petLine)"
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    memberRankingCard
                    petCoverageCard
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
