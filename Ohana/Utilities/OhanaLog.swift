//
//  OhanaLog.swift
//  Ohana
//
//  Small OSLog bridge for places that need lightweight diagnostics without
//  scattering Logger setup across app and test code.
//

import Foundation
import OSLog

enum OhanaLog {
    nonisolated static func debug(_ message: String, category: String = "General") {
        logger(category).debug("\(message, privacy: .public)")
    }

    nonisolated static func info(_ message: String, category: String = "General") {
        logger(category).info("\(message, privacy: .public)")
    }

    nonisolated static func warning(_ message: String, category: String = "General") {
        logger(category).warning("\(message, privacy: .public)")
    }

    nonisolated static func error(_ message: String, category: String = "General") {
        logger(category).error("\(message, privacy: .public)")
    }

    private nonisolated static func logger(_ category: String) -> Logger {
        Logger(subsystem: "com.guanchen.li.Ohana", category: category)
    }
}
