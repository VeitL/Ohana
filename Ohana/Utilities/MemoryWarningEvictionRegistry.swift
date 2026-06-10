import Foundation
import UIKit

@MainActor
enum MemoryWarningEvictionRegistry {
    private static var observers: [String: NSObjectProtocol] = [:]

    static func register(ownerID: String, handler: @escaping @MainActor () -> Void) {
        guard observers[ownerID] == nil else { return }
        observers[ownerID] = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }
}
