//
//  ModelContextExtensions.swift
//  Ohana
//
//  F9: 统一的 ModelContext.save() 错误日志，替代散落各处的 try? context.save()
//

import SwiftData
import Foundation
import os.log

private let logger = Logger(subsystem: "com.guanchen.li.Ohana", category: "SwiftData")

extension ModelContext {
    /// 安全保存，失败时记录错误日志而非静默吞掉
    func safeSave(file: String = #file, line: Int = #line) {
        do {
            try save()
        } catch {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logger.error("💾 SwiftData save failed at \(fileName):\(line) — \(error.localizedDescription)")
            #if DEBUG
            print("🚨 SwiftData save FAILED at \(fileName):\(line): \(error)")
            #endif
        }
    }
}
