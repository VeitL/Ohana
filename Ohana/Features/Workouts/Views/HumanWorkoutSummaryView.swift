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
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var healthManager = HumanHealthKitManager()
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showAddSheet = false
    @State private var petWalkSnapshots: [HumanWorkoutPetWalkSnapshot] = []

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.workout, viewedBy: activeHumanId) }
    private var sortedLogs: [HumanWorkoutLog] { human.workoutLogs.sorted { $0.date > $1.date } }
    @MainActor private var summaryRows: [WorkoutSummaryRow] {
        let liveHealthKitIDs = Set(healthManager.recentWorkouts.map(\.healthKitWorkoutUUID))
        let livePetWalkIDs = Set(petWalkSnapshots.map(\.sourcePetWalkLogID))
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
            return WorkoutSummaryRow.petWalk(
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
        let healthRows = healthManager.recentWorkouts
            .filter { overlappingPetWalk(for: $0) == nil }
            .map { workout in
                WorkoutSummaryRow.healthKit(
                    workout,
                    title: workout.type.localizedTitle(l)
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
                    Task { await refreshHealthDataIfAvailable() }
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
                if showsHealthSetupAction {
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
                }

                Button {
                    Task { await refreshHealthDataIfAvailable() }
                } label: {
                    Image(systemName: "arrow.clockwise").accessibilityHidden(true)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 48, height: 48)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(healthManager.isLoading || healthManager.authorizationStatus == .notAvailable)
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
                HumanWorkoutActivityRings(snapshot: healthManager.snapshot, l: l)
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

            if let activityGoalStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(activityGoalStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-activity-goal-status")
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

            if let recentWorkoutsStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(recentWorkoutsStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-recent-status")
            }

            if summaryRows.isEmpty {
                VStack(spacing: 8) {
                    if healthManager.isLoading, healthManager.recentWorkoutsStatus == .notLoaded {
                        ProgressView()
                            .tint(Color.goPrimary)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "figure.run.circle").accessibilityHidden(true)
                            .font(OhanaFont.metric(size: 34))
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    Text(recentWorkoutsEmptyText)
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
            }
            .accessibilityElement(children: .combine)

            rowAction(row)
        }
        .padding(.vertical, 10)
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
        if let log = row.log, !row.isHealthKit, !row.isPetWalk {
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
        case .accessRequested:
            l.tr(zh: "Apple Health 已设置", en: "Apple Health Set Up", de: "Apple Health eingerichtet")
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
            l.tr(zh: "读取步数、距离、活动能量、活动目标和运动记录，只用于此成员的本地页面。", en: "Read steps, distance, active energy, activity goals, and workouts for this member’s local screen.", de: "Liest Schritte, Distanz, Aktivenergie, Aktivitätsziele und Trainings für diese lokale Ansicht.")
        case .accessRequested:
            l.tr(zh: "页面直接显示 Apple Health 当前允许读取的数据；拒绝的单项会显示为无数据。", en: "This screen shows data Apple Health currently allows; denied types appear as no data.", de: "Diese Ansicht zeigt aktuell erlaubte Apple-Health-Daten; verweigerte Typen erscheinen ohne Daten.")
        case .unknown:
            l.tr(zh: "点按刷新，Ohana 会重新检查可读取的数据。", en: "Refresh to check readable data again.", de: "Aktualisiere, um lesbare Daten erneut zu prüfen.")
        case let .failed(message):
            message
        }
    }

    private var connectionButtonTitle: String {
        switch healthManager.authorizationStatus {
        case .notAvailable:
            l.tr(zh: "不可用", en: "Unavailable", de: "Nicht verfügbar")
        default:
            l.tr(zh: "设置", en: "Set Up", de: "Einrichten")
        }
    }

    private var showsHealthSetupAction: Bool {
        switch healthManager.authorizationStatus {
        case .notDetermined, .unknown, .failed:
            true
        case .notAvailable, .accessRequested:
            false
        }
    }

    @MainActor private var recentWorkoutsCountText: String {
        l.tr(
            zh: "\(summaryRows.count) 项活动",
            en: "\(summaryRows.count) activities",
            de: "\(summaryRows.count) Aktivitäten"
        )
    }

    private var recentWorkoutsStatusText: String? {
        guard case .failed = healthManager.recentWorkoutsStatus else { return nil }
        return l.tr(
            zh: "Apple Health 最近运动读取失败。请刷新重试；Ohana 手动记录不受影响。",
            en: "Recent Apple Health workouts could not be read. Refresh to retry; Ohana manual records are unaffected.",
            de: "Letzte Apple-Health-Trainings konnten nicht gelesen werden. Aktualisiere erneut; manuelle Ohana-Einträge bleiben erhalten."
        )
    }

    private var recentWorkoutsEmptyText: String {
        if healthManager.isLoading, healthManager.recentWorkoutsStatus == .notLoaded {
            return l.tr(zh: "正在读取运动记录…", en: "Loading workouts…", de: "Trainings werden geladen…")
        }
        switch healthManager.recentWorkoutsStatus {
        case .noData:
            return l.tr(
                zh: "最近没有可读取的运动记录",
                en: "No readable recent workouts",
                de: "Keine lesbaren letzten Trainings"
            )
        case .failed:
            return l.tr(zh: "还没有 Ohana 手动运动记录", en: "No manual Ohana workouts yet", de: "Noch keine manuellen Ohana-Trainings")
        case .notLoaded, .available:
            return l.tr(zh: "还没有运动记录", en: "No workouts yet", de: "Noch keine Trainings")
        }
    }

    private var moveMetricText: String {
        let snapshot = healthManager.snapshot
        if snapshot.moveMode == .moveTime {
            if snapshot.moveGoal > 0 {
                return "\(snapshot.moveValue)/\(snapshot.moveGoal) min"
            }
            return "\(snapshot.moveValue) min"
        }
        if snapshot.moveGoal > 0 {
            return "\(snapshot.moveValue)/\(snapshot.moveGoal) kcal"
        }
        return "\(snapshot.moveValue) kcal"
    }

    private var activityGoalStatusText: String? {
        switch healthManager.activitySummaryStatus {
        case .notLoaded:
            nil
        case .noData:
            l.tr(
                zh: "今天没有可读取的活动目标。请在 Apple Health 中检查 Ohana 的“活动”读取权限。",
                en: "No activity goals are readable today. Check Ohana’s Activity access in Apple Health.",
                de: "Heute sind keine Aktivitätsziele lesbar. Prüfe Ohanas Aktivitätszugriff in Apple Health."
            )
        case .failed:
            l.tr(
                zh: "活动目标读取失败；今日数值仍会显示，请点按刷新重试。",
                en: "Activity goals could not be read. Today’s values remain visible; refresh to retry.",
                de: "Aktivitätsziele konnten nicht gelesen werden. Heutige Werte bleiben sichtbar; aktualisiere erneut."
            )
        case .available:
            switch healthManager.snapshot.activityGoalAvailability {
            case .complete:
                nil
            case .partial:
                l.tr(
                    zh: "Apple Health 只提供了部分目标；已有目标的圆环仍按真实进度显示。",
                    en: "Apple Health provided only some goals; available rings still show real progress.",
                    de: "Apple Health lieferte nur einige Ziele; verfügbare Ringe zeigen den echten Fortschritt."
                )
            case .unavailable:
                l.tr(
                    zh: "Apple Health 未提供活动目标；今日数值仍会显示。",
                    en: "Apple Health did not provide activity goals; today’s values remain visible.",
                    de: "Apple Health lieferte keine Aktivitätsziele; heutige Werte bleiben sichtbar."
                )
            }
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
        await refreshHealthDataIfAvailable()
    }

    private func loadPetWalkSnapshots() {
        petWalkSnapshots = HumanWorkoutPetWalkSnapshotBuilder.snapshots(for: human, context: modelContext)
    }

    private func requestHealthAccess() async {
        await healthManager.requestReadAuthorization()
    }

    private func refreshHealthDataIfAvailable() async {
        switch healthManager.authorizationStatus {
        case .accessRequested, .unknown:
            await healthManager.loadTodaySummary()
            _ = await healthManager.loadRecentWorkouts()
        case .failed:
            await healthManager.refreshAuthorizationStatus()
        case .notAvailable, .notDetermined:
            break
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

    private func overlappingHealthKitWorkout(for walk: HumanWorkoutPetWalkSnapshot) -> HumanHealthKitWorkoutSnapshot? {
        healthManager.recentWorkouts.first { workout in
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
                log: log
            )
        }

        static func healthKit(_ workout: HumanHealthKitWorkoutSnapshot, title: String) -> WorkoutSummaryRow {
            WorkoutSummaryRow(
                id: "healthkit-\(workout.healthKitWorkoutUUID)",
                title: title,
                type: workout.type,
                date: workout.startDate,
                durationMinutes: workout.durationMinutes,
                distanceKm: workout.distanceKm,
                calories: workout.calories,
                steps: workout.steps,
                isHealthKit: true,
                isPetWalk: false,
                isMatched: false,
                sourceName: workout.sourceName,
                overlapText: nil,
                log: nil
            )
        }

        static func petWalk(
            _ walk: HumanWorkoutPetWalkSnapshot,
            title: String,
            sourceName: String,
            overlapText: String?,
            matchedHealthKitWorkout: HumanHealthKitWorkoutSnapshot?
        ) -> WorkoutSummaryRow {
            WorkoutSummaryRow(
                id: "pet-walk-\(walk.sourcePetWalkLogID)",
                title: title,
                type: .walking,
                date: walk.startDate,
                durationMinutes: walk.durationMinutes,
                distanceKm: walk.distanceKm,
                calories: matchedHealthKitWorkout?.calories ?? 0,
                steps: matchedHealthKitWorkout?.steps ?? 0,
                isHealthKit: matchedHealthKitWorkout != nil,
                isPetWalk: true,
                isMatched: matchedHealthKitWorkout != nil,
                sourceName: matchedHealthKitWorkout?.sourceName ?? sourceName,
                overlapText: overlapText,
                log: nil
            )
        }
    }
}

private struct HumanWorkoutActivityRings: View {
    let snapshot: HumanWorkoutHealthSnapshot
    let l: L10n

    var body: some View {
        ZStack {
            ActivityRing(
                progress: progress(value: snapshot.moveValue, goal: snapshot.moveGoal),
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
        .accessibilityLabel(l.tr(zh: "活动环", en: "Activity rings", de: "Aktivitätsringe"))
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("human-workout-activity-rings")
    }

    private func progress(value: Int, goal: Int) -> Double? {
        guard goal > 0 else { return nil }
        return min(max(Double(value) / Double(goal), 0), 1.25)
    }

    private var accessibilityValue: String {
        let moveUnit = snapshot.moveMode == .moveTime ? minuteUnit : kilocalorieUnit
        let move = metricAccessibilityValue(value: snapshot.moveValue, goal: snapshot.moveGoal, unit: moveUnit)
        let exercise = metricAccessibilityValue(
            value: snapshot.exerciseMinutes,
            goal: snapshot.exerciseGoalMinutes,
            unit: minuteUnit
        )
        let stand = metricAccessibilityValue(value: snapshot.standHours, goal: snapshot.standGoalHours, unit: hourUnit)
        return l.tr(
            zh: "活动 \(move)，锻炼 \(exercise)，站立 \(stand)",
            en: "Move \(move), exercise \(exercise), stand \(stand)",
            de: "Bewegen \(move), Training \(exercise), Stehen \(stand)"
        )
    }

    private func metricAccessibilityValue(value: Int, goal: Int, unit: String) -> String {
        guard goal > 0 else {
            return l.tr(
                zh: "\(value) \(unit)，目标不可用",
                en: "\(value) \(unit), goal unavailable",
                de: "\(value) \(unit), Ziel nicht verfügbar"
            )
        }
        return "\(value)/\(goal) \(unit)"
    }

    private var minuteUnit: String {
        l.tr(zh: "分钟", en: "minutes", de: "Minuten")
    }

    private var hourUnit: String {
        l.tr(zh: "小时", en: "hours", de: "Stunden")
    }

    private var kilocalorieUnit: String {
        l.tr(zh: "千卡", en: "kilocalories", de: "Kilokalorien")
    }
}

private struct ActivityRing: View {
    let progress: Double?
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(progress == nil ? 0.09 : 0.16), lineWidth: lineWidth)
            if let progress {
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
            } else {
                Circle()
                    .stroke(
                        color.opacity(0.34),
                        style: StrokeStyle(lineWidth: max(2, lineWidth * 0.22), lineCap: .round, dash: [1, 7])
                    )
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
