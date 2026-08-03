//
//  HumanHealthConditionsView.swift
//  Ohana
//
//  Route-scoped Human health condition tracking. Reads are deliberately
//  bounded; persistent mutations live in HumanHealthConditionCommandExecutor.
//

import SwiftData
import SwiftUI

struct HumanHealthConditionsView: View {
    let human: Human
    let showsCloseButton: Bool
    let onClose: () -> Void

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @State private var refreshToken = 0

    init(
        human: Human,
        showsCloseButton: Bool = false,
        onClose: @escaping () -> Void = {}
    ) {
        self.human = human
        self.showsCloseButton = showsCloseButton
        self.onClose = onClose
    }

    private var activeHumanID: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanID) }
    private var canViewMedication: Bool { !human.isPrivate(.medication, viewedBy: activeHumanID) }

    var body: some View {
        Group {
            if isPrivacyLocked {
                HumanHealthConditionsLockedView(human: human)
            } else {
                HumanHealthConditionsDataContainer(
                    human: human,
                    canViewMedication: canViewMedication,
                    refreshToken: refreshToken,
                    onRecordsChanged: { refreshToken += 1 }
                )
                .id("\(human.id.uuidString):\(canViewMedication)")
            }
        }
        .navigationTitle(L10n(AppLanguage.code).tr(zh: "健康状况", en: "Health Conditions", de: "Gesundheitszustände"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Label(
                            L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"),
                            systemImage: "xmark"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
                }
            }
        }
        .environment(\.locale, AppLanguage.effectiveLocale)
    }
}

private struct HumanHealthConditionsLockedView: View {
    let human: Human
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 18) {
                HumanModulePageHeader(
                    human: human,
                    title: l.tr(zh: "健康状况", en: "Health Conditions", de: "Gesundheitszustände"),
                    subtitle: l.tr(zh: "状态、症状与趋势", en: "Status, symptoms, and trends", de: "Status, Symptome und Trends"),
                    showsCloseButton: false,
                    onClose: {}
                )
                HumanModulePrivacyLockedView(
                    title: l.tr(zh: "健康记录已锁定", en: "Health records are locked", de: "Gesundheitsdaten sind gesperrt"),
                    message: l.tr(zh: "只有本人可以查看这些状态和趋势。", en: "Only the owner can view these states and trends.", de: "Nur die betroffene Person kann diese Einträge und Trends sehen.")
                )
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .accessibilityIdentifier("human-conditions-screen")
    }
}

private enum HumanHealthConditionsDataState: Equatable {
    case loading
    case loaded
    case failed
}

private struct HumanHealthConditionsDataContainer: View {
    let human: Human
    let canViewMedication: Bool
    let refreshToken: Int
    let onRecordsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var routeData = HumanHealthConditionsRouteData()
    @State private var dataState = HumanHealthConditionsDataState.loading
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var refreshFailed = false
    @State private var conditionPageCursors: [HumanHealthHistoryPageCursor?] = [nil]
    @State private var conditionPageIndex = 0
    @State private var conditionPageLoadTask: Task<Void, Never>?
    @State private var conditionPageLoadFailed = false

    var body: some View {
        Group {
            if routeData.hasLoaded {
                HumanHealthConditionsContentView(
                    human: human,
                    canViewMedication: canViewMedication,
                    isReadOnly: human.hasPassedAway,
                    conditions: routeData.conditions,
                    conditionSnapshots: routeData.conditionSnapshots,
                    analysisLimitedConditionIDs: routeData.analysisLimitedConditionIDs,
                    medicationAnalysisIncompleteConditionIDs: routeData.medicationAnalysisIncompleteConditionIDs,
                    medications: routeData.medications,
                    medicationLogs: routeData.medicationLogs,
                    metricLogs: routeData.metricLogs,
                    activeConditionCount: routeData.activeConditionCount,
                    sevenDayObservationCount: routeData.sevenDayObservationCount,
                    recentObservationCount: routeData.recentObservationCount,
                    conditionPageNumber: conditionPageIndex + 1,
                    hasNewerConditionPage: conditionPageIndex > 0,
                    hasOlderConditionPage: routeData.hasOlderConditions,
                    isLoadingConditionPage: conditionPageLoadTask != nil,
                    refreshFailed: refreshFailed,
                    conditionPageLoadFailed: conditionPageLoadFailed,
                    onRetryLoad: retryRouteDataLoad,
                    onLoadNewerConditions: loadNewerConditionPage,
                    onLoadOlderConditions: loadOlderConditionPage,
                    onRecordsChanged: onRecordsChanged
                )
            } else {
                HumanHealthConditionsRouteStatusView(
                    human: human,
                    state: dataState,
                    onRetry: retryRouteDataLoad
                )
            }
        }
        .onAppear { scheduleRouteDataLoad() }
        .onChange(of: refreshToken) { _, _ in
            scheduleRouteDataLoad(delayMilliseconds: 24, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
            conditionPageLoadTask?.cancel()
            conditionPageLoadTask = nil
        }
    }

    @MainActor
    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 24, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            do {
                routeData = try HumanHealthConditionsRouteData.load(
                    humanID: human.id,
                    canViewMedication: canViewMedication,
                    context: modelContext
                )
                dataState = .loaded
                refreshFailed = false
                conditionPageCursors = [nil]
                conditionPageIndex = 0
                conditionPageLoadFailed = false
            } catch {
                OhanaLog.warning(
                    "Human health conditions route load failed: \(error.localizedDescription)",
                    category: "HumanHealth"
                )
                if routeData.hasLoaded {
                    refreshFailed = true
                } else {
                    dataState = .failed
                }
            }
            dataLoadTask = nil
        }
    }

    @MainActor
    private func retryRouteDataLoad() {
        guard dataLoadTask == nil else { return }
        if !routeData.hasLoaded { dataState = .loading }
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
    }

    @MainActor
    private func loadOlderConditionPage() {
        guard let cursor = routeData.nextConditionCursor else { return }
        loadConditionPage(olderThan: cursor, targetIndex: conditionPageIndex + 1)
    }

    @MainActor
    private func loadNewerConditionPage() {
        guard conditionPageIndex > 0 else { return }
        let targetIndex = conditionPageIndex - 1
        loadConditionPage(olderThan: conditionPageCursors[targetIndex], targetIndex: targetIndex)
    }

    @MainActor
    private func loadConditionPage(
        olderThan cursor: HumanHealthHistoryPageCursor?,
        targetIndex: Int
    ) {
        guard conditionPageLoadTask == nil else { return }
        conditionPageLoadFailed = false
        conditionPageLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 0) {
            do {
                let page = try HumanHealthConditionHistoryQuery.page(
                    humanID: human.id,
                    olderThan: cursor,
                    limit: HumanHealthConditionsRouteData.conditionPageSize,
                    context: modelContext
                )
                try routeData.replaceConditionPage(
                    page,
                    humanID: human.id,
                    context: modelContext
                )
                if targetIndex == conditionPageCursors.count {
                    conditionPageCursors.append(cursor)
                } else if conditionPageCursors.indices.contains(targetIndex) {
                    conditionPageCursors[targetIndex] = cursor
                }
                conditionPageIndex = targetIndex
            } catch {
                conditionPageLoadFailed = true
                OhanaLog.warning(
                    "Human health condition page load failed: \(error.localizedDescription)",
                    category: "HumanHealth"
                )
            }
            conditionPageLoadTask = nil
        }
    }
}

private struct HumanHealthConditionsRouteStatusView: View {
    let human: Human
    let state: HumanHealthConditionsDataState
    let onRetry: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 18) {
                HumanModulePageHeader(
                    human: human,
                    title: l.tr(zh: "健康状况", en: "Health Conditions", de: "Gesundheitszustände"),
                    subtitle: l.tr(zh: "症状、状态与趋势追踪", en: "Symptoms, state, and trend tracking", de: "Symptome, Status und Trends"),
                    showsCloseButton: false,
                    onClose: {}
                )

                if state == .failed {
                    ContentUnavailableView {
                        Label(
                            l.tr(zh: "无法读取健康记录", en: "Health records couldn’t load", de: "Gesundheitsdaten konnten nicht geladen werden"),
                            systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                        )
                    } description: {
                        Text(l.tr(
                            zh: "记录仍保存在本机，请重试读取。",
                            en: "Your records remain on this device. Try loading them again.",
                            de: "Deine Einträge bleiben auf diesem Gerät. Versuche das Laden erneut."
                        ))
                    } actions: {
                        Button(l.tr(zh: "重试", en: "Try Again", de: "Erneut versuchen"), action: onRetry)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(l.tr(zh: "正在读取健康记录…", en: "Loading health records…", de: "Gesundheitsdaten werden geladen …"))
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .accessibilityIdentifier("human-conditions-screen")
    }
}

private enum HumanHealthConditionSheetDestination: Identifiable {
    case createCondition

    var id: String { "create-condition" }
}

private struct HumanHealthConditionsContentView: View {
    let human: Human
    let canViewMedication: Bool
    let isReadOnly: Bool
    let conditions: [HumanHealthCondition]
    let conditionSnapshots: [UUID: HumanHealthConditionTrendSnapshot]
    let analysisLimitedConditionIDs: Set<UUID>
    let medicationAnalysisIncompleteConditionIDs: Set<UUID>
    let medications: [HumanMedication]
    let medicationLogs: [HumanMedicationLog]
    let metricLogs: [HumanHealthMetricLog]
    let activeConditionCount: Int
    let sevenDayObservationCount: Int
    let recentObservationCount: Int
    let conditionPageNumber: Int
    let hasNewerConditionPage: Bool
    let hasOlderConditionPage: Bool
    let isLoadingConditionPage: Bool
    let refreshFailed: Bool
    let conditionPageLoadFailed: Bool
    let onRetryLoad: () -> Void
    let onLoadNewerConditions: () -> Void
    let onLoadOlderConditions: () -> Void
    let onRecordsChanged: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var sheetDestination: HumanHealthConditionSheetDestination?
    @AccessibilityFocusState private var focusedConditionID: UUID?

    private var l: L10n { L10n(appLanguage) }
    private var appLocale: Locale { AppLanguage.effectiveLocale }
    private var currentConditions: [HumanHealthCondition] {
        conditions.filter { $0.trackingStatus != .resolved }
    }
    private var endedConditions: [HumanHealthCondition] {
        conditions.filter { $0.trackingStatus == .resolved }
    }
    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        pageHeader
                            .id("human-condition-page-top")
                        if refreshFailed {
                            loadFailureNotice(
                                message: l.tr(
                                    zh: "刷新失败，当前仍显示上一次成功读取的记录。",
                                    en: "Refresh failed. The last successfully loaded records are still shown.",
                                    de: "Aktualisierung fehlgeschlagen. Die zuletzt erfolgreich geladenen Einträge bleiben sichtbar."
                                ),
                                retry: onRetryLoad
                            )
                        }
                        HumanPrivateDataNotice(human: human, field: .weight)
                        if isReadOnly {
                            memorialReadOnlyNotice
                        }
                        summaryStrip
                        analysisBoundaryCard
                        if !canViewMedication {
                            medicationPrivacyNotice
                        }

                        if conditions.isEmpty {
                            emptyState
                        } else {
                            if !currentConditions.isEmpty {
                                conditionSection(
                                    title: l.tr(zh: "正在追踪", en: "Tracking", de: "In Beobachtung"),
                                    conditions: currentConditions
                                )
                            }
                            if !endedConditions.isEmpty {
                                conditionSection(
                                    title: l.tr(zh: "已结束", en: "Ended", de: "Beendet"),
                                    conditions: endedConditions
                                )
                            }
                            conditionHistoryPager
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: conditionPageNumber) { _, newPage in
                    proxy.scrollTo("human-condition-page-top", anchor: .top)
                    focusedConditionID = currentConditions.first?.id ?? endedConditions.first?.id
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: l.tr(
                            zh: "已读取健康状况第 \(newPage) 页",
                            en: "Condition page \(newPage) loaded",
                            de: "Zustandsseite \(newPage) geladen"
                        )
                    )
                }
            }
        }
        .accessibilityIdentifier("human-conditions-screen")
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            if !isReadOnly {
                HumanModuleFloatingActionButton(
                    title: l.tr(zh: "添加状况", en: "Add condition", de: "Zustand hinzufügen"),
                    icon: "plus"
                ) {
                    sheetDestination = .createCondition
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .accessibilityIdentifier("human-condition-add-action")
                .padding(.trailing, 20)
                .padding(.vertical, 18)
            }
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .createCondition:
                HumanHealthConditionEditorSheet(
                    human: human,
                    condition: nil,
                    medications: medications,
                    canViewMedication: canViewMedication,
                    onSaved: onRecordsChanged,
                    onDeleted: onRecordsChanged
                )
            }
        }
        .onChange(of: conditionPageLoadFailed) { _, failed in
            guard failed else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: l.tr(
                    zh: "健康状况页面读取失败，当前页面已保留",
                    en: "Condition page load failed; the current page was preserved",
                    de: "Zustandsseite konnte nicht geladen werden; die aktuelle Seite bleibt erhalten"
                )
            )
        }
        .onChange(of: refreshFailed) { _, failed in
            guard failed else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: l.tr(
                    zh: "健康记录刷新失败，仍显示上一次成功读取的内容",
                    en: "Health records failed to refresh; the last successful content remains visible",
                    de: "Gesundheitsdaten konnten nicht aktualisiert werden; die zuletzt geladenen Inhalte bleiben sichtbar"
                )
            )
        }
    }

    private var pageHeader: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "健康状况", en: "Health Conditions", de: "Gesundheitszustände"),
            subtitle: l.tr(zh: "症状、状态与趋势追踪", en: "Symptoms, state, and trend tracking", de: "Symptome, Status und Trends"),
            showsCloseButton: false,
            onClose: {}
        ) {
            if !isReadOnly {
                HumanPrivacyToggleButton(human: human, field: .weight)
            }
        }
    }

    private var summaryStrip: some View {
        HumanModuleMetricStrip(metrics: [
            FeatureHubMetric(
                id: "conditions",
                title: l.tr(zh: "追踪中", en: "Tracking", de: "Aktiv"),
                value: "\(activeConditionCount)"
            ),
            FeatureHubMetric(
                id: "seven-day-observations",
                title: l.tr(zh: "近 7 天记录", en: "Logs in 7 days", de: "7-Tage-Einträge"),
                value: "\(sevenDayObservationCount)"
            ),
            FeatureHubMetric(
                id: "year-observations",
                title: l.tr(zh: "近 12 个月", en: "Past 12 months", de: "Letzte 12 Monate"),
                value: "\(recentObservationCount)"
            )
        ])
    }

    private var analysisBoundaryCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "waveform.path.ecg.rectangle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goBlue)
                .frame(width: 34, height: 34) // a11y: allow decorative summary glyph; card text carries meaning.
                .background(Color.goBlue.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "趋势来自你的记录", en: "Trends come from your logs", de: "Trends stammen aus deinen Einträgen"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "只做描述性汇总，不用于诊断，也不推断药物与状态之间的因果关系。",
                    en: "Descriptive summaries only—not diagnosis or proof that medication caused a change.",
                    de: "Nur beschreibende Zusammenfassungen—keine Diagnose oder Aussage zur Ursache durch Medikamente."
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.goBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var memorialReadOnlyNotice: some View {
        Label(
            l.tr(
                zh: "纪念模式仅保留历史查看，不能新增或修改健康记录。",
                en: "Memorial mode keeps history view-only; health records cannot be added or changed.",
                de: "Im Gedenkmodus bleibt der Verlauf schreibgeschützt; Gesundheitsdaten können nicht ergänzt oder geändert werden."
            ),
            systemImage: "lock.fill"
        )
        .font(OhanaFont.caption(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var medicationPrivacyNotice: some View {
        Label(
            l.tr(
                zh: "关联用药、服药完成率和用药观察已按隐私设置隐藏。",
                en: "Linked medications, completion, and medication observations are hidden by privacy settings.",
                de: "Verknüpfte Medikamente, Erfüllung und Medikamentenbeobachtungen sind durch die Datenschutzeinstellung ausgeblendet."
            ),
            systemImage: "pills.fill"
        )
        .font(OhanaFont.caption(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func loadFailureNotice(message: String, retry: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut"), action: retry)
                    .font(OhanaFont.caption(.black))
            }

            VStack(alignment: .leading, spacing: 9) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut"), action: retry)
                    .font(OhanaFont.caption(.black))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.goOrange.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    @ViewBuilder
    private var conditionHistoryPager: some View {
        if hasNewerConditionPage || hasOlderConditionPage || conditionPageLoadFailed {
            VStack(alignment: .leading, spacing: 10) {
                if conditionPageLoadFailed {
                    Label(
                        l.tr(
                            zh: "这一页没有成功读取，当前页内容未改变。",
                            en: "That page couldn’t load. The current page is unchanged.",
                            de: "Diese Seite konnte nicht geladen werden. Die aktuelle Seite bleibt unverändert."
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.goOrange.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        conditionPageButton(
                            title: l.tr(zh: "较新", en: "Newer", de: "Neuere"),
                            systemImage: "chevron.backward",
                            enabled: hasNewerConditionPage,
                            action: onLoadNewerConditions
                        )
                        Spacer(minLength: 8)
                        conditionPageLabel
                        Spacer(minLength: 8)
                        conditionPageButton(
                            title: l.tr(zh: "较早", en: "Older", de: "Ältere"),
                            systemImage: "chevron.forward",
                            enabled: hasOlderConditionPage,
                            action: onLoadOlderConditions
                        )
                    }

                    VStack(spacing: 10) {
                        conditionPageLabel
                        HStack(spacing: 10) {
                            conditionPageButton(
                                title: l.tr(zh: "较新", en: "Newer", de: "Neuere"),
                                systemImage: "chevron.backward",
                                enabled: hasNewerConditionPage,
                                action: onLoadNewerConditions
                            )
                            conditionPageButton(
                                title: l.tr(zh: "较早", en: "Older", de: "Ältere"),
                                systemImage: "chevron.forward",
                                enabled: hasOlderConditionPage,
                                action: onLoadOlderConditions
                            )
                        }
                    }
                }
            }
        }
    }

    private var conditionPageLabel: some View {
        Group {
            if isLoadingConditionPage {
                ProgressView()
                    .accessibilityLabel(l.tr(
                        zh: "正在读取健康状况页面",
                        en: "Loading condition page",
                        de: "Zustandsseite wird geladen"
                    ))
            } else {
                Text(l.tr(zh: "健康状况第 \(conditionPageNumber) 页", en: "Condition page \(conditionPageNumber)", de: "Zustandsseite \(conditionPageNumber)"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func conditionPageButton(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled || isLoadingConditionPage)
    }

    private func conditionSection(
        title: String,
        conditions: [HumanHealthCondition]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            ForEach(conditions) { condition in
                NavigationLink {
                    HumanHealthConditionDetailView(
                        human: human,
                        condition: condition,
                        canViewMedication: canViewMedication,
                        isReadOnly: isReadOnly,
                        observations: [],
                        initialSnapshot: conditionSnapshots[condition.id] ?? .empty,
                        recentObservationCount: conditionSnapshots[condition.id]?.totalCount ?? 0,
                        analysisIsLimited: analysisLimitedConditionIDs.contains(condition.id),
                        medicationAnalysisIsIncomplete: medicationAnalysisIncompleteConditionIDs.contains(condition.id),
                        medications: medications,
                        medicationLogs: medicationLogs,
                        metricLogs: metricLogs,
                        onRecordsChanged: onRecordsChanged
                    )
                } label: {
                    conditionRow(condition)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityFocused($focusedConditionID, equals: condition.id)
                .accessibilityIdentifier("human-condition-row-\(condition.id.uuidString)")
            }
        }
    }

    private func conditionRow(_ condition: HumanHealthCondition) -> some View {
        let snapshot = conditionSnapshots[condition.id] ?? .empty
        let category = condition.category

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: category.systemImage).accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(category.tint)
                .frame(width: 44, height: 44)
                .background(category.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    conditionRowIdentity(condition, snapshot: snapshot)
                    Spacer(minLength: 4)
                    conditionSeverity(
                        snapshot,
                        category: category,
                        isLimited: analysisLimitedConditionIDs.contains(condition.id)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    conditionRowIdentity(condition, snapshot: snapshot)
                    conditionSeverity(
                        snapshot,
                        category: category,
                        isLimited: analysisLimitedConditionIDs.contains(condition.id)
                    )
                }
            }

            Image(systemName: "chevron.forward").accessibilityHidden(true)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .padding(13)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(snapshot.latestSeverity.map { "\($0) / 10" } ?? l.tr(zh: "暂无状态记录", en: "No status logs", de: "Keine Status-Einträge"))
    }

    private func conditionRowIdentity(
        _ condition: HumanHealthCondition,
        snapshot: HumanHealthConditionTrendSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    conditionName(condition)
                    conditionStatus(condition)
                }
                VStack(alignment: .leading, spacing: 5) {
                    conditionName(condition)
                    conditionStatus(condition)
                }
            }
            Text(conditionRowSubtitle(condition, snapshot: snapshot))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func conditionName(_ condition: HumanHealthCondition) -> some View {
        Text(condition.name)
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func conditionStatus(_ condition: HumanHealthCondition) -> some View {
        Text(condition.trackingStatus.displayName(l))
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(condition.trackingStatus.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(condition.trackingStatus.tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func conditionSeverity(
        _ snapshot: HumanHealthConditionTrendSnapshot,
        category: HumanHealthConditionCategory,
        isLimited: Bool
    ) -> some View {
        if let severity = snapshot.latestSeverity {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(severity)/10")
                    .font(OhanaFont.metric(size: 20))
                    .foregroundStyle(category.tint)
                Text(isLimited
                    ? l.tr(zh: "最近 1,024 条", en: "Latest 1,024", de: "Neueste 1.024")
                    : snapshot.severityTrend.displayName(l))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(snapshot.severityTrend.tint)
                    .lineLimit(2)
            }
        }
    }

    private func conditionRowSubtitle(
        _ condition: HumanHealthCondition,
        snapshot: HumanHealthConditionTrendSnapshot
    ) -> String {
        let category = condition.category.displayName(l)
        guard let latestDate = snapshot.latestRecordedAt else {
            return l.tr(zh: "\(category) · 尚未记录状态", en: "\(category) · No state logs", de: "\(category) · Keine Status-Einträge")
        }
        let formattedDate = latestDate.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: appLocale
        ))
        return l.tr(
            zh: "\(category) · 最近 \(formattedDate)",
            en: "\(category) · Latest \(formattedDate)",
            de: "\(category) · Zuletzt \(formattedDate)"
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cross.case.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 62, height: 62)
                .background(Color.goTeal.opacity(0.14), in: Circle())
            Text(isReadOnly
                ? l.tr(zh: "没有历史健康状况", en: "No health condition history", de: "Kein Verlauf zu Gesundheitszuständen")
                : l.tr(zh: "建立第一份健康状况档案", en: "Create the first health condition", de: "Ersten Gesundheitszustand anlegen"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(isReadOnly
                ? l.tr(
                    zh: "此前没有保存相关记录。",
                    en: "No related records were saved previously.",
                    de: "Zuvor wurden keine entsprechenden Einträge gespeichert."
                )
                : l.tr(
                    zh: "可追踪心理与情绪、甲状腺、过敏、毛发与头皮等长期或反复变化。",
                    en: "Track recurring or long-term changes in mental health, thyroid, allergy, hair and scalp, and more.",
                    de: "Verfolge wiederkehrende oder langfristige Veränderungen bei Psyche, Schilddrüse, Allergien, Haar und Kopfhaut."
                ))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }
}
