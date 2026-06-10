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
        switch self {
        case .dailyCare: "每日照护"
        case .healthBody: "健康"
        case .archiveMemory: "成长档案"
        case .householdHub: "家庭事务"
        case .oasisRewards: "绿洲奖励"
        case .plants: "植物"
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
    case humanExpense(PersistentIdentifier)
    case plantsDashboard
    case plantDetail(UUID)
    case growthRoadmap
    case wealthDashboard
    case bountyBoard
    case familyWeeklyReport
    case careLedgerAnalysis
    case reminderObservability
    case coconutShop
    case gacha
    case calendar
}

enum PetFeature: String, Hashable, CaseIterable {
    case health, medications, food, hygiene, walks, potty
    case retention, basicInfo, documents, moments, achievements
    case weight, expense

    var title: String {
        switch self {
        case .health: "健康档案"
        case .medications: "用药管理"
        case .food: "饮食管理"
        case .hygiene: "清洁护理"
        case .walks: "遛狗记录"
        case .potty: "噗噗电台"
        case .retention: "成长档案"
        case .basicInfo: "基本信息"
        case .documents: "证件保障"
        case .moments: "重要时刻"
        case .achievements: "成就"
        case .weight: "体重记录"
        case .expense: "花费记录"
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
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
            size: size,
            backgroundOpacity: 0.3
        )
    }
}
