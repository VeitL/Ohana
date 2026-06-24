//
//  QuickFeedAntiRepeatScreenModel.swift
//  Ohana
//
//  Read helper for quick-feed duplicate-care warnings.
//

import Foundation

struct QuickFeedAntiRepeatScreenModel {
    let pet: Pet
    let currentUserId: String?
    let humans: [Human]
    let feedingLedgerEntries: [QuickFeedLedgerEntry]
    let now: Date

    func recentFeedingWarning() -> (executorName: String, minutesAgo: Int)? {
        let thresholdSeconds = Double(120 * 60)
        let recentEntries = feedingLedgerEntries
            .filter { entry in
                entry.petId == pet.id &&
                    now.timeIntervalSince(entry.date) >= 0 &&
                    now.timeIntervalSince(entry.date) < thresholdSeconds
            }
            .sorted { $0.date > $1.date }
        guard let latestEntry = recentEntries.first else { return nil }

        let minutesAgo = Int(now.timeIntervalSince(latestEntry.date) / 60)
        var executorName = "某人"
        if let actorId = latestEntry.actorId, !actorId.isEmpty {
            if actorId == currentUserId {
                executorName = "你"
            } else if let human = humans.first(where: { $0.id.uuidString == actorId }) {
                executorName = human.name
            }
        }

        return (executorName, max(1, minutesAgo))
    }
}
