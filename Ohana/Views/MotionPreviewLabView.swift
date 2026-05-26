//
//  MotionPreviewLabView.swift
//  Ohana
//
//  System-level motion preview for choosing Ohana's restrained premium motion.
//

import SwiftUI

struct MotionPreviewLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var selectedSystem: MotionPreviewSystem = .capsule
    @State private var selectedChartSystem: MotionPreviewSystem = .flow
    @State private var selectedAccent: MotionPreviewAccent = .primary
    @State private var counter = 9709
    @State private var secondaryCounter = 11
    @State private var numberPulse = false
    @State private var floatingDelta: Int?
    @State private var deltaToken = 0
    @State private var progress = 0.62
    @State private var progressPulse = false
    @State private var chartVariant = 0
    @State private var chartReveal = true
    @State private var selectedContext = 0
    @State private var sheetVisible = false
    @State private var sheetContentVisible = false
    @State private var standaloneContentVisible = true
    @State private var triggerToken = 0

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color { selectedAccent.color }
    private var chartSystem: MotionPreviewSystem { selectedChartSystem }
    private var recipeSummary: String {
        l.tr(
            zh: "当前选择：全局 \(selectedSystem.shortName(l))；Chart 使用 \(selectedChartSystem.shortName(l))，线条慢慢延长。",
            en: "Current pick: global \(selectedSystem.shortName(l)); charts use \(selectedChartSystem.shortName(l)) with a slow line draw.",
            de: "Aktuelle Wahl: global \(selectedSystem.shortName(l)); Charts nutzen \(selectedChartSystem.shortName(l)) mit langsamem Linienaufbau."
        )
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    systemSelector
                    accentSelector
                    actionRail
                    motionSpecMatrix
                    numberScenario
                    progressScenario
                    chartScenario
                    contextScenario
                    sheetOpenScenario
                    sheetContentScenario
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.tr(zh: "Motion System 预览", en: "Motion System Preview", de: "Motion-System-Vorschau"))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "3 套完整系统，每套分别定义数字、进度、chart、切换、sheet 打开、sheet 内容加载。",
                    en: "Three complete systems. Each defines numbers, progress, charts, switching, sheet opening, and sheet content loading.",
                    de: "Drei komplette Systeme fuer Zahlen, Fortschritt, Charts, Wechsel, Sheet-Oeffnung und Sheet-Inhaltsladen."
                ))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schliessen"))
        }
    }

    private var systemSelector: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "基础 Motion System", en: "Base Motion System", de: "Basis-Motion-System"),
            subtitle: recipeSummary
        ) {
            VStack(spacing: 10) {
                ForEach(MotionPreviewSystem.allCases) { system in
                    Button {
                        OhanaFeedback.selection()
                        withAnimation(system.animation(.switching, reduceMotion: reduceMotion)) {
                            selectedSystem = system
                            triggerToken += 1
                        }
                        replaySheetContent()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: system.icon)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(selectedSystem == system ? Color.ohanaPrimaryActionText : Color.ohanaFunctionalIcon)
                                .frame(width: 34, height: 34)
                                .background(selectedSystem == system ? accent : Color.ohanaControlFill, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(system.title(l))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                    Text(system.badge(l))
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(selectedSystem == system ? Color.ohanaPrimaryActionText : accent)
                                        .padding(.horizontal, 7)
                                        .frame(height: 20)
                                        .background(selectedSystem == system ? accent : accent.opacity(0.13), in: Capsule())
                                }
                                Text(system.summary(l))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: selectedSystem == system ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedSystem == system ? accent : Color.ohanaTertiaryText)
                        }
                        .padding(10)
                        .background(selectedSystem == system ? accent.opacity(0.14) : Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(selectedSystem == system ? accent.opacity(0.52) : Color.ohanaGlassStroke.opacity(0.68), lineWidth: 1)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var accentSelector: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "5 个原色", en: "Five Base Colors", de: "Fuenf Grundfarben"),
            subtitle: l.tr(zh: "只影响本页预览，不修改全局主题。", en: "This only affects the preview page, not the global theme.", de: "Gilt nur fuer diese Vorschau, nicht fuer das globale Theme.")
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(MotionPreviewAccent.allCases) { item in
                    Button {
                        OhanaFeedback.selection()
                        withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
                            selectedAccent = item
                            triggerToken += 1
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Circle()
                                .fill(item.color)
                                .frame(width: selectedAccent == item ? 34 : 28, height: selectedAccent == item ? 34 : 28)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.ohanaPrimaryText.opacity(selectedAccent == item ? 0.86 : 0), lineWidth: 2)
                                }
                                .shadow(color: item.color.opacity(selectedAccent == item ? 0.32 : 0.10), radius: selectedAccent == item ? 12 : 5, x: 0, y: 5) // ui-v4: allow palette preview glow

                            Text(item.title(l))
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(selectedAccent == item ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(selectedAccent == item ? item.color.opacity(0.14) : Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selectedAccent == item ? item.color.opacity(0.58) : Color.ohanaGlassStroke.opacity(0.65), lineWidth: 1)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var actionRail: some View {
        HStack(spacing: 9) {
            previewCommand(title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "play.fill") {
                playAll()
            }
            previewCommand(title: l.tr(zh: "数字", en: "Number", de: "Zahl"), icon: "number") {
                triggerNumber()
            }
            previewCommand(title: l.tr(zh: "进度", en: "Progress", de: "Fortschritt"), icon: "chart.bar.fill") {
                triggerProgress()
            }
            previewCommand(title: l.tr(zh: "Sheet", en: "Sheet", de: "Sheet"), icon: "rectangle.bottomthird.inset.filled") {
                toggleSheet()
            }
        }
    }

    private func previewCommand(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: accent.opacity(0.22), radius: 12, x: 0, y: 7) // ui-v4: allow primary command depth in motion preview
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var motionSpecMatrix: some View {
        MotionPreviewPanel(
            title: l.tr(zh: "当前 Ohana 配方的 6 项设计", en: "Six Designs in the Current Ohana Recipe", de: "Sechs Designs im aktuellen Ohana-Rezept"),
            subtitle: l.tr(zh: "基础系统使用 Capsule；Chart 单独使用 Flow 的慢线条 reveal。", en: "The base system uses Capsule; charts use Flow's slow line reveal.", de: "Das Basissystem nutzt Capsule; Charts nutzen Flows langsames Linien-Reveal.")
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(MotionPreviewCategory.allCases) { category in
                    let categorySystem = system(for: category)
                    let spec = categorySystem.spec(for: category, l)
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: category.icon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(category.title(l))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(categorySystem.shortName(l))
                                    .font(.system(size: 8, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .padding(.horizontal, 5)
                                    .frame(height: 16)
                                    .background(accent, in: Capsule())
                            }
                            Text(spec)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var numberScenario: some View {
        MotionScenarioPanel(
            category: .number,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerNumber
        ) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(l.tr(zh: "椰子数", en: "Coconut balance", de: "Kokos-Konto"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 15, weight: .black))
                        Text("\(counter)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .ohanaNumericMotion(counter)
                    }
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(accent, in: Capsule())
                    .scaleEffect(numberPulse ? selectedSystem.numberScale : 1)
                    .overlay(alignment: .topTrailing) {
                        if let floatingDelta {
                            Text("+\(floatingDelta)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                                .offset(x: 8, y: selectedSystem.numberDeltaOffset)
                                .transition(selectedSystem.numberDeltaTransition)
                        }
                    }
                    .animation(selectedSystem.animation(.number, reduceMotion: reduceMotion), value: numberPulse)
                    .animation(selectedSystem.animation(.number, reduceMotion: reduceMotion), value: counter)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(l.tr(zh: "Today Focus", en: "Today Focus", de: "Today Focus"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text("\(secondaryCounter)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .ohanaNumericMotion(secondaryCounter)
                        .scaleEffect(numberPulse ? selectedSystem.secondaryNumberScale : 1)
                }
            }
        }
    }

    private var progressScenario: some View {
        MotionScenarioPanel(
            category: .progress,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerProgress
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "能量注入", en: "Energy injection", de: "Energie"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .ohanaNumericMotion(progress)
                        .scaleEffect(progressPulse ? selectedSystem.progressLabelScale : 1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.ohanaControlFill)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(16, geo.size.width * progress))
                            .overlay(alignment: .trailing) {
                                Circle()
                                    .fill(Color.ohanaPrimaryActionText.opacity(selectedSystem.progressCapOpacity))
                                    .frame(width: 9, height: 9)
                                    .padding(.trailing, 4)
                                    .scaleEffect(progressPulse ? selectedSystem.progressCapScale : 1)
                            }
                    }
                }
                .frame(height: 18)
                .animation(selectedSystem.animation(.progress, reduceMotion: reduceMotion), value: progress)

                HStack(spacing: 8) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        Capsule()
                            .fill(index < Int(progress * 5.0) ? accent : Color.ohanaControlFill)
                            .frame(height: 8)
                            .animation(selectedSystem.animation(.progress, reduceMotion: reduceMotion).delay(selectedSystem.progressStagger * Double(index)), value: progress)
                    }
                }
            }
        }
    }

    private var chartScenario: some View {
        MotionScenarioPanel(
            category: .chart,
            system: chartSystem,
            accent: accent,
            localization: l,
            action: triggerChart
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "周趋势", en: "Weekly trend", de: "Wochentrend"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(chartSystem.chartLabel(l))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(accent.opacity(0.14), in: Capsule())
                }

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.ohanaControlFill.opacity(0.54))
                    MotionPreviewChartArea(points: chartPoints)
                        .fill(accent.opacity(0.16))
                        .scaleEffect(x: 1, y: chartReveal ? 1 : chartSystem.chartAreaStartScale, anchor: .bottom)
                        .opacity(chartReveal ? 1 : 0)
                    MotionPreviewChartLine(points: chartPoints)
                        .trim(from: 0, to: chartReveal ? 1 : 0)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    ForEach(chartPoints.indices, id: \.self) { index in
                        MotionPreviewChartDot(
                            point: chartPoints[index],
                            index: index,
                            count: chartPoints.count,
                            accent: accent,
                            visible: chartReveal,
                            system: chartSystem
                        )
                    }
                }
                .frame(height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .animation(chartSystem.animation(.chart, reduceMotion: reduceMotion), value: chartReveal)
            }
        }
    }

    private var contextScenario: some View {
        MotionScenarioPanel(
            category: .switching,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: triggerContextSwitch
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(MotionPreviewContext.fixtures.indices, id: \.self) { index in
                        let item = MotionPreviewContext.fixtures[index]
                        Button {
                            guard selectedContext != index else { return }
                            withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
                                selectedContext = index
                                triggerToken += 1
                            }
                            OhanaFeedback.selection()
                        } label: {
                            Text(item.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(selectedContext == index ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(selectedContext == index ? accent : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                let context = MotionPreviewContext.fixtures[selectedContext]
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "日历快照", en: "Calendar snapshot", de: "Kalender-Snapshot"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            Text(context.name)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        Spacer()
                        Text("\(context.items.count)")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                            .ohanaNumericMotion(context.items.count)
                    }

                    ForEach(context.items.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(index == 0 ? accent : context.tint)
                                .frame(width: 8, height: 8)
                            Text(context.items[index].text(l))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Spacer()
                            Text(index == 0 ? l.tr(zh: "优先", en: "First", de: "Zuerst") : l.tr(zh: "已排程", en: "Ready", de: "Bereit"))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(index == 0 ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(index == 0 ? accent : Color.ohanaControlFill, in: Capsule())
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Color.ohanaControlFill.opacity(0.64), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.ohanaCardSurfaceElevated.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .id(selectedContext)
                .transition(selectedSystem.switchTransition)
                .ohanaContextHandoff(triggerToken, direction: .neutral, initialScale: selectedSystem.switchInitialScale)
            }
        }
    }

    private var sheetOpenScenario: some View {
        MotionScenarioPanel(
            category: .sheetOpen,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: toggleSheet
        ) {
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(l.tr(
                        zh: "这里专门看 sheet 外壳打开/关闭：位移、缩放、透明度、遮罩节奏。",
                        en: "This isolates sheet shell open/close: offset, scale, opacity, and scrim rhythm.",
                        de: "Isoliert die Sheet-Huelle: Versatz, Skalierung, Deckkraft und Scrim-Rhythmus."
                    ))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        toggleSheet()
                    } label: {
                        Label(sheetVisible ? l.tr(zh: "关闭 Sheet", en: "Close Sheet", de: "Sheet schliessen") : l.tr(zh: "打开 Sheet", en: "Open Sheet", de: "Sheet oeffnen"), systemImage: "rectangle.bottomthird.inset.filled")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.bottom, sheetVisible ? 160 : 0)

                if sheetVisible {
                    MotionPreviewSheetShell(
                        system: selectedSystem,
                        accent: accent,
                        localization: l,
                        contentVisible: sheetContentVisible,
                        onClose: toggleSheet,
                        onConfirm: {
                            triggerNumber()
                            toggleSheet()
                        }
                    )
                    .transition(selectedSystem.sheetTransition)
                }
            }
            .frame(minHeight: 264, alignment: .top)
            .animation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion), value: sheetVisible)
        }
    }

    private var sheetContentScenario: some View {
        MotionScenarioPanel(
            category: .sheetContent,
            system: selectedSystem,
            accent: accent,
            localization: l,
            action: replaySheetContent
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "内容加载节奏", en: "Content loading rhythm", de: "Inhalts-Laderhythmus"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(selectedSystem.contentLabel(l))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(accent.opacity(0.14), in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(MotionPreviewLoadingRow.fixtures.indices, id: \.self) { index in
                        MotionPreviewContentLoadingRow(
                            row: MotionPreviewLoadingRow.fixtures[index],
                            index: index,
                            visible: standaloneContentVisible,
                            accent: accent,
                            system: selectedSystem,
                            localization: l
                        )
                    }
                }
            }
        }
    }

    private var chartPoints: [CGFloat] {
        MotionPreviewChartFixtures.points[chartVariant % MotionPreviewChartFixtures.points.count]
    }

    private func system(for category: MotionPreviewCategory) -> MotionPreviewSystem {
        category == .chart ? selectedChartSystem : selectedSystem
    }

    private func playAll() {
        triggerNumber()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            triggerProgress()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            triggerChart()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            triggerContextSwitch()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            replaySheetContent()
        }
    }

    private func triggerNumber() {
        let token = deltaToken + 1
        deltaToken = token
        floatingDelta = selectedSystem == .signal ? 18 : 12
        OhanaFeedback.light()
        withAnimation(selectedSystem.animation(.number, reduceMotion: reduceMotion)) {
            numberPulse = true
            counter += floatingDelta ?? 0
            secondaryCounter += 1
            triggerToken += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.numberSettleDelay) {
            guard deltaToken == token else { return }
            withAnimation(selectedSystem.animation(.number, reduceMotion: reduceMotion)) {
                numberPulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.numberDeltaLife) {
            guard deltaToken == token else { return }
            withAnimation(GoMotion.quick) {
                floatingDelta = nil
            }
        }
    }

    private func triggerProgress() {
        let next = progress > 0.84 ? 0.36 : min(0.94, progress + selectedSystem.progressStep)
        withAnimation(selectedSystem.animation(.progress, reduceMotion: reduceMotion)) {
            progressPulse = true
            progress = next
            triggerToken += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.progressPulseLife) {
            withAnimation(selectedSystem.animation(.progress, reduceMotion: reduceMotion)) {
                progressPulse = false
            }
        }
        OhanaFeedback.selection()
    }

    private func triggerChart() {
        chartVariant = (chartVariant + 1) % MotionPreviewChartFixtures.points.count
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            chartReveal = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(chartSystem.animation(.chart, reduceMotion: reduceMotion)) {
                chartReveal = true
                triggerToken += 1
            }
        }
        OhanaFeedback.selection()
    }

    private func triggerContextSwitch() {
        withAnimation(selectedSystem.animation(.switching, reduceMotion: reduceMotion)) {
            selectedContext = (selectedContext + 1) % MotionPreviewContext.fixtures.count
            triggerToken += 1
        }
        OhanaFeedback.selection()
    }

    private func toggleSheet() {
        if sheetVisible {
            withAnimation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion)) {
                sheetVisible = false
                sheetContentVisible = false
            }
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sheetContentVisible = false
        }
        withAnimation(selectedSystem.animation(.sheetOpen, reduceMotion: reduceMotion)) {
            sheetVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + selectedSystem.sheetContentStartDelay) {
            withAnimation(selectedSystem.animation(.sheetContent, reduceMotion: reduceMotion)) {
                sheetContentVisible = true
            }
        }
        OhanaFeedback.soft()
    }

    private func replaySheetContent() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            standaloneContentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(selectedSystem.animation(.sheetContent, reduceMotion: reduceMotion)) {
                standaloneContentVisible = true
                triggerToken += 1
            }
        }
    }
}

private enum MotionPreviewCategory: String, CaseIterable, Identifiable {
    case number
    case progress
    case chart
    case switching
    case sheetOpen
    case sheetContent

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .number: return "number"
        case .progress: return "chart.bar.fill"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .switching: return "person.2.fill"
        case .sheetOpen: return "rectangle.bottomthird.inset.filled"
        case .sheetContent: return "list.bullet.rectangle"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .number:
            return l.tr(zh: "数字", en: "Numbers", de: "Zahlen")
        case .progress:
            return l.tr(zh: "进度条", en: "Progress", de: "Fortschritt")
        case .chart:
            return l.tr(zh: "Chart", en: "Chart", de: "Chart")
        case .switching:
            return l.tr(zh: "切换", en: "Switching", de: "Wechsel")
        case .sheetOpen:
            return l.tr(zh: "Sheet 打开", en: "Sheet Opening", de: "Sheet-Oeffnung")
        case .sheetContent:
            return l.tr(zh: "Sheet 内容加载", en: "Sheet Content Loading", de: "Sheet-Inhaltsladen")
        }
    }
}

private enum MotionPreviewSystem: String, CaseIterable, Identifiable {
    case flow
    case capsule
    case signal

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flow: return "water.waves"
        case .capsule: return "circle.hexagongrid.fill"
        case .signal: return "sparkles"
        }
    }

    var numberScale: CGFloat {
        switch self {
        case .flow: return 1.035
        case .capsule: return 1.105
        case .signal: return 1.12
        }
    }

    var secondaryNumberScale: CGFloat {
        switch self {
        case .flow: return 1.012
        case .capsule: return 1.035
        case .signal: return 1.045
        }
    }

    var numberDeltaOffset: CGFloat {
        switch self {
        case .flow: return -18
        case .capsule: return -23
        case .signal: return -28
        }
    }

    var numberSettleDelay: Double {
        switch self {
        case .flow: return 0.18
        case .capsule: return 0.24
        case .signal: return 0.30
        }
    }

    var numberDeltaLife: Double {
        switch self {
        case .flow: return 0.82
        case .capsule: return 1.05
        case .signal: return 1.14
        }
    }

    var progressStep: Double {
        switch self {
        case .flow: return 0.14
        case .capsule: return 0.18
        case .signal: return 0.22
        }
    }

    var progressLabelScale: CGFloat {
        switch self {
        case .flow: return 1.01
        case .capsule: return 1.035
        case .signal: return 1.05
        }
    }

    var progressCapScale: CGFloat {
        switch self {
        case .flow: return 1.08
        case .capsule: return 1.20
        case .signal: return 1.30
        }
    }

    var progressCapOpacity: Double {
        switch self {
        case .flow: return 0.38
        case .capsule: return 0.62
        case .signal: return 0.74
        }
    }

    var progressStagger: Double {
        switch self {
        case .flow: return 0.012
        case .capsule: return 0.026
        case .signal: return 0.038
        }
    }

    var progressPulseLife: Double {
        switch self {
        case .flow: return 0.16
        case .capsule: return 0.22
        case .signal: return 0.26
        }
    }

    var chartAreaStartScale: CGFloat {
        switch self {
        case .flow: return 1.0
        case .capsule: return 0.84
        case .signal: return 0.74
        }
    }

    var chartDotStartScale: CGFloat {
        switch self {
        case .flow: return 0.96
        case .capsule: return 0.70
        case .signal: return 0.55
        }
    }

    var chartDotStagger: Double {
        switch self {
        case .flow: return 0.045
        case .capsule: return 0.026
        case .signal: return 0.040
        }
    }

    var switchInitialScale: CGFloat {
        switch self {
        case .flow: return 0.998
        case .capsule: return 0.990
        case .signal: return 0.984
        }
    }

    var sheetContentStartDelay: Double {
        switch self {
        case .flow: return 0.08
        case .capsule: return 0.10
        case .signal: return 0.12
        }
    }

    var contentRowOffset: CGFloat {
        switch self {
        case .flow: return 6
        case .capsule: return 12
        case .signal: return 16
        }
    }

    var contentRowScale: CGFloat {
        switch self {
        case .flow: return 0.996
        case .capsule: return 0.982
        case .signal: return 0.970
        }
    }

    var contentStagger: Double {
        switch self {
        case .flow: return 0.018
        case .capsule: return 0.035
        case .signal: return 0.052
        }
    }

    var numberDeltaTransition: AnyTransition {
        switch self {
        case .flow:
            return .opacity.combined(with: .offset(y: -10))
        case .capsule:
            return .scale(scale: 0.72, anchor: .bottom).combined(with: .opacity)
        case .signal:
            return .scale(scale: 0.58, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: -8))
        }
    }

    var switchTransition: AnyTransition {
        switch self {
        case .flow:
            return .opacity
        case .capsule:
            return .opacity.combined(with: .scale(scale: 0.988, anchor: .top))
        case .signal:
            return .opacity.combined(with: .scale(scale: 0.976, anchor: .top))
        }
    }

    var sheetTransition: AnyTransition {
        switch self {
        case .flow:
            return .move(edge: .bottom).combined(with: .opacity)
        case .capsule:
            return .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.985, anchor: .bottom))
        case .signal:
            return .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.960, anchor: .bottom))
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "A. Flow", en: "A. Flow", de: "A. Flow")
        case .capsule:
            return l.tr(zh: "B. Capsule", en: "B. Capsule", de: "B. Capsule")
        case .signal:
            return l.tr(zh: "C. Signal", en: "C. Signal", de: "C. Signal")
        }
    }

    func shortName(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "Flow", en: "Flow", de: "Flow")
        case .capsule:
            return l.tr(zh: "Capsule", en: "Capsule", de: "Capsule")
        case .signal:
            return l.tr(zh: "Signal", en: "Signal", de: "Signal")
        }
    }

    func badge(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "日常", en: "Daily", de: "Alltag")
        case .capsule:
            return l.tr(zh: "推荐", en: "Pick", de: "Favorit")
        case .signal:
            return l.tr(zh: "奖励", en: "Reward", de: "Belohnung")
        }
    }

    func summary(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "最克制，数字像流水，切换几乎无位移。适合日历、表单、长列表。", en: "The quietest system: fluid numbers and nearly no movement for switching. Good for calendars, forms, and long lists.", de: "Am ruhigsten: fliessende Zahlen, kaum Bewegung beim Wechsel. Gut fuer Kalender, Formulare und Listen.")
        case .capsule:
            return l.tr(zh: "接近你喜欢的椰子胶囊：轻弹、numeric motion、反馈清晰但不夸张。", en: "Closest to the coconut capsule feel: light spring, numeric motion, clear but restrained feedback.", de: "Nahe am Kokos-Kapsel-Gefuehl: leichte Federung, Zahlenbewegung, klares aber dezentes Feedback.")
        case .signal:
            return l.tr(zh: "更适合打卡/财富/奖励瞬间，普通切换仍压低幅度。", en: "Best for check-ins, wealth, and reward moments while normal switching stays controlled.", de: "Gut fuer Check-ins, Vermoegen und Belohnungen, normale Wechsel bleiben kontrolliert.")
        }
    }

    func positioning(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "像水一样顺，不吸引注意。", en: "Smooth like water, without asking for attention.", de: "Fliessend wie Wasser, ohne Aufmerksamkeit zu fordern.")
        case .capsule:
            return l.tr(zh: "全局默认候选：高级、轻弹、可长期使用。", en: "Global default candidate: premium, lightly elastic, usable everywhere.", de: "Kandidat fuer den Standard: hochwertig, leicht elastisch, ueberall nutzbar.")
        case .signal:
            return l.tr(zh: "强调成功和奖励，不用于高频普通切换。", en: "Emphasizes success and rewards, not for frequent ordinary switching.", de: "Betont Erfolg und Belohnung, nicht fuer haeufige normale Wechsel.")
        }
    }

    func spec(for category: MotionPreviewCategory, _ l: L10n) -> String {
        switch (self, category) {
        case (.flow, .number):
            return l.tr(zh: "numericText + 1.035 scale + 0.82s delta fade", en: "numericText + 1.035 scale + 0.82s delta fade", de: "numericText + 1.035 Skalierung + 0.82s Delta")
        case (.flow, .progress):
            return l.tr(zh: "0.42/0.96 spring，几乎无弹跳", en: "0.42/0.96 spring, almost no bounce", de: "0.42/0.96 Feder, fast kein Bounce")
        case (.flow, .chart):
            return l.tr(zh: "0.72s 线条延长 + area 轻淡入，点位轻显", en: "0.72s slow line draw + soft area fade, quiet dots", de: "0.72s langsamer Linienaufbau + weiche Flaeche")
        case (.flow, .switching):
            return l.tr(zh: "opacity handoff，0.998 snapshot scale", en: "opacity handoff, 0.998 snapshot scale", de: "Opacity-Handoff, 0.998 Snapshot")
        case (.flow, .sheetOpen):
            return l.tr(zh: "bottom slide + fade，无明显 pop", en: "bottom slide + fade, no obvious pop", de: "Bottom-Slide + Fade")
        case (.flow, .sheetContent):
            return l.tr(zh: "18ms row stagger，6pt 上浮", en: "18ms row stagger, 6pt lift", de: "18ms Zeilen-Stagger, 6pt Lift")
        case (.capsule, .number):
            return l.tr(zh: "numericText + 1.105 capsule pulse + floating delta", en: "numericText + 1.105 capsule pulse + floating delta", de: "numericText + 1.105 Kapsel-Puls")
        case (.capsule, .progress):
            return l.tr(zh: "进度尾点轻弹，26ms 分段 stagger", en: "elastic trailing cap, 26ms segment stagger", de: "Elastische Kappe, 26ms Stagger")
        case (.capsule, .chart):
            return l.tr(zh: "area grow + line trim + 点位依次弹出", en: "area grow + line trim + staged dot pop", de: "Flaeche waechst + Punkte poppen")
        case (.capsule, .switching):
            return l.tr(zh: "opacity + 0.988 scale，像快照换气", en: "opacity + 0.988 scale, snapshot breath", de: "Opacity + 0.988 Snapshot-Atmen")
        case (.capsule, .sheetOpen):
            return l.tr(zh: "bottomSpringScaleFade，轻弹落位", en: "bottomSpringScaleFade, lightly settles", de: "BottomSpringScaleFade")
        case (.capsule, .sheetContent):
            return l.tr(zh: "35ms row stagger，12pt/0.982 进入", en: "35ms row stagger, 12pt/0.982 entrance", de: "35ms Stagger, 12pt/0.982")
        case (.signal, .number):
            return l.tr(zh: "奖励数字 1.12 pop，delta 更高更快", en: "reward number 1.12 pop, higher faster delta", de: "Belohnungszahl 1.12 Pop")
        case (.signal, .progress):
            return l.tr(zh: "尾点更亮，38ms 阶段推进", en: "brighter cap, 38ms staged push", de: "Hellere Kappe, 38ms Stufen")
        case (.signal, .chart):
            return l.tr(zh: "chart reveal 更强，但只一次", en: "stronger one-shot chart reveal", de: "Staerkeres einmaliges Reveal")
        case (.signal, .switching):
            return l.tr(zh: "0.976 scale，仍禁止横跳", en: "0.976 scale, still no lateral jump", de: "0.976 Skalierung, kein Seitensprung")
        case (.signal, .sheetOpen):
            return l.tr(zh: "更明显的 bottom pop，只给奖励/确认", en: "more visible bottom pop for rewards/confirm", de: "Staerkerer Bottom-Pop")
        case (.signal, .sheetContent):
            return l.tr(zh: "52ms staged reveal，适合奖品列表", en: "52ms staged reveal, for reward lists", de: "52ms gestaffeltes Reveal")
        }
    }

    func chartLabel(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "线条生长", en: "Line draw", de: "Linienaufbau")
        case .capsule:
            return l.tr(zh: "点位轻弹", en: "Dot pop", de: "Punkt-Pop")
        case .signal:
            return l.tr(zh: "奖励强调", en: "Reward emphasis", de: "Belohnungsfokus")
        }
    }

    func contentLabel(_ l: L10n) -> String {
        switch self {
        case .flow:
            return l.tr(zh: "轻淡入", en: "Soft fade", de: "Weicher Fade")
        case .capsule:
            return l.tr(zh: "轻弹加载", en: "Elastic load", de: "Elastisches Laden")
        case .signal:
            return l.tr(zh: "分段揭示", en: "Staged reveal", de: "Gestaffeltes Reveal")
        }
    }

    func animation(_ category: MotionPreviewCategory, reduceMotion: Bool) -> Animation {
        guard !reduceMotion else { return GoMotion.reduced }
        switch (self, category) {
        case (.flow, .number):
            return .interactiveSpring(response: 0.26, dampingFraction: 0.94, blendDuration: 0.08)
        case (.flow, .progress):
            return .interactiveSpring(response: 0.42, dampingFraction: 0.96, blendDuration: 0.16)
        case (.flow, .chart):
            return .easeOut(duration: 0.72)
        case (.flow, .switching):
            return .interactiveSpring(response: 0.34, dampingFraction: 0.98, blendDuration: 0.14)
        case (.flow, .sheetOpen):
            return .interactiveSpring(response: 0.42, dampingFraction: 0.94, blendDuration: 0.18)
        case (.flow, .sheetContent):
            return .easeOut(duration: 0.22)
        case (.capsule, .number):
            return GoMotion.feedback
        case (.capsule, .progress):
            return .interactiveSpring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.14)
        case (.capsule, .chart):
            return .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.16)
        case (.capsule, .switching):
            return GoMotion.selection
        case (.capsule, .sheetOpen):
            return GoMotion.sheetEnter
        case (.capsule, .sheetContent):
            return .interactiveSpring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.12)
        case (.signal, .number):
            return .interactiveSpring(response: 0.22, dampingFraction: 0.72, blendDuration: 0.08)
        case (.signal, .progress):
            return .interactiveSpring(response: 0.30, dampingFraction: 0.78, blendDuration: 0.12)
        case (.signal, .chart):
            return .interactiveSpring(response: 0.40, dampingFraction: 0.82, blendDuration: 0.16)
        case (.signal, .switching):
            return .interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.14)
        case (.signal, .sheetOpen):
            return .interactiveSpring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.16)
        case (.signal, .sheetContent):
            return .interactiveSpring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.12)
        }
    }
}

private enum MotionPreviewAccent: String, CaseIterable, Identifiable {
    case primary
    case blue
    case teal
    case purple
    case orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .primary: return Color.goPrimary
        case .blue: return Color.goBlue
        case .teal: return Color.goTeal
        case .purple: return Color.goPurple
        case .orange: return Color.goOrange
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .primary: return l.tr(zh: "主色", en: "Primary", de: "Primaer")
        case .blue: return l.tr(zh: "蓝", en: "Blue", de: "Blau")
        case .teal: return l.tr(zh: "青", en: "Teal", de: "Tuerkis")
        case .purple: return l.tr(zh: "紫", en: "Purple", de: "Violett")
        case .orange: return l.tr(zh: "橙", en: "Orange", de: "Orange")
        }
    }
}

private struct MotionPreviewPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }
}

private struct MotionScenarioPanel<Content: View>: View {
    let category: MotionPreviewCategory
    let system: MotionPreviewSystem
    let accent: Color
    let localization: L10n
    let action: () -> Void
    let content: Content

    init(
        category: MotionPreviewCategory,
        system: MotionPreviewSystem,
        accent: Color,
        localization: L10n,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.category = category
        self.system = system
        self.accent = accent
        self.localization = localization
        self.action = action
        self.content = content()
    }

    var body: some View {
        MotionPreviewPanel(title: category.title(localization), subtitle: system.spec(for: category, localization)) {
            VStack(alignment: .leading, spacing: 12) {
                content

                Button(action: action) {
                    Label(localization.tr(zh: "重新预览", en: "Replay", de: "Erneut zeigen"), systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

private struct MotionPreviewChartLine: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        var path = Path()
        let step = rect.width / CGFloat(points.count - 1)
        for index in points.indices {
            let x = CGFloat(index) * step
            let y = rect.height * (1 - points[index])
            if index == points.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct MotionPreviewChartArea: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        var path = MotionPreviewChartLine(points: points).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct MotionPreviewChartDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let point: CGFloat
    let index: Int
    let count: Int
    let accent: Color
    let visible: Bool
    let system: MotionPreviewSystem

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .position(
                    x: CGFloat(index) * geo.size.width / CGFloat(max(count - 1, 1)),
                    y: geo.size.height * (1 - point)
                )
                .scaleEffect(visible ? 1 : system.chartDotStartScale)
                .opacity(visible ? 1 : 0)
                .animation(system.animation(.chart, reduceMotion: reduceMotion).delay(system.chartDotStagger * Double(index)), value: visible)
        }
        .allowsHitTesting(false)
    }
}

private struct MotionPreviewSheetShell: View {
    let system: MotionPreviewSystem
    let accent: Color
    let localization: L10n
    let contentVisible: Bool
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.ohanaSecondaryText.opacity(0.42))
                .frame(width: 44, height: 5)

            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.tr(zh: "短 Sheet", en: "Short Sheet", de: "Kurzes Sheet"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(system.title(localization))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(spacing: 8) {
                ForEach(MotionPreviewLoadingRow.fixtures.indices, id: \.self) { index in
                    MotionPreviewContentLoadingRow(
                        row: MotionPreviewLoadingRow.fixtures[index],
                        index: index,
                        visible: contentVisible,
                        accent: accent,
                        system: system,
                        localization: localization
                    )
                }
            }

            Button(action: onConfirm) {
                Text(localization.tr(zh: "确认 +12", en: "Confirm +12", de: "Bestaetigen +12"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.18), radius: 24, x: 0, y: 14) // ui-v4: allow short sheet preview depth
    }
}

private struct MotionPreviewContentLoadingRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let row: MotionPreviewLoadingRow
    let index: Int
    let visible: Bool
    let accent: Color
    let system: MotionPreviewSystem
    let localization: L10n

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(visible ? Color.ohanaPrimaryActionText : accent)
                .frame(width: 30, height: 30)
                .background(visible ? accent : accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title.text(localization))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(row.subtitle.text(localization))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(row.value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : system.contentRowOffset)
        .scaleEffect(visible ? 1 : system.contentRowScale, anchor: .top)
        .animation(system.animation(.sheetContent, reduceMotion: reduceMotion).delay(system.contentStagger * Double(index)), value: visible)
    }
}

private struct MotionPreviewContext {
    let name: String
    let tint: Color
    let items: [MotionPreviewLocalizedText]

    static let fixtures: [MotionPreviewContext] = [
        MotionPreviewContext(
            name: "Mochi",
            tint: Color.goPurple,
            items: [
                MotionPreviewLocalizedText(zh: "08:30 喂食", en: "08:30 Feed", de: "08:30 Fuettern"),
                MotionPreviewLocalizedText(zh: "13:00 遛弯", en: "13:00 Walk", de: "13:00 Spaziergang"),
                MotionPreviewLocalizedText(zh: "21:00 刷牙", en: "21:00 Teeth", de: "21:00 Zaehne"),
            ]
        ),
        MotionPreviewContext(
            name: "lilo",
            tint: Color.goOrange,
            items: [
                MotionPreviewLocalizedText(zh: "09:00 换水", en: "09:00 Water", de: "09:00 Wasser"),
                MotionPreviewLocalizedText(zh: "16:30 梳毛", en: "16:30 Brush", de: "16:30 Buersten"),
                MotionPreviewLocalizedText(zh: "20:40 体重", en: "20:40 Weight", de: "20:40 Gewicht"),
            ]
        ),
        MotionPreviewContext(
            name: "Lee",
            tint: Color.goTeal,
            items: [
                MotionPreviewLocalizedText(zh: "07:45 用药", en: "07:45 Meds", de: "07:45 Medizin"),
                MotionPreviewLocalizedText(zh: "12:15 喝水", en: "12:15 Water", de: "12:15 Wasser"),
                MotionPreviewLocalizedText(zh: "19:30 复盘", en: "19:30 Review", de: "19:30 Review"),
            ]
        ),
    ]
}

private struct MotionPreviewLoadingRow {
    let icon: String
    let title: MotionPreviewLocalizedText
    let subtitle: MotionPreviewLocalizedText
    let value: String

    static let fixtures: [MotionPreviewLoadingRow] = [
        MotionPreviewLoadingRow(
            icon: "checkmark",
            title: MotionPreviewLocalizedText(zh: "打卡结果", en: "Check-in result", de: "Check-in Ergebnis"),
            subtitle: MotionPreviewLocalizedText(zh: "业务结果已经准备好", en: "Business result is already ready", de: "Ergebnis ist bereit"),
            value: "+12"
        ),
        MotionPreviewLoadingRow(
            icon: "chart.bar.fill",
            title: MotionPreviewLocalizedText(zh: "今日统计", en: "Today stats", de: "Heute Statistik"),
            subtitle: MotionPreviewLocalizedText(zh: "作为 snapshot 轻量呈现", en: "Rendered as a lightweight snapshot", de: "Als leichter Snapshot dargestellt"),
            value: "84%"
        ),
        MotionPreviewLoadingRow(
            icon: "bell.fill",
            title: MotionPreviewLocalizedText(zh: "提醒状态", en: "Reminder state", de: "Erinnerungsstatus"),
            subtitle: MotionPreviewLocalizedText(zh: "不在动画帧里重新同步", en: "No resync inside the animation frame", de: "Keine Resyncs im Animationsframe"),
            value: "3"
        ),
    ]
}

private struct MotionPreviewLocalizedText {
    let zh: String
    let en: String
    let de: String

    func text(_ l: L10n) -> String {
        l.tr(zh: zh, en: en, de: de)
    }
}

private enum MotionPreviewChartFixtures {
    static let points: [[CGFloat]] = [
        [0.30, 0.44, 0.38, 0.58, 0.62, 0.74, 0.82],
        [0.48, 0.36, 0.54, 0.50, 0.68, 0.64, 0.88],
        [0.22, 0.34, 0.45, 0.42, 0.61, 0.76, 0.72],
    ]
}

#Preview {
    NavigationStack {
        MotionPreviewLabView()
    }
}
