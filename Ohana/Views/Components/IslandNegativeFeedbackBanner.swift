//
//  IslandNegativeFeedbackBanner.swift
//  Ohana
//
//  P0 留存：岛屿负反馈浮窗 — 连断 / 漏药 / 护理超期 / 叶发黄
//  主页轻量提示，可被划走（当日不再显示）
//

import SwiftUI
import SwiftData

struct IslandNegativeFeedbackBanner: View {
    let signals: [IslandNegativeSignal]
    var onDismiss: () -> Void
    var onTap: (IslandNegativeSignal) -> Void

    @AppStorage("islandNegativeBannerDismissedDate") private var dismissedDateRaw: String = ""
    @State private var selectedIndex: Int = 0

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var shouldShow: Bool {
        dismissedDateRaw != todayKey && !signals.isEmpty
    }

    private var current: IslandNegativeSignal? {
        guard selectedIndex < signals.count else { return signals.first }
        return signals[selectedIndex]
    }

    var body: some View {
        if shouldShow, let signal = current {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(signal.severity == .critical
                              ? Color.goRed.opacity(0.18)
                              : Color.goYellow.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: signal.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(signal.severity == .critical ? Color.goRed : Color.goYellow)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(signal.detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                if signals.count > 1 {
                    Text("\(selectedIndex + 1)/\(signals.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.3))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                Button {
                    dismissedDateRaw = todayKey
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        signal.severity == .critical
                            ? Color.goRed.opacity(0.35)
                            : Color.goYellow.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .onTapGesture {
                if signals.count > 1 {
                    selectedIndex = (selectedIndex + 1) % signals.count
                    UISelectionFeedbackGenerator().selectionChanged()
                } else {
                    onTap(signal)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
