//
//  OnlineFeatureGateNoticeCenter.swift
//  Ohana
//
//  Visible app-level notices for online surfaces blocked in the launch build.
//

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

enum OnlineFeatureGateNoticeCenter {
    static let notificationName = Notification.Name("OhanaOnlineFeatureGateNotice")
    static let reasonUserInfoKey = "reason"

    static func post(_ reason: OnlineFeatureGateNoticeReason) {
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: [reasonUserInfoKey: reason.rawValue]
        )
    }

    static func reason(from notification: Notification) -> OnlineFeatureGateNoticeReason? {
        guard let rawValue = notification.userInfo?[reasonUserInfoKey] as? String else {
            return nil
        }
        return OnlineFeatureGateNoticeReason(rawValue: rawValue)
    }
}
