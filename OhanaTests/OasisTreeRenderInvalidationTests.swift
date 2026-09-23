import Foundation
import Testing
@testable import Ohana

@Suite(.serialized)
struct OasisTreeRenderInvalidationTests {
    @Test func renderRevisionAdvancesAndWrapsWithoutOverflow() throws {
        let suiteName = "OasisTreeRenderInvalidationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(OasisTreePreferenceStore.advanceRenderRevision(defaults: defaults) == 1)
        #expect(defaults.integer(forKey: OasisTreePreferenceStore.renderRevisionKey) == 1)

        defaults.set(Int.max, forKey: OasisTreePreferenceStore.renderRevisionKey)
        #expect(OasisTreePreferenceStore.advanceRenderRevision(defaults: defaults) == 0)
    }

    @Test func renderRevisionParticipatesInFrozenTreeSnapshotIdentity() {
        let previous = OasisTreeRenderSnapshot(revision: 4, level: 2, progressToNextLevel: 0.4)
        let current = OasisTreeRenderSnapshot(revision: 5, level: 2, progressToNextLevel: 0.4)

        #expect(previous != current)
    }

    @Test func energyChangesInvalidateTheEmbeddedOasisSnapshot() throws {
        let managerSource = try source("Ohana/Features/Oasis/OasisTreeManager.swift")
        let homeSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift")
        let utilitySource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+Utilities.swift")

        #expect(managerSource.components(separatedBy: "OasisTreePreferenceStore.advanceRenderRevision()").count >= 3)
        #expect(homeSource.contains("@AppStorage(OasisTreePreferenceStore.renderRevisionKey)"))
        #expect(utilitySource.contains("revision: oasisTreeRenderRevision"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
