import Foundation

struct FixtureStore {
    let snapshotURL: URL

    func write(_ data: Data) throws {
        try data.write(to: snapshotURL)
    }

    func removeSnapshotIfPresent() throws {}
}
