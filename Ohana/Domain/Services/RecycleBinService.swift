//
//  RecycleBinService.swift
//  Ohana
//
//  Recoverable deletion boundary for D8/D16.
//

import Foundation
import SwiftData

protocol RecycleBinSoftDeletable: AnyObject {
    var id: UUID { get }
    var trashedAt: Date? { get set }
    var trashExpiresAt: Date? { get set }
    var trashBatchId: String { get set }
    var trashedByHumanId: String { get set }
}

extension RecycleBinSoftDeletable {
    var isInRecycleBin: Bool { trashedAt != nil }
}

extension Sequence where Element: RecycleBinSoftDeletable {
    var activeRecycleBinItems: [Element] {
        filter { $0.trashedAt == nil }
    }
}

extension Pet: RecycleBinSoftDeletable {}
extension Human: RecycleBinSoftDeletable {}
extension Plant: RecycleBinSoftDeletable {}
extension Event: RecycleBinSoftDeletable {}
extension PetCareLog: RecycleBinSoftDeletable {}
extension PetPottyLog: RecycleBinSoftDeletable {}
extension PetWalkLog: RecycleBinSoftDeletable {}
extension PetWeightLog: RecycleBinSoftDeletable {}
extension PetExpenseLog: RecycleBinSoftDeletable {}
extension PetHygieneLog: RecycleBinSoftDeletable {}
extension PetHealthLog: RecycleBinSoftDeletable {}
extension SymptomLog: RecycleBinSoftDeletable {}
extension HeatCycleLog: RecycleBinSoftDeletable {}
extension PetFoodRecord: RecycleBinSoftDeletable {}
extension PetMedication: RecycleBinSoftDeletable {}
extension PetPhotoLog: RecycleBinSoftDeletable {}
extension PetMilestone: RecycleBinSoftDeletable {}
extension PetDocument: RecycleBinSoftDeletable {}
extension PetInsurance: RecycleBinSoftDeletable {}

nonisolated enum RecycleBinEntryKind: String, Codable, CaseIterable {
    case pet
    case human
    case plant
    case petPhoto
    case petMilestone
    case petDocument
    case petInsurance
    case petHealthLog
    case symptomLog
    case heatCycleLog
    case petActivityClearBatch
}

struct RecycleBinListItem: Identifiable, Equatable {
    let id: String
    let kind: RecycleBinEntryKind
    let sourceID: UUID
    let title: String
    let subtitle: String
    let trashedAt: Date
    let trashExpiresAt: Date
    let batchID: UUID?
}

struct RecycleBinPurgeResult: Equatable {
    var purgedSourceCount = 0
    var purgedBatchCount = 0

    var didChange: Bool {
        purgedSourceCount > 0 || purgedBatchCount > 0
    }
}

struct RecycleBinRestoreResult: Equatable {
    let restoredSourceCount: Int
    let restoredBatchCount: Int

    var didChange: Bool {
        restoredSourceCount > 0 || restoredBatchCount > 0
    }
}

@MainActor
enum RecycleBinService {
    static let retentionDays = 30
    static let petActivityClearBatchKind = RecycleBinEntryKind.petActivityClearBatch.rawValue
    private static let aggregateReminderActorPrefix = "system:recycle:"

    static func expirationDate(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: retentionDays, to: date)
            ?? date.addingTimeInterval(TimeInterval(retentionDays * 24 * 60 * 60))
    }

    static func moveToRecycleBin(
        _ item: RecycleBinSoftDeletable,
        now: Date = Date(),
        trashedByHumanId: String? = nil,
        batchId: String = "",
        calendar: Calendar = .current,
        context: ModelContext? = nil
    ) {
        item.trashedAt = now
        item.trashExpiresAt = expirationDate(from: now, calendar: calendar)
        item.trashBatchId = batchId
        item.trashedByHumanId = normalizedHumanId(trashedByHumanId)
        if let context {
            markModifiedForSync(item, context: context, modifiedAt: now)
            if let event = item as? Event {
                suppressAggregateReminders(for: event, batchId: batchId, context: context, now: now)
            }
        }
    }

    static func restore(_ item: RecycleBinSoftDeletable, context: ModelContext? = nil) {
        item.trashedAt = nil
        item.trashExpiresAt = nil
        item.trashBatchId = ""
        item.trashedByHumanId = ""
        if let context {
            markModifiedForSync(item, context: context)
        }
    }

    static func listItems(context: ModelContext) -> [RecycleBinListItem] {
        var items: [RecycleBinListItem] = []
        items += trashedMembers(context: context)
        items += trashedPreciousArchives(context: context)
        items += trashedBatches(context: context)
        return items.sorted { left, right in
            if left.trashedAt != right.trashedAt {
                return left.trashedAt > right.trashedAt
            }
            return left.id < right.id
        }
    }

    @discardableResult
    static func restoreItem(_ item: RecycleBinListItem, context: ModelContext) -> RecycleBinRestoreResult {
        if item.trashExpiresAt <= Date() {
            _ = purgeExpired(context: context)
            return RecycleBinRestoreResult(restoredSourceCount: 0, restoredBatchCount: 0)
        }

        if item.kind == .petActivityClearBatch, let batchID = item.batchID {
            return restoreBatch(id: batchID, context: context)
        }

        let restored = restoreSource(kind: item.kind, id: item.sourceID, context: context)
        if restored > 0 {
            context.safeSave()
        }
        return RecycleBinRestoreResult(restoredSourceCount: restored, restoredBatchCount: 0)
    }

    @discardableResult
    static func purgeExpired(context: ModelContext, now: Date = Date()) -> RecycleBinPurgeResult {
        var result = RecycleBinPurgeResult()
        result.purgedSourceCount += purgeExpiredSources(Pet.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredHumans(context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(Plant.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(Event.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetCareLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetPottyLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetWalkLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetWeightLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetExpenseLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetHygieneLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetHealthLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(SymptomLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(HeatCycleLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetFoodRecord.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetMedication.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetPhotoLog.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetMilestone.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetDocument.self, context: context, now: now)
        result.purgedSourceCount += purgeExpiredSources(PetInsurance.self, context: context, now: now)
        result.purgedBatchCount += purgeExpiredBatches(context: context, now: now)
        if result.didChange {
            context.safeSave()
        }
        return result
    }

    static func petActivityClearBatchId(_ id: UUID) -> String {
        "\(petActivityClearBatchKind):\(id.uuidString)"
    }

    static func batchUUID(from raw: String) -> UUID? {
        let prefix = "\(petActivityClearBatchKind):"
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }

    static func aggregateTrashBatchId(kind: String, id: UUID) -> String {
        "aggregate:\(kind):\(id.uuidString)"
    }

    private static func trashedMembers(context: ModelContext) -> [RecycleBinListItem] {
        trashed(Pet.self, context: context).map {
            item(kind: .pet, id: $0.id, title: $0.name, subtitle: "Pet", source: $0)
        } + trashed(Human.self, context: context).map {
            item(kind: .human, id: $0.id, title: $0.name, subtitle: "Human", source: $0)
        } + trashed(Plant.self, context: context).map {
            item(kind: .plant, id: $0.id, title: $0.name, subtitle: "Plant", source: $0)
        }
    }

    private static func trashedPreciousArchives(context: ModelContext) -> [RecycleBinListItem] {
        var items: [RecycleBinListItem] = []

        let petPhotos: [RecycleBinListItem] = trashed(PetPhotoLog.self, context: context)
            .filter(\.trashBatchId.isEmpty)
            .map { item(kind: .petPhoto, id: $0.id, title: $0.note.isEmpty ? "Photo" : $0.note, subtitle: $0.pet?.name ?? "", source: $0) }
        items.append(contentsOf: petPhotos)

        let petMilestones: [RecycleBinListItem] = trashed(PetMilestone.self, context: context)
            .filter(\.trashBatchId.isEmpty)
            .map { item(kind: .petMilestone, id: $0.id, title: $0.title, subtitle: $0.pet?.name ?? "", source: $0) }
        items.append(contentsOf: petMilestones)

        let petDocuments: [RecycleBinListItem] = trashed(PetDocument.self, context: context)
            .filter(\.trashBatchId.isEmpty)
            .map { item(kind: .petDocument, id: $0.id, title: $0.title, subtitle: $0.pet?.name ?? "", source: $0) }
        items.append(contentsOf: petDocuments)

        let petInsurancePolicies: [RecycleBinListItem] = trashed(PetInsurance.self, context: context)
            .filter(\.trashBatchId.isEmpty)
            .map { item(kind: .petInsurance, id: $0.id, title: $0.productName.isEmpty ? $0.companyName : $0.productName, subtitle: $0.pet?.name ?? "", source: $0) }
        items.append(contentsOf: petInsurancePolicies)

        let petHealthLogs: [RecycleBinListItem] = trashed(PetHealthLog.self, context: context)
            .filter(\.trashBatchId.isEmpty)
            .map { item(kind: .petHealthLog, id: $0.id, title: $0.note.isEmpty ? $0.type : $0.note, subtitle: $0.pet?.name ?? "", source: $0) }
        items.append(contentsOf: petHealthLogs)

        return items
    }

    private static func trashedBatches(context: ModelContext) -> [RecycleBinListItem] {
        fetchAll(RecycleBinBatch.self, context: context).map { batch in
            RecycleBinListItem(
                id: "batch:\(batch.id.uuidString)",
                kind: RecycleBinEntryKind(rawValue: batch.kindRaw) ?? .petActivityClearBatch,
                sourceID: UUID(uuidString: batch.sourceEntityId) ?? batch.id,
                title: batch.title,
                subtitle: batch.subtitle,
                trashedAt: batch.trashedAt,
                trashExpiresAt: batch.trashExpiresAt,
                batchID: batch.id
            )
        }
    }

    private static func item(
        kind: RecycleBinEntryKind,
        id: UUID,
        title: String,
        subtitle: String,
        source: RecycleBinSoftDeletable
    ) -> RecycleBinListItem {
        RecycleBinListItem(
            id: "\(kind.rawValue):\(id.uuidString)",
            kind: kind,
            sourceID: id,
            title: title.isEmpty ? kind.rawValue : title,
            subtitle: subtitle,
            trashedAt: source.trashedAt ?? .distantPast,
            trashExpiresAt: source.trashExpiresAt ?? .distantPast,
            batchID: batchUUID(from: source.trashBatchId)
        )
    }

    private static func trashed<T: PersistentModel & RecycleBinSoftDeletable>(
        _: T.Type,
        context: ModelContext
    ) -> [T] {
        fetchAll(T.self, context: context).filter { $0.trashedAt != nil }
    }

    private static func fetchAll<T: PersistentModel>(_: T.Type, context: ModelContext) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning("RecycleBinService failed to fetch \(T.self): \(error.localizedDescription)", category: "Care")
            return []
        }
    }

    private static func restoreSource(kind: RecycleBinEntryKind, id: UUID, context: ModelContext) -> Int {
        switch kind {
        case .pet:
            restoreAggregateSource(Pet.self, id: id, context: context)
        case .human:
            restoreAggregateSource(Human.self, id: id, context: context)
        case .plant:
            restoreAggregateSource(Plant.self, id: id, context: context)
        case .petPhoto:
            restoreSource(PetPhotoLog.self, id: id, context: context)
        case .petMilestone:
            restoreSource(PetMilestone.self, id: id, context: context)
        case .petDocument:
            restoreSource(PetDocument.self, id: id, context: context)
        case .petInsurance:
            restoreSource(PetInsurance.self, id: id, context: context)
        case .petHealthLog:
            restoreSource(PetHealthLog.self, id: id, context: context)
        case .symptomLog:
            restoreSource(SymptomLog.self, id: id, context: context)
        case .heatCycleLog:
            restoreSource(HeatCycleLog.self, id: id, context: context)
        case .petActivityClearBatch:
            0
        }
    }

    private static func restoreSource<T: PersistentModel & RecycleBinSoftDeletable>(
        _: T.Type,
        id: UUID,
        context: ModelContext
    ) -> Int {
        guard let source = fetchAll(T.self, context: context).first(where: { $0.id == id && $0.trashedAt != nil }) else {
            return 0
        }
        let batchId = source.trashBatchId
        restore(source, context: context)
        return 1 + restoreAggregateReminders(batchId: batchId, context: context)
    }

    private static func restoreAggregateSource<T: PersistentModel & RecycleBinSoftDeletable>(
        _: T.Type,
        id: UUID,
        context: ModelContext
    ) -> Int {
        guard let source = fetchAll(T.self, context: context).first(where: { $0.id == id && $0.trashedAt != nil }) else {
            return 0
        }
        let batchId = source.trashBatchId
        restore(source, context: context)
        let restoredEvents = restoreAggregateEvents(batchId: batchId, context: context)
        let restoredReminders = restoreAggregateReminders(batchId: batchId, context: context)
        return 1 + restoredEvents + restoredReminders
    }

    private static func restoreAggregateEvents(batchId: String, context: ModelContext) -> Int {
        guard !batchId.isEmpty else { return 0 }
        let events = fetchAll(Event.self, context: context).filter {
            $0.trashBatchId == batchId && $0.trashedAt != nil
        }
        for event in events {
            restore(event, context: context)
        }
        return events.count
    }

    private static func restoreBatch(id: UUID, context: ModelContext) -> RecycleBinRestoreResult {
        guard let batch = fetchAll(RecycleBinBatch.self, context: context).first(where: { $0.id == id }) else {
            return RecycleBinRestoreResult(restoredSourceCount: 0, restoredBatchCount: 0)
        }
        let batchId = petActivityClearBatchId(id)
        var restoredCount = 0
        restoredCount += restoreBatchSources(Event.self, batchId: batchId, context: context)
        restoredCount += restoreAggregateReminders(batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetCareLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetPottyLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetWalkLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetWeightLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetExpenseLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetHygieneLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetHealthLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(SymptomLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(HeatCycleLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetFoodRecord.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetMedication.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetPhotoLog.self, batchId: batchId, context: context)
        restoredCount += restoreBatchSources(PetMilestone.self, batchId: batchId, context: context)
        restorePetStateIfNeeded(from: batch, context: context)
        context.delete(batch)
        context.safeSave()
        return RecycleBinRestoreResult(restoredSourceCount: restoredCount, restoredBatchCount: 1)
    }

    private static func restoreBatchSources<T: PersistentModel & RecycleBinSoftDeletable>(
        _: T.Type,
        batchId: String,
        context: ModelContext
    ) -> Int {
        let sources = fetchAll(T.self, context: context).filter { $0.trashBatchId == batchId }
        for source in sources {
            restore(source, context: context)
        }
        return sources.count
    }

    private static func purgeExpiredSources<T: PersistentModel & RecycleBinSoftDeletable>(
        _: T.Type,
        context: ModelContext,
        now: Date
    ) -> Int {
        let expired = fetchAll(T.self, context: context).filter { source in
            guard let expiresAt = source.trashExpiresAt else { return false }
            return expiresAt <= now
        }
        for source in expired {
            markCascadeDeletedForSync(source, context: context, deletedAt: now)
            markDeletedForSync(source, context: context, deletedAt: now)
            context.delete(source)
        }
        return expired.count
    }

    private static func purgeExpiredHumans(context: ModelContext, now: Date) -> Int {
        let expired = fetchAll(Human.self, context: context).filter { source in
            guard let expiresAt = source.trashExpiresAt else { return false }
            return expiresAt <= now
        }
        var purgedCount = 0
        for human in expired {
            purgedCount += purgeHumanScopedRows(for: human, context: context, deletedAt: now)
            markDeletedForSync(human, context: context, deletedAt: now)
            context.delete(human)
            purgedCount += 1
        }
        return purgedCount
    }

    private static func purgeExpiredBatches(context: ModelContext, now: Date) -> Int {
        let expired = fetchAll(RecycleBinBatch.self, context: context).filter { $0.trashExpiresAt <= now }
        for batch in expired {
            context.delete(batch)
        }
        return expired.count
    }

    private static func restorePetStateIfNeeded(from batch: RecycleBinBatch, context: ModelContext) {
        guard let petID = UUID(uuidString: batch.sourceEntityId),
              let metadata = try? JSONDecoder().decode(PetActivityClearBatchMetadata.self, from: Data(batch.metadataJSON.utf8)),
              let pet = fetchAll(Pet.self, context: context).first(where: { $0.id == petID })
        else { return }
        pet.currentStreak = metadata.previousStreak
        pet.lastCheckInDate = metadata.previousLastCheckInReferenceDate.map(Date.init(timeIntervalSinceReferenceDate:))
        CloudSyncMutationRecorder.markModified(pet, context: context)
    }

    private static func markModifiedForSync(
        _ source: RecycleBinSoftDeletable,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) {
        switch source {
        case let pet as Pet:
            CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: modifiedAt)
        case let human as Human:
            CloudSyncMutationRecorder.markModified(human, context: context, modifiedAt: modifiedAt)
        case let event as Event:
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: modifiedAt)
        case let log as PetCareLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetPottyLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetHygieneLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetHealthLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetWalkLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetExpenseLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetWeightLog:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        case let log as PetFoodRecord:
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: modifiedAt)
        default:
            break
        }
    }

    static func markDeletedForSync(
        _ source: RecycleBinSoftDeletable,
        context: ModelContext,
        deletedAt: Date = Date()
    ) {
        switch source {
        case let pet as Pet:
            CloudSyncMutationRecorder.markDeleted(pet, context: context, deletedAt: deletedAt, deletedByHumanId: pet.trashedByHumanId)
        case let human as Human:
            CloudSyncMutationRecorder.markDeleted(human, context: context, deletedAt: deletedAt, deletedByHumanId: human.trashedByHumanId)
        case let event as Event:
            CloudSyncMutationRecorder.markDeleted(event, context: context, deletedAt: deletedAt, deletedByHumanId: event.trashedByHumanId)
        case let log as PetCareLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetPottyLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetHygieneLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetHealthLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetWalkLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetExpenseLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetWeightLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as PetFoodRecord:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let medication as PetMedication:
            CloudSyncMutationRecorder.markDeleted(medication, pet: medication.pet, context: context, deletedAt: deletedAt, deletedByHumanId: medication.trashedByHumanId)
        case let photo as PetPhotoLog:
            CloudSyncMutationRecorder.markDeleted(photo, pet: photo.pet, context: context, deletedAt: deletedAt, deletedByHumanId: photo.trashedByHumanId)
        case let milestone as PetMilestone:
            CloudSyncMutationRecorder.markDeleted(milestone, pet: milestone.pet, context: context, deletedAt: deletedAt, deletedByHumanId: milestone.trashedByHumanId)
        case let document as PetDocument:
            CloudSyncMutationRecorder.markDeleted(document, pet: document.pet, context: context, deletedAt: deletedAt, deletedByHumanId: document.trashedByHumanId)
        case let insurance as PetInsurance:
            CloudSyncMutationRecorder.markDeleted(insurance, pet: insurance.pet, context: context, deletedAt: deletedAt, deletedByHumanId: insurance.trashedByHumanId)
        case let log as SymptomLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        case let log as HeatCycleLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: log.trashedByHumanId)
        default:
            break
        }
    }

    private static func normalizedHumanId(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func aggregateReminderActorId(batchId: String) -> String {
        aggregateReminderActorPrefix + batchId
    }

    private static func suppressAggregateReminders(
        for event: Event,
        batchId: String,
        context: ModelContext,
        now: Date
    ) {
        guard !batchId.isEmpty else { return }
        let actorId = aggregateReminderActorId(batchId: batchId)
        for reminder in event.reminders where reminder.statusEnum == .pending || reminder.statusEnum == .failed || reminder.statusEnum == .snoozed {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            reminder.statusEnum = .skipped
            reminder.completedAt = nil
            reminder.completedBy = actorId
            CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
        }
    }

    private static func restoreAggregateReminders(batchId: String, context: ModelContext) -> Int {
        guard !batchId.isEmpty else { return 0 }
        let actorId = aggregateReminderActorId(batchId: batchId)
        let reminders = fetchAll(Reminder.self, context: context).filter {
            $0.completedBy == actorId && $0.statusEnum == .skipped
        }
        for reminder in reminders {
            reminder.statusEnum = .pending
            reminder.completedAt = nil
            reminder.completedBy = ""
            reminder.event?.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
            CloudSyncMutationRecorder.markModified(reminder, context: context)
            if reminder.scheduledAt > Date() {
                OhanaNotifications.current.schedule(reminder: reminder)
            }
        }
        return reminders.count
    }

    private static func markCascadeDeletedForSync(
        _ source: RecycleBinSoftDeletable,
        context: ModelContext,
        deletedAt: Date
    ) {
        if let pet = source as? Pet {
            markPetCascadeDeletedForSync(pet, context: context, deletedAt: deletedAt)
        } else if let event = source as? Event {
            let deletedBy = event.trashedByHumanId
            for reminder in event.reminders {
                CloudSyncMutationRecorder.markDeleted(reminder, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
            }
        } else if let insurance = source as? PetInsurance {
            let deletedBy = insurance.trashedByHumanId
            for claim in insurance.claims {
                CloudSyncMutationRecorder.markDeleted(claim, pet: insurance.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
            }
        }
    }

    private static func markPetCascadeDeletedForSync(
        _ pet: Pet,
        context: ModelContext,
        deletedAt: Date
    ) {
        let deletedBy = pet.trashedByHumanId
        for log in pet.careLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.pottyLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.hygieneLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.healthLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.walkLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.expenseLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.weightLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for record in pet.foodRecords {
            CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for medication in pet.medications {
            CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for photo in pet.photoLogs {
            CloudSyncMutationRecorder.markDeleted(photo, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for milestone in pet.milestones {
            CloudSyncMutationRecorder.markDeleted(milestone, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for document in pet.documents {
            CloudSyncMutationRecorder.markDeleted(document, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for insurance in pet.insurances {
            for claim in insurance.claims {
                CloudSyncMutationRecorder.markDeleted(claim, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
            }
            CloudSyncMutationRecorder.markDeleted(insurance, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.symptomLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        for log in pet.heatCycleLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
    }

    private static func purgeHumanScopedRows(
        for human: Human,
        context: ModelContext,
        deletedAt: Date
    ) -> Int {
        let humanId = human.id.uuidString
        let deletedBy = human.trashedByHumanId
        var purgedCount = 0

        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanMedication.self, context: context).filter { $0.humanId == humanId },
            context: context
        ) { medication in
            CloudSyncMutationRecorder.markDeleted(medication, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanMedicationLog.self, context: context).filter { $0.humanId == humanId },
            context: context
        ) { log in
            CloudSyncMutationRecorder.markDeleted(log, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanHealthReport.self, context: context).filter { $0.humanId == humanId },
            context: context
        ) { report in
            CloudSyncMutationRecorder.markDeleted(report, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(WishlistItem.self, context: context).filter { $0.creatorId == humanId },
            context: context
        ) { item in
            CloudSyncMutationRecorder.markDeleted(item, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(PetExpenseLog.self, context: context).filter { $0.executorId == humanId && $0.pet == nil },
            context: context
        ) { log in
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanWeightLog.self, context: context).filter { $0.human?.id == human.id },
            context: context
        ) { log in
            CloudSyncMutationRecorder.markDeleted(log, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanWorkoutLog.self, context: context).filter { $0.human?.id == human.id },
            context: context
        ) { log in
            CloudSyncMutationRecorder.markDeleted(log, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }
        purgedCount += deleteHumanScopedRows(
            fetchAll(HumanHealthMetricLog.self, context: context).filter { $0.human?.id == human.id },
            context: context
        ) { log in
            CloudSyncMutationRecorder.markDeleted(log, context: context, deletedAt: deletedAt, deletedByHumanId: deletedBy)
        }

        return purgedCount
    }

    private static func deleteHumanScopedRows<T: PersistentModel>(
        _ rows: [T],
        context: ModelContext,
        markDeleted: (T) -> Void
    ) -> Int {
        for row in rows {
            markDeleted(row)
            context.delete(row)
        }
        return rows.count
    }
}

struct PetActivityClearBatchMetadata: Codable, Equatable {
    let previousStreak: Int
    let previousLastCheckInReferenceDate: TimeInterval?

    init(pet: Pet) {
        previousStreak = pet.currentStreak
        previousLastCheckInReferenceDate = pet.lastCheckInDate?.timeIntervalSinceReferenceDate
    }
}
