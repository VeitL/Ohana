//
//  FocusHomeAuxiliaryViews.swift
//  Ohana
//
//  Small rendering-only helpers used by the home flow.
//

import SwiftData
import SwiftUI

struct ExpandedQuickMenuOption: Identifiable {
    let id: String
    let icon: String
    let title: String
    let tint: Color
}

struct TodayFocusSnapshot {
    let pets: [Pet]
    let plants: [Plant]
    let humans: [Human]
    let refreshedQuests: [IslandQuest]
    let assignedFamilyTasks: [FamilyCollaborationTask]
    let pendingExchangeRequests: [CoconutExchangeRequest]
    let negativeSignals: [IslandNegativeSignal]

    static let empty = TodayFocusSnapshot(
        pets: [],
        plants: [],
        humans: [],
        refreshedQuests: [],
        assignedFamilyTasks: [],
        pendingExchangeRequests: [],
        negativeSignals: []
    )

    static func make(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        events: [Event],
        humans: [Human],
        activeHumanId: String,
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest]
    ) -> TodayFocusSnapshot {
        let quests = IslandQuestEngine.todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans
        )
        let refreshedQuests = TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs
        )
        let assignedTasks: [FamilyCollaborationTask]
        if activeHumanId.isEmpty {
            assignedTasks = []
        } else {
            assignedTasks = familyTasks
                .filter {
                    !$0.isFinished &&
                    (($0.status == .pendingReview && $0.createdById == activeHumanId) ||
                     ($0.status != .pendingReview && ($0.assignedToId == activeHumanId || $0.claimedById == activeHumanId)))
                }
                .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
        }
        let pendingExchanges: [CoconutExchangeRequest]
        if activeHumanId.isEmpty {
            pendingExchanges = []
        } else {
            pendingExchanges = exchangeRequests
                .filter { $0.status == .pending && $0.receiverId == activeHumanId }
                .sorted { $0.createdAt < $1.createdAt }
        }
        return TodayFocusSnapshot(
            pets: pets,
            plants: plants,
            humans: humans,
            refreshedQuests: refreshedQuests,
            assignedFamilyTasks: assignedTasks,
            pendingExchangeRequests: pendingExchanges,
            negativeSignals: IslandNegativeFeedback.signals(pets: pets, plants: plants)
        )
    }
}

struct TodayFocusQuestCardHost: View {
    let pets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePet: Pet?
    let isLive: Bool
    var presentation: TodayFocusCardPresentation = .board
    var onOpenQuest: (IslandQuest) -> Void
    var onCompleteQuest: (IslandQuest) -> Void
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void
    var onTapOasis: () -> Void
    var onTapFamilyTask: (FamilyCollaborationTask) -> Void
    var onConfirmExchange: (CoconutExchangeRequest) -> Void = { _ in }

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Query(sort: \PetCareLog.date, order: .reverse) private var liveCare: [PetCareLog]
    @Query(sort: \PetWalkLog.startDate, order: .reverse) private var liveWalks: [PetWalkLog]
    @Query(sort: \PetPottyLog.date, order: .reverse) private var livePotty: [PetPottyLog]
    @Query(sort: \HumanWeightLog.date, order: .reverse) private var liveHumanWeights: [HumanWeightLog]
    @Query(sort: \FamilyCollaborationTask.updatedAt, order: .reverse) private var familyTasks: [FamilyCollaborationTask]
    @Query(sort: \CoconutExchangeRequest.createdAt, order: .reverse) private var exchangeRequests: [CoconutExchangeRequest]
    @State private var renderSnapshot = TodayFocusSnapshot.empty
    @State private var renderSnapshotRefreshKey: SnapshotRefreshKey?

    init(
        pets: [Pet],
        plants: [Plant],
        reminders: [Reminder],
        humans: [Human],
        events: [Event],
        activePet: Pet?,
        isLive: Bool = true,
        presentation: TodayFocusCardPresentation = .board,
        onOpenQuest: @escaping (IslandQuest) -> Void,
        onCompleteQuest: @escaping (IslandQuest) -> Void,
        onTapNegativeSignal: @escaping (IslandNegativeSignal) -> Void,
        onTapOasis: @escaping () -> Void,
        onTapFamilyTask: @escaping (FamilyCollaborationTask) -> Void,
        onConfirmExchange: @escaping (CoconutExchangeRequest) -> Void = { _ in }
    ) {
        self.pets = pets
        self.plants = plants
        self.reminders = reminders
        self.humans = humans
        self.events = events
        self.activePet = activePet
        self.isLive = isLive
        self.presentation = presentation
        self.onOpenQuest = onOpenQuest
        self.onCompleteQuest = onCompleteQuest
        self.onTapNegativeSignal = onTapNegativeSignal
        self.onTapOasis = onTapOasis
        self.onTapFamilyTask = onTapFamilyTask
        self.onConfirmExchange = onConfirmExchange

        let todayStart = Calendar.current.startOfDay(for: Date())
        let activeStatus = FamilyCollaborationTaskStatus.active.rawValue
        let claimedStatus = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReviewStatus = FamilyCollaborationTaskStatus.pendingReview.rawValue
        let pendingExchangeStatus = CoconutExchangeRequestStatus.pending.rawValue
        _liveCare = Query(
            filter: #Predicate<PetCareLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _liveWalks = Query(
            filter: #Predicate<PetWalkLog> { $0.startDate >= todayStart },
            sort: \.startDate,
            order: .reverse
        )
        _livePotty = Query(
            filter: #Predicate<PetPottyLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _liveHumanWeights = Query(
            filter: #Predicate<HumanWeightLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _familyTasks = Query(
            filter: #Predicate<FamilyCollaborationTask> {
                $0.statusRaw == activeStatus || $0.statusRaw == claimedStatus || $0.statusRaw == pendingReviewStatus
            },
            sort: \.updatedAt,
            order: .reverse
        )
        _exchangeRequests = Query(
            filter: #Predicate<CoconutExchangeRequest> { $0.statusRaw == pendingExchangeStatus },
            sort: \.createdAt,
            order: .reverse
        )
    }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var privacyVisibleHumans: [Human] {
        PrivacyService.unlockedHumans(for: .weight, from: humans, viewedBy: activeHumanId)
    }

    var body: some View {
        TodayFocusCard(
            snapshot: renderSnapshot,
            presentation: presentation,
            onOpenQuest: onOpenQuest,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapOasis: onTapOasis,
            onTapFamilyTask: onTapFamilyTask,
            onConfirmExchange: onConfirmExchange,
            freezesToFrontCard: !isLive,
            allowsAmbientMotion: isLive && presentation == .board
        )
        .task(id: snapshotTaskKey) {
            guard case .live(let key) = snapshotTaskKey else { return }
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 96)
            guard !Task.isCancelled else { return }
            refreshSnapshotIfNeeded(for: key)
        }
    }

    private enum SnapshotTaskKey: Equatable, Sendable {
        case live(SnapshotRefreshKey)
        case frozen
    }

    private struct SnapshotRefreshKey: Equatable, Sendable {
        let language: String
        let activeHumanId: String
        let pets: Int
        let plants: Int
        let reminders: Int
        let events: Int
        let humans: Int
        let careLogs: Int
        let walkLogs: Int
        let pottyLogs: Int
        let humanWeightLogs: Int
        let familyTasks: Int
        let exchangeRequests: Int
    }

    private var snapshotTaskKey: SnapshotTaskKey {
        isLive ? .live(snapshotRefreshKey) : .frozen
    }

    private var snapshotRefreshKey: SnapshotRefreshKey {
        SnapshotRefreshKey(
            language: AppLanguage.code,
            activeHumanId: activeHumanIdStr,
            pets: petRefreshToken,
            plants: plantRefreshToken,
            reminders: reminderRefreshToken,
            events: eventRefreshToken,
            humans: humanRefreshToken,
            careLogs: logRefreshToken(liveCare.prefix(16)) { log in
                combine(log.id.hashValue, timestampValue(log.date))
            },
            walkLogs: logRefreshToken(liveWalks.prefix(16)) { log in
                combine(log.id.hashValue, timestampValue(log.startDate))
            },
            pottyLogs: logRefreshToken(livePotty.prefix(16)) { log in
                combine(log.id.hashValue, timestampValue(log.date))
            },
            humanWeightLogs: logRefreshToken(liveHumanWeights.prefix(12)) { log in
                combine(log.id.hashValue, timestampValue(log.date))
            },
            familyTasks: logRefreshToken(familyTasks.prefix(12)) { task in
                combine(
                    task.id.hashValue,
                    task.statusRaw.hashValue,
                    (task.assignedToId ?? "").hashValue,
                    (task.claimedById ?? "").hashValue,
                    timestampValue(task.updatedAt)
                )
            },
            exchangeRequests: logRefreshToken(exchangeRequests.prefix(12)) { request in
                combine(
                    request.id.hashValue,
                    request.statusRaw.hashValue,
                    request.receiverId.hashValue,
                    timestampValue(request.updatedAt)
                )
            }
        )
    }

    private var petRefreshToken: Int {
        logRefreshToken(pets.prefix(12)) { pet in
            combine(
                pet.id.hashValue,
                pet.name.hashValue,
                pet.currentStreak,
                pet.coconutBalance,
                pet.hasPassedAway ? 1 : 0
            )
        }
    }

    private var plantRefreshToken: Int {
        logRefreshToken(plants.prefix(12)) { plant in
            combine(
                plant.id.hashValue,
                plant.name.hashValue,
                plant.wateringIntervalDays,
                plant.fertilizingIntervalDays,
                timestampValue(plant.lastWateredDate),
                timestampValue(plant.lastFertilizedDate)
            )
        }
    }

    private var reminderRefreshToken: Int {
        logRefreshToken(reminders.prefix(8)) { reminder in
            combine(
                reminder.id.hashValue,
                timestampValue(reminder.scheduledAt),
                reminder.status.hashValue
            )
        }
    }

    private var eventRefreshToken: Int {
        logRefreshToken(events.prefix(16)) { event in
            combine(
                event.id.hashValue,
                timestampValue(event.startDate),
                event.isCompleted ? 1 : 0
            )
        }
    }

    private var humanRefreshToken: Int {
        logRefreshToken(humans.prefix(12)) { human in
            combine(
                human.id.hashValue,
                human.name.hashValue,
                human.coconutBalance
            )
        }
    }

    private func logRefreshToken<S: Sequence>(_ items: S, token: (S.Element) -> Int) -> Int {
        items.reduce(0) { partial, item in
            combine(partial, token(item))
        }
    }

    private func combine(_ values: Int...) -> Int {
        values.reduce(17) { partial, value in
            partial &* 31 &+ value
        }
    }

    private func timestampValue(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970)
    }

    private func timestampValue(_ date: Date?) -> Int {
        guard let date else { return 0 }
        return timestampValue(date)
    }

    private func refreshSnapshotIfNeeded(for key: SnapshotRefreshKey) {
        guard key != renderSnapshotRefreshKey else { return }
        let next = TodayFocusSnapshot.make(
            pets: pets,
            plants: plants,
            reminders: reminders,
            events: events,
            humans: privacyVisibleHumans,
            activeHumanId: activeHumanIdStr,
            careLogs: liveCare,
            walkLogs: liveWalks,
            pottyLogs: livePotty,
            humanWeightLogs: liveHumanWeights,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderSnapshot = next
            renderSnapshotRefreshKey = key
        }
    }
}

struct WalkLaunchBurst: View {
    @State private var animate = false

    private let paws: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-92, 50, 0.00), (-48, 18, 0.06), (-6, 42, 0.12),
        (38, 10, 0.18), (82, 34, 0.24)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.goLime.opacity(animate ? 0.22 : 0.04),
                            Color.goTeal.opacity(animate ? 0.16 : 0.03),
                            .clear
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .scaleEffect(animate ? 1.02 : 0.96)

            HStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 20, weight: .black))
                Text("开始巡岛")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.goPrimary, in: Capsule())
            .scaleEffect(animate ? 1 : 0.72)
            .opacity(animate ? 1 : 0)

            ForEach(paws.indices, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.goLime.opacity(0.88))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 16))
                    .offset(
                        x: animate ? paws[index].x : paws[index].x - 28,
                        y: animate ? paws[index].y - 64 : paws[index].y
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.78).delay(paws[index].delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            withAnimation(HeroAnim.fabSpring) {
                animate = true
            }
        }
    }
}

struct FocusHumanPortrait: View {
    let emoji: String
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .fill(color.mix(with: .white, by: 0.45).opacity(0.30))
                    .frame(width: g.size.width * 0.65)
                    .offset(x: -g.size.width * 0.18, y: -g.size.height * 0.14)
                Text(emoji)
                    .font(.system(size: g.size.height * 0.44))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -g.size.height * 0.04)
            }
        }
    }
}

struct ExpandedQuickActionMenuPanel: View {
    let icon: String
    let title: String
    let status: String
    let accent: Color
    let isLocked: Bool
    let lockedText: String?
    let quickTitle: String
    let detailTitle: String?
    let isQuickDisabled: Bool
    let quickOptions: [ExpandedQuickMenuOption]
    let onQuick: () -> Void
    let onDetail: () -> Void
    let onOption: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                .padding(.top, 8)
                .gesture(
                    DragGesture(minimumDistance: 12).onEnded { value in
                        if value.translation.height > 32 {
                            onClose()
                        }
                    }
                )

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(status)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            VStack(spacing: 10) {
                if isLocked {
                    lockedBlock
                } else if !quickOptions.isEmpty {
                    optionGrid
                } else {
                    actionButton(
                        title: quickTitle,
                        icon: isQuickDisabled ? "checkmark.circle.fill" : "bolt.fill",
                        tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                        foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                        isDisabled: isQuickDisabled,
                        action: onQuick
                    )
                }

                if !isLocked, let detailTitle {
                    actionButton(
                        title: detailTitle,
                        icon: "chart.line.uptrend.xyaxis",
                        tint: Color.ohanaControlFill,
                        foreground: Color.ohanaPrimaryText,
                        isDisabled: false,
                        action: onDetail
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        .shadow(color: Color.black.opacity(0.34), radius: 30, x: 0, y: -8) // ui-v4: allow lifted overlay shadow
    }

    private var lockedBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(lockedText ?? "")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var optionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quickTitle)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(quickOptions) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onOption(option.id)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(option.tint)
                            Text(option.title)
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        foreground: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                Text(title)
                    .font(OhanaFont.body(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint, in: Capsule())
        }
        .disabled(isDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
}
