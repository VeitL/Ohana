//
//  GuidedFeedHomeView.swift
//  Ohana
//
//  Progressive home surface for feeding: one primary task plus quiet discovery.
//

import SwiftUI

struct FeedGuidedMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let tint: Color
    var isHighlighted: Bool = false
}

struct FeedGuidedTaskState {
    let modeTitle: String
    let modeIcon: String
    let modeTint: Color
    let title: String
    let metricTitle: String
    let metricValue: String
    let detail: String
    let primaryTitle: String
    let primaryIcon: String
    let isPrimaryEnabled: Bool
    let metrics: [FeedGuidedMetric]
    let feedbackToken: CheckInFeedbackToken?
    let stockFeedbackToken: CheckInFeedbackToken?
}

struct FeedGuidedModeOption: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void
}

struct FeedGuidedChartState {
    let title: String
    let value: String
    let subtitle: String
    let points: [OhanaMinimalChartPoint]
    let tint: Color
    let progress: Double
    let emptyText: String
    let action: () -> Void
}

struct FeedDiscoveryDockItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let tint: Color
    let action: () -> Void
}

struct GuidedFeedHomeView: View {
    let task: FeedGuidedTaskState
    let modeTitle: String
    let modeOptions: [FeedGuidedModeOption]
    let chart: FeedGuidedChartState?
    let dockItems: [FeedDiscoveryDockItem]
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            FeedGuidedModeStrip(title: modeTitle, options: modeOptions)

            FeedPrimaryTaskCard(task: task, primaryAction: primaryAction)

            if let chart {
                FeedGuidedMiniChartCard(chart: chart)
            }

            FeedDiscoveryDock(items: dockItems)
        }
    }
}

private struct FeedGuidedModeStrip: View {
    let title: String
    let options: [FeedGuidedModeOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(title, systemImage: "switch.2")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                if let selected = options.first(where: \.isSelected) {
                    Text(selected.title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(selected.tint)
                }
            }

            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button(action: option.action) {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11, weight: .black))
                            Text(option.title)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.74)
                        }
                        .foregroundStyle(option.isSelected ? Color.arkInk : option.tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(option.isSelected ? option.tint : option.tint.opacity(0.12), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(option.isSelected ? option.tint.opacity(0.35) : Color.clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 22)
    }
}

private struct FeedPrimaryTaskCard: View {
    let task: FeedGuidedTaskState
    let primaryAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Label(task.modeTitle, systemImage: task.modeIcon)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(task.modeTint, in: Capsule())

                    Spacer()

                    Text(task.metricTitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(task.detail)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 8)

                    Text(task.metricValue)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(task.modeTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .contentTransition(.numericText())
                }

                if !task.metrics.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(task.metrics) { metric in
                            FeedGuidedMetricPill(metric: metric)
                        }
                    }
                }

                Button(action: primaryAction) {
                    Label(task.primaryTitle, systemImage: task.primaryIcon)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(task.isPrimaryEnabled ? task.modeTint : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!task.isPrimaryEnabled)
                .opacity(task.isPrimaryEnabled ? 1 : 0.58)
            }
            .padding(16)

            VStack(alignment: .trailing, spacing: 6) {
                if let token = task.feedbackToken {
                    CheckInFeedbackBadge(token: token)
                }
                if let token = task.stockFeedbackToken {
                    CheckInFeedbackBadge(token: token)
                }
            }
            .padding(.top, 54)
            .padding(.trailing, 16)
        }
        .feedFlatBlockSurface(cornerRadius: 26)
        .checkInPulse(task.feedbackToken)
    }
}

private struct FeedGuidedMiniChartCard: View {
    let chart: FeedGuidedChartState

    var body: some View {
        Button(action: chart.action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chart.title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(chart.subtitle)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Text(chart.value)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(chart.tint)
                        .contentTransition(.numericText())
                }

                if chart.points.allSatisfy({ $0.value <= 0 }) {
                    Text(chart.emptyText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(maxWidth: .infinity, minHeight: 70)
                } else {
                    OhanaMinimalBarChart(
                        points: chart.points,
                        tint: chart.tint,
                        progress: chart.progress,
                        showsLabels: true,
                        maxBarHeight: 58
                    )
                    .frame(height: 88)
                    .opacity(0.42 + chart.progress * 0.58)
                    .animation(GoMotion.page, value: chart.progress)
                }
            }
            .padding(13)
            .feedFlatBlockSurface(cornerRadius: 22)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct FeedGuidedMetricPill: View {
    let metric: FeedGuidedMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(metric.isHighlighted ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
                .lineLimit(1)
            Text(metric.value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(metric.isHighlighted ? Color.arkInk : metric.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(metric.isHighlighted ? metric.tint : metric.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(GoMotion.feedback, value: metric.isHighlighted)
    }
}

private struct FeedDiscoveryDock: View {
    let items: [FeedDiscoveryDockItem]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(items) { item in
                Button {
                    OhanaFeedback.light()
                    item.action()
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(item.tint)
                        Text(item.title)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(item.value)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}
