//
//  PlantDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

private struct PlantDetailActionItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let primaryTitle: String
    let careType: PlantCareType?
    let task: PlantCareTaskSnapshot?
    let opensEdit: Bool
}

private struct PlantCarePlanInsight: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private struct PlantHealthReviewSignal: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let priority: Int
}

private enum PlantDetailFeatureAnchor: Hashable {
    case overview
    case todayCare
    case carePlan
    case profile
    case safety
    case knowledge
    case healthReview
    case growthDiary
    case timeline
}

struct PlantDetailPhotoItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let imageData: Data
    let tint: Color
}

struct PlantDetailContentView: View {
    let plant: Plant
    let households: [Household]
    let onOpenCalendar: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage("ohana_onboarding_has_pets") private var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") private var onboardingHasChildren = false

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingEditSheet = false
    @State private var showingAllFeaturesHub = false
    @State private var showingDeleteConfirm = false
    @State private var showingPhotoGallery = false
    @State private var careLogDraftType: PlantCareType?
    @State private var isDeletePending = false
    @State private var deleteUndoTask: Task<Void, Never>?
    @State private var diagnosisResult: PlantDiagnosisResult?
    @State private var pendingFeatureScrollTarget: PlantDetailFeatureAnchor?
    private var catalogEntry: PlantCatalogEntry? { PlantCatalog.entry(id: plant.catalogSpeciesId) }
    private var l: L10n { L10n(appLanguage) }
    private var careTasks: [PlantCareTaskSnapshot] { appServices.plantCarePlans.tasks(for: plant) }
    private var isWateringDue: Bool {
        careTasks.contains { $0.careType == .watering && $0.daysUntilDue <= 0 }
    }
    private var isFertilizingDue: Bool {
        careTasks.contains { $0.careType == .fertilizing && $0.daysUntilDue <= 0 }
    }
    var wateringIntervalDays: Int {
        careTasks.first { $0.careType == .watering }?.effectiveIntervalDays ?? plant.wateringIntervalDays
    }
    var fertilizingIntervalDays: Int {
        careTasks.first { $0.careType == .fertilizing }?.effectiveIntervalDays ?? plant.fertilizingIntervalDays
    }
    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }
    private var recentLogs: [PlantCareLog] {
        plant.careLogs.sorted { $0.date > $1.date }
    }
    private var nextTask: PlantCareTaskSnapshot? { careTasks.first }
    private var dueTaskCount: Int { careTasks.count { $0.daysUntilDue <= 0 } }
    private var placementSummary: String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactSpot = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !exactSpot.isEmpty, room != exactSpot {
            return "\(room) · \(exactSpot)"
        }
        if !room.isEmpty { return room }
        if !exactSpot.isEmpty { return exactSpot }
        return l.tr(zh: "未设置位置", en: "No location set", de: "Kein Standort")
    }
    private var healthTone: Color {
        switch plant.healthStatus {
        case .thriving:
            Color.goLime
        case .stable:
            Color.goTeal
        case .watching:
            Color.goYellow
        case .stressed:
            Color.goRed
        }
    }
    private var healthSummaryText: String {
        switch plant.healthStatus {
        case .thriving:
            l.tr(zh: "叶片和节奏都很好", en: "Leaves and rhythm look good", de: "Blätter und Rhythmus wirken gut")
        case .stable:
            l.tr(zh: "维持当前护理节奏", en: "Keep the current care rhythm", de: "Aktuellen Pflegerhythmus beibehalten")
        case .watching:
            l.tr(zh: "建议观察叶片和土壤", en: "Watch leaves and soil", de: "Blätter und Erde beobachten")
        case .stressed:
            l.tr(zh: "优先排查浇水、光照和虫害", en: "Check water, light, and pests first", de: "Zuerst Wasser, Licht und Schädlinge prüfen")
        }
    }
    private var wateringStatusText: String {
        guard let days = plant.daysSinceWatered else {
            return l.tr(zh: "还没有浇水记录", en: "No watering records yet", de: "Noch keine Gießprotokolle")
        }
        return l.tr(zh: "距上次 \(days) 天", en: "\(days)d since last", de: "\(days) T. seitdem")
    }
    private var fertilizingStatusText: String {
        guard let days = plant.daysSinceFertilized else {
            return l.tr(zh: "还没有施肥记录", en: "No fertilizing records yet", de: "Noch keine Düngeprotokolle")
        }
        return l.tr(zh: "距上次 \(days) 天", en: "\(days)d since last", de: "\(days) T. seitdem")
    }
    private var activeSafetyWarningCount: Int {
        [
            onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs),
            onboardingHasChildren && plant.isToxicToChildren,
            !plant.isIndoorSuitable,
            plant.isNearClimateSource
        ].count { $0 }
    }
    private var growthDiaryPhotoCount: Int {
        recentLogs.count { $0.photoData != nil }
    }
    private var recentObservationWindowStart: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date().addingTimeInterval(-30 * 86400)
    }
    private var latestHealthReviewLog: PlantCareLog? {
        recentLogs.first { log in
            [
                PlantCareType.pestCheck,
                .pestFound,
                .yellowLeaf,
                .newLeaf,
                .leafCleaning,
                .photo,
                .customNote
            ].contains(log.careType)
        }
    }
    private var recentStressSignalLogs: [PlantCareLog] {
        recentLogs.filter { log in
            log.date >= recentObservationWindowStart &&
                (log.careType == .yellowLeaf || log.careType == .pestFound)
        }
    }
    private var recentObservationLogCount: Int {
        recentLogs.count { log in
            log.date >= recentObservationWindowStart &&
                [
                    PlantCareType.pestCheck,
                    .pestFound,
                    .yellowLeaf,
                    .newLeaf,
                    .leafCleaning,
                    .photo,
                    .customNote
                ].contains(log.careType)
        }
    }
    private var healthReviewSignals: [PlantHealthReviewSignal] {
        var signals: [PlantHealthReviewSignal] = []

        if plant.healthStatus == .stressed || plant.healthStatus == .watching {
            signals.append(
                PlantHealthReviewSignal(
                    id: "status",
                    icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "eye.fill",
                    title: plant.healthStatus == .stressed
                        ? l.tr(zh: "健康状态紧张", en: "Health is stressed", de: "Gesundheit ist angespannt")
                        : l.tr(zh: "需要持续观察", en: "Needs watching", de: "Weiter beobachten"),
                    detail: healthSummaryText,
                    tint: plant.healthStatus == .stressed ? Color.goRed : Color.goYellow,
                    priority: 0
                )
            )
        }

        if !recentStressSignalLogs.isEmpty {
            signals.append(
                PlantHealthReviewSignal(
                    id: "recent-stress",
                    icon: "waveform.path.ecg",
                    title: l.tr(zh: "30 天内有异常信号", en: "Recent stress signals", de: "Aktuelle Stresssignale"),
                    detail: l.tr(
                        zh: "\(recentStressSignalLogs.count) 条黄叶/虫害记录，建议先复查叶背、土面和新芽。",
                        en: "\(recentStressSignalLogs.count) yellow-leaf or pest notes in 30 days. Recheck leaf undersides, soil, and new growth.",
                        de: "\(recentStressSignalLogs.count) Gelbblatt- oder Schädlingsnotizen in 30 Tagen. Blattunterseiten, Erde und Neutriebe prüfen."
                    ),
                    tint: Color.goRed,
                    priority: 1
                )
            )
        }

        if latestHealthReviewLog == nil {
            signals.append(
                PlantHealthReviewSignal(
                    id: "no-review",
                    icon: "stethoscope",
                    title: l.tr(zh: "还没有健康观察", en: "No health review yet", de: "Noch kein Gesundheitscheck"),
                    detail: l.tr(
                        zh: "记录一次叶片/虫害复查，后续时间线会更像完整植物病历。",
                        en: "Log one leaf or pest check so the timeline becomes a real plant health record.",
                        de: "Einen Blatt- oder Schädlingscheck erfassen, damit die Zeitachse zur echten Pflanzenakte wird."
                    ),
                    tint: Color.goTeal,
                    priority: 2
                )
            )
        }

        if plant.isNearClimateSource || !plant.potHasDrainage {
            let factors = [
                plant.isNearClimateSource ? l.tr(zh: "靠近空调/暖气", en: "near AC/heater", de: "nahe Klima/Heizung") : nil,
                !plant.potHasDrainage ? l.tr(zh: "无排水孔", en: "no drainage", de: "ohne Abzug") : nil
            ].compactMap(\.self)
            signals.append(
                PlantHealthReviewSignal(
                    id: "environment-risk",
                    icon: "humidity.fill",
                    title: l.tr(zh: "环境会放大风险", en: "Environment raises risk", de: "Umgebung erhöht Risiko"),
                    detail: factors.joined(separator: " · "),
                    tint: Color.goYellow,
                    priority: 3
                )
            )
        }

        if activeSafetyWarningCount > 0 {
            signals.append(
                PlantHealthReviewSignal(
                    id: "safety",
                    icon: "shield.checkered",
                    title: l.tr(zh: "安全摆放待复核", en: "Safe placement needs review", de: "Sicherer Standort prüfen"),
                    detail: l.tr(
                        zh: "\(activeSafetyWarningCount) 个家庭安全提示会影响摆放和提醒文案。",
                        en: "\(activeSafetyWarningCount) household safety notes affect placement and reminders.",
                        de: "\(activeSafetyWarningCount) Sicherheitshinweise beeinflussen Standort und Erinnerungen."
                    ),
                    tint: Color.goYellow,
                    priority: 4
                )
            )
        }

        if signals.isEmpty {
            signals.append(
                PlantHealthReviewSignal(
                    id: "clear",
                    icon: "checkmark.seal.fill",
                    title: l.tr(zh: "暂未发现高优先级异常", en: "No high-priority issues", de: "Keine dringenden Auffälligkeiten"),
                    detail: l.tr(
                        zh: "继续按计划护理，观察新叶、叶色和土壤湿度即可。",
                        en: "Keep the current plan and watch new leaves, color, and soil moisture.",
                        de: "Plan beibehalten und neue Blätter, Farbe und Erdfeuchte beobachten."
                    ),
                    tint: Color.goLime,
                    priority: 9
                )
            )
        }

        return signals.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    private var healthReviewSummaryText: String {
        if plant.healthStatus == .stressed {
            return l.tr(zh: "先排查浇水、光照、虫害，再考虑施肥。", en: "Check water, light, and pests before fertilizing.", de: "Wasser, Licht und Schädlinge vor dem Düngen prüfen.")
        }
        if plant.healthStatus == .watching || !recentStressSignalLogs.isEmpty {
            return l.tr(zh: "把最近异常和复查动作放在同一张卡里，避免只看流水记录。", en: "Recent issues and rechecks are grouped here instead of buried in the log.", de: "Auffälligkeiten und Checks stehen hier statt nur im Verlauf.")
        }
        if latestHealthReviewLog == nil {
            return l.tr(zh: "补一次健康观察后，这里会形成植物的简版病历摘要。", en: "Add one health review to build a compact plant medical summary.", de: "Ein Gesundheitscheck baut hier eine kompakte Pflanzenakte auf.")
        }
        return l.tr(zh: "状态稳定，继续按计划护理并定期复查。", en: "Stable now; keep the plan and recheck routinely.", de: "Aktuell stabil; Plan beibehalten und regelmäßig prüfen.")
    }
    private var latestHealthReviewText: String {
        guard let latestHealthReviewLog else {
            return l.tr(zh: "未记录", en: "Not logged", de: "Nicht erfasst")
        }
        return "\(latestHealthReviewLog.careType.displayName) · \(shortDate(latestHealthReviewLog.date))"
    }
    private var galleryPhotoItems: [PlantDetailPhotoItem] {
        var items: [PlantDetailPhotoItem] = []

        if let avatarImageData = plant.avatarImageData {
            items.append(
                PlantDetailPhotoItem(
                    id: "\(plant.id.uuidString)-profile",
                    title: plant.name,
                    subtitle: l.tr(zh: "档案照片", en: "Profile photo", de: "Profilfoto"),
                    detail: placementSummary,
                    imageData: avatarImageData,
                    tint: healthTone
                )
            )
        }

        items += recentLogs.compactMap { log -> PlantDetailPhotoItem? in
            guard let photoData = log.photoData else { return nil }
            return PlantDetailPhotoItem(
                id: "\(plant.id.uuidString)-log-\(log.id.uuidString)",
                title: log.careType.displayName,
                subtitle: timelineDateText(for: log),
                detail: timelineNoteText(for: log) ?? plant.name,
                imageData: photoData,
                tint: careTint(for: log.careType)
            )
        }

        return items
    }
    private var growthDiaryMarkdown: String {
        PlantGrowthDiaryExportService.markdown(
            for: plant,
            includePhotoPlaceholders: true,
            languageCode: appLanguage
        )
    }
    private var growthDiaryDateRangeText: String {
        guard let first = recentLogs.last?.date else {
            return l.tr(zh: "还没有记录", en: "No logs yet", de: "Noch keine Protokolle")
        }
        guard let latest = recentLogs.first?.date, latest != first else {
            return shortDate(first)
        }
        return "\(shortDate(first)) - \(shortDate(latest))"
    }
    private var growthDiarySummaryText: String {
        if recentLogs.isEmpty {
            return l.tr(
                zh: "完成一次照护或观察后，这里会生成可分享的成长档案。",
                en: "Log one care action or observation to create a shareable growth diary.",
                de: "Eine Pflegeaktion oder Beobachtung erstellt hier ein teilbares Wachstumstagebuch."
            )
        }
        return l.tr(
            zh: "\(recentLogs.count) 条记录，\(growthDiaryPhotoCount) 张照片线索，覆盖 \(growthDiaryDateRangeText)。",
            en: "\(recentLogs.count) logs, \(growthDiaryPhotoCount) photo notes, covering \(growthDiaryDateRangeText).",
            de: "\(recentLogs.count) Protokolle, \(growthDiaryPhotoCount) Foto-Hinweise, Zeitraum \(growthDiaryDateRangeText)."
        )
    }
    private var profileMissingItems: [String] {
        var items: [String] = []
        if plant.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(l.tr(zh: "品种", en: "species", de: "Art"))
        }
        if plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plant.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(l.tr(zh: "摆放位置", en: "placement", de: "Standort"))
        }
        if plant.potDiameterCm == 0, plant.soilType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(l.tr(zh: "盆土", en: "potting", de: "Topf/Erde"))
        }
        if catalogEntry == nil {
            items.append(l.tr(zh: "资料库匹配", en: "catalog match", de: "Katalogabgleich"))
        }
        if recentLogs.isEmpty {
            items.append(l.tr(zh: "首条护理记录", en: "first care log", de: "erstes Pflegeprotokoll"))
        }
        return items
    }
    private var profileCompletionPercent: Int {
        let total = 5
        let completed = max(0, total - profileMissingItems.count)
        return Int((Double(completed) / Double(total) * 100).rounded())
    }
    private var carePlanInsights: [PlantCarePlanInsight] {
        var insights: [PlantCarePlanInsight] = []

        if let catalogEntry {
            insights.append(
                PlantCarePlanInsight(
                    id: "catalog-baseline",
                    icon: "books.vertical.fill",
                    title: l.tr(zh: "资料库基准", en: "Catalog baseline", de: "Katalogbasis"),
                    detail: l.tr(
                        zh: "\(catalogEntry.localizedCommonName) · 难度 \(catalogEntry.localizedCareDifficulty) · 基准浇水 \(catalogEntry.defaultWateringDays) 天",
                        en: "\(catalogEntry.localizedCommonName) · \(catalogEntry.localizedCareDifficulty) · baseline watering \(catalogEntry.defaultWateringDays)d",
                        de: "\(catalogEntry.localizedCommonName) · \(catalogEntry.localizedCareDifficulty) · Basis-Gießen \(catalogEntry.defaultWateringDays) T."
                    ),
                    tint: Color.goLime
                )
            )
        } else {
            insights.append(
                PlantCarePlanInsight(
                    id: "catalog-missing",
                    icon: "questionmark.folder.fill",
                    title: l.tr(zh: "缺少资料库匹配", en: "Catalog match missing", de: "Katalogabgleich fehlt"),
                    detail: l.tr(
                        zh: "匹配品种后，浇水、施肥和安全提示会更贴合这株植物。",
                        en: "Match a species to tune watering, fertilizing, and safety guidance.",
                        de: "Mit Artabgleich werden Gießen, Düngen und Sicherheit genauer."
                    ),
                    tint: Color.goYellow
                )
            )
        }

        insights.append(environmentCarePlanInsight)

        if let learned = careTasks.first(where: { !$0.learningSummary.isEmpty })?.learningSummary {
            insights.append(
                PlantCarePlanInsight(
                    id: "history-learning",
                    icon: "chart.line.uptrend.xyaxis",
                    title: l.tr(zh: "已学习你的护理反馈", en: "Learning from your care rhythm", de: "Lernt aus deinem Pflegerhythmus"),
                    detail: learned,
                    tint: Color.goTeal
                )
            )
        } else {
            insights.append(
                PlantCarePlanInsight(
                    id: "history-building",
                    icon: "clock.badge.checkmark.fill",
                    title: l.tr(zh: "正在建立历史节奏", en: "Building care history", de: "Pflegeverlauf wird aufgebaut"),
                    detail: recentLogs.isEmpty
                        ? l.tr(zh: "先完成几次护理记录，Ohana 才能判断你是否经常提前或延后。", en: "Log a few care actions so Ohana can see whether you often act early or late.", de: "Einige Pflegeaktionen protokollieren, damit Ohana frühe oder späte Muster erkennt.")
                        : l.tr(zh: "\(recentLogs.count) 条记录已进入档案，继续记录会让节奏更稳。", en: "\(recentLogs.count) logs are in the profile; more logs make the rhythm steadier.", de: "\(recentLogs.count) Protokolle sind im Profil; mehr Verlauf stabilisiert den Rhythmus."),
                    tint: Color.goTeal
                )
            )
        }

        insights.append(healthCarePlanInsight)
        return insights
    }

    private var environmentCarePlanInsight: PlantCarePlanInsight {
        let factors = environmentPlanFactors
        return PlantCarePlanInsight(
            id: "environment-adjustment",
            icon: "sun.max.fill",
            title: l.tr(zh: "环境会调整周期", en: "Environment tunes cadence", de: "Umgebung passt Rhythmus an"),
            detail: factors.isEmpty
                ? l.tr(zh: "当前环境信息较稳定，主要按基础周期和历史记录安排。", en: "Current environment looks stable, so the plan leans on baseline cadence and history.", de: "Die Umgebung wirkt stabil; der Plan nutzt vor allem Basisrhythmus und Verlauf.")
                : factors.joined(separator: " · "),
            tint: Color.goYellow
        )
    }

    private var environmentPlanFactors: [String] {
        var factors: [String] = []
        if plant.lightLevel == .direct || plant.windowDirection == .south || plant.windowDirection == .west {
            factors.append(l.tr(zh: "强光位置会更快消耗水分", en: "strong light dries soil faster", de: "starkes Licht trocknet Erde schneller"))
        }
        if plant.lightLevel == .low {
            factors.append(l.tr(zh: "弱光会放慢水分消耗", en: "low light slows water use", de: "wenig Licht verlangsamt Wasserverbrauch"))
        }
        if plant.isNearClimateSource {
            factors.append(l.tr(zh: "空调/暖气旁需要更频繁观察", en: "AC/heater proximity needs closer checks", de: "Nähe zu Klima/Heizung braucht engere Checks"))
        }
        if plant.humidityPreference == .humid {
            factors.append(l.tr(zh: "偏湿植物会安排喷雾/湿度关注", en: "humid-loving plants get misting and humidity checks", de: "feuchtigkeitsliebende Pflanzen bekommen Feuchte-Checks"))
        }
        if plant.isSucculent {
            factors.append(l.tr(zh: "多肉类会拉长施肥和浇水节奏", en: "succulent traits stretch water and fertilizer cadence", de: "Sukkulenten verlängern Gieß- und Düngeabstände"))
        }
        if plant.isHydroponic {
            factors.append(l.tr(zh: "水培会改变施肥和换盆判断", en: "hydroponic setup changes fertilizer and repotting logic", de: "Hydrokultur ändert Dünge- und Umtopf-Logik"))
        }
        if !plant.potHasDrainage {
            factors.append(l.tr(zh: "无排水孔会提高积水风险", en: "no drainage raises waterlogging risk", de: "ohne Abzug steigt Staunässe-Risiko"))
        }
        return Array(factors.prefix(3))
    }

    private var healthCarePlanInsight: PlantCarePlanInsight {
        switch plant.healthStatus {
        case .thriving:
            PlantCarePlanInsight(
                id: "health-thriving",
                icon: "leaf.circle.fill",
                title: l.tr(zh: "健康状态支持当前节奏", en: "Health supports this rhythm", de: "Gesundheit stützt diesen Rhythmus"),
                detail: l.tr(zh: "状态很好时，计划会保持稳定，不频繁打断。", en: "When the plant is thriving, the plan stays steady and avoids noisy interruptions.", de: "Bei gutem Zustand bleibt der Plan stabil und stört weniger."),
                tint: Color.goLime
            )
        case .stable:
            PlantCarePlanInsight(
                id: "health-stable",
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "稳定状态，优先维持", en: "Stable state, maintain first", de: "Stabiler Zustand, zuerst halten"),
                detail: l.tr(zh: "没有明显压力信号时，计划会以固定护理和轻量观察为主。", en: "Without stress signals, the plan favors routine care and light observation.", de: "Ohne Stresssignale setzt der Plan auf Routinepflege und leichte Beobachtung."),
                tint: Color.goTeal
            )
        case .watching:
            PlantCarePlanInsight(
                id: "health-watching",
                icon: "eye.fill",
                title: l.tr(zh: "需观察，增加复查权重", en: "Watching, checks get priority", de: "Beobachtung, Checks priorisiert"),
                detail: l.tr(zh: "叶片、土壤和虫害复查会排在普通护理前面。", en: "Leaf, soil, and pest checks move ahead of routine care.", de: "Blatt-, Erd- und Schädlingschecks kommen vor Routinepflege."),
                tint: Color.goYellow
            )
        case .stressed:
            PlantCarePlanInsight(
                id: "health-stressed",
                icon: "exclamationmark.triangle.fill",
                title: l.tr(zh: "状态紧张，先排查问题", en: "Stressed, inspect first", de: "Gestresst, zuerst prüfen"),
                detail: l.tr(zh: "施肥会更保守，优先排查浇水、光照和虫害。", en: "Fertilizing becomes more conservative while water, light, and pests are checked first.", de: "Düngen wird vorsichtiger; Wasser, Licht und Schädlinge zuerst prüfen."),
                tint: Color.goRed
            )
        }
    }
    private var careActionItems: [PlantDetailActionItem] {
        var items: [PlantDetailActionItem] = []

        for task in careTasks.filter({ $0.daysUntilDue <= 0 }).prefix(2) {
            items.append(
                PlantDetailActionItem(
                    id: "due-\(task.careType.rawValue)",
                    icon: careSymbol(for: task.careType),
                    title: task.title,
                    detail: "\(dueText(for: task)) · \(task.subtitle)",
                    tint: careTint(for: task.careType),
                    primaryTitle: l.tr(zh: "完成", en: "Done", de: "Erledigt"),
                    careType: task.careType,
                    task: task,
                    opensEdit: false
                )
            )
        }

        if plant.healthStatus == .watching || plant.healthStatus == .stressed {
            items.append(
                PlantDetailActionItem(
                    id: "health-pest-check",
                    icon: "stethoscope",
                    title: plant.healthStatus == .stressed
                        ? l.tr(zh: "先做一次病虫害复查", en: "Run a pest recheck first", de: "Zuerst Schädlingscheck machen")
                        : l.tr(zh: "观察叶片和土壤", en: "Check leaves and soil", de: "Blätter und Erde prüfen"),
                    detail: healthSummaryText,
                    tint: plant.healthStatus == .stressed ? Color.goRed : Color.goYellow,
                    primaryTitle: PlantCareType.pestCheck.displayName,
                    careType: .pestCheck,
                    task: nil,
                    opensEdit: false
                )
            )
        }

        if activeSafetyWarningCount > 0 {
            items.append(
                PlantDetailActionItem(
                    id: "safety-placement",
                    icon: "exclamationmark.triangle.fill",
                    title: l.tr(zh: "复核安全摆放", en: "Review safe placement", de: "Sicheren Standort prüfen"),
                    detail: l.tr(
                        zh: "\(activeSafetyWarningCount) 个安全提示需要确认，尤其是宠物/儿童够不到的位置。",
                        en: "\(activeSafetyWarningCount) safety notes need review, especially reach from pets or children.",
                        de: "\(activeSafetyWarningCount) Sicherheitshinweise prüfen, besonders Reichweite von Tieren oder Kindern."
                    ),
                    tint: Color.goYellow,
                    primaryTitle: l.tr(zh: "编辑位置", en: "Edit placement", de: "Standort bearbeiten"),
                    careType: nil,
                    task: nil,
                    opensEdit: true
                )
            )
        }

        if !profileMissingItems.isEmpty {
            items.append(
                PlantDetailActionItem(
                    id: "profile-completion",
                    icon: "list.clipboard.fill",
                    title: l.tr(zh: "补齐植物档案", en: "Complete plant profile", de: "Pflanzenprofil vervollständigen"),
                    detail: l.tr(
                        zh: "还缺：\(profileMissingItems.prefix(3).joined(separator: "、"))",
                        en: "Missing: \(profileMissingItems.prefix(3).joined(separator: ", "))",
                        de: "Fehlt: \(profileMissingItems.prefix(3).joined(separator: ", "))"
                    ),
                    tint: Color.goTeal,
                    primaryTitle: l.tr(zh: "去完善", en: "Complete", de: "Ergänzen"),
                    careType: nil,
                    task: nil,
                    opensEdit: true
                )
            )
        }

        if items.isEmpty, let task = nextTask {
            items.append(
                PlantDetailActionItem(
                    id: "next-\(task.careType.rawValue)",
                    icon: careSymbol(for: task.careType),
                    title: l.tr(zh: "下一项可以提前处理", en: "Next care can be handled early", de: "Nächste Pflege kann vorgezogen werden"),
                    detail: "\(dueText(for: task)) · \(task.subtitle)",
                    tint: careTint(for: task.careType),
                    primaryTitle: l.tr(zh: "现在完成", en: "Do now", de: "Jetzt erledigen"),
                    careType: task.careType,
                    task: task,
                    opensEdit: false
                )
            )
        }

        if items.isEmpty {
            items.append(
                PlantDetailActionItem(
                    id: "growth-check",
                    icon: "leaf.circle.fill",
                    title: l.tr(zh: "记录一次成长观察", en: "Log a growth check", de: "Wachstumscheck protokollieren"),
                    detail: l.tr(
                        zh: "状态稳定时，可以记录新叶、清洁叶片或补照片。",
                        en: "When things are calm, log new leaves, clean leaves, or add a photo note.",
                        de: "Wenn alles ruhig ist, neue Blätter, Blattpflege oder Foto-Notiz erfassen."
                    ),
                    tint: Color.goLime,
                    primaryTitle: PlantCareType.newLeaf.displayName,
                    careType: .newLeaf,
                    task: nil,
                    opensEdit: false
                )
            )
        }

        return Array(items.prefix(4))
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroCard
                        careOverviewCard
                            .id(PlantDetailFeatureAnchor.overview)
                        actionQueueCard
                        plantSectionHeader(
                            l.tr(zh: "今日护理", en: "Today care", de: "Pflege heute"),
                            subtitle: l.tr(zh: "先处理最重要的动作，再记录日常护理。", en: "Handle the most important task first, then log routine care.", de: "Zuerst die wichtigste Aufgabe erledigen, dann Routinepflege protokollieren.")
                        )
                        .id(PlantDetailFeatureAnchor.todayCare)
                        nextTaskCard
                        quickActions
                        plantSectionHeader(
                            l.tr(zh: "护理节奏", en: "Care rhythm", de: "Pflegerhythmus"),
                            subtitle: l.tr(zh: "Ohana 会结合环境、品种和历史记录调整节奏。", en: "Ohana adjusts the rhythm with environment, species, and care history.", de: "Ohana passt den Rhythmus mit Umgebung, Art und Pflegeverlauf an.")
                        )
                        .id(PlantDetailFeatureAnchor.carePlan)
                        careRhythmCard
                        carePlanInsightCard
                        plantSectionHeader(
                            l.tr(zh: "档案", en: "Profile", de: "Profil"),
                            subtitle: l.tr(zh: "像宠物/人类档案一样记录摆放、盆土和成长线索。", en: "Track placement, potting, and growth like other household profiles.", de: "Standort, Topf und Wachstum wie bei anderen Haushaltsprofilen festhalten.")
                        )
                        .id(PlantDetailFeatureAnchor.profile)
                        environmentCard
                        growthProfileCard
                        safetyCard
                            .id(PlantDetailFeatureAnchor.safety)
                        plantSectionHeader(
                            l.tr(zh: "资料与诊断", en: "Knowledge and checks", de: "Wissen und Checks"),
                            subtitle: l.tr(zh: "本地资料库和谨慎诊断一起给出可执行建议。", en: "Local catalog notes and cautious checks provide actionable guidance.", de: "Lokale Katalogdaten und vorsichtige Checks geben umsetzbare Hinweise.")
                        )
                        .id(PlantDetailFeatureAnchor.knowledge)
                        catalogCard
                        diagnosisCard
                        healthReviewCard
                            .id(PlantDetailFeatureAnchor.healthReview)
                        growthDiaryCard
                            .id(PlantDetailFeatureAnchor.growthDiary)
                        plantSectionHeader(
                            l.tr(zh: "时间线", en: "Timeline", de: "Zeitachse"),
                            subtitle: l.tr(zh: "护理、观察和备注都沉淀到这里。", en: "Care, observations, and notes settle here.", de: "Pflege, Beobachtungen und Notizen sammeln sich hier.")
                        )
                        .id(PlantDetailFeatureAnchor.timeline)
                        historyCard
                        notesCard
                        deleteSection
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .onChange(of: pendingFeatureScrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(GoMotion.page) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    Task { @MainActor in
                        await OhanaFrameScheduler.waitAfterNextFrame()
                        if pendingFeatureScrollTarget == target {
                            pendingFeatureScrollTarget = nil
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button { showingAllFeaturesHub = true } label: {
                        Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative all-features glyph; button label names the action.
                            .accessibilityHidden(true)
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .accessibilityLabel(l.tr(zh: "植物全部功能", en: "All plant features", de: "Alle Pflanzenfunktionen"))
                    .accessibilityIdentifier("plant-detail-all-features-action")

                    Button { showingEditSheet = true } label: {
                        Image(systemName: "pencil.circle").accessibilityHidden(true)
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .accessibilityIdentifier("plant-detail-edit-action")
                }
            }
        }
        .accessibilityIdentifier("plant-detail-screen")
        .sheet(isPresented: $showingAllFeaturesHub) {
            PlantAllFeaturesSheet(
                plant: plant,
                careTasks: careTasks,
                logCount: recentLogs.count,
                photoCount: galleryPhotoItems.count,
                profileCompletionPercent: profileCompletionPercent,
                safetyWarningCount: activeSafetyWarningCount,
                onOpenDestination: openPlantFeatureDestination
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlantSheet(plant: plant)
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PlantPhotoGallerySheet(
                plantName: plant.name,
                photos: galleryPhotoItems
            )
        }
        .sheet(item: $careLogDraftType) { type in
            PlantCareLogSheet(
                plant: plant,
                initialCareType: type,
                currentHealthStatus: plant.healthStatus,
                onSave: savePlantCareLog
            )
        }
        .safeAreaInset(edge: .bottom) {
            pendingDeleteBanner
        }
        .alert(l.tr(zh: "确认删除", en: "Confirm deletion", de: "Löschen bestätigen"), isPresented: $showingDeleteConfirm) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                stagePlantDelete()
            }
        } message: {
            Text(l.tr(
                zh: "确定要删除 \(plant.name) 吗？确认后会先保留 6 秒，可在本页撤销。",
                en: "Delete \(plant.name)? After confirming, Ohana keeps it for 6 seconds so you can undo here.",
                de: "\(plant.name) löschen? Nach der Bestätigung bleibt es 6 Sekunden lang hier widerrufbar."
            ))
        }
        .onDisappear {
            deleteUndoTask?.cancel()
            commandQueue.cancelAll()
        }
        .task(id: plant.healthStatusRaw) {
            diagnosisResult = await appServices.plantIntelligence.diagnosePlant(
                imageData: nil,
                symptoms: diagnosisSymptoms
            )
        }
    }

    private var careOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "植物状态", en: "Plant status", de: "Pflanzenstatus"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(healthSummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 12)
                statusPill(
                    icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "leaf.fill",
                    title: plant.healthStatus.displayName,
                    tint: healthTone
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                overviewMetric(
                    icon: "calendar.badge.clock",
                    title: l.tr(zh: "待办", en: "Due", de: "Fällig"),
                    value: dueTaskCount == 0
                        ? l.tr(zh: "无到期", en: "None due", de: "Nichts fällig")
                        : l.tr(zh: "\(dueTaskCount) 项到期", en: "\(dueTaskCount) due", de: "\(dueTaskCount) fällig"),
                    tint: dueTaskCount == 0 ? Color.goTeal : Color.goYellow
                )
                overviewMetric(
                    icon: "arrow.forward.circle.fill",
                    title: l.tr(zh: "下一步", en: "Next", de: "Nächstes"),
                    value: nextTask.map { dueText(for: $0) } ?? l.tr(zh: "无计划", en: "No plan", de: "Kein Plan"),
                    tint: nextTask?.isOverdue == true ? Color.goRed : Color.goLime
                )
                overviewMetric(
                    icon: "drop.fill",
                    title: l.tr(zh: "浇水", en: "Water", de: "Gießen"),
                    value: wateringStatusText,
                    tint: isWateringDue ? Color.goYellow : Color.goTeal
                )
                overviewMetric(
                    icon: "mappin.and.ellipse",
                    title: l.tr(zh: "位置", en: "Place", de: "Ort"),
                    value: placementSummary,
                    tint: Color.goLime
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-detail-health-summary")
        .padding(.horizontal, 16)
    }

    private var actionQueueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist.checked") // a11y: allow decorative queue glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive queue glyph; text carries the accessible content.
                    .background(Color.goLime.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "今日行动队列", en: "Today's action queue", de: "Aktionsliste heute"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(actionQueueSummary)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("\(profileCompletionPercent)%")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.goLime, in: Capsule())
                    .accessibilityLabel(l.tr(zh: "档案完成度 \(profileCompletionPercent)%", en: "Profile \(profileCompletionPercent)% complete", de: "Profil zu \(profileCompletionPercent)% vollständig"))
            }

            VStack(spacing: 10) {
                ForEach(careActionItems) { item in
                    actionQueueRow(item)
                }
            }

            actionQueueToolRail
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-queue")
        .padding(.horizontal, 16)
    }

    private var actionQueueSummary: String {
        if dueTaskCount > 0 {
            return l.tr(
                zh: "\(dueTaskCount) 项照护到期，先完成高优先级动作。",
                en: "\(dueTaskCount) care tasks are due; start with the highest priority actions.",
                de: "\(dueTaskCount) Pflegeaufgaben sind fällig; mit hoher Priorität beginnen."
            )
        }
        if plant.healthStatus == .watching || plant.healthStatus == .stressed {
            return l.tr(
                zh: "当前重点是观察和复查，避免问题拖到下一次提醒。",
                en: "Focus on observation and checks before the next reminder.",
                de: "Beobachtung und Checks vor der nächsten Erinnerung priorisieren."
            )
        }
        if !profileMissingItems.isEmpty {
            return l.tr(
                zh: "没有紧急照护，适合补齐档案让计划更准确。",
                en: "No urgent care; complete the profile so the plan gets smarter.",
                de: "Keine dringende Pflege; Profil ergänzen, damit der Plan genauer wird."
            )
        }
        return l.tr(
            zh: "节奏稳定，可以做一次轻量观察或提前处理下一项。",
            en: "The rhythm is stable; log a small observation or handle the next item early.",
            de: "Der Rhythmus ist stabil; kleine Beobachtung oder nächste Aufgabe vorziehen."
        )
    }

    private func actionQueueRow(_ item: PlantDetailActionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.icon) // a11y: allow decorative row glyph; row text and buttons carry context.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive action glyph; row label carries content.
                    .background(item.tint, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.detail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    performActionQueueItem(item)
                } label: {
                    Text(item.primaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minWidth: 92, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(item.tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(actionQueuePrimaryAccessibilityLabel(item))
                .accessibilityIdentifier("plant-detail-action-primary-\(item.id)")

                if let task = item.task, task.daysUntilDue <= 0 {
                    Button {
                        deferTaskOneDay(task)
                    } label: {
                        Text(l.tr(zh: "延后一天", en: "Defer 1 day", de: "1 Tag später"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(minWidth: 92, minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "延后\(task.title)一天", en: "Defer \(task.title) by one day", de: "\(task.title) um einen Tag verschieben"))
                    .accessibilityIdentifier("plant-detail-action-defer-\(item.id)")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-item-\(item.id)")
    }

    private var actionQueueToolRail: some View {
        HStack(spacing: 8) {
            actionQueueToolButton(
                id: "calendar",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "日历", en: "Calendar", de: "Kalender"),
                subtitle: nextTask.map { dueText(for: $0) } ?? l.tr(zh: "计划", en: "Plan", de: "Plan"),
                tint: nextTask?.isOverdue == true ? Color.goRed : Color.goTeal,
                action: openCareCalendar
            )

            actionQueueToolButton(
                id: "reminders",
                icon: plant.remindersEnabled ? "bell.badge.fill" : "bell.slash.fill",
                title: l.tr(zh: "提醒", en: "Reminders", de: "Hinweise"),
                subtitle: plant.remindersEnabled
                    ? l.tr(zh: "开启", en: "On", de: "An")
                    : l.tr(zh: "关闭", en: "Off", de: "Aus"),
                tint: plant.remindersEnabled ? Color.goLime : Color.goYellow,
                action: openReminderSettings
            )

            actionQueueToolButton(
                id: "photos",
                icon: "photo.on.rectangle.angled",
                title: l.tr(zh: "照片", en: "Photos", de: "Fotos"),
                subtitle: galleryPhotoItems.isEmpty
                    ? l.tr(zh: "补照片", en: "Add", de: "Ergänzen")
                    : l.tr(zh: "\(galleryPhotoItems.count) 张", en: "\(galleryPhotoItems.count)", de: "\(galleryPhotoItems.count)"),
                tint: galleryPhotoItems.isEmpty ? Color.goYellow : Color.goTeal,
                action: openPlantPhotos
            )
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-action-tools")
    }

    private func actionQueueToolButton(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon) // a11y: allow decorative tool glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72, alignment: .center)
            .padding(.horizontal, 10)
            .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier("plant-detail-action-tool-\(id)")
    }

    private func actionQueuePrimaryAccessibilityLabel(_ item: PlantDetailActionItem) -> String {
        "\(item.primaryTitle), \(item.title)"
    }

    private var nextTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles") // a11y: allow decorative section glyph; heading names the next task.
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "下一步", en: "Next step", de: "Nächster Schritt"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            if let task = careTasks.first {
                Text(task.title)
                    .font(OhanaFont.adaptive(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(task.explanation)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Erledigt")) {
                        openCareLogSheet(task.careType)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.goLime, in: Capsule())
                    .accessibilityIdentifier("plant-detail-next-task-complete")

                    Button(l.tr(zh: "延后一天", en: "Defer one day", de: "Um einen Tag verschieben")) {
                        deferTaskOneDay(task)
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    .accessibilityIdentifier("plant-detail-next-task-defer")
                }
                if task.careType == .watering {
                    Button(l.tr(zh: "土还湿，延后", en: "Soil still wet, defer", de: "Erde noch feucht, verschieben")) {
                        deferTaskOneDay(task, reason: "soilWet")
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    .accessibilityIdentifier("plant-detail-next-task-soil-wet-defer")
                }
            } else {
                Text(l.tr(zh: "暂无任务", en: "No tasks yet", de: "Noch keine Aufgaben"))
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    private var careRhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "metronome.fill", title: l.tr(zh: "护理节奏", en: "Care rhythm", de: "Pflegerhythmus"))
            rhythmRow(
                icon: "drop.fill",
                title: l.tr(zh: "浇水", en: "Watering", de: "Gießen"),
                status: wateringStatusText,
                detail: wateringIntervalText,
                tint: isWateringDue ? Color.goYellow : Color.goTeal,
                progress: plant.daysSinceWatered.map { min(1, Double($0) / Double(max(wateringIntervalDays, 1))) }
            )
            rhythmRow(
                icon: "leaf.fill",
                title: l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen"),
                status: fertilizingStatusText,
                detail: fertilizingIntervalText,
                tint: isFertilizingDue ? Color.goYellow : Color.goLime,
                progress: plant.daysSinceFertilized.map { min(1, Double($0) / Double(max(fertilizingIntervalDays, 1))) }
            )
            if let pestTask = careTasks.first(where: { $0.careType == .pestCheck }) {
                rhythmRow(
                    icon: "ladybug.fill",
                    title: PlantCareType.pestCheck.displayName,
                    status: dueText(for: pestTask),
                    detail: pestTask.subtitle,
                    tint: pestTask.isOverdue ? Color.goRed : Color.goYellow,
                    progress: nil
                )
            }
            if let cleaningTask = careTasks.first(where: { $0.careType == .leafCleaning }) {
                rhythmRow(
                    icon: "sparkles",
                    title: PlantCareType.leafCleaning.displayName,
                    status: dueText(for: cleaningTask),
                    detail: cleaningTask.subtitle,
                    tint: cleaningTask.isOverdue ? Color.goRed : Color.goTeal,
                    progress: nil
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-detail-care-rhythm")
        .padding(.horizontal, 16)
    }

    private var carePlanInsightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(icon: "slider.horizontal.3", title: l.tr(zh: "计划依据", en: "Plan reasoning", de: "Planlogik"))
            Text(l.tr(
                zh: "Ohana 会把资料库、环境、历史记录和健康状态合并成当前护理节奏。",
                en: "Ohana combines catalog, environment, history, and health to shape the current cadence.",
                de: "Ohana kombiniert Katalog, Umgebung, Verlauf und Zustand zum aktuellen Rhythmus."
            ))
            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(carePlanInsights.prefix(4)) { insight in
                    carePlanInsightRow(insight)
                }
            }

            Button {
                showingEditSheet = true
            } label: {
                Text(l.tr(zh: "调整植物档案", en: "Adjust plant profile", de: "Pflanzenprofil anpassen"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color.goLime, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-detail-care-plan-edit-profile")
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-care-plan-insights")
        .padding(.horizontal, 16)
    }

    private func carePlanInsightRow(_ insight: PlantCarePlanInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon) // a11y: allow decorative plan-reason glyph; row text carries the insight.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 44, height: 44)
                .background(insight.tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "sun.max.fill", title: l.tr(zh: "环境", en: "Environment", de: "Umgebung"))
            detailRow(l.tr(zh: "房间", en: "Room", de: "Raum"), value: plant.roomName.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.roomName)
            detailRow(l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"), value: plant.location.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") : plant.location)
            detailRow(l.tr(zh: "场景", en: "Scene", de: "Standortart"), value: plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "阳台/花园", en: "Balcony/garden", de: "Balkon/Garten"))
            detailRow(l.tr(zh: "窗向", en: "Window", de: "Fenster"), value: plant.windowDirection.displayName)
            detailRow(l.tr(zh: "光照", en: "Light", de: "Licht"), value: plant.lightLevel.displayName)
            if plant.lastLightMeasurementLux > 0 {
                detailRow(l.tr(zh: "光照实测", en: "Light reading", de: "Lichtmessung"), value: "\(plant.lastLightMeasurementLux) lux\(plant.lastLightMeasurementDate.map { " · \(shortDate($0))" } ?? "")")
            }
            detailRow(l.tr(zh: "湿度偏好", en: "Humidity preference", de: "Luftfeuchte"), value: plant.humidityPreference.displayName)
            detailRow(l.tr(zh: "温度偏好", en: "Temperature preference", de: "Temperatur"), value: plant.temperaturePreference.displayName)
            if plant.isNearClimateSource {
                detailRow(l.tr(zh: "环境风险", en: "Environment risk", de: "Umgebungsrisiko"), value: l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"))
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    private var growthProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "ruler.fill", title: l.tr(zh: "盆土与成长", en: "Potting and growth", de: "Topf und Wachstum"))
            if plant.potDiameterCm > 0 {
                detailRow(l.tr(zh: "盆径", en: "Pot diameter", de: "Topfdurchmesser"), value: "\(Int(plant.potDiameterCm)) cm")
            }
            detailRow(l.tr(zh: "排水孔", en: "Drainage hole", de: "Abzugsloch"), value: plant.potHasDrainage ? l.tr(zh: "有", en: "Yes", de: "Ja") : l.tr(zh: "无", en: "No", de: "Nein"))
            if !plant.potMaterial.isEmpty {
                detailRow(l.tr(zh: "盆材质", en: "Pot material", de: "Topfmaterial"), value: plant.potMaterial)
            }
            if !plant.soilType.isEmpty {
                detailRow(l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: plant.soilType)
            }
            if plant.currentHeightCm > 0 || plant.currentSpreadCm > 0 {
                detailRow(
                    l.tr(zh: "当前尺寸", en: "Current size", de: "Aktuelle Größe"),
                    value: l.tr(
                        zh: "\(Int(plant.currentHeightCm)) cm 高 · \(Int(plant.currentSpreadCm)) cm 冠幅",
                        en: "\(Int(plant.currentHeightCm)) cm tall · \(Int(plant.currentSpreadCm)) cm spread",
                        de: "\(Int(plant.currentHeightCm)) cm hoch · \(Int(plant.currentSpreadCm)) cm breit"
                    )
                )
            }
            if let acquiredDate = plant.acquiredDate {
                detailRow(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), value: shortDate(acquiredDate))
            }
            if !plant.acquisitionSource.isEmpty {
                detailRow(l.tr(zh: "来源", en: "Source", de: "Quelle"), value: plant.acquisitionSource)
            }
            let typeSummary = [
                plant.isHydroponic ? l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur") : nil,
                plant.isSucculent ? l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus") : nil
            ].compactMap(\.self).joined(separator: " · ")
            if !typeSummary.isEmpty {
                detailRow(l.tr(zh: "类型", en: "Type", de: "Typ"), value: typeSummary)
            }
            if plant.potDiameterCm == 0,
               plant.potMaterial.isEmpty,
               plant.soilType.isEmpty,
               plant.currentHeightCm == 0,
               plant.currentSpreadCm == 0,
               plant.acquiredDate == nil,
               plant.acquisitionSource.isEmpty,
               typeSummary.isEmpty {
                Text(l.tr(
                    zh: "还没有补充盆土、尺寸和来源信息。完善后，护理计划会更像一份真正的植物档案。",
                    en: "Potting, size, and source details are still empty. Completing them makes this feel like a real plant profile.",
                    de: "Topf-, Größen- und Herkunftsdetails fehlen noch. Mit ihnen wirkt das Profil wie eine echte Pflanzenakte."
                ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityIdentifier("plant-detail-growth-profile")
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var safetyCard: some View {
        if plant.isToxicToCats || plant.isToxicToDogs || plant.isToxicToChildren || !plant.isIndoorSuitable {
            VStack(alignment: .leading, spacing: 10) {
                detailHeader(icon: "exclamationmark.triangle.fill", title: l.tr(zh: "安全提示", en: "Safety note", de: "Sicherheitshinweis"))
                if onboardingHasPets, plant.isToxicToCats || plant.isToxicToDogs {
                    Text(l.tr(
                        zh: "对猫/狗有误食风险，请放在宠物够不到的位置。",
                        en: "May be risky if cats or dogs chew it. Keep it out of pets' reach.",
                        de: "Kann bei Katzen oder Hunden beim Anknabbern riskant sein. Außer Reichweite von Haustieren stellen."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if onboardingHasChildren, plant.isToxicToChildren {
                    Text(l.tr(
                        zh: "对儿童有误食刺激风险，提醒文案会优先提示安全摆放。",
                        en: "May irritate children if eaten. Reminders will prioritize safe placement.",
                        de: "Kann Kinder beim Verschlucken reizen. Erinnerungen betonen eine sichere Platzierung."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if (!onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
                    (!onboardingHasChildren && plant.isToxicToChildren) {
                    Text(l.tr(
                        zh: "资料库标记存在误食风险；若家里之后有宠物或儿童，可以在设置/详情中优先关注摆放安全。",
                        en: "The catalog marks an ingestion risk. If pets or children join later, prioritize safe placement in Settings or details.",
                        de: "Der Katalog markiert ein Verschluckrisiko. Wenn später Haustiere oder Kinder dazukommen, sichere Platzierung in Einstellungen oder Details priorisieren."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                if !plant.isIndoorSuitable {
                    Text(l.tr(
                        zh: "资料库标记为不太适合室内长期养护。",
                        en: "The catalog marks this as less suitable for long-term indoor care.",
                        de: "Der Katalog markiert sie als weniger geeignet für langfristige Innenpflege."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var catalogCard: some View {
        if let catalogEntry {
            VStack(alignment: .leading, spacing: 12) {
                detailHeader(icon: "books.vertical.fill", title: l.tr(zh: "资料库", en: "Catalog", de: "Katalog"))
                detailRow(l.tr(zh: "拉丁名", en: "Latin name", de: "Lateinischer Name"), value: catalogEntry.latinName)
                detailRow(l.tr(zh: "浇水", en: "Watering", de: "Gießen"), value: catalogEntry.localizedWateringPreference)
                detailRow(l.tr(zh: "湿度", en: "Humidity", de: "Luftfeuchte"), value: catalogEntry.localizedHumidity)
                detailRow(l.tr(zh: "温度", en: "Temperature", de: "Temperatur"), value: catalogEntry.localizedTemperature)
                detailRow(l.tr(zh: "土壤", en: "Soil", de: "Erde"), value: catalogEntry.localizedSoil)
                detailRow(l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen"), value: catalogEntry.localizedFertilizing)
                detailRow(l.tr(zh: "繁殖", en: "Propagation", de: "Vermehrung"), value: catalogEntry.localizedPropagation)
                detailRow(l.tr(zh: "修剪", en: "Pruning", de: "Schnitt"), value: catalogEntry.localizedPruning)
                detailRow(l.tr(zh: "常见问题", en: "Common issues", de: "Häufige Probleme"), value: catalogEntry.localizedCommonIssues)
                detailRow(l.tr(zh: "毒性", en: "Toxicity", de: "Toxizität"), value: catalogEntry.localizedToxicity)
                detailRow(l.tr(zh: "难度", en: "Difficulty", de: "Schwierigkeit"), value: catalogEntry.localizedCareDifficulty)
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
            .accessibilityIdentifier("plant-detail-catalog-profile")
            .padding(.horizontal, 16)
        }
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "stethoscope", title: l.tr(zh: "病虫害诊断", en: "Pest and disease check", de: "Schädlings- und Krankheitscheck"))
            Text(diagnosisResult?.uncertaintyMessage ?? l.tr(
                zh: "当前未连接智能诊断服务，Ohana 会展示不确定性和可执行复查步骤。",
                en: "Smart diagnosis is not connected yet. Ohana shows uncertainty and actionable recheck steps.",
                de: "Die intelligente Diagnose ist noch nicht verbunden. Ohana zeigt Unsicherheit und konkrete Schritte zur Kontrolle."
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach((diagnosisResult?.causes ?? []).prefix(3)) { cause in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cause.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(cause.severity)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.goYellow, in: Capsule())
                    }
                    Text(cause.steps.prefix(2).joined(separator: " · "))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(3)
                    Text(cause.shouldIsolate
                        ? l.tr(zh: "建议先隔离，\(cause.recheckAfterDays) 天后复查", en: "Isolate first; recheck in \(cause.recheckAfterDays) days", de: "Zuerst isolieren; in \(cause.recheckAfterDays) Tagen prüfen")
                        : l.tr(zh: "\(cause.recheckAfterDays) 天后复查", en: "Recheck in \(cause.recheckAfterDays) days", de: "In \(cause.recheckAfterDays) Tagen prüfen"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(cause.shouldIsolate ? Color.goRed : Color.ohanaSecondaryText)
                }
                .padding(10)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
            diagnosisQuickActions
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-diagnosis-card")
        .padding(.horizontal, 16)
    }

    private var diagnosisQuickActions: some View {
        HStack(spacing: 8) {
            diagnosisActionButton(
                type: .pestCheck,
                icon: "ladybug.fill",
                tint: Color.goLime,
                isSubtle: false,
                identifier: "plant-detail-diagnosis-pest-check",
                accessibilityText: l.tr(zh: "记录\(plant.name)的病虫害复查", en: "Log a pest check for \(plant.name)", de: "Schädlingscheck für \(plant.name) erfassen")
            )
            diagnosisActionButton(
                type: .photo,
                icon: "camera.fill",
                tint: Color.goTeal,
                isSubtle: false,
                identifier: "plant-detail-diagnosis-photo",
                accessibilityText: l.tr(zh: "为\(plant.name)添加诊断照片", en: "Add a diagnosis photo for \(plant.name)", de: "Diagnosefoto für \(plant.name) hinzufügen")
            )
            diagnosisActionButton(
                type: .pestFound,
                icon: "exclamationmark.triangle.fill",
                tint: Color.goYellow,
                isSubtle: true,
                identifier: "plant-detail-diagnosis-pest-found",
                accessibilityText: l.tr(zh: "记录\(plant.name)发现虫害", en: "Log pest found for \(plant.name)", de: "Schädlingsfund für \(plant.name) erfassen")
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-diagnosis-actions")
    }

    private func diagnosisActionButton(
        type: PlantCareType,
        icon: String,
        tint: Color,
        isSubtle: Bool,
        identifier: String,
        accessibilityText: String
    ) -> some View {
        Button {
            openCareLogSheet(type)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon) // a11y: allow decorative diagnosis-action glyph; text names the action.
                    .font(OhanaFont.adaptive(size: 10, weight: .black))
                    .accessibilityHidden(true)
                Text(type.displayName)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSubtle ? Color.ohanaPrimaryText : Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(tint.opacity(isSubtle ? 0.22 : 1), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(identifier)
    }

    private var healthReviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.path.ecg") // a11y: allow decorative health-review glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive health-review glyph; text carries the content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "健康观察", en: "Health review", de: "Gesundheitscheck"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(healthReviewSummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                healthReviewMetric(
                    icon: "waveform.path.ecg.rectangle.fill",
                    title: l.tr(zh: "状态", en: "Status", de: "Status"),
                    value: plant.healthStatus.displayName,
                    tint: healthTone
                )
                healthReviewMetric(
                    icon: "tray.full.fill",
                    title: l.tr(zh: "30天观察", en: "30d notes", de: "30T Notizen"),
                    value: "\(recentObservationLogCount)",
                    tint: recentStressSignalLogs.isEmpty ? Color.goTeal : Color.goYellow
                )
                healthReviewMetric(
                    icon: "clock.badge.checkmark.fill",
                    title: l.tr(zh: "最近复查", en: "Latest", de: "Zuletzt"),
                    value: latestHealthReviewText,
                    tint: latestHealthReviewLog == nil ? Color.goYellow : Color.goLime
                )
            }

            VStack(spacing: 8) {
                ForEach(healthReviewSignals.prefix(4)) { signal in
                    healthReviewSignalRow(signal)
                }
            }

            HStack(spacing: 10) {
                    Button {
                        openCareLogSheet(.pestCheck)
                } label: {
                    Text(PlantCareType.pestCheck.displayName)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录一次病虫害复查", en: "Log a pest check for \(plant.name)", de: "Schädlingscheck für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-health-review-pest-check")

                Button {
                    openCareLogSheet(.yellowLeaf)
                } label: {
                    Text(PlantCareType.yellowLeaf.displayName)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录黄叶观察", en: "Log a yellow-leaf note for \(plant.name)", de: "Gelbblattnotiz für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-health-review-yellow-leaf")

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-health-review")
        .padding(.horizontal, 16)
    }

    private func healthReviewMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative health metric glyph; metric text carries value.
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func healthReviewSignalRow(_ signal: PlantHealthReviewSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: signal.icon) // a11y: allow decorative health signal glyph; row text carries signal details.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(signal.tint)
                .frame(width: 34, height: 34) // a11y: allow non-interactive signal glyph; row label carries the content.
                .background(signal.tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(signal.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signal.detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-health-review-signal-\(signal.id)")
    }

    private var growthDiaryCard: some View {
        let photos = galleryPhotoItems

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass") // a11y: allow decorative diary glyph; heading names the card.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive diary glyph; text carries the content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "成长档案", en: "Growth diary", de: "Wachstumstagebuch"))
                        .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(growthDiarySummaryText)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                diaryStatPill(
                    icon: "tray.full.fill",
                    title: l.tr(zh: "记录", en: "Logs", de: "Protokolle"),
                    value: "\(recentLogs.count)",
                    tint: Color.goLime
                )
                diaryStatPill(
                    icon: "photo.on.rectangle.angled",
                    title: l.tr(zh: "照片", en: "Photos", de: "Fotos"),
                    value: "\(growthDiaryPhotoCount)",
                    tint: Color.goTeal
                )
                diaryStatPill(
                    icon: "calendar",
                    title: l.tr(zh: "跨度", en: "Range", de: "Zeitraum"),
                    value: growthDiaryDateRangeText,
                    tint: Color.goYellow
                )
            }

            if photos.isEmpty {
                emptyPhotoGalleryHint
            } else {
                photoGalleryPreviewStrip(photos)
            }

            HStack(spacing: 10) {
                ShareLink(item: growthDiaryMarkdown) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up") // a11y: allow decorative share glyph; button label names export action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "导出 Markdown", en: "Export Markdown", de: "Markdown exportieren"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color.goLime, in: Capsule())
                }
                .accessibilityLabel(l.tr(zh: "导出\(plant.name)成长档案", en: "Export \(plant.name)'s growth diary", de: "Wachstumstagebuch von \(plant.name) exportieren"))
                .accessibilityIdentifier("plant-detail-growth-diary-export")

                if !photos.isEmpty {
                    Button {
                        showingPhotoGallery = true
                    } label: {
                        Text(l.tr(zh: "查看照片", en: "View photos", de: "Fotos ansehen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "查看\(plant.name)的植物照片", en: "View \(plant.name)'s plant photos", de: "Pflanzenfotos von \(plant.name) ansehen"))
                    .accessibilityIdentifier("plant-detail-photo-gallery-open")
                }

                Button {
                    openCareLogSheet(.newLeaf)
                } label: {
                    Text(l.tr(zh: "记录观察", en: "Log observation", de: "Beobachtung erfassen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)记录一次成长观察", en: "Log a growth observation for \(plant.name)", de: "Wachstumsbeobachtung für \(plant.name) erfassen"))
                .accessibilityIdentifier("plant-detail-growth-diary-log-observation")

                Button {
                    openCareLogSheet(.photo)
                } label: {
                    Text(l.tr(zh: "添加照片", en: "Add photo", de: "Foto hinzufügen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "为\(plant.name)添加成长照片", en: "Add a growth photo for \(plant.name)", de: "Wachstumsfoto für \(plant.name) hinzufügen"))
                .accessibilityIdentifier("plant-detail-growth-diary-add-photo")

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-growth-diary")
        .padding(.horizontal, 16)
    }

    private var emptyPhotoGalleryHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled") // a11y: allow decorative photo hint glyph; text explains the empty gallery.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goTeal)
                .frame(width: 44, height: 44)
                .background(Color.goTeal.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "还没有照片线索", en: "No photo notes yet", de: "Noch keine Foto-Hinweise"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "带照片的档案图或护理记录会自动进入这里，方便回看叶片变化。",
                    en: "Profile photos and care logs with images appear here for leaf-change review.",
                    de: "Profilfotos und Pflegeprotokolle mit Bildern erscheinen hier zur Blattkontrolle."
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-detail-photo-gallery-empty")
    }

    private func photoGalleryPreviewStrip(_ photos: [PlantDetailPhotoItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos.prefix(5)) { photo in
                    Button {
                        showingPhotoGallery = true
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            PlantDetailDecodedImageTile(
                                imageData: photo.imageData,
                                tint: photo.tint,
                                fillsContainer: true
                            )
                            .frame(width: 118, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                            Text(photo.title)
                                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(photo.subtitle)
                                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 118, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("\(photo.title), \(photo.subtitle)")
                    .accessibilityIdentifier("plant-detail-photo-preview-\(photo.id)")
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-detail-photo-gallery-preview")
    }

    private func diaryStatPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative stat glyph; pill text carries value.
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var diagnosisSymptoms: [String] {
        switch plant.healthStatus {
        case .thriving, .stable:
            ["黄叶"]
        case .watching:
            ["黄叶", "停止生长"]
        case .stressed:
            ["黄叶", "叶片卷曲", "掉叶"]
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkMint.opacity(0.58), Color.goLime.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                Circle()
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.62), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Text(plant.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 48))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "植物档案", en: "Plant profile", de: "Pflanzenprofil"))
                    .font(OhanaFont.adaptive(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .textCase(.uppercase)

                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("plant-detail-name")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if !plant.species.isEmpty {
                            profileChip(icon: "leaf.fill", text: plant.species)
                        }
                        profileChip(icon: plant.isIndoor ? "house.fill" : "sun.max.fill", text: plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "户外", en: "Outdoor", de: "Draußen"))
                    }
                    profileChip(icon: "mappin.and.ellipse", text: placementSummary)
                    if activeSafetyWarningCount > 0 {
                        profileChip(
                            icon: "exclamationmark.triangle.fill",
                            text: l.tr(zh: "\(activeSafetyWarningCount) 个安全提示", en: "\(activeSafetyWarningCount) safety notes", de: "\(activeSafetyWarningCount) Sicherheitshinweise"),
                            tint: Color.goYellow
                        )
                    }
                }

                if let task = nextTask {
                    Text(l.tr(zh: "下一项：\(task.title) · \(dueText(for: task))", en: "Next: \(task.title) · \(dueText(for: task))", de: "Nächstes: \(task.title) · \(dueText(for: task))"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(task.isOverdue ? Color.goRed : Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func profileChip(icon: String, text: String, tint: Color = Color.goLime) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
    }

    private func statusPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .heavy))
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint, in: Capsule())
    }

    private func overviewMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24) // a11y: allow non-interactive metric glyph; row text carries the accessible content.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                Text(value)
                    .font(OhanaFont.adaptive(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 46, alignment: .top)
    }

    private func rhythmRow(
        icon: String,
        title: String,
        status: String,
        detail: String,
        tint: Color,
        progress: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26) // a11y: allow non-interactive rhythm glyph; row text carries the accessible content.
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(detail)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
                Text(status)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            if let progress {
                ProgressView(value: progress)
                    .tint(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }

    private func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            let days = abs(task.daysUntilDue)
            return l.tr(zh: "逾期 \(days) 天", en: "\(days)d overdue", de: "\(days) T. überfällig")
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        if task.daysUntilDue == 1 {
            return l.tr(zh: "明天", en: "Tomorrow", de: "Morgen")
        }
        return l.tr(zh: "\(task.daysUntilDue) 天后", en: "In \(task.daysUntilDue)d", de: "In \(task.daysUntilDue) T.")
    }

    // MARK: - Watering Card
    private var wateringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goTeal)
                Text(l.tr(zh: "浇水状态", en: "Watering status", de: "Gießstatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceWatered {
                let progress = min(1.0, Double(days) / Double(max(wateringIntervalDays, 1)))
                let color: Color = progress < 0.5 ? Color.goTeal : (progress < 0.8 ? Color.goYellow : Color.goRed)

                HStack {
                    Text(l.tr(zh: "距上次浇水 \(days) 天", en: "\(days) days since watering", de: "\(days) Tage seit dem Gießen"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(wateringIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isWateringDue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(Color.goYellow)
                            .font(OhanaFont.adaptive(size: 12))
                        Text(l.tr(zh: "该浇水了！", en: "Time to water!", de: "Zeit zum Gießen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有浇水记录", en: "No watering records yet", de: "Noch keine Gießprotokolle"))
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Fertilizing Card
    private var fertilizingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goLime)
                Text(l.tr(zh: "施肥状态", en: "Fertilizing status", de: "Düngestatus"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }

            if let days = plant.daysSinceFertilized {
                let progress = min(1.0, Double(days) / Double(max(fertilizingIntervalDays, 1)))
                let color: Color = progress < 0.5 ? Color.goLime : (progress < 0.8 ? Color.goYellow : Color.goRed)

                HStack {
                    Text(l.tr(zh: "距上次施肥 \(days) 天", en: "\(days) days since fertilizing", de: "\(days) Tage seit dem Düngen"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium))
                    Spacer()
                    Text(fertilizingIntervalText)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                ProgressView(value: progress)
                    .tint(color)

                if isFertilizingDue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .foregroundStyle(Color.goYellow)
                            .font(OhanaFont.adaptive(size: 12))
                        Text(l.tr(zh: "该施肥了！", en: "Time to fertilize!", de: "Zeit zum Düngen!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else {
                Text(l.tr(zh: "还没有施肥记录", en: "No fertilizing records yet", de: "Noch keine Düngeprotokolle"))
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .padding(.horizontal, 16)
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button {
                waterPlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill").accessibilityHidden(true)
                    Text(l.tr(zh: "浇水", en: "Water", de: "Gießen"))
                }
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goTeal.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
                }
            }
            .accessibilityIdentifier("plant-detail-water-action")

            Button {
                fertilizePlant()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill").accessibilityHidden(true)
                    Text(l.tr(zh: "施肥", en: "Fertilize", de: "Düngen"))
                }
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goLime.opacity(0.6), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
                }
            }
            .accessibilityIdentifier("plant-detail-fertilize-action")

            careActionButton(type: .pestCheck, icon: "ladybug.fill", color: Color.goYellow)
            careActionButton(type: .leafCleaning, icon: "sparkles", color: Color.goTeal)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        Group {
            if !plant.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text").accessibilityHidden(true)
                            .foregroundStyle(Color.goTeal)
                        Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Text(plant.notes)
                        .font(OhanaFont.adaptive(size: 14))
                }
                .padding(16)
                .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
                .padding(.horizontal, 16)
            }
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailHeader(icon: "clock.arrow.circlepath", title: l.tr(zh: "护理历史", en: "Care history", de: "Pflegeverlauf"))
            if recentLogs.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "leaf.arrow.circlepath") // a11y: allow decorative empty timeline glyph; adjacent text explains the state.
                        .accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 36, height: 36) // a11y: allow non-interactive timeline glyph; row text carries the content.
                        .background(Color.goTeal.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "还没有护理日志", en: "No care logs yet", de: "Noch keine Pflegeprotokolle"))
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "完成一次浇水、施肥或观察后，这里会生成植物的活动时间线。",
                            en: "Water, fertilize, or observe once to start this plant's activity timeline.",
                            de: "Gießen, düngen oder beobachten startet hier die Aktivitäts-Zeitachse."
                        ))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                timelineSummaryStrip

                VStack(spacing: 0) {
                    ForEach(Array(recentLogs.prefix(6).enumerated()), id: \.element.id) { index, log in
                        timelineLogRow(log, isLast: index == min(recentLogs.count, 6) - 1)
                    }
                }
            }
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: OhanaRadius.input)
        .accessibilityIdentifier("plant-detail-care-timeline")
        .padding(.horizontal, 16)
    }

    private var timelineSummaryStrip: some View {
        HStack(spacing: 8) {
            timelineSummaryPill(
                icon: "tray.full.fill",
                title: l.tr(zh: "记录", en: "Logs", de: "Protokolle"),
                value: "\(recentLogs.count)",
                tint: Color.goLime
            )
            if let latest = recentLogs.first {
                timelineSummaryPill(
                    icon: careSymbol(for: latest.careType),
                    title: l.tr(zh: "最近", en: "Latest", de: "Zuletzt"),
                    value: latest.careType.displayName,
                    tint: careTint(for: latest.careType)
                )
            }
        }
    }

    private func timelineSummaryPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: allow decorative summary glyph; pill text carries the value.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func timelineLogRow(_ log: PlantCareLog, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: careSymbol(for: log.careType)) // a11y: allow decorative timeline glyph; row text names the care action.
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive care log glyph; row text carries the content.
                    .background(careTint(for: log.careType), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.ohanaControlFill.opacity(0.85))
                        .frame(width: 2, height: 26) // a11y: allow non-interactive timeline connector; timeline row text carries the content.
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.careType.displayName)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(timelineDateText(for: log))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if let note = timelineNoteText(for: log) {
                    Text(note)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func timelineDateText(for log: PlantCareLog) -> String {
        log.date.formatted(date: .abbreviated, time: .shortened)
    }

    private func timelineNoteText(for log: PlantCareLog) -> String? {
        let note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty,
              !note.hasPrefix("defer:"),
              !note.hasPrefix("skip:") else { return nil }
        return note
    }

    private func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goLime
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

    // MARK: - Delete Section
    @ViewBuilder
    private var pendingDeleteBanner: some View {
        if isDeletePending {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill") // a11y: allow decorative pending-delete glyph; adjacent text describes the state.
                    .foregroundStyle(Color.goRed)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "即将删除 \(plant.name)", en: "Deleting \(plant.name) soon", de: "\(plant.name) wird gleich gelöscht"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "6 秒内可撤销；到时会清理相关日历和提醒。",
                        en: "Undo within 6 seconds; related calendar items and reminders will be cleaned up.",
                        de: "Innerhalb von 6 Sekunden widerrufbar; zugehörige Kalenderpunkte und Erinnerungen werden bereinigt."
                    ))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                Button(l.tr(zh: "撤销", en: "Undo", de: "Widerrufen")) {
                    cancelPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goLime)
                .accessibilityIdentifier("plant-detail-delete-undo")

                Button(l.tr(zh: "立即删除", en: "Delete now", de: "Jetzt löschen"), role: .destructive) {
                    commitPendingDelete()
                }
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .accessibilityIdentifier("plant-detail-delete-now")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash").accessibilityHidden(true)
                Text(l.tr(zh: "删除植物", en: "Delete plant", de: "Pflanze löschen"))
            }
            .font(OhanaFont.adaptive(size: 14, weight: .semibold))
            .foregroundStyle(Color.goRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.goRed.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.2), lineWidth: 1)
            }
        }
        .disabled(isDeletePending)
        .opacity(isDeletePending ? 0.55 : 1)
        .accessibilityIdentifier("plant-detail-delete-action")
        .padding(.horizontal, 16)
    }

    // MARK: - Actions
    private func waterPlant() {
        openCareLogSheet(.watering)
    }

    private func fertilizePlant() {
        openCareLogSheet(.fertilizing)
    }

    private func performActionQueueItem(_ item: PlantDetailActionItem) {
        if item.opensEdit {
            showingEditSheet = true
            return
        }
        if let task = item.task {
            openCareLogSheet(task.careType)
            return
        }
        if let careType = item.careType {
            openCareLogSheet(careType)
        }
    }

    private func careActionButton(type: PlantCareType, icon: String, color: Color) -> some View {
        Button {
            openCareLogSheet(type)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).accessibilityHidden(true)
                Text(type.displayName)
            }
            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.45), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("plant-detail-care-action-\(type.rawValue)")
    }

    private func openPlantFeatureDestination(_ destination: PlantFeatureDestination) {
        switch destination {
        case .water:
            openCareLogSheet(.watering)
        case .fertilize:
            openCareLogSheet(.fertilizing)
        case .pestCheck:
            openCareLogSheet(.pestCheck)
        case .leafCleaning:
            openCareLogSheet(.leafCleaning)
        case .profile:
            showingEditSheet = true
        case .photos:
            if galleryPhotoItems.isEmpty {
                openCareLogSheet(.photo)
            } else {
                showingPhotoGallery = true
            }
        case .carePlan:
            pendingFeatureScrollTarget = .carePlan
        case .calendar:
            openCareCalendar()
        case .reminders:
            openReminderSettings()
        case .healthReview:
            pendingFeatureScrollTarget = .healthReview
        case .timeline:
            pendingFeatureScrollTarget = .timeline
        case .catalog:
            pendingFeatureScrollTarget = .knowledge
        case .safety:
            if activeSafetyWarningCount > 0 {
                pendingFeatureScrollTarget = .safety
            } else {
                showingEditSheet = true
            }
        }
    }

    private func openCareCalendar() {
        showingAllFeaturesHub = false
        OhanaFrameScheduler.runAfterNextFrame {
            onOpenCalendar(plant.id)
        }
    }

    private func openReminderSettings() {
        showingAllFeaturesHub = false
        showingEditSheet = true
    }

    private func openPlantPhotos() {
        showingAllFeaturesHub = false
        if galleryPhotoItems.isEmpty {
            openCareLogSheet(.photo)
        } else {
            showingPhotoGallery = true
        }
    }

    private func openCareLogSheet(_ type: PlantCareType) {
        careLogDraftType = type
    }

    private func savePlantCareLog(_ type: PlantCareType, careNote: String, healthStatus: PlantHealthStatus, photoData: Data?) {
        recordCare(type, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
    }

    private func recordCare(
        _ type: PlantCareType,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
        }
    }

    private func deferTaskOneDay(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        let reasonSuffix = reason.map { "|\($0)" } ?? ""
        recordCare(.customNote, careNote: "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))\(reasonSuffix)")
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    private func stagePlantDelete() {
        guard !isDeletePending else { return }
        isDeletePending = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        deleteUndoTask?.cancel()
        deleteUndoTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                commitPendingDelete()
            }
        }
    }

    private func cancelPendingDelete() {
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func commitPendingDelete() {
        guard isDeletePending else { return }
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        deletePlant()
    }

    private func deletePlant() {
        let command = DomainCommand.memberDeletion(entityID: plant.id, kind: EntityKind.plant.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                plant,
                note: "plant.detail.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}
