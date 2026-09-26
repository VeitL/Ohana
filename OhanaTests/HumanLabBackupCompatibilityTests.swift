import Foundation
import Testing
@testable import Ohana

@Suite("Human lab backup compatibility")
struct HumanLabBackupCompatibilityTests {
    @Test("Legacy metric JSON decodes without scan provenance fields")
    func legacyMetricDecodes() throws {
        let id = UUID().uuidString
        let createdAt = "2026-08-02T12:00:00Z"
        let json = """
        {
          "id": "\(id)",
          "metricKey": "tsh",
          "unitCode": "mIU_L",
          "value": 2.4,
          "date": "\(createdAt)",
          "notes": "",
          "humanId": null,
          "createdAt": "\(createdAt)"
        }
        """

        let decoded = try JSONDecoder().decode(
            HumanHealthMetricLogBackup.self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(decoded.sourceReportID == nil)
        #expect(decoded.sourceLabel == nil)
        #expect(decoded.referenceLow == nil)
        #expect(decoded.referenceHigh == nil)
        #expect(decoded.referenceRangeText == nil)
        #expect(decoded.reportedFlagRaw == nil)
    }

    @Test("Legacy report JSON decodes as an unspecified capture source")
    func legacyReportDecodes() throws {
        let id = UUID().uuidString
        let humanID = UUID().uuidString
        let createdAt = "2026-08-02T12:00:00Z"
        let json = """
        {
          "id": "\(id)",
          "humanId": "\(humanID)",
          "reportTypeRaw": "\(HealthReportType.bloodTest.rawValue)",
          "conclusionRaw": "\(ReportConclusion.normal.rawValue)",
          "hospitalName": "",
          "doctorName": "",
          "reportDate": "\(createdAt)",
          "nextCheckDate": null,
          "summary": "",
          "notes": "",
          "colorHex": "",
          "createdAt": "\(createdAt)"
        }
        """

        let decoded = try JSONDecoder().decode(
            HumanHealthReportBackup.self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(decoded.captureSourceRaw == nil)
    }
}
