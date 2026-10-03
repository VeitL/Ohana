import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanHealthCommandOwnershipTests {
    @Test func humanMedicationCommandsRejectForeignPlanAndDoseMutationMatrix() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        let editMedication = HumanMedication(
            humanId: owner.id.uuidString,
            name: "Owner edit medication",
            dosage: "1 tablet",
            frequency: .daily
        )
        let activationMedication = HumanMedication(
            humanId: owner.id.uuidString.lowercased(),
            name: "Owner activation medication",
            dosage: "2 tablets",
            frequency: .daily
        )
        let deleteMedication = HumanMedication(
            humanId: owner.id.uuidString,
            name: "Owner delete medication",
            dosage: "3 tablets",
            frequency: .daily
        )
        let doseMedication = HumanMedication(
            humanId: owner.id.uuidString,
            name: "Owner dose medication",
            dosage: "4 tablets",
            frequency: .daily
        )
        let editEvent = medicationEvent(for: editMedication)
        let activationEvent = medicationEvent(for: activationMedication)
        let deleteEvent = medicationEvent(for: deleteMedication)

        context.insert(owner)
        context.insert(otherHuman)
        context.insert(editMedication)
        context.insert(activationMedication)
        context.insert(deleteMedication)
        context.insert(doseMedication)
        context.insert(editEvent)
        context.insert(activationEvent)
        context.insert(deleteEvent)
        try context.save()

        let updateResult = HumanMedicationPlanCommandService.savePlan(
            human: otherHuman,
            editing: editMedication,
            input: HumanMedicationPlanCommandInput(
                name: "Stolen medication",
                dosage: "9 tablets",
                frequency: .daily,
                customFrequencyNote: "",
                doseMinutes: [9 * 60],
                weeklyWeekday: 2,
                startDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
                endDate: nil,
                colorHex: "FF0000",
                visibleNotes: "foreign update",
                isActive: true,
                appLanguage: "en"
            ),
            context: context,
            scheduleReminders: false
        )
        let activationResult = HumanMedicationPlanCommandService.setPlanActive(
            human: otherHuman,
            medication: activationMedication,
            isActive: false,
            appLanguage: "en",
            context: context,
            scheduleReminders: false
        )
        let deleteResult = HumanMedicationPlanCommandService.deletePlan(
            human: otherHuman,
            medication: deleteMedication,
            context: context,
            scheduleReminders: false
        )
        let doseResult = HumanMedicationDoseCommandService.setDoseStatus(
            human: otherHuman,
            medicationID: doseMedication.id,
            scheduledTime: Date(timeIntervalSinceReferenceDate: 800_000_100),
            status: .taken,
            context: context,
            now: Date(timeIntervalSinceReferenceDate: 800_000_101)
        )

        #expect(updateResult == nil)
        #expect(!activationResult.didChange)
        #expect(!activationResult.didPersist)
        #expect(activationResult.isActive)
        #expect(!deleteResult.didChange)
        #expect(!deleteResult.didPersist)
        #expect(!doseResult.didChange)
        #expect(!doseResult.didPersist)
        #expect(!doseResult.recordedLedgerEvent)
        #expect(editMedication.humanId == owner.id.uuidString)
        #expect(editMedication.name == "Owner edit medication")
        #expect(activationMedication.humanId == owner.id.uuidString.lowercased())
        #expect(activationMedication.isActive)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).count == 4)
        #expect(Set(try context.fetch(FetchDescriptor<Event>()).map(\.id)) == [
            editEvent.id,
            activationEvent.id,
            deleteEvent.id
        ])
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func humanHealthCommandsRejectForeignMetricAndReportMutationMatrix() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let otherHuman = Human(name: "Other")
        let metric = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.4,
            notes: "owner metric",
            human: owner
        )
        let updateReport = HumanHealthReport(
            humanId: owner.id.uuidString.lowercased(),
            reportType: .bloodTest,
            conclusion: .attention,
            hospitalName: "Owner Hospital",
            summary: "owner update report"
        )
        let deleteReport = HumanHealthReport(
            humanId: owner.id.uuidString,
            reportType: .physical,
            conclusion: .normal,
            hospitalName: "Owner Clinic",
            summary: "owner delete report"
        )
        context.insert(owner)
        context.insert(otherHuman)
        owner.healthMetricLogs.append(metric)
        context.insert(metric)
        context.insert(updateReport)
        context.insert(deleteReport)
        try context.save()

        let updateResult = HumanHealthReportCommandService.updateReport(
            updateReport,
            human: otherHuman,
            input: HumanHealthReportCommandInput(
                reportType: .cardiac,
                conclusion: .critical,
                hospitalName: "Foreign Hospital",
                doctorName: "Foreign Doctor",
                reportDate: Date(timeIntervalSinceReferenceDate: 800_001_000),
                nextCheckDate: nil,
                summary: "foreign update",
                notes: "foreign notes"
            ),
            context: context
        )
        let metricUpdateResult = HumanHealthMetricCommandService.updateMetricLog(
            metric,
            human: otherHuman,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mIU_L",
                value: 9.9,
                date: Date(timeIntervalSinceReferenceDate: 800_001_000),
                notes: "foreign metric update"
            ),
            context: context
        )
        let deleteResult = HumanHealthReportCommandService.deleteReport(
            deleteReport,
            human: otherHuman,
            context: context
        )
        let metricDeleteResult = HumanHealthMetricCommandService.deleteMetricLog(
            metric,
            human: otherHuman,
            context: context
        )

        #expect(!updateResult.didChange)
        #expect(!metricUpdateResult.didChange)
        #expect(!metricUpdateResult.didPersist)
        #expect(!deleteResult.didChange)
        #expect(!metricDeleteResult.didChange)
        #expect(updateReport.humanId == owner.id.uuidString.lowercased())
        #expect(updateReport.reportType == .bloodTest)
        #expect(updateReport.conclusion == .attention)
        #expect(updateReport.hospitalName == "Owner Hospital")
        #expect(updateReport.summary == "owner update report")
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).map(\.id) == [metric.id])
        #expect(metric.human?.id == owner.id)
        #expect(metric.value == 2.4)
        #expect(metric.notes == "owner metric")
        #expect(owner.healthMetricLogs.map(\.id) == [metric.id])
        #expect(otherHuman.healthMetricLogs.isEmpty)
        #expect(!context.hasChanges)
    }

    private func medicationEvent(for medication: HumanMedication) -> Event {
        Event(
            title: medication.name,
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV97.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
