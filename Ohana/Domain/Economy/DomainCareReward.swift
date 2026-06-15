//
//  DomainCareReward.swift
//  Ohana
//
//  Feature-neutral reward payloads emitted by domain write/effect paths.
//

import Foundation

enum DomainCareRewardAction: Equatable {
    case walk(distanceMeters: Double)
    case potty(isLitter: Bool)
    case feed
    case water
    case care(type: HygieneType)
    case health
    case expense
    case milestone
    case weight
    case dailyFocusCompletion
    case general(humanReward: Int, petReward: Int, emoji: String, title: String)
}

enum DomainCareRewardQuality: Equatable {
    case none
    case precise
    case withNote
    case withPhoto
    case preciseAndNote
    case preciseAndPhoto
    case preciseNotePhoto

    static func compose(precise: Bool, hasNote: Bool, hasPhoto: Bool) -> DomainCareRewardQuality {
        switch (precise, hasNote, hasPhoto) {
        case (true, true, true): .preciseNotePhoto
        case (true, false, true): .preciseAndPhoto
        case (true, true, false): .preciseAndNote
        case (false, false, true): .withPhoto
        case (false, true, false): .withNote
        case (true, false, false): .precise
        default: .none
        }
    }
}
