//
//  SharedModelContainer.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

// MARK: - Schema V1（v4.5.0，首个版本化 Schema）
// 重命名/删除字段时：使用 .custom(fromVersion:toVersion:willMigrate:didMigrate:)

enum ArkSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self,
            Human.self,
            Plant.self,
            Household.self,
            Event.self,
            Reminder.self,
            PetPottyLog.self,
            PetWalkLog.self,
            PetHygieneLog.self,
            PetWeightLog.self,
            PetHealthLog.self,
            PetDocument.self,
            PetExpenseLog.self,
            PetFoodRecord.self,
            PetMilestone.self,
            WaterLog.self
        ]
    }
}

// MARK: - Schema V2（v4.7.0，新增 Pet.currentStreak + Pet.lastCheckInDate）
enum ArkSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self,
            Human.self,
            Plant.self,
            Household.self,
            Event.self,
            Reminder.self,
            PetPottyLog.self,
            PetWalkLog.self,
            PetHygieneLog.self,
            PetWeightLog.self,
            PetHealthLog.self,
            PetDocument.self,
            PetExpenseLog.self,
            PetFoodRecord.self,
            PetMilestone.self,
            WaterLog.self
        ]
    }
}

// MARK: - Schema V3（v4.8.0，新增 Household.totalProsperity 岛屿 EXP，只增不减）
enum ArkSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self,
            Human.self,
            Plant.self,
            Household.self,
            Event.self,
            Reminder.self,
            PetPottyLog.self,
            PetWalkLog.self,
            PetHygieneLog.self,
            PetWeightLog.self,
            PetHealthLog.self,
            PetDocument.self,
            PetExpenseLog.self,
            PetFoodRecord.self,
            PetMilestone.self,
            WaterLog.self
        ]
    }
}

// MARK: - Schema V4（v4.9.0，新增 PetRelationship 宠物家庭关系）
// （此 enum 保持不变，由 V5 继续继承）
enum ArkSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self,
            Human.self,
            Plant.self,
            Household.self,
            Event.self,
            Reminder.self,
            PetPottyLog.self,
            PetWalkLog.self,
            PetHygieneLog.self,
            PetWeightLog.self,
            PetHealthLog.self,
            PetDocument.self,
            PetExpenseLog.self,
            PetFoodRecord.self,
            PetMilestone.self,
            WaterLog.self,
            PetRelationship.self
        ]
    }
}

// MARK: - Schema V5（v5.0.0，PetHealthLog 新增 expirationDate 可选字段）
enum ArkSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self,
            Human.self,
            Plant.self,
            Household.self,
            Event.self,
            Reminder.self,
            PetPottyLog.self,
            PetWalkLog.self,
            PetHygieneLog.self,
            PetWeightLog.self,
            PetHealthLog.self,
            PetDocument.self,
            PetExpenseLog.self,
            PetFoodRecord.self,
            PetMilestone.self,
            WaterLog.self,
            PetRelationship.self
        ]
    }
}

// MARK: - Schema V6（v5.1.0，PetDocument 新增 cost/attachmentData/attachmentFilename）
enum ArkSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self
        ]
    }
}

// MARK: - Schema V7（v5.2.0，新增 PetCareLog 喂食/喂水/铲屎追踪）
enum ArkSchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self
        ]
    }
}

// MARK: - Schema V8（v5.6.0，U13: 新增 HumanWeightLog + Human.nationality/city）
enum ArkSchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self
        ]
    }
}

// MARK: - Schema V9（v5.7.0，U14: 新增 HumanWorkoutLog）
enum ArkSchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self
        ]
    }
}

// MARK: - Schema V10（v6.8.0, Pet 新增 foodTrackingModeRaw/casualOpenDate/casualDurationDays 双轨制粮食追踪）
enum ArkSchemaV10: VersionedSchema {
    static var versionIdentifier = Schema.Version(10, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self
        ]
    }
}

// MARK: - Schema V11（v7.0.0, Pet/Human 新增 coconutBalance; 所有 Log 新增 executorId 家庭协作游戏）
enum ArkSchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self
        ]
    }
}

// MARK: - Schema V12（v8.5.0, 新增 WishlistItem; Event 新增 assigneeId）
enum ArkSchemaV12: VersionedSchema {
    static var versionIdentifier = Schema.Version(12, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V13（v9.0.0, Human 新增 shouldShowOnHome）
enum ArkSchemaV13: VersionedSchema {
    static var versionIdentifier = Schema.Version(13, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V14（v9.1.0, Pet 新增 passedAwayDate — Rainbow Bridge 生命周期）
enum ArkSchemaV14: VersionedSchema {
    static var versionIdentifier = Schema.Version(14, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V15（Human 新增 themeColorHex 正式字段，迁移自 notes 颜色 hack）
enum ArkSchemaV15: VersionedSchema {
    static var versionIdentifier = Schema.Version(15, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V16（Human 新增 privateFieldsRaw + heightCm — FIX 1 隐私控制 + 身体数据）
enum ArkSchemaV16: VersionedSchema {
    static var versionIdentifier = Schema.Version(16, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V17（PetMilestone 新增 photoData — FIX 7 里程碑配图）
enum ArkSchemaV17: VersionedSchema {
    static var versionIdentifier = Schema.Version(17, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V18（P5: PetMilestone 新增 location 字段）
enum ArkSchemaV18: VersionedSchema {
    static var versionIdentifier = Schema.Version(18, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V19（P2: Pet 新增 cardStyleRaw 字段）
enum ArkSchemaV19: VersionedSchema {
    static var versionIdentifier = Schema.Version(19, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self
        ]
    }
}

// MARK: - Schema V20（新增 PetDocumentAttachment — 多附件支持）
enum ArkSchemaV20: VersionedSchema {
    static var versionIdentifier = Schema.Version(20, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self
        ]
    }
}

// MARK: - Schema V21（新增 HumanMedication — 人类吃药提醒）
enum ArkSchemaV21: VersionedSchema {
    static var versionIdentifier = Schema.Version(21, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self
        ]
    }
}

// MARK: - Schema V22（新增 HumanHealthReport — 身体检测报告）
enum ArkSchemaV22: VersionedSchema {
    static var versionIdentifier = Schema.Version(22, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self
        ]
    }
}

// MARK: - Schema V23（PetWeightLog.weightUnit + Pet.weeklyWalkGoalKm）
enum ArkSchemaV23: VersionedSchema {
    static var versionIdentifier = Schema.Version(23, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self
        ]
    }
}

// MARK: - Schema V24（PetMedication 新模型 + Pet vet 结构化字段 + PetWeightLog.bcsScore）
enum ArkSchemaV24: VersionedSchema {
    static var versionIdentifier = Schema.Version(24, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self
        ]
    }
}

// MARK: - Schema V25（PetInsurance + PetPhotoLog 新模型）
enum ArkSchemaV25: VersionedSchema {
    static var versionIdentifier = Schema.Version(25, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self
        ]
    }
}

// MARK: - Schema V26（Pet.personalityTagsRaw 性格标签）
enum ArkSchemaV26: VersionedSchema {
    static var versionIdentifier = Schema.Version(26, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self
        ]
    }
}

// MARK: - Schema V27（Plant 新增 themeColorHex/avatarImageData/careLogs; 新增 PlantCareLog 模型）
enum ArkSchemaV27: VersionedSchema {
    static var versionIdentifier = Schema.Version(27, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self
        ]
    }
}

// MARK: - Schema V28（PetPhotoLog 地理位置字段）
enum ArkSchemaV28: VersionedSchema {
    static var versionIdentifier = Schema.Version(28, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self
        ]
    }
}

// MARK: - Schema V29（SymptomLog, HeatCycleLog 异常症状与生理期支持）
enum ArkSchemaV29: VersionedSchema {
    static var versionIdentifier = Schema.Version(29, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self
        ]
    }
}

// MARK: - Schema V30（InsuranceClaim 报销记录 + PetInsurance.paymentFrequency）
enum ArkSchemaV30: VersionedSchema {
    static var versionIdentifier = Schema.Version(30, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self
        ]
    }
}

// MARK: - Schema V31（PetInsurance 新增 paymentDayOfMonth/showInCalendar/otherFeeAmount/otherFeeNote；Event 新增 insurancePremium 类型）
enum ArkSchemaV31: VersionedSchema {
    static var versionIdentifier = Schema.Version(31, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self
        ]
    }
}

// MARK: - Schema V32（PetInsurance 新增 firstPremiumPaymentDate）
enum ArkSchemaV32: VersionedSchema {
    static var versionIdentifier = Schema.Version(32, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self
        ]
    }
}

// MARK: - Schema V33（PetWalkLog 新增 behaviorNotes/moodRating）
enum ArkSchemaV33: VersionedSchema {
    static var versionIdentifier = Schema.Version(33, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self
        ]
    }
}

// MARK: - Schema V34（新增 HumanMedicationLog，人类吃药打卡记录）
enum ArkSchemaV34: VersionedSchema {
    static var versionIdentifier = Schema.Version(34, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self, HumanMedicationLog.self
        ]
    }
}

// MARK: - Schema V35（Human 新增 mbti）
enum ArkSchemaV35: VersionedSchema {
    static var versionIdentifier = Schema.Version(35, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Pet.self, Human.self, Plant.self, Household.self, Event.self, Reminder.self,
            PetPottyLog.self, PetWalkLog.self, PetHygieneLog.self, PetWeightLog.self,
            PetHealthLog.self, PetDocument.self, PetExpenseLog.self, PetFoodRecord.self,
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
            InsuranceClaim.self, HumanMedicationLog.self
        ]
    }
}

// MARK: - Schema V36（Pet 新增粮仓断粮提醒偏好）
enum ArkSchemaV36: VersionedSchema {
    static var versionIdentifier = Schema.Version(36, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV35.models
    }
}

// MARK: - Schema V37（新增统一照护事件账本 CareLedgerEvent）
enum ArkSchemaV37: VersionedSchema {
    static var versionIdentifier = Schema.Version(37, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV36.models + [CareLedgerEvent.self]
    }
}

// MARK: - Schema V38（体重/健康/护理记录新增 executorId）
enum ArkSchemaV38: VersionedSchema {
    static var versionIdentifier = Schema.Version(38, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV37.models
    }
}

// MARK: - Schema V39（喂食干湿粮、零食类型与逐餐计划字段）
enum ArkSchemaV39: VersionedSchema {
    static var versionIdentifier = Schema.Version(39, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV38.models
    }
}

// MARK: - Schema V40（Human 本地账户 PIN 字段）
enum ArkSchemaV40: VersionedSchema {
    static var versionIdentifier = Schema.Version(40, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV39.models
    }
}

// MARK: - Schema V41（Pet 当前主粮类型）
enum ArkSchemaV41: VersionedSchema {
    static var versionIdentifier = Schema.Version(41, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV40.models
    }
}

// MARK: - Schema V42（余粮购买日期、开袋日期与余量修正）
enum ArkSchemaV42: VersionedSchema {
    static var versionIdentifier = Schema.Version(42, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV41.models
    }
}

// MARK: - Schema V43（Human 新增离世纪念模式日期）
enum ArkSchemaV43: VersionedSchema {
    static var versionIdentifier = Schema.Version(43, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV42.models
    }
}

// MARK: - Schema V44（预留：人类/宠物纪念模式后续轻量字段）
enum ArkSchemaV44: VersionedSchema {
    static var versionIdentifier = Schema.Version(44, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV43.models
    }
}

// MARK: - Schema V45（统一家庭协作任务）
enum ArkSchemaV45: VersionedSchema {
    static var versionIdentifier = Schema.Version(45, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV44.models + [FamilyCollaborationTask.self]
    }
}

// MARK: - Schema V46（椰子货币兑换记录）
enum ArkSchemaV46: VersionedSchema {
    static var versionIdentifier = Schema.Version(46, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV45.models + [CoconutExchangeRequest.self]
    }
}

// MARK: - Schema V47（Oasis 升级椰子 + 电子宠物）
enum ArkSchemaV47: VersionedSchema {
    static var versionIdentifier = Schema.Version(47, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV46.models + [
            OasisUpgradeCoconut.self,
            OasisElectronicPet.self,
            OasisCritterFragmentBalance.self,
            OasisUnlock.self
        ]
    }
}

// MARK: - Schema V48（Oasis 电子宠物互动日志 + 展示扩展）
enum ArkSchemaV48: VersionedSchema {
    static var versionIdentifier = Schema.Version(48, 0, 0)

    static var models: [any PersistentModel.Type] {
        ArkSchemaV47.models + [OasisCritterActionLog.self]
    }
}

// MARK: - Schema V49（Oasis 电子宠物长期养成扩展字段）
enum ArkSchemaV49: VersionedSchema {
    static var versionIdentifier = Schema.Version(49, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV48.models }
}

// MARK: - Schema V50（遛狗便便位置标记）
enum ArkSchemaV50: VersionedSchema {
    static var versionIdentifier = Schema.Version(50, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV49.models }
}

// MARK: - Schema V51（3D 破框卡片专用素材）
enum ArkSchemaV51: VersionedSchema {
    static var versionIdentifier = Schema.Version(51, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV50.models }
}

// MARK: - Schema V52（同物种多宠共同照护记录）
enum ArkSchemaV52: VersionedSchema {
    static var versionIdentifier = Schema.Version(52, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV51.models + [SharedCareSession.self] }
}

// MARK: - Schema V53（系列盲盒扭蛋收藏与抽取记录）
enum ArkSchemaV53: VersionedSchema {
    static var versionIdentifier = Schema.Version(53, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV52.models + [GachaOwnedItem.self, GachaDrawLog.self] }
}

// MARK: - Schema V54（扭蛋非收藏结果与即时奖励记录）
enum ArkSchemaV54: VersionedSchema {
    static var versionIdentifier = Schema.Version(54, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV53.models }
}

// MARK: - Schema V55（Oasis 电子宠物低压力生命状态）
enum ArkSchemaV55: VersionedSchema {
    static var versionIdentifier = Schema.Version(55, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV54.models }
}

// MARK: - Schema V56（人类体检指标追踪 HumanHealthMetricLog）
enum ArkSchemaV56: VersionedSchema {
    static var versionIdentifier = Schema.Version(56, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV55.models + [HumanHealthMetricLog.self] }
}

// MARK: - Schema V57（同物种共享事实扩展）
enum ArkSchemaV57: VersionedSchema {
    static var versionIdentifier = Schema.Version(57, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV56.models }
}

// MARK: - Schema V58（椰子钱包账户与不可变流水）
enum ArkSchemaV58: VersionedSchema {
    static var versionIdentifier = Schema.Version(58, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV57.models + [CoconutAccount.self, CoconutLedgerEntry.self] }
}

// MARK: - Schema V59（椰子经济每日预算用量事件）
enum ArkSchemaV59: VersionedSchema {
    static var versionIdentifier = Schema.Version(59, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV58.models + [EconomyBudgetUsageEvent.self] }
}

// MARK: - Schema V60（宠物用药计划持久化余量）
enum ArkSchemaV60: VersionedSchema {
    static var versionIdentifier = Schema.Version(60, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV59.models }
}

// MARK: - Schema V61（人类性别/身份迁出 notes 元数据）
enum ArkSchemaV61: VersionedSchema {
    static var versionIdentifier = Schema.Version(61, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV60.models }
}

// MARK: - Schema V62（宠物粮仓元数据结构化）
enum ArkSchemaV62: VersionedSchema {
    static var versionIdentifier = Schema.Version(62, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV61.models }
}

// MARK: - Schema V63（自动喂食去重键结构化）
enum ArkSchemaV63: VersionedSchema {
    static var versionIdentifier = Schema.Version(63, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV62.models }
}

// MARK: - Schema V64（CloudKit 同步元数据与 tombstone 状态）
enum ArkSchemaV64: VersionedSchema {
    static var versionIdentifier = Schema.Version(64, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV63.models + [CloudSyncRecordState.self] }
}

// MARK: - Schema V65（共享喂食计划组标识）
enum ArkSchemaV65: VersionedSchema {
    static var versionIdentifier = Schema.Version(65, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV64.models }
}

// MARK: - Schema V66（CloudSync tombstone 持久化标记）
enum ArkSchemaV66: VersionedSchema {
    static var versionIdentifier = Schema.Version(66, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV65.models }
}

// MARK: - Schema V67（共同遛狗多人执行者列表）
enum ArkSchemaV67: VersionedSchema {
    static var versionIdentifier = Schema.Version(67, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV66.models }
}

// MARK: - Schema V68（CloudSync tombstone 默认值）
enum ArkSchemaV68: VersionedSchema {
    static var versionIdentifier = Schema.Version(68, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV67.models }
}

// MARK: - Schema V69（legacy 回收站软删除字段，保留以打开既有 store）
enum ArkSchemaV69: VersionedSchema {
    static var versionIdentifier = Schema.Version(69, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV68.models + [RecycleBinBatch.self] }
}

// MARK: - Schema V70（legacy 症状与发情记录回收站字段，保留以打开既有 store）
enum ArkSchemaV70: VersionedSchema {
    static var versionIdentifier = Schema.Version(70, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV69.models }
}

// MARK: - Schema V71（商店购买所有权记录）
enum ArkSchemaV71: VersionedSchema {
    static var versionIdentifier = Schema.Version(71, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV70.models + [ShopPurchaseRecord.self] }
}

// MARK: - Schema V72（共享清洁记录会话关联）
enum ArkSchemaV72: VersionedSchema {
    static var versionIdentifier = Schema.Version(72, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV71.models }
}

// MARK: - Schema V73（植物首发档案字段与护理日志扩展）
enum ArkSchemaV73: VersionedSchema {
    static var versionIdentifier = Schema.Version(73, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV72.models }
}

// MARK: - Schema V74（植物环境档案轻量字段）
enum ArkSchemaV74: VersionedSchema {
    static var versionIdentifier = Schema.Version(74, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV73.models }
}

// MARK: - Schema V75（植物护理日志照片轻量索引）
enum ArkSchemaV75: VersionedSchema {
    static var versionIdentifier = Schema.Version(75, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV74.models }
}

// MARK: - Schema V76（植物头像轻量索引）
enum ArkSchemaV76: VersionedSchema {
    static var versionIdentifier = Schema.Version(76, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV75.models }
}

// MARK: - Schema V77（成员头像与宠物破框图轻量索引）
enum ArkSchemaV77: VersionedSchema {
    static var versionIdentifier = Schema.Version(77, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV76.models }
}

// MARK: - Schema V78（植物护理日志照片签名轻量索引）
enum ArkSchemaV78: VersionedSchema {
    static var versionIdentifier = Schema.Version(78, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV77.models }
}

// MARK: - Schema V79（宠物相册照片轻量索引）
enum ArkSchemaV79: VersionedSchema {
    static var versionIdentifier = Schema.Version(79, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV78.models }
}

// MARK: - Schema V80（宠物证件附件轻量索引）
enum ArkSchemaV80: VersionedSchema {
    static var versionIdentifier = Schema.Version(80, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV79.models }
}

// MARK: - Schema V81（宠物头像透明度轻量索引）
enum ArkSchemaV81: VersionedSchema {
    static var versionIdentifier = Schema.Version(81, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV80.models }
}

// MARK: - Schema V82（宠物里程碑照片轻量索引）
enum ArkSchemaV82: VersionedSchema {
    static var versionIdentifier = Schema.Version(82, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV81.models }
}

// MARK: - Schema V83（Human Workout HealthKit 来源元数据）
enum ArkSchemaV83: VersionedSchema {
    static var versionIdentifier = Schema.Version(83, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV82.models }
}

// MARK: - Schema V84（Human Workout 关联遛狗记录来源）
enum ArkSchemaV84: VersionedSchema {
    static var versionIdentifier = Schema.Version(84, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV83.models }
}

// MARK: - Schema V85（Plant 非破坏性归档生命周期）
enum ArkSchemaV85: VersionedSchema {
    static var versionIdentifier = Schema.Version(85, 0, 0)
    static var models: [any PersistentModel.Type] { ArkSchemaV84.models }
}

// MARK: - Migration Plan
// 只保留有真实 custom logic 的 stage；轻量新增字段/模型不需要显式 stage。
// 相邻 schema hash 相同时，显式 stage 会触发 iOS 26 "model reference cannot be equal"。
enum ArkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ArkSchemaV1.self, ArkSchemaV2.self, ArkSchemaV3.self, ArkSchemaV4.self,
         ArkSchemaV5.self, ArkSchemaV6.self, ArkSchemaV7.self, ArkSchemaV8.self,
         ArkSchemaV9.self, ArkSchemaV10.self, ArkSchemaV11.self, ArkSchemaV12.self,
         ArkSchemaV13.self, ArkSchemaV14.self, ArkSchemaV15.self, ArkSchemaV16.self,
         ArkSchemaV17.self, ArkSchemaV18.self, ArkSchemaV19.self, ArkSchemaV20.self,
         ArkSchemaV21.self, ArkSchemaV22.self, ArkSchemaV23.self, ArkSchemaV24.self,
         ArkSchemaV25.self, ArkSchemaV26.self, ArkSchemaV27.self, ArkSchemaV28.self, ArkSchemaV29.self,
         ArkSchemaV30.self, ArkSchemaV31.self, ArkSchemaV32.self, ArkSchemaV33.self, ArkSchemaV34.self,
         ArkSchemaV35.self, ArkSchemaV36.self, ArkSchemaV37.self, ArkSchemaV38.self, ArkSchemaV39.self,
         ArkSchemaV40.self, ArkSchemaV41.self, ArkSchemaV42.self, ArkSchemaV43.self, ArkSchemaV44.self,
         ArkSchemaV45.self, ArkSchemaV46.self, ArkSchemaV47.self, ArkSchemaV48.self, ArkSchemaV49.self,
         ArkSchemaV50.self, ArkSchemaV51.self, ArkSchemaV52.self, ArkSchemaV53.self, ArkSchemaV54.self,
         ArkSchemaV55.self, ArkSchemaV56.self, ArkSchemaV57.self, ArkSchemaV58.self, ArkSchemaV59.self,
         ArkSchemaV60.self, ArkSchemaV61.self, ArkSchemaV62.self, ArkSchemaV63.self, ArkSchemaV64.self,
         ArkSchemaV65.self, ArkSchemaV66.self, ArkSchemaV67.self, ArkSchemaV68.self, ArkSchemaV69.self,
         ArkSchemaV70.self, ArkSchemaV71.self, ArkSchemaV72.self, ArkSchemaV73.self, ArkSchemaV74.self,
         ArkSchemaV75.self, ArkSchemaV76.self, ArkSchemaV77.self, ArkSchemaV78.self, ArkSchemaV79.self,
         ArkSchemaV80.self, ArkSchemaV81.self, ArkSchemaV82.self, ArkSchemaV83.self, ArkSchemaV84.self,
         ArkSchemaV85.self]
    }

    static var stages: [MigrationStage] { [] }
}

// MARK: - Shared Container
enum SharedModelContainerStoreIdentity: String, Hashable, Sendable {
    case primary
}

enum SharedModelContainerStoreKind: String, CaseIterable, Equatable, Sendable {
    case primaryWithMigrationPlan
    case primaryWithoutMigrationPlan

    var identity: SharedModelContainerStoreIdentity {
        .primary
    }
}

struct SharedModelContainerOpenFailure: Error, Equatable, Sendable {
    let attemptedStoreKinds: [SharedModelContainerStoreKind]
}

enum SharedModelContainerOpenPolicy {
    static let orderedAttempts: [SharedModelContainerStoreKind] = [
        .primaryWithMigrationPlan,
        .primaryWithoutMigrationPlan
    ]

    static let writableStoreIdentities = Set(orderedAttempts.map(\.identity))

    static func open<Value>(
        using opener: (SharedModelContainerStoreKind) throws -> Value
    ) throws -> Value {
        var attemptedStoreKinds: [SharedModelContainerStoreKind] = []

        for storeKind in orderedAttempts {
            do {
                return try opener(storeKind)
            } catch {
                attemptedStoreKinds.append(storeKind)
            }
        }

        throw SharedModelContainerOpenFailure(attemptedStoreKinds: attemptedStoreKinds)
    }
}

enum SharedModelContainer {
    private static let lock = NSLock()
    private static var _shared: ModelContainer?

    /// 全 App + 后台回调共用**一个**容器，对应同一套磁盘库。
    static func make() throws -> ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let created = try createPersistentContainer()
        _shared = created
        return created
    }

    static func makePreview() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func createPersistentContainer() throws -> ModelContainer {
        ensureApplicationSupportDirectory()
        let schema = Schema(ArkSchemaV85.models)
        let primaryConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try SharedModelContainerOpenPolicy.open { storeKind in
                switch storeKind {
                case .primaryWithMigrationPlan:
                    do {
                        let container = try ModelContainer(
                            for: schema,
                            migrationPlan: ArkMigrationPlan.self,
                            configurations: [primaryConfiguration]
                        )
                        #if DEBUG
                            OhanaLog.info(
                                "SwiftData: primary store opened with migrationPlan",
                                category: "SwiftData"
                            )
                        #endif
                        return container
                    } catch {
                        #if DEBUG
                            OhanaLog.warning(
                                "SwiftData: migrationPlan open failed - \(error)",
                                category: "SwiftData"
                            )
                            OhanaLog.warning(
                                "SwiftData: retrying the same primary store without migrationPlan",
                                category: "SwiftData"
                            )
                        #endif
                        throw error
                    }
                case .primaryWithoutMigrationPlan:
                    do {
                        let container = try ModelContainer(
                            for: schema,
                            configurations: [primaryConfiguration]
                        )
                        #if DEBUG
                            OhanaLog.info(
                                "SwiftData: same primary store opened without migrationPlan",
                                category: "SwiftData"
                            )
                        #endif
                        return container
                    } catch {
                        #if DEBUG
                            OhanaLog.warning(
                                "SwiftData: same primary store without migrationPlan failed - \(error)",
                                category: "SwiftData"
                            )
                        #endif
                        throw error
                    }
                }
            }
        } catch {
            OhanaLog.error(
                "SwiftData: primary store unavailable; stopped before creating an alternate writable store",
                category: "SwiftData"
            )
            throw error
        }
    }

    private static func ensureApplicationSupportDirectory() {
        do {
            try LocalBackupExclusionPolicy.prepareApplicationSupportDirectory()
        } catch {
            OhanaLog.error(
                "SwiftData: Application Support backup exclusion failed - \(error.localizedDescription)",
                category: "Privacy"
            )
        }
    }
}
