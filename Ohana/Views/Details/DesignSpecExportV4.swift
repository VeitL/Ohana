//
//  DesignSpecExportV4.swift
//  Ohana
//

import Foundation

enum DesignSpecAuditEngineV4 {
    static func results(for selection: DesignSpecSelectionV4) -> [DesignSpecAuditResultV4] {
        [
            contrast(selection),
            touchTarget(selection),
            glassReadability(selection),
            motionIntensity(selection),
            stateCoverage(selection),
            navigationChrome(selection),
            hardcodedColorRisk(selection)
        ]
    }

    private static func contrast(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let risky = selection.accent == "violet" && selection.background == "deep"
        return DesignSpecAuditResultV4(
            id: "contrast",
            titleZh: "文字对比",
            titleEn: "Text Contrast",
            detailZh: risky ? "柔紫配深色需检查小字。" : "主文本/按钮组合安全。",
            detailEn: risky ? "Violet on deep backgrounds needs small-text checks." : "Primary text and buttons are safe.",
            status: risky ? .warning : .pass,
            icon: "textformat.size"
        )
    }

    private static func touchTarget(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let compact = selection.button == "compact" || selection.density == "compact"
        return DesignSpecAuditResultV4(
            id: "touchTarget",
            titleZh: "触控区域",
            titleEn: "Touch Target",
            detailZh: compact ? "紧凑模式要保持 44pt 点击区。" : "按钮高度符合高频操作。",
            detailEn: compact ? "Compact controls must retain 44pt hit areas." : "Button height supports frequent use.",
            status: compact ? .warning : .pass,
            icon: "hand.tap.fill"
        )
    }

    private static func glassReadability(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let clearRisk = selection.sheetGlass == "refractive" || selection.sheetGlass == "nativeRegular" || selection.sheetGlass == "clear" || selection.sheetGlass == "edgePrism"
        return DesignSpecAuditResultV4(
            id: "glassReadability",
            titleZh: "玻璃可读性",
            titleEn: "Glass Readability",
            detailZh: clearRisk ? "高透玻璃必须搭配轻遮罩、细描边和鲜艳背景测试。" : "玻璃厚度和文字可读性平衡。",
            detailEn: clearRisk ? "Transparent glass needs a light scrim, thin stroke, and vivid-backdrop testing." : "Glass depth and readability are balanced.",
            status: clearRisk ? .warning : .pass,
            icon: "sparkles"
        )
    }

    private static func motionIntensity(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let intense = selection.motion == "playful" || selection.fabMotion == "fan" || selection.reward == "confetti"
        return DesignSpecAuditResultV4(
            id: "motionIntensity",
            titleZh: "动效强度",
            titleEn: "Motion Intensity",
            detailZh: intense ? "强动效只建议用于奖励。" : "动效适合高频页面。",
            detailEn: intense ? "Strong motion should stay in reward moments." : "Motion is safe for frequent screens.",
            status: intense ? .warning : .pass,
            icon: "sparkles"
        )
    }

    private static func stateCoverage(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let subtle = selection.inputState == "subtle" && selection.toast == "silent"
        return DesignSpecAuditResultV4(
            id: "stateCoverage",
            titleZh: "状态可见",
            titleEn: "State Visibility",
            detailZh: subtle ? "输入和反馈都偏安静，错误需加强。" : "错误、锁定、成功状态可识别。",
            detailEn: subtle ? "Inputs and feedback are quiet; errors need emphasis." : "Error, locked, and success states are identifiable.",
            status: subtle ? .warning : .pass,
            icon: "seal.fill"
        )
    }

    private static func hardcodedColorRisk(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        DesignSpecAuditResultV4(
            id: "hardcodedColorRisk",
            titleZh: "深浅色安全",
            titleEn: "Theme Safety",
            detailZh: "预览使用 token 色，不依赖硬编码白/黑。",
            detailEn: "Preview uses token colors, not hardcoded white/black.",
            status: .pass,
            icon: "moon.stars.fill"
        )
    }

    private static func navigationChrome(_ selection: DesignSpecSelectionV4) -> DesignSpecAuditResultV4 {
        let heavy = selection.pageCloseButton == "pill" && selection.sheetChrome == "pillClose"
        return DesignSpecAuditResultV4(
            id: "navigationChrome",
            titleZh: "导航与关闭",
            titleEn: "Navigation Chrome",
            detailZh: heavy ? "页面关闭和弹窗关闭都偏重，确认是否必要。" : "设置图标、页面返回、页面关闭和弹窗关闭都有独立 token。",
            detailEn: heavy ? "Both page close and sheet close are heavy; confirm the need." : "Settings icons, page back, page close, and sheet close have explicit tokens.",
            status: heavy ? .warning : .pass,
            icon: "chevron.left.forwardslash.chevron.right"
        )
    }
}

struct DesignSpecExportPayloadV4: Codable {
    let version: Int
    let generatedAt: String
    let note: String
    let selection: DesignSpecSelectionV4
    let resolvedTokens: [String: String]
    let componentRules: [String: String]
    let sceneCoverage: [String]
    let accessibilityAudit: [DesignSpecAuditResultV4]
}

enum DesignSpecExporterV4 {
    static func payload(selection: DesignSpecSelectionV4, mode: DesignPreviewModeV4) -> DesignSpecExportPayloadV4 {
        let palette = DesignSpecPaletteV4(selection: selection, mode: mode)
        return DesignSpecExportPayloadV4(
            version: 4,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            note: "Ohana UI guidelines console V4. Preview uses fixture data only and does not mutate app theme.",
            selection: selection,
            resolvedTokens: selection.tokenSummary.merging(palette.resolvedTokenSummary) { current, _ in current },
            componentRules: componentRules(selection),
            sceneCoverage: [
                "allElements: 全元素总览 / All iOS UI elements in one canvas",
                "navigationChrome: 设置行左图标、非弹窗返回/关闭、弹窗关闭 / Settings row icons, page back/close, and sheet close",
                "calendar: 日历、日程与提醒设计 / Calendar, agenda, and reminder design",
                "sheetOverlay: 弹窗覆盖层 / Interactive sheet overlay"
            ],
            accessibilityAudit: DesignSpecAuditEngineV4.results(for: selection)
        )
    }

    static func json(selection: DesignSpecSelectionV4, mode: DesignPreviewModeV4) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload(selection: selection, mode: mode)),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func markdown(selection: DesignSpecSelectionV4, mode: DesignPreviewModeV4) -> String {
        let export = payload(selection: selection, mode: mode)
        let tokens = export.resolvedTokens
            .sorted { $0.key < $1.key }
            .map { "- `\($0.key)`: \($0.value)" }
            .joined(separator: "\n")
        let rules = export.componentRules
            .sorted { $0.key < $1.key }
            .map { "- **\($0.key)**: \($0.value)" }
            .joined(separator: "\n")
        let audit = export.accessibilityAudit
            .map { "- \($0.titleZh) / \($0.titleEn): \($0.status.rawValue) — \($0.detailZh)" }
            .joined(separator: "\n")

        return """
        # Ohana UI 规范选择 V4

        Generated: \(export.generatedAt)

        ## Tokens
        \(tokens)

        ## Component Rules
        \(rules)

        ## Scene Coverage
        \(export.sceneCoverage.map { "- \($0)" }.joined(separator: "\n"))

        ## Accessibility Audit
        \(audit)

        ## Notes
        - 预览只使用固定样例数据，不读取真实 SwiftData。
        - 本选择不动态改变全 app，只作为后续 UI 修改的设计依据。
        - 后续实现页面时优先遵循 `docs/design/ui规范.md` 与 `ui规范.selection.json`。
        """
    }

    static func defaultSelectionJSON() -> String {
        json(selection: .ohanaDefault, mode: .dark)
    }

    private static func componentRules(_ selection: DesignSpecSelectionV4) -> [String: String] {
        [
            "button": "Primary CTA uses \(selection.button); one primary action per screen.",
            "card": "Business surfaces use \(selection.card); sheet glass choices must not override the selected card style.",
            "sheet": "Sheets use independent tokens: \(selection.sheet) layout, \(selection.sheetGlass) background, \(selection.sheetCard) card, \(selection.sheetInput) input, \(selection.sheetButton) button, and \(selection.sheetChrome) chrome.",
            "icon": "Functional icons use \(selection.icon): SF Symbol or template vector glyphs in goPrimary only; no multicolor, skeuomorphic, emoji, or illustration-style glyphs for app controls.",
            "settingsIcon": "Settings rows use \(selection.settingIcon) leading icon treatment without colored tile backgrounds.",
            "navigationChrome": "Non-sheet pages use \(selection.pageBackButton) back controls and \(selection.pageCloseButton) close controls; sheets use \(selection.sheetChrome) independently.",
            "input": "Inputs use \(selection.input) style with \(selection.inputState) state emphasis.",
            "chart": "Charts use \(selection.chartLine) trend style and \(selection.chartAxis) axis treatment.",
            "calendar": "Calendar uses \(selection.calendarLayout) layout, \(selection.calendarDay) day cells, \(selection.calendarEvent) event markers, and \(selection.calendarAgenda) agenda rows.",
            "motion": "Motion uses \(selection.motion), FAB uses \(selection.fabMotion), transition uses \(selection.transition).",
            "motionContinuity": "All visible state changes must transition smoothly with the selected motion token; no hard cuts for controls, toggles, sheets, lists, charts, calendar, or theme changes.",
            "privacy": "Locked/private states must show icon + text placeholder and never leak values."
        ]
    }
}
