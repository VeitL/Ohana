//
//  PetMilestone.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

@Model
final class PetMilestone {
    var id: UUID
    var date: Date
    var title: String
    var emoji: String
    var notes: String
    var pet: Pet?
    // FIX 7 (ArkSchemaV17): 里程碑配图
    var photoData: Data?
    // P5: 地址文本（手动填写 或 定位后写入）
    var location: String

    init(date: Date = Date(), title: String = "", emoji: String = "🎉", notes: String = "", pet: Pet? = nil, photoData: Data? = nil, location: String = "") {
        self.id = UUID()
        self.date = date
        self.title = title
        self.emoji = emoji
        self.notes = notes
        self.pet = pet
        self.photoData = photoData
        self.location = location
    }
}
