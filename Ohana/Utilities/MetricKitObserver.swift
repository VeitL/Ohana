//
//  MetricKitObserver.swift
//  Ohana
//
//  Production observability via MetricKit: aggregated launch/hang/memory
//  metrics and crash / hang / CPU / disk-write diagnostics. Crash diagnostics
//  are delivered by the system on the next launch, so summaries are persisted
//  and replayed into AppPerformanceMonitor for the in-app diagnostics panel.
//

import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

#if canImport(MetricKit)

@MainActor
final class MetricKitObserver: NSObject {
    static let shared = MetricKitObserver()

    private let store = MetricDiagnosticsStore()
    private var didStart = false

    private override init() {
        super.init()
    }

    /// Registers the subscriber and replays any persisted diagnostics from the
    /// previous session (crashes arrive on the next launch).
    func start() {
        guard !didStart else { return }
        didStart = true

        replayPersistedDiagnostics()
        MXMetricManager.shared.add(self)
    }

    private func replayPersistedDiagnostics() {
        let pending = store.drainUnreported()
        guard !pending.isEmpty else { return }
        for entry in pending {
            AppPerformanceMonitor.shared.record(
                "metrickit_diagnostic_replay",
                valueMS: entry.valueMS,
                note: entry.note
            )
        }
    }

    private func ingest(name: String, valueMS: Double, note: String, persist: Bool) {
        AppPerformanceMonitor.shared.record(name, valueMS: valueMS, note: note)
        if persist {
            store.append(MetricDiagnosticEntry(valueMS: valueMS, note: "\(name): \(note)"))
        }
    }
}

// MARK: - MXMetricManagerSubscriber

extension MetricKitObserver: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let summaries = payloads.map { MetricKitSummarizer.summarize($0) }
        Task { @MainActor in
            for summary in summaries {
                self.ingest(
                    name: "metrickit_metrics",
                    valueMS: summary.hangTimeMS,
                    note: summary.note,
                    persist: false
                )
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let summaries = payloads.flatMap { MetricKitSummarizer.summarize($0) }
        Task { @MainActor in
            for summary in summaries {
                self.ingest(
                    name: summary.name,
                    valueMS: summary.valueMS,
                    note: summary.note,
                    persist: true
                )
            }
        }
    }
}

// MARK: - Summarizers

private enum MetricKitSummarizer {
    struct MetricSummary {
        let hangTimeMS: Double
        let note: String
    }

    struct DiagnosticSummary {
        let name: String
        let valueMS: Double
        let note: String
    }

    static func summarize(_ payload: MXMetricPayload) -> MetricSummary {
        var parts: [String] = []
        var hangMS = 0.0

        if let launch = payload.applicationLaunchMetrics {
            let firstDraw = averageDurationMS(launch.histogrammedTimeToFirstDraw)
            if firstDraw > 0 {
                parts.append("firstDraw≈\(Int(firstDraw))ms")
            }
            let resume = averageDurationMS(launch.histogrammedApplicationResumeTime)
            if resume > 0 {
                parts.append("resume≈\(Int(resume))ms")
            }
        }

        if let responsiveness = payload.applicationResponsivenessMetrics {
            hangMS = averageDurationMS(responsiveness.histogrammedApplicationHangTime)
            if hangMS > 0 {
                parts.append("hang≈\(Int(hangMS))ms")
            }
        }

        if let memory = payload.memoryMetrics {
            let peak = memory.peakMemoryUsage.converted(to: .megabytes).value
            parts.append("peakMem≈\(Int(peak))MB")
        }

        if let exits = payload.applicationExitMetrics {
            let abnormal = exits.backgroundExitData.cumulativeAbnormalExitCount
            if abnormal > 0 {
                parts.append("bgAbnormalExits=\(abnormal)")
            }
        }

        let note = parts.isEmpty ? "no notable metrics" : parts.joined(separator: ", ")
        return MetricSummary(hangTimeMS: hangMS, note: note)
    }

    static func summarize(_ payload: MXDiagnosticPayload) -> [DiagnosticSummary] {
        var summaries: [DiagnosticSummary] = []

        for crash in payload.crashDiagnostics ?? [] {
            let reason = crash.terminationReason ?? "unknown"
            let signal = crash.signal?.stringValue ?? "—"
            let exception = crash.exceptionType?.stringValue ?? "—"
            summaries.append(
                DiagnosticSummary(
                    name: "metrickit_crash",
                    valueMS: 0,
                    note: "reason=\(reason), signal=\(signal), exception=\(exception)"
                )
            )
        }

        for hang in payload.hangDiagnostics ?? [] {
            let ms = hang.hangDuration.converted(to: .milliseconds).value
            summaries.append(
                DiagnosticSummary(
                    name: "metrickit_hang",
                    valueMS: ms,
                    note: "hangDuration≈\(Int(ms))ms"
                )
            )
        }

        for cpu in payload.cpuExceptionDiagnostics ?? [] {
            let seconds = cpu.totalCPUTime.converted(to: .seconds).value
            summaries.append(
                DiagnosticSummary(
                    name: "metrickit_cpu_exception",
                    valueMS: seconds * 1_000,
                    note: "totalCPU≈\(String(format: "%.1f", seconds))s"
                )
            )
        }

        for disk in payload.diskWriteExceptionDiagnostics ?? [] {
            let mb = disk.totalWritesCaused.converted(to: .megabytes).value
            summaries.append(
                DiagnosticSummary(
                    name: "metrickit_disk_write_exception",
                    valueMS: 0,
                    note: "totalWrites≈\(Int(mb))MB"
                )
            )
        }

        return summaries
    }
}

/// Average of bucket midpoints weighted by sample count, converted to ms.
private func averageDurationMS(_ histogram: MXHistogram<UnitDuration>) -> Double {
    let enumerator = histogram.bucketEnumerator
    var totalCount = 0
    var weightedSum = 0.0
    while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitDuration> {
        let mid = (bucket.bucketStart.converted(to: .milliseconds).value
            + bucket.bucketEnd.converted(to: .milliseconds).value) / 2
        weightedSum += mid * Double(bucket.bucketCount)
        totalCount += bucket.bucketCount
    }
    return totalCount > 0 ? weightedSum / Double(totalCount) : 0
}

#else

@MainActor
final class MetricKitObserver {
    static let shared = MetricKitObserver()
    private init() {}
    func start() {}
}

#endif

// MARK: - Persisted diagnostics ring buffer

struct MetricDiagnosticEntry: Codable {
    let valueMS: Double
    let note: String
    let timestamp: Date

    init(valueMS: Double, note: String, timestamp: Date = Date()) {
        self.valueMS = valueMS
        self.note = note
        self.timestamp = timestamp
    }
}

/// Small persistent ring buffer so crash diagnostics (delivered on next launch)
/// survive until they can be surfaced in the diagnostics panel.
final class MetricDiagnosticsStore {
    private let defaults: UserDefaults
    private let key = "ohana_metrickit_pending_diagnostics"
    private let maxEntries = 20
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func append(_ entry: MetricDiagnosticEntry) {
        lock.lock()
        defer { lock.unlock() }
        var entries = loadLocked()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        saveLocked(entries)
    }

    func drainUnreported() -> [MetricDiagnosticEntry] {
        lock.lock()
        defer { lock.unlock() }
        let entries = loadLocked()
        defaults.removeObject(forKey: key)
        return entries
    }

    private func loadLocked() -> [MetricDiagnosticEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([MetricDiagnosticEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveLocked(_ entries: [MetricDiagnosticEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
