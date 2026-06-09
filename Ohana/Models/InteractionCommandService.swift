//
//  InteractionCommandService.swift
//  Ohana
//
//  Domain write boundaries for high-frequency interaction rows and quick moments.
//

import Foundation
import SwiftData
import UIKit

struct MomentCommandResult: Equatable {
    let savedLogIDs: [UUID]
    let coconutDelta: Int
}

enum MomentCommandService {
    @discardableResult
    @MainActor
    static func recordMoment(
        pet: Pet?,
        note: String,
        photoData: [Data],
        locationLatitude: Double,
        locationLongitude: Double,
        locationPlacename: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> MomentCommandResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNote.isEmpty || !photoData.isEmpty else {
            return MomentCommandResult(savedLogIDs: [], coconutDelta: 0)
        }

        let payloads = photoData.isEmpty ? [Data(count: 1)] : photoData
        var savedLogs: [PetPhotoLog] = []
        for (index, data) in payloads.enumerated() {
            let log = PetPhotoLog(
                imageData: data,
                date: date.addingTimeInterval(Double(index) * 0.01),
                note: cleanNote,
                pet: pet,
                locationLatitude: locationLatitude,
                locationLongitude: locationLongitude,
                locationPlacename: locationPlacename
            )
            context.insert(log)
            savedLogs.append(log)
        }

        context.safeSave()

        let before = QuestManager.shared.coconutCount
        QuestManager.shared.addCoconuts(
            1,
            emoji: "📸",
            title: "记录时刻 +1🥥",
            actorId: executorId
        )
        let coconutDelta = max(0, QuestManager.shared.coconutCount - before)

        if let savedLog = savedLogs.first {
            CareLedgerService.record(
                occurredAt: savedLog.date,
                actorKind: executorId == nil ? .unknown : .human,
                actorId: executorId,
                subjectKind: pet == nil ? .system : .pet,
                subjectId: pet?.id.uuidString,
                eventKind: .milestone,
                actionType: "petMoment",
                note: savedLog.note,
                source: .quickAction,
                legacyModelName: "PetPhotoLog",
                legacyModelId: savedLog.id.uuidString,
                coconutDelta: coconutDelta,
                context: context
            )
        }

        return MomentCommandResult(savedLogIDs: savedLogs.map(\.id), coconutDelta: coconutDelta)
    }
}

@MainActor
struct MomentCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordMoment(
        pet: Pet?,
        note noteText: String,
        photoData: [Data],
        locationLatitude: Double,
        locationLongitude: Double,
        locationPlacename: String,
        executorId: String?,
        date: Date = Date(),
        revisionNote: String
    ) -> MomentCommandResult {
        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: noteText,
            photoData: photoData,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            locationPlacename: locationPlacename,
            context: context,
            executorId: executorId,
            date: date
        )
        revisionCenter.publishQuickMoment(result, petID: pet?.id, note: revisionNote)
        return result
    }
}

struct PetPhotoAlbumCreateResult: Equatable {
    let petID: UUID
    let photoIDs: [UUID]
}

struct PetPhotoAlbumUpdateResult: Equatable {
    let petID: UUID
    let photoID: UUID
    let didChange: Bool
}

struct PetPhotoAlbumDeleteResult: Equatable {
    let petID: UUID
    let photoID: UUID
}

enum PetPhotoAlbumCommandService {
    @discardableResult
    @MainActor
    static func createPhotos(
        data payloads: [Data],
        pet: Pet,
        context: ModelContext,
        date: Date = Date()
    ) -> PetPhotoAlbumCreateResult {
        guard !payloads.isEmpty else {
            return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: [])
        }

        var logs: [PetPhotoLog] = []
        for (index, data) in payloads.enumerated() {
            let log = PetPhotoLog(
                imageData: data,
                date: date.addingTimeInterval(Double(index) * 0.01),
                pet: pet
            )
            context.insert(log)
            logs.append(log)
        }
        context.safeSave()
        return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: logs.map(\.id))
    }

    @discardableResult
    @MainActor
    static func updateNote(
        _ note: String,
        photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPhotoAlbumUpdateResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChange = photo.note != cleanNote
        photo.note = cleanNote
        if didChange {
            context.safeSave()
        }
        return PetPhotoAlbumUpdateResult(petID: pet.id, photoID: photo.id, didChange: didChange)
    }

    @discardableResult
    @MainActor
    static func deletePhoto(
        _ photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPhotoAlbumDeleteResult {
        let photoID = photo.id
        context.delete(photo)
        context.safeSave()
        return PetPhotoAlbumDeleteResult(petID: pet.id, photoID: photoID)
    }
}

@MainActor
struct PetPhotoAlbumCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createPhotos(
        data payloads: [Data],
        pet: Pet,
        date: Date = Date(),
        note: String
    ) -> PetPhotoAlbumCreateResult {
        let result = PetPhotoAlbumCommandService.createPhotos(
            data: payloads,
            pet: pet,
            context: context,
            date: date
        )
        revisionCenter.publishPetPhotoCreate(result, note: note)
        return result
    }

    @discardableResult
    func updateNote(
        _ noteText: String,
        photo: PetPhotoLog,
        pet: Pet,
        note: String
    ) -> PetPhotoAlbumUpdateResult {
        let result = PetPhotoAlbumCommandService.updateNote(
            noteText,
            photo: photo,
            pet: pet,
            context: context
        )
        revisionCenter.publishPetPhotoUpdate(result, note: note)
        return result
    }

    @discardableResult
    func deletePhoto(
        _ photo: PetPhotoLog,
        pet: Pet,
        note: String
    ) -> PetPhotoAlbumDeleteResult {
        let result = PetPhotoAlbumCommandService.deletePhoto(photo, pet: pet, context: context)
        revisionCenter.publishPetPhotoDelete(result, note: note)
        return result
    }
}

enum HumanWishlistCommandError: LocalizedError, Equatable {
    case emptyTitle
    case invalidCost
    case itemOwnershipMismatch
    case alreadyRedeemed
    case insufficientCoconuts(missing: Int)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "心愿内容不能为空。"
        case .invalidCost:
            return "心愿兑换费用必须大于 0。"
        case .itemOwnershipMismatch:
            return "这个心愿不属于当前成员。"
        case .alreadyRedeemed:
            return "这个心愿已经兑换。"
        case let .insufficientCoconuts(missing):
            return "椰子余额不足，还差 \(missing) 个。"
        }
    }
}

struct HumanWishlistCommandInput: Equatable {
    let title: String
    let cost: Int
    let createdAt: Date

    init(title: String, cost: Int, createdAt: Date = Date()) {
        self.title = title
        self.cost = cost
        self.createdAt = createdAt
    }
}

struct HumanWishlistCommandResult: Equatable {
    let humanID: UUID
    let itemID: UUID
    let coconutDelta: Int
    let ledgerEventID: UUID?
    let isRedeemed: Bool
}

struct HumanWishlistDeleteCommandResult: Equatable {
    let humanID: UUID
    let itemID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum HumanWishlistCommandService {
    @discardableResult
    @MainActor
    static func createItem(
        input: HumanWishlistCommandInput,
        for human: Human,
        context: ModelContext
    ) throws -> HumanWishlistCommandResult {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw HumanWishlistCommandError.emptyTitle }
        guard input.cost > 0 else { throw HumanWishlistCommandError.invalidCost }

        let item = WishlistItem(title: title, cost: input.cost, creatorId: human.id.uuidString)
        item.createdAt = input.createdAt
        context.insert(item)
        context.safeSave()
        return HumanWishlistCommandResult(
            humanID: human.id,
            itemID: item.id,
            coconutDelta: 0,
            ledgerEventID: nil,
            isRedeemed: false
        )
    }

    @discardableResult
    @MainActor
    static func redeemItem(
        _ item: WishlistItem,
        for human: Human,
        redeemedById: String?,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> HumanWishlistCommandResult {
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        guard !item.isRedeemed else { throw HumanWishlistCommandError.alreadyRedeemed }
        guard item.cost > 0 else { throw HumanWishlistCommandError.invalidCost }
        guard human.coconutBalance >= item.cost else {
            throw HumanWishlistCommandError.insufficientCoconuts(missing: item.cost - human.coconutBalance)
        }

        human.coconutBalance -= item.cost
        item.isRedeemed = true
        item.redeemedById = normalizedId(redeemedById)

        let questManager = providedQuestManager ?? QuestManager.shared
        questManager.recordCoconutDelta(
            -item.cost,
            emoji: "🎁",
            title: "兑换「\(item.title)」",
            actorId: human.id.uuidString,
            actorName: human.name
        )
        let ledger = CareLedgerService.record(
            actorKind: .human,
            actorId: item.redeemedById ?? human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .coconut,
            actionType: "humanWishlistRedeem",
            note: item.title,
            source: .economy,
            legacyModelName: "WishlistItem",
            legacyModelId: item.id.uuidString,
            coconutDelta: -item.cost,
            privacyFieldRaw: HumanPrivateField.wishlist.rawValue,
            context: context,
            save: false
        )
        context.safeSave()

        return HumanWishlistCommandResult(
            humanID: human.id,
            itemID: item.id,
            coconutDelta: -item.cost,
            ledgerEventID: ledger.id,
            isRedeemed: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteItem(
        _ item: WishlistItem,
        for human: Human,
        context: ModelContext
    ) throws -> HumanWishlistDeleteCommandResult {
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        let ledgerEvents = ledgerEvents(for: item, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let itemID = item.id
        context.delete(item)
        context.safeSave()
        return HumanWishlistDeleteCommandResult(
            humanID: human.id,
            itemID: itemID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    private static func normalizedId(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static func ledgerEvents(
        for item: WishlistItem,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = item.id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == "WishlistItem" && $0.legacyModelId == idString }
    }
}

@MainActor
struct HumanWishlistCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createItem(
        input: HumanWishlistCommandInput,
        for human: Human,
        note: String
    ) throws -> HumanWishlistCommandResult {
        let result = try HumanWishlistCommandService.createItem(input: input, for: human, context: context)
        revisionCenter.publishHumanWishlistCreate(result, note: note)
        return result
    }

    @discardableResult
    func redeemItem(
        _ item: WishlistItem,
        for human: Human,
        redeemedById: String?,
        questManager: QuestManager? = nil,
        note: String
    ) throws -> HumanWishlistCommandResult {
        let result = try HumanWishlistCommandService.redeemItem(
            item,
            for: human,
            redeemedById: redeemedById,
            context: context,
            questManager: questManager
        )
        revisionCenter.publishHumanWishlistRedeem(result, note: note)
        return result
    }

    @discardableResult
    func deleteItem(
        _ item: WishlistItem,
        for human: Human,
        note: String
    ) throws -> HumanWishlistDeleteCommandResult {
        let result = try HumanWishlistCommandService.deleteItem(item, for: human, context: context)
        revisionCenter.publishHumanWishlistDelete(result, note: note)
        return result
    }
}

struct CatCareCommandInput: Equatable {
    let actionRaw: String
    let emoji: String
    let recordsHygiene: Bool
    let occurredAt: Date
    let executorId: String?

    init(
        actionRaw: String,
        emoji: String,
        recordsHygiene: Bool,
        occurredAt: Date = Date(),
        executorId: String? = nil
    ) {
        self.actionRaw = actionRaw
        self.emoji = emoji
        self.recordsHygiene = recordsHygiene
        self.occurredAt = occurredAt
        self.executorId = executorId
    }
}

struct CatCareCommandResult: Equatable {
    let petID: UUID
    let actionRaw: String
    let eventID: UUID
    let hygieneLogID: UUID?
}

struct CatCareUndoCommandResult: Equatable {
    let petID: UUID
    let eventID: UUID
    let hygieneLogID: UUID?
}

enum CatCareCommandService {
    @discardableResult
    @MainActor
    static func record(
        pet: Pet,
        input: CatCareCommandInput,
        context: ModelContext
    ) -> CatCareCommandResult {
        let event = Event(
            title: "\(input.emoji) \(input.actionRaw)",
            startDate: input.occurredAt,
            isAllDay: false,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)

        let hygieneLog: PetHygieneLog?
        if input.recordsHygiene {
            let log = PetHygieneLog(date: input.occurredAt, type: .bath, pet: pet, executorId: input.executorId)
            context.insert(log)
            hygieneLog = log
        } else {
            hygieneLog = nil
        }
        context.safeSave()

        return CatCareCommandResult(
            petID: pet.id,
            actionRaw: input.actionRaw,
            eventID: event.id,
            hygieneLogID: hygieneLog?.id
        )
    }

    @discardableResult
    @MainActor
    static func undo(
        pet: Pet,
        eventID: UUID,
        hygieneLogID: UUID?,
        context: ModelContext
    ) -> CatCareUndoCommandResult {
        if let event = fetchEvent(id: eventID, petID: pet.id, context: context) {
            context.delete(event)
        }
        if let hygieneLogID,
           let log = fetchHygieneLog(id: hygieneLogID, petID: pet.id, context: context) {
            context.delete(log)
        }
        context.safeSave()
        return CatCareUndoCommandResult(petID: pet.id, eventID: eventID, hygieneLogID: hygieneLogID)
    }

    @MainActor
    private static func fetchEvent(id: UUID, petID: UUID, context: ModelContext) -> Event? {
        let idString = petID.uuidString
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return events.first {
            $0.id == id &&
            $0.relatedEntityId == idString &&
            $0.eventType == EventType.litterBox.rawValue
        }
    }

    @MainActor
    private static func fetchHygieneLog(id: UUID, petID: UUID, context: ModelContext) -> PetHygieneLog? {
        let logs = (try? context.fetch(FetchDescriptor<PetHygieneLog>())) ?? []
        return logs.first { $0.id == id && $0.pet?.id == petID }
    }
}

struct PetMilestoneCommandInput: Equatable {
    let date: Date
    let title: String
    let emoji: String
    let notes: String
    let photoData: Data?
    let location: String
}

struct PetMilestoneCommandResult: Equatable {
    let petID: UUID
    let milestoneIDs: [UUID]
    let coconutDelta: Int
}

struct PetMilestoneDeleteCommandResult: Equatable {
    let petID: UUID
    let milestoneID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum PetMilestoneCommandService {
    @discardableResult
    @MainActor
    static func seedSystemMilestones(
        for pet: Pet,
        context: ModelContext
    ) -> PetMilestoneCommandResult {
        var existingTitles = Set(pet.milestones.map(\.title))
        var created: [(milestone: PetMilestone, actionType: String)] = []

        func appendIfNeeded(date: Date?, title: String, emoji: String, notes: String, actionType: String) {
            guard let date, !existingTitles.contains(title) else { return }
            let milestone = PetMilestone(date: date, title: title, emoji: emoji, notes: notes, pet: pet)
            context.insert(milestone)
            existingTitles.insert(title)
            created.append((milestone, actionType))
        }

        appendIfNeeded(
            date: pet.birthday,
            title: "\(pet.name)的生日 🎂",
            emoji: "🎂",
            notes: "出生啦！",
            actionType: "autoBirthday"
        )
        appendIfNeeded(
            date: pet.homeDate,
            title: "\(pet.name)到家了 🏠",
            emoji: "🏠",
            notes: "第一天回家!",
            actionType: "autoHomeDate"
        )
        if let heaviest = pet.weightLogs.max(by: { $0.weight < $1.weight }) {
            appendIfNeeded(
                date: heaviest.date,
                title: "最重记录：\(String(format: "%.1f", heaviest.weight))kg",
                emoji: "⚖️",
                notes: "历史最高体重记录",
                actionType: "autoHeaviestWeight"
            )
        }

        for entry in created {
            recordLedger(
                milestone: entry.milestone,
                pet: pet,
                actionType: entry.actionType,
                source: .service,
                coconutDelta: 0,
                context: context,
                save: false
            )
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return PetMilestoneCommandResult(
            petID: pet.id,
            milestoneIDs: created.map { $0.milestone.id },
            coconutDelta: 0
        )
    }

    @discardableResult
    @MainActor
    static func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        context: ModelContext
    ) -> PetMilestoneCommandResult {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return PetMilestoneCommandResult(petID: pet.id, milestoneIDs: [], coconutDelta: 0)
        }

        let milestone = PetMilestone(
            date: input.date,
            title: title,
            emoji: input.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎉" : input.emoji,
            notes: input.notes,
            pet: pet,
            photoData: input.photoData,
            location: input.location
        )
        context.insert(milestone)
        context.safeSave()

        let reward = QuestManager.shared.awardAction(type: .milestone, pet: pet, context: context)
        let coconutDelta = max(0, reward.humanGot + reward.petGot)
        recordLedger(
            milestone: milestone,
            pet: pet,
            actionType: "manual",
            source: .detail,
            coconutDelta: coconutDelta,
            context: context
        )

        return PetMilestoneCommandResult(
            petID: pet.id,
            milestoneIDs: [milestone.id],
            coconutDelta: coconutDelta
        )
    }

    @discardableResult
    @MainActor
    static func deleteMilestone(
        _ milestone: PetMilestone,
        pet: Pet,
        context: ModelContext
    ) -> PetMilestoneDeleteCommandResult {
        let ledgerEvents = ledgerEvents(for: milestone, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let milestoneID = milestone.id
        context.delete(milestone)
        context.safeSave()
        return PetMilestoneDeleteCommandResult(
            petID: pet.id,
            milestoneID: milestoneID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    private static func recordLedger(
        milestone: PetMilestone,
        pet: Pet,
        actionType: String,
        source: CareLedgerSource,
        coconutDelta: Int,
        context: ModelContext,
        save: Bool = true
    ) -> CareLedgerEvent {
        CareLedgerService.record(
            occurredAt: milestone.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .milestone,
            actionType: actionType,
            note: milestone.title,
            source: source,
            legacyModelName: "PetMilestone",
            legacyModelId: milestone.id.uuidString,
            coconutDelta: coconutDelta,
            context: context,
            save: save
        )
    }

    @MainActor
    private static func ledgerEvents(
        for milestone: PetMilestone,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = milestone.id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == "PetMilestone" && $0.legacyModelId == idString }
    }
}

@MainActor
struct PetMilestoneCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func seedSystemMilestones(for pet: Pet, note: String) -> PetMilestoneCommandResult {
        let result = PetMilestoneCommandService.seedSystemMilestones(for: pet, context: context)
        revisionCenter.publishPetMilestoneSeed(result, note: note)
        return result
    }

    @discardableResult
    func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        note: String
    ) -> PetMilestoneCommandResult {
        let result = PetMilestoneCommandService.createMilestone(input: input, pet: pet, context: context)
        revisionCenter.publishPetMilestoneRecord(result, note: note)
        return result
    }

    @discardableResult
    func deleteMilestone(
        _ milestone: PetMilestone,
        pet: Pet,
        note: String
    ) -> PetMilestoneDeleteCommandResult {
        let result = PetMilestoneCommandService.deleteMilestone(milestone, pet: pet, context: context)
        revisionCenter.publishPetMilestoneDelete(result, note: note)
        return result
    }
}

struct PetDocumentAttachmentCommandInput: Equatable {
    let data: Data
    let filename: String
    let isImage: Bool
}

struct PetDocumentCreateCommandInput: Equatable {
    let title: String
    let category: DocumentCategory
    let issuingAuthority: String
    let notes: String
    let issueDate: Date?
    let expiryDate: Date?
    let cost: Double
    let payerId: String?
    let documentNumber: String
    let attachments: [PetDocumentAttachmentCommandInput]
}

struct PetDocumentUpdateCommandInput: Equatable {
    let title: String
    let category: DocumentCategory
    let issuingAuthority: String
    let notes: String
    let issueDate: Date?
    let expiryDate: Date?
    let cost: Double
    let attachmentData: Data?
    let clearsAttachment: Bool
    let attachments: [PetDocumentAttachmentCommandInput]

    init(
        title: String,
        category: DocumentCategory,
        issuingAuthority: String,
        notes: String,
        issueDate: Date?,
        expiryDate: Date?,
        cost: Double,
        attachmentData: Data?,
        clearsAttachment: Bool,
        attachments: [PetDocumentAttachmentCommandInput] = []
    ) {
        self.title = title
        self.category = category
        self.issuingAuthority = issuingAuthority
        self.notes = notes
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.cost = cost
        self.attachmentData = attachmentData
        self.clearsAttachment = clearsAttachment
        self.attachments = attachments
    }
}

struct PetDocumentCommandResult: Equatable {
    let petID: UUID
    let documentID: UUID
    let expenseLogIDs: [UUID]
    let ledgerEventIDs: [UUID]
}

struct PetDocumentDeleteCommandResult: Equatable {
    let petID: UUID
    let documentID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum PetDocumentCommandService {
    @discardableResult
    @MainActor
    static func createDocument(
        input: PetDocumentCreateCommandInput,
        pet: Pet,
        context: ModelContext,
        now: Date = Date()
    ) -> PetDocumentCommandResult {
        let finalTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(pet.name)\(input.category.rawValue)"
            : input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = PetDocument(title: finalTitle, category: input.category, pet: pet)
        document.issuingAuthority = input.issuingAuthority
        document.notes = input.notes
        document.issueDate = input.issueDate
        document.expiryDate = input.expiryDate
        document.cost = max(0, input.cost)
        applyAttachments(input.attachments, to: document, context: context)

        let expenseLogs = makeExpensesIfNeeded(
            pet: pet,
            document: document,
            category: input.category,
            amount: document.cost,
            issueDate: input.issueDate,
            payerId: validPayerId(input.payerId, context: context),
            now: now,
            context: context
        )

        context.insert(document)
        if !input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           input.category == .passport {
            pet.passportNumber = input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let ledgerEvents = expenseLogs.map { expense in
            CareLedgerService.record(
                occurredAt: expense.date,
                actorKind: expense.executorId == nil ? .unknown : .human,
                actorId: expense.executorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .expense,
                actionType: expense.expenseCategory.rawValue,
                amountValue: expense.amount,
                amountUnit: "currency",
                note: expense.note,
                source: .detail,
                legacyModelName: "PetExpenseLog",
                legacyModelId: expense.id.uuidString,
                context: context,
                save: false
            )
        }

        context.safeSave()
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: expenseLogs.map(\.id),
            ledgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    static func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        context: ModelContext
    ) -> PetDocumentCommandResult {
        document.title = input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(pet.name)\(input.category.rawValue)"
            : input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        document.category = input.category.rawValue
        document.issuingAuthority = input.issuingAuthority
        document.notes = input.notes
        document.issueDate = input.issueDate
        document.expiryDate = input.expiryDate
        document.cost = max(0, input.cost)
        if input.clearsAttachment {
            document.attachmentData = nil
            document.attachmentFilename = ""
            document.attachments.removeAll()
        } else if !input.attachments.isEmpty {
            applyAttachments(input.attachments, to: document, context: context)
        } else if let data = input.attachmentData {
            document.attachmentData = data
            if document.attachmentFilename.isEmpty {
                document.attachmentFilename = "image.jpg"
            }
        }
        context.safeSave()
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: [],
            ledgerEventIDs: []
        )
    }

    @discardableResult
    @MainActor
    static func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        context: ModelContext
    ) -> PetDocumentDeleteCommandResult {
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetDocument", id: document.id, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let documentID = document.id
        context.delete(document)
        context.safeSave()
        return PetDocumentDeleteCommandResult(
            petID: pet.id,
            documentID: documentID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func applyAttachments(
        _ attachments: [PetDocumentAttachmentCommandInput],
        to document: PetDocument,
        context: ModelContext
    ) {
        guard let first = attachments.first else { return }
        document.attachmentData = first.data
        document.attachmentFilename = first.filename.isEmpty
            ? (first.isImage ? "image.jpg" : "attachment")
            : first.filename
        document.attachments = attachments.map { input in
            PetDocumentAttachment(
                data: input.data,
                filename: input.filename.isEmpty ? (input.isImage ? "image.jpg" : "attachment") : input.filename,
                isImage: input.isImage
            )
        }
        for attachment in document.attachments {
            context.insert(attachment)
        }
    }

    @MainActor
    private static func makeExpensesIfNeeded(
        pet: Pet,
        document: PetDocument,
        category: DocumentCategory,
        amount: Double,
        issueDate: Date?,
        payerId: String?,
        now: Date,
        context: ModelContext
    ) -> [PetExpenseLog] {
        guard amount > 0 else { return [] }
        let expenseDate: Date = {
            guard let issueDate else { return now }
            return issueDate > now ? now : issueDate
        }()
        let plans = DocumentExpenseSyncPlanner.plannedExpenses(
            documentCategory: category,
            amount: amount,
            date: expenseDate,
            note: document.title,
            payerId: payerId
        )
        return plans.map { plan in
            let expense = PetExpenseLog(
                date: plan.date,
                amount: plan.amount,
                category: plan.category,
                note: plan.note,
                pet: pet,
                executorId: plan.payerId
            )
            context.insert(expense)
            return expense
        }
    }

    @MainActor
    private static func validPayerId(_ payerId: String?, context: ModelContext) -> String? {
        guard let payerId, !payerId.isEmpty, UUID(uuidString: payerId) != nil else { return nil }
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        return humans.contains { $0.id.uuidString == payerId } ? payerId : nil
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }
}

@MainActor
struct PetDocumentCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createDocument(
        input: PetDocumentCreateCommandInput,
        pet: Pet,
        note: String
    ) -> PetDocumentCommandResult {
        let result = PetDocumentCommandService.createDocument(input: input, pet: pet, context: context)
        revisionCenter.publishPetDocumentCreate(result, category: input.category, note: note)
        return result
    }

    @discardableResult
    func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        note: String
    ) -> PetDocumentCommandResult {
        let result = PetDocumentCommandService.updateDocument(document, pet: pet, input: input, context: context)
        revisionCenter.publishPetDocumentUpdate(result, note: note)
        return result
    }

    @discardableResult
    func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        note: String
    ) -> PetDocumentDeleteCommandResult {
        let result = PetDocumentCommandService.deleteDocument(document, pet: pet, context: context)
        revisionCenter.publishPetDocumentDelete(result, note: note)
        return result
    }
}

struct EventCompletionRewardResult: Equatable {
    let awarded: Bool
    let skippedByExistingCare: Bool
    let coconutDelta: Int
}

struct WeightCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let coconutDelta: Int
    let ledgerEventID: UUID?

    init(logID: UUID, subjectID: UUID?, coconutDelta: Int, ledgerEventID: UUID? = nil) {
        self.logID = logID
        self.subjectID = subjectID
        self.coconutDelta = coconutDelta
        self.ledgerEventID = ledgerEventID
    }
}

struct DashboardRecordDeleteCommandResult: Equatable {
    let subjectID: UUID
    let subjectKind: String
    let recordID: UUID
    let recordKind: String
    let removedLedgerEventIDs: [UUID]
}

enum WeightCommandService {
    @discardableResult
    @MainActor
    static func recordPetWeight(
        pet: Pet,
        weight: Double,
        date: Date,
        context: ModelContext,
        executorId: String? = nil,
        weightUnit: String = "kg",
        bcsScore: Int = 0,
        awardsReward: Bool = false,
        ledgerSource: CareLedgerSource? = nil
    ) -> WeightCommandResult {
        let coconutBefore = QuestManager.shared.coconutCount
        let log = PetWeightLog(
            date: date,
            weight: weight,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        if awardsReward {
            QuestManager.shared.awardAction(type: .weight, pet: pet, context: context)
        }

        let ledgerEvent = ledgerSource.map { source in
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: executorId == nil ? .unknown : .human,
                actorId: executorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .weight,
                actionType: "petWeight",
                amountValue: log.weightInKg,
                amountUnit: "kg",
                source: source,
                legacyModelName: "PetWeightLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        if !awardsReward || ledgerEvent != nil {
            context.safeSave()
        }
        let coconutDelta = awardsReward
            ? max(0, QuestManager.shared.coconutCount - coconutBefore)
            : 0
        return WeightCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEvent?.id
        )
    }

    @discardableResult
    @MainActor
    static func recordHumanWeight(
        human: Human,
        weight: Double,
        date: Date,
        context: ModelContext,
        executorId: String? = nil
    ) -> WeightCommandResult {
        let log = HumanWeightLog(
            date: date,
            weight: weight,
            human: human,
            executorId: executorId
        )
        context.insert(log)
        human.weightLogs.append(log)
        context.safeSave()
        return WeightCommandResult(logID: log.id, subjectID: human.id, coconutDelta: 0)
    }
}

@MainActor
struct DashboardRecordCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordPetWeight(
        pet: Pet,
        weight: Double,
        date: Date,
        executorId: String?,
        weightUnit: String = "kg",
        bcsScore: Int = 0,
        awardsReward: Bool = false,
        ledgerSource: CareLedgerSource? = nil,
        command: DomainCommand,
        note: String
    ) -> WeightCommandResult {
        let result = WeightCommandService.recordPetWeight(
            pet: pet,
            weight: weight,
            date: date,
            context: context,
            executorId: executorId,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            awardsReward: awardsReward,
            ledgerSource: ledgerSource
        )
        revisionCenter.publishWeightEntry(command: command, subjectID: pet.id, result: result, note: note)
        return result
    }

    @discardableResult
    func recordHumanWeight(
        human: Human,
        weight: Double,
        date: Date,
        executorId: String?,
        command: DomainCommand,
        note: String
    ) -> WeightCommandResult {
        let result = WeightCommandService.recordHumanWeight(
            human: human,
            weight: weight,
            date: date,
            context: context,
            executorId: executorId
        )
        revisionCenter.publishWeightEntry(command: command, subjectID: human.id, result: result, note: note)
        return result
    }

    @discardableResult
    func deletePetWeight(_ log: PetWeightLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetWeight(log, pet: pet, context: context)
        revisionCenter.publishWeightDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHumanWeight(_ log: HumanWeightLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanWeight(log, human: human, context: context)
        revisionCenter.publishWeightDelete(result, note: note)
        return result
    }

    @discardableResult
    func recordPetExpense(
        pet: Pet,
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note expenseNote: String,
        executorId: String?,
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = [],
        command: DomainCommand,
        revisionNote: String
    ) -> ExpenseCommandResult {
        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: amount,
            date: date,
            category: category,
            note: expenseNote,
            context: context,
            executorId: executorId,
            source: source,
            receiptTitle: receiptTitle,
            receiptCategory: receiptCategory,
            receiptAttachments: receiptAttachments
        )
        revisionCenter.publishExpenseEntry(command: command, subjectID: pet.id, result: result, note: revisionNote)
        return result
    }

    @discardableResult
    func recordHumanExpense(
        human: Human,
        amount: Double,
        date: Date,
        note expenseNote: String,
        category: ExpenseCategory = .other,
        command: DomainCommand,
        revisionNote: String
    ) -> ExpenseCommandResult {
        let result = ExpenseCommandService.recordHumanExpense(
            human: human,
            amount: amount,
            date: date,
            note: expenseNote,
            context: context,
            category: category
        )
        revisionCenter.publishExpenseEntry(command: command, subjectID: human.id, result: result, note: revisionNote)
        return result
    }

    @discardableResult
    func deletePetExpense(_ log: PetExpenseLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetExpense(log, pet: pet, context: context)
        revisionCenter.publishExpenseDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHumanExpense(_ log: PetExpenseLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanExpense(log, human: human, context: context)
        revisionCenter.publishExpenseDelete(result, note: note)
        return result
    }
}

enum DashboardRecordCommandService {
    @discardableResult
    @MainActor
    static func deletePetWeight(
        _ log: PetWeightLog,
        pet: Pet,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: pet.id,
            subjectKind: EntityKind.pet.rawValue,
            recordID: log.id,
            recordKind: "PetWeightLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    static func deleteHumanWeight(
        _ log: HumanWeightLog,
        human: Human,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: human.id,
            subjectKind: EntityKind.human.rawValue,
            recordID: log.id,
            recordKind: "HumanWeightLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    static func deletePetExpense(
        _ log: PetExpenseLog,
        pet: Pet,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: pet.id,
            subjectKind: EntityKind.pet.rawValue,
            recordID: log.id,
            recordKind: "PetExpenseLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    static func deleteHumanExpense(
        _ log: PetExpenseLog,
        human: Human,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: human.id,
            subjectKind: EntityKind.human.rawValue,
            recordID: log.id,
            recordKind: "PetExpenseLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    private static func deleteRecord<T: PersistentModel>(
        _ record: T,
        subjectID: UUID,
        subjectKind: String,
        recordID: UUID,
        recordKind: String,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        let ledgerEvents = ledgerEvents(forLegacyModelName: recordKind, id: recordID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(record)
        context.safeSave()
        return DashboardRecordDeleteCommandResult(
            subjectID: subjectID,
            subjectKind: subjectKind,
            recordID: recordID,
            recordKind: recordKind,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }
}

struct PetCareTrackingCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID
    let linkedPottyLogID: UUID?
    let careType: CareType
    let coconutDelta: Int
}

struct PetCareTrackingDeleteCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID
    let linkedPottyLogID: UUID?
    let removedLedgerEventIDs: [UUID]
}

enum PetCareTrackingCommandService {
    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> (result: PetCareTrackingCommandResult, log: PetCareLog) {
        if type == .feeding, amountGrams > 0 {
            let recorded = CareEventService.recordManualFeedFact(
                pet: pet,
                amountGrams: amountGrams,
                context: context,
                executorId: executorId,
                date: date,
                source: .detail
            )
            return (
                PetCareTrackingCommandResult(
                    petID: pet.id,
                    careLogID: recorded.result.logID,
                    linkedPottyLogID: nil,
                    careType: .feeding,
                    coconutDelta: recorded.result.coconutDelta
                ),
                recorded.log
            )
        }

        let recorded = CareEventService.recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward(for: type, pet: pet),
            date: date,
            source: .detail,
            createsLinkedPottyLog: type == .litter
        )
        return (
            PetCareTrackingCommandResult(
                petID: pet.id,
                careLogID: recorded.result.logID,
                linkedPottyLogID: recorded.result.linkedPottyLogID,
                careType: type,
                coconutDelta: recorded.result.coconutDelta
            ),
            recorded.log
        )
    }

    @discardableResult
    @MainActor
    static func deleteCareLog(
        _ log: PetCareLog,
        pet: Pet,
        context: ModelContext
    ) -> PetCareTrackingDeleteCommandResult {
        let careLogID = log.id
        let linkedPotty = linkedPottyLog(for: log, pet: pet, context: context)
        var removedLedgerEvents = ledgerEvents(forLegacyModelName: "PetCareLog", id: careLogID, context: context)
        if let linkedPotty {
            removedLedgerEvents += ledgerEvents(forLegacyModelName: "PetPottyLog", id: linkedPotty.id, context: context)
        }

        for event in removedLedgerEvents {
            context.delete(event)
        }
        if let linkedPotty {
            context.delete(linkedPotty)
        }
        context.delete(log)
        context.safeSave()

        return PetCareTrackingDeleteCommandResult(
            petID: pet.id,
            careLogID: careLogID,
            linkedPottyLogID: linkedPotty?.id,
            removedLedgerEventIDs: removedLedgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func linkedPottyLog(for log: PetCareLog, pet: Pet, context: ModelContext) -> PetPottyLog? {
        guard log.careType == .litter else { return nil }
        let logs = (try? context.fetch(FetchDescriptor<PetPottyLog>())) ?? []
        return logs
            .filter { candidate in
                candidate.pet?.id == pet.id
                    && candidate.executorId == log.executorId
                    && abs(candidate.date.timeIntervalSince(log.date)) < 2
            }
            .min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(log.date)) < abs(rhs.date.timeIntervalSince(log.date))
            }
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }

    private static func reward(for type: CareType, pet: Pet) -> QuestManager.OhanaActionType {
        switch type {
        case .feeding:
            return .feed
        case .watering:
            return .water
        case .litter:
            return .potty(isLitter: true)
        case .play:
            return .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            return .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            return .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        case .waterChange:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 换水奖励")
        }
    }
}

struct PetPottyDeleteCommandResult: Equatable {
    let petID: UUID
    let logID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum PetPottyCommandService {
    @discardableResult
    @MainActor
    static func deletePottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPottyDeleteCommandResult {
        let logID = log.id
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetPottyLog", id: logID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(log)
        context.safeSave()
        return PetPottyDeleteCommandResult(
            petID: pet.id,
            logID: logID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }
}

@MainActor
struct PetCareCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordCare(
        pet: Pet,
        type: CareType,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        executorId: String? = nil,
        date: Date = Date(),
        note: String? = nil
    ) -> (result: PetCareTrackingCommandResult, log: PetCareLog) {
        let recorded = PetCareTrackingCommandService.recordCare(
            pet: pet,
            type: type,
            amountGrams: amountGrams,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            date: date
        )
        revisionCenter.publishPetCareRecord(
            recorded.result,
            note: note ?? "petCareTracking.record.\(recorded.result.careType.rawValue)"
        )
        return recorded
    }

    @discardableResult
    func deleteCareLog(
        _ log: PetCareLog,
        pet: Pet,
        note: String
    ) -> PetCareTrackingDeleteCommandResult {
        let result = PetCareTrackingCommandService.deleteCareLog(log, pet: pet, context: context)
        revisionCenter.publishPetCareDelete(result, note: note)
        return result
    }

    @discardableResult
    func deletePottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        note: String
    ) -> PetPottyDeleteCommandResult {
        let result = PetPottyCommandService.deletePottyLog(log, pet: pet, context: context)
        revisionCenter.publishPetPottyDelete(result, note: note)
        return result
    }

    @discardableResult
    func recordCatCare(
        pet: Pet,
        input: CatCareCommandInput,
        note: String = "catCare.record"
    ) -> CatCareCommandResult {
        let result = CatCareCommandService.record(pet: pet, input: input, context: context)
        revisionCenter.publishCatCareRecord(result, note: note)
        return result
    }

    @discardableResult
    func undoCatCare(
        pet: Pet,
        eventID: UUID,
        hygieneLogID: UUID?,
        note: String = "catCare.undo"
    ) -> CatCareUndoCommandResult {
        let result = CatCareCommandService.undo(
            pet: pet,
            eventID: eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )
        revisionCenter.publishCatCareUndo(result, note: note)
        return result
    }
}

struct PetHealthRecordCommandInput: Equatable {
    let type: HealthLogType
    let date: Date
    let name: String
    let note: String
    let vetName: String
    let cost: Double
    let expirationDate: Date?
    let nextCheckupDate: Date?
    let executorId: String?
    let source: CareLedgerSource
    let includesNameInNote: Bool
    let expirationReminderLeadDays: Int?

    init(
        type: HealthLogType,
        date: Date,
        name: String,
        note: String,
        vetName: String,
        cost: Double,
        expirationDate: Date?,
        nextCheckupDate: Date?,
        executorId: String?,
        source: CareLedgerSource,
        includesNameInNote: Bool,
        expirationReminderLeadDays: Int? = nil
    ) {
        self.type = type
        self.date = date
        self.name = name
        self.note = note
        self.vetName = vetName
        self.cost = max(0, cost.isFinite ? cost : 0)
        self.expirationDate = expirationDate
        self.nextCheckupDate = nextCheckupDate
        self.executorId = executorId
        self.source = source
        self.includesNameInNote = includesNameInNote
        self.expirationReminderLeadDays = expirationReminderLeadDays.map { max(0, $0) }
    }

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var composedNote: String {
        guard includesNameInNote else { return cleanNote }
        guard !cleanName.isEmpty else { return cleanNote }
        return cleanNote.isEmpty ? cleanName : "\(cleanName) - \(cleanNote)"
    }

    var recordName: String {
        cleanName.isEmpty ? type.rawValue : cleanName
    }
}

struct PetHealthCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let expenseLogID: UUID?
    let eventID: UUID?
    let reminderID: UUID?
    let coconutDelta: Int
}

enum PetHealthCommandService {
    @discardableResult
    @MainActor
    static func recordHealth(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext,
        awardsReward: Bool = true,
        schedulesReminderNotification: Bool = true
    ) -> PetHealthCommandResult {
        let log = PetHealthLog(
            date: input.date,
            type: input.type,
            note: input.composedNote,
            pet: pet,
            executorId: input.executorId
        )
        log.vetName = input.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        log.cost = input.cost
        log.expirationDate = input.expirationDate
        log.nextCheckupDate = input.nextCheckupDate
        context.insert(log)

        let expense = makeExpenseIfNeeded(
            pet: pet,
            input: input,
            context: context
        )
        let event = makeExpirationEventIfNeeded(
            pet: pet,
            input: input,
            context: context
        )
        let reminder = makeExpirationReminderIfNeeded(
            event: event,
            input: input,
            context: context
        )

        let reward = awardsReward
            ? CoconutEconomyService.awardCareAction(type: .health, pet: pet, context: context)
            : (humanGot: 0, petGot: 0)
        let coconutDelta = CareLedgerService.rewardDelta(reward)

        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: input.executorId == nil ? .unknown : .human,
            actorId: input.executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: input.type.rawValue,
            amountValue: input.cost,
            amountUnit: input.cost > 0 ? "currency" : "",
            note: log.note,
            source: input.source,
            sourceEventId: event?.id.uuidString,
            legacyModelName: "PetHealthLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context,
            save: false
        )

        if let expense {
            CareLedgerService.record(
                occurredAt: expense.date,
                actorKind: input.executorId == nil ? .unknown : .human,
                actorId: input.executorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .expense,
                actionType: ExpenseCategory.medical.rawValue,
                amountValue: expense.amount,
                amountUnit: "currency",
                note: expense.note,
                source: input.source,
                legacyModelName: "PetExpenseLog",
                legacyModelId: expense.id.uuidString,
                context: context,
                save: false
            )
        }

        context.safeSave()
        if schedulesReminderNotification, let reminder {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: input.source
                )
            }
        }
        return PetHealthCommandResult(
            logID: log.id,
            subjectID: pet.id,
            expenseLogID: expense?.id,
            eventID: event?.id,
            reminderID: reminder?.id,
            coconutDelta: coconutDelta
        )
    }

    @MainActor
    private static func makeExpenseIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> PetExpenseLog? {
        guard input.cost > 0 else { return nil }
        let expense = PetExpenseLog(
            date: input.date,
            amount: input.cost,
            category: .medical,
            note: input.recordName,
            pet: pet,
            executorId: input.executorId
        )
        context.insert(expense)
        return expense
    }

    @MainActor
    private static func makeExpirationEventIfNeeded(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> Event? {
        guard let dueDate = input.expirationDate,
              let eventType = expirationEventType(for: input.type)
        else { return nil }
        let event = Event(
            title: "\(eventType.emoji) \(pet.name) · \(input.recordName)到期提醒",
            startDate: dueDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)
        return event
    }

    @MainActor
    private static func makeExpirationReminderIfNeeded(
        event: Event?,
        input: PetHealthRecordCommandInput,
        context: ModelContext
    ) -> Reminder? {
        guard let event,
              let dueDate = input.expirationDate,
              let leadDays = input.expirationReminderLeadDays
        else { return nil }

        let scheduledAt = Calendar.current.date(
            byAdding: .day,
            value: -leadDays,
            to: dueDate
        ) ?? dueDate
        guard scheduledAt > Date() else { return nil }

        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        reminder.statusEnum = .pending
        context.insert(reminder)
        return reminder
    }

    private static func expirationEventType(for type: HealthLogType) -> EventType? {
        switch type {
        case .vaccine:
            return .vaccine
        case .dewormingInternal:
            return .internalDeworming
        case .dewormingExternal:
            return .externalDeworming
        default:
            return nil
        }
    }
}

struct PetSymptomCommandInput: Equatable {
    let date: Date
    let category: SymptomCategory
    let symptomName: String
    let severity: SymptomSeverity
    let note: String
    let photoData: Data?

    var cleanSymptomName: String {
        symptomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetSymptomCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let ledgerEventID: UUID
}

enum PetSymptomCommandService {
    @discardableResult
    @MainActor
    static func recordSymptom(
        pet: Pet,
        input: PetSymptomCommandInput,
        context: ModelContext
    ) -> PetSymptomCommandResult? {
        guard !input.cleanSymptomName.isEmpty else { return nil }

        let log = SymptomLog(
            date: input.date,
            category: input.category,
            symptomName: input.cleanSymptomName,
            severity: input.severity,
            note: input.cleanNote,
            photoData: input.photoData,
            pet: pet
        )
        context.insert(log)

        let ledgerEvent = CareLedgerService.record(
            occurredAt: log.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "symptom",
            note: log.symptomName,
            source: .detail,
            legacyModelName: "SymptomLog",
            legacyModelId: log.id.uuidString,
            context: context,
            save: false
        )
        context.safeSave()

        return PetSymptomCommandResult(
            logID: log.id,
            subjectID: pet.id,
            ledgerEventID: ledgerEvent.id
        )
    }
}

struct PetHealthDeleteResult: Equatable {
    let subjectID: UUID
    let recordID: UUID
    let kind: String
    let didDelete: Bool
}

enum PetHealthDeleteCommandService {
    @discardableResult
    @MainActor
    static func deleteHealthLog(
        _ log: PetHealthLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "health",
            didDelete: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteSymptomLog(
        _ log: SymptomLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "symptom",
            didDelete: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteHeatCycleLog(
        _ log: HeatCycleLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHealthDeleteResult {
        let recordID = log.id
        context.delete(log)
        context.safeSave()
        return PetHealthDeleteResult(
            subjectID: pet.id,
            recordID: recordID,
            kind: "heat",
            didDelete: true
        )
    }
}

@MainActor
struct PetHealthCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordHealth(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        awardsReward: Bool = true,
        schedulesReminderNotification: Bool = true,
        note: String
    ) -> PetHealthCommandResult {
        let result = PetHealthCommandService.recordHealth(
            pet: pet,
            input: input,
            context: context,
            awardsReward: awardsReward,
            schedulesReminderNotification: schedulesReminderNotification
        )
        revisionCenter.publishPetHealthRecord(result, type: input.type.rawValue, note: note)
        return result
    }

    @discardableResult
    func recordSymptom(
        pet: Pet,
        input: PetSymptomCommandInput,
        note: String,
        emptyNote: String = "pet.symptom.empty"
    ) -> PetSymptomCommandResult? {
        guard let result = PetSymptomCommandService.recordSymptom(pet: pet, input: input, context: context) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .petHealthRecord(petID: pet.id, type: "symptom"),
                    affectedEntityIDs: [pet.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishPetSymptom(result, note: note)
        return result
    }

    @discardableResult
    func recordHeatCycle(
        pet: Pet,
        input: PetHeatCycleCommandInput,
        note: String
    ) -> PetHeatCycleCommandResult {
        let result = PetHeatCycleCommandService.recordHeatCycle(pet: pet, input: input, context: context)
        revisionCenter.publishPetHeatCycle(result, note: note)
        return result
    }

    @discardableResult
    func deleteHealthLog(_ log: PetHealthLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHealthLog(log, pet: pet, context: context)
        revisionCenter.publishPetHealthDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteSymptomLog(_ log: SymptomLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteSymptomLog(log, pet: pet, context: context)
        revisionCenter.publishPetHealthDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHeatCycleLog(_ log: HeatCycleLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHeatCycleLog(log, pet: pet, context: context)
        revisionCenter.publishPetHealthDelete(result, note: note)
        return result
    }
}

struct InsuranceClaimCommandInput: Equatable {
    let claimDate: Date
    let incidentDate: Date
    let totalExpense: Double
    let claimedAmount: Double
    let status: ClaimStatus
    let note: String
    let executorId: String?
    let relatedExpenseLogId: String?
    let approvedAt: Date?

    init(
        claimDate: Date = Date(),
        incidentDate: Date,
        totalExpense: Double,
        claimedAmount: Double,
        status: ClaimStatus,
        note: String,
        executorId: String?,
        relatedExpenseLogId: String? = nil,
        approvedAt: Date? = nil
    ) {
        self.claimDate = claimDate
        self.incidentDate = incidentDate
        self.totalExpense = max(0, totalExpense.isFinite ? totalExpense : 0)
        self.claimedAmount = max(0, claimedAmount.isFinite ? claimedAmount : 0)
        self.status = status
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.executorId = executorId
        self.relatedExpenseLogId = relatedExpenseLogId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.approvedAt = approvedAt
    }
}

struct InsurancePolicySaveCommandInput: Equatable {
    let companyName: String
    let policyNumber: String
    let productName: String
    let annualPremium: Double
    let coverageAmount: Double
    let startDate: Date
    let renewalDate: Date
    let notes: String
    let paymentFrequency: InsurancePaymentFrequency
    let paymentDayOfMonth: Int
    let showInCalendar: Bool
    let otherFeeAmount: Double
    let otherFeeNote: String
    let autoGeneratesPayments: Bool
    let executorId: String?

    init(
        companyName: String,
        policyNumber: String,
        productName: String,
        annualPremium: Double,
        coverageAmount: Double,
        startDate: Date,
        renewalDate: Date,
        notes: String,
        paymentFrequency: InsurancePaymentFrequency,
        paymentDayOfMonth: Int,
        showInCalendar: Bool,
        otherFeeAmount: Double,
        otherFeeNote: String,
        autoGeneratesPayments: Bool,
        executorId: String?
    ) {
        self.companyName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.policyNumber = policyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.annualPremium = max(0, annualPremium.isFinite ? annualPremium : 0)
        self.coverageAmount = max(0, coverageAmount.isFinite ? coverageAmount : 0)
        self.startDate = startDate
        self.renewalDate = renewalDate
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.paymentFrequency = paymentFrequency
        self.paymentDayOfMonth = max(1, min(28, paymentDayOfMonth))
        self.showInCalendar = showInCalendar
        self.otherFeeAmount = max(0, otherFeeAmount.isFinite ? otherFeeAmount : 0)
        self.otherFeeNote = otherFeeNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.autoGeneratesPayments = autoGeneratesPayments
        self.executorId = executorId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

struct InsurancePolicyCommandResult: Equatable {
    let policyID: UUID
    let petID: UUID
    let didChange: Bool
    let expenseLogIDs: [UUID]
    let eventIDs: [UUID]

    init(
        policyID: UUID,
        petID: UUID,
        didChange: Bool,
        expenseLogIDs: [UUID] = [],
        eventIDs: [UUID] = []
    ) {
        self.policyID = policyID
        self.petID = petID
        self.didChange = didChange
        self.expenseLogIDs = expenseLogIDs
        self.eventIDs = eventIDs
    }
}

struct InsuranceClaimCommandResult: Equatable {
    let claimID: UUID
    let policyID: UUID
    let petID: UUID
    let expenseLogID: UUID?
    let didChange: Bool
}

enum InsurancePolicyCommandService {
    @discardableResult
    @MainActor
    static func savePolicy(
        existing insurance: PetInsurance?,
        pet: Pet,
        input: InsurancePolicySaveCommandInput,
        context: ModelContext
    ) -> InsurancePolicyCommandResult {
        if let insurance {
            apply(input, to: insurance)
            context.safeSave()
            return InsurancePolicyCommandResult(
                policyID: insurance.id,
                petID: pet.id,
                didChange: true
            )
        }

        let insurance = PetInsurance(
            companyName: input.companyName,
            policyNumber: input.policyNumber,
            productName: input.productName,
            annualPremium: input.annualPremium,
            coverageAmount: input.coverageAmount,
            startDate: input.startDate,
            renewalDate: input.renewalDate,
            notes: input.notes,
            paymentFrequency: input.paymentFrequency,
            paymentDayOfMonth: input.paymentDayOfMonth,
            showInCalendar: input.showInCalendar,
            otherFeeAmount: input.otherFeeAmount,
            otherFeeNote: input.otherFeeNote,
            pet: pet
        )
        context.insert(insurance)

        let schedule = input.autoGeneratesPayments && input.annualPremium > 0
            ? generatePaymentSchedule(for: insurance, pet: pet, executorId: input.executorId, context: context)
            : (expenses: [], events: [])
        context.safeSave()
        return InsurancePolicyCommandResult(
            policyID: insurance.id,
            petID: pet.id,
            didChange: true,
            expenseLogIDs: schedule.expenses.map(\.id),
            eventIDs: schedule.events.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    static func setPolicyActive(
        _ insurance: PetInsurance,
        isActive: Bool,
        pet: Pet,
        context: ModelContext
    ) -> InsurancePolicyCommandResult {
        let didChange = insurance.isActive != isActive
        insurance.isActive = isActive
        context.safeSave()
        return InsurancePolicyCommandResult(
            policyID: insurance.id,
            petID: pet.id,
            didChange: didChange
        )
    }

    @discardableResult
    @MainActor
    static func deletePolicy(
        _ insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) -> InsurancePolicyCommandResult {
        let policyID = insurance.id
        let petID = pet.id
        context.delete(insurance)
        context.safeSave()
        return InsurancePolicyCommandResult(
            policyID: policyID,
            petID: petID,
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func createClaim(
        insurance: PetInsurance,
        pet: Pet,
        input: InsuranceClaimCommandInput,
        context: ModelContext
    ) -> InsuranceClaimCommandResult {
        let approvedAmount = input.status == .approved ? input.claimedAmount : 0
        let approvedAt = input.status == .approved ? (input.approvedAt ?? input.claimDate) : nil
        let claim = InsuranceClaim(
            claimDate: input.claimDate,
            incidentDate: input.incidentDate,
            totalExpense: input.totalExpense,
            claimedAmount: input.claimedAmount,
            approvedAmount: approvedAmount,
            status: input.status,
            note: input.note,
            relatedExpenseLogId: input.relatedExpenseLogId,
            insurance: insurance
        )
        claim.approvedAt = approvedAt
        context.insert(claim)

        let expense = makeReimbursementExpenseIfNeeded(
            insurance: insurance,
            pet: pet,
            amount: approvedAmount,
            approvedDate: approvedAt ?? input.claimDate,
            executorId: input.executorId,
            context: context
        )

        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expense?.id,
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func updateClaimStatus(
        _ claim: InsuranceClaim,
        to status: ClaimStatus,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext,
        approvedAt: Date = Date(),
        executorId: String? = nil
    ) -> InsuranceClaimCommandResult {
        let oldStatus = claim.claimStatus
        let oldApprovedAmount = claim.approvedAmount
        claim.statusRaw = status.rawValue

        var expense: PetExpenseLog?
        if status == .approved, claim.approvedAmount == 0 {
            claim.approvedAmount = claim.claimedAmount
            claim.approvedAt = approvedAt
            expense = makeReimbursementExpenseIfNeeded(
                insurance: insurance,
                pet: pet,
                amount: claim.approvedAmount,
                approvedDate: approvedAt,
                executorId: executorId,
                context: context
            )
        }

        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expense?.id,
            didChange: oldStatus != status || oldApprovedAmount != claim.approvedAmount
        )
    }

    @discardableResult
    @MainActor
    static func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) -> InsuranceClaimCommandResult {
        let claimID = claim.id
        context.delete(claim)
        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claimID,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: nil,
            didChange: true
        )
    }

    @MainActor
    private static func makeReimbursementExpenseIfNeeded(
        insurance: PetInsurance,
        pet: Pet,
        amount: Double,
        approvedDate: Date,
        executorId: String?,
        context: ModelContext
    ) -> PetExpenseLog? {
        guard amount > 0 else { return nil }
        let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: productName)
        guard InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: pet.expenseLogs,
            date: approvedDate,
            amount: amount,
            note: note
        ) else { return nil }

        let expense = PetExpenseLog(
            date: approvedDate,
            amount: -amount,
            category: .insurancePremium,
            note: note,
            pet: pet,
            executorId: executorId
        )
        context.insert(expense)
        return expense
    }

    @MainActor
    private static func apply(_ input: InsurancePolicySaveCommandInput, to insurance: PetInsurance) {
        insurance.companyName = input.companyName
        insurance.policyNumber = input.policyNumber
        insurance.productName = input.productName
        insurance.annualPremium = input.annualPremium
        insurance.coverageAmount = input.coverageAmount
        insurance.startDate = input.startDate
        insurance.renewalDate = input.renewalDate
        insurance.notes = input.notes
        insurance.paymentFrequencyRaw = input.paymentFrequency.rawValue
        insurance.paymentDayOfMonth = input.paymentDayOfMonth
        insurance.showInCalendar = input.showInCalendar
        insurance.otherFeeAmount = input.otherFeeAmount
        insurance.otherFeeNote = input.otherFeeNote
    }

    @discardableResult
    @MainActor
    private static func generatePaymentSchedule(
        for insurance: PetInsurance,
        pet: Pet,
        executorId: String?,
        context: ModelContext
    ) -> (expenses: [PetExpenseLog], events: [Event]) {
        let dates = InsurancePaymentSchedule.dates(for: insurance, calendar: .current)
        let name = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let perPeriodBase = insurance.paymentFrequency.periodAmount(fromAnnual: insurance.annualPremium)
        let perPeriod = perPeriodBase + insurance.otherFeeAmount
        var expenses: [PetExpenseLog] = []
        var events: [Event] = []

        for (index, payDate) in dates.enumerated() {
            let otherNote = insurance.otherFeeNote.isEmpty ? "其他费用" : insurance.otherFeeNote
            let expNote = index == 0
                ? "\(name) 首期保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
                : "\(name) 保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
            let expense = PetExpenseLog(
                date: payDate,
                amount: perPeriod,
                category: .insurancePremium,
                note: expNote,
                pet: pet,
                executorId: executorId
            )
            context.insert(expense)
            expenses.append(expense)

            if insurance.showInCalendar {
                let event = Event(
                    title: "🛡️ \(name) 缴费",
                    startDate: payDate,
                    isAllDay: true,
                    eventType: EventType.insurancePremium.rawValue,
                    relatedEntityType: "pet_insurance",
                    relatedEntityId: insurance.id.uuidString
                )
                context.insert(event)
                events.append(event)
            }
        }
        return (expenses, events)
    }
}

@MainActor
struct InsuranceCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func savePolicy(
        existing insurance: PetInsurance?,
        pet: Pet,
        input: InsurancePolicySaveCommandInput,
        note: String
    ) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.savePolicy(
            existing: insurance,
            pet: pet,
            input: input,
            context: context
        )
        revisionCenter.publishInsurancePolicy(
            result,
            action: insurance == nil ? "create" : "update",
            note: note
        )
        return result
    }

    @discardableResult
    func setPolicyActive(
        _ insurance: PetInsurance,
        isActive: Bool,
        pet: Pet,
        note: String
    ) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.setPolicyActive(
            insurance,
            isActive: isActive,
            pet: pet,
            context: context
        )
        revisionCenter.publishInsurancePolicy(
            result,
            action: isActive ? "activate" : "deactivate",
            note: note
        )
        return result
    }

    @discardableResult
    func deletePolicy(_ insurance: PetInsurance, pet: Pet, note: String) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.deletePolicy(insurance, pet: pet, context: context)
        revisionCenter.publishInsurancePolicy(result, action: "delete", note: note)
        return result
    }

    @discardableResult
    func createClaim(
        insurance: PetInsurance,
        pet: Pet,
        input: InsuranceClaimCommandInput,
        note: String
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.createClaim(
            insurance: insurance,
            pet: pet,
            input: input,
            context: context
        )
        revisionCenter.publishInsuranceClaim(result, action: "create", note: note)
        return result
    }

    @discardableResult
    func updateClaimStatus(
        _ claim: InsuranceClaim,
        to status: ClaimStatus,
        insurance: PetInsurance,
        pet: Pet,
        executorId: String?,
        note: String
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: status,
            insurance: insurance,
            pet: pet,
            context: context,
            executorId: executorId
        )
        revisionCenter.publishInsuranceClaim(result, action: "status.\(status.rawValue)", note: note)
        return result
    }

    @discardableResult
    func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        note: String
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.deleteClaim(
            claim,
            insurance: insurance,
            pet: pet,
            context: context
        )
        revisionCenter.publishInsuranceClaim(result, action: "delete", note: note)
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct PetHygienePlanCommandInput: Equatable {
    let startDate: Date
    let isAllDay: Bool
    let startTime: Date
    let hasEndDate: Bool
    let endDate: Date
    let repeatDays: Int
    let customNote: String

    init(
        startDate: Date,
        isAllDay: Bool,
        startTime: Date,
        hasEndDate: Bool,
        endDate: Date,
        repeatDays: Int,
        customNote: String
    ) {
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.hasEndDate = hasEndDate
        self.endDate = endDate
        self.repeatDays = max(0, repeatDays)
        self.customNote = customNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetHygieneCheckInCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let hygieneType: HygieneType
    let coconutDelta: Int
}

struct PetHygieneDeleteCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let didDelete: Bool
    let removedLedgerEventIDs: [UUID]
}

struct PetHygienePlanCommandResult: Equatable {
    let eventID: UUID
    let reminderID: UUID
    let subjectID: UUID
    let hygieneType: HygieneType
}

enum PetHygieneCommandService {
    @discardableResult
    @MainActor
    static func record(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> (result: PetHygieneCheckInCommandResult, log: PetHygieneLog) {
        let recorded = CareEventService.recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
        return (
            PetHygieneCheckInCommandResult(
                logID: recorded.result.logID,
                subjectID: recorded.result.subjectID,
                hygieneType: recorded.result.hygieneType,
                coconutDelta: recorded.result.coconutDelta
            ),
            recorded.log
        )
    }

    @discardableResult
    @MainActor
    static func delete(
        _ log: PetHygieneLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHygieneDeleteCommandResult {
        let logID = log.id
        let ledgerEvents = ledgerEvents(for: logID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(log)
        context.safeSave()
        return PetHygieneDeleteCommandResult(
            logID: logID,
            subjectID: pet.id,
            didDelete: true,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(for logID: UUID, context: ModelContext) -> [CareLedgerEvent] {
        let idString = logID.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == idString }
    }

    @discardableResult
    @MainActor
    static func createPlan(
        pet: Pet,
        type: HygieneType,
        input: PetHygienePlanCommandInput,
        context: ModelContext,
        scheduleNotification: Bool = true
    ) -> PetHygienePlanCommandResult {
        let calendar = Calendar.current
        let title = "\(pet.name) — \(type.rawValue)"
        let fullTitle = input.customNote.isEmpty ? title : "\(title) — \(input.customNote)"

        let dayStart = calendar.startOfDay(for: input.startDate)
        let time = calendar.dateComponents([.hour, .minute], from: input.startTime)
        let eventStart = input.isAllDay
            ? dayStart
            : (calendar.date(
                bySettingHour: time.hour ?? 9,
                minute: time.minute ?? 0,
                second: 0,
                of: dayStart
            ) ?? dayStart)
        let reminderTime = input.isAllDay
            ? (calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart)
            : eventStart

        let eventEndDate: Date?
        if input.hasEndDate {
            let endDay = calendar.startOfDay(for: input.endDate)
            eventEndDate = input.isAllDay
                ? endDay
                : (calendar.date(
                    bySettingHour: time.hour ?? 9,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: endDay
                ) ?? endDay)
        } else {
            eventEndDate = nil
        }

        let event = Event(
            title: fullTitle,
            startDate: eventStart,
            endDate: eventEndDate,
            isAllDay: input.isAllDay,
            eventType: EventType.grooming.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = input.repeatDays
        if input.hasEndDate {
            event.recurrenceEndDate = calendar.startOfDay(for: input.endDate)
        } else if input.repeatDays > 0 {
            event.recurrenceEndDate = calendar.date(byAdding: .year, value: 1, to: dayStart)
        }

        if input.repeatDays > 0 {
            CarePlanCalendarSync.suppressDefaultPlan(kind: "groom", pet: pet, context: context)
            HygieneType.setCustomCycleDays(input.repeatDays, for: type, petId: pet.id)
        }
        context.insert(event)

        let reminder = Reminder(event: event, scheduledAt: reminderTime)
        reminder.statusEnum = .pending
        context.insert(reminder)
        context.safeSave()

        if scheduleNotification {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: .detail
                )
            }
        }

        return PetHygienePlanCommandResult(
            eventID: event.id,
            reminderID: reminder.id,
            subjectID: pet.id,
            hygieneType: type
        )
    }
}

@MainActor
struct PetHygieneCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func record(
        pet: Pet,
        type: HygieneType,
        executorId: String?,
        date: Date = Date(),
        note: String
    ) -> (result: PetHygieneCheckInCommandResult, log: PetHygieneLog) {
        let recorded = PetHygieneCommandService.record(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
        revisionCenter.publishPetHygieneRecord(recorded.result, note: note)
        return recorded
    }

    @discardableResult
    func delete(
        _ log: PetHygieneLog,
        pet: Pet,
        note: String
    ) -> PetHygieneDeleteCommandResult {
        let result = PetHygieneCommandService.delete(log, pet: pet, context: context)
        revisionCenter.publishPetHygieneDelete(result, note: note)
        return result
    }

    @discardableResult
    func createPlan(
        pet: Pet,
        type: HygieneType,
        input: PetHygienePlanCommandInput,
        scheduleNotification: Bool = true,
        note: String
    ) -> PetHygienePlanCommandResult {
        let result = PetHygieneCommandService.createPlan(
            pet: pet,
            type: type,
            input: input,
            context: context,
            scheduleNotification: scheduleNotification
        )
        revisionCenter.publishPetHygienePlan(result, note: note)
        return result
    }
}

struct TodayFocusEventCompletionCommandResult: Equatable {
    let eventID: UUID
    let isCompleted: Bool
    let didChange: Bool
}

enum TodayFocusCommandService {
    @discardableResult
    @MainActor
    static func completeEvent(
        _ event: Event,
        on date: Date,
        context: ModelContext
    ) -> TodayFocusEventCompletionCommandResult {
        let wasOccurrenceComplete = event.isOccurrenceMarkedComplete(on: date)
        let wasCompleted = event.isCompleted

        event.setOccurrenceMarkedComplete(true, on: date)
        if event.recurrenceDays <= 0 {
            event.isCompleted = true
        }
        context.safeSave()

        return TodayFocusEventCompletionCommandResult(
            eventID: event.id,
            isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: date),
            didChange: !wasOccurrenceComplete || wasCompleted != event.isCompleted
        )
    }
}

struct PlantCareCommandResult: Equatable {
    let plantID: UUID
    let logID: UUID
    let eventID: UUID
    let ledgerEventID: UUID
    let careType: PlantCareType
}

enum PlantCareCommandService {
    @discardableResult
    @MainActor
    static func recordCare(
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        context: ModelContext,
        now: Date = Date()
    ) -> PlantCareCommandResult {
        switch type {
        case .watering:
            plant.lastWateredDate = now
        case .fertilizing:
            plant.lastFertilizedDate = now
        }

        let log = PlantCareLog(date: now, careType: type, executorId: executorId)
        log.plant = plant
        context.insert(log)

        let event = Event(
            title: "\(type.emoji) 给 \(plant.name)\(type.displayName)",
            startDate: now,
            isAllDay: false,
            eventType: type == .watering ? EventType.watering.rawValue : EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        event.assigneeId = executorId
        context.insert(event)

        let ledgerEvent = CareLedgerService.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: type.rawValue,
            note: log.note,
            source: .detail,
            sourceEventId: event.id.uuidString,
            legacyModelName: "PlantCareLog",
            legacyModelId: log.id.uuidString,
            context: context,
            save: false
        )
        context.safeSave()

        return PlantCareCommandResult(
            plantID: plant.id,
            logID: log.id,
            eventID: event.id,
            ledgerEventID: ledgerEvent.id,
            careType: type
        )
    }
}

struct PlantCreationCommandInput: Equatable {
    let id: UUID
    let name: String
    let species: String
    let location: String
    let avatarEmoji: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        location: String,
        avatarEmoji: String,
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
    }
}

struct PlantCreationCommandResult: Equatable {
    let plantID: UUID
    let kind: String
}

enum PlantCreationCommandService {
    @discardableResult
    @MainActor
    static func createPlant(
        input: PlantCreationCommandInput,
        context: ModelContext
    ) -> PlantCreationCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let plant = Plant(
            name: trimmedName.isEmpty ? "Plant" : trimmedName,
            species: input.species.trimmingCharacters(in: .whitespacesAndNewlines),
            location: input.location.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarEmoji: input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "🌱"
                : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            wateringIntervalDays: input.wateringIntervalDays,
            fertilizingIntervalDays: input.fertilizingIntervalDays
        )
        plant.id = input.id
        context.insert(plant)
        context.safeSave()

        return PlantCreationCommandResult(
            plantID: plant.id,
            kind: EntityKind.plant.rawValue
        )
    }
}

@MainActor
struct PlantCreationCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createPlant(
        input: PlantCreationCommandInput,
        note: String
    ) -> PlantCreationCommandResult {
        let result = PlantCreationCommandService.createPlant(input: input, context: context)
        revisionCenter.publishMemberCreation(result, note: note)
        return result
    }
}

struct PetHeatCycleCommandInput: Equatable {
    let startDate: Date
    let endDate: Date?
    let status: HeatCycleStatus
    let note: String
    let isMated: Bool
    let expectedDeliveryDate: Date?
}

struct PetHeatCycleCommandResult: Equatable {
    let subjectID: UUID
    let logID: UUID
    let status: HeatCycleStatus
}

enum PetHeatCycleCommandService {
    @discardableResult
    @MainActor
    static func recordHeatCycle(
        pet: Pet,
        input: PetHeatCycleCommandInput,
        context: ModelContext
    ) -> PetHeatCycleCommandResult {
        let log = HeatCycleLog(
            startDate: input.startDate,
            endDate: input.endDate,
            status: input.status,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            isMated: input.isMated,
            expectedDeliveryDate: input.expectedDeliveryDate,
            pet: pet
        )
        context.insert(log)
        context.safeSave()

        return PetHeatCycleCommandResult(
            subjectID: pet.id,
            logID: log.id,
            status: input.status
        )
    }
}

struct MemberDeletionCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let removedRelatedEventIDs: [UUID]
    let removedQuickActionCount: Int
    let requiresReplacementHuman: Bool
    let requiresAccountSwitch: Bool
    let clearsActiveHumanID: Bool
}

struct PetProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String?
    let species: String
    let breed: String
    let gender: String
    let isNeutered: Bool
    let birthday: Date?
    let homeDate: Date?
    let themeHex: String
    let notes: String
    let coatColor: String?
    let eyeColor: String?
    let microchipID: String?
    let vetContact: String?
    let vetClinicName: String?
    let vetDoctorName: String?
    let vetAddress: String?
    let allergies: String?
    let passportNumber: String?
    let hasPassportExpiry: Bool?
    let passportExpiryDate: Date?
    let formerName: String?
    let birthCountry: String?
    let birthCity: String?
    let lineageInfo: String?
    let foodBrand: String?
    let dailyPortionGrams: Double?

    init(
        name: String,
        avatarImageData: Data?,
        avatarEmoji: String? = nil,
        species: String,
        breed: String,
        gender: String,
        isNeutered: Bool,
        birthday: Date?,
        homeDate: Date?,
        themeHex: String,
        notes: String,
        coatColor: String? = nil,
        eyeColor: String? = nil,
        microchipID: String? = nil,
        vetContact: String? = nil,
        vetClinicName: String? = nil,
        vetDoctorName: String? = nil,
        vetAddress: String? = nil,
        allergies: String? = nil,
        passportNumber: String? = nil,
        hasPassportExpiry: Bool? = nil,
        passportExpiryDate: Date? = nil,
        formerName: String? = nil,
        birthCountry: String? = nil,
        birthCity: String? = nil,
        lineageInfo: String? = nil,
        foodBrand: String? = nil,
        dailyPortionGrams: Double? = nil
    ) {
        self.name = name
        self.avatarImageData = avatarImageData
        self.avatarEmoji = avatarEmoji
        self.species = species
        self.breed = breed
        self.gender = gender
        self.isNeutered = isNeutered
        self.birthday = birthday
        self.homeDate = homeDate
        self.themeHex = themeHex
        self.notes = notes
        self.coatColor = coatColor
        self.eyeColor = eyeColor
        self.microchipID = microchipID
        self.vetContact = vetContact
        self.vetClinicName = vetClinicName
        self.vetDoctorName = vetDoctorName
        self.vetAddress = vetAddress
        self.allergies = allergies
        self.passportNumber = passportNumber
        self.hasPassportExpiry = hasPassportExpiry
        self.passportExpiryDate = passportExpiryDate
        self.formerName = formerName
        self.birthCountry = birthCountry
        self.birthCity = birthCity
        self.lineageInfo = lineageInfo
        self.foodBrand = foodBrand
        self.dailyPortionGrams = dailyPortionGrams
    }
}

struct HumanProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let role: String
    let gender: String
    let birthday: Date?
    let bloodType: String
    let heightText: String
    let mbti: String
    let nationality: String
    let city: String
    let themeHex: String
    let notes: String
    let preservedNoteParts: [String]
    let shouldShowOnHome: Bool?
    let privateFieldsRaw: Set<String>?

    init(
        name: String,
        avatarImageData: Data?,
        avatarEmoji: String,
        role: String,
        gender: String,
        birthday: Date?,
        bloodType: String,
        heightText: String,
        mbti: String,
        nationality: String,
        city: String,
        themeHex: String,
        notes: String,
        preservedNoteParts: [String],
        shouldShowOnHome: Bool? = nil,
        privateFieldsRaw: Set<String>? = nil
    ) {
        self.name = name
        self.avatarImageData = avatarImageData
        self.avatarEmoji = avatarEmoji
        self.role = role
        self.gender = gender
        self.birthday = birthday
        self.bloodType = bloodType
        self.heightText = heightText
        self.mbti = mbti
        self.nationality = nationality
        self.city = city
        self.themeHex = themeHex
        self.notes = notes
        self.preservedNoteParts = preservedNoteParts
        self.shouldShowOnHome = shouldShowOnHome
        self.privateFieldsRaw = privateFieldsRaw
    }
}

struct PlantProfileCommandInput: Equatable {
    let name: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let species: String
    let location: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let themeHex: String
    let notes: String
}

struct MemberProfileCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let changedFields: Set<String>
}

struct MemberLifecycleCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let action: String
}

struct MemberHomeVisibilityCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let visible: Bool
}

struct PetWalkGoalCommandResult: Equatable {
    let petID: UUID
    let goalKm: Double
}

struct PetWalkSummaryCommandResult: Equatable {
    let petID: UUID
    let walkID: UUID
    let moodRating: Int
    let hasNotes: Bool
}

enum MemberProfileCommandService {
    @discardableResult
    @MainActor
    static func updatePet(
        _ pet: Pet,
        input: PetProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.name = trimmedName.isEmpty ? pet.name : trimmedName
        pet.avatarImageData = input.avatarImageData
        if let avatarEmoji = input.avatarEmoji {
            let trimmedEmoji = avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
            pet.avatarEmoji = trimmedEmoji.isEmpty ? "🐾" : trimmedEmoji
        }
        pet.species = input.species
        pet.breed = input.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.gender = input.gender
        pet.isNeutered = input.isNeutered
        pet.birthday = input.birthday
        pet.homeDate = input.homeDate
        pet.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            input.themeHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        pet.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coatColor = input.coatColor {
            pet.coatColor = coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let eyeColor = input.eyeColor {
            pet.eyeColor = eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let microchipID = input.microchipID {
            pet.microchipID = microchipID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetContact = input.vetContact {
            pet.vetContact = vetContact.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetClinicName = input.vetClinicName {
            pet.vetClinicName = vetClinicName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetDoctorName = input.vetDoctorName {
            pet.vetDoctorName = vetDoctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let vetAddress = input.vetAddress {
            pet.vetAddress = vetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let allergies = input.allergies {
            pet.allergies = allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let passportNumber = input.passportNumber {
            pet.passportNumber = passportNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let hasPassportExpiry = input.hasPassportExpiry {
            pet.passportExpiryDate = hasPassportExpiry ? input.passportExpiryDate : nil
        }
        if let formerName = input.formerName {
            pet.formerName = formerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let birthCountry = input.birthCountry {
            pet.birthCountry = birthCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let birthCity = input.birthCity {
            pet.birthCity = birthCity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let lineageInfo = input.lineageInfo {
            pet.lineageInfo = lineageInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let foodBrand = input.foodBrand {
            pet.foodBrand = foodBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dailyPortionGrams = input.dailyPortionGrams {
            pet.dailyPortionGrams = max(0, dailyPortionGrams)
        }
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context)
        context.safeSave()

        var changedFields: Set<String> = [
            "name", "avatarImageData", "species", "breed", "gender",
            "isNeutered", "birthday", "homeDate", "themeColorHex", "notes"
        ]
        if input.avatarEmoji != nil { changedFields.insert("avatarEmoji") }
        if input.coatColor != nil { changedFields.insert("coatColor") }
        if input.eyeColor != nil { changedFields.insert("eyeColor") }
        if input.microchipID != nil { changedFields.insert("microchipID") }
        if input.vetContact != nil { changedFields.insert("vetContact") }
        if input.vetClinicName != nil { changedFields.insert("vetClinicName") }
        if input.vetDoctorName != nil { changedFields.insert("vetDoctorName") }
        if input.vetAddress != nil { changedFields.insert("vetAddress") }
        if input.allergies != nil { changedFields.insert("allergies") }
        if input.passportNumber != nil { changedFields.insert("passportNumber") }
        if input.hasPassportExpiry != nil { changedFields.insert("passportExpiryDate") }
        if input.formerName != nil { changedFields.insert("formerName") }
        if input.birthCountry != nil { changedFields.insert("birthCountry") }
        if input.birthCity != nil { changedFields.insert("birthCity") }
        if input.lineageInfo != nil { changedFields.insert("lineageInfo") }
        if input.foodBrand != nil { changedFields.insert("foodBrand") }
        if input.dailyPortionGrams != nil { changedFields.insert("dailyPortionGrams") }

        return MemberProfileCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            changedFields: changedFields
        )
    }

    @discardableResult
    @MainActor
    static func updateHuman(
        _ human: Human,
        input: HumanProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        human.name = trimmedName.isEmpty ? human.name : trimmedName
        human.avatarImageData = input.avatarImageData
        human.avatarEmoji = input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "👤"
            : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        human.role = HumanProfileOptions.normalizedRole(input.role)
        human.birthday = input.birthday
        human.bloodType = input.bloodType == "未填写" ? "" : input.bloodType
        human.heightCm = Double(input.heightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        human.mbti = input.mbti == "未填写" ? "" : input.mbti.uppercased()
        human.nationality = input.nationality.trimmingCharacters(in: .whitespacesAndNewlines)
        human.city = input.city.trimmingCharacters(in: .whitespacesAndNewlines)
        human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            input.themeHex,
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )

        var noteParts: [String] = []
        let normalizedGender = HumanProfileOptions.normalizedGender(input.gender)
        if !normalizedGender.isEmpty {
            noteParts.append("性别:\(normalizedGender)")
        }
        noteParts.append(contentsOf: input.preservedNoteParts)
        let trimmedNotes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            noteParts.append(trimmedNotes)
        }
        human.notes = noteParts.joined(separator: "｜")
        if let shouldShowOnHome = input.shouldShowOnHome {
            human.shouldShowOnHome = shouldShowOnHome
        }
        if let privateFieldsRaw = input.privateFieldsRaw {
            for field in HumanPrivateField.allCases {
                human.setPrivate(field, privateFieldsRaw.contains(field.rawValue))
            }
        }
        context.safeSave()

        var changedFields: Set<String> = [
            "name", "avatarImageData", "avatarEmoji", "role", "birthday",
            "bloodType", "heightCm", "mbti", "nationality", "city",
            "themeColorHex", "notes"
        ]
        if input.shouldShowOnHome != nil { changedFields.insert("shouldShowOnHome") }
        if input.privateFieldsRaw != nil { changedFields.insert("privateFields") }

        return MemberProfileCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            changedFields: changedFields
        )
    }

    @discardableResult
    @MainActor
    static func updatePlant(
        _ plant: Plant,
        input: PlantProfileCommandInput,
        context: ModelContext
    ) -> MemberProfileCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.name = trimmedName.isEmpty ? plant.name : trimmedName
        plant.avatarImageData = input.avatarImageData
        plant.avatarEmoji = input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "🌱"
            : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.species = input.species.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.location = input.location.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.wateringIntervalDays = input.wateringIntervalDays
        plant.fertilizingIntervalDays = input.fertilizingIntervalDays
        plant.themeColorHex = input.themeHex
        plant.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.safeSave()

        return MemberProfileCommandResult(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            changedFields: [
                "name", "avatarImageData", "avatarEmoji", "species", "location",
                "wateringIntervalDays", "fertilizingIntervalDays", "themeColorHex", "notes"
            ]
        )
    }
}

enum PetBondVaultUnlockFailure: Equatable {
    case alreadyUnlocked
    case insufficientBalance
}

struct PetBondVaultUnlockCommandResult: Equatable {
    let petID: UUID
    let itemID: String
    let cost: Int
    let didUnlock: Bool
    let failure: PetBondVaultUnlockFailure?
    let ledgerEventID: UUID?
}

struct PetCardAppearanceCommandResult: Equatable {
    let petID: UUID
    let action: String
}

enum Avatar2DUpgradeFailure: Equatable {
    case missingProfile
    case noPass
}

struct Avatar2DUpgradeCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let didUpgrade: Bool
    let failure: Avatar2DUpgradeFailure?
}

struct AchievementRewardClaim: Equatable {
    let badgeID: String
    let rewardKey: String
    let emoji: String
    let logTitle: String
    let isUnlocked: Bool
}

struct AchievementRewardCommandResult: Equatable {
    let entityID: UUID
    let entityKind: String
    let badgeIDs: [String]
    let totalAmount: Int
    let updatedClaimedRewardRaw: String
    let didClaim: Bool
}

enum AchievementRewardCommandService {
    @discardableResult
    @MainActor
    static func claimRewards(
        _ claims: [AchievementRewardClaim],
        claimedRewardRaw: String,
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) -> AchievementRewardCommandResult {
        let entityID = human?.id ?? pet.id
        let entityKind = human == nil ? EntityKind.pet.rawValue : EntityKind.human.rawValue
        var claimedIDs = Set(claimedRewardRaw.split(separator: ",").map(String.init))
        let claimable = claims.filter { claim in
            claim.isUnlocked && !claimedIDs.contains(claim.rewardKey)
        }
        guard amountPerBadge > 0, !claimable.isEmpty else {
            return AchievementRewardCommandResult(
                entityID: entityID,
                entityKind: entityKind,
                badgeIDs: claims.map(\.badgeID),
                totalAmount: 0,
                updatedClaimedRewardRaw: claimedRewardRaw,
                didClaim: false
            )
        }

        for claim in claimable {
            claimedIDs.insert(claim.rewardKey)
        }

        let totalAmount = claimable.count * amountPerBadge
        if let human {
            human.coconutBalance += totalAmount
        } else {
            pet.coconutBalance += totalAmount
        }

        let questManager = providedQuestManager ?? QuestManager.shared
        for claim in claimable {
            questManager.recordCoconutDelta(
                amountPerBadge,
                emoji: claim.emoji,
                title: claim.logTitle,
                actorId: entityID.uuidString,
                actorName: human?.name ?? pet.name
            )
        }
        let updatedRaw = claimedIDs.sorted().joined(separator: ",")
        UserDefaults.standard.set(updatedRaw, forKey: "achievement_claimedRewardIDs")
        context.safeSave()

        return AchievementRewardCommandResult(
            entityID: entityID,
            entityKind: entityKind,
            badgeIDs: claimable.map(\.badgeID),
            totalAmount: totalAmount,
            updatedClaimedRewardRaw: updatedRaw,
            didClaim: true
        )
    }
}

struct BackdateCheckInCommandResult: Equatable {
    let petID: UUID
    let humanID: UUID?
    let actionKey: String
    let humanGot: Int
    let petGot: Int

    var totalCoconuts: Int { humanGot + petGot }
    var didAward: Bool { totalCoconuts > 0 }
}

enum BackdateCheckInCommandService {
    @discardableResult
    @MainActor
    static func award(
        action: QuestManager.OhanaActionType,
        actionKey: String,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) -> BackdateCheckInCommandResult {
        let human = currentActiveHuman(context: context)
        let reward = (providedQuestManager ?? QuestManager.shared).awardAction(
            type: action,
            pet: pet,
            context: context
        )
        return BackdateCheckInCommandResult(
            petID: pet.id,
            humanID: human?.id,
            actionKey: actionKey,
            humanGot: reward.humanGot,
            petGot: reward.petGot
        )
    }

    @MainActor
    private static func currentActiveHuman(context: ModelContext) -> Human? {
        let activeID = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        guard !activeID.isEmpty else { return nil }
        return (try? context.fetch(FetchDescriptor<Human>()))?.first { $0.id.uuidString == activeID }
    }
}

enum ShopPurchaseFailure: Equatable {
    case missingActiveHuman
    case insufficientBalance(missing: Int)
}

struct ShopPurchaseCommandResult: Equatable {
    let humanID: UUID?
    let itemID: String
    let cost: Int
    let didPurchase: Bool
    let failure: ShopPurchaseFailure?
    let ledgerEventID: UUID?
}

enum ShopPurchaseCommandService {
    @discardableResult
    @MainActor
    static func purchase(
        item: ShopItem,
        buyer: Human?,
        itemName: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) -> ShopPurchaseCommandResult {
        guard item.cost > 0 else {
            return ShopPurchaseCommandResult(
                humanID: buyer?.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: true,
                failure: nil,
                ledgerEventID: nil
            )
        }
        guard let buyer else {
            return ShopPurchaseCommandResult(
                humanID: nil,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .missingActiveHuman,
                ledgerEventID: nil
            )
        }
        guard buyer.coconutBalance >= item.cost else {
            return ShopPurchaseCommandResult(
                humanID: buyer.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .insufficientBalance(missing: item.cost - buyer.coconutBalance),
                ledgerEventID: nil
            )
        }

        buyer.coconutBalance -= item.cost
        let questManager = providedQuestManager ?? QuestManager.shared
        questManager.recordCoconutDelta(
            -item.cost,
            emoji: item.emoji,
            title: itemName,
            actorId: buyer.id.uuidString,
            actorName: buyer.name
        )
        let ledger = CareLedgerService.record(
            actorKind: .human,
            actorId: buyer.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "shopPurchase",
            note: itemName,
            source: .economy,
            coconutDelta: -item.cost,
            metadataJSON: "{\"shopItemId\":\"\(item.id)\"}",
            context: context,
            save: false
        )
        context.safeSave()

        return ShopPurchaseCommandResult(
            humanID: buyer.id,
            itemID: item.id,
            cost: item.cost,
            didPurchase: true,
            failure: nil,
            ledgerEventID: ledger.id
        )
    }
}

enum PetBondVaultUnlockCommandService {
    @discardableResult
    @MainActor
    static func unlock(
        item: PetBondVaultItem,
        pet: Pet,
        title: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) -> PetBondVaultUnlockCommandResult {
        guard !PetBondVaultStore.isUnlocked(item.kind, for: pet.id) else {
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: .alreadyUnlocked,
                ledgerEventID: nil
            )
        }
        guard pet.coconutBalance >= item.cost else {
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: .insufficientBalance,
                ledgerEventID: nil
            )
        }

        pet.coconutBalance -= item.cost
        PetBondVaultStore.unlock(item.kind, for: pet.id)
        let questManager = providedQuestManager ?? QuestManager.shared
        questManager.recordCoconutDelta(
            -item.cost,
            emoji: "🐾",
            title: title,
            actorId: pet.id.uuidString,
            actorName: pet.name
        )
        let ledger = CareLedgerService.record(
            actorKind: .pet,
            actorId: pet.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .coconut,
            actionType: "petBondVaultUnlock",
            note: title,
            source: .economy,
            coconutDelta: -item.cost,
            metadataJSON: "{\"itemId\":\"\(item.id)\",\"economy\":\"petBondVault\"}",
            context: context,
            save: false
        )
        context.safeSave()

        return PetBondVaultUnlockCommandResult(
            petID: pet.id,
            itemID: item.id,
            cost: item.cost,
            didUnlock: true,
            failure: nil,
            ledgerEventID: ledger.id
        )
    }
}

enum PetCardAppearanceCommandService {
    @discardableResult
    @MainActor
    static func enablePopout(
        pet: Pet,
        imageData: Data,
        sourceRaw: String,
        context: ModelContext
    ) -> PetCardAppearanceCommandResult {
        pet.cardPopoutImageData = imageData
        pet.cardPopoutSourceRaw = sourceRaw
        pet.cardStyleRaw = "popout"
        context.safeSave()
        return PetCardAppearanceCommandResult(petID: pet.id, action: "enablePopout")
    }

    @discardableResult
    @MainActor
    static func restoreClassic(
        pet: Pet,
        context: ModelContext
    ) -> PetCardAppearanceCommandResult {
        pet.cardStyleRaw = "classic"
        context.safeSave()
        return PetCardAppearanceCommandResult(petID: pet.id, action: "restoreClassic")
    }
}

enum Avatar2DUpgradeCommandService {
    @discardableResult
    @MainActor
    static func upgradeHuman(
        _ human: Human,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        let rawGender = HumanProfileOptions.normalizedGender(human.genderRaw)
        let avatarGender: String
        switch rawGender {
        case "男", "女", "非二元":
            avatarGender = rawGender
        default:
            avatarGender = "非二元"
        }

        guard let data = HumanAvatarAssetCatalog.avatarData(gender: avatarGender, birthday: human.birthday) else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .missingProfile
            )
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        human.avatarImageData = data
        human.avatarEmoji = HumanGenderIdentity.fallbackAvatarEmoji(for: avatarGender)
        context.safeSave()
        return Avatar2DUpgradeCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            didUpgrade: true,
            failure: nil
        )
    }

    @discardableResult
    @MainActor
    static func upgradePet(
        _ pet: Pet,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor,
            eyeColor: pet.eyeColor
        ) else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .missingProfile
            )
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        pet.avatarImageData = data
        context.safeSave()
        return Avatar2DUpgradeCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            didUpgrade: true,
            failure: nil
        )
    }
}

@MainActor
struct RewardEconomyCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func purchase(
        item: ShopItem,
        buyer: Human?,
        itemName: String,
        questManager: QuestManager? = nil,
        note: String
    ) -> ShopPurchaseCommandResult {
        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: itemName,
            context: context,
            questManager: questManager
        )
        revisionCenter.publishShopPurchase(result, note: note)
        return result
    }

    @discardableResult
    func claimAchievementRewards(
        _ claims: [AchievementRewardClaim],
        claimedRewardRaw: String,
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> AchievementRewardCommandResult {
        let result = AchievementRewardCommandService.claimRewards(
            claims,
            claimedRewardRaw: claimedRewardRaw,
            amountPerBadge: amountPerBadge,
            human: human,
            pet: pet,
            context: context,
            questManager: questManager
        )
        revisionCenter.publishAchievementReward(result, note: note)
        return result
    }

    @discardableResult
    func awardBackdateCheckIn(
        action: QuestManager.OhanaActionType,
        actionKey: String,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> BackdateCheckInCommandResult {
        let result = BackdateCheckInCommandService.award(
            action: action,
            actionKey: actionKey,
            pet: pet,
            context: context,
            questManager: questManager
        )
        revisionCenter.publishBackdateCheckIn(result, note: note)
        return result
    }

    @discardableResult
    func awardBackdateCheckIn(
        actionKey: String,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> BackdateCheckInCommandResult {
        awardBackdateCheckIn(
            action: backdateActionType(for: actionKey),
            actionKey: actionKey,
            pet: pet,
            questManager: questManager,
            note: note
        )
    }

    private func backdateActionType(for actionKey: String) -> QuestManager.OhanaActionType {
        switch actionKey {
        case "feed":
            return .feed
        case "water":
            return .water
        case "potty":
            return .potty(isLitter: false)
        case "walk":
            return .walk(distanceMeters: 300)
        default:
            return .general(
                humanReward: 1,
                petReward: 0,
                emoji: "📅",
                title: "Backdate check-in"
            )
        }
    }

    @discardableResult
    func unlockBondVaultItem(
        _ item: PetBondVaultItem,
        pet: Pet,
        title: String,
        questManager: QuestManager? = nil,
        note: String
    ) -> PetBondVaultUnlockCommandResult {
        let result = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: title,
            context: context,
            questManager: questManager
        )
        revisionCenter.publishPetBondVaultUnlock(result, note: note)
        return result
    }

    @discardableResult
    func enablePetPopoutCard(
        pet: Pet,
        imageData: Data,
        sourceRaw: String,
        note: String
    ) -> PetCardAppearanceCommandResult {
        let result = PetCardAppearanceCommandService.enablePopout(
            pet: pet,
            imageData: imageData,
            sourceRaw: sourceRaw,
            context: context
        )
        revisionCenter.publishPetCardAppearance(result, note: note)
        return result
    }

    @discardableResult
    func restoreClassicPetCard(
        pet: Pet,
        note: String
    ) -> PetCardAppearanceCommandResult {
        let result = PetCardAppearanceCommandService.restoreClassic(pet: pet, context: context)
        revisionCenter.publishPetCardAppearance(result, note: note)
        return result
    }

    @discardableResult
    func upgradeHumanTo2DAvatar(
        _ human: Human,
        note: String
    ) -> Avatar2DUpgradeCommandResult {
        let result = Avatar2DUpgradeCommandService.upgradeHuman(human, context: context)
        revisionCenter.publishAvatar2DUpgrade(result, note: note)
        return result
    }

    @discardableResult
    func upgradePetTo2DAvatar(
        _ pet: Pet,
        note: String
    ) -> Avatar2DUpgradeCommandResult {
        let result = Avatar2DUpgradeCommandService.upgradePet(pet, context: context)
        revisionCenter.publishAvatar2DUpgrade(result, note: note)
        return result
    }
}

enum MemberLifecycleCommandService {
    @discardableResult
    @MainActor
    static func markPetPassedAway(
        _ pet: Pet,
        date: Date,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        RainbowBridgeService.markPassedAway(pet: pet, date: date, context: context)
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.mark"
        )
    }

    @discardableResult
    @MainActor
    static func undoPetPassedAway(
        _ pet: Pet,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        RainbowBridgeService.undoPassedAway(pet: pet, context: context)
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.undo"
        )
    }

    @discardableResult
    @MainActor
    static func clearPetActivityRecords(
        _ pet: Pet,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        pet.clearAllActivityRecords(in: context)
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "records.clear"
        )
    }

    @discardableResult
    @MainActor
    static func markHumanPassedAway(
        _ human: Human,
        date: Date,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        human.passedAwayDate = date
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.mark"
        )
    }

    @discardableResult
    @MainActor
    static func undoHumanPassedAway(
        _ human: Human,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        human.passedAwayDate = nil
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.undo"
        )
    }
}

enum MemberHomeVisibilityCommandService {
    @discardableResult
    @MainActor
    static func setHumanHomeVisibility(
        _ human: Human,
        visible: Bool,
        context: ModelContext
    ) -> MemberHomeVisibilityCommandResult {
        human.shouldShowOnHome = visible
        context.safeSave()
        return MemberHomeVisibilityCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            visible: visible
        )
    }
}

enum PetWalkCommandService {
    @discardableResult
    @MainActor
    static func saveWeeklyGoal(
        _ goalKm: Double,
        for pet: Pet,
        context: ModelContext
    ) -> PetWalkGoalCommandResult {
        pet.weeklyWalkGoalKm = max(0, goalKm)
        context.safeSave()
        return PetWalkGoalCommandResult(petID: pet.id, goalKm: pet.weeklyWalkGoalKm)
    }

    @discardableResult
    @MainActor
    static func saveSummary(
        for walk: PetWalkLog,
        pet: Pet,
        moodRating: Int,
        notes: String,
        context: ModelContext
    ) -> PetWalkSummaryCommandResult {
        let normalizedRating = min(5, max(0, moodRating))
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        walk.moodRating = normalizedRating
        walk.behaviorNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        context.safeSave()
        return PetWalkSummaryCommandResult(
            petID: pet.id,
            walkID: walk.id,
            moodRating: normalizedRating,
            hasNotes: !trimmedNotes.isEmpty
        )
    }
}

@MainActor
struct PetWalkCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func saveWeeklyGoal(
        _ goalKm: Double,
        for pet: Pet,
        note: String
    ) -> PetWalkGoalCommandResult {
        let result = PetWalkCommandService.saveWeeklyGoal(goalKm, for: pet, context: context)
        revisionCenter.publishPetWalkGoal(result, note: note)
        return result
    }

    @discardableResult
    func saveSummary(
        for walk: PetWalkLog,
        pet: Pet,
        moodRating: Int,
        notes: String,
        note: String
    ) -> PetWalkSummaryCommandResult {
        let result = PetWalkCommandService.saveSummary(
            for: walk,
            pet: pet,
            moodRating: moodRating,
            notes: notes,
            context: context
        )
        revisionCenter.publishPetWalkSummary(result, note: note)
        return result
    }
}

@MainActor
struct PlantCareCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordCare(
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        note: String
    ) -> PlantCareCommandResult {
        let result = PlantCareCommandService.recordCare(
            type,
            plant: plant,
            executorId: executorId,
            context: context
        )
        revisionCenter.publishPlantCare(result, note: note)
        return result
    }
}

@MainActor
struct MemberCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func updatePetProfile(_ pet: Pet, input: PetProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updatePet(pet, input: input, context: context)
        revisionCenter.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func updateHumanProfile(_ human: Human, input: HumanProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updateHuman(human, input: input, context: context)
        revisionCenter.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func updatePlantProfile(_ plant: Plant, input: PlantProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updatePlant(plant, input: input, context: context)
        revisionCenter.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func setHumanHomeVisibility(
        _ human: Human,
        visible: Bool,
        note: String
    ) -> MemberHomeVisibilityCommandResult {
        let result = MemberHomeVisibilityCommandService.setHumanHomeVisibility(human, visible: visible, context: context)
        revisionCenter.publishMemberHomeVisibility(result, note: note)
        return result
    }

    @discardableResult
    func publishPetHomeVisibility(
        petID: UUID,
        visible: Bool,
        note: String
    ) -> MemberHomeVisibilityCommandResult {
        let result = MemberHomeVisibilityCommandResult(
            entityID: petID,
            kind: EntityKind.pet.rawValue,
            visible: visible
        )
        revisionCenter.publishMemberHomeVisibility(result, note: note)
        return result
    }

    @discardableResult
    func markPetPassedAway(_ pet: Pet, date: Date, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.markPetPassedAway(pet, date: date, context: context)
        revisionCenter.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func undoPetPassedAway(_ pet: Pet, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.undoPetPassedAway(pet, context: context)
        revisionCenter.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func clearPetActivityRecords(_ pet: Pet, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.clearPetActivityRecords(pet, context: context)
        revisionCenter.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func markHumanPassedAway(_ human: Human, date: Date, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.markHumanPassedAway(human, date: date, context: context)
        revisionCenter.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func undoHumanPassedAway(_ human: Human, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.undoHumanPassedAway(human, context: context)
        revisionCenter.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func deletePet(_ pet: Pet, note: String) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deletePet(pet, context: context)
        revisionCenter.publishMemberDeletion(result, note: note)
        return result
    }

    @discardableResult
    func deleteHuman(
        _ human: Human,
        activeHumanID: String,
        note: String
    ) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deleteHuman(human, activeHumanID: activeHumanID, context: context)
        revisionCenter.publishMemberDeletion(result, note: note)
        return result
    }

    @discardableResult
    func deletePlant(_ plant: Plant, note: String) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deletePlant(plant, context: context)
        revisionCenter.publishMemberDeletion(result, note: note)
        return result
    }
}

struct SettingsActiveHumanSwitchCommandResult: Equatable {
    let humanID: UUID
    let didSyncHomeStack: Bool
    let updatedHomeCardOrderRaw: String
}

struct SettingsCoconutBalanceCommandResult: Equatable {
    let humanID: UUID?
    let amount: Int
    let legacyDelta: Int
}

enum SettingsCommandService {
    @discardableResult
    @MainActor
    static func syncHomeCardStackAfterActiveHumanSwitch(
        from oldHumanIdRaw: String,
        to human: Human,
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        context: ModelContext
    ) -> SettingsActiveHumanSwitchCommandResult {
        var updatedOrderRaw = homeCardOrderRaw
        let didChange = HomeActiveHumanCardSync.applyAfterAccountSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: &updatedOrderRaw
        )
        if didChange {
            context.safeSave()
        }
        return SettingsActiveHumanSwitchCommandResult(
            humanID: human.id,
            didSyncHomeStack: didChange,
            updatedHomeCardOrderRaw: updatedOrderRaw
        )
    }

    @discardableResult
    @MainActor
    static func applyCoconutBalanceTest(
        amount rawAmount: Int,
        human: Human?,
        questManager: QuestManager,
        title: String,
        actorName: String?,
        context: ModelContext
    ) -> SettingsCoconutBalanceCommandResult {
        let amount = max(0, rawAmount)
        human?.coconutBalance = amount
        if human != nil {
            context.safeSave()
        }

        let delta = amount - questManager.coconutCount
        questManager.recordCoconutDelta(
            delta,
            emoji: "🧪",
            title: title,
            actorId: human?.id.uuidString,
            actorName: actorName
        )

        return SettingsCoconutBalanceCommandResult(
            humanID: human?.id,
            amount: amount,
            legacyDelta: delta
        )
    }
}

@MainActor
struct SettingsCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func syncHomeCardStackAfterActiveHumanSwitch(
        from oldHumanIdRaw: String,
        to human: Human,
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        note: String
    ) -> SettingsActiveHumanSwitchCommandResult {
        let result = SettingsCommandService.syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            context: context
        )
        revisionCenter.publishSettingsActiveHumanSwitch(result, note: note)
        return result
    }

    @discardableResult
    func applyCoconutBalanceTest(
        amount: Int,
        human: Human?,
        questManager: QuestManager,
        title: String,
        actorName: String?,
        note: String
    ) -> SettingsCoconutBalanceCommandResult {
        let result = SettingsCommandService.applyCoconutBalanceTest(
            amount: amount,
            human: human,
            questManager: questManager,
            title: title,
            actorName: actorName,
            context: context
        )
        revisionCenter.publishSettingsCoconutBalance(result, note: note)
        return result
    }
}

enum MemberDeletionCommandService {
    private static let quickActionItemsKey = "quickActionItems_v2"

    @discardableResult
    @MainActor
    static func deletePet(
        _ pet: Pet,
        context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> MemberDeletionCommandResult {
        let petID = pet.id
        let petIDString = petID.uuidString
        let relatedEvents = fetchEvents(relatedEntityID: petIDString, context: context)
        for event in relatedEvents {
            context.delete(event)
        }

        let removedQuickActionCount = removeQuickAccessItems(forPetID: petID, userDefaults: userDefaults)
        context.delete(pet)
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: petID,
            kind: EntityKind.pet.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: removedQuickActionCount,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false
        )
    }

    @discardableResult
    @MainActor
    static func deleteHuman(
        _ human: Human,
        activeHumanID: String,
        context: ModelContext
    ) -> MemberDeletionCommandResult {
        let humanID = human.id
        let humanIDString = humanID.uuidString
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        let hasRemainingHuman = humans.contains { $0.id.uuidString != humanIDString }
        let deletedCurrentHuman = activeHumanID == humanIDString
        let requiresReplacementHuman = !hasRemainingHuman
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman

        context.delete(human)
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: humanID,
            kind: EntityKind.human.rawValue,
            removedRelatedEventIDs: [],
            removedQuickActionCount: 0,
            requiresReplacementHuman: requiresReplacementHuman,
            requiresAccountSwitch: requiresAccountSwitch,
            clearsActiveHumanID: deletedCurrentHuman || requiresReplacementHuman
        )
    }

    @discardableResult
    @MainActor
    static func deletePlant(_ plant: Plant, context: ModelContext) -> MemberDeletionCommandResult {
        let plantID = plant.id
        context.delete(plant)
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: plantID,
            kind: EntityKind.plant.rawValue,
            removedRelatedEventIDs: [],
            removedQuickActionCount: 0,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false
        )
    }

    @MainActor
    private static func fetchEvents(relatedEntityID: String, context: ModelContext) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == relatedEntityID
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func removeQuickAccessItems(forPetID petID: UUID, userDefaults: UserDefaults) -> Int {
        guard let json = userDefaults.string(forKey: quickActionItemsKey),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let items = object as? [[String: Any]]
        else { return 0 }

        let petIDString = petID.uuidString
        var removedCount = 0
        let filtered = items.filter { item in
            let petId = item["petId"] as? String
            let entityId = item["entityId"] as? String
            let entityKindRaw = item["entityKindRaw"] as? String
            let shouldRemove = petId == petIDString || (entityId == petIDString && entityKindRaw == EntityKind.pet.rawValue)
            if shouldRemove {
                removedCount += 1
            }
            return !shouldRemove
        }

        guard removedCount > 0,
              let newData = try? JSONSerialization.data(withJSONObject: filtered, options: []),
              let newJSON = String(data: newData, encoding: .utf8)
        else { return removedCount }
        userDefaults.set(newJSON, forKey: quickActionItemsKey)
        return removedCount
    }
}

struct HumanPrivacyCommandResult: Equatable {
    let humanID: UUID
    let action: String
    let changedFields: Set<String>
}

enum HumanPrivacyCommandService {
    @discardableResult
    @MainActor
    static func verifyPasscode(
        _ pin: String,
        for human: Human,
        now: Date,
        context: ModelContext
    ) -> HumanPasscodeVerification {
        let result = HumanPasscodeService.verify(pin, for: human, now: now)
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func setPasscode(
        _ pin: String,
        for human: Human,
        context: ModelContext
    ) throws -> HumanPrivacyCommandResult {
        try HumanPasscodeService.setPasscode(pin, for: human)
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: "passcode.set",
            changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
        )
    }

    @discardableResult
    @MainActor
    static func changePasscode(
        currentPin: String,
        newPin: String,
        for human: Human,
        now: Date = Date(),
        context: ModelContext
    ) throws -> HumanPasscodeVerification {
        let result = try HumanPasscodeService.changePasscode(
            currentPin: currentPin,
            newPin: newPin,
            for: human,
            now: now
        )
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func removePasscode(
        currentPin: String,
        for human: Human,
        now: Date = Date(),
        context: ModelContext
    ) throws -> HumanPasscodeVerification {
        let result = try HumanPasscodeService.removePasscode(currentPin: currentPin, for: human, now: now)
        if shouldSaveVerificationResult(result) {
            context.safeSave()
        }
        return result
    }

    @discardableResult
    @MainActor
    static func setPrivateField(
        _ field: HumanPrivateField,
        isPrivate: Bool,
        for human: Human,
        context: ModelContext
    ) -> HumanPrivacyCommandResult {
        let before = human.privateFields
        human.setPrivate(field, isPrivate)
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: "privacy.field",
            changedFields: before.symmetricDifference(human.privateFields)
        )
    }

    @discardableResult
    @MainActor
    static func setAllPrivateFields(
        isPrivate: Bool,
        for human: Human,
        context: ModelContext
    ) -> HumanPrivacyCommandResult {
        let before = human.privateFields
        for field in HumanPrivateField.allCases {
            human.setPrivate(field, isPrivate)
        }
        context.safeSave()
        return HumanPrivacyCommandResult(
            humanID: human.id,
            action: isPrivate ? "privacy.allPrivate" : "privacy.allPublic",
            changedFields: before.symmetricDifference(human.privateFields)
        )
    }

    private static func shouldSaveVerificationResult(_ result: HumanPasscodeVerification) -> Bool {
        switch result {
        case .success, .incorrect, .locked:
            return true
        case .invalidFormat, .noPasscode:
            return false
        }
    }
}

@MainActor
struct HumanPrivacyCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func verifyPasscode(_ pin: String, for human: Human, now: Date) -> HumanPasscodeVerification {
        HumanPrivacyCommandService.verifyPasscode(pin, for: human, now: now, context: context)
    }

    @discardableResult
    func setPasscode(_ pin: String, for human: Human, note: String) throws -> HumanPrivacyCommandResult {
        let result = try HumanPrivacyCommandService.setPasscode(pin, for: human, context: context)
        revisionCenter.publishHumanPrivacy(result, note: note)
        return result
    }

    @discardableResult
    func changePasscode(
        currentPin: String,
        newPin: String,
        for human: Human,
        now: Date = Date(),
        note: String
    ) throws -> HumanPasscodeVerification {
        let verification = try HumanPrivacyCommandService.changePasscode(
            currentPin: currentPin,
            newPin: newPin,
            for: human,
            now: now,
            context: context
        )
        if verification == .success {
            revisionCenter.publishHumanPrivacy(
                HumanPrivacyCommandResult(
                    humanID: human.id,
                    action: "passcode.change",
                    changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
                ),
                note: note
            )
        }
        return verification
    }

    @discardableResult
    func removePasscode(
        currentPin: String,
        for human: Human,
        now: Date = Date(),
        note: String
    ) throws -> HumanPasscodeVerification {
        let verification = try HumanPrivacyCommandService.removePasscode(
            currentPin: currentPin,
            for: human,
            now: now,
            context: context
        )
        if verification == .success {
            revisionCenter.publishHumanPrivacy(
                HumanPrivacyCommandResult(
                    humanID: human.id,
                    action: "passcode.remove",
                    changedFields: ["pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"]
                ),
                note: note
            )
        }
        return verification
    }

    @discardableResult
    func setPrivateField(
        _ field: HumanPrivateField,
        isPrivate: Bool,
        for human: Human,
        note: String
    ) -> HumanPrivacyCommandResult {
        let result = HumanPrivacyCommandService.setPrivateField(
            field,
            isPrivate: isPrivate,
            for: human,
            context: context
        )
        revisionCenter.publishHumanPrivacy(result, note: note)
        return result
    }

    @discardableResult
    func setAllPrivateFields(
        isPrivate: Bool,
        for human: Human,
        note: String
    ) -> HumanPrivacyCommandResult {
        let result = HumanPrivacyCommandService.setAllPrivateFields(
            isPrivate: isPrivate,
            for: human,
            context: context
        )
        revisionCenter.publishHumanPrivacy(result, note: note)
        return result
    }
}

struct ExpenseCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let coconutDelta: Int
    let ledgerEventID: UUID?
    let documentID: UUID?

    init(
        logID: UUID,
        subjectID: UUID?,
        coconutDelta: Int,
        ledgerEventID: UUID? = nil,
        documentID: UUID? = nil
    ) {
        self.logID = logID
        self.subjectID = subjectID
        self.coconutDelta = coconutDelta
        self.ledgerEventID = ledgerEventID
        self.documentID = documentID
    }
}

enum ExpenseCommandService {
    @discardableResult
    @MainActor
    static func recordPetExpense(
        pet: Pet,
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = []
    ) -> ExpenseCommandResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: date,
            amount: amount,
            category: category,
            note: cleanNote,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        let document: PetDocument?
        if !receiptAttachments.isEmpty {
            let receiptDocument = ExpenseReceiptDocumentBuilder.makeDocument(
                title: receiptTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "\(pet.name) · \(category.rawValue)",
                category: receiptCategory ?? .other,
                cost: amount,
                date: log.date,
                visibleNote: cleanNote,
                linkedExpenseLogId: log.id.uuidString,
                attachments: receiptAttachments,
                pet: pet
            )
            context.insert(receiptDocument)
            for attachment in receiptDocument.attachments {
                context.insert(attachment)
            }
            document = receiptDocument
        } else {
            document = nil
        }

        let reward = QuestManager.shared.awardAction(type: .expense, pet: pet, context: context)
        let coconutDelta = CareLedgerService.rewardDelta(reward)
        let ledgerEvent = CareLedgerService.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: category.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            note: cleanNote,
            source: source,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            context: context
        )
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEvent.id,
            documentID: document?.id
        )
    }

    @discardableResult
    @MainActor
    static func recordHumanExpense(
        human: Human,
        amount: Double,
        date: Date,
        note: String,
        context: ModelContext,
        category: ExpenseCategory = .other
    ) -> ExpenseCommandResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: date,
            amount: amount,
            category: category,
            note: cleanNote,
            pet: nil,
            executorId: human.id.uuidString
        )
        context.insert(log)

        let reward = QuestManager.shared.awardAction(type: .expense, pet: nil, context: context)
        let coconutDelta = CareLedgerService.rewardDelta(reward)
        let ledgerEvent = CareLedgerService.record(
            occurredAt: date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .expense,
            actionType: category.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            note: cleanNote,
            source: .quickAction,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            privacyFieldRaw: HumanPrivateField.expense.rawValue,
            context: context
        )
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: human.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEvent.id
        )
    }
}

struct WorkoutCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let ledgerEventID: UUID?
}

struct WorkoutDeleteCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum WorkoutCommandService {
    @discardableResult
    @MainActor
    static func recordHumanWorkout(
        human: Human,
        type: WorkoutType,
        durationMinutes: Int,
        date: Date,
        context: ModelContext,
        distanceKm: Double = 0,
        calories: Int = 0,
        notes: String = "",
        source: CareLedgerSource = .quickAction
    ) -> WorkoutCommandResult {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = HumanWorkoutLog(
            date: date,
            type: type,
            durationMinutes: durationMinutes,
            distanceKm: max(0, distanceKm.isFinite ? distanceKm : 0),
            calories: max(0, calories),
            steps: 0,
            notes: cleanNotes,
            sourceHealthKit: false,
            human: human
        )
        context.insert(log)
        let ledgerEvent = CareLedgerService.record(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .workout,
            actionType: log.typeRaw,
            amountValue: Double(log.durationMinutes),
            amountUnit: "min",
            note: log.notes,
            source: source,
            legacyModelName: "HumanWorkoutLog",
            legacyModelId: log.id.uuidString,
            metadataJSON: "{\"distanceKm\":\(log.distanceKm),\"calories\":\(log.calories),\"steps\":\(log.steps)}",
            context: context,
            save: false
        )
        context.safeSave()
        return WorkoutCommandResult(logID: log.id, subjectID: human.id, ledgerEventID: ledgerEvent.id)
    }

    @discardableResult
    @MainActor
    static func deleteHumanWorkout(
        _ log: HumanWorkoutLog,
        human: Human,
        context: ModelContext
    ) -> WorkoutDeleteCommandResult {
        let ledgerEvents = ledgerEvents(for: log.id, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let logID = log.id
        context.delete(log)
        context.safeSave()
        return WorkoutDeleteCommandResult(
            logID: logID,
            subjectID: human.id,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(for logID: UUID, context: ModelContext) -> [CareLedgerEvent] {
        let idString = logID.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == "HumanWorkoutLog" && $0.legacyModelId == idString }
    }
}

struct HumanMedicationCommandResult: Equatable {
    let medicationID: UUID
    let subjectID: UUID
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanCommandInput: Equatable {
    let name: String
    let dosage: String
    let frequency: MedicationFrequency
    let customFrequencyNote: String
    let doseMinutes: [Int]
    let weeklyWeekday: Int
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let visibleNotes: String
    let isActive: Bool
    let appLanguage: String

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanDosage: String {
        dosage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanCustomFrequencyNote: String {
        frequency == .custom ? customFrequencyNote.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    var normalizedDoseMinutes: [Int] {
        guard !frequency.isManualEntry else { return [] }
        let source = doseMinutes.isEmpty ? HumanMedicationSchedulePlan.defaultDoseMinutes(for: frequency) : doseMinutes
        return HumanMedicationScheduleMetadata.normalizedDoseMinutes(source)
    }

    var scheduleMetadata: HumanMedicationScheduleMetadata? {
        guard !frequency.isManualEntry else { return nil }
        return HumanMedicationScheduleMetadata(
            doseMinutes: normalizedDoseMinutes,
            weeklyWeekday: frequency == .weekly ? weeklyWeekday : nil
        )
    }

    var savedNotes: String {
        HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: visibleNotes,
            metadata: scheduleMetadata
        )
    }

    func firstDoseTime(calendar: Calendar = .current) -> Date {
        let firstMinute = normalizedDoseMinutes.first ?? 8 * 60
        return HumanMedicationSchedulePlan.date(on: Date(), minuteOfDay: firstMinute, calendar: calendar) ?? Date()
    }
}

struct HumanMedicationPlanCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let created: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanDeleteCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationPlanActivationCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let isActive: Bool
    let didChange: Bool
    let calendarEventIDs: [UUID]
    let removedCalendarEventIDs: [UUID]
    let scheduledReminderSync: Bool
}

struct HumanMedicationDoseCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let logID: UUID?
    let status: HumanMedicationStatus
    let didChange: Bool
    let recordedLedgerEvent: Bool
}

enum HumanMedicationCommandService {
    @discardableResult
    @MainActor
    static func createMedication(
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        firstDoseTime: Date,
        startDate: Date,
        colorHex: String,
        notes: String,
        context: ModelContext,
        reminderEnabled: Bool
    ) -> HumanMedicationCommandResult? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: cleanName,
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            firstDoseTime: firstDoseTime,
            startDate: startDate,
            colorHex: colorHex,
            notes: notes
        )
        medication.isActive = true
        context.insert(medication)
        context.safeSave()

        if reminderEnabled {
            let meds = fetchHumanMedications(humanID: human.id.uuidString, context: context)
            MedicationReminderService.shared.scheduleHumanMedicationReminders(
                for: human,
                meds: meds,
                context: context
            )
        }

        return HumanMedicationCommandResult(
            medicationID: medication.id,
            subjectID: human.id,
            scheduledReminderSync: reminderEnabled
        )
    }

    @MainActor
    private static func fetchHumanMedications(humanID: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanID
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

struct PetMedicationPlanCommandInput: Equatable {
    let name: String
    let dosage: String
    let frequency: PetMedicationFrequency
    let doseMinutes: [Int]
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let notes: String
    let isActive: Bool
    let remainingAmount: Double?

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanDosage: String {
        dosage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedDoseMinutes: [Int] {
        PetMedicationSchedulePlan.normalizedDoseMinutes(
            doseMinutes,
            count: PetMedicationSchedulePlan.dosesPerDay(for: frequency),
            frequency: frequency
        )
    }

    var savedCustomFrequencyNote: String {
        PetMedicationSchedulePlan.encodeDoseMinutes(normalizedDoseMinutes)
    }

    var cleanNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetMedicationPlanCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let created: Bool
    let scheduledReminderSync: Bool
}

struct PetMedicationPlanDeleteCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let scheduledReminderSync: Bool
}

struct PetMedicationPlanActivationCommandResult: Equatable {
    let subjectID: UUID
    let medicationID: UUID
    let isActive: Bool
    let didChange: Bool
    let scheduledReminderSync: Bool
}

enum PetMedicationPlanCommandService {
    @discardableResult
    @MainActor
    static func savePlan(
        pet: Pet,
        editing existingMedication: PetMedication?,
        input: PetMedicationPlanCommandInput,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true
    ) -> PetMedicationPlanCommandResult? {
        guard !input.cleanName.isEmpty else { return nil }

        let medication: PetMedication
        let created: Bool
        if let existing = existingMedication {
            medication = existing
            created = false
        } else {
            medication = PetMedication(
                name: input.cleanName,
                dosage: input.cleanDosage,
                frequency: input.frequency,
                startDate: input.startDate,
                endDate: input.endDate,
                colorHex: input.colorHex,
                notes: input.cleanNotes,
                pet: pet
            )
            context.insert(medication)
            created = true
        }

        apply(input, to: medication, pet: pet)
        context.safeSave()
        syncRemainingAmount(input.remainingAmount, medicationID: medication.id, userDefaults: userDefaults)

        if scheduleReminders {
            MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanCommandResult(
            subjectID: pet.id,
            medicationID: medication.id,
            created: created,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func deletePlan(
        pet: Pet,
        medication: PetMedication,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true
    ) -> PetMedicationPlanDeleteCommandResult {
        let medicationID = medication.id
        context.delete(medication)
        context.safeSave()
        userDefaults.removeObject(forKey: remainingAmountKey(medicationID: medicationID))

        if scheduleReminders {
            MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanDeleteCommandResult(
            subjectID: pet.id,
            medicationID: medicationID,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func setPlanActive(
        pet: Pet,
        medication: PetMedication,
        isActive: Bool,
        context: ModelContext,
        scheduleReminders: Bool = true
    ) -> PetMedicationPlanActivationCommandResult {
        let didChange = medication.isActive != isActive
        medication.isActive = isActive
        context.safeSave()

        if scheduleReminders {
            MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: context)
        }

        return PetMedicationPlanActivationCommandResult(
            subjectID: pet.id,
            medicationID: medication.id,
            isActive: isActive,
            didChange: didChange,
            scheduledReminderSync: scheduleReminders
        )
    }

    static func remainingAmountKey(medicationID: UUID) -> String {
        "medication_remaining_\(medicationID.uuidString)"
    }

    @MainActor
    private static func apply(_ input: PetMedicationPlanCommandInput, to medication: PetMedication, pet: Pet) {
        medication.name = input.cleanName
        medication.dosage = input.cleanDosage
        medication.frequency = input.frequency
        medication.customFrequencyNote = input.savedCustomFrequencyNote
        medication.startDate = input.startDate
        medication.endDate = input.endDate
        medication.colorHex = input.colorHex
        medication.notes = input.cleanNotes
        medication.isActive = input.isActive
        medication.pet = pet
    }

    private static func syncRemainingAmount(
        _ amount: Double?,
        medicationID: UUID,
        userDefaults: UserDefaults
    ) {
        let key = remainingAmountKey(medicationID: medicationID)
        guard let amount else {
            userDefaults.removeObject(forKey: key)
            return
        }
        userDefaults.set(max(0, amount), forKey: key)
    }
}

@MainActor
struct PetMedicationCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func savePlan(
        pet: Pet,
        editing existingMedication: PetMedication?,
        input: PetMedicationPlanCommandInput,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        note: String,
        emptyNote: String = "pet.medication.plan.empty"
    ) -> PetMedicationPlanCommandResult? {
        guard let result = PetMedicationPlanCommandService.savePlan(
            pet: pet,
            editing: existingMedication,
            input: input,
            context: context,
            userDefaults: userDefaults,
            scheduleReminders: scheduleReminders
        ) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .petMedicationPlan(petID: pet.id, medicationID: existingMedication?.id),
                    affectedEntityIDs: [pet.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishPetMedicationPlan(result, note: note)
        return result
    }

    @discardableResult
    func deletePlan(
        pet: Pet,
        medication: PetMedication,
        userDefaults: UserDefaults = .standard,
        scheduleReminders: Bool = true,
        note: String
    ) -> PetMedicationPlanDeleteCommandResult {
        let result = PetMedicationPlanCommandService.deletePlan(
            pet: pet,
            medication: medication,
            context: context,
            userDefaults: userDefaults,
            scheduleReminders: scheduleReminders
        )
        revisionCenter.publishPetMedicationPlanDelete(result, note: note)
        return result
    }

    @discardableResult
    func setPlanActive(
        pet: Pet,
        medication: PetMedication,
        isActive: Bool,
        scheduleReminders: Bool = true,
        note: String
    ) -> PetMedicationPlanActivationCommandResult {
        let result = PetMedicationPlanCommandService.setPlanActive(
            pet: pet,
            medication: medication,
            isActive: isActive,
            context: context,
            scheduleReminders: scheduleReminders
        )
        revisionCenter.publishPetMedicationPlanActivation(result, note: note)
        return result
    }
}

enum HumanMedicationPlanCommandService {
    private static let humanMedicationEntityType = "human_medication"

    @discardableResult
    @MainActor
    static func savePlan(
        human: Human,
        editing existingMedication: HumanMedication?,
        input: HumanMedicationPlanCommandInput,
        context: ModelContext,
        scheduleReminders: Bool = true
    ) -> HumanMedicationPlanCommandResult? {
        guard !input.cleanName.isEmpty else { return nil }

        let medication: HumanMedication
        let created: Bool
        if let existing = existingMedication {
            medication = existing
            created = false
        } else {
            medication = HumanMedication(
                humanId: human.id.uuidString,
                name: input.cleanName,
                dosage: input.cleanDosage,
                frequency: input.frequency,
                firstDoseTime: input.firstDoseTime(),
                startDate: input.startDate,
                endDate: input.endDate,
                colorHex: input.colorHex,
                notes: input.savedNotes
            )
            context.insert(medication)
            created = true
        }

        apply(input, to: medication, human: human)
        let calendarSync = syncCalendarEvents(
            for: medication,
            human: human,
            appLanguage: input.appLanguage,
            context: context
        )
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(for: human, context: context)
        }

        return HumanMedicationPlanCommandResult(
            subjectID: human.id,
            medicationID: medication.id,
            created: created,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func deletePlan(
        human: Human,
        medication: HumanMedication,
        context: ModelContext,
        scheduleReminders: Bool = true
    ) -> HumanMedicationPlanDeleteCommandResult {
        let medicationID = medication.id
        let removedEventIDs = removeCalendarEvents(for: medicationID, context: context)
        context.delete(medication)
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(for: human, context: context)
        }

        return HumanMedicationPlanDeleteCommandResult(
            subjectID: human.id,
            medicationID: medicationID,
            removedCalendarEventIDs: removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func setPlanActive(
        human: Human,
        medication: HumanMedication,
        isActive: Bool,
        appLanguage: String,
        context: ModelContext,
        scheduleReminders: Bool = true
    ) -> HumanMedicationPlanActivationCommandResult {
        let didChange = medication.isActive != isActive
        medication.isActive = isActive
        let calendarSync = syncCalendarEvents(
            for: medication,
            human: human,
            appLanguage: appLanguage,
            context: context
        )
        context.safeSave()

        if scheduleReminders {
            scheduleHumanMedicationReminders(for: human, context: context)
        }

        return HumanMedicationPlanActivationCommandResult(
            subjectID: human.id,
            medicationID: medication.id,
            isActive: isActive,
            didChange: didChange,
            calendarEventIDs: calendarSync.createdEventIDs,
            removedCalendarEventIDs: calendarSync.removedEventIDs,
            scheduledReminderSync: scheduleReminders
        )
    }

    @MainActor
    private static func apply(_ input: HumanMedicationPlanCommandInput, to medication: HumanMedication, human: Human) {
        medication.humanId = human.id.uuidString
        medication.name = input.cleanName
        medication.dosage = input.cleanDosage
        medication.frequency = input.frequency
        medication.customFrequencyNote = input.cleanCustomFrequencyNote
        medication.firstDoseTime = input.firstDoseTime()
        medication.startDate = input.startDate
        medication.endDate = input.endDate
        medication.colorHex = input.colorHex
        medication.notes = input.savedNotes
        medication.isActive = input.isActive
    }

    @MainActor
    private static func syncCalendarEvents(
        for medication: HumanMedication,
        human: Human,
        appLanguage: String,
        context: ModelContext
    ) -> (removedEventIDs: [UUID], createdEventIDs: [UUID]) {
        let removedEventIDs = removeCalendarEvents(for: medication.id, context: context)
        guard medication.isActive, !medication.frequency.isManualEntry else {
            return (removedEventIDs, [])
        }

        let calendar = Calendar.current
        let firstDay = firstScheduledDay(for: medication, calendar: calendar)
        let doseMinutes = HumanMedicationSchedulePlan.doseMinutes(for: medication, calendar: calendar)
        var createdEventIDs: [UUID] = []

        for (index, minute) in doseMinutes.enumerated() {
            guard let start = HumanMedicationSchedulePlan.date(on: firstDay, minuteOfDay: minute, calendar: calendar) else {
                continue
            }
            let event = Event(
                title: calendarEventTitle(
                    for: medication,
                    human: human,
                    doseIndex: index,
                    totalDoses: doseMinutes.count,
                    appLanguage: appLanguage
                ),
                startDate: start,
                eventType: EventType.medication.rawValue,
                relatedEntityType: humanMedicationEntityType,
                relatedEntityId: medication.id.uuidString
            )
            event.recurrenceDays = medication.frequency == .weekly ? 7 : 1
            event.recurrenceEndDate = medication.endDate.map { calendar.startOfDay(for: $0) }
            event.assigneeId = human.id.uuidString
            context.insert(event)
            createdEventIDs.append(event.id)
        }

        return (removedEventIDs, createdEventIDs)
    }

    private static func firstScheduledDay(for medication: HumanMedication, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: medication.startDate)
        guard medication.frequency == .weekly else { return start }
        let targetWeekday = HumanMedicationScheduleMetadata.parse(from: medication.notes)?.weeklyWeekday
            ?? calendar.component(.weekday, from: start)
        let startWeekday = calendar.component(.weekday, from: start)
        let delta = (targetWeekday - startWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }

    private static func calendarEventTitle(
        for medication: HumanMedication,
        human: Human,
        doseIndex: Int,
        totalDoses: Int,
        appLanguage: String
    ) -> String {
        let l = L10n(appLanguage)
        let doseSuffix = totalDoses > 1
            ? l.tr(zh: " · 第 \(doseIndex + 1) 次", en: " · Dose \(doseIndex + 1)", de: " · Dosis \(doseIndex + 1)")
            : ""
        let dosageSuffix = medication.dosage.isEmpty ? "" : " · \(medication.dosage)"
        return "💊 \(human.name) · \(medication.name)\(dosageSuffix)\(doseSuffix)"
    }

    @MainActor
    private static func removeCalendarEvents(for medicationID: UUID, context: ModelContext) -> [UUID] {
        let medicationIDString = medicationID.uuidString
        let entityType = humanMedicationEntityType
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == entityType && event.relatedEntityId == medicationIDString
            }
        )
        let events = (try? context.fetch(descriptor)) ?? []
        let removedEventIDs = events.map(\.id)
        for event in events {
            context.delete(event)
        }
        return removedEventIDs
    }

    @MainActor
    private static func scheduleHumanMedicationReminders(for human: Human, context: ModelContext) {
        let meds = fetchHumanMedications(humanID: human.id.uuidString, context: context)
        MedicationReminderService.shared.scheduleHumanMedicationReminders(
            for: human,
            meds: meds,
            context: context
        )
    }

    @MainActor
    private static func fetchHumanMedications(humanID: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanID
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

enum HumanMedicationDoseCommandService {
    @discardableResult
    @MainActor
    static func setDoseStatus(
        human: Human,
        medicationID: UUID,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        context: ModelContext,
        source: CareLedgerSource = .detail,
        now: Date = Date()
    ) -> HumanMedicationDoseCommandResult {
        let update = HumanMedicationLogStore.applyDoseStatus(
            humanId: human.id.uuidString,
            medicationId: medicationID.uuidString,
            scheduledTime: scheduledTime,
            status: status,
            existingLogs: [],
            context: context
        )

        var recordedLedgerEvent = false
        if update.shouldRecordLedgerEvent, let log = update.log {
            recordedLedgerEvent = true
            CareLedgerService.record(
                occurredAt: log.recordedTime ?? now,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                eventKind: .medication,
                actionType: status == .taken ? "humanMedicationTaken" : "humanMedicationSkipped",
                source: source,
                legacyModelName: "HumanMedicationLog",
                legacyModelId: log.id.uuidString,
                metadataJSON: "{\"medicationId\":\"\(medicationID.uuidString)\"}",
                context: context,
                save: false
            )
        }

        if update.didChange {
            context.safeSave()
        }

        return HumanMedicationDoseCommandResult(
            subjectID: human.id,
            medicationID: medicationID,
            logID: update.log?.id,
            status: status,
            didChange: update.didChange,
            recordedLedgerEvent: recordedLedgerEvent
        )
    }
}

struct HumanHealthMetricCommandResult {
    let log: HumanHealthMetricLog
    let logID: UUID
    let subjectID: UUID
    let metricKey: String
}

struct HumanHealthMetricDeleteCommandResult: Equatable {
    let humanID: UUID
    let metricKey: String
    let logID: UUID
}

enum HumanHealthMetricCommandService {
    @discardableResult
    @MainActor
    static func recordMetric(
        human: Human,
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date,
        notes: String,
        context: ModelContext
    ) -> HumanHealthMetricCommandResult? {
        guard value > 0, value.isFinite else { return nil }
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = HumanHealthMetricLog(
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            date: date,
            notes: cleanNotes,
            human: human
        )
        context.insert(log)
        human.healthMetricLogs.append(log)
        context.safeSave()
        return HumanHealthMetricCommandResult(
            log: log,
            logID: log.id,
            subjectID: human.id,
            metricKey: metricKey
        )
    }

    @discardableResult
    @MainActor
    static func deleteMetricLog(
        _ log: HumanHealthMetricLog,
        human: Human,
        context: ModelContext
    ) -> HumanHealthMetricDeleteCommandResult {
        let logID = log.id
        let metricKey = log.metricKey
        human.healthMetricLogs.removeAll { $0.id == logID }
        context.delete(log)
        context.safeSave()
        return HumanHealthMetricDeleteCommandResult(
            humanID: human.id,
            metricKey: metricKey,
            logID: logID
        )
    }
}

struct HumanHealthReportCommandInput: Equatable {
    let reportType: HealthReportType
    let conclusion: ReportConclusion
    let hospitalName: String
    let doctorName: String
    let reportDate: Date
    let nextCheckDate: Date?
    let summary: String
    let notes: String
}

struct HumanHealthReportCommandResult: Equatable {
    let humanID: UUID
    let reportID: UUID
    let reportType: String
}

enum HumanHealthReportCommandService {
    @discardableResult
    @MainActor
    static func createReport(
        human: Human,
        input: HumanHealthReportCommandInput,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        let report = HumanHealthReport(
            humanId: human.id.uuidString,
            reportType: input.reportType,
            conclusion: input.conclusion,
            hospitalName: input.hospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
            doctorName: input.doctorName.trimmingCharacters(in: .whitespacesAndNewlines),
            reportDate: input.reportDate,
            nextCheckDate: input.nextCheckDate,
            summary: input.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(report)
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw
        )
    }

    @discardableResult
    @MainActor
    static func updateReport(
        _ report: HumanHealthReport,
        human: Human,
        input: HumanHealthReportCommandInput,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        report.humanId = human.id.uuidString
        report.reportType = input.reportType
        report.conclusion = input.conclusion
        report.hospitalName = input.hospitalName.trimmingCharacters(in: .whitespacesAndNewlines)
        report.doctorName = input.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        report.reportDate = input.reportDate
        report.nextCheckDate = input.nextCheckDate
        report.summary = input.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        report.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw
        )
    }

    @discardableResult
    @MainActor
    static func deleteReport(
        _ report: HumanHealthReport,
        human: Human,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        let reportID = report.id
        let reportType = report.reportTypeRaw
        context.delete(report)
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: reportID,
            reportType: reportType
        )
    }
}

@MainActor
struct HumanHealthReportCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createReport(
        human: Human,
        input: HumanHealthReportCommandInput,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.createReport(
            human: human,
            input: input,
            context: context
        )
        revisionCenter.publishHumanHealthReport(result, action: "create", note: note)
        return result
    }

    @discardableResult
    func updateReport(
        _ report: HumanHealthReport,
        human: Human,
        input: HumanHealthReportCommandInput,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.updateReport(
            report,
            human: human,
            input: input,
            context: context
        )
        revisionCenter.publishHumanHealthReport(result, action: "update", note: note)
        return result
    }

    @discardableResult
    func deleteReport(
        _ report: HumanHealthReport,
        human: Human,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.deleteReport(
            report,
            human: human,
            context: context
        )
        revisionCenter.publishHumanHealthReport(result, action: "delete", note: note)
        return result
    }
}

struct HumanNoteFileAttachmentPayload: Equatable {
    let fileName: String
    let data: Data
    let isImage: Bool
}

struct HumanNoteCommandResult: Equatable {
    let subjectID: UUID
    let attachmentCount: Int
    let eventID: UUID?
    let reminderID: UUID?
}

struct HumanNoteDeleteResult: Equatable {
    let subjectID: UUID
    let didDelete: Bool
}

enum HumanNoteCommandService {
    @discardableResult
    @MainActor
    static func recordNote(
        human: Human,
        note: String,
        date: Date,
        imageAttachments: [UIImage],
        fileAttachments: [HumanNoteFileAttachmentPayload],
        reminderDate: Date?,
        appLanguage: String,
        context: ModelContext,
        scheduleNotification: Bool = true
    ) -> HumanNoteCommandResult? {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNote.isEmpty || !imageAttachments.isEmpty || !fileAttachments.isEmpty || reminderDate != nil else {
            return nil
        }

        let attachments = persistAttachments(
            images: imageAttachments,
            files: fileAttachments,
            humanID: human.id
        )
        let l = L10n(appLanguage)
        let entry = noteEntry(
            note: cleanNote,
            date: date,
            attachments: attachments,
            reminderDate: reminderDate,
            l: l
        )
        human.notes = human.notes.isEmpty ? entry : human.notes + "\n\n" + entry

        let reminderPair = reminderDate.map {
            createReminder(
                human: human,
                note: cleanNote,
                reminderDate: $0,
                l: l,
                context: context
            )
        }

        context.safeSave()

        if scheduleNotification, let reminder = reminderPair?.reminder {
            Task {
                await ReminderSchedulingService.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: .quickAction
                )
            }
        }

        return HumanNoteCommandResult(
            subjectID: human.id,
            attachmentCount: attachments.count,
            eventID: reminderPair?.event.id,
            reminderID: reminderPair?.reminder.id
        )
    }

    @discardableResult
    @MainActor
    static func deleteNote(
        human: Human,
        rawString: String,
        context: ModelContext
    ) -> HumanNoteDeleteResult {
        let target = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, !human.notes.isEmpty else {
            return HumanNoteDeleteResult(subjectID: human.id, didDelete: false)
        }

        let parts = human.notes.components(separatedBy: "\n\n")
        let remaining = parts.filter { part in
            part.trimmingCharacters(in: .whitespacesAndNewlines) != target
        }
        let didDelete = remaining.count != parts.count
        guard didDelete else {
            return HumanNoteDeleteResult(subjectID: human.id, didDelete: false)
        }

        human.notes = remaining
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        context.safeSave()
        return HumanNoteDeleteResult(subjectID: human.id, didDelete: true)
    }

    private static func persistAttachments(
        images: [UIImage],
        files: [HumanNoteFileAttachmentPayload],
        humanID: UUID
    ) -> [HumanNoteAttachmentReference] {
        var references: [HumanNoteAttachmentReference] = []
        for (index, image) in images.enumerated() {
            if let ref = HumanNoteAttachmentStore.saveImage(image, humanId: humanID, index: index + 1) {
                references.append(ref)
            }
        }
        for file in files {
            if let ref = HumanNoteAttachmentStore.saveFile(
                data: file.data,
                originalFileName: file.fileName,
                isImage: file.isImage,
                humanId: humanID
            ) {
                references.append(ref)
            }
        }
        return references
    }

    private static func noteEntry(
        note: String,
        date: Date,
        attachments: [HumanNoteAttachmentReference],
        reminderDate: Date?,
        l: L10n
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "[\(formatter.string(from: date))] \(recordBody(note: note, attachments: attachments, reminderDate: reminderDate, l: l))\(HumanNoteAttachmentStore.marker(for: attachments))"
    }

    private static func recordBody(
        note: String,
        attachments: [HumanNoteAttachmentReference],
        reminderDate: Date?,
        l: L10n
    ) -> String {
        var parts: [String] = []
        if !note.isEmpty {
            parts.append(note)
        }
        let imageCount = attachments.filter(\.isImage).count
        let fileNames = attachments.filter { !$0.isImage }.map(\.fileName)
        if imageCount > 0 {
            parts.append(l.tr(zh: "照片 \(imageCount) 张", en: "\(imageCount) photo(s)", de: "\(imageCount) Foto(s)"))
        }
        if !fileNames.isEmpty {
            let names = fileNames.joined(separator: ", ")
            parts.append(l.tr(zh: "文件：\(names)", en: "Files: \(names)", de: "Dateien: \(names)"))
        }
        if let reminderDate {
            let formatted = reminderDate.formatted(date: .abbreviated, time: .shortened)
            parts.append(l.tr(zh: "提醒：\(formatted)", en: "Reminder: \(formatted)", de: "Erinnerung: \(formatted)"))
        }
        return parts.isEmpty ? l.tr(zh: "记录", en: "Record", de: "Eintrag") : parts.joined(separator: " · ")
    }

    @MainActor
    private static func createReminder(
        human: Human,
        note: String,
        reminderDate: Date,
        l: L10n,
        context: ModelContext
    ) -> (event: Event, reminder: Reminder) {
        let title = note.isEmpty
            ? l.tr(zh: "\(human.name) 的记录提醒", en: "\(human.name)'s note reminder", de: "Notizerinnerung für \(human.name)")
            : note
        let event = Event(
            title: title,
            startDate: reminderDate,
            eventType: EventType.task.rawValue,
            relatedEntityType: "human_note",
            relatedEntityId: human.id.uuidString
        )
        event.assigneeId = human.id.uuidString
        let reminder = Reminder(event: event, scheduledAt: reminderDate)
        event.reminders.append(reminder)
        context.insert(event)
        context.insert(reminder)
        return (event, reminder)
    }
}

@MainActor
struct HumanCareCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func recordWorkout(
        human: Human,
        type: WorkoutType,
        durationMinutes: Int,
        date: Date,
        distanceKm: Double = 0,
        calories: Int = 0,
        notes: String = "",
        source: CareLedgerSource = .quickAction,
        command: DomainCommand,
        note: String
    ) -> WorkoutCommandResult {
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: type,
            durationMinutes: durationMinutes,
            date: date,
            context: context,
            distanceKm: distanceKm,
            calories: calories,
            notes: notes,
            source: source
        )
        revisionCenter.publishHumanWorkout(result, command: command, note: note)
        return result
    }

    @discardableResult
    func deleteWorkout(
        _ log: HumanWorkoutLog,
        human: Human,
        command: DomainCommand,
        note: String
    ) -> WorkoutDeleteCommandResult {
        let result = WorkoutCommandService.deleteHumanWorkout(log, human: human, context: context)
        revisionCenter.publishHumanWorkoutDelete(result, command: command, note: note)
        return result
    }

    @discardableResult
    func createQuickMedication(
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        firstDoseTime: Date,
        startDate: Date,
        colorHex: String,
        notes: String,
        reminderEnabled: Bool,
        note: String,
        emptyNote: String = "quick.human.medication.noop"
    ) -> HumanMedicationCommandResult? {
        guard let result = HumanMedicationCommandService.createMedication(
            human: human,
            name: name,
            dosage: dosage,
            frequency: frequency,
            firstDoseTime: firstDoseTime,
            startDate: startDate,
            colorHex: colorHex,
            notes: notes,
            context: context,
            reminderEnabled: reminderEnabled
        ) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .quickHumanMedication(humanID: human.id),
                    affectedEntityIDs: [human.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishQuickHumanMedication(result, note: note)
        return result
    }

    @discardableResult
    func saveMedicationPlan(
        human: Human,
        editing existingMedication: HumanMedication?,
        input: HumanMedicationPlanCommandInput,
        scheduleReminders: Bool = true,
        note: String? = nil,
        emptyNote: String = "human.medication.plan.invalid"
    ) -> HumanMedicationPlanCommandResult? {
        guard let result = HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: existingMedication,
            input: input,
            context: context,
            scheduleReminders: scheduleReminders
        ) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .humanMedicationPlan(humanID: human.id, medicationID: existingMedication?.id),
                    affectedEntityIDs: [human.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishHumanMedicationPlan(
            result,
            commandMedicationID: existingMedication?.id,
            note: note ?? (result.created ? "human.medication.plan.created" : "human.medication.plan.updated")
        )
        return result
    }

    @discardableResult
    func setMedicationPlanActive(
        human: Human,
        medication: HumanMedication,
        isActive: Bool,
        appLanguage: String,
        scheduleReminders: Bool = true,
        note: String? = nil
    ) -> HumanMedicationPlanActivationCommandResult {
        let result = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: isActive,
            appLanguage: appLanguage,
            context: context,
            scheduleReminders: scheduleReminders
        )
        let revisionNote = note
            ?? (result.scheduledReminderSync ? "human.medication.plan.activation.reminders" : "human.medication.plan.activation")
        revisionCenter.publishHumanMedicationPlanActivation(result, note: revisionNote)
        return result
    }

    @discardableResult
    func deleteMedicationPlan(
        human: Human,
        medication: HumanMedication,
        scheduleReminders: Bool = true,
        note: String
    ) -> HumanMedicationPlanDeleteCommandResult {
        let result = HumanMedicationPlanCommandService.deletePlan(
            human: human,
            medication: medication,
            context: context,
            scheduleReminders: scheduleReminders
        )
        revisionCenter.publishHumanMedicationPlanDelete(result, note: note)
        return result
    }

    @discardableResult
    func setMedicationDoseStatus(
        human: Human,
        medicationID: UUID,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        source: CareLedgerSource = .detail,
        now: Date = Date(),
        note: String? = nil
    ) -> HumanMedicationDoseCommandResult {
        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medicationID,
            scheduledTime: scheduledTime,
            status: status,
            context: context,
            source: source,
            now: now
        )
        let scheduledMinute = Int(scheduledTime.timeIntervalSince1970 / 60)
        let revisionNote = note
            ?? (result.recordedLedgerEvent ? "human.medication.dose.ledger" : "human.medication.dose")
        revisionCenter.publishHumanMedicationDose(result, scheduledMinute: scheduledMinute, note: revisionNote)
        return result
    }

    @discardableResult
    func recordHealthMetric(
        human: Human,
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date,
        notes: String,
        note: String,
        emptyNote: String = "human.health.metric.noop"
    ) -> HumanHealthMetricCommandResult? {
        guard let result = HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            date: date,
            notes: notes,
            context: context
        ) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .humanHealthMetric(humanID: human.id, metricKey: metricKey),
                    affectedEntityIDs: [human.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishHumanHealthMetric(result, note: note)
        return result
    }

    @discardableResult
    func deleteHealthMetric(
        _ log: HumanHealthMetricLog,
        human: Human,
        note: String
    ) -> HumanHealthMetricDeleteCommandResult {
        let result = HumanHealthMetricCommandService.deleteMetricLog(log, human: human, context: context)
        revisionCenter.publishHumanHealthMetricDelete(result, note: note)
        return result
    }

    @discardableResult
    func recordNote(
        human: Human,
        noteText: String,
        date: Date,
        imageAttachments: [UIImage],
        fileAttachments: [HumanNoteFileAttachmentPayload],
        reminderDate: Date?,
        appLanguage: String,
        scheduleNotification: Bool = true,
        note: String,
        emptyNote: String = "human.note.noop"
    ) -> HumanNoteCommandResult? {
        guard let result = HumanNoteCommandService.recordNote(
            human: human,
            note: noteText,
            date: date,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            reminderDate: reminderDate,
            appLanguage: appLanguage,
            context: context,
            scheduleNotification: scheduleNotification
        ) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .humanNote(humanID: human.id),
                    affectedEntityIDs: [human.id],
                    wroteBusinessFact: false,
                    note: emptyNote
                )
            )
            return nil
        }
        revisionCenter.publishHumanNote(result, note: note)
        return result
    }

    @discardableResult
    func deleteNote(
        human: Human,
        rawString: String,
        note: String? = nil
    ) -> HumanNoteDeleteResult {
        let result = HumanNoteCommandService.deleteNote(
            human: human,
            rawString: rawString,
            context: context
        )
        revisionCenter.publishHumanNoteDelete(
            result,
            note: note ?? (result.didDelete ? "human.note.delete" : "human.note.delete.noop")
        )
        return result
    }
}

struct CalendarEventPlanCommandInput: Equatable {
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let eventType: EventType
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let reminderLeadMinutes: Int?
    let assigneeId: String?

    var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CalendarEventPlanCommandResult: Equatable {
    let eventID: UUID
    let reminderIDs: [UUID]
    let scheduledReminderSync: Bool
}

enum CalendarEventPlanCommandService {
    private static let maxReminderOccurrences = 500

    @discardableResult
    @MainActor
    static func createEvent(
        input: CalendarEventPlanCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true
    ) -> CalendarEventPlanCommandResult? {
        guard !input.cleanTitle.isEmpty else { return nil }

        let event = Event(
            title: input.cleanTitle,
            startDate: input.startDate,
            endDate: nil,
            isAllDay: input.isAllDay,
            eventType: input.eventType.rawValue,
            relatedEntityType: input.relatedEntityType,
            relatedEntityId: input.relatedEntityId
        )
        event.recurrenceDays = input.recurrenceDays
        event.recurrenceEndDate = input.recurrenceDays > 0 ? input.recurrenceEndDate : nil
        event.assigneeId = input.assigneeId
        context.insert(event)

        let createdReminders = createReminders(for: event, input: input, context: context)
        context.safeSave()

        let shouldScheduleReminders = scheduleNotifications && !createdReminders.isEmpty
        if shouldScheduleReminders {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleManyIfNeeded(
                    reminders: createdReminders,
                    context: context,
                    source: .calendar
                )
            }
        }

        return CalendarEventPlanCommandResult(
            eventID: event.id,
            reminderIDs: createdReminders.map(\.id),
            scheduledReminderSync: shouldScheduleReminders
        )
    }

    @MainActor
    private static func createReminders(
        for event: Event,
        input: CalendarEventPlanCommandInput,
        context: ModelContext
    ) -> [Reminder] {
        guard let leadMinutes = input.reminderLeadMinutes else { return [] }

        let calendar = Calendar.current
        if input.recurrenceDays >= 1, let recurrenceEndDate = input.recurrenceEndDate {
            var reminders: [Reminder] = []
            var cursor = input.startDate
            var safetyCount = 0
            while cursor <= recurrenceEndDate && safetyCount < maxReminderOccurrences {
                let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: cursor) ?? cursor
                let reminder = Reminder(event: event, scheduledAt: scheduled)
                context.insert(reminder)
                reminders.append(reminder)

                guard let next = calendar.date(byAdding: .day, value: input.recurrenceDays, to: cursor),
                      next > cursor else {
                    break
                }
                cursor = next
                safetyCount += 1
            }
            return reminders
        }

        let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: input.startDate) ?? input.startDate
        let reminder = Reminder(event: event, scheduledAt: scheduled)
        context.insert(reminder)
        return [reminder]
    }
}

enum EventCompletionCommandService {
    @discardableResult
    @MainActor
    static func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext,
        executorId: String? = nil,
        now: Date = Date()
    ) -> EventCompletionRewardResult {
        guard event.isActionableTask else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }
        guard !hasTodayCareCheckIn(for: event, context: context, now: now) else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: true, coconutDelta: 0)
        }

        let before = QuestManager.shared.coconutCount
        QuestManager.shared.addCoconuts(
            5,
            emoji: "🥥",
            title: event.title + " 完成奖励",
            actorId: executorId
        )
        let coconutDelta = max(0, QuestManager.shared.coconutCount - before)
        CareLedgerService.record(
            occurredAt: now,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: subjectKind(for: event),
            subjectId: event.relatedEntityId.isEmpty ? nil : event.relatedEntityId,
            eventKind: .coconut,
            actionType: "eventCompletionReward",
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            coconutDelta: coconutDelta,
            metadataJSON: "{\"occurrence\":\"\(Event.occurrenceStorageKey(for: occurrenceDate))\"}",
            context: context
        )
        return EventCompletionRewardResult(awarded: coconutDelta > 0, skippedByExistingCare: false, coconutDelta: coconutDelta)
    }

    @MainActor
    private static func hasTodayCareCheckIn(for event: Event, context: ModelContext, now: Date) -> Bool {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet" else { return false }
        let petId = event.relatedEntityId
        let text = "\(event.title) \(event.eventType)".lowercased()
        let isFeeding = text.contains("喂") || text.contains("feed") || text.contains("吃")
        let isWatering = text.contains("水") || text.contains("喝")
        let isPotty = text.contains("便") || text.contains("铲") || text.contains("potty")
        let isWalk = text.contains("遛") || text.contains("散步") || text.contains("巡岛") || text.contains("walk")
        guard isFeeding || isWatering || isPotty || isWalk else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        if isPotty {
            let descriptor = FetchDescriptor<PetPottyLog>(
                predicate: #Predicate { log in
                    log.date >= today && log.date < tomorrow
                }
            )
            guard let logs = try? context.fetch(descriptor) else { return false }
            return logs.contains { $0.pet?.id.uuidString == petId }
        }
        if isWalk {
            let descriptor = FetchDescriptor<PetWalkLog>(
                predicate: #Predicate { log in
                    log.startDate >= today && log.startDate < tomorrow
                }
            )
            guard let logs = try? context.fetch(descriptor) else { return false }
            return logs.contains { $0.pet?.id.uuidString == petId }
        }

        let careType = isFeeding ? CareType.feeding.rawValue : CareType.watering.rawValue
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate { log in
                log.date >= today && log.date < tomorrow
            }
        )
        guard let logs = try? context.fetch(descriptor) else { return false }
        return logs.contains { $0.pet?.id.uuidString == petId && $0.type == careType }
    }

    private static func subjectKind(for event: Event) -> CareLedgerSubjectKind {
        switch event.relatedEntityType {
        case EntityKind.pet.rawValue, "pet":
            return .pet
        case EntityKind.human.rawValue, "human":
            return .human
        case EntityKind.plant.rawValue, "plant":
            return .plant
        default:
            return event.relatedEntityId.isEmpty ? .system : .unknown
        }
    }
}

@MainActor
struct EventCompletionCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        executorId: String?,
        now: Date = Date(),
        note: String
    ) -> EventCompletionRewardResult {
        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: occurrenceDate,
            context: context,
            executorId: executorId,
            now: now
        )
        revisionCenter.publishEventCompletionReward(result, eventID: event.id, note: note)
        return result
    }
}

struct CalendarEventCompletionResult: Equatable {
    let eventID: UUID
    let isCompleted: Bool
    let syncedReminderCount: Int
}

enum CalendarEventDeletionScope: Equatable {
    case wholeEvent
    case singleOccurrence
    case thisAndFuture

    var revisionActionKey: String {
        switch self {
        case .wholeEvent:
            return "wholeEvent"
        case .singleOccurrence:
            return "singleOccurrence"
        case .thisAndFuture:
            return "thisAndFuture"
        }
    }
}

enum CalendarEventDeletionOutcome: Equatable {
    case deletedEvent(UUID)
    case advancedStart(UUID)
    case truncated(UUID)
    case split(originalID: UUID, newEventID: UUID)

    var primaryEventID: UUID {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            return id
        case let .split(originalID, _):
            return originalID
        }
    }

    var affectedEventIDs: Set<UUID> {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            return [id]
        case let .split(originalID, newEventID):
            return [originalID, newEventID]
        }
    }
}

enum CalendarEventCommandService {
    @discardableResult
    @MainActor
    static func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        now: Date = Date()
    ) -> CalendarEventCompletionResult {
        let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
        event.setOccurrenceMarkedComplete(shouldComplete, on: occurrenceDate)
        CalendarTaskCompletionSyncService.syncPetTask(
            event: event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            pets: pets,
            context: context,
            executorId: executorId
        )

        let remindersToSync = remindersForCompletionSync(event: event, now: now)
        for reminder in remindersToSync {
            if shouldComplete {
                ReminderCompletionService.complete(reminder, by: executorId, context: context)
            } else {
                ReminderCompletionService.reopen(reminder, by: executorId, context: context)
            }
        }
        if remindersToSync.isEmpty {
            context.safeSave()
        }

        return CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: shouldComplete,
            syncedReminderCount: remindersToSync.count
        )
    }

    private static func remindersForCompletionSync(event: Event, now: Date) -> [Reminder] {
        guard event.recurrenceDays == 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return event.reminders.filter { reminder in
            reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow
        }
    }

    @discardableResult
    @MainActor
    static func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let outcome: CalendarEventDeletionOutcome
        switch scope {
        case .wholeEvent:
            outcome = .deletedEvent(event.id)
            context.delete(event)
        case .singleOccurrence:
            outcome = deleteSingleOccurrence(event: event, occurrenceDate: occurrenceDate, context: context)
        case .thisAndFuture:
            outcome = deleteThisAndFuture(event: event, occurrenceDate: occurrenceDate, context: context)
        }
        context.safeSave()
        return outcome
    }

    @MainActor
    private static func deleteSingleOccurrence(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart == eventStart {
            guard let next = calendar.date(byAdding: .day, value: event.recurrenceDays, to: eventStart) else {
                context.delete(event)
                return .deletedEvent(event.id)
            }
            let hasMore = event.recurrenceEndDate.map { next <= calendar.startOfDay(for: $0) } ?? true
            if hasMore {
                event.startDate = next
                return .advancedStart(event.id)
            }
            context.delete(event)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        let nextOccurrence = calendar.date(byAdding: .day, value: event.recurrenceDays, to: occurrenceStart) ?? occurrenceStart
        let hasAfter = event.recurrenceEndDate.map { nextOccurrence <= calendar.startOfDay(for: $0) } ?? true

        if hasAfter {
            let newEvent = Event(
                title: event.title,
                startDate: nextOccurrence,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                eventType: event.eventType,
                relatedEntityType: event.relatedEntityType,
                relatedEntityId: event.relatedEntityId
            )
            newEvent.recurrenceDays = event.recurrenceDays
            newEvent.recurrenceEndDate = event.recurrenceEndDate
            newEvent.assigneeId = event.assigneeId
            newEvent.feedRuleKindRaw = event.feedRuleKindRaw
            newEvent.foodKindRaw = event.foodKindRaw
            newEvent.feedAmountGrams = event.feedAmountGrams
            context.insert(newEvent)
            event.recurrenceEndDate = dayBefore
            return .split(originalID: event.id, newEventID: newEvent.id)
        }

        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }

    @MainActor
    private static func deleteThisAndFuture(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart <= eventStart {
            context.delete(event)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }
}

@MainActor
struct CalendarCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func createEvent(input: CalendarEventPlanCommandInput) -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: nil)
        guard let result = CalendarEventPlanCommandService.createEvent(input: input, context: context) else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: command,
                    wroteBusinessFact: false,
                    note: "calendar.event.create.empty"
                )
            )
            return nil
        }

        revisionCenter.publishCalendarEventPlan(
            result,
            relatedEntityId: input.relatedEntityId,
            note: result.scheduledReminderSync ? "calendar.event.created.reminders" : "calendar.event.created"
        )
        return result
    }

    @discardableResult
    func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        executorId: String?,
        note: String
    ) -> CalendarEventCompletionResult {
        let result = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: pets,
            context: context,
            executorId: executorId
        )
        revisionCenter.publishCalendarEventCompletion(result, note: note)
        return result
    }

    @discardableResult
    func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        note: String
    ) -> CalendarEventDeletionOutcome {
        let outcome = CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: occurrenceDate,
            scope: scope,
            context: context
        )
        revisionCenter.publishCalendarEventDeletion(outcome, scope: scope, note: note)
        return outcome
    }
}

struct ReminderCommandResult: Equatable {
    let reminderID: UUID
    let eventID: UUID?
    let action: String
}

@MainActor
struct ReminderCommandExecutor {
    let context: ModelContext
    let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func complete(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        ReminderCompletionService.complete(reminder, by: humanId, context: context)
        return publish(reminder, action: "complete", note: note)
    }

    @discardableResult
    func completeWithCoconutReward(
        _ reminder: Reminder,
        by humanId: String?,
        amount: Int,
        title: String,
        emoji: String = "✅",
        note: String
    ) -> ReminderCommandResult {
        ReminderCompletionService.complete(reminder, by: humanId, context: context)
        if amount != 0 {
            QuestManager.shared.addCoconuts(
                amount,
                emoji: emoji,
                reason: title,
                actorId: humanId
            )
            CareLedgerService.recordCoconut(
                delta: amount,
                title: title,
                actorId: humanId,
                actorName: nil,
                source: .economy,
                context: context
            )
        }
        return publish(reminder, action: "complete.reward", note: note)
    }

    @discardableResult
    func skip(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        ReminderCompletionService.skip(reminder, by: humanId, context: context)
        return publish(reminder, action: "skip", note: note)
    }

    @discardableResult
    func reopen(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        ReminderCompletionService.reopen(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: "reopen", note: note)
    }

    @discardableResult
    func snoozeOneDay(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        ReminderCompletionService.snoozeOneDay(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: "snoozeOneDay", note: note)
    }

    @discardableResult
    private func publish(_ reminder: Reminder, action: String, note: String) -> ReminderCommandResult {
        let result = ReminderCommandResult(
            reminderID: reminder.id,
            eventID: reminder.event?.id,
            action: action
        )
        revisionCenter.publishReminderAction(result, note: note)
        return result
    }
}
