import Foundation

struct FixtureStore {
    let containerURL: URL
    let snapshotURL: URL

    func write(_ data: Data) throws {
        try verifyBackupExclusion(at: containerURL)
        try data.write(to: snapshotURL, options: [.atomic])
        try verifyBackupExclusion(at: snapshotURL)
    }

    func removeSnapshotIfPresent() throws {}

    private func verifyBackupExclusion(at url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
        let persisted = try mutableURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup
        guard persisted == true else { throw CocoaError(.fileWriteUnknown) }
    }
}
