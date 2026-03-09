//
//  PetHygieneLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum HygieneType: String, Codable, CaseIterable {
    case teeth = "刷牙"
    case nails = "剪甲"
    case ears = "清耳"
    case brushing = "梳毛"
    case bath = "洗澡"
    
    var emoji: String {
        switch self {
        case .teeth: return "🦷"
        case .nails: return "✂️"
        case .ears: return "👂"
        case .brushing: return "🪮"
        case .bath: return "🛁"
        }
    }
    
    var cycleDays: Int {
        switch self {
        case .teeth: return 1
        case .nails: return 14
        case .ears: return 7
        case .brushing: return 3
        case .bath: return 14
        }
    }
}

@Model
final class PetHygieneLog {
    #Index<PetHygieneLog>([\.date])
    var id: UUID
    var date: Date
    var type: String
    var pet: Pet?
    
    init(date: Date = Date(), type: HygieneType = .bath, pet: Pet? = nil) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.pet = pet
    }
    
    var hygieneType: HygieneType {
        HygieneType(rawValue: type) ?? .bath
    }
}
