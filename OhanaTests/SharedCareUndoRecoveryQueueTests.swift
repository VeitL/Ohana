import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct SharedCareUndoRecoveryQueueTests {
    @Test func multiplePendingReceiptsRemainVisibleAndRecoveryUsesEarliestDueDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 50000)
        let earlierDeadline = now.addingTimeInterval(5)
        let laterDeadline = now.addingTimeInterval(12)
        let laterRetryDate = now.addingTimeInterval(30)
        let earlierReceipt = makeReceipt(
            occurredAt: now,
            undoDeadline: earlierDeadline
        )
        let laterReceipt = makeReceipt(
            occurredAt: now,
            undoDeadline: laterDeadline
        )

        context.insert(laterReceipt)
        context.insert(earlierReceipt)
        try context.save()

        let initialTokens = SharedCareUndoFinalizationService.pendingUndoTokens(
            context: context,
            now: now
        )

        #expect(initialTokens.count == 2)
        #expect(initialTokens.compactMap(\.receiptID) == [earlierReceipt.id, laterReceipt.id])
        #expect(initialTokens.compactMap(\.undoDeadline) == [earlierDeadline, laterDeadline])
        #expect(
            SharedCareUndoFinalizationService.nextRecoveryDate(
                context: context,
                now: now
            ) == earlierDeadline
        )

        earlierReceipt.state = .externalEffectsPending
        earlierReceipt.nextRetryAt = laterRetryDate
        try context.save()

        let remainingTokens = SharedCareUndoFinalizationService.pendingUndoTokens(
            context: context,
            now: now
        )

        #expect(remainingTokens.compactMap(\.receiptID) == [laterReceipt.id])
        #expect(
            SharedCareUndoFinalizationService.nextRecoveryDate(
                context: context,
                now: now
            ) == laterDeadline
        )
    }

    private func makeReceipt(
        occurredAt: Date,
        undoDeadline: Date
    ) -> SharedCareUndoReceipt {
        let sourcePetID = UUID()
        return SharedCareUndoReceipt(
            sharedSessionId: UUID(),
            sourcePetId: sourcePetID,
            targetPetIds: [sourcePetID, UUID()],
            actionKind: .litterScoop,
            occurredAt: occurredAt,
            createdAt: occurredAt,
            undoDeadline: undoDeadline
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV91.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
