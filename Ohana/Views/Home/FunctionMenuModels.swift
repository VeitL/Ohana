import SwiftUI
import SwiftData

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
        case .dailyCare:     return "每日照护"
        case .healthBody:    return "健康"
        case .archiveMemory: return "成长档案"
        case .householdHub:  return "家庭事务"
        case .oasisRewards:  return "绿洲奖励"
        case .plants:        return "植物"
        }
    }

    var icon: String {
        switch self {
        case .dailyCare:     return "sun.max.fill"
        case .healthBody:    return "cross.fill"
        case .archiveMemory: return "folder.fill"
        case .householdHub:  return "house.fill"
        case .oasisRewards:  return "globe.asia.australia.fill"
        case .plants:        return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .dailyCare:     return Color(hex: "F59E0B")
        case .healthBody:    return Color(hex: "EF4444")
        case .archiveMemory: return Color(hex: "F59E0B")
        case .householdHub:  return Color.goTeal
        case .oasisRewards:  return Color(hex: "EAB308")
        case .plants:        return Color(hex: "22C55E")
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
        case .health:        return "健康档案"
        case .medications:   return "用药管理"
        case .food:          return "饮食管理"
        case .hygiene:       return "清洁护理"
        case .walks:         return "遛狗记录"
        case .potty:         return "噗噗电台"
        case .retention:     return "成长档案"
        case .basicInfo:     return "基本信息"
        case .documents:     return "证件保障"
        case .moments:       return "重要时刻"
        case .achievements:  return "成就"
        case .weight:        return "体重记录"
        case .expense:       return "花费记录"
        }
    }

    var icon: String {
        switch self {
        case .health:        return "cross.fill"
        case .medications:   return "pills.fill"
        case .food:          return "fork.knife"
        case .hygiene:       return "bubbles.and.sparkles.fill"
        case .walks:         return "figure.walk"
        case .potty:         return "drop.fill"
        case .retention:     return "sparkles.rectangle.stack.fill"
        case .basicInfo:     return "person.fill"
        case .documents:     return "doc.fill"
        case .moments:       return "sparkles"
        case .achievements:  return "trophy.fill"
        case .weight:        return "scalemass.fill"
        case .expense:       return "creditcard.fill"
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
