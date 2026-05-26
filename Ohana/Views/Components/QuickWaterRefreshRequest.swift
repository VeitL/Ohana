//
//  QuickWaterRefreshRequest.swift
//  Ohana
//
//  Coalesced refresh flags for the water sheet's route-scoped render snapshot.
//

import Foundation

struct QuickWaterRefreshRequest: OptionSet {
    let rawValue: Int

    static let reloadSnapshot = QuickWaterRefreshRequest(rawValue: 1 << 0)
    static let syncDisplayedMode = QuickWaterRefreshRequest(rawValue: 1 << 1)
    static let forceDisplayedMode = QuickWaterRefreshRequest(rawValue: 1 << 2)
}
