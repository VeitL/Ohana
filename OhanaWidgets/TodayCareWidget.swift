import SwiftUI
import WidgetKit

struct TodayCareWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TodayCareWidgetSnapshot
}

struct TodayCareWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> TodayCareWidgetEntry {
        TodayCareWidgetEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayCareWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(entry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TodayCareWidgetEntry>) -> Void) {
        let entry = entry()
        let earliestRefresh = Date().addingTimeInterval(15 * 60)
        completion(
            Timeline(
                entries: [entry],
                policy: .after(max(earliestRefresh, entry.snapshot.nextRefreshAt))
            )
        )
    }

    private func entry() -> TodayCareWidgetEntry {
        let now = Date()
        let storedSnapshot = (try? SystemSurfaceSnapshotStore.live.read()) ?? nil
        let languageCode = storedSnapshot?.languageCode
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        let resolved = if let storedSnapshot, storedSnapshot.isFresh(at: now) {
            storedSnapshot
        } else {
            TodayCareWidgetSnapshot.unavailable(languageCode: languageCode, now: now)
        }
        return TodayCareWidgetEntry(date: now, snapshot: resolved)
    }
}

struct TodayCareWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: OhanaSystemSurfaceConstants.todayCareWidgetKind,
            provider: TodayCareWidgetProvider()
        ) { entry in
            TodayCareWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("WIDGET_TODAY_CARE_NAME")
        .description("WIDGET_TODAY_CARE_DESCRIPTION")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct TodayCareWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayCareWidgetEntry

    var body: some View {
        Group {
            switch entry.snapshot.access {
            case .personal:
                personalContent
                    .privacySensitive()
            case .upgradeRequired:
                accessMessage(
                    symbol: "lock.fill",
                    title: copy(.personalFeature),
                    detail: copy(.personalFeatureDetail)
                )
            case .unavailable:
                accessMessage(
                    symbol: "arrow.clockwise",
                    title: copy(.todayCare),
                    detail: copy(.unavailable)
                )
            }
        }
        .widgetURL(widgetURL)
    }

    @ViewBuilder
    private var personalContent: some View {
        switch family {
        case .systemMedium:
            mediumContent
        case .accessoryRectangular:
            accessoryContent
        default:
            smallContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let item = entry.snapshot.items.first {
                Spacer(minLength: 0)
                Image(systemName: item.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color(for: item.urgency))
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .privacySensitive()
                itemMetadata(item)
            } else {
                Spacer(minLength: 0)
                emptyState
            }
        }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.snapshot.items.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else {
                ForEach(entry.snapshot.items) { item in
                    Link(destination: item.deepLinkURL) {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbolName)
                                .frame(width: 20)
                                .foregroundStyle(color(for: item.urgency))
                                .widgetAccentable()
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                itemMetadata(item)
                            }
                            .privacySensitive()
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var accessoryContent: some View {
        HStack(spacing: 8) {
            Gauge(
                value: Double(entry.snapshot.completedTodayCount),
                in: 0 ... Double(max(1, entry.snapshot.totalTodayCount))
            ) {
                Image(systemName: "heart.text.clipboard").accessibilityHidden(true)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
            .accessibilityLabel(copy(.todayCare))
            .accessibilityValue("\(entry.snapshot.completedTodayCount) \(copy(.completed))")
            VStack(alignment: .leading, spacing: 2) {
                Text(copy(.todayCare))
                    .font(.headline)
                if let item = entry.snapshot.items.first {
                    Text(item.title)
                        .font(.caption)
                        .lineLimit(1)
                        .privacySensitive()
                } else {
                    Text(emptyStateTitle)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(copy(.todayCare))
                .font(.headline)
            Spacer(minLength: 4)
            Text("\(entry.snapshot.completedTodayCount)/\(entry.snapshot.totalTodayCount)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary) // native-ui: allow WidgetKit owns adaptive semantic contrast.
                .accessibilityLabel("\(entry.snapshot.completedTodayCount) \(copy(.completed))")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                .font(.title2)
                .foregroundStyle(.green)
            Text(emptyStateTitle)
                .font(.headline)
            Text("\(entry.snapshot.completedTodayCount) \(copy(.completed))")
                .font(.caption)
                .foregroundStyle(.secondary) // native-ui: allow WidgetKit owns adaptive semantic contrast.
        }
    }

    private var emptyStateTitle: String {
        if entry.snapshot.totalTodayCount > 0,
           entry.snapshot.completedTodayCount >= entry.snapshot.totalTodayCount {
            return copy(.allDone)
        }
        return copy(.noTasks)
    }

    private func accessMessage(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary) // native-ui: allow WidgetKit owns adaptive semantic contrast.
                .lineLimit(family == .systemMedium ? 2 : 3)
            if family == .systemMedium {
                Text(copy(.openOhana))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private func itemMetadata(_ item: TodayCareWidgetItem) -> some View {
        HStack(spacing: 4) {
            if let subjectName = item.subjectName {
                Text(subjectName)
                    .lineLimit(1)
                    .privacySensitive()
            }
            if item.subjectName != nil, item.dueAt != nil {
                Text("·")
            }
            if let dueAt = item.dueAt {
                Text(dueAt, style: .relative)
                    .monospacedDigit()
            }
            if item.urgency == .overdue || item.urgency == .critical {
                Text(copy(.overdue))
                    .foregroundStyle(.red)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary) // native-ui: allow WidgetKit owns adaptive semantic contrast.
        .lineLimit(1)
    }

    private func color(for urgency: TodayCareWidgetUrgency) -> Color {
        switch urgency {
        case .standard: .accentColor
        case .overdue: .orange
        case .critical: .red
        }
    }

    private func copy(_ key: SystemSurfaceCopy.Key) -> String {
        SystemSurfaceCopy.text(key, languageCode: entry.snapshot.languageCode)
    }

    private var widgetURL: URL {
        switch entry.snapshot.access {
        case .personal:
            entry.snapshot.deepLinkURL
        case .upgradeRequired, .unavailable:
            OhanaExternalRoute.settings.url
        }
    }
}

#Preview(as: .systemSmall) {
    TodayCareWidget()
} timeline: {
    TodayCareWidgetEntry(date: .now, snapshot: .placeholder())
}

#Preview(as: .systemMedium) {
    TodayCareWidget()
} timeline: {
    TodayCareWidgetEntry(date: .now, snapshot: .placeholder())
}
