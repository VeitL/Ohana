import Charts
import Combine
import SwiftData
import SwiftUI

// UI contract: HumanHealthConditionDetailView and native Health record Forms.
// Reason: the same member-owned, read-first health history and record action.
// Allowed divergence: a medication picker, delay picker, and aligned daily plot.
struct HumanHealthMedicationPatternView: View {
    let human: Human
    let condition: HumanHealthCondition
    let onRecordsChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""
    @State private var choices: HumanHealthPatternMedicationChoices?
    @State private var selectedMedicationID: UUID?
    @State private var delay: HumanHealthObservationDelay
    @State private var refresh = 0
    @State private var failed = false
    @State private var showsRecord = false

    init(human: Human, condition: HumanHealthCondition, onRecordsChanged: @escaping () -> Void) {
        self.human = human
        self.condition = condition
        self.onRecordsChanged = onRecordsChanged
        // A viewing hypothesis for this use case, not a medical latency claim.
        _delay = State(initialValue: condition.category == .hairAndScalp ? .twoMonths : .sameDay)
    }

    private var l: L10n { L10n(appLanguage) }
    private var viewerID: UUID? { UUID(uuidString: activeHumanIDRaw) }
    private var isLocked: Bool {
        human.isPrivate(.weight, viewedBy: viewerID) || human.isPrivate(.medication, viewedBy: viewerID)
    }
    private var loadToken: String { "\(human.id)|\(condition.id)|\(refresh)|\(activeHumanIDRaw)|\(isLocked)" }

    var body: some View {
        List {
            Section {
                Text("\(human.name) · \(condition.name)").font(OhanaFont.headline())
                Text(HumanHealthPatternCopy.introduction.text(l)).font(OhanaFont.callout())
            }
            if isLocked {
                Label(l.tr(zh: "健康记录已锁定", en: "Health records are locked", de: "Gesundheitsdaten sind gesperrt"), systemImage: "lock.fill")
            } else if failed {
                Text(HumanHealthHomeText.loadFailed.title(l))
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) { refresh += 1 }
            } else if let choices {
                selectionSection(choices)
                if let selectedMedicationID {
                    HumanHealthMedicationPatternContent(
                        humanID: human.id, conditionID: condition.id, medicationID: selectedMedicationID,
                        viewerID: viewerID, delay: delay
                    )
                    .id("\(loadToken)|\(selectedMedicationID)|\(delay.rawValue)")
                }
            } else { ProgressView() }
        }
        .navigationTitle(HumanHealthPatternCopy.title.text(l))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("human-health-medication-pattern-screen")
        .safeAreaInset(edge: .bottom) {
            if !isLocked, !human.hasPassedAway, condition.trackingStatus != .resolved {
                Button(HumanHealthPatternCopy.recordToday.text(l)) { showsRecord = true }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("human-health-pattern-record-today")
            }
        }
        .sheet(isPresented: $showsRecord) {
            HumanHealthObservationEditorSheet(human: human, condition: condition, observation: nil, canViewMedication: !isLocked, onSaved: {
                refresh += 1
                onRecordsChanged()
            }, onDeleted: {})
        }
        .task(id: loadToken) { await loadChoices() }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { _ in refresh += 1 }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh += 1 } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh += 1 }
    }

    @ViewBuilder
    private func selectionSection(_ choices: HumanHealthPatternMedicationChoices) -> some View {
        Section {
            if choices.medications.isEmpty {
                Text(HumanHealthPatternCopy.noMedication.text(l))
                NavigationLink {
                    HumanMedicationView(human: human)
                } label: {
                    Text(l.tr(zh: "今日用药", en: "Medication today", de: "Medikamente heute"))
                }
            } else {
                Picker(HumanHealthPatternCopy.medication.text(l), selection: $selectedMedicationID) {
                    Text(HumanHealthPatternCopy.chooseMedication.text(l)).tag(nil as UUID?)
                    ForEach(choices.medications) { medication in
                        Text(medication.dosage.isEmpty ? medication.name : "\(medication.name) · \(medication.dosage)")
                            .tag(Optional(medication.id))
                    }
                }
                .accessibilityIdentifier("human-health-pattern-medication-picker")
            }
            Picker(HumanHealthPatternCopy.interval.text(l), selection: $delay) {
                ForEach(HumanHealthObservationDelay.allCases) { option in
                    Text(HumanHealthPatternCopy.daysLater(option.rawValue, l: l)).tag(option)
                }
            }
            .accessibilityIdentifier("human-health-pattern-delay-picker")
            if !choices.isComplete { Text(HumanHealthHomeText.incomplete.title(l)) }
        } footer: {
            Text(HumanHealthPatternCopy.boundary.text(l))
        }
    }

    @MainActor
    private func loadChoices() async {
        choices = nil
        failed = false
        guard !isLocked else { return }
        await Task.yield()
        guard !Task.isCancelled, !isLocked else { return }
        do {
            let loaded = try HumanHealthMedicationPatternReadModel.medications(humanID: human.id, conditionID: condition.id, viewerID: viewerID, context: modelContext)
            if !loaded.medications.contains(where: { $0.id == selectedMedicationID }) {
                let linked = loaded.medications.filter { condition.linkedMedicationIDs.contains($0.id) }
                selectedMedicationID = linked.count == 1 ? linked.first?.id : (loaded.medications.count == 1 ? loaded.medications.first?.id : nil)
            }
            choices = loaded
        } catch { failed = true }
    }
}

private struct HumanHealthMedicationPatternContent: View {
    let humanID: UUID
    let conditionID: UUID
    let medicationID: UUID
    let viewerID: UUID?
    let delay: HumanHealthObservationDelay
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var snapshot: HumanHealthMedicationPatternSnapshot?
    @State private var failed = false
    @State private var retry = 0
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Group {
            if failed {
                Section {
                    Text(HumanHealthHomeText.loadFailed.title(l))
                    Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) { retry += 1 }
                }
            } else if let snapshot {
                results(snapshot)
            } else { ProgressView() }
        }
        .task(id: retry) {
            snapshot = nil
            failed = false
            await Task.yield()
            guard !Task.isCancelled else { return }
            do {
                snapshot = try HumanHealthMedicationPatternReadModel.load(humanID: humanID, conditionID: conditionID, medicationID: medicationID, viewerID: viewerID, delay: delay, context: modelContext)
            } catch { failed = true }
        }
    }

    @ViewBuilder
    private func results(_ snapshot: HumanHealthMedicationPatternSnapshot) -> some View {
        Section(HumanHealthPatternCopy.timeline.text(l)) {
            if !snapshot.isComplete {
                Text(HumanHealthPatternCopy.incomplete.text(l))
                    .accessibilityIdentifier("human-health-pattern-incomplete")
            }
            if snapshot.days.isEmpty {
                Text(HumanHealthPatternCopy.noObservations.text(l))
            } else {
                Text(HumanHealthPatternCopy.coverage(snapshot.pairedDayCount, total: snapshot.days.count, l: l))
                    .font(OhanaFont.callout())
                chart(snapshot)
            }
        }
        if !snapshot.days.isEmpty, snapshot.isComplete {
            Section(HumanHealthPatternCopy.comparison.text(l)) {
                if let comparison = snapshot.comparison {
                    comparisonRow(.taken, mean: comparison.takenMean, count: comparison.takenDays)
                    comparisonRow(.skipped, mean: comparison.skippedMean, count: comparison.skippedDays)
                } else { Text(HumanHealthPatternCopy.insufficient.text(l)) }
            }
            .accessibilityIdentifier("human-health-pattern-comparison")
        }
        Section {
            DisclosureGroup(HumanHealthPatternCopy.history.text(l)) {
                ForEach(snapshot.days.reversed()) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(day.severity.formatted(.number.precision(.fractionLength(1))))/10")
                        Text("\(day.medicationDate.formatted(date: .abbreviated, time: .omitted)) · \(day.medicationState.title(l))")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            DisclosureGroup(HumanHealthPatternCopy.method.text(l)) {
                Text(HumanHealthPatternCopy.methodDetail.text(l))
                    .font(OhanaFont.callout())
            }
        }
    }

    private func comparisonRow(_ status: HumanHealthMedicationDayState, mean: Double, count: Int) -> some View {
        LabeledContent(status.title(l), value: HumanHealthPatternCopy.mean(mean, days: count, l: l))
    }

    private func chart(_ snapshot: HumanHealthMedicationPatternSnapshot) -> some View {
        Chart(snapshot.days) { day in
            PointMark(x: .value(HumanHealthPatternCopy.date.text(l), day.date), y: .value(HumanHealthPatternCopy.severity.text(l), day.severity))
                .foregroundStyle(by: .value(HumanHealthPatternCopy.medication.text(l), day.medicationState.title(l)))
                .symbol(by: .value(HumanHealthPatternCopy.medication.text(l), day.medicationState.title(l)))
                .accessibilityLabel(Text("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(day.medicationState.title(l))"))
                .accessibilityValue(Text("\(day.severity.formatted(.number.precision(.fractionLength(1))))/10"))
        }
        .chartYScale(domain: 0 ... 10)
        .chartXScale(domain: snapshot.start ... snapshot.end)
        .chartForegroundStyleScale(domain: HumanHealthMedicationDayState.allCases.map { $0.title(l) }, range: [Color.goBlue, Color.goOrange, Color.goPurple, Color.ohanaSecondaryText])
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .frame(height: 220)
        .accessibilityLabel(HumanHealthPatternCopy.timeline.text(l))
        .accessibilityIdentifier("human-health-pattern-chart")
    }
}
