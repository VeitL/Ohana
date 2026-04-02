//
//  HeatCycleLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

// MARK: - Heat Cycle Status
enum HeatCycleStatus: String, Codable, CaseIterable {
    case proestrus = "发情前期"   // 准备期，可能见红
    case estrus = "发情期"       // 接受交配期
    case diestrus = "发情后期"    // 拒绝交配，可能假孕
    case anestrus = "休情期"     // 平静期
    case pregnant = "孕期"       // 已确认怀孕
    case nursing = "哺乳期"       // 产后
    
    var colorHex: String {
        switch self {
        case .proestrus: return "FF8C42" // Orange
        case .estrus: return "FF4757"    // Red
        case .diestrus: return "A78BFA"  // Purple
        case .anestrus: return "00D4AA"  // Teal
        case .pregnant: return "FF6B9D"  // Pink
        case .nursing: return "FFDD44"   // Yellow
        }
    }
}

@Model
final class HeatCycleLog {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var statusRaw: String
    var note: String
    var isMated: Bool
    var expectedDeliveryDate: Date? // 如果确认交配/怀孕，记录预期产期
    
    var pet: Pet?
    
    init(startDate: Date = Date(), endDate: Date? = nil, status: HeatCycleStatus = .proestrus, note: String = "", isMated: Bool = false, expectedDeliveryDate: Date? = nil, pet: Pet? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.statusRaw = status.rawValue
        self.note = note
        self.isMated = isMated
        self.expectedDeliveryDate = expectedDeliveryDate
        self.pet = pet
    }
    
    var status: HeatCycleStatus {
        HeatCycleStatus(rawValue: statusRaw) ?? .proestrus
    }
}
