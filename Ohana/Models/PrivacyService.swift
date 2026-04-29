//
//  PrivacyService.swift
//  Ohana
//
//  Centralized privacy policy for local family member data.
//

import Foundation

enum PrivacyService {
    static func field(forHumanAction actionType: String) -> HumanPrivateField? {
        switch actionType {
        case "humanWeight", "weight":
            return .weight
        case "humanWorkout", "workout":
            return .workout
        case "humanMedication", "medication":
            return .medication
        case "humanNote", "note":
            return .note
        case "humanWishlist", "wish", "wishlist":
            return .wishlist
        case "humanExpense", "expense":
            return .expense
        default:
            return nil
        }
    }

    static func isLocked(_ field: HumanPrivateField, for human: Human, viewedBy viewerId: UUID?) -> Bool {
        human.isPrivate(field, viewedBy: viewerId)
    }

    static func isHumanQuickActionLocked(_ item: QuickActionItem, human: Human?, viewedBy viewerId: UUID?) -> Bool {
        guard item.entityKind == .human,
              let field = field(forHumanAction: item.actionType),
              let human else {
            return false
        }
        return isLocked(field, for: human, viewedBy: viewerId)
    }

    static func badgeText(for field: HumanPrivateField, human: Human, viewedBy viewerId: UUID?) -> String {
        human.privateFields.contains(field.rawValue) ? "仅自己" : "公开"
    }

    static func lockedMessage(for field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            return "体重数据仅本人可见"
        case .workout:
            return "运动数据仅本人可见"
        case .medication:
            return "吃药记录仅本人可见"
        case .wishlist:
            return "椰子资产与愿望清单仅本人可见"
        case .expense:
            return "花费记录仅本人可见"
        case .note:
            return "备注仅本人可见"
        }
    }
}
