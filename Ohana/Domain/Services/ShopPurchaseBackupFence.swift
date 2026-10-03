//
//  ShopPurchaseBackupFence.swift
//  Ohana
//
//  Fail-closed coordination between durable writes and backup/restore.
//

import Foundation
import SwiftData

nonisolated enum PersistenceWriteFence {
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var activeContainers: Set<ObjectIdentifier> = []

        func tryEnter(_ container: ModelContainer) -> Bool {
            guard lock.try() else { return false }
            defer { lock.unlock() }
            return activeContainers.insert(ObjectIdentifier(container)).inserted
        }

        func leave(_ container: ModelContainer) {
            _ = lock.withLock {
                activeContainers.remove(ObjectIdentifier(container))
            }
        }
    }

    private static let registry = Registry()

    /// Runs an operation only when no purchase, backup, or restore currently
    /// owns the fence. Contention never waits: callers surface a retryable
    /// domain result instead of blocking the main actor or a backup actor.
    static func withExclusiveAccess<Result>(
        context: ModelContext,
        unavailable: () throws -> Result,
        operation: () throws -> Result
    ) rethrows -> Result {
        let container = context.container
        guard registry.tryEnter(container) else {
            return try unavailable()
        }
        defer { registry.leave(container) }
        return try operation()
    }
}

/// Source-compatible spelling kept for existing shop callers. All durable
/// economy commands share the same registry through `PersistenceWriteFence`.
nonisolated enum ShopPurchaseBackupFence {
    static func withExclusiveAccess<Result>(
        context: ModelContext,
        unavailable: () throws -> Result,
        operation: () throws -> Result
    ) rethrows -> Result {
        try PersistenceWriteFence.withExclusiveAccess(
            context: context,
            unavailable: unavailable,
            operation: operation
        )
    }
}
