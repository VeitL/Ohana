//
//  Localization.swift
//  Ohana
//
//  多语言支持：语言注册表 + fallback 文案解析，"ohana" 不翻译
//

import Foundation

nonisolated struct L10n {
    let lang: String

    init(_ lang: String = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.detectedCode) {
        self.lang = AppLanguage.normalize(lang)
    }

    var languageCode: String { lang }
    var isChinese: Bool { lang == "zh" }
    var isEnglish: Bool { lang == "en" }
    var isDe: Bool { lang == "de" }
    var isSpanish: Bool { lang == "es" }
    var isPortuguese: Bool { lang == "pt" }
    var isFrench: Bool { lang == "fr" }
    var isJapanese: Bool { lang == "ja" }
    var isKorean: Bool { lang == "ko" }
    var isItalian: Bool { lang == "it" }
    var usesEnglishFallback: Bool { lang != "zh" }
    /// Legacy compatibility flag for older two-language helpers. New UI copy should use `tr` or `text`.
    var isEn: Bool { usesEnglishFallback }
    func text(_ value: AppLocalizedText) -> String {
        value.resolve(lang)
    }

    /// Resolves dynamic catalog keys through the App's selected language instead
    /// of the device language. Chinese source keys remain the storage value.
    func resourceName(_ key: String, bundle: Bundle = .main) -> String {
        guard !key.isEmpty, !isChinese else { return key }
        let missingValue = "__OHANA_MISSING_LOCALIZATION__"
        for code in AppLanguage.fallbackChain(for: lang) where code != "zh" {
            let lproj = AppLanguage.lprojName(for: code)
            guard let path = bundle.path(forResource: lproj, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else { continue }
            let value = localizedBundle.localizedString(
                forKey: key,
                value: missingValue,
                table: nil
            )
            if value != missingValue {
                return value
            }
        }
        return key
    }

    func tr(
        zh: String,
        en: String,
        de: String? = nil,
        es: String? = nil,
        pt: String? = nil,
        fr: String? = nil,
        ja: String? = nil,
        ko: String? = nil,
        it: String? = nil,
        extras: [String: String] = [:]
    ) -> String {
        var values = Self.curatedStaticTranslations[zh] ?? Self.curatedPrefixTranslations(for: zh) ?? [:]
        values.merge(extras) { _, new in new }
        return AppLocalizedText(zh: zh, en: en, de: de, es: es, pt: pt, fr: fr, ja: ja, ko: ko, it: it, extras: values).resolve(lang)
    }

    func tr(
        _ translations: [String: String],
        fallbackCode: String = AppLanguage.fallbackCode
    ) -> String {
        AppLocalizedText(translations: translations, fallbackCode: fallbackCode).resolve(lang)
    }

    private static func curatedPrefixTranslations(for zh: String) -> [String: String]? {
        let prefix = "支持并解锁 · "
        guard zh.hasPrefix(prefix),
              let translations = curatedStaticTranslations[prefix]
        else { return nil }

        let suffix = zh.dropFirst(prefix.count)
        return translations.mapValues { $0 + suffix }
    }

    private static let curatedStaticTranslationsBase: [String: [String: String]] = [
        "首页": ["es": "Inicio", "pt": "Início", "fr": "Accueil"],
        "植物": ["es": "Plantas", "pt": "Plantas", "fr": "Plantes"],
        "日历": ["es": "Calendario", "pt": "Calendário", "fr": "Calendrier"],
        "图鉴": ["es": "Equipo", "pt": "Equipe", "fr": "Équipe"],
        "绿洲": ["es": "Oasis", "pt": "Oásis", "fr": "Oasis"],
        "Ohana 图鉴": ["es": "Equipo Ohana", "pt": "Equipe Ohana", "fr": "Équipe Ohana"],
        "早上好": ["es": "Buenos días", "pt": "Bom dia", "fr": "Bonjour"],
        "下午好": ["es": "Buenas tardes", "pt": "Boa tarde", "fr": "Bon après-midi"],
        "晚上好": ["es": "Buenas noches", "pt": "Boa noite", "fr": "Bonsoir"],
        "晚安": ["es": "Buenas noches", "pt": "Boa noite", "fr": "Bonne nuit"],
        "设置": ["es": "Ajustes", "pt": "Ajustes", "fr": "Réglages"],
        "添加成员": ["es": "Añadir miembro", "pt": "Adicionar membro", "fr": "Ajouter un membre"],
        "管理主页": ["es": "Gestionar inicio", "pt": "Gerenciar início", "fr": "Gérer l'accueil"],
        "管理主页模块": ["es": "Gestionar secciones", "pt": "Gerenciar seções", "fr": "Gérer les sections"],
        "偏好设置": ["es": "Preferencias", "pt": "Preferências", "fr": "Préférences"],
        "国家/地区": ["es": "País/región", "pt": "País/região", "fr": "Pays/région"],
        "语言": ["es": "Idioma", "pt": "Idioma", "fr": "Langue"],
        "计量单位": ["es": "Unidades", "pt": "Unidades", "fr": "Unités"],
        "货币": ["es": "Moneda", "pt": "Moeda", "fr": "Devise"],
        "外观主题": ["es": "Aspecto", "pt": "Aparência", "fr": "Apparence"],
        "跟随系统": ["es": "Sistema", "pt": "Sistema", "fr": "Système"],
        "浅色模式": ["es": "Claro", "pt": "Claro", "fr": "Clair"],
        "深色模式": ["es": "Oscuro", "pt": "Escuro", "fr": "Sombre"],
        "查看引导页": ["es": "Ver introducción", "pt": "Ver introdução", "fr": "Voir l'introduction"],
        "个人信息": ["es": "Perfil", "pt": "Perfil", "fr": "Profil"],
        "未设置": ["es": "Sin definir", "pt": "Não definido", "fr": "Non défini"],
        "修改昵称": ["es": "Editar apodo", "pt": "Editar apelido", "fr": "Modifier le surnom"],
        "输入昵称": ["es": "Introduce un apodo", "pt": "Insira um apelido", "fr": "Saisir un surnom"],
        "通知": ["es": "Notificaciones", "pt": "Notificações", "fr": "Notifications"],
        "关于": ["es": "Acerca de", "pt": "Sobre", "fr": "À propos"],
        "宠物管理": ["es": "Gestión de mascotas", "pt": "Gestão de pets", "fr": "Gestion des animaux"],
        "清除所有数据": ["es": "Borrar todos los datos", "pt": "Limpar todos os dados", "fr": "Effacer toutes les données"],
        "设备身份": ["es": "Identidad del dispositivo", "pt": "Identidade do dispositivo", "fr": "Identité de l'appareil"],
        "昵称": ["es": "Apodo", "pt": "Apelido", "fr": "Surnom"],
        "编辑": ["es": "Editar", "pt": "Editar", "fr": "Modifier"],
        "照护卡": ["es": "Tarjeta de cuidado", "pt": "Cartão de cuidado", "fr": "Carte de garde"],
        "免疫小盾牌": ["es": "Escudo inmune", "pt": "Escudo imune", "fr": "Petit bouclier immunitaire"],
        "疫苗小本本": ["es": "Cartilla de vacunas", "pt": "Carteira de vacinas", "fr": "Carnet de vaccins"],
        "暂无记录": ["es": "Sin registros aún", "pt": "Sem registros ainda", "fr": "Aucun enregistrement"],
        "已过期": ["es": "Caducado", "pt": "Expirado", "fr": "Expiré"],
        "体重": ["es": "Peso", "pt": "Peso", "fr": "Poids"],
        "花费": ["es": "Gasto", "pt": "Despesa", "fr": "Dépense"],
        "快速记账": ["es": "Gasto rápido", "pt": "Despesa rápida", "fr": "Dépense rapide"],
        "金额": ["es": "Importe", "pt": "Valor", "fr": "Montant"],
        "分类": ["es": "Categoría", "pt": "Categoria", "fr": "Catégorie"],
        "支付者": ["es": "Pagador", "pt": "Pagador", "fr": "Payeur"],
        "未指定": ["es": "Sin especificar", "pt": "Não especificado", "fr": "Non indiqué"],
        "更多": ["es": "Más", "pt": "Mais", "fr": "Plus"],
        "今天": ["es": "Hoy", "pt": "Hoje", "fr": "Aujourd'hui"],
        "有备注": ["es": "Con nota", "pt": "Com nota", "fr": "Avec note"],
        "日期": ["es": "Fecha", "pt": "Data", "fr": "Date"],
        "备注": ["es": "Notas", "pt": "Notas", "fr": "Notes"],
        "可选": ["es": "Opcional", "pt": "Opcional", "fr": "Optionnel"],
        "保存": ["es": "Guardar", "pt": "Salvar", "fr": "Enregistrer"],
        "取消": ["es": "Cancelar", "pt": "Cancelar", "fr": "Annuler"],
        "确认": ["es": "Confirmar", "pt": "Confirmar", "fr": "Confirmer"],
        "完成": ["es": "Listo", "pt": "Concluído", "fr": "Terminé"],
        "搜索": ["es": "Buscar", "pt": "Buscar", "fr": "Rechercher"],
        "噗噗": ["es": "Popó", "pt": "Cocô", "fr": "Caca"],
        "本月": ["es": "Este mes", "pt": "Este mês", "fr": "Ce mois-ci"],
        "巡岛": ["es": "Ronda", "pt": "Ronda", "fr": "Ronde"],
        "今日": ["es": "Hoy", "pt": "Hoje", "fr": "Aujourd'hui"],
        "粮仓": ["es": "Despensa", "pt": "Despensa", "fr": "Réserve"],
        "岁月史书": ["es": "Crónica", "pt": "Crônica", "fr": "Chronique"],
        "危险区域": ["es": "Zona peligrosa", "pt": "Zona de perigo", "fr": "Zone dangereuse"],
        "健康 & 身体": ["es": "Salud y cuerpo", "pt": "Saúde e corpo", "fr": "Santé et corps"],
        "活动 & 记录": ["es": "Actividad y registros", "pt": "Atividade e registros", "fr": "Activité et historiques"],
        "财务": ["es": "Finanzas", "pt": "Finanças", "fr": "Finances"],
        "提醒 & 备注": ["es": "Recordatorios y notas", "pt": "Lembretes e notas", "fr": "Rappels et notes"],
        "用药": ["es": "Medicación", "pt": "Medicação", "fr": "Médicaments"],
        "待办": ["es": "Tareas", "pt": "Tarefas", "fr": "À faire"],
        "椰子": ["es": "Coco", "pt": "Coco", "fr": "Noix de coco"],
        "删除成员": ["es": "Eliminar miembro", "pt": "Excluir membro", "fr": "Supprimer le membre"],
        "狗": ["es": "Perro", "pt": "Cão", "fr": "Chien"],
        "猫": ["es": "Gato", "pt": "Gato", "fr": "Chat"],
        "兔子": ["es": "Conejo", "pt": "Coelho", "fr": "Lapin"],
        "仓鼠": ["es": "Hámster", "pt": "Hamster", "fr": "Hamster"],
        "谁要上岛？": ["es": "¿Quién sube a la isla?", "pt": "Quem chega à ilha?", "fr": "Qui monte sur l'île ?"],
        "小动物室友": ["es": "Compañero animal", "pt": "Companheiro pet", "fr": "Petit coloc animal"],
        "人类队友": ["es": "Equipo humano", "pt": "Equipe humana", "fr": "Équipe humaine"],
        "叶子朋友": ["es": "Amigo de hojas", "pt": "Amigo de folhas", "fr": "Ami feuillu"],
        "加入 Ohana 岛": ["es": "Unirse a la isla Ohana", "pt": "Entrar na ilha Ohana", "fr": "Rejoindre l'île Ohana"],
        "基本信息": ["es": "Datos básicos", "pt": "Básico", "fr": "Infos de base"],
        "品种": ["es": "Raza", "pt": "Raça", "fr": "Race"],
        "头像设置": ["es": "Foto de perfil", "pt": "Foto de perfil", "fr": "Photo de profil"],
        "生物特征": ["es": "Bio y fechas", "pt": "Bio e datas", "fr": "Bio et dates"],
        "外貌特征": ["es": "Aspecto", "pt": "Aparência", "fr": "Apparence"],
        "主题色": ["es": "Color de acento", "pt": "Cor de destaque", "fr": "Couleur d'accent"],
        "主题色（可选）": ["es": "Color de acento (opcional)", "pt": "Cor de destaque (opcional)", "fr": "Couleur d’accent (facultative)"],
        "名字（必填）": ["es": "Nombre (obligatorio)", "pt": "Nome (obrigatório)", "fr": "Nom (obligatoire)"],
        "物种": ["es": "Especie", "pt": "Espécie", "fr": "Espèce"],
        "生日": ["es": "Cumpleaños", "pt": "Aniversário", "fr": "Anniversaire"],
        "到家日": ["es": "Día de llegada", "pt": "Dia de chegada", "fr": "Jour d'arrivée"],
        "性别": ["es": "Sexo", "pt": "Gênero", "fr": "Sexe"],
        "性别（必填）": ["es": "Sexo (obligatorio)", "pt": "Gênero (obrigatório)", "fr": "Sexe (obligatoire)"],
        "未知": ["es": "Desconocido", "pt": "Desconhecido", "fr": "Inconnu"],
        "毛色": ["es": "Pelaje", "pt": "Pelagem", "fr": "Robe"],
        "毛色（可选）": ["es": "Pelaje (opcional)", "pt": "Pelagem (opcional)", "fr": "Robe (facultative)"],
        "暂不设置": ["es": "Omitir por ahora", "pt": "Pular por enquanto", "fr": "Ignorer pour l’instant"],
        "性格（可选）": ["es": "Personalidad (opcional)", "pt": "Personalidade (opcional)", "fr": "Personnalité (facultative)"],
        "已手动选择": ["es": "Elegido manualmente", "pt": "Seleção manual", "fr": "Choisie manuellement"],
        "已自动分配": ["es": "Asignado automáticamente", "pt": "Atribuída automaticamente", "fr": "Attribuée automatiquement"],
        "已按毛色自动搭配": ["es": "Combinado automáticamente con el pelaje", "pt": "Combinada automaticamente com a pelagem", "fr": "Assortie automatiquement à la robe"],
        "恢复自动": ["es": "Usar automático", "pt": "Usar automático", "fr": "Utiliser le mode automatique"],
        "选择宠物主题色": ["es": "Elegir el color de acento de la mascota", "pt": "Escolher a cor de destaque do pet", "fr": "Choisir la couleur d’accent de l’animal"],
        "保存时消耗 1 张头像券": ["es": "Usa 1 pase de avatar al guardar", "pt": "Usa 1 passe de avatar ao salvar", "fr": "Utilise 1 pass d’avatar lors de l’enregistrement"],
        "正在检查 Personal 额度": ["es": "Comprobando el límite de Personal", "pt": "Verificando o limite do Personal", "fr": "Vérification du quota Personal"],
        "暂时无法检查宠物额度": ["es": "No se puede comprobar ahora el límite de mascotas", "pt": "Não foi possível verificar o limite de pets agora", "fr": "Impossible de vérifier le quota d’animaux pour le moment"],
        "自定义": ["es": "Personalizado", "pt": "Personalizado", "fr": "Personnalisé"],
        "保存中…": ["es": "Guardando…", "pt": "Salvando…", "fr": "Enregistrement…"],
        "保存失败": ["es": "No se pudo guardar", "pt": "Não foi possível salvar", "fr": "Échec de l'enregistrement"],
        "下一步": ["es": "Siguiente", "pt": "Próximo", "fr": "Suivant"],
        "选择品种": ["es": "Elegir raza", "pt": "Escolher raça", "fr": "Choisir une race"],
        "清鸟笼": ["es": "Limpiar jaula", "pt": "Limpar gaiola", "fr": "Nettoyer la cage"],
        "放飞": ["es": "Vuelo libre", "pt": "Voo livre", "fr": "Vol libre"],
        "喂食": ["es": "Comida", "pt": "Comida", "fr": "Nourrir"],
        "喂水": ["es": "Agua", "pt": "Água", "fr": "Eau"],
        "换水": ["es": "Cambiar agua", "pt": "Trocar água", "fr": "Changer l'eau"],
        "清滤材": ["es": "Limpiar filtro", "pt": "Limpar filtro", "fr": "Nettoyer le filtre"],
        "遛狗": ["es": "Paseo", "pt": "Passeio", "fr": "Promenade"],
        "铲砂": ["es": "Limpiar arena", "pt": "Limpar areia", "fr": "Litière"],
        "护理": ["es": "Cuidado", "pt": "Cuidado", "fr": "Soin"],
        "运动": ["es": "Ejercicio", "pt": "Exercício", "fr": "Sport"],
        "吃药": ["es": "Meds", "pt": "Remédios", "fr": "Médocs"],
        "记录": ["es": "Nota", "pt": "Nota", "fr": "Note"],
        "陪玩": ["es": "Jugar", "pt": "Brincar", "fr": "Jouer"],
        "🏝️ 今日委托": ["es": "🏝️ Misiones de la isla", "pt": "🏝️ Missões da ilha", "fr": "🏝️ Missions de l'île"],
        "⚡ 快捷打卡": ["es": "⚡ Check-in rápido", "pt": "⚡ Check-in rápido", "fr": "⚡ Check-in rapide"],
        "🗺️ 岛屿功能": ["es": "🗺️ Centro de la isla", "pt": "🗺️ Hub da ilha", "fr": "🗺️ Hub de l'île"],
        "📊 岛屿统计": ["es": "📊 Estadísticas", "pt": "📊 Estatísticas", "fr": "📊 Stats de l'île"],
        "添加": ["es": "Añadir", "pt": "Adicionar", "fr": "Ajouter"],
        "生命之树": ["es": "Árbol de vida", "pt": "Árvore da vida", "fr": "Arbre de vie"],
        "前往绿洲": ["es": "Abrir Oasis", "pt": "Abrir Oásis", "fr": "Ouvrir l'oasis"],
        "健康": ["es": "Salud", "pt": "Saúde", "fr": "Santé"],
        "医疗档案": ["es": "Historial", "pt": "Registros", "fr": "Dossiers"],
        "日程安排": ["es": "Agenda", "pt": "Agenda", "fr": "Planning"],
        "支出统计": ["es": "Totales", "pt": "Totais", "fr": "Totaux"],
        "成长曲线": ["es": "Curvas", "pt": "Curvas", "fr": "Courbes"],
        "奖励中心": ["es": "Recompensas", "pt": "Recompensas", "fr": "Récompenses"],
        "还没有宠物": ["es": "Aún no hay mascotas", "pt": "Ainda sem pets", "fr": "Aucun animal pour l'instant"],
        "本周散步": ["es": "Paseos esta semana", "pt": "Passeios da semana", "fr": "Promenades cette semaine"],
        "本月花费": ["es": "Gastos del mes", "pt": "Despesas do mês", "fr": "Dépenses du mois"],
        "刷牙": ["es": "Dientes", "pt": "Dentes", "fr": "Dents"],
        "剪甲": ["es": "Uñas", "pt": "Unhas", "fr": "Griffes"],
        "耳朵": ["es": "Orejas", "pt": "Orelhas", "fr": "Oreilles"],
        "梳毛": ["es": "Cepillado", "pt": "Escovação", "fr": "Brossage"],
        "洗澡": ["es": "Baño", "pt": "Banho", "fr": "Bain"],
        "详情": ["es": "Detalles", "pt": "Detalhes", "fr": "Détails"],
        "相伴天数": ["es": "Días juntos", "pt": "Dias juntos", "fr": "Jours ensemble"],
        "一起度过了": ["es": "Juntos por", "pt": "Juntos por", "fr": "Ensemble depuis"],
        "化作星星，守护着你": ["es": "Como estrella, cuidando de ti", "pt": "Como estrela, cuidando de você", "fr": "Une étoile qui veille sur toi"],
        "巡岛中": ["es": "En ronda", "pt": "Em ronda", "fr": "En ronde"],
        "噗噗站点": ["es": "Paradas popó", "pt": "Paradas cocô", "fr": "Arrêts caca"],
        "暂停": ["es": "Pausa", "pt": "Pausar", "fr": "Pause"],
        "继续": ["es": "Continuar", "pt": "Continuar", "fr": "Continuer"],
        "结束": ["es": "Terminar", "pt": "Encerrar", "fr": "Terminer"],
        // MARK: - Supporter Pack
        "3 组 Supporter 背景": ["es": "3 fondos Supporter", "pt": "3 fundos Supporter", "fr": "3 arrière-plans Supporter", "ja": "Supporter背景3種", "ko": "Supporter 배경 3종", "it": "3 sfondi Supporter"],
        "App Store 已确认此设备不再拥有 Supporter Pack，且霓虹笑脸没有椰子购买记录。你的照护数据不会受到影响；请在方便时恢复默认图标。": [
            "es": "El App Store ha confirmado que este dispositivo ya no tiene el Supporter Pack y que Sonrisa Neón no se obtuvo con cocos. Tus datos de cuidados no se verán afectados; cambia al icono predeterminado cuando puedas.",
            "pt": "A App Store confirmou que este dispositivo não possui mais o Supporter Pack e que o Sorriso Neon não foi obtido com cocos. Seus dados de cuidados não serão afetados; volte ao ícone padrão quando puder.",
            "fr": "L’App Store a confirmé que cet appareil ne possède plus le Supporter Pack et que Sourire néon n’a pas été obtenu avec des noix de coco. Tes données de soins ne sont pas affectées ; rétablis l’icône par défaut quand tu le peux.",
            "ja": "App Storeにより、このデバイスではSupporter Packが所有されておらず、ネオンスマイルもココナッツで入手されていないことが確認されました。お世話のデータには影響しません。都合のよいときにデフォルトアイコンへ戻してください。",
            "ko": "App Store에서 이 기기에 더 이상 Supporter Pack이 없고 네온 스마일도 코코넛으로 획득하지 않았음을 확인했습니다. 돌봄 데이터에는 영향이 없습니다. 편할 때 기본 아이콘으로 변경해 주세요.",
            "it": "L’App Store ha confermato che questo dispositivo non possiede più il Supporter Pack e che Sorriso neon non è stato ottenuto con le noci di cocco. I dati di cura non subiranno modifiche; ripristina l’icona predefinita quando vuoi."
        ],
        "App Store 暂不可用": ["es": "App Store no disponible", "pt": "App Store indisponível", "fr": "App Store indisponible", "ja": "App Storeを利用できません", "ko": "App Store를 사용할 수 없음", "it": "App Store non disponibile"],
        "App Store 无法完成此请求，请重试。": ["es": "El App Store no pudo completar esta solicitud. Inténtalo de nuevo.", "pt": "A App Store não conseguiu concluir esta solicitação. Tente novamente.", "fr": "L’App Store n’a pas pu traiter cette demande. Réessaie.", "ja": "App Storeでこのリクエストを完了できませんでした。もう一度お試しください。", "ko": "App Store에서 이 요청을 완료할 수 없습니다. 다시 시도해 주세요.", "it": "L’App Store non ha potuto completare la richiesta. Riprova."],
        "Founding Ohana 海报": ["es": "Póster Founding Ohana", "pt": "Pôster Founding Ohana", "fr": "Affiche Founding Ohana", "ja": "Founding Ohanaポスター", "ko": "Founding Ohana 포스터", "it": "Poster Founding Ohana"],
        "Solo 永久完整免费": ["es": "Solo siempre será totalmente gratis", "pt": "Solo será sempre totalmente gratuito", "fr": "Solo restera toujours entièrement gratuit", "ja": "Soloはずっとすべて無料", "ko": "Solo는 언제나 모든 기능이 무료", "it": "Solo sarà sempre completamente gratuito"],
        "Supporter Pack": ["es": "Supporter Pack", "pt": "Supporter Pack", "fr": "Supporter Pack", "ja": "Supporter Pack", "ko": "Supporter Pack", "it": "Supporter Pack"],
        "Supporter Pack 暂时无法使用。": ["es": "El Supporter Pack no está disponible temporalmente.", "pt": "O Supporter Pack está temporariamente indisponível.", "fr": "Le Supporter Pack est temporairement indisponible.", "ja": "Supporter Packは現在利用できません。", "ko": "Supporter Pack을 일시적으로 사용할 수 없습니다.", "it": "Il Supporter Pack non è temporaneamente disponibile."],
        "Supporter Pack 已恢复。": ["es": "Supporter Pack restaurado.", "pt": "Supporter Pack restaurado.", "fr": "Supporter Pack restauré.", "ja": "Supporter Packを復元しました。", "ko": "Supporter Pack을 복원했습니다.", "it": "Supporter Pack ripristinato."],
        "Supporter 周报海报": ["es": "Póster semanal Supporter", "pt": "Pôster semanal Supporter", "fr": "Affiche hebdomadaire Supporter", "ja": "Supporter週間レポートポスター", "ko": "Supporter 주간 리포트 포스터", "it": "Poster settimanale Supporter"],
        "Supporter 图标权益已变化": ["es": "El acceso al icono Supporter ha cambiado", "pt": "O acesso ao ícone Supporter mudou", "fr": "L’accès à l’icône Supporter a changé", "ja": "Supporterアイコンの利用権が変更されました", "ko": "Supporter 아이콘 사용 권한이 변경됨", "it": "L’accesso all’icona Supporter è cambiato"],
        "Supporter 背景": ["es": "Fondos Supporter", "pt": "Fundos Supporter", "fr": "Arrière-plans Supporter", "ja": "Supporter背景", "ko": "Supporter 배경", "it": "Sfondi Supporter"],
        "一次性购买": ["es": "Compra única", "pt": "Compra única", "fr": "Achat unique", "ja": "買い切り", "ko": "일회성 구매", "it": "Acquisto una tantum"],
        "一起让 Ohana 长久生长": ["es": "Ayuda a Ohana a crecer a largo plazo", "pt": "Ajude o Ohana a crescer por muito tempo", "fr": "Aide Ohana à grandir durablement", "ja": "Ohanaをこれからも育てよう", "ko": "Ohana가 오래 성장하도록 함께해 주세요", "it": "Aiuta Ohana a crescere nel tempo"],
        "使用": ["es": "Usar", "pt": "Usar", "fr": "Utiliser", "ja": "使用する", "ko": "사용", "it": "Usa"],
        "使用中": ["es": "En uso", "pt": "Em uso", "fr": "En cours d’utilisation", "ja": "使用中", "ko": "사용 중", "it": "In uso"],
        "此购买无法验证，未解锁任何付费内容。": ["es": "No se pudo verificar esta compra. No se ha desbloqueado ningún contenido de pago.", "pt": "Não foi possível verificar esta compra. Nenhum conteúdo pago foi desbloqueado.", "fr": "Cet achat n’a pas pu être vérifié. Aucun contenu payant n’a été débloqué.", "ja": "この購入を検証できなかったため、有料コンテンツはアンロックされていません。", "ko": "이 구매를 확인할 수 없어 유료 콘텐츠가 잠금 해제되지 않았습니다.", "it": "Non è stato possibile verificare l’acquisto. Nessun contenuto a pagamento è stato sbloccato."],
        "保留原版分享，再增加 Founding Ohana 样式": ["es": "Conserva el formato estándar y añade un estilo Founding Ohana", "pt": "Mantenha o compartilhamento padrão e adicione um estilo Founding Ohana", "fr": "Conserve le partage standard et ajoute un style Founding Ohana", "ja": "通常の共有に加えて、Founding Ohanaスタイルを利用可能", "ko": "기본 공유는 그대로 두고 Founding Ohana 스타일을 추가", "it": "Mantieni la condivisione standard e aggiungi uno stile Founding Ohana"],
        "关闭": ["es": "Cerrar", "pt": "Fechar", "fr": "Fermer", "ja": "閉じる", "ko": "닫기", "it": "Chiudi"],
        "分享海报": ["es": "Póster para compartir", "pt": "Pôster para compartilhar", "fr": "Affiche à partager", "ja": "共有ポスター", "ko": "공유 포스터", "it": "Poster da condividere"],
        "午夜群岛": ["es": "Islas de Medianoche", "pt": "Ilhas da Meia-noite", "fr": "Îles de minuit", "ja": "真夜中の島々", "ko": "한밤의 섬", "it": "Isole di mezzanotte"],
        "可选择": ["es": "Disponible", "pt": "Disponível", "fr": "Disponible", "ja": "選択可能", "ko": "선택 가능", "it": "Disponibile"],
        "安静深蓝，衬托夜间记录": ["es": "Azul profundo y sereno para los registros nocturnos", "pt": "Azul-escuro tranquilo para os registros noturnos", "fr": "Un bleu profond et paisible pour les notes du soir", "ja": "夜の記録を引き立てる静かな深いブルー", "ko": "밤 기록을 돋보이게 하는 차분한 딥 블루", "it": "Blu profondo e tranquillo per le note notturne"],
        "家庭成员、宠物、植物、记录、提醒与导出都不设数量付费墙。": [
            "es": "Los miembros de la familia, las mascotas, las plantas, los registros, los recordatorios y las exportaciones no están sujetos a límites de pago.",
            "pt": "Membros da família, pets, plantas, registros, lembretes e exportações não têm limites de quantidade pagos.",
            "fr": "Les membres de la famille, les animaux, les plantes, les notes, les rappels et les exportations ne sont soumis à aucune limite payante.",
            "ja": "家族、ペット、植物、記録、リマインダー、書き出しに有料の数制限はありません。",
            "ko": "가족 구성원, 반려동물, 식물, 기록, 알림, 내보내기에 유료 수량 제한이 없습니다.",
            "it": "Familiari, animali, piante, registri, promemoria ed esportazioni non hanno limiti quantitativi a pagamento."
        ],
        "已使用椰子获得，继续永久可用": ["es": "Ya se obtuvo con cocos y seguirá disponible para siempre", "pt": "Já foi obtido com cocos e continuará disponível para sempre", "fr": "Déjà obtenu avec des noix de coco et disponible définitivement", "ja": "ココナッツで入手済みのため、今後もずっと利用可能", "ko": "코코넛으로 이미 획득했으며 계속 영구 사용 가능", "it": "Già ottenuto con le noci di cocco e disponibile per sempre"],
        "已由 Supporter Pack 解锁": ["es": "Desbloqueado con el Supporter Pack", "pt": "Desbloqueado pelo Supporter Pack", "fr": "Débloqué grâce au Supporter Pack", "ja": "Supporter Packでアンロック済み", "ko": "Supporter Pack으로 잠금 해제됨", "it": "Sbloccato con il Supporter Pack"],
        "已解锁": ["es": "Desbloqueado", "pt": "Desbloqueado", "fr": "Débloqué", "ja": "アンロック済み", "ko": "잠금 해제됨", "it": "Sbloccato"],
        "已选择": ["es": "Seleccionado", "pt": "Selecionado", "fr": "Sélectionné", "ja": "選択中", "ko": "선택됨", "it": "Selezionato"],
        "当前 Apple 账号没有可恢复的 Supporter Pack 购买。": ["es": "La cuenta de Apple actual no tiene ninguna compra del Supporter Pack que se pueda restaurar.", "pt": "A Conta Apple atual não tem nenhuma compra do Supporter Pack para restaurar.", "fr": "Le compte Apple actuel ne possède aucun achat du Supporter Pack à restaurer.", "ja": "現在のApple Accountには、復元できるSupporter Packの購入がありません。", "ko": "현재 Apple 계정에 복원할 수 있는 Supporter Pack 구매 내역이 없습니다.", "it": "L’Apple Account attuale non ha acquisti del Supporter Pack da ripristinare."],
        "恢复购买": ["es": "Restaurar compras", "pt": "Restaurar compras", "fr": "Restaurer les achats", "ja": "購入を復元", "ko": "구매 복원", "it": "Ripristina acquisti"],
        "恢复默认图标": ["es": "Usar el icono predeterminado", "pt": "Usar o ícone padrão", "fr": "Utiliser l’icône par défaut", "ja": "デフォルトアイコンを使用", "ko": "기본 아이콘 사용", "it": "Usa l’icona predefinita"],
        "感谢支持 · Founding Ohana": ["es": "Gracias por tu apoyo · Founding Ohana", "pt": "Obrigado pelo apoio · Founding Ohana", "fr": "Merci pour ton soutien · Founding Ohana", "ja": "ご支援ありがとう · Founding Ohana", "ko": "응원해 주셔서 감사합니다 · Founding Ohana", "it": "Grazie per il supporto · Founding Ohana"],
        "支持 Ohana": ["es": "Apoya a Ohana", "pt": "Apoie o Ohana", "fr": "Soutenir Ohana", "ja": "Ohanaを応援", "ko": "Ohana 응원하기", "it": "Sostieni Ohana"],
        // Prefix entry for the localized StoreKit price appended by SupporterPackView.
        "支持并解锁 · ": ["es": "Apoya y desbloquea · ", "pt": "Apoie e desbloqueie · ", "fr": "Soutenir et débloquer · ", "ja": "応援してアンロック · ", "ko": "응원하고 잠금 해제 · ", "it": "Sostieni e sblocca · "],
        "无法恢复默认图标": ["es": "No se pudo restaurar el icono predeterminado", "pt": "Não foi possível restaurar o ícone padrão", "fr": "Impossible de rétablir l’icône par défaut", "ja": "デフォルトアイコンに戻せませんでした", "ko": "기본 아이콘을 복원할 수 없음", "it": "Impossibile ripristinare l’icona predefinita"],
        "暂时无法从 App Store 获取此商品。Solo 的全部功能仍可正常使用。": ["es": "Este producto no está disponible temporalmente en el App Store. Todas las funciones de Solo siguen funcionando.", "pt": "Este produto está temporariamente indisponível na App Store. Todos os recursos do Solo continuam funcionando.", "fr": "Ce produit est temporairement indisponible sur l’App Store. Toutes les fonctions de Solo restent accessibles.", "ja": "この商品は現在App Storeから取得できません。Soloのすべての機能は引き続き利用できます。", "ko": "현재 App Store에서 이 상품을 불러올 수 없습니다. Solo의 모든 기능은 계속 사용할 수 있습니다.", "it": "Questo prodotto non è temporaneamente disponibile sull’App Store. Tutte le funzioni di Solo restano utilizzabili."],
        "标准": ["es": "Estándar", "pt": "Padrão", "fr": "Standard", "ja": "標準", "ko": "기본", "it": "Standard"],
        "标准海报": ["es": "Póster estándar", "pt": "Pôster padrão", "fr": "Affiche standard", "ja": "標準ポスター", "ko": "기본 포스터", "it": "Poster standard"],
        "正在恢复…": ["es": "Restaurando…", "pt": "Restaurando…", "fr": "Restauration…", "ja": "復元中…", "ko": "복원 중…", "it": "Ripristino…"],
        "正在获取价格": ["es": "Cargando precio", "pt": "Carregando preço", "fr": "Chargement du prix", "ja": "価格を取得中", "ko": "가격 불러오는 중", "it": "Caricamento prezzo"],
        "等待 App Store 批准": ["es": "Esperando la aprobación del App Store", "pt": "Aguardando aprovação da App Store", "fr": "En attente de l’approbation de l’App Store", "ja": "App Storeの承認待ち", "ko": "App Store 승인 대기 중", "it": "In attesa dell’approvazione dell’App Store"],
        "流光绿洲": ["es": "Resplandor del oasis", "pt": "Brilho do oásis", "fr": "Lueur de l’oasis", "ja": "オアシスの輝き", "ko": "오아시스 글로우", "it": "Bagliore dell’oasi"],
        "流光绿洲、午夜群岛与霓虹网格": ["es": "Resplandor del oasis, Islas de Medianoche y Cuadrícula Neón", "pt": "Brilho do oásis, Ilhas da Meia-noite e Grade Neon", "fr": "Lueur de l’oasis, Îles de minuit et Grille néon", "ja": "オアシスの輝き、真夜中の島々、ネオングリッド", "ko": "오아시스 글로우, 한밤의 섬, 네온 그리드", "it": "Bagliore dell’oasi, Isole di mezzanotte e Griglia neon"],
        "知道了": ["es": "Entendido", "pt": "Entendi", "fr": "Compris", "ja": "わかりました", "ko": "확인", "it": "Ho capito"],
        "稍后": ["es": "Más tarde", "pt": "Mais tarde", "fr": "Plus tard", "ja": "あとで", "ko": "나중에", "it": "Più tardi"],
        "立即解锁；也可以在椰子商店中赚取": ["es": "Desbloquéalo ahora o consíguelo en la Tienda de Cocos", "pt": "Desbloqueie agora ou ganhe na Loja de Cocos", "fr": "Débloque-la maintenant ou obtiens-la dans la Boutique Coco", "ja": "今すぐアンロックするか、ココナッツショップで獲得", "ko": "지금 잠금 해제하거나 코코넛 상점에서 획득", "it": "Sblocca subito oppure ottienila nel Negozio delle noci di cocco"],
        "谢谢你成为 Founding Ohana。外观权益已解锁。": ["es": "Gracias por convertirte en Founding Ohana. Tus extras visuales están desbloqueados.", "pt": "Obrigado por se tornar Founding Ohana. Seus extras visuais foram desbloqueados.", "fr": "Merci de devenir Founding Ohana. Tes bonus visuels sont débloqués.", "ja": "Founding Ohanaになってくれてありがとう。外観特典をアンロックしました。", "ko": "Founding Ohana가 되어 주셔서 감사합니다. 꾸미기 혜택이 잠금 해제되었습니다.", "it": "Grazie per essere diventato Founding Ohana. Gli extra estetici sono sbloccati."],
        "购买后立即使用，也可在椰子商店赚取": ["es": "Úsalo de inmediato con el pack o consíguelo en la Tienda de Cocos", "pt": "Use imediatamente com o pacote ou ganhe na Loja de Cocos", "fr": "Utilise-la immédiatement avec le pack ou obtiens-la dans la Boutique Coco", "ja": "パックですぐに使うか、ココナッツショップで獲得", "ko": "팩으로 바로 사용하거나 코코넛 상점에서 획득", "it": "Usala subito con il pacchetto oppure ottienila nel Negozio delle noci di cocco"],
        "购买正在等待批准，完成后会自动解锁。": ["es": "La compra está pendiente de aprobación y se desbloqueará automáticamente cuando se complete.", "pt": "A compra está aguardando aprovação e será desbloqueada automaticamente quando for concluída.", "fr": "L’achat attend une approbation et se débloquera automatiquement une fois terminé.", "ja": "購入は承認待ちです。完了すると自動的にアンロックされます。", "ko": "구매 승인 대기 중이며 완료되면 자동으로 잠금 해제됩니다.", "it": "L’acquisto è in attesa di approvazione e si sbloccherà automaticamente al termine."],
        "这是一次性支持购买。它只解锁外观，不会把照护能力变成付费门槛。": [
            "es": "Esta es una compra única de apoyo. Solo desbloquea extras visuales y nunca convierte los cuidados en una función de pago.",
            "pt": "Esta é uma compra única de apoio. Ela só desbloqueia extras visuais e nunca transforma os cuidados em um recurso pago.",
            "fr": "Il s’agit d’un achat de soutien unique. Il débloque seulement des bonus visuels, sans jamais rendre les soins payants.",
            "ja": "一度きりの応援購入です。外観特典だけをアンロックし、お世話機能を有料にすることはありません。",
            "ko": "한 번만 결제하는 응원 구매입니다. 꾸미기 혜택만 잠금 해제하며 돌봄 기능을 유료화하지 않습니다.",
            "it": "È un acquisto di supporto una tantum. Sblocca solo extra estetici e non rende mai a pagamento le funzioni di cura."
        ],
        "选择分享海报": ["es": "Elegir póster para compartir", "pt": "Escolher pôster para compartilhar", "fr": "Choisir l’affiche à partager", "ja": "共有ポスターを選択", "ko": "공유 포스터 선택", "it": "Scegli il poster da condividere"],
        "重试获取商品": ["es": "Volver a cargar el producto", "pt": "Tentar carregar o produto novamente", "fr": "Réessayer de charger le produit", "ja": "商品を再取得", "ko": "상품 다시 불러오기", "it": "Riprova a caricare il prodotto"],
        "需要 Supporter Pack": ["es": "Requiere el Supporter Pack", "pt": "Requer o Supporter Pack", "fr": "Nécessite le Supporter Pack", "ja": "Supporter Packが必要", "ko": "Supporter Pack 필요", "it": "Richiede il Supporter Pack"],
        "霓虹笑脸": ["es": "Sonrisa Neón", "pt": "Sorriso Neon", "fr": "Sourire néon", "ja": "ネオンスマイル", "ko": "네온 스마일", "it": "Sorriso neon"],
        "霓虹笑脸 App 图标": ["es": "Icono de la app Sonrisa Neón", "pt": "Ícone do app Sorriso Neon", "fr": "Icône de l’app Sourire néon", "ja": "ネオンスマイルのAppアイコン", "ko": "네온 스마일 앱 아이콘", "it": "Icona app Sorriso neon"],
        "霓虹网格": ["es": "Cuadrícula Neón", "pt": "Grade Neon", "fr": "Grille néon", "ja": "ネオングリッド", "ko": "네온 그리드", "it": "Griglia neon"],
        "青柠光球缓慢漂浮": ["es": "Luz verde lima a la deriva", "pt": "Luz verde-limão flutuando lentamente", "fr": "Lueur citron vert en mouvement lent", "ja": "ライム色の光がゆっくり漂う", "ko": "라임빛 구체가 천천히 떠다님", "it": "Luce color lime che fluttua lentamente"],
        "青蓝与紫色交织的数字夜景": ["es": "Una noche digital entre cian y violeta", "pt": "Uma noite digital entre ciano e violeta", "fr": "Une nuit numérique entre cyan et violet", "ja": "シアンと紫が交差するデジタルな夜景", "ko": "청록과 보라가 어우러진 디지털 야경", "it": "Una notte digitale tra ciano e viola"],
        "首发支持者标记": ["es": "Distintivo de apoyo del lanzamiento", "pt": "Marca de apoiador do lançamento", "fr": "Badge de soutien au lancement", "ja": "ローンチサポーターマーク", "ko": "출시 서포터 표시", "it": "Contrassegno sostenitore del lancio"]
    ]
    private static let curatedStaticTranslationsExpansion: [String: [String: String]] = [
        "首页": ["ja": "ホーム", "ko": "홈", "it": "Home"],
        "植物": ["ja": "植物", "ko": "식물", "it": "Piante"],
        "日历": ["ja": "カレンダー", "ko": "캘린더", "it": "Calendario"],
        "图鉴": ["ja": "クルー", "ko": "크루", "it": "Squadra"],
        "绿洲": ["ja": "オアシス", "ko": "오아시스", "it": "Oasi"],
        "Ohana 图鉴": ["ja": "Ohana クルー", "ko": "Ohana 크루", "it": "Squadra Ohana"],
        "早上好": ["ja": "おはよう", "ko": "좋은 아침", "it": "Buongiorno"],
        "下午好": ["ja": "こんにちは", "ko": "좋은 오후", "it": "Buon pomeriggio"],
        "晚上好": ["ja": "こんばんは", "ko": "좋은 저녁", "it": "Buonasera"],
        "晚安": ["ja": "おやすみ", "ko": "잘 자요", "it": "Buonanotte"],
        "设置": ["ja": "設定", "ko": "설정", "it": "Impostazioni"],
        "添加成员": ["ja": "メンバー追加", "ko": "멤버 추가", "it": "Aggiungi membro"],
        "管理主页": ["ja": "ホーム管理", "ko": "홈 관리", "it": "Gestisci home"],
        "管理主页模块": ["ja": "セクション管理", "ko": "섹션 관리", "it": "Gestisci sezioni"],
        "偏好设置": ["ja": "環境設定", "ko": "환경설정", "it": "Preferenze"],
        "国家/地区": ["ja": "国/地域", "ko": "국가/지역", "it": "Paese/regione"],
        "语言": ["ja": "言語", "ko": "언어", "it": "Lingua"],
        "计量单位": ["ja": "単位", "ko": "단위", "it": "Unità"],
        "货币": ["ja": "通貨", "ko": "통화", "it": "Valuta"],
        "外观主题": ["ja": "外観", "ko": "화면 스타일", "it": "Aspetto"],
        "跟随系统": ["ja": "システム", "ko": "시스템", "it": "Sistema"],
        "浅色模式": ["ja": "ライト", "ko": "라이트", "it": "Chiaro"],
        "深色模式": ["ja": "ダーク", "ko": "다크", "it": "Scuro"],
        "查看引导页": ["ja": "イントロを見る", "ko": "온보딩 보기", "it": "Rivedi guida"],
        "个人信息": ["ja": "プロフィール", "ko": "프로필", "it": "Profilo"],
        "未设置": ["ja": "未設定", "ko": "미설정", "it": "Non impostato"],
        "修改昵称": ["ja": "ニックネーム編集", "ko": "닉네임 수정", "it": "Modifica soprannome"],
        "输入昵称": ["ja": "ニックネームを入力", "ko": "닉네임 입력", "it": "Inserisci soprannome"],
        "通知": ["ja": "通知", "ko": "알림", "it": "Notifiche"],
        "关于": ["ja": "Ohana について", "ko": "Ohana 정보", "it": "Info"],
        "宠物管理": ["ja": "ペット管理", "ko": "반려동물 관리", "it": "Gestione pet"],
        "清除所有数据": ["ja": "すべてのデータを消去", "ko": "모든 데이터 지우기", "it": "Cancella tutti i dati"],
        "设备身份": ["ja": "デバイスID", "ko": "기기 ID", "it": "Identità dispositivo"],
        "昵称": ["ja": "ニックネーム", "ko": "닉네임", "it": "Soprannome"],
        "编辑": ["ja": "編集", "ko": "편집", "it": "Modifica"],
        "照护卡": ["ja": "お世話カード", "ko": "돌봄 카드", "it": "Scheda cura"],
        "免疫小盾牌": ["ja": "免疫シールド", "ko": "면역 방패", "it": "Scudo immunitario"],
        "疫苗小本本": ["ja": "ワクチン手帳", "ko": "백신 수첩", "it": "Libretto vaccini"],
        "暂无记录": ["ja": "まだ記録なし", "ko": "아직 기록 없음", "it": "Nessun record"],
        "已过期": ["ja": "期限切れ", "ko": "만료됨", "it": "Scaduto"],
        "体重": ["ja": "体重", "ko": "체중", "it": "Peso"],
        "花费": ["ja": "支出", "ko": "지출", "it": "Spesa"],
        "快速记账": ["ja": "クイック支出", "ko": "빠른 지출", "it": "Spesa rapida"],
        "金额": ["ja": "金額", "ko": "금액", "it": "Importo"],
        "分类": ["ja": "カテゴリ", "ko": "카테고리", "it": "Categoria"],
        "支付者": ["ja": "支払者", "ko": "결제자", "it": "Pagante"],
        "未指定": ["ja": "未指定", "ko": "미지정", "it": "Non indicato"],
        "更多": ["ja": "もっと", "ko": "더 보기", "it": "Altro"],
        "今天": ["ja": "今日", "ko": "오늘", "it": "Oggi"],
        "有备注": ["ja": "メモあり", "ko": "메모 있음", "it": "Con nota"],
        "日期": ["ja": "日付", "ko": "날짜", "it": "Data"],
        "备注": ["ja": "メモ", "ko": "메모", "it": "Note"],
        "可选": ["ja": "任意", "ko": "선택", "it": "Opzionale"],
        "保存": ["ja": "保存", "ko": "저장", "it": "Salva"],
        "取消": ["ja": "キャンセル", "ko": "취소", "it": "Annulla"],
        "确认": ["ja": "確認", "ko": "확인", "it": "Conferma"],
        "完成": ["ja": "完了", "ko": "완료", "it": "Fatto"],
        "搜索": ["ja": "検索", "ko": "검색", "it": "Cerca"],
        "噗噗": ["ja": "ぷっぷ", "ko": "뿌뿌", "it": "Popò"],
        "本月": ["ja": "今月", "ko": "이번 달", "it": "Questo mese"],
        "巡岛": ["ja": "パトロール", "ko": "섬 순찰", "it": "Giro isola"],
        "今日": ["ja": "今日", "ko": "오늘", "it": "Oggi"],
        "粮仓": ["ja": "ごはん倉庫", "ko": "밥 창고", "it": "Dispensa"],
        "岁月史书": ["ja": "思い出ログ", "ko": "추억 기록", "it": "Cronaca"],
        "危险区域": ["ja": "危険エリア", "ko": "위험 구역", "it": "Zona pericolosa"],
        "健康 & 身体": ["ja": "健康とからだ", "ko": "건강과 몸", "it": "Salute e corpo"],
        "活动 & 记录": ["ja": "活動と記録", "ko": "활동과 기록", "it": "Attività e registri"],
        "财务": ["ja": "家計", "ko": "재정", "it": "Finanze"],
        "提醒 & 备注": ["ja": "リマインダーとメモ", "ko": "리마인더와 메모", "it": "Promemoria e note"],
        "用药": ["ja": "お薬", "ko": "약", "it": "Farmaci"],
        "待办": ["ja": "やること", "ko": "할 일", "it": "Da fare"],
        "椰子": ["ja": "ココナッツ", "ko": "코코넛", "it": "Cocco"],
        "删除成员": ["ja": "メンバー削除", "ko": "멤버 삭제", "it": "Elimina membro"],
        "狗": ["ja": "犬", "ko": "강아지", "it": "Cane"],
        "猫": ["ja": "猫", "ko": "고양이", "it": "Gatto"],
        "兔子": ["ja": "うさぎ", "ko": "토끼", "it": "Coniglio"],
        "仓鼠": ["ja": "ハムスター", "ko": "햄스터", "it": "Criceto"],
        "谁要上岛？": ["ja": "だれが島にくる？", "ko": "누가 섬에 올까요?", "it": "Chi sale sull'isola?"],
        "小动物室友": ["ja": "どうぶつルームメイト", "ko": "작은 동물 룸메이트", "it": "Coinquilino peloso"],
        "人类队友": ["ja": "人間チーム", "ko": "사람 팀원", "it": "Squadra umana"],
        "叶子朋友": ["ja": "葉っぱの友だち", "ko": "잎사귀 친구", "it": "Amico foglioso"],
        "加入 Ohana 岛": ["ja": "Ohana島に参加", "ko": "Ohana 섬에 합류", "it": "Entra nell'isola Ohana"],
        "基本信息": ["ja": "基本情報", "ko": "기본 정보", "it": "Info base"],
        "品种": ["ja": "品種", "ko": "품종", "it": "Razza"],
        "头像设置": ["ja": "プロフィール写真", "ko": "프로필 사진", "it": "Foto profilo"],
        "生物特征": ["ja": "生体情報", "ko": "생체 정보", "it": "Bio e date"],
        "外貌特征": ["ja": "見た目", "ko": "외모", "it": "Aspetto"],
        "主题色": ["ja": "テーマカラー", "ko": "테마 색", "it": "Colore tema"],
        "主题色（可选）": ["ja": "テーマカラー（任意）", "ko": "테마 색(선택)", "it": "Colore tema (opzionale)"],
        "名字（必填）": ["ja": "名前（必須）", "ko": "이름(필수)", "it": "Nome (obbligatorio)"],
        "物种": ["ja": "種類", "ko": "종", "it": "Specie"],
        "生日": ["ja": "誕生日", "ko": "생일", "it": "Compleanno"],
        "到家日": ["ja": "お迎え日", "ko": "집에 온 날", "it": "Giorno d'arrivo"],
        "性别": ["ja": "性別", "ko": "성별", "it": "Sesso"],
        "性别（必填）": ["ja": "性別（必須）", "ko": "성별(필수)", "it": "Sesso (obbligatorio)"],
        "未知": ["ja": "不明", "ko": "알 수 없음", "it": "Sconosciuto"],
        "毛色": ["ja": "毛色", "ko": "털색", "it": "Mantello"],
        "毛色（可选）": ["ja": "毛色（任意）", "ko": "털색(선택)", "it": "Mantello (opzionale)"],
        "暂不设置": ["ja": "今は設定しない", "ko": "나중에 설정", "it": "Salta per ora"],
        "性格（可选）": ["ja": "性格（任意）", "ko": "성격(선택)", "it": "Personalità (opzionale)"],
        "已手动选择": ["ja": "手動で選択", "ko": "직접 선택", "it": "Scelto manualmente"],
        "已自动分配": ["ja": "自動で割り当て", "ko": "자동 배정", "it": "Assegnato automaticamente"],
        "已按毛色自动搭配": ["ja": "毛色に合わせて自動設定", "ko": "털색에 맞춰 자동 설정", "it": "Abbinato automaticamente al mantello"],
        "恢复自动": ["ja": "自動に戻す", "ko": "자동으로 설정", "it": "Usa automatico"],
        "选择宠物主题色": ["ja": "ペットのテーマカラーを選択", "ko": "반려동물 테마 색 선택", "it": "Scegli il colore tema del pet"],
        "保存时消耗 1 张头像券": ["ja": "保存時にアバターパスを1枚使用", "ko": "저장 시 아바타 패스 1장 사용", "it": "Usa 1 pass avatar al salvataggio"],
        "正在检查 Personal 额度": ["ja": "Personalの上限を確認中", "ko": "Personal 한도 확인 중", "it": "Verifica del limite Personal"],
        "暂时无法检查宠物额度": ["ja": "ペットの上限を現在確認できません", "ko": "현재 반려동물 한도를 확인할 수 없습니다", "it": "Impossibile verificare ora il limite di pet"],
        "自定义": ["ja": "カスタム", "ko": "직접 설정", "it": "Personalizzato"],
        "保存中…": ["ja": "保存中…", "ko": "저장 중…", "it": "Salvataggio…"],
        "保存失败": ["ja": "保存できません", "ko": "저장 실패", "it": "Salvataggio non riuscito"],
        "下一步": ["ja": "次へ", "ko": "다음", "it": "Avanti"],
        "选择品种": ["ja": "品種を選択", "ko": "품종 선택", "it": "Scegli razza"],
        "清鸟笼": ["ja": "鳥かご掃除", "ko": "새장 청소", "it": "Pulisci gabbia"],
        "放飞": ["ja": "放鳥", "ko": "자유 비행", "it": "Volo libero"],
        "喂食": ["ja": "ごはん", "ko": "밥", "it": "Cibo"],
        "喂水": ["ja": "お水", "ko": "물", "it": "Acqua"],
        "换水": ["ja": "水替え", "ko": "물 갈기", "it": "Cambia acqua"],
        "清滤材": ["ja": "フィルター掃除", "ko": "필터 청소", "it": "Pulisci filtro"],
        "遛狗": ["ja": "お散歩", "ko": "산책", "it": "Passeggiata"],
        "铲砂": ["ja": "砂そうじ", "ko": "모래 치우기", "it": "Lettiera"],
        "护理": ["ja": "ケア", "ko": "케어", "it": "Cura"],
        "运动": ["ja": "運動", "ko": "운동", "it": "Esercizio"],
        "吃药": ["ja": "お薬", "ko": "약 먹기", "it": "Medicine"],
        "记录": ["ja": "記録", "ko": "기록", "it": "Nota"],
        "陪玩": ["ja": "あそぶ", "ko": "놀아주기", "it": "Gioco"],
        "🏝️ 今日委托": ["ja": "🏝️ 今日の島ミッション", "ko": "🏝️ 오늘의 섬 미션", "it": "🏝️ Missioni dell'isola"],
        "⚡ 快捷打卡": ["ja": "⚡ クイック記録", "ko": "⚡ 빠른 체크인", "it": "⚡ Check-in rapido"],
        "🗺️ 岛屿功能": ["ja": "🗺️ 島のハブ", "ko": "🗺️ 섬 허브", "it": "🗺️ Hub isola"],
        "📊 岛屿统计": ["ja": "📊 島の統計", "ko": "📊 섬 통계", "it": "📊 Statistiche"],
        "添加": ["ja": "追加", "ko": "추가", "it": "Aggiungi"],
        "生命之树": ["ja": "生命の木", "ko": "생명의 나무", "it": "Albero della vita"],
        "前往绿洲": ["ja": "オアシスへ", "ko": "오아시스로", "it": "Apri Oasi"],
        "健康": ["ja": "健康", "ko": "건강", "it": "Salute"],
        "医疗档案": ["ja": "医療記録", "ko": "의료 기록", "it": "Cartelle"],
        "日程安排": ["ja": "予定", "ko": "일정", "it": "Agenda"],
        "支出统计": ["ja": "支出まとめ", "ko": "지출 합계", "it": "Totali"],
        "成长曲线": ["ja": "成長カーブ", "ko": "성장 곡선", "it": "Curve"],
        "奖励中心": ["ja": "ごほうびセンター", "ko": "보상 센터", "it": "Ricompense"],
        "还没有宠物": ["ja": "まだペットがいません", "ko": "아직 반려동물이 없어요", "it": "Ancora nessun pet"],
        "本周散步": ["ja": "今週のお散歩", "ko": "이번 주 산책", "it": "Passeggiate settimana"],
        "本月花费": ["ja": "今月の支出", "ko": "이번 달 지출", "it": "Spese del mese"],
        "刷牙": ["ja": "歯みがき", "ko": "양치", "it": "Denti"],
        "剪甲": ["ja": "爪切り", "ko": "발톱", "it": "Unghie"],
        "耳朵": ["ja": "耳", "ko": "귀", "it": "Orecchie"],
        "梳毛": ["ja": "ブラッシング", "ko": "빗질", "it": "Spazzola"],
        "洗澡": ["ja": "お風呂", "ko": "목욕", "it": "Bagno"],
        "详情": ["ja": "詳細", "ko": "상세", "it": "Dettagli"],
        "相伴天数": ["ja": "一緒の日数", "ko": "함께한 날", "it": "Giorni insieme"],
        "一起度过了": ["ja": "一緒に", "ko": "함께한 시간", "it": "Insieme da"],
        "化作星星，守护着你": ["ja": "星になって見守ってる", "ko": "별이 되어 지켜줘요", "it": "Una stella che ti protegge"],
        "巡岛中": ["ja": "パトロール中", "ko": "순찰 중", "it": "In giro"],
        "噗噗站点": ["ja": "ぷっぷ電台", "ko": "뿌뿌 방송국", "it": "Radio popò"],
        "暂停": ["ja": "一時停止", "ko": "일시정지", "it": "Pausa"],
        "继续": ["ja": "再開", "ko": "계속", "it": "Riprendi"],
        "结束": ["ja": "終了", "ko": "종료", "it": "Fine"]
    ]
    private static let curatedPersonalCommerceTranslations: [String: [String: String]] = [
        // MARK: - Free / Personal commerce
        "Ohana Personal 已解锁。": ["es": "Ohana Personal ya está desbloqueado.", "pt": "Ohana Personal foi desbloqueado.", "fr": "Ohana Personal est maintenant débloqué.", "ja": "Ohana Personalが利用可能になりました。", "ko": "Ohana Personal이 잠금 해제되었습니다.", "it": "Ohana Personal è ora sbloccato."],
        "Ohana Personal 已启用": ["es": "Ohana Personal está activo", "pt": "Ohana Personal está ativo", "fr": "Ohana Personal est actif", "ja": "Ohana Personalは有効です", "ko": "Ohana Personal이 활성화되었습니다", "it": "Ohana Personal è attivo"],
        "免费够用，需要更多时再升级": ["es": "Free cubre lo esencial. Mejora cuando necesites más.", "pt": "Free cobre o essencial. Faça upgrade quando precisar de mais.", "fr": "Free couvre l’essentiel. Passez à la version supérieure si nécessaire.", "ja": "基本機能はFreeで。必要になったらアップグレード。", "ko": "필수 기능은 Free로. 더 필요할 때 업그레이드하세요.", "it": "Free copre l’essenziale. Passa al livello superiore quando serve."],
        "Free 没有广告，也不会锁住你的记录。Personal 为更多活跃成员与进阶本地工具而生。": [
            "es": "Free no tiene anuncios y nunca bloquea tus registros. Ohana Personal ofrece más espacio para crecer y herramientas locales avanzadas.",
            "pt": "Free não tem anúncios e nunca bloqueia seus registros. Ohana Personal oferece mais espaço para crescer e ferramentas locais avançadas.",
            "fr": "Free est sans publicité et ne bloque jamais vos données. Ohana Personal offre plus de capacité et des outils locaux avancés.",
            "ja": "Freeには広告がなく、記録がロックされることもありません。Ohana Personalでは利用枠が広がり、高度なローカルツールを使えます。",
            "ko": "Free에는 광고가 없으며 기록을 잠그지 않습니다. Ohana Personal은 더 넉넉한 이용 한도와 고급 로컬 도구를 제공합니다.",
            "it": "Free è senza pubblicità e non blocca mai i tuoi dati. Ohana Personal offre più spazio per crescere e strumenti locali avanzati."
        ],
        "无限数量与全部 Personal 功能已可使用。": [
            "es": "Las cantidades son ilimitadas y todas las funciones de Ohana Personal están disponibles.",
            "pt": "As quantidades são ilimitadas e todos os recursos do Ohana Personal estão disponíveis.",
            "fr": "Les quantités sont illimitées et toutes les fonctionnalités Ohana Personal sont disponibles.",
            "ja": "利用数は無制限で、Ohana Personalのすべての機能を利用できます。",
            "ko": "이용 수는 무제한이며 Ohana Personal의 모든 기능을 사용할 수 있습니다.",
            "it": "Le quantità sono illimitate e tutte le funzioni Ohana Personal sono disponibili."
        ],
        "Ohana Personal 年度方案": ["es": "Ohana Personal anual", "pt": "Ohana Personal anual", "fr": "Ohana Personal annuel", "ja": "Ohana Personal 年額", "ko": "Ohana Personal 연간", "it": "Ohana Personal annuale"],
        "Ohana Personal 月度方案": ["es": "Ohana Personal mensual", "pt": "Ohana Personal mensal", "fr": "Ohana Personal mensuel", "ja": "Ohana Personal 月額", "ko": "Ohana Personal 월간", "it": "Ohana Personal mensile"],
        "你之前购买的 Supporter Pack 已自动升级为 Ohana Personal Lifetime，无需再次付费。": [
            "es": "Tu compra anterior de Supporter Pack se ha actualizado a Ohana Personal Lifetime sin coste adicional.",
            "pt": "Sua compra anterior do Supporter Pack foi atualizada para Ohana Personal Lifetime sem custo adicional.",
            "fr": "Votre ancien achat de Supporter Pack a été converti en Ohana Personal Lifetime sans frais supplémentaires.",
            "ja": "以前購入したSupporter Packは、追加料金なしでOhana Personal Lifetimeにアップグレードされました。",
            "ko": "이전에 구매한 Supporter Pack이 추가 비용 없이 Ohana Personal Lifetime으로 업그레이드되었습니다.",
            "it": "Il tuo precedente acquisto di Supporter Pack è stato aggiornato a Ohana Personal Lifetime senza costi aggiuntivi."
        ],
        "Free 与 Personal": ["es": "Free y Personal", "pt": "Free e Personal", "fr": "Free et Personal", "ja": "FreeとPersonal", "ko": "Free와 Personal", "it": "Free e Personal"],
        "永久免费 · 无广告": ["es": "Free para siempre · Sin anuncios", "pt": "Free para sempre · Sem anúncios", "fr": "Free pour toujours · Sans publicité", "ja": "ずっとFree · 広告なし", "ko": "평생 Free · 광고 없음", "it": "Free per sempre · Senza pubblicità"],
        "1 只活跃宠物、2 位活跃 Human、5 株活跃植物": ["es": "1 mascota activa, 2 Human activos y 5 plantas activas", "pt": "1 animal ativo, 2 Human ativos e 5 plantas ativas", "fr": "1 animal actif, 2 Human actifs et 5 plantes actives", "ja": "アクティブなペット1匹、Human 2人、植物5株", "ko": "활성 반려동물 1마리, Human 2명, 식물 5개", "it": "1 animale attivo, 2 Human attivi e 5 piante attive"],
        "3 个普通活跃计划；健康关键提醒不限数量": ["es": "3 planes cotidianos activos; los recordatorios críticos de salud no tienen límite", "pt": "3 planos ativos do dia a dia; lembretes críticos de saúde são ilimitados", "fr": "3 plans courants actifs ; les rappels de santé essentiels sont illimités", "ja": "通常のアクティブなプランは3件まで。健康上重要なリマインダーは無制限", "ko": "일반 활성 플랜 3개, 건강상 중요한 미리 알림은 무제한", "it": "3 piani quotidiani attivi; i promemoria sanitari essenziali sono illimitati"],
        "全部历史、现有数据、核心照护记录与导出始终可用": [
            "es": "Todo el historial, los datos existentes, los registros de cuidados esenciales y las exportaciones siguen disponibles",
            "pt": "Todo o histórico, os dados existentes, os registros essenciais de cuidados e as exportações continuam disponíveis",
            "fr": "Tout l’historique, les données existantes, les soins essentiels et les exportations restent disponibles",
            "ja": "すべての履歴、既存データ、基本のケア記録、エクスポートは引き続き利用できます",
            "ko": "전체 기록, 기존 데이터, 핵심 돌봄 기록 및 내보내기는 계속 이용할 수 있습니다",
            "it": "Tutta la cronologia, i dati esistenti, le cure essenziali e le esportazioni restano disponibili"
        ],
        "按月、按年或 Lifetime": ["es": "Mensual, anual o Lifetime", "pt": "Mensal, anual ou Lifetime", "fr": "Mensuel, annuel ou Lifetime", "ja": "月額、年額、またはLifetime", "ko": "월간, 연간 또는 Lifetime", "it": "Mensile, annuale o Lifetime"],
        "月度、年度或 Lifetime": ["es": "Mensual, anual o Lifetime", "pt": "Mensal, anual ou Lifetime", "fr": "Mensuel, annuel ou Lifetime", "ja": "月額、年額、またはLifetime", "ko": "월간, 연간 또는 Lifetime", "it": "Mensile, annuale o Lifetime"],
        "活跃宠物、Human、植物与计划不限数量": ["es": "Mascotas activas, Human, plantas y planes sin límite", "pt": "Animais ativos, Human, plantas e planos sem limite", "fr": "Animaux actifs, Human, plantes et plans sans limite", "ja": "アクティブなペット、Human、植物、プランが無制限", "ko": "활성 반려동물, Human, 식물 및 플랜 무제한", "it": "Animali attivi, Human, piante e piani senza limiti"],
        "90 天与全部时间的进阶趋势分析": ["es": "Análisis avanzados de tendencias de 90 días y de todo el historial", "pt": "Análises avançadas de tendências de 90 dias e de todo o histórico", "fr": "Analyses avancées des tendances sur 90 jours et sur tout l’historique", "ja": "90日間と全期間の高度な傾向分析", "ko": "90일 및 전체 기간 고급 추세 분석", "it": "Analisi avanzate delle tendenze a 90 giorni e dell’intero storico"],
        "兽医 PDF 摘要": ["es": "Resúmenes veterinarios en PDF", "pt": "Resumos veterinários em PDF", "fr": "Résumés vétérinaires en PDF", "ja": "獣医向けPDF要約", "ko": "수의사용 PDF 요약", "it": "Riepiloghi veterinari in PDF"],
        "全部 Founding Supporter 外观权益": ["es": "Todos los extras visuales de Founding Supporter", "pt": "Todos os extras visuais de Founding Supporter", "fr": "Tous les extras visuels Founding Supporter", "ja": "Founding Supporterのすべての外観特典", "ko": "Founding Supporter의 모든 디자인 혜택", "it": "Tutti gli extra estetici Founding Supporter"],
        "管理订阅": ["es": "Gestionar suscripción", "pt": "Gerenciar assinatura", "fr": "Gérer l’abonnement", "ja": "サブスクリプションを管理", "ko": "구독 관리", "it": "Gestisci abbonamento"],
        "升级为 Lifetime": ["es": "Actualizar a Lifetime", "pt": "Fazer upgrade para Lifetime", "fr": "Passer à Lifetime", "ja": "Lifetimeにアップグレード", "ko": "Lifetime으로 업그레이드", "it": "Passa a Lifetime"],
        "Lifetime 是可选的一次性购买。购买后 Apple 不会自动取消你现有的月度或年度订阅，请在订阅管理中确认续订状态。": [
            "es": "Lifetime es una compra única opcional. Apple no cancela automáticamente tu suscripción mensual o anual actual; comprueba su renovación en la gestión de suscripciones.",
            "pt": "Lifetime é uma compra única opcional. A Apple não cancela automaticamente sua assinatura mensal ou anual atual; confira a renovação no gerenciamento de assinaturas.",
            "fr": "Lifetime est un achat unique facultatif. Apple n’annule pas automatiquement votre abonnement mensuel ou annuel actuel ; vérifiez son renouvellement dans la gestion des abonnements.",
            "ja": "Lifetimeは任意の買い切り購入です。Appleが現在の月額または年額サブスクリプションを自動的に解約することはありません。サブスクリプション管理で更新状況を確認してください。",
            "ko": "Lifetime은 선택 가능한 일회성 구매입니다. Apple은 기존 월간 또는 연간 구독을 자동으로 취소하지 않으니 구독 관리에서 갱신 상태를 확인하세요.",
            "it": "Lifetime è un acquisto una tantum facoltativo. Apple non annulla automaticamente l’abbonamento mensile o annuale esistente; verificane il rinnovo nella gestione abbonamenti."
        ],
        "管理现有订阅": ["es": "Gestionar suscripción actual", "pt": "Gerenciar assinatura atual", "fr": "Gérer l’abonnement actuel", "ja": "現在のサブスクリプションを管理", "ko": "기존 구독 관리", "it": "Gestisci abbonamento esistente"],
        "正在向 App Store 核对你的 Personal 方案。核对完成前不会推荐重复购买。": [
            "es": "Ohana está comprobando tu plan Ohana Personal con App Store. No se ofrecerá otra compra hasta que termine la verificación.",
            "pt": "Ohana está verificando seu plano Ohana Personal com a App Store. Nenhuma nova compra será oferecida até o fim da verificação.",
            "fr": "Ohana vérifie votre formule Ohana Personal auprès de l’App Store. Aucun nouvel achat ne sera proposé avant la fin de la vérification.",
            "ja": "OhanaがApp StoreでOhana Personalプランを確認しています。確認が完了するまで、再購入は案内されません。",
            "ko": "Ohana가 App Store에서 Ohana Personal 플랜을 확인하고 있습니다. 확인이 끝날 때까지 재구매가 제공되지 않습니다.",
            "it": "Ohana sta verificando il tuo piano Ohana Personal con l’App Store. Non verrà proposto un nuovo acquisto finché la verifica non sarà completata."
        ],
        "选择方案": ["es": "Elegir un plan", "pt": "Escolher um plano", "fr": "Choisir une formule", "ja": "プランを選択", "ko": "플랜 선택", "it": "Scegli un piano"],
        "暂时无法从 App Store 获取这个方案。Free 仍可正常使用。": [
            "es": "Este plan no está disponible temporalmente en App Store. Free sigue funcionando con normalidad.",
            "pt": "Este plano está temporariamente indisponível na App Store. Free continua funcionando normalmente.",
            "fr": "Cette formule est temporairement indisponible sur l’App Store. Free reste pleinement utilisable.",
            "ja": "このプランは現在App Storeで一時的に利用できません。Freeは引き続き通常どおり使えます。",
            "ko": "이 플랜은 현재 App Store에서 일시적으로 사용할 수 없습니다. Free는 계속 정상적으로 이용할 수 있습니다.",
            "it": "Questo piano è temporaneamente non disponibile sull’App Store. Free continua a funzionare normalmente."
        ],
        "重试获取方案": ["es": "Volver a cargar los planes", "pt": "Carregar planos novamente", "fr": "Recharger les formules", "ja": "プランを再読み込み", "ko": "플랜 다시 불러오기", "it": "Ricarica i piani"],
        "推荐": ["es": "Recomendado", "pt": "Recomendado", "fr": "Recommandé", "ja": "おすすめ", "ko": "추천", "it": "Consigliato"],
        "未选择": ["es": "No seleccionado", "pt": "Não selecionado", "fr": "Non sélectionné", "ja": "未選択", "ko": "선택되지 않음", "it": "Non selezionato"],
        "月度": ["es": "Mensual", "pt": "Mensal", "fr": "Mensuel", "ja": "月額", "ko": "월간", "it": "Mensile"],
        "年度": ["es": "Anual", "pt": "Anual", "fr": "Annuel", "ja": "年額", "ko": "연간", "it": "Annuale"],
        "按月自动续订，可随时在 Apple 账号中取消": ["es": "Se renueva mensualmente; cancela cuando quieras en tu cuenta de Apple", "pt": "Renovação mensal; cancele quando quiser na sua Conta Apple", "fr": "Renouvellement mensuel ; annulez à tout moment dans votre compte Apple", "ja": "毎月自動更新。Apple Accountでいつでも解約できます", "ko": "매월 자동 갱신되며 Apple 계정에서 언제든지 취소할 수 있습니다", "it": "Rinnovo mensile; annulla in qualsiasi momento nel tuo Apple Account"],
        "可免费试用 14 天，之后按年续订": ["es": "14 días de prueba gratis; después, renovación anual", "pt": "Teste grátis por 14 dias; depois, renovação anual", "fr": "Essai gratuit de 14 jours, puis renouvellement annuel", "ja": "14日間無料、その後は年額で更新", "ko": "14일 무료 체험 후 연간 갱신", "it": "Prova gratuita di 14 giorni, poi rinnovo annuale"],
        "按年自动续订，可随时在 Apple 账号中取消": ["es": "Se renueva anualmente; cancela cuando quieras en tu cuenta de Apple", "pt": "Renovação anual; cancele quando quiser na sua Conta Apple", "fr": "Renouvellement annuel ; annulez à tout moment dans votre compte Apple", "ja": "毎年自動更新。Apple Accountでいつでも解約できます", "ko": "매년 자동 갱신되며 Apple 계정에서 언제든지 취소할 수 있습니다", "it": "Rinnovo annuale; annulla in qualsiasi momento nel tuo Apple Account"],
        "一次购买，永久解锁当前 Personal 功能": ["es": "Una compra para acceder permanentemente a las funciones actuales de Ohana Personal", "pt": "Uma compra para acesso permanente aos recursos atuais do Ohana Personal", "fr": "Un achat pour un accès permanent aux fonctionnalités Ohana Personal actuelles", "ja": "1回の購入で、現在のOhana Personal機能を永続的に利用できます", "ko": "한 번 구매하면 현재 Ohana Personal 기능을 영구적으로 이용할 수 있습니다", "it": "Un solo acquisto per accedere permanentemente alle attuali funzioni Ohana Personal"],
        "载入中": ["es": "Cargando", "pt": "Carregando", "fr": "Chargement", "ja": "読み込み中", "ko": "불러오는 중", "it": "Caricamento"],
        "请先选择一个方案": ["es": "Elige un plan para continuar", "pt": "Escolha um plano para continuar", "fr": "Choisissez une formule pour continuer", "ja": "続けるにはプランを選択してください", "ko": "계속하려면 플랜을 선택하세요", "it": "Scegli un piano per continuare"],
        "Personal 外观权益": ["es": "Extras visuales de Personal", "pt": "Extras visuais do Personal", "fr": "Bonus visuels de Personal", "ja": "Personalの外観特典", "ko": "Personal 디자인 혜택", "it": "Extra estetici di Personal"],
        "流光绿洲、午夜群岛与霓虹网格背景": ["es": "Fondos Resplandor del oasis, Islas de Medianoche y Cuadrícula Neón", "pt": "Fundos Brilho do oásis, Ilhas da Meia-noite e Grade Neon", "fr": "Arrière-plans Lueur de l’oasis, Îles de minuit et Grille néon", "ja": "オアシスの輝き、真夜中の島々、ネオングリッドの背景", "ko": "오아시스 글로우, 한밤의 섬, 네온 그리드 배경", "it": "Sfondi Bagliore dell’oasi, Isole di mezzanotte e Griglia neon"],
        "Founding Ohana 周报海报与支持者标记": ["es": "Póster semanal Founding Ohana y distintivo de apoyo", "pt": "Pôster semanal Founding Ohana e marca de apoiador", "fr": "Affiche hebdomadaire Founding Ohana et badge de soutien", "ja": "Founding Ohana週間レポートポスターとサポーターマーク", "ko": "Founding Ohana 주간 리포트 포스터 및 서포터 표시", "it": "Poster settimanale Founding Ohana e contrassegno sostenitore"],
        "已由 Ohana Personal 解锁": ["es": "Desbloqueado con Ohana Personal", "pt": "Desbloqueado pelo Ohana Personal", "fr": "Débloqué grâce à Ohana Personal", "ja": "Ohana Personalでアンロック済み", "ko": "Ohana Personal로 잠금 해제됨", "it": "Sbloccato con Ohana Personal"],
        "Personal 可立即解锁，也可在椰子商店赚取": ["es": "Desbloquéalo con Personal o consíguelo en la Tienda de Cocos", "pt": "Desbloqueie com o Personal ou ganhe na Loja de Cocos", "fr": "Débloquez-le avec Personal ou obtenez-le dans la Boutique Coco", "ja": "Personalですぐにアンロックするか、ココナッツショップで獲得", "ko": "Personal로 바로 잠금 해제하거나 코코넛 상점에서 획득", "it": "Sbloccalo con Personal oppure ottienilo nel Negozio delle noci di cocco"],
        "月度与年度方案会自动续订，除非在当前周期结束前至少 24 小时于 Apple 账号中取消。Lifetime 为一次性购买。付款由 Apple 处理。": [
            "es": "Los planes mensuales y anuales se renuevan automáticamente, salvo que se cancelen en tu cuenta de Apple al menos 24 horas antes de que finalice el periodo actual. Lifetime es una compra única. Apple procesa el pago.",
            "pt": "Os planos mensais e anuais são renovados automaticamente, a menos que sejam cancelados na sua Conta Apple pelo menos 24 horas antes do fim do período atual. Lifetime é uma compra única. O pagamento é processado pela Apple.",
            "fr": "Les formules mensuelles et annuelles se renouvellent automatiquement, sauf annulation dans votre compte Apple au moins 24 heures avant la fin de la période en cours. Lifetime est un achat unique. Le paiement est traité par Apple.",
            "ja": "月額および年額プランは、現在の期間が終了する24時間以上前にApple Accountで解約しない限り自動更新されます。Lifetimeは買い切りです。支払いはAppleが処理します。",
            "ko": "월간 및 연간 요금제는 현재 이용 기간이 끝나기 최소 24시간 전에 Apple 계정에서 취소하지 않으면 자동 갱신됩니다. Lifetime은 일회성 구매이며 결제는 Apple에서 처리합니다.",
            "it": "I piani mensili e annuali si rinnovano automaticamente, salvo annullamento nell’Apple Account almeno 24 ore prima della fine del periodo corrente. Lifetime è un acquisto una tantum. Il pagamento è gestito da Apple."
        ],
        "Lifetime 仅包含当前平台的本地 Personal 功能，不包含未来的 Family 在线服务或 Care+。": [
            "es": "Lifetime cubre las funciones locales de Ohana Personal en esta plataforma; no incluye futuros servicios en línea de Family ni Care+.",
            "pt": "Lifetime cobre os recursos locais do Ohana Personal nesta plataforma; futuros serviços online do Family e o Care+ não estão incluídos.",
            "fr": "Lifetime couvre les fonctionnalités locales Ohana Personal sur cette plateforme ; les futurs services en ligne Family et Care+ ne sont pas inclus.",
            "ja": "Lifetimeには、このプラットフォームのローカルなOhana Personal機能のみが含まれます。将来のFamilyオンラインサービスやCare+は含まれません。",
            "ko": "Lifetime에는 이 플랫폼의 로컬 Ohana Personal 기능만 포함되며 향후 Family 온라인 서비스와 Care+는 포함되지 않습니다.",
            "it": "Lifetime include le funzionalità locali Ohana Personal su questa piattaforma; i futuri servizi online Family e Care+ non sono inclusi."
        ],
        "隐私政策": ["es": "Política de privacidad", "pt": "Política de Privacidade", "fr": "Politique de confidentialité", "ja": "プライバシーポリシー", "ko": "개인정보 처리방침", "it": "Informativa sulla privacy"],
        "使用条款": ["es": "Términos de uso", "pt": "Termos de Uso", "fr": "Conditions d’utilisation", "ja": "利用規約", "ko": "이용 약관", "it": "Termini di utilizzo"],
        "Ohana Personal 已解锁。谢谢你的支持。": ["es": "Ohana Personal está desbloqueado. Gracias por tu apoyo.", "pt": "Ohana Personal foi desbloqueado. Obrigado pelo apoio.", "fr": "Ohana Personal est débloqué. Merci pour votre soutien.", "ja": "Ohana Personalをアンロックしました。ご支援ありがとうございます。", "ko": "Ohana Personal이 잠금 해제되었습니다. 응원해 주셔서 감사합니다.", "it": "Ohana Personal è sbloccato. Grazie per il supporto."],
        "Ohana Personal 已恢复。": ["es": "Ohana Personal se ha restaurado.", "pt": "Ohana Personal foi restaurado.", "fr": "Ohana Personal a été restauré.", "ja": "Ohana Personalを復元しました。", "ko": "Ohana Personal을 복원했습니다.", "it": "Ohana Personal è stato ripristinato."],
        "当前 Apple 账号没有可恢复的 Personal 或 Supporter Pack 购买。": [
            "es": "La cuenta de Apple actual no tiene ninguna compra de Personal o Supporter Pack que se pueda restaurar.",
            "pt": "A Conta Apple atual não tem nenhuma compra do Personal ou Supporter Pack para restaurar.",
            "fr": "Le compte Apple actuel ne possède aucun achat Personal ou Supporter Pack à restaurer.",
            "ja": "現在のApple Accountには、復元できるPersonalまたはSupporter Packの購入がありません。",
            "ko": "현재 Apple 계정에 복원할 수 있는 Personal 또는 Supporter Pack 구매 내역이 없습니다.",
            "it": "L’Apple Account attuale non ha acquisti Personal o Supporter Pack da ripristinare."
        ],
        "Ohana Personal 暂时无法使用。": ["es": "Ohana Personal no está disponible temporalmente.", "pt": "Ohana Personal está temporariamente indisponível.", "fr": "Ohana Personal est temporairement indisponible.", "ja": "Ohana Personalは現在利用できません。", "ko": "Ohana Personal을 일시적으로 사용할 수 없습니다.", "it": "Ohana Personal non è temporaneamente disponibile."],
        "Personal 背景": ["es": "Fondos Personal", "pt": "Fundos Personal", "fr": "Arrière-plans Personal", "ja": "Personal背景", "ko": "Personal 배경", "it": "Sfondi Personal"],
        "需要 Ohana Personal": ["es": "Requiere Ohana Personal", "pt": "Requer o Ohana Personal", "fr": "Nécessite Ohana Personal", "ja": "Ohana Personalが必要", "ko": "Ohana Personal 필요", "it": "Richiede Ohana Personal"],
        "添加另一只宠物": ["es": "Añadir otra mascota", "pt": "Adicionar outro animal", "fr": "Ajouter un autre animal", "ja": "別のペットを追加", "ko": "다른 반려동물 추가", "it": "Aggiungi un altro animale"],
        "添加更多 Human": ["es": "Añadir más Human", "pt": "Adicionar mais Human", "fr": "Ajouter d’autres Human", "ja": "Humanをさらに追加", "ko": "Human 더 추가", "it": "Aggiungi altri Human"],
        "添加更多活跃植物": ["es": "Añadir más plantas activas", "pt": "Adicionar mais plantas ativas", "fr": "Ajouter d’autres plantes actives", "ja": "アクティブな植物をさらに追加", "ko": "활성 식물 더 추가", "it": "Aggiungi altre piante attive"],
        "创建更多普通计划": ["es": "Crear más planes cotidianos", "pt": "Criar mais planos do dia a dia", "fr": "Créer plus de plans courants", "ja": "通常プランをさらに作成", "ko": "일반 플랜 더 만들기", "it": "Crea altri piani quotidiani"],
        "查看更长期趋势": ["es": "Ver tendencias a más largo plazo", "pt": "Ver tendências de prazo mais longo", "fr": "Voir les tendances à plus long terme", "ja": "より長期の傾向を見る", "ko": "더 장기적인 추세 보기", "it": "Visualizza tendenze a più lungo termine"],
        "生成兽医 PDF 摘要": ["es": "Crear un resumen veterinario en PDF", "pt": "Criar um resumo veterinário em PDF", "fr": "Créer un résumé vétérinaire en PDF", "ja": "獣医向けPDF要約を作成", "ko": "수의사용 PDF 요약 만들기", "it": "Crea un riepilogo veterinario in PDF"],
        "使用 Personal 外观": ["es": "Usar estilos de Ohana Personal", "pt": "Usar visuais do Ohana Personal", "fr": "Utiliser les styles Ohana Personal", "ja": "Ohana Personalの外観を使用", "ko": "Ohana Personal 디자인 사용", "it": "Usa gli stili di Ohana Personal"],
        "现有数据不会被锁定或删除。": ["es": "Tus datos existentes nunca se bloquearán ni eliminarán.", "pt": "Seus dados existentes nunca serão bloqueados nem excluídos.", "fr": "Vos données existantes ne seront jamais bloquées ni supprimées.", "ja": "既存のデータがロックまたは削除されることはありません。", "ko": "기존 데이터는 잠기거나 삭제되지 않습니다.", "it": "I dati esistenti non verranno mai bloccati né eliminati."],
        "Free 提供最近 30 天的基础趋势；Ohana Personal 解锁 90 天与全部时间分析。现有记录始终可用。": [
            "es": "Free incluye tendencias básicas de los últimos 30 días. Ohana Personal desbloquea análisis de 90 días y de todo el historial. Los registros existentes siguen siempre disponibles.",
            "pt": "Free inclui tendências básicas dos últimos 30 dias. Ohana Personal libera análises de 90 dias e de todo o histórico. Os registros existentes continuam sempre disponíveis.",
            "fr": "Free inclut les tendances de base des 30 derniers jours. Ohana Personal débloque les analyses sur 90 jours et sur tout l’historique. Les données existantes restent toujours disponibles.",
            "ja": "Freeでは直近30日間の基本的な傾向を確認できます。Ohana Personalでは90日間と全期間の分析を利用できます。既存の記録は常に利用できます。",
            "ko": "Free에서는 최근 30일의 기본 추세를 볼 수 있습니다. Ohana Personal에서는 90일 및 전체 기간 분석을 이용할 수 있습니다. 기존 기록은 항상 이용할 수 있습니다.",
            "it": "Free include le tendenze di base degli ultimi 30 giorni. Ohana Personal sblocca analisi a 90 giorni e dell’intero storico. I dati esistenti restano sempre disponibili."
        ],
        "Ohana Personal 可从本地记录生成兽医 PDF 摘要；原始记录与手动导出始终可用。": [
            "es": "Ohana Personal crea resúmenes veterinarios en PDF a partir de registros locales. Los registros originales y la exportación manual siguen siempre disponibles.",
            "pt": "Ohana Personal cria resumos veterinários em PDF a partir de registros locais. Os registros originais e a exportação manual continuam sempre disponíveis.",
            "fr": "Ohana Personal crée des résumés vétérinaires en PDF à partir des données locales. Les données brutes et l’export manuel restent toujours disponibles.",
            "ja": "Ohana Personalではローカルの記録から獣医向けPDF要約を作成できます。元の記録と手動エクスポートは常に利用できます。",
            "ko": "Ohana Personal은 로컬 기록으로 수의사용 PDF 요약을 만들 수 있습니다. 원본 기록과 수동 내보내기는 항상 이용할 수 있습니다.",
            "it": "Ohana Personal crea riepiloghi veterinari in PDF dai dati locali. I dati originali e l’esportazione manuale restano sempre disponibili."
        ],
        "Ohana Personal 解锁全部 Founding Supporter 外观权益。": ["es": "Ohana Personal desbloquea todos los extras visuales de Founding Supporter.", "pt": "Ohana Personal libera todos os extras visuais de Founding Supporter.", "fr": "Ohana Personal débloque tous les extras visuels Founding Supporter.", "ja": "Ohana PersonalではFounding Supporterのすべての外観特典を利用できます。", "ko": "Ohana Personal은 Founding Supporter의 모든 디자인 혜택을 잠금 해제합니다.", "it": "Ohana Personal sblocca tutti gli extra estetici Founding Supporter."],
        "Personal Lifetime · 已启用": ["es": "Personal Lifetime · Activo", "pt": "Personal Lifetime · Ativo", "fr": "Personal Lifetime · Actif", "ja": "Personal Lifetime · 有効", "ko": "Personal Lifetime · 활성", "it": "Personal Lifetime · Attivo"],
        "Personal 年度方案 · 已启用": ["es": "Personal anual · Activo", "pt": "Personal anual · Ativo", "fr": "Personal annuel · Actif", "ja": "Personal 年額 · 有効", "ko": "Personal 연간 · 활성", "it": "Personal annuale · Attivo"],
        "Personal 月度方案 · 已启用": ["es": "Personal mensual · Activo", "pt": "Personal mensal · Ativo", "fr": "Personal mensuel · Actif", "ja": "Personal 月額 · 有効", "ko": "Personal 월간 · 활성", "it": "Personal mensile · Attivo"],
        "已启用": ["es": "Activo", "pt": "Ativo", "fr": "Actif", "ja": "有効", "ko": "활성", "it": "Attivo"]
    ]
    private static let curatedStaticTranslations: [String: [String: String]] = {
        var values = curatedStaticTranslationsBase
        for (key, translations) in curatedStaticTranslationsExpansion {
            values[key, default: [:]].merge(translations) { _, new in new }
        }
        for (key, translations) in curatedPersonalCommerceTranslations {
            values[key, default: [:]].merge(translations) { _, new in new }
        }
        return values
    }()

    var tabHome: String { tr(zh: "首页", en: "Home", de: "Start") }
    var tabPlant: String { tr(zh: "植物", en: "Plants", de: "Pflanzen") }
    var tabCalendar: String { tr(zh: "日历", en: "Calendar", de: "Kalender") }
    var tabCrew: String { tr(zh: "图鉴", en: "Crew", de: "Team") }
    var tabOasis: String { tr(zh: "绿洲", en: "Oasis", de: "Oase") }

    func greeting(_ text: String) -> String { text } // greeting 已由逻辑生成
    var ohanaCrew: String { tr(zh: "Ohana 图鉴", en: "Ohana Crew", de: "Ohana Team") }

    func morningHint(_ name: String) -> String {
        tr(zh: "带 \(name) 早晨出去走走吧", en: "Take \(name) for a morning walk", de: "Geh morgens mit \(name) spazieren")
    }

    func eveningHint(_ name: String) -> String {
        tr(zh: "黄金时段，带 \(name) 散个步 🌇", en: "Golden hour — walk \(name) 🌇", de: "Goldene Stunde — geh mit \(name) raus 🌇")
    }

    func defaultHint(_ name: String) -> String {
        tr(zh: "\(name) 在等你呢", en: "\(name) is waiting for you", de: "\(name) wartet auf dich")
    }

    var goodMorning: String { tr(zh: "早上好", en: "Good morning", de: "Guten Morgen") }
    var goodAfternoon: String { tr(zh: "下午好", en: "Good afternoon", de: "Guten Tag") }
    var goodEvening: String { tr(zh: "晚上好", en: "Good evening", de: "Guten Abend") }
    var goodNight: String { tr(zh: "晚安", en: "Good night", de: "Gute Nacht") }
    // MARK: - Settings
    var settings: String { tr(zh: "设置", en: "Settings", de: "Einstellungen") }
    var addMember: String { tr(zh: "添加成员", en: "Add Member", de: "Mitglied hinzufügen") }
    var manageHome: String { tr(zh: "管理主页", en: "Manage Home", de: "Startseite verwalten") }
    var manageHomeModules: String { tr(zh: "管理主页模块", en: "Manage home sections", de: "Startseitenbereiche verwalten") }
    var preferences: String { tr(zh: "偏好设置", en: "Preferences", de: "Einstellungen") }
    var countryRegion: String { tr(zh: "国家/地区", en: "Country/Region", de: "Land/Region") }
    var countryDefaultsHint: String {
        tr(
            zh: "选择后会应用默认语言、单位和货币，之后仍可单独修改",
            en: "Applies default language, units, and currency; each can still be changed",
            de: "Setzt Sprache, Einheiten und Währung vor, bleibt einzeln änderbar"
        )
    }

    var language: String { tr(zh: "语言", en: "Language", de: "Sprache") }
    var measurementUnits: String { tr(zh: "计量单位", en: "Measurement units", de: "Maßeinheiten") }
    var measurementUnitsHint: String {
        tr(
            zh: "用于体重、距离、粮食重量等显示",
            en: "Used for weight, distance, and food amount displays",
            de: "Für Gewicht, Distanz und Futtermengen"
        )
    }

    var currency: String { tr(zh: "货币", en: "Currency", de: "Währung") }
    var currencyDisplayOnlyHint: String {
        tr(
            zh: "只影响显示格式，不进行汇率换算",
            en: "Only changes display format; no exchange conversion",
            de: "Ändert nur die Anzeige, keine Umrechnung"
        )
    }

    var appearance: String { tr(zh: "外观主题", en: "Appearance", de: "Darstellung") }
    var themeSystem: String { tr(zh: "跟随系统", en: "System", de: "System") }
    var themeLight: String { tr(zh: "浅色模式", en: "Light", de: "Hell") }
    var themeDark: String { tr(zh: "深色模式", en: "Dark", de: "Dunkel") }
    var replayOnboarding: String { tr(zh: "查看引导页", en: "Replay onboarding", de: "Einführung ansehen") }
    var replayOnboardingSubtitle: String {
        tr(zh: "重新播放首次启动引导，方便测试", en: "Replay the first-launch guide for testing", de: "Startanleitung zum Testen erneut anzeigen")
    }

    var personalInfo: String { tr(zh: "个人信息", en: "Profile", de: "Profil") }
    var notSet: String { tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt") }
    var editNickname: String { tr(zh: "修改昵称", en: "Edit nickname", de: "Spitznamen ändern") }
    var enterNickname: String { tr(zh: "输入昵称", en: "Enter nickname", de: "Spitznamen eingeben") }
    var notifications: String { tr(zh: "通知", en: "Notifications", de: "Benachrichtigungen") }
    var about: String { tr(zh: "关于", en: "About", de: "Über") }
    var petManagement: String { tr(zh: "宠物管理", en: "Pet Management", de: "Haustierverwaltung") }
    var clearAllData: String { tr(zh: "清除所有数据", en: "Clear All Data", de: "Alle Daten löschen") }
    var notificationPermission: String { tr(zh: "通知权限", en: "Notification Permission", de: "Benachrichtigungen") }
    var manageNotification: String { tr(zh: "管理通知设置", en: "Manage notification settings", de: "Benachrichtigungseinstellungen verwalten") }
    var deviceIdentity: String { tr(zh: "设备身份", en: "Device Identity", de: "Geräteidentität") }
    var nickname: String { tr(zh: "昵称", en: "Nickname", de: "Spitzname") }
    // MARK: - Pet Detail
    var edit: String { tr(zh: "编辑", en: "Edit", de: "Bearbeiten") }
    var calendar: String { tr(zh: "日历", en: "Calendar", de: "Kalender") }
    var sitterCard: String { tr(zh: "照护卡", en: "Sitter Card", de: "Betreuungskarte") }
    var immuneHealth: String { tr(zh: "免疫小盾牌", en: "Immune Shield", de: "Immunschild") }
    var vaccineBook: String { tr(zh: "疫苗小本本", en: "Vaccine Book", de: "Impfpass") }
    var noRecords: String { tr(zh: "暂无记录", en: "No records yet", de: "Noch keine Einträge") }
    var expired: String { tr(zh: "已过期", en: "Expired", de: "Abgelaufen") }
    func validUntil(_ date: String) -> String {
        tr(zh: "有效至 \(date)", en: "Valid until \(date)", de: "Gültig bis \(date)", es: "Válido hasta \(date)", pt: "Válido até \(date)", fr: "Valable jusqu'au \(date)")
    }

    var weight: String { tr(zh: "体重", en: "Weight", de: "Gewicht") }
    var expense: String { tr(zh: "花费", en: "Expense", de: "Ausgabe") }
    var quickExpenseTitle: String { tr(zh: "快速记账", en: "Quick expense", de: "Schnelle Ausgabe") }
    var quickExpenseAmount: String { tr(zh: "金额", en: "Amount", de: "Betrag") }
    var quickExpenseCommonAmounts: String { tr(zh: "常用金额", en: "Common amounts", de: "Häufige Beträge") }
    var quickExpenseCategory: String { tr(zh: "分类", en: "Category", de: "Kategorie") }
    var quickExpensePayer: String { tr(zh: "支付者", en: "Payer", de: "Zahlende Person") }
    var quickExpenseUnspecified: String { tr(zh: "未指定", en: "Unspecified", de: "Nicht angegeben") }
    var quickExpenseMore: String { tr(zh: "更多", en: "More", de: "Mehr") }
    var quickExpenseToday: String { tr(zh: "今天", en: "Today", de: "Heute") }
    var quickExpenseHasNote: String { tr(zh: "有备注", en: "Has note", de: "Mit Notiz") }
    var quickExpenseDate: String { tr(zh: "日期", en: "Date", de: "Datum") }
    var quickExpenseNote: String { tr(zh: "备注", en: "Note", de: "Notiz") }
    var quickExpenseOptional: String { tr(zh: "可选", en: "Optional", de: "Optional") }
    var quickExpenseSave: String { tr(zh: "保存花费", en: "Save expense", de: "Ausgabe speichern") }
    var quickExpenseSaving: String { tr(zh: "保存中", en: "Saving", de: "Speichert") }
    var quickExpenseKeyboardSave: String { tr(zh: "保存", en: "Save", de: "Speichern") }
    var quickExpenseMedicalRecorded: String { tr(zh: "医疗花费已记录", en: "Medical expense saved", de: "Medizinische Ausgabe gespeichert") }
    func quickExpenseSubmitToInsurer(_ name: String) -> String {
        tr(zh: "可以继续提交给 \(name)", en: "You can submit it to \(name)", de: "Du kannst sie bei \(name) einreichen", es: "Puedes enviarlo a \(name)", pt: "Você pode enviar para \(name)", fr: "Tu peux l'envoyer à \(name)")
    }

    var quickExpenseInsuranceCompany: String { tr(zh: "保险公司", en: "insurer", de: "Versicherung") }
    var quickExpenseApplyClaim: String { tr(zh: "已记录 · 申请报销", en: "Saved · Claim", de: "Gespeichert · Erstattung") }
    var quickExpenseReceipt: String { tr(zh: "凭证", en: "Receipt", de: "Beleg") }
    func quickExpenseReceiptCount(_ count: Int) -> String {
        tr(zh: "\(count) 个附件", en: "\(count) attachment\(count == 1 ? "" : "s")", de: "\(count) Anhang\(count == 1 ? "" : "e")", es: "\(count) adjunto\(count == 1 ? "" : "s")", pt: "\(count) anexo\(count == 1 ? "" : "s")", fr: "\(count) pièce\(count == 1 ? "" : "s") jointe\(count == 1 ? "" : "s")")
    }

    var quickExpenseCamera: String { tr(zh: "拍照", en: "Camera", de: "Kamera") }
    var quickExpensePhotos: String { tr(zh: "相册", en: "Photos", de: "Fotos") }
    var quickExpenseFile: String { tr(zh: "文件", en: "File", de: "Datei") }
    var quickExpenseRemoveReceipt: String { tr(zh: "移除凭证", en: "Remove receipt", de: "Beleg entfernen") }
    var quickExpenseImage: String { tr(zh: "图片", en: "Image", de: "Bild") }
    var quickExpenseCameraUnavailable: String { tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar") }
    var quickExpenseCameraPermissionMessage: String {
        tr(zh: "请在系统设置中允许 Ohana 访问相机。", en: "Allow Ohana to access the camera in system settings.", de: "Erlaube Ohana den Kamerazugriff in den Systemeinstellungen.", es: "Permite que Ohana acceda a la cámara en los ajustes del sistema.", pt: "Permita que o Ohana acesse a câmera nos ajustes do sistema.", fr: "Autorise Ohana à accéder à l'appareil photo dans les réglages système.")
    }

    var quickExpenseInsuranceSingleTitle: String { tr(zh: "单笔保险费", en: "Single insurance expense", de: "Einzelne Versicherungszahlung") }
    var quickExpenseInsuranceSingleWithPolicy: String {
        tr(zh: "长期扣款请在保单页管理，避免重复生成。", en: "Manage recurring payments on the policy page to avoid duplicates.", de: "Wiederkehrende Zahlungen bitte in der Police verwalten, um Duplikate zu vermeiden.", es: "Gestiona los pagos recurrentes en la póliza para evitar duplicados.", pt: "Gerencie pagamentos recorrentes na apólice para evitar duplicatas.", fr: "Gère les paiements récurrents dans la police pour éviter les doublons.")
    }

    var quickExpenseInsuranceSingleNoPolicy: String {
        tr(zh: "这里可以先补记一笔保险费；长期计划请从保单页创建。", en: "Use this for one insurance payment; create long-term plans from the policy page.", de: "Hier nur eine Zahlung erfassen; langfristige Pläne in der Police anlegen.", es: "Úsalo para un pago de seguro; crea planes largos desde la póliza.", pt: "Use para um pagamento de seguro; crie planos longos na apólice.", fr: "Utilise ceci pour un paiement d'assurance; crée les plans durables depuis la police.")
    }

    func expenseCategoryTitle(_ category: ExpenseCategory) -> String {
        switch category {
        case .food: tr(zh: "食物", en: "Food", de: "Futter")
        case .treats: tr(zh: "零食", en: "Treats", de: "Snacks")
        case .medical: tr(zh: "医疗", en: "Medical", de: "Medizin")
        case .grooming: tr(zh: "美容", en: "Grooming", de: "Pflege")
        case .toys: tr(zh: "玩具", en: "Toys", de: "Spielzeug")
        case .insurancePremium: tr(zh: "保险费", en: "Insurance", de: "Versicherung")
        case .other: tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }

    func insuranceFrequencyTitle(_ frequency: InsurancePaymentFrequency) -> String {
        switch frequency {
        case .monthly: tr(zh: "按月", en: "Monthly", de: "Monatlich")
        case .quarterly: tr(zh: "按季", en: "Quarterly", de: "Vierteljährlich")
        case .annual: tr(zh: "按年", en: "Yearly", de: "Jährlich")
        case .once: tr(zh: "一次性", en: "Once", de: "Einmalig")
        }
    }

    var thisMonth: String { tr(zh: "本月", en: "This month", de: "Diesen Monat") }
    var patrol: String { tr(zh: "巡岛", en: "Patrol", de: "Runde drehen") }
    var potty: String { tr(zh: "噗噗", en: "Poop", de: "Häufchen") }
    var today: String { tr(zh: "今日", en: "Today", de: "Heute") }
    var foodStock: String { tr(zh: "粮仓", en: "Pantry", de: "Vorrat") }
    func daysLeft(_ n: Int) -> String { tr(zh: "仅剩 \(n) 天", en: "\(n) days left", de: "Noch \(n) Tage", es: "Quedan \(n) días", pt: "Faltam \(n) dias", fr: "Plus que \(n) jours", ja: "あと \(n) 日", ko: "\(n)일 남음", it: "Mancano \(n) giorni") }
    var timeline: String { tr(zh: "岁月史书", en: "Timeline", de: "Chronik") }
    func entries(_ n: Int) -> String { tr(zh: "\(n) 条", en: "\(n) entries", de: "\(n) Einträge", es: "\(n) entradas", pt: "\(n) registros", fr: "\(n) entrées") }
    var noEntries: String { tr(zh: "还没有任何记录", en: "No entries yet", de: "Noch keine Einträge") }
    var dangerZone: String { tr(zh: "危险区域", en: "Danger zone", de: "Gefahrenbereich") }
    var clearRecords: String { tr(zh: "仅清空所有记录", en: "Clear records only", de: "Nur Einträge löschen") }
    func deletePet(_ name: String) -> String { tr(zh: "彻底删除 \(name)", en: "Delete \(name)", de: "\(name) löschen", es: "Eliminar \(name)", pt: "Excluir \(name)", fr: "Supprimer \(name)") }
    // MARK: - Human Detail
    var healthBody: String { tr(zh: "健康 & 身体", en: "Health & Body", de: "Gesundheit & Körper") }
    var activityRecords: String { tr(zh: "活动 & 记录", en: "Activity & Records", de: "Aktivität & Einträge") }
    var finance: String { tr(zh: "财务", en: "Finance", de: "Finanzen") }
    var remindersNotes: String { tr(zh: "提醒 & 备注", en: "Reminders & Notes", de: "Erinnerungen & Notizen") }
    var medication: String { tr(zh: "用药", en: "Medication", de: "Medikamente") }
    var todo: String { tr(zh: "待办", en: "To-do", de: "Aufgaben") }
    var coconut: String { tr(zh: "椰子", en: "Coconut", de: "Kokosnuss") }
    var notes: String { tr(zh: "备注", en: "Notes", de: "Notizen") }
    var deleteMember: String { tr(zh: "删除成员", en: "Delete Member", de: "Mitglied löschen") }
    // MARK: - Common
    var save: String { tr(zh: "保存", en: "Save", de: "Speichern") }
    var cancel: String { tr(zh: "取消", en: "Cancel", de: "Abbrechen") }
    var confirm: String { tr(zh: "确认", en: "Confirm", de: "Bestätigen") }
    var done: String { tr(zh: "完成", en: "Done", de: "Fertig") }
    var search: String { tr(zh: "搜索", en: "Search", de: "Suchen") }
    func searchPlaceholder(_ text: String) -> String {
        tr(zh: "搜索\(text)...", en: "Search \(text)...", de: "\(text) suchen...", es: "Buscar \(text)...", pt: "Buscar \(text)...", fr: "Rechercher \(text)...")
    }

    var times: String { tr(zh: "次", en: "times", de: "Mal") }
    var types: String { tr(zh: "种", en: "types", de: "Arten") }
    var items: String { tr(zh: "条", en: "items", de: "Einträge") }
    // MARK: - Pet Species
    var dog: String { tr(zh: "狗", en: "Dog", de: "Hund") }
    var cat: String { tr(zh: "猫", en: "Cat", de: "Katze") }
    var rabbit: String { tr(zh: "兔子", en: "Rabbit", de: "Kaninchen") }
    var hamster: String { tr(zh: "仓鼠", en: "Hamster", de: "Hamster") }
    // MARK: - Calendar
    var monthView: String { tr(zh: "月视图", en: "Month", de: "Monat") }
    var listView: String { tr(zh: "列表", en: "List", de: "Liste") }
    var addEvent: String { tr(zh: "添加事件", en: "Add Event", de: "Termin hinzufügen") }
    // MARK: - Oasis
    var oasis: String { tr(zh: "绿洲", en: "Oasis", de: "Oase") }
    // MARK: - Crew Roster
    func searchCrewPlaceholder() -> String {
        tr(zh: "搜索岛民...", en: "Search island residents...", de: "Inselteam suchen...", es: "Buscar habitantes...", pt: "Buscar moradores...", fr: "Rechercher l'équipe...")
    }

    // MARK: - Batch Actions
    var batchCheckIn: String { tr(zh: "一键全家", en: "Crew check-in", de: "Team-Check-in") }
    /// 无 `@AppStorage` 的视图可用（与 `SettingsView` / `AppLanguage` 一致）
    static var current: L10n { L10n(UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.detectedCode) }
    // MARK: - Add Entity sheet
    var addEntityNavRoot: String { tr(zh: "添加家人", en: "Add to the island", de: "Zur Insel hinzufügen") }
    var addEntityHeadline: String { tr(zh: "谁要上岛？", en: "Who's joining the fun?", de: "Wer kommt dazu?") }
    var addEntitySub: String { tr(zh: "选择要加入岛屿的类型", en: "Pick a buddy type for your isle", de: "Wähle, wer einziehen soll") }
    var addEntityBack: String { tr(zh: "返回", en: "Back", de: "Zurück") }
    var addEntityClose: String { tr(zh: "关闭", en: "Close", de: "Schließen") }
    var addEntityWIP: String { tr(zh: "很快就来", en: "Soon!", de: "Kommt bald!") }
    var addEntityPetTitle: String { tr(zh: "小动物室友", en: "Pet pal", de: "Haustierfreund") }
    var addEntityPetBlurb: String { tr(zh: "毛茸茸、羽毛款、鳞片款都欢迎", en: "Furry, feathery, or scaly roomies", de: "Fell, Federn oder Schuppen willkommen") }
    var addEntityHumanTitle: String { tr(zh: "人类队友", en: "Human crew", de: "Menschen-Team") }
    var addEntityHumanBlurb: String { tr(zh: "添加一起照顾家的搭子", en: "Two-leg family & co-pilots", de: "Familie und Co-Piloten") }
    var addEntityPlantTitle: String { tr(zh: "叶子朋友", en: "Leafy friend", de: "Blattfreund") }
    var addEntityPlantBlurb: String { tr(zh: "阳光、水分和一点好心情", en: "Water, sun, good vibes only", de: "Wasser, Sonne, gute Laune") }
    // MARK: - Human wizard — mesh card titles
    var humanWizMesh1: String { tr(zh: "名字 · 1/6", en: "NAME · 1/6", de: "NAME · 1/6") }
    var humanWizMesh2: String { tr(zh: "个人档案 · 2/6", en: "PROFILE · 2/6", de: "PROFIL · 2/6") }
    var humanWizMesh3: String { tr(zh: "头像 · 3/6", en: "AVATAR · 3/6", de: "AVATAR · 3/6") }
    var humanWizMesh4: String { tr(zh: "资料与权限 · 4/6", en: "DETAILS & PERMISSION · 4/6", de: "DETAILS & RECHTE · 4/6") }
    var humanWizMesh5: String { tr(zh: "身体数据 · 5/6", en: "BODY & PRIVACY · 5/6", de: "KÖRPER & PRIVATSPHÄRE · 5/6") }
    var humanWizMesh6: String { tr(zh: "确认信息 · 6/6", en: "FINAL CHECK · 6/6", de: "ABSCHLUSS · 6/6") }
    var humanWizNameLabel: String { tr(zh: "姓名（必填）", en: "Name (required)", de: "Name (Pflicht)") }
    var humanWizNamePlaceholder: String { tr(zh: "输入名字", en: "Their island name", de: "Inselname") }
    var humanWizAvatarPhoto: String { tr(zh: "头像照片", en: "Profile photo", de: "Profilfoto") }
    var humanWizPhotoLibrary: String { tr(zh: "相册", en: "Photos", de: "Fotos") }
    var humanWizCamera: String { tr(zh: "拍照", en: "Camera", de: "Kamera") }
    var humanWizPasteSubject: String { tr(zh: "粘贴主体", en: "Paste cutout", de: "Ausschnitt einfügen") }
    var humanWizPasteHint: String {
        tr(
            zh: "相册长按人物 → 拷贝主体 → 点粘贴",
            en: "Long-press a person in Photos → Copy Subject → tap here",
            de: "Person in Fotos halten → Motiv kopieren → hier tippen"
        )
    }

    var humanWizEmojiAvatar: String { tr(zh: "或选择 Emoji 头像", en: "Or pick an emoji face", de: "Oder Emoji-Gesicht wählen") }
    var humanWizDupNameInline: String { tr(zh: "名字已被占用，请换一个", en: "That name's taken. Try another!", de: "Name schon vergeben. Nimm einen anderen.") }
    var humanWizGenderLabel: String { tr(zh: "性别/身份（必选）", en: "Gender / identity (required)", de: "Geschlecht / Identität (erforderlich)") }
    var humanWizBirthdayLabel: String { tr(zh: "生日（可选）", en: "Birthday (optional)", de: "Geburtstag (optional)") }
    var humanWizBirthdayHint: String { tr(zh: "点按选择日期，滚轮选好后点「完成」", en: "Tap to spin the wheel, then hit Done", de: "Tippen, Datum drehen, dann Fertig") }
    var humanWizBloodLabel: String { tr(zh: "血型（可选）", en: "Blood type (optional)", de: "Blutgruppe (optional)") }
    var humanWizMbtiLabel: String { tr(zh: "MBTI（可选）", en: "MBTI (optional)", de: "MBTI (optional)") }
    var humanWizSkipChip: String { tr(zh: "不填", en: "Skip", de: "Überspringen") }
    func humanWizBloodTag(_ type: String) -> String { tr(zh: "血型 \(type)", en: "Type \(type)", de: "Blutgruppe \(type)", es: "Tipo \(type)", pt: "Tipo \(type)", fr: "Groupe \(type)") }
    func humanWizNationalityTag(_ country: String) -> String { tr(zh: "国籍 \(country)", en: "From \(country)", de: "Aus \(country)", es: "De \(country)", pt: "De \(country)", fr: "De \(country)") }
    var humanWizNationalityLabel: String { tr(zh: "国籍（可选）", en: "Nationality (optional)", de: "Nationalität (optional)") }
    var humanWizNationalityHint: String { tr(zh: "从列表选择护照国籍，可不填", en: "Passport country from the list, or skip", de: "Passland wählen oder überspringen") }
    var humanWizResidenceLabel: String { tr(zh: "现居地（可选）", en: "Where you live (optional)", de: "Wohnort (optional)") }
    var humanWizResidenceHint: String { tr(zh: "选择当前居住的国家与城市", en: "Pick country + city for your nest", de: "Land und Stadt für dein Nest") }
    var humanWizResidenceCityPlaceholder: String { tr(zh: "输入城市名称", en: "Type your city", de: "Stadt eingeben") }
    var humanWizNotesLabel: String { tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)") }
    var humanWizNotesPlaceholder: String { tr(zh: "任何想记录的信息", en: "Anything cozy to remember", de: "Alles, was bleiben soll") }
    var humanWizBodyLabel: String { tr(zh: "身体数据（可选）", en: "Body stats (optional)", de: "Körperdaten (optional)") }
    var humanWizHeightLabel: String { tr(zh: "身高", en: "Height", de: "Größe") }
    var humanWizHeightPh: String { tr(zh: "如 170", en: "e.g. 170", de: "z. B. 170") }
    var humanWizWeightLabel: String { tr(zh: "体重", en: "Weight", de: "Gewicht") }
    var humanWizWeightPh: String { tr(zh: "如 65.0", en: "e.g. 65", de: "z. B. 65") }
    var humanWizWeightFootnote: String { tr(zh: "填写体重将自动创建初始体重记录", en: "Adding weight creates a first log for charts", de: "Gewicht legt den ersten Diagramm-Eintrag an") }
    var humanWizPrivacyLabel: String { tr(zh: "隐私设置", en: "Privacy toggles", de: "Privatsphäre") }
    var humanWizPrivacyHint: String { tr(zh: "设为私密后，同设备的其他成员无法查看该内容", en: "When private, other profiles on this device can't peek", de: "Privat heißt: andere Profile auf diesem Gerät sehen es nicht") }
    var humanWizPrivacyWeight: String { tr(zh: "体重记录与图表", en: "Weight logs & charts", de: "Gewicht & Diagramme") }
    var humanWizPrivacyWorkout: String { tr(zh: "运动记录", en: "Workouts", de: "Workouts") }
    var humanWizPrivacyWishlist: String { tr(zh: "心愿单", en: "Wishlist", de: "Wunschliste") }
    var humanWizPrivacyExpense: String { tr(zh: "花费记录", en: "Spending", de: "Ausgaben") }
    var humanWizThemeLabel: String { tr(zh: "主题颜色", en: "Accent color", de: "Akzentfarbe") }
    var humanWizRolePermsLabel: String { tr(zh: "权限", en: "Permission", de: "Berechtigung") }
    var humanWizSummaryLabel: String { tr(zh: "信息摘要", en: "Cozy recap", de: "Kurzüberblick") }
    var humanWizSummaryEmpty: String { tr(zh: "选择权限和性别/身份后会出现在这里", en: "Pick permission and identity to preview them here", de: "Wähle Berechtigung und Identität für die Vorschau") }
    var humanWizRoleOwnerTitle: String { tr(zh: "管理者", en: "Admin", de: "Verwaltung") }
    var humanWizRoleOwnerDesc: String { tr(zh: "管理家庭资料与核心设置", en: "Manages home profile and core settings", de: "Verwaltet Haushalt und zentrale Einstellungen") }
    var humanWizRoleMemberTitle: String { tr(zh: "成员", en: "Member", de: "Mitglied") }
    var humanWizRoleMemberDesc: String { tr(zh: "日常记录与照护打卡", en: "Daily logs and care check-ins", de: "Alltagsnotizen und Pflege-Check-ins") }
    var humanWizRoleEditorTitle: String { humanWizRoleMemberTitle }
    var humanWizRoleEditorDesc: String { humanWizRoleMemberDesc }
    var humanWizRoleViewerTitle: String { humanWizRoleMemberTitle }
    var humanWizRoleViewerDesc: String { humanWizRoleMemberDesc }
    var humanWizJoinIsland: String { tr(zh: "加入 Ohana 岛", en: "Hop onto Ohana Isle!", de: "Ab auf die Ohana-Insel!") }
    var humanWizNeedName: String { tr(zh: "请先填写名字", en: "Name first, please", de: "Erst der Name") }
    var humanWizNeedGender: String { tr(zh: "请选择性别/身份", en: "Pick gender / identity", de: "Identität auswählen") }
    var humanWizNameTakenBtn: String { tr(zh: "名字已被占用", en: "Name taken", de: "Name vergeben") }
    var humanWizBirthdaySheetTitle: String { tr(zh: "选择生日", en: "Pick a birthday", de: "Geburtstag wählen") }
    var humanWizBirthdayEventSuffix: String { tr(zh: " 的生日 🎂", en: "'s birthday 🎂", de: " hat Geburtstag 🎂") }
    var humanWizDupAlertTitle: String { tr(zh: "名字已被占用 🏠", en: "That name's taken 🏠", de: "Name schon vergeben 🏠") }
    var humanWizDupAlertOk: String { tr(zh: "好的，换一个", en: "Got it. New name!", de: "Okay, neuer Name!") }
    func humanWizDupAlertMsg(_ name: String) -> String {
        tr(
            zh: "Ohana 里已经有叫「\(name)」的家人，换个名字吧！",
            en: "Someone on Ohana is already called \"\(name)\". Pick another cozy name!",
            de: "In Ohana heißt schon jemand \"\(name)\". Nimm einen neuen Kuschelnamen!",
            es: "En Ohana ya hay alguien llamado \"\(name)\". Elige otro nombre bonito.",
            pt: "No Ohana já existe alguém chamado \"\(name)\". Escolha outro nome fofo.",
            fr: "Dans Ohana, quelqu'un s'appelle déjà \"\(name)\". Choisis un autre joli nom."
        )
    }

    func humanGenderDisplay(_ key: String) -> String {
        switch HumanProfileOptions.normalizedGender(key) {
        case "男": tr(zh: "男", en: "Man", de: "Mann")
        case "女": tr(zh: "女", en: "Woman", de: "Frau")
        case "非二元": tr(zh: "非二元", en: "Non-binary", de: "Nichtbinär")
        case "不透露": tr(zh: "不透露", en: "Prefer not to say", de: "Keine Angabe")
        default: key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? notSet : key
        }
    }

    func humanThemeSwatchLabel(_ zh: String) -> String {
        switch zh {
        case "青柠": tr(zh: "青柠", en: "Lime", de: "Limette")
        case "橙色": tr(zh: "橙色", en: "Orange", de: "Orange")
        case "珊瑚": tr(zh: "珊瑚", en: "Coral", de: "Koralle")
        case "玫红": tr(zh: "玫红", en: "Rose", de: "Rosé")
        case "莓果": tr(zh: "莓果", en: "Berry", de: "Beere")
        case "靛蓝": tr(zh: "靛蓝", en: "Indigo", de: "Indigo")
        case "深靛": tr(zh: "深靛", en: "Deep indigo", de: "Tiefes Indigo")
        case "粉色": tr(zh: "粉色", en: "Pink", de: "Pink")
        case "青色": tr(zh: "青色", en: "Teal", de: "Türkis")
        case "深青": tr(zh: "深青", en: "Deep teal", de: "Tiefes Türkis")
        case "海青": tr(zh: "海青", en: "Sea cyan", de: "Meerescyan")
        case "湖蓝": tr(zh: "湖蓝", en: "Lake blue", de: "Seeblau")
        case "孔雀": tr(zh: "孔雀", en: "Peacock", de: "Pfau")
        case "森林": tr(zh: "森林", en: "Forest", de: "Wald")
        case "橄榄": tr(zh: "橄榄", en: "Olive", de: "Olive")
        case "叶绿": tr(zh: "叶绿", en: "Leaf", de: "Blattgrün")
        case "紫色": tr(zh: "紫色", en: "Purple", de: "Violett")
        case "紫罗兰": tr(zh: "紫罗兰", en: "Violet", de: "Violett")
        case "红色": tr(zh: "红色", en: "Red", de: "Rot")
        case "金色": tr(zh: "金色", en: "Gold", de: "Gold")
        case "琥珀": tr(zh: "琥珀", en: "Amber", de: "Bernstein")
        case "栗色": tr(zh: "栗色", en: "Chestnut", de: "Kastanie")
        case "酒红": tr(zh: "酒红", en: "Wine", de: "Weinrot")
        case "咖啡": tr(zh: "咖啡", en: "Coffee", de: "Kaffee")
        case "灰色": tr(zh: "灰色", en: "Slate", de: "Schiefer")
        default: zh
        }
    }

    func humanResidenceCityOther(_ zh: String) -> String {
        zh == "其他" ? tr(zh: "其他", en: "Other", de: "Andere") : zh
    }

    // MARK: - Human wallet cards
    var humanWalletNewMember: String { tr(zh: "新成员", en: "New island buddy", de: "Neuer Inselbuddy") }
    var humanWalletResident: String { tr(zh: "岛民", en: "Island pal", de: "Inselfreund") }
    var humanWalletSubtitlePlaceholder: String { tr(zh: "填写下方信息完善档案", en: "Fill the lil' form below ✨", de: "Unten ausfüllen, Profil wird rund ✨") }
    // MARK: - Add Pet Wizard
    var petWizMesh1: String { tr(zh: "基本信息 · 1/6", en: "WHO'S THAT CUTIE · 1/6", de: "WER IST SO SÜSS · 1/6") }
    var petWizMesh2: String { tr(zh: "生物特征 · 2/6", en: "LIL' BIO · 2/6", de: "KLEINE BIO · 2/6") }
    var petWizMesh3: String { tr(zh: "外貌与主题色 · 3/6", en: "SPOTS & SPARKLE · 3/6", de: "LOOK & GLANZ · 3/6") }
    var petWizMesh4: String { tr(zh: "头像 · 4/6", en: "PHOTO BOOP · 4/6", de: "FOTO-TIPP · 4/6") }
    var petWizMesh5: String { tr(zh: "标签 · 5/6", en: "VIBE TAGS · 5/6", de: "VIBE-TAGS · 5/6") }
    var petWizMesh6: String { tr(zh: "确认信息 · 6/6", en: "ALL SET? · 6/6", de: "ALLES BEREIT? · 6/6") }
    var petWizIslandWelcome: String { tr(zh: "岛屿欢迎新家人！", en: "The isle throws a welcome party!", de: "Die Insel schmeißt eine Willkommensrunde!") }
    var petWizBentoBasic: String { tr(zh: "基本信息", en: "Basics", de: "Basics") }
    var petWizBentoBreed: String { tr(zh: "品种", en: "Breed", de: "Rasse") }
    var petWizBentoAvatar: String { tr(zh: "头像设置", en: "Profile pic", de: "Profilbild") }
    var petWizBentoBio: String { tr(zh: "生物特征", en: "Bio & dates", de: "Bio & Daten") }
    var petWizBentoAppearance: String { tr(zh: "外貌特征", en: "Looks", de: "Look") }
    var petWizBentoTheme: String { tr(zh: "主题色", en: "Accent", de: "Akzent") }
    var petWizBentoTagsTitle: String { tr(zh: "给 TA 点小标签", en: "Tiny tags for them", de: "Kleine Tags fürs Wesen") }
    var petWizOptionalParen: String { tr(zh: "（可选）", en: "(optional)", de: "(optional)") }
    func petWizTagPicked(_ n: Int) -> String {
        tr(zh: "最多 3 个 · 已选 \(n)/3", en: "Pick up to 3 · \(n)/3", de: "Bis zu 3 · \(n)/3", es: "Hasta 3 · \(n)/3", pt: "Até 3 · \(n)/3", fr: "Jusqu'à 3 · \(n)/3")
    }

    var petWizNamePlaceholder: String { tr(zh: "给你的小怪兽起个名字", en: "Name your lil' monster", de: "Gib deinem kleinen Wunder einen Namen") }
    var petWizNameLabelRequired: String { tr(zh: "名字（必填）", en: "Name (required)", de: "Name (Pflicht)") }
    var petWizSpecies: String { tr(zh: "物种", en: "Species", de: "Art") }
    var petWizSpeciesOtherPh: String { tr(zh: "请输入物种，如：蜥蜴、刺猬", en: "Type a species, e.g. gecko or hedgehog", de: "Art eingeben, z. B. Gecko") }
    var petWizBreedExpand: String { tr(zh: "点按展开品种列表", en: "Tap to open breed list", de: "Tippen für Rassenliste") }
    var petWizBreedCollapse: String { tr(zh: "点按收起列表", en: "Tap to hide breed list", de: "Tippen zum Einklappen") }
    var petWizBreedSearchPh: String { tr(zh: "搜索品种…", en: "Search breeds…", de: "Rassen suchen…") }
    var petWizBreedNoMatch: String { tr(zh: "未找到匹配品种，可在列表中选择「其他」并自定义", en: "No hits. Pick Other and type a custom breed", de: "Nichts gefunden. Andere wählen und selbst eintragen") }
    var petWizBreedNone: String { tr(zh: "不选品种", en: "Skip breed", de: "Rasse überspringen") }
    var petWizCustomBreed: String { tr(zh: "自定义品种", en: "Custom breed", de: "Eigene Rasse") }
    var petWizCustomBreedFieldPh: String { tr(zh: "输入品种名称", en: "Breed name", de: "Rassenname") }
    var petWizAvatarHint: String { tr(zh: "点击粘贴抠图，或从下方选择", en: "Paste a cutout, or pick below", de: "Ausschnitt einfügen oder unten wählen") }
    var petWizRemoveAvatar: String { tr(zh: "移除头像，使用默认物种图标", en: "Remove photo · use species icon", de: "Foto entfernen · Art-Icon nutzen") }
    var petWizRemoveAvatarShort: String { tr(zh: "移除头像", en: "Remove photo", de: "Foto entfernen") }
    var petWizClipboardEmpty: String { tr(zh: "剪贴板", en: "Clipboard", de: "Zwischenablage") }
    var petWizNeuter: String { tr(zh: "绝育", en: "Spay / neuter", de: "Kastration") }
    var petWizNeuteredOn: String { tr(zh: "已绝育", en: "Spayed / neutered", de: "Kastriert") }
    var petWizNeuteredOff: String { tr(zh: "未绝育", en: "Not yet", de: "Noch nicht") }
    var petWizBirthday: String { tr(zh: "生日", en: "Birthday", de: "Geburtstag") }
    var petWizHomeDate: String { tr(zh: "到家日", en: "Gotcha day", de: "Einzugstag") }
    var petWizToggleOn: String { tr(zh: "启用", en: "On", de: "Ein") }
    var petWizGender: String { tr(zh: "性别", en: "Gender", de: "Geschlecht") }
    var petWizGenderBoy: String { tr(zh: "♂ 男孩", en: "♂ Boy", de: "♂ Junge") }
    var petWizGenderGirl: String { tr(zh: "♀ 女孩", en: "♀ Girl", de: "♀ Mädchen") }
    var petWizCoatSection: String { tr(zh: "毛色", en: "Coat", de: "Fell") }
    var petWizThemeSection: String { tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe") }
    var petWizCardThemeCaption: String { tr(zh: "宠物卡片主题色", en: "Wallet card accent", de: "Kartenakzent") }
    var petWizCardPreviewHex: String { tr(zh: "卡片预览色 #", en: "Preview swatch #", de: "Vorschaufarbe #") }
    var petWizTapBodyCoat: String { tr(zh: "点击身体 → 毛色", en: "Tap body → coat", de: "Körper tippen → Fell") }
    var petWizCardBgCaption: String { tr(zh: "卡片背景色", en: "Card backdrop", de: "Kartenhintergrund") }
    var petWizPassportLabel: String { tr(zh: "护照号码", en: "Passport #", de: "Passnummer") }
    var petWizMicrochipLabel: String { tr(zh: "芯片号 (Microchip ID)", en: "Microchip ID", de: "Microchip-ID") }
    var petWizOptionalShort: String { tr(zh: "选填", en: "Optional", de: "Optional") }
    var petWizMicrochipPlaceholder: String { tr(zh: "15位数字（选填）", en: "15 digits (optional)", de: "15 Ziffern (optional)") }
    var petWizUnnamed: String { tr(zh: "未命名", en: "Unnamed", de: "Unbenannt") }
    var petWizPickSpeciesFirst: String { tr(zh: "请先选择宠物品种", en: "Pick a species first", de: "Erst eine Art wählen") }
    var petWizNoSameSpeciesPets: String { tr(zh: "岛上暂时没有同品种宠物", en: "No same-species pals on the isle yet", de: "Noch keine Artgenossen auf der Insel") }
    var petWizCrossBreedHint: String { tr(zh: "不同品种间没有亲属关系，直接跳过", en: "Cross-breed bonds aren't tracked. Skip ahead!", de: "Artübergreifende Bindungen werden nicht verfolgt. Weiter!") }
    var petWizPickRelationIntro: String { tr(zh: "选择与每只宠物的关系（可多选，选填）", en: "Pick a vibe with each pet (multi, optional)", de: "Beziehung zu jedem Tier wählen (optional)") }
    var petWizPickCoatTitle: String { tr(zh: "选择毛色", en: "Pick coat color", de: "Fellfarbe wählen") }
    var petWizCustomColorPickerTitle: String { tr(zh: "自定义颜色", en: "Custom color", de: "Eigene Farbe") }
    var petCustomSwatch: String { tr(zh: "自定义", en: "Custom", de: "Eigen") }
    var petWizSaving: String { tr(zh: "保存中…", en: "Saving…", de: "Speichert…") }
    var petWizSavingShort: String { tr(zh: "保存中...", en: "Saving...", de: "Speichert...") }
    var petWizSaveFailedTitle: String { tr(zh: "保存失败", en: "Couldn't save", de: "Speichern fehlgeschlagen") }
    var petWizSaveFailedDefault: String { tr(zh: "无法写入资料库，请稍后重试。", en: "Couldn't write to the island vault. Try again?", de: "Konnte nicht speichern. Noch einmal versuchen?") }
    var petWizNext: String { tr(zh: "下一步", en: "Next", de: "Weiter") }
    var petWizBreedSheetTitle: String { tr(zh: "选择品种", en: "Choose breed", de: "Rasse wählen") }
    var petWizBreedSearchPrompt: String { tr(zh: "搜索品种", en: "Search breeds", de: "Rassen suchen") }
    var petWizBreedFieldPh: String { tr(zh: "请输入品种名称", en: "Type breed name", de: "Rassenname eingeben") }
    func petSpeciesLabel(_ storageKey: String) -> String {
        switch storageKey {
        case "狗": dog
        case "猫": cat
        case "兔子": rabbit
        case "仓鼠": hamster
        case "鸟": tr(zh: "鸟", en: "Birdie", de: "Vogel")
        case "其他": tr(zh: "其他", en: "Other critter", de: "Anderer Liebling")
        default: storageKey
        }
    }

    func petCoatPatternDisplay(_ zh: String) -> String {
        switch zh {
        case "三花": tr(zh: "三花", en: "Calico", de: "Schildpatt-Weiß")
        case "银渐层": tr(zh: "银渐层", en: "Silver shaded", de: "Silber schattiert")
        case "玳瑁": tr(zh: "玳瑁", en: "Tortie", de: "Schildpatt")
        case "奶牛色": tr(zh: "奶牛色", en: "Cow", de: "Kuhmuster")
        case "蓝白双色": tr(zh: "蓝白双色", en: "Blue & white", de: "Blau-Weiß")
        default: zh
        }
    }

    func petCoatOrEyeDisplay(_ zh: String) -> String {
        if isChinese { return zh }
        if isDe, let mapped = Self.petAppearanceZhToDe[zh] { return mapped }
        if zh == "自定义" { return petCustomSwatch }
        if let mapped = Self.petAppearanceZhToEn[zh] { return mapped }
        return petCoatPatternDisplay(zh)
    }

    func petWizDaysUntilHome(_ days: Int) -> String {
        tr(zh: "还有 \(days) 天到家", en: "\(days) days until gotcha 🏠", de: "Noch \(days) Tage bis zum Einzug 🏠", es: "\(days) días para llegar a casa 🏠", pt: "\(days) dias até chegar em casa 🏠", fr: "\(days) jours avant l'arrivée 🏠")
    }

    var petWizHomeToday: String { tr(zh: "今天到家", en: "Gotcha day is today!", de: "Heute ist Einzugstag!") }
    func petWizTogetherDays(_ days: Int) -> String {
        tr(zh: "已陪伴 \(days) 天", en: "Together \(days) days 💛", de: "\(days) Tage zusammen 💛", es: "\(days) días juntos 💛", pt: "\(days) dias juntos 💛", fr: "\(days) jours ensemble 💛")
    }

    func petWizMilestoneTogether(_ days: Int) -> String {
        tr(zh: "共度 \(days) 天", en: "Together \(days) days", de: "\(days) Tage zusammen", es: "\(days) días juntos", pt: "\(days) dias juntos", fr: "\(days) jours ensemble")
    }

    func petWizAgeWallet(years: Int, months: Int) -> String {
        if years > 0 {
            if months > 0 {
                return tr(zh: "\(years)岁\(months)月", en: "\(years)y \(months)m old", de: "\(years) J. \(months) Mon.", es: "\(years) a \(months) m", pt: "\(years) a \(months) m", fr: "\(years) a \(months) m")
            }
            return tr(zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.", es: "\(years) años", pt: "\(years) anos", fr: "\(years) ans")
        }
        return tr(zh: "\(months)个月", en: "\(months) mo", de: "\(months) Mon.", es: "\(months) meses", pt: "\(months) meses", fr: "\(months) mois")
    }

    func petWizBreedCollapseSummary(isCustomBreed: Bool, customBreedText: String, breed: String) -> String {
        if isCustomBreed {
            let t = customBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? tr(zh: "其他（待输入）", en: "Other (type it in)", de: "Andere (eintragen)", es: "Otro (por escribir)", pt: "Outro (preencher)", fr: "Autre (à saisir)") : t
        }
        if breed.isEmpty { return tr(zh: "未选择品种", en: "No breed picked", de: "Keine Rasse gewählt", es: "Sin raza elegida", pt: "Nenhuma raça escolhida", fr: "Aucune race choisie") }
        return breed
    }

    private static let petAppearanceZhToDe: [String: String] = [
        "三色": "Dreifarbig",
        "乳白": "Cremeweiß",
        "其他": "Andere",
        "多色": "Mehrfarbig",
        "奶白": "Milchweiß",
        "异瞳": "Verschiedene Augen",
        "杏色": "Apricot",
        "栗色": "Kastanie",
        "棕白": "Braun-Weiß",
        "棕色": "Braun",
        "榛色": "Hasel",
        "橘猫": "Orange getigert",
        "橙色": "Orange",
        "灰白": "Grau-Weiß",
        "灰色": "Grau",
        "玳瑁": "Schildpatt",
        "白猫": "Weiße Katze",
        "白色": "Weiß",
        "白面": "Weißes Gesicht",
        "米色": "Beige",
        "红柴": "Roter Shiba",
        "红白": "Rot-Weiß",
        "红色": "Rot",
        "纯白": "Reinweiß",
        "纯黑": "Tiefschwarz",
        "绿色": "Grün",
        "花斑": "Gefleckt",
        "蓝白": "Blau-Weiß",
        "蓝色": "Blau",
        "虎斑": "Getigert",
        "金色": "Gold",
        "铜色": "Kupfer",
        "银白": "Silber-Weiß",
        "银色": "Silber",
        "黄色": "Gelb",
        "黑猫": "Schwarze Katze",
        "黑白": "Schwarz-Weiß",
        "黑色": "Schwarz"
    ]
    private static let petAppearanceZhToEn: [String: String] = [
        "三色": "Tricolor",
        "乳白": "Cream white",
        "其他": "Other",
        "多色": "Multi",
        "奶白": "Milky white",
        "异瞳": "Odd-eyed",
        "杏色": "Apricot",
        "栗色": "Chestnut",
        "棕白": "Brown & white",
        "棕色": "Brown",
        "榛色": "Hazel",
        "橘猫": "Orange tabby",
        "橙色": "Orange",
        "灰白": "Gray & white",
        "灰色": "Gray",
        "玳瑁": "Tortie",
        "白猫": "White cat",
        "白色": "White",
        "白面": "White face",
        "米色": "Beige",
        "红柴": "Red Shiba",
        "红白": "Red & white",
        "红色": "Red",
        "纯白": "Pure white",
        "纯黑": "Jet black",
        "绿色": "Green",
        "花斑": "Spotted",
        "蓝白": "Blue & white",
        "蓝色": "Blue",
        "虎斑": "Tabby",
        "金色": "Gold",
        "铜色": "Copper",
        "银白": "Silver & white",
        "银色": "Silver",
        "黄化": "Lutino",
        "黄色": "Yellow",
        "黑棕": "Black-brown",
        "黑猫": "Black cat",
        "黑白": "Black & white",
        "黑色": "Black",
        "丁香色": "Lilac",
        "冰蓝色": "Ice blue",
        "奶油色": "Cream",
        "奶白色": "Off-white",
        "柠檬白": "Lemon white",
        "棕虎斑": "Brown tabby",
        "棕豹纹": "Brown spotted",
        "椒盐色": "Salt & pepper",
        "橙黄色": "Orange-yellow",
        "沙棕色": "Sand brown",
        "浅灰色": "Light gray",
        "浅蓝色": "Light blue",
        "浅银色": "Light silver",
        "深棕色": "Dark brown",
        "深灰色": "Dark gray",
        "深金色": "Dark gold",
        "灰棕色": "Gray-brown",
        "玳瑁色": "Tortoiseshell",
        "珍珠色": "Pearl",
        "琥珀色": "Amber",
        "盐椒色": "Salt & pepper",
        "红棕色": "Red-brown",
        "红虎斑": "Red tabby",
        "红金色": "Red gold",
        "翠绿色": "Emerald",
        "肉桂色": "Cinnamon",
        "花斑色": "Spotted coat",
        "蓝棕色": "Blue-brown",
        "蓝灰色": "Blue-gray",
        "蓝绿色": "Teal",
        "蓝豹纹": "Blue spotted",
        "虎斑色": "Tabby",
        "貂色白": "Sable & white",
        "貂褐色": "Sable brown",
        "重点色": "Point",
        "金棕色": "Golden brown",
        "金渐层": "Golden shaded (chinchilla)",
        "金白色": "Gold & white",
        "金黄色": "Golden yellow",
        "铜绿色": "Bronze green",
        "银渐层": "Silver shaded",
        "银虎斑": "Silver tabby",
        "银豹纹": "Silver spotted",
        "黄褐色": "Tan",
        "黑棕色": "Dark brown-black",
        "黑红色": "Black-red",
        "黑芝麻": "Black sesame",
        "黑银色": "Black silver",
        "丁香配白": "Lilac & white",
        "奶牛白底": "Cow (white base)",
        "奶牛黑斑": "Cow (black spots)",
        "巧克力棕": "Chocolate brown",
        "巧克力色": "Chocolate",
        "桃色肤色": "Peach skin",
        "棕虎斑白": "Brown tabby & white",
        "浅奶油金": "Light cream gold",
        "白底肝斑": "White + liver spots",
        "白底黑斑": "White + black spots",
        "白腹深刺": "White belly, dark quills",
        "红宝石色": "Ruby",
        "蓝宝石色": "Sapphire blue",
        "蓝色肤色": "Blue skin tone",
        "蓝重点色": "Blue point",
        "虎纹肤色": "Tiger skin tone",
        "金底渐层": "Golden shaded",
        "银底渐层": "Silver shaded",
        "雪色豹纹": "Snow spotted",
        "黑棕三色": "Black-brown tricolor",
        "黑白三色": "Black-white tricolor",
        "黑色肤色": "Black skin tone",
        "丁香重点色": "Lilac point",
        "巧克力配白": "Chocolate & white",
        "布伦海姆色": "Blenheim",
        "海豹重点色": "Seal point",
        "蓝重点配白": "Blue point & white",
        "钢蓝背棕腿": "Steel blue back, brown legs",
        "黑棕白三色": "Black-brown-white",
        "奶油（裏白）": "Cream (white under)",
        "奶牛（黑白）": "Cow (B/W)",
        "巧克力重点色": "Chocolate point",
        "橙色脸颊灰色": "Orange-cheek gray",
        "海豹重点配白": "Seal point & white",
        "狸花（虎斑）": "Mackerel tabby",
        "白色（冬季）": "Winter white",
        "粉色（白化）": "Pink (albino)",
        "红色（白化）": "Red (albino)",
        "蓝色（灰蓝）": "Blue (slate)",
        "黑棕（鞍形）": "Black saddle",
        "三花（黑白橘）": "Calico (B/W/O)"
    ]
    // MARK: - Pet cutout pro tip
    var petProTipTitle: String { tr(zh: "解锁 3D 悬浮卡片", en: "Unlock the 3D floaty card", de: "3D-Schwebekarte freischalten") }
    var petProTipStep1Prefix: String { tr(zh: "在系统相册中", en: "In Photos, ", de: "In Fotos: ") }
    var petProTipStep1Highlight: String { tr(zh: "长按宠物主体", en: "long-press your pet", de: "Haustier lange halten") }
    var petProTipStep2Prefix: String { tr(zh: "点击", en: "Tap ", de: "Dann ") }
    var petProTipStep2Highlight: String { tr(zh: "拷贝", en: "Copy Subject", de: "Motiv kopieren") }
    var petProTipStep2Suffix: String { tr(zh: "保存到剪贴板", en: " to stash it on the clipboard", de: " antippen") }
    var petProTipStep3Prefix: String { tr(zh: "返回 Ohana，点击上方", en: "Back in Ohana, tap ", de: "Zurück in Ohana: ") }
    var petProTipStep3Highlight: String { tr(zh: "粘贴按钮", en: "Paste", de: "Einfügen") }
    // MARK: - Home / Overview & GO dashboard
    var homeDailyCoconutTitle: String { tr(zh: "每日登录奖励 +1🥥", en: "Daily login +1 🥥", de: "Täglicher Login +1 🥥") }
    var homeDailyCoconutSub: String { tr(zh: "坚持照顾家人，收获更多椰子", en: "Keep caring for your crew. More coconuts await!", de: "Weiter kümmern. Mehr Kokosnüsse warten!") }
    var homeClaimCoconuts: String { tr(zh: "收下", en: "Claim", de: "Abholen") }
    func homeFamilyCareTitle(petName: String) -> String {
        tr(zh: "今日 · 谁在照顾 \(petName)", en: "Today · Who's on duty for \(petName)", de: "Heute · Wer kümmert sich um \(petName)?", es: "Hoy · ¿quién cuida de \(petName)?", pt: "Hoje · quem cuida de \(petName)?", fr: "Aujourd'hui · qui veille sur \(petName) ?")
    }

    var homeRecordMoment: String { tr(zh: "记录时刻", en: "Log a moment", de: "Moment festhalten") }
    var homeConfirmCheckIn: String { tr(zh: "确定打卡", en: "Check in anyway", de: "Trotzdem eintragen") }
    var homeMemoryShardsTitle: String { tr(zh: "记忆碎片", en: "Memory sparkles", de: "Erinnerungsfunken") }
    var homeMemoryShardsBody: String {
        tr(
            zh: "继续记录喂食、散步或体重数据\n美好时刻会在这里浮现 ✨",
            en: "Keep logging feeds, walks, or weights.\nLil' highlights will bubble up here ✨",
            de: "Füttern, Spaziergänge oder Gewicht weiter loggen.\nKleine Highlights tauchen hier auf ✨",
            es: "Sigue registrando comidas, paseos o peso.\nLos momentitos lindos aparecerán aquí ✨",
            pt: "Continue registrando comida, passeios ou peso.\nMomentinhos fofos aparecem aqui ✨",
            fr: "Continue à noter repas, promenades ou poids.\nLes petits moments doux apparaîtront ici ✨"
        )
    }

    var homeMemoryCoconutTitle: String { tr(zh: "珍惜记忆 +1🥥", en: "Cherished memory +1 🥥", de: "Lieblingserinnerung +1 🥥") }
    var homeDailyCheckInRewardTitle: String { tr(zh: "每日打卡奖励", en: "Daily check-in reward", de: "Tägliche Check-in-Belohnung") }
    var homeDailyLoginRewardTitle: String { tr(zh: "每日登录奖励", en: "Daily login reward", de: "Tägliche Login-Belohnung") }
    var homeIslandQuestRewardTitle: String { tr(zh: "岛屿委托奖励", en: "Island quest reward", de: "Inselauftrag-Belohnung") }
    var homeQuickCheckInNote: String { tr(zh: "快捷打卡", en: "Quick log", de: "Schnelllog") }
    func homePlantWaterEventTitle(plantName: String) -> String {
        tr(zh: "💧 给 \(plantName) 浇水", en: "💧 Water \(plantName)", de: "💧 \(plantName) gießen", es: "💧 Regar \(plantName)", pt: "💧 Regar \(plantName)", fr: "💧 Arroser \(plantName)")
    }

    func homePlantFertilizeEventTitle(plantName: String) -> String {
        tr(zh: "🌿 给 \(plantName) 施肥", en: "🌿 Fertilize \(plantName)", de: "🌿 \(plantName) düngen", es: "🌿 Abonar \(plantName)", pt: "🌿 Adubar \(plantName)", fr: "🌿 Fertiliser \(plantName)")
    }

    func homeToastWalkStarted(_ petName: String) -> String {
        tr(zh: "开始遛 \(petName)！", en: "Walking \(petName)!", de: "\(petName) geht los!", es: "¡Paseo con \(petName)!", pt: "Passeio com \(petName)!", fr: "Promenade avec \(petName) !")
    }

    func homeToastPotty(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 噗噗打卡 +\(points)🥥", en: "\(petName) poop logged +\(points) 🥥", de: "\(petName) Häufchen +\(points) 🥥", es: "\(petName) popó registrado +\(points) 🥥", pt: "\(petName) cocô registrado +\(points) 🥥", fr: "\(petName) caca noté +\(points) 🥥", ja: "\(petName) ぷっぷ記録 +\(points) 🥥", ko: "\(petName) 뿌뿌 기록 +\(points) 🥥", it: "\(petName) popò registrata +\(points) 🥥")
    }

    func homeToastLitter(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 铲砂完成 +\(points)🥥", en: "\(petName) litter scooped +\(points) 🥥", de: "\(petName) Klo sauber +\(points) 🥥", es: "\(petName) arena limpia +\(points) 🥥", pt: "\(petName) areia limpa +\(points) 🥥", fr: "\(petName) litière propre +\(points) 🥥")
    }

    func homeToastManualFeed(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 手动喂食 +\(points)🥥", en: "\(petName) manual feed +\(points) 🥥", de: "\(petName) Futter +\(points) 🥥", es: "\(petName) comida manual +\(points) 🥥", pt: "\(petName) comida manual +\(points) 🥥", fr: "\(petName) repas manuel +\(points) 🥥")
    }

    func homeToastWater(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 喂水打卡 +\(points)🥥", en: "\(petName) water log +\(points) 🥥", de: "\(petName) Wasser +\(points) 🥥", es: "\(petName) agua registrada +\(points) 🥥", pt: "\(petName) água registrada +\(points) 🥥", fr: "\(petName) eau notée +\(points) 🥥")
    }

    func homeToastPlay(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 逗玩打卡 +\(points)🥥", en: "\(petName) playtime +\(points) 🥥", de: "\(petName) Spielzeit +\(points) 🥥", es: "\(petName) juego +\(points) 🥥", pt: "\(petName) brincadeira +\(points) 🥥", fr: "\(petName) jeu +\(points) 🥥")
    }

    func homePlayQuestTitle(_ petName: String) -> String {
        tr(zh: "\(petName) 逗玩打卡", en: "\(petName) · playtime", de: "\(petName) · Spielzeit", es: "\(petName) · juego", pt: "\(petName) · brincar", fr: "\(petName) · jeu")
    }

    func homeToastPlannedFeed(_ petName: String, points: Int) -> String {
        tr(zh: "\(petName) 计划喂食打卡 +\(points)🥥", en: "\(petName) planned meal +\(points) 🥥", de: "\(petName) geplante Mahlzeit +\(points) 🥥", es: "\(petName) comida planificada +\(points) 🥥", pt: "\(petName) refeição planejada +\(points) 🥥", fr: "\(petName) repas prévu +\(points) 🥥")
    }

    func homeToastHealthVaccine(_ petName: String) -> String {
        tr(zh: "\(petName) 疫苗记录 ✅", en: "\(petName) vaccine logged ✅", de: "\(petName) Impfung gespeichert ✅", es: "\(petName) vacuna registrada ✅", pt: "\(petName) vacina registrada ✅", fr: "\(petName) vaccin noté ✅")
    }

    func homeToastHealthDeworm(_ petName: String) -> String {
        tr(zh: "\(petName) 驱虫记录 ✅", en: "\(petName) dewormer logged ✅", de: "\(petName) Entwurmung gespeichert ✅", es: "\(petName) desparasitación registrada ✅", pt: "\(petName) vermífugo registrado ✅", fr: "\(petName) vermifuge noté ✅")
    }

    func homeToastHealthVisit(_ petName: String) -> String {
        tr(zh: "\(petName) 就诊记录 ✅", en: "\(petName) vet visit logged ✅", de: "\(petName) Tierarztbesuch gespeichert ✅", es: "\(petName) visita al vet registrada ✅", pt: "\(petName) visita ao vet registrada ✅", fr: "\(petName) visite véto notée ✅")
    }

    var homeWalkNoneToday: String { tr(zh: "今日未遛", en: "No walks yet", de: "Noch keine Runde") }
    func homeWalkTodayBadge(count: Int, dist: String) -> String {
        tr(zh: "今日\(count)次·\(dist)", en: "\(count)× today · \(dist)", de: "\(count)× heute · \(dist)", es: "\(count)× hoy · \(dist)", pt: "\(count)× hoje · \(dist)", fr: "\(count)× aujourd'hui · \(dist)")
    }

    func homeFeedMealsProgress(current: Int, goal: Int) -> String {
        tr(zh: "\(current)/\(goal)餐", en: "\(current)/\(goal) meals", de: "\(current)/\(goal) Mahlzeiten", es: "\(current)/\(goal) comidas", pt: "\(current)/\(goal) refeições", fr: "\(current)/\(goal) repas")
    }

    func homeTimesToday(_ n: Int) -> String {
        tr(zh: "今日\(n)次", en: "\(n)× today", de: "\(n)× heute", es: "\(n)× hoy", pt: "\(n)× hoje", fr: "\(n)× aujourd'hui")
    }

    func homeExpenseMonthCNY(_ amount: Int) -> String {
        let formatted = AppCurrency.format(Double(amount), fractionDigits: 0)
        return tr(zh: "本月\(formatted)", en: "\(formatted) this month", de: "\(formatted) diesen Monat", es: "\(formatted) este mes", pt: "\(formatted) este mês", fr: "\(formatted) ce mois-ci")
    }

    func homeLastWeightKg(_ kg: Double) -> String {
        let formatted = AppMeasurementSystem.formatWeightKilograms(kg)
        return tr(zh: "上次\(formatted)", en: "Last \(formatted)", de: "Zuletzt \(formatted)", es: "Último \(formatted)", pt: "Último \(formatted)", fr: "Dernier \(formatted)")
    }

    var homeAntiDupFeedTitle: String { tr(zh: "重复喂食提醒", en: "Feed again?", de: "Noch einmal füttern?") }
    func homeAntiDupFeedMessage(executor: String, minutes: Int, petName: String) -> String {
        tr(zh: "\(executor) 在 \(minutes) 分钟前刚喂过 \(petName) ，确定要再喂一次吗？", en: "\(executor) fed \(petName) \(minutes) min ago. Log another meal?", de: "\(executor) hat \(petName) vor \(minutes) Min. gefüttert. Noch eine Mahlzeit?", es: "\(executor) alimentó a \(petName) hace \(minutes) min. ¿Registrar otra comida?", pt: "\(executor) alimentou \(petName) há \(minutes) min. Registrar outra refeição?", fr: "\(executor) a nourri \(petName) il y a \(minutes) min. Noter un autre repas ?")
    }

    var homeAntiDupWaterTitle: String { tr(zh: "重复喂水提醒", en: "Water again?", de: "Noch einmal Wasser?") }
    func homeAntiDupWaterMessage(executor: String, minutes: Int, petName: String) -> String {
        tr(zh: "\(executor) 在 \(minutes) 分钟前刚喂过 \(petName) 水，确定要再记录一次吗？", en: "\(executor) refreshed \(petName)'s water \(minutes) min ago. Log again?", de: "\(executor) hat \(petName)s Wasser vor \(minutes) Min. erneuert. Noch einmal?", es: "\(executor) refrescó el agua de \(petName) hace \(minutes) min. ¿Registrar otra vez?", pt: "\(executor) trocou a água de \(petName) há \(minutes) min. Registrar de novo?", fr: "\(executor) a rafraîchi l'eau de \(petName) il y a \(minutes) min. Noter encore ?")
    }

    var homeQAFeed: String { tr(zh: "喂食", en: "Feed", de: "Füttern") }
    var homeQAWater: String { tr(zh: "喂水", en: "Water", de: "Wasser") }
    var homeQAWaterChange: String { tr(zh: "换水", en: "Change water", de: "Wasser wechseln") }
    var homeQAFilterClean: String { tr(zh: "清滤材", en: "Filter clean", de: "Filter reinigen") }
    var homeQAWalk: String { tr(zh: "遛狗", en: "Walk", de: "Gassi") }
    var homeQAPotty: String { tr(zh: "噗噗", en: "Poop", de: "Häufchen") }
    var homeQALitter: String { tr(zh: "铲砂", en: "Scoop", de: "Schaufeln") }
    var homeQAGroom: String { tr(zh: "护理", en: "Groom", de: "Pflege") }
    var homeQAWeight: String { tr(zh: "体重", en: "Weight", de: "Gewicht") }
    var homeQASport: String { tr(zh: "运动", en: "Workout", de: "Workout") }
    var homeQAMeds: String { tr(zh: "吃药", en: "Meds", de: "Medis") }
    var homeQANote: String { tr(zh: "记录", en: "Note", de: "Notiz") }
    var homeQAPlay: String { tr(zh: "陪玩", en: "Play", de: "Spielen") }
    var homeQACageClean: String { tr(zh: "清鸟笼", en: "Clean cage", de: "Käfig reinigen") }
    var homeQAFreeFlight: String { tr(zh: "放飞", en: "Free flight", de: "Freiflug") }
    var goSectionIslandQuests: String { tr(zh: "🏝️ 今日委托", en: "🏝️ Island quests", de: "🏝️ Inselaufträge") }
    var goSectionIslandQuestsLabel: String { tr(zh: "ISLAND QUESTS", en: "ISLAND QUESTS", de: "INSELAUFTRÄGE") }
    var goSectionQuickActions: String { tr(zh: "⚡ 快捷打卡", en: "⚡ Quick check-in", de: "⚡ Schnell-Check-in") }
    var goSectionQuickActionsLabel: String { tr(zh: "QUICK ACTIONS", en: "QUICK ACTIONS", de: "SCHNELLAKTIONEN") }
    var goFeatureHubTitle: String { tr(zh: "🗺️ 岛屿功能", en: "🗺️ Island hub", de: "🗺️ Insel-Hub") }
    var goStatsTitle: String { tr(zh: "📊 岛屿统计", en: "📊 Island stats", de: "📊 Inselwerte") }
    var goAddChip: String { tr(zh: "添加", en: "Add", de: "Hinzufügen") }
    func goLifeTreeTitle(levelName: String) -> String {
        tr(zh: "生命之树 · \(levelName)", en: "Life Tree · \(levelName)", de: "Lebensbaum · \(levelName)", es: "Árbol de vida · \(levelName)", pt: "Árvore da vida · \(levelName)", fr: "Arbre de vie · \(levelName)")
    }

    func goTreeNeedEnergy(_ n: Int) -> String {
        tr(zh: "还差 \(n) 🥥 能量升级", en: "\(n) more 🥥 to level up", de: "Noch \(n) 🥥 bis zum Level-up", es: "Faltan \(n) 🥥 para subir", pt: "Faltam \(n) 🥥 para subir", fr: "Encore \(n) 🥥 pour monter")
    }

    var goTreeMaxLevel: String { tr(zh: "已达最高等级 ✨", en: "Max level reached ✨", de: "Max-Level erreicht ✨") }
    var goInjectEnergy: String { tr(zh: "⚡ 注入能量", en: "⚡ Send energy", de: "⚡ Energie senden") }
    var goToOasis: String { tr(zh: "前往绿洲", en: "Open Oasis", de: "Oase öffnen") }
    var goFeatPatrol: String { tr(zh: "巡岛", en: "Patrol", de: "Runde") }
    var goFeatPatrolSub: String { tr(zh: "遛宠", en: "Walkies", de: "Gassi") }
    var goFeatHealth: String { tr(zh: "健康", en: "Health", de: "Gesundheit") }
    var goFeatHealthSub: String { tr(zh: "医疗档案", en: "Records", de: "Akten") }
    var goFeatCalendar: String { tr(zh: "日历", en: "Calendar", de: "Kalender") }
    var goFeatCalendarSub: String { tr(zh: "日程安排", en: "Schedule", de: "Plan") }
    var goFeatExpense: String { tr(zh: "花费", en: "Spend", de: "Ausgaben") }
    var goFeatExpenseSub: String { tr(zh: "支出统计", en: "Totals", de: "Summen") }
    var goFeatWeight: String { tr(zh: "体重", en: "Weight", de: "Gewicht") }
    var goFeatWeightSub: String { tr(zh: "成长曲线", en: "Curves", de: "Kurven") }
    var goFeatOasis: String { tr(zh: "绿洲", en: "Oasis", de: "Oase") }
    var goFeatOasisSub: String { tr(zh: "奖励中心", en: "Rewards", de: "Belohnungen") }
    var goAddPetLocked: String { tr(zh: "添加宠物", en: "Add a pet", de: "Haustier hinzufügen") }
    var goEmptyPetsTitle: String { tr(zh: "还没有宠物", en: "No pets yet", de: "Noch keine Haustiere") }
    var goEmptyPetsSub: String { tr(zh: "添加你的第一只宠物\n开启家庭数据统计", en: "Add your first pet\nto unlock island stats", de: "Erstes Haustier hinzufügen\nund Inselwerte öffnen") }
    var goEmptyPetsCTA: String { tr(zh: "立即添加 →", en: "Add now →", de: "Jetzt hinzufügen →") }
    var goWeekWalks: String { tr(zh: "本周散步", en: "Walks this week", de: "Runden diese Woche") }
    var goThisMonthExpense: String { tr(zh: "本月花费", en: "Spending (month)", de: "Ausgaben (Monat)") }
    func goPetFoodPantry(_ name: String) -> String {
        tr(zh: "\(name)粮仓", en: "\(name)'s pantry", de: "\(name)s Vorrat", es: "Despensa de \(name)", pt: "Despensa de \(name)", fr: "Réserve de \(name)")
    }

    // MARK: - Care / hygiene / potty (UI labels; persisted logs keep zh `rawValue`)
    func careTypeUILabel(_ type: CareType) -> String {
        switch type {
        case .feeding: tr(zh: "喂食", en: "Feeding", de: "Füttern")
        case .watering: tr(zh: "喂水", en: "Water", de: "Wasser")
        case .litter: tr(zh: "铲砂", en: "Scoop litter", de: "Klo reinigen")
        case .waterChange: tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean: tr(zh: "清滤材", en: "Filter cleaning", de: "Filter reinigen")
        case .cageCleaning: tr(zh: "清鸟笼", en: "Cage cleaning", de: "Käfig reinigen")
        case .freeFlight: tr(zh: "放飞", en: "Free flight", de: "Freiflug")
        case .misting: tr(zh: "喷水", en: "Misting", de: "Besprühen")
        case .substrateChange: tr(zh: "换垫材", en: "Substrate change", de: "Substratwechsel")
        case .play: tr(zh: "陪玩", en: "Playtime", de: "Spielen")
        }
    }

    func hygieneTypeUILabel(_ type: HygieneType) -> String {
        switch type {
        case .teeth: tr(zh: "刷牙", en: "Teeth", de: "Zähne")
        case .nails: tr(zh: "剪甲", en: "Nails", de: "Krallen")
        case .ears: tr(zh: "耳朵", en: "Ears", de: "Ohren")
        case .brushing: tr(zh: "梳毛", en: "Brushing", de: "Bürsten")
        case .bath: tr(zh: "洗澡", en: "Bath", de: "Bad")
        }
    }

    func pottyTypeUILabel(_ type: PottyType) -> String {
        type.localizedLabel(self)
    }

    func homeToastPottyLine(petName: String, type: PottyType, points: Int) -> String {
        let label = pottyTypeUILabel(type)
        return tr(
            zh: "\(petName) \(type.emoji)\(label) +\(points)🥥",
            en: "\(petName) \(type.emoji) \(label) +\(points) 🥥",
            de: "\(petName) \(type.emoji) \(label) +\(points) 🥥",
            es: "\(petName) \(type.emoji) \(label) +\(points) 🥥",
            pt: "\(petName) \(type.emoji) \(label) +\(points) 🥥",
            fr: "\(petName) \(type.emoji) \(label) +\(points) 🥥"
        )
    }

    func homeToastGroomLine(petName: String, type: HygieneType, points: Int) -> String {
        let label = hygieneTypeUILabel(type)
        return tr(zh: "\(petName) \(label)打卡 +\(points)🥥", en: "\(petName) · \(label) +\(points) 🥥", de: "\(petName) · \(label) +\(points) 🥥", es: "\(petName) · \(label) +\(points) 🥥", pt: "\(petName) · \(label) +\(points) 🥥", fr: "\(petName) · \(label) +\(points) 🥥")
    }

    // MARK: - Pet ID card (Ark crew)
    var petCardDetail: String { tr(zh: "详情", en: "Details", de: "Details") }
    var petCardDaysTogetherCaption: String { tr(zh: "相伴天数", en: "Days together", de: "Tage zusammen") }
    func petCardStreak(_ days: Int) -> String {
        tr(zh: "🔥 \(days)天连续", en: "🔥 \(days)-day streak", de: "🔥 \(days)-Tage-Serie", es: "🔥 racha de \(days) días", pt: "🔥 sequência de \(days) dias", fr: "🔥 série de \(days) jours")
    }

    var petCardDayUnit: String { tr(zh: "天", en: "d", de: "T") }
    var petCardTogetherPrefix: String { tr(zh: "一起度过了", en: "Together for", de: "Zusammen seit") }
    var petCardRainbowTitle: String { tr(zh: "化作星星，守护着你", en: "Shining as stars, watching over you", de: "Als Stern bei dir") }
    func petCardRainbowTogether(days: Int, yearsApart: Int) -> String {
        if yearsApart > 0 {
            return tr(
                zh: "相伴 \(days) 天 · 离开 \(yearsApart) 年",
                en: "Together \(days) days · gone \(yearsApart) yr\(yearsApart == 1 ? "" : "s")",
                de: "\(days) Tage zusammen · seit \(yearsApart) J. fort",
                es: "\(days) días juntos · se fue hace \(yearsApart) año\(yearsApart == 1 ? "" : "s")",
                pt: "\(days) dias juntos · partiu há \(yearsApart) ano\(yearsApart == 1 ? "" : "s")",
                fr: "\(days) jours ensemble · parti il y a \(yearsApart) an\(yearsApart == 1 ? "" : "s")"
            )
        }
        return tr(zh: "相伴 \(days) 天", en: "Together \(days) days", de: "\(days) Tage zusammen", es: "\(days) días juntos", pt: "\(days) dias juntos", fr: "\(days) jours ensemble")
    }

    var petCardWalkPatrolling: String { tr(zh: "巡岛中", en: "On patrol", de: "Auf Runde") }
    var petCardWalkDistanceLabel: String { tr(zh: "巡岛距离", en: "Patrol distance", de: "Rundendistanz") }
    var petCardWalkPoopLabel: String { tr(zh: "噗噗站点", en: "Poop stops", de: "Häufchen-Stopps") }
    var petCardPause: String { tr(zh: "暂停", en: "Pause", de: "Pause") }
    var petCardResume: String { tr(zh: "继续", en: "Resume", de: "Weiter") }
    var petCardEndWalk: String { tr(zh: "结束", en: "End", de: "Beenden") }
    func petCardVaccineCountdown(daysUntilDue: Int) -> String {
        if daysUntilDue < 0 {
            let overdue = abs(daysUntilDue)
            if overdue >= 30 { return tr(zh: "逾期\(overdue / 30)月", en: "\(overdue / 30) mo overdue", de: "\(overdue / 30) Mon. überfällig", es: "\(overdue / 30) meses tarde", pt: "\(overdue / 30) meses atrasado", fr: "\(overdue / 30) mois de retard", ja: "\(overdue / 30)か月遅れ", ko: "\(overdue / 30)개월 지남", it: "\(overdue / 30) mesi in ritardo") }
            return tr(zh: "逾期\(overdue)天", en: "\(overdue)d overdue", de: "\(overdue) T. überfällig", es: "\(overdue)d tarde", pt: "\(overdue)d atrasado", fr: "\(overdue) j de retard", ja: "\(overdue)日遅れ", ko: "\(overdue)일 지남", it: "\(overdue) g in ritardo")
        }
        if daysUntilDue == 0 { return today }
        if daysUntilDue < 30 { return tr(zh: "\(daysUntilDue)天后", en: "in \(daysUntilDue)d", de: "in \(daysUntilDue) T.", es: "en \(daysUntilDue)d", pt: "em \(daysUntilDue)d", fr: "dans \(daysUntilDue) j", ja: "\(daysUntilDue)日後", ko: "\(daysUntilDue)일 후", it: "tra \(daysUntilDue) g") }
        if daysUntilDue < 365 { return tr(zh: "\(daysUntilDue / 30)个月后", en: "in \(daysUntilDue / 30) mo", de: "in \(daysUntilDue / 30) Mon.", es: "en \(daysUntilDue / 30) meses", pt: "em \(daysUntilDue / 30) meses", fr: "dans \(daysUntilDue / 30) mois", ja: "\(daysUntilDue / 30)か月後", ko: "\(daysUntilDue / 30)개월 후", it: "tra \(daysUntilDue / 30) mesi") }
        let y = daysUntilDue / 365
        return tr(zh: "\(y)年后", en: "in \(y) yr\(y == 1 ? "" : "s")", de: "in \(y) J.", es: "en \(y) año\(y == 1 ? "" : "s")", pt: "em \(y) ano\(y == 1 ? "" : "s")", fr: "dans \(y) an\(y == 1 ? "" : "s")", ja: "\(y)年後", ko: "\(y)년 후", it: "tra \(y) ann\(y == 1 ? "o" : "i")")
    }

    func petCardHumanEquivBody(humanAge: Int, isFemale: Bool) -> String {
        switch humanAge {
        case 0 ..< 3:
            tr(zh: "👶 相当于人类宝宝 \(humanAge) 岁", en: "👶 ≈ human baby \(humanAge)", de: "👶 ≈ Menschenbaby \(humanAge)", es: "👶 ≈ bebé humano de \(humanAge)", pt: "👶 ≈ bebê humano de \(humanAge)", fr: "👶 ≈ bébé humain de \(humanAge)")
        case 3 ..< 8:
            tr(
                zh: "🎠 相当于 \(humanAge) 岁的\(isFemale ? "小公主" : "小男孩")",
                en: "🎠 ≈ a \(humanAge)-yr-old \(isFemale ? "little princess" : "little dude")",
                de: "🎠 ≈ \(humanAge) Jahre, \(isFemale ? "kleine Prinzessin" : "kleiner Wirbel")",
                es: "🎠 ≈ \(humanAge) años, \(isFemale ? "mini princesa" : "mini aventurero")",
                pt: "🎠 ≈ \(humanAge) anos, \(isFemale ? "mini princesa" : "mini aventureiro")",
                fr: "🎠 ≈ \(humanAge) ans, \(isFemale ? "mini princesse" : "mini aventurier")"
            )
        case 8 ..< 13:
            tr(
                zh: "🎒 相当于 \(humanAge) 岁的\(isFemale ? "萌妹" : "小大人")",
                en: "🎒 ≈ \(humanAge) yrs \(isFemale ? "cool kid sis" : "cool kid bro")",
                de: "🎒 ≈ \(humanAge) Jahre, \(isFemale ? "cooles Mädchen" : "cooler Typ")",
                es: "🎒 ≈ \(humanAge) años, \(isFemale ? "chica con chispa" : "peque adulto")",
                pt: "🎒 ≈ \(humanAge) anos, \(isFemale ? "garota esperta" : "mini adulto")",
                fr: "🎒 ≈ \(humanAge) ans, \(isFemale ? "fillette pétillante" : "petit grand")"
            )
        case 13 ..< 18:
            tr(
                zh: "🌱 相当于 \(humanAge) 岁的\(isFemale ? "少女" : "少男")",
                en: "🌱 ≈ \(humanAge) yrs \(isFemale ? "teen queen" : "teen pal")",
                de: "🌱 ≈ \(humanAge) Jahre Teenie-Energie",
                es: "🌱 ≈ \(humanAge) años de energía teen",
                pt: "🌱 ≈ \(humanAge) anos de energia teen",
                fr: "🌱 ≈ \(humanAge) ans d'énergie ado"
            )
        case 18 ..< 25:
            tr(
                zh: "🔥 相当于 \(humanAge) 岁的\(isFemale ? "活力少女" : "鲜肉小哥")",
                en: "🔥 ≈ \(humanAge) yrs \(isFemale ? "sparkly young adult" : "bright young adult")",
                de: "🔥 ≈ \(humanAge) Jahre, jung und hellwach",
                es: "🔥 ≈ \(humanAge) años, joven con brillo",
                pt: "🔥 ≈ \(humanAge) anos, jovem cheio de brilho",
                fr: "🔥 ≈ \(humanAge) ans, jeune et lumineux"
            )
        case 25 ..< 35:
            tr(
                zh: "💼 相当于 \(humanAge) 岁的\(isFemale ? "独立美女" : "稳重帅哥")",
                en: "💼 ≈ \(humanAge) yrs \(isFemale ? "grown-up glow" : "steady glow-up")",
                de: "💼 ≈ \(humanAge) Jahre, erwachsen mit Glanz",
                es: "💼 ≈ \(humanAge) años, adulto con flow",
                pt: "💼 ≈ \(humanAge) anos, adulto com charme",
                fr: "💼 ≈ \(humanAge) ans, adulte avec style"
            )
        case 35 ..< 50:
            tr(
                zh: "🌟 相当于 \(humanAge) 岁的\(isFemale ? "优雅女士" : "成熟大叔")",
                en: "🌟 ≈ \(humanAge) yrs \(isFemale ? "elegant vibes" : "seasoned vibes")",
                de: "🌟 ≈ \(humanAge) Jahre, souverän und warm",
                es: "🌟 ≈ \(humanAge) años, vibra elegante",
                pt: "🌟 ≈ \(humanAge) anos, vibe elegante",
                fr: "🌟 ≈ \(humanAge) ans, vibe élégante"
            )
        case 50 ..< 65:
            tr(
                zh: "👑 相当于 \(humanAge) 岁的\(isFemale ? "典雅长辈" : "稳重前辈")",
                en: "👑 ≈ \(humanAge) yrs \(isFemale ? "wise matriarch" : "wise patriarch")",
                de: "👑 ≈ \(humanAge) Jahre, weise und königlich",
                es: "👑 ≈ \(humanAge) años, sabio y de la realeza",
                pt: "👑 ≈ \(humanAge) anos, sábio e majestoso",
                fr: "👑 ≈ \(humanAge) ans, sage et royal"
            )
        default:
            tr(zh: "🧓 相当于人类 \(humanAge) 岁的长者", en: "🧓 ≈ \(humanAge) human yrs wise & warm", de: "🧓 ≈ \(humanAge) Menschenjahre, weise und warm", es: "🧓 ≈ \(humanAge) años humanos, sabio y cálido", pt: "🧓 ≈ \(humanAge) anos humanos, sábio e quentinho", fr: "🧓 ≈ \(humanAge) ans humains, sage et doux")
        }
    }
}
