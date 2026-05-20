//
//  DesignSpecTypesV4.swift
//  Ohana
//
//  Lightweight design-system tokens for the developer UI guidelines console.
//

import Foundation
import SwiftUI

enum DesignPreviewModeV4: String, CaseIterable, Identifiable, Codable {
    case dark
    case light

    var id: String { rawValue }
    var zh: String { self == .dark ? "深色" : "浅色" }
    var en: String { self == .dark ? "Dark" : "Light" }
    var icon: String { self == .dark ? "moon.fill" : "sun.max.fill" }
}

enum DesignBuilderStepV4: String, CaseIterable, Identifiable {
    case background
    case card
    case button
    case input
    case controls
    case text
    case navigation
    case sheet
    case chart
    case calendar
    case feedback
    case motion

    var id: String { rawValue }

    var zh: String {
        switch self {
        case .background: return "背景"
        case .card: return "卡片"
        case .button: return "按钮"
        case .input: return "输入"
        case .controls: return "控件"
        case .text: return "文字"
        case .navigation: return "导航"
        case .sheet: return "弹窗"
        case .chart: return "图表"
        case .calendar: return "日历"
        case .feedback: return "反馈"
        case .motion: return "动效"
        }
    }

    var en: String {
        switch self {
        case .background: return "Background"
        case .card: return "Card"
        case .button: return "Button"
        case .input: return "Input"
        case .controls: return "Controls"
        case .text: return "Text"
        case .navigation: return "Navigation"
        case .sheet: return "Sheet"
        case .chart: return "Chart"
        case .calendar: return "Calendar"
        case .feedback: return "Feedback"
        case .motion: return "Motion"
        }
    }

    var icon: String {
        switch self {
        case .background: return "paintpalette.fill"
        case .card: return "rectangle.on.rectangle.angled.fill"
        case .button: return "capsule.fill"
        case .input: return "keyboard.fill"
        case .controls: return "switch.2"
        case .text: return "textformat"
        case .navigation: return "rectangle.topthird.inset.filled"
        case .sheet: return "rectangle.bottomthird.inset.filled"
        case .chart: return "chart.xyaxis.line"
        case .calendar: return "calendar"
        case .feedback: return "bell.badge.fill"
        case .motion: return "sparkles"
        }
    }
}

enum DesignSpecComponentStateV4: String, CaseIterable, Identifiable, Codable {
    case normal
    case pressed
    case selected
    case focused
    case disabled
    case loading
    case empty
    case error
    case warning
    case success
    case locked

    var id: String { rawValue }

    var zh: String {
        switch self {
        case .normal: return "正常"
        case .pressed: return "按下"
        case .selected: return "选中"
        case .focused: return "聚焦"
        case .disabled: return "禁用"
        case .loading: return "加载"
        case .empty: return "空"
        case .error: return "错误"
        case .warning: return "警告"
        case .success: return "成功"
        case .locked: return "锁定"
        }
    }

    var en: String {
        switch self {
        case .normal: return "Normal"
        case .pressed: return "Pressed"
        case .selected: return "Selected"
        case .focused: return "Focused"
        case .disabled: return "Disabled"
        case .loading: return "Loading"
        case .empty: return "Empty"
        case .error: return "Error"
        case .warning: return "Warning"
        case .success: return "Success"
        case .locked: return "Locked"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "circle"
        case .pressed: return "hand.tap.fill"
        case .selected: return "checkmark.circle.fill"
        case .focused: return "scope"
        case .disabled: return "slash.circle"
        case .loading: return "hourglass"
        case .empty: return "tray"
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.seal.fill"
        case .locked: return "lock.fill"
        }
    }
}

struct DesignSpecSelectionV4: Codable, Equatable {
    var background: String
    var accent: String
    var card: String
    var glass: String
    var density: String
    var button: String
    var tap: String
    var input: String
    var inputState: String
    var toggle: String
    var chip: String
    var segment: String
    var progress: String
    var type: String
    var icon: String
    var settingIcon: String
    var navigation: String
    var pageBackButton: String
    var pageCloseButton: String
    var listRow: String
    var badge: String
    var sheet: String
    var sheetTransparency: String
    var sheetChrome: String
    var sheetGlass: String
    var sheetCard: String
    var sheetInput: String
    var sheetButton: String
    var chartLine: String
    var chartAxis: String
    var calendarLayout: String = "agendaHybrid"
    var calendarDay: String = "glassTile"
    var calendarEvent: String = "dots"
    var calendarAgenda: String = "timeRail"
    var toast: String
    var banner: String
    var haptic: String
    var motion: String
    var fabMotion: String
    var transition: String
    var reward: String

    static let ohanaDefault = DesignSpecSelectionV4(
        background: "deep",
        accent: "lime",
        card: "flat",
        glass: "clear",
        density: "compact",
        button: "pill",
        tap: "spring",
        input: "flat",
        inputState: "clear",
        toggle: "pill",
        chip: "pill",
        segment: "capsule",
        progress: "bar",
        type: "rounded",
        icon: "monochromePrimary",
        settingIcon: "plainGlyph",
        navigation: "floating",
        pageBackButton: "floatingCircle",
        pageCloseButton: "iconOnly",
        listRow: "filled",
        badge: "solid",
        sheet: "compact",
        sheetTransparency: "clear",
        sheetChrome: "iconOnly",
        sheetGlass: "nativeRegular",
        sheetCard: "flat",
        sheetInput: "flat",
        sheetButton: "pill",
        chartLine: "area",
        chartAxis: "quiet",
        calendarLayout: "agendaHybrid",
        calendarDay: "minimalNumber",
        calendarEvent: "dots",
        calendarAgenda: "timeRail",
        toast: "icon",
        banner: "inline",
        haptic: "soft",
        motion: "spring",
        fabMotion: "rotate",
        transition: "scale",
        reward: "bouncy"
    )

    var tokenSummary: [String: String] {
        [
            "background": background,
            "accent": accent,
            "card": card,
            "glass": glass,
            "density": density,
            "button": button,
            "tap": tap,
            "input": input,
            "inputState": inputState,
            "toggle": toggle,
            "chip": chip,
            "segment": segment,
            "progress": progress,
            "type": type,
            "icon": icon,
            "settingIcon": settingIcon,
            "navigation": navigation,
            "pageBackButton": pageBackButton,
            "pageCloseButton": pageCloseButton,
            "listRow": listRow,
            "badge": badge,
            "sheet": sheet,
            "sheetTransparency": sheetTransparency,
            "sheetChrome": sheetChrome,
            "sheetGlass": sheetGlass,
            "sheetCard": sheetCard,
            "sheetInput": sheetInput,
            "sheetButton": sheetButton,
            "chartLine": chartLine,
            "chartAxis": chartAxis,
            "calendarLayout": calendarLayout,
            "calendarDay": calendarDay,
            "calendarEvent": calendarEvent,
            "calendarAgenda": calendarAgenda,
            "toast": toast,
            "banner": banner,
            "haptic": haptic,
            "motion": motion,
            "fabMotion": fabMotion,
            "transition": transition,
            "reward": reward
        ]
    }

    static func decode(from string: String) -> DesignSpecSelectionV4? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DesignSpecSelectionV4.self, from: data)
    }

    static func fromLegacyJSONString(_ string: String) -> DesignSpecSelectionV4? {
        guard let data = string.data(using: .utf8),
              let legacy = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        var value = DesignSpecSelectionV4.ohanaDefault
        value.background = legacy["background"] ?? value.background
        value.accent = legacy["accent"] ?? value.accent
        value.card = legacy["card"] ?? value.card
        value.glass = legacy["glass"] ?? value.glass
        value.density = legacy["density"] ?? value.density
        value.button = legacy["button"] ?? value.button
        value.tap = legacy["tap"] ?? value.tap
        value.input = legacy["input"] ?? value.input
        value.inputState = legacy["inputState"] ?? value.inputState
        value.toggle = legacy["toggle"] ?? value.toggle
        value.chip = legacy["chip"] ?? value.chip
        value.segment = legacy["segment"] ?? value.segment
        value.progress = legacy["progress"] ?? value.progress
        value.type = legacy["type"] ?? value.type
        value.icon = Self.normalizedIcon(legacy["icon"] ?? value.icon)
        value.settingIcon = Self.normalizedSettingIcon(legacy["settingIcon"] ?? value.settingIcon)
        value.navigation = legacy["navigation"] ?? value.navigation
        value.pageBackButton = legacy["pageBackButton"] ?? value.pageBackButton
        value.pageCloseButton = legacy["pageCloseButton"] ?? value.pageCloseButton
        value.listRow = legacy["listRow"] ?? value.listRow
        value.badge = legacy["badge"] ?? value.badge
        value.sheet = legacy["sheet"] ?? value.sheet
        value.sheetTransparency = legacy["sheetTransparency"] ?? value.sheetTransparency
        value.sheetChrome = legacy["sheetChrome"] ?? value.sheetChrome
        value.sheetGlass = legacy["sheetGlass"] ?? legacy["glass"] ?? value.sheetGlass
        value.sheetCard = legacy["sheetCard"] ?? legacy["card"] ?? value.sheetCard
        value.sheetInput = legacy["sheetInput"] ?? legacy["input"] ?? value.sheetInput
        value.sheetButton = legacy["sheetButton"] ?? legacy["button"] ?? value.sheetButton
        value.chartLine = legacy["chartLine"] ?? value.chartLine
        value.chartAxis = legacy["chartAxis"] ?? value.chartAxis
        value.calendarLayout = legacy["calendarLayout"] ?? value.calendarLayout
        value.calendarDay = legacy["calendarDay"] ?? value.calendarDay
        value.calendarEvent = legacy["calendarEvent"] ?? value.calendarEvent
        value.calendarAgenda = legacy["calendarAgenda"] ?? value.calendarAgenda
        value.toast = legacy["toast"] ?? value.toast
        value.haptic = legacy["haptic"] ?? value.haptic
        value.motion = legacy["motion"] ?? value.motion
        value.fabMotion = legacy["fabMotion"] ?? value.fabMotion
        value.transition = legacy["transition"] ?? value.transition
        return value
    }

    func encodedString(pretty: Bool) -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

extension DesignSpecSelectionV4 {
    private enum CodingKeys: String, CodingKey {
        case background
        case accent
        case card
        case glass
        case density
        case button
        case tap
        case input
        case inputState
        case toggle
        case chip
        case segment
        case progress
        case type
        case icon
        case settingIcon
        case navigation
        case pageBackButton
        case pageCloseButton
        case listRow
        case badge
        case sheet
        case sheetTransparency
        case sheetChrome
        case sheetGlass
        case sheetCard
        case sheetInput
        case sheetButton
        case chartLine
        case chartAxis
        case calendarLayout
        case calendarDay
        case calendarEvent
        case calendarAgenda
        case toast
        case banner
        case haptic
        case motion
        case fabMotion
        case transition
        case reward
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DesignSpecSelectionV4.ohanaDefault
        background = try container.decodeIfPresent(String.self, forKey: .background) ?? defaults.background
        accent = try container.decodeIfPresent(String.self, forKey: .accent) ?? defaults.accent
        card = try container.decodeIfPresent(String.self, forKey: .card) ?? defaults.card
        glass = try container.decodeIfPresent(String.self, forKey: .glass) ?? defaults.glass
        density = try container.decodeIfPresent(String.self, forKey: .density) ?? defaults.density
        button = try container.decodeIfPresent(String.self, forKey: .button) ?? defaults.button
        tap = try container.decodeIfPresent(String.self, forKey: .tap) ?? defaults.tap
        input = try container.decodeIfPresent(String.self, forKey: .input) ?? defaults.input
        inputState = try container.decodeIfPresent(String.self, forKey: .inputState) ?? defaults.inputState
        toggle = try container.decodeIfPresent(String.self, forKey: .toggle) ?? defaults.toggle
        chip = try container.decodeIfPresent(String.self, forKey: .chip) ?? defaults.chip
        segment = try container.decodeIfPresent(String.self, forKey: .segment) ?? defaults.segment
        progress = try container.decodeIfPresent(String.self, forKey: .progress) ?? defaults.progress
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? defaults.type
        icon = Self.normalizedIcon(try container.decodeIfPresent(String.self, forKey: .icon) ?? defaults.icon)
        settingIcon = Self.normalizedSettingIcon(try container.decodeIfPresent(String.self, forKey: .settingIcon) ?? defaults.settingIcon)
        navigation = try container.decodeIfPresent(String.self, forKey: .navigation) ?? defaults.navigation
        pageBackButton = try container.decodeIfPresent(String.self, forKey: .pageBackButton) ?? defaults.pageBackButton
        pageCloseButton = try container.decodeIfPresent(String.self, forKey: .pageCloseButton) ?? defaults.pageCloseButton
        listRow = try container.decodeIfPresent(String.self, forKey: .listRow) ?? defaults.listRow
        badge = try container.decodeIfPresent(String.self, forKey: .badge) ?? defaults.badge
        sheet = try container.decodeIfPresent(String.self, forKey: .sheet) ?? defaults.sheet
        sheetTransparency = try container.decodeIfPresent(String.self, forKey: .sheetTransparency) ?? defaults.sheetTransparency
        sheetChrome = try container.decodeIfPresent(String.self, forKey: .sheetChrome) ?? defaults.sheetChrome
        sheetGlass = try container.decodeIfPresent(String.self, forKey: .sheetGlass) ?? (try container.decodeIfPresent(String.self, forKey: .glass) ?? defaults.sheetGlass)
        sheetCard = try container.decodeIfPresent(String.self, forKey: .sheetCard) ?? (try container.decodeIfPresent(String.self, forKey: .card) ?? defaults.sheetCard)
        sheetInput = try container.decodeIfPresent(String.self, forKey: .sheetInput) ?? (try container.decodeIfPresent(String.self, forKey: .input) ?? defaults.sheetInput)
        sheetButton = try container.decodeIfPresent(String.self, forKey: .sheetButton) ?? (try container.decodeIfPresent(String.self, forKey: .button) ?? defaults.sheetButton)
        chartLine = try container.decodeIfPresent(String.self, forKey: .chartLine) ?? defaults.chartLine
        chartAxis = try container.decodeIfPresent(String.self, forKey: .chartAxis) ?? defaults.chartAxis
        calendarLayout = try container.decodeIfPresent(String.self, forKey: .calendarLayout) ?? defaults.calendarLayout
        calendarDay = try container.decodeIfPresent(String.self, forKey: .calendarDay) ?? defaults.calendarDay
        calendarEvent = try container.decodeIfPresent(String.self, forKey: .calendarEvent) ?? defaults.calendarEvent
        calendarAgenda = try container.decodeIfPresent(String.self, forKey: .calendarAgenda) ?? defaults.calendarAgenda
        toast = try container.decodeIfPresent(String.self, forKey: .toast) ?? defaults.toast
        banner = try container.decodeIfPresent(String.self, forKey: .banner) ?? defaults.banner
        haptic = try container.decodeIfPresent(String.self, forKey: .haptic) ?? defaults.haptic
        motion = try container.decodeIfPresent(String.self, forKey: .motion) ?? defaults.motion
        fabMotion = try container.decodeIfPresent(String.self, forKey: .fabMotion) ?? defaults.fabMotion
        transition = try container.decodeIfPresent(String.self, forKey: .transition) ?? defaults.transition
        reward = try container.decodeIfPresent(String.self, forKey: .reward) ?? defaults.reward
    }
}

fileprivate extension DesignSpecSelectionV4 {
    static func normalizedIcon(_ rawValue: String) -> String {
        switch rawValue {
        case "monochromePrimary":
            return rawValue
        default:
            return ohanaDefault.icon
        }
    }

    static func normalizedSettingIcon(_ rawValue: String) -> String {
        switch rawValue {
        case "plainGlyph":
            return rawValue
        default:
            return ohanaDefault.settingIcon
        }
    }
}

struct DesignSpecAuditResultV4: Identifiable, Codable {
    enum Status: String, Codable {
        case pass
        case warning
        case fail
    }

    let id: String
    let titleZh: String
    let titleEn: String
    let detailZh: String
    let detailEn: String
    let status: Status
    let icon: String
}

struct DesignSpecOptionV4: Identifiable {
    let id: String
    let zh: String
    let en: String
    let zhDescription: String
    let enDescription: String
    let icon: String
    let tint: Color
    let recommended: Bool
    let goodFor: [String]
    let avoidFor: [String]

    init(
        _ id: String,
        _ zh: String,
        _ en: String,
        _ zhDescription: String,
        _ enDescription: String,
        _ icon: String,
        _ tint: Color,
        recommended: Bool = false,
        goodFor: [String] = [],
        avoidFor: [String] = []
    ) {
        self.id = id
        self.zh = zh
        self.en = en
        self.zhDescription = zhDescription
        self.enDescription = enDescription
        self.icon = icon
        self.tint = tint
        self.recommended = recommended
        self.goodFor = goodFor
        self.avoidFor = avoidFor
    }
}
