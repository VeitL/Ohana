//
//  SafetyContactCommandService.swift
//  Ohana
//
//  Local-only write boundary for Zen safety contacts.
//

import Foundation
import SwiftData

nonisolated struct SafetyContactSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let sortOrder: Int
    let isEnabled: Bool

    @MainActor
    init(_ contact: SafetyContact) {
        id = contact.id
        name = contact.name
        phoneNumber = contact.phoneNumber
        sortOrder = contact.sortOrder
        isEnabled = contact.isEnabled
    }
}

nonisolated enum SafetyContactCommandError: Error, Equatable, Sendable {
    case invalidName
    case invalidPhoneNumber
    case contactLimitReached(limit: Int)
    case contactNotFound
    case persistenceFailed
}

@MainActor
enum SafetyContactCommandService {
    static func snapshots(context: ModelContext) throws -> [SafetyContactSnapshot] {
        var descriptor = FetchDescriptor<SafetyContact>(
            sortBy: [
                SortDescriptor(\SafetyContact.sortOrder),
                SortDescriptor(\SafetyContact.createdAt)
            ]
        )
        descriptor.fetchLimit = 4
        return try context.fetch(descriptor).map { SafetyContactSnapshot($0) }
    }

    @discardableResult
    static func create(
        name: String,
        phoneNumber: String,
        capabilities: OhanaPlanCapabilities,
        context: ModelContext,
        now: Date = Date()
    ) throws -> SafetyContactSnapshot {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw SafetyContactCommandError.invalidName }
        guard !cleanPhoneNumber.isEmpty else { throw SafetyContactCommandError.invalidPhoneNumber }

        let existing = try context.fetch(
            FetchDescriptor<SafetyContact>(sortBy: [SortDescriptor(\SafetyContact.sortOrder)])
        )
        let limit = capabilities.contacts.maximumLocalContacts
        guard existing.count < limit else {
            throw SafetyContactCommandError.contactLimitReached(limit: limit)
        }

        let contact = SafetyContact(
            name: cleanName,
            phoneNumber: cleanPhoneNumber,
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1,
            createdAt: now
        )
        context.insert(contact)
        try saveOrRollback(context)
        return SafetyContactSnapshot(contact)
    }

    /// Existing contacts stay editable after a Personal downgrade. The quota
    /// is enforced only when a new contact is created, so no local contact is
    /// silently deleted or disabled when entitlement state changes.
    @discardableResult
    static func update(
        id: UUID,
        name: String,
        phoneNumber: String,
        isEnabled: Bool,
        context: ModelContext,
        now: Date = Date()
    ) throws -> SafetyContactSnapshot {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw SafetyContactCommandError.invalidName }
        guard !cleanPhoneNumber.isEmpty else { throw SafetyContactCommandError.invalidPhoneNumber }

        guard let contact = try contact(id: id, context: context) else {
            throw SafetyContactCommandError.contactNotFound
        }
        contact.name = cleanName
        contact.phoneNumber = cleanPhoneNumber
        contact.isEnabled = isEnabled
        contact.updatedAt = now
        try saveOrRollback(context)
        return SafetyContactSnapshot(contact)
    }

    static func delete(id: UUID, context: ModelContext) throws {
        guard let contact = try contact(id: id, context: context) else {
            throw SafetyContactCommandError.contactNotFound
        }
        context.delete(contact) // derived-state: allow SafetyContact is intentionally device-local and has no synced derivatives
        try saveOrRollback(context)
    }

    private static func contact(id: UUID, context: ModelContext) throws -> SafetyContact? {
        var descriptor = FetchDescriptor<SafetyContact>(
            predicate: #Predicate<SafetyContact> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func saveOrRollback(_ context: ModelContext) throws {
        let result = context.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            context.rollback()
            throw SafetyContactCommandError.persistenceFailed
        }
    }
}
