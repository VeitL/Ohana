//
//  FamilyWeeklyReportDashboardView.swift
//  Ohana
//
//  Family-wide weekly report across pets, members, and assigned tasks.
//

import SwiftData
import SwiftUI

struct FamilyWeeklyReportDashboardContentView: View {
    let pets: [Pet]
    let humans: [Human]
    let ledgerEvents: [CareLedgerEvent]
    let photoMemories: [FamilyWeeklyPhotoMemory]
    let healthAlertSources: [PetHealthAlertSource]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var preparedShareText: String?

    private var l: L10n { L10n(appLanguage) }

    private var visibleHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    private var visibleHumanCount: Int {
        visibleHumans.count
    }

    private var isSingleVisibleHumanFamily: Bool {
        SingleMemberFamilyShapePresentation.isSingleVisibleHumanFamily(humanCount: visibleHumanCount)
    }

    private var weekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Date().addingTimeInterval(-6 * 86400), duration: 7 * 86400)
    }

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var allEntries: [ReportEntry] {
        entries(for: activePets, in: weekInterval)
    }

    private var rankedMembers: [MemberStat] {
        var dict: [String: MemberStat] = [:]
        let visibleHumansById = Dictionary(uniqueKeysWithValues: visibleHumans.map { ($0.id.uuidString, $0) })
        for entry in allEntries {
            let id = entry.actorId ?? "unknown"
            guard id == "unknown" || visibleHumansById[id] != nil else { continue }
            let human = visibleHumansById[id]
            let name = human?.name ?? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugewiesen")
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

    private var weekPhotoMemories: [FamilyWeeklyPhotoMemory] {
        photoMemories
    }

    private var weekWeightTrends: [WeightTrend] {
        activePets.compactMap { pet in
            let logs = ledgerEvents
                .filter {
                    $0.subjectKind == CareLedgerSubjectKind.pet.rawValue &&
                        $0.subjectId == pet.id.uuidString &&
                        $0.eventKindEnum == .weight &&
                        $0.occurredAt < weekInterval.end &&
                        $0.amountValue > 0
                }
                .map { WeightSample(date: $0.occurredAt, weight: $0.amountValue) }
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
        PetHealthAlertEngine().scanAlerts(sources: healthAlertSources, localization: l)
    }

    private var storyHeadline: String {
        if allEntries.isEmpty {
            return l.tr(zh: "这周还在等待第一条照护故事", en: "This week is waiting for its first care story", de: "Diese Woche wartet noch auf die erste Pflegegeschichte")
        }
        if let pet = topPet {
            return l.tr(zh: "\(pet.name) 这周被好好照顾了 \(pet.count) 次", en: "\(pet.name) was cared for \(pet.count) times this week", de: "\(pet.name) wurde diese Woche \(pet.count)-mal versorgt")
        }
        return l.tr(zh: "这周的家庭照护已经留下记录", en: "This week's family care has been recorded", de: "Die Familienpflege dieser Woche wurde festgehalten")
    }

    private var storyBody: String {
        guard !allEntries.isEmpty else {
            return l.tr(zh: "完成一次喂食、陪玩、照片或健康记录后，周报会自动整理成可分享的家庭故事。", en: "After a feeding, play, photo, or health record, the weekly report turns it into a shareable family story.", de: "Nach Fütterung, Spielen, Foto oder Gesundheitsnotiz formt der Wochenbericht daraus eine teilbare Familiengeschichte.")
        }
        let leader = rankedMembers.first.map {
            SingleMemberFamilyShapePresentation.weeklyReportLeaderStory(name: $0.name, humanCount: visibleHumanCount, l: l)
        } ?? l.tr(zh: "照护记录已同步", en: "Care records are synced", de: "Pflegeeinträge sind synchronisiert")
        let day = mostActiveDay.map {
            l.tr(zh: "\($0.date.formatted(.dateTime.weekday(.wide))) 最活跃", en: "\($0.date.formatted(.dateTime.weekday(.wide))) was the busiest day", de: "\($0.date.formatted(.dateTime.weekday(.wide))) war am aktivsten")
        } ?? l.tr(zh: "每天都有记录", en: "Every day has a record", de: "Jeder Tag hat einen Eintrag")
        return "\(leader)，\(day)。\(weightStoryText) \(photoStoryText) \(healthStoryText)"
    }

    private var weightStoryText: String {
        guard let trend = weekWeightTrends.max(by: { abs($0.deltaKg) < abs($1.deltaKg) }) else {
            return l.tr(zh: "体重趋势还缺少连续记录。", en: "Weight trends still need more continuous records.", de: "Für Gewichtstrends fehlen noch fortlaufende Einträge.")
        }
        if abs(trend.deltaKg) < 0.05 {
            return l.tr(zh: "\(trend.petName) 体重稳定在 \(String(format: "%.1fkg", trend.latestKg))。", en: "\(trend.petName)'s weight stayed around \(String(format: "%.1fkg", trend.latestKg)).", de: "\(trend.petName)s Gewicht blieb bei etwa \(String(format: "%.1fkg", trend.latestKg)).")
        }
        let sign = trend.deltaKg > 0 ? "+" : ""
        return l.tr(zh: "\(trend.petName) 近 \(trend.days) 天体重 \(sign)\(String(format: "%.1fkg", trend.deltaKg))。", en: "\(trend.petName)'s weight changed \(sign)\(String(format: "%.1fkg", trend.deltaKg)) over \(trend.days) days.", de: "\(trend.petName)s Gewicht änderte sich in \(trend.days) Tagen um \(sign)\(String(format: "%.1fkg", trend.deltaKg)).")
    }

    private var photoStoryText: String {
        guard let memory = weekPhotoMemories.first else {
            return l.tr(zh: "本周还没有照片回忆。", en: "No photo memories yet this week.", de: "Diese Woche gibt es noch keine Fotoerinnerungen.")
        }
        return l.tr(zh: "最新回忆是 \(memory.petName) 的照片。", en: "The latest memory is a photo of \(memory.petName).", de: "Die neueste Erinnerung ist ein Foto von \(memory.petName).")
    }

    private var healthStoryText: String {
        guard let first = healthAlerts.first else {
            return l.tr(zh: "健康提醒正常。", en: "Health reminders look normal.", de: "Gesundheitshinweise sind unauffällig.")
        }
        let urgentCount = healthAlerts.count(where: { $0.severity == .urgent })
        if urgentCount > 0 {
            return l.tr(zh: "\(urgentCount) 项紧急健康提醒：\(first.title)。", en: "\(urgentCount) urgent health reminders: \(first.title).", de: "\(urgentCount) dringende Gesundheitshinweise: \(first.title).")
        }
        return l.tr(zh: "\(healthAlerts.count) 项健康提醒待留意：\(first.title)。", en: "\(healthAlerts.count) health reminders need attention: \(first.title).", de: "\(healthAlerts.count) Gesundheitshinweise beachten: \(first.title).")
    }

    private var shareText: String {
        let leader = rankedMembers.first.map {
            l.tr(zh: "\($0.emoji) \($0.name) \($0.count) 次", en: "\($0.emoji) \($0.name) \($0.count) times", de: "\($0.emoji) \($0.name) \($0.count)-mal")
        } ?? l.tr(zh: "暂无", en: "None yet", de: "Noch nichts")
        let petLine = topPet.map {
            l.tr(zh: "\($0.name) 被照顾 \($0.count) 次", en: "\($0.name) was cared for \($0.count) times", de: "\($0.name) wurde \($0.count)-mal versorgt")
        } ?? l.tr(zh: "暂无宠物记录", en: "No pet records yet", de: "Noch keine Tiereinträge")
        let leaderLabel = SingleMemberFamilyShapePresentation.weeklyReportShareLeaderLabel(humanCount: visibleHumanCount, l: l)
        return l.tr(
            zh: "Ohana 本周家庭周报\n\(storyHeadline)\n\(storyBody)\n总照护 \(allEntries.count) 次\n\(leaderLabel)：\(leader)\n最受关注：\(petLine)",
            en: "Ohana family weekly report\n\(storyHeadline)\n\(storyBody)\nTotal care: \(allEntries.count)\n\(leaderLabel): \(leader)\nMost cared for: \(petLine)",
            de: "Ohana Familien-Wochenbericht\n\(storyHeadline)\n\(storyBody)\nPflege gesamt: \(allEntries.count)\n\(leaderLabel): \(leader)\nAm meisten versorgt: \(petLine)"
        )
    }

    private var sharePreparationSignature: String {
        [
            "\(weekInterval.start.timeIntervalSince1970)",
            "\(weekInterval.end.timeIntervalSince1970)",
            "\(allEntries.count)",
            rankedMembers.first.map { "\($0.id):\($0.count):\($0.coconuts)" } ?? "none",
            topPet.map { "\($0.name):\($0.count)" } ?? "none",
            healthAlerts.first.map { "\($0.title):\($0.severity.rawValue)" } ?? "none",
            "\(weekPhotoMemories.count)",
            appLanguage
        ].joined(separator: "|")
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
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
        .navigationTitle(l.tr(zh: "家庭周报", en: "Family report", de: "Familienbericht"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sharePreparationSignature) {
            await prepareShareText()
        }
        .accessibilityIdentifier("family-weekly-report-screen")
    }

    @MainActor
    private func prepareShareText() async {
        preparedShareText = nil
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        preparedShareText = shareText
    }

    private var shareButtonLabel: some View {
        Label(l.tr(zh: "分享", en: "Share", de: "Teilen"), systemImage: "square.and.arrow.up")
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.goPrimary, in: Capsule())
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "本周 Ohana", en: "This week in Ohana", de: "Diese Woche in Ohana"))
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("\(weekInterval.start.formatted(.dateTime.month().day())) - \(weekInterval.end.formatted(.dateTime.month().day()))")
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if let preparedShareText {
                    ShareLink(item: preparedShareText) { // smoothness: allow prepared export payload built after visual handoff
                        shareButtonLabel
                    }
                } else {
                    Button {} label: {
                        shareButtonLabel
                    }
                    .disabled(true)
                    .accessibilityLabel(l.tr(zh: "周报分享内容准备中", en: "Weekly report share text is being prepared", de: "Wochenbericht wird zum Teilen vorbereitet"))
                }
            }

            HStack(spacing: 10) {
                metric(l.tr(zh: "照护", en: "Care", de: "Pflege"), "\(allEntries.count)", .goPrimary)
                metric(l.tr(zh: "成员", en: "Members", de: "Mitglieder"), "\(rankedMembers.count(where: { $0.id != "unknown" }))", .goTeal)
                metric(l.tr(zh: "椰子", en: "Coconuts", de: "Kokosnüsse"), "\(allEntries.reduce(0) { $0 + $1.coconuts })", .goYellow)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-header-card")
    }

    private var weeklyStoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(l.tr(zh: "本周故事", en: "Weekly story", de: "Wochengeschichte"), icon: "sparkles.rectangle.stack.fill")
            VStack(alignment: .leading, spacing: 6) {
                Text(storyHeadline)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(storyBody)
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                storyPill(
                    icon: isSingleVisibleHumanFamily ? "person.fill.checkmark" : "crown.fill",
                    title: rankedMembers.first?.name ?? l.tr(zh: "暂无", en: "None yet", de: "Noch nichts"),
                    subtitle: SingleMemberFamilyShapePresentation.weeklyReportLeaderPillSubtitle(
                        humanCount: visibleHumanCount,
                        l: l
                    ),
                    color: .goPrimary
                )
                storyPill(
                    icon: "calendar.badge.clock",
                    title: mostActiveDay.map { $0.date.formatted(.dateTime.weekday(.abbreviated)) } ?? l.tr(zh: "暂无", en: "None yet", de: "Noch nichts"),
                    subtitle: l.tr(zh: "最活跃日", en: "Busiest day", de: "Aktivster Tag"),
                    color: .goTeal
                )
                storyPill(
                    icon: "photo.fill",
                    title: "\(weekPhotoMemories.count)",
                    subtitle: l.tr(zh: "照片回忆", en: "Photo memories", de: "Fotoerinnerungen"),
                    color: .goYellow
                )
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-story-card")
    }

    private var memberRankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                SingleMemberFamilyShapePresentation.weeklyReportContributionSectionTitle(
                    humanCount: visibleHumanCount,
                    l: l
                ),
                icon: isSingleVisibleHumanFamily ? "person.fill.checkmark" : "person.2.fill"
            )
            if rankedMembers.isEmpty {
                emptyText(l.tr(zh: "本周还没有照护记录", en: "No care records yet this week", de: "Diese Woche noch keine Pflegeeinträge"))
                    .accessibilityIdentifier("family-weekly-report-member-contribution-empty")
            } else {
                ForEach(Array(rankedMembers.prefix(5).enumerated()), id: \.element.id) { index, stat in
                    HStack(spacing: 10) {
                        memberContributionBadge(index: index)
                        Text(stat.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.name).font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text(l.tr(zh: "\(stat.count) 次照护 · +\(stat.coconuts)🥥", en: "\(stat.count) care actions · +\(stat.coconuts)🥥", de: "\(stat.count) Pflegeaktionen · +\(stat.coconuts)🥥")).font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        }
                        Spacer()
                    }
                    .accessibilityIdentifier("family-weekly-report-member-contribution-row-\(stat.id)")
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-member-contribution-card")
    }

    private var memoryAndHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "成长回忆与健康提醒", en: "Memories and health reminders", de: "Erinnerungen und Gesundheit"), icon: "heart.text.square.fill")
            if let memory = weekPhotoMemories.first {
                HStack(spacing: 12) {
                    AsyncDecodedImageView(
                        cacheID: "family-weekly-photo-memory-\(memory.id.uuidString)",
                        sourceSignature: memory.imageSignature,
                        maxPixel: 160,
                        asyncDataProvider: {
                            await imageData(for: memory)
                        }
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    } placeholder: {
                        Image(systemName: "photo.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 20, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 58, height: 58)
                            .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "\(memory.petName) 的本周回忆", en: "\(memory.petName)'s weekly memory", de: "\(memory.petName)s Wochenerinnerung"))
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(memory.note.isEmpty ? memory.date.formatted(.dateTime.weekday().hour().minute()) : memory.note)
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            } else {
                emptyText(l.tr(zh: "本周还没有照片回忆，下一次记录照片后会出现在这里", en: "No photo memories this week. The next photo record will appear here.", de: "Diese Woche noch keine Fotoerinnerungen. Das nächste Foto erscheint hier."))
            }

            if healthAlerts.isEmpty {
                statusLine(icon: "checkmark.seal.fill", text: l.tr(zh: "本周没有紧急健康提醒", en: "No urgent health reminders this week", de: "Diese Woche keine dringenden Gesundheitshinweise"), color: .goTeal)
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
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-memory-health-card")
    }

    private func imageData(for memory: FamilyWeeklyPhotoMemory) async -> Data? {
        guard memory.canAttemptImageAttachmentLoad else {
            return nil
        }
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        return await loader.petPhotoLogImageData(modelID: memory.modelID)
    }

    private var petCoverageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "宠物照护覆盖", en: "Pet care coverage", de: "Pflegeabdeckung"), icon: "pawprint.fill")
            ForEach(activePets) { pet in
                let count = entries(for: [pet], in: weekInterval).count
                HStack {
                    FMPetAvatar(pet: pet, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name).font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(count > 0 ? l.tr(zh: "本周 \(count) 次记录", en: "\(count) records this week", de: "\(count) Einträge diese Woche") : l.tr(zh: "本周暂无记录", en: "No records this week", de: "Diese Woche keine Einträge")).font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                    Spacer()
                    Text(count > 0 ? l.tr(zh: "已照顾", en: "Covered", de: "Versorgt") : l.tr(zh: "待关注", en: "Needs attention", de: "Braucht Aufmerksamkeit"))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(count > 0 ? Color.goPrimary : Color.goOrange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((count > 0 ? Color.goPrimary : Color.goOrange).opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-pet-coverage-card")
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "最近发生了什么", en: "Recent activity", de: "Zuletzt passiert"), icon: "clock.arrow.circlepath")
            if allEntries.isEmpty {
                emptyText(SingleMemberFamilyShapePresentation.weeklyReportRecentActivityEmptyText(
                    humanCount: visibleHumanCount,
                    l: l
                ))
                .accessibilityIdentifier("family-weekly-report-recent-activity-empty")
            } else {
                ForEach(allEntries.prefix(8)) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.icon)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(entry.color)
                            .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(entry.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.actorName) · \(entry.title)")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text("\(entry.petName) · \(entry.date.formatted(.dateTime.weekday().hour().minute()))")
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                    }
                    .accessibilityIdentifier("family-weekly-report-recent-activity-row-\(entry.id.uuidString)")
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-recent-activity-card")
    }

    private var previousWeeksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "近 4 周趋势", en: "Last 4 weeks", de: "Letzte 4 Wochen"), icon: "chart.bar.fill")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(lastFourWeeks(), id: \.label) { week in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: OhanaRadius.tiny)
                            .fill(Color.goPrimary.opacity(0.75))
                            .frame(height: CGFloat(max(8, min(90, week.count * 8))))
                        Text(week.label)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("family-weekly-report-previous-weeks-card")
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)).foregroundStyle(color) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(label).font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Spacer()
        }
    }

    @ViewBuilder
    private func memberContributionBadge(index: Int) -> some View {
        if isSingleVisibleHumanFamily {
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative contribution badge; row text carries the accessible meaning
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary, in: Circle())
        } else {
            Text("\(index + 1)")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.arkInk)
                .frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(index == 0 ? Color.goPrimary : Color.primary.opacity(0.08), in: Circle())
        }
    }

    private func storyPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(color)
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func statusLine(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func entries(for pets: [Pet], in interval: DateInterval) -> [ReportEntry] {
        appServices.careLedgerStats.reportEntries(
            events: ledgerEvents,
            pets: pets,
            humans: humans,
            interval: interval
        )
    }

    private func lastFourWeeks() -> [(label: String, count: Int)] {
        (0 ..< 4).map { offset in
            let base = Calendar.current.date(byAdding: .weekOfYear, value: -(3 - offset), to: Date()) ?? Date()
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: base) ?? weekInterval
            let count = entries(for: activePets, in: interval).count
            return ("W\(offset + 1)", count)
        }
    }
}

private typealias ReportEntry = CareLedgerReportEntry

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

private struct WeightSample {
    let date: Date
    let weight: Double
}

struct FamilyWeeklyPhotoMemory: Identifiable, Equatable {
    let id: UUID
    let modelID: PersistentIdentifier
    let petName: String
    let imageSignature: String
    let canAttemptImageAttachmentLoad: Bool
    let note: String
    let date: Date
}
