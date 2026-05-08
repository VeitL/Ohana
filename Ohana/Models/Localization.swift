//
//  Localization.swift
//  Ohana
//
//  多语言支持：语言注册表 + fallback 文案解析，"ohana" 不翻译
//

import Foundation

struct L10n {
    let lang: String

    init(_ lang: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh") {
        self.lang = AppLanguage.normalize(lang)
    }

    var isEn: Bool { lang == "en" }
    var isDe: Bool { lang == "de" }

    func text(_ value: AppLocalizedText) -> String {
        value.resolve(lang)
    }

    func tr(
        zh: String,
        en: String,
        de: String? = nil,
        extras: [String: String] = [:]
    ) -> String {
        AppLocalizedText(zh: zh, en: en, de: de, extras: extras).resolve(lang)
    }

    func tr(
        _ translations: [String: String],
        fallbackCode: String = AppLanguage.fallbackCode
    ) -> String {
        AppLocalizedText(translations: translations, fallbackCode: fallbackCode).resolve(lang)
    }

    // MARK: - Dock / Tab
    var tabHome: String { tr(zh: "首页", en: "Home", de: "Start") }
    var tabPlant: String { tr(zh: "植物", en: "Plants", de: "Pflanzen") }
    var tabCalendar: String { tr(zh: "日历", en: "Calendar", de: "Kalender") }
    var tabCrew: String { tr(zh: "图鉴", en: "Crew", de: "Team") }
    var tabOasis: String { tr(zh: "绿洲", en: "Oasis", de: "Oase") }

    // MARK: - Global Header
    func greeting(_ text: String) -> String { text } // greeting 已由逻辑生成
    var ohanaCrew: String { tr(zh: "Ohana 图鉴", en: "Ohana Crew", de: "Ohana Team") }

    // MARK: - Greeting hints
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
    var edit: String { isEn ? "Edit" : "编辑" }
    var calendar: String { isEn ? "Calendar" : "日历" }
    var sitterCard: String { isEn ? "Sitter Card" : "寄养卡" }
    var immuneHealth: String { isEn ? "Immune Health" : "免疫健康" }
    var vaccineBook: String { isEn ? "Vaccine Book" : "疫苗本" }
    var noRecords: String { isEn ? "No records" : "暂无记录" }
    var expired: String { isEn ? "Expired" : "已过期" }
    func validUntil(_ date: String) -> String { isEn ? "Valid until \(date)" : "有效至 \(date)" }
    var weight: String { isEn ? "Weight" : "体重" }
    var expense: String { isEn ? "Expense" : "花费" }
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
        tr(zh: "可以继续提交给 \(name)", en: "You can submit it to \(name)", de: "Du kannst sie bei \(name) einreichen")
    }
    var quickExpenseInsuranceCompany: String { tr(zh: "保险公司", en: "insurer", de: "Versicherung") }
    var quickExpenseApplyClaim: String { tr(zh: "已记录 · 申请报销", en: "Saved · Claim", de: "Gespeichert · Erstattung") }
    var quickExpenseReceipt: String { tr(zh: "凭证", en: "Receipt", de: "Beleg") }
    func quickExpenseReceiptCount(_ count: Int) -> String {
        tr(zh: "\(count) 个附件", en: "\(count) attachment\(count == 1 ? "" : "s")", de: "\(count) Anhang\(count == 1 ? "" : "e")")
    }
    var quickExpenseCamera: String { tr(zh: "拍照", en: "Camera", de: "Kamera") }
    var quickExpensePhotos: String { tr(zh: "相册", en: "Photos", de: "Fotos") }
    var quickExpenseFile: String { tr(zh: "文件", en: "File", de: "Datei") }
    var quickExpenseRemoveReceipt: String { tr(zh: "移除凭证", en: "Remove receipt", de: "Beleg entfernen") }
    var quickExpenseImage: String { tr(zh: "图片", en: "Image", de: "Bild") }
    var quickExpenseCameraUnavailable: String { tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar") }
    var quickExpenseCameraPermissionMessage: String {
        tr(zh: "请在系统设置中允许 Ohana 访问相机。", en: "Allow Ohana to access the camera in system settings.", de: "Erlaube Ohana den Kamerazugriff in den Systemeinstellungen.")
    }
    var quickExpenseInsuranceSingleTitle: String { tr(zh: "单笔保险费", en: "Single insurance expense", de: "Einzelne Versicherungszahlung") }
    var quickExpenseInsuranceSingleWithPolicy: String {
        tr(zh: "长期扣款请在保单页管理，避免重复生成。", en: "Manage recurring payments on the policy page to avoid duplicates.", de: "Wiederkehrende Zahlungen bitte in der Police verwalten, um Duplikate zu vermeiden.")
    }
    var quickExpenseInsuranceSingleNoPolicy: String {
        tr(zh: "这里可以先补记一笔保险费；长期计划请从保单页创建。", en: "Use this for one insurance payment; create long-term plans from the policy page.", de: "Hier nur eine Zahlung erfassen; langfristige Pläne in der Police anlegen.")
    }
    func expenseCategoryTitle(_ category: ExpenseCategory) -> String {
        switch category {
        case .food: return tr(zh: "食物", en: "Food", de: "Futter")
        case .treats: return tr(zh: "零食", en: "Treats", de: "Snacks")
        case .medical: return tr(zh: "医疗", en: "Medical", de: "Medizin")
        case .grooming: return tr(zh: "美容", en: "Grooming", de: "Pflege")
        case .toys: return tr(zh: "玩具", en: "Toys", de: "Spielzeug")
        case .insurancePremium: return tr(zh: "保险费", en: "Insurance", de: "Versicherung")
        case .other: return tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }
    func insuranceFrequencyTitle(_ frequency: InsurancePaymentFrequency) -> String {
        switch frequency {
        case .monthly: return tr(zh: "按月", en: "Monthly", de: "Monatlich")
        case .quarterly: return tr(zh: "按季", en: "Quarterly", de: "Vierteljährlich")
        case .annual: return tr(zh: "按年", en: "Yearly", de: "Jährlich")
        case .once: return tr(zh: "一次性", en: "Once", de: "Einmalig")
        }
    }
    var thisMonth: String { isEn ? "This month" : "本月" }
    var patrol: String { isEn ? "Patrol" : "巡岛" }
    var potty: String { isEn ? "Potty" : "噗噗" }
    var today: String { isEn ? "Today" : "今日" }
    var foodStock: String { isEn ? "Food Stock" : "粮仓" }
    func daysLeft(_ n: Int) -> String { isEn ? "\(n) days left" : "仅剩 \(n) 天" }
    var timeline: String { isEn ? "Timeline" : "岁月史书" }
    func entries(_ n: Int) -> String { isEn ? "\(n) entries" : "\(n) 条" }
    var noEntries: String { isEn ? "No entries yet" : "还没有任何记录" }
    var dangerZone: String { isEn ? "DANGER ZONE" : "危险区域" }
    var clearRecords: String { isEn ? "Clear All Records" : "仅清空所有记录" }
    func deletePet(_ name: String) -> String { isEn ? "Delete \(name)" : "彻底删除 \(name)" }

    // MARK: - Human Detail
    var healthBody: String { isEn ? "Health & Body" : "健康 & 身体" }
    var activityRecords: String { isEn ? "Activity & Records" : "活动 & 记录" }
    var finance: String { isEn ? "Finance" : "财务" }
    var remindersNotes: String { isEn ? "Reminders & Notes" : "提醒 & 备注" }
    var medication: String { isEn ? "Medication" : "用药" }
    var todo: String { isEn ? "To-do" : "待办" }
    var coconut: String { isEn ? "Coconut" : "椰子" }
    var notes: String { isEn ? "Notes" : "备注" }
    var deleteMember: String { isEn ? "Delete Member" : "删除成员" }

    // MARK: - Common
    var save: String { tr(zh: "保存", en: "Save", de: "Speichern") }
    var cancel: String { tr(zh: "取消", en: "Cancel", de: "Abbrechen") }
    var confirm: String { tr(zh: "确认", en: "Confirm", de: "Bestätigen") }
    var done: String { tr(zh: "完成", en: "Done", de: "Fertig") }
    var search: String { tr(zh: "搜索", en: "Search", de: "Suchen") }
    func searchPlaceholder(_ text: String) -> String {
        tr(zh: "搜索\(text)...", en: "Search \(text)...", de: "\(text) suchen...")
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
    func searchCrewPlaceholder() -> String { isEn ? "Search island residents..." : "搜索岛民..." }

    // MARK: - Batch Actions
    var batchCheckIn: String { isEn ? "Quick Check-in" : "一键全家" }

    /// 无 `@AppStorage` 的视图可用（与 `SettingsView` / `AppLanguage` 一致）
    static var current: L10n { L10n(UserDefaults.standard.string(forKey: "appLanguage") ?? "zh") }

    // MARK: - Add Entity sheet
    var addEntityNavRoot: String { isEn ? "Add to the island" : "添加家人" }
    var addEntityHeadline: String { isEn ? "Who's joining the fun?" : "添加新成员" }
    var addEntitySub: String { isEn ? "Pick a buddy type for your isle" : "选择要加入岛屿的类型" }
    var addEntityBack: String { isEn ? "Back" : "返回" }
    var addEntityClose: String { isEn ? "Close" : "关闭" }
    var addEntityWIP: String { isEn ? "Soon!" : "开发中" }
    var addEntityPetTitle: String { isEn ? "Pet pal" : "宠物" }
    var addEntityPetBlurb: String { isEn ? "Furry, feathery, or scaly roomies" : "添加你的毛孩子、小怪兽" }
    var addEntityHumanTitle: String { isEn ? "Human crew" : "家庭成员" }
    var addEntityHumanBlurb: String { isEn ? "Two-leg family & co-pilots" : "添加家庭成员" }
    var addEntityPlantTitle: String { isEn ? "Leafy friend" : "植物" }
    var addEntityPlantBlurb: String { isEn ? "Water, sun, good vibes only" : "添加绿植花卉" }

    // MARK: - Human wizard — mesh card titles
    var humanWizMesh1: String { tr(zh: "名字 · 1/6", en: "NAME · 1/6", de: "NAME · 1/6") }
    var humanWizMesh2: String { tr(zh: "个人档案 · 2/6", en: "PROFILE · 2/6", de: "PROFIL · 2/6") }
    var humanWizMesh3: String { tr(zh: "头像 · 3/6", en: "AVATAR · 3/6", de: "AVATAR · 3/6") }
    var humanWizMesh4: String { tr(zh: "资料与权限 · 4/6", en: "DETAILS & PERMISSION · 4/6", de: "DETAILS & RECHTE · 4/6") }
    var humanWizMesh5: String { tr(zh: "身体数据 · 5/6", en: "BODY & PRIVACY · 5/6", de: "KORPER & PRIVATSPHARE · 5/6") }
    var humanWizMesh6: String { tr(zh: "确认信息 · 6/6", en: "FINAL CHECK · 6/6", de: "ABSCHLUSS · 6/6") }

    var humanWizNameLabel: String { isEn ? "Name (required)" : "姓名（必填）" }
    var humanWizNamePlaceholder: String { isEn ? "Their island name" : "输入名字" }
    var humanWizAvatarPhoto: String { isEn ? "Profile photo" : "头像照片" }
    var humanWizPhotoLibrary: String { isEn ? "Photos" : "相册" }
    var humanWizCamera: String { isEn ? "Camera" : "拍照" }
    var humanWizPasteSubject: String { isEn ? "Paste cutout" : "粘贴主体" }
    var humanWizPasteHint: String { isEn ? "Long-press a person in Photos → Copy Subject → tap here" : "相册长按人物 → 拷贝主体 → 点粘贴" }
    var humanWizEmojiAvatar: String { isEn ? "Or pick an emoji face" : "或选择 Emoji 头像" }
    var humanWizDupNameInline: String { isEn ? "That name's taken — try another!" : "名字已被占用，请换一个" }

    var humanWizGenderLabel: String { tr(zh: "性别/身份（必选）", en: "Gender / identity (required)", de: "Geschlecht / Identität (erforderlich)") }
    var humanWizBirthdayLabel: String { isEn ? "Birthday (optional)" : "生日（可选）" }
    var humanWizBirthdayHint: String { isEn ? "Tap to spin the wheel, then hit Done ✓" : "点按选择日期，滚轮选好后点「完成」" }
    var humanWizBloodLabel: String { isEn ? "Blood type (optional)" : "血型（可选）" }
    var humanWizMbtiLabel: String { isEn ? "MBTI (optional)" : "MBTI（可选）" }
    var humanWizSkipChip: String { isEn ? "Skip" : "不填" }
    func humanWizBloodTag(_ type: String) -> String { isEn ? "Type \(type)" : "血型 \(type)" }
    func humanWizNationalityTag(_ country: String) -> String { isEn ? "From \(country)" : "国籍 \(country)" }

    var humanWizNationalityLabel: String { isEn ? "Nationality (optional)" : "国籍（可选）" }
    var humanWizNationalityHint: String { isEn ? "Passport country from the list — or skip" : "从列表选择护照国籍，可不填" }
    var humanWizResidenceLabel: String { isEn ? "Where you live (optional)" : "现居地（可选）" }
    var humanWizResidenceHint: String { isEn ? "Pick country + city for your nest" : "选择当前居住的国家与城市" }
    var humanWizResidenceCityPlaceholder: String { isEn ? "Type your city" : "输入城市名称" }
    var humanWizNotesLabel: String { isEn ? "Notes (optional)" : "备注（可选）" }
    var humanWizNotesPlaceholder: String { isEn ? "Anything cozy to remember" : "任何想记录的信息" }

    var humanWizBodyLabel: String { isEn ? "Body stats (optional)" : "身体数据（可选）" }
    var humanWizHeightLabel: String { isEn ? "Height" : "身高" }
    var humanWizHeightPh: String { isEn ? "e.g. 170" : "如 170" }
    var humanWizWeightLabel: String { isEn ? "Weight" : "体重" }
    var humanWizWeightPh: String { isEn ? "e.g. 65" : "如 65.0" }
    var humanWizWeightFootnote: String { isEn ? "Adding weight creates a first log for charts" : "填写体重将自动创建初始体重记录" }

    var humanWizPrivacyLabel: String { isEn ? "Privacy toggles" : "隐私设置" }
    var humanWizPrivacyHint: String { isEn ? "When private, other profiles on this device can't peek" : "设为私密后，同设备的其他成员无法查看该内容" }
    var humanWizPrivacyWeight: String { isEn ? "Weight logs & charts" : "体重记录与图表" }
    var humanWizPrivacyWorkout: String { isEn ? "Workouts" : "运动记录" }
    var humanWizPrivacyWishlist: String { isEn ? "Wishlist" : "心愿单" }
    var humanWizPrivacyExpense: String { isEn ? "Spending" : "花费记录" }

    var humanWizThemeLabel: String { isEn ? "Accent color" : "主题颜色" }
    var humanWizRolePermsLabel: String { tr(zh: "权限", en: "Permission", de: "Berechtigung") }
    var humanWizSummaryLabel: String { isEn ? "Cozy recap" : "信息摘要" }
    var humanWizSummaryEmpty: String { tr(zh: "选择权限和性别/身份后会出现在这里", en: "Pick permission and identity to preview them here", de: "Wähle Berechtigung und Identität für die Vorschau") }

    var humanWizRoleOwnerTitle: String { tr(zh: "管理者", en: "Admin", de: "Verwaltung") }
    var humanWizRoleOwnerDesc: String { tr(zh: "管理家庭资料与核心设置", en: "Manages home profile and core settings", de: "Verwaltet Haushalt und zentrale Einstellungen") }
    var humanWizRoleMemberTitle: String { tr(zh: "成员", en: "Member", de: "Mitglied") }
    var humanWizRoleMemberDesc: String { tr(zh: "日常记录与照护打卡", en: "Daily logs and care check-ins", de: "Alltagsnotizen und Pflege-Check-ins") }
    var humanWizRoleEditorTitle: String { humanWizRoleMemberTitle }
    var humanWizRoleEditorDesc: String { humanWizRoleMemberDesc }
    var humanWizRoleViewerTitle: String { humanWizRoleMemberTitle }
    var humanWizRoleViewerDesc: String { humanWizRoleMemberDesc }

    var humanWizJoinIsland: String { isEn ? "Hop onto Ohana Isle!" : "加入 Ohana 岛" }
    var humanWizNeedName: String { isEn ? "Name first, please" : "请先填写名字" }
    var humanWizNeedGender: String { tr(zh: "请选择性别/身份", en: "Pick gender / identity", de: "Identität auswählen") }
    var humanWizNameTakenBtn: String { isEn ? "Name taken" : "名字已被占用" }
    var humanWizBirthdaySheetTitle: String { isEn ? "Pick a birthday" : "选择生日" }
    var humanWizBirthdayEventSuffix: String { isEn ? "'s birthday 🎂" : " 的生日 🎂" }

    var humanWizDupAlertTitle: String { isEn ? "That name's taken 🏠" : "名字已被占用 🏠" }
    var humanWizDupAlertOk: String { isEn ? "Got it — new name!" : "好的，换一个" }
    func humanWizDupAlertMsg(_ name: String) -> String {
        isEn
            ? "Someone on Ohana is already called 「\(name)」 — pick another cozy name!"
            : "Ohana 里已经有叫「\(name)」的家人，换个名字吧！"
    }

    func humanGenderDisplay(_ key: String) -> String {
        switch HumanProfileOptions.normalizedGender(key) {
        case "男": return tr(zh: "男", en: "Man", de: "Mann")
        case "女": return tr(zh: "女", en: "Woman", de: "Frau")
        case "非二元": return tr(zh: "非二元", en: "Non-binary", de: "Nichtbinär")
        case "不透露": return tr(zh: "不透露", en: "Prefer not to say", de: "Keine Angabe")
        default: return key
        }
    }

    func humanThemeSwatchLabel(_ zh: String) -> String {
        switch zh {
        case "青柠": return isEn ? "Lime" : "青柠"
        case "橙色": return isEn ? "Orange" : "橙色"
        case "靛蓝": return isEn ? "Indigo" : "靛蓝"
        case "粉色": return isEn ? "Pink" : "粉色"
        case "青色": return isEn ? "Teal" : "青色"
        case "紫色": return isEn ? "Purple" : "紫色"
        case "红色": return isEn ? "Red" : "红色"
        case "金色": return isEn ? "Gold" : "金色"
        default: return zh
        }
    }

    func humanResidenceCityOther(_ zh: String) -> String {
        zh == "其他" ? (isEn ? "Other" : "其他") : zh
    }

    // MARK: - Human wallet cards
    var humanWalletNewMember: String { isEn ? "New island buddy" : "新成员" }
    var humanWalletResident: String { isEn ? "Island pal" : "岛民" }
    var humanWalletSubtitlePlaceholder: String { isEn ? "Fill the lil' form below ✨" : "填写下方信息完善档案" }

    // MARK: - Add Pet Wizard
    var petWizMesh1: String { isEn ? "WHO'S THAT CUTIE · 1/6" : "基本信息 · 1/6" }
    var petWizMesh2: String { isEn ? "LIL' BIO · 2/6" : "生物特征 · 2/6" }
    var petWizMesh3: String { isEn ? "SPOTS & SPARKLE · 3/6" : "外貌与主题色 · 3/6" }
    var petWizMesh4: String { isEn ? "PHOTO BOOP · 4/6" : "头像 · 4/6" }
    var petWizMesh5: String { isEn ? "VIBE TAGS · 5/6" : "标签 · 5/6" }
    var petWizMesh6: String { isEn ? "ALL SET? · 6/6" : "确认信息 · 6/6" }

    var petWizIslandWelcome: String { isEn ? "The isle throws a welcome party!" : "岛屿欢迎新家人！" }
    var petWizBentoBasic: String { isEn ? "Basics" : "基本信息" }
    var petWizBentoBreed: String { isEn ? "Breed" : "品种" }
    var petWizBentoAvatar: String { isEn ? "Profile pic" : "头像设置" }
    var petWizBentoBio: String { isEn ? "Bio & dates" : "生物特征" }
    var petWizBentoAppearance: String { isEn ? "Looks" : "外貌特征" }
    var petWizBentoTheme: String { isEn ? "Accent" : "主题色" }
    var petWizBentoTagsTitle: String { isEn ? "Tiny tags for them" : "给 TA 点小标签" }
    var petWizOptionalParen: String { isEn ? "(optional)" : "（可选）" }
    func petWizTagPicked(_ n: Int) -> String {
        isEn ? "Pick up to 3 · \(n)/3" : "最多 3 个 · 已选 \(n)/3"
    }

    var petWizNamePlaceholder: String { isEn ? "Name your lil' monster" : "给你的小怪兽起个名字" }
    var petWizNameLabelRequired: String { isEn ? "Name (required)" : "名字（必填）" }
    var petWizSpecies: String { isEn ? "Species" : "物种" }
    var petWizSpeciesOtherPh: String { isEn ? "Type a species (e.g. gecko, hedgehog)" : "请输入物种，如：蜥蜴、刺猬" }
    var petWizBreedExpand: String { isEn ? "Tap to open breed list" : "点按展开品种列表" }
    var petWizBreedCollapse: String { isEn ? "Tap to hide breed list" : "点按收起列表" }
    var petWizBreedSearchPh: String { isEn ? "Search breeds…" : "搜索品种…" }
    var petWizBreedNoMatch: String { isEn ? "No hits — pick Other and type a custom breed" : "未找到匹配品种，可在列表中选择「其他」并自定义" }
    var petWizBreedNone: String { isEn ? "Skip breed" : "不选品种" }
    var petWizCustomBreed: String { isEn ? "Custom breed" : "自定义品种" }
    var petWizCustomBreedFieldPh: String { isEn ? "Breed name" : "输入品种名称" }
    var petWizAvatarHint: String { isEn ? "Paste a cutout, or pick below" : "点击粘贴抠图，或从下方选择" }
    var petWizRemoveAvatar: String { isEn ? "Remove photo · use species icon" : "移除头像，使用默认物种图标" }
    var petWizRemoveAvatarShort: String { isEn ? "Remove photo" : "移除头像" }
    var petWizClipboardEmpty: String { isEn ? "Clipboard" : "剪贴板" }
    var petWizNeuter: String { isEn ? "Spay / neuter" : "绝育" }
    var petWizNeuteredOn: String { isEn ? "Spayed / neutered" : "已绝育" }
    var petWizNeuteredOff: String { isEn ? "Not yet" : "未绝育" }
    var petWizBirthday: String { isEn ? "Birthday" : "生日" }
    var petWizHomeDate: String { isEn ? "Gotcha day" : "到家日" }
    var petWizToggleOn: String { isEn ? "On" : "启用" }
    var petWizGender: String { isEn ? "Gender" : "性别" }
    var petWizGenderBoy: String { isEn ? "♂ Boy" : "♂ 男孩" }
    var petWizGenderGirl: String { isEn ? "♀ Girl" : "♀ 女孩" }
    var petWizGenderUnknown: String { isEn ? "Unknown" : "未知" }
    var petWizCoatSection: String { isEn ? "Coat" : "毛色" }
    var petWizEyeSection: String { isEn ? "Eyes" : "瞳色" }
    var petWizThemeSection: String { isEn ? "Accent color" : "主题色" }
    var petWizCardThemeCaption: String { isEn ? "Wallet card accent" : "宠物卡片主题色" }
    var petWizCardPreviewHex: String { isEn ? "Preview swatch #" : "卡片预览色 #" }
    var petWizTapBodyCoat: String { isEn ? "Tap body → coat" : "点击身体 → 毛色" }
    var petWizTapEyeColor: String { isEn ? "Tap eyes → peepers" : "点击眼睛 → 瞳色" }
    var petWizCardBgCaption: String { isEn ? "Card backdrop" : "卡片背景色" }
    var petWizPassportLabel: String { isEn ? "Passport #" : "护照号码" }
    var petWizMicrochipLabel: String { isEn ? "Microchip ID" : "芯片号 (Microchip ID)" }
    var petWizOptionalShort: String { isEn ? "Optional" : "选填" }
    var petWizMicrochipPlaceholder: String { isEn ? "15 digits (optional)" : "15位数字（选填）" }
    var petWizUnnamed: String { isEn ? "Unnamed" : "未命名" }
    var petWizPickSpeciesFirst: String { isEn ? "Pick a species first" : "请先选择宠物品种" }
    var petWizNoSameSpeciesPets: String { isEn ? "No same-species pals on the isle yet" : "岛上暂时没有同品种宠物" }
    var petWizCrossBreedHint: String { isEn ? "Cross-breed bonds aren’t tracked — skip ahead!" : "不同品种间没有亲属关系，直接跳过" }
    var petWizPickRelationIntro: String { isEn ? "Pick a vibe with each pet (multi, optional)" : "选择与每只宠物的关系（可多选，选填）" }

    var petWizPickCoatTitle: String { isEn ? "Pick coat color" : "选择毛色" }
    var petWizPickEyeTitle: String { isEn ? "Pick eye color" : "选择瞳色" }
    var petWizCustomColorPickerTitle: String { isEn ? "Custom color" : "自定义颜色" }
    var petCustomSwatch: String { isEn ? "Custom" : "自定义" }
    var petWizAppearanceNoBreedHint: String {
        isEn
            ? "No breed yet? Here are universal coat & eye swatches — pick a breed to narrow phenotypes."
            : "尚未选择品种时显示通用毛色与瞳色；选定品种后选项会自动收窄到该品种常见表型。"
    }
    var petWizSaving: String { isEn ? "Saving…" : "保存中…" }
    var petWizSavingShort: String { isEn ? "Saving..." : "保存中..." }
    var petWizSaveFailedTitle: String { isEn ? "Couldn’t save" : "保存失败" }
    var petWizSaveFailedDefault: String { isEn ? "Couldn’t write to the island vault — try again?" : "无法写入资料库，请稍后重试。" }
    var petWizNext: String { isEn ? "Next" : "下一步" }
    var petWizBreedSheetTitle: String { isEn ? "Choose breed" : "选择品种" }
    var petWizBreedSearchPrompt: String { isEn ? "Search breeds" : "搜索品种" }
    var petWizBreedFieldPh: String { isEn ? "Type breed name" : "请输入品种名称" }

    func petSpeciesLabel(_ storageKey: String) -> String {
        switch storageKey {
        case "狗": return dog
        case "猫": return cat
        case "兔子": return rabbit
        case "仓鼠": return hamster
        case "鸟": return isEn ? "Birdie" : "鸟"
        case "其他": return isEn ? "Other critter" : "其他"
        default: return storageKey
        }
    }

    func petCoatPatternDisplay(_ zh: String) -> String {
        switch zh {
        case "三花": return isEn ? "Calico" : "三花"
        case "银渐层": return isEn ? "Silver shaded" : "银渐层"
        case "玳瑁": return isEn ? "Tortie" : "玳瑁"
        case "奶牛色": return isEn ? "Cow" : "奶牛色"
        case "蓝白双色": return isEn ? "Blue & white" : "蓝白双色"
        default: return zh
        }
    }

    func petCoatOrEyeDisplay(_ zh: String) -> String {
        guard isEn else { return zh }
        if zh == "自定义" { return petCustomSwatch }
        if let mapped = Self.petAppearanceZhToEn[zh] { return mapped }
        return petCoatPatternDisplay(zh)
    }

    func petWizDaysUntilHome(_ days: Int) -> String {
        isEn ? "\(days) days until gotcha 🏠" : "还有 \(days) 天到家"
    }
    var petWizHomeToday: String { isEn ? "Gotcha day is today!" : "今天到家" }
    func petWizTogetherDays(_ days: Int) -> String {
        isEn ? "Together \(days) days 💛" : "已陪伴 \(days) 天"
    }
    func petWizMilestoneTogether(_ days: Int) -> String {
        isEn ? "Together \(days) days" : "共度 \(days) 天"
    }

    func petWizAgeWallet(years: Int, months: Int) -> String {
        if years > 0 {
            if months > 0 {
                return isEn ? "\(years)y \(months)m old" : "\(years)岁\(months)月"
            }
            return isEn ? "\(years) yrs" : "\(years)岁"
        }
        return isEn ? "\(months) mo" : "\(months)个月"
    }

    func petWizBreedCollapseSummary(isCustomBreed: Bool, customBreedText: String, breed: String) -> String {
        if isCustomBreed {
            let t = customBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? (isEn ? "Other (type it in)" : "其他（待输入）") : t
        }
        if breed.isEmpty { return isEn ? "No breed picked" : "未选择品种" }
        return breed
    }

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
        "三花（黑白橘）": "Calico (B/W/O)",
    ]

    // MARK: - Pet cutout pro tip
    var petProTipTitle: String { isEn ? "Unlock the 3D floaty card" : "解锁 3D 悬浮卡片" }
    var petProTipStep1Prefix: String { isEn ? "In Photos, " : "在系统相册中" }
    var petProTipStep1Highlight: String { isEn ? "long-press your pet" : "长按宠物主体" }
    var petProTipStep2Prefix: String { isEn ? "Tap " : "点击" }
    var petProTipStep2Highlight: String { isEn ? "Copy Subject" : "拷贝" }
    var petProTipStep2Suffix: String { isEn ? " to stash it on the clipboard" : "保存到剪贴板" }
    var petProTipStep3Prefix: String { isEn ? "Back in Ohana, tap " : "返回 Ohana，点击上方" }
    var petProTipStep3Highlight: String { isEn ? "Paste" : "粘贴按钮" }

    // MARK: - Home / Overview & GO dashboard
    var homeDailyCoconutTitle: String { isEn ? "Daily login +1 🥥" : "每日登录奖励 +1🥥" }
    var homeDailyCoconutSub: String { isEn ? "Keep caring for your crew — more coconuts await!" : "坚持照顾家人，收获更多椰子" }
    var homeClaimCoconuts: String { isEn ? "Claim" : "收下" }
    func homeFamilyCareTitle(petName: String) -> String {
        isEn ? "Today · Who’s on duty for \(petName)" : "今日 · 谁在照顾 \(petName)"
    }
    var homeRecordMoment: String { isEn ? "Log a moment" : "记录时刻" }
    var homeConfirmCheckIn: String { isEn ? "Check in anyway" : "确定打卡" }
    var homeMemoryShardsTitle: String { isEn ? "Memory sparkles" : "记忆碎片" }
    var homeMemoryShardsBody: String {
        isEn
            ? "Keep logging feeds, walks, or weights —\nlil’ highlights will bubble up here ✨"
            : "继续记录喂食、散步或体重数据\n美好时刻会在这里浮现 ✨"
    }
    var homeMemoryCoconutTitle: String { isEn ? "Cherished memory +1 🥥" : "珍惜记忆 +1🥥" }
    var homeDailyCheckInRewardTitle: String { isEn ? "Daily check-in reward" : "每日打卡奖励" }
    var homeDailyLoginRewardTitle: String { isEn ? "Daily login reward" : "每日登录奖励" }
    var homeIslandQuestRewardTitle: String { isEn ? "Island quest reward" : "岛屿委托奖励" }

    var homeQuickCheckInNote: String { isEn ? "Quick log" : "快捷打卡" }

    func homePlantWaterEventTitle(plantName: String) -> String {
        isEn ? "💧 Water \(plantName)" : "💧 给 \(plantName) 浇水"
    }
    func homePlantFertilizeEventTitle(plantName: String) -> String {
        isEn ? "🌿 Fertilize \(plantName)" : "🌿 给 \(plantName) 施肥"
    }

    func homeToastWalkStarted(_ petName: String) -> String {
        isEn ? "Walking \(petName)!" : "开始遛 \(petName)！"
    }
    func homeToastPotty(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) potty log +\(points) 🥥" : "\(petName) 便便打卡 +\(points)🥥"
    }
    func homeToastLitter(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) litter box +\(points) 🥥" : "\(petName) 铲猫砂 +\(points)🥥"
    }
    func homeToastManualFeed(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) manual feed +\(points) 🥥" : "\(petName) 手动喂食 +\(points)🥥"
    }
    func homeToastWater(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) water log +\(points) 🥥" : "\(petName) 喂水打卡 +\(points)🥥"
    }
    func homeToastPlay(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) playtime +\(points) 🥥" : "\(petName) 逗玩打卡 +\(points)🥥"
    }
    func homePlayQuestTitle(_ petName: String) -> String {
        isEn ? "\(petName) · playtime" : "\(petName) 逗玩打卡"
    }
    func homeToastPlannedFeed(_ petName: String, points: Int) -> String {
        isEn ? "\(petName) planned meal +\(points) 🥥" : "\(petName) 计划喂食打卡 +\(points)🥥"
    }
    func homeToastHealthVaccine(_ petName: String) -> String {
        isEn ? "\(petName) vaccine logged ✅" : "\(petName) 疫苗记录 ✅"
    }
    func homeToastHealthDeworm(_ petName: String) -> String {
        isEn ? "\(petName) dewormer logged ✅" : "\(petName) 驱虫记录 ✅"
    }
    func homeToastHealthVisit(_ petName: String) -> String {
        isEn ? "\(petName) vet visit logged ✅" : "\(petName) 就诊记录 ✅"
    }

    var homeWalkNoneToday: String { isEn ? "No walks yet" : "今日未遛" }
    func homeWalkTodayBadge(count: Int, dist: String) -> String {
        isEn ? "\(count)× today · \(dist)" : "今日\(count)次·\(dist)"
    }
    func homeFeedMealsProgress(current: Int, goal: Int) -> String {
        isEn ? "\(current)/\(goal) meals" : "\(current)/\(goal)餐"
    }
    func homeTimesToday(_ n: Int) -> String {
        isEn ? "\(n)× today" : "今日\(n)次"
    }
    func homeExpenseMonthCNY(_ amount: Int) -> String {
        let formatted = AppCurrency.format(Double(amount), fractionDigits: 0)
        return isEn ? "\(formatted) this month" : "本月\(formatted)"
    }
    func homeLastWeightKg(_ kg: Double) -> String {
        let formatted = AppMeasurementSystem.formatWeightKilograms(kg)
        return isEn ? "Last \(formatted)" : "上次\(formatted)"
    }

    var homeAntiDupFeedTitle: String { isEn ? "Feed again?" : "重复喂食提醒" }
    func homeAntiDupFeedMessage(executor: String, minutes: Int, petName: String) -> String {
        isEn
            ? "\(executor) fed \(petName) \(minutes) min ago — log another meal?"
            : "\(executor) 在 \(minutes) 分钟前刚喂过 \(petName) ，确定要再喂一次吗？"
    }
    var homeAntiDupWaterTitle: String { isEn ? "Water again?" : "重复喂水提醒" }
    func homeAntiDupWaterMessage(executor: String, minutes: Int, petName: String) -> String {
        isEn
            ? "\(executor) refreshed \(petName)’s water \(minutes) min ago — log again?"
            : "\(executor) 在 \(minutes) 分钟前刚喂过 \(petName) 水，确定要再记录一次吗？"
    }

    // Quick action chip labels (home / GO)
    var homeQAFeed: String { isEn ? "Feed" : "喂食" }
    var homeQAWater: String { isEn ? "Water" : "喂水" }
    var homeQAWaterChange: String { isEn ? "Change water" : "换水" }
    var homeQAFilterClean: String { isEn ? "Filter clean" : "清滤材" }
    var homeQAWalk: String { isEn ? "Walk" : "遛狗" }
    var homeQAPotty: String { isEn ? "Potty" : "便便" }
    var homeQALitter: String { isEn ? "Litter" : "铲屎" }
    var homeQAGroom: String { isEn ? "Groom" : "护理" }
    var homeQAWeight: String { isEn ? "Weight" : "体重" }
    var homeQASport: String { isEn ? "Workout" : "运动" }
    var homeQAMeds: String { isEn ? "Meds" : "吃药" }
    var homeQANote: String { isEn ? "Note" : "记录" }

    // GO dashboard sections & hub
    var goSectionIslandQuests: String { isEn ? "🏝️ Island quests" : "🏝️ 今日委托" }
    var goSectionIslandQuestsLabel: String { isEn ? "ISLAND QUESTS" : "ISLAND QUESTS" }
    var goSectionQuickActions: String { isEn ? "⚡ Quick check-in" : "⚡ 快捷打卡" }
    var goSectionQuickActionsLabel: String { isEn ? "QUICK ACTIONS" : "QUICK ACTIONS" }
    var goFeatureHubTitle: String { isEn ? "🗺️ Island hub" : "🗺️ 岛屿功能" }
    var goStatsTitle: String { isEn ? "📊 Island stats" : "📊 岛屿统计" }
    var goAddChip: String { isEn ? "Add" : "添加" }
    func goLifeTreeTitle(levelName: String) -> String {
        isEn ? "Life Tree · \(levelName)" : "生命之树 · \(levelName)"
    }
    func goTreeNeedEnergy(_ n: Int) -> String {
        isEn ? "\(n) more 🥥 to level up" : "还差 \(n) 🥥 能量升级"
    }
    var goTreeMaxLevel: String { isEn ? "Max level reached ✨" : "已达最高等级 ✨" }
    var goInjectEnergy: String { isEn ? "⚡ Send energy" : "⚡ 注入能量" }
    var goToOasis: String { isEn ? "Open Oasis" : "前往绿洲" }
    var goFeatPatrol: String { isEn ? "Patrol" : "巡岛" }
    var goFeatPatrolSub: String { isEn ? "Walkies" : "遛宠" }
    var goFeatHealth: String { isEn ? "Health" : "健康" }
    var goFeatHealthSub: String { isEn ? "Records" : "医疗档案" }
    var goFeatCalendar: String { isEn ? "Calendar" : "日历" }
    var goFeatCalendarSub: String { isEn ? "Schedule" : "日程安排" }
    var goFeatExpense: String { isEn ? "Spend" : "花费" }
    var goFeatExpenseSub: String { isEn ? "Totals" : "支出统计" }
    var goFeatWeight: String { isEn ? "Weight" : "体重" }
    var goFeatWeightSub: String { isEn ? "Curves" : "成长曲线" }
    var goFeatOasis: String { isEn ? "Oasis" : "绿洲" }
    var goFeatOasisSub: String { isEn ? "Rewards" : "奖励中心" }
    var goAddPetLocked: String { isEn ? "Add a pet" : "添加宠物" }
    var goEmptyPetsTitle: String { isEn ? "No pets yet" : "还没有宠物" }
    var goEmptyPetsSub: String { isEn ? "Add your first pet to unlock island stats" : "添加你的第一只宠物\n开启家庭数据统计" }
    var goEmptyPetsCTA: String { isEn ? "Add now →" : "立即添加 →" }
    var goWeekWalks: String { isEn ? "Walks this week" : "本周散步" }
    var goThisMonthExpense: String { isEn ? "Spending (month)" : "本月花费" }
    func goPetFoodPantry(_ name: String) -> String {
        isEn ? "\(name)’s pantry" : "\(name)粮仓"
    }

    // MARK: - Care / hygiene / potty (UI labels; persisted logs keep zh `rawValue`)
    func careTypeUILabel(_ type: CareType) -> String {
        if !isEn { return type.label }
        switch type {
        case .feeding: return "Feeding"
        case .watering: return "Water"
        case .litter: return "Litter box"
        case .waterChange: return "Water change"
        case .filterClean: return "Filter cleaning"
        case .cageCleaning: return "Cage cleaning"
        case .freeFlight: return "Free flight"
        case .misting: return "Misting"
        case .substrateChange: return "Substrate change"
        case .play: return "Playtime"
        }
    }

    func hygieneTypeUILabel(_ type: HygieneType) -> String {
        if !isEn { return type.rawValue }
        switch type {
        case .teeth: return "Teeth"
        case .nails: return "Nails"
        case .ears: return "Ears"
        case .brushing: return "Brushing"
        case .bath: return "Bath"
        }
    }

    func pottyTypeUILabel(_ type: PottyType) -> String {
        if !isEn { return type.rawValue }
        switch type {
        case .perfectPoop: return "Great poop"
        case .softPoop: return "Soft stool"
        case .liquidPoop: return "Loose stool"
        case .pee: return "Pee"
        }
    }

    func homeToastPottyLine(petName: String, type: PottyType, points: Int) -> String {
        let label = pottyTypeUILabel(type)
        return isEn
            ? "\(petName) \(type.emoji) \(label) +\(points) 🥥"
            : "\(petName) \(type.emoji)\(label) +\(points)🥥"
    }

    func homeToastGroomLine(petName: String, type: HygieneType, points: Int) -> String {
        let label = hygieneTypeUILabel(type)
        return isEn ? "\(petName) · \(label) +\(points) 🥥" : "\(petName) \(label)打卡 +\(points)🥥"
    }

    // MARK: - Pet ID card (Ark crew)
    var petCardDetail: String { isEn ? "Details" : "详情" }
    var petCardDaysTogetherCaption: String { isEn ? "Days together" : "相伴天数" }
    func petCardStreak(_ days: Int) -> String {
        isEn ? "🔥 \(days)-day streak" : "🔥 \(days)天连续"
    }
    var petCardDayUnit: String { isEn ? "d" : "天" }
    var petCardTogetherPrefix: String { isEn ? "Together for" : "一起度过了" }
    var petCardRainbowTitle: String { isEn ? "Shining as stars, watching over you" : "化作星星，守护着你" }
    func petCardRainbowTogether(days: Int, yearsApart: Int) -> String {
        if isEn {
            if yearsApart > 0 {
                return "Together \(days) days · gone \(yearsApart) yr\(yearsApart == 1 ? "" : "s")"
            }
            return "Together \(days) days"
        }
        if yearsApart > 0 { return "相伴 \(days) 天 · 离开 \(yearsApart) 年" }
        return "相伴 \(days) 天"
    }

    var petCardWalkPatrolling: String { isEn ? "On patrol" : "巡岛中" }
    var petCardWalkDistanceLabel: String { isEn ? "Patrol distance" : "巡岛距离" }
    var petCardWalkPoopLabel: String { isEn ? "Poops" : "便便次数" }
    var petCardPause: String { isEn ? "Pause" : "暂停" }
    var petCardResume: String { isEn ? "Resume" : "继续" }
    var petCardEndWalk: String { isEn ? "End" : "结束" }

    func petCardVaccineCountdown(daysUntilDue: Int) -> String {
        if daysUntilDue < 0 {
            let overdue = abs(daysUntilDue)
            if overdue >= 30 { return isEn ? "\(overdue / 30) mo overdue" : "逾期\(overdue / 30)月" }
            return isEn ? "\(overdue)d overdue" : "逾期\(overdue)天"
        }
        if daysUntilDue == 0 { return isEn ? "Today" : "今天" }
        if daysUntilDue < 30 { return isEn ? "in \(daysUntilDue)d" : "\(daysUntilDue)天后" }
        if daysUntilDue < 365 { return isEn ? "in \(daysUntilDue / 30) mo" : "\(daysUntilDue / 30)个月后" }
        let y = daysUntilDue / 365
        return isEn ? "in \(y) yr\(y == 1 ? "" : "s")" : "\(y)年后"
    }

    func petCardHumanEquivBody(humanAge: Int, isFemale: Bool) -> String {
        switch humanAge {
        case 0..<3:
            return isEn ? "👶 ≈ human baby \(humanAge)" : "👶 相当于人类宝宝 \(humanAge) 岁"
        case 3..<8:
            return isEn
                ? "🎠 ≈ a \(humanAge)-yr-old \(isFemale ? "little princess" : "little dude")"
                : "🎠 相当于 \(humanAge) 岁的\(isFemale ? "小公主" : "小男孩")"
        case 8..<13:
            return isEn
                ? "🎒 ≈ \(humanAge) yrs \(isFemale ? "cool kid sis" : "cool kid bro")"
                : "🎒 相当于 \(humanAge) 岁的\(isFemale ? "萌妹" : "小大人")"
        case 13..<18:
            return isEn
                ? "🌱 ≈ \(humanAge) yrs \(isFemale ? "teen queen" : "teen pal")"
                : "🌱 相当于 \(humanAge) 岁的\(isFemale ? "少女" : "少男")"
        case 18..<25:
            return isEn
                ? "🔥 ≈ \(humanAge) yrs \(isFemale ? "sparkly young adult" : "bright young adult")"
                : "🔥 相当于 \(humanAge) 岁的\(isFemale ? "活力少女" : "鲜肉小哥")"
        case 25..<35:
            return isEn
                ? "💼 ≈ \(humanAge) yrs \(isFemale ? "grown-up glow" : "steady glow-up")"
                : "💼 相当于 \(humanAge) 岁的\(isFemale ? "独立美女" : "稳重帅哥")"
        case 35..<50:
            return isEn
                ? "🌟 ≈ \(humanAge) yrs \(isFemale ? "elegant vibes" : "seasoned vibes")"
                : "🌟 相当于 \(humanAge) 岁的\(isFemale ? "优雅女士" : "成熟大叔")"
        case 50..<65:
            return isEn
                ? "👑 ≈ \(humanAge) yrs \(isFemale ? "wise matriarch" : "wise patriarch")"
                : "👑 相当于 \(humanAge) 岁的\(isFemale ? "典雅长辈" : "稳重前辈")"
        default:
            return isEn ? "🧓 ≈ \(humanAge) human yrs wise & warm" : "🧓 相当于人类 \(humanAge) 岁的长者"
        }
    }
}

// MARK: - App language (与设置页 `appLanguage` / `@AppStorage` 同步)

nonisolated enum AppLanguage {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: String
        let localeIdentifier: String
        let swiftUILocaleIdentifier: String
        let lprojName: String

        var id: String { code }
    }

    /// 以后新增语言时只需要在这里追加一项，并添加对应 `.lproj/Localizable.strings`。
    static let supported: [Option] = [
        Option(
            code: "zh",
            displayName: "中文",
            localeIdentifier: "zh_CN",
            swiftUILocaleIdentifier: "zh-Hans",
            lprojName: "zh-Hans"
        ),
        Option(
            code: "en",
            displayName: "English",
            localeIdentifier: "en_US",
            swiftUILocaleIdentifier: "en",
            lprojName: "en"
        ),
        Option(
            code: "de",
            displayName: "Deutsch",
            localeIdentifier: "de_DE",
            swiftUILocaleIdentifier: "de",
            lprojName: "de"
        )
    ]

    static let fallbackCode = "zh"

    /// 与 `SettingsView` 中 Picker 的 tag 一致。
    static var code: String {
        normalize(UserDefaults.standard.string(forKey: "appLanguage") ?? fallbackCode)
    }

    static var isEnglish: Bool { code == "en" }
    static var isGerman: Bool { code == "de" }
    static var usesChineseDateFormat: Bool { code == "zh" }
    static var supportedCodes: Set<String> { Set(supported.map(\.code)) }

    static func normalize(_ raw: String) -> String {
        supported.contains { $0.code == raw } ? raw : fallbackCode
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    /// `DateFormatter` / `NumberFormatter` 等使用。
    static var effectiveLocale: Locale {
        Locale(identifier: currentOption.localeIdentifier)
    }

    static var compactMonthDayFormat: String {
        switch code {
        case "zh":
            return "M月d日"
        case "de":
            return "d. MMM"
        default:
            return "MMM d"
        }
    }

    static var fullMonthYearFormat: String {
        usesChineseDateFormat ? "yyyy年 M月" : "MMMM yyyy"
    }

    static var dailyReportDateFormat: String {
        switch code {
        case "zh":
            return "M月d日 EEEE"
        case "de":
            return "EEEE, d. MMM"
        default:
            return "EEEE, MMM d"
        }
    }

    /// SwiftUI `Text` 等查 `Localizable.strings` 时使用，与 `en.lproj` / `zh-Hans` 资源一致。
    static var swiftUIPreferredLocale: Locale {
        Locale(identifier: currentOption.swiftUILocaleIdentifier)
    }

    /// 例：`2026-04-19`，用于「每日只弹一次」等与展示语言无关的键。
    static var calendarDayKeyToday: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.startOfDay(for: Date()))
    }
}

// MARK: - Localized text value

nonisolated struct AppLocalizedText: Hashable {
    let translations: [String: String]
    let fallbackCode: String

    init(
        zh: String,
        en: String? = nil,
        de: String? = nil,
        extras: [String: String] = [:],
        fallbackCode: String = AppLanguage.fallbackCode
    ) {
        var values = extras
        values["zh"] = zh
        if let en { values["en"] = en }
        if let de { values["de"] = de }

        self.translations = values
        self.fallbackCode = AppLanguage.normalize(fallbackCode)
    }

    init(
        translations: [String: String],
        fallbackCode: String = AppLanguage.fallbackCode
    ) {
        self.translations = translations
        self.fallbackCode = AppLanguage.normalize(fallbackCode)
    }

    func resolve(_ rawLanguageCode: String = AppLanguage.code) -> String {
        let code = AppLanguage.normalize(rawLanguageCode)
        if let value = translations[code], !value.isEmpty {
            return value
        }
        if let fallback = translations[fallbackCode], !fallback.isEmpty {
            return fallback
        }
        return translations.values.first { !$0.isEmpty } ?? ""
    }

    var missingSupportedLanguageCodes: [String] {
        AppLanguage.supported
            .map(\.code)
            .filter { translations[$0]?.isEmpty ?? true }
    }
}

// MARK: - App measurement system (全局显示单位；不迁移历史数据)

nonisolated enum AppMeasurementSystem {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: AppLocalizedText
        let shortLabel: String
        let systemIconName: String

        var id: String { code }

        func title(_ languageCode: String = AppLanguage.code) -> String {
            displayName.resolve(languageCode)
        }
    }

    static let storageKey = "appMeasurementSystem"
    static let fallbackCode = "metric"

    static let supported: [Option] = [
        Option(
            code: "metric",
            displayName: AppLocalizedText(zh: "公制 · kg / cm", en: "Metric · kg / cm", de: "Metrisch · kg / cm"),
            shortLabel: "kg",
            systemIconName: "scalemass"
        ),
        Option(
            code: "imperial",
            displayName: AppLocalizedText(zh: "英制 · lb / in", en: "Imperial · lb / in", de: "Imperial · lb / in"),
            shortLabel: "lb",
            systemIconName: "ruler"
        )
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? fallbackCode)
    }

    static func normalize(_ raw: String) -> String {
        supported.contains { $0.code == raw } ? raw : fallbackCode
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    static func option(for raw: String) -> Option {
        supported.first { $0.code == normalize(raw) } ?? supported[0]
    }

    static func formatWeightKilograms(_ kilograms: Double, fractionDigits: Int = 1) -> String {
        switch code {
        case "imperial":
            let pounds = kilograms * 2.2046226218
            return "\(formattedNumber(pounds, fractionDigits: fractionDigits)) lb"
        default:
            return "\(formattedNumber(kilograms, fractionDigits: fractionDigits)) kg"
        }
    }

    static func formatFoodGrams(_ grams: Double, fractionDigits: Int = 0) -> String {
        switch code {
        case "imperial":
            let pounds = grams / 453.59237
            return pounds >= 1
                ? "\(formattedNumber(pounds, fractionDigits: 1)) lb"
                : "\(formattedNumber(grams * 0.0352739619, fractionDigits: 1)) oz"
        default:
            return grams >= 1_000
                ? "\(formattedNumber(grams / 1_000, fractionDigits: 1)) kg"
                : "\(formattedNumber(grams, fractionDigits: fractionDigits)) g"
        }
    }

    static func formatDistanceMeters(_ meters: Double, fractionDigits: Int = 1) -> String {
        switch code {
        case "imperial":
            let miles = meters / 1_609.344
            return miles >= 0.1
                ? "\(formattedNumber(miles, fractionDigits: fractionDigits)) mi"
                : "\(formattedNumber(meters * 3.280839895, fractionDigits: 0)) ft"
        default:
            return meters >= 1_000
                ? "\(formattedNumber(meters / 1_000, fractionDigits: fractionDigits)) km"
                : "\(formattedNumber(meters, fractionDigits: 0)) m"
        }
    }

    private static func formattedNumber(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

// MARK: - App currency (全局真实货币显示；不做汇率换算)

nonisolated enum AppCurrency {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: String
        let symbol: String
        let localeIdentifier: String
        let systemIconName: String

        var id: String { code }
    }

    static let storageKey = "appCurrency"
    static let fallbackCode = "CNY"

    static let supported: [Option] = [
        Option(code: "CNY", displayName: "CNY · ¥", symbol: "¥", localeIdentifier: "zh_CN", systemIconName: "yensign.circle"),
        Option(code: "USD", displayName: "USD · $", symbol: "$", localeIdentifier: "en_US", systemIconName: "dollarsign.circle"),
        Option(code: "EUR", displayName: "EUR · €", symbol: "€", localeIdentifier: "de_DE", systemIconName: "eurosign.circle"),
        Option(code: "GBP", displayName: "GBP · £", symbol: "£", localeIdentifier: "en_GB", systemIconName: "sterlingsign.circle"),
        Option(code: "JPY", displayName: "JPY · ¥", symbol: "¥", localeIdentifier: "ja_JP", systemIconName: "yensign.circle"),
        Option(code: "HKD", displayName: "HKD · HK$", symbol: "HK$", localeIdentifier: "zh_HK", systemIconName: "dollarsign.circle"),
        Option(code: "TWD", displayName: "TWD · NT$", symbol: "NT$", localeIdentifier: "zh_TW", systemIconName: "dollarsign.circle")
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? fallbackCode)
    }

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return supported.contains { $0.code == upper } ? upper : fallbackCode
    }

    static var currentOption: Option {
        supported.first { $0.code == code } ?? supported[0]
    }

    static var symbol: String { currentOption.symbol }
    static var systemIconName: String { currentOption.systemIconName }

    static func format(_ amount: Double, fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: currentOption.localeIdentifier)
        formatter.currencyCode = currentOption.code
        formatter.currencySymbol = currentOption.symbol
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currentOption.symbol)\(amount)"
    }

    static func formatCompact(_ amount: Double) -> String {
        if amount >= 10_000 {
            return "\(symbol)\(String(format: "%.0fk", amount / 1_000))"
        }
        if amount >= 100 {
            return format(amount, fractionDigits: 0)
        }
        return amount > 0 ? format(amount, fractionDigits: 1) : format(0, fractionDigits: 0)
    }
}

// MARK: - App country / region (国家默认偏好映射)

nonisolated enum AppCountry {
    struct Option: Identifiable, Hashable {
        let code: String
        let displayName: AppLocalizedText
        let flag: String
        let defaultLanguageCode: String
        let defaultCurrencyCode: String
        let defaultMeasurementSystemCode: String

        var id: String { code }

        func title(_ languageCode: String = AppLanguage.code) -> String {
            "\(flag) \(displayName.resolve(languageCode))"
        }
    }

    static let storageKey = "appCountry"
    static let fallbackCode = "CN"

    static let supported: [Option] = [
        Option(
            code: "CN",
            displayName: AppLocalizedText(zh: "中国大陆", en: "Mainland China", de: "Festlandchina"),
            flag: "🇨🇳",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "CNY",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "US",
            displayName: AppLocalizedText(zh: "美国", en: "United States", de: "Vereinigte Staaten"),
            flag: "🇺🇸",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "USD",
            defaultMeasurementSystemCode: "imperial"
        ),
        Option(
            code: "DE",
            displayName: AppLocalizedText(zh: "德国", en: "Germany", de: "Deutschland"),
            flag: "🇩🇪",
            defaultLanguageCode: "de",
            defaultCurrencyCode: "EUR",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "GB",
            displayName: AppLocalizedText(zh: "英国", en: "United Kingdom", de: "Vereinigtes Königreich"),
            flag: "🇬🇧",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "GBP",
            defaultMeasurementSystemCode: "imperial"
        ),
        Option(
            code: "JP",
            displayName: AppLocalizedText(zh: "日本", en: "Japan", de: "Japan"),
            flag: "🇯🇵",
            defaultLanguageCode: "en",
            defaultCurrencyCode: "JPY",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "HK",
            displayName: AppLocalizedText(zh: "中国香港", en: "Hong Kong", de: "Hongkong"),
            flag: "🇭🇰",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "HKD",
            defaultMeasurementSystemCode: "metric"
        ),
        Option(
            code: "TW",
            displayName: AppLocalizedText(zh: "中国台湾", en: "Taiwan", de: "Taiwan"),
            flag: "🇹🇼",
            defaultLanguageCode: "zh",
            defaultCurrencyCode: "TWD",
            defaultMeasurementSystemCode: "metric"
        )
    ]

    static var code: String {
        normalize(UserDefaults.standard.string(forKey: storageKey) ?? detectedCode)
    }

    static var detectedCode: String {
        let regionCode = Locale.current.region?.identifier.uppercased()
        if let regionCode, supported.contains(where: { $0.code == regionCode }) {
            return regionCode
        }

        let languageCode = Locale.current.language.languageCode?.identifier.lowercased()
        switch languageCode {
        case "de":
            return "DE"
        case "en":
            return "US"
        default:
            return fallbackCode
        }
    }

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return supported.contains { $0.code == upper } ? upper : fallbackCode
    }

    static var currentOption: Option {
        option(for: code)
    }

    static func option(for raw: String) -> Option {
        supported.first { $0.code == normalize(raw) } ?? supported[0]
    }

    static func ensureInitialized() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: storageKey) == nil else { return }

        let selected = option(for: detectedCode)
        defaults.set(selected.code, forKey: storageKey)

        if defaults.object(forKey: "appLanguage") == nil {
            defaults.set(AppLanguage.normalize(selected.defaultLanguageCode), forKey: "appLanguage")
        }
        if defaults.object(forKey: AppCurrency.storageKey) == nil {
            defaults.set(AppCurrency.normalize(selected.defaultCurrencyCode), forKey: AppCurrency.storageKey)
        }
        if defaults.object(forKey: AppMeasurementSystem.storageKey) == nil {
            defaults.set(AppMeasurementSystem.normalize(selected.defaultMeasurementSystemCode), forKey: AppMeasurementSystem.storageKey)
        }
    }

    static func applyDefaults(for countryCode: String) {
        let selected = option(for: countryCode)
        let defaults = UserDefaults.standard
        defaults.set(selected.code, forKey: storageKey)
        defaults.set(AppLanguage.normalize(selected.defaultLanguageCode), forKey: "appLanguage")
        defaults.set(AppCurrency.normalize(selected.defaultCurrencyCode), forKey: AppCurrency.storageKey)
        defaults.set(AppMeasurementSystem.normalize(selected.defaultMeasurementSystemCode), forKey: AppMeasurementSystem.storageKey)
    }
}
