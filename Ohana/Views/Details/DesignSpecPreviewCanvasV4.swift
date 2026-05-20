//
//  DesignSpecPreviewCanvasV4.swift
//  Ohana
//

import SwiftUI

struct DesignSpecPreviewCanvasV4: View {
    let selection: DesignSpecSelectionV4
    let mode: DesignPreviewModeV4
    @Binding var toast: String?

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var tapPulse = false
    @State private var fabOpen = false
    @State private var fieldText = "50"
    @State private var toggleOn = true
    @State private var sliderValue = 0.64
    @State private var selectedRange = "7D"
    @State private var showSheetLayer = false
    @State private var rewardActive = false
    @State private var fieldFocused = false
    @State private var isVisible = false

    private var palette: DesignSpecPaletteV4 {
        DesignSpecPaletteV4(selection: selection, mode: mode)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            background

            previewScroller
                .opacity(showSheetLayer ? 0.72 : 1)
                .blur(radius: showSheetLayer ? sheetBackdropBlur : 0)

            previewFab
                .padding(16)

            if tapPulse {
                tapBurst
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }

            if showSheetLayer {
                sheetShowcase
                    .padding(12)
                    .transition(sheetTransition)
            }
        }
        .frame(height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(mode == .dark ? 0.22 : 0.08), radius: 18, y: 10) // ui-v4: allow framed developer preview depth
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            play("画布点击 / Canvas tap")
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }

    private var previewScroller: some View {
        ScrollView(.vertical, showsIndicators: true) {
            allElementsPreview
                .padding(13)
                .padding(.bottom, 86)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .bottom) { scrollHint }
    }

    private var scrollHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 9, weight: .black))
            Text("上下滑动预览 / Scroll preview")
                .font(font(9, .black))
        }
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(sheetGlass(cornerRadius: 999))
        .padding(.bottom, 8)
    }

    private var allElementsPreview: some View {
        VStack(alignment: .leading, spacing: space(10, 12, 15)) {
            previewNavigationBar(title: "UI 元素总览", subtitle: "All iOS elements · fixture data")

            HStack(spacing: 9) {
                metricTile("卡片", "Card", "Glass", "rectangle.on.rectangle.angled.fill", palette.accent)
                metricTile("按钮", "Button", "CTA", "capsule.fill", Color.goBlue)
                metricTile("状态", "State", "11", "seal.fill", Color.goTeal)
            }

            bigFocusCard
            controlsShowcase
            chartTile(title: "图表 / Chart", subtitle: "Line, axis, progress and metric", values: [0.30, 0.58, 0.48, 0.70, 0.62, 0.84, 0.78])
            calendarShowcase
            formAndListShowcase
            sheetLauncher
            compactStateMatrix

            if selection.navigation == "bottom" {
                bottomNavPreview
            }
        }
    }

    private var controlsShowcase: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("控件", "Controls")
            HStack(spacing: 8) {
                Button("Primary") { play("Primary Button") }
                    .buttonStyle(buttonStyle(.primary))
                Button("Secondary") { play("Secondary Button") }
                    .buttonStyle(buttonStyle(.secondary))
                Button {
                    play("Icon Button")
                } label: {
                    Image(systemName: icon("bell.fill"))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(buttonStyle(.icon))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("选择标签 / Chips")
                    .font(font(10, .black))
                    .foregroundStyle(palette.secondaryText)
                HStack(spacing: 7) {
                    chip("干粮", selected: true)
                    chip("湿粮", selected: false)
                    chip("90D", selected: selectedRange == "90D")
                }
            }
            controlDeck
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var formAndListShowcase: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("输入与列表", "Inputs, toggles, rows and badges")
            formRow("当前成员", "Current human", "person.crop.circle.fill", trailing: "Guan")
            formRow("隐私测试", "Privacy matrix", "lock.shield.fill", trailing: toggleOn ? "On" : "Off")
            inputPreview(title: "金额 / Amount", value: "$26.80", state: fieldFocused ? .focused : .normal)
            listRowPreview
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var sheetLauncher: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("弹窗", "Sheet, modal and destructive confirm")
            HStack(spacing: 9) {
                metricTile("类型", "Type", selection.sheet, "rectangle.bottomthird.inset.filled", palette.accent)
                metricTile("背景", "Sheet bg", selection.sheetGlass, "sparkles", Color.goPurple)
                metricTile("关闭", "Close", selection.sheetChrome, "xmark", Color.goTeal)
            }
            HStack(spacing: 8) {
                Button("打开弹窗 / Open Sheet") {
                    withAnimation(motion) { showSheetLayer = true }
                    play("打开弹窗 / Open sheet")
                }
                .buttonStyle(buttonStyle(.primary))
                Button("删除确认 / Confirm") {
                    withAnimation(motion) { showSheetLayer = true }
                    play("删除确认 / Confirm")
                }
                .buttonStyle(buttonStyle(.destructive))
            }
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var compactStateMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("状态矩阵", "Normal, selected, disabled, error, loading, locked")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(DesignSpecComponentStateV4.allCases) { state in
                    compactStateCell(state)
                }
            }
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var calendarShowcase: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("日历", "Calendar, agenda and reminders")
            HStack(spacing: 7) {
                chip(calendarOptionTitle(selection.calendarLayout, in: DesignSpecOptionCatalogV4.calendarLayouts), selected: true)
                chip(calendarOptionTitle(selection.calendarEvent, in: DesignSpecOptionCatalogV4.calendarEvents), selected: false)
            }

            switch selection.calendarLayout {
            case "weekStrip":
                calendarWeekStrip
                calendarAgendaPreview
            case "timeline":
                calendarAgendaPreview
            case "monthGrid":
                calendarMonthGrid
            default:
                calendarMonthGrid
                calendarAgendaPreview
            }
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var calendarMonthGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("May 2026")
                    .font(font(13, .black))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                HStack(spacing: 6) {
                    iconCircle("chevron.left")
                        .frame(width: 28, height: 28)
                    iconCircle("chevron.right")
                        .frame(width: 28, height: 28)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(font(8, .black))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
                ForEach(1...28, id: \.self) { day in
                    calendarDayCell(day, isToday: day == 11, isSelected: day == 12, intensity: calendarIntensity(day))
                }
            }
        }
        .padding(10)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(palette.stroke, lineWidth: 1))
    }

    private var calendarWeekStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(zip(["一", "二", "三", "四", "五", "六", "日"], [11, 12, 13, 14, 15, 16, 17])), id: \.1) { weekday, day in
                VStack(spacing: 5) {
                    Text(weekday)
                        .font(font(8, .black))
                        .foregroundStyle(palette.secondaryText)
                    calendarDayCell(day, isToday: day == 11, isSelected: day == 12, intensity: calendarIntensity(day))
                        .frame(height: 56)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
    }

    private var calendarAgendaPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            if selection.calendarAgenda == "groupedCards" {
                Text("今日 / Today")
                    .font(font(10, .black))
                    .foregroundStyle(palette.secondaryText)
            }
            calendarAgendaRow(time: "09:00", title: "主粮计划", subtitle: "Food plan · li lo", icon: "fork.knife", tint: palette.accent)
            calendarAgendaRow(time: "14:30", title: "换水", subtitle: "Water change · 4 天周期", icon: "drop.fill", tint: Color.goBlue)
            calendarAgendaRow(time: "20:00", title: "体重记录", subtitle: "Weight check · private", icon: "scalemass.fill", tint: Color.goTeal)
        }
        .padding(selection.calendarAgenda == "groupedCards" ? 10 : 0)
        .background(selection.calendarAgenda == "groupedCards" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
    }

    private func calendarDayCell(_ day: Int, isToday: Bool, isSelected: Bool, intensity: Double) -> some View {
        let hasEvents = [3, 7, 11, 12, 17, 18, 23, 27].contains(day)
        let fill: Color
        let stroke: Color
        let foreground: Color
        switch selection.calendarDay {
        case "minimalNumber":
            fill = .clear
            stroke = .clear
            foreground = isSelected ? palette.accent : palette.primaryText
        case "filledCircle":
            fill = isSelected ? palette.accent : (isToday ? palette.accent.opacity(0.16) : .clear)
            stroke = isToday && !isSelected ? palette.accent : .clear
            foreground = isSelected ? palette.accentText : palette.primaryText
        case "heatmap":
            fill = palette.accent.opacity(0.08 + intensity * 0.34)
            stroke = isSelected ? palette.accent : .clear
            foreground = palette.primaryText
        default:
            fill = isSelected ? palette.accent.opacity(0.24) : palette.cardFill
            stroke = isSelected || isToday ? palette.accent : palette.stroke
            foreground = isSelected ? palette.accent : palette.primaryText
        }

        return VStack(spacing: 3) {
            Text("\(day)")
                .font(font(10, isSelected || isToday ? .black : .bold))
                .foregroundStyle(foreground)
            if hasEvents {
                calendarEventMarker(day)
            } else {
                Spacer(minLength: 0).frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: selection.calendarDay == "minimalNumber" ? 30 : 38)
        .padding(.vertical, selection.calendarDay == "minimalNumber" ? 1 : 4)
        .background(fill, in: RoundedRectangle(cornerRadius: selection.calendarDay == "filledCircle" ? 999 : innerRadius - 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: selection.calendarDay == "filledCircle" ? 999 : innerRadius - 4, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func calendarEventMarker(_ day: Int) -> some View {
        switch selection.calendarEvent {
        case "bars":
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(day.isMultiple(of: 2) ? palette.accent : Color.goBlue)
                .frame(width: 18, height: 3)
        case "icons":
            HStack(spacing: 2) {
                Image(systemName: icon(day.isMultiple(of: 2) ? "fork.knife" : "drop.fill"))
                if day.isMultiple(of: 3) {
                    Image(systemName: icon("pawprint.fill"))
                }
            }
            .font(.system(size: 6, weight: iconWeight))
            .foregroundStyle(palette.accent)
        case "stack":
            Text(day.isMultiple(of: 3) ? "3" : "2")
                .font(font(7, .black))
                .foregroundStyle(palette.accentText)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(palette.accent, in: Capsule())
        default:
            HStack(spacing: 2) {
                Circle().fill(palette.accent).frame(width: 4, height: 4)
                if day.isMultiple(of: 3) {
                    Circle().fill(Color.goBlue).frame(width: 4, height: 4)
                }
            }
        }
    }

    private func calendarAgendaRow(time: String, title: String, subtitle: String, icon iconName: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            if selection.calendarAgenda == "timeRail" {
                VStack(spacing: 3) {
                    Circle().fill(tint).frame(width: 7, height: 7)
                    Rectangle().fill(palette.stroke).frame(width: 1, height: 32)
                }
                .frame(width: 12)
            }

            if selection.calendarAgenda != "plainList" {
                Text(time)
                    .font(font(9, .black))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 38, alignment: .leading)
            }

            Image(systemName: icon(iconName))
                .font(.system(size: 12, weight: iconWeight))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(font(11, .black))
                    .foregroundStyle(palette.primaryText)
                Text(subtitle)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 4)

            if selection.calendarAgenda == "swipeRows" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "trash")
                }
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(palette.accent)
            }
        }
        .padding(selection.calendarAgenda == "plainList" ? 7 : 9)
        .background(selection.calendarAgenda == "plainList" ? .clear : palette.controlFill, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(selection.calendarAgenda == "swipeRows" ? palette.accent.opacity(0.30) : .clear, lineWidth: 1))
    }

    private func calendarIntensity(_ day: Int) -> Double {
        let seed = (day * 37) % 100
        return Double(seed) / 100.0
    }

    private func calendarOptionTitle(_ id: String, in options: [DesignSpecOptionV4]) -> String {
        options.first(where: { $0.id == id }).map(\.zh) ?? id
    }

    private func sectionHeader(_ zh: String, _ en: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(zh)
                    .font(font(13, .black))
                    .foregroundStyle(palette.primaryText)
                Text(en)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            badgePreview
        }
    }

    private var bigFocusCard: some View {
        VStack(alignment: .leading, spacing: space(9, 11, 13)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日照顾")
                        .font(font(19, .black))
                        .foregroundStyle(palette.primaryText)
                    Text("Today Care")
                        .font(font(11, .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Image(systemName: icon("sparkles"))
                    .font(.system(size: 17, weight: iconWeight))
                    .foregroundStyle(palette.accent)
            }

            editableInputPreview

            HStack(spacing: 8) {
                Button("打卡 / Record") { play("按钮点击 / Button tap") }
                    .onLongPressGesture {
                        withAnimation(motion) { showSheetLayer = true }
                        play("长按反馈 / Long press")
                    }
                    .buttonStyle(buttonStyle(.primary))
                Button("计划 / Plan") {
                    withAnimation(motion) { showSheetLayer = true }
                    play("打开弹窗 / Open sheet")
                }
                .buttonStyle(buttonStyle(.secondary))
            }
        }
        .padding(space(12, 14, 17))
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var editableInputPreview: some View {
        let state: FieldState = selection.inputState == "errorFirst" ? .error : (fieldFocused ? .focused : .normal)
        let stroke = state == .focused ? palette.accent : (state == .error ? palette.danger : palette.stroke)
        return VStack(alignment: .leading, spacing: 5) {
            Text("克数 / Grams")
                .font(font(10, .black))
                .foregroundStyle(state == .error ? palette.danger : palette.secondaryText)
            HStack(spacing: 9) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 12, weight: iconWeight))
                    .foregroundStyle(stroke)
                Button {
                    withAnimation(GoMotion.feedback) {
                        fieldFocused.toggle()
                    }
                    play("输入框聚焦 / Field focus")
                } label: {
                    Text(fieldText)
                        .font(font(14, .bold))
                        .foregroundStyle(palette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
                Text("g")
                    .font(font(12, .black))
                    .foregroundStyle(palette.secondaryText)
                if state == .error {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(palette.danger)
                }
            }
            .padding(.horizontal, selection.input == "compact" ? 10 : 12)
            .padding(.vertical, selection.input == "compact" ? 9 : 11)
            .background(DesignSpecUIV4.fieldFill(selection: selection, palette: palette), in: RoundedRectangle(cornerRadius: fieldRadius, style: .continuous))
            .overlay(fieldBorder(stroke: stroke, state: state))
            .shadow(color: selection.inputState == "glow" && fieldFocused ? palette.accent.opacity(0.28) : .clear, radius: 12) // ui-v4: allow focus glow option preview
        }
    }

    private var controlDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(["7D", "30D", "90D"], id: \.self) { range in
                    Button {
                        withAnimation(motion) { selectedRange = range }
                        play("分段切换 / Segment")
                    } label: {
                        chip(range, selected: selectedRange == range)
                    }
                    .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom segment-chip animation
                }

                Spacer(minLength: 8)
                privacyToggle
            }

            HStack(spacing: 10) {
                progressPreview
                listRowPreview
            }
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private var privacyToggle: some View {
        Button {
            withAnimation(motion) { toggleOn.toggle() }
            play(toggleOn ? "切为隐私 / Private" : "切为公开 / Public")
        } label: {
            HStack(spacing: selection.toggle == "text" ? 6 : 8) {
                Image(systemName: toggleOn ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .black))
                if selection.toggle == "text" || selection.toggle == "row" {
                    Text(toggleOn ? "公开 / Public" : "隐私 / Private")
                        .font(font(10, .black))
                }
                Circle()
                    .fill(toggleOn ? palette.accent : palette.secondaryText.opacity(0.35))
                    .frame(width: 16, height: 16)
                    .offset(x: toggleOn ? 7 : -7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(palette.controlFill, in: Capsule())
            }
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, selection.toggle == "row" ? 10 : 7)
            .padding(.vertical, 7)
            .frame(maxWidth: selection.toggle == "row" ? .infinity : nil, alignment: .leading)
            .background(selection.toggle == "row" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom privacy toggle animation
    }

    private var progressPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("进度 / Progress")
                    .font(font(10, .black))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(Int(sliderValue * 100))%")
                    .font(font(10, .black))
                    .foregroundStyle(palette.accent)
            }

            if selection.progress == "ring" {
                ZStack {
                    Circle().stroke(palette.stroke, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: sliderValue)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 40, height: 40)
            } else if selection.progress == "steps" {
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < Int((sliderValue * 5).rounded(.up)) ? palette.accent : palette.stroke)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.vertical, 13)
            } else if selection.progress == "bar" {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.stroke.opacity(0.45))
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: max(18, proxy.size.width * sliderValue))
                    }
                }
                .frame(height: 10)
                .padding(.vertical, 12)
            } else {
                Slider(value: $sliderValue, in: 0...1)
                    .tint(palette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listRowPreview: some View {
        HStack(spacing: 9) {
            Image(systemName: icon("clock.fill"))
                .font(.system(size: 12, weight: iconWeight))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)
                .background(palette.controlFill, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text("最近记录")
                    .font(font(11, .black))
                    .foregroundStyle(palette.primaryText)
                Text("12:30 · 50g")
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 4)
            badgePreview
        }
        .padding(selection.listRow == "dense" ? 7 : 9)
        .background(selection.listRow == "plain" ? .clear : palette.controlFill, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(selection.listRow == "outlined" ? palette.stroke : .clear, lineWidth: 1))
    }

    private var badgePreview: some View {
        Text(selection.badge == "dot" ? "" : (selection.badge == "number" ? "2" : "New"))
            .font(font(8, .black))
            .foregroundStyle(selection.badge == "outline" ? palette.accent : Color.arkInk)
            .frame(width: selection.badge == "dot" ? 8 : nil, height: selection.badge == "dot" ? 8 : nil)
            .padding(.horizontal, selection.badge == "dot" ? 0 : 7)
            .padding(.vertical, selection.badge == "dot" ? 0 : 4)
            .background(selection.badge == "outline" ? Color.clear : palette.accent, in: Capsule())
            .overlay(Capsule().strokeBorder(selection.badge == "outline" ? palette.accent : Color.clear, lineWidth: 1))
    }

    private var sheetShowcase: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sheetTitle)
                        .font(font(17, .black))
                        .foregroundStyle(palette.primaryText)
                    Text("Sheet system · \(selection.sheetGlass)")
                        .font(font(10, .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                if selection.sheetChrome == "pillClose" {
                    Button("关闭") { dismissSheet() }
                        .font(font(11, .black))
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(palette.controlFill, in: Capsule())
                } else {
                    Button { dismissSheet() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(palette.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ScaleButtonStyle()) // ui-v4: allow icon-only sheet close control
                }
            }

            if selection.sheet == "overview" {
                chartTile(title: "喂食 Overview", subtitle: "Food overview", values: [0.35, 0.62, 0.42, 0.80, 0.66, 0.74, 0.58])
            } else if selection.sheet == "confirm" || selection.sheetChrome == "danger" {
                destructivePreview
            } else {
                inputPreview(title: "克数 / Grams", value: fieldText, state: .focused, sheetStyle: true)
                HStack(spacing: 8) {
                    chip("42g", selected: false)
                    chip("50g", selected: true)
                    chip("75g", selected: false)
                }
            }

            HStack(spacing: 8) {
                Button(sheetActionTitle) {
                    withAnimation(motion) {
                        rewardActive = true
                        showSheetLayer = false
                    }
                    play("保存成功 / Saved")
                }
                .buttonStyle(sheetButtonStyle(selection.sheet == "confirm" ? .destructive : .primary))

                if selection.sheetChrome == "bottomCTA" {
                    Button("稍后 / Later") { dismissSheet() }
                        .buttonStyle(sheetButtonStyle(.secondary))
                }
            }
        }
        .padding(selection.sheet == "minimal" ? 13 : 16)
        .background(sheetGlass(cornerRadius: selection.sheet == "minimal" ? 20 : 28))
        .shadow(color: .black.opacity(mode == .dark ? 0.24 : 0.12), radius: 18, y: 10) // ui-v4: allow sheet overlay depth preview
    }

    private var destructivePreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .foregroundStyle(palette.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("确认删除")
                    .font(font(14, .black))
                    .foregroundStyle(palette.primaryText)
                Text("Confirm destructive action")
                    .font(font(10, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(12)
        .background(palette.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
    }

    private var previewFab: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if fabOpen {
                VStack(alignment: .trailing, spacing: 8) {
                    fabAction("主粮", "Food", "fork.knife")
                    fabAction("余粮", "Stock", "shippingbox.fill")
                    fabAction("零食", "Treat", "heart.fill")
                }
                .transition(fabMenuTransition)
            }

            Button {
                withAnimation(motion) { fabOpen.toggle() }
                play(fabOpen ? "FAB 展开 / FAB open" : "FAB 收起 / FAB close")
            } label: {
                Image(systemName: fabOpen ? "xmark" : "plus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(palette.accentText)
                    .frame(width: 54, height: 54)
                    .background(palette.accent, in: Circle())
                    .shadow(color: palette.accent.opacity(0.32), radius: 15, y: 8) // ui-v4: allow FAB elevation preview
                    .rotationEffect(.degrees(selection.fabMotion == "rotate" && fabOpen ? 45 : 0))
                    .scaleEffect(selection.fabMotion == "pop" && fabOpen ? 1.10 : 1)
                    .offset(y: selection.fabMotion == "float" && fabOpen ? -6 : 0)
            }
            .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom FAB animation preview
        }
    }

    private func fabAction(_ zh: String, _ en: String, _ iconName: String) -> some View {
        Button {
            withAnimation(motion) { fabOpen = false }
            play("\(zh) / \(en)")
        } label: {
            HStack(spacing: 7) {
                Text("\(zh) / \(en)")
                    .font(font(10, .black))
                Image(systemName: icon(iconName))
                    .font(.system(size: 11, weight: iconWeight))
            }
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(sheetGlass(cornerRadius: 999))
        }
        .buttonStyle(ScaleButtonStyle()) // ui-v4: allow custom floating action row
    }

    private var tapBurst: some View {
        ZStack {
            Circle()
                .stroke(palette.accent.opacity(0.65), lineWidth: 2)
                .frame(width: 72, height: 72)
                .scaleEffect(tapPulse ? 1.55 : 0.65)
                .opacity(tapPulse ? 0 : 0.85)
            Image(systemName: selection.tap == "bright" ? "sparkles" : "hand.tap.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(palette.accent)
                .scaleEffect(tapPulse ? 1.08 : 0.82)
        }
        .animation(motion, value: tapPulse)
    }

    private func previewNavigationBar(title: String, subtitle: String) -> some View {
        HStack(spacing: selection.navigation == "rail" ? 9 : 10) {
            if selection.navigation == "rail" {
                VStack(spacing: 8) {
                    iconCircle("house.fill")
                    iconCircle("chart.bar.fill")
                    iconCircle("gearshape.fill")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(font(selection.navigation == "compact" ? 16 : 18, .black))
                    .foregroundStyle(palette.primaryText)
                Text(subtitle)
                    .font(font(11, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            iconCircle("bell.badge.fill")
            iconCircle("person.crop.circle.fill")
        }
        .padding(selection.navigation == "floating" ? 10 : 0)
        .background(selection.navigation == "floating" ? palette.controlFill : .clear, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(selection.navigation == "floating" ? palette.stroke : .clear, lineWidth: 1))
    }

    private var bottomNavPreview: some View {
        HStack {
            iconTab("house.fill", "Home", selected: true)
            iconTab("fork.knife", "Food", selected: false)
            iconTab("chart.bar.fill", "Stats", selected: false)
            iconTab("gearshape.fill", "Set", selected: false)
        }
        .padding(8)
        .background(sheetGlass(cornerRadius: 999))
    }

    private func iconTab(_ iconName: String, _ title: String, selected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon(iconName))
                .font(.system(size: 13, weight: iconWeight))
            Text(title)
                .font(font(8, .black))
        }
        .foregroundStyle(selected ? palette.accent : palette.secondaryText)
        .frame(maxWidth: .infinity)
    }

    private func metricTile(_ zh: String, _ en: String, _ value: String, _ iconName: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon(iconName))
                .font(.system(size: 13, weight: iconWeight))
                .foregroundStyle(tint)
            Text(value)
                .font(font(16, .black))
                .foregroundStyle(palette.primaryText)
            Text("\(zh) / \(en)")
                .font(font(10, .black))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardFill(cornerRadius: innerRadius))
    }

    private func chartTile(title: String, subtitle: String, values: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(font(13, .black))
                        .foregroundStyle(palette.primaryText)
                    Text(subtitle)
                        .font(font(10, .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                chip(selectedRange, selected: true)
            }
            miniChart(values: values)
        }
        .padding(12)
        .background(cardFill(cornerRadius: cardRadius))
    }

    private func miniChart(values: [CGFloat]) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) / CGFloat(values.count - 1) * width,
                    y: height - value * height + 4
                )
            }

            ZStack {
                if selection.chartAxis != "none" {
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(palette.stroke.opacity(selection.chartAxis == "strong" ? 0.95 : 0.55))
                                .frame(height: 0.7)
                            Spacer(minLength: 0)
                        }
                    }
                }

                if selection.chartLine == "bars" {
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(values, id: \.self) { value in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(palette.accent)
                                .frame(height: max(14, value * height))
                        }
                    }
                    .padding(.horizontal, 5)
                } else {
                    if selection.chartLine == "area" {
                        areaPath(points: points, size: proxy.size)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.38), palette.accent.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    linePath(points: points)
                        .stroke(
                            palette.accent,
                            style: StrokeStyle(
                                lineWidth: selection.chartLine == "thin" ? 2 : 3.4,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: selection.chartLine == "dash" ? [6, 5] : []
                            )
                        )
                }
            }
        }
        .frame(height: 82)
    }

    private func statusBanner(_ zh: String, _ en: String, icon iconName: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon(iconName))
                .font(.system(size: 13, weight: iconWeight))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(zh)
                    .font(font(12, .black))
                    .foregroundStyle(palette.primaryText)
                Text(en)
                    .font(font(9, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
        .padding(11)
        .background(bannerFill(tint: tint), in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(tint.opacity(0.26), lineWidth: 1))
    }

    private func formRow(_ zh: String, _ en: String, _ iconName: String, trailing: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(iconName))
                .font(.system(size: 13, weight: iconWeight))
                .foregroundStyle(palette.accent)
                .frame(width: 30, height: 30)
                .background(palette.controlFill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(zh)
                    .font(font(13, .black))
                    .foregroundStyle(palette.primaryText)
                Text(en)
                    .font(font(10, .bold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Text(trailing)
                .font(font(11, .black))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(11)
        .background(selection.listRow == "plain" ? .clear : palette.controlFill, in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(selection.listRow == "outlined" ? palette.stroke : .clear, lineWidth: 1))
    }

    private func inputPreview(title: String, value: String, state: FieldState, sheetStyle: Bool = false) -> some View {
        let tokens = sheetStyle ? sheetTokenSelection : selection
        let stroke = state == .focused ? palette.accent : (state == .error ? palette.danger : palette.stroke)
        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(font(10, .black))
                .foregroundStyle(state == .error ? palette.danger : palette.secondaryText)
            HStack(spacing: 9) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 12, weight: iconWeight))
                    .foregroundStyle(stroke)
                Text(value)
                    .font(font(14, .bold))
                    .foregroundStyle(state == .disabled ? palette.secondaryText : palette.primaryText)
                Spacer()
                if state == .error {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(palette.danger)
                }
            }
            .padding(.horizontal, tokens.input == "compact" ? 10 : 12)
            .padding(.vertical, tokens.input == "compact" ? 9 : 11)
            .background(DesignSpecUIV4.fieldFill(selection: tokens, palette: palette), in: RoundedRectangle(cornerRadius: DesignSpecUIV4.fieldRadius(tokens), style: .continuous))
            .overlay(fieldBorder(stroke: stroke, state: state, tokens: tokens))
        }
        .opacity(state == .disabled ? 0.58 : 1)
    }

    private func compactStateCell(_ state: DesignSpecComponentStateV4) -> some View {
        let tint = stateTint(state)
        return HStack(spacing: 5) {
            Image(systemName: state.icon)
                .font(.system(size: 10, weight: iconWeight))
                .foregroundStyle(palette.accent)
            Text(state.zh)
                .font(font(9, .black))
                .foregroundStyle(state == .disabled ? palette.secondaryText : palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(state == .empty ? Color.clear : tint.opacity(0.10), in: RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: innerRadius, style: .continuous).strokeBorder(tint.opacity(state == .focused ? 0.72 : 0.24), lineWidth: state == .focused ? 1.5 : 1))
        .opacity(state == .disabled ? 0.48 : 1)
    }

    private func chip(_ title: String, selected: Bool) -> some View {
        let radius: CGFloat
        let fill: Color
        let stroke: Color
        let foreground: Color
        switch selection.chip {
        case "soft":
            radius = 12
            fill = selected ? palette.accent.opacity(0.22) : palette.secondaryAccent.opacity(0.12)
            stroke = .clear
            foreground = selected ? palette.accent : palette.primaryText
        case "outline":
            radius = 999
            fill = selected ? palette.accent.opacity(0.12) : .clear
            stroke = selected ? palette.accent : palette.stroke
            foreground = selected ? palette.accent : palette.primaryText
        case "tiny":
            radius = 8
            fill = selected ? palette.accent : palette.flatBlock
            stroke = .clear
            foreground = selected ? palette.accentText : palette.primaryText
        default:
            radius = 999
            fill = selected ? palette.accent : palette.controlFill
            stroke = selected ? .clear : palette.stroke
            foreground = selected ? palette.accentText : palette.primaryText
        }
        return Text(title)
            .font(font(10, .black))
            .foregroundStyle(foreground)
            .padding(.horizontal, selection.chip == "tiny" ? 8 : 11)
            .padding(.vertical, selection.chip == "tiny" ? 6 : 7)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: selection.chip == "outline" ? 1.3 : 1))
    }

    private func iconCircle(_ iconName: String) -> some View {
        Image(systemName: icon(iconName))
            .font(.system(size: 13, weight: iconWeight))
            .foregroundStyle(palette.accent)
            .frame(width: 34, height: 34)
    }

    private var background: some View {
        ZStack {
            palette.background
            if selection.background == "goGradient" {
                RadialGradient(
                    colors: [palette.accent.opacity(mode == .dark ? 0.32 : 0.20), .clear],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 460
                )
                RadialGradient(
                    colors: [palette.secondaryAccent.opacity(mode == .dark ? 0.20 : 0.13), .clear],
                    center: .bottomTrailing,
                    startRadius: 30,
                    endRadius: 420
                )
            }
        }
    }

    private var vividGlassBackdrop: some View {
        Group {
            if workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible) {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    vividGlassBackdropFrame(phase: phase)
                }
            } else {
                vividGlassBackdropFrame(phase: 0)
            }
        }
    }

    private func vividGlassBackdropFrame(phase: TimeInterval) -> some View {
        let wave = sin(phase * 0.34)
        let drift = cos(phase * 0.26)
        return ZStack {
            Color(hex: mode == .dark ? "080B28" : "EAF7FF")
            ForEach(0..<16, id: \.self) { index in
                let offset = CGFloat(index) * 36 - 240
                let y = CGFloat((index * 31) % 180) - 78
                let width = CGFloat(220 + (index % 4) * 42)
                let height = CGFloat(index % 3 == 0 ? 8 : 5)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(vividLineColor(index).opacity(index % 5 == 0 ? 0.96 : 0.78))
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -23 : 18))
                    .offset(x: offset + CGFloat(wave) * 28 + CGFloat(index % 4) * CGFloat(drift) * 8, y: y + CGFloat(drift) * 22)
                    .blur(radius: index % 6 == 0 ? 0.6 : 0)
            }
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .stroke(vividLineColor(index + 8).opacity(0.55), lineWidth: 2)
                    .frame(width: CGFloat(72 + index * 16), height: CGFloat(22 + index * 5))
                    .rotationEffect(.degrees(Double(index * 17) + wave * 8))
                    .offset(x: CGFloat(index * 28) - 110 + CGFloat(drift) * 18, y: CGFloat(index * 19) - 64)
            }
            glassBackdropDenseTextLayer(wave: wave, drift: drift)
            glassBackdropTextLayer(wave: wave, drift: drift)
            RadialGradient(
                colors: [Color.white.opacity(0.34), .clear], // ui-v4: allow vivid glass preview glare
                center: UnitPoint(x: 0.18 + 0.18 * CGFloat(drift), y: 0.12 + 0.10 * CGFloat(wave)),
                startRadius: 8,
                endRadius: 250
            )
            RadialGradient(
                colors: [Color(hex: "00E5FF").opacity(0.28), .clear],
                center: UnitPoint(x: 0.78 + 0.10 * CGFloat(wave), y: 0.22 + 0.16 * CGFloat(drift)),
                startRadius: 12,
                endRadius: 180
            )
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.20)], // ui-v4: allow vivid glass preview depth
                startPoint: .top,
                endPoint: .bottom
            )
            .hueRotation(.degrees(wave * 8))
        }
        .animation(.linear(duration: 0.18), value: wave) // ui-v4: allow tiny continuous preview animation
    }

    private func glassBackdropDenseTextLayer(wave: Double, drift: Double) -> some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                Text(denseGlassLine(index))
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(vividLineColor(index).opacity(mode == .dark ? 0.42 : 0.58))
                    .lineLimit(1)
                    .frame(width: 520, alignment: .leading)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.5 : 2.5))
                    .offset(
                        x: -210 + CGFloat(drift) * CGFloat(20 - index % 6),
                        y: CGFloat(index * 15) - 112 + CGFloat(wave) * CGFloat(7 + index % 4)
                    )
            }
            ForEach(0..<10, id: \.self) { index in
                Text("0123456789  文字穿过玻璃  LENS")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(mode == .dark ? 0.22 : 0.34)) // ui-v4: allow vivid glass lab text contrast
                    .rotationEffect(.degrees(90))
                    .offset(
                        x: CGFloat(index * 40) - 184 + CGFloat(wave) * 10,
                        y: CGFloat(drift) * 14
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func glassBackdropTextLayer(wave: Double, drift: Double) -> some View {
        ZStack {
            ForEach(0..<9, id: \.self) { index in
                Text(glassBackdropPhrase(index))
                    .font(.system(size: CGFloat(20 + (index % 5) * 4), weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle((index.isMultiple(of: 2) ? Color.white : Color(hex: "C9FF27")).opacity(mode == .dark ? 0.33 : 0.46)) // ui-v4: allow vivid glass lab text contrast
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 8))
                    .offset(
                        x: CGFloat(index * 43) - 178 + CGFloat(wave) * CGFloat(22 + index * 2),
                        y: CGFloat((index * 31) % 184) - 90 + CGFloat(drift) * CGFloat(12 + index)
                    )
                    .blur(radius: index == 3 ? 0.35 : 0)
            }
            ForEach(0..<14, id: \.self) { index in
                Text("GLASS \(index + 1) · 12345 · UI")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(vividLineColor(index + 2).opacity(mode == .dark ? 0.48 : 0.60))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? 17 : -14))
                    .offset(
                        x: CGFloat(index * 31) - 178 + CGFloat(drift) * 16,
                        y: CGFloat((index * 21) % 184) - 92 + CGFloat(wave) * 11
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func denseGlassLine(_ index: Int) -> String {
        switch index % 4 {
        case 0: return "OHANA UI GLASS LAB  ·  文字穿过玻璃  ·  0123456789"
        case 1: return "REFRACTION TEST  ·  CONTROL GAUSSIAN  ·  ABCDEFG"
        case 2: return "深色浅色开关参数  ·  controlFill stroke accent"
        default: return "LENS MAGNIFIER  ·  moving text behind sheet glass"
        }
    }

    private func glassBackdropPhrase(_ index: Int) -> String {
        switch index % 5 {
        case 0: return "OHANA GLASS"
        case 1: return "高斯控件"
        case 2: return "LENS TEST"
        case 3: return "文字穿透"
        default: return "REFRACTION"
        }
    }

    private func vividLineColor(_ index: Int) -> Color {
        switch index % 6 {
        case 0: return Color(hex: "00E5FF")
        case 1: return Color(hex: "C9FF27")
        case 2: return Color(hex: "FF3DA6")
        case 3: return Color(hex: "7A3DFF")
        case 4: return Color(hex: "FFB000")
        default: return Color(hex: "35FFB5")
        }
    }

    private func cardFill(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            if selection.card == "glass" {
                glassLayers(selection.glass, shape: shape)
            } else if selection.card == "solid" {
                shape.fill(palette.solidCard)
            } else if selection.card == "flat" {
                shape.fill(palette.flatBlock)
            } else if selection.card == "tinted" {
                shape.fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.18), palette.cardFill],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(mode == .dark ? Color.white.opacity(selection.card == "elevated" ? 0.12 : 0.08) : Color.white.opacity(selection.card == "elevated" ? 0.78 : 0.60)) // ui-v4: allow card style contrast comparison
                shape.fill(palette.accent.opacity(selection.card == "glass" ? 0.035 : 0.055))
            }
        }
        .overlay(shape.strokeBorder(selection.card == "flat" ? .clear : (selection.card == "glass" ? glassStroke(for: selection.glass) : palette.stroke), lineWidth: 1))
        .shadow(color: Color.black.opacity(cardShadowOpacity), radius: selection.card == "elevated" ? 15 : 6, y: 7) // ui-v4: allow preview depth shadow
    }

    private func fieldBorder(stroke: Color, state: FieldState, tokens: DesignSpecSelectionV4? = nil) -> some View {
        let tokens = tokens ?? selection
        return RoundedRectangle(cornerRadius: DesignSpecUIV4.fieldRadius(tokens), style: .continuous)
            .strokeBorder(tokens.input == "flat" ? .clear : stroke, lineWidth: state == .normal ? 1 : 1.5)
    }

    private func sheetGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glassId = sheetGlassId
        return ZStack {
            glassLayers(glassId, shape: shape)
            shape.fill(palette.accent.opacity(selection.sheetGlass == "calendarWidget" ? 0.055 : 0.018))
        }
        .overlay(shape.strokeBorder(glassStroke(for: glassId), lineWidth: 1))
    }

    private func glassSurface(_ id: String, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            glassLayers(id, shape: shape)
        }
        .overlay(shape.strokeBorder(glassStroke(for: id), lineWidth: id == "edgePrism" ? 1.2 : 1))
        .shadow(color: Color.black.opacity(id == "nativeRegular" || id == "clear" ? 0.08 : 0.14), radius: id == "nativeRegular" || id == "clear" ? 5 : 9, y: 5) // ui-v4: allow preview glass shadow
    }

    @ViewBuilder
    private func glassLayers(_ id: String, shape: RoundedRectangle) -> some View {
        if id == "solid" {
            shape.fill(mode == .dark ? Color(hex: "17162A").opacity(0.94) : Color.white.opacity(0.92)) // ui-v4: allow internal solid sheet preview
        } else if id == "frosted" {
            shape.fill(.ultraThinMaterial).opacity(0.86) // ui-v4: allow internal frosted sheet preview
            shape.fill(Color.white.opacity(mode == .dark ? 0.12 : 0.34)) // ui-v4: allow internal frosted tint
        } else if id == "refractive" {
            controlSwitchGlassLayers(shape: shape, showsControls: false)
        } else if id == "nativeRegular" {
            nativeRegularGlassLayers(shape: shape)
        } else if id == "clear" {
            nativeClearGlassLayers(shape: shape)
        } else if id == "edgePrism" {
            edgePrismGlassLayers(shape: shape)
        } else {
            shape.fill(.ultraThinMaterial).opacity(glassOpacity(for: id)) // ui-v4: allow intentional glass material comparison
            shape.fill(glassTint(for: id))
            if id == "calendarWidget" {
                RadialGradient(
                    colors: [Color(hex: "00E5FF").opacity(0.24), .clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 150
                )
                RadialGradient(
                    colors: [Color(hex: "7C3DFF").opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 150
                )
            }
            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear], // ui-v4: allow glass edge highlight
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(shape.strokeBorder(lineWidth: 1.1))
        }
    }

    private func controlSwitchGlassLayers(shape: RoundedRectangle, showsControls: Bool) -> some View {
        ZStack {
            shape.fill(.clear)
                .glassEffect(.regular.tint(palette.controlFill).interactive(false), in: shape)
            shape.fill(palette.controlFill)
            shape.fill(Color.white.opacity(mode == .dark ? 0.018 : 0.090)) // ui-v4: allow switch-glass inner tint
            LinearGradient(
                colors: [Color.white.opacity(mode == .dark ? 0.12 : 0.32), .clear], // ui-v4: allow switch-glass top sheen
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(shape.strokeBorder(lineWidth: 1.2))

            if showsControls {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(palette.accent.opacity(0.94))
                        .frame(width: 42, height: 24)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.7)) // ui-v4: allow selected control rim
                    Circle()
                        .fill(palette.primaryText.opacity(mode == .dark ? 0.12 : 0.10))
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(palette.primaryText.opacity(mode == .dark ? 0.08 : 0.07))
                        .frame(width: 18, height: 18)
                }
                .padding(7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .opacity(0.82)
                .allowsHitTesting(false)
            }
        }
    }

    private func nativeRegularGlassLayers(shape: RoundedRectangle) -> some View {
        ZStack {
            shape.fill(.clear)
                .glassEffect(.regular.interactive(false), in: shape)
            LinearGradient(
                colors: [Color.white.opacity(mode == .dark ? 0.10 : 0.24), .clear], // ui-v4: allow native glass edge sheen
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(shape.strokeBorder(lineWidth: 1.0))
        }
    }

    private func nativeClearGlassLayers(shape: RoundedRectangle) -> some View {
        ZStack {
            shape.fill(.clear)
                .glassEffect(.clear.interactive(false), in: shape)
            LinearGradient(
                colors: [Color.white.opacity(mode == .dark ? 0.07 : 0.18), .clear], // ui-v4: allow clear glass edge sheen
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(shape.strokeBorder(lineWidth: 0.9))
        }
    }

    private func edgePrismGlassLayers(shape: RoundedRectangle) -> some View {
        ZStack {
            shape.fill(.clear)
                .glassEffect(.regular.tint(palette.accent.opacity(0.10)).interactive(false), in: shape)
            RadialGradient(
                colors: [palette.accent.opacity(mode == .dark ? 0.20 : 0.14), .clear],
                center: .topLeading,
                startRadius: 4,
                endRadius: 150
            )
            RadialGradient(
                colors: [palette.secondaryAccent.opacity(mode == .dark ? 0.15 : 0.10), .clear],
                center: .bottomTrailing,
                startRadius: 4,
                endRadius: 150
            )
            LinearGradient(
                colors: [Color.white.opacity(0.18), .clear, palette.accent.opacity(0.18)], // ui-v4: allow prism glass rim
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(shape.strokeBorder(lineWidth: 1.35))
        }
    }

    private var sheetGlassId: String {
        selection.sheetGlass
    }

    private func glassOpacity(for id: String) -> Double {
        switch id {
        case "refractive": return 0.08
        case "nativeRegular": return 0
        case "calendarWidget": return 0.42
        case "clear": return 0
        case "edgePrism": return 0.12
        case "frosted": return 0.86
        case "solid": return 1
        default: return 0.68
        }
    }

    private func glassTint(for id: String) -> Color {
        switch id {
        case "refractive":
            return palette.controlFill
        case "nativeRegular", "clear":
            return .clear
        case "edgePrism":
            return palette.accent.opacity(mode == .dark ? 0.035 : 0.020)
        case "calendarWidget":
            return Color(hex: "1A0738").opacity(mode == .dark ? 0.46 : 0.18)
        case "frosted":
            return Color.white.opacity(mode == .dark ? 0.12 : 0.34) // ui-v4: allow frosted glass tint
        case "solid":
            return mode == .dark ? Color(hex: "17162A").opacity(0.94) : Color.white.opacity(0.92) // ui-v4: allow solid sheet tint
        default:
            return palette.accent.opacity(0.06)
        }
    }

    private func glassStroke(for id: String) -> Color {
        switch id {
        case "refractive":
            return palette.stroke
        case "nativeRegular":
            return Color.white.opacity(mode == .dark ? 0.24 : 0.38) // ui-v4: allow native glass rim
        case "clear":
            return Color.white.opacity(mode == .dark ? 0.18 : 0.30) // ui-v4: allow clear glass rim
        case "edgePrism":
            return palette.accent.opacity(mode == .dark ? 0.42 : 0.34)
        case "calendarWidget":
            return Color.white.opacity(mode == .dark ? 0.26 : 0.38) // ui-v4: allow widget glass rim
        case "solid":
            return palette.stroke
        case "frosted":
            return Color.white.opacity(mode == .dark ? 0.22 : 0.48) // ui-v4: allow frosted glass rim
        default:
            return Color.white.opacity(mode == .dark ? 0.22 : 0.48) // ui-v4: allow glass rim
        }
    }

    private func glassDisplayName(_ id: String) -> String {
        DesignSpecOptionCatalogV4.glass.first(where: { $0.id == id }).map { "\($0.zh) / \($0.en)" } ?? id
    }

    private func glassShortName(_ id: String) -> String {
        DesignSpecOptionCatalogV4.glass.first(where: { $0.id == id })?.zh ?? id
    }

    private func bannerFill(tint: Color) -> Color {
        switch selection.banner {
        case "quiet": return palette.controlFill
        case "card": return tint.opacity(0.14)
        default: return tint.opacity(0.10)
        }
    }

    private var buttonStyle: (DesignSpecButtonKindV4) -> DesignSpecTokenButtonStyleV4 {
        { kind in DesignSpecTokenButtonStyleV4(kind: kind, palette: palette, selection: selection) }
    }

    private var sheetButtonStyle: (DesignSpecButtonKindV4) -> DesignSpecTokenButtonStyleV4 {
        { kind in DesignSpecTokenButtonStyleV4(kind: kind, palette: palette, selection: sheetTokenSelection) }
    }

    private var sheetTokenSelection: DesignSpecSelectionV4 {
        var tokens = selection
        tokens.glass = selection.sheetGlass
        tokens.card = selection.sheetCard
        tokens.input = selection.sheetInput
        tokens.button = selection.sheetButton
        return tokens
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func dismissSheet() {
        withAnimation(motion) { showSheetLayer = false }
    }

    private func play(_ message: String) {
        DesignSpecUIV4.triggerHaptic(selection)
        withAnimation(motion) {
            tapPulse = true
            toast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(motion) { tapPulse = false }
        }
    }

    private func stateTint(_ state: DesignSpecComponentStateV4) -> Color {
        switch state {
        case .error: return palette.danger
        case .warning: return palette.warning
        case .success: return palette.success
        case .locked: return Color.goYellow
        case .selected, .focused, .pressed: return palette.accent
        case .disabled: return palette.secondaryText
        case .loading: return Color.goBlue
        case .empty: return palette.tertiaryText
        default: return palette.secondaryAccent
        }
    }

    private var motion: Animation { DesignSpecUIV4.motionAnimation(selection) }
    private var font: (CGFloat, Font.Weight) -> Font { { size, weight in DesignSpecUIV4.typeFont(size, weight: weight, selection: selection) } }
    private var icon: (String) -> String { { name in DesignSpecUIV4.iconName(name, selection: selection) } }
    private var iconWeight: Font.Weight { DesignSpecUIV4.iconWeight(selection) }
    private var space: (CGFloat, CGFloat, CGFloat) -> CGFloat { { c, b, a in DesignSpecUIV4.density(c, b, a, selection: selection) } }
    private var cardRadius: CGFloat { DesignSpecUIV4.cardRadius(selection) }
    private var innerRadius: CGFloat { DesignSpecUIV4.innerRadius(selection) }
    private var fieldRadius: CGFloat { DesignSpecUIV4.fieldRadius(selection) }
    private var cardShadowOpacity: Double {
        if selection.card == "flat" { return 0 }
        return selection.card == "elevated" ? 0.16 : 0.06
    }
    private var sheetBackdropBlur: CGFloat {
        switch selection.sheetGlass {
        case "nativeRegular", "clear": return 0.4
        case "calendarWidget": return 1.4
        case "edgePrism": return 1.1
        default: return 0.8
        }
    }

    private var sheetTransition: AnyTransition {
        switch selection.transition {
        case "slide": return .move(edge: .bottom).combined(with: .opacity)
        case "fade": return .opacity
        case "blur": return .scale(scale: 0.98).combined(with: .opacity)
        default: return .scale(scale: 0.88, anchor: .bottom).combined(with: .opacity)
        }
    }

    private var fabMenuTransition: AnyTransition {
        switch selection.transition {
        case "slide": return .move(edge: .bottom).combined(with: .opacity)
        case "fade": return .opacity
        case "blur": return .scale(scale: 0.98).combined(with: .opacity)
        default: return .scale(scale: 0.84, anchor: .bottomTrailing).combined(with: .opacity)
        }
    }

    private var sheetTitle: String {
        switch selection.sheet {
        case "overview": return "喂食 Overview"
        case "minimal": return "快速打卡"
        case "confirm": return "确认操作"
        default: return "记录喂食"
        }
    }

    private var sheetActionTitle: String {
        selection.sheet == "confirm" || selection.sheetChrome == "danger" ? "确认删除 / Delete" : "保存记录 / Save"
    }
}

private enum FieldState {
    case normal
    case focused
    case error
    case disabled
}
