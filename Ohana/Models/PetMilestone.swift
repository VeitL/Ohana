//
//  PetMilestone.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum PetMilestonePhotoAttachmentState: String, Codable, Sendable {
    case unknown
    case absent
    case present
}

@Model
final class PetMilestone {
    var id: UUID
    var date: Date
    var title: String
    var emoji: String
    var notes: String
    var pet: Pet?
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""
    // FIX 7 (ArkSchemaV17): 里程碑配图
    @Attribute(.externalStorage) var photoData: Data?
    var photoAttachmentStateRaw: String = PetMilestonePhotoAttachmentState.unknown.rawValue
    var photoImageSignature: String = ""
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
        updatePhotoAttachmentIndex(for: photoData)
    }

    var photoAttachmentState: PetMilestonePhotoAttachmentState {
        get { PetMilestonePhotoAttachmentState(rawValue: photoAttachmentStateRaw) ?? .unknown }
        set { photoAttachmentStateRaw = newValue.rawValue }
    }

    var hasPhotoAttachment: Bool {
        canAttemptPhotoAttachmentLoad
    }

    var canAttemptPhotoAttachmentLoad: Bool {
        photoAttachmentState != .absent
    }

    var photoThumbnailSignature: String {
        if !photoImageSignature.isEmpty {
            return photoImageSignature
        }
        guard canAttemptPhotoAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):\(date.timeIntervalSince1970)"
    }

    var needsPhotoAttachmentIndexRepair: Bool {
        photoAttachmentState == .unknown || (hasPhotoAttachment && photoImageSignature.isEmpty)
    }

    func updatePhotoData(_ data: Data?) {
        photoData = data
        updatePhotoAttachmentIndex(for: data)
    }

    @discardableResult
    func repairPhotoAttachmentIndexIfNeeded() -> Bool {
        guard needsPhotoAttachmentIndexRepair else { return false }
        updatePhotoAttachmentIndex(for: photoData)
        return true
    }

    @discardableResult
    func backfillPhotoAttachmentPresence(hasData: Bool) -> Bool {
        if hasData {
            guard photoAttachmentState != .present else { return false }
            photoAttachmentState = .present
            return true
        }

        guard photoAttachmentState != .absent || !photoImageSignature.isEmpty else { return false }
        photoAttachmentState = .absent
        photoImageSignature = ""
        return true
    }

    private func updatePhotoAttachmentIndex(for data: Data?) {
        let hasPayload = data?.isEmpty == false
        photoAttachmentState = hasPayload ? .present : .absent
        photoImageSignature = hasPayload ? data.map(MediaPayloadSignature.signature(for:)) ?? "" : ""
    }
}
