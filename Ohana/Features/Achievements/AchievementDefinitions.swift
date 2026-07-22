//
//  AchievementDefinitions.swift
//  Ohana
//
//  Stable catalog shared by progression, rewards, backup, and presentation.
//

import Foundation

nonisolated enum AchievementScopeKind: String, Codable, CaseIterable, Sendable {
    case pet
    case human
    case island
    case legacyUnknown = "legacy_unknown"
}

nonisolated struct AchievementScopeReference: Hashable, Codable, Sendable {
    let kind: AchievementScopeKind
    let id: String

    init(kind: AchievementScopeKind, id: String = "") {
        self.kind = kind
        self.id = kind == .island ? Self.islandID : id
    }

    static let islandID = "ohana-island"
    static let island = AchievementScopeReference(kind: .island)

    static func pet(_ id: UUID) -> AchievementScopeReference {
        AchievementScopeReference(kind: .pet, id: id.uuidString)
    }

    static func human(_ id: UUID) -> AchievementScopeReference {
        AchievementScopeReference(kind: .human, id: id.uuidString)
    }

    func achievementKey(for achievementID: String) -> String {
        switch kind {
        case .island:
            "global::\(achievementID)"
        case .pet, .human:
            "\(id)_\(achievementID)"
        case .legacyUnknown:
            id.isEmpty ? achievementID : "\(id)_\(achievementID)"
        }
    }
}

nonisolated enum AchievementCategory: String, Codable, CaseIterable, Sendable {
    case care
    case health
    case movement
    case memory
    case profile
    case economy
    case companion
    case gacha
    case island
}

nonisolated struct AchievementReward: Equatable, Codable, Sendable {
    let coconuts: Int
    let stardust: Int
}

nonisolated enum AchievementCopyLanguage: String, CaseIterable, Codable, Sendable {
    case zh
    case en
    case de
    case es
    case pt
    case fr
    case ja
    case ko
    case it
}

nonisolated struct AchievementLocalizedCopy: Equatable, Codable, Sendable {
    private let values: [AchievementCopyLanguage: String]

    init(
        zh: String,
        en: String,
        de: String,
        es: String,
        pt: String,
        fr: String,
        ja: String,
        ko: String,
        it: String
    ) {
        values = [
            .zh: zh,
            .en: en,
            .de: de,
            .es: es,
            .pt: pt,
            .fr: fr,
            .ja: ja,
            .ko: ko,
            .it: it
        ]
    }

    func value(languageCode: String) -> String {
        let normalized = languageCode
            .split(separator: "-")
            .first
            .map { $0.lowercased() } ?? "en"
        let language = AchievementCopyLanguage(rawValue: normalized) ?? .en
        return values[language] ?? values[.en] ?? ""
    }

    var registeredLanguageCount: Int { values.count }
}

nonisolated struct AchievementDefinition: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let scope: AchievementScopeKind
    let category: AchievementCategory
    let conditionKey: String
    let reward: AchievementReward
    let artworkName: String
    let emoji: String
    let title: AchievementLocalizedCopy
    let condition: AchievementLocalizedCopy
}

nonisolated enum AchievementDefinitionCatalog {
    static let all: [AchievementDefinition] = pet + island + human
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func definition(id: String) -> AchievementDefinition? { byID[id] }

    static func definitions(scope: AchievementScopeKind) -> [AchievementDefinition] {
        all.filter { $0.scope == scope }
    }

    private typealias CopyPair = (title: String, condition: String)

    private struct AdditionalLocalizedCopy: Sendable {
        let de: CopyPair
        let es: CopyPair
        let pt: CopyPair
        let fr: CopyPair
        let ja: CopyPair
        let ko: CopyPair
        let it: CopyPair
    }

    private static let additionalCopyByID: [String: AdditionalLocalizedCopy] = [
        "iron_gut": .init(
            de: ("Robuster Magen", "7 Tage in Folge idealen Kot protokollieren."),
            es: ("Estómago de hierro", "Registra heces perfectas durante 7 días seguidos."),
            pt: ("Estômago de ferro", "Registre fezes perfeitas por 7 dias consecutivos."),
            fr: ("Estomac d’acier", "Enregistrer des selles parfaites pendant 7 jours consécutifs."),
            ja: ("鉄の胃", "7日間連続で理想的な便を記録する"),
            ko: ("튼튼한 장", "7일 연속으로 건강한 배변을 기록하세요."),
            it: ("Stomaco d’acciaio", "Registra feci perfette per 7 giorni consecutivi.")
        ),
        "iron_paw": .init(
            de: ("Eiserne Pfoten", "Insgesamt 100 km Gassi gehen."),
            es: ("Patas de hierro", "Acumula 100 km de paseos."),
            pt: ("Patas de ferro", "Acumule 100 km de passeios."),
            fr: ("Pattes d’acier", "Atteindre 100 km de promenades au total."),
            ja: ("鉄の肉球", "散歩で累計100 kmに到達する"),
            ko: ("강철 발바닥", "산책으로 누적 100km를 달성하세요."),
            it: ("Zampe d’acciaio", "Raggiungi 100 km complessivi di passeggiate.")
        ),
        "walk_streak": .init(
            de: ("Gassi-Serie", "An 7 Tagen in Folge einen Spaziergang protokollieren."),
            es: ("Racha de paseos", "Registra un paseo durante 7 días seguidos."),
            pt: ("Sequência de passeios", "Registre um passeio por 7 dias consecutivos."),
            fr: ("Série de promenades", "Enregistrer une promenade pendant 7 jours consécutifs."),
            ja: ("散歩ストリーク", "7日間連続で散歩を記録する"),
            ko: ("산책 연속 기록", "7일 연속으로 산책을 기록하세요."),
            it: ("Serie di passeggiate", "Registra una passeggiata per 7 giorni consecutivi.")
        ),
        "health_hero": .init(
            de: ("Gesundheitsheld", "Einen Gesundheitseintrag haben und 30 Tage ohne Notfall oder Operation bleiben."),
            es: ("Héroe de la salud", "Ten un registro de salud y pasa 30 días sin urgencias ni cirugías."),
            pt: ("Herói da saúde", "Tenha um registro de saúde e passe 30 dias sem emergência ou cirurgia."),
            fr: ("Héros de la santé", "Avoir un dossier de santé et passer 30 jours sans urgence ni opération."),
            ja: ("健康ヒーロー", "健康記録を作成し、30日間救急受診や手術なしで過ごす"),
            ko: ("건강 영웅", "건강 기록이 있고 30일 동안 응급 진료나 수술 없이 지내세요."),
            it: ("Eroe della salute", "Crea una registrazione sanitaria e trascorri 30 giorni senza emergenze né interventi.")
        ),
        "nutritionist": .init(
            de: ("Ernährungsprofi", "An 14 aufeinanderfolgenden Kalendertagen Fütterungen protokollieren."),
            es: ("Nutricionista", "Registra la alimentación durante 14 días naturales seguidos."),
            pt: ("Nutricionista", "Registre a alimentação em 14 dias consecutivos."),
            fr: ("Nutritionniste", "Enregistrer les repas pendant 14 jours calendaires consécutifs."),
            ja: ("栄養管理士", "14日間連続で給餌を記録する"),
            ko: ("영양사", "14일 연속으로 급여를 기록하세요."),
            it: ("Nutrizionista", "Registra i pasti per 14 giorni di calendario consecutivi.")
        ),
        "happy_birthday": .init(
            de: ("Alles Gute zum Geburtstag", "Ohana am Geburtstag deines Gefährten öffnen."),
            es: ("Feliz cumpleaños", "Abre Ohana el día del cumpleaños de tu compañero."),
            pt: ("Feliz aniversário", "Abra o Ohana no aniversário do seu companheiro."),
            fr: ("Joyeux anniversaire", "Ouvrir Ohana le jour de l’anniversaire de votre compagnon."),
            ja: ("お誕生日おめでとう", "パートナーの誕生日にOhanaを開く"),
            ko: ("생일 축하해요", "동료의 생일에 Ohana를 여세요."),
            it: ("Buon compleanno", "Apri Ohana il giorno del compleanno del tuo compagno.")
        ),
        "hundred_days": .init(
            de: ("100 Tage zusammen", "100 Tage zusammenleben."),
            es: ("100 días juntos", "Vive 100 días junto a tu compañero."),
            pt: ("100 dias juntos", "Viva 100 dias junto do seu companheiro."),
            fr: ("100 jours ensemble", "Vivre ensemble pendant 100 jours."),
            ja: ("一緒に100日", "100日間一緒に暮らす"),
            ko: ("함께한 100일", "동료와 100일을 함께 지내세요."),
            it: ("100 giorni insieme", "Vivi insieme al tuo compagno per 100 giorni.")
        ),
        "first_record": .init(
            de: ("Erster Schritt", "Den ersten Pflegeeintrag abschließen."),
            es: ("Primer paso", "Completa el primer registro de cuidados."),
            pt: ("Primeiro passo", "Conclua o primeiro registro de cuidados."),
            fr: ("Premier pas", "Effectuer le premier suivi de soins."),
            ja: ("はじめの一歩", "最初のケア記録を完了する"),
            ko: ("첫걸음", "첫 돌봄 기록을 완료하세요."),
            it: ("Primo passo", "Completa la prima registrazione di cura.")
        ),
        "day_one_checkin": .init(
            de: ("Heute eingecheckt", "Heute einen beliebigen Pflegeeintrag abschließen."),
            es: ("Al día hoy", "Completa hoy cualquier registro de cuidados."),
            pt: ("Check-in de hoje", "Conclua hoje qualquer registro de cuidados."),
            fr: ("À jour aujourd’hui", "Effectuer aujourd’hui un suivi de soins quelconque."),
            ja: ("今日もケア完了", "今日、いずれかのケア記録を完了する"),
            ko: ("오늘도 출석", "오늘 돌봄 기록을 하나 완료하세요."),
            it: ("Presente oggi", "Completa oggi una registrazione di cura qualsiasi.")
        ),
        "old_friend": .init(
            de: ("Alter Freund", "Das Profil deines Gefährten seit 7 Tagen führen."),
            es: ("Viejo amigo", "Mantén el perfil de tu compañero durante 7 días."),
            pt: ("Velho amigo", "Mantenha o perfil do seu companheiro por 7 dias."),
            fr: ("Vieil ami", "Conserver le profil de votre compagnon pendant 7 jours."),
            ja: ("長い付き合い", "パートナーのプロフィール作成から7日を迎える"),
            ko: ("오랜 친구", "동료 프로필을 만든 지 7일을 달성하세요."),
            it: ("Vecchio amico", "Mantieni il profilo del tuo compagno per 7 giorni.")
        ),
        "long_runner": .init(
            de: ("Langstreckenläufer", "Bei einem Spaziergang 5 km erreichen."),
            es: ("Caminante de fondo", "Alcanza 5 km en un solo paseo."),
            pt: ("Caminhante de longa distância", "Alcance 5 km em um único passeio."),
            fr: ("Marcheur au long cours", "Atteindre 5 km en une seule promenade."),
            ja: ("ロングウォーカー", "1回の散歩で5 kmに到達する"),
            ko: ("장거리 산책가", "한 번의 산책으로 5km를 달성하세요."),
            it: ("Camminatore instancabile", "Raggiungi 5 km in una sola passeggiata.")
        ),
        "medication_complete": .init(
            de: ("Durchgezogen", "Eine Medikamentenkur abschließen."),
            es: ("Misión cumplida", "Completa un tratamiento con medicamentos."),
            pt: ("Missão cumprida", "Conclua um tratamento com medicamentos."),
            fr: ("Mission accomplie", "Terminer un traitement médicamenteux."),
            ja: ("お薬完走", "1つの投薬コースを完了する"),
            ko: ("끝까지 완료", "약물 치료 과정을 하나 완료하세요."),
            it: ("Missione compiuta", "Completa un ciclo di terapia farmacologica.")
        ),
        "photo_enthusiast": .init(
            de: ("Fotofan", "20 Fotos speichern."),
            es: ("Amante de las fotos", "Guarda 20 fotos."),
            pt: ("Fã de fotos", "Salve 20 fotos."),
            fr: ("Passion photo", "Enregistrer 20 photos."),
            ja: ("写真愛好家", "写真を20枚保存する"),
            ko: ("사진 애호가", "사진 20장을 저장하세요."),
            it: ("Appassionato di foto", "Salva 20 foto.")
        ),
        "expense_tracker": .init(
            de: ("Ausgabenprofi", "10 Ausgaben erfassen."),
            es: ("Control de gastos", "Registra 10 gastos."),
            pt: ("Controle de despesas", "Registre 10 despesas."),
            fr: ("Suivi des dépenses", "Enregistrer 10 dépenses."),
            ja: ("支出管理上手", "支出を10件記録する"),
            ko: ("지출 기록가", "지출을 10건 기록하세요."),
            it: ("Contabile esperto", "Registra 10 spese.")
        ),
        "weight_manager": .init(
            de: ("Gewichtsmanager", "7 Gewichtseinträge erfassen."),
            es: ("Control del peso", "Registra el peso 7 veces."),
            pt: ("Gestor de peso", "Registre o peso 7 vezes."),
            fr: ("Suivi du poids", "Enregistrer le poids 7 fois."),
            ja: ("体重管理上手", "体重を7回記録する"),
            ko: ("체중 관리사", "체중을 7번 기록하세요."),
            it: ("Custode del peso", "Registra il peso 7 volte.")
        ),
        "hydration_buddy": .init(
            de: ("Trinkfreund", "14 Wassereinträge abschließen."),
            es: ("Compañero de hidratación", "Completa 14 registros de agua."),
            pt: ("Amigo da hidratação", "Conclua 14 registros de água."),
            fr: ("Compagnon d’hydratation", "Effectuer 14 suivis d’eau."),
            ja: ("水分補給の相棒", "給水を14回記録する"),
            ko: ("수분 섭취 친구", "물 급여를 14번 기록하세요."),
            it: ("Amico dell’idratazione", "Completa 14 registrazioni dell’acqua.")
        ),
        "play_champion": .init(
            de: ("Spielchampion", "20 Spieleinträge abschließen."),
            es: ("Campeón del juego", "Completa 20 registros de juego."),
            pt: ("Campeão da brincadeira", "Conclua 20 registros de brincadeiras."),
            fr: ("Champion du jeu", "Effectuer 20 séances de jeu."),
            ja: ("遊びの達人", "遊びを20回記録する"),
            ko: ("놀이 챔피언", "놀이를 20번 기록하세요."),
            it: ("Campione di gioco", "Completa 20 sessioni di gioco.")
        ),
        "clean_keeper": .init(
            de: ("Sauberkeitsprofi", "20 Reinigungen protokollieren."),
            es: ("Guardián de la limpieza", "Completa 20 cuidados de limpieza."),
            pt: ("Guardião da limpeza", "Conclua 20 cuidados de limpeza."),
            fr: ("As du nettoyage", "Effectuer 20 soins de nettoyage."),
            ja: ("おそうじ名人", "清掃ケアを20回記録する"),
            ko: ("청결 지킴이", "청결 관리를 20번 기록하세요."),
            it: ("Custode della pulizia", "Completa 20 attività di pulizia.")
        ),
        "treat_scout": .init(
            de: ("Leckerli-Detektiv", "10 Leckerlis protokollieren."),
            es: ("Detective de premios", "Registra 10 premios."),
            pt: ("Detetive de petiscos", "Registre 10 petiscos."),
            fr: ("Détective des friandises", "Enregistrer 10 friandises."),
            ja: ("おやつ探偵", "おやつを10回記録する"),
            ko: ("간식 탐정", "간식을 10번 기록하세요."),
            it: ("Detective degli snack", "Registra 10 snack.")
        ),
        "food_kind_explorer": .init(
            de: ("Trocken- und Nassfutter", "Sowohl Trocken- als auch Nassfutter protokollieren."),
            es: ("Explorador de seco y húmedo", "Registra tanto alimento seco como húmedo."),
            pt: ("Explorador de secos e úmidos", "Registre alimentos secos e úmidos."),
            fr: ("Explorateur sec et humide", "Enregistrer des aliments secs et humides."),
            ja: ("ドライ＆ウェット", "ドライフードとウェットフードの両方を記録する"),
            ko: ("건식·습식 탐험가", "건사료와 습식 사료를 모두 기록하세요."),
            it: ("Esploratore secco e umido", "Registra sia cibo secco sia cibo umido.")
        ),
        "auto_feeder_pilot": .init(
            de: ("Automatische Fütterung", "3 Einträge mit dem Futterautomaten erstellen."),
            es: ("Alimentación automática", "Crea 3 registros con el comedero automático."),
            pt: ("Alimentação automática", "Crie 3 registros com o alimentador automático."),
            fr: ("Repas automatiques", "Créer 3 suivis avec le distributeur automatique."),
            ja: ("自動給餌", "自動給餌器から3件の記録を作成する"),
            ko: ("자동 급여", "자동 급식기로 기록을 3건 만드세요."),
            it: ("Alimentazione automatica", "Crea 3 registrazioni con il distributore automatico.")
        ),
        "stock_keeper": .init(
            de: ("Vorratshüter", "2 Futtervorräte auffüllen und protokollieren."),
            es: ("Guardián de la despensa", "Registra 2 reposiciones de alimento."),
            pt: ("Guardião da despensa", "Registre 2 reposições de alimento."),
            fr: ("Gardien du garde-manger", "Enregistrer 2 réapprovisionnements de nourriture."),
            ja: ("フードストック管理人", "フード補充を2回記録する"),
            ko: ("사료 창고지기", "사료 보충을 2번 기록하세요."),
            it: ("Custode della dispensa", "Registra 2 rifornimenti di cibo.")
        ),
        "protection_ready": .init(
            de: ("Gut abgesichert", "Ein Dokument oder eine Versicherung hinzufügen."),
            es: ("Protección lista", "Añade un documento o una póliza de seguro."),
            pt: ("Proteção em dia", "Adicione um documento ou seguro."),
            fr: ("Protection assurée", "Ajouter un document ou une assurance."),
            ja: ("もしもの備え", "書類または保険を追加する"),
            ko: ("든든한 보호", "문서나 보험을 추가하세요."),
            it: ("Protezione pronta", "Aggiungi un documento o una polizza assicurativa.")
        ),
        "vaccine_keeper": .init(
            de: ("Impfpass", "Eine Impfung protokollieren."),
            es: ("Cartilla de vacunación", "Registra una vacuna."),
            pt: ("Caderneta de vacinação", "Registre uma vacina."),
            fr: ("Carnet de vaccination", "Enregistrer un vaccin."),
            ja: ("ワクチン手帳", "ワクチン接種を1回記録する"),
            ko: ("예방접종 수첩", "예방접종을 한 번 기록하세요."),
            it: ("Libretto dei vaccini", "Registra una vaccinazione.")
        ),
        "symptom_watcher": .init(
            de: ("Symptombeobachter", "3 Symptome protokollieren."),
            es: ("Observador de síntomas", "Registra 3 síntomas."),
            pt: ("Observador de sintomas", "Registre 3 sintomas."),
            fr: ("Veille des symptômes", "Enregistrer 3 symptômes."),
            ja: ("症状ウォッチャー", "症状を3回記録する"),
            ko: ("증상 관찰자", "증상을 3번 기록하세요."),
            it: ("Osservatore dei sintomi", "Registra 3 sintomi.")
        ),
        "care_streak_keeper": .init(
            de: ("Pflegeserie", "An 14 Tagen in Folge eine beliebige Pflege abschließen."),
            es: ("Racha de cuidados", "Completa cualquier cuidado durante 14 días seguidos."),
            pt: ("Sequência de cuidados", "Conclua qualquer cuidado por 14 dias consecutivos."),
            fr: ("Série de soins", "Effectuer un soin quelconque pendant 14 jours consécutifs."),
            ja: ("ケアストリーク", "14日間連続でいずれかのケアを完了する"),
            ko: ("돌봄 연속 기록", "14일 연속으로 돌봄을 하나 완료하세요."),
            it: ("Serie di cure", "Completa una cura qualsiasi per 14 giorni consecutivi.")
        ),
        "meal_archivist": .init(
            de: ("Mahlzeitenarchiv", "50 Hauptmahlzeiten protokollieren."),
            es: ("Archivo de comidas", "Completa 50 registros de comidas principales."),
            pt: ("Arquivo de refeições", "Conclua 50 registros de refeições principais."),
            fr: ("Archives des repas", "Effectuer 50 suivis de repas principaux."),
            ja: ("食事アーカイブ", "主食を50回記録する"),
            ko: ("식사 기록 보관가", "주식을 50번 기록하세요."),
            it: ("Archivista dei pasti", "Completa 50 registrazioni di pasti principali.")
        ),
        "water_guardian": .init(
            de: ("Wasserwächter", "50 Wasser- oder Wasserwechsel-Einträge abschließen."),
            es: ("Guardián del agua", "Completa 50 registros de agua o cambio de agua."),
            pt: ("Guardião da água", "Conclua 50 registros de água ou troca de água."),
            fr: ("Gardien de l’eau", "Effectuer 50 suivis d’eau ou de changement d’eau."),
            ja: ("水の守り人", "給水または水交換を50回記録する"),
            ko: ("물 지킴이", "물 급여나 물 교체를 50번 기록하세요."),
            it: ("Guardiano dell’acqua", "Completa 50 registrazioni di acqua o cambio dell’acqua.")
        ),
        "memory_collector": .init(
            de: ("Erinnerungsalbum", "50 Fotos speichern."),
            es: ("Álbum de recuerdos", "Guarda 50 fotos."),
            pt: ("Álbum de memórias", "Salve 50 fotos."),
            fr: ("Album de souvenirs", "Enregistrer 50 photos."),
            ja: ("思い出アルバム", "写真を50枚保存する"),
            ko: ("추억 앨범", "사진 50장을 저장하세요."),
            it: ("Album dei ricordi", "Salva 50 foto.")
        ),
        "weight_rhythm": .init(
            de: ("Gewichtsrhythmus", "14 Gewichtseinträge erfassen."),
            es: ("Ritmo del peso", "Registra el peso 14 veces."),
            pt: ("Ritmo do peso", "Registre o peso 14 vezes."),
            fr: ("Rythme du poids", "Enregistrer le poids 14 fois."),
            ja: ("体重リズム", "体重を14回記録する"),
            ko: ("체중 리듬", "체중을 14번 기록하세요."),
            it: ("Ritmo del peso", "Registra il peso 14 volte.")
        ),
        "year_companion": .init(
            de: ("Ein Jahr zusammen", "365 Tage zusammenleben."),
            es: ("Un año juntos", "Vive 365 días junto a tu compañero."),
            pt: ("Um ano juntos", "Viva 365 dias junto do seu companheiro."),
            fr: ("Un an ensemble", "Vivre ensemble pendant 365 jours."),
            ja: ("一緒に1年", "365日間一緒に暮らす"),
            ko: ("함께한 1년", "동료와 365일을 함께 지내세요."),
            it: ("Un anno insieme", "Vivi insieme al tuo compagno per 365 giorni.")
        ),
        "global_island_crew": .init(
            de: ("Ohana-Team", "Insgesamt mindestens 2 aktive Personen und Haustiere haben."),
            es: ("Equipo Ohana", "Ten al menos 2 personas y mascotas activas en total."),
            pt: ("Equipe Ohana", "Tenha pelo menos 2 pessoas e pets ativos no total."),
            fr: ("Équipe Ohana", "Avoir au moins 2 membres humains et animaux actifs au total."),
            ja: ("Ohanaチーム", "アクティブな人とペットを合計2メンバー以上にする"),
            ko: ("Ohana 팀", "활성 사람과 반려동물을 합해 구성원 2명 이상을 등록하세요."),
            it: ("Squadra Ohana", "Aggiungi almeno 2 persone e animali attivi in totale.")
        ),
        "global_first_critter": .init(
            de: ("Erster Begleiter", "Den ersten Begleiter erhalten."),
            es: ("Primer compañero", "Consigue al primer compañero."),
            pt: ("Primeiro companheiro", "Obtenha o primeiro companheiro."),
            fr: ("Premier compagnon", "Obtenir le premier compagnon."),
            ja: ("最初の仲間", "最初の仲間を迎える"),
            ko: ("첫 번째 동료", "첫 번째 동료를 획득하세요."),
            it: ("Primo compagno", "Ottieni il primo compagno.")
        ),
        "global_legendary_critter": .init(
            de: ("Legendärer Begleiter", "Einen legendären Begleiter erhalten."),
            es: ("Compañero legendario", "Consigue un compañero legendario."),
            pt: ("Companheiro lendário", "Obtenha um companheiro lendário."),
            fr: ("Compagnon légendaire", "Obtenir un compagnon légendaire."),
            ja: ("伝説の仲間", "伝説の仲間を迎える"),
            ko: ("전설의 동료", "전설의 동료를 획득하세요."),
            it: ("Compagno leggendario", "Ottieni un compagno leggendario.")
        ),
        "global_critter_collector": .init(
            de: ("Begleitersammlung", "3 verschiedene Begleiter sammeln."),
            es: ("Colección de compañeros", "Colecciona 3 compañeros diferentes."),
            pt: ("Coleção de companheiros", "Colecione 3 companheiros diferentes."),
            fr: ("Collection de compagnons", "Collectionner 3 compagnons différents."),
            ja: ("仲間図鑑", "3種類の仲間を集める"),
            ko: ("동료 도감", "서로 다른 동료 3명을 수집하세요."),
            it: ("Collezione di compagni", "Colleziona 3 compagni diversi.")
        ),
        "global_critter_star": .init(
            de: ("Sternenbegleiter", "Einen Begleiter auf 2 Sterne bringen."),
            es: ("Compañero estelar", "Sube cualquier compañero a 2 estrellas."),
            pt: ("Companheiro estrelado", "Eleve qualquer companheiro a 2 estrelas."),
            fr: ("Compagnon étoilé", "Faire passer un compagnon à 2 étoiles."),
            ja: ("星付きの仲間", "いずれかの仲間を2つ星にする"),
            ko: ("별빛 동료", "아무 동료나 별 2개로 성장시키세요."),
            it: ("Compagno stellato", "Porta un compagno a 2 stelle.")
        ),
        "global_critter_caretaker": .init(
            de: ("Sanfte Pflege", "10 Interaktionen mit Begleitern abschließen."),
            es: ("Cuidado con cariño", "Completa 10 interacciones con compañeros."),
            pt: ("Cuidado gentil", "Conclua 10 interações com companheiros."),
            fr: ("Soins en douceur", "Effectuer 10 interactions avec des compagnons."),
            ja: ("やさしいお世話", "仲間とのふれあいを10回完了する"),
            ko: ("다정한 돌봄", "동료와 10번 교감하세요."),
            it: ("Cura gentile", "Completa 10 interazioni con i compagni.")
        ),
        "global_first_blind_box": .init(
            de: ("Erste Blindbox", "Die erste Blindbox ziehen."),
            es: ("Primera caja sorpresa", "Abre tu primera caja sorpresa."),
            pt: ("Primeira caixa surpresa", "Faça a primeira abertura de uma caixa surpresa."),
            fr: ("Première boîte surprise", "Effectuer le premier tirage d’une boîte surprise."),
            ja: ("はじめてのブラインドボックス", "初めてブラインドボックスを引く"),
            ko: ("첫 블라인드 박스", "첫 블라인드 박스 뽑기를 완료하세요."),
            it: ("Prima scatola a sorpresa", "Effettua la prima estrazione da una scatola a sorpresa.")
        ),
        "global_blind_box_collector": .init(
            de: ("Blindbox-Sammler", "8 verschiedene Sammelfiguren besitzen."),
            es: ("Coleccionista de cajas sorpresa", "Consigue 8 diseños coleccionables diferentes."),
            pt: ("Colecionador de caixas surpresa", "Tenha 8 estilos colecionáveis diferentes."),
            fr: ("Collectionneur de boîtes surprise", "Posséder 8 modèles de collection différents."),
            ja: ("ブラインドボックス収集家", "8種類のコレクションアイテムを所持する"),
            ko: ("블라인드 박스 수집가", "서로 다른 수집품 8종을 보유하세요."),
            it: ("Collezionista di scatole sorpresa", "Possiedi 8 modelli da collezione diversi.")
        ),
        "global_secret_blind_box": .init(
            de: ("Geheimtreffer!", "Einen beliebigen geheimen Artikel erhalten."),
            es: ("¡Pieza secreta!", "Consigue cualquier pieza secreta."),
            pt: ("Item secreto!", "Obtenha qualquer item secreto."),
            fr: ("Modèle secret !", "Obtenir un objet secret."),
            ja: ("シークレット！", "いずれかのシークレットを獲得する"),
            ko: ("시크릿 당첨!", "시크릿 아이템을 하나 획득하세요."),
            it: ("Pezzo segreto!", "Ottieni un oggetto segreto.")
        ),
        "global_gacha_series_complete": .init(
            de: ("Serie komplett", "Alle regulären Artikel einer Serie sammeln."),
            es: ("Serie completa", "Completa todos los artículos normales de una serie."),
            pt: ("Série completa", "Complete todos os itens regulares de uma série."),
            fr: ("Série complète", "Réunir tous les objets standards d’une série."),
            ja: ("シリーズ完成", "いずれかのシリーズの通常アイテムをすべて集める"),
            ko: ("시리즈 완성", "아무 시리즈의 일반 아이템을 모두 모으세요."),
            it: ("Serie completa", "Completa tutti gli oggetti standard di una serie.")
        ),
        "global_gacha_jackpot": .init(
            de: ("Jackpot-Glück", "Den Jackpot mit 500 Kokosnüssen ziehen."),
            es: ("Suerte de jackpot", "Consigue el premio de 500 cocos."),
            pt: ("Sorte grande", "Tire o prêmio de 500 cocos."),
            fr: ("Chance au jackpot", "Décrocher le jackpot de 500 noix de coco."),
            ja: ("ジャックポット", "ココナッツ500個の大当たりを引く"),
            ko: ("잭팟 행운", "코코넛 500개 잭팟을 뽑으세요."),
            it: ("Fortuna da jackpot", "Vinci il jackpot da 500 noci di cocco.")
        ),
        "human_profile_ready": .init(
            de: ("Profil bereit", "Die nicht sensiblen Basisangaben des Profils vervollständigen."),
            es: ("Perfil listo", "Completa los datos básicos no sensibles de tu perfil."),
            pt: ("Perfil pronto", "Complete os dados básicos não sensíveis do seu perfil."),
            fr: ("Profil prêt", "Renseigner les informations de base non sensibles du profil."),
            ja: ("プロフィール完成", "機密情報を含まない基本プロフィールを完成させる"),
            ko: ("프로필 완성", "민감하지 않은 기본 프로필 정보를 완성하세요."),
            it: ("Profilo pronto", "Completa i dati di base non sensibili del profilo.")
        ),
        "human_first_record": .init(
            de: ("Erster Eintrag", "Einen beliebigen persönlichen Eintrag abschließen."),
            es: ("Primer registro", "Completa cualquier registro personal."),
            pt: ("Primeiro registro", "Complete qualquer registro pessoal."),
            fr: ("Première entrée", "Effectuer une première entrée personnelle."),
            ja: ("最初の記録", "いずれかの個人記録を完了する"),
            ko: ("첫 기록", "개인 기록을 하나 완료하세요."),
            it: ("Prima registrazione", "Completa una registrazione personale.")
        ),
        "human_weight_starter": .init(
            de: ("Startgewicht", "Den ersten Gewichtseintrag erfassen."),
            es: ("Peso inicial", "Registra el primer peso."),
            pt: ("Peso inicial", "Registre o primeiro peso."),
            fr: ("Poids de départ", "Enregistrer le premier poids."),
            ja: ("体重の基準点", "最初の体重を記録する"),
            ko: ("첫 체중", "첫 체중을 기록하세요."),
            it: ("Peso iniziale", "Registra il primo peso.")
        ),
        "human_weight_keeper": .init(
            de: ("Trendbeobachter", "7 Gewichtseinträge erfassen."),
            es: ("Observador de tendencias", "Registra el peso 7 veces."),
            pt: ("Observador de tendências", "Registre o peso 7 vezes."),
            fr: ("Suivi des tendances", "Enregistrer le poids 7 fois."),
            ja: ("トレンドウォッチャー", "体重を7回記録する"),
            ko: ("추세 관찰자", "체중을 7번 기록하세요."),
            it: ("Osservatore delle tendenze", "Registra il peso 7 volte.")
        ),
        "human_expense_tracker": .init(
            de: ("Ausgabenstart", "5 Ausgaben erfassen."),
            es: ("Primeros gastos", "Registra 5 gastos."),
            pt: ("Primeiras despesas", "Registre 5 despesas."),
            fr: ("Premières dépenses", "Enregistrer 5 dépenses."),
            ja: ("支出記録デビュー", "支出を5件記録する"),
            ko: ("지출 기록 시작", "지출을 5건 기록하세요."),
            it: ("Prime spese", "Registra 5 spese.")
        ),
        "human_medication_setup": .init(
            de: ("Medikamentenplan", "Einen Medikamentenplan erstellen."),
            es: ("Plan de medicación", "Crea un plan de medicación."),
            pt: ("Plano de medicação", "Crie um plano de medicação."),
            fr: ("Plan de traitement", "Créer un plan de traitement."),
            ja: ("お薬プラン", "服薬プランを1件作成する"),
            ko: ("복약 계획", "복약 계획을 하나 만드세요."),
            it: ("Piano terapeutico", "Crea un piano terapeutico.")
        ),
        "human_medication_keeper": .init(
            de: ("Medikamentenrhythmus", "7 Medikamenten-Check-ins abschließen."),
            es: ("Rutina de medicación", "Completa 7 controles de medicación."),
            pt: ("Rotina de medicação", "Conclua 7 check-ins de medicação."),
            fr: ("Rythme du traitement", "Effectuer 7 validations de prise."),
            ja: ("服薬リズム", "服薬チェックインを7回完了する"),
            ko: ("복약 리듬", "복약 체크인을 7번 완료하세요."),
            it: ("Ritmo della terapia", "Completa 7 check-in dei farmaci.")
        ),
        "human_workout_starter": .init(
            de: ("Erstes Training", "Das erste Training protokollieren."),
            es: ("Primer entrenamiento", "Registra el primer entrenamiento."),
            pt: ("Primeiro treino", "Registre o primeiro treino."),
            fr: ("Premier entraînement", "Enregistrer le premier entraînement."),
            ja: ("初めての運動", "最初の運動を記録する"),
            ko: ("첫 운동", "첫 운동을 기록하세요."),
            it: ("Primo allenamento", "Registra il primo allenamento.")
        ),
        "human_workout_rhythm": .init(
            de: ("Trainingsrhythmus", "10 Trainings protokollieren."),
            es: ("Ritmo de entrenamiento", "Registra 10 entrenamientos."),
            pt: ("Ritmo de treino", "Registre 10 treinos."),
            fr: ("Rythme d’entraînement", "Enregistrer 10 entraînements."),
            ja: ("運動リズム", "運動を10回記録する"),
            ko: ("운동 리듬", "운동을 10번 기록하세요."),
            it: ("Ritmo di allenamento", "Registra 10 allenamenti.")
        ),
        "human_workout_hero": .init(
            de: ("Trainingsroutine", "30 Trainings protokollieren."),
            es: ("Hábito de entrenamiento", "Registra 30 entrenamientos."),
            pt: ("Hábito de treino", "Registre 30 treinos."),
            fr: ("Habitude sportive", "Enregistrer 30 entraînements."),
            ja: ("運動習慣", "運動を30回記録する"),
            ko: ("운동 습관", "운동을 30번 기록하세요."),
            it: ("Abitudine di allenamento", "Registra 30 allenamenti.")
        ),
        "human_coconut_saver": .init(
            de: ("Kokosnussvorrat", "Ein persönliches Guthaben von 500 Kokosnüssen erreichen."),
            es: ("Reserva de cocos", "Alcanza un saldo personal de 500 cocos."),
            pt: ("Reserva de cocos", "Alcance um saldo pessoal de 500 cocos."),
            fr: ("Réserve de noix de coco", "Atteindre un solde personnel de 500 noix de coco."),
            ja: ("ココナッツ貯金", "個人残高をココナッツ500個にする"),
            ko: ("코코넛 저금통", "개인 잔액으로 코코넛 500개를 달성하세요."),
            it: ("Scorta di cocco", "Raggiungi un saldo personale di 500 noci di cocco.")
        ),
        "human_coconut_elite": .init(
            de: ("Kokosnusstresor", "Ein persönliches Guthaben von 2.000 Kokosnüssen erreichen."),
            es: ("Bóveda de cocos", "Alcanza un saldo personal de 2000 cocos."),
            pt: ("Cofre de cocos", "Alcance um saldo pessoal de 2.000 cocos."),
            fr: ("Coffre aux noix de coco", "Atteindre un solde personnel de 2 000 noix de coco."),
            ja: ("ココナッツ金庫", "個人残高をココナッツ2,000個にする"),
            ko: ("코코넛 금고", "개인 잔액으로 코코넛 2,000개를 달성하세요."),
            it: ("Caveau di cocco", "Raggiungi un saldo personale di 2.000 noci di cocco.")
        ),
        "human_old_friend": .init(
            de: ("Ohana-Stammgast", "Das eigene Profil seit 7 Tagen führen."),
            es: ("Habitual de Ohana", "Mantén tu perfil durante 7 días."),
            pt: ("Amigo do Ohana", "Mantenha seu perfil por 7 dias."),
            fr: ("Habitué d’Ohana", "Conserver son profil pendant 7 jours."),
            ja: ("Ohanaの常連", "自分のプロフィール作成から7日を迎える"),
            ko: ("Ohana 단골", "내 프로필을 만든 지 7일을 달성하세요."),
            it: ("Amico di Ohana", "Mantieni il tuo profilo per 7 giorni.")
        ),
        "human_year_friend": .init(
            de: ("Ein Jahr mit dir", "Das eigene Profil seit 365 Tagen führen."),
            es: ("Un año contigo", "Mantén tu perfil durante 365 días."),
            pt: ("Um ano com você", "Mantenha seu perfil por 365 dias."),
            fr: ("Un an avec soi", "Conserver son profil pendant 365 jours."),
            ja: ("自分と歩んだ1年", "自分のプロフィール作成から365日を迎える"),
            ko: ("나와 함께한 1년", "내 프로필을 만든 지 365일을 달성하세요."),
            it: ("Un anno con te", "Mantieni il tuo profilo per 365 giorni.")
        )
    ]

    private static func make(
        _ id: String,
        _ scope: AchievementScopeKind,
        _ category: AchievementCategory,
        _ emoji: String,
        _ artwork: String,
        _ zh: String,
        _ en: String,
        _ conditionZh: String,
        _ conditionEn: String,
        stardust: Int = 0
    ) -> AchievementDefinition {
        guard let additionalCopy = additionalCopyByID[id] else {
            preconditionFailure("Missing localized achievement copy for \(id)")
        }

        return AchievementDefinition(
            id: id,
            scope: scope,
            category: category,
            conditionKey: "achievement.condition.\(id)",
            reward: AchievementReward(coconuts: 10, stardust: stardust),
            artworkName: artwork,
            emoji: emoji,
            title: AchievementLocalizedCopy(
                zh: zh,
                en: en,
                de: additionalCopy.de.title,
                es: additionalCopy.es.title,
                pt: additionalCopy.pt.title,
                fr: additionalCopy.fr.title,
                ja: additionalCopy.ja.title,
                ko: additionalCopy.ko.title,
                it: additionalCopy.it.title
            ),
            condition: AchievementLocalizedCopy(
                zh: conditionZh,
                en: conditionEn,
                de: additionalCopy.de.condition,
                es: additionalCopy.es.condition,
                pt: additionalCopy.pt.condition,
                fr: additionalCopy.fr.condition,
                ja: additionalCopy.ja.condition,
                ko: additionalCopy.ko.condition,
                it: additionalCopy.it.condition
            )
        )
    }

    private static let pet: [AchievementDefinition] = [
        make("iron_gut", .pet, .health, "💪", "AchievementBgIronGut", "钢铁肠胃", "Iron Stomach", "连续 7 天记录完美便便", "Log perfect poop for 7 consecutive days."),
        make("iron_paw", .pet, .movement, "🏃", "AchievementBgIronPaw", "铁脚板", "Iron Paws", "累计遛狗 100 公里", "Reach 100 km of walks."),
        make("walk_streak", .pet, .movement, "📅", "AchievementBgWalkStreak", "连续巡岛", "Walking Streak", "连续 7 天记录散步", "Log a walk for 7 consecutive days."),
        make("health_hero", .pet, .health, "💎", "AchievementBgHealthHero", "健康达人", "Health Hero", "有健康记录且 30 天内无急诊或手术", "Have a health record and no emergency or surgery for 30 days."),
        make("nutritionist", .pet, .care, "🍗", "AchievementBgNutritionist", "营养师", "Nutritionist", "真实连续 14 天记录喂食", "Log feeding on 14 consecutive calendar days."),
        make("happy_birthday", .pet, .memory, "🎂", "AchievementBgHappyBirthday", "生日快乐", "Happy Birthday", "在伙伴生日当天打开 Ohana", "Open Ohana on your companion's birthday."),
        make("hundred_days", .pet, .memory, "🗓️", "AchievementBgHundredDays", "相伴百日", "100 Days Together", "共同生活 100 天", "Live together for 100 days."),
        make("first_record", .pet, .care, "📝", "AchievementBgFirstRecord", "第一步", "First Step", "完成第一条照护记录", "Complete the first care record."),
        make("day_one_checkin", .pet, .care, "✅", "AchievementBgDayOneCheckin", "今日全勤", "Checked In Today", "今天完成任意照护记录", "Complete any care record today."),
        make("old_friend", .pet, .memory, "🤝", "AchievementBgOldFriend", "老朋友", "Old Friend", "伙伴档案建立 7 天", "Keep the companion profile for 7 days."),
        make("long_runner", .pet, .movement, "🐾", "AchievementBgLongRunner", "长跑健将", "Long-Distance Walker", "单次散步达到 5 公里", "Reach 5 km in one walk."),
        make("medication_complete", .pet, .health, "💊", "AchievementBgMedicationComplete", "坚持到底", "Followed Through", "完成一个用药疗程", "Complete a medication course."),
        make("photo_enthusiast", .pet, .memory, "📸", "AchievementBgPhotoEnthusiast", "拍照达人", "Photo Enthusiast", "保存 20 张照片", "Save 20 photos."),
        make("expense_tracker", .pet, .economy, "💰", "AchievementBgExpenseTracker", "记账能手", "Expense Tracker", "记录 10 笔花费", "Log 10 expenses."),
        make("weight_manager", .pet, .health, "🏋️", "AchievementBgWeightManager", "体重管理师", "Weight Keeper", "记录 7 次体重", "Log weight 7 times."),
        make("hydration_buddy", .pet, .care, "💧", "AchievementBgHydrationBuddy", "喝水伙伴", "Hydration Buddy", "完成 14 次喂水记录", "Complete 14 water records."),
        make("play_champion", .pet, .care, "🎾", "AchievementBgPlayChampion", "逗玩达人", "Play Champion", "完成 20 次陪玩", "Complete 20 play records."),
        make("clean_keeper", .pet, .care, "🧹", "AchievementBgCleanKeeper", "清洁管家", "Clean Keeper", "完成 20 次清洁照护", "Complete 20 cleaning records."),
        make("treat_scout", .pet, .care, "🦴", "AchievementBgTreatScout", "零食侦探", "Treat Scout", "记录 10 次零食", "Log 10 treats."),
        make("food_kind_explorer", .pet, .care, "🥣", "AchievementBgFoodKindExplorer", "干湿双修", "Dry and Wet Explorer", "记录干粮与湿粮", "Record both dry and wet food."),
        make("auto_feeder_pilot", .pet, .care, "🤖", "AchievementBgAutoFeederPilot", "自动喂养", "Auto Feeding", "自动喂食器生成 3 条记录", "Create 3 automatic-feeder records."),
        make("stock_keeper", .pet, .care, "🧺", "AchievementBgStockKeeper", "粮仓管理员", "Pantry Keeper", "完成 2 次补粮记录", "Create 2 food-stock records."),
        make("protection_ready", .pet, .health, "🛡️", "AchievementBgProtectionReady", "证件守护", "Protection Ready", "添加证件或保险", "Add a document or insurance policy."),
        make("vaccine_keeper", .pet, .health, "💉", "AchievementBgVaccineKeeper", "疫苗本", "Vaccine Keeper", "记录一次疫苗", "Record a vaccine."),
        make("symptom_watcher", .pet, .health, "🌡️", "AchievementBgSymptomWatcher", "异常观察员", "Symptom Watcher", "记录 3 次症状", "Log 3 symptoms."),
        make("care_streak_keeper", .pet, .care, "🧭", "AchievementBgCareStreakKeeper", "照护连线", "Care Streak", "连续 14 天完成任意照护", "Complete any care record for 14 consecutive days."),
        make("meal_archivist", .pet, .care, "🍽️", "AchievementBgMealArchivist", "餐桌档案", "Meal Archivist", "完成 50 次主食记录", "Complete 50 main-meal records."),
        make("water_guardian", .pet, .care, "🚰", "AchievementBgWaterGuardian", "清泉守卫", "Water Guardian", "完成 50 次喂水或换水", "Complete 50 water or water-change records."),
        make("memory_collector", .pet, .memory, "🖼️", "AchievementBgMemoryCollector", "记忆相册", "Memory Album", "保存 50 张照片", "Save 50 photos."),
        make("weight_rhythm", .pet, .health, "📊", "AchievementBgWeightRhythm", "体重节奏", "Weight Rhythm", "记录 14 次体重", "Log weight 14 times."),
        make("year_companion", .pet, .memory, "🌿", "AchievementBgYearCompanion", "一年同行", "One Year Together", "共同生活 365 天", "Live together for 365 days.")
    ]

    private static let island: [AchievementDefinition] = [
        make("global_island_crew", .island, .island, "🏝️", "AchievementBgGlobalIslandCrew", "Ohana 小队", "Ohana Crew", "有效 Human 与 Pet 合计至少 2 位", "Have at least 2 active Humans and Pets in total."),
        make("global_first_critter", .island, .companion, "🌳", "AchievementBgGlobalFirstCritter", "伙伴初醒", "First Companion", "获得第一位伙伴", "Get the first companion.", stardust: 20),
        make("global_legendary_critter", .island, .companion, "✨", "AchievementBgGlobalLegendaryCritter", "传说伙伴", "Legendary Companion", "获得传说伙伴", "Get a legendary companion.", stardust: 60),
        make("global_critter_collector", .island, .companion, "🐾", "AchievementBgGlobalCritterCollector", "伙伴图鉴", "Companion Collection", "收集 3 位不同伙伴", "Collect 3 different companions.", stardust: 40),
        make("global_critter_star", .island, .companion, "⭐", "AchievementBgGlobalCritterStar", "星级伙伴", "Star Companion", "任意伙伴达到 2 星", "Raise any companion to 2 stars.", stardust: 40),
        make("global_critter_caretaker", .island, .companion, "🤲", "AchievementBgGlobalCritterCaretaker", "轻养成", "Gentle Care", "完成 10 次伙伴互动", "Complete 10 companion interactions.", stardust: 20),
        make("global_first_blind_box", .island, .gacha, "🎁", "AchievementBgGlobalFirstBlindBox", "第一颗盲盒", "First Blind Box", "完成第一次盲盒抽取", "Complete the first blind-box draw.", stardust: 20),
        make("global_blind_box_collector", .island, .gacha, "🧸", "AchievementBgGlobalBlindBoxCollector", "盲盒收藏家", "Blind Box Collector", "拥有 8 个不同收藏款", "Own 8 different collectible styles.", stardust: 40),
        make("global_secret_blind_box", .island, .gacha, "🌘", "AchievementBgGlobalSecretBlindBox", "隐藏款！", "Secret Pull!", "获得任意隐藏款", "Get any secret item.", stardust: 60),
        make("global_gacha_series_complete", .island, .gacha, "🧩", "AchievementBgGlobalGachaSeriesComplete", "系列完成", "Series Complete", "集齐任意系列普通款", "Complete the regular items in any series.", stardust: 60),
        make("global_gacha_jackpot", .island, .gacha, "🥥", "AchievementBgGlobalGachaJackpot", "欧气爆棚", "Jackpot Luck", "抽中 500 椰子礼包", "Pull the 500-coconut jackpot.", stardust: 20)
    ]

    private static let human: [AchievementDefinition] = [
        make("human_profile_ready", .human, .profile, "👤", "AchievementBgHumanProfileReady", "身份卡完成", "Profile Ready", "完成非敏感基础建档", "Complete the non-sensitive basics of your profile."),
        make("human_first_record", .human, .health, "📝", "AchievementBgHumanFirstRecord", "第一条记录", "First Record", "完成任意个人记录", "Complete any personal record."),
        make("human_weight_starter", .human, .health, "⚖️", "AchievementBgHumanWeightStarter", "体重起点", "Weight Baseline", "记录第一条体重", "Log the first weight entry."),
        make("human_weight_keeper", .human, .health, "📈", "AchievementBgHumanWeightKeeper", "趋势观察员", "Trend Watcher", "记录 7 次体重", "Log weight 7 times."),
        make("human_expense_tracker", .human, .economy, "💳", "AchievementBgHumanExpenseTracker", "记账上手", "Expense Starter", "记录 5 笔花费", "Log 5 expenses."),
        make("human_medication_setup", .human, .health, "💊", "AchievementBgHumanMedicationSetup", "用药计划", "Medication Plan", "建立一个用药计划", "Create a medication plan."),
        make("human_medication_keeper", .human, .health, "✅", "AchievementBgHumanMedicationKeeper", "按时吃药", "Medication Rhythm", "完成 7 次用药打卡", "Complete 7 medication check-ins."),
        make("human_workout_starter", .human, .movement, "🏃", "AchievementBgHumanWorkoutStarter", "开始活动", "First Workout", "记录第一条运动", "Log the first workout."),
        make("human_workout_rhythm", .human, .movement, "🔥", "AchievementBgHumanWorkoutRhythm", "运动节奏", "Workout Rhythm", "记录 10 次运动", "Log 10 workouts."),
        make("human_workout_hero", .human, .movement, "🏅", "AchievementBgHumanWorkoutHero", "运动成形", "Workout Habit", "记录 30 次运动", "Log 30 workouts."),
        make("human_coconut_saver", .human, .economy, "🥥", "AchievementBgHumanCoconutSaver", "椰子小金库", "Coconut Stash", "个人余额达到 500 椰子", "Reach 500 personal coconuts."),
        make("human_coconut_elite", .human, .economy, "🏦", "AchievementBgHumanCoconutElite", "椰子金库", "Coconut Vault", "个人余额达到 2000 椰子", "Reach 2,000 personal coconuts."),
        make("human_old_friend", .human, .memory, "🤝", "AchievementBgHumanOldFriend", "Ohana 老朋友", "Ohana Regular", "本人档案建立 7 天", "Keep your profile for 7 days."),
        make("human_year_friend", .human, .memory, "🌿", "AchievementBgHumanYearFriend", "自我同行", "A Year with Yourself", "本人档案建立 365 天", "Keep your profile for 365 days.")
    ]
}

nonisolated enum HumanBasicProfileAchievementPolicy {
    /// Only non-sensitive, required identity-card fields participate. Optional
    /// health/demographic fields such as birthday, height, blood type, MBTI,
    /// nationality, and city are deliberately never read here.
    static func score(_ human: Human) -> Int {
        let nameReady = !human.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let roleReady = !HumanProfileOptions.normalizedRole(human.role).isEmpty
        let avatarReady = !human.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || human.hasAvatarImageAttachment
        return [nameReady, roleReady, avatarReady].count(where: { $0 })
    }

    static func isReady(_ human: Human) -> Bool { score(human) == 3 }
}
