import ActivityKit
import SwiftUI
import WidgetKit

struct WalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            WalkLockScreenView(context: context)
                .activityBackgroundTint(Color.green.opacity(0.16))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(OhanaExternalRoute.activeWalk(petID: context.attributes.petID).url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill").accessibilityHidden(true)
                            .foregroundStyle(.green)
                        Text(context.attributes.petName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .privacySensitive()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkPoopCount(
                        state: context.state,
                        languageCode: context.attributes.languageCode
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    WalkElapsedTime(state: context.state, font: .headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(
                            WalkSurfaceFormatter.distance(
                                context.state.distanceMeters,
                                systemCode: context.state.measurementSystemCode
                            ),
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                        )
                        .font(.caption.weight(.semibold))
                        Spacer()
                        WalkPhaseLabel(
                            state: context.state,
                            languageCode: context.attributes.languageCode
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.state.phase == .paused ? "pause.fill" : "pawprint.fill")
                    .foregroundStyle(context.state.phase == .paused ? .orange : .green)
                    .accessibilityHidden(true)
            } compactTrailing: {
                WalkElapsedTime(state: context.state, font: .caption2.monospacedDigit())
                    .frame(maxWidth: 50)
            } minimal: {
                Image(systemName: context.state.phase == .paused ? "pause.fill" : "pawprint.fill")
                    .foregroundStyle(context.state.phase == .paused ? .orange : .green)
                    .accessibilityHidden(true)
            }
            .widgetURL(OhanaExternalRoute.activeWalk(petID: context.attributes.petID).url)
            .keylineTint(.green)
        }
    }
}

private struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.18))
                Image(systemName: "pawprint.fill").accessibilityHidden(true)
                    .foregroundStyle(.green)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.petName)
                    .font(.headline)
                    .lineLimit(1)
                    .privacySensitive()
                WalkPhaseLabel(
                    state: context.state,
                    languageCode: context.attributes.languageCode
                )
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                WalkElapsedTime(state: context.state, font: .title3.monospacedDigit().weight(.semibold))
                HStack(spacing: 8) {
                    Label(
                        WalkSurfaceFormatter.distance(
                            context.state.distanceMeters,
                            systemCode: context.state.measurementSystemCode
                        ),
                        systemImage: "figure.walk"
                    )
                    WalkPoopCount(
                        state: context.state,
                        languageCode: context.attributes.languageCode
                    )
                }
                .font(.caption2)
                .foregroundStyle(.secondary) // native-ui: allow WidgetKit owns adaptive semantic contrast.
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct WalkElapsedTime: View {
    let state: WalkActivityAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            if state.phase == .running {
                Text(state.elapsedReferenceDate, style: .timer)
            } else {
                Text(WalkSurfaceFormatter.elapsed(state.elapsedSeconds))
            }
        }
        .font(font)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .contentTransition(.numericText())
    }
}

private struct WalkPhaseLabel: View {
    let state: WalkActivityAttributes.ContentState
    let languageCode: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }

    private var title: String {
        switch state.phase {
        case .running:
            copy(.walk)
        case .paused:
            copy(.paused)
        case .finished:
            copy(.finished)
        }
    }

    private var symbol: String {
        switch state.phase {
        case .running: "figure.walk"
        case .paused: "pause.circle.fill"
        case .finished: "checkmark.circle.fill"
        }
    }

    private var color: Color {
        switch state.phase {
        case .running: .green
        case .paused: .orange
        case .finished: .secondary
        }
    }

    private func copy(_ key: SystemSurfaceCopy.Key) -> String {
        SystemSurfaceCopy.text(key, languageCode: languageCode)
    }
}

private struct WalkPoopCount: View {
    let state: WalkActivityAttributes.ContentState
    let languageCode: String

    var body: some View {
        Label("\(state.poopCount)", systemImage: "leaf.fill")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.brown)
            .accessibilityLabel("\(state.poopCount) \(copy(.poops))")
    }

    private func copy(_ key: SystemSurfaceCopy.Key) -> String {
        SystemSurfaceCopy.text(key, languageCode: languageCode)
    }
}

#Preview("Walk", as: .content, using: WalkActivityAttributes(
    sessionID: UUID(),
    petID: UUID(),
    petName: "Mochi",
    startedAt: .now.addingTimeInterval(-754),
    languageCode: "en"
)) {
    WalkLiveActivityWidget()
} contentStates: {
    WalkActivityAttributes.ContentState(
        phase: .running,
        elapsedSeconds: 754,
        elapsedReferenceDate: .now.addingTimeInterval(-754),
        distanceMeters: 1240,
        poopCount: 1,
        measurementSystemCode: "metric",
        updatedAt: .now
    )
    WalkActivityAttributes.ContentState(
        phase: .paused,
        elapsedSeconds: 754,
        elapsedReferenceDate: .now.addingTimeInterval(-754),
        distanceMeters: 1240,
        poopCount: 1,
        measurementSystemCode: "metric",
        updatedAt: .now
    )
}
