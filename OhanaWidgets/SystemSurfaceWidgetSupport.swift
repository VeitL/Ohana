import Foundation
import SwiftUI

enum SystemSurfaceCopy {
    static func text(_ key: Key, languageCode: String) -> String {
        let language = normalizedLanguage(languageCode)
        return translations[language]?[key] ?? translations["en"]?[key] ?? key.rawValue
    }

    enum Key: String, Hashable {
        case todayCare
        case completed
        case allDone
        case noTasks
        case overdue
        case personalFeature
        case personalFeatureDetail
        case openOhana
        case unavailable
        case walk
        case paused
        case finished
        case poops
    }

    private static func normalizedLanguage(_ raw: String) -> String {
        let lowercased = raw.lowercased()
        if lowercased.hasPrefix("zh") { return "zh" }
        if lowercased.hasPrefix("de") { return "de" }
        if lowercased.hasPrefix("es") { return "es" }
        if lowercased.hasPrefix("pt") { return "pt" }
        if lowercased.hasPrefix("fr") { return "fr" }
        if lowercased.hasPrefix("ja") { return "ja" }
        if lowercased.hasPrefix("ko") { return "ko" }
        if lowercased.hasPrefix("it") { return "it" }
        return "en"
    }

    private static let translations: [String: [Key: String]] = [
        "en": [
            .todayCare: "Today’s care", .completed: "completed", .allDone: "All done",
            .noTasks: "Nothing due right now", .overdue: "overdue",
            .personalFeature: "Personal feature", .personalFeatureDetail: "Unlock widgets with Ohana Personal.",
            .openOhana: "Open Ohana", .unavailable: "Open Ohana to refresh",
            .walk: "Walk", .paused: "Paused", .finished: "Finished", .poops: "potty"
        ],
        "zh": [
            .todayCare: "今日照护", .completed: "已完成", .allDone: "全部完成",
            .noTasks: "目前没有待办", .overdue: "已逾期",
            .personalFeature: "Personal 功能", .personalFeatureDetail: "升级 Ohana Personal 后使用小组件。",
            .openOhana: "打开 Ohana", .unavailable: "打开 Ohana 以刷新",
            .walk: "遛狗", .paused: "已暂停", .finished: "已结束", .poops: "便便"
        ],
        "de": [
            .todayCare: "Heutige Pflege", .completed: "erledigt", .allDone: "Alles erledigt",
            .noTasks: "Gerade nichts fällig", .overdue: "überfällig",
            .personalFeature: "Personal-Funktion", .personalFeatureDetail: "Widgets mit Ohana Personal freischalten.",
            .openOhana: "Ohana öffnen", .unavailable: "Ohana zum Aktualisieren öffnen",
            .walk: "Spaziergang", .paused: "Pausiert", .finished: "Beendet", .poops: "Kot"
        ],
        "es": [
            .todayCare: "Cuidados de hoy", .completed: "completadas", .allDone: "Todo listo",
            .noTasks: "Nada pendiente ahora", .overdue: "atrasadas",
            .personalFeature: "Función Personal", .personalFeatureDetail: "Desbloquea widgets con Ohana Personal.",
            .openOhana: "Abrir Ohana", .unavailable: "Abre Ohana para actualizar",
            .walk: "Paseo", .paused: "En pausa", .finished: "Finalizado", .poops: "deposiciones"
        ],
        "pt": [
            .todayCare: "Cuidados de hoje", .completed: "concluídas", .allDone: "Tudo feito",
            .noTasks: "Nada pendente agora", .overdue: "atrasadas",
            .personalFeature: "Recurso Personal", .personalFeatureDetail: "Desbloqueie widgets com Ohana Personal.",
            .openOhana: "Abrir Ohana", .unavailable: "Abra o Ohana para atualizar",
            .walk: "Passeio", .paused: "Pausado", .finished: "Finalizado", .poops: "cocô"
        ],
        "fr": [
            .todayCare: "Soins du jour", .completed: "terminées", .allDone: "Tout est fait",
            .noTasks: "Rien à faire maintenant", .overdue: "en retard",
            .personalFeature: "Fonction Personal", .personalFeatureDetail: "Débloquez les widgets avec Ohana Personal.",
            .openOhana: "Ouvrir Ohana", .unavailable: "Ouvrez Ohana pour actualiser",
            .walk: "Promenade", .paused: "En pause", .finished: "Terminée", .poops: "selles"
        ],
        "ja": [
            .todayCare: "今日のケア", .completed: "完了", .allDone: "すべて完了",
            .noTasks: "現在の予定はありません", .overdue: "期限超過",
            .personalFeature: "Personal 機能", .personalFeatureDetail: "Ohana Personal でウィジェットを利用できます。",
            .openOhana: "Ohanaを開く", .unavailable: "Ohanaを開いて更新",
            .walk: "散歩", .paused: "一時停止", .finished: "終了", .poops: "トイレ"
        ],
        "ko": [
            .todayCare: "오늘의 돌봄", .completed: "완료", .allDone: "모두 완료",
            .noTasks: "지금 할 일이 없어요", .overdue: "기한 지남",
            .personalFeature: "Personal 기능", .personalFeatureDetail: "Ohana Personal에서 위젯을 사용할 수 있어요.",
            .openOhana: "Ohana 열기", .unavailable: "Ohana를 열어 새로고침",
            .walk: "산책", .paused: "일시 정지", .finished: "종료", .poops: "배변"
        ],
        "it": [
            .todayCare: "Cure di oggi", .completed: "completate", .allDone: "Tutto fatto",
            .noTasks: "Niente in scadenza", .overdue: "in ritardo",
            .personalFeature: "Funzione Personal", .personalFeatureDetail: "Sblocca i widget con Ohana Personal.",
            .openOhana: "Apri Ohana", .unavailable: "Apri Ohana per aggiornare",
            .walk: "Passeggiata", .paused: "In pausa", .finished: "Terminata", .poops: "bisogni"
        ]
    ]
}

enum WalkSurfaceFormatter {
    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func distance(_ meters: Double, systemCode: String) -> String {
        let meters = max(0, meters)
        if systemCode == "imperial" {
            let miles = meters / 1609.344
            if miles >= 0.1 { return String(format: "%.2f mi", miles) }
            return String(format: "%.0f ft", meters * 3.28084)
        }
        if meters >= 1000 { return String(format: "%.2f km", meters / 1000) }
        return String(format: "%.0f m", meters)
    }
}
