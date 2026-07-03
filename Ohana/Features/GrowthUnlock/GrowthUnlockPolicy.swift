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
        localized(zh: titleZh, en: titleEn, de: titleDe, language: language)
    }

    func detail(language: String) -> String {
        localized(zh: detailZh, en: detailEn, de: detailDe, language: language)
    }

    private func localized(zh: String, en: String, de: String, language: String) -> String {
        switch language {
        case "en": en
        case "de": de
        default: zh
        }
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
            detailZh: "先开放所有刚需管理：成员、基础信息、喂食、喝水、便便、健康、用药、花费、证件和基础日历。",
            detailEn: "Start with every core utility: members, basic info, food, water, potty, health, medication, expenses, documents, and the basic calendar.",
            detailDe: "Beginne mit allen Kernfunktionen: Mitglieder, Basisinfos, Futter, Wasser, Toilette, Gesundheit, Medikamente, Kosten, Dokumente und Kalender.",
            icon: "leaf.fill",
            tintHex: "22C55E"
        ),
        GrowthUnlockStep(
            id: .bodyHealth,
            requiredLevel: 2,
            titleZh: "健康嫩芽",
            titleEn: "Health Sprout",
            titleDe: "Gesundheits-Spross",
            detailZh: "强化健康概览、体重趋势和清洁护理入口，让记录开始形成可扫描的管理面板。",
            detailEn: "Add health overviews, weight trends, and hygiene surfaces so records become scannable management.",
            detailDe: "Ergänzt Gesundheitsübersicht, Gewichtstrends und Hygiene-Oberflächen.",
            icon: "cross.fill",
            tintHex: "14B8A6"
        ),
        GrowthUnlockStep(
            id: .memory,
            requiredLevel: 3,
            titleZh: "成长枝条",
            titleEn: "Memory Branch",
            titleDe: "Erinnerungs-Zweig",
            detailZh: "强化遛狗、互动、成长时刻和记忆墙，开始把长期变化沉淀成故事。",
            detailEn: "Strengthen walks, play, moments, and memory walls so long-term change becomes a story.",
            detailDe: "Stärkt Spaziergänge, Spiel, Momente und Erinnerungen.",
            icon: "sparkles.rectangle.stack.fill",
            tintHex: "F59E0B"
        ),
        GrowthUnlockStep(
            id: .household,
            requiredLevel: 4,
            titleZh: "家庭树冠",
            titleEn: "Family Canopy",
            titleDe: "Familien-Krone",
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
            titleZh: "奖励果实",
            titleEn: "Reward Fruit",
            titleDe: "Belohnungs-Frucht",
            detailZh: "解锁完整椰子商店、装饰、周报和更完整的奖励循环。",
            detailEn: "Unlock the full coconut shop, cosmetics, weekly reports, and a fuller reward loop.",
            detailDe: "Schalte Kokos-Shop, Wochenberichte und Belohnungen frei.",
            icon: "bag.fill",
            tintHex: "EAB308"
        ),
        GrowthUnlockStep(
            id: .advancedPlay,
            requiredLevel: 7,
            titleZh: "灵树玩法",
            titleEn: "Spirit Tree Play",
            titleDe: "Geistbaum-Spiel",
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
            detailZh: "解锁高级照护趋势和异常洞察，让长期数据真正辅助决策。",
            detailEn: "Unlock advanced care trends and anomaly insights so long-term data supports decisions.",
            detailDe: "Schalte Pflegetrends und Auffälligkeiten frei, damit Langzeitdaten Entscheidungen stützen.",
            icon: "chart.xyaxis.line",
            tintHex: "06B6D4"
        ),
        GrowthUnlockStep(
            id: .memoryReview,
            requiredLevel: 9,
            titleZh: "记忆年轮",
            titleEn: "Memory Rings",
            titleDe: "Erinnerungs-Ringe",
            detailZh: "强化成长回顾、记忆归档和家庭周报，沉淀长期陪伴价值。",
            detailEn: "Strengthen growth reviews, memory archives, and household reports for long-term meaning.",
            detailDe: "Stärkt Rückblicke, Erinnerungsarchive und Familienberichte.",
            icon: "book.closed.fill",
            tintHex: "EC4899"
        ),
        GrowthUnlockStep(
            id: .mastery,
            requiredLevel: 10,
            titleZh: "大师树冠",
            titleEn: "Master Canopy",
            titleDe: "Meister-Krone",
            detailZh: "解锁大师树外观、顶级被动收益和长期荣誉，不再阻塞核心管理。",
            detailEn: "Unlock master tree styling, top passive income, and long-term honors without blocking utility.",
            detailDe: "Schaltet Meisterbaum, höchste Erträge und Langzeit-Ehren frei.",
            icon: "crown.fill",
            tintHex: "00FFD1"
        )
    ]
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
            .familyWeeklyReport
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
            localized(zh: "高级洞察", en: "Advanced insights", de: "Erweiterte Einsichten", language: language)
        case .memoryReview:
            localized(zh: "成长回顾", en: "Growth review", de: "Wachstumsrückblick", language: language)
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
        case .householdHub: .household
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
        case let .featureAggregate(feature):
            stageID(for: feature)
        case .petFood, .petPotty, .petBasicInfo, .calendar,
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
        case .plantsDashboard, .plantsList, .plantsPhotos, .plantsCalendar, .plantDetail, .plantCalendar:
            .household
        case .familyWeeklyReport, .coconutShop:
            .rewards
        case .gacha:
            .advancedPlay
        }
    }

    private static func localized(zh: String, en: String, de: String, language: String) -> String {
        switch language {
        case "en": en
        case "de": de
        default: zh
        }
    }
}
