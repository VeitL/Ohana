//
//  PetWeightLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

@Model
final class PetWeightLog {
    var id: UUID
    var date: Date
    var weight: Double
    var weightUnit: String  // "kg" | "g" — ArkSchemaV23
    var bcsScore: Int       // ArkSchemaV24：BCS 体型评分 1-9，0 = 未评
    var pet: Pet?
    
    init(date: Date = Date(), weight: Double = 0, weightUnit: String = "kg", bcsScore: Int = 0, pet: Pet? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.weightUnit = weightUnit
        self.bcsScore = bcsScore
        self.pet = pet
    }

    /// 统一换算为 kg（用于图表对比）
    var weightInKg: Double {
        weightUnit == "g" ? weight / 1000.0 : weight
    }
}

// MARK: - BCS 估算（按物种/品种关键词/月龄与当前体重粗算 1–9，非临床诊断）
enum PetBodyConditionEstimator {
    static func suggestedBCS(for pet: Pet, weightKg: Double) -> Int {
        let cal = Calendar.current
        let ageMonths: Int = {
            guard let b = pet.birthday else { return 24 }
            return max(1, cal.dateComponents([.month], from: b, to: Date()).month ?? 24)
        }()
        var idealKg = 10.0
        if pet.species == "猫" {
            idealKg = 4.2
            let b = pet.breed.lowercased()
            if b.contains("缅因") || b.contains("大型") || b.contains("挪威") { idealKg = 6.8 }
            if b.contains("小型") || b.contains("暹罗") { idealKg = 3.4 }
        } else if pet.species == "狗" {
            let b = pet.breed.lowercased()
            if b.contains("大型") || b.contains("金毛") || b.contains("拉布拉多") || b.contains("德牧")
                || b.contains("阿拉斯加") || b.contains("萨摩耶") || b.contains("哈士奇") {
                idealKg = 30
            } else if b.contains("小型") || b.contains("泰迪") || b.contains("吉娃娃") || b.contains("博美")
                || b.contains("约克夏") || b.contains("马尔济斯") {
                idealKg = 5.5
            } else if b.contains("中型") || b.contains("柴犬") || b.contains("边牧") || b.contains("柯基") {
                idealKg = 14
            } else {
                idealKg = 12
            }
        }
        if ageMonths < 8 {
            idealKg *= 0.52
        } else if ageMonths < 18 {
            idealKg *= 0.85
        }
        let ratio = weightKg / max(idealKg, 0.35)
        let score: Int
        switch ratio {
        case ..<0.74: score = 2
        case ..<0.84: score = 3
        case ..<0.92: score = 4
        case ..<1.03: score = 5
        case ..<1.12: score = 6
        case ..<1.22: score = 7
        default: score = 8
        }
        return min(9, max(1, score))
    }
}
