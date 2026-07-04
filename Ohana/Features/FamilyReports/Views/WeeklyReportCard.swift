//
//  WeeklyReportCard.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

struct WeeklyReportCard: View {
    let pet: Pet
    let ledgerEvents: [CareLedgerEvent]
    @State private var isRendering = false
    @State private var isSharing = false
    @State private var shareImage: UIImage? = nil
    @State private var pulseShare = false
    @State private var isVisible = false
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    init(pet: Pet, ledgerEvents: [CareLedgerEvent] = []) {
        self.pet = pet
        self.ledgerEvents = ledgerEvents
    }

    private var shouldPulseShare: Bool {
        workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible)
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private var weekEnd: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
    }

    private var weekLedgerEvents: [CareLedgerEvent] {
        ledgerEvents.filter { event in
            isPetEvent(event) &&
                event.occurredAt >= weekStart &&
                event.occurredAt < weekEnd &&
                isWeeklyReportActivity(event)
        }
    }

    private var weekWalkEvents: [CareLedgerEvent] {
        weekLedgerEvents.filter { $0.eventKindEnum == .walk }
    }

    private var weekPottyEvents: [CareLedgerEvent] {
        weekLedgerEvents.filter { $0.eventKindEnum == .potty }
    }

    private var weekExpenses: Double {
        weekLedgerEvents
            .filter { $0.eventKindEnum == .expense }
            .reduce(0) { $0 + max(0, $1.amountValue) }
    }

    private var totalWalkDistance: Double {
        weekWalkEvents.reduce(0) { $0 + max(0, $1.amountValue) }
    }

    private var totalWalkDuration: TimeInterval {
        weekWalkEvents.reduce(0) { partial, event in
            partial + max(0, CareLedgerMetadata.doubleValue(named: "durationSeconds", in: event.metadataJSON) ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goPrimary)
                Text("本周小报")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(weekStart, format: .dateTime.month().day()) - \(weekEnd, format: .dateTime.month().day())")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                Button {
                    Task { await renderAndShare() }
                } label: {
                    if isRendering {
                        ProgressView().tint(Color.goPrimary).scaleEffect(0.75)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                            Text("分享")
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.goPrimary, in: Capsule())
                        .scaleEffect(shouldPulseShare && pulseShare ? 1.06 : 1.0)
                        .animation(shouldPulseShare ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : GoMotion.reduced, value: pulseShare) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                        .onAppear {
                            isVisible = true
                            pulseShare = shouldPulseShare
                        }
                        .onDisappear {
                            isVisible = false
                            pulseShare = false
                        }
                        .onChange(of: shouldPulseShare) { _, canRun in
                            pulseShare = canRun
                        }
                    }
                }
                .disabled(isRendering)
            }

            // 统计网格
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                statBubble(emoji: "🚶", value: "\(weekWalkEvents.count)", label: "巡岛")
                statBubble(emoji: "📏", value: distanceFormatted, label: "距离")
                statBubble(emoji: "⏱️", value: durationFormatted, label: "时长")
                statBubble(emoji: "💩", value: "\(weekPottyEvents.count)", label: "便便")
                statBubble(emoji: "💰", value: AppCurrency.format(weekExpenses, fractionDigits: 0), label: "花费")
                statBubble(emoji: "⚖️", value: latestWeight, label: "体重")
            }

            // 7天活跃热力图
            VStack(alignment: .leading, spacing: 6) {
                Text("活跃天数")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium))
                    .foregroundStyle(Color.ohanaSecondaryText)

                HStack(spacing: 4) {
                    ForEach(0 ..< 7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart) ?? Date()
                        let hasActivity = hasActivityOn(date)

                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: OhanaRadius.micro)
                                .fill(hasActivity ? Color.purple.opacity(0.6) : Color.gray.opacity(0.15))
                                .frame(height: 24)

                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(OhanaFont.adaptive(size: 9, weight: .medium))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
        .sheet(isPresented: $isSharing) {
            if let img = shareImage {
                ShareSheet(image: img)
            }
        }
    }

    private func statBubble(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(OhanaFont.adaptive(size: 16))
            Text(value)
                .font(OhanaFont.adaptive(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .medium))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface.opacity(0.3), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
    }

    private var distanceFormatted: String {
        if totalWalkDistance >= 1000 {
            return String(format: "%.1fkm", totalWalkDistance / 1000)
        }
        return String(format: "%.0fm", totalWalkDistance)
    }

    private var durationFormatted: String {
        guard totalWalkDuration > 0 else { return "--" }
        let minutes = Int(totalWalkDuration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h\(minutes % 60)m"
        }
        return "\(minutes)min"
    }

    private var latestWeight: String {
        let weightEvents = ledgerEvents
            .filter { isPetEvent($0) && $0.eventKindEnum == .weight && $0.amountValue > 0 }
            .sorted { $0.occurredAt > $1.occurredAt }
        if let event = weightEvents.first {
            return String(format: "%.1fkg", event.amountValue)
        }
        return "--"
    }

    private func hasActivityOn(_ date: Date) -> Bool {
        let cal = Calendar.current
        return weekLedgerEvents.contains { cal.isDate($0.occurredAt, inSameDayAs: date) }
    }

    private func isPetEvent(_ event: CareLedgerEvent) -> Bool {
        event.subjectKind == CareLedgerSubjectKind.pet.rawValue &&
            event.subjectId == pet.id.uuidString
    }

    private func isWeeklyReportActivity(_ event: CareLedgerEvent) -> Bool {
        switch event.eventKindEnum {
        case .care, .potty, .walk, .hygiene, .health, .weight, .medication, .expense:
            true
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            false
        }
    }

    // MARK: - Share Poster
    @MainActor
    private func renderAndShare() async {
        isRendering = true
        defer { isRendering = false }
        let poster = weeklyPoster
        let renderer = ImageRenderer(content:
            poster
                .frame(width: 360)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        if let img = renderer.uiImage {
            shareImage = img
            isSharing = true
        }
    }

    // MARK: - Poster Layout（独立视图，供 ImageRenderer 渲染）
    private var weeklyPoster: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部品牌条
            HStack {
                Text("🏝️ Ohana 周报")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Spacer()
                Text("\(weekStart, format: .dateTime.month().day()) — \(weekEnd, format: .dateTime.month().day())")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 宠物 Hero
            HStack(spacing: 14) {
                PetAvatarPortraitView(
                    pet: pet,
                    fallbackText: pet.avatarEmoji,
                    themeColor: Color(hex: pet.safeThemeColorHex),
                    size: 64,
                    backgroundOpacity: 0.25,
                    transparentScale: 0.78
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("本周战绩")
                        .font(OhanaFont.adaptive(size: 12, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                Spacer()
                // 活跃天数大字
                let activeDays = (0 ..< 7).count(where: { i in
                    let d = Calendar.current.date(byAdding: .day, value: i, to: weekStart) ?? Date()
                    return hasActivityOn(d)
                })
                VStack(spacing: 2) {
                    Text("\(activeDays)")
                        .font(OhanaFont.adaptive(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                    Text("活跃天")
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // 数据网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                posterStat(emoji: "🚶", value: "\(weekWalkEvents.count)次", label: "巡岛")
                posterStat(emoji: "📏", value: distanceFormatted, label: "距离")
                posterStat(emoji: "⏱️", value: durationFormatted, label: "时长")
                posterStat(emoji: "💩", value: "\(weekPottyEvents.count)次", label: "便便")
                posterStat(emoji: "💰", value: AppCurrency.format(weekExpenses, fractionDigits: 0), label: "花费")
                posterStat(emoji: "⚖️", value: latestWeight, label: "体重")
            }
            .padding(.horizontal, 16)

            // 热力图
            HStack(spacing: 4) {
                ForEach(0 ..< 7, id: \.self) { i in
                    let d = Calendar.current.date(byAdding: .day, value: i, to: weekStart) ?? Date()
                    let active = hasActivityOn(d)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: OhanaRadius.micro)
                            .fill(active ? Color.goPrimary.opacity(0.7) : Color.primary.opacity(0.08))
                            .frame(height: 20)
                        Text(d, format: .dateTime.weekday(.narrow))
                            .font(OhanaFont.adaptive(size: 8, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // 底部水印
            HStack {
                Spacer()
                Text("Made with Ohana 🏝️")
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.18))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "2A1F6B"), Color(hex: "1A0E4B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1.5)
        )
    }

    private func posterStat(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(OhanaFont.adaptive(size: 18))
            Text(value)
                .font(OhanaFont.adaptive(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .medium))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
    }
}
