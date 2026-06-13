//
//  OnlineFeatureGateNoticeCenter.swift
//  Ohana
//
//  Visible app-level notices for online surfaces blocked in the launch build.
//

import Combine
import Foundation

enum OnlineFeatureGateNoticeReason: String, Identifiable, Sendable {
    case cloudShareInviteBlocked

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .cloudShareInviteBlocked:
            l.tr(zh: "联机协作即将推出", en: "Online collaboration is coming soon")
        }
    }

    func message(_ l: L10n) -> String {
        switch self {
        case .cloudShareInviteBlocked:
            l.tr(
                zh: "这个版本不会加入共享家庭，您的本机数据保持不变。",
                en: "This version will not join a shared household. Your local data stays unchanged."
            )
        }
    }
}

@MainActor
enum OnlineFeatureGateNoticeCenter {
    static let notices = PassthroughSubject<OnlineFeatureGateNoticeReason, Never>()

    static func post(_ reason: OnlineFeatureGateNoticeReason) {
        notices.send(reason)
    }
}
