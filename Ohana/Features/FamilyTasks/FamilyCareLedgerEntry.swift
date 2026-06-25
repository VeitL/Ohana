import Foundation
import SwiftData

struct FamilyCareLedgerEntry: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case care
        case potty
        case walk
        case expense
    }

    let id: UUID
    let petID: UUID
    let date: Date
    let executorIDs: [String]
    let kind: Kind
    let actionType: String

    static func weekStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? calendar.startOfDay(for: now)
    }

    static func fetchPetEntries(
        since start: Date,
        context: ModelContext,
        fetchLimit: Int = 400
    ) -> [FamilyCareLedgerEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        do {
            var descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubject &&
                        event.occurredAt >= start
                },
                sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
            )
            descriptor.fetchLimit = fetchLimit
            return entries(from: try context.fetch(descriptor), start: start)
        } catch {
            OhanaLog.warning(
                "Family care ledger entry fetch failed: \(error.localizedDescription)",
                category: "FamilyTasks"
            )
            return []
        }
    }

    static func entries(
        from ledgerEvents: [CareLedgerEvent],
        petIDs: Set<UUID>? = nil,
        start: Date? = nil,
        end: Date? = nil
    ) -> [FamilyCareLedgerEntry] {
        ledgerEvents.compactMap { event in
            guard event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  let subjectId = event.subjectId,
                  let petID = UUID(uuidString: subjectId),
                  petIDs?.contains(petID) ?? true,
                  start.map({ event.occurredAt >= $0 }) ?? true,
                  end.map({ event.occurredAt < $0 }) ?? true,
                  let kind = Kind(eventKind: event.eventKindEnum)
            else { return nil }

            return FamilyCareLedgerEntry(
                id: event.id,
                petID: petID,
                date: event.occurredAt,
                executorIDs: executorIDs(from: event),
                kind: kind,
                actionType: event.actionType
            )
        }
    }

    private static func executorIDs(from event: CareLedgerEvent) -> [String] {
        let metadataExecutorIDs: [String] = if event.eventKindEnum == .walk {
            CareLedgerMetadata.stringArrayValue(named: "executorIds", in: event.metadataJSON)
        } else {
            []
        }
        let source = metadataExecutorIDs.isEmpty ? [event.actorId].compactMap(\.self) : metadataExecutorIDs
        var seen: Set<String> = []
        return source.compactMap { id in
            let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }
}

private extension FamilyCareLedgerEntry.Kind {
    init?(eventKind: CareLedgerEventKind) {
        switch eventKind {
        case .care:
            self = .care
        case .potty:
            self = .potty
        case .walk:
            self = .walk
        case .expense:
            self = .expense
        default:
            return nil
        }
    }
}
