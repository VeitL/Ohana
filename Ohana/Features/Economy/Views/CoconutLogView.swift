//
//  CoconutLogView.swift
//  Ohana
//
//  B7: 椰子获取记录页（从 OasisRewardView 椰子按钮进入）
//

import SwiftData
import SwiftUI

enum CoconutLogSubject: Identifiable, Hashable {
    case pet(UUID)
    case human(UUID)

    var id: String {
        switch self {
        case let .pet(id): "pet-\(id.uuidString)"
        case let .human(id): "human-\(id.uuidString)"
        }
    }

    var actorId: String {
        switch self {
        case let .pet(id), let .human(id):
            id.uuidString
        }
    }
}

private enum CoconutLogActorKind: Hashable {
    case pet
    case human
}

private struct CoconutLogActorSnapshot: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let balance: Int
    let kind: CoconutLogActorKind
}

private struct CoconutLogMemberSnapshot {
    let isReady: Bool
    let pets: [CoconutLogActorSnapshot]
    let visibleHumans: [CoconutLogActorSnapshot]
    let hiddenHumanIds: Set<String>
    let frozenActorIds: Set<String>
    let activePetBalanceTotal: Int
    let activeHumanBalanceTotal: Int

    static let empty = CoconutLogMemberSnapshot(
        isReady: false,
        pets: [],
        visibleHumans: [],
        hiddenHumanIds: [],
        frozenActorIds: [],
        activePetBalanceTotal: 0,
        activeHumanBalanceTotal: 0
    )

    @MainActor
    static func fetch(
        context: ModelContext,
        viewedBy activeHumanId: UUID?,
        privacy: HumanPrivacyManaging
    ) -> CoconutLogMemberSnapshot {
        var humanDescriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt)]
        )
        humanDescriptor.fetchLimit = 80
        let humans: [Human]
        do {
            humans = try context.fetch(humanDescriptor)
        } catch {
            OhanaLog.warning(
                "[CoconutLogMemberSnapshot] failed to fetch humans: \(error.localizedDescription)",
                category: "Economy"
            )
            humans = []
        }

        var petDescriptor = FetchDescriptor<Pet>(
            sortBy: [SortDescriptor(\Pet.createdAt)]
        )
        petDescriptor.fetchLimit = 120
        let pets: [Pet]
        do {
            pets = try context.fetch(petDescriptor)
        } catch {
            OhanaLog.warning(
                "[CoconutLogMemberSnapshot] failed to fetch pets: \(error.localizedDescription)",
                category: "Economy"
            )
            pets = []
        }

        let visibleHumans = privacy
            .unlockedHumans(for: .wishlist, from: humans, viewedBy: activeHumanId)
            .map { human in
                CoconutLogActorSnapshot(
                    id: human.id.uuidString,
                    name: human.name,
                    emoji: human.avatarEmoji.isEmpty ? "😊" : human.avatarEmoji,
                    balance: human.coconutBalance,
                    kind: .human
                )
            }
        let hiddenHumanIds = Set(humans.compactMap { human in
            privacy.isLocked(.wishlist, for: human, viewedBy: activeHumanId)
                ? human.id.uuidString
                : nil
        })
        let frozenActorIds = Set(
            pets.filter { !EconomyWalletWritePolicy.canWrite($0) }.map(\.id.uuidString) +
                humans.filter { !EconomyWalletWritePolicy.canWrite($0) }.map(\.id.uuidString)
        )
        let petSnapshots = pets.map { pet in
            CoconutLogActorSnapshot(
                id: pet.id.uuidString,
                name: pet.name,
                emoji: "🐾",
                balance: pet.coconutBalance,
                kind: .pet
            )
        }

        return CoconutLogMemberSnapshot(
            isReady: true,
            pets: petSnapshots,
            visibleHumans: visibleHumans,
            hiddenHumanIds: hiddenHumanIds,
            frozenActorIds: frozenActorIds,
            activePetBalanceTotal: pets
                .filter(EconomyWalletWritePolicy.canWrite)
                .reduce(0) { $0 + $1.coconutBalance },
            activeHumanBalanceTotal: humans
                .filter(EconomyWalletWritePolicy.canWrite)
                .reduce(0) { $0 + $1.coconutBalance }
        )
    }

    func actor(id: String) -> CoconutLogActorSnapshot? {
        pets.first { $0.id == id } ?? visibleHumans.first { $0.id == id }
    }

    func balance(for actorId: String) -> Int {
        guard !hiddenHumanIds.contains(actorId) else { return 0 }
        return actor(id: actorId)?.balance ?? 0
    }

    func subjectName(for subject: CoconutLogSubject) -> String? {
        actor(id: subject.actorId)?.name
    }

    func knownActors(from logs: [CoconutLogEntry]) -> [(id: String, name: String, emoji: String)] {
        var seen = Set<String>()
        var result: [(String, String, String)] = []

        for human in visibleHumans {
            seen.insert(human.id)
            result.append((human.id, human.name, human.emoji))
        }
        for pet in pets {
            seen.insert(pet.id)
            result.append((pet.id, pet.name, pet.emoji))
        }
        for log in logs {
            guard let id = log.actorId,
                  let name = log.actorName,
                  !seen.contains(id) else { continue }
            seen.insert(id)
            result.append((id, name, actor(id: id)?.emoji ?? "🐾"))
        }
        return result
    }
}

struct CoconutLogContentView: View {
    let walletAccounts: [CoconutAccount]
    let walletLedgerEntries: [CoconutLedgerEntry]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    // N10: member filter
    @State private var selectedActorId: String? = nil
    @State private var showingWealthDashboard = false
    @State private var isHistoryContentReady = false
    @State private var memberSnapshot = CoconutLogMemberSnapshot.empty
    @State private var historyContentMountTask: Task<Void, Never>?
    @State private var memberSnapshotTask: Task<Void, Never>?
    private let subject: CoconutLogSubject?
    private let onClose: (() -> Void)?
    private let safeTopInset: CGFloat
    private let safeBottomInset: CGFloat
    private let historyContentDelayMilliseconds: UInt64

    init(
        walletAccounts: [CoconutAccount],
        walletLedgerEntries: [CoconutLedgerEntry],
        subject: CoconutLogSubject? = nil,
        onClose: (() -> Void)? = nil,
        safeTopInset: CGFloat = 0,
        safeBottomInset: CGFloat = 0,
        historyContentDelayMilliseconds: UInt64 = 70
    ) {
        self.walletAccounts = walletAccounts
        self.walletLedgerEntries = walletLedgerEntries
        self.subject = subject
        self.onClose = onClose
        self.safeTopInset = safeTopInset
        self.safeBottomInset = safeBottomInset
        self.historyContentDelayMilliseconds = historyContentDelayMilliseconds
        _selectedActorId = State(initialValue: subject?.actorId)
    }

    private var l: L10n { L10n(appLanguage) }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var activeHumanActorId: String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    private var isContentReady: Bool {
        isHistoryContentReady && memberSnapshot.isReady
    }

    private var visibleLogs: [CoconutLogEntry] {
        walletLedgerEntries
            .filter { $0.delta != 0 }
            .map { $0.asCoconutLogEntry() }
            .filter { !memberSnapshot.hiddenHumanIds.contains($0.actorId ?? "") }
    }

    private var visibleCoconutTotal: Int {
        if let subject {
            return balance(for: subject.actorId)
        }
        if let selectedActorId {
            return balance(for: selectedActorId)
        }
        if !walletAccounts.isEmpty {
            return walletAccounts.reduce(0) { total, account in
                guard account.ownerKind != .system,
                      !memberSnapshot.frozenActorIds.contains(account.ownerId) else {
                    return total
                }
                return total + account.balance
            }
        }
        return memberSnapshot.activePetBalanceTotal + memberSnapshot.activeHumanBalanceTotal
    }

    private func balance(for actorId: String) -> Int {
        if let account = walletAccounts.first(where: { $0.ownerId == actorId }),
           !(account.ownerKind == .human && memberSnapshot.hiddenHumanIds.contains(account.ownerId)) {
            return account.balance
        }
        return memberSnapshot.balance(for: actorId)
    }

    private var filteredLogs: [CoconutLogEntry] {
        guard let id = subject?.actorId ?? selectedActorId else { return visibleLogs }
        return visibleLogs.filter { $0.actorId == id }
    }

    private var subjectName: String? {
        guard let subject else { return nil }
        return memberSnapshot.subjectName(for: subject)
    }

    private var knownActors: [(id: String, name: String, emoji: String)] {
        memberSnapshot.knownActors(from: visibleLogs)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, safeTopInset + 16)
                    .padding(.bottom, 16)

                if isContentReady {
                    historyContent
                        .transition(.opacity)
                } else {
                    historyOpeningPlaceholder
                        .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingWealthDashboard) {
            IslandWealthDashboardView()
        }
        .onAppear {
            scheduleMemberSnapshotRefresh()
            scheduleHistoryContentMount()
            seedDefaultActorFilterIfNeeded()
        }
        .onDisappear {
            historyContentMountTask?.cancel()
            memberSnapshotTask?.cancel()
        }
        .onChange(of: activeHumanIdStr) { oldValue, newValue in
            guard subject == nil else { return }
            scheduleMemberSnapshotRefresh()
            let next = newValue.isEmpty ? nil : newValue
            if selectedActorId == nil || selectedActorId == oldValue || selectedActorId?.isEmpty == true {
                withAnimation(GoMotion.selection) {
                    selectedActorId = next
                }
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        balanceHeader

        GoDashedDivider().padding(.horizontal, 20)

        if subject == nil, !knownActors.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(id: nil, emoji: "🌴", name: l.tr(zh: "全部", en: "All", de: "Alle"))
                    ForEach(knownActors, id: \.id) { actor in
                        filterChip(id: actor.id, emoji: actor.emoji, name: actor.name)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
        }

        if filteredLogs.isEmpty {
            emptyState
        } else {
            logList
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: 10) {
            Text("🥥").font(OhanaFont.adaptive(size: 44)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            VStack(alignment: .leading, spacing: 2) {
                Text("\(visibleCoconutTotal)")
                    .font(OhanaFont.adaptive(size: 52, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .contentTransition(.numericText())
                    .animation(GoMotion.feedback, value: visibleCoconutTotal)
                Text(l.tr(zh: "当前椰子余额", en: "Current coconut balance", de: "Aktueller Kokosnussstand"))
                    .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var historyOpeningPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.goPrimary)
                .scaleEffect(0.88)
            Text(l.tr(zh: "正在整理椰子历史", en: "Preparing coconut history", de: "Kokosnuss-Historie wird vorbereitet"))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🥥").font(OhanaFont.adaptive(size: 48)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text((subject == nil && selectedActorId == nil)
                ? l.tr(zh: "还没有椰子记录", en: "No coconut history yet", de: "Noch keine Kokosnuss-Historie")
                : l.tr(zh: "该成员暂无椰子记录", en: "No history for this member", de: "Keine Historie für dieses Mitglied"))
                .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            Text(l.tr(zh: "完成打卡后，椰子收支会出现在这里", en: "Coconut changes appear here after check-ins", de: "Kokosnuss-Bewegungen erscheinen hier nach Check-ins"))
                .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var logList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { idx, log in
                    logRow(log: log)
                    if idx < filteredLogs.count - 1 {
                        Divider()
                            .background(Color.ohanaCardStroke)
                            .padding(.leading, 78)
                    }
                }
            }
            .padding(.bottom, 40 + safeBottomInset)
        }
    }

    private func scheduleHistoryContentMount() {
        guard !isHistoryContentReady else { return }
        historyContentMountTask?.cancel()
        historyContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: historyContentDelayMilliseconds) {
            withAnimation(GoMotion.quick) {
                isHistoryContentReady = true
            }
            historyContentMountTask = nil
        }
    }

    private func scheduleMemberSnapshotRefresh() {
        memberSnapshotTask?.cancel()
        memberSnapshotTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 36) {
            memberSnapshot = CoconutLogMemberSnapshot.fetch(
                context: modelContext,
                viewedBy: activeHumanId,
                privacy: appServices.privacy
            )
            seedDefaultActorFilterIfNeeded()
            memberSnapshotTask = nil
        }
    }

    private func seedDefaultActorFilterIfNeeded() {
        guard subject == nil, selectedActorId == nil, let activeHumanActorId else { return }
        selectedActorId = activeHumanActorId
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                    Text(l.tr(zh: "椰子历史", en: "Coconut History", de: "Kokosnuss-Historie"))
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Text((isContentReady ? subjectName : nil) ?? l.tr(zh: "每一笔收支", en: "Every coconut change", de: "Jede Bewegung"))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                showingWealthDashboard = true
            } label: {
                Image(systemName: "chart.pie.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "打开财富分析", en: "Open wealth analysis", de: "Vermögensanalyse öffnen"))

            Button { closeLog() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private func closeLog() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private func filterChip(id: String?, emoji: String, name: String) -> some View {
        let isSelected = selectedActorId == id
        Button {
            withAnimation(GoMotion.selection) { selectedActorId = id }
        } label: {
            HStack(spacing: 5) {
                Text(emoji).font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.selection, value: selectedActorId)
    }

    @ViewBuilder
    private func logRow(log: CoconutLogEntry) -> some View {
        let isEarning = log.amount > 0
        let actor = log.actorId.flatMap { memberSnapshot.actor(id: $0) }
        let isPet = actor?.kind == .pet
        let isHuman = actor?.kind == .human
        let isSystem = log.actorId == nil || (!isPet && !isHuman)

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isEarning ? Color.goPrimary : Color.goRed).opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(log.emoji).font(OhanaFont.adaptive(size: 22)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(log.localizedTitle(l: l))
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                HStack(spacing: 6) {
                    if isSystem {
                        // 全局系统奖励
                        Text(l.tr(zh: "🏕️ 岛屿奖励", en: "🏕️ Island reward", de: "🏕️ Insel-Belohnung"))
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.ohanaControlFill, in: Capsule())
                    } else if isPet {
                        // 宜物标签：展示宜物名
                        HStack(spacing: 3) {
                            Text("🐾")
                                .font(OhanaFont.adaptive(size: 9)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text(log.actorName ?? "")
                                .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        }
                        .foregroundStyle(Color.goTeal)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.goTeal.opacity(0.12), in: Capsule())
                    } else if isHuman {
                        // 人类标签
                        Text(log.actorName ?? "")
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary.opacity(0.9))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.goPrimary.opacity(0.1), in: Capsule())
                    }
                    Text(log.timeAgoString(l: l))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                }
            }
            Spacer()
            HStack(spacing: 3) {
                Text(isEarning ? "+\(log.amount)" : "\(log.amount)")
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(isEarning ? Color.goPrimary : Color.goRed)
                Text("🥥").font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

#Preview {
    CoconutLogView()
}
