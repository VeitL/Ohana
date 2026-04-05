//
//  SharedModelContainer.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

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
            WaterLog.self,
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
            WaterLog.self,
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
            WaterLog.self,
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
            PetRelationship.self,
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
            PetRelationship.self,
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
            PetMilestone.self, WaterLog.self, PetRelationship.self,
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
            PetMilestone.self, WaterLog.self, PetRelationship.self, PetCareLog.self,
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
            HumanWeightLog.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            HumanWeightLog.self, HumanWorkoutLog.self, WishlistItem.self,
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
            PetDocumentAttachment.self,
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
            PetDocumentAttachment.self, HumanMedication.self,
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
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
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
            PetDocumentAttachment.self, HumanMedication.self, HumanHealthReport.self,
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
            PetMedication.self,
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
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
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
            PetMedication.self, PetInsurance.self, PetPhotoLog.self,
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
            PlantCareLog.self,
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
            PlantCareLog.self,
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
            PlantCareLog.self, SymptomLog.self, HeatCycleLog.self,
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
            InsuranceClaim.self,
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
            InsuranceClaim.self,
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
            InsuranceClaim.self,
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
            InsuranceClaim.self,
        ]
    }
}

// MARK: - Migration Plan
// NOTE: 只保留有真实 custom logic 的 stage。
// SwiftData 的 lightweight migration 对于"只新增字段/模型"完全不需要显式 stage——
// 当 store 版本落后于当前 schema 时，SwiftData 会自动完成字段填充。
// 明确列出 stages 反而会导致 iOS 26 抛出 "model reference cannot be equal" 异常
// （当两个相邻 schema 的 Core Data hash 相同时）。
enum ArkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ArkSchemaV1.self, ArkSchemaV2.self, ArkSchemaV3.self, ArkSchemaV4.self,
         ArkSchemaV5.self, ArkSchemaV6.self, ArkSchemaV7.self, ArkSchemaV8.self,
         ArkSchemaV9.self, ArkSchemaV10.self, ArkSchemaV11.self, ArkSchemaV12.self,
         ArkSchemaV13.self, ArkSchemaV14.self, ArkSchemaV15.self, ArkSchemaV16.self,
         ArkSchemaV17.self, ArkSchemaV18.self, ArkSchemaV19.self, ArkSchemaV20.self,
         ArkSchemaV21.self, ArkSchemaV22.self, ArkSchemaV23.self, ArkSchemaV24.self,
         ArkSchemaV25.self, ArkSchemaV26.self, ArkSchemaV27.self, ArkSchemaV28.self, ArkSchemaV29.self,
         ArkSchemaV30.self, ArkSchemaV31.self, ArkSchemaV32.self, ArkSchemaV33.self]
    }

    static var stages: [MigrationStage] { [] }
}

// MARK: - Shared Container
///
/// **为何「每次 Build 像重装、岛没了」？**
/// 1. **内存库降级**：若两次磁盘打开失败，旧逻辑会退回 `isStoredInMemoryOnly`，进程一结束 SwiftData 全丢；`ohana_has_onboarded` 等仍在 UserDefaults，表现像「又要建岛 / 数据没了」。
/// 2. **模拟器**：换了一台 Simulator、Reset Content、或删掉 App，会换沙盒路径，数据自然空。
/// 3. **重复 ModelContainer**：后台任务若再 `make()` 出新容器，可能与主进程争用同一 SQLite，行为异常；现改为**单例**。
struct SharedModelContainer {
    /// 与 `Ohana.entitlements` 中 App Group **完全一致**（旧代码误写为 `group.com.guanchen.li.Ark`）
    static let appGroupID = "group.com.guanchen.li.Ohana"

    private static let lock = NSLock()
    private static var _shared: ModelContainer?

    /// 全 App + 后台回调共用**一个**容器，对应同一套磁盘库。
    static func make() -> ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let created = createPersistentContainer()
        _shared = created
        return created
    }

    private static func createPersistentContainer() -> ModelContainer {
        let schema = Schema(ArkSchemaV33.models)
        let defaultConfig = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [defaultConfig]
            )
            UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
            #if DEBUG
            print("✅ SwiftData: 主存储已打开（含 migrationPlan）")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ SwiftData: migrationPlan 打开失败 — \(error)")
            print("⚠️ SwiftData: 尝试无迁移计划打开同一默认库…")
            #endif
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [defaultConfig]
            )
            UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
            #if DEBUG
            print("✅ SwiftData: 默认库已打开（无 migrationPlan）")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ SwiftData: 无迁移计划仍失败 — \(error)")
            #endif
        }

        // 第三层：独立命名的磁盘库（仍落 Application Support，**非内存**），避免杀进程后数据蒸发
        let diskFallback = ModelConfiguration(
            "ohana_disk_fallback",
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [diskFallback])
            UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
            #if DEBUG
            print("⚠️ SwiftData: 已使用备用磁盘库 `ohana_disk_fallback`（主 default 无法打开时）")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ SwiftData: 备用磁盘库失败 — \(error)")
            #endif
        }

        UserDefaults.standard.set(true, forKey: "ohana_db_fallback_active")
        #if DEBUG
        print("🚨 SwiftData: 磁盘全部失败，最后使用内存库（**退出 App 后数据不保留**）")
        #endif
        let memoryConfig = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            #if DEBUG
            print("🚨 SwiftData: 连内存库也创建失败 — \(error)")
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
