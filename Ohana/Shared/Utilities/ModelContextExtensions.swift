//
//  ModelContextExtensions.swift
//  Ohana
//
//  F9: 统一的 ModelContext.save() 错误日志，替代散落各处的 try? context.save()
//

import Foundation
import os.log
import SwiftData

nonisolated struct ModelContextSaveResult: Equatable, Sendable {
    let didSave: Bool
    let errorDescription: String?

    static let saved = ModelContextSaveResult(didSave: true, errorDescription: nil)

    static func failed(_ error: Error) -> ModelContextSaveResult {
        ModelContextSaveResult(didSave: false, errorDescription: error.localizedDescription)
    }
}

nonisolated struct ModelContextSaveFailureEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let fileName: String
    let line: Int
    let errorDescription: String
    let occurredAt: Date
}

nonisolated enum PersistenceSaveFailureCenter {
    static let notificationName = Notification.Name("OhanaPersistenceSaveFailed")
    static let eventUserInfoKey = "ModelContextSaveFailureEvent"

    static func publish(error: Error, file: String, line: Int) {
        let event = ModelContextSaveFailureEvent(
            id: UUID(),
            fileName: URL(fileURLWithPath: file).lastPathComponent,
            line: line,
            errorDescription: error.localizedDescription,
            occurredAt: Date()
        )
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: [eventUserInfoKey: event]
        )
    }
}

extension ModelContext {
    @discardableResult
    nonisolated func safeSaveResult(
        file: String = #file,
        line: Int = #line,
        publishFailureEvent: Bool = false
    ) -> ModelContextSaveResult {
        do {
            try save()
            return .saved
        } catch {
            Self.logSaveFailure(error, file: file, line: line)
            if publishFailureEvent {
                PersistenceSaveFailureCenter.publish(error: error, file: file, line: line)
            }
            return .failed(error)
        }
    }

    /// 安全保存，失败时记录错误日志而非静默吞掉
    nonisolated func safeSave(file: String = #file, line: Int = #line) {
        _ = safeSaveResult(file: file, line: line, publishFailureEvent: true)
    }

    private nonisolated static func logSaveFailure(_ error: Error, file: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logger = Logger(subsystem: "com.guanchen.li.Ohana", category: "SwiftData")
        logger.error("💾 SwiftData save failed at \(fileName):\(line) — \(error.localizedDescription)")
        #if DEBUG
            OhanaLog.error("SwiftData save failed at \(fileName):\(line): \(error)", category: "SwiftData")
        #endif
    }
}
