//
//  Plant.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

@Model
final class Plant {
    var id: UUID
    var name: String
    var species: String
    var location: String
    var avatarEmoji: String
    var wateringIntervalDays: Int
    var fertilizingIntervalDays: Int
    var lastWateredDate: Date?
    var lastFertilizedDate: Date?
    var notes: String
    var createdAt: Date
    
    init(
        name: String = "",
        species: String = "",
        location: String = "",
        avatarEmoji: String = "🌱",
        wateringIntervalDays: Int = 7,
        fertilizingIntervalDays: Int = 30
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.lastWateredDate = nil
        self.lastFertilizedDate = nil
        self.notes = ""
        self.createdAt = Date()
    }
    
    var daysSinceWatered: Int? {
        guard let lastWateredDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastWateredDate, to: Date()).day
    }
    
    var daysSinceFertilized: Int? {
        guard let lastFertilizedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastFertilizedDate, to: Date()).day
    }
    
    var needsWatering: Bool {
        guard let days = daysSinceWatered else { return true }
        return days >= wateringIntervalDays
    }
    
    var needsFertilizing: Bool {
        guard let days = daysSinceFertilized else { return true }
        return days >= fertilizingIntervalDays
    }
}
