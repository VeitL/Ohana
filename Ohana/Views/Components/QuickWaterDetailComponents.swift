//
//  QuickWaterDetailComponents.swift
//  Ohana
//

import SwiftUI

// MARK: - Water detail supporting components extracted for compile-time isolation.

enum WaterOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        }
    }

    var title: String {
        switch self {
        case .days7: return "7天"
        case .days30: return "30天"
        case .days90: return "90天"
        }
    }
}

struct WaterChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct WaterNativeSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.clear)
            .glassEffect(.regular.interactive(false), in: shape)
    }
}

struct WaterInlineSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.clear)
            .glassEffect(.regular.interactive(false), in: shape)
    }
}

struct WaterPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

extension View {
    func waterGlassSurface(cornerRadius: CGFloat, tint: Color = .white, tintOpacity: Double = 0.04) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.62))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
    }
}

struct WaterCoreCard: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let subtitle: String
    let progress: Double?
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var tapAction: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var surface: some ShapeStyle {
        Color.ohanaCardSurface
    }

    var body: some View {
        HStack(spacing: 14) {
            tappableInfo

            VStack(spacing: 8) {
                Button(action: primaryAction) {
                    HStack(spacing: 5) {
                        Image(systemName: primaryIcon)
                            .font(.system(size: 11, weight: .black))
                        Text(primaryTitle)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(minWidth: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .frame(minWidth: 72)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tappableInfo: some View {
        if let tapAction {
            Button(action: tapAction) {
                infoContent
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            infoContent
        }
    }

    private var infoContent: some View {
        HStack(spacing: 14) {
            ZStack {
                if let progress {
                    WaterProgressRing(progress: progress, tint: tint)
                        .frame(width: 58, height: 58)
                } else {
                    Circle()
                        .stroke(tint.opacity(0.2), lineWidth: 7)
                        .frame(width: 58, height: 58)
                }
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }
}

struct WaterProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(GoMotion.page, value: progress)
        }
    }
}

struct WaterHeroCard: View {
    let tint: Color
    let secondaryTint: Color
    let waterCount: Int
    let waterDueProgress: Double
    let filterDueProgress: Double
    let isAquatic: Bool

    @State private var ripple = false
    @State private var isVisible = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(\.colorScheme) private var colorScheme

    private var shouldAnimateHero: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ohanaCardSurface)

            HStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(tint.opacity(0.16 - Double(index) * 0.03), lineWidth: 2)
                            .frame(width: ripple ? 98 + CGFloat(index * 18) : 62 + CGFloat(index * 10))
                            .opacity(ripple ? 0.18 : 0.58)
                            .animation(
                                shouldAnimateHero
                                ? .easeInOut(duration: 1.9 + Double(index) * 0.18).repeatForever(autoreverses: true)
                                : nil,
                                value: ripple
                            )
                    }

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(tint.opacity(0.68), lineWidth: 4)
                            .frame(width: 86, height: 54)
                            .offset(y: 12)
                        Capsule()
                            .fill(tint.opacity(0.28))
                            .frame(width: 68, height: 16)
                            .offset(y: 9)
                        Image(systemName: isAquatic ? "water.waves" : "drop.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(tint)
                            .offset(y: -12)
                    }
                }
                .frame(width: 118, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    Text(isAquatic ? "水体状态" : "今日饮水")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(isAquatic ? "管理" : "\(waterCount) 次")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    HStack(spacing: 12) {
                        MiniWaterGauge(title: "换水", progress: waterDueProgress, tint: tint)
                        MiniWaterGauge(title: "滤芯", progress: filterDueProgress, tint: secondaryTint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            isVisible = true
            updateHeroMotion()
        }
        .onDisappear {
            isVisible = false
            ripple = false
        }
        .onChange(of: shouldAnimateHero) { _, _ in
            updateHeroMotion()
        }
    }

    private func updateHeroMotion() {
        ripple = shouldAnimateHero
    }
}

struct MiniWaterGauge: View {
    let title: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(tint.opacity(0.2))
                .frame(width: 34, height: 8)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, 34 * min(max(progress, 0), 1)), height: 8)
                }
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }
}

struct WaterLogRow: View {
    let log: PetCareLog
    let tint: Color
    var showDelete = true
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.careType.systemIconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(log.careType.label)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if log.amountMl > 0 {
                    Text("\(Int(log.amountMl))ml")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            Spacer()
            Text(log.date, format: .dateTime.month().day().hour().minute())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.55))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 3)
    }
}

struct WaterAmountSettingsSheet: View {
    let tint: Color
    @Binding var amountEnabled: Bool
    @Binding var amountText: String
    let onSave: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("喂水")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text(amountEnabled ? "默认 \(displayAmount)ml" : "只记录次数")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Toggle(isOn: $amountEnabled.animation(GoMotion.feedback)) {
                settingsRow("记录水量", value: amountEnabled ? "开" : "关")
            }
            .tint(tint)

            if amountEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("默认水量")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("250", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .submitLabel(.done)
                            .onSubmit { amountFocused = false }
                        Text("ml")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([100, 150, 200, 250, 300, 500], id: \.self) { amount in
                                Button {
                                    withAnimation(GoMotion.feedback) {
                                        amountText = "\(amount)"
                                        amountFocused = false
                                    }
                                } label: {
                                    Text("\(amount)ml")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            Button {
                amountFocused = false
                onSave()
            } label: {
                Text("保存")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(tint, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { amountFocused = false }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
    }

    private var displayAmount: Int {
        Int((Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 250).rounded())
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

struct WaterChangeSettingsSheet: View {
    let tint: Color
    @Binding var intervalDays: Int
    @Binding var anchorDate: Date
    @Binding var reminderOn: Bool
    let nextDateText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            settingsHero(icon: "arrow.2.circlepath", title: "换水计划", value: "下次 \(nextDateText)")

            Stepper(value: $intervalDays.animation(GoMotion.feedback), in: 1...30) {
                settingsRow("周期", value: "\(intervalDays)天")
            }
            .tint(tint)

            DatePicker("起算日", selection: $anchorDate, displayedComponents: .date)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("日历提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
    }

    private func settingsHero(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

struct FilterSettingsSheet: View {
    let tint: Color
    @Binding var cleanIntervalDays: Int
    @Binding var replaceIntervalDays: Int
    @Binding var reminderOn: Bool
    let nextCleanText: String
    let nextReplaceText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("滤芯计划")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("清洗 \(nextCleanText) · 更换 \(nextReplaceText)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Stepper(value: $cleanIntervalDays.animation(GoMotion.feedback), in: 1...60) {
                settingsRow("清洗", value: "\(cleanIntervalDays)天")
            }
            .tint(tint)

            Stepper(value: $replaceIntervalDays.animation(GoMotion.feedback), in: 7...365) {
                settingsRow("更换", value: "\(replaceIntervalDays)天")
            }
            .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

struct WaterPlanSettingsSheet: View {
    let tint: Color
    @Binding var count: Int
    @Binding var times: [Date]
    let completionText: String
    let onCountChange: (Int) -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 54, height: 54)
                        .background(tint.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("喂水计划")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text("今日 \(completionText) · 每天 \(count) 次")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }

                Stepper(value: $count.animation(GoMotion.feedback), in: 1...6) {
                    settingsRow("每日次数", value: "\(count)次")
                }
                .tint(tint)
                .onChange(of: count) { _, newValue in
                    onCountChange(newValue)
                }

                VStack(spacing: 10) {
                    ForEach(0..<count, id: \.self) { index in
                        DatePicker(
                            "第 \(index + 1) 次",
                            selection: Binding(
                                get: { time(at: index) },
                                set: { setTime($0, at: index) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tint(tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("切回手动")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        onSave()
                    } label: {
                        Text("保存计划")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private func time(at index: Int) -> Date {
        if index < times.count {
            return times[index]
        }
        return WaterPlanWriter.suggestedTimes(count: count)[min(index, max(count - 1, 0))]
    }

    private func setTime(_ date: Date, at index: Int) {
        while times.count <= index {
            times.append(WaterPlanWriter.suggestedTimes(count: count)[min(times.count, max(count - 1, 0))])
        }
        times[index] = date
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

struct WaterHistorySheet: View {
    let logs: [PetCareLog]
    let tintForLog: (PetCareLog) -> Color
    let onDelete: (PetCareLog) -> Void

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    Text("暂无记录")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: tintForLog(log), showDelete: true) {
                            onDelete(log)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("水管理记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
