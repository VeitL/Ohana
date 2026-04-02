//
//  Localization.swift
//  Ohana
//
//  多语言支持：中/英切换，"ohana" 不翻译
//

import Foundation

struct L10n {
    let lang: String

    init(_ lang: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh") {
        self.lang = lang
    }

    var isEn: Bool { lang == "en" }

    // MARK: - Dock / Tab
    var tabHome: String { isEn ? "Home" : "首页" }
    var tabPlant: String { isEn ? "Plants" : "植物" }
    var tabCalendar: String { isEn ? "Calendar" : "日历" }
    var tabCrew: String { isEn ? "Crew" : "图鉴" }
    var tabOasis: String { isEn ? "Oasis" : "绿洲" }

    // MARK: - Global Header
    func greeting(_ text: String) -> String { text } // greeting 已由逻辑生成
    var ohanaCrew: String { isEn ? "Ohana Crew" : "Ohana 图鉴" }

    // MARK: - Greeting hints
    func morningHint(_ name: String) -> String { isEn ? "Take \(name) for a morning walk" : "带 \(name) 早晨出去走走吧" }
    func eveningHint(_ name: String) -> String { isEn ? "Golden hour — walk \(name) 🌇" : "黄金时段，带 \(name) 散个步 🌇" }
    func defaultHint(_ name: String) -> String { isEn ? "\(name) is waiting for you" : "\(name) 在等你呢" }

    var goodMorning: String { isEn ? "Good morning" : "早上好" }
    var goodAfternoon: String { isEn ? "Good afternoon" : "下午好" }
    var goodEvening: String { isEn ? "Good evening" : "晚上好" }
    var goodNight: String { isEn ? "Good night" : "晚安" }

    // MARK: - Settings
    var settings: String { isEn ? "Settings" : "设置" }
    var addMember: String { isEn ? "Add Member" : "添加成员" }
    var manageHome: String { isEn ? "Manage Home" : "管理主页" }
    var preferences: String { isEn ? "Preferences" : "偏好设置" }
    var language: String { isEn ? "Language" : "语言" }
    var appearance: String { isEn ? "Appearance" : "外观主题" }
    var backgroundStyle: String { isEn ? "Background Style" : "背景风格" }
    var notifications: String { isEn ? "Notifications" : "通知" }
    var about: String { isEn ? "About" : "关于" }
    var petManagement: String { isEn ? "Pet Management" : "宠物管理" }
    var clearAllData: String { isEn ? "Clear All Data" : "清除所有数据" }
    var notificationPermission: String { isEn ? "Notification Permission" : "通知权限" }
    var manageNotification: String { isEn ? "Manage notification settings" : "管理通知设置" }
    var deviceIdentity: String { isEn ? "Device Identity" : "设备身份" }
    var nickname: String { isEn ? "Nickname" : "昵称" }

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
    var save: String { isEn ? "Save" : "保存" }
    var cancel: String { isEn ? "Cancel" : "取消" }
    var confirm: String { isEn ? "Confirm" : "确认" }
    var done: String { isEn ? "Done" : "完成" }
    var search: String { isEn ? "Search" : "搜索" }
    func searchPlaceholder(_ text: String) -> String { isEn ? "Search \(text)..." : "搜索\(text)..." }
    var times: String { isEn ? "times" : "次" }
    var types: String { isEn ? "types" : "种" }
    var items: String { isEn ? "items" : "条" }

    // MARK: - Pet Species
    var dog: String { isEn ? "Dog" : "狗" }
    var cat: String { isEn ? "Cat" : "猫" }
    var rabbit: String { isEn ? "Rabbit" : "兔子" }
    var hamster: String { isEn ? "Hamster" : "仓鼠" }

    // MARK: - Calendar
    var monthView: String { isEn ? "Month" : "月视图" }
    var listView: String { isEn ? "List" : "列表" }
    var addEvent: String { isEn ? "Add Event" : "添加事件" }

    // MARK: - Oasis
    var oasis: String { isEn ? "Oasis" : "绿洲" }

    // MARK: - Crew Roster
    func searchCrewPlaceholder() -> String { isEn ? "Search island residents..." : "搜索岛民..." }

    // MARK: - Batch Actions
    var batchCheckIn: String { isEn ? "Quick Check-in" : "一键全家" }
}
