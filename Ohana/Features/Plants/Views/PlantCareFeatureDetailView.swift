//
//  PlantCareFeatureDetailView.swift
//  Ohana
//
//  Dedicated plant care feature pages reached from Home plant cards and the
//  plant FAB group.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

struct PlantCareFeatureDetailView: View {
    let plants: [Plant]
    let feature: PlantCareFeatureDestination
    let focusedPlantID: UUID?
    let focusedCareType: PlantCareType?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @State private var logDraft: PlantCareFeatureLogDraft?
    @State private var waterPlanCalendarEnabled = true
    @State private var waterSystemReminderEnabled = true
    @State private var waterCompletionCalendarEnabled = true
    @State private var waterReminderLeadDays = 0
    @State private var waterScheduleEndEnabled = false
    @State private var waterScheduleEndDate = Date()
    @State private var waterSchedulePersistenceError: String?
    @State private var selectedWaterMode: PlantWaterGuidedMode = .overview
    @State private var routeSnapshot = PlantCareFeatureRouteSnapshot.empty
    @State private var routeSnapshotRefreshTask: Task<Void, Never>?
    @State private var routeSnapshotRefreshGeneration = 0

    private var l: L10n { L10n(appLanguage) }
    private var isAggregate: Bool { focusedPlantID == nil }
    private var focusedPlant: Plant? {
        guard let focusedPlantID else { return nil }
        return plants.first { $0.id == focusedPlantID }
    }
    private var scopedPlants: [Plant] {
        let source: [Plant] = if let focusedPlant {
            [focusedPlant]
        } else {
            plants
        }
        return source.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
    private var routeSnapshotRequest: PlantCareFeatureRouteSnapshotRequest {
        PlantCareFeatureRouteSnapshotRequest(
            plantIDs: scopedPlants.map(\.id),
            feature: feature,
            focusedCareType: focusedCareType,
            now: Date()
        )
    }
    private var isRouteSnapshotLoading: Bool {
        routeSnapshot.requestKey != routeSnapshotRequest.key || !routeSnapshot.hasLoaded
    }
    private var records: [PlantCareFeatureRecord] {
        routeSnapshot.records
    }
    private var pageTitle: String {
        if let focusedCareType {
            return focusedCareType.displayName(l: l)
        }
        return isAggregate ? feature.aggregateTitle(l: l) : feature.title(l: l)
    }
    private var subtitle: String {
        if let focusedPlant {
            return focusedPlant.name
        }
        return l.tr(zh: "所有植物", en: "All plants", de: "Alle Pflanzen")
    }
    private var latestRecordDate: Date? {
        records.first?.date
    }
    private var waterReminderLeadTitle: String {
        (WaterReminderLeadOption(rawValue: waterReminderLeadDays) ?? .sameDay).title(l: l)
    }
    private var primaryCareType: PlantCareType {
        focusedCareType ?? feature.primaryCareType
    }
    private var scheduleCommands: PlantCareFeatureScheduleCommandExecutor {
        PlantCareFeatureScheduleCommandExecutor(context: modelContext, services: appServices)
    }

    private func matchesFocusedFeature(_ careType: PlantCareType) -> Bool {
        focusedCareType.map { $0 == careType } ?? feature.matches(careType)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if scopedPlants.isEmpty {
                        emptyPlantsState
                    } else if let focusedPlant,
                              feature == .water,
                              focusedCareType == nil || focusedCareType == .watering {
                        waterGuidedHome(for: focusedPlant)
                    } else {
                        summaryBand
                        if isAggregate {
                            aggregateComparisonSection
                            plantCollectionSection
                        } else if let focusedPlant {
                            focusedPlantActionSection(focusedPlant)
                        }
                        recordSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logDraft) { draft in
            if let plant = plant(for: draft.plantID) {
                PlantCareLogSheet(
                    plant: plant,
                    initialCareType: draft.careType,
                    currentHealthStatus: plant.healthStatus,
                    onSave: { careType, careNote, healthStatus, photoData in
                        saveCareLog(
                            careType,
                            plant: plant,
                            careNote: careNote,
                            healthStatus: healthStatus,
                            photoData: photoData
                        )
                    }
                )
            }
        }
        .onAppear {
            refreshWaterScheduleControls()
            scheduleRouteSnapshotRefresh()
        }
        .onChange(of: focusedPlantID) {
            selectedWaterMode = .overview
            refreshWaterScheduleControls()
            scheduleRouteSnapshotRefresh(force: true)
        }
        .onChange(of: routeSnapshotRequest.key) {
            scheduleRouteSnapshotRefresh(force: true)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteSnapshotRefresh(force: true)
        }
        .onDisappear {
            routeSnapshotRefreshTask?.cancel()
            routeSnapshotRefreshTask = nil
        }
        .accessibilityIdentifier(accessibilityRootID)
    }

    private var accessibilityRootID: String {
        if let focusedPlantID {
            return "plant-care-feature-\(feature.rawValue)-\(focusedPlantID.uuidString)"
        }
        return "plant-care-feature-\(feature.rawValue)-aggregate"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let focusedPlant {
                plantAvatar(focusedPlant)
                    .frame(width: 46, height: 46)
            } else {
                Image(systemName: feature.icon)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(feature.tint)
                    .frame(width: 46, height: 46)
                    .background(feature.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(focusedPlant?.name ?? pageTitle)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(focusedPlant == nil ? subtitle : pageTitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-header")
    }

    private var summaryBand: some View {
        LazyVGrid(columns: plantCareFeatureMetricColumns, spacing: 10) {
            metricTile(
                id: "plants",
                icon: "leaf.fill",
                title: l.tr(zh: "植物", en: "Plants", de: "Pflanzen"),
                value: "\(scopedPlants.count)",
                tint: Color.goPrimary
            )
            metricTile(
                id: "records",
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "记录", en: "Logs", de: "Einträge"),
                value: isRouteSnapshotLoading ? "…" : "\(records.count)",
                tint: feature.tint
            )
            metricTile(
                id: "latest",
                icon: "calendar",
                title: l.tr(zh: "最近一次", en: "Latest", de: "Zuletzt"),
                value: isRouteSnapshotLoading ? "…" : (latestRecordDate.map(relativeDateText) ?? l.tr(zh: "暂无", en: "None", de: "Keine")),
                tint: Color.goTeal
            )
            metricTile(
                id: "due",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "待处理", en: "Due", de: "Fällig"),
                value: isRouteSnapshotLoading ? "…" : "\(duePlantCount)",
                tint: duePlantCount > 0 ? Color.goYellow : Color.goTeal
            )
        }
    }

    private var plantCareFeatureMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 132), spacing: 10)]
    }

    private var plantCareFeatureInsightColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 156), spacing: 10)]
    }

    private var duePlantCount: Int {
        duePlantsForFeature.count
    }

    private var aggregateComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "照护比较", en: "Care comparison", de: "Pflegevergleich"))

            LazyVGrid(columns: plantCareFeatureInsightColumns, spacing: 10) {
                ForEach(aggregateInsights) { insight in
                    aggregateInsightTile(insight)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-aggregate-comparison")
    }

    private var aggregateInsights: [PlantCareAggregateInsight] {
        var insights: [PlantCareAggregateInsight] = [
            aggregateDueInsight,
            aggregateRecentInsight
        ]
        if let roomInsight = aggregateRoomPressureInsight {
            insights.append(roomInsight)
        }
        if let outlierInsight = aggregateOutlierInsight {
            insights.append(outlierInsight)
        }
        if let rhythmInsight = aggregateRhythmInsight {
            insights.append(rhythmInsight)
        }
        return Array(insights.prefix(4))
    }

    private var aggregateDueInsight: PlantCareAggregateInsight {
        PlantCareAggregateInsight(
            id: "due",
            icon: "calendar.badge.clock",
            title: l.tr(zh: "今日压力", en: "Due now", de: "Jetzt fällig"),
            value: "\(duePlantCount)",
            detail: duePlantCount == 0
                ? l.tr(zh: "当前没有到期植物", en: "No plants are due now", de: "Aktuell nichts fällig")
                : l.tr(zh: "\(duePlantCount) 株需要处理", en: "\(duePlantCount) plants need care", de: "\(duePlantCount) Pflanzen brauchen Pflege"),
            tint: duePlantCount > 0 ? Color.goYellow : Color.goTeal
        )
    }

    private var aggregateRecentInsight: PlantCareAggregateInsight {
        let recentCount = records.count { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day.map { $0 <= 30 } ?? false }
        return PlantCareAggregateInsight(
            id: "recent",
            icon: "chart.line.uptrend.xyaxis",
            title: l.tr(zh: "30天记录", en: "30-day logs", de: "30-Tage"),
            value: "\(recentCount)",
            detail: recentCount == 0
                ? l.tr(zh: "最近没有记录", en: "No recent logs", de: "Keine aktuellen Einträge")
                : l.tr(zh: "最近 30 天形成的节奏", en: "Recent 30-day care rhythm", de: "Pflege der letzten 30 Tage"),
            tint: feature.tint
        )
    }

    private var aggregateRoomPressureInsight: PlantCareAggregateInsight? {
        let plantsForRoom: [Plant] = feature == .log ? scopedPlants.filter { !featureRecords(for: $0).isEmpty } : duePlantsForFeature
        guard !plantsForRoom.isEmpty else { return nil }
        let grouped = Dictionary(grouping: plantsForRoom, by: roomName(for:))
            .sorted {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }
        guard let top = grouped.first else { return nil }
        return PlantCareAggregateInsight(
            id: "room",
            icon: "house.lodge.fill",
            title: l.tr(zh: "房间负担", en: "Room load", de: "Raumlast"),
            value: top.key,
            detail: l.tr(zh: "\(top.value.count) 株植物", en: "\(top.value.count) plants", de: "\(top.value.count) Pflanzen"),
            tint: Color.goPrimary
        )
    }

    private var aggregateOutlierInsight: PlantCareAggregateInsight? {
        if feature == .log {
            let quietPlants = scopedPlants.sorted {
                (lastFeatureCareDate(for: $0) ?? .distantPast) < (lastFeatureCareDate(for: $1) ?? .distantPast)
            }
            guard let quietPlant = quietPlants.first else { return nil }
            let lastText = lastFeatureCareDate(for: quietPlant).map(relativeDateText) ?? l.tr(zh: "暂无记录", en: "No logs", de: "Keine Einträge")
            return PlantCareAggregateInsight(
                id: "quiet",
                icon: "moon.zzz.fill",
                title: l.tr(zh: "最少记录", en: "Quietest", de: "Am ruhigsten"),
                value: quietPlant.name,
                detail: lastText,
                tint: Color.goYellow
            )
        }

        let ranked = scopedPlants
            .map { plant in (plant: plant, days: overdueDays(for: plant)) }
            .sorted {
                if $0.days != $1.days { return $0.days > $1.days }
                return $0.plant.name.localizedStandardCompare($1.plant.name) == .orderedAscending
            }
        guard let top = ranked.first, top.days > 0 else {
            let percent = scopedPlants.isEmpty ? 0 : Int((Double(max(0, scopedPlants.count - duePlantCount)) / Double(scopedPlants.count) * 100).rounded())
            return PlantCareAggregateInsight(
                id: "on-track",
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "按计划", en: "On track", de: "Im Plan"),
                value: "\(percent)%",
                detail: l.tr(zh: "没有明显延误", en: "No clear overdue outlier", de: "Keine klare Verzögerung"),
                tint: Color.goTeal
            )
        }
        return PlantCareAggregateInsight(
            id: "outlier",
            icon: "exclamationmark.triangle.fill",
            title: l.tr(zh: "最需关注", en: "Needs attention", de: "Braucht Blick"),
            value: top.plant.name,
            detail: l.tr(zh: "偏离计划 \(top.days) 天", en: "\(top.days)d past cadence", de: "\(top.days) T. über Rhythmus"),
            tint: Color.goYellow
        )
    }

    private var aggregateRhythmInsight: PlantCareAggregateInsight? {
        guard feature != .log else { return nil }
        let deltas = scopedPlants.compactMap { plant -> Int? in
            guard let actual = averageIntervalDays(for: plant) else { return nil }
            return actual - plannedIntervalDays(for: plant)
        }
        guard !deltas.isEmpty else { return nil }
        let averageDelta = Int((Double(deltas.reduce(0, +)) / Double(deltas.count)).rounded())
        let prefix = averageDelta > 0 ? "+" : ""
        return PlantCareAggregateInsight(
            id: "rhythm",
            icon: "metronome.fill",
            title: l.tr(zh: "实际节奏", en: "Actual rhythm", de: "Echter Takt"),
            value: "\(prefix)\(averageDelta)天",
            detail: l.tr(zh: "实际间隔 vs 计划", en: "Actual interval vs plan", de: "Echter Abstand vs. Plan"),
            tint: abs(averageDelta) <= 1 ? Color.goTeal : Color.goYellow
        )
    }

    private func aggregateInsightTile(_ insight: PlantCareAggregateInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: insight.icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(insight.tint)
                    .frame(width: 32, height: 32) // a11y: allow non-interactive metric glyph; tile text carries the accessible content.
                    .background(insight.tint.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                Text(insight.title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(insight.value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(insight.detail)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-aggregate-\(insight.id)")
    }

    private func metricTile(id: String, icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-metric-\(id)")
    }

    private var plantCollectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "植物列表", en: "Plants", de: "Pflanzen"))

            VStack(spacing: 10) {
                ForEach(scopedPlants) { plant in
                    plantCollectionRow(plant)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-plant-list")
    }

    private func focusedPlantActionSection(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "快捷记录", en: "Quick log", de: "Schneller Eintrag"))
            plantCollectionRow(plant)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-focused-actions")
    }

    private func waterGuidedHome(for plant: Plant) -> some View {
        VStack(spacing: 14) {
            PlantWaterModeStrip(l: l, selectedMode: $selectedWaterMode)
            PlantWaterPrimaryTaskCard(
                l: l,
                model: waterPrimaryCardModel(for: plant),
                onOpenPlan: { selectWaterMode(.plan) },
                onQuickRecord: { quickRecordWater(for: plant) }
            )

            switch selectedWaterMode {
            case .overview:
                PlantWaterGuidedMiniChartCard(l: l, model: waterChartCardModel(for: plant))
                PlantWaterCompactDiscoveryDock(
                    items: waterDiscoveryItems(for: plant),
                    adviceItems: waterAdviceItems(for: plant, task: wateringTask(for: plant)),
                    onSelect: { handleWaterDiscoveryAction($0, plant: plant) }
                )
            case .plan:
                waterScheduleControlSection(plant)
            case .history:
                PlantWaterGuidedMiniChartCard(l: l, model: waterChartCardModel(for: plant))
                recordSection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-guided-home")
    }

    private func waterPrimaryCardModel(for plant: Plant) -> PlantWaterPrimaryCardModel {
        let task = wateringTask(for: plant)
        return PlantWaterPrimaryCardModel(
            title: waterPrimaryTitle(for: plant, task: task),
            habitSummary: waterHabitSummary(for: plant, task: task),
            metricValue: waterPrimaryMetricValue(for: plant, task: task),
            signals: Array(waterSignals(for: plant, task: task).prefix(3)),
            advice: waterAdviceItems(for: plant, task: task).first
        )
    }

    private func waterPrimaryTitle(for plant: Plant, task: PlantCareTaskSnapshot?) -> String {
        if plant.needsWatering || (task?.daysUntilDue ?? 1) <= 0 {
            return l.tr(zh: "现在该浇水", en: "Watering is due", de: "Gießen ist fällig")
        }
        return l.tr(zh: "浇水节奏稳定", en: "Watering rhythm is steady", de: "Gießrhythmus ist stabil")
    }

    private func waterPrimaryMetricValue(for plant: Plant, task: PlantCareTaskSnapshot?) -> String {
        if let days = task?.daysUntilDue {
            if days <= 0 {
                return l.tr(zh: "今天", en: "Today", de: "Heute")
            }
            return l.tr(zh: "\(days)天", en: "\(days)d", de: "\(days)T")
        }
        let intervalDays = appServices.plantCarePlans.intervalDays(for: .watering, plant: plant)
        return l.tr(
            zh: "\(intervalDays)天",
            en: "\(intervalDays)d",
            de: "\(intervalDays)T"
        )
    }

    private func selectWaterMode(_ mode: PlantWaterGuidedMode) {
        withAnimation(GoMotion.selection) {
            selectedWaterMode = mode
        }
    }

    private func waterScheduleControlSection(_ plant: Plant) -> some View {
        PlantWaterScheduleControlSection(
            l: l,
            summary: waterReminderSummary(for: plant, task: wateringTask(for: plant)),
            persistenceError: waterSchedulePersistenceError,
            bindings: waterScheduleBindings(for: plant),
            onResync: { resyncWaterReminder(for: plant) }
        )
    }

    private func waterScheduleBindings(for plant: Plant) -> PlantWaterScheduleControlBindings {
        PlantWaterScheduleControlBindings(
            intervalDays: Binding(
                get: { max(1, plant.wateringIntervalDays) },
                set: { updateWateringInterval($0, for: plant) }
            ),
            startDate: Binding(
                get: { waterScheduleStartDate(for: plant) },
                set: { updateWateringStartDate($0, for: plant) }
            ),
            endEnabled: Binding(
                get: { waterScheduleEndEnabled },
                set: { setWaterScheduleEndEnabled($0, for: plant) }
            ),
            endDate: Binding(
                get: { waterScheduleEndDate },
                set: { setWaterScheduleEndDate($0, for: plant) }
            ),
            planCalendarEnabled: Binding(
                get: { waterPlanCalendarEnabled },
                set: { setWaterPlanCalendarEnabled($0, for: plant) }
            ),
            systemReminderEnabled: Binding(
                get: { waterSystemReminderEnabled },
                set: { setWaterSystemReminderEnabled($0, for: plant) }
            ),
            reminderLeadDays: Binding(
                get: { waterReminderLeadDays },
                set: { setWaterReminderLeadDays($0, for: plant) }
            ),
            completionCalendarEnabled: Binding(
                get: { waterCompletionCalendarEnabled },
                set: { setWaterCompletionCalendarEnabled($0, for: plant) }
            )
        )
    }

    private func waterChartCardModel(for plant: Plant) -> PlantWaterChartCardModel {
        PlantWaterChartCardModel(
            plantName: plant.name,
            plannedIntervalDays: plannedIntervalDays(for: plant),
            points: wateringBarChartPoints(for: plant),
            wateringLogCount: wateringLogCount(for: plant),
            isLoading: isRouteSnapshotLoading
        )
    }

    private func waterDiscoveryItems(for plant: Plant) -> [PlantWaterDiscoveryItem] {
        let task = wateringTask(for: plant)
        let adviceItems = waterAdviceItems(for: plant, task: task)
        return [
            PlantWaterDiscoveryItem(
                id: "habit",
                icon: "humidity.fill",
                title: l.tr(zh: "习性", en: "Habit", de: "Vorliebe"),
                value: adviceItems.first ?? plant.humidityPreference.displayName,
                tint: Color.goTeal,
                action: nil
            ),
            PlantWaterDiscoveryItem(
                id: "plan",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "计划", en: "Plan", de: "Plan"),
                value: waterPlanSummaryText(for: plant, task: task),
                tint: Color.goYellow,
                action: .plan
            ),
            PlantWaterDiscoveryItem(
                id: "history",
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "历史", en: "History", de: "Verlauf"),
                value: waterHistorySummaryText(),
                tint: feature.tint,
                action: .history
            ),
            PlantWaterDiscoveryItem(
                id: "detail",
                icon: "square.and.pencil",
                title: l.tr(zh: "详细记录", en: "Detail log", de: "Detailprotokoll"),
                value: l.tr(zh: "照片/备注", en: "Photo + note", de: "Foto + Notiz"),
                tint: feature.tint,
                action: .detail
            )
        ]
    }

    private func handleWaterDiscoveryAction(_ action: PlantWaterDiscoveryAction, plant: Plant) {
        switch action {
        case .plan:
            selectWaterMode(.plan)
        case .history:
            selectWaterMode(.history)
        case .detail:
            openLog(for: plant)
        }
    }

    private func waterPlanSummaryText(for plant: Plant, task: PlantCareTaskSnapshot?) -> String {
        let interval = task?.effectiveIntervalDays ?? appServices.plantCarePlans.intervalDays(for: .watering, plant: plant)
        guard waterPlanCalendarEnabled else {
            return l.tr(
                zh: "每 \(interval) 天 · 不显示到日历",
                en: "Every \(interval)d · calendar off",
                de: "Alle \(interval) T. · Kalender aus"
            )
        }
        guard waterSystemReminderEnabled else {
            return l.tr(
                zh: "每 \(interval) 天 · 无系统提醒",
                en: "Every \(interval)d · no alerts",
                de: "Alle \(interval) T. · ohne Hinweis"
            )
        }
        return l.tr(
            zh: "每 \(interval) 天 · \(waterReminderLeadTitle)",
            en: "Every \(interval)d · \(waterReminderLeadTitle)",
            de: "Alle \(interval) T. · \(waterReminderLeadTitle)"
        )
    }

    private func waterHistorySummaryText() -> String {
        if let latestRecordDate {
            return l.tr(
                zh: "\(records.count) 条 · \(relativeDateText(latestRecordDate))",
                en: "\(records.count) logs · \(relativeDateText(latestRecordDate))",
                de: "\(records.count) Einträge · \(relativeDateText(latestRecordDate))"
            )
        }
        return l.tr(
            zh: "暂无记录",
            en: "No logs yet",
            de: "Noch keine Einträge"
        )
    }

    private func plantCollectionRow(_ plant: Plant) -> some View {
        HStack(alignment: .center, spacing: 12) {
            plantAvatar(plant)

            VStack(alignment: .leading, spacing: 5) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(plantStatusText(plant))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Button {
                openLog(for: plant)
            } label: {
                Image(systemName: "plus") // a11y: allow decorative add glyph; button label is provided by accessibilityLabel.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(feature.tint, in: Circle())
                    .contentShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(logButtonTitle)
            .accessibilityIdentifier("plant-care-feature-log-\(plant.id.uuidString)")
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func plantAvatar(_ plant: Plant) -> some View {
        Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
            .frame(width: 44, height: 44)
            .background(Color(hex: plant.themeColorHex).opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))

            if isRouteSnapshotLoading {
                loadingRecordState
            } else if records.isEmpty {
                emptyRecordState
            } else {
                VStack(spacing: 10) {
                    ForEach(records.prefix(80)) { record in
                        recordRow(record)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-history")
    }

    private func recordRow(_ record: PlantCareFeatureRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: careSymbol(for: record.careType))
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: record.careType))
                .frame(width: 44, height: 44)
                .background(careTint(for: record.careType).opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.careType.displayName(l: l))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if isAggregate {
                        Text(record.plantName)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }

                Text(fullDateText(record.date))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !record.note.isEmpty {
                    Text(record.note)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let healthStatus = record.healthStatus {
                    Text(healthStatusText(healthStatus))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(healthTint(for: healthStatus))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-record-\(record.id.uuidString)")
    }

    private var emptyPlantsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf") // a11y: allow decorative empty-state glyph; text names the state.
                .font(OhanaFont.adaptive(size: 24, weight: .black))
                .foregroundStyle(feature.tint)
                .accessibilityHidden(true)
            Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "添加植物后，这里会汇总对应的护理记录。", en: "After adding plants, this page will collect the matching care logs.", de: "Nach dem Hinzufügen sammelt diese Seite passende Pflegeeinträge."))
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-empty-plants")
    }

    private var emptyRecordState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "暂无记录", en: "No logs yet", de: "Noch keine Einträge"))
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(emptyRecordHint)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-care-feature-empty-records")
    }

    private var loadingRecordState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "正在整理历史", en: "Preparing history", de: "Verlauf wird vorbereitet"))
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "首帧先展示操作区，记录会以快照补上。", en: "Actions render first; logs arrive as a snapshot.", de: "Aktionen erscheinen zuerst; Einträge folgen als Snapshot."))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-care-feature-loading-records")
    }

    private var emptyRecordHint: String {
        switch feature {
        case .water:
            l.tr(zh: "记录第一次浇水后，这里会显示浇水和喷雾历史。", en: "After the first water log, watering and misting history appears here.", de: "Nach dem ersten Gießen erscheinen Gieß- und Sprühverlauf hier.")
        case .fertilize:
            l.tr(zh: "记录第一次施肥或换盆后，这里会显示营养与盆土历史。", en: "After the first feed or repotting log, nutrition and soil history appears here.", de: "Nach dem ersten Düngen oder Umtopfen erscheint der Verlauf hier.")
        case .maintenance:
            l.tr(zh: "记录修剪、擦叶或转盆后，这里会显示整理养护历史。", en: "Pruning, leaf cleaning, and pot rotation logs appear here.", de: "Schnitt, Blattpflege und Drehungen erscheinen hier.")
        case .health:
            l.tr(zh: "记录查虫、黄叶或虫害后，这里会形成健康复查历史。", en: "Pest checks, yellow leaves, and pest findings build this health history.", de: "Schädlingschecks, gelbe Blätter und Befall bilden diesen Verlauf.")
        case .growth:
            l.tr(zh: "拍照、新叶和备注会形成成长记录。", en: "Photos, new leaves, and notes build the growth record.", de: "Fotos, neue Blätter und Notizen bilden den Wachstumsverlauf.")
        case .log:
            l.tr(zh: "记录备注、照片、黄叶、虫害或换盆后，这里会形成植物时间线。", en: "Notes, photos, leaf changes, pest checks, and repotting build this timeline.", de: "Notizen, Fotos, Blattwechsel, Schädlingschecks und Umtopfen bilden diese Zeitachse.")
        }
    }

    private var logButtonTitle: String {
        switch feature {
        case .water:
            l.tr(zh: "新增浇水记录", en: "Add water log", de: "Gießen erfassen")
        case .fertilize:
            l.tr(zh: "新增施肥记录", en: "Add fertilizer log", de: "Düngen erfassen")
        case .maintenance:
            l.tr(zh: "新增养护记录", en: "Add care log", de: "Pflege erfassen")
        case .health:
            l.tr(zh: "新增复查记录", en: "Add health review", de: "Gesundheitscheck erfassen")
        case .growth:
            l.tr(zh: "新增成长记录", en: "Add growth note", de: "Wachstum erfassen")
        case .log:
            l.tr(zh: "新增植物记录", en: "Add plant log", de: "Pflanzennotiz erfassen")
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .textCase(.uppercase)
    }

    private func wateringTask(for plant: Plant) -> PlantCareTaskSnapshot? {
        routeSnapshot.wateringTasksByPlantID[plant.id]
    }

    private func waterSignals(for plant: Plant, task: PlantCareTaskSnapshot?) -> [PlantWateringSignal] {
        [
            PlantWateringSignal(
                id: "interval",
                title: l.tr(zh: "周期", en: "Cadence", de: "Rhythmus"),
                value: l.tr(
                    zh: "每 \(task?.effectiveIntervalDays ?? appServices.plantCarePlans.intervalDays(for: .watering, plant: plant)) 天",
                    en: "Every \(task?.effectiveIntervalDays ?? appServices.plantCarePlans.intervalDays(for: .watering, plant: plant))d",
                    de: "Alle \(task?.effectiveIntervalDays ?? appServices.plantCarePlans.intervalDays(for: .watering, plant: plant)) T."
                ),
                tint: Color.goTeal
            ),
            PlantWateringSignal(
                id: "due",
                title: l.tr(zh: "下次", en: "Next", de: "Nächstes"),
                value: task.map(waterDueText) ?? l.tr(zh: "无计划", en: "No plan", de: "Kein Plan"),
                tint: task?.daysUntilDue ?? 1 <= 0 ? Color.goYellow : Color.goPrimary
            ),
            PlantWateringSignal(
                id: "last",
                title: l.tr(zh: "上次", en: "Last", de: "Zuletzt"),
                value: plant.daysSinceWatered.map {
                    l.tr(zh: "\($0) 天前", en: "\($0)d ago", de: "vor \($0) T.")
                } ?? l.tr(zh: "暂无", en: "None", de: "Keine"),
                tint: Color.goTeal
            ),
            PlantWateringSignal(
                id: "humidity",
                title: l.tr(zh: "偏好", en: "Preference", de: "Vorliebe"),
                value: plant.humidityPreference.displayName,
                tint: plant.humidityPreference == .humid ? Color.goTeal : Color.goPrimary
            )
        ]
    }

    private func waterHabitSummary(for plant: Plant, task: PlantCareTaskSnapshot?) -> String {
        if let task {
            return task.subtitle
        }
        if let entry = PlantCatalog.entry(id: plant.catalogSpeciesId) {
            return l.tr(
                zh: "\(entry.localizedCommonName) 的基准浇水周期约 \(entry.defaultWateringDays) 天。",
                en: "\(entry.localizedCommonName)'s baseline watering cadence is about \(entry.defaultWateringDays)d.",
                de: "Der Basis-Gießrhythmus von \(entry.localizedCommonName) liegt bei etwa \(entry.defaultWateringDays) T."
            )
        }
        return l.tr(zh: "按档案中的光照、盆器和土壤干湿调整浇水。", en: "Adjust watering by light, pot, and soil moisture in the profile.", de: "Gießen nach Licht, Topf und Erdfeuchte im Profil anpassen.")
    }

    private func waterAdviceItems(for plant: Plant, task: PlantCareTaskSnapshot?) -> [String] {
        var items: [String] = []
        if let entry = PlantCatalog.entry(id: plant.catalogSpeciesId) {
            items.append(l.tr(
                zh: "习性：\(entry.localizedWateringPreference)",
                en: "Habit: \(entry.localizedWateringPreference)",
                de: "Rhythmus: \(entry.localizedWateringPreference)"
            ))
        }
        if plant.isHydroponic {
            items.append(l.tr(zh: "水培：看水位/根系", en: "Hydro: water level + roots", de: "Hydro: Wasserstand + Wurzeln"))
        } else if plant.isSucculent {
            items.append(l.tr(zh: "多肉：干透再浇", en: "Succulent: dry first", de: "Sukkulent: erst trocknen"))
        } else {
            items.append(l.tr(zh: "浇前摸土/掂盆", en: "Check soil/pot weight", de: "Erde/Topfgewicht prüfen"))
        }
        if !plant.potHasDrainage {
            items.append(l.tr(zh: "无排水：少量", en: "No drainage: light water", de: "Ohne Abzug: wenig Wasser"))
        }
        if plant.isNearClimateSource {
            items.append(l.tr(zh: "风口：更勤观察", en: "Draft/heat: watch closer", de: "Klima/Heizung: öfter prüfen"))
        }
        if task?.learningSummary != nil {
            items.append(l.tr(zh: "已学习近期节奏", en: "Recent rhythm learned", de: "Rhythmus gelernt"))
        }
        return Array(uniqueStrings(items).prefix(4))
    }

    private func wateringBarChartPoints(for plant: Plant) -> [OhanaMinimalChartPoint] {
        let wateringRecords = records
            .filter { $0.plantID == plant.id && $0.careType == .watering }
            .sorted { $0.date < $1.date }
        guard wateringRecords.count >= 2 else { return [] }

        var points: [OhanaMinimalChartPoint] = []
        for index in wateringRecords.indices.dropFirst() {
            let previous = Calendar.current.startOfDay(for: wateringRecords[index - 1].date)
            let current = Calendar.current.startOfDay(for: wateringRecords[index].date)
            let days = max(0, Calendar.current.dateComponents([.day], from: previous, to: current).day ?? 0)
            points.append(OhanaMinimalChartPoint(
                date: wateringRecords[index].date,
                value: Double(days),
                label: wateringRecords[index].date.formatted(.dateTime.month(.abbreviated).day()),
                id: wateringRecords[index].id.uuidString
            ))
        }
        return Array(points.suffix(10))
    }

    private func wateringLogCount(for plant: Plant) -> Int {
        records.count { $0.plantID == plant.id && $0.careType == .watering }
    }

    private func waterReminderSummary(for plant: Plant, task: PlantCareTaskSnapshot?) -> String {
        guard waterPlanCalendarEnabled else {
            return l.tr(zh: "计划不显示在日历", en: "Calendar plan is off", de: "Kalenderplan ist aus")
        }
        guard waterSystemReminderEnabled else {
            return l.tr(zh: "系统提醒关闭，日历计划保留", en: "Alerts off, calendar plan kept", de: "Hinweise aus, Kalenderplan bleibt")
        }
        if PlantReminderPreferenceStore.isTravelModeEnabled() {
            return l.tr(zh: "旅行模式暂停通知，今日照护保留", en: "Travel mode pauses alerts only", de: "Reisemodus pausiert nur Hinweise")
        }
        if let task {
            return l.tr(
                zh: "下次 \(fullDateText(task.dueDate))",
                en: "Next \(fullDateText(task.dueDate))",
                de: "Nächstes \(fullDateText(task.dueDate))"
            )
        }
        return l.tr(zh: "按计划提醒", en: "Plan reminders", de: "Plan-Erinnerungen")
    }

    private func refreshWaterScheduleControls() {
        guard feature == .water, let focusedPlant else { return }
        let now = Date()
        let snapshot = scheduleCommands.controlSnapshot(for: focusedPlant, now: now)
        waterPlanCalendarEnabled = snapshot.planCalendarEnabled
        waterSystemReminderEnabled = snapshot.systemReminderEnabled
        waterCompletionCalendarEnabled = snapshot.completionCalendarEnabled
        waterReminderLeadDays = snapshot.reminderLeadDays
        waterScheduleEndEnabled = snapshot.hasRecurrenceEndDate
        waterScheduleEndDate = snapshot.resolvedRecurrenceEndDate(now: now, calendar: .current)
    }

    private func waterScheduleStartDate(for plant: Plant) -> Date {
        plant.lastWateredDate ?? plant.createdAt
    }

    private func updateWateringInterval(_ days: Int, for plant: Plant) {
        applyWaterScheduleFact(.intervalDays(days), for: plant)
    }

    private func updateWateringStartDate(_ date: Date, for plant: Plant) {
        applyWaterScheduleFact(.startDate(date), for: plant)
    }

    private func setWaterScheduleEndEnabled(_ enabled: Bool, for plant: Plant) {
        waterScheduleEndEnabled = enabled
        let endDate = enabled ? Calendar.current.startOfDay(for: waterScheduleEndDate) : nil
        scheduleCommands.setPreference(.recurrenceEndDate(endDate), for: plant)
    }

    private func setWaterScheduleEndDate(_ date: Date, for plant: Plant) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        waterScheduleEndDate = normalizedDate
        scheduleCommands.setPreference(.recurrenceEndDate(normalizedDate), for: plant)
    }

    private func setWaterReminderLeadDays(_ days: Int, for plant: Plant) {
        waterReminderLeadDays = days
        scheduleCommands.setPreference(.reminderLeadDays(days), for: plant)
    }

    private func applyWaterScheduleFact(_ mutation: PlantWaterScheduleFactMutation, for plant: Plant) {
        let result = scheduleCommands.updateScheduleFact(mutation, for: plant)
        guard result.didPersist else {
            waterSchedulePersistenceError = waterScheduleSaveFailureMessage(result.persistenceErrorDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        waterSchedulePersistenceError = nil
    }

    private func waterScheduleSaveFailureMessage(_ errorDescription: String?) -> String {
        if let errorDescription, !errorDescription.isEmpty {
            return l.tr(
                zh: "浇水计划保存失败：\(errorDescription)",
                en: "Watering plan couldn't be saved: \(errorDescription)",
                de: "Gießplan konnte nicht gespeichert werden: \(errorDescription)"
            )
        }
        return l.tr(
            zh: "浇水计划保存失败，请检查存储空间后重试。",
            en: "Watering plan couldn't be saved. Check storage and try again.",
            de: "Gießplan konnte nicht gespeichert werden. Speicher pruefen und erneut versuchen."
        )
    }

    private func waterDueText(_ task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            return l.tr(zh: "超期 \(abs(task.daysUntilDue)) 天", en: "\(abs(task.daysUntilDue))d overdue", de: "\(abs(task.daysUntilDue)) T. überfällig")
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return l.tr(zh: "\(task.daysUntilDue) 天后", en: "In \(task.daysUntilDue)d", de: "In \(task.daysUntilDue) T.")
    }

    private func setWaterPlanCalendarEnabled(_ enabled: Bool, for plant: Plant) {
        waterPlanCalendarEnabled = enabled
        scheduleCommands.setPreference(.planCalendarEnabled(enabled), for: plant)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func setWaterSystemReminderEnabled(_ enabled: Bool, for plant: Plant) {
        waterSystemReminderEnabled = enabled
        scheduleCommands.setPreference(.systemReminderEnabled(enabled), for: plant)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func setWaterCompletionCalendarEnabled(_ enabled: Bool, for plant: Plant) {
        waterCompletionCalendarEnabled = enabled
        scheduleCommands.setPreference(.completionCalendarEnabled(enabled), for: plant)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resyncWaterReminder(for plant: Plant) {
        scheduleCommands.resyncPlan(for: plant)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func quickRecordWater(for plant: Plant) {
        saveCareLog(.watering, plant: plant, careNote: "", healthStatus: plant.healthStatus, photoData: nil)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    private func plantStatusText(_ plant: Plant) -> String {
        switch feature {
        case .water:
            if let days = plant.daysSinceWatered {
                return l.tr(zh: "上次浇水 \(days) 天前", en: "Last watered \(days)d ago", de: "Zuletzt vor \(days) T. gegossen")
            }
            return l.tr(zh: "还没有浇水记录", en: "No water log yet", de: "Noch kein Gießprotokoll")
        case .fertilize:
            if let days = plant.daysSinceFertilized {
                return l.tr(zh: "上次施肥 \(days) 天前", en: "Last fertilized \(days)d ago", de: "Zuletzt vor \(days) T. gedüngt")
            }
            return l.tr(zh: "还没有施肥记录", en: "No fertilizer log yet", de: "Noch kein Düngeprotokoll")
        case .maintenance, .health, .growth, .log:
            let count = featureRecords(for: plant).count
            return count == 0
                ? l.tr(zh: "还没有相关记录", en: "No matching logs yet", de: "Noch keine passenden Einträge")
                : l.tr(zh: "\(count) 条相关记录", en: "\(count) matching logs", de: "\(count) passende Einträge")
        }
    }

    private func featureRecords(for plant: Plant) -> [PlantCareFeatureRecord] {
        records.filter { $0.plantID == plant.id && matchesFocusedFeature($0.careType) }
    }

    private var duePlantsForFeature: [Plant] {
        guard feature.category?.isSchedulable == true else { return [] }
        return scopedPlants.filter { routeSnapshot.duePlantIDs.contains($0.id) }
    }

    private func roomName(for plant: Plant) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty { return room }
        return plant.isIndoor
            ? l.tr(zh: "未设置室内位置", en: "Unassigned indoor", de: "Innen ohne Ort")
            : l.tr(zh: "未设置户外位置", en: "Unassigned outdoor", de: "Außen ohne Ort")
    }

    private func daysSinceFeatureCare(for plant: Plant) -> Int? {
        switch feature {
        case .water:
            plant.daysSinceWatered
        case .fertilize:
            plant.daysSinceFertilized
        case .maintenance, .health, .growth, .log:
            lastFeatureCareDate(for: plant).flatMap {
                Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: Date())).day
            }
        }
    }

    private func plannedIntervalDays(for plant: Plant) -> Int {
        routeSnapshot.primaryIntervalDaysByPlantID[plant.id] ?? PlantCareFeatureRouteSnapshotActor.fallbackIntervalDays(
            for: primaryCareType,
            plant: plant
        )
    }

    private func overdueDays(for plant: Plant) -> Int {
        let planned = plannedIntervalDays(for: plant)
        guard let daysSinceFeatureCare = daysSinceFeatureCare(for: plant) else { return planned }
        return max(0, daysSinceFeatureCare - planned)
    }

    private func featureCadenceDates(for plant: Plant) -> [Date] {
        featureRecords(for: plant)
            .map(\.date)
            .sorted()
    }

    private func averageIntervalDays(for plant: Plant) -> Int? {
        let dates = featureCadenceDates(for: plant)
        guard dates.count >= 2 else { return nil }
        var gaps: [Int] = []
        for index in dates.indices.dropFirst() {
            let previous = Calendar.current.startOfDay(for: dates[index - 1])
            let current = Calendar.current.startOfDay(for: dates[index])
            gaps.append(max(0, Calendar.current.dateComponents([.day], from: previous, to: current).day ?? 0))
        }
        guard !gaps.isEmpty else { return nil }
        return Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
    }

    private func lastFeatureCareDate(for plant: Plant) -> Date? {
        featureRecords(for: plant)
            .map(\.date)
            .max()
    }

    private func openLog(for plant: Plant) {
        logDraft = PlantCareFeatureLogDraft(plantID: plant.id, careType: primaryCareType)
    }

    private func saveCareLog(
        _ careType: PlantCareType,
        plant: Plant,
        careNote: String,
        healthStatus: PlantHealthStatus,
        photoData: Data?
    ) {
        let request = PlantCareCommandRequest(
            careType: careType,
            plant: plant,
            executorID: activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
        let result = PlantCareCommandExecutor(context: modelContext, services: appServices).recordCare(
            request,
            note: "plant.feature.care",
            options: PlantCareCommandOptions()
        )
        UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        if result.didPersist {
            scheduleRouteSnapshotRefresh(force: true, delayMilliseconds: 0)
        }
    }

    private func scheduleRouteSnapshotRefresh(force: Bool = false, delayMilliseconds: UInt64 = 24) {
        let request = routeSnapshotRequest
        guard force || routeSnapshot.requestKey != request.key || !routeSnapshot.hasLoaded else { return }
        routeSnapshotRefreshTask?.cancel()
        routeSnapshotRefreshGeneration += 1
        let generation = routeSnapshotRefreshGeneration
        let container = modelContext.container
        routeSnapshot = PlantCareFeatureRouteSnapshot.loading(requestKey: request.key, preserving: routeSnapshot)
        routeSnapshotRefreshTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled,
                  generation == routeSnapshotRefreshGeneration else {
                return
            }
            let builder = PlantCareFeatureRouteSnapshotActor(modelContainer: container)
            do {
                let snapshot = try await builder.load(request: request)
                guard !Task.isCancelled,
                      generation == routeSnapshotRefreshGeneration,
                      snapshot.requestKey == routeSnapshotRequest.key else {
                    return
                }
                applyRouteSnapshot(snapshot)
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning("Plant care feature route snapshot load failed: \(error)", category: "Plants")
            }
            clearRouteSnapshotRefreshTask(generation: generation)
        }
    }

    private func applyRouteSnapshot(_ snapshot: PlantCareFeatureRouteSnapshot) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            routeSnapshot = snapshot
        }
    }

    private func clearRouteSnapshotRefreshTask(generation: Int) {
        guard generation == routeSnapshotRefreshGeneration else { return }
        routeSnapshotRefreshTask = nil
    }

    private func plant(for id: UUID) -> Plant? {
        plants.first { $0.id == id }
    }

    private func relativeDateText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fullDateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func healthStatusText(_ status: PlantHealthStatus) -> String {
        switch status {
        case .thriving:
            l.tr(zh: "状态很好", en: "Thriving", de: "Sehr guter Zustand")
        case .stable:
            l.tr(zh: "稳定", en: "Stable", de: "Stabil")
        case .watching:
            l.tr(zh: "需要观察", en: "Needs watching", de: "Beobachten")
        case .stressed:
            l.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst")
        }
    }

    private func healthTint(for status: PlantHealthStatus) -> Color {
        switch status {
        case .thriving:
            Color.goPrimary
        case .stable:
            Color.goTeal
        case .watching:
            Color.goYellow
        case .stressed:
            Color.goRed
        }
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }
}
