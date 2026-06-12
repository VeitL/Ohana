//
//  QuickCareExecutorPickerBarContainer.swift
//  Ohana
//
//  Feature-owned SwiftData fetch for quick-care executor picking.
//

import SwiftData
import SwiftUI

struct QuickCareExecutorPickerBarContainer: View {
    var tint: Color = .goPrimary
    var compact: Bool = false

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        ExecutorPickerBar(
            humans: humans,
            tint: tint,
            compact: compact
        )
    }
}
