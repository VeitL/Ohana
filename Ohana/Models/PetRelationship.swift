//
//  PetRelationship.swift
//  Ohana
//
//  宠物家庭关系模型（ArkSchemaV4 新增）
//

import SwiftData
import Foundation

// MARK: - Relationship Type

enum PetRelationshipType: String, CaseIterable, Codable {
    case parent        = "parent"
    case child         = "child"
    case sibling       = "sibling"
    case halfSibling   = "halfSibling"
    case mate          = "mate"
    case other         = "other"

    /// 根据两只宠物的性别返回适合显示的描述
    /// fromGender: 被描述宠物（关系发起方）的性别
    /// toGender:   目标宠物的性别
    func displayName(fromGender: String, toGender: String) -> String {
        switch self {
        case .parent:
            return toGender == "female" ? "妈妈" : toGender == "male" ? "爸爸" : "父/母"
        case .child:
            return toGender == "female" ? "女儿" : toGender == "male" ? "儿子" : "孩子"
        case .sibling:
            // 同父同母
            if fromGender == "male" && toGender == "female" { return "姐姐/妹妹" }
            if fromGender == "female" && toGender == "male" { return "哥哥/弟弟" }
            if toGender == "female" { return "姐妹" }
            if toGender == "male"   { return "兄弟" }
            return "兄弟姐妹"
        case .halfSibling:
            if fromGender == "male" && toGender == "female" { return "同母异父姐/妹" }
            if fromGender == "female" && toGender == "male" { return "同父异母哥/弟" }
            return "同父异母/同母异父"
        case .mate:
            return toGender == "female" ? "伴侣♀" : toGender == "male" ? "伴侣♂" : "伴侣"
        case .other:
            return "其他关系"
        }
    }

    var icon: String {
        switch self {
        case .parent:      return "person.2.fill"
        case .child:       return "figure.and.child.holdinghands"
        case .sibling:     return "person.2"
        case .halfSibling: return "person.2.slash"
        case .mate:        return "heart.fill"
        case .other:       return "pawprint.fill"
        }
    }

    /// 按性别筛选可用的关系类型
    static func available(fromGender: String) -> [PetRelationshipType] {
        // 所有关系都可用，但 displayName 会随性别自动调整
        return PetRelationshipType.allCases
    }
}

// MARK: - PetRelationship Model

@Model
final class PetRelationship {
    var id: UUID
    /// 关系发起方宠物 ID
    var fromPetId: UUID
    /// 关系目标宠物 ID
    var toPetId: UUID
    /// 关系类型 raw value
    var relationshipTypeRaw: String
    /// 备注（可选）
    var note: String
    var createdAt: Date

    var relationshipType: PetRelationshipType {
        get { PetRelationshipType(rawValue: relationshipTypeRaw) ?? .other }
        set { relationshipTypeRaw = newValue.rawValue }
    }

    init(fromPetId: UUID, toPetId: UUID, type: PetRelationshipType, note: String = "") {
        self.id = UUID()
        self.fromPetId = fromPetId
        self.toPetId = toPetId
        self.relationshipTypeRaw = type.rawValue
        self.note = note
        self.createdAt = Date()
    }
}
