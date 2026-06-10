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

    init(entry: CoconutLogEntry) {
        id = entry.id
        amount = entry.amount
        growthXP = entry.growthXP ?? 0
        emoji = entry.emoji
        title = entry.feedbackMessage ?? entry.title
        actorId = entry.actorId
        date = entry.date
    }
}
