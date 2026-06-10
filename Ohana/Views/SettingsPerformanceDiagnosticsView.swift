//
//  SettingsPerformanceDiagnosticsView.swift
//  Ohana
//
//  Performance diagnostics section split out of SettingsView.
//

import SwiftUI

struct PerformanceDiagnosticsView: View {
    @ObservedObject private var monitor = AppPerformanceMonitor.shared

    private var primaryText: Color {
        Color.ohanaPrimaryText
    }

    private var secondaryText: Color {
        Color.ohanaSecondaryText
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("性能诊断")
                            .font(OhanaFont.adaptive(size: 30, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text("用于验收启动、首页、头像、点击和相机链路。数值越低越好。")
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(secondaryText)
                    }

                    HStack(spacing: 10) {
                        metricSummaryCard(title: "样本", value: "\(monitor.samples.count)", icon: "chart.bar.fill")
                        metricSummaryCard(title: "最近", value: latestMetricText, icon: "timer")
                    }

                    VStack(spacing: 0) {
                        if monitor.samples.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "speedometer") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 28, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goPrimary)
                                Text("还没有性能样本")
                                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(primaryText)
                                Text("回到首页、点击卡片或进入头像裁剪后，这里会记录链路耗时。")
                                    .font(OhanaFont.adaptive(size: 12, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ForEach(monitor.samples) { sample in
                                performanceSampleRow(sample)
                                if sample.id != monitor.samples.last?.id {
                                    OhanaDashedDivider(color: Color.ohanaDivider)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.ohanaCardSurface,
                                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                            .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    )

                    Button {
                        monitor.clear()
                    } label: {
                        Label("清空样本", systemImage: "trash")
                            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(monitor.samples.isEmpty)
                    .opacity(monitor.samples.isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 42)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var latestMetricText: String {
        guard let sample = monitor.samples.first else { return "-" }
        return formatMS(sample.valueMS)
    }

    private func metricSummaryCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(primaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaCardSurface,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func performanceSampleRow(_ sample: AppPerformanceMonitor.Sample) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.name)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(primaryText)
                if let note = sample.note, !note.isEmpty {
                    Text(note)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(secondaryText)
                }
                Text(sample.timestamp.formatted(date: .omitted, time: .standard))
                    .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .monospaced)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(secondaryText.opacity(0.7))
            }
            Spacer(minLength: 8)
            Text(formatMS(sample.valueMS))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(sample.valueMS > 1000 ? Color.goRed : Color.goPrimary)
        }
        .padding(.vertical, 10)
    }

    private func formatMS(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2fs", value / 1000)
        }
        return String(format: "%.0fms", value)
    }
}
