//
//  DesignSpecOptionCatalogV4.swift
//  Ohana
//

import SwiftUI

enum DesignSpecOptionCatalogV4 {
    static let backgrounds = [
        DesignSpecOptionV4("goGradient", "GO 渐变", "GO Gradient", "品牌感强，适合主路径。", "Brand-led, best for primary flows.", "circle.hexagongrid.fill", Color.goPrimary, recommended: true, goodFor: ["首页", "开发者预览"], avoidFor: ["长表单"]),
        DesignSpecOptionV4("deep", "深色极光", "Deep Aurora", "沉浸感强，适合夜间。", "Immersive and dark-mode first.", "moon.stars.fill", Color.goPurple, goodFor: ["深色模式", "图表"], avoidFor: ["浅色模式"]),
        DesignSpecOptionV4("soft", "浅色柔光", "Soft Light", "清爽、低压力。", "Clean and low-friction.", "sun.max.fill", Color.goBlue, goodFor: ["设置", "表单"], avoidFor: ["强视觉首页"]),
        DesignSpecOptionV4("plain", "纯净", "Plain", "最稳定，性能风险低。", "Most stable and low-risk.", "rectangle.fill", Color.goTeal, goodFor: ["长列表", "工具页"], avoidFor: ["品牌首屏"])
    ]

    static let accents = [
        DesignSpecOptionV4("lime", "模式自适应", "Adaptive", "全局唯一主操作色：深色使用荧光绿，浅色自动解析为清爽蓝。", "The single global action color: lime in dark mode, blue in light mode.", "sparkles", Color.goPrimary, recommended: true, goodFor: ["主 CTA", "确认", "选中态", "功能入口"]),
        DesignSpecOptionV4("blue", "清爽蓝", "Blue", "适合信息和水相关功能。", "Good for information and water flows.", "drop.fill", Color.goBlue, goodFor: ["喂水", "设置"]),
        DesignSpecOptionV4("coral", "暖珊瑚", "Coral", "更亲近，适合奖励反馈。", "Warm and reward-friendly.", "heart.fill", Color.goOrange, goodFor: ["零食", "奖励"], avoidFor: ["错误状态"]),
        DesignSpecOptionV4("violet", "柔紫", "Violet", "有高级感，但需注意对比度。", "Premium, but needs contrast checks.", "moon.fill", Color.goPurple, goodFor: ["夜间", "图表"])
    ]

    static let cards = [
        DesignSpecOptionV4("glass", "透明玻璃", "Glass", "只用于明确的弹窗、系统 chrome 或 Liquid Glass 展示。", "Only for explicit sheets, system chrome, or Liquid Glass showcases.", "square.stack.3d.up.fill", Color.goPrimary, goodFor: ["弹窗", "设计实验"], avoidFor: ["普通业务卡片", "长列表", "低对比背景"]),
        DesignSpecOptionV4("solid", "实色", "Solid", "可读性最稳。", "Most readable and predictable.", "rectangle.fill", Color.goBlue, goodFor: ["表单", "长列表"]),
        DesignSpecOptionV4("flat", "纯色无边框", "Flat Block", "默认业务表面：纯色块、无描边、无阴影，靠背景层级和间距分组。", "Default business surface: solid block, no stroke or shadow; grouping comes from surface rhythm and spacing.", "rectangle.inset.filled", Color.goTeal, recommended: true, goodFor: ["极简表单", "密集工具页", "高频卡片"]),
        DesignSpecOptionV4("elevated", "浮层", "Elevated", "只给需要浮在内容上的关键层级。", "Only for critical layers that truly float above content.", "rectangle.on.rectangle.angled.fill", Color.goPurple, goodFor: ["弹窗", "关键浮层"], avoidFor: ["普通卡片", "密集列表"]),
        DesignSpecOptionV4("tinted", "轻彩色", "Tinted", "有情绪但不抢内容。", "Expressive without overpowering content.", "paintbrush.pointed.fill", Color.goTeal, goodFor: ["状态卡"])
    ]

    static let glass = [
        DesignSpecOptionV4("calendarWidget", "日历 Widget", "Calendar Widget", "深紫半透明底 + 青蓝折射光，接近 macOS 桌面日历 widget。", "Deep violet translucent base with cyan refraction.", "calendar", Color.goPurple, goodFor: ["深色弹窗", "overview"]),
        DesignSpecOptionV4("refractive", "控件高斯", "Control Gaussian", "原生 glassEffect + 顶部深浅色开关同款控件底、细描边和高光。", "Native glassEffect with the top theme switch control fill, fine stroke, and highlight.", "switch.2", Color.goBlue, recommended: true, goodFor: ["弹窗", "数字键盘", "操作浮层"], avoidFor: ["复杂彩色文字"]),
        DesignSpecOptionV4("nativeRegular", "原生高斯", "Native Regular", "纯 .glassEffect(.regular)，不叠加 palette.controlFill。", "Pure .glassEffect(.regular) without palette.controlFill.", "circle.hexagongrid.fill", Color.goTeal, goodFor: ["测试真实系统折射", "轻弹窗"], avoidFor: ["需要稳定底色"]),
        DesignSpecOptionV4("clear", "原生清透", "Native Clear", "纯 .glassEffect(.clear)，最透明，适合检查背景穿透。", "Pure .glassEffect(.clear), the most transparent option for backdrop testing.", "sparkles", Color.goPrimary, goodFor: ["透明测试", "轻提示"], avoidFor: ["长文本"]),
        DesignSpecOptionV4("edgePrism", "光边棱镜", "Edge Prism", "原生 glassEffect + 轻彩色边缘光，有玻璃边界但不厚重。", "Native glassEffect with a subtle colored rim, defined but not heavy.", "diamond.fill", Color.goTeal, goodFor: ["高级弹窗", "奖励反馈"], avoidFor: ["极简表单"])
    ]

    static let densities = [
        DesignSpecOptionV4("compact", "紧凑", "Compact", "信息密度高。", "High information density.", "rectangle.compress.vertical", Color.goBlue, goodFor: ["设置", "历史"], avoidFor: ["新手流程"]),
        DesignSpecOptionV4("balanced", "平衡", "Balanced", "默认密度。", "Default density.", "rectangle.split.3x1.fill", Color.goPrimary, recommended: true, goodFor: ["大多数页面"]),
        DesignSpecOptionV4("airy", "舒展", "Airy", "更轻松，但一屏信息少。", "More breathable, less dense.", "rectangle.expand.vertical", Color.goPurple, goodFor: ["引导", "空状态"])
    ]

    static let buttons = [
        DesignSpecOptionV4("pill", "胶囊", "Pill", "主操作语法：全局主 CTA、确认和关键入口。", "Primary action grammar for global CTAs, confirmations, and key entry points.", "capsule.fill", Color.goPrimary, recommended: true, goodFor: ["主 CTA", "确认", "关键入口"]),
        DesignSpecOptionV4("round", "圆角矩形", "Rounded", "适合表单和管理页。", "Good for forms and management.", "rectangle.roundedtop.fill", Color.goBlue, goodFor: ["设置"]),
        DesignSpecOptionV4("compact", "紧凑", "Compact", "节省空间但触控风险高。", "Space-saving but touch-risky.", "minus.rectangle.fill", Color.goTeal, goodFor: ["工具栏"], avoidFor: ["主操作"]),
        DesignSpecOptionV4("square", "柔方", "Soft Square", "更像专业工具。", "More operational and tool-like.", "square.fill", Color.goOrange, goodFor: ["开发者页"])
    ]

    static let taps = [
        DesignSpecOptionV4("spring", "弹性", "Spring", "轻 scale/opacity + soft haptic，默认。", "Light scale/opacity plus soft haptic by default.", "hand.tap.fill", Color.goPrimary, recommended: true, goodFor: ["主操作", "高频按钮"]),
        DesignSpecOptionV4("tiny", "轻按", "Tiny", "最克制。", "Subtle and restrained.", "circle", Color.goBlue, goodFor: ["列表"]),
        DesignSpecOptionV4("deep", "深按", "Deep", "明确但可能偏重。", "Clear, but can feel heavy.", "arrow.down.circle.fill", Color.goOrange, goodFor: ["危险确认"], avoidFor: ["高频按钮", "列表行"]),
        DesignSpecOptionV4("bright", "亮度", "Bright", "适合奖励，不适合常规表单。", "Rewarding, not for routine forms.", "sun.max.fill", Color.goYellow, goodFor: ["奖励"], avoidFor: ["高频输入"])
    ]

    static let inputs = [
        DesignSpecOptionV4("glass", "玻璃", "Glass", "和弹窗一致。", "Matches glass sheets.", "keyboard.fill", Color.goPrimary, recommended: true, goodFor: ["轻表单"]),
        DesignSpecOptionV4("filled", "填充", "Filled", "最稳、最清晰。", "Most stable and readable.", "rectangle.fill", Color.goBlue, goodFor: ["金额", "数字"]),
        DesignSpecOptionV4("flat", "纯色无边框", "Flat Block", "纯色输入块，不显示边框。", "Solid input block without visible borders.", "rectangle.inset.filled", Color.goTeal, goodFor: ["极简表单", "快捷记录"]),
        DesignSpecOptionV4("underline", "下划线", "Underline", "轻，但错误状态不明显。", "Lightweight, weaker error visibility.", "underline", Color.goTeal, goodFor: ["短字段"], avoidFor: ["复杂表单"]),
        DesignSpecOptionV4("compact", "紧凑", "Compact", "用于密集编辑。", "For dense editing.", "rectangle.compress.vertical", Color.goOrange, goodFor: ["管理页"])
    ]

    static let inputStates = [
        DesignSpecOptionV4("clear", "清晰", "Clear", "状态明显但不过度。", "Clear without being loud.", "checkmark.seal.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("subtle", "轻状态", "Subtle", "克制，适合熟练用户。", "Restrained for expert flows.", "circle", Color.goBlue),
        DesignSpecOptionV4("errorFirst", "错误优先", "Error First", "错误状态更醒目。", "Makes errors more prominent.", "exclamationmark.triangle.fill", Color.goRed),
        DesignSpecOptionV4("glow", "焦点光", "Focus Glow", "高级但需避免过亮。", "Premium, but avoid over-glow.", "sparkles", Color.goPurple)
    ]

    static let toggles = [
        DesignSpecOptionV4("pill", "胶囊", "Pill", "系统熟悉感强。", "Familiar switch pattern.", "switch.2", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("lock", "锁图标", "Lock", "适合隐私。", "Best for privacy.", "lock.fill", Color.goYellow),
        DesignSpecOptionV4("text", "文字", "Text", "语义清楚但占空间。", "Clear but wider.", "checkmark.circle.fill", Color.goTeal),
        DesignSpecOptionV4("row", "整行", "Row", "适合设置页。", "Good for Settings rows.", "list.bullet.rectangle", Color.goBlue)
    ]

    static let chips = [
        DesignSpecOptionV4("pill", "胶囊标签", "Pill Chip", "用于筛选、快捷克数、时间范围。", "For filters, quick grams, and ranges.", "capsule.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("soft", "柔色标签", "Soft Chip", "浅色块，选中更温和。", "Soft tinted block with gentler selection.", "circle.lefthalf.filled", Color.goBlue),
        DesignSpecOptionV4("outline", "描边标签", "Outline Chip", "只用边线表达边界。", "Boundary is shown only by stroke.", "capsule", Color.goTeal),
        DesignSpecOptionV4("tiny", "小方标签", "Tiny Chip", "更像密集工具栏按钮。", "Compact square chip for dense toolbars.", "square.fill", Color.goOrange)
    ]

    static let segments = [
        DesignSpecOptionV4("capsule", "胶囊组", "Capsule", "当前推荐。", "Recommended default.", "rectangle.split.3x1.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("tabs", "标签页", "Tabs", "适合页面级切换。", "For page-level switching.", "rectangle.topthird.inset.filled", Color.goBlue),
        DesignSpecOptionV4("underline", "下划线", "Underline", "轻量、内容优先。", "Lightweight and content-first.", "underline", Color.goTeal),
        DesignSpecOptionV4("buttons", "按钮组", "Buttons", "操作感更强。", "More action-oriented.", "square.grid.3x1.fill.below.line.grid.1x2", Color.goPurple)
    ]

    static let progresses = [
        DesignSpecOptionV4("bar", "进度条", "Bar", "最易读。", "Most readable.", "chart.bar.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("ring", "进度环", "Ring", "适合卡片指标。", "Good for metric cards.", "circle.dashed", Color.goBlue),
        DesignSpecOptionV4("slider", "滑杆", "Slider", "适合可调值。", "For adjustable values.", "slider.horizontal.3", Color.goTeal),
        DesignSpecOptionV4("steps", "阶段点", "Steps", "适合流程进度。", "For process stages.", "circle.grid.cross.fill", Color.goOrange)
    ]

    static let types = [
        DesignSpecOptionV4("rounded", "圆体", "Rounded", "Ohana 默认。", "Ohana default.", "textformat", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("compact", "紧凑粗体", "Compact", "适合密集信息。", "For dense information.", "bold", Color.goBlue),
        DesignSpecOptionV4("editorial", "柔和展示", "Editorial", "更有温度。", "Warmer display style.", "textformat.size", Color.goPurple),
        DesignSpecOptionV4("mono", "数字强调", "Metric Mono", "适合金额/克数。", "For money and metrics.", "number", Color.goTeal)
    ]

    static let icons = [
        DesignSpecOptionV4("monochromePrimary", "全局单色", "Monochrome Primary", "所有功能 icon 统一 goPrimary，禁止彩色仿真/emoji。", "All functional icons use goPrimary only; no multicolor, skeuomorphic, or emoji glyphs.", "circle.grid.2x2.fill", Color.goPrimary, recommended: true, goodFor: ["导航", "快捷操作", "列表", "状态入口"])
    ]

    static let settingIcons = [
        DesignSpecOptionV4("plainGlyph", "纯符号", "Plain Glyph", "设置行无底块，只显示 goPrimary 单色符号。", "Settings rows use a goPrimary monochrome glyph without a tile background.", "circle", Color.goPrimary, recommended: true, goodFor: ["设置页", "表单行", "极简列表"])
    ]

    static let navigation = [
        DesignSpecOptionV4("floating", "悬浮顶部", "Floating", "适合 GO Focus。", "Good for GO Focus.", "rectangle.topthird.inset.filled", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("compact", "紧凑栏", "Compact", "适合工具页。", "For utility pages.", "menubar.rectangle", Color.goBlue),
        DesignSpecOptionV4("bottom", "底部栏", "Bottom Bar", "适合多主入口。", "For multi-root navigation.", "rectangle.bottomthird.inset.filled", Color.goTeal),
        DesignSpecOptionV4("rail", "侧轨", "Side Rail", "只适合大屏或预览。", "Only for large screens or previews.", "sidebar.left", Color.goPurple, avoidFor: ["iPhone 单手"])
    ]

    static let pageBackButtons = [
        DesignSpecOptionV4("systemChevron", "系统返回", "System Chevron", "使用 NavigationStack 默认返回，不自定义背景。", "Use NavigationStack's system back behavior without custom chrome.", "chevron.left", Color.goBlue, goodFor: ["常规 push 详情"]),
        DesignSpecOptionV4("floatingCircle", "悬浮圆形", "Floating Circle", "自定义页面默认：chevron + 轻背景圆形。", "Default custom page back: chevron in a light circular surface.", "chevron.left.circle.fill", Color.goPrimary, recommended: true, goodFor: ["自定义顶部栏", "详情页"]),
        DesignSpecOptionV4("solidCircle", "实色圆形", "Solid Circle", "用于图片/hero 上，保证对比。", "For image or hero surfaces where contrast must be guaranteed.", "arrow.left.circle.fill", Color.goTeal, goodFor: ["彩色 hero"], avoidFor: ["长表单"]),
        DesignSpecOptionV4("textPill", "文字胶囊", "Text Pill", "只用于多级详情或不明确路径。", "Only for deep hierarchy where path clarity matters.", "chevron.left.forwardslash.chevron.right", Color.goOrange, goodFor: ["多级详情"], avoidFor: ["高频页"])
    ]

    static let pageCloseButtons = [
        DesignSpecOptionV4("iconOnly", "纯图标", "Icon Only", "非弹窗页面默认关闭：xmark，无额外底色。", "Default non-sheet close: xmark without extra background.", "xmark", Color.goPrimary, recommended: true, goodFor: ["业务详情", "全屏预览"]),
        DesignSpecOptionV4("circle", "圆形关闭", "Circle Close", "用于图片、强视觉背景或对比不足时。", "For imagery, strong visuals, or low-contrast backdrops.", "xmark.circle.fill", Color.goBlue, goodFor: ["图片预览"]),
        DesignSpecOptionV4("pill", "关闭胶囊", "Close Pill", "退出长表单或可能丢失数据时使用。", "For long forms or possible unsaved changes.", "capsule.fill", Color.goTeal, goodFor: ["长表单"], avoidFor: ["短弹窗"]),
        DesignSpecOptionV4("text", "文字关闭", "Text Close", "最低视觉重量。", "Lowest visual weight.", "textformat", Color.goOrange, goodFor: ["轻内容页"], avoidFor: ["危险流程"])
    ]

    static let listRows = [
        DesignSpecOptionV4("filled", "填充行", "Filled", "设置页默认。", "Default for Settings.", "list.bullet.rectangle.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("outlined", "描边行", "Outlined", "边界清楚。", "Clear boundary.", "rectangle", Color.goBlue),
        DesignSpecOptionV4("plain", "纯文字", "Plain", "最轻。", "Lightest.", "line.3.horizontal", Color.goTeal),
        DesignSpecOptionV4("dense", "紧凑行", "Dense", "适合历史列表。", "For history lists.", "rectangle.compress.vertical", Color.goOrange)
    ]

    static let badges = [
        DesignSpecOptionV4("solid", "实心", "Solid", "最醒目。", "Most visible.", "seal.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("outline", "描边", "Outline", "低干扰。", "Less intrusive.", "seal", Color.goBlue),
        DesignSpecOptionV4("dot", "圆点", "Dot", "只表达存在。", "Presence only.", "circle.fill", Color.goRed),
        DesignSpecOptionV4("number", "数字", "Number", "适合未读计数。", "For counters.", "number.circle.fill", Color.goOrange)
    ]

    static let sheets = [
        DesignSpecOptionV4("compact", "紧凑", "Compact", "记录弹窗默认。", "Default for record sheets.", "rectangle.bottomthird.inset.filled", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("bottom", "底部", "Bottom", "靠近手指。", "Thumb-friendly.", "rectangle.inset.bottomleft.filled", Color.goBlue),
        DesignSpecOptionV4("overview", "Overview", "Overview", "适合数据总览。", "For data overview.", "chart.xyaxis.line", Color.goPurple),
        DesignSpecOptionV4("minimal", "极简", "Minimal", "只有关键字段。", "Only key fields.", "line.3.horizontal", Color.goTeal),
        DesignSpecOptionV4("confirm", "确认", "Confirm", "危险操作确认。", "For destructive confirmation.", "exclamationmark.triangle.fill", Color.goRed)
    ]

    static let sheetTransparency = [
        DesignSpecOptionV4("clear", "清透", "Clear", "能看到背景，但有对比风险。", "Visible backdrop with contrast risk.", "sparkles", Color.goPrimary),
        DesignSpecOptionV4("balanced", "平衡", "Balanced", "推荐。", "Recommended.", "circle.lefthalf.filled", Color.goBlue, recommended: true),
        DesignSpecOptionV4("frosted", "磨砂", "Frosted", "更稳。", "Safer.", "cloud.fill", Color.goPurple),
        DesignSpecOptionV4("solid", "实色", "Solid", "最清楚。", "Clearest.", "eye.fill", Color.goOrange)
    ]

    static let sheetChrome = [
        DesignSpecOptionV4("iconOnly", "纯图标关闭", "Icon Close", "Ohana 默认。", "Ohana default.", "xmark", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("pillClose", "胶囊关闭", "Pill Close", "适合长表单退出。", "For long form exits.", "xmark.circle.fill", Color.goBlue),
        DesignSpecOptionV4("bottomCTA", "底部 CTA", "Bottom CTA", "适合记录。", "For record flows.", "rectangle.bottomthird.inset.filled", Color.goTeal),
        DesignSpecOptionV4("danger", "危险强调", "Danger", "仅删除确认。", "Only destructive confirms.", "trash.fill", Color.goRed)
    ]

    static let chartLines = [
        DesignSpecOptionV4("area", "面积线", "Area", "趋势最直观。", "Most intuitive for trends.", "chart.xyaxis.line", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("thin", "细线", "Thin", "更专业。", "More professional.", "waveform.path", Color.goBlue),
        DesignSpecOptionV4("dash", "虚线", "Dashed", "适合目标线。", "For goal/reference lines.", "line.diagonal", Color.goTeal),
        DesignSpecOptionV4("bars", "柱状", "Bars", "适合每日数量。", "For daily totals.", "chart.bar.fill", Color.goOrange)
    ]

    static let chartAxes = [
        DesignSpecOptionV4("quiet", "安静网格", "Quiet", "推荐。", "Recommended.", "square.grid.3x3", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("strong", "强坐标", "Strong", "适合分析页。", "For analytical pages.", "ruler.fill", Color.goBlue),
        DesignSpecOptionV4("none", "无坐标", "None", "适合小卡片。", "For small cards.", "minus", Color.goTeal)
    ]

    static let calendarLayouts = [
        DesignSpecOptionV4("monthGrid", "月历网格", "Month Grid", "适合完整计划浏览。", "Best for complete schedule scanning.", "calendar", Color.goPrimary, goodFor: ["日历主页", "计划密集"]),
        DesignSpecOptionV4("weekStrip", "周条", "Week Strip", "更轻，适合卡片页。", "Lightweight, good inside cards.", "calendar.day.timeline.left", Color.goBlue, goodFor: ["首页嵌入", "快速概览"]),
        DesignSpecOptionV4("agendaHybrid", "月历 + 日程", "Agenda Hybrid", "Ohana 推荐：先看日期，再看任务。", "Ohana recommended: date context plus tasks.", "calendar.badge.clock", Color.goTeal, recommended: true, goodFor: ["护理计划", "提醒"]),
        DesignSpecOptionV4("timeline", "时间轴", "Timeline", "适合当天事件非常多。", "Best when today's events are dense.", "point.topleft.down.curvedto.point.bottomright.up", Color.goPurple, goodFor: ["日视图", "历史"])
    ]

    static let calendarDays = [
        DesignSpecOptionV4("minimalNumber", "纯数字", "Number Only", "最干净，但状态弱。", "Cleanest, but state is subtle.", "number", Color.goBlue, goodFor: ["轻量概览"]),
        DesignSpecOptionV4("filledCircle", "圆形选中", "Filled Circle", "系统熟悉感强。", "Familiar system calendar behavior.", "circle.fill", Color.goPrimary, goodFor: ["选择日期"]),
        DesignSpecOptionV4("glassTile", "玻璃日期格", "Glass Tile", "和 Ohana 卡片语言统一。", "Matches Ohana's glass card language.", "square.stack.3d.up.fill", Color.goTeal, recommended: true, goodFor: ["品牌页", "深色模式"]),
        DesignSpecOptionV4("heatmap", "热力格", "Heatmap", "直观看到照顾强度。", "Shows care intensity at a glance.", "square.grid.3x3.fill", Color.goOrange, goodFor: ["统计", "连续记录"], avoidFor: ["精确计划"])
    ]

    static let calendarEvents = [
        DesignSpecOptionV4("dots", "彩色点", "Dots", "安静、不占空间。", "Quiet and space-efficient.", "ellipsis", Color.goPrimary, recommended: true, goodFor: ["月视图"]),
        DesignSpecOptionV4("bars", "短条", "Bars", "比点更容易数。", "Easier to count than dots.", "line.3.horizontal", Color.goBlue, goodFor: ["多任务日期"]),
        DesignSpecOptionV4("icons", "小图标", "Icons", "类型识别最快。", "Fastest type recognition.", "pawprint.fill", Color.goTeal, goodFor: ["宠物护理"]),
        DesignSpecOptionV4("stack", "数量堆叠", "Count Stack", "适合事件很多的日期。", "Good for days with many events.", "square.stack.3d.up.fill", Color.goPurple, goodFor: ["密集日历"])
    ]

    static let calendarAgenda = [
        DesignSpecOptionV4("plainList", "纯列表", "Plain List", "最轻、最稳定。", "Lightest and most stable.", "list.bullet", Color.goBlue, goodFor: ["历史"]),
        DesignSpecOptionV4("timeRail", "时间轨", "Time Rail", "时间顺序最清楚。", "Clearest sequence by time.", "timeline.selection", Color.goPrimary, recommended: true, goodFor: ["当天计划"]),
        DesignSpecOptionV4("groupedCards", "分组卡片", "Grouped Cards", "适合按成员或类型分组。", "Good for grouping by member or type.", "rectangle.stack.fill", Color.goTeal, goodFor: ["多人/多宠物"]),
        DesignSpecOptionV4("swipeRows", "滑动行", "Swipe Rows", "强调完成/删除操作。", "Emphasizes complete/delete actions.", "arrow.left.and.right", Color.goOrange, goodFor: ["待办处理"], avoidFor: ["只读统计"])
    ]

    static let toasts = [
        DesignSpecOptionV4("glass", "玻璃", "Glass", "轻反馈默认。", "Default lightweight feedback.", "message.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("compact", "紧凑", "Compact", "低打扰。", "Low interruption.", "text.bubble.fill", Color.goBlue),
        DesignSpecOptionV4("icon", "图标", "Icon", "动作更明确。", "More explicit.", "checkmark.circle.fill", Color.goTeal),
        DesignSpecOptionV4("silent", "安静", "Silent", "仅用于重复操作。", "For repeated actions.", "checkmark", Color.goOrange)
    ]

    static let banners = [
        DesignSpecOptionV4("inline", "行内", "Inline", "跟随内容。", "Inline with content.", "rectangle.and.text.magnifyingglass", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("top", "顶部", "Top", "页面级提醒。", "Page-level notice.", "rectangle.topthird.inset.filled", Color.goBlue),
        DesignSpecOptionV4("card", "卡片", "Card", "适合警告详情。", "For warning details.", "exclamationmark.bubble.fill", Color.goOrange),
        DesignSpecOptionV4("quiet", "安静", "Quiet", "低干扰。", "Low-interruption.", "bell.slash.fill", Color.goTeal)
    ]

    static let haptics = [
        DesignSpecOptionV4("off", "关闭", "Off", "适合低功耗。", "For reduced feedback.", "speaker.slash.fill", Color.goBlue),
        DesignSpecOptionV4("soft", "轻触", "Soft", "推荐。", "Recommended.", "hand.tap.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("rigid", "明确", "Rigid", "适合危险确认。", "For destructive confirms.", "dot.radiowaves.left.and.right", Color.goOrange),
        DesignSpecOptionV4("success", "成功", "Success", "适合完成记录。", "For saved states.", "checkmark.seal.fill", Color.goTeal)
    ]

    static let motions = [
        DesignSpecOptionV4("reduced", "克制", "Reduced", "最稳。", "Most stable.", "minus.circle.fill", Color.goBlue),
        DesignSpecOptionV4("quick", "快速", "Quick", "高频操作。", "For high-frequency actions.", "bolt.fill", Color.goTeal),
        DesignSpecOptionV4("spring", "弹性", "Spring", "Ohana 默认。", "Ohana default.", "scribble.variable", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("playful", "可爱", "Playful", "奖励场景。", "For reward moments.", "sparkles", Color.goPurple, avoidFor: ["表单输入"])
    ]

    static let fabMotions = [
        DesignSpecOptionV4("rotate", "旋转", "Rotate", "清晰、常见。", "Clear and familiar.", "arrow.clockwise.circle.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("pop", "弹出", "Pop", "更活泼。", "More lively.", "sparkles", Color.goPurple),
        DesignSpecOptionV4("fan", "扇形展开", "Fan", "强视觉。", "High visual energy.", "fanblades.fill", Color.goBlue, avoidFor: ["高频页"]),
        DesignSpecOptionV4("float", "上浮", "Float", "轻盈。", "Light and airy.", "arrow.up.circle.fill", Color.goTeal)
    ]

    static let transitions = [
        DesignSpecOptionV4("scale", "缩放", "Scale", "稳妥。", "Reliable default.", "arrow.up.left.and.arrow.down.right", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("slide", "滑入", "Slide", "方向感清楚。", "Clear directionality.", "arrow.up", Color.goBlue),
        DesignSpecOptionV4("fade", "淡入", "Fade", "最克制。", "Most restrained.", "circle.lefthalf.filled", Color.goTeal),
        DesignSpecOptionV4("blur", "模糊", "Blur", "高级但性能需注意。", "Premium, watch performance.", "camera.filters", Color.goPurple)
    ]

    static let rewards = [
        DesignSpecOptionV4("bouncy", "弹跳", "Bouncy", "零食奖励默认。", "Default treat reward.", "heart.fill", Color.goPrimary, recommended: true),
        DesignSpecOptionV4("confetti", "粒子", "Confetti", "庆祝感强。", "Strong celebration.", "sparkles", Color.goPurple),
        DesignSpecOptionV4("quiet", "安静", "Quiet", "专业克制。", "Professional and calm.", "checkmark", Color.goTeal),
        DesignSpecOptionV4("soundless", "无声", "Soundless", "不打扰。", "Non-intrusive.", "speaker.slash.fill", Color.goBlue)
    ]
}
