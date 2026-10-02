import Foundation

/// Wait for evidence of asynchronous work, rather than a guessed number of yields.
@MainActor
enum TestObservation {
    static func wait(timeout: Duration = .seconds(3), until condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard !Task.isCancelled, ContinuousClock.now < deadline else { return false }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                return false
            }
        }
        return true
    }
}

/// Restore shared preferences exactly; removing a key is not restoration.
@MainActor
enum TestPreferences {
    static func preserve(_ keys: [String], in defaults: UserDefaults = .standard) -> () -> Void {
        let previous = keys.compactMap { key in defaults.object(forKey: key).map { (key, $0) } }
        let values = Dictionary(uniqueKeysWithValues: previous)
        return {
            for key in keys {
                if let value = values[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }
}
