//
//  CoconutLogEntry+Presentation.swift
//  Ohana
//

import Foundation

extension CoconutLogEntry {
    var localizedTitle: String {
        localizedTitle(l: .current)
    }

    func localizedTitle(l: L10n) -> String {
        if let feedbackMessage, !feedbackMessage.isEmpty {
            return DomainCareRewardGeneralTitle.localized(feedbackMessage, fallbackActorName: actorName, l: l) ?? feedbackMessage
        }
        return DomainCareRewardGeneralTitle.localized(title, fallbackActorName: actorName, l: l) ?? title
    }

    var timeAgoString: String {
        timeAgoString(l: .current)
    }

    func timeAgoString(l: L10n) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return l.tr(zh: "刚刚", en: "Just now", de: "Gerade eben")
        }
        if seconds < 3600 {
            let minutes = seconds / 60
            return l.tr(zh: "\(minutes) 分钟前", en: "\(minutes)m ago", de: "vor \(minutes) Min.")
        }
        if seconds < 86400 {
            let hours = seconds / 3600
            return l.tr(zh: "\(hours) 小时前", en: "\(hours)h ago", de: "vor \(hours) Std.")
        }
        if seconds < 86400 * 2 {
            return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern")
        }
        let days = seconds / 86400
        if days < 30 {
            return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) Tagen")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.option(for: l.languageCode).localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}
