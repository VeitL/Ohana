//
//  HumanWorkoutSummaryView.swift
//  Ohana
//
//  Apple Health-backed human workout summary in Ohana V4 style.
//

import SwiftData
import SwiftUI

struct HumanWorkoutSummaryView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var healthManager = HumanHealthKitManager()
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showAddSheet = false
    @State private var petWalkSnapshots: [HumanWorkoutPetWalkSnapshot] = []

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.workout, viewedBy: activeHumanId) }
    private var sortedLogs: [HumanWorkoutLog] { human.workoutLogs.sorted { $0.date > $1.date } }
    private var importedHealthKitUUIDs: Set<String> {
        Set(human.workoutLogs.map(\.healthKitWorkoutUUID).filter { !$0.isEmpty })
    }
    private var importedPetWalkLogIDs: Set<String> {
        Set(human.workoutLogs.map(\.sourcePetWalkLogID).filter { !$0.isEmpty })
    }
    private var importablePetWalkSnapshots: [HumanWorkoutPetWalkSnapshot] {
        petWalkSnapshots.filter { !importedPetWalkLogIDs.contains($0.sourcePetWalkLogID) }
    }
    private var importableCandidates: [HealthKitWorkoutImportCandidate] {
        healthManager.recentWorkoutCandidates.filter { !importedHealthKitUUIDs.contains($0.healthKitWorkoutUUID) }
    }
    @MainActor private var summaryRows: [WorkoutSummaryRow] {
        let localRows = sortedLogs.map(localWorkoutRow)
        let petWalkRows = importablePetWalkSnapshots.map { walk in
            let matchedCandidate = overlappingHealthKitCandidate(for: walk)
            return WorkoutSummaryRow.petWalkCandidate(
                walk,
                title: petWalkTitle(for: walk),
                sourceName: petWalkSourceName(for: walk),
                overlapText: matchedCandidate == nil ? nil : l.tr(
                    zh: "已匹配 Apple Health，加入时会合并为一条记录。",
                    en: "Matched with Apple Health; adding will merge into one log.",
                    de: "Mit Apple Health abgeglichen; wird als ein Eintrag zusammengeführt."
                ),
                matchedHealthKitCandidate: matchedCandidate
            )
        }
        let healthRows = importableCandidates
            .filter { overlappingImportablePetWalk(for: $0) == nil }
            .map { candidate in
                let matchedPetWalk = overlappingPetWalk(for: candidate, includeImported: true)
                return WorkoutSummaryRow.healthKitCandidate(
                    candidate,
                    title: candidate.type.localizedTitle(l),
                    overlapText: matchedPetWalk == nil ? nil : l.tr(
                        zh: "疑似同一次遛狗，导入会合并来源。",
                        en: "Looks like the same dog walk; import will merge sources.",
                        de: "Vermutlich derselbe Hundegang; der Import führt Quellen zusammen."
                    ),
                    matchedPetWalk: matchedPetWalk
                )
            }
        return (localRows + petWalkRows + healthRows).sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OhanaAppBackground()

                VStack(spacing: 12) {
                    HumanModulePageHeader(
                        human: human,
                        title: l.tr(zh: "运动摘要", en: "Workout Summary", de: "Trainingsübersicht"),
                        subtitle: l.tr(zh: "今天的活动与记录", en: "Today’s activity and logs", de: "Aktivität und Einträge heute"),
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
                                healthConnectionCard
                                activityRingsCard
                                metricCardsGrid
                                recentWorkoutsCard
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
            .task { await prepareHealthSnapshot() }
            .sheet(isPresented: $showAddSheet) {
                AddWorkoutSheet(human: human) {
                    Task { await refreshHealthDataIfConnected() }
                }
                .ohanaSheetPagePresentation() // ui-v4: allow complex workout editor uses full-height system sheet
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var healthConnectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "heart.text.square.fill").accessibilityHidden(true)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(connectionTitle)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(connectionSubtitle)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if healthManager.isLoading {
                    ProgressView()
                        .tint(Color.goPrimary)
                        .frame(width: 44, height: 44)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task { await requestHealthAccess() }
                } label: {
                    Text(connectionButtonTitle)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(healthManager.isLoading || healthManager.authorizationStatus == .notAvailable)
                .accessibilityIdentifier("human-workout-health-connect-action")

                Button {
                    Task { await refreshHealthDataIfConnected() }
                } label: {
                    Image(systemName: "arrow.clockwise").accessibilityHidden(true)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 48, height: 48)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "刷新运动数据", en: "Refresh workout data", de: "Trainingsdaten aktualisieren"))
                .accessibilityIdentifier("human-workout-health-refresh-action")
            }
        }
        .padding(16)
        .workoutSummaryCard()
    }

    private var activityRingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "活动环", en: "Activity Rings", de: "Aktivitätsringe"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            HStack(spacing: 18) {
                HumanWorkoutActivityRings(snapshot: healthManager.snapshot)
                    .frame(width: 136, height: 136)

                VStack(alignment: .leading, spacing: 12) {
                    ActivityRingMetric(
                        title: l.tr(zh: "活动", en: "Move", de: "Bewegen"),
                        value: moveMetricText,
                        color: .goRed
                    )
                    ActivityRingMetric(
                        title: l.tr(zh: "锻炼", en: "Exercise", de: "Training"),
                        value: exerciseMetricText,
                        color: .goPrimary
                    )
                    ActivityRingMetric(
                        title: l.tr(zh: "站立", en: "Stand", de: "Stehen"),
                        value: standMetricText,
                        color: .goCardCyan
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .workoutSummaryCard()
    }

    private var metricCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HumanWorkoutMetricCard(
                title: l.tr(zh: "步数", en: "Step Count", de: "Schritte"),
                subtitle: l.tr(zh: "今天", en: "Today", de: "Heute"),
                value: "\(healthManager.snapshot.steps)",
                unit: "",
                tint: .goPurple,
                points: chartPoints(from: healthManager.snapshot.hourlySteps, idPrefix: "steps")
            )
            HumanWorkoutMetricCard(
                title: l.tr(zh: "步行距离", en: "Step Distance", de: "Schrittdistanz"),
                subtitle: l.tr(zh: "今天", en: "Today", de: "Heute"),
                value: String(format: "%.2f", healthManager.snapshot.distanceKm),
                unit: "km",
                tint: .goCardCyan,
                points: chartPoints(from: healthManager.snapshot.hourlyDistanceKm, idPrefix: "distance")
            )
        }
    }

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "最近运动", en: "Recent Workouts", de: "Letzte Trainings"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(recentWorkoutsCountText)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if summaryRows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run.circle").accessibilityHidden(true)
                        .font(OhanaFont.metric(size: 34))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(l.tr(zh: "还没有运动记录", en: "No workouts yet", de: "Noch keine Trainings"))
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(summaryRows.prefix(12)) { row in
                        workoutRow(row)
                        if row.id != summaryRows.prefix(12).last?.id {
                            GoDashedDivider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .workoutSummaryCard()
    }

    private func workoutRow(_ row: WorkoutSummaryRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.type.icon)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color(hex: row.type.colorHex))
                .frame(width: 44, height: 44)
                .background(Color(hex: row.type.colorHex).opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.title)
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    if row.isHealthKit {
                        sourceBadge(row.sourceName.isEmpty ? "Apple Health" : row.sourceName, tint: .goPrimary)
                    }
                    if row.isPetWalk {
                        sourceBadge(l.tr(zh: "遛狗", en: "Dog Walk", de: "Hundegang"), tint: .goCardCyan)
                    }
                    if row.isMatched {
                        sourceBadge(l.tr(zh: "已匹配", en: "Matched", de: "Abgeglichen"), tint: .goYellow)
                    }
                }
                Text(row.date, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if let overlapText = row.overlapText {
                    Text(overlapText)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.goYellow)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(row.durationMinutes) min")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color(hex: row.type.colorHex))
                Text(row.secondaryMetric)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            rowAction(row)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func sourceBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.arkInk)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
    }

    @ViewBuilder
    private func rowAction(_ row: WorkoutSummaryRow) -> some View {
        if let petWalk = row.petWalk {
            Button {
                importPetWalk(petWalk, matchedCandidate: row.matchedHealthKitCandidate)
            } label: {
                Image(systemName: "plus.circle").accessibilityHidden(true)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "加入遛狗运动", en: "Add dog walk workout", de: "Hundegang als Training hinzufügen"))
            .accessibilityIdentifier("human-workout-import-pet-walk-\(petWalk.sourcePetWalkLogID)")
        } else if let candidate = row.candidate {
            Button {
                importCandidate(candidate)
            } label: {
                Image(systemName: "square.and.arrow.down").accessibilityHidden(true)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "导入运动", en: "Import workout", de: "Training importieren"))
            .accessibilityIdentifier("human-workout-import-\(candidate.healthKitWorkoutUUID)")
        } else if let log = row.log {
            Button {
                deleteLog(log)
            } label: {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.58))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "删除运动记录", en: "Delete workout log", de: "Trainingseintrag löschen"))
            .accessibilityIdentifier("human-workout-delete-action")
        }
    }

    private var connectionTitle: String {
        switch healthManager.authorizationStatus {
        case .notAvailable:
            l.tr(zh: "Apple Health 不可用", en: "Apple Health Unavailable", de: "Apple Health nicht verfügbar")
        case .notDetermined:
            l.tr(zh: "连接 Apple Health", en: "Connect Apple Health", de: "Apple Health verbinden")
        case .connected:
            l.tr(zh: "Apple Health 已连接", en: "Apple Health Connected", de: "Apple Health verbunden")
        case .unknown:
            l.tr(zh: "检查 Apple Health", en: "Check Apple Health", de: "Apple Health prüfen")
        case .failed:
            l.tr(zh: "读取 Apple Health 失败", en: "Apple Health Read Failed", de: "Apple Health konnte nicht gelesen werden")
        }
    }

    private var connectionSubtitle: String {
        switch healthManager.authorizationStatus {
        case .notAvailable:
            l.tr(zh: "当前设备不支持读取 HealthKit 数据。", en: "This device cannot read HealthKit data.", de: "Dieses Gerät kann keine HealthKit-Daten lesen.")
        case .notDetermined:
            l.tr(zh: "读取步数、距离、活动能量和运动记录，只用于此成员的本地摘要。", en: "Read steps, distance, active energy, and workouts for this member’s local summary.", de: "Liest Schritte, Distanz, Aktivenergie und Trainings für diese lokale Übersicht.")
        case .connected:
            l.tr(zh: "今日活动已同步到页面摘要，运动记录可按需导入。", en: "Today’s activity is shown here, and workouts can be imported when needed.", de: "Die heutige Aktivität wird hier gezeigt; Trainings können bei Bedarf importiert werden.")
        case .unknown:
            l.tr(zh: "点按刷新，Ohana 会重新检查可读取的数据。", en: "Refresh to check readable data again.", de: "Aktualisiere, um lesbare Daten erneut zu prüfen.")
        case let .failed(message):
            message
        }
    }

    private var connectionButtonTitle: String {
        switch healthManager.authorizationStatus {
        case .connected:
            l.tr(zh: "重新连接", en: "Reconnect", de: "Neu verbinden")
        case .notAvailable:
            l.tr(zh: "不可用", en: "Unavailable", de: "Nicht verfügbar")
        default:
            l.tr(zh: "设置", en: "Set Up", de: "Einrichten")
        }
    }

    private var recentWorkoutsCountText: String {
        if importablePetWalkSnapshots.isEmpty {
            return l.tr(zh: "\(sortedLogs.count) 条记录", en: "\(sortedLogs.count) logs", de: "\(sortedLogs.count) Einträge")
        }
        return l.tr(
            zh: "\(sortedLogs.count) 条记录 · \(importablePetWalkSnapshots.count) 次遛狗可加入",
            en: "\(sortedLogs.count) logs · \(importablePetWalkSnapshots.count) dog walks",
            de: "\(sortedLogs.count) Einträge · \(importablePetWalkSnapshots.count) Hundegänge"
        )
    }

    private var moveMetricText: String {
        if healthManager.snapshot.moveGoalKcal > 0 {
            "\(healthManager.snapshot.activeEnergyKcal)/\(healthManager.snapshot.moveGoalKcal) kcal"
        } else {
            "\(healthManager.snapshot.activeEnergyKcal) kcal"
        }
    }

    private var exerciseMetricText: String {
        if healthManager.snapshot.exerciseGoalMinutes > 0 {
            "\(healthManager.snapshot.exerciseMinutes)/\(healthManager.snapshot.exerciseGoalMinutes) min"
        } else {
            "\(healthManager.snapshot.exerciseMinutes) min"
        }
    }

    private var standMetricText: String {
        if healthManager.snapshot.standGoalHours > 0 {
            "\(healthManager.snapshot.standHours)/\(healthManager.snapshot.standGoalHours) hrs"
        } else {
            "\(healthManager.snapshot.standHours) hrs"
        }
    }

    private func chartPoints(from points: [HumanHealthHourlyPoint], idPrefix: String) -> [OhanaMinimalChartPoint] {
        let start = Calendar.current.startOfDay(for: Date())
        return points.map { point in
            OhanaMinimalChartPoint(
                date: start.addingTimeInterval(Double(point.hour) * 3600),
                value: point.value,
                label: String(format: "%02d", point.hour),
                id: "\(idPrefix)-\(point.hour)"
            )
        }
    }

    private func prepareHealthSnapshot() async {
        loadPetWalkSnapshots()
        await healthManager.refreshAuthorizationStatus()
        await refreshHealthDataIfConnected()
    }

    private func loadPetWalkSnapshots() {
        petWalkSnapshots = HumanWorkoutPetWalkSnapshotBuilder.snapshots(for: human, context: modelContext)
    }

    private func requestHealthAccess() async {
        await healthManager.requestReadAuthorization()
    }

    private func refreshHealthDataIfConnected() async {
        switch healthManager.authorizationStatus {
        case .connected, .unknown:
            await healthManager.loadTodaySummary()
            _ = await healthManager.loadRecentWorkoutCandidates()
        case .failed:
            await healthManager.refreshAuthorizationStatus()
        case .notAvailable, .notDetermined:
            break
        }
    }

    private func importCandidate(_ candidate: HealthKitWorkoutImportCandidate) {
        let matchedPetWalk = overlappingPetWalk(for: candidate, includeImported: true)
        let command = DomainCommand.humanWorkoutEntry(humanID: human.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).recordWorkout(
                human: human,
                type: candidate.type,
                durationMinutes: candidate.durationMinutes,
                date: candidate.startDate,
                distanceKm: candidate.distanceKm,
                calories: candidate.calories,
                steps: candidate.steps,
                sourceHealthKit: true,
                healthKitWorkoutUUID: candidate.healthKitWorkoutUUID,
                healthKitSourceBundleID: candidate.sourceBundleID,
                healthKitSourceName: candidate.sourceName,
                sourcePetWalkLogID: matchedPetWalk?.sourcePetWalkLogID ?? "",
                source: .importData,
                command: command,
                note: "human.workout.healthkit.import"
            )
        }
    }

    private func importPetWalk(_ petWalk: HumanWorkoutPetWalkSnapshot, matchedCandidate: HealthKitWorkoutImportCandidate?) {
        let command = DomainCommand.humanWorkoutEntry(humanID: human.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).recordWorkout(
                human: human,
                type: matchedCandidate?.type ?? .walking,
                durationMinutes: petWalk.durationMinutes,
                date: petWalk.startDate,
                distanceKm: petWalk.distanceKm,
                calories: matchedCandidate?.calories ?? 0,
                steps: matchedCandidate?.steps ?? 0,
                notes: "Ohana dog walk",
                sourceHealthKit: matchedCandidate != nil,
                healthKitWorkoutUUID: matchedCandidate?.healthKitWorkoutUUID ?? "",
                healthKitSourceBundleID: matchedCandidate?.sourceBundleID ?? "",
                healthKitSourceName: matchedCandidate?.sourceName ?? "",
                sourcePetWalkLogID: petWalk.sourcePetWalkLogID,
                source: .importData,
                command: command,
                note: "human.workout.petwalk.import"
            )
        }
    }

    private func deleteLog(_ log: HumanWorkoutLog) {
        let command = DomainCommand.humanWorkoutDelete(humanID: human.id, recordID: log.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext, services: appServices).deleteWorkout(
                log,
                human: human,
                command: command,
                note: "human.workout.delete"
            )
        }
    }

    private func localWorkoutRow(_ log: HumanWorkoutLog) -> WorkoutSummaryRow {
        let linkedPetWalk = petWalkSnapshot(for: log.sourcePetWalkLogID)
        let title = linkedPetWalk.map(petWalkTitle(for:)) ?? log.workoutType.localizedTitle(l)
        return WorkoutSummaryRow.local(
            log,
            title: title,
            sourceName: log.healthKitSourceName,
            isPetWalk: !log.sourcePetWalkLogID.isEmpty,
            isMatched: log.sourceHealthKit && !log.sourcePetWalkLogID.isEmpty
        )
    }

    private func petWalkSnapshot(for id: String) -> HumanWorkoutPetWalkSnapshot? {
        guard !id.isEmpty else { return nil }
        return petWalkSnapshots.first { $0.sourcePetWalkLogID == id }
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

    private func overlappingHealthKitCandidate(for walk: HumanWorkoutPetWalkSnapshot) -> HealthKitWorkoutImportCandidate? {
        importableCandidates.first { candidate in
            isLikelySameWorkout(candidate: candidate, petWalk: walk)
        }
    }

    private func overlappingImportablePetWalk(for candidate: HealthKitWorkoutImportCandidate) -> HumanWorkoutPetWalkSnapshot? {
        importablePetWalkSnapshots.first { walk in
            isLikelySameWorkout(candidate: candidate, petWalk: walk)
        }
    }

    private func overlappingPetWalk(
        for candidate: HealthKitWorkoutImportCandidate,
        includeImported: Bool
    ) -> HumanWorkoutPetWalkSnapshot? {
        let walks = includeImported ? petWalkSnapshots : importablePetWalkSnapshots
        return walks.first { walk in
            isLikelySameWorkout(candidate: candidate, petWalk: walk)
        }
    }

    private func isLikelySameWorkout(
        candidate: HealthKitWorkoutImportCandidate,
        petWalk: HumanWorkoutPetWalkSnapshot
    ) -> Bool {
        guard candidate.type.isWalkingLikeForPetWalkMatch else { return false }
        let walkDurationMinutes = petWalk.durationMinutes
        let durationDelta = abs(candidate.durationMinutes - walkDurationMinutes)
        let durationThreshold = max(10, Int(Double(max(candidate.durationMinutes, walkDurationMinutes)) * 0.2))
        let distanceDelta = abs(candidate.distanceKm - petWalk.distanceKm)
        let distanceThreshold = max(0.3, max(candidate.distanceKm, petWalk.distanceKm) * 0.18)
        let startsClose = abs(candidate.startDate.timeIntervalSince(petWalk.startDate)) <= 10 * 60
        return startsClose && durationDelta <= durationThreshold && distanceDelta <= distanceThreshold
    }

    private struct WorkoutSummaryRow: Identifiable {
        let id: String
        let title: String
        let type: WorkoutType
        let date: Date
        let durationMinutes: Int
        let distanceKm: Double
        let calories: Int
        let steps: Int
        let isHealthKit: Bool
        let isPetWalk: Bool
        let isMatched: Bool
        let sourceName: String
        let overlapText: String?
        let log: HumanWorkoutLog?
        let candidate: HealthKitWorkoutImportCandidate?
        let petWalk: HumanWorkoutPetWalkSnapshot?
        let matchedHealthKitCandidate: HealthKitWorkoutImportCandidate?

        var secondaryMetric: String {
            if distanceKm > 0.01 {
                return String(format: "%.1f km", distanceKm)
            }
            if calories > 0 {
                return "\(calories) kcal"
            }
            if steps > 0 {
                return "\(steps) steps"
            }
            return ""
        }

        static func local(
            _ log: HumanWorkoutLog,
            title: String,
            sourceName: String,
            isPetWalk: Bool,
            isMatched: Bool
        ) -> WorkoutSummaryRow {
            WorkoutSummaryRow(
                id: "local-\(log.id.uuidString)",
                title: title,
                type: log.workoutType,
                date: log.date,
                durationMinutes: log.durationMinutes,
                distanceKm: log.distanceKm,
                calories: log.calories,
                steps: log.steps,
                isHealthKit: log.sourceHealthKit,
                isPetWalk: isPetWalk,
                isMatched: isMatched,
                sourceName: sourceName,
                overlapText: nil,
                log: log,
                candidate: nil,
                petWalk: nil,
                matchedHealthKitCandidate: nil
            )
        }

        static func healthKitCandidate(
            _ candidate: HealthKitWorkoutImportCandidate,
            title: String,
            overlapText: String?,
            matchedPetWalk: HumanWorkoutPetWalkSnapshot?
        ) -> WorkoutSummaryRow {
            WorkoutSummaryRow(
                id: "candidate-\(candidate.healthKitWorkoutUUID)",
                title: title,
                type: candidate.type,
                date: candidate.startDate,
                durationMinutes: candidate.durationMinutes,
                distanceKm: candidate.distanceKm,
                calories: candidate.calories,
                steps: candidate.steps,
                isHealthKit: true,
                isPetWalk: matchedPetWalk != nil,
                isMatched: matchedPetWalk != nil,
                sourceName: candidate.sourceName,
                overlapText: overlapText,
                log: nil,
                candidate: candidate,
                petWalk: nil,
                matchedHealthKitCandidate: nil
            )
        }

        static func petWalkCandidate(
            _ walk: HumanWorkoutPetWalkSnapshot,
            title: String,
            sourceName: String,
            overlapText: String?,
            matchedHealthKitCandidate: HealthKitWorkoutImportCandidate?
        ) -> WorkoutSummaryRow {
            WorkoutSummaryRow(
                id: "pet-walk-\(walk.sourcePetWalkLogID)",
                title: title,
                type: .walking,
                date: walk.startDate,
                durationMinutes: walk.durationMinutes,
                distanceKm: walk.distanceKm,
                calories: matchedHealthKitCandidate?.calories ?? 0,
                steps: matchedHealthKitCandidate?.steps ?? 0,
                isHealthKit: matchedHealthKitCandidate != nil,
                isPetWalk: true,
                isMatched: matchedHealthKitCandidate != nil,
                sourceName: matchedHealthKitCandidate?.sourceName ?? sourceName,
                overlapText: overlapText,
                log: nil,
                candidate: nil,
                petWalk: walk,
                matchedHealthKitCandidate: matchedHealthKitCandidate
            )
        }
    }
}

private struct HumanWorkoutActivityRings: View {
    let snapshot: HumanWorkoutHealthSnapshot

    var body: some View {
        ZStack {
            ActivityRing(
                progress: progress(value: snapshot.activeEnergyKcal, goal: snapshot.moveGoalKcal),
                color: .goRed,
                lineWidth: 18,
                inset: 0
            )
            ActivityRing(
                progress: progress(value: snapshot.exerciseMinutes, goal: snapshot.exerciseGoalMinutes),
                color: .goPrimary,
                lineWidth: 18,
                inset: 25
            )
            ActivityRing(
                progress: progress(value: snapshot.standHours, goal: snapshot.standGoalHours),
                color: .goCardCyan,
                lineWidth: 18,
                inset: 50
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity rings")
    }

    private func progress(value: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(value) / Double(goal), 0), 1.25)
    }
}

private struct ActivityRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress > 1 {
                Circle()
                    .trim(from: 0, to: min(progress - 1, 0.25))
                    .stroke(color.opacity(0.72), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(inset)
    }
}

private struct ActivityRingMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct HumanWorkoutMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let tint: Color
    let points: [OhanaMinimalChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 36))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                if !unit.isEmpty {
                    Text(unit.uppercased())
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(tint)
                }
            }
            OhanaMinimalBarChart(
                points: points,
                tint: tint,
                showsLabels: false,
                maxBarHeight: 74,
                emptyBarColor: Color.ohanaControlFill.opacity(0.72)
            )
            .frame(height: 82)
            HStack {
                ForEach(["00", "06", "12", "18"], id: \.self) { label in
                    Text(label)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    if label != "18" { Spacer() }
                }
            }
        }
        .padding(14)
        .frame(minHeight: 210, alignment: .top)
        .workoutSummaryCard()
    }
}

private extension View {
    func workoutSummaryCard() -> some View {
        background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke.opacity(0.7), lineWidth: 1)
        }
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
