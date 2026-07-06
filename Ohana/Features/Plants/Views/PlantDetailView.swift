//
//  PlantDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct PlantDetailContentView: View {
    let plant: Plant
    let households: [Household]
    let initialFeatureDestination: PlantFeatureDestination?

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") var activeHumanIdRaw = ""
    @AppStorage("ohana_onboarding_has_pets") var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") var onboardingHasChildren = false

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var showingEditSheet = false
    @State var showingAllFeaturesHub = false
    @State var showingPlantDetailExtras = false
    @State var showingDeleteConfirm = false
    @State var showingPhotoGallery = false
    @State var careLogDraftType: PlantCareType?
    @State var careFeatureDraft: PlantDetailCareFeatureDraft?
    @State var quickCareConfirmDraft: PlantQuickCareConfirmDraft?
    @State var quickCareToast: PlantQuickCareToast?
    @State var pendingDetailQuickCareTypes: Set<PlantCareType> = []
    @State var completedDetailQuickCareTypes: Set<PlantCareType> = []
    @State var failedDetailQuickCareTypes: Set<PlantCareType> = []
    @State var isDeletePending = false
    @State var isDeleteCommitting = false
    @State var deleteUndoTask: Task<Void, Never>?
    @State var diagnosisResult: PlantDiagnosisResult?
    @State var pendingFeatureScrollTarget: PlantDetailFeatureAnchor?
    @State var didOpenInitialFeatureDestination = false
    @State private var renderDataRefreshTask: Task<Void, Never>?
    @State private var renderDataRefreshGeneration = 0
    @State private var mediaAttachmentIndexRepairTask: Task<Void, Never>?
    @State var quickCareToastClearTask: Task<Void, Never>?
    @State private var renderData: PlantDetailRenderData?
    var catalogEntry: PlantCatalogEntry? { PlantCatalog.entry(id: plant.catalogSpeciesId) }
    var l: L10n { L10n(appLanguage) }
    var isRenderDataReady: Bool { renderData != nil }
    var renderDataRevision: Int { renderData?.revision ?? 0 }
    var careTasks: [PlantCareTaskSnapshot] {
        renderData?.careTasks ?? []
    }
    var taskSummary: PlantDetailTaskSummary? {
        renderData?.taskSummary
    }
    var logSummary: PlantDetailLogSummary? {
        renderData?.logSummary
    }
    var isWateringDue: Bool {
        taskSummary?.isWateringDue ?? false
    }
    var isFertilizingDue: Bool {
        taskSummary?.isFertilizingDue ?? false
    }
    var wateringIntervalDays: Int {
        taskSummary?.wateringIntervalDays ?? plant.wateringIntervalDays
    }
    var fertilizingIntervalDays: Int {
        taskSummary?.fertilizingIntervalDays ?? plant.fertilizingIntervalDays
    }
    var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }
    var recentLogs: [PlantDetailLogSnapshot] {
        renderData?.recentLogs ?? []
    }
    var nextTask: PlantCareTaskSnapshot? { taskSummary?.nextTask }
    var dueTaskCount: Int { taskSummary?.dueTaskCount ?? 0 }
    var placementSummary: String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactSpot = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !exactSpot.isEmpty, room != exactSpot {
            return "\(room) · \(exactSpot)"
        }
        if !room.isEmpty { return room }
        if !exactSpot.isEmpty { return exactSpot }
        return l.tr(zh: "未设置位置", en: "No location set", de: "Kein Standort")
    }
    var healthTone: Color {
        switch plant.healthStatus {
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
    var healthSummaryText: String {
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
    var wateringStatusText: String {
        guard let days = plant.daysSinceWatered else {
            return l.tr(zh: "还没有浇水记录", en: "No watering records yet", de: "Noch keine Gießprotokolle")
        }
        return l.tr(zh: "距上次 \(days) 天", en: "\(days)d since last", de: "\(days) T. seitdem")
    }
    var fertilizingStatusText: String {
        guard let days = plant.daysSinceFertilized else {
            return l.tr(zh: "还没有施肥记录", en: "No fertilizing records yet", de: "Noch keine Düngeprotokolle")
        }
        return l.tr(zh: "距上次 \(days) 天", en: "\(days)d since last", de: "\(days) T. seitdem")
    }
    var activeSafetyWarningCount: Int {
        [
            onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs),
            onboardingHasChildren && plant.isToxicToChildren,
            !plant.isIndoorSuitable,
            plant.isNearClimateSource
        ].count { $0 }
    }
    var growthDiaryPhotoCount: Int {
        renderData?.growthDiaryPhotoCount ?? 0
    }
    var latestHealthReviewLog: PlantDetailLogSnapshot? {
        logSummary?.latestHealthReviewLog
    }
    var recentStressSignalCount: Int {
        logSummary?.recentStressSignalCount ?? 0
    }
    var hasRecentStressSignals: Bool {
        logSummary?.hasRecentStressSignals ?? false
    }
    var recentObservationLogCount: Int {
        logSummary?.recentObservationLogCount ?? 0
    }
    var healthReviewSignals: [PlantHealthReviewSignal] {
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

        if hasRecentStressSignals {
            signals.append(
                PlantHealthReviewSignal(
                    id: "recent-stress",
                    icon: "waveform.path.ecg",
                    title: l.tr(zh: "30 天内有异常信号", en: "Recent stress signals", de: "Aktuelle Stresssignale"),
                    detail: l.tr(
                        zh: "\(recentStressSignalCount) 条黄叶/虫害记录，建议先复查叶背、土面和新芽。",
                        en: "\(recentStressSignalCount) yellow-leaf or pest notes in 30 days. Recheck leaf undersides, soil, and new growth.",
                        de: "\(recentStressSignalCount) Gelbblatt- oder Schädlingsnotizen in 30 Tagen. Blattunterseiten, Erde und Neutriebe prüfen."
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
                    tint: Color.goPrimary,
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
    var healthReviewSummaryText: String {
        if plant.healthStatus == .stressed {
            return l.tr(zh: "先查水、光、虫。", en: "Check water, light, pests.", de: "Wasser, Licht, Schädlinge prüfen.")
        }
        if plant.healthStatus == .watching || hasRecentStressSignals {
            return l.tr(zh: "近期异常优先复查。", en: "Review recent signals first.", de: "Aktuelle Signale zuerst prüfen.")
        }
        if latestHealthReviewLog == nil {
            return l.tr(zh: "还没有健康观察。", en: "No health review yet.", de: "Noch kein Gesundheitscheck.")
        }
        return l.tr(zh: "状态稳定。", en: "Stable.", de: "Stabil.")
    }
    var latestHealthReviewText: String {
        guard let latestHealthReviewLog else {
            return l.tr(zh: "未记录", en: "Not logged", de: "Nicht erfasst")
        }
        return "\(latestHealthReviewLog.careType.displayName(l: l)) · \(shortDate(latestHealthReviewLog.date))"
    }
    var galleryPhotoItems: [PlantDetailPhotoItem] {
        renderData?.galleryPhotoItems ?? []
    }
    var growthDiaryMarkdown: String {
        renderData?.growthDiaryMarkdown ?? ""
    }
    var growthDiaryDateRangeText: String {
        guard let first = logSummary?.firstLogDate else {
            return l.tr(zh: "还没有记录", en: "No logs yet", de: "Noch keine Protokolle")
        }
        guard let latest = logSummary?.latestLogDate, latest != first else {
            return shortDate(first)
        }
        return "\(shortDate(first)) - \(shortDate(latest))"
    }
    var growthDiarySummaryText: String {
        let logCount = logSummary?.logCount ?? 0
        if logCount == 0 {
            return l.tr(
                zh: "暂无成长记录。",
                en: "No growth record yet.",
                de: "Noch keine Wachstumsakte."
            )
        }
        return l.tr(
            zh: "\(logCount) 条 · \(growthDiaryPhotoCount) 图 · \(growthDiaryDateRangeText)",
            en: "\(logCount) logs · \(growthDiaryPhotoCount) photos · \(growthDiaryDateRangeText)",
            de: "\(logCount) Protokolle · \(growthDiaryPhotoCount) Fotos · \(growthDiaryDateRangeText)"
        )
    }
    var profileMissingItems: [String] {
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
        if (logSummary?.logCount ?? 0) == 0 {
            items.append(l.tr(zh: "首条护理记录", en: "first care log", de: "erstes Pflegeprotokoll"))
        }
        return items
    }
    var profileCompletionPercent: Int {
        let total = 5
        let completed = max(0, total - profileMissingItems.count)
        return Int((Double(completed) / Double(total) * 100).rounded())
    }
    var carePlanInsights: [PlantCarePlanInsight] {
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
                    tint: Color.goPrimary
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

        if let learned = taskSummary?.learningSummary {
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
                    detail: (logSummary?.logCount ?? 0) == 0
                        ? l.tr(zh: "先完成几次护理记录，Ohana 才能判断你是否经常提前或延后。", en: "Log a few care actions so Ohana can see whether you often act early or late.", de: "Einige Pflegeaktionen protokollieren, damit Ohana frühe oder späte Muster erkennt.")
                        : l.tr(zh: "\(logSummary?.logCount ?? 0) 条记录已进入档案，继续记录会让节奏更稳。", en: "\(logSummary?.logCount ?? 0) logs are in the profile; more logs make the rhythm steadier.", de: "\(logSummary?.logCount ?? 0) Protokolle sind im Profil; mehr Verlauf stabilisiert den Rhythmus."),
                    tint: Color.goTeal
                )
            )
        }

        insights.append(healthCarePlanInsight)
        return insights
    }

    var environmentCarePlanInsight: PlantCarePlanInsight {
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

    var environmentPlanFactors: [String] {
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

    var placementFitItems: [PlantPlacementFitItem] {
        [
            placementLightFitItem,
            placementSafetyFitItem,
            placementEnvironmentFitItem
        ]
    }

    var placementLightFitItem: PlantPlacementFitItem {
        let desiredLight = catalogEntry?.lightRequirement ?? plant.lightLevel
        let hasLowLux = plant.lastLightMeasurementLux > 0 && plant.lastLightMeasurementLux < 1000
        let hasHighLux = plant.lastLightMeasurementLux >= 10000
        let isTooDim: Bool = switch desiredLight {
        case .low:
            false
        case .medium, .brightIndirect:
            plant.lightLevel == .low || hasLowLux
        case .direct:
            plant.lightLevel == .low || plant.lightLevel == .medium || hasLowLux
        }
        let isTooStrong: Bool = switch desiredLight {
        case .low, .medium, .brightIndirect:
            plant.lightLevel == .direct || hasHighLux
        case .direct:
            false
        }

        if isTooDim {
            return PlantPlacementFitItem(
                id: "light-dim",
                icon: "sun.min.fill",
                title: l.tr(zh: "光照偏弱", en: "Light may be low", de: "Licht eher schwach"),
                detail: l.tr(
                    zh: "这株更适合 \(desiredLight.displayName)，可以靠近明亮窗边一点。",
                    en: "This plant prefers \(desiredLight.displayName); move it a little closer to bright window light.",
                    de: "Diese Pflanze mag \(desiredLight.displayName); etwas näher ans helle Fenster stellen."
                ),
                tint: Color.goYellow
            )
        }
        if isTooStrong {
            return PlantPlacementFitItem(
                id: "light-strong",
                icon: "sun.max.fill",
                title: l.tr(zh: "直晒要留意", en: "Watch direct sun", de: "Direktsonne beachten"),
                detail: l.tr(
                    zh: "当前光照可能偏强，午后直晒时先观察焦边和卷叶。",
                    en: "Light may be strong here; watch for scorched edges or curled leaves in afternoon sun.",
                    de: "Das Licht kann stark sein; bei Nachmittagssonne auf braune Ränder oder eingerollte Blätter achten."
                ),
                tint: Color.goYellow
            )
        }
        return PlantPlacementFitItem(
            id: "light-fit",
            icon: "sun.haze.fill",
            title: l.tr(zh: "光照基本合适", en: "Light looks reasonable", de: "Licht passt grundsätzlich"),
            detail: l.tr(
                zh: "按当前档案看，位置和光照偏好没有明显冲突。",
                en: "Based on this profile, the placement and light preference do not conflict.",
                de: "Laut Profil widersprechen Standort und Lichtbedarf sich nicht."
            ),
            tint: Color.goPrimary
        )
    }

    var placementSafetyFitItem: PlantPlacementFitItem {
        if activeSafetyWarningCount > 0 {
            return PlantPlacementFitItem(
                id: "safety-review",
                icon: "shield.lefthalf.filled",
                title: l.tr(zh: "安全距离要复核", en: "Review safe reach", de: "Sichere Reichweite prüfen"),
                detail: l.tr(
                    zh: "宠物、儿童或室内适配提示会影响摆放，优先放在够不到的位置。",
                    en: "Pet, child, or indoor-fit notes affect placement; keep it out of easy reach first.",
                    de: "Haustier-, Kinder- oder Innenraumhinweise beeinflussen den Standort; zuerst außer Reichweite stellen."
                ),
                tint: Color.goYellow
            )
        }
        return PlantPlacementFitItem(
            id: "safety-clear",
            icon: "checkmark.shield.fill",
            title: l.tr(zh: "安全风险低", en: "Low safety risk", de: "Geringes Sicherheitsrisiko"),
            detail: l.tr(
                zh: "当前档案没有高优先级误食或室内摆放风险。",
                en: "This profile has no high-priority ingestion or indoor placement risk.",
                de: "Dieses Profil hat kein hohes Verschluck- oder Innenraumrisiko."
            ),
            tint: Color.goTeal
        )
    }

    var placementEnvironmentFitItem: PlantPlacementFitItem {
        if plant.isNearClimateSource {
            return PlantPlacementFitItem(
                id: "climate-source",
                icon: "wind",
                title: l.tr(zh: "远离空调/暖气", en: "Move from AC/heater", de: "Weg von Klima/Heizung"),
                detail: l.tr(
                    zh: "风口和暖气会让叶片、盆土变化更快；能移开就更省心。",
                    en: "Drafts and heaters make leaves and soil change faster; moving it away keeps care simpler.",
                    de: "Luftzug und Heizung verändern Blätter und Erde schneller; etwas Abstand macht Pflege einfacher."
                ),
                tint: Color.goYellow
            )
        }
        if !plant.potHasDrainage {
            return PlantPlacementFitItem(
                id: "drainage",
                icon: "drop.triangle.fill",
                title: l.tr(zh: "浇水要更保守", en: "Water more cautiously", de: "Vorsichtiger gießen"),
                detail: l.tr(
                    zh: "无排水孔时先少量浇，并等表土明显变干后再处理。",
                    en: "Without drainage, water lightly and wait until the surface soil clearly dries.",
                    de: "Ohne Abzug vorsichtig gießen und warten, bis die Oberfläche klar trocken ist."
                ),
                tint: Color.goYellow
            )
        }
        if plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plant.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlantPlacementFitItem(
                id: "location-missing",
                icon: "mappin.and.ellipse",
                title: l.tr(zh: "补一个位置即可", en: "Add one location", de: "Einen Standort ergänzen"),
                detail: l.tr(
                    zh: "只要填房间或具体位置，后续提醒和复查会更容易判断。",
                    en: "Adding a room or spot is enough to make reminders and checks easier to judge.",
                    de: "Ein Raum oder Ort reicht, damit Erinnerungen und Checks besser passen."
                ),
                tint: Color.goTeal
            )
        }
        return PlantPlacementFitItem(
            id: "environment-fit",
            icon: "house.and.flag.fill",
            title: l.tr(zh: "位置信息够用", en: "Placement is usable", de: "Standort ist nutzbar"),
            detail: l.tr(
                zh: "当前档案足够支持简单护理计划，后续按叶片和土壤反馈微调。",
                en: "The profile is enough for a simple care plan; tune later with leaf and soil feedback.",
                de: "Das Profil reicht für einen einfachen Pflegeplan; später mit Blatt- und Erdfeedback anpassen."
            ),
            tint: Color.goPrimary
        )
    }

    var seasonalGuidanceTitle: String {
        switch Calendar.current.component(.month, from: Date()) {
        case 3 ... 5:
            l.tr(zh: "春季生长期", en: "Spring growth season", de: "Frühjahrswachstum")
        case 6 ... 8:
            l.tr(zh: "夏季高温/强光", en: "Summer heat and light", de: "Sommerhitze und Licht")
        case 9 ... 11:
            l.tr(zh: "秋季换季", en: "Autumn transition", de: "Herbstübergang")
        default:
            l.tr(zh: "冬季低生长", en: "Winter slow growth", de: "Winterruhe")
        }
    }

    var seasonalGuidanceSummary: String {
        l.tr(
            zh: "以土壤和叶片为准。",
            en: "Soil and leaves come first.",
            de: "Erde und Blätter zuerst."
        )
    }

    var seasonalCareItems: [PlantSeasonalCareItem] {
        var items: [PlantSeasonalCareItem] = []
        switch Calendar.current.component(.month, from: Date()) {
        case 3 ... 5:
            items.append(PlantSeasonalCareItem(
                id: "season-spring",
                icon: "leaf.fill",
                title: l.tr(zh: "观察新叶", en: "Watch new growth", de: "Neue Triebe beobachten"),
                detail: l.tr(zh: "可以逐步恢复薄肥，但状态紧张时先别急。", en: "Light feeding can resume gradually, but wait if the plant is stressed.", de: "Schwache Düngung langsam starten, bei Stress aber warten."),
                tint: Color.goPrimary
            ))
        case 6 ... 8:
            items.append(PlantSeasonalCareItem(
                id: "season-summer",
                icon: "sun.max.fill",
                title: l.tr(zh: "先看暴晒和缺水", en: "Check sun and dryness", de: "Sonne und Trockenheit prüfen"),
                detail: l.tr(zh: "阳台、南/西向和小盆更容易干；午后焦边先移开强光。", en: "Balcony, south/west light, and small pots dry faster; move from harsh afternoon sun if edges scorch.", de: "Balkon, Süd/West-Licht und kleine Töpfe trocknen schneller; bei verbrannten Rändern aus Mittagssonne nehmen."),
                tint: Color.goYellow
            ))
        case 9 ... 11:
            items.append(PlantSeasonalCareItem(
                id: "season-autumn",
                icon: "arrow.triangle.2.circlepath",
                title: l.tr(zh: "慢慢减少施肥", en: "Reduce feeding slowly", de: "Düngung langsam reduzieren"),
                detail: l.tr(zh: "换季时先维持稳定位置，少搬动，留意夜间低温。", en: "Keep placement stable during the transition and watch cooler nights.", de: "Standort in der Übergangszeit stabil halten und kühlere Nächte beachten."),
                tint: Color.goTeal
            ))
        default:
            items.append(PlantSeasonalCareItem(
                id: "season-winter",
                icon: "snowflake",
                title: l.tr(zh: "浇水和施肥放慢", en: "Slow water and feeding", de: "Gießen und Düngen bremsen"),
                detail: l.tr(zh: "多数室内植物生长变慢，施肥可延后，浇水前先确认土干。", en: "Most indoor plants slow down; defer feeding and confirm soil is dry before watering.", de: "Viele Zimmerpflanzen wachsen langsamer; Düngen verschieben und vor dem Gießen trockene Erde prüfen."),
                tint: Color.goTeal
            ))
        }

        items.append(
            plant.isIndoor
                ? PlantSeasonalCareItem(
                    id: "weather-indoor",
                    icon: "house.fill",
                    title: l.tr(zh: "室内先看小环境", en: "Indoor microclimate first", de: "Innenklima zuerst"),
                    detail: l.tr(zh: "室内不必追天气预报，重点看窗边温度、空调暖气和盆土。", en: "No need to chase forecasts indoors; watch window temperature, AC/heater, and soil.", de: "Innen nicht dem Wetterbericht folgen; Fensterwärme, Klima/Heizung und Erde beobachten."),
                    tint: Color.goPrimary
                )
                : PlantSeasonalCareItem(
                    id: "weather-outdoor",
                    icon: "cloud.sun.rain.fill",
                    title: l.tr(zh: "阳台/户外看实际天气", en: "Outdoor depends on real weather", de: "Draußen zählt echtes Wetter"),
                    detail: l.tr(zh: "高温大风会更快干，连续阴雨后先别急着浇。", en: "Heat and wind dry faster; after rainy stretches, do not rush watering.", de: "Hitze und Wind trocknen schneller; nach Regenphasen nicht sofort gießen."),
                    tint: Color.goYellow
                )
        )

        if plant.isSucculent {
            items.append(PlantSeasonalCareItem(
                id: "plant-type-succulent",
                icon: "drop.degreesign.fill",
                title: l.tr(zh: "多肉宁可少水", en: "Succulents prefer less water", de: "Sukkulenten lieber trockener"),
                detail: l.tr(zh: "无论季节，宁可等土更干一些再浇。", en: "Across seasons, wait for soil to dry more before watering.", de: "In jeder Saison lieber trockener werden lassen."),
                tint: Color.goTeal
            ))
        } else if plant.humidityPreference == .humid {
            items.append(PlantSeasonalCareItem(
                id: "plant-type-humid",
                icon: "humidity.fill",
                title: l.tr(zh: "偏湿植物看湿度", en: "Humidity-loving plant", de: "Feuchtigkeitsliebend"),
                detail: l.tr(zh: "干燥季节重点观察叶尖和卷叶，而不是只增加浇水量。", en: "In dry periods, watch tips and curled leaves instead of only adding more water.", de: "In trockenen Phasen Blattspitzen und Rollen prüfen, nicht nur mehr gießen."),
                tint: Color.goTeal
            ))
        }

        return Array(items.prefix(3))
    }

    var healthCarePlanInsight: PlantCarePlanInsight {
        switch plant.healthStatus {
        case .thriving:
            PlantCarePlanInsight(
                id: "health-thriving",
                icon: "leaf.circle.fill",
                title: l.tr(zh: "健康状态支持当前节奏", en: "Health supports this rhythm", de: "Gesundheit stützt diesen Rhythmus"),
                detail: l.tr(zh: "状态很好时，计划会保持稳定，不频繁打断。", en: "When the plant is thriving, the plan stays steady and avoids noisy interruptions.", de: "Bei gutem Zustand bleibt der Plan stabil und stört weniger."),
                tint: Color.goPrimary
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
    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        heroCard
                        careOverviewCard
                            .id(PlantDetailFeatureAnchor.overview)
                        plantSectionHeader(l.tr(zh: "今日护理", en: "Today care", de: "Pflege heute"))
                        .id(PlantDetailFeatureAnchor.todayCare)
                        todayCarePanel
                        plantSectionHeader(l.tr(zh: "成长记录", en: "Growth record", de: "Wachstumsakte"))
                        .id(PlantDetailFeatureAnchor.growthDiary)
                        growthDiaryCard
                        plantSectionHeader(l.tr(zh: "时间线", en: "Timeline", de: "Zeitachse"))
                        .id(PlantDetailFeatureAnchor.timeline)
                        historyCard
                        notesCard
                        advancedPlantDetailsSection
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
        .onAppear {
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
            scheduleMediaAttachmentIndexRepair()
            scheduleInitialPlantFeatureDestinationIfNeeded()
        }
        .onChange(of: appLanguage) { _, _ in
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
        }
        .onChange(of: renderDataRevision) { _, _ in
            openInitialPlantFeatureDestinationIfReady()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            guard shouldRefreshPlantDetailRenderDataForLatestMutation else { return }
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
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
        .overlay(alignment: .bottom) {
            plantQuickCareOverlay
        }
        .sheet(isPresented: $showingAllFeaturesHub) {
            PlantAllFeaturesSheet(
                plant: plant,
                careTasks: careTasks,
                logCount: logSummary?.logCount ?? 0,
                photoCount: galleryPhotoItems.count,
                profileCompletionPercent: profileCompletionPercent,
                safetyWarningCount: activeSafetyWarningCount,
                onOpenDestination: queuePlantFeatureHubDestination
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlantSheet(plant: plant)
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PlantPhotoGallerySheet(
                plantName: plant.name,
                photos: galleryPhotoItems,
                imageRevision: renderDataRevision,
                imageDataProvider: { await photoImageData(for: $0) }
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
        .sheet(item: $careFeatureDraft) { draft in
            PlantCareFeatureDetailView(
                plants: [plant],
                feature: draft.feature,
                focusedPlantID: plant.id,
                focusedCareType: draft.focusedCareType
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
            renderDataRefreshTask?.cancel()
            mediaAttachmentIndexRepairTask?.cancel()
            quickCareToastClearTask?.cancel()
            deleteUndoTask?.cancel()
            if !isDeleteCommitting {
                commandQueue.cancelAll()
            }
        }
        .task(id: plant.healthStatusRaw) {
            diagnosisResult = await appServices.plantIntelligence.diagnosePlant(
                imageData: nil,
                symptoms: diagnosisSymptoms
            )
        }
    }

    var shouldRefreshPlantDetailRenderDataForLatestMutation: Bool {
        guard let mutation = appServices.domainRevisions.lastMutation else {
            return false
        }
        return mutation.affectedEntityIDs.contains(plant.id)
    }

    func schedulePlantDetailRenderDataRebuild(delayMilliseconds: UInt64 = 24) {
        renderDataRefreshTask?.cancel()
        renderDataRefreshGeneration += 1
        let generation = renderDataRefreshGeneration
        let container = modelContext.container
        let plantModelID = plant.persistentModelID
        let languageCode = appLanguage
        let nextRevision = (renderData?.revision ?? 0) + 1
        renderDataRefreshTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled,
                  generation == renderDataRefreshGeneration else {
                return
            }
            let builder = PlantDetailRenderDataActor(modelContainer: container)
            do {
                let data = try await builder.build(
                    request: PlantDetailRenderDataRequest(
                        plantModelID: plantModelID,
                        revision: nextRevision,
                        languageCode: languageCode,
                        now: Date()
                    )
                )
                guard !Task.isCancelled,
                      generation == renderDataRefreshGeneration else {
                    return
                }
                applyPlantDetailRenderData(data)
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning("Plant detail render data build failed: \(error)", category: "Plants")
            }
            clearPlantDetailRenderDataRefreshTask(generation: generation)
        }
    }

    func applyPlantDetailRenderData(_ data: PlantDetailRenderData) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderData = data
        }
    }

    func clearPlantDetailRenderDataRefreshTask(generation: Int) {
        guard generation == renderDataRefreshGeneration else { return }
        renderDataRefreshTask = nil
    }

    func scheduleMediaAttachmentIndexRepair() {
        mediaAttachmentIndexRepairTask?.cancel()
        mediaAttachmentIndexRepairTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 96)
            guard !Task.isCancelled else { return }
            let didRepair = PlantMediaAttachmentIndexRepair.repair(
                plants: [plant],
                modelContext: modelContext
            )
            if didRepair {
                schedulePlantDetailRenderDataRebuild(delayMilliseconds: 0)
            }
            mediaAttachmentIndexRepairTask = nil
        }
    }

    func photoImageData(for photo: PlantDetailPhotoItem) async -> Data? {
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        switch photo.source {
        case .profile:
            return await loader.plantAvatarImageData(modelID: plant.persistentModelID)
        case let .careLog(logModelID, _):
            return await loader.plantCareLogPhotoData(modelID: logModelID)
        }
    }

    var advancedPlantDetailsSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(GoMotion.quick) {
                    showingPlantDetailExtras.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative advanced-details glyph; button text labels the action.
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.goTeal.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "更多植物资料", en: "More plant details", de: "Weitere Pflanzendetails"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "节奏 · 位置 · 安全", en: "Rhythm · Place · Safety", de: "Rhythmus · Ort · Sicherheit"))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down") // a11y: allow decorative disclosure glyph; button value exposes expanded state.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .rotationEffect(.degrees(showingPlantDetailExtras ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 16)
            .accessibilityLabel(l.tr(zh: "更多植物资料", en: "More plant details", de: "Weitere Pflanzendetails"))
            .accessibilityValue(showingPlantDetailExtras ? l.tr(zh: "已展开", en: "Expanded", de: "Geöffnet") : l.tr(zh: "已收起", en: "Collapsed", de: "Geschlossen"))
            .accessibilityIdentifier("plant-detail-advanced-toggle")

            if showingPlantDetailExtras {
                VStack(spacing: 20) {
                    plantSectionHeader(l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan"))
                    .id(PlantDetailFeatureAnchor.carePlan)
                    careRhythmCard
                    carePlanInsightCard
                    seasonalGuidanceCard
                    plantSectionHeader(l.tr(zh: "植物档案", en: "Plant profile", de: "Pflanzenprofil"))
                    .id(PlantDetailFeatureAnchor.profile)
                    environmentCard
                    growthProfileCard
                    placementFitCard
                    plantSectionHeader(l.tr(zh: "健康与资料", en: "Health and knowledge", de: "Gesundheit und Wissen"))
                    .id(PlantDetailFeatureAnchor.knowledge)
                    safetyCard
                        .id(PlantDetailFeatureAnchor.safety)
                    catalogCard
                    diagnosisCard
                    healthReviewCard
                        .id(PlantDetailFeatureAnchor.healthReview)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("plant-detail-advanced-content")
            }
        }
        .accessibilityIdentifier("plant-detail-advanced-section")
    }

    var diagnosisSymptoms: [String] {
        switch plant.healthStatus {
        case .thriving, .stable:
            ["黄叶"]
        case .watching:
            ["黄叶", "停止生长"]
        case .stressed:
            ["黄叶", "叶片卷曲", "掉叶"]
        }
    }
}
