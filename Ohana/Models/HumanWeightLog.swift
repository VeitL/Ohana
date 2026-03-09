//
//  HumanWeightLog.swift
//  Ohana
//
//  U13: 人类体重记录

import SwiftData
import Foundation

@Model
final class HumanWeightLog {
    var id: UUID
    var date: Date
    var weight: Double
    var human: Human?

    init(date: Date = Date(), weight: Double = 0, human: Human? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.human = human
    }
}
