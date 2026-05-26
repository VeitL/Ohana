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
    var detail: String?
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

struct FeedModeTransitionRenderState {
    let id: UUID
    let fromMode: FeedOperatingMode
    let toMode: FeedOperatingMode
    var progress: CGFloat
    let viewState: FeedHomeViewState

    var isAnimating: Bool {
        progress < 0.999
    }
}

struct FeedGuidedTaskTransition {
    let fromTask: FeedGuidedTaskState
    let toTask: FeedGuidedTaskState
    let progress: CGFloat

    var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }
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
    var secondaryIcon: String?
    var secondaryAccessibilityLabel: String?
    let action: () -> Void
    var secondaryAction: (() -> Void)?
}

struct GuidedFeedHomeView: View {
    let task: FeedGuidedTaskState
    let taskTransition: FeedGuidedTaskTransition?
    let modeTitle: String
    let modeOptions: [FeedGuidedModeOption]
    let chart: FeedGuidedChartState?
    let dockItems: [FeedDiscoveryDockItem]
    let primaryAction: () -> Void
    let taskSettingsAction: () -> Void
    let inlineTaskPanel: AnyView?
    let inlineTreatPanel: AnyView?

    var body: some View {
        VStack(spacing: 14) {
            FeedGuidedModeStrip(title: modeTitle, options: modeOptions)

            FeedPrimaryTaskCard(
                task: task,
                taskTransition: taskTransition,
                primaryAction: primaryAction,
                settingsAction: taskSettingsAction,
                inlinePanel: inlineTaskPanel
            )

            if let chart {
                FeedGuidedMiniChartCard(chart: chart)
            }

            FeedDiscoveryDock(items: dockItems, inlineTreatPanel: inlineTreatPanel)
        }
    }
}

private struct FeedGuidedModeStrip: View {
    let title: String
    let options: [FeedGuidedModeOption]

    @Namespace private var selectionNamespace

    private var selectedOptionID: String {
        options.first(where: \.isSelected)?.id ?? ""
    }

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
                        .contentTransition(.opacity)
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
                        .background {
                            ZStack {
                                Capsule()
                                    .fill(option.tint.opacity(0.12))

                                if option.isSelected {
                                    Capsule()
                                        .fill(option.tint)
                                        .matchedGeometryEffect(id: "feedModeSelection", in: selectionNamespace)
                                }
                            }
                        }
                        .overlay {
                            Capsule()
                                .stroke(option.isSelected ? option.tint.opacity(0.35) : Color.clear, lineWidth: 2)
                        }
                        .contentShape(Capsule())
                        .scaleEffect(option.isSelected ? 1.015 : 1)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .zIndex(option.isSelected ? 1 : 0)
                }
            }
            .animation(GoMotion.page, value: selectedOptionID)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 22)
    }
}

private struct FeedPrimaryTaskCard: View {
    let task: FeedGuidedTaskState
    let taskTransition: FeedGuidedTaskTransition?
    let primaryAction: () -> Void
    let settingsAction: () -> Void
    let inlinePanel: AnyView?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let taskTransition {
                    let p = taskTransition.clampedProgress
                    FeedPrimaryTaskSurface(task: taskTransition.fromTask, primaryAction: primaryAction, settingsAction: settingsAction)
                        .opacity(Double(1 - p))
                        .scaleEffect(1 - p * 0.025, anchor: .center)
                        .offset(x: -18 * p)
                        .zIndex(p < 0.5 ? 2 : 1)
                        .allowsHitTesting(false)

                    FeedPrimaryTaskSurface(task: taskTransition.toTask, primaryAction: primaryAction, settingsAction: settingsAction)
                        .opacity(Double(p))
                        .scaleEffect(0.985 + p * 0.015, anchor: .center)
                        .offset(x: 18 * (1 - p))
                        .zIndex(p >= 0.5 ? 2 : 1)
                        .allowsHitTesting(p > 0.98)
                } else {
                    FeedPrimaryTaskSurface(task: task, primaryAction: primaryAction, settingsAction: settingsAction)
                }
            }
            .zIndex(2)
            .frame(maxWidth: .infinity)
            .checkInPulse((taskTransition?.toTask ?? task).feedbackToken)

            if let inlinePanel {
                inlinePanel
                    .padding(.top, -6)
                    .modifier(FeedBottomEdgeDrawerReveal())
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FeedBottomEdgeDrawerReveal: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
    }
}

private struct FeedPrimaryTaskSurface: View {
    let task: FeedGuidedTaskState
    let primaryAction: () -> Void
    let settingsAction: () -> Void

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
                        .contentTransition(.opacity)

                    Spacer()

                    Button(action: settingsAction) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(task.modeTint)
                            .frame(width: 44, height: 44)
                            .background(Color.ohanaControlFill, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(Text("Settings"))
                }

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .contentTransition(.opacity)

                        Text(task.detail)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .contentTransition(.opacity)
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
                        .contentTransition(.opacity)
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
        .frame(maxWidth: .infinity)
        .frame(minHeight: 224)
        .feedFlatBlockSurface(cornerRadius: 26)
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
            if let detail = metric.detail {
                Text(detail)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(metric.isHighlighted ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
            }
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
    let inlineTreatPanel: AnyView?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(items.prefix(2))) { item in
                    if item.id == "treat" {
                        FeedDiscoveryLargeDockCard(item: item, inlinePanel: inlineTreatPanel)
                    } else {
                        FeedDiscoveryLargeDockCard(item: item, inlinePanel: nil)
                    }
                }
            }

            ForEach(Array(items.dropFirst(2))) { item in
                FeedDiscoveryCompactDockCard(item: item)
            }
        }
    }
}

private struct FeedDiscoveryLargeDockCard: View {
    let item: FeedDiscoveryDockItem
    let inlinePanel: AnyView?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Button {
                    OhanaFeedback.light()
                    item.action()
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(item.tint)
                            .frame(width: 42, height: 42)
                            .background(item.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        Spacer(minLength: 0)
                        Text(item.title)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(item.value)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(item.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 118)
                    .padding(14)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                if let secondaryIcon = item.secondaryIcon, let secondaryAction = item.secondaryAction {
                    Button {
                        OhanaFeedback.light()
                        secondaryAction()
                    } label: {
                        Image(systemName: secondaryIcon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 44, height: 44)
                            .background(item.tint, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(Text(item.secondaryAccessibilityLabel ?? item.title))
                    .padding(8)
                    .zIndex(2)
                }
            }
            .zIndex(2)

            if let inlinePanel {
                inlinePanel
                    .padding(.top, -6)
                    .modifier(FeedBottomEdgeDrawerReveal())
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FeedDiscoveryCompactDockCard: View {
    let item: FeedDiscoveryDockItem

    var body: some View {
        Button {
            OhanaFeedback.light()
            item.action()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(item.tint)
                    .frame(width: 36, height: 36)
                    .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(item.title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(item.value)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
