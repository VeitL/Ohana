//
//  GachaRouteContainer.swift
//  Ohana
//
//  Screen-level query container for gacha routes.
//

import SwiftData
import SwiftUI

struct GachaRouteContainer: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \GachaOwnedItem.latestObtainedAt, order: .reverse) private var ownedItems: [GachaOwnedItem]
    @Query(sort: \GachaDrawLog.drawDate, order: .reverse) private var drawLogs: [GachaDrawLog]

    var drawsBackground: Bool = true
    var onClose: (() -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    var body: some View {
        GachaView(
            drawsBackground: drawsBackground,
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            humans: humans,
            ownedItems: ownedItems,
            drawLogs: drawLogs
        )
    }
}
