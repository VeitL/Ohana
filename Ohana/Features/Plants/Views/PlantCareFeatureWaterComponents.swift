//
//  PlantCareFeatureWaterComponents.swift
//  Ohana
//
//  Value-driven render components for the focused watering route.
//

import SwiftUI

struct PlantWaterModeStrip: View {
    let l: L10n
    @Binding var selectedMode: PlantWaterGuidedMode

    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Label(l.tr(zh: "浇水模式", en: "Watering mode", de: "Gießmodus"), systemImage: "switch.2")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                Text(selectedMode.title(l: l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                ForEach(PlantWaterGuidedMode.allCases) { mode in
                    modeButton(mode)
                }
            }
        }
        .padding(13)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-mode-strip")
    }

    private func modeButton(_ mode: PlantWaterGuidedMode) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            OhanaFeedback.light()
            withAnimation(GoMotion.selection) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .accessibilityHidden(true)
                Text(mode.title(l: l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .fill(Color.goTeal)
                        .matchedGeometryEffect(id: "plant-water-mode-selection", in: selectionNamespace)
                } else {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .fill(Color.goTeal.opacity(0.12))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-care-feature-water-mode-\(mode.rawValue)")
    }
}

struct PlantWaterPrimaryTaskCard: View {
    let l: L10n
    let model: PlantWaterPrimaryCardModel
    let onOpenPlan: () -> Void
    let onQuickRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Label(l.tr(zh: "浇水", en: "Watering", de: "Gießen"), systemImage: "drop.fill")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.goTeal, in: Capsule())

                Spacer()

                Button(action: openPlan) {
                    Image(systemName: "gearshape.fill") // a11y: allow decorative plan glyph; accessibilityLabel names the button.
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                        .contentShape(Circle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "管理浇水计划", en: "Manage watering plan", de: "Gießplan verwalten"))
                .accessibilityIdentifier("plant-care-feature-water-card-plan")
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.title)
                        .font(OhanaFont.adaptive(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(model.habitSummary)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 8)

                Text(model.metricValue)
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 8) {
                ForEach(model.signals) { signal in
                    PlantWaterGuidedMetricPill(signal: signal)
                }
            }

            if let advice = model.advice {
                PlantWaterGuidedNotice(text: advice, tint: Color.goTeal)
            }

            Button(action: quickRecord) {
                Label(l.tr(zh: "快速记录已浇水", en: "Log watered now", de: "Jetzt Gießen erfassen"), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.goTeal, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-care-feature-water-quick-log")
        }
        .padding(16)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-primary-card")
    }

    private func openPlan() {
        OhanaFeedback.light()
        onOpenPlan()
    }

    private func quickRecord() {
        OhanaFeedback.medium()
        onQuickRecord()
    }
}

private struct PlantWaterGuidedMetricPill: View {
    let signal: PlantWateringSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(signal.title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(signal.value)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(signal.tint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(signal.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PlantWaterGuidedNotice: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative advice marker; text carries the content.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }
}

struct PlantWaterGuidedMiniChartCard: View {
    let l: L10n
    let model: PlantWaterChartCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "浇水趋势", en: "Watering trend", de: "Gießtrend"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "只看节奏，详情在历史。", en: "A quiet rhythm. Details in history.", de: "Ruhiger Rhythmus. Details im Verlauf."))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 8)
                Text(l.tr(zh: "目标 \(model.plannedIntervalDays) 天", en: "Target \(model.plannedIntervalDays)d", de: "Ziel \(model.plannedIntervalDays) T."))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            chartContent
        }
        .padding(13)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-chart")
    }

    @ViewBuilder
    private var chartContent: some View {
        if model.isLoading {
            loadingState
        } else if model.points.isEmpty {
            emptyState
        } else {
            OhanaMinimalBarChart(
                points: model.points,
                tint: Color.goTeal,
                progress: 1,
                showsLabels: true,
                maxBarHeight: 58
            )
            .frame(height: 88)
            .accessibilityLabel(l.tr(zh: "\(model.plantName) 的浇水间隔 mini 图表", en: "\(model.plantName) watering interval mini chart", de: "Mini-Gießintervall-Diagramm für \(model.plantName)"))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(l.tr(zh: "还没有足够的浇水间隔", en: "Not enough watering intervals yet", de: "Noch nicht genug Gießintervalle"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(model.wateringLogCount == 0
                ? l.tr(zh: "记录第一次浇水后会开始累积趋势。", en: "The trend starts after the first watering log.", de: "Der Trend beginnt nach dem ersten Gießprotokoll.")
                : l.tr(zh: "再记录一次浇水后会显示实际间隔。", en: "Log one more watering to show the real interval.", de: "Noch einmal gießen erfassen, dann erscheint das echte Intervall."))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(14)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(l.tr(zh: "正在整理浇水节奏", en: "Preparing watering rhythm", de: "Gießrhythmus wird vorbereitet"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "先显示页面，历史趋势稍后补上。", en: "The page stays ready while history loads.", de: "Die Seite bleibt bereit, während der Verlauf lädt."))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(14)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-water-chart-loading")
    }
}

struct PlantWaterCompactDiscoveryDock: View {
    let items: [PlantWaterDiscoveryItem]
    let adviceItems: [String]
    let onSelect: (PlantWaterDiscoveryAction) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]
    private let adviceColumns = [GridItem(.adaptive(minimum: 132), spacing: 8)]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    PlantWaterCompactDiscoveryCard(item: item, onSelect: onSelect)
                }
            }

            if adviceItems.count > 1 {
                LazyVGrid(columns: adviceColumns, spacing: 8) {
                    ForEach(Array(adviceItems.dropFirst().prefix(2)), id: \.self) { advice in
                        PlantWaterAdviceChip(text: advice)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-care-feature-water-discovery-dock")
    }
}

private struct PlantWaterCompactDiscoveryCard: View {
    let item: PlantWaterDiscoveryItem
    let onSelect: (PlantWaterDiscoveryAction) -> Void

    var body: some View {
        Group {
            if let action = item.action {
                Button {
                    OhanaFeedback.light()
                    onSelect(action)
                } label: {
                    content(isInteractive: true)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                content(isInteractive: false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-care-feature-water-dock-\(item.id)")
    }

    private func content(isInteractive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(item.tint)
                    .frame(width: 34, height: 34) // a11y: allow visual glyph frame; card text carries the accessible content.
                    .background(item.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isInteractive {
                    Image(systemName: "chevron.right") // a11y: allow decorative affordance; card label names the action.
                        .font(OhanaFont.adaptive(size: 9, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }
            }

            Text(item.value)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(item.tint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }
}

private struct PlantWaterAdviceChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative advice marker; chip text carries the content.
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.goTeal)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.46), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
