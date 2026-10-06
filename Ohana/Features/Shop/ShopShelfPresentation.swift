import Foundation

nonisolated enum ShopShelfSection: String, CaseIterable, Identifiable {
    case oasis
    case appIcons
    case members

    var id: String { rawValue }

    static func destination(for category: ShopItem.ShopCategory) -> Self {
        switch category {
        case .plantDecor, .title_, .boost, .cashExchange: .oasis
        case .appIcon: .appIcons
        case .avatar2d, .effect: .members
        }
    }

    func contains(_ item: ShopItem) -> Bool {
        Self.destination(for: item.category) == self
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .oasis: l.text(ShopShelfCopy.oasisTitle)
        case .appIcons: l.text(ShopShelfCopy.iconsTitle)
        case .members: l.text(ShopShelfCopy.membersTitle)
        }
    }
}

/// Presentation copy is independent of canonical purchase definitions, so
/// shortening a shelf label cannot invalidate an outstanding purchase.
nonisolated enum ShopShelfCopy {
    static func name(for itemID: String) -> AppLocalizedText? { names[itemID] }
    static func description(for itemID: String) -> AppLocalizedText? { descriptions[itemID] }

    static let avatarPassTitle: AppLocalizedText = .init(
        zh: "立体头像券", en: "Avatar Pass", de: "Avatarpass",
        es: "Pase de avatar", pt: "Passe de avatar", fr: "Pass avatar",
        ja: "立体アバターチケット", ko: "입체 아바타 이용권", it: "Pass avatar"
    )

    static let oasisTitle: AppLocalizedText = .init(
        zh: "绿洲装饰",
        en: "Oasis Decor",
        de: "Oasis-Deko",
        es: "Decoración de Oasis",
        pt: "Decoração de Oasis",
        fr: "Décor d’Oasis",
        ja: "オアシスの装飾",
        ko: "오아시스 장식",
        it: "Decorazioni di Oasis"
    )

    static let iconsTitle: AppLocalizedText = .init(
        zh: "应用图标",
        en: "App Icons",
        de: "App-Symbole",
        es: "Iconos de la app",
        pt: "Ícones do app",
        fr: "Icônes de l’app",
        ja: "アプリアイコン",
        ko: "앱 아이콘",
        it: "Icone dell’app"
    )

    static let membersTitle: AppLocalizedText = .init(
        zh: "成员外观",
        en: "Member Looks",
        de: "Mitglieder-Looks",
        es: "Aspecto de miembros",
        pt: "Visual dos membros",
        fr: "Apparence des membres",
        ja: "メンバーの外観",
        ko: "멤버 외관",
        it: "Aspetto dei membri"
    )

    static let availableBalance: AppLocalizedText = .init(
        zh: "可用椰子",
        en: "Available Coconuts",
        de: "Verfügbare Kokosnüsse",
        es: "Cocos disponibles",
        pt: "Cocos disponíveis",
        fr: "Noix de coco disponibles",
        ja: "利用可能なココナッツ",
        ko: "사용 가능한 코코넛",
        it: "Cocco disponibile"
    )

    static let permanent: AppLocalizedText = .init(
        zh: "永久外观",
        en: "Permanent Look",
        de: "Dauerhafter Look",
        es: "Aspecto permanente",
        pt: "Visual permanente",
        fr: "Apparence permanente",
        ja: "永続的な外観",
        ko: "영구 외관",
        it: "Aspetto permanente"
    )

    static let singleUse: AppLocalizedText = .init(
        zh: "单次使用",
        en: "Single Use",
        de: "Einmalige Nutzung",
        es: "Un solo uso",
        pt: "Uso único",
        fr: "Usage unique",
        ja: "1回分",
        ko: "1회 사용",
        it: "Uso singolo"
    )

    static let ownedManage: AppLocalizedText = .init(
        zh: "已拥有 · 管理",
        en: "Owned · Manage",
        de: "Besitzt · Verwalten",
        es: "Adquirido · Gestionar",
        pt: "Adquirido · Gerenciar",
        fr: "Acquis · Gérer",
        ja: "所有済み · 管理",
        ko: "보유 중 · 관리",
        it: "Acquistato · Gestisci"
    )

    static let transparentRequired: AppLocalizedText = .init(
        zh: "需透明图片",
        en: "Cutout Image Needed",
        de: "Freisteller nötig",
        es: "Requiere imagen recortada",
        pt: "Requer imagem recortada",
        fr: "Image détourée requise",
        ja: "切り抜き画像が必要",
        ko: "배경 없는 이미지 필요",
        it: "Immagine scontornata richiesta"
    )

    static let plantCosmetic: AppLocalizedText = .init(
        zh: "装饰只改变绿洲外观，不影响照护。",
        en: "Decor changes the Oasis look without affecting care.",
        de: "Deko ändert das Aussehen von Oasis, ohne die Pflege zu beeinflussen.",
        es: "La decoración cambia Oasis sin afectar los cuidados.",
        pt: "A decoração muda Oasis sem afetar os cuidados.",
        fr: "Le décor change Oasis sans modifier les soins.",
        ja: "装飾はオアシスの見た目だけを変え、お世話には影響しません。",
        ko: "장식은 오아시스 외관만 바꾸며 돌봄에 영향을 주지 않습니다.",
        it: "Le decorazioni cambiano Oasis senza influire sulle cure."
    )

    static let sceneReplacement: AppLocalizedText = .init(
        zh: "使用后替换当前场景装饰，可随时在百宝箱切换；可与盆器外观同时使用。",
        en: "Replaces the current scene decor. Switch anytime in the treasure box; combine it with a pot look.",
        de: "Ersetzt die aktuelle Szenendeko. In der Schatzkiste wechseln und mit einem Topf-Look kombinieren.",
        es: "Sustituye la escena actual. Cámbiala en el cofre y combínala con macetas.",
        pt: "Substitui o cenário atual. Troque no baú e combine com vasos.",
        fr: "Remplace le décor actuel. Changez-le dans le coffre et associez-le aux pots.",
        ja: "現在のシーン装飾を置き換えます。宝箱で切り替え可能。鉢の外観と併用できます。",
        ko: "현재 배경 장식을 바꿉니다. 보물함에서 변경하고 화분 외관과 함께 사용할 수 있습니다.",
        it: "Sostituisce la scena attuale. Cambiala nel forziere e abbinala ai vasi."
    )

    static let potCompanion: AppLocalizedText = .init(
        zh: "使用后替换当前盆器外观，可随时在百宝箱切换；可与场景装饰同时使用。",
        en: "Replaces the current pot look. Switch anytime in the treasure box; combine it with scene decor.",
        de: "Ersetzt den aktuellen Topf-Look. In der Schatzkiste wechseln und mit Szenendeko kombinieren.",
        es: "Sustituye las macetas actuales. Cámbialas en el cofre y combínalas con la escena.",
        pt: "Substitui os vasos atuais. Troque no baú e combine com o cenário.",
        fr: "Remplace l’apparence des pots. Changez-la dans le coffre et associez-la au décor.",
        ja: "現在の鉢の外観を置き換えます。宝箱で切り替え可能。シーン装飾と併用できます。",
        ko: "현재 화분 외관을 바꿉니다. 보물함에서 변경하고 배경 장식과 함께 사용할 수 있습니다.",
        it: "Sostituisce l’aspetto dei vasi. Cambialo nel forziere e abbinalo alla scena."
    )

    static let avatarRules: AppLocalizedText = .init(
        zh: "首个人类与首个宠物的内置立体头像名额免费。这张券提供一个额外名额，兑换后在百宝箱选择对象。",
        en: "The first built-in human avatar and pet avatar are free. This pass adds one slot; choose its member in the treasure box.",
        de: "Der erste Menschen- und Tieravatar ist kostenlos. Dieser Pass bietet einen weiteren Platz; Mitglied in der Schatzkiste wählen.",
        es: "El primer avatar de persona y mascota es gratis. Este pase añade uno; elige al miembro en el cofre.",
        pt: "O primeiro avatar humano e de pet é grátis. O passe adiciona uma vaga; escolha o membro no baú.",
        fr: "Le premier avatar humain et animal est gratuit. Ce pass ajoute une place ; choisissez le membre dans le coffre.",
        ja: "最初の人とペットの内蔵アバター枠は無料。この券で1枠追加し、宝箱で対象を選びます。",
        ko: "첫 사람 및 반려동물의 기본 아바타는 무료입니다. 이용권으로 한 자리를 추가하고 보물함에서 대상을 선택하세요.",
        it: "Il primo avatar umano e animale è gratuito. Il pass aggiunge un posto; scegli il membro nel forziere."
    )

    static let popoutSetup: AppLocalizedText = .init(
        zh: "需要一位在世宠物和透明抠图。兑换后在百宝箱选择宠物并配置图片，仅用于普通模式首页。",
        en: "Needs an active pet and a cutout image. Choose the pet and image in the treasure box after redeeming; shown on Standard Home.",
        de: "Benötigt ein aktives Tier und einen Freisteller. Nach dem Einlösen in der Schatzkiste einrichten; auf der Standard-Startseite sichtbar.",
        es: "Requiere mascota activa e imagen recortada. Configúralas en el cofre; se muestra en Inicio estándar.",
        pt: "Requer pet ativo e imagem recortada. Configure no baú; aparece no Início padrão.",
        fr: "Animal actif et image détourée requis. Configurez-les dans le coffre ; visible sur l’accueil standard.",
        ja: "有効なペットと切り抜き画像が必要です。交換後に宝箱で設定し、通常モードのホームで表示。",
        ko: "활성 반려동물과 배경 없는 이미지가 필요합니다. 교환 후 보물함에서 설정하며 일반 모드 홈에 표시됩니다.",
        it: "Richiede un animale attivo e un’immagine scontornata. Configura nel forziere; visibile nella Home standard."
    )

    static let finalSale: AppLocalizedText = .init(
        zh: "兑换后不可撤销或退款。暂未应用时保留权益，可重试，不会再次扣款。",
        en: "Redemptions cannot be cancelled or refunded. If application is delayed, keep your item and retry without another charge.",
        de: "Einlösungen sind nicht stornierbar oder erstattbar. Bei Verzögerung bleibt der Artikel erhalten; erneut versuchen ohne weitere Belastung.",
        es: "No se puede cancelar ni reembolsar. Si tarda en aplicarse, conservas el artículo y puedes reintentar sin otro cargo.",
        pt: "Não pode ser cancelado ou reembolsado. Se demorar a aplicar, o item é mantido; tente novamente sem nova cobrança.",
        fr: "Échange définitif, sans remboursement. Si l’application tarde, l’article reste acquis ; réessayez sans nouveau débit.",
        ja: "交換後の取消・返金はできません。適用が遅れても権利は保持され、再課金なしで再試行できます。",
        ko: "교환 후 취소나 환불은 불가능합니다. 적용이 늦어져도 권리가 유지되며 추가 결제 없이 다시 시도할 수 있습니다.",
        it: "Gli scambi non sono annullabili o rimborsabili. Se l’applicazione tarda, mantieni l’articolo e riprova senza altri addebiti."
    )

    static let fundingPreview: AppLocalizedText = .init(
        zh: "预计出资如下，以确认时余额为准。",
        en: "Expected contributions below, based on balances at confirmation.",
        de: "Voraussichtliche Beiträge; maßgeblich ist das Guthaben bei Bestätigung.",
        es: "Aportaciones previstas según el saldo al confirmar.",
        pt: "Contribuições previstas conforme o saldo ao confirmar.",
        fr: "Contributions prévues selon les soldes à la confirmation.",
        ja: "支払い予定は以下のとおりです。確定時の残高が適用されます。",
        ko: "아래는 예상 분담액이며 확정 시 잔액을 기준으로 합니다.",
        it: "Contributi previsti in base ai saldi alla conferma."
    )

    static let cofunding: AppLocalizedText = .init(
        zh: "付款成员余额不足时，由其他在世成员共同补足。",
        en: "Other active members cover a shortfall in the paying member’s balance.",
        de: "Andere aktive Mitglieder ergänzen einen Fehlbetrag des zahlenden Mitglieds.",
        es: "Otros miembros activos cubren el saldo que falte.",
        pt: "Outros membros ativos completam o saldo que faltar.",
        fr: "Les autres membres actifs complètent le solde manquant.",
        ja: "支払うメンバーの残高が足りない場合、他の有効なメンバーが補います。",
        ko: "결제 멤버의 잔액이 부족하면 다른 활성 멤버가 보충합니다.",
        it: "Gli altri membri attivi coprono il saldo mancante."
    )

    static let payingMember: AppLocalizedText = .init(
        zh: "付款成员",
        en: "Paying Member",
        de: "Zahlendes Mitglied",
        es: "Miembro que paga",
        pt: "Membro pagante",
        fr: "Membre payeur",
        ja: "支払うメンバー",
        ko: "결제 멤버",
        it: "Membro pagante"
    )

    static let chooseBuyer: AppLocalizedText = .init(
        zh: "请选择一位在世成员付款。",
        en: "Choose an active member to pay.",
        de: "Wähle ein aktives Mitglied zum Bezahlen.",
        es: "Elige un miembro activo para pagar.",
        pt: "Escolha um membro ativo para pagar.",
        fr: "Choisissez un membre actif pour payer.",
        ja: "支払う有効なメンバーを選んでください。",
        ko: "결제할 활성 멤버를 선택하세요.",
        it: "Scegli un membro attivo per pagare."
    )

    static let settlementPending: AppLocalizedText = .init(
        zh: "商品正在应用，不会再次扣款。",
        en: "Applying your item without another charge.",
        de: "Artikel wird ohne weitere Belastung angewendet.",
        es: "Aplicando el artículo sin otro cargo.",
        pt: "Aplicando o item sem nova cobrança.",
        fr: "Application de l’article sans nouveau débit.",
        ja: "再課金なしで商品を適用中です。",
        ko: "추가 결제 없이 상품을 적용 중입니다.",
        it: "Applicazione dell’articolo senza altri addebiti."
    )

    static let settlementAttention: AppLocalizedText = .init(
        zh: "商品已兑换，权益已保留。可重试应用，不会再次扣款。",
        en: "Your item is redeemed and preserved. Retry applying it without another charge.",
        de: "Artikel eingelöst und erhalten. Erneut anwenden ohne weitere Belastung.",
        es: "El artículo ya es tuyo. Reintenta aplicarlo sin otro cargo.",
        pt: "O item já é seu e está preservado. Tente aplicar sem nova cobrança.",
        fr: "L’article est acquis et conservé. Réessayez sans nouveau débit.",
        ja: "交換済みの権利は保持されています。再課金なしで適用を再試行できます。",
        ko: "교환한 상품의 권리가 유지됩니다. 추가 결제 없이 적용을 다시 시도하세요.",
        it: "L’articolo è acquisito e conservato. Riprova senza altri addebiti."
    )

    private static let names: [String: AppLocalizedText] = [
        "appicon_coconut": .init(
            zh: "椰子",
            en: "Coconut",
            de: "Kokosnuss",
            es: "Coco",
            pt: "Coco",
            fr: "Noix de coco",
            ja: "ココナッツ",
            ko: "코코넛",
            it: "Cocco"
        ),
        "appicon_clean_blue": .init(
            zh: "清蓝",
            en: "Clean Blue",
            de: "Klares Blau",
            es: "Azul claro",
            pt: "Azul claro",
            fr: "Bleu clair",
            ja: "クリアブルー",
            ko: "클린 블루",
            it: "Blu chiaro"
        ),
        "appicon_lime_night": .init(
            zh: "青柠夜色",
            en: "Lime Night",
            de: "Lime-Nacht",
            es: "Noche lima",
            pt: "Noite lima",
            fr: "Nuit citron vert",
            ja: "ライムナイト",
            ko: "라임 나이트",
            it: "Notte lime"
        ),
        "plant_decor_ceramic_pot_skin": .init(
            zh: "陶盆外观",
            en: "Ceramic Pots",
            de: "Keramiktöpfe",
            es: "Macetas de cerámica",
            pt: "Vasos de cerâmica",
            fr: "Pots en céramique",
            ja: "陶器の鉢",
            ko: "도자기 화분",
            it: "Vasi in ceramica"
        ),
        "plant_decor_moss_path": .init(
            zh: "苔藓小径",
            en: "Moss Path",
            de: "Moospfad",
            es: "Sendero de musgo",
            pt: "Caminho de musgo",
            fr: "Sentier de mousse",
            ja: "苔の小道",
            ko: "이끼 오솔길",
            it: "Sentiero di muschio"
        ),
        "plant_decor_greenhouse_corner": .init(
            zh: "温室角落",
            en: "Greenhouse Corner",
            de: "Gewächshaus-Ecke",
            es: "Rincón de invernadero",
            pt: "Cantinho de estufa",
            fr: "Coin de serre",
            ja: "温室コーナー",
            ko: "온실 코너",
            it: "Angolo serra"
        ),
        "fx_lime_glow": .init(
            zh: "青柠光晕",
            en: "Lime Glow",
            de: "Lime-Leuchten",
            es: "Brillo lima",
            pt: "Brilho lima",
            fr: "Halo citron vert",
            ja: "ライムグロー",
            ko: "라임 글로우",
            it: "Bagliore lime"
        ),
        "fx_popout_card": .init(
            zh: "立体破框卡片",
            en: "Popout Card",
            de: "Popout-Karte",
            es: "Tarjeta emergente",
            pt: "Cartão em relevo",
            fr: "Carte en relief",
            ja: "立体ポップアウトカード",
            ko: "입체 팝아웃 카드",
            it: "Scheda in rilievo"
        ),
        "boost_avatar2d_extra": avatarPassTitle
    ]

    private static let descriptions: [String: AppLocalizedText] = [
        "appicon_coconut": .init(
            zh: "将主屏幕应用图标换成椰子主题。",
            en: "Use a coconut app icon on your Home Screen.",
            de: "Kokosnuss-App-Symbol für deinen Home-Bildschirm.",
            es: "Usa un icono de coco en la pantalla de inicio.",
            pt: "Use um ícone de coco na tela inicial.",
            fr: "Une icône de noix de coco sur l’écran d’accueil.",
            ja: "ホーム画面のアプリアイコンをココナッツに変更。",
            ko: "홈 화면 앱 아이콘을 코코넛으로 변경합니다.",
            it: "Un’icona a tema cocco sulla schermata Home."
        ),
        "appicon_clean_blue": .init(
            zh: "将主屏幕应用图标换成清爽蓝白。",
            en: "Use a blue-and-white app icon on your Home Screen.",
            de: "Blau-weißes App-Symbol für deinen Home-Bildschirm.",
            es: "Usa un icono azul y blanco en la pantalla de inicio.",
            pt: "Use um ícone azul e branco na tela inicial.",
            fr: "Une icône bleu et blanc sur l’écran d’accueil.",
            ja: "ホーム画面のアプリアイコンを青と白に変更。",
            ko: "홈 화면 앱 아이콘을 파란색과 흰색으로 변경합니다.",
            it: "Un’icona blu e bianca sulla schermata Home."
        ),
        "appicon_lime_night": .init(
            zh: "将主屏幕应用图标换成深色青柠。",
            en: "Use a dark lime app icon on your Home Screen.",
            de: "Dunkles Lime-App-Symbol für deinen Home-Bildschirm.",
            es: "Usa un icono lima oscuro en la pantalla de inicio.",
            pt: "Use um ícone lima escuro na tela inicial.",
            fr: "Une icône sombre citron vert sur l’écran d’accueil.",
            ja: "ホーム画面のアプリアイコンをダークライムに変更。",
            ko: "홈 화면 앱 아이콘을 어두운 라임색으로 변경합니다.",
            it: "Un’icona scura color lime sulla schermata Home."
        ),
        "plant_decor_ceramic_pot_skin": .init(
            zh: "更换绿洲生命树旁的盆器外观。",
            en: "Change the pots beside the Oasis life tree.",
            de: "Ändere die Töpfe neben dem Oasis-Lebensbaum.",
            es: "Cambia las macetas junto al árbol de Oasis.",
            pt: "Mude os vasos ao lado da árvore de Oasis.",
            fr: "Changez les pots près de l’arbre de vie d’Oasis.",
            ja: "オアシスの生命の木のそばにある鉢を変更。",
            ko: "오아시스 생명나무 옆 화분을 바꿉니다.",
            it: "Cambia i vasi accanto all’albero di Oasis."
        ),
        "plant_decor_moss_path": .init(
            zh: "在绿洲生命树旁铺上苔藓小径。",
            en: "Add a moss path beside the Oasis life tree.",
            de: "Moospfad neben dem Oasis-Lebensbaum.",
            es: "Añade un sendero de musgo junto al árbol de Oasis.",
            pt: "Adicione um caminho de musgo junto à árvore de Oasis.",
            fr: "Un sentier de mousse près de l’arbre de vie d’Oasis.",
            ja: "オアシスの生命の木のそばに苔の小道を追加。",
            ko: "오아시스 생명나무 옆에 이끼 길을 더합니다.",
            it: "Un sentiero di muschio accanto all’albero di Oasis."
        ),
        "plant_decor_greenhouse_corner": .init(
            zh: "将绿洲生命树旁的场景换成温室角落。",
            en: "Add a greenhouse corner beside the Oasis life tree.",
            de: "Gewächshaus-Ecke neben dem Oasis-Lebensbaum.",
            es: "Añade un rincón de invernadero junto al árbol de Oasis.",
            pt: "Adicione uma estufa junto à árvore de Oasis.",
            fr: "Un coin de serre près de l’arbre de vie d’Oasis.",
            ja: "オアシスの生命の木のそばを温室コーナーに変更。",
            ko: "오아시스 생명나무 옆을 온실 코너로 바꿉니다.",
            it: "Un angolo serra accanto all’albero di Oasis."
        ),
        "fx_lime_glow": .init(
            zh: "让普通模式首页的宠物卡片散发青柠光晕。",
            en: "Add a lime glow to pet cards on Standard Home.",
            de: "Lime-Leuchten für Tierkarten auf der Standard-Startseite.",
            es: "Añade un brillo lima a las mascotas en Inicio estándar.",
            pt: "Adicione brilho lima aos pets no Início padrão.",
            fr: "Un halo citron vert sur les animaux de l’accueil standard.",
            ja: "通常モードのホームのペットカードにライム色の光。",
            ko: "일반 모드 홈의 반려동물 카드에 라임빛을 더합니다.",
            it: "Bagliore lime sulle schede animali nella Home standard."
        ),
        "fx_popout_card": .init(
            zh: "让普通模式首页的宠物从卡片中立体浮出。",
            en: "Let pets pop out of their cards on Standard Home.",
            de: "Tiere treten aus ihren Karten auf der Standard-Startseite hervor.",
            es: "Las mascotas sobresalen de sus tarjetas en Inicio estándar.",
            pt: "Os pets saltam dos cartões no Início padrão.",
            fr: "Les animaux sortent de leur carte sur l’accueil standard.",
            ja: "通常モードのホームでペットがカードから浮き出ます。",
            ko: "일반 모드 홈에서 반려동물이 카드 밖으로 떠오릅니다.",
            it: "Gli animali emergono dalle schede nella Home standard."
        ),
        "boost_avatar2d_extra": .init(
            zh: "额外解锁一位人类或宠物的内置立体头像。",
            en: "Unlock an extra built-in avatar for one human or pet.",
            de: "Ein zusätzlicher integrierter Avatar für einen Menschen oder ein Tier.",
            es: "Desbloquea un avatar adicional para una persona o mascota.",
            pt: "Libere um avatar extra para uma pessoa ou pet.",
            fr: "Un avatar intégré supplémentaire pour une personne ou un animal.",
            ja: "人またはペット1人分の内蔵立体アバターを追加。",
            ko: "사람 또는 반려동물 한 명의 기본 입체 아바타를 추가합니다.",
            it: "Un avatar integrato aggiuntivo per una persona o un animale."
        )
    ]
}
