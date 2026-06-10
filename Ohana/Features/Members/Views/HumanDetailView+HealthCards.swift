//
//  HumanDetailView+HealthCards.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension HumanDetailView {
    var medicationCard: some View {
        Button { showingMedication = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goRed.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "pills.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goRed)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("吃药提醒")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    if myMeds.isEmpty {
                        Text("暂无用药计划")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(myMeds.prefix(3)) { med in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: med.colorHex))
                                            .frame(width: 6, height: 6) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                        Text(med.name)
                                            .font(OhanaFont.caption(.semibold))
                                            .foregroundStyle(Color(hex: "475569"))
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: med.colorHex).opacity(0.15), in: Capsule())
                                }
                                if myMeds.count > 3 {
                                    Text("+\(myMeds.count - 3)")
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(Color(hex: "6B82C4"))
                                }
                            }
                        }
                    }
                }
                Spacer()
                if !myMeds.isEmpty {
                    ZStack {
                        Circle().fill(Color.goRed).frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        Text("\(myMeds.count)")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.arkInk)
                    }
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: 24)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Health Report Card
    var healthReportCard: some View {
        Button { showingHealthReport = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goTeal.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "stethoscope") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goTeal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("身体检测报告")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    if myReports.isEmpty {
                        Text("暂无检测报告")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    } else {
                        let abnormal = myReports.filter { $0.conclusion == .abnormal || $0.conclusion == .critical }.count
                        HStack(spacing: 6) {
                            Text("\(myReports.count) 份报告")
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color(hex: "6B82C4"))
                            if abnormal > 0 {
                                Text("· \(abnormal) 项异常")
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.goOrange)
                            }
                        }
                    }
                }
                Spacer()
                if !myReports.isEmpty {
                    ZStack {
                        Circle().fill(Color.goTeal).frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        Text("\(myReports.count)")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.arkInk)
                    }
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: 24)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Health Metric Card
    var healthMetricCard: some View {
        let latest = myHealthMetricLogs.sorted {
            if $0.date == $1.date { return $0.createdAt > $1.createdAt }
            return $0.date > $1.date
        }.first

        return Button { showingHealthMetrics = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goTeal.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "waveform.path.ecg.rectangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goTeal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    if let latest,
                       let metric = HealthMetricCatalog.metric(forKey: latest.metricKey),
                       let unit = metric.unit(for: latest.unitCode) {
                        Text("\(metric.displayName(l)) · \(unit.formattedValue(latest.value))")
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color(hex: "6B82C4"))
                            .lineLimit(1)
                    } else {
                        Text(l.tr(zh: "TSH、HbA1c、血压等趋势追踪", en: "Track TSH, HbA1c, blood pressure, and more", de: "TSH, HbA1c, Blutdruck und mehr verfolgen"))
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if !myHealthMetricLogs.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(myHealthMetricLogs.count)")
                            .font(OhanaFont.metric(size: 20))
                            .foregroundStyle(Color.goTeal)
                        if abnormalHealthMetricLogCount > 0 {
                            Text("+\(abnormalHealthMetricLogCount)")
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.goOrange)
                        }
                    }
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: 24)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Weight Card
    var weightCard: some View {
        Button { showWeightHistory = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goPrimary.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "scalemass.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("体重记录")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    if let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first {
                        Text(latest.date, style: .date)
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    } else {
                        Text("暂无记录")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    }
                }
                Spacer()
                if let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", latest.weight))
                            .font(OhanaFont.metric(size: 24))
                            .foregroundStyle(Color.goPrimary)
                        Text("kg")
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(Color.goPrimary.opacity(0.7))
                    }
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: 24)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Show On Home Card
}
