//
//  OhanaLog.swift
//  Ohana
//
//  Small OSLog bridge for places that need lightweight diagnostics without
//  scattering Logger setup across app and test code.
//

import Foundation
import OSLog

enum OhanaLogPrivacy {
    case privateText
    case publicText
}

enum OhanaLog {
    nonisolated static func debug(
        _ message: String,
        category: String = "General",
        privacy: OhanaLogPrivacy = .privateText
    ) {
        switch privacy {
        case .privateText:
            logger(category).debug("\(message, privacy: .private)")
        case .publicText:
            logger(category).debug("\(message, privacy: .public)")
        }
    }

    nonisolated static func info(
        _ message: String,
        category: String = "General",
        privacy: OhanaLogPrivacy = .privateText
    ) {
        switch privacy {
        case .privateText:
            logger(category).info("\(message, privacy: .private)")
        case .publicText:
            logger(category).info("\(message, privacy: .public)")
        }
    }

    nonisolated static func warning(
        _ message: String,
        category: String = "General",
        privacy: OhanaLogPrivacy = .privateText
    ) {
        switch privacy {
        case .privateText:
            logger(category).warning("\(message, privacy: .private)")
        case .publicText:
            logger(category).warning("\(message, privacy: .public)")
        }
    }

    nonisolated static func error(
        _ message: String,
        category: String = "General",
        privacy: OhanaLogPrivacy = .privateText
    ) {
        switch privacy {
        case .privateText:
            logger(category).error("\(message, privacy: .private)")
        case .publicText:
            logger(category).error("\(message, privacy: .public)")
        }
    }

    private nonisolated static func logger(_ category: String) -> Logger {
        Logger(subsystem: "com.guanchen.li.Ohana", category: category)
    }
}
