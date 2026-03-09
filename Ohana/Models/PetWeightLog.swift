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
    var pet: Pet?
    
    init(date: Date = Date(), weight: Double = 0, pet: Pet? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.pet = pet
    }
}
