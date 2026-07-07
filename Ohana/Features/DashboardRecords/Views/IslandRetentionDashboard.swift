//
//  IslandRetentionDashboard.swift
//  Ohana
//
//  Cross-pet archive and memory overview for GO home FAB and feature groups.
//

import SwiftData
import SwiftUI

struct IslandRetentionDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?
    let pets: [Pet]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var careLedgerEvents: [CareLedgerEvent] = []
    @State private var archiveMetricsByPetId: [UUID: PetRetentionArchiveMetrics] = [:]
    @State private var ledgerLoadTask: Task<Void, Never>?
    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var growProgress: CGFloat = 0

    private var screenModel: IslandRetentionDashboardScreenModel {
        IslandRetentionDashboardScreenModel(
            pets: pets,
            selectedPetId: selectedPetId,
            careLedgerEvents: careLedgerEvents,
            archiveMetricsByPetId: archiveMetricsByPetId
        )
    }

    private var activePets: [Pet] { screenModel.activePets }

    private var summaries: [RetentionPetSummary] {
        screenModel.summaries
    }

    private var averageScore: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + Double($1.score) } / Double(summaries.count)
    }

    private var totalMemories: Int {
        summaries.reduce(0) { $0 + $1.photos + $1.milestones }
    }

    private var totalAchievements: (unlocked: Int, total: Int) {
        summaries.reduce((0, 0)) { partial, item in
            (partial.0 + item.unlocked, partial.1 + item.totalAchievements)
        }
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                NavigationStack {
                    PetRetentionHubView(
                        pet: pet,
                        careLedgerEvents: careLedgerEvents,
                        archiveMetrics: screenModel.archiveMetrics(for: pet.id)
                    )
                }
            }
            .onAppear {
                animateGrowth()
                scheduleCareLedgerLoad()
            }
            .onChange(of: selectedPetId) { _, _ in animateGrowth() }
            .onDisappear {
                ledgerLoadTask?.cancel()
                ledgerLoadTask = nil
            }
    }

    private func scheduleCareLedgerLoad(delayMilliseconds: UInt64 = 48, force: Bool = false) {
        guard force || careLedgerEvents.isEmpty || archiveMetricsByPetId.isEmpty else { return }
        guard ledgerLoadTask == nil else { return }
        let petIDs = Set(pets.map(\.id))
        ledgerLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            let routeData = Self.fetchRouteData(petIDs: petIDs, context: modelContext)
            careLedgerEvents = routeData.careLedgerEvents
            archiveMetricsByPetId = routeData.archiveMetricsByPetId
            ledgerLoadTask = nil
        }
    }

    @MainActor
    private static func fetchRouteData(petIDs: Set<UUID>, context: ModelContext) -> IslandRetentionRouteData {
        IslandRetentionRouteData(
            careLedgerEvents: fetchCareLedgerEvents(petIDs: Set(petIDs.map(\.uuidString)), context: context),
            archiveMetricsByPetId: fetchArchiveMetrics(petIDs: petIDs, context: context)
        )
    }

    @MainActor
    private static func fetchArchiveMetrics(petIDs: Set<UUID>, context: ModelContext) -> [UUID: PetRetentionArchiveMetrics] {
        guard !petIDs.isEmpty else { return [:] }
        var archiveMetricsByPetId: [UUID: PetRetentionArchiveMetrics] = [:]
        for petID in petIDs {
            archiveMetricsByPetId[petID] = PetRetentionArchiveMetrics.load(petID: petID, context: context)
        }
        return archiveMetricsByPetId
    }

    private static func fetchCareLedgerEvents(petIDs: Set<String>, context: ModelContext) -> [CareLedgerEvent] {
        guard !petIDs.isEmpty else { return [] }
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubjectKind
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor).filter {
                petIDs.contains($0.subjectId ?? "") && isAchievementLedgerEvent($0)
            }
        } catch {
            OhanaLog.warning(
                "Island retention ledger fetch failed: \(error.localizedDescription)",
                category: "DashboardRecords"
            )
            return []
        }
    }

    private nonisolated static func isAchievementLedgerEvent(_ event: CareLedgerEvent) -> Bool {
        switch event.eventKindEnum {
        case .care, .potty, .walk, .hygiene, .health, .weight, .expense, .medication, .milestone:
            true
        case .workout, .reminder, .plantCare, .coconut, .unknown:
            false
        }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                ZStack {
                    OhanaAppBackground().ignoresSafeArea()
                    scrollContent
                }
                .ignoresSafeArea(edges: .top)
                .navigationBarHidden(true)
            }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if standalone { navBar }
                memberSelector
                treeHero
                memoryCapsules
                archiveRows
                Color.clear.frame(height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, standalone ? 0 : 14)
        }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .goGlassBackground(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text(l.tr(zh: "成长档案", en: "Growth Archive", de: "Wachstumsarchiv"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 64)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "tree.fill", isSelected: selectedPetId == nil) {
                    selectedPetId = nil
                }
                ForEach(activePets) { pet in
                    selectorChip(title: pet.name, avatar: { FMPetAvatar(pet: pet, size: 22) }, isSelected: selectedPetId == pet.id) {
                        selectedPetId = pet.id
                    }
                }
            }
        }
    }

    private var treeHero: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                    .fill(Color.goPrimary.opacity(0.72))
                    .frame(width: 18, height: 64 * growProgress)
                ForEach(0 ..< 5, id: \.self) { index in
                    Circle()
                        .fill(index < Int(averageScore.rounded()) ? Color.goPrimary.opacity(0.82) : Color.white.opacity(0.12)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                        .frame(width: 22 + CGFloat(index) * 9, height: 22 + CGFloat(index) * 9)
                        .offset(x: index.isMultiple(of: 2) ? -22 : 22, y: -CGFloat(index) * 13 * growProgress)
                        .scaleEffect(growProgress)
                }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 7) {
                Text(l.tr(zh: "档案完整度", en: "Archive completeness", de: "Archivvollstaendigkeit"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", averageScore))
                        .font(OhanaFont.adaptive(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    Text("/ 5")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                }
                Text(l.tr(
                    zh: "\(totalMemories) 个记忆点 · \(totalAchievements.unlocked)/\(totalAchievements.total) 枚成就",
                    en: "\(totalMemories) memory points · \(totalAchievements.unlocked)/\(totalAchievements.total) achievements",
                    de: "\(totalMemories) Erinnerungspunkte · \(totalAchievements.unlocked)/\(totalAchievements.total) Erfolge"
                ))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.goPrimary.opacity(0.19), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
    }

    private var memoryCapsules: some View {
        HStack(spacing: 8) {
            archiveMetric(l.tr(zh: "照片", en: "Photos", de: "Fotos"), "\(summaries.reduce(0) { $0 + $1.photos })", "photo.on.rectangle.angled", .goTeal)
            archiveMetric(l.tr(zh: "时刻", en: "Moments", de: "Momente"), "\(summaries.reduce(0) { $0 + $1.milestones })", "sparkles", .goPrimary)
            archiveMetric(l.tr(zh: "证件", en: "Documents", de: "Dokumente"), "\(summaries.reduce(0) { $0 + $1.documents })", "doc.fill", .goOrange)
        }
    }

    private func archiveMetric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
            Text(value)
                .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var archiveRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成员成长档案", en: "Member growth archive", de: "Wachstumsarchiv der Mitglieder"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            ForEach(summaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(summary.pet.name)
                                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                                Spacer()
                                Text("\(summary.score)/5")
                                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.goPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                                    Capsule()
                                        .fill(Color.goPrimary)
                                        .frame(width: geo.size.width * CGFloat(summary.score) / 5 * growProgress)
                                }
                            }
                            .frame(height: 7)
                            Text(l.tr(
                                zh: "\(summary.photos) 张照片 · \(summary.milestones) 个时刻 · \(summary.unlocked)/\(summary.totalAchievements) 成就",
                                en: "\(summary.photos) photos · \(summary.milestones) moments · \(summary.unlocked)/\(summary.totalAchievements) achievements",
                                de: "\(summary.photos) Fotos · \(summary.milestones) Momente · \(summary.unlocked)/\(summary.totalAchievements) Erfolge"
                            ))
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.3)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func selectorChip(title: String, avatar: () -> some View, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goPrimary : Color.white.opacity(0.12), in: Capsule()) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        selectorChip(title: title, avatar: {
            Image(systemName: icon).font(OhanaFont.adaptive(size: 11, weight: .bold))
        }, isSelected: isSelected, action: action)
    }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func animateGrowth() {
        growProgress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            growProgress = 1
        }
    }
}

private struct IslandRetentionRouteData {
    let careLedgerEvents: [CareLedgerEvent]
    let archiveMetricsByPetId: [UUID: PetRetentionArchiveMetrics]
}
