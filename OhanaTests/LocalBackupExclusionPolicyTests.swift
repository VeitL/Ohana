import Foundation
import Testing
@testable import Ohana

struct LocalBackupExclusionPolicyTests {
    @Test func marksDirectoriesAndFilesAsExcludedFromDeviceBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalBackupExclusionPolicyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try LocalBackupExclusionPolicy.excludeFromDeviceBackup(root)

        let rootValues = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(rootValues.isExcludedFromBackup == true)

        let file = root.appendingPathComponent("private-payload.bin")
        try Data("private".utf8).write(to: file, options: [.atomic])
        try LocalBackupExclusionPolicy.excludeFromDeviceBackup(file)

        let fileValues = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(fileValues.isExcludedFromBackup == true)
    }
}
