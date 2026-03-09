//
//  PetDocument.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum DocumentCategory: String, Codable, CaseIterable {
    case passport = "护照"
    case vaccine = "疫苗本"
    case insurance = "保险"
    case medical = "病历"
    case registration = "登记证"
    case other = "其他"
    
    var emoji: String {
        switch self {
        case .passport: return "🛂"
        case .vaccine: return "💉"
        case .insurance: return "🛡️"
        case .medical: return "📋"
        case .registration: return "📄"
        case .other: return "📎"
        }
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
    @Attribute(.externalStorage) var attachmentData: Data?
    var attachmentFilename: String
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
        self.attachmentFilename = ""
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
}
