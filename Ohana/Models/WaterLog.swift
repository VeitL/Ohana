//
//  WaterLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

@Model
final class WaterLog {
    var id: UUID
    var date: Date
    var amountMl: Double
    var note: String
    
    init(date: Date = Date(), amountMl: Double = 0, note: String = "") {
        self.id = UUID()
        self.date = date
        self.amountMl = amountMl
        self.note = note
    }
}
