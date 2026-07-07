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

private struct PlantCareFeatureLogDraft: Identifiable {
    let id = UUID()
    let plantID: UUID
    let careType: PlantCareType
}

private struct PlantCareFeatureRecord: Identifiable {
    let id: UUID
    let plantID: UUID
    let plantName: String
    let date: Date
    let careType: PlantCareType
    let note: String
    let healthStatus: PlantHealthStatus?
}

private struct PlantWateringChartPoint: Identifiable {
    let id: String
    let date: Date
    let intervalDays: Int
}

private struct PlantWateringSignal: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let tint: Color
}

private struct PlantCareAggregateInsight: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
}

private enum PlantWaterGuidedMode: String, CaseIterable, Identifiable {
    case overview
    case plan
    case history

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview:
            "drop.circle.fill"
        case .plan:
            "calendar.badge.clock"
        case .history:
            "clock.arrow.circlepath"
        }
    }

    func title(l: L10n) -> String {
        switch self {
        case .overview:
            l.tr(zh: "概览", en: "Overview", de: "Übersicht")
        case .plan:
            l.tr(zh: "计划", en: "Plan", de: "Plan")
        case .history:
            l.tr(zh: "历史", en: "History", de: "Verlauf")
        }
    }
}

private enum WaterReminderLeadOption: Int, CaseIterable, Identifiable {
    case sameDay = 0
    case oneDay = 1
    case twoDays = 2
    case oneWeek = 7

    var id: Int { rawValue }

    func title(l: L10n) -> String {
        switch self {
        case .sameDay:
            l.tr(zh: "当天", en: "Same day", de: "Am selben Tag")
        case .oneDay:
            l.tr(zh: "提前 1 天", en: "1 day before", de: "1 Tag vorher")
        case .twoDays:
            l.tr(zh: "提前 2 天", en: "2 days before", de: "2 Tage vorher")
        case .oneWeek:
            l.tr(zh: "提前 7 天", en: "7 days before", de: "7 Tage vorher")
        }
    }
}

struct PlantCareFeatureDetailView: View {
    let plants: [Plant]
    let feature: PlantCareFeatureDestination
    let focusedPlantID: UUID?
    let focusedCareType: PlantCareType?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
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
    @Namespace private var waterModeSelectionNamespace

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
    private var records: [PlantCareFeatureRecord] {
        scopedPlants
            .flatMap { plant in
                plant.careLogs
                    .filter { matchesFocusedFeature($0.careType) }
                    .map { log in
                        PlantCareFeatureRecord(
                            id: log.id,
                            plantID: plant.id,
                            plantName: plant.name,
                            date: log.date,
                            careType: log.careType,
                            note: log.note.trimmingCharacters(in: .whitespacesAndNewlines),
                            healthStatus: log.healthStatus
                        )
                    }
            }
            .sorted { $0.date > $1.date }
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
        }
        .onChange(of: focusedPlantID) {
            selectedWaterMode = .overview
            refreshWaterScheduleControls()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-header")
    }

    private var summaryBand: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                value: "\(records.count)",
                tint: feature.tint
            )
            metricTile(
                id: "latest",
                icon: "calendar",
                title: l.tr(zh: "最近一次", en: "Latest", de: "Zuletzt"),
                value: latestRecordDate.map(relativeDateText) ?? l.tr(zh: "暂无", en: "None", de: "Keine"),
                tint: Color.goTeal
            )
            metricTile(
                id: "due",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "待处理", en: "Due", de: "Fällig"),
                value: "\(duePlantCount)",
                tint: duePlantCount > 0 ? Color.goYellow : Color.goTeal
            )
        }
    }

    private var duePlantCount: Int {
        duePlantsForFeature.count
    }

    private var aggregateComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "照护比较", en: "Care comparison", de: "Pflegevergleich"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(insight.value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(insight.detail)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text(value)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
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
            waterModeStrip(for: plant)
            waterPrimaryTaskCard(for: plant)

            switch selectedWaterMode {
            case .overview:
                waterGuidedMiniChartCard(for: plant)
                waterCompactDiscoveryDock(for: plant)
            case .plan:
                waterScheduleControlSection(plant)
            case .history:
                waterGuidedMiniChartCard(for: plant)
                recordSection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-guided-home")
    }

    private func waterModeStrip(for _: Plant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Label(l.tr(zh: "浇水模式", en: "Watering mode", de: "Gießmodus"), systemImage: "switch.2")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                Text(selectedWaterMode.title(l: l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                ForEach(PlantWaterGuidedMode.allCases) { mode in
                    let isSelected = selectedWaterMode == mode
                    Button {
                        OhanaFeedback.light()
                        withAnimation(GoMotion.selection) {
                            selectedWaterMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(OhanaFont.adaptive(size: 12, weight: .black))
                                .accessibilityHidden(true)
                            Text(mode.title(l: l))
                                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                    .fill(Color.goTeal)
                                    .matchedGeometryEffect(id: "plant-water-mode-selection", in: waterModeSelectionNamespace)
                            } else {
                                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                    .fill(Color.goTeal.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("plant-care-feature-water-mode-\(mode.rawValue)")
                }
            }
        }
        .padding(13)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-mode-strip")
    }

    private func waterPrimaryTaskCard(for plant: Plant) -> some View {
        let task = wateringTask(for: plant)
        let signals = Array(waterSignals(for: plant, task: task).prefix(3))
        let advice = waterAdviceItems(for: plant, task: task).first
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "浇水", en: "Watering", de: "Gießen"), systemImage: "drop.fill")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.goTeal, in: Capsule())

                Spacer()

                Button {
                    OhanaFeedback.light()
                    withAnimation(GoMotion.selection) {
                        selectedWaterMode = .plan
                    }
                } label: {
                    Image(systemName: "gearshape.fill") // a11y: allow decorative plan glyph; accessibilityLabel names the button.
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                        .contentShape(Circle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "管理浇水计划", en: "Manage watering plan", de: "Gießplan verwalten"))
                .accessibilityIdentifier("plant-care-feature-water-card-plan")
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(waterPrimaryTitle(for: plant, task: task))
                        .font(OhanaFont.adaptive(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(waterHabitSummary(for: plant, task: task))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 8)

                Text(waterPrimaryMetricValue(for: plant, task: task))
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 8) {
                ForEach(signals) { signal in
                    waterGuidedMetricPill(signal)
                }
            }

            if let advice {
                waterGuidedNotice(text: advice, tint: Color.goTeal)
            }

            Button {
                OhanaFeedback.medium()
                quickRecordWater(for: plant)
            } label: {
                Label(l.tr(zh: "快速记录已浇水", en: "Log watered now", de: "Jetzt Gießen erfassen"), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.goTeal, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-care-feature-water-quick-log")
        }
        .padding(16)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-primary-card")
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

    private func waterGuidedMetricPill(_ signal: PlantWateringSignal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(signal.title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
            Text(signal.value)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(signal.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(signal.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func waterGuidedNotice(text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative advice marker; text carries the content.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }

    private func waterHabitSection(_ plant: Plant) -> some View {
        let task = wateringTask(for: plant)
        let signals = waterSignals(for: plant, task: task)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "drop.degreesign.fill",
                title: l.tr(zh: "浇水习性与建议", en: "Watering habit and guidance", de: "Gießverhalten und Empfehlung"),
                subtitle: waterHabitSummary(for: plant, task: task),
                tint: Color.goTeal
            )

            waterQuickActionRail(for: plant)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(signals) { signal in
                    waterSignalPill(signal)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(waterAdviceItems(for: plant, task: task), id: \.self) { advice in
                    waterAdviceChip(advice)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-habit")
    }

    private func waterQuickActionRail(for plant: Plant) -> some View {
        HStack(spacing: 10) {
            Button {
                quickRecordWater(for: plant)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill") // a11y: allow decorative quick-log glyph; button text names the action.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .accessibilityHidden(true)
                    Text(l.tr(zh: "快速记录已浇水", en: "Log watered now", de: "Jetzt Gießen erfassen"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.goTeal, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-care-feature-water-quick-log")

            Button {
                openLog(for: plant)
            } label: {
                Image(systemName: "square.and.pencil") // a11y: allow decorative detailed-log glyph; accessibilityLabel names the action.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 48, height: 48)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Circle())
                    .contentShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "添加详细浇水记录", en: "Add detailed water log", de: "Detailliertes Gießprotokoll hinzufügen"))
            .accessibilityIdentifier("plant-care-feature-water-detailed-log")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-quick-actions")
    }

    private func waterScheduleControlSection(_ plant: Plant) -> some View {
        let task = wateringTask(for: plant)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "calendar.badge.clock",
                title: l.tr(zh: "浇水计划与提醒", en: "Watering plan and reminders", de: "Gießplan und Erinnerungen"),
                subtitle: waterReminderSummary(for: plant, task: task),
                tint: Color.goYellow
            )

            Stepper(
                value: Binding(
                    get: { max(1, plant.wateringIntervalDays) },
                    set: { updateWateringInterval($0, for: plant) }
                ),
                in: 1 ... 60
            ) {
                scheduleControlText(
                    title: l.tr(zh: "浇水间隔", en: "Watering interval", de: "Gießintervall"),
                    value: l.tr(zh: "每 \(max(1, plant.wateringIntervalDays)) 天", en: "Every \(max(1, plant.wateringIntervalDays))d", de: "Alle \(max(1, plant.wateringIntervalDays)) T."),
                    footnote: l.tr(zh: "用于计算下一次浇水和循环日历计划。", en: "Used for the next due date and recurring calendar plan.", de: "Wird für Fälligkeit und wiederkehrenden Kalenderplan genutzt.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-interval-stepper")

            DatePicker(
                selection: Binding(
                    get: { waterScheduleStartDate(for: plant) },
                    set: { updateWateringStartDate($0, for: plant) }
                ),
                displayedComponents: [.date]
            ) {
                scheduleControlText(
                    title: l.tr(zh: "起始日期", en: "Start date", de: "Startdatum"),
                    value: fullDateText(waterScheduleStartDate(for: plant)),
                    footnote: l.tr(zh: "按最近一次浇水作为计划起点。", en: "Uses the last watering date as the plan start.", de: "Nutzt das letzte Gießen als Planstart.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-start-date")

            Toggle(isOn: Binding(
                get: { waterScheduleEndEnabled },
                set: { setWaterScheduleEndEnabled($0, for: plant) }
            )) {
                scheduleControlText(
                    title: l.tr(zh: "设置结束日期", en: "Set end date", de: "Enddatum setzen"),
                    value: waterScheduleEndEnabled ? fullDateText(waterScheduleEndDate) : l.tr(zh: "长期循环", en: "No end date", de: "Ohne Enddatum"),
                    footnote: l.tr(zh: "开启后，循环计划会在结束日期停止。", en: "When enabled, the recurring plan stops at this date.", de: "Wenn aktiv, endet der wiederkehrende Plan an diesem Datum.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-end-enabled")

            if waterScheduleEndEnabled {
                DatePicker(
                    selection: Binding(
                        get: { waterScheduleEndDate },
                        set: { setWaterScheduleEndDate($0, for: plant) }
                    ),
                    displayedComponents: [.date]
                ) {
                    scheduleControlText(
                        title: l.tr(zh: "结束日期", en: "End date", de: "Enddatum"),
                        value: fullDateText(waterScheduleEndDate),
                        footnote: l.tr(zh: "计划到这天后停止循环。", en: "The recurring plan stops after this date.", de: "Der Plan endet nach diesem Datum.")
                    )
                }
                .tint(Color.goTeal)
                .frame(minHeight: 58)
                .padding(12)
                .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
                .accessibilityIdentifier("plant-care-feature-water-end-date")
            }

            Toggle(isOn: Binding(
                get: { waterPlanCalendarEnabled },
                set: { setWaterPlanCalendarEnabled($0, for: plant) }
            )) {
                scheduleControlText(
                    title: l.tr(zh: "显示计划到日历", en: "Show plan in calendar", de: "Plan im Kalender zeigen"),
                    value: waterPlanCalendarEnabled ? l.tr(zh: "已显示", en: "Shown", de: "Angezeigt") : l.tr(zh: "不显示", en: "Hidden", de: "Ausgeblendet"),
                    footnote: l.tr(zh: "只控制未来循环计划；不会删除已经完成的护理记录。", en: "Controls only the future recurring plan; completed care logs stay intact.", de: "Steuert nur den zukünftigen Plan; erledigte Einträge bleiben erhalten.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-calendar-toggle")

            Toggle(isOn: Binding(
                get: { waterSystemReminderEnabled },
                set: { setWaterSystemReminderEnabled($0, for: plant) }
            )) {
                scheduleControlText(
                    title: l.tr(zh: "系统提醒", en: "System alerts", de: "Systemhinweise"),
                    value: waterSystemReminderEnabled ? l.tr(zh: "开启", en: "On", de: "Ein") : l.tr(zh: "关闭", en: "Off", de: "Aus"),
                    footnote: l.tr(zh: "关闭后日历计划仍保留，但不会生成提醒或推送。", en: "When off, the calendar plan remains without reminders or push alerts.", de: "Bei Aus bleibt der Kalenderplan ohne Erinnerungen oder Push.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-system-reminder-toggle")

            VStack(alignment: .leading, spacing: 10) {
                scheduleControlText(
                    title: l.tr(zh: "提前提醒时间", en: "Reminder lead time", de: "Vorlaufzeit"),
                    value: waterReminderLeadTitle,
                    footnote: l.tr(zh: "按当前提醒时间窗口发送。", en: "Delivered in the current reminder time window.", de: "Wird im aktuellen Erinnerungsfenster gesendet.")
                )

                Picker(
                    selection: Binding(
                        get: { waterReminderLeadDays },
                        set: { setWaterReminderLeadDays($0, for: plant) }
                    )
                ) {
                    ForEach(WaterReminderLeadOption.allCases) { option in
                        Text(option.title(l: l)).tag(option.rawValue)
                    }
                } label: {
                    Text(l.tr(zh: "提前提醒时间", en: "Reminder lead time", de: "Vorlaufzeit"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .tint(Color.goTeal)
            .opacity(waterSystemReminderEnabled ? 1 : 0.52)
            .disabled(!waterSystemReminderEnabled)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-lead-picker")

            Toggle(isOn: Binding(
                get: { waterCompletionCalendarEnabled },
                set: { setWaterCompletionCalendarEnabled($0, for: plant) }
            )) {
                scheduleControlText(
                    title: l.tr(zh: "护理记录显示在日历", en: "Show completed logs in calendar", de: "Erledigte Einträge im Kalender"),
                    value: waterCompletionCalendarEnabled ? l.tr(zh: "显示", en: "Shown", de: "Angezeigt") : l.tr(zh: "隐藏", en: "Hidden", de: "Ausgeblendet"),
                    footnote: l.tr(zh: "只影响浇水完成记录是否出现在日历；不会删除护理日志。", en: "Controls whether completed watering logs appear in Calendar; care logs are not deleted.", de: "Steuert nur Kalenderanzeige erledigter Einträge; Pflegeprotokolle bleiben erhalten.")
                )
            }
            .tint(Color.goTeal)
            .frame(minHeight: 58)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            .accessibilityIdentifier("plant-care-feature-water-completion-calendar-toggle")

            if let waterSchedulePersistenceError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative error glyph; adjacent text announces the failure.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .accessibilityHidden(true)
                    Text(waterSchedulePersistenceError)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
                .accessibilityIdentifier("plant-care-feature-water-schedule-error")
            }

            Button {
                resyncWaterReminder(for: plant)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath") // a11y: allow decorative sync glyph; button text names the action.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .accessibilityHidden(true)
                    Text(l.tr(zh: "同步浇水日历计划", en: "Sync watering calendar plan", de: "Gießkalender synchronisieren"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-care-feature-water-reminder-sync")
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-schedule")
    }

    private func scheduleControlText(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(footnote)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func waterHistoryChartSection(_ plant: Plant) -> some View {
        waterGuidedMiniChartCard(for: plant)
    }

    private func waterGuidedMiniChartCard(for plant: Plant) -> some View {
        let points = wateringChartPoints(for: plant)
        let chartPoints = wateringBarChartPoints(for: plant)
        let targetDays = appServices.plantCarePlans.intervalDays(for: .watering, plant: plant)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "浇水趋势", en: "Watering trend", de: "Gießtrend"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "只看节奏，详情在历史。", en: "A quiet rhythm. Details in history.", de: "Ruhiger Rhythmus. Details im Verlauf."))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 8)
                Text(l.tr(zh: "目标 \(targetDays) 天", en: "Target \(targetDays)d", de: "Ziel \(targetDays) T."))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            if points.isEmpty {
                emptyWaterChartState(for: plant)
            } else {
                OhanaMinimalBarChart(
                    points: chartPoints,
                    tint: Color.goTeal,
                    progress: 1,
                    showsLabels: true,
                    maxBarHeight: 58
                )
                .frame(height: 88)
                .accessibilityLabel(l.tr(zh: "\(plant.name) 的浇水间隔 mini 图表", en: "\(plant.name) watering interval mini chart", de: "Mini-Gießintervall-Diagramm für \(plant.name)"))
            }
        }
        .padding(13)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-chart")
    }

    private func waterCompactDiscoveryDock(for plant: Plant) -> some View {
        let task = wateringTask(for: plant)
        let adviceItems = waterAdviceItems(for: plant, task: task)
        return VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                waterCompactDiscoveryCard(
                    id: "habit",
                    icon: "humidity.fill",
                    title: l.tr(zh: "习性", en: "Habit", de: "Vorliebe"),
                    value: adviceItems.first ?? plant.humidityPreference.displayName,
                    tint: Color.goTeal,
                    action: nil
                )
                waterCompactDiscoveryCard(
                    id: "plan",
                    icon: "calendar.badge.clock",
                    title: l.tr(zh: "计划", en: "Plan", de: "Plan"),
                    value: waterPlanSummaryText(for: plant, task: task),
                    tint: Color.goYellow
                ) {
                    withAnimation(GoMotion.selection) {
                        selectedWaterMode = .plan
                    }
                }
                waterCompactDiscoveryCard(
                    id: "history",
                    icon: "clock.arrow.circlepath",
                    title: l.tr(zh: "历史", en: "History", de: "Verlauf"),
                    value: waterHistorySummaryText(for: plant),
                    tint: feature.tint
                ) {
                    withAnimation(GoMotion.selection) {
                        selectedWaterMode = .history
                    }
                }
                waterCompactDiscoveryCard(
                    id: "detail",
                    icon: "square.and.pencil",
                    title: l.tr(zh: "详细记录", en: "Detail log", de: "Detailprotokoll"),
                    value: l.tr(zh: "照片/备注", en: "Photo + note", de: "Foto + Notiz"),
                    tint: feature.tint
                ) {
                    openLog(for: plant)
                }
            }

            if adviceItems.count > 1 {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                    ForEach(Array(adviceItems.dropFirst().prefix(2)), id: \.self) { advice in
                        waterAdviceChip(advice)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-discovery-dock")
    }

    private func waterCompactDiscoveryCard(
        id: String,
        icon: String,
        title: String,
        value: String,
        tint: Color,
        action: (() -> Void)?
    ) -> some View {
        Group {
            if let action {
                Button {
                    OhanaFeedback.light()
                    action()
                } label: {
                    waterCompactDiscoveryCardContent(icon: icon, title: title, value: value, tint: tint, isInteractive: true)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                waterCompactDiscoveryCardContent(icon: icon, title: title, value: value, tint: tint, isInteractive: false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-water-dock-\(id)")
    }

    private func waterCompactDiscoveryCardContent(
        icon: String,
        title: String,
        value: String,
        tint: Color,
        isInteractive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34) // a11y: allow visual glyph frame; card text carries the accessible content.
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                if isInteractive {
                    Image(systemName: "chevron.right") // a11y: allow decorative affordance; card label names the action.
                        .font(OhanaFont.adaptive(size: 9, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }
            }

            Text(value)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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

    private func waterHistorySummaryText(for _: Plant) -> String {
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

            if records.isEmpty {
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

    private func sectionHeader(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36) // a11y: allow non-interactive header glyph; text carries the accessible content.
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func waterSignalPill(_ signal: PlantWateringSignal) -> some View {
        HStack(spacing: 9) {
            Image(systemName: signal.icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(signal.tint)
                .frame(width: 30, height: 30) // a11y: allow non-interactive metric glyph; label and value carry the accessible content.
                .background(signal.tint.opacity(0.13), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(signal.title)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(signal.value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-water-signal-\(signal.id)")
    }

    private func waterAdviceChip(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative advice marker; chip text carries the content.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.goTeal)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.46), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func emptyWaterChartState(for plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(l.tr(zh: "还没有足够的浇水间隔", en: "Not enough watering intervals yet", de: "Noch nicht genug Gießintervalle"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(wateringLogCount(for: plant) == 0
                ? l.tr(zh: "记录第一次浇水后会开始累积趋势。", en: "The trend starts after the first watering log.", de: "Der Trend beginnt nach dem ersten Gießprotokoll.")
                : l.tr(zh: "再记录一次浇水后会显示实际间隔。", en: "Log one more watering to show the real interval.", de: "Noch einmal gießen erfassen, dann erscheint das echte Intervall."))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(14)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func wateringTask(for plant: Plant) -> PlantCareTaskSnapshot? {
        appServices.plantCarePlans.tasks(for: plant).first { $0.careType == .watering }
    }

    private func waterSignals(for plant: Plant, task: PlantCareTaskSnapshot?) -> [PlantWateringSignal] {
        [
            PlantWateringSignal(
                id: "interval",
                icon: "calendar.badge.clock",
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
                icon: "clock.fill",
                title: l.tr(zh: "下次", en: "Next", de: "Nächstes"),
                value: task.map(waterDueText) ?? l.tr(zh: "无计划", en: "No plan", de: "Kein Plan"),
                tint: task?.daysUntilDue ?? 1 <= 0 ? Color.goYellow : Color.goPrimary
            ),
            PlantWateringSignal(
                id: "last",
                icon: "drop.circle.fill",
                title: l.tr(zh: "上次", en: "Last", de: "Zuletzt"),
                value: plant.daysSinceWatered.map {
                    l.tr(zh: "\($0) 天前", en: "\($0)d ago", de: "vor \($0) T.")
                } ?? l.tr(zh: "暂无", en: "None", de: "Keine"),
                tint: Color.goTeal
            ),
            PlantWateringSignal(
                id: "humidity",
                icon: "humidity.fill",
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

    private func wateringChartPoints(for plant: Plant) -> [PlantWateringChartPoint] {
        let wateringLogs = plant.careLogs
            .filter { $0.careType == .watering }
            .sorted { $0.date < $1.date }
        guard wateringLogs.count >= 2 else { return [] }

        var points: [PlantWateringChartPoint] = []
        for index in wateringLogs.indices.dropFirst() {
            let previous = Calendar.current.startOfDay(for: wateringLogs[index - 1].date)
            let current = Calendar.current.startOfDay(for: wateringLogs[index].date)
            let days = max(0, Calendar.current.dateComponents([.day], from: previous, to: current).day ?? 0)
            points.append(PlantWateringChartPoint(
                id: wateringLogs[index].id.uuidString,
                date: wateringLogs[index].date,
                intervalDays: days
            ))
        }
        return Array(points.suffix(10))
    }

    private func wateringBarChartPoints(for plant: Plant) -> [OhanaMinimalChartPoint] {
        wateringChartPoints(for: plant).map { point in
            OhanaMinimalChartPoint(
                date: point.date,
                value: Double(point.intervalDays),
                label: point.date.formatted(.dateTime.month(.abbreviated).day()),
                id: point.id
            )
        }
    }

    private func wateringLogCount(for plant: Plant) -> Int {
        plant.careLogs.count { $0.careType == .watering }
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
        waterPlanCalendarEnabled = PlantReminderPreferenceStore.isPlanCalendarEnabled(
            forPlantID: focusedPlant.id,
            careType: .watering,
            fallback: PlantReminderPreferenceStore.planCalendarFallback(
                for: .watering,
                plantRemindersEnabled: focusedPlant.remindersEnabled
            )
        )
        waterSystemReminderEnabled = PlantReminderPreferenceStore.isSystemReminderEnabled(
            forPlantID: focusedPlant.id,
            careType: .watering
        )
        waterCompletionCalendarEnabled = PlantReminderPreferenceStore.isCompletionCalendarEnabled(
            forPlantID: focusedPlant.id,
            careType: .watering
        )
        waterReminderLeadDays = PlantReminderPreferenceStore.reminderLeadDays(
            forPlantID: focusedPlant.id,
            careType: .watering
        )
        if let endDate = PlantReminderPreferenceStore.recurrenceEndDate(
            forPlantID: focusedPlant.id,
            careType: .watering
        ) {
            waterScheduleEndEnabled = true
            waterScheduleEndDate = endDate
        } else {
            waterScheduleEndEnabled = false
            waterScheduleEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        }
    }

    private func waterScheduleStartDate(for plant: Plant) -> Date {
        plant.lastWateredDate ?? plant.createdAt
    }

    private func updateWateringInterval(_ days: Int, for plant: Plant) {
        let clampedDays = min(max(days, 1), 60)
        guard plant.wateringIntervalDays != clampedDays else { return }
        plant.wateringIntervalDays = clampedDays
        persistWateringScheduleFacts(for: plant)
    }

    private func updateWateringStartDate(_ date: Date, for plant: Plant) {
        let startDate = Calendar.current.startOfDay(for: date)
        guard plant.lastWateredDate.map({ Calendar.current.isDate($0, inSameDayAs: startDate) }) != true else { return }
        plant.lastWateredDate = startDate
        persistWateringScheduleFacts(for: plant)
    }

    private func setWaterScheduleEndEnabled(_ enabled: Bool, for plant: Plant) {
        waterScheduleEndEnabled = enabled
        let endDate = enabled ? Calendar.current.startOfDay(for: waterScheduleEndDate) : nil
        PlantReminderPreferenceStore.setRecurrenceEndDate(endDate, forPlantID: plant.id, careType: .watering)
        resyncWaterSchedule(for: plant)
    }

    private func setWaterScheduleEndDate(_ date: Date, for plant: Plant) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        waterScheduleEndDate = normalizedDate
        PlantReminderPreferenceStore.setRecurrenceEndDate(normalizedDate, forPlantID: plant.id, careType: .watering)
        resyncWaterSchedule(for: plant)
    }

    private func setWaterReminderLeadDays(_ days: Int, for plant: Plant) {
        waterReminderLeadDays = days
        PlantReminderPreferenceStore.setReminderLeadDays(days, forPlantID: plant.id, careType: .watering)
        resyncWaterSchedule(for: plant)
    }

    @discardableResult
    private func persistWateringScheduleFacts(for plant: Plant) -> Bool {
        CloudSyncMutationRecorder.markModified(plant, context: modelContext)
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            waterSchedulePersistenceError = waterScheduleSaveFailureMessage(saveResult.errorDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
        waterSchedulePersistenceError = nil
        resyncWaterSchedule(for: plant)
        return true
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

    private func resyncWaterSchedule(for plant: Plant) {
        appServices.plantReminderControls.resyncPlans(plants: [plant], context: modelContext)
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
        PlantReminderPreferenceStore.setPlanCalendarEnabled(enabled, forPlantID: plant.id, careType: .watering)
        resyncWaterSchedule(for: plant)
        publishWaterPreferenceRefresh(for: plant, action: "waterPlanCalendar")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func setWaterSystemReminderEnabled(_ enabled: Bool, for plant: Plant) {
        waterSystemReminderEnabled = enabled
        PlantReminderPreferenceStore.setSystemReminderEnabled(enabled, forPlantID: plant.id, careType: .watering)
        resyncWaterSchedule(for: plant)
        publishWaterPreferenceRefresh(for: plant, action: "waterSystemReminder")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func setWaterCompletionCalendarEnabled(_ enabled: Bool, for plant: Plant) {
        waterCompletionCalendarEnabled = enabled
        PlantReminderPreferenceStore.setCompletionCalendarEnabled(enabled, forPlantID: plant.id, careType: .watering)
        publishWaterPreferenceRefresh(for: plant, action: "waterCompletionCalendar")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resyncWaterReminder(for plant: Plant) {
        appServices.plantReminderControls.resyncPlans(plants: [plant], context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func publishWaterPreferenceRefresh(for plant: Plant, action: String) {
        appServices.domainRevisions.publish(
            DomainMutationResult(
                command: .plantCare(plantID: plant.id, action: action),
                affectedEntityIDs: [plant.id],
                wroteBusinessFact: false,
                note: "plant.water.preference"
            )
        )
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

    private func featureRecords(for plant: Plant) -> [PlantCareLog] {
        plant.careLogs.filter { matchesFocusedFeature($0.careType) }
    }

    private var duePlantsForFeature: [Plant] {
        guard feature.category?.isSchedulable == true else { return [] }
        return scopedPlants.filter { plant in
            appServices.plantCarePlans.tasks(for: plant).contains {
                matchesFocusedFeature($0.careType) && $0.daysUntilDue <= 0
            }
        }
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
        switch feature {
        case .water:
            max(1, appServices.plantCarePlans.intervalDays(for: .watering, plant: plant))
        case .fertilize:
            max(1, appServices.plantCarePlans.intervalDays(for: .fertilizing, plant: plant))
        case .maintenance, .health:
            max(1, appServices.plantCarePlans.intervalDays(for: primaryCareType, plant: plant))
        case .growth:
            30
        case .log:
            30
        }
    }

    private func overdueDays(for plant: Plant) -> Int {
        let planned = plannedIntervalDays(for: plant)
        guard let daysSinceFeatureCare = daysSinceFeatureCare(for: plant) else { return planned }
        return max(0, daysSinceFeatureCare - planned)
    }

    private func featureCadenceDates(for plant: Plant) -> [Date] {
        plant.careLogs
            .filter { log in
                switch feature {
                case .water:
                    matchesFocusedFeature(log.careType)
                case .fertilize:
                    matchesFocusedFeature(log.careType)
                case .maintenance, .health, .growth, .log:
                    matchesFocusedFeature(log.careType)
                }
            }
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
        let result = HomeCommandExecutor(modelContext: modelContext, services: appServices).recordPlantCare(
            careType,
            plant: plant,
            executorId: activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
        UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
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
