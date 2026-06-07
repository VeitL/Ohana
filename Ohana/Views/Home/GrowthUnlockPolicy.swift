import Foundation

enum GrowthUnlockStageID: String, CaseIterable, Identifiable {
    case dailyCare
    case bodyHealth
    case memory
    case household
    case oasisPlants
    case rewards
    case advancedPlay

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
        case "en": return en
        case "de": return de
        default: return zh
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

enum GrowthUnlockPolicy {
    static let stages: [GrowthUnlockStep] = [
        GrowthUnlockStep(
            id: .dailyCare,
            requiredLevel: 1,
            titleZh: "照护种子",
            titleEn: "Care Seed",
            titleDe: "Pflege-Samen",
            detailZh: "先完成最重要的每日照护：成员、喂食、喝水、便便和基础日历。",
            detailEn: "Start with the essentials: members, food, water, potty, and the basic calendar.",
            detailDe: "Beginne mit dem Wichtigsten: Mitglieder, Futter, Wasser, Toilette und Kalender.",
            icon: "leaf.fill",
            tintHex: "22C55E"
        ),
        GrowthUnlockStep(
            id: .bodyHealth,
            requiredLevel: 2,
            titleZh: "健康嫩芽",
            titleEn: "Health Sprout",
            titleDe: "Gesundheits-Spross",
            detailZh: "解锁健康档案、体重和清洁护理，让记录从打卡变成管理。",
            detailEn: "Unlock health records, weight, and hygiene so check-ins become real care management.",
            detailDe: "Schalte Gesundheit, Gewicht und Hygiene frei, damit Einträge zu echter Pflege werden.",
            icon: "cross.fill",
            tintHex: "14B8A6"
        ),
        GrowthUnlockStep(
            id: .memory,
            requiredLevel: 3,
            titleZh: "成长枝条",
            titleEn: "Memory Branch",
            titleDe: "Erinnerungs-Zweig",
            detailZh: "解锁用药、遛狗、互动和成长时刻，开始记录长期变化。",
            detailEn: "Unlock medication, walks, play, and moments to track long-term growth.",
            detailDe: "Schalte Medikamente, Spaziergänge, Spiel und Momente frei.",
            icon: "sparkles.rectangle.stack.fill",
            tintHex: "F59E0B"
        ),
        GrowthUnlockStep(
            id: .household,
            requiredLevel: 4,
            titleZh: "家庭树冠",
            titleEn: "Family Canopy",
            titleDe: "Familien-Krone",
            detailZh: "解锁花费、证件、家庭事务和照护分析，管理开始覆盖全家。",
            detailEn: "Unlock expense, documents, family tasks, and care analysis for household management.",
            detailDe: "Schalte Kosten, Dokumente, Familienaufgaben und Pflegeanalyse frei.",
            icon: "house.fill",
            tintHex: "8B5CF6"
        ),
        GrowthUnlockStep(
            id: .oasisPlants,
            requiredLevel: 5,
            titleZh: "绿洲成形",
            titleEn: "Oasis Forms",
            titleDe: "Oase entsteht",
            detailZh: "解锁植物、资产概览和生命之树收益，成长开始反哺管理。",
            detailEn: "Unlock plants, wealth overview, and Life Tree income as growth feeds back into utility.",
            detailDe: "Schalte Pflanzen, Vermögen und Baum-Erträge frei.",
            icon: "tree.fill",
            tintHex: "84CC16"
        ),
        GrowthUnlockStep(
            id: .rewards,
            requiredLevel: 6,
            titleZh: "奖励果实",
            titleEn: "Reward Fruit",
            titleDe: "Belohnungs-Frucht",
            detailZh: "解锁椰子商店、家庭周报和更完整的奖励循环。",
            detailEn: "Unlock the coconut shop, weekly reports, and a fuller reward loop.",
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
        )
    ]

    static func currentStep(currentLevel: Int) -> GrowthUnlockStep {
        stages
            .last(where: { currentLevel >= $0.requiredLevel }) ?? stages[0]
    }

    static func nextLockedStep(currentLevel: Int) -> GrowthUnlockStep? {
        stages
            .first(where: { currentLevel < $0.requiredLevel })
    }

    static func newlyUnlockedStages(from previousLevel: Int, to currentLevel: Int) -> [GrowthUnlockStep] {
        guard currentLevel > previousLevel else { return [] }
        return stages.filter { step in
            step.requiredLevel > previousLevel && step.requiredLevel <= currentLevel
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

    static func status(for stageID: GrowthUnlockStageID, currentLevel: Int) -> GrowthUnlockStatus {
        GrowthUnlockStatus(
            step: stages.first(where: { $0.id == stageID }) ?? stages[0],
            currentLevel: currentLevel
        )
    }

    static func stageID(for group: FeatureGroup) -> GrowthUnlockStageID {
        switch group {
        case .dailyCare: return .dailyCare
        case .healthBody: return .bodyHealth
        case .archiveMemory: return .memory
        case .householdHub: return .household
        case .plants: return .oasisPlants
        case .oasisRewards: return .rewards
        }
    }

    static func stageID(for feature: PetFeature) -> GrowthUnlockStageID {
        switch feature {
        case .food, .potty, .basicInfo:
            return .dailyCare
        case .health, .hygiene, .weight:
            return .bodyHealth
        case .medications, .walks, .moments, .achievements, .retention:
            return .memory
        case .documents, .expense:
            return .household
        }
    }

    static func stageID(for destination: FMDest) -> GrowthUnlockStageID {
        switch destination {
        case .featureGroup(let group):
            return stageID(for: group)
        case .featureAggregate(let feature):
            return stageID(for: feature)
        case .petFood, .petPotty, .petBasicInfo, .calendar:
            return .dailyCare
        case .petHealth, .petHygiene, .petWeight, .humanWeight:
            return .bodyHealth
        case .petMedications, .petWalks, .petMoments, .petTimeline, .petAchievements, .petRetention:
            return .memory
        case .petDocuments, .petInsurance, .petExpense, .humanExpense, .bountyBoard,
             .careLedgerAnalysis, .reminderObservability:
            return .household
        case .plantsDashboard, .wealthDashboard:
            return .oasisPlants
        case .familyWeeklyReport, .coconutShop:
            return .rewards
        case .gacha:
            return .advancedPlay
        }
    }
}
