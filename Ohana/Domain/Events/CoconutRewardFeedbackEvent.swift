//
//  CoconutRewardFeedbackEvent.swift
//  Ohana
//
//  Typed one-shot event for coconut reward UI feedback.
//

import Foundation

struct OhanaCoconutRewardEvent: Identifiable, Equatable {
    let id: UUID
    let amount: Int
    let growthXP: Int
    let emoji: String
    let title: String
    let actorId: String?
    let date: Date

    init(
        id: UUID = UUID(),
        amount: Int,
        growthXP: Int = 0,
        emoji: String,
        title: String,
        actorId: String?,
        date: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.growthXP = growthXP
        self.emoji = emoji
        self.title = title
        self.actorId = actorId
        self.date = date
    }

    init(entry: CoconutLogEntry) {
        id = entry.id
        amount = entry.amount
        growthXP = entry.growthXP ?? 0
        emoji = entry.emoji
        title = entry.localizedTitle
        actorId = entry.actorId
        date = entry.date
    }
}
