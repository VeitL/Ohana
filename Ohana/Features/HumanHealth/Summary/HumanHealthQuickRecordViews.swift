import SwiftData
import SwiftUI

// Route-scoped reads stay on the main actor; these forms reuse the domain editors.
struct HumanMetricQuickRecordView: View {
    let human: Human
    let onSaved: (String) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""
    @State private var query = ""
    @State private var recentKeys: [String] = []
    @State private var hasLoaded = false
    @State private var failed = false
    @State private var selection: MetricSelection?
    private var l: L10n { L10n(appLanguage) }
    private var isLocked: Bool { human.isPrivate(.weight, viewedBy: UUID(uuidString: activeHumanIDRaw)) }

    private struct MetricSelection: Identifiable {
        let metric: HealthMetric
        let unit: String
        var id: String { metric.key }
    }

    var body: some View {
        NavigationStack {
            List {
                Text(human.name).font(OhanaFont.headline())
                if isLocked || human.hasPassedAway {
                    Text(l.tr(zh: "健康记录已锁定", en: "Health records are locked", de: "Gesundheitsdaten sind gesperrt"))
                } else {
                    if failed { retryRow }
                    if !hasLoaded { ProgressView() }
                    if query.isEmpty && !recentKeys.isEmpty {
                        Section(HumanHealthHomeText.recentMetrics.title(l)) {
                            ForEach(recentKeys, id: \.self) { key in
                                if let metric = HealthMetricCatalog.metric(forKey: key) { metricButton(metric, recent: true) }
                            }
                        }
                    }
                    ForEach(HealthMetricCategory.allCases) { category in
                        let metrics = HealthMetricCatalog.all.filter { $0.category == category && HumanMetricQuickRecordPolicy.matches($0, query: query, l: l) }
                        if !metrics.isEmpty {
                            Section(category.displayName(l)) { ForEach(metrics) { metricButton($0) } }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: HumanHealthHomeText.searchMetrics.title(l))
            .navigationTitle(HumanHealthHomeText.chooseMetric.title(l))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(l.cancel) { dismiss() } } }
        }
        .accessibilityIdentifier("human-health-quick-metric-picker")
        .task { await loadRecent() }
        .sheet(item: $selection) { selected in
            HumanHealthMetricEntrySheet(human: human, metric: selected.metric, initialUnitCode: selected.unit) { _ in
                onSaved(selected.metric.key)
            }
        }
    }

    private var retryRow: some View {
        VStack(alignment: .leading) {
            Text(HumanHealthHomeText.loadFailed.title(l))
            Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) { Task { await loadRecent() } }
        }
    }

    private func metricButton(_ metric: HealthMetric, recent: Bool = false) -> some View {
        Button {
            do {
                let unit = try HumanMetricQuickRecordPolicy.preferredUnit(metric: metric, humanID: human.id, country: appCountry, context: modelContext)
                selection = MetricSelection(metric: metric, unit: unit)
                failed = false
            } catch { failed = true }
        } label: {
            HStack {
                Text(metric.displayName(l))
                Spacer()
                Text(metric.shortNames.first ?? "").foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("human-health-quick-\(recent ? "recent-metric" : "metric")-\(metric.key)")
    }

    @MainActor
    private func loadRecent() async {
        guard !isLocked, !human.hasPassedAway else {
            hasLoaded = true
            return
        }
        await Task.yield()
        guard !Task.isCancelled else { return }
        do {
            recentKeys = try HumanMetricQuickRecordPolicy.recentKeys(humanID: human.id, context: modelContext)
            hasLoaded = true
            failed = false
        } catch {
            failed = true
            hasLoaded = true
        }
    }
}

struct HumanObservationQuickRecordView: View {
    let human: Human
    let onSaved: (UUID) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""
    @State private var conditions: [HumanHealthCondition] = []
    @State private var selectedCondition: HumanHealthCondition?
    @State private var cursor: HumanHealthHistoryPageCursor?
    @State private var hasLoaded = false
    @State private var failed = false
    @State private var showsCreateCondition = false
    private var l: L10n { L10n(appLanguage) }
    private var isLocked: Bool { human.isPrivate(.weight, viewedBy: UUID(uuidString: activeHumanIDRaw)) }
    private var canViewMedication: Bool { !human.isPrivate(.medication, viewedBy: UUID(uuidString: activeHumanIDRaw)) }

    var body: some View {
        Group {
            if let condition = selectedCondition, !isLocked, !human.hasPassedAway {
                HumanHealthObservationEditorSheet(human: human, condition: condition, observation: nil, canViewMedication: canViewMedication, onSaved: { onSaved(condition.id) }, onDeleted: {})
            } else {
                NavigationStack {
                    List {
                        Text(human.name).font(OhanaFont.headline())
                        if isLocked || human.hasPassedAway {
                            Text(l.tr(zh: "健康记录已锁定", en: "Health records are locked", de: "Gesundheitsdaten sind gesperrt"))
                        } else if !hasLoaded { ProgressView() }
                        else if failed {
                            Text(HumanHealthHomeText.loadFailed.title(l))
                            Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) { loadPage(older: false) }
                        } else {
                            ForEach(conditions) { condition in
                                Button(condition.name) { selectedCondition = condition }
                                    .accessibilityIdentifier("human-health-quick-condition-\(condition.id.uuidString)")
                            }
                            if cursor != nil {
                                Button(l.tr(zh: "更多", en: "More", de: "Mehr")) { loadPage(older: true) }
                            }
                            if conditions.isEmpty {
                                Text(HumanHealthHomeText.needsCondition.title(l))
                            }
                            Button(HumanHealthHomeText.addCondition.title(l)) { showsCreateCondition = true }
                                .accessibilityIdentifier("human-health-quick-add-condition")
                        }
                    }
                    .navigationTitle(HumanHealthHomeText.chooseCondition.title(l))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(l.cancel) { dismiss() } } }
                }
            }
        }
        .accessibilityIdentifier("human-health-quick-state-picker")
        .task { await Task.yield()
        if !Task.isCancelled { loadPage(older: false) }
        }
        .sheet(isPresented: $showsCreateCondition, onDismiss: { loadPage(older: false) }) {
            HumanHealthConditionEditorSheet(human: human, condition: nil, medications: [], canViewMedication: canViewMedication, onSaved: { showsCreateCondition = false }, onDeleted: {})
        }
    }

    private func loadPage(older: Bool) {
        guard !isLocked, !human.hasPassedAway else { hasLoaded = true
        return
        }
        do {
            let page = try HumanHealthConditionHistoryQuery.page(humanID: human.id, olderThan: older ? cursor : nil, limit: 32, context: modelContext)
            conditions = page.records
            cursor = page.nextCursor
            hasLoaded = true
            failed = false
            if !older, page.records.count == 1, !page.hasOlder { selectedCondition = page.records.first }
        } catch { failed = true
        hasLoaded = true
        }
    }
}

struct HumanHealthConditionRouteView: View {
    let human: Human
    let conditionID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""
    @State private var data = HumanHealthConditionsRouteData()
    @State private var failed = false
    @State private var refresh = 0
    private var l: L10n { L10n(appLanguage) }
    private var isLocked: Bool { human.isPrivate(.weight, viewedBy: UUID(uuidString: activeHumanIDRaw)) }
    private var canViewMedication: Bool { !human.isPrivate(.medication, viewedBy: UUID(uuidString: activeHumanIDRaw)) }
    var body: some View {
        Group {
            if !isLocked, let condition = data.conditions.first {
                HumanHealthConditionDetailView(human: human, condition: condition, canViewMedication: canViewMedication, isReadOnly: human.hasPassedAway, observations: [], initialSnapshot: data.conditionSnapshots[condition.id] ?? .empty, recentObservationCount: data.conditionSnapshots[condition.id]?.totalCount ?? 0, analysisIsLimited: data.analysisLimitedConditionIDs.contains(condition.id), medicationAnalysisIsIncomplete: data.medicationAnalysisIncompleteConditionIDs.contains(condition.id), medications: data.medications, medicationLogs: data.medicationLogs, metricLogs: data.metricLogs, onRecordsChanged: { refresh += 1 })
            } else if failed || isLocked || data.hasLoaded {
                VStack {
                    Text(l.tr(zh: "记录暂不可用", en: "Record unavailable", de: "Eintrag nicht verfügbar"))
                    if failed { Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) { refresh += 1 } }
                }
            } else { ProgressView() }
        }
        .task(id: "\(refresh):\(isLocked):\(canViewMedication)") {
            guard !isLocked else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            do {
                data = try HumanHealthQuickRecordReadModel.condition(humanID: human.id, conditionID: conditionID, canViewMedication: canViewMedication, context: modelContext)
                failed = false
            } catch { failed = true }
        }
    }
}
