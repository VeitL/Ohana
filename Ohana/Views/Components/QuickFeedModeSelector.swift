//
//  QuickFeedModeSelector.swift
//  Ohana
//
//  Compact mode selector shared by feeding management surfaces.
//

import SwiftUI

struct QuickFeedModeSelector: View {
    let localization: L10n
    let selectedMode: FeedOperatingMode
    let onSelect: (FeedOperatingMode) -> Void

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FeedOperatingMode.allCases) { mode in
                modeChip(mode)
            }
        }
        .padding(4)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
        .animation(GoMotion.page, value: selectedMode)
    }

    private func modeChip(_ mode: FeedOperatingMode) -> some View {
        let selected = selectedMode == mode
        let tint = mode.feedTint

        return Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.feedIconName)
                    .font(.system(size: 10, weight: .black))
                Text(mode.feedShortTitle(localization))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(selected ? Color.arkInk : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background {
                if selected {
                    Capsule()
                        .fill(tint)
                        .matchedGeometryEffect(id: "quickFeedModeSelection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .zIndex(selected ? 1 : 0)
    }
}
