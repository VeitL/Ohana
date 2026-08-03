//
//  HumanWorkoutSummaryView.swift
//  Ohana
//
//  Apple Health-backed human workout summary in Ohana V4 style.
//

import SwiftData
import SwiftUI
import UIKit

struct HumanWorkoutSummaryView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HumanAppleHealthBindingStore.storageKey) private var appleHealthBoundHumanIDRaw = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var healthManager = HumanHealthKitManager()
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showAddSheet = false
    @State private var selectedPeriod: HumanWorkoutHistoryPeriod = .thirtyDays
    @State private var localWorkoutLogs: [HumanWorkoutLog] = []
    @State private var petWalkSnapshots: [HumanWorkoutPetWalkSnapshot] = []
    @State private var localHistoryReadState: HumanWorkoutHistoryReadState = .loading
    @State private var petWalkHistoryReadState: HumanWorkoutHistoryReadState = .loading
    @State private var healthKitHistoryReadState: HumanWorkoutHistoryReadState = .notIncluded
    @State private var historyNow = Date()
    @State private var preparedAppleHealthBindingTaskID: String?
    @State private var boundAppleHealthHumanName: String?
    @State private var pendingAppleHealthBindingAction: HumanWorkoutAppleHealthBindingAction?
    @State private var pendingWorkoutDeletion: HumanWorkoutLog?

    private var l: L10n { L10n(appLanguage) }
    // The active Human is only the viewer for the existing privacy policy. It
    // must never be treated as the owner of this device's Apple Health data.
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.workout, viewedBy: activeHumanId) }
    private var sortedLogs: [HumanWorkoutLog] { localWorkoutLogs.sorted { $0.date > $1.date } }
    private var boundAppleHealthHumanID: UUID? {
        HumanAppleHealthBindingPolicy.normalizedHumanID(from: appleHealthBoundHumanIDRaw)
    }

    private var appleHealthBindingState: HumanAppleHealthBindingState {
        HumanAppleHealthBindingPolicy.state(
            boundHumanID: boundAppleHealthHumanID,
            viewedHumanID: human.id,
            viewedHumanHasPassedAway: human.hasPassedAway
        )
    }

    private var canReadLiveAppleHealth: Bool {
        appleHealthBindingState.allowsLiveHealthRead
    }

    private var appleHealthBindingTaskID: String {
        "\(human.id.uuidString):\(appleHealthBoundHumanIDRaw):\(human.hasPassedAway)"
    }

    private var workoutHistoryTaskID: String {
        "\(appleHealthBindingTaskID):\(selectedPeriod.rawValue)"
    }

    private var selectedPeriodStart: Date {
        selectedPeriod.startDate(containing: historyNow)
    }

    private var historyCoverage: HumanWorkoutHistoryCoverage {
        HumanWorkoutHistoryCoverage(
            local: localHistoryReadState,
            petWalk: petWalkHistoryReadState,
            healthKit: healthKitHistoryReadState
        )
    }

    @MainActor private var liveHealthKitWorkouts: [HumanHealthKitWorkoutSnapshot] {
        canReadLiveAppleHealth ? healthManager.recentWorkouts : []
    }

    @MainActor private var summaryRows: [HumanWorkoutSummaryRow] {
        let liveHealthKitIDs = Set(liveHealthKitWorkouts.map(\.healthKitWorkoutUUID))
        let livePetWalkIDs = Set(petWalkSnapshots.flatMap(\.sourcePetWalkLogIDs))
        let localRows = sortedLogs
            .filter { log in
                HumanWorkoutSourceMergePolicy.shouldShowLocalLog(
                    healthKitWorkoutUUID: log.healthKitWorkoutUUID,
                    sourcePetWalkLogID: log.sourcePetWalkLogID,
                    liveHealthKitIDs: liveHealthKitIDs,
                    livePetWalkIDs: livePetWalkIDs
                )
            }
            .map(localWorkoutRow)
        let petWalkRows = petWalkSnapshots.map { walk in
            let matchedWorkout = overlappingHealthKitWorkout(for: walk)
            return HumanWorkoutSummaryRow.petWalk(
                walk,
                title: petWalkTitle(for: walk),
                sourceName: petWalkSourceName(for: walk),
                overlapText: matchedWorkout == nil ? nil : l.tr(
                    zh: "与 Apple Health 中的同一次运动自动合并显示。",
                    en: "Automatically combined with the matching Apple Health workout.",
                    de: "Automatisch mit dem passenden Apple-Health-Training zusammengeführt."
                ),
                matchedHealthKitWorkout: matchedWorkout
            )
        }
        let healthRows = liveHealthKitWorkouts
            .filter { overlappingPetWalk(for: $0) == nil }
            .map { workout in
                HumanWorkoutSummaryRow.healthKit(
                    workout,
                    title: workout.type.localizedTitle(l)
                )
            }
        return (localRows + petWalkRows + healthRows)
            .filter { $0.date >= selectedPeriodStart && $0.date <= historyNow }
            .sorted { $0.date > $1.date }
    }

    @MainActor private var trendSnapshot: HumanWorkoutTrendSnapshot {
        HumanWorkoutTrendSnapshotBuilder.make(
            samples: summaryRows.map(\.trendSample),
            period: selectedPeriod,
            now: historyNow,
            coverage: historyCoverage
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground()

            VStack(spacing: 12) {
                HumanModulePageHeader(
                    human: human,
                    title: l.tr(zh: "运动摘要", en: "Workout Summary", de: "Trainingsübersicht"),
                    subtitle: l.tr(
                        zh: "今天的活动与区间历史",
                        en: "Today’s activity and period history",
                        de: "Heutige Aktivität und Zeitraumverlauf"
                    ),
                    onClose: { dismiss() }
                ) {
                    HumanPrivacyToggleButton(human: human, field: .workout)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("human-workout-summary-view")
                .padding(.horizontal, 16)
                .padding(.top, 14)

                if isPrivacyLocked {
                    Spacer(minLength: 0)
                    HumanModulePrivacyLockedView(
                        title: appServices.privacy.lockedMessage(for: .workout),
                        message: l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this profile to view it.", de: "Wechsle zu diesem Profil, um es zu sehen.")
                    )
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            HumanPrivateDataNotice(human: human, field: .workout)
                            HumanWorkoutAppleHealthBindingCard(
                                humanName: human.name,
                                state: appleHealthBindingState,
                                boundHumanName: boundAppleHealthHumanName,
                                onRequestAction: { pendingAppleHealthBindingAction = $0 }
                            )
                            if canReadLiveAppleHealth {
                                HumanWorkoutSectionHeading(
                                    icon: "applewatch",
                                    title: l.tr(
                                        zh: "Apple Health 今日快照",
                                        en: "Apple Health Today",
                                        de: "Apple Health heute"
                                    ),
                                    subtitle: l.tr(
                                        zh: "来自本机当前可读数据；活动环仅表示今天的设备快照。",
                                        en: "Currently readable on this device; Activity Rings show only today’s device snapshot.",
                                        de: "Aktuell auf diesem Gerät lesbar; die Aktivitätsringe zeigen nur den heutigen Gerätestand."
                                    )
                                )
                                HumanWorkoutHealthSnapshotCards(
                                    authorizationStatus: healthManager.authorizationStatus,
                                    activitySummaryStatus: healthManager.activitySummaryStatus,
                                    snapshot: healthManager.snapshot,
                                    isLoading: healthManager.isLoading,
                                    onRequestHealthAccess: {
                                        Task { await requestHealthAccess() }
                                    },
                                    onRefresh: {
                                        Task { await refreshHealthDataIfAvailable() }
                                    }
                                )
                            }
                            HumanWorkoutHistoryOverviewCard(
                                selectedPeriod: $selectedPeriod,
                                trendSnapshot: trendSnapshot,
                                historyCoverage: historyCoverage
                            )
                            HumanWorkoutRecentWorkoutsCard(
                                selectedPeriod: selectedPeriod,
                                rows: summaryRows,
                                historyCoverage: historyCoverage,
                                canReadLiveAppleHealth: canReadLiveAppleHealth,
                                isHealthLoading: healthManager.isLoading,
                                recentWorkoutsStatus: healthManager.recentWorkoutsStatus,
                                onDelete: { pendingWorkoutDeletion = $0 }
                            )
                            Spacer(minLength: 92)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                    }
                }
            }

            if !isPrivacyLocked {
                HumanModuleFloatingActionButton(
                    title: l.tr(zh: "添加运动", en: "Add Workout", de: "Training hinzufügen"),
                    icon: "plus",
                    action: { showAddSheet = true }
                )
                .accessibilityIdentifier("human-workout-add-action")
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPeriod) { _, _ in
            markHistorySourcesLoading()
        }
        .task(id: workoutHistoryTaskID) { await prepareHealthSnapshot() }
        .sheet(isPresented: $showAddSheet) {
            AddWorkoutSheet(human: human) {
                Task { await refreshWorkoutHistoryAndHealth() }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow complex workout editor uses full-height system sheet
        }
        .confirmationDialog(
            appleHealthBindingConfirmationTitle,
            isPresented: appleHealthBindingConfirmationIsPresented,
            titleVisibility: .visible
        ) {
            appleHealthBindingConfirmationActions
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                pendingAppleHealthBindingAction = nil
            }
        } message: {
            Text(appleHealthBindingConfirmationMessage)
        }
        .alert(
            l.tr(zh: "删除这条手动运动记录？", en: "Delete this manual workout?", de: "Dieses manuelle Training löschen?"),
            isPresented: workoutDeletionConfirmationIsPresented
        ) {
            Button(l.tr(zh: "删除记录", en: "Delete Record", de: "Eintrag löschen"), role: .destructive) {
                guard let log = pendingWorkoutDeletion else { return }
                pendingWorkoutDeletion = nil
                deleteLog(log)
            }
            .accessibilityIdentifier("human-workout-confirm-delete-action")
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                pendingWorkoutDeletion = nil
            }
        } message: {
            Text(l.tr(
                zh: "删除后无法撤销；Apple Health 与遛狗来源不会受到影响。",
                en: "This cannot be undone. Apple Health and dog-walk sources are not affected.",
                de: "Dies kann nicht rückgängig gemacht werden. Apple Health und Hundegänge bleiben unverändert."
            ))
        }
    }

    private var appleHealthBindingConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingAppleHealthBindingAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingAppleHealthBindingAction = nil
                }
            }
        )
    }

    private var appleHealthBindingConfirmationTitle: String {
        switch pendingAppleHealthBindingAction {
        case .bind:
            l.tr(zh: "绑定 Apple Health？", en: "Bind Apple Health?", de: "Apple Health verbinden?")
        case .rebind:
            l.tr(zh: "改绑 Apple Health？", en: "Rebind Apple Health?", de: "Apple Health neu verbinden?")
        case .unbind:
            l.tr(zh: "解绑 Apple Health？", en: "Unbind Apple Health?", de: "Apple Health trennen?")
        case nil:
            ""
        }
    }

    private var appleHealthBindingConfirmationMessage: String {
        switch pendingAppleHealthBindingAction {
        case .bind:
            return l.tr(
                zh: "确认后，这台设备可读取的实时 Apple Health 数据只显示在 \(human.name) 的运动页。",
                en: "After confirmation, live Apple Health data readable on this device appears only on \(human.name)’s workout screen.",
                de: "Danach erscheinen lesbare Live-Apple-Health-Daten dieses Geräts nur in \(human.name)s Trainingsansicht."
            )
        case .rebind:
            let owner = boundAppleHealthHumanName ?? l.tr(zh: "当前成员", en: "the current Human", de: "die aktuelle Person")
            return l.tr(
                zh: "实时查看权将从 \(owner) 移到 \(human.name)。双方的手动运动和遛狗记录都不会改变。",
                en: "Live viewing moves from \(owner) to \(human.name). Manual workouts and dog walks for both Humans remain unchanged.",
                de: "Die Live-Anzeige wechselt von \(owner) zu \(human.name). Manuelle Trainings und Hundegänge beider Personen bleiben unverändert."
            )
        case .unbind:
            return l.tr(
                zh: "解绑后 Ohana 会停止在成员页读取和显示实时 Apple Health 数据。既有手动运动与遛狗记录会保留。",
                en: "Ohana will stop reading and showing live Apple Health data on Human screens. Existing manual workouts and dog walks remain.",
                de: "Ohana liest und zeigt danach keine Live-Apple-Health-Daten mehr in Personenansichten. Vorhandene manuelle Trainings und Hundegänge bleiben erhalten."
            )
        case nil:
            return ""
        }
    }

    @ViewBuilder
    private var appleHealthBindingConfirmationActions: some View {
        switch pendingAppleHealthBindingAction {
        case .bind:
            Button(l.tr(zh: "确认绑定", en: "Confirm Binding", de: "Bindung bestätigen")) {
                applyAppleHealthBindingAction(.bind)
            }
            .accessibilityIdentifier("human-workout-apple-health-confirm-bind-action")
        case .rebind:
            Button(l.tr(zh: "确认改绑", en: "Confirm Rebinding", de: "Neue Bindung bestätigen")) {
                applyAppleHealthBindingAction(.rebind)
            }
            .accessibilityIdentifier("human-workout-apple-health-confirm-rebind-action")
        case .unbind:
            Button(l.tr(zh: "确认解绑", en: "Confirm Unbinding", de: "Trennung bestätigen"), role: .destructive) {
                applyAppleHealthBindingAction(.unbind)
            }
            .accessibilityIdentifier("human-workout-apple-health-confirm-unbind-action")
        case nil:
            EmptyView()
        }
    }

    private func applyAppleHealthBindingAction(_ action: HumanWorkoutAppleHealthBindingAction) {
        pendingAppleHealthBindingAction = nil
        switch action {
        case .bind, .rebind:
            guard HumanAppleHealthBindingStore.bind(
                to: human.id,
                humanHasPassedAway: human.hasPassedAway
            ) else { return }
            boundAppleHealthHumanName = human.name
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .unbind:
            _ = HumanAppleHealthBindingStore.invalidateIfBound(to: human.id)
            boundAppleHealthHumanName = nil
            healthManager.clearVisibleData()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var workoutDeletionConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingWorkoutDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingWorkoutDeletion = nil
                }
            }
        )
    }

    private func prepareHealthSnapshot() async {
        historyNow = Date()
        validateAppleHealthBinding()
        markHistorySourcesLoading()
        loadLocalWorkoutLogs()
        loadPetWalkSnapshots()
        let needsFullHealthRefresh = preparedAppleHealthBindingTaskID != appleHealthBindingTaskID
        preparedAppleHealthBindingTaskID = appleHealthBindingTaskID
        guard canReadLiveAppleHealth else {
            healthManager.clearVisibleData()
            healthKitHistoryReadState = .notIncluded
            return
        }
        guard needsFullHealthRefresh else {
            await refreshRecentHealthWorkoutsIfAvailable()
            return
        }
        await healthManager.refreshAuthorizationStatus()
        guard !Task.isCancelled, canReadLiveAppleHealth else { return }
        await refreshHealthDataIfAvailable()
    }

    @MainActor
    private func validateAppleHealthBinding() {
        guard let boundHumanID = boundAppleHealthHumanID else {
            if !appleHealthBoundHumanIDRaw.isEmpty {
                _ = HumanAppleHealthBindingStore.unbind()
            }
            boundAppleHealthHumanName = nil
            return
        }

        if boundHumanID == human.id {
            boundAppleHealthHumanName = human.name
            if human.hasPassedAway {
                _ = HumanAppleHealthBindingStore.invalidateIfBound(to: human.id)
                boundAppleHealthHumanName = nil
            }
            return
        }

        do {
            guard let boundHuman = try HumanWorkoutSummaryRouteData.boundHumanProfile(
                id: boundHumanID,
                from: modelContext
            ), !boundHuman.hasPassedAway else {
                _ = HumanAppleHealthBindingStore.invalidateIfBound(to: boundHumanID)
                boundAppleHealthHumanName = nil
                return
            }
            boundAppleHealthHumanName = boundHuman.name
        } catch {
            OhanaLog.warning(
                "Apple Health Human binding validation failed: \(error.localizedDescription)",
                category: "Workouts"
            )
            boundAppleHealthHumanName = nil
        }
    }

    private func loadPetWalkSnapshots() {
        let page = HumanWorkoutPetWalkSnapshotBuilder.page(
            for: human,
            since: selectedPeriodStart,
            through: historyNow,
            limit: selectedPeriod.queryLimit,
            context: modelContext
        )
        petWalkSnapshots = page.snapshots
        petWalkHistoryReadState = page.readState
    }

    private func loadLocalWorkoutLogs() {
        do {
            let page = try HumanWorkoutSummaryRouteData.localWorkoutHistory(
                humanID: human.id,
                since: selectedPeriodStart,
                through: historyNow,
                limit: selectedPeriod.queryLimit,
                from: modelContext
            )
            localWorkoutLogs = page.logs
            localHistoryReadState = page.readState
        } catch {
            OhanaLog.warning(
                "Human workout history fetch failed: \(error.localizedDescription)",
                category: "Workouts"
            )
            localWorkoutLogs = []
            localHistoryReadState = .unavailable
        }
    }

    private func markHistorySourcesLoading() {
        localHistoryReadState = .loading
        petWalkHistoryReadState = .loading
        healthKitHistoryReadState = canReadLiveAppleHealth ? .loading : .notIncluded
    }

    private func requestHealthAccess() async {
        guard canReadLiveAppleHealth else { return }
        await healthManager.requestReadAuthorization()
        guard !Task.isCancelled, canReadLiveAppleHealth else { return }
        await loadRecentHealthWorkoutsForSelectedPeriod()
    }

    private func refreshWorkoutHistoryAndHealth() async {
        historyNow = Date()
        markHistorySourcesLoading()
        loadLocalWorkoutLogs()
        loadPetWalkSnapshots()
        await refreshHealthDataIfAvailable()
    }

    private func refreshHealthDataIfAvailable() async {
        guard canReadLiveAppleHealth else {
            healthManager.clearVisibleData()
            healthKitHistoryReadState = .notIncluded
            return
        }
        switch healthManager.authorizationStatus {
        case .accessRequested, .unknown:
            await healthManager.loadTodaySummary()
            guard !Task.isCancelled else { return }
            await loadRecentHealthWorkoutsForSelectedPeriod()
        case .failed:
            healthKitHistoryReadState = .unavailable
            await healthManager.refreshAuthorizationStatus()
        case .notAvailable, .notDetermined:
            healthKitHistoryReadState = .notIncluded
        }
    }

    private func refreshRecentHealthWorkoutsIfAvailable() async {
        guard canReadLiveAppleHealth else {
            healthManager.clearVisibleData()
            healthKitHistoryReadState = .notIncluded
            return
        }
        switch healthManager.authorizationStatus {
        case .accessRequested, .unknown:
            await loadRecentHealthWorkoutsForSelectedPeriod()
        case .failed:
            healthKitHistoryReadState = .unavailable
            await healthManager.refreshAuthorizationStatus()
        case .notAvailable, .notDetermined:
            healthKitHistoryReadState = .notIncluded
        }
    }

    private func loadRecentHealthWorkoutsForSelectedPeriod() async {
        let requestedPeriod = selectedPeriod
        let requestStart = requestedPeriod.startDate(containing: historyNow)
        _ = await healthManager.loadRecentWorkouts(
            since: requestStart,
            limit: requestedPeriod.healthKitQueryLimit
        )
        guard !Task.isCancelled, requestedPeriod == selectedPeriod else { return }
        healthKitHistoryReadState = switch healthManager.recentWorkoutsStatus {
        case .available, .noData:
            healthManager.recentWorkoutsWereTruncated ? .truncated : .complete
        case .failed:
            .unavailable
        case .notLoaded:
            .loading
        }
    }

    private func deleteLog(_ log: HumanWorkoutLog) {
        let command = DomainCommand.humanWorkoutDelete(humanID: human.id, recordID: log.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).deleteWorkout(
                log,
                human: human,
                command: command,
                note: "human.workout.delete"
            )
            if result.didPersist {
                loadLocalWorkoutLogs()
            }
        }
    }

    private func localWorkoutRow(_ log: HumanWorkoutLog) -> HumanWorkoutSummaryRow {
        let linkedPetWalk = petWalkSnapshot(for: log.sourcePetWalkLogID)
        let title = linkedPetWalk.map(petWalkTitle(for:)) ?? log.workoutType.localizedTitle(l)
        return HumanWorkoutSummaryRow.local(
            log,
            title: title,
            sourceName: log.healthKitSourceName,
            isPetWalk: !log.sourcePetWalkLogID.isEmpty,
            isMatched: log.sourceHealthKit && !log.sourcePetWalkLogID.isEmpty
        )
    }

    private func petWalkSnapshot(for id: String) -> HumanWorkoutPetWalkSnapshot? {
        guard !id.isEmpty else { return nil }
        return petWalkSnapshots.first { $0.containsSourcePetWalkLogID(id) }
    }

    private func petWalkTitle(for walk: HumanWorkoutPetWalkSnapshot) -> String {
        if let petName = walk.petName, !petName.isEmpty {
            return l.tr(zh: "\(petName) 遛狗", en: "\(petName) Dog Walk", de: "\(petName) Hundegang")
        }
        return l.tr(zh: "遛狗步行", en: "Dog Walk", de: "Hundegang")
    }

    private func petWalkSourceName(for walk: HumanWorkoutPetWalkSnapshot) -> String {
        if let petName = walk.petName, !petName.isEmpty {
            return petName
        }
        return l.tr(zh: "Ohana 遛狗", en: "Ohana Dog Walk", de: "Ohana Hundegang")
    }

    private func overlappingHealthKitWorkout(for walk: HumanWorkoutPetWalkSnapshot) -> HumanHealthKitWorkoutSnapshot? {
        liveHealthKitWorkouts.first { workout in
            isLikelySameWorkout(workout: workout, petWalk: walk)
        }
    }

    private func overlappingPetWalk(for workout: HumanHealthKitWorkoutSnapshot) -> HumanWorkoutPetWalkSnapshot? {
        petWalkSnapshots.first { walk in
            isLikelySameWorkout(workout: workout, petWalk: walk)
        }
    }

    private func isLikelySameWorkout(
        workout: HumanHealthKitWorkoutSnapshot,
        petWalk: HumanWorkoutPetWalkSnapshot
    ) -> Bool {
        guard workout.type.isWalkingLikeForPetWalkMatch else { return false }
        let walkDurationMinutes = petWalk.durationMinutes
        let durationDelta = abs(workout.durationMinutes - walkDurationMinutes)
        let durationThreshold = max(10, Int(Double(max(workout.durationMinutes, walkDurationMinutes)) * 0.2))
        let distanceDelta = abs(workout.distanceKm - petWalk.distanceKm)
        let distanceThreshold = max(0.3, max(workout.distanceKm, petWalk.distanceKm) * 0.18)
        let startsClose = abs(workout.startDate.timeIntervalSince(petWalk.startDate)) <= 10 * 60
        return startsClose && durationDelta <= durationThreshold && distanceDelta <= distanceThreshold
    }
}

private extension WorkoutType {
    var isWalkingLikeForPetWalkMatch: Bool {
        switch self {
        case .walking, .hiking, .running:
            true
        case .cycling, .swimming, .gym, .yoga, .other:
            false
        }
    }
}
