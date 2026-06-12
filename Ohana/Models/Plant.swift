//
//  Plant.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Plant {
    var id: UUID
    var name: String
    var species: String
    var location: String
    var avatarEmoji: String
    var themeColorHex: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var wateringIntervalDays: Int
    var fertilizingIntervalDays: Int
    var lastWateredDate: Date?
    var lastFertilizedDate: Date?
    var notes: String
    var createdAt: Date
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    @Relationship(deleteRule: .cascade) var careLogs: [PlantCareLog]

    init(
        name: String = "",
        species: String = "",
        location: String = "",
        avatarEmoji: String = "🌱",
        wateringIntervalDays: Int = 7,
        fertilizingIntervalDays: Int = 30,
        themeColorHex: String = "4CAF50"
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.themeColorHex = themeColorHex
        self.avatarImageData = nil
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.lastWateredDate = nil
        self.lastFertilizedDate = nil
        self.notes = ""
        self.createdAt = Date()
        self.careLogs = []
    }

    var daysSinceWatered: Int? {
        daysSinceWatered(on: Date())
    }

    func daysSinceWatered(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let lastWateredDate else { return nil }
        return calendar.dateComponents([.day], from: lastWateredDate, to: date).day
    }

    var daysSinceFertilized: Int? {
        daysSinceFertilized(on: Date())
    }

    func daysSinceFertilized(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let lastFertilizedDate else { return nil }
        return calendar.dateComponents([.day], from: lastFertilizedDate, to: date).day
    }

    var needsWatering: Bool {
        needsWatering(on: Date())
    }

    func needsWatering(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let days = daysSinceWatered(on: date, calendar: calendar) else { return true }
        return days >= wateringIntervalDays
    }

    var needsFertilizing: Bool {
        needsFertilizing(on: Date())
    }

    func needsFertilizing(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let days = daysSinceFertilized(on: date, calendar: calendar) else { return true }
        return days >= fertilizingIntervalDays
    }
}
