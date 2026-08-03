import Combine
import SwiftData
import SwiftUI
import UIKit

nonisolated enum HumanHealthReportDataPhase: Equatable, Sendable {
    case loading
    case loaded
    case failed
}

nonisolated struct HumanHealthReportDataState: Equatable, Sendable {
    var phase: HumanHealthReportDataPhase = .loading
    var isRefreshing = false
    var refreshFailed = false
    var needsReload = false

    var hasSuccessfulSnapshot: Bool { phase == .loaded }
}

nonisolated enum HumanHealthReportDataEvent: Equatable, Sendable {
    case loadStarted
    case loadSucceeded
    case loadFailed
    case loadCancelled
}

nonisolated enum HumanHealthReportDataStateReducer {
    static func reduce(
        _ state: HumanHealthReportDataState,
        event: HumanHealthReportDataEvent
    ) -> HumanHealthReportDataState {
        var next = state
        switch event {
        case .loadStarted:
            next.needsReload = false
            if state.hasSuccessfulSnapshot {
                next.isRefreshing = true
            } else {
                next.phase = .loading
                next.isRefreshing = false
                next.refreshFailed = false
            }
        case .loadSucceeded:
            next.phase = .loaded
            next.isRefreshing = false
            next.refreshFailed = false
            next.needsReload = false
        case .loadFailed:
            next.isRefreshing = false
            next.needsReload = false
            if state.hasSuccessfulSnapshot {
                next.phase = .loaded
                next.refreshFailed = true
            } else {
                next.phase = .failed
                next.refreshFailed = false
            }
        case .loadCancelled:
            next.isRefreshing = false
            next.needsReload = true
        }
        return next
    }
}

struct HumanHealthReportView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var routeData = HumanHealthReportRouteData()
    @State private var dataState = HumanHealthReportDataState()
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var olderPageLoadTask: Task<Void, Never>?
    @State private var olderPageLoadFailed = false
    @State private var reloadRequestedWhileLoading = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Group {
            switch dataState.phase {
            case .loaded:
                HumanHealthReportContentView(
                    human: human,
                    myReports: routeData.reports,
                    hasMoreReports: routeData.hasMoreReports,
                    isLoadingOlderReports: olderPageLoadTask != nil,
                    olderPageLoadFailed: olderPageLoadFailed,
                    refreshFailed: dataState.refreshFailed,
                    onRetryLoad: retryRouteDataLoad,
                    onLoadOlderReports: loadOlderReports
                )
            case .loading, .failed:
                HumanHealthReportRouteStatusView(
                    phase: dataState.phase,
                    onRetry: retryRouteDataLoad
                )
            }
        }
        .navigationTitle(l.tr(zh: "🏥 身体检测报告", en: "🏥 Health Reports", de: "🏥 Gesundheitsberichte"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduleRouteDataLoad(force: dataState.needsReload)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            cancelRouteDataLoad()
        }
    }

    @MainActor
    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || dataState.needsReload || !dataState.hasSuccessfulSnapshot else { return }
        guard dataLoadTask == nil, olderPageLoadTask == nil else {
            if force { reloadRequestedWhileLoading = true }
            return
        }
        dataState = HumanHealthReportDataStateReducer.reduce(dataState, event: .loadStarted)
        let humanID = human.id
        let container = modelContext.container
        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else { return }
            do {
                let reference = try await HumanHealthReportRouteDataActor(modelContainer: container)
                    .load(humanID: humanID)
                try Task.checkCancellation()
                routeData = HumanHealthReportRouteData(reference: reference, context: modelContext)
                dataState = HumanHealthReportDataStateReducer.reduce(dataState, event: .loadSucceeded)
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Human health report route data fetch failed: \(error.localizedDescription)",
                    category: "HumanHealth"
                )
                dataState = HumanHealthReportDataStateReducer.reduce(dataState, event: .loadFailed)
                announceLoadFailure(isRefreshFailure: dataState.refreshFailed)
            }
            dataLoadTask = nil
            runDeferredReloadIfNeeded()
        }
    }

    @MainActor
    private func retryRouteDataLoad() {
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
    }

    @MainActor
    private func cancelRouteDataLoad() {
        if let dataLoadTask {
            dataLoadTask.cancel()
            self.dataLoadTask = nil
            dataState = HumanHealthReportDataStateReducer.reduce(dataState, event: .loadCancelled)
        }
        olderPageLoadTask?.cancel()
        olderPageLoadTask = nil
        reloadRequestedWhileLoading = false
    }

    @MainActor
    private func loadOlderReports() {
        guard dataLoadTask == nil,
              olderPageLoadTask == nil,
              let cursor = routeData.nextCursor else { return }
        olderPageLoadFailed = false
        let humanID = human.id
        let container = modelContext.container
        olderPageLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            do {
                let reference = try await HumanHealthReportRouteDataActor(modelContainer: container).loadPage(
                    humanID: humanID,
                    olderThan: cursor
                )
                try Task.checkCancellation()
                let page = HumanHealthReportPage(reference: reference, context: modelContext)
                routeData.append(page)
            } catch is CancellationError {
                return
            } catch {
                olderPageLoadFailed = true
                OhanaLog.warning(
                    "Older human health report page failed: \(error.localizedDescription)",
                    category: "HumanHealth"
                )
            }
            olderPageLoadTask = nil
            runDeferredReloadIfNeeded()
        }
    }

    @MainActor
    private func runDeferredReloadIfNeeded() {
        guard reloadRequestedWhileLoading else { return }
        reloadRequestedWhileLoading = false
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
    }

    @MainActor
    private func announceLoadFailure(isRefreshFailure: Bool) {
        UIAccessibility.post(
            notification: .announcement,
            argument: isRefreshFailure
                ? l.tr(
                    zh: "健康报告刷新失败，仍显示上一次成功读取的内容",
                    en: "Health reports failed to refresh; the last successful content remains visible",
                    de: "Gesundheitsberichte konnten nicht aktualisiert werden; die zuletzt geladenen Inhalte bleiben sichtbar"
                )
                : l.tr(
                    zh: "健康报告读取失败，可重试",
                    en: "Health reports failed to load. You can retry",
                    de: "Gesundheitsberichte konnten nicht geladen werden. Du kannst es erneut versuchen"
                )
        )
    }
}

struct HumanHealthReportLinkedMetricsView: View {
    private static let presentationLimit = 100

    let humanID: UUID
    let reportID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var linkedLogs: [HumanHealthMetricLog] = []
    @State private var isTruncated = false
    @State private var dataPhase: HumanHealthReportDataPhase = .loading
    @State private var reloadGeneration = 0

    private var l: L10n { L10n(appLanguage) }
    private var visibleLogs: [HumanHealthMetricLog] {
        Array(linkedLogs.prefix(Self.presentationLimit))
    }
    init(humanID: UUID, reportID: UUID) {
        self.humanID = humanID
        self.reportID = reportID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                l.tr(zh: "本次导入指标", en: "Imported results", de: "Importierte Werte"),
                systemImage: "list.bullet.clipboard.fill"
            )
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)

            if dataPhase == .loading {
                ProgressView()
                    .tint(Color.goTeal)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityLabel(l.tr(
                        zh: "正在读取关联指标",
                        en: "Loading linked results",
                        de: "Verknüpfte Werte werden geladen"
                    ))
            } else if dataPhase == .failed {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "关联指标读取失败。已保存的数据没有被更改。",
                        en: "Linked results could not be loaded. Your saved data was not changed.",
                        de: "Verknüpfte Werte konnten nicht geladen werden. Deine gespeicherten Daten wurden nicht geändert.",
                        es: "No se pudieron cargar los resultados vinculados. Tus datos guardados no se modificaron.",
                        pt: "Não foi possível carregar os resultados vinculados. Seus dados salvos não foram alterados.",
                        fr: "Impossible de charger les résultats liés. Vos données enregistrées n’ont pas été modifiées.",
                        ja: "関連する結果を読み込めませんでした。保存済みのデータは変更されていません。",
                        ko: "연결된 결과를 불러오지 못했습니다. 저장된 데이터는 변경되지 않았습니다.",
                        it: "Impossibile caricare i risultati collegati. I dati salvati non sono stati modificati."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        reloadGeneration &+= 1
                    } label: {
                        Label(
                            l.tr(
                                zh: "重试", en: "Retry", de: "Erneut versuchen",
                                es: "Reintentar", pt: "Tentar novamente", fr: "Réessayer",
                                ja: "再試行", ko: "다시 시도", it: "Riprova"
                            ),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.goTeal)
                    .accessibilityIdentifier("human-health-report-linked-metrics-load-retry-action")
                }
                .accessibilityIdentifier("human-health-report-linked-metrics-load-failed-state")
            } else if visibleLogs.isEmpty {
                Text(l.tr(
                    zh: "这份扫描报告没有保留关联指标。原图与 OCR 全文不会长期保存。",
                    en: "No linked results are retained for this scanned report. The source image and full OCR text are not stored long term.",
                    de: "Für diesen gescannten Bericht sind keine verknüpften Werte gespeichert. Quellbild und vollständiger OCR-Text werden nicht dauerhaft aufbewahrt."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(visibleLogs.enumerated()), id: \.element.id) { index, log in
                    if index > 0 { Divider() }
                    linkedMetricRow(log)
                }
                Text(l.tr(
                    zh: "这里保留已确认的数值、单位、报告参考范围与原始标记；原图和 OCR 全文不会长期保存。",
                    en: "Confirmed values, units, report ranges, and source flags are retained here; the source image and full OCR text are not stored long term.",
                    de: "Bestätigte Werte, Einheiten, Berichtsbereiche und Originalmarkierungen bleiben hier erhalten; Quellbild und vollständiger OCR-Text werden nicht dauerhaft gespeichert."
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            if isTruncated {
                Text(l.tr(
                    zh: "仅显示前 \(Self.presentationLimit) 项关联指标；这份报告的指标列表未完整载入。",
                    en: "Showing the first \(Self.presentationLimit) linked results; this report's result list is incomplete.",
                    de: "Es werden die ersten \(Self.presentationLimit) verknüpften Werte angezeigt; die Liste ist unvollständig."
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.goOrange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityIdentifier("human-health-report-linked-metrics")
        .task(id: linkedMetricLoadID) {
            await loadLinkedMetrics()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { _ in
            reloadGeneration &+= 1
        }
    }

    private var linkedMetricLoadID: String {
        "\(humanID.uuidString):\(reportID.uuidString):\(reloadGeneration)"
    }

    @MainActor
    private func loadLinkedMetrics() async {
        if linkedLogs.isEmpty {
            dataPhase = .loading
        }
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 96)
        guard !Task.isCancelled else { return }
        do {
            let reference = try await HumanHealthReportRouteDataActor(modelContainer: modelContext.container)
                .linkedMetrics(
                    humanID: humanID,
                    reportID: reportID,
                    limit: Self.presentationLimit
                )
            try Task.checkCancellation()
            linkedLogs = reference.recordModelIDs.compactMap {
                modelContext.model(for: $0) as? HumanHealthMetricLog
            }
            isTruncated = reference.isTruncated
            dataPhase = .loaded
        } catch is CancellationError {
            return
        } catch {
            if linkedLogs.isEmpty {
                dataPhase = .failed
            }
            OhanaLog.warning(
                "Linked Human health metrics fetch failed: \(error.localizedDescription)",
                category: "HumanHealth"
            )
        }
    }

    private func linkedMetricRow(_ log: HumanHealthMetricLog) -> some View {
        let metric = HealthMetricCatalog.metric(forKey: log.metricKey)
        let unit = metric?.unit(for: log.unitCode)
        let title = metric?.displayName(l)
            ?? log.sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = unit?.formattedValue(log.value)
            ?? "\(log.value.formatted()) \(log.unitCode)"

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.isEmpty ? log.metricKey : title)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .multilineTextAlignment(.trailing)
            }
            HStack(spacing: 8) {
                Text(reportedFlagText(log.reportedFlag))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(log.reportedFlag == .unknown ? Color.ohanaSecondaryText : Color.goOrange)
                Text(referenceText(log, unit: unit))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func reportedFlagText(_ flag: HumanHealthMetricReportedFlag) -> String {
        switch flag {
        case .low: l.tr(zh: "报告标记：低", en: "Report flag: Low", de: "Berichtsmarkierung: Niedrig")
        case .normal: l.tr(zh: "报告标记：正常", en: "Report flag: Normal", de: "Berichtsmarkierung: Normal")
        case .high: l.tr(zh: "报告标记：高", en: "Report flag: High", de: "Berichtsmarkierung: Hoch")
        case .unknown: l.tr(zh: "报告未提供结构化标记", en: "No structured report flag", de: "Keine strukturierte Berichtsmarkierung")
        }
    }

    private func referenceText(_ log: HumanHealthMetricLog, unit: HealthMetricUnit?) -> String {
        let rawText = log.referenceRangeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawText.isEmpty {
            return l.tr(zh: "报告参考：\(rawText)", en: "Report range: \(rawText)", de: "Berichtsbereich: \(rawText)")
        }
        let suffix = unit.map { " \($0.label)" } ?? ""
        switch (log.referenceLow, log.referenceHigh) {
        case let (.some(low), .some(high)):
            return l.tr(zh: "报告参考：\(low.formatted())–\(high.formatted())\(suffix)", en: "Report range: \(low.formatted())–\(high.formatted())\(suffix)", de: "Berichtsbereich: \(low.formatted())–\(high.formatted())\(suffix)")
        case let (.some(low), .none):
            return l.tr(zh: "报告参考：≥ \(low.formatted())\(suffix)", en: "Report range: ≥ \(low.formatted())\(suffix)", de: "Berichtsbereich: ≥ \(low.formatted())\(suffix)")
        case let (.none, .some(high)):
            return l.tr(zh: "报告参考：≤ \(high.formatted())\(suffix)", en: "Report range: ≤ \(high.formatted())\(suffix)", de: "Berichtsbereich: ≤ \(high.formatted())\(suffix)")
        case (.none, .none):
            return l.tr(zh: "报告未提供参考范围", en: "No report range provided", de: "Kein Berichtsbereich angegeben")
        }
    }
}

private struct HumanHealthReportRouteStatusView: View {
    let phase: HumanHealthReportDataPhase
    let onRetry: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            switch phase {
            case .loading:
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.goTeal)
                    Text(l.tr(
                        zh: "正在读取健康报告…",
                        en: "Loading health reports…",
                        de: "Gesundheitsberichte werden geladen …"
                    ))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("human-health-report-loading-state")
            case .failed:
                ContentUnavailableView {
                    Label(
                        l.tr(
                            zh: "无法读取健康报告",
                            en: "Health reports unavailable",
                            de: "Gesundheitsberichte nicht verfügbar"
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                } description: {
                    Text(l.tr(
                        zh: "报告暂时无法读取。请重试；成功读取前不会显示空记录状态。",
                        en: "The reports could not be loaded. Try again; an empty state appears only after a successful load.",
                        de: "Die Berichte konnten nicht geladen werden. Versuche es erneut; ein leerer Zustand erscheint erst nach erfolgreichem Laden."
                    ))
                } actions: {
                    Button(action: onRetry) {
                        Label(
                            l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.goTeal)
                    .accessibilityIdentifier("human-health-report-load-retry-action")
                }
                .accessibilityIdentifier("human-health-report-load-failed-state")
            case .loaded:
                EmptyView()
            }
        }
    }
}
