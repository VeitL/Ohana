//
//  PetPhotoLog.swift
//  Ohana
//
//  ArkSchemaV25：宠物照片相册模型
//

import Foundation
import SwiftData

enum PetPhotoAttachmentState: String, Codable, Sendable {
    case unknown
    case absent
    case present
}

@Model
final class PetPhotoLog {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data // Persisted photo payload; command writers sanitize and downsample new user imports.
    var imageAttachmentStateRaw: String = PetPhotoAttachmentState.unknown.rawValue
    var imageSignature: String = ""
    var date: Date
    var note: String // 可选备注（最多 140 字）
    var createdAt: Date
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""
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
        let hasRenderableImage = Self.hasRenderableImagePayload(imageData)
        self.imageAttachmentStateRaw = hasRenderableImage ? PetPhotoAttachmentState.present.rawValue : PetPhotoAttachmentState.absent.rawValue
        self.imageSignature = hasRenderableImage ? MediaPayloadSignature.signature(for: imageData) : ""
        self.date = date
        self.note = note
        self.createdAt = Date()
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationPlacename = locationPlacename
        self.pet = pet
    }

    var imageAttachmentState: PetPhotoAttachmentState {
        get { PetPhotoAttachmentState(rawValue: imageAttachmentStateRaw) ?? .unknown }
        set { imageAttachmentStateRaw = newValue.rawValue }
    }

    var hasImageAttachment: Bool {
        canAttemptImageAttachmentLoad
    }

    var canAttemptImageAttachmentLoad: Bool {
        imageAttachmentState != .absent
    }

    var imageThumbnailSignature: String {
        if !imageSignature.isEmpty {
            return imageSignature
        }
        guard canAttemptImageAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):\(createdAt.timeIntervalSince1970)"
    }

    var needsImageAttachmentIndexRepair: Bool {
        imageAttachmentState == .unknown || (hasImageAttachment && imageSignature.isEmpty)
    }

    func updateImageData(_ data: Data) {
        imageData = data
        updateImageAttachmentIndex(for: data)
    }

    @discardableResult
    func repairImageAttachmentIndexIfNeeded() -> Bool {
        guard needsImageAttachmentIndexRepair else { return false }
        updateImageAttachmentIndex(for: imageData)
        return true
    }

    @discardableResult
    func backfillImageAttachmentPresenceAssumingPayload() -> Bool {
        guard imageAttachmentState != .present else { return false }
        imageAttachmentState = .present
        return true
    }

    private func updateImageAttachmentIndex(for data: Data) {
        let hasRenderableImage = Self.hasRenderableImagePayload(data)
        imageAttachmentState = hasRenderableImage ? .present : .absent
        imageSignature = hasRenderableImage ? MediaPayloadSignature.signature(for: data) : ""
    }

    private static func hasRenderableImagePayload(_ data: Data) -> Bool {
        data.count > 8
    }
}
