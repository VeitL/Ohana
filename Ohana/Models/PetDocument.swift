//
//  PetDocument.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum DocumentCategory: String, Codable, CaseIterable {
    case passport = "护照"
    case vaccine = "疫苗本"
    case insurance = "保险"
    case medical = "病历"
    case registration = "登记证"
    case other = "其他"

    static var protectionDocumentCases: [DocumentCategory] {
        [.passport, .medical, .registration, .other]
    }

    var emoji: String {
        switch self {
        case .passport: "🛂"
        case .vaccine: "💉"
        case .insurance: "🛡️"
        case .medical: "📋"
        case .registration: "📄"
        case .other: "📎"
        }
    }
}

// MARK: - PetDocumentAttachment (multi-attachment support)

enum PetDocumentAttachmentState: String, Codable, Sendable {
    case unknown
    case absent
    case present
}

@Model
final class PetDocumentAttachment {
    var id: UUID
    @Attribute(.externalStorage) var data: Data
    var dataAttachmentStateRaw: String = PetDocumentAttachmentState.unknown.rawValue
    var dataSignature: String = ""
    var filename: String
    var isImage: Bool

    init(data: Data, filename: String, isImage: Bool) {
        self.id = UUID()
        self.data = data
        let hasPayload = !data.isEmpty
        self.dataAttachmentStateRaw = hasPayload ? PetDocumentAttachmentState.present.rawValue : PetDocumentAttachmentState.absent.rawValue
        self.dataSignature = hasPayload ? MediaPayloadSignature.signature(for: data) : ""
        self.filename = filename
        self.isImage = isImage
    }

    var dataAttachmentState: PetDocumentAttachmentState {
        get { PetDocumentAttachmentState(rawValue: dataAttachmentStateRaw) ?? .unknown }
        set { dataAttachmentStateRaw = newValue.rawValue }
    }

    var hasDataAttachment: Bool {
        canAttemptDataAttachmentLoad
    }

    var canAttemptDataAttachmentLoad: Bool {
        dataAttachmentState != .absent
    }

    var dataThumbnailSignature: String {
        if !dataSignature.isEmpty {
            return dataSignature
        }
        guard canAttemptDataAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):\(filename)"
    }

    var needsDataAttachmentIndexRepair: Bool {
        dataAttachmentState == .unknown || (hasDataAttachment && dataSignature.isEmpty)
    }

    func updateData(_ data: Data) {
        self.data = data
        updateDataAttachmentIndex(for: data)
    }

    @discardableResult
    func repairDataAttachmentIndexIfNeeded() -> Bool {
        guard needsDataAttachmentIndexRepair else { return false }
        updateDataAttachmentIndex(for: data)
        return true
    }

    @discardableResult
    func backfillDataAttachmentPresenceAssumingPayload() -> Bool {
        guard dataAttachmentState != .present else { return false }
        dataAttachmentState = .present
        return true
    }

    private func updateDataAttachmentIndex(for data: Data) {
        let hasPayload = !data.isEmpty
        dataAttachmentState = hasPayload ? .present : .absent
        dataSignature = hasPayload ? MediaPayloadSignature.signature(for: data) : ""
    }
}

@Model
final class PetDocument {
    var id: UUID
    var title: String
    var category: String
    var issueDate: Date?
    var expiryDate: Date?
    var issuingAuthority: String
    var notes: String
    var reminderDate: Date?
    var cost: Double
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""
    @Attribute(.externalStorage) var attachmentData: Data? // Keeping for backward compatibility temporarily
    var legacyAttachmentStateRaw: String = PetDocumentAttachmentState.unknown.rawValue
    var legacyAttachmentSignature: String = ""
    var attachmentFilename: String // Keeping for backward compatibility temporarily

    @Relationship(deleteRule: .cascade)
    var attachments: [PetDocumentAttachment] = []

    var pet: Pet?

    init(title: String = "", category: DocumentCategory = .other, pet: Pet? = nil) {
        self.id = UUID()
        self.title = title
        self.category = category.rawValue
        self.issueDate = nil
        self.expiryDate = nil
        self.issuingAuthority = ""
        self.notes = ""
        self.reminderDate = nil
        self.cost = 0
        self.attachmentData = nil
        self.legacyAttachmentStateRaw = PetDocumentAttachmentState.absent.rawValue
        self.legacyAttachmentSignature = ""
        self.attachmentFilename = ""
        self.attachments = []
        self.pet = pet
    }

    var documentCategory: DocumentCategory {
        DocumentCategory(rawValue: category) ?? .other
    }

    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }

    var isExpiringSoon: Bool {
        guard let expiryDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return daysUntilExpiry <= 30 && daysUntilExpiry > 0
    }

    var legacyAttachmentState: PetDocumentAttachmentState {
        get { PetDocumentAttachmentState(rawValue: legacyAttachmentStateRaw) ?? .unknown }
        set { legacyAttachmentStateRaw = newValue.rawValue }
    }

    var hasLegacyAttachment: Bool {
        canAttemptLegacyAttachmentLoad
    }

    var canAttemptLegacyAttachmentLoad: Bool {
        legacyAttachmentState != .absent
    }

    var legacyAttachmentThumbnailSignature: String {
        if !legacyAttachmentSignature.isEmpty {
            return legacyAttachmentSignature
        }
        guard canAttemptLegacyAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):\(attachmentFilename)"
    }

    var shouldDisplayLegacyAttachmentSlot: Bool {
        hasLegacyAttachment || (legacyAttachmentState == .unknown && !attachmentFilename.isEmpty)
    }

    var needsLegacyAttachmentIndexRepair: Bool {
        legacyAttachmentState == .unknown || (hasLegacyAttachment && legacyAttachmentSignature.isEmpty)
    }

    func updateLegacyAttachment(data: Data?, filename: String) {
        attachmentData = data
        attachmentFilename = data == nil ? "" : filename
        updateLegacyAttachmentIndex(for: data)
    }

    @discardableResult
    func repairLegacyAttachmentIndexIfNeeded() -> Bool {
        guard needsLegacyAttachmentIndexRepair else { return false }
        updateLegacyAttachmentIndex(for: attachmentData)
        if legacyAttachmentState == .absent {
            attachmentFilename = ""
        }
        return true
    }

    @discardableResult
    func backfillLegacyAttachmentPresence(hasData: Bool) -> Bool {
        if hasData {
            guard legacyAttachmentState != .present else { return false }
            legacyAttachmentState = .present
            return true
        }

        guard legacyAttachmentState != .absent
            || !legacyAttachmentSignature.isEmpty
        else { return false }
        legacyAttachmentState = .absent
        legacyAttachmentSignature = ""
        attachmentFilename = ""
        return true
    }

    private func updateLegacyAttachmentIndex(for data: Data?) {
        legacyAttachmentState = data == nil ? .absent : .present
        legacyAttachmentSignature = data.map(MediaPayloadSignature.signature(for:)) ?? ""
    }
}
