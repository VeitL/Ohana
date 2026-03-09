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

// MARK: - Migration Plan
enum ArkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ArkSchemaV1.self, ArkSchemaV2.self, ArkSchemaV3.self, ArkSchemaV4.self,
         ArkSchemaV5.self, ArkSchemaV6.self, ArkSchemaV7.self, ArkSchemaV8.self,
         ArkSchemaV9.self, ArkSchemaV10.self, ArkSchemaV11.self, ArkSchemaV12.self,
         ArkSchemaV13.self, ArkSchemaV14.self, ArkSchemaV15.self, ArkSchemaV16.self,
         ArkSchemaV17.self, ArkSchemaV18.self, ArkSchemaV19.self, ArkSchemaV20.self]
    }

    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(fromVersion: ArkSchemaV1.self,  toVersion: ArkSchemaV2.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV2.self,  toVersion: ArkSchemaV3.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV3.self,  toVersion: ArkSchemaV4.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV4.self,  toVersion: ArkSchemaV5.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV5.self,  toVersion: ArkSchemaV6.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV6.self,  toVersion: ArkSchemaV7.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV7.self,  toVersion: ArkSchemaV8.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV8.self,  toVersion: ArkSchemaV9.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV9.self,  toVersion: ArkSchemaV10.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV10.self, toVersion: ArkSchemaV11.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV11.self, toVersion: ArkSchemaV12.self),
            MigrationStage.lightweight(fromVersion: ArkSchemaV12.self, toVersion: ArkSchemaV13.self),
            // V13 → V14: Pet 新增 passedAwayDate(nil)，lightweight 自动填充 nil
            MigrationStage.lightweight(fromVersion: ArkSchemaV13.self, toVersion: ArkSchemaV14.self),
            // V14 → V15: Human 新增 themeColorHex，自定义迁移从 notes 字段提取颜色
            MigrationStage.custom(
                fromVersion: ArkSchemaV14.self,
                toVersion: ArkSchemaV15.self,
                willMigrate: nil,
                didMigrate: { context in
                    let desc = FetchDescriptor<Human>()
                    let humans = (try? context.fetch(desc)) ?? []
                    for human in humans {
                        // 从 notes 提取 "themeColor:XXXXXX" 并写入新字段
                        if let range = human.notes.range(of: "themeColor:") {
                            let hex = String(human.notes[range.upperBound...].prefix(6))
                            if hex.count == 6 {
                                human.themeColorHex = hex
                                // 从 notes 中移除该段
                                let fullTag = "themeColor:" + hex
                                human.notes = human.notes
                                    .replacingOccurrences(of: fullTag, with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                    try? context.save()
                }
            ),
            // V15 → V16: Human 新增 privateFieldsRaw ("") + heightCm (0.0)， lightweight 自动填充默认値
            MigrationStage.lightweight(fromVersion: ArkSchemaV15.self, toVersion: ArkSchemaV16.self),
            // V16 → V17: PetMilestone 新增 photoData (nil)， lightweight 自动填充 nil
            MigrationStage.lightweight(fromVersion: ArkSchemaV16.self, toVersion: ArkSchemaV17.self),
            // V17 → V18: PetMilestone 新增 location ("")， lightweight 自动填充空字符串
            MigrationStage.lightweight(fromVersion: ArkSchemaV17.self, toVersion: ArkSchemaV18.self),
            // V18 → V19: Pet 新增 cardStyleRaw ("classic")， lightweight 自动填充
            MigrationStage.lightweight(fromVersion: ArkSchemaV18.self, toVersion: ArkSchemaV19.self),
            // V19 → V20: 新增 PetDocumentAttachment 多附件表，lightweight 自动创建
            MigrationStage.lightweight(fromVersion: ArkSchemaV19.self, toVersion: ArkSchemaV20.self),
        ]
    }
}


// MARK: - Shared Container
struct SharedModelContainer {
    static let appGroupID = "group.com.guanchen.li.Ark"

    @MainActor
    static func make() -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        let schema = Schema(ArkSchemaV20.models)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            // F3: 清除之前的数据库错误标记（如果有）
            UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
            return container
        } catch {
            // F3: 标记数据库降级为内存模式，App 层可据此弹出警告
            UserDefaults.standard.set(true, forKey: "ohana_db_fallback_active")
            UserDefaults.standard.set(error.localizedDescription, forKey: "ohana_db_fallback_error")
            #if DEBUG
            print("🚨 SwiftData container creation FAILED: \(error)")
            print("🚨 Falling back to in-memory store — ALL DATA WILL BE LOST on next launch!")
            #endif
            let fallbackConfig = ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: ArkMigrationPlan.self,
                    configurations: [fallbackConfig]
                )
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
