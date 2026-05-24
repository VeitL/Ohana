//
//  WeightHistoryView.swift
//  Ohana
//
//  体重历史页 (C8a) - 上部图表 + 下部前置layer记录列表
//

import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)? = nil
    var showsCloseButton: Bool = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var showingWeightPopup = false
    @State private var isInlineWeightComposerVisible = false
    @State private var newWeightText = ""
    @State private var newWeightUnit = "kg"
    @State private var newWeightDate = Date()

    private var sortedLogs: [PetWeightLog] {
        pet.weightLogs.sorted(by: { $0.date > $1.date })
    }

    private var chartLogs: [PetWeightLog] {
        Array(pet.weightLogs.sorted(by: { $0.date < $1.date }).suffix(20))
    }

    // MARK: - Feeding data helpers
    private var recentFoodRecords: [PetFoodRecord] {
        pet.foodRecords.sorted { $0.startDate > $1.startDate }.prefix(7).map { $0 }
    }
    private var avgDailyGrams: Double? {
        let precise = recentFoodRecords.filter { $0.dailyGrams > 0 }
        guard !precise.isEmpty else { return nil }
        return precise.reduce(0.0) { $0 + $1.dailyGrams } / Double(precise.count)
    }

    private var parsedInlineWeight: Double? {
        CountryDecimalInput.parse(newWeightText, countryCode: appCountry)
    }

    private var canSaveInlineWeight: Bool {
        (parsedInlineWeight ?? 0) > 0
    }

    private var inlineQuickWeights: [Double] {
        let latestKg = sortedLogs.first?.weightInKg
        let base = latestKg ?? (pet.species.lowercased().contains("cat") || pet.species.contains("猫") ? 4.0 : 10.0)
        return [base - 0.2, base, base + 0.2]
            .filter { $0 > 0 }
            .map { (($0 * 10).rounded() / 10) }
    }

    var body: some View {
        ZStack {
            PetWeightDashboardContent(
                pet: pet,
                showsCloseButton: showsCloseButton,
                onClose: { dismiss() },
                onAdd: {
                    withAnimation(GoMotion.feedback) {
                        showingWeightPopup = true
                    }
                },
                onRemove: onRemove
            )

            if showingWeightPopup {
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            showingWeightPopup = false
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("体重趋势")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if let latest = sortedLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(displayWeightValue(latest))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(displayWeightUnit(latest))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        }
                    }
                }
                Spacer()
                // 宠物头像
                PetAvatarPortraitView(
                    imageData: pet.avatarImageData,
                    fallbackText: pet.avatarEmoji,
                    themeColor: Color(hex: pet.safeThemeColorHex),
                    size: 56,
                    backgroundOpacity: 0.18
                )
                .overlay(Circle().strokeBorder(Color.ohanaSecondaryText.opacity(0.2), lineWidth: 2))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 变化标签
            if chartLogs.count >= 2 {
                let first = chartLogs.first!.weightInKg
                let last  = chartLogs.last!.weightInKg
                let delta = last - first
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(displayWeightDelta(delta))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .goGlassBackground(Capsule())
                .padding(.horizontal, 24)
            }

            // 折线图
            if chartLogs.count >= 2 {
                WeightDetailLineChart(logs: chartLogs)
                    .frame(height: 130)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // X轴标签
                let recent = chartLogs
                if let f = recent.first, let l = recent.last {
                    HStack {
                        Text(f.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(l.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .padding(.horizontal, 24)
                }
            } else {
                Text("记录 2 条以上体重后可显示趋势图")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }

            Spacer()
        }
    }

    // MARK: - Feeding Insight Banner
    private func feedingInsightBanner(avg: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.goOrange)
                .frame(width: 36, height: 36)
                .background(Color.goOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("饮食 · 体重关联")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                HStack(spacing: 4) {
                    Text(String(format: "近期日均摄入 %.0fg", avg))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if let latest = sortedLogs.first, let prev = sortedLogs.dropFirst().first {
                        let delta = latest.weightInKg - prev.weightInKg
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(delta >= 0 ? Color.goOrange : Color.goTeal)
                        Text(displayWeightDelta(delta))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(delta >= 0 ? Color.goOrange : Color.goTeal)
                    }
                }
            }

            Spacer()

            // Mini bar showing last few food records
            HStack(alignment: .bottom, spacing: 3) {
                let maxG = recentFoodRecords.map { $0.dailyGrams }.max() ?? 1
                ForEach(Array(recentFoodRecords.prefix(5).enumerated()), id: \.offset) { i, rec in
                    let h = max(6, CGFloat(rec.dailyGrams / maxG) * 28)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == 0 ? Color.goOrange : Color.goOrange.opacity(0.35))
                        .frame(width: 6, height: h)
                }
            }
            .frame(height: 28)
        }
        .padding(12)
        .goTranslucentCard(cornerRadius: 14)
    }

    // MARK: - Record List Layer
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                HStack {
                    Text("历史记录")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text("\(sortedLogs.count) 条")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        if isInlineWeightComposerVisible {
                            inlineWeightComposer
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        ForEach(sortedLogs) { log in
                            weightRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text("还没有体重记录\n点击右上角 + 在这里记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var inlineWeightComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录体重")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("不用系统键盘，直接快速输入")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        isInlineWeightComposerVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(newWeightText.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 1, countryCode: appCountry) : newWeightText)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(newWeightText.isEmpty ? Color.ohanaSecondaryText.opacity(0.55) : Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Spacer()
                    Picker("", selection: $newWeightUnit) {
                        Text("kg").tag("kg")
                        Text("g").tag("g")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 118)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                EmbeddedDecimalKeypad(
                    text: $newWeightText,
                    countryCode: appCountry,
                    maxFractionDigits: 2,
                    accent: .goPrimary,
                    isMini: true,
                    showsSubmitButton: false
                )
            }

            HStack(spacing: 8) {
                ForEach(inlineQuickWeights, id: \.self) { weight in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            newWeightText = CountryDecimalInput.format(weight, countryCode: appCountry, maxFractionDigits: 1)
                            newWeightUnit = "kg"
                        }
                    } label: {
                        Text("\(CountryDecimalInput.format(weight, countryCode: appCountry, maxFractionDigits: 1)) kg")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                Text("日期")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DatePicker("", selection: $newWeightDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: saveInlineWeight) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("保存体重")
                }
                .font(OhanaFont.body(.black))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSaveInlineWeight ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .disabled(!canSaveInlineWeight)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func bcsColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return Color(hex: "4ECDC4")
        case 4...5: return Color.goPrimary
        case 6...7: return Color(hex: "FFD93D")
        default:    return Color(hex: "FF6B6B")
        }
    }

    private func displayWeightValue(_ log: PetWeightLog) -> String {
        let formatted = AppMeasurementSystem.formatWeightKilograms(log.weightInKg)
        return formatted.split(separator: " ").first.map(String.init) ?? formatted
    }

    private func displayWeightUnit(_ log: PetWeightLog) -> String {
        let parts = AppMeasurementSystem.formatWeightKilograms(log.weightInKg).split(separator: " ")
        return parts.dropFirst().first.map(String.init) ?? log.weightUnit
    }

    private func displayWeightDelta(_ kilograms: Double) -> String {
        let converted = AppMeasurementSystem.code == "imperial" ? kilograms * 2.2046226218 : kilograms
        let unit = AppMeasurementSystem.code == "imperial" ? "lb" : "kg"
        return String(format: "%+.2f %@", converted, unit)
    }

    private func weightRow(log: PetWeightLog) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.primary.opacity(0.6))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                Text(log.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(displayWeightValue(log))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(displayWeightUnit(log))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                }
                if log.bcsScore > 0 {
                    Text("BCS \(log.bcsScore)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(bcsColor(log.bcsScore), in: Capsule())
                }
            }

            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func saveInlineWeight() {
        guard let value = parsedInlineWeight, value > 0 else { return }
        let log = PetWeightLog(
            date: newWeightDate,
            weight: value,
            weightUnit: newWeightUnit,
            bcsScore: autoBCS(for: value, unit: newWeightUnit),
            pet: pet,
            executorId: UserDefaults.standard.string(forKey: "currentActiveHumanId")
        )
        modelContext.insert(log)
        QuestManager.shared.awardAction(type: .weight, pet: pet, context: modelContext)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) {
            newWeightText = ""
            newWeightUnit = "kg"
            newWeightDate = Date()
            isInlineWeightComposerVisible = false
        }
    }

    private func autoBCS(for value: Double, unit: String) -> Int {
        let kg = unit == "g" ? value / 1000.0 : value
        return PetBodyConditionEstimator.suggestedBCS(for: pet, weightKg: kg)
    }
}

// MARK: - Weight Detail Line Chart (大图)
struct WeightDetailLineChart: View {
    let logs: [PetWeightLog]

    private var sortedLogs: [PetWeightLog] {
        logs.sorted { $0.date < $1.date }
    }

    private var yDomain: ClosedRange<Double> {
        OhanaChartStyle.yDomain(values: sortedLogs.map(\.weightInKg), includeZero: false, paddingRatio: 0.16, minimumSpan: 0.5)
    }

    var body: some View {
        OhanaMinimalTrendChart(
            points: sortedLogs.map {
                OhanaMinimalChartPoint(date: $0.date, value: $0.weightInKg, id: $0.id.uuidString)
            },
            yDomain: yDomain,
            tint: .goPrimary,
            yReferenceLineCount: 3,
            yReferenceFormatter: { OhanaChartStyle.weightReferenceLabel(kilograms: $0, domain: $1) }
        )
    }
}
