import Foundation

enum GrowthUnlockStageID: String, CaseIterable, Identifiable {
    case dailyCare
    case bodyHealth
    case memory
    case household
    case oasisPlants
    case rewards
    case advancedPlay
    case advancedInsights
    case memoryReview
    case mastery

    var id: String { rawValue }
}

struct GrowthUnlockStep: Identifiable, Hashable {
    let id: GrowthUnlockStageID
    let requiredLevel: Int
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let detailZh: String
    let detailEn: String
    let detailDe: String
    let icon: String
    let tintHex: String

    func title(language: String) -> String {
        let additional: [String: String] = switch id {
        case .dailyCare:
            ["es": "Semilla de cuidado", "pt": "Semente de cuidado", "fr": "Graine de soin", "ja": "ケアの種", "ko": "돌봄 씨앗", "it": "Seme di cura"]
        case .bodyHealth:
            ["es": "Brote de salud", "pt": "Broto de saúde", "fr": "Pousse de santé", "ja": "健康の芽", "ko": "건강 새싹", "it": "Germoglio di salute"]
        case .memory:
            ["es": "Rama de recuerdos", "pt": "Ramo de memórias", "fr": "Branche de souvenirs", "ja": "成長の枝", "ko": "추억 가지", "it": "Ramo dei ricordi"]
        case .household:
            ["es": "Copa de vida", "pt": "Copa da vida", "fr": "Canopée de vie", "ja": "生命の樹冠", "ko": "생명의 수관", "it": "Chioma della vita"]
        case .oasisPlants:
            ["es": "Rendimiento del oasis", "pt": "Rendimento do Oasis", "fr": "Rendement de l’Oasis", "ja": "オアシスの恵み", "ko": "오아시스 수확", "it": "Raccolto dell’Oasi"]
        case .rewards:
            ["es": "Fruto del cuidado", "pt": "Fruto do cuidado", "fr": "Fruit des soins", "ja": "ケアの実", "ko": "돌봄 열매", "it": "Frutto della cura"]
        case .advancedPlay:
            ["es": "Colección", "pt": "Coleção", "fr": "Collection", "ja": "コレクション", "ko": "컬렉션", "it": "Collezione"]
        case .advancedInsights:
            ["es": "Anillos de análisis", "pt": "Anéis de análise", "fr": "Anneaux d’analyse", "ja": "洞察の年輪", "ko": "통찰 나이테", "it": "Anelli di analisi"]
        case .memoryReview:
            ["es": "Anillos de recuerdos", "pt": "Anéis de memórias", "fr": "Anneaux de souvenirs", "ja": "思い出の年輪", "ko": "추억 나이테", "it": "Anelli dei ricordi"]
        case .mastery:
            ["es": "Copa maestra", "pt": "Copa mestra", "fr": "Canopée maîtresse", "ja": "マスター樹冠", "ko": "마스터 수관", "it": "Chioma maestra"]
        }
        return AppLocalizedText(
            zh: titleZh,
            en: titleEn,
            de: titleDe,
            extras: additional
        ).resolve(language)
    }

    func detail(language: String) -> String {
        AppLocalizedText(zh: detailZh, en: detailEn, de: detailDe).resolve(language)
    }
}

struct GrowthUnlockStatus: Hashable, Identifiable {
    let step: GrowthUnlockStep
    let currentLevel: Int

    var id: String {
        "\(step.id.rawValue)-\(currentLevel)"
    }

    var isUnlocked: Bool {
        currentLevel >= step.requiredLevel
    }

    var missingLevels: Int {
        max(0, step.requiredLevel - currentLevel)
    }
}

enum AppFeatureAvailability: Equatable {
    case visible(GrowthUnlockStatus)
    case hiddenLocked(GrowthUnlockStatus)
    case outOfScope

    var isVisibleInApp: Bool {
        if case .visible = self { return true }
        return false
    }

    var status: GrowthUnlockStatus? {
        switch self {
        case let .visible(status), let .hiddenLocked(status):
            status
        case .outOfScope:
            nil
        }
    }
}

enum GrowthUnlockCatalog {
    static let stages: [GrowthUnlockStep] = [
        GrowthUnlockStep(
            id: .dailyCare,
            requiredLevel: 1,
            titleZh: "照护种子",
            titleEn: "Care Seed",
            titleDe: "Pflege-Samen",
            detailZh: "开放日常照护、单个成员或宠物的健康与用药记录，以及家庭洞察中的体重、花费和基础日历。",
            detailEn: "Open daily care, individual health and medication records, plus Weight, Expenses, and the basic calendar in Household Insights.",
            detailDe: "Öffnet tägliche Pflege, einzelne Gesundheits- und Medikamenteneinträge sowie Gewicht, Ausgaben und den Basiskalender in den Haushaltseinblicken.",
            icon: "leaf.fill",
            tintHex: "22C55E"
        ),
        GrowthUnlockStep(
            id: .bodyHealth,
            requiredLevel: 2,
            titleZh: "健康嫩芽",
            titleEn: "Health Sprout",
            titleDe: "Gesundheits-Spross",
            detailZh: "解锁健康与用药的家庭聚合面板和基础趋势；原始健康与用药记录已在 Lv.1 开放。",
            detailEn: "Unlock household health and medication summaries with basic trends; raw health and medication records are already open at Lv.1.",
            detailDe: "Öffnet zusammengefasste Gesundheits- und Medikamentenansichten mit Basistrends; einzelne Einträge sind bereits ab Lv.1 offen.",
            icon: "cross.fill",
            tintHex: "14B8A6"
        ),
        GrowthUnlockStep(
            id: .memory,
            requiredLevel: 3,
            titleZh: "成长枝条",
            titleEn: "Memory Branch",
            titleDe: "Erinnerungs-Zweig",
            detailZh: "解锁时光记录、照片、成长时间线和成就，把长期变化沉淀成故事。",
            detailEn: "Unlock moments, photos, growth timelines, and achievements so long-term change becomes a story.",
            detailDe: "Öffnet Momente, Fotos, Wachstumszeitleisten und Erfolge für langfristige Geschichten.",
            icon: "sparkles.rectangle.stack.fill",
            tintHex: "F59E0B"
        ),
        GrowthUnlockStep(
            id: .household,
            requiredLevel: 4,
            titleZh: "生命树冠",
            titleEn: "Life Canopy",
            titleDe: "Lebenskrone",
            detailZh: "家庭从宠物扩展到家中其他生命：解锁植物档案、护理计划、日志、资料库和本地提醒。",
            detailEn: "Extend the household from pets to other living things: unlock plant profiles, care plans, logs, catalog, and local reminders.",
            detailDe: "Erweitert den Haushalt von Haustieren auf weitere Lebewesen: Pflanzenprofile, Pflegepläne, Protokolle, Katalog und lokale Erinnerungen.",
            icon: "house.fill",
            tintHex: "8B5CF6"
        ),
        GrowthUnlockStep(
            id: .oasisPlants,
            requiredLevel: 5,
            titleZh: "绿洲收益",
            titleEn: "Oasis Yield",
            titleDe: "Oasis-Ertrag",
            detailZh: "植物基础管理已经开放；Lv.5 开始把照护反馈到绿洲氛围、装饰和收益循环。",
            detailEn: "Basic plant management is already open; Lv.5 starts feeding care back into Oasis mood, decoration, and yield loops.",
            detailDe: "Die grundlegende Pflanzenverwaltung ist bereits offen; ab Lv.5 fließt Pflege in Oasis-Stimmung, Deko und Ertrag zurück.",
            icon: "tree.fill",
            tintHex: "84CC16"
        ),
        GrowthUnlockStep(
            id: .rewards,
            requiredLevel: 6,
            titleZh: "成果果实",
            titleEn: "Care Fruit",
            titleDe: "Pflegefrucht",
            detailZh: "解锁椰子商店、装饰和标准家庭周报。",
            detailEn: "Unlock the coconut shop, cosmetics, and the standard household weekly report.",
            detailDe: "Öffnet Kokos-Shop, Dekorationen und den Standard-Wochenbericht des Haushalts.",
            icon: "bag.fill",
            tintHex: "EAB308"
        ),
        GrowthUnlockStep(
            id: .advancedPlay,
            requiredLevel: 7,
            titleZh: "收藏玩法",
            titleEn: "Collection Play",
            titleDe: "Sammelspiel",
            detailZh: "解锁扭蛋和高级收集玩法；它们是奖励层，不打断日常管理。",
            detailEn: "Unlock gacha and advanced collection as a reward layer that never interrupts daily care.",
            detailDe: "Schalte Gacha und Sammlung frei, ohne die tägliche Pflege zu stören.",
            icon: "circle.grid.cross.fill",
            tintHex: "F97316"
        ),
        GrowthUnlockStep(
            id: .advancedInsights,
            requiredLevel: 8,
            titleZh: "洞察树环",
            titleEn: "Insight Rings",
            titleDe: "Einsichts-Ringe",
            detailZh: "解锁深度照护分析和完整提醒诊断；安全告警始终可见。",
            detailEn: "Unlock deep care analysis and full reminder diagnostics; safety alerts always remain visible.",
            detailDe: "Öffnet tiefe Pflegeanalysen und vollständige Erinnerungsdiagnosen; Sicherheitswarnungen bleiben immer sichtbar.",
            icon: "chart.xyaxis.line",
            tintHex: "06B6D4"
        ),
        GrowthUnlockStep(
            id: .memoryReview,
            requiredLevel: 9,
            titleZh: "记忆年轮",
            titleEn: "Memory Rings",
            titleDe: "Erinnerungs-Ringe",
            detailZh: "解锁独立的长期家庭回顾，按月份整理重要照护与回忆，不重复周报。",
            detailEn: "Unlock a distinct long-term household review with monthly care and memory highlights, separate from the weekly report.",
            detailDe: "Öffnet einen eigenständigen Langzeitrückblick mit monatlichen Pflege- und Erinnerungshöhepunkten, getrennt vom Wochenbericht.",
            icon: "book.closed.fill",
            tintHex: "EC4899"
        ),
        GrowthUnlockStep(
            id: .mastery,
            requiredLevel: 10,
            titleZh: "大师树冠",
            titleEn: "Master Canopy",
            titleDe: "Meister-Krone",
            detailZh: "解锁电子宠物、大师树外观、顶级被动收益和长期荣誉。",
            detailEn: "Unlock the e-critter, master tree styling, top passive income, and long-term honors.",
            detailDe: "Öffnet E-Critter, Meisterbaum, höchste passive Erträge und Langzeit-Ehren.",
            icon: "crown.fill",
            tintHex: "00FFD1"
        )
    ]
}

enum GrowthUnlockExperiencePolicy {
    private static let standardOnlyZenStages: Set<GrowthUnlockStageID> = [
        .dailyCare,
        .bodyHealth,
        .household,
        .advancedInsights,
        .memoryReview
    ]

    static func isStandardOnlyInZen(_ stageID: GrowthUnlockStageID) -> Bool {
        standardOnlyZenStages.contains(stageID)
    }

    static func detail(
        for step: GrowthUnlockStep,
        experienceMode: AppExperienceMode,
        language: String
    ) -> String {
        guard experienceMode == .zen else { return step.detail(language: language) }
        let text: AppLocalizedText = switch step.id {
        case .dailyCare:
            AppLocalizedText(
                zh: "普通模式在此开放日常照护、健康与用药记录和基础家庭洞察；Zen 打卡与 Oasis 不受此等级限制。",
                en: "Standard opens daily care, health and medication records, and basic household insights here; Zen check-ins and Oasis are not gated by this level.",
                de: "Im Standardmodus öffnen sich hier tägliche Pflege, Gesundheits- und Medikamenteneinträge sowie grundlegende Haushaltseinblicke; Zen-Check-ins und Oasis sind nicht daran gebunden."
            )
        case .bodyHealth:
            AppLocalizedText(
                zh: "普通模式在此开放家庭健康与用药聚合趋势；Zen 仍保持轻量打卡体验。",
                en: "Standard opens household health and medication trends here; Zen keeps its lightweight check-in experience.",
                de: "Im Standardmodus öffnen sich hier Gesundheits- und Medikamententrends des Haushalts; Zen bleibt bei leichten Check-ins."
            )
        case .memory:
            AppLocalizedText(
                zh: "Zen 在此开放成就；时光记录、照片与成长时间线可切换到普通模式使用。",
                en: "Zen opens achievements here; switch to Standard for moments, photos, and growth timelines.",
                de: "Zen öffnet hier Erfolge; Momente, Fotos und Wachstumszeitleisten sind im Standardmodus verfügbar."
            )
        case .household:
            AppLocalizedText(
                zh: "Zen 从第一天就显示植物卡片；Lv.4 开放的是普通模式中的植物护理计划、日志、资料库和本地提醒。",
                en: "Zen shows plant cards from day one; Lv.4 opens Standard-mode plant care plans, logs, the catalog, and local reminders.",
                de: "Zen zeigt Pflanzenkarten ab dem ersten Tag; Lv.4 öffnet Pflegepläne, Protokolle, Katalog und lokale Erinnerungen im Standardmodus."
            )
        case .oasisPlants:
            AppLocalizedText(
                zh: "开放共享 Oasis 的氛围、装饰与每日被动收益循环。",
                en: "Open the shared Oasis mood, decoration, and daily passive-income loop.",
                de: "Öffnet Stimmung, Dekoration und tägliche passive Erträge der gemeinsamen Oasis."
            )
        case .rewards:
            AppLocalizedText(
                zh: "开放共享椰子商店与装饰；家庭周报属于普通模式。",
                en: "Open the shared coconut shop and cosmetics; household weekly reports belong to Standard.",
                de: "Öffnet den gemeinsamen Kokos-Shop und Kosmetik; Haushalts-Wochenberichte gehören zum Standardmodus."
            )
        case .advancedPlay:
            AppLocalizedText(
                zh: "开放共享扭蛋与高级收集玩法，不打断每日打卡。",
                en: "Open shared gacha and advanced collection without interrupting daily check-ins.",
                de: "Öffnet gemeinsame Gacha- und Sammelfunktionen, ohne tägliche Check-ins zu unterbrechen."
            )
        case .advancedInsights:
            AppLocalizedText(
                zh: "普通模式在此开放深度照护分析与完整提醒诊断；Zen 的安全告警始终可见。",
                en: "Standard opens deep care analysis and full reminder diagnostics here; Zen safety alerts always remain visible.",
                de: "Im Standardmodus öffnen sich hier tiefe Pflegeanalysen und vollständige Erinnerungsdiagnosen; Sicherheitswarnungen bleiben in Zen immer sichtbar."
            )
        case .memoryReview:
            AppLocalizedText(
                zh: "普通模式在此开放按月整理照护与回忆的长期家庭回顾。",
                en: "Standard opens the monthly long-term household care and memory review here.",
                de: "Im Standardmodus öffnet sich hier der monatliche Langzeitrückblick auf Pflege und Erinnerungen."
            )
        case .mastery:
            AppLocalizedText(
                zh: "开放共享电子宠物、大师树外观、顶级被动收益和长期荣誉。",
                en: "Open the shared e-critter, master tree styling, top passive income, and long-term honors.",
                de: "Öffnet den gemeinsamen E-Critter, Meisterbaum, höchste passive Erträge und Langzeit-Ehren."
            )
        }
        return text.resolve(language)
    }
}

enum GrowthUnlockPolicy {
    static let stages: [GrowthUnlockStep] = GrowthUnlockCatalog.stages

    static func currentStep(currentLevel: Int) -> GrowthUnlockStep {
        stages
            .last(where: { currentLevel >= $0.requiredLevel }) ?? stages[0]
    }

    static func nextLockedStep(currentLevel: Int) -> GrowthUnlockStep? {
        stages
            .first(where: { currentLevel < $0.requiredLevel })
    }

    static func roadmapStages(includeOutOfScope _: Bool = false) -> [GrowthUnlockStep] {
        stages
    }

    static func newlyUnlockedStages(from previousLevel: Int, to currentLevel: Int) -> [GrowthUnlockStep] {
        guard currentLevel > previousLevel else { return [] }
        return stages.filter { step in
            step.requiredLevel > previousLevel && step.requiredLevel <= currentLevel
        }
    }

    static func primaryDestination(for step: GrowthUnlockStep) -> FMDest {
        primaryDestination(for: step.id)
    }

    static func primaryDestination(for stageID: GrowthUnlockStageID) -> FMDest {
        switch stageID {
        case .dailyCare:
            .featureGroup(.dailyCare)
        case .bodyHealth:
            .featureGroup(.healthBody)
        case .memory:
            .featureGroup(.archiveMemory)
        case .household:
            .featureGroup(.plants)
        case .oasisPlants:
            .wealthDashboard
        case .rewards:
            .coconutShop
        case .advancedPlay:
            .gacha
        case .advancedInsights:
            .careLedgerAnalysis
        case .memoryReview:
            .familyLongTermReview
        case .mastery:
            .wealthDashboard
        }
    }

    static func primaryDestinationTitle(for step: GrowthUnlockStep, language: String) -> String {
        primaryDestinationTitle(for: step.id, language: language)
    }

    static func primaryDestinationTitle(for stageID: GrowthUnlockStageID, language: String) -> String {
        switch stageID {
        case .dailyCare:
            localized(zh: "每日照护", en: "Daily care", de: "Tägliche Pflege", language: language)
        case .bodyHealth:
            localized(zh: "健康管理", en: "Health", de: "Gesundheit", language: language)
        case .memory:
            localized(zh: "成长档案", en: "Growth archive", de: "Wachstumsarchiv", language: language)
        case .household:
            localized(zh: "植物照护", en: "Plant care", de: "Pflanzenpflege", language: language)
        case .oasisPlants:
            localized(zh: "Oasis 树收益", en: "Oasis tree income", de: "Oasis-Baum-Erträge", language: language)
        case .rewards:
            localized(zh: "椰子商店", en: "Coconut shop", de: "Kokos-Shop", language: language)
        case .advancedPlay:
            localized(zh: "扭蛋玩法", en: "Gacha play", de: "Gacha-Spiel", language: language)
        case .advancedInsights:
            localized(zh: "照护分析", en: "Care analysis", de: "Pflegeanalyse", language: language)
        case .memoryReview:
            localized(zh: "长期回顾", en: "Long-term review", de: "Langzeitrückblick", language: language)
        case .mastery:
            localized(zh: "大师树冠", en: "Master canopy", de: "Meister-Krone", language: language)
        }
    }

    static func status(for group: FeatureGroup, currentLevel: Int) -> GrowthUnlockStatus {
        status(for: stageID(for: group), currentLevel: currentLevel)
    }

    static func status(for feature: PetFeature, currentLevel: Int) -> GrowthUnlockStatus {
        status(for: stageID(for: feature), currentLevel: currentLevel)
    }

    static func status(for destination: FMDest, currentLevel: Int) -> GrowthUnlockStatus {
        status(for: stageID(for: destination), currentLevel: currentLevel)
    }

    static func availability(for group: FeatureGroup, currentLevel: Int) -> AppFeatureAvailability {
        availability(for: status(for: group, currentLevel: currentLevel))
    }

    static func availability(for feature: PetFeature, currentLevel: Int) -> AppFeatureAvailability {
        availability(for: status(for: feature, currentLevel: currentLevel))
    }

    static func availability(for destination: FMDest, currentLevel: Int) -> AppFeatureAvailability {
        if isOutOfScope(destination) { return .outOfScope }
        if destination == .growthRoadmap {
            return .visible(status(for: GrowthUnlockStageID.dailyCare, currentLevel: currentLevel))
        }
        return availability(for: status(for: destination, currentLevel: currentLevel))
    }

    static func isVisibleInApp(_ destination: FMDest, currentLevel: Int) -> Bool {
        availability(for: destination, currentLevel: currentLevel).isVisibleInApp
    }

    static func isOutOfScope(_: FMDest) -> Bool {
        false
    }

    private static func availability(for status: GrowthUnlockStatus) -> AppFeatureAvailability {
        status.isUnlocked ? .visible(status) : .hiddenLocked(status)
    }

    static func status(for stageID: GrowthUnlockStageID, currentLevel: Int) -> GrowthUnlockStatus {
        GrowthUnlockStatus(
            step: stages.first(where: { $0.id == stageID }) ?? stages[0],
            currentLevel: currentLevel
        )
    }

    static func stageID(for group: FeatureGroup) -> GrowthUnlockStageID {
        switch group {
        case .dailyCare: .dailyCare
        case .healthBody: .bodyHealth
        case .archiveMemory: .memory
        // Household Insights is a stable container whose children keep their
        // own unlock levels. Gating the container at the plant milestone would
        // also hide its Lv.1 expense surface until Lv.4.
        case .householdHub: .dailyCare
        case .plants: .household
        case .oasisRewards: .rewards
        }
    }

    static func stageID(for feature: PetFeature) -> GrowthUnlockStageID {
        switch feature {
        case .food, .potty, .basicInfo, .health, .hygiene, .weight, .medications, .walks, .documents, .expense:
            .dailyCare
        case .moments, .achievements, .retention:
            .memory
        }
    }

    static func stageID(for destination: FMDest) -> GrowthUnlockStageID {
        switch destination {
        case .growthRoadmap:
            .dailyCare
        case let .featureGroup(group):
            stageID(for: group)
        case .petFeatureCollection, .petSharedCheckIn:
            .dailyCare
        case .featureAggregate(.health), .featureAggregate(.medications):
            .bodyHealth
        case let .featureAggregate(feature):
            stageID(for: feature)
        case .petFood, .petWater, .petPotty, .petBasicInfo,
             .petHealth, .petHygiene, .petWeight, .humanWeight,
             .humanWorkout, .humanMedication, .humanNote,
             .petMedications, .petWalks, .petDocuments, .petInsurance,
             .petExpense, .humanExpense:
            .dailyCare
        case .petMoments, .petTimeline, .petAchievements, .petRetention:
            .memory
        case .bountyBoard:
            .household
        case .careLedgerAnalysis, .reminderObservability:
            .advancedInsights
        case .wealthDashboard:
            .oasisPlants
        case .plantsDashboard, .plantsBatchCare, .plantsBatchCareFiltered, .plantsBatchQuickRecord, .plantFeatureCollection, .plantsList, .plantsPhotos, .plantDetail, .plantFeature, .plantCare, .plantCareAggregate:
            .household
        case .familyWeeklyReport, .coconutShop:
            .rewards
        case .familyLongTermReview:
            .memoryReview
        case .gacha:
            .advancedPlay
        }
    }

    private static func localized(zh: String, en: String, de: String, language: String) -> String {
        L10n(language).tr(zh: zh, en: en, de: de)
    }
}
