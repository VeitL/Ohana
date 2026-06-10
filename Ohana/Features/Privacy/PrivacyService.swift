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
            .weight
        case "humanWorkout", "workout":
            .workout
        case "humanMedication", "medication":
            .medication
        case "humanNote", "note":
            .note
        case "humanWishlist", "wish", "wishlist":
            .wishlist
        case "humanExpense", "expense":
            .expense
        default:
            nil
        }
    }

    static func isLocked(_ field: HumanPrivateField, for human: Human, viewedBy viewerId: UUID?) -> Bool {
        human.isPrivate(field, viewedBy: viewerId)
    }

    static func unlockedHumans(for field: HumanPrivateField, from humans: [Human], viewedBy viewerId: UUID?) -> [Human] {
        humans.filter { !isLocked(field, for: $0, viewedBy: viewerId) }
    }

    static func publicHumans(for field: HumanPrivateField, from humans: [Human]) -> [Human] {
        humans.filter { !$0.privateFields.contains(field.rawValue) }
    }

    static func isPubliclyHidden(_ field: HumanPrivateField, for human: Human) -> Bool {
        human.privateFields.contains(field.rawValue)
    }

    static func isPubliclyHidden(_ field: HumanPrivateField, humanId: String?, in humans: [Human]) -> Bool {
        guard let humanId,
              !humanId.isEmpty,
              let human = humans.first(where: { $0.id.uuidString == humanId }) else {
            return false
        }
        return isPubliclyHidden(field, for: human)
    }

    static func isLocked(_ field: HumanPrivateField, humanId: String?, in humans: [Human], viewedBy viewerId: UUID?) -> Bool {
        guard let humanId,
              !humanId.isEmpty,
              let human = humans.first(where: { $0.id.uuidString == humanId }) else {
            return false
        }
        return isLocked(field, for: human, viewedBy: viewerId)
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
        isLocked(field, for: human, viewedBy: viewerId) ? "仅自己" : "公开"
    }

    static func lockedMessage(for field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            "体重数据仅本人可见"
        case .workout:
            "运动数据仅本人可见"
        case .medication:
            "吃药记录仅本人可见"
        case .wishlist:
            "椰子资产与愿望清单仅本人可见"
        case .expense:
            "花费记录仅本人可见"
        case .note:
            "备注仅本人可见"
        }
    }
}
