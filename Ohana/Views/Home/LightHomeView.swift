//
//  LightHomeView.swift
//  Ohana
//
//  A rebuilt home surface optimized for fast first-frame interaction.
//

import SwiftUI

struct LightHomeReminderTitleSnapshot: Equatable {
    var titlesByReminderID: [UUID: String] = [:]

    static let empty = LightHomeReminderTitleSnapshot()

    var signature: String {
        titlesByReminderID
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { "\($0.key.uuidString):\($0.value)" }
            .joined(separator: "|")
    }

    func title(for reminderID: UUID, fallback: String) -> String {
        let title = titlesByReminderID[reminderID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? fallback : title
    }

    static func build(from pendingReminders: [Reminder], language: String) -> LightHomeReminderTitleSnapshot {
        let fallbackTitle = L10n(language).tr(zh: "待办", en: "Task", de: "Aufgabe")
        let titles = Dictionary(
            uniqueKeysWithValues: pendingReminders
                .sorted { $0.scheduledAt < $1.scheduledAt }
                .prefix(8)
                .map { reminder in
                    let rawTitle = reminder.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return (reminder.id, rawTitle.isEmpty ? fallbackTitle : rawTitle)
                }
        )
        return LightHomeReminderTitleSnapshot(titlesByReminderID: titles)
    }
}

struct LightHomeView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let pendingReminders: [Reminder]
    let reminderTitleSnapshot: LightHomeReminderTitleSnapshot

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @StateObject private var tabState = VerticalHomeTabVisualState()
    @State private var activeAddEntityType: EntityType?
    @State private var quickRoute: LightHomeQuickRoute?
    @State private var showingSettings = false
    @State private var showingCrewRoster = false
    @State private var calendarAddEventTrigger = 0
    @State private var oasisInjectEnergyTrigger = 0
    @State private var homeSnapshot = LightHomeSnapshot.empty
    @State private var snapshotSignature = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }

    private var renderSnapshot: LightHomeSnapshot {
        homeSnapshot.isReady ? homeSnapshot : buildSnapshot()
    }

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = max(geo.safeAreaInsets.top, 12)
            let safeBottom = max(geo.safeAreaInsets.bottom, 8)
            let headerHeight = safeTop + 64
            let bottomBarHeight = safeBottom + 84
            let contentHeight = max(320, geo.size.height - headerHeight - bottomBarHeight)
            let snapshot = renderSnapshot

            ZStack(alignment: .top) {
                OhanaAppBackground()

                VerticalHomePagedContent(tabState: tabState) { lifecycle in
                    LightHomeDashboardPage(
                        snapshot: snapshot,
                        isVisible: lifecycle.isVisible || lifecycle.isPreparingForDisplay,
                        onOpenMember: openMember,
                        onOpenQuickAction: openQuickAction,
                        onAddMember: { activeAddEntityType = humans.isEmpty ? .human : .pet },
                        onOpenCrew: { showingCrewRoster = true }
                    )
                } calendar: { lifecycle in
                    CalendarView(
                        hideToolbar: true,
                        showsEmbeddedControls: true,
                        addEventTrigger: calendarAddEventTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isPreparingForDisplay || lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                } oasis: { lifecycle in
                    OasisRewardView(
                        hideToolbar: true,
                        injectEnergyTrigger: oasisInjectEnergyTrigger,
                        isEmbeddedPrepared: lifecycle.isPrepared,
                        isEmbeddedVisible: lifecycle.isPreparingForDisplay || lifecycle.isVisible,
                        isEmbeddedActive: lifecycle.isLive
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                } plants: { _ in
                    LightHomePlantsPage(
                        plants: snapshot.plants,
                        onOpenPlant: openPlant,
                        onAddPlant: { activeAddEntityType = .plant }
                    )
                    .padding(.horizontal, 14)
                }
                .frame(width: geo.size.width, height: contentHeight)
                .position(x: geo.size.width / 2, y: headerHeight + contentHeight / 2)

                LightHomeHeader(
                    title: "Ohana",
                    subtitle: snapshot.headerSubtitle,
                    coconutText: snapshot.coconutText,
                    onCrew: { showingCrewRoster = true },
                    onSettings: { showingSettings = true }
                )
                .padding(.top, safeTop)
                .padding(.horizontal, 16)
                .zIndex(10)

                LightHomeTabBar(
                    selectedTab: tabState.selectedTab,
                    safeBottom: safeBottom,
                    canAnimate: canAnimate,
                    onSelect: selectTab,
                    onCenter: centerAction
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(9)
            }
        }
        .task(id: dataSignature) {
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            refreshSnapshotIfNeeded()
        }
        .onAppear {
            refreshSnapshotIfNeeded(force: !homeSnapshot.isReady)
        }
        .sheet(item: $activeAddEntityType) { type in
            AddEntityDestinationView(
                type: type,
                onComplete: { activeAddEntityType = nil },
                onPetSaved: { selectedPet = $0 },
                onHumanSaved: { human in
                    activeHumanIdStr = human.id.uuidString
                    selectedHuman = human
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow role creation flow as long sheet
        }
        .sheet(item: $quickRoute) { route in
            quickRouteDestination(route)
        }
        .sheet(isPresented: $showingCrewRoster) {
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet: { pet in
                        showingCrewRoster = false
                        selectedPet = pet
                    },
                    onSelectHuman: { human in
                        showingCrewRoster = false
                        selectedHuman = human
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCrewRoster = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow member hub as long sheet
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var dataSignature: String {
        [
            pets.map { "\($0.id.uuidString):\($0.name):\($0.species):\($0.avatarEmoji):\($0.safeThemeColorHex):\($0.coconutBalance):\($0.currentStreak):\($0.hasPassedAway)" }.joined(separator: "|"),
            humans.map { "\($0.id.uuidString):\($0.name):\($0.avatarEmoji):\($0.safeThemeColorHex):\($0.coconutBalance):\($0.shouldShowOnHome)" }.joined(separator: "|"),
            plants.map { "\($0.id.uuidString):\($0.name):\($0.avatarEmoji):\($0.themeColorHex):\($0.needsWatering):\($0.needsFertilizing)" }.joined(separator: "|"),
            pendingReminders.prefix(8).map { "\($0.id.uuidString):\(Int($0.scheduledAt.timeIntervalSince1970)):\($0.status)" }.joined(separator: "|"),
            reminderTitleSnapshot.signature,
            appLanguage,
            hiddenHomePetIDsRaw,
            activeHumanIdStr
        ].joined(separator: "#")
    }

    private func buildSnapshot() -> LightHomeSnapshot {
        LightHomeSnapshot.build(
            pets: pets,
            humans: humans,
            plants: plants,
            pendingReminders: pendingReminders,
            reminderTitleSnapshot: reminderTitleSnapshot,
            activeHumanId: UUID(uuidString: activeHumanIdStr),
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            language: appLanguage
        )
    }

    private func refreshSnapshotIfNeeded(force: Bool = false) {
        let signature = dataSignature
        guard force || signature != snapshotSignature else { return }
        let next = buildSnapshot()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            homeSnapshot = next
            snapshotSignature = signature
        }
    }

    private func selectTab(_ tab: VerticalHomeTab) {
        guard tabState.selectedTab != tab else { return }
        OhanaFeedback.light()
        tabState.select(tab)
    }

    private func centerAction() {
        switch tabState.selectedTab {
        case .home:
            activeAddEntityType = humans.isEmpty ? .human : .pet
        case .calendar:
            calendarAddEventTrigger += 1
        case .oasis:
            oasisInjectEnergyTrigger += 1
        case .plants:
            activeAddEntityType = .plant
        }
    }

    private func openMember(_ member: LightHomeMemberSnapshot) {
        switch member.kind {
        case .pet:
            selectedPetTab = .overview
            selectedPet = pets.first { $0.id == member.id }
        case .human:
            selectedHuman = humans.first { $0.id == member.id }
        }
    }

    private func openPlant(_ plant: LightHomePlantSnapshot) {
        selectedPlant = plants.first { $0.id == plant.id }
    }

    private func openQuickAction(_ action: LightHomeQuickAction) {
        guard let pet = primaryPet else {
            activeAddEntityType = .pet
            return
        }
        switch action {
        case .feed:
            quickRoute = .feed(pet.id)
        case .water:
            quickRoute = .water(pet.id)
        case .potty:
            quickRoute = .potty(pet.id)
        case .play:
            quickRoute = .play(pet.id)
        }
    }

    private var primaryPet: Pet? {
        pets
            .filter { !$0.hasPassedAway && HomeCardVisibility.isPetVisible($0, raw: hiddenHomePetIDsRaw) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    @ViewBuilder
    private func quickRouteDestination(_ route: LightHomeQuickRoute) -> some View {
        switch route {
        case let .feed(id):
            if let pet = pet(id) {
                QuickFeedDetailSheet(
                    pet: pet,
                    onRemove: { quickRoute = nil },
                    showsRemoveQuickActionFooter: false,
                    opensManualSheetOnAppear: true
                )
                .ohanaSheetPagePresentation() // ui-v4: allow feeding as long sheet
            } else {
                LightHomeMissingRouteView { quickRoute = nil }
            }
        case let .water(id):
            if let pet = pet(id) {
                QuickWaterDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow water as long sheet
            } else {
                LightHomeMissingRouteView { quickRoute = nil }
            }
        case let .potty(id):
            if let pet = pet(id) {
                QuickPottyDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow potty as long sheet
            } else {
                LightHomeMissingRouteView { quickRoute = nil }
            }
        case let .play(id):
            if let pet = pet(id) {
                QuickPlayDetailSheet(pet: pet) { quickRoute = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow play as long sheet
            } else {
                LightHomeMissingRouteView { quickRoute = nil }
            }
        }
    }

    private func pet(_ id: UUID) -> Pet? {
        pets.first { $0.id == id }
    }
}

private enum LightHomeQuickRoute: Identifiable {
    case feed(UUID)
    case water(UUID)
    case potty(UUID)
    case play(UUID)

    var id: String {
        switch self {
        case let .feed(id): return "feed-\(id.uuidString)"
        case let .water(id): return "water-\(id.uuidString)"
        case let .potty(id): return "potty-\(id.uuidString)"
        case let .play(id): return "play-\(id.uuidString)"
        }
    }
}

private enum LightHomeMemberKind {
    case pet
    case human
}

private struct LightHomeMemberSnapshot: Identifiable {
    let id: UUID
    let kind: LightHomeMemberKind
    let name: String
    let subtitle: String
    let emoji: String
    let colorHex: String
    let metric: String
    let badge: String?
    let isWarning: Bool
}

private struct LightHomePlantSnapshot: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let emoji: String
    let colorHex: String
    let needsCare: Bool
}

private struct LightHomeReminderSnapshot: Identifiable {
    let id: UUID
    let title: String
    let timeText: String
    let isFailed: Bool
}

private struct LightHomeSnapshot {
    var isReady = false
    var members: [LightHomeMemberSnapshot] = []
    var plants: [LightHomePlantSnapshot] = []
    var reminders: [LightHomeReminderSnapshot] = []
    var activeHumanName = ""
    var pendingCount = 0
    var warningCount = 0
    var coconutTotal = 0

    static let empty = LightHomeSnapshot()

    var headerSubtitle: String {
        activeHumanName.isEmpty ? "Ready" : activeHumanName
    }

    var coconutText: String {
        "\(coconutTotal)"
    }

    static func build(
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        pendingReminders: [Reminder],
        reminderTitleSnapshot: LightHomeReminderTitleSnapshot,
        activeHumanId: UUID?,
        hiddenPetIDsRaw: String,
        language: String
    ) -> LightHomeSnapshot {
        let l = L10n(language)
        let visiblePets = pets
            .filter { !$0.hasPassedAway && HomeCardVisibility.isPetVisible($0, raw: hiddenPetIDsRaw) }
            .sorted { $0.createdAt > $1.createdAt }
        let visibleHumans = humans
            .filter(\.shouldShowOnHome)
            .sorted { $0.createdAt > $1.createdAt }
        let memberSnapshots = visiblePets.map { pet in
            LightHomeMemberSnapshot(
                id: pet.id,
                kind: .pet,
                name: pet.name.isEmpty ? l.tr(zh: "未命名", en: "Unnamed", de: "Unbenannt") : pet.name,
                subtitle: pet.species.isEmpty ? l.tr(zh: "伙伴", en: "Companion", de: "Gefährte") : pet.species,
                emoji: pet.avatarEmoji.isEmpty ? "pawprint.fill" : pet.avatarEmoji,
                colorHex: pet.safeThemeColorHex,
                metric: "\(pet.coconutBalance)",
                badge: pet.currentStreak > 0 ? "\(pet.currentStreak)d" : nil,
                isWarning: false
            )
        } + visibleHumans.map { human in
            LightHomeMemberSnapshot(
                id: human.id,
                kind: .human,
                name: human.name.isEmpty ? l.tr(zh: "家人", en: "Family", de: "Familie") : human.name,
                subtitle: l.tr(zh: "成员", en: "Member", de: "Mitglied"),
                emoji: human.avatarEmoji.isEmpty ? "person.fill" : human.avatarEmoji,
                colorHex: human.safeThemeColorHex,
                metric: "\(human.coconutBalance)",
                badge: activeHumanId == human.id ? l.tr(zh: "当前", en: "Active", de: "Aktiv") : nil,
                isWarning: false
            )
        }

        let reminderSnapshots = pendingReminders
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .prefix(4)
            .map { reminder in
                let fallbackTitle = l.tr(zh: "待办", en: "Task", de: "Aufgabe")
                return LightHomeReminderSnapshot(
                    id: reminder.id,
                    title: reminderTitleSnapshot.title(for: reminder.id, fallback: fallbackTitle),
                    timeText: Self.timeText(for: reminder.scheduledAt),
                    isFailed: reminder.isFailed
                )
            }

        let plantSnapshots = plants
            .sorted { $0.createdAt > $1.createdAt }
            .map { plant in
                let needsCare = plant.needsWatering || plant.needsFertilizing
                return LightHomePlantSnapshot(
                    id: plant.id,
                    name: plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name,
                    subtitle: plant.species.isEmpty ? plant.location : plant.species,
                    emoji: plant.avatarEmoji.isEmpty ? "leaf.fill" : plant.avatarEmoji,
                    colorHex: plant.themeColorHex,
                    needsCare: needsCare
                )
            }

        let activeHuman = activeHumanId.flatMap { id in humans.first { $0.id == id } } ?? humans.first
        return LightHomeSnapshot(
            isReady: true,
            members: Array(memberSnapshots.prefix(HomeCardVisibility.maxVisibleCards)),
            plants: plantSnapshots,
            reminders: Array(reminderSnapshots),
            activeHumanName: activeHuman?.name ?? "",
            pendingCount: pendingReminders.count,
            warningCount: pendingReminders.filter(\.isFailed).count,
            coconutTotal: pets.reduce(0) { $0 + $1.coconutBalance } + humans.reduce(0) { $0 + $1.coconutBalance }
        )
    }

    private static func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        return formatter.string(from: date)
    }
}

private struct LightHomeDashboardPage: View {
    let snapshot: LightHomeSnapshot
    let isVisible: Bool
    let onOpenMember: (LightHomeMemberSnapshot) -> Void
    let onOpenQuickAction: (LightHomeQuickAction) -> Void
    let onAddMember: () -> Void
    let onOpenCrew: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }
    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: isVisible)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                focusBand
                quickActionGrid
                membersSection
                remindersSection
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: snapshot.pendingCount)
    }

    private var focusBand: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.tr(zh: "Today Focus", en: "Today Focus", de: "Today Focus"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(focusTitle)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(focusSubtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                Text("\(snapshot.pendingCount)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(snapshot.warningCount > 0 ? Color.goOrange : Color.goPrimary)
                    .contentTransition(.numericText())
                Text(l.tr(zh: "待办", en: "tasks", de: "Aufgaben"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(width: 74, height: 74)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var focusTitle: String {
        if let first = snapshot.reminders.first {
            return first.title
        }
        return l.tr(zh: "今天很清爽", en: "Clear today", de: "Heute ist frei")
    }

    private var focusSubtitle: String {
        if let first = snapshot.reminders.first {
            return first.timeText
        }
        return l.tr(zh: "没有迫近事项", en: "No urgent items", de: "Keine dringenden Punkte")
    }

    private var quickActionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: l.tr(zh: "快捷操作", en: "Quick Actions", de: "Schnellaktionen"),
                actionTitle: nil,
                action: nil
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(LightHomeQuickAction.allCases) { action in
                    Button {
                        OhanaFeedback.light()
                        onOpenQuickAction(action)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: action.icon)
                                .font(.system(size: 21, weight: .black))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(action.tint)
                                .frame(width: 44, height: 44)
                                .background(action.tint.opacity(0.12), in: Circle())
                            Text(action.title(l))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: l.tr(zh: "成员", en: "Crew", de: "Crew"),
                actionTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
                action: onOpenCrew
            )

            if snapshot.members.isEmpty {
                Button(action: onAddMember) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                        Text(l.tr(zh: "添加第一个成员", en: "Add first member", de: "Erstes Mitglied hinzufügen"))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.members) { member in
                            LightHomeMemberTile(member: member) {
                                onOpenMember(member)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: l.tr(zh: "接下来", en: "Next", de: "Als Nächstes"),
                actionTitle: nil,
                action: nil
            )

            if snapshot.reminders.isEmpty {
                LightHomeEmptyLine(
                    icon: "checkmark.seal.fill",
                    title: l.tr(zh: "没有待办", en: "Nothing pending", de: "Nichts offen")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.reminders) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isFailed ? "exclamationmark.circle.fill" : "clock.fill")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(item.isFailed ? Color.goOrange : Color.goPrimary)
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(item.timeText)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

private enum LightHomeQuickAction: CaseIterable, Identifiable {
    case feed
    case water
    case potty
    case play

    var id: String { String(describing: self) }

    var icon: String {
        switch self {
        case .feed: return "fork.knife"
        case .water: return "drop.fill"
        case .potty: return "tray.full.fill"
        case .play: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .feed: return Color.goOrange
        case .water: return Color.goTeal
        case .potty: return Color.goBlue
        case .play: return Color.goPrimary
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .feed: return l.tr(zh: "喂食", en: "Feed", de: "Füttern")
        case .water: return l.tr(zh: "饮水", en: "Water", de: "Wasser")
        case .potty: return l.tr(zh: "便便", en: "Potty", de: "Toilette")
        case .play: return l.tr(zh: "玩耍", en: "Play", de: "Spiel")
        }
    }
}

private struct LightHomeMemberTile: View {
    let member: LightHomeMemberSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LightHomeAvatar(emoji: member.emoji, color: Color(hex: member.colorHex), size: 46)
                    Spacer()
                    Text(member.metric)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(member.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                if let badge = member.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(member.isWarning ? Color.goOrange : Color.goPrimary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(width: 144, height: 142, alignment: .topLeading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct LightHomePlantsPage: View {
    let plants: [LightHomePlantSnapshot]
    let onOpenPlant: (LightHomePlantSnapshot) -> Void
    let onAddPlant: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if plants.isEmpty {
                    LightHomeEmptyState(
                        icon: "leaf.fill",
                        title: l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"),
                        actionTitle: l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"),
                        action: onAddPlant
                    )
                    .padding(.top, 80)
                } else {
                    ForEach(plants) { plant in
                        Button {
                            onOpenPlant(plant)
                        } label: {
                            HStack(spacing: 12) {
                                LightHomeAvatar(emoji: plant.emoji, color: Color(hex: plant.colorHex), size: 46)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plant.name)
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                    Text(plant.subtitle.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.subtitle)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if plant.needsCare {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(Color.goTeal)
                                }
                            }
                            .padding(14)
                            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                Spacer(minLength: 18)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

private struct LightHomeHeader: View {
    let title: String
    let subtitle: String
    let coconutText: String
    let onCrew: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(coconutText)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(Color.ohanaCardSurface, in: Capsule())

            LightHomeIconButton(icon: "person.2.fill", action: onCrew)
            LightHomeIconButton(icon: "gearshape.fill", action: onSettings)
        }
        .frame(height: 52)
    }
}

private struct LightHomeTabBar: View {
    let selectedTab: VerticalHomeTab
    let safeBottom: CGFloat
    let canAnimate: Bool
    let onSelect: (VerticalHomeTab) -> Void
    let onCenter: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.calendar)
                Spacer(minLength: 72)
                tabButton(.oasis)
                tabButton(.plants)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, safeBottom + 8)

            Button {
                OhanaFeedback.medium()
                onCenter()
            } label: {
                Image(systemName: centerIcon)
                    .font(.system(size: 24, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 64, height: 64)
                    .background(Color.goPrimary, in: Circle())
                    .shadow(color: Color.goPrimary.opacity(0.26), radius: 16, x: 0, y: 8) // ui-v4: allow elevated primary nav action
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, safeBottom + 26)
        }
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: selectedTab)
    }

    private var centerIcon: String {
        switch selectedTab {
        case .home: return "plus"
        case .calendar: return "calendar.badge.plus"
        case .oasis: return "bolt.fill"
        case .plants: return "leaf.fill"
        }
    }

    private func tabButton(_ tab: VerticalHomeTab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .black))
                    .symbolRenderingMode(.monochrome)
                Text(tab.title(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selectedTab == tab ? Color.goPrimary : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct LightHomeAvatar: View {
    let emoji: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
            if emoji.contains(".") || emoji.contains("fill") {
                Image(systemName: emoji)
                    .font(.system(size: size * 0.42, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.46))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct LightHomeIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct LightHomeEmptyLine: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LightHomeEmptyState: View {
    let icon: String
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct LightHomeMissingRouteView: View {
    let onClose: () -> Void
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Color.goOrange)
            Text(l.tr(zh: "对象已不存在", en: "Item no longer exists", de: "Element existiert nicht mehr"))
                .font(.system(size: 17, weight: .black, design: .rounded))
            Button(action: onClose) {
                Text(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground())
    }
}
