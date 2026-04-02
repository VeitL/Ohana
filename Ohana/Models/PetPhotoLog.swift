//
//  PetPhotoLog.swift
//  Ohana
//
//  ArkSchemaV25：宠物照片相册模型
//

import SwiftData
import Foundation

@Model
final class PetPhotoLog {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data    // 原图（externalStorage 防止 db 膨胀）
    var date: Date
    var note: String        // 可选备注（最多 140 字）
    var createdAt: Date
    /// 记录位置（0,0 表示未记录）
    var locationLatitude: Double
    var locationLongitude: Double
    var locationPlacename: String

    @Relationship(inverse: \Pet.photoLogs) var pet: Pet?

    init(
        imageData: Data,
        date: Date = Date(),
        note: String = "",
        pet: Pet? = nil,
        locationLatitude: Double = 0,
        locationLongitude: Double = 0,
        locationPlacename: String = ""
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.date = date
        self.note = note
        self.createdAt = Date()
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationPlacename = locationPlacename
        self.pet = pet
    }
}
