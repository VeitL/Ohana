//
//  DailyStreakDetailView.swift
//  Ohana
//
//  打卡连击详情页 — 打卡日历 + 连击排行
//

import SwiftData
import SwiftUI

private struct DailyStreakAvatarIndex {
    let signatures: [UUID: String]
    let payloads: [FocusWalletAvatarCache.Payload]
    let cacheKey: String

    static let empty = DailyStreakAvatarIndex(
        signatures: [:],
        payloads: [],
        cacheKey: "daily-streak-empty"
    )
    static func make(humans: [Human]) -> DailyStreakAvatarIndex {
        var signatures: [UUID: String] = [:]
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for human in humans {
            guard let data = human.avatarImageData else { continue }
            let signature = FocusWalletAvatarCache.signature(for: data)
            signatures[human.id] = signature
            payloads.append(FocusWalletAvatarCache.Payload(id: human.id, data: data))
        }

        let cacheKey = payloads
            .map { payload in
                "\(payload.id.uuidString):\(payload.data?.count ?? 0)"
            }
            .joined(separator: "|")

        return DailyStreakAvatarIndex(
            signatures: signatures,
            payloads: payloads,
            cacheKey: cacheKey.isEmpty ? "daily-streak-empty" : "daily-streak-\(cacheKey)"
        )
    }
}

private struct DailyStreakLeaderboardEntry: Identifiable {
    let human: Human
    let count: Int
    let coconuts: Int

    var id: UUID { human.id }
}

struct DailyStreakDetailView: View {
    let pets: [Pet]
    let humans: [Human]
    let ledgerEvents: [CareLedgerEvent]
    var onClose: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var selectedMonth = Date()
    @State private var checkedInDates: Set<String> = []
    @State private var makeupDates: Set<String> = []
    @State private var makeupPackCount = 0
    @State private var showMakeupConfirm: String? = nil
    @State private var lastClaimedMilestone = 0
    @State private var monthSlideDirection = 1
    @State private var checkInCommandTask: Task<Void, Never>?
    @State private var avatarIndex = DailyStreakAvatarIndex.empty
    @State private var familyLeaderboardSnapshot: [DailyStreakLeaderboardEntry] = []

    private let cal = Calendar.current
    private var commandExecutor: OasisRewardCommandExecutor {
        OasisRewardCommandExecutor(
            context: modelContext,
            rewards: appServices.oasisRewards,
            shopInventory: appServices.shopInventory
        )
    }

    private var l: L10n { L10n(appLanguage) }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId } ?? humans.first
    }

    private var activeHumanIdForStreak: String {
        activeHuman?.id.uuidString ?? currentActiveHumanId
    }

    private var currentTreeLevel: Int {
        appServices.oasisTree.treeLevel.rawValue
    }

    private var coconutShopLockedLevel: Int? {
        guard let requiredLevel = AppFeatureRouteGuard.requiredLevel(for: AppSheetRoute.coconutShop(.boost)) else {
            return nil
        }
        return currentTreeLevel >= requiredLevel ? nil : requiredLevel
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(zh: "打卡连击", en: "Check-in streak", de: "Check-in-Serie"),
            subtitle: activeHuman?.name ?? "Ohana",
            onClose: closePage,
            leading: {
                Image(systemName: "flame.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Circle())
            },
            trailing: {
                EmptyView()
            },
            content: {
                VStack(spacing: 16) {
                    coconutLogShortcut
                    myStreakCard
                    if humans.count > 1 {
                        familyCompetitionSection
                    }
                    checkInCalendarSection
                }
                .padding(.bottom, 18)
            },
            floating: {
                EmptyView()
            }
        )
        .accessibilityIdentifier("daily-streak-screen")
        .onAppear {
            selectedMonth = Date()
            loadCheckInData()
            scheduleTodayCheckIn()
        }
        .task(id: avatarSourceKey) {
            await prepareHumanAvatars()
        }
        .task(id: familyLeaderboardSourceKey) {
            await refreshFamilyLeaderboardSnapshot()
        }
        .onChange(of: currentActiveHumanId) { _, _ in
            selectedMonth = Date()
            loadCheckInData()
            scheduleTodayCheckIn()
        }
        .alert(
            l.tr(zh: "补签确认", en: "Confirm makeup check-in", de: "Nachhol-Check-in bestaetigen"),
            isPresented: Binding(get: { showMakeupConfirm != nil }, set: { if !$0 { showMakeupConfirm = nil } })
        ) {
            Button(l.tr(zh: "消耗1个补签包确认", en: "Use 1 makeup pack", de: "1 Nachholpaket verwenden")) {
                if let date = showMakeupConfirm {
                    applyMakeup(date: date)
                }
                showMakeupConfirm = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { showMakeupConfirm = nil }
        } message: {
            Text(l.tr(zh: "补签 \(showMakeupConfirm ?? "")，将消耗1个补签包", en: "Make up \(showMakeupConfirm ?? "") using 1 makeup pack", de: "\(showMakeupConfirm ?? "") mit 1 Nachholpaket nachholen"))
        }
        .onDisappear {
            checkInCommandTask?.cancel()
            checkInCommandTask = nil
            avatarPipeline.cancel(key: avatarIndex.cacheKey)
        }
    }

    private func closePage() {
        dismiss()
        onClose?()
    }

    private func presentCoconutLog() {
        onPresentCoconutLog?(nil)
    }

    private func presentCoconutShop(_ category: ShopItem.ShopCategory) {
        guard AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(category), currentLevel: currentTreeLevel) else {
            AppFeatureRouteGuard.recordIntercept(
                AppFeatureRouteGuard.lockedRouteNote(for: AppSheetRoute.coconutShop(category), currentLevel: currentTreeLevel)
            )
            OhanaFeedback.error()
            return
        }
        onPresentCoconutShop?(category)
    }

    // MARK: - 我的连击卡片
    private var coconutLogShortcut: some View {
        let balance = activeHuman?.coconutBalance ?? 0
        return Button(action: presentCoconutLog) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath") // a11y: allow leading icon; button label describes action.
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "椰子账本", en: "Coconut ledger", de: "Kokosnuss-Buch"))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "查看连击和奖励记录", en: "View streak and reward history", de: "Serien- und Belohnungsverlauf ansehen"))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer(minLength: 10)

                HStack(spacing: 3) {
                    Text("🥥")
                        .font(OhanaFont.metric(size: 10, .medium))
                    Text("\(balance)")
                        .font(OhanaFont.caption(.black))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.goPrimary, in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "查看椰子账本，当前 \(balance) 个椰子", en: "View coconut ledger, current balance \(balance) coconuts", de: "Kokosnuss-Buch ansehen, aktueller Stand \(balance) Kokosnuesse"))
    }

    private var myStreakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    if let activeHuman {
                        humanAvatar(activeHuman, size: 52)
                    } else {
                        Text("🧑")
                            .font(OhanaFont.adaptive(size: 26)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .frame(width: 52, height: 52)
                            .background(
                                Color(hex: OhanaThemeColorPolicy.humanFallbackHex).opacity(0.18),
                                in: Circle()
                            )
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(activeHuman?.name ?? l.tr(zh: "我", en: "Me", de: "Ich"))
                        .font(OhanaFont.adaptive(size: 17, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "每天打开 App 即打卡", en: "Open the app daily to check in", de: "Oeffne die App taeglich zum Check-in"))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(currentStreak)")
                            .font(OhanaFont.adaptive(size: 44, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(currentStreak > 0 ? Color.goOrange : Color.ohanaPrimaryText.opacity(0.25))
                            .contentTransition(.numericText())
                        Text(l.tr(zh: "天", en: "days", de: "Tage"))
                            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    }
                    Text(streakMoodText)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goOrange)
                }
            }

            // 里程碑进度条
            let milestones = [3, 7, 14, 30, 60, 100]
            if let next = milestones.first(where: { $0 > currentStreak }) {
                let prev = milestones.last(where: { $0 <= currentStreak }) ?? 0
                let progress = Double(currentStreak - prev) / Double(next - prev)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.tr(zh: "距离 \(next) 天里程碑", en: "\(next)-day milestone ahead", de: "\(next)-Tage-Meilenstein voraus"))
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        Spacer()
                        Text(l.tr(zh: "还差 \(next - currentStreak) 天", en: "\(next - currentStreak) days left", de: "Noch \(next - currentStreak) Tage"))
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goOrange.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: OhanaRadius.micro)
                                .fill(Color.ohanaPrimaryText.opacity(0.1))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: OhanaRadius.micro)
                                .fill(LinearGradient(colors: [Color.goOrange, Color.goYellow], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
    }

    private var familyCompetitionSection: some View {
        let leaderboard = familyLeaderboardSnapshot
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "家庭连击", en: "Family streak", de: "Familienserie"))
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "本周照护贡献，谁最稳一眼就知道", en: "This week's care contributions at a glance", de: "Pflegebeitraege dieser Woche auf einen Blick"))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "flame.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goOrange)
            }

            VStack(spacing: 8) {
                ForEach(Array(leaderboard.prefix(4).enumerated()), id: \.element.human.id) { index, entry in
                    HStack(spacing: 10) {
                        Text(index == 0 ? "🏆" : "\(index + 1)")
                            .font(.system(size: index == 0 ? 20 : 13, weight: .black, design: .rounded))
                            .foregroundStyle(index == 0 ? Color.goYellow : Color.ohanaSecondaryText)
                            .frame(width: 28)
                        humanAvatar(entry.human, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.human.name)
                                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(entry.count == 0 ? l.tr(zh: "本周还没有记录", en: "No records this week yet", de: "Diese Woche noch keine Eintraege") : l.tr(zh: "\(entry.count) 次照护 · +\(entry.coconuts)🥥", en: "\(entry.count) care actions · +\(entry.coconuts)🥥", de: "\(entry.count) Pflegeaktionen · +\(entry.coconuts)🥥"))
                                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        Text("\(entry.count)")
                            .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(index == 0 ? Color.goPrimary : Color.ohanaPrimaryText)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(index == 0 ? Color.goPrimary.opacity(0.14) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
    }

    private var checkInCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                    Text(l.tr(zh: "打卡日历", en: "Check-in calendar", de: "Check-in-Kalender"))
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("🔥")
                    Text(l.tr(zh: "\(currentStreak) 天连胜", en: "\(currentStreak)-day streak", de: "\(currentStreak)-Tage-Serie"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.goOrange.opacity(0.12), in: Capsule())
            }

            checkInStatsRow

            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            HStack {
                Button {
                    shiftCheckInMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "上个月", en: "Previous month", de: "Vorheriger Monat"))

                Spacer()

                Text(monthYearString(selectedMonth))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)

                Spacer()

                let canMoveForward = !cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
                if canMoveForward {
                    Button {
                        shiftCheckInMonth(by: 1)
                    } label: {
                        nextMonthIcon(isEnabled: true)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "下个月", en: "Next month", de: "Naechster Monat"))
                } else {
                    nextMonthIcon(isEnabled: false)
                        .accessibilityLabel(l.tr(zh: "已经是当前月份", en: "Already the current month", de: "Bereits der aktuelle Monat"))
                }
            }

            HStack(spacing: 0) {
                ForEach(localizedWeekdaySymbols, id: \.self) { d in
                    Text(d)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = monthCalendarCells(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    calendarDayCell(cell)
                }
            }
            .id(checkInMonthKey)
            .transition(.asymmetric(
                insertion: .move(edge: monthSlideDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: monthSlideDirection > 0 ? .leading : .trailing).combined(with: .opacity)
            ))

            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("📦").font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "补签包", en: "Makeup packs", de: "Nachholpakete"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    Text("×\(makeupPackCount)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(makeupPackCount > 0 ? Color.goPrimary : Color.ohanaPrimaryText.opacity(0.3))
                }
                Spacer()
                if makeupPackCount > 0 {
                    Text(l.tr(zh: "点击灰色日期补签", en: "Tap a gray date to make it up", de: "Tippe ein graues Datum zum Nachholen"))
                        .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary.opacity(0.7))
                } else if let coconutShopLockedLevel {
                    lockedShopLabel(level: coconutShopLockedLevel)
                } else {
                    Button { presentCoconutShop(.boost) } label: {
                        Text(l.tr(zh: "去商店购买 →", en: "Buy in shop →", de: "Im Shop kaufen →"))
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goYellow.opacity(0.85))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if currentStreak > 0 {
                checkInMilestoneRow
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
    }

    private var checkInStatsRow: some View {
        HStack(spacing: 10) {
            checkInStatCell(value: "\(checkedInDates.count)", label: l.tr(zh: "总打卡", en: "Total", de: "Gesamt"), icon: "checkmark.circle.fill", color: Color.goPrimary)
            checkInStatCell(value: "\(currentStreak)", label: l.tr(zh: "当前连胜", en: "Current", de: "Aktuell"), icon: "flame.fill", color: Color.goOrange)
            checkInStatCell(value: "\(longestStreak)", label: l.tr(zh: "最长连胜", en: "Longest", de: "Laengste"), icon: "trophy.fill", color: Color.goYellow)
            checkInStatCell(value: "\(monthCheckInRate)%", label: l.tr(zh: "本月", en: "This month", de: "Dieser Monat"), icon: "chart.bar.fill", color: Color.goCardCyan)
        }
    }

    private func checkInStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(color)
            Text(value)
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    private func nextMonthIcon(isEnabled: Bool) -> some View {
        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
            .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(isEnabled ? Color.ohanaPrimaryText.opacity(0.5) : Color.ohanaPrimaryText.opacity(0.15))
            .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .background(
                isEnabled ? Color.ohanaControlFill : Color.ohanaControlFill.opacity(0.72),
                in: Circle()
            )
    }

    private func lockedShopLabel(level: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill") // a11y: allow decorative lock icon; capsule label describes the locked shop.
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .accessibilityHidden(true)
            Text(l.tr(zh: "商店 Lv.\(level) 解锁", en: "Shop unlocks at Lv.\(level)", de: "Shop wird auf Lv.\(level) freigeschaltet"))
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
        .accessibilityLabel(l.tr(zh: "椰子商店生命之树 Lv.\(level) 解锁", en: "Coconut shop unlocks at Life Tree Lv.\(level)", de: "Kokosnuss-Shop wird mit Lebensbaum Lv.\(level) freigeschaltet"))
    }

    private var checkInMilestoneRow: some View {
        let milestones: [(days: Int, reward: Int, emoji: String)] = [
            (7, 10, "⭐️"), (14, 25, "🌟"), (30, 60, "💎"), (60, 150, "👑"), (100, 300, "🏆")
        ]
        let nextMilestone = milestones.first(where: { $0.days > currentStreak })
        let lastClaimed = lastClaimedMilestone

        return VStack(spacing: 8) {
            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            if let nextMilestone {
                HStack(spacing: 6) {
                    Text(nextMilestone.emoji)
                    Text(l.tr(
                        zh: "再连续 \(nextMilestone.days - currentStreak) 天即可领取 +\(nextMilestone.reward)🥥",
                        en: "\(nextMilestone.days - currentStreak) more streak days to claim +\(nextMilestone.reward)🥥",
                        de: "Noch \(nextMilestone.days - currentStreak) Serientage fuer +\(nextMilestone.reward)🥥"
                    ))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary.opacity(0.75))
                    Spacer()
                }
            }

            let claimable = milestones.filter { $0.days <= currentStreak && $0.days > lastClaimed }
            ForEach(claimable, id: \.days) { milestone in
                Button {
                    claimMilestone(milestone.days, reward: milestone.reward, emoji: milestone.emoji)
                } label: {
                    HStack(spacing: 8) {
                        Text(milestone.emoji)
                            .font(OhanaFont.adaptive(size: 16)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(zh: "\(milestone.days) 天连胜达成！", en: "\(milestone.days)-day streak reached!", de: "\(milestone.days)-Tage-Serie erreicht!"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                        Spacer()
                        Text(l.tr(zh: "+\(milestone.reward)🥥 领取", en: "Claim +\(milestone.reward)🥥", de: "+\(milestone.reward)🥥 abholen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private struct CalendarCell {
        let dateStr: String
        let day: Int
        let isToday: Bool
        let isChecked: Bool
        let isMakeup: Bool
        let isFuture: Bool
    }

    private func monthCalendarCells(for month: Date) -> [CalendarCell] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let comps = cal.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = cal.date(from: comps) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [CalendarCell] = []
        for _ in 0 ..< weekdayOfFirst {
            cells.append(CalendarCell(dateStr: "", day: 0, isToday: false, isChecked: false, isMakeup: false, isFuture: false))
        }

        let todayString = fmt.string(from: Date())
        for day in 1 ... daysInMonth {
            var dc = DateComponents()
            dc.year = comps.year
            dc.month = comps.month
            dc.day = day
            let date = cal.date(from: dc) ?? firstOfMonth
            let dateStr = fmt.string(from: date)
            let isToday = dateStr == todayString
            let isChecked = checkedInDates.contains(dateStr)
            let isMakeup = makeupDates.contains(dateStr)
            let isFuture = date > Date() && !isToday
            cells.append(CalendarCell(dateStr: dateStr, day: day, isToday: isToday, isChecked: isChecked, isMakeup: isMakeup, isFuture: isFuture))
        }
        return cells
    }

    private var checkInMonthKey: String {
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > 44, abs(width) > abs(height) * 1.25 else { return }
                shiftCheckInMonth(by: width < 0 ? 1 : -1)
            }
    }

    private func shiftCheckInMonth(by delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: selectedMonth) else { return }
        if next > Date(), !cal.isDate(next, equalTo: Date(), toGranularity: .month) {
            return
        }
        monthSlideDirection = delta >= 0 ? 1 : -1
        withAnimation(GoMotion.selection) {
            selectedMonth = next
        }
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarCell) -> some View {
        if cell.dateStr.isEmpty {
            Color.clear.frame(minHeight: 40)
        } else {
            if isMakeupEligible(cell) {
                Button {
                    showMakeupConfirm = cell.dateStr
                } label: {
                    calendarDayCellContent(cell)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "补签 \(cell.dateStr)", en: "Make up \(cell.dateStr)", de: "\(cell.dateStr) nachholen"))
            } else {
                calendarDayCellContent(cell)
            }
        }
    }

    private func isMakeupEligible(_ cell: CalendarCell) -> Bool {
        !cell.isChecked && !cell.isToday && !cell.isFuture && makeupPackCount > 0
    }

    private func calendarDayCellContent(_ cell: CalendarCell) -> some View {
        ZStack {
            Circle()
                .fill(cellFillColor(cell))
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .overlay(
                    Circle().strokeBorder(
                        cell.isToday ? Color.goPrimary : .clear,
                        lineWidth: 1.5
                    )
                )
            if cell.isChecked {
                if cell.isMakeup {
                    Image(systemName: "arrow.uturn.backward") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                } else {
                    Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                }
            } else {
                Text("\(cell.day)")
                    .font(OhanaFont.adaptive(size: 13, weight: cell.isToday ? .black : .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(
                        cell.isFuture ? Color.ohanaPrimaryText.opacity(0.2) :
                            cell.isToday ? Color.goPrimary :
                            Color.ohanaPrimaryText.opacity(0.7)
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .contentShape(Rectangle())
    }

    private func cellFillColor(_ cell: CalendarCell) -> Color {
        if cell.isChecked, cell.isMakeup {
            Color.goYellow.opacity(0.85)
        } else if cell.isChecked {
            Color.goPrimary
        } else if cell.isToday {
            Color.goPrimary.opacity(0.22)
        } else {
            Color.ohanaControlFill
        }
    }

    @ViewBuilder
    private func humanAvatar(_ human: Human, size: CGFloat) -> some View {
        let signature = avatarIndex.signatures[human.id] ?? ""
        if !signature.isEmpty,
           let image = avatarPipeline.cachedImage(for: human.id, signature: signature) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(human.avatarEmoji.isEmpty ? "🧑" : human.avatarEmoji)
                .font(.system(size: size * 0.52))
                .frame(width: size, height: size)
                .background(Color(hex: human.safeThemeColorHex).opacity(0.18), in: Circle())
        }
    }

    private var avatarSourceKey: String {
        humans.map { human in
            "\(human.id.uuidString):\(human.avatarImageData?.count ?? 0)"
        }
        .joined(separator: "|")
    }

    private func prepareHumanAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        let previousKey = avatarIndex.cacheKey
        let nextIndex = DailyStreakAvatarIndex.make(humans: humans)
        if previousKey != nextIndex.cacheKey {
            avatarPipeline.cancel(key: previousKey)
        }
        avatarIndex = nextIndex
        guard !nextIndex.payloads.isEmpty else { return }
        avatarPipeline.seedPreviewEntries(nextIndex.payloads)
        avatarPipeline.preload(
            payloads: nextIndex.payloads,
            key: nextIndex.cacheKey,
            delayMilliseconds: 48
        )
    }

    private var familyLeaderboardSourceKey: String {
        let latestLedgerTimestamp = ledgerEvents.first?.occurredAt.timeIntervalSince1970 ?? 0
        return [
            "humans:\(humans.count)",
            "pets:\(pets.count)",
            "ledger:\(ledgerEvents.count)",
            "latest:\(Int(latestLedgerTimestamp))"
        ].joined(separator: "|")
    }

    private func refreshFamilyLeaderboardSnapshot() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }
        familyLeaderboardSnapshot = makeFamilyLeaderboardSnapshot()
    }

    private func makeFamilyLeaderboardSnapshot() -> [DailyStreakLeaderboardEntry] {
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? cal.date(byAdding: .day, value: -7, to: Date())
            ?? Date()
        let interval = DateInterval(start: start, end: Date())
        let livingPets = pets.filter { !$0.hasPassedAway }
        let entries = appServices.careLedgerStats.reportEntries(
            events: ledgerEvents,
            pets: livingPets,
            humans: humans,
            interval: interval
        )
        return humans
            .map { human in
                let id = human.id.uuidString
                let mine = entries.filter { $0.actorId == id }
                return DailyStreakLeaderboardEntry(
                    human: human,
                    count: mine.count,
                    coconuts: mine.reduce(0) { $0 + $1.coconuts }
                )
            }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.coconuts != $1.coconuts { return $0.coconuts > $1.coconuts }
                return $0.human.createdAt < $1.human.createdAt
            }
    }

    private var shortDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.effectiveLocale
        f.dateFormat = AppLanguage.compactMonthDayFormat
        return f
    }

    private var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.effectiveLocale
        f.dateFormat = AppLanguage.fullMonthYearFormat
        return f
    }

    private func monthYearString(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    private var localizedWeekdaySymbols: [String] {
        switch l.languageCode {
        case "en":
            ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        case "de":
            ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        default:
            ["日", "一", "二", "三", "四", "五", "六"]
        }
    }

    private var streakMoodText: String {
        if currentStreak >= 30 {
            return l.tr(zh: "🔥 传奇！", en: "🔥 Legendary!", de: "🔥 Legendaer!")
        }
        if currentStreak >= 7 {
            return l.tr(zh: "🔥 火热！", en: "🔥 On fire!", de: "🔥 Laeuft heiss!")
        }
        return l.tr(zh: "继续保持", en: "Keep it going", de: "Dranbleiben")
    }

    private var currentStreak: Int {
        CheckInStreakStore.currentStreak(for: activeHumanIdForStreak, calendar: cal)
    }

    private var longestStreak: Int {
        CheckInStreakStore.longestStreak(for: activeHumanIdForStreak, calendar: cal)
    }

    private var monthCheckInRate: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: comps) else { return 0 }
        let dayOfMonth = cal.component(.day, from: today)
        var count = 0
        for day in 0 ..< dayOfMonth {
            if let date = cal.date(byAdding: .day, value: day, to: firstOfMonth) {
                let value = fmt.string(from: date)
                if checkedInDates.contains(value) {
                    count += 1
                }
            }
        }
        return dayOfMonth > 0 ? Int(Double(count) / Double(dayOfMonth) * 100) : 0
    }

    private func loadCheckInData() {
        applyCheckInSnapshot(commandExecutor.loadCheckInData(currentActiveHumanId: activeHumanIdForStreak))
    }

    private func triggerTodayCheckIn() {
        guard let updatedDates = commandExecutor.triggerTodayCheckIn(
            currentActiveHumanId: activeHumanIdForStreak,
            checkedInDates: checkedInDates,
            postsRewardFeedback: false
        ) else { return }
        checkedInDates = updatedDates
    }

    private func scheduleTodayCheckIn() {
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            triggerTodayCheckIn()
            checkInCommandTask = nil
        }
    }

    private func applyMakeup(date: String) {
        let snapshot = OasisCheckInSnapshot(
            checkedInDates: checkedInDates,
            makeupDates: makeupDates,
            makeupPackCount: makeupPackCount,
            lastClaimedMilestone: lastClaimedMilestone
        )
        OhanaFeedback.medium()
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            guard let updated = commandExecutor.applyMakeup(
                date: date,
                currentActiveHumanId: activeHumanIdForStreak,
                snapshot: snapshot
            ) else {
                checkInCommandTask = nil
                return
            }
            applyCheckInSnapshot(updated)
            checkInCommandTask = nil
        }
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        lastClaimedMilestone = days
        OhanaFeedback.success()
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            commandExecutor.claimMilestone(
                days: days,
                reward: reward,
                emoji: emoji,
                currentActiveHumanId: activeHumanIdForStreak
            )
            checkInCommandTask = nil
        }
    }

    private func applyCheckInSnapshot(_ snapshot: OasisCheckInSnapshot) {
        checkedInDates = snapshot.checkedInDates
        makeupDates = snapshot.makeupDates
        makeupPackCount = snapshot.makeupPackCount
        lastClaimedMilestone = snapshot.lastClaimedMilestone
    }
}
