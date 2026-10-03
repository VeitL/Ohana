import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HumanRehydrateNormalizationTests {
    @Test func rehydrateCanonicalizesHumanHealthOwnersAndRejectsCrossHumanDoseLogs() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Schema(ArkSchemaV97.models),
            configurations: [configuration]
        )
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let other = Human(name: "Other")
        context.insert(owner)
        context.insert(other)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let medicationID = UUID()
        let medicationResult = try DomainMemberContentRehydrateWriter.insertHumanMedicationIfNeeded(
            snapshot: DomainHumanMedicationRehydrateSnapshot(
                id: medicationID,
                humanId: "  \(owner.id.uuidString.lowercased())  ",
                name: "Medication",
                dosage: "5 mg",
                frequencyRaw: MedicationFrequency.daily.rawValue,
                customFrequencyNote: "",
                firstDoseTime: now,
                startDate: now,
                endDate: nil,
                colorHex: "88AAFF",
                notes: "",
                isActive: true,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        #expect(medicationResult.inserted)

        let ownedLogResult = try DomainMemberContentRehydrateWriter.insertHumanMedicationLogIfNeeded(
            snapshot: DomainHumanMedicationLogRehydrateSnapshot(
                id: UUID(),
                humanId: owner.id.uuidString.lowercased(),
                medicationId: medicationID.uuidString.lowercased(),
                scheduledTime: now,
                statusRaw: HumanMedicationStatus.taken.rawValue,
                recordedTime: now,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        #expect(ownedLogResult.inserted)

        let crossHumanLogResult = try DomainMemberContentRehydrateWriter.insertHumanMedicationLogIfNeeded(
            snapshot: DomainHumanMedicationLogRehydrateSnapshot(
                id: UUID(),
                humanId: other.id.uuidString,
                medicationId: medicationID.uuidString,
                scheduledTime: now.addingTimeInterval(60),
                statusRaw: HumanMedicationStatus.taken.rawValue,
                recordedTime: now,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        #expect(!crossHumanLogResult.inserted)

        let reportResult = try DomainMemberContentRehydrateWriter.insertHumanHealthReportIfNeeded(
            snapshot: DomainHumanHealthReportRehydrateSnapshot(
                id: UUID(),
                humanId: owner.id.uuidString.lowercased(),
                reportTypeRaw: HealthReportType.physical.rawValue,
                conclusionRaw: ReportConclusion.normal.rawValue,
                hospitalName: "Clinic",
                doctorName: "Doctor",
                reportDate: now,
                nextCheckDate: nil,
                summary: "",
                notes: "",
                recordedByHumanId: other.id.uuidString.lowercased(),
                colorHex: "88AAFF",
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        #expect(reportResult.inserted)

        let medications = try context.fetch(FetchDescriptor<HumanMedication>())
        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let reports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        #expect(medications.map(\.humanId) == [owner.id.uuidString])
        #expect(logs.count == 1)
        #expect(logs.first?.humanId == owner.id.uuidString)
        #expect(logs.first?.medicationId == medicationID.uuidString)
        #expect(reports.map(\.humanId) == [owner.id.uuidString])
        #expect(reports.first?.recordedByHumanId == other.id.uuidString)
    }
}
