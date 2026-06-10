//
//  HumanWeightDashboardContent.swift
//  Ohana
//
//  Dashboard content split from WeightExpenseDashboardComponents.
//

import SwiftData
import SwiftUI

struct HumanWeightDashboardContent: View {
    let human: Human
    var onClose: () -> Void
    var onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: PetWeightDashboardContent.WeightRange = .days30
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var logs: [HumanWeightLog] { human.weightLogs.sorted { $0.date > $1.date } }
    private func trendPoints(now: Date = Date()) -> [WeightTrendPoint] {
        WeightTrendDataBuilder.points(
            from: logs.map { (date: $0.date, kilograms: $0.weight) },
            rangeStart: selectedRange.startDate(now: now),
            rangeEnd: now
        )
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(zh: "体重趋势", en: "Weight Trend", de: "Gewicht"),
            subtitle: human.name,
            onClose: onClose,
            leading: {
                FeatureHubAvatar(
                    imageData: human.avatarImageData,
                    emoji: human.avatarEmoji,
                    fallback: "👤",
                    tint: Color(hex: human.safeThemeColorHex)
                )
            },
            trailing: {
                if isViewingOwnProfile {
                    HumanPrivacyToggleButton(human: human, field: .weight)
                }
            },
            content: {
                if isPrivacyLocked {
                    HumanModulePrivacyLockedView(
                        title: l.tr(zh: "体重记录仅本人可见", en: "Weight is private", de: "Gewicht ist privat"),
                        message: l.tr(zh: "请切换到本人账户后查看。", en: "Switch to this account to view it.", de: "Wechsle zu diesem Konto, um es zu sehen.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HumanPrivateDataNotice(human: human, field: .weight)
                        metrics
                        chartBlock
                        historyBlock
                    }
                }
            },
            floating: {
                if !isPrivacyLocked {
                    addButton
                }
            }
        )
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "latest", title: l.tr(zh: "当前", en: "Current", de: "Aktuell"), value: latestWeightText),
            FeatureHubMetric(id: "change", title: l.tr(zh: "变化", en: "Change", de: "Änderung"), value: deltaText),
            FeatureHubMetric(id: "count", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(logs.count)")
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "趋势", en: "Trend", de: "Trend"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: PetWeightDashboardContent.WeightRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }
            let now = Date()
            let points = trendPoints(now: now)
            if !points.isEmpty {
                UnifiedWeightTrendChart(points: points, xDomain: selectedRange.xDomain(now: now), accent: .goPrimary)
                    .frame(height: 190)
            } else {
                emptyState(icon: "chart.xyaxis.line", text: l.tr(zh: "记录 2 次后显示趋势", en: "Add 2 logs to show a trend", de: "2 Einträge zeigen einen Trend"))
            }
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if logs.isEmpty {
                emptyState(icon: "scalemass.fill", text: l.tr(zh: "还没有体重记录", en: "No weight logs yet", de: "Noch keine Gewichtseinträge"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(logs.prefix(20)) { log in
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 14, weight: .black))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(log.date.formatted(date: .omitted, time: .shortened))
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            Spacer()
                            Text(String(format: "%.1f kg", log.weight))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Button {
                                commandQueue.enqueue(
                                    .weightDelete(
                                        entityID: human.id,
                                        entityKind: EntityKind.human.rawValue,
                                        recordID: log.id
                                    )
                                ) {
                                    DashboardRecordCommandExecutor(context: modelContext, services: appServices).deleteHumanWeight(
                                        log,
                                        human: human,
                                        note: "dashboard.weight.delete.\(EntityKind.human.rawValue)"
                                    )
                                }
                            } label: {
                                Image(systemName: "trash").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加体重", en: "Add weight", de: "Gewicht hinzufügen"))
    }

    private var latestWeightText: String {
        guard let latest = logs.first else { return "—" }
        return String(format: "%.1f kg", latest.weight)
    }

    private var deltaText: String {
        guard let latest = logs.first, let previous = logs.dropFirst().first else { return "—" }
        return String(format: "%+.1f kg", latest.weight - previous.weight)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }
}
