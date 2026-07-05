import SwiftData
import SwiftUI

// MARK: - Function Menu Navigation Models

enum FeatureGroup: String, Hashable, CaseIterable {
    case dailyCare
    case healthBody
    case archiveMemory
    case householdHub
    case oasisRewards
    case plants

    var title: String {
        title(l: L10n("zh"))
    }

    func title(l: L10n) -> String {
        switch self {
        case .dailyCare:
            l.tr(zh: "每日照护", en: "Daily Care", de: "Tägliche Pflege")
        case .healthBody:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .archiveMemory:
            l.tr(zh: "成长档案", en: "Growth Records", de: "Wachstumsakte")
        case .householdHub:
            l.tr(zh: "家庭事务", en: "Household", de: "Haushalt")
        case .oasisRewards:
            l.tr(zh: "绿洲奖励", en: "Oasis Rewards", de: "Oasis-Belohnungen")
        case .plants:
            l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }

    var icon: String {
        switch self {
        case .dailyCare: "sun.max.fill"
        case .healthBody: "cross.fill"
        case .archiveMemory: "folder.fill"
        case .householdHub: "house.fill"
        case .oasisRewards: "globe.asia.australia.fill"
        case .plants: "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .dailyCare: Color(hex: "F59E0B")
        case .healthBody: Color(hex: "EF4444")
        case .archiveMemory: Color(hex: "F59E0B")
        case .householdHub: Color.goTeal
        case .oasisRewards: Color(hex: "EAB308")
        case .plants: Color(hex: "22C55E")
        }
    }
}

enum FMDest: Hashable {
    case featureGroup(FeatureGroup)
    case featureAggregate(PetFeature)
    case petHealth(PersistentIdentifier)
    case petMedications(PersistentIdentifier)
    case petFood(PersistentIdentifier)
    case petHygiene(PersistentIdentifier)
    case petWalks(PersistentIdentifier)
    case petPotty(PersistentIdentifier)
    case petBasicInfo(PersistentIdentifier)
    case petDocuments(PersistentIdentifier)
    case petInsurance(PersistentIdentifier)
    case petMoments(PersistentIdentifier)
    case petTimeline(PersistentIdentifier)
    case petAchievements(PersistentIdentifier)
    case petRetention(PersistentIdentifier)
    case petWeight(PersistentIdentifier)
    case petExpense(PersistentIdentifier)
    case humanWeight(PersistentIdentifier)
    case humanWorkout(PersistentIdentifier)
    case humanMedication(PersistentIdentifier)
    case humanNote(PersistentIdentifier)
    case humanExpense(PersistentIdentifier)
    case plantsDashboard
    case plantsBatchCare
    case plantsBatchCareFiltered(PlantCareType)
    case plantsList
    case plantsPhotos
    case plantDetail(UUID)
    case plantFeature(UUID, PlantFeatureDestination)
    case plantCare(UUID, PlantCareFeatureDestination)
    case plantCareAggregate(PlantCareFeatureDestination)
    case growthRoadmap
    case wealthDashboard
    case bountyBoard
    case familyWeeklyReport
    case careLedgerAnalysis
    case reminderObservability
    case coconutShop
    case gacha
}

enum PlantCareFeatureDestination: String, Hashable, CaseIterable, Sendable {
    case water
    case fertilize
    case log

    var title: String {
        title(l: L10n("zh"))
    }

    func title(l: L10n) -> String {
        switch self {
        case .water:
            l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilize:
            l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .log:
            l.tr(zh: "记录", en: "Logs", de: "Notizen")
        }
    }

    func aggregateTitle(l: L10n) -> String {
        switch self {
        case .water:
            l.tr(zh: "全部浇水记录", en: "All Water Logs", de: "Alle Gießprotokolle")
        case .fertilize:
            l.tr(zh: "全部施肥记录", en: "All Fertilizer Logs", de: "Alle Düngeprotokolle")
        case .log:
            l.tr(zh: "全部植物记录", en: "All Plant Logs", de: "Alle Pflanzennotizen")
        }
    }

    var icon: String {
        switch self {
        case .water:
            "drop.fill"
        case .fertilize:
            "leaf.fill"
        case .log:
            "note.text"
        }
    }

    var primaryCareType: PlantCareType {
        switch self {
        case .water:
            .watering
        case .fertilize:
            .fertilizing
        case .log:
            .customNote
        }
    }

    var tint: Color {
        switch self {
        case .water:
            Color.goTeal
        case .fertilize:
            Color.goPrimary
        case .log:
            Color.goYellow
        }
    }

    func matches(_ careType: PlantCareType) -> Bool {
        switch self {
        case .water:
            careType == .watering || careType == .misting
        case .fertilize:
            careType == .fertilizing
        case .log:
            !Self.water.matches(careType) && !Self.fertilize.matches(careType)
        }
    }
}

enum PetFeature: String, Hashable, CaseIterable {
    case health, medications, food, hygiene, walks, potty
    case retention, basicInfo, documents, moments, achievements
    case weight, expense

    var title: String {
        title(l: L10n("zh"))
    }

    func title(l: L10n) -> String {
        switch self {
        case .health:
            l.tr(zh: "健康档案", en: "Health Records", de: "Gesundheitsakte")
        case .medications:
            l.tr(zh: "用药管理", en: "Medication", de: "Medikamente")
        case .food:
            l.tr(zh: "饮食管理", en: "Food", de: "Futter")
        case .hygiene:
            l.tr(zh: "清洁护理", en: "Hygiene", de: "Hygiene")
        case .walks:
            l.tr(zh: "遛狗记录", en: "Walks", de: "Spaziergänge")
        case .potty:
            l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio")
        case .retention:
            l.tr(zh: "成长档案", en: "Growth Records", de: "Wachstumsakte")
        case .basicInfo:
            l.tr(zh: "基本信息", en: "Basic Info", de: "Basisdaten")
        case .documents:
            l.tr(zh: "证件保障", en: "Documents", de: "Dokumente")
        case .moments:
            l.tr(zh: "重要时刻", en: "Moments", de: "Momente")
        case .achievements:
            l.tr(zh: "成就", en: "Achievements", de: "Erfolge")
        case .weight:
            l.tr(zh: "体重记录", en: "Weight", de: "Gewicht")
        case .expense:
            l.tr(zh: "花费记录", en: "Expenses", de: "Ausgaben")
        }
    }

    var icon: String {
        switch self {
        case .health: "cross.fill"
        case .medications: "pills.fill"
        case .food: "fork.knife"
        case .hygiene: "bubbles.and.sparkles.fill"
        case .walks: "figure.walk"
        case .potty: "drop.fill"
        case .retention: "sparkles.rectangle.stack.fill"
        case .basicInfo: "person.fill"
        case .documents: "doc.fill"
        case .moments: "sparkles"
        case .achievements: "trophy.fill"
        case .weight: "scalemass.fill"
        case .expense: "creditcard.fill"
        }
    }
}

struct FMPetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        PetAvatarPortraitView(
            pet: pet,
            fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
            size: size,
            backgroundOpacity: 0.3
        )
    }
}
