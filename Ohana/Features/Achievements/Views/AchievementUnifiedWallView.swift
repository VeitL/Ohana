//
//  AchievementUnifiedWallView.swift
//  Ohana
//
//  Snapshot-driven member and island achievement wall.
//

import SwiftData
import SwiftUI

struct AchievementUnifiedWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIDRaw = ""

    let pets: [Pet]
    let humans: [Human]

    @State private var snapshot = AchievementWallSnapshot.empty
    @State private var selectedScopeKey: String
    @State private var selectedCategoryRaw = Self.allFilterKey
    @State private var selectedStatus = AchievementWallStatusFilter.all
    @State private var selectedRecipientID: UUID?
    @State private var detailItem: AchievementWallItemSnapshot?
    @State private var pendingClaimItems: [AchievementWallItemSnapshot] = []
    @State private var showsClaimConfirmation = false
    @State private var isLoading = true
    @State private var isClaiming = false
    @State private var loadErrorMessage: String?
    @State private var claimMessage: AchievementClaimMessage?
    @State private var refreshRevision = 0

    private static let allFilterKey = "all"

    init(pets: [Pet], humans: [Human]) {
        self.pets = pets
        self.humans = humans
        let firstHuman = humans.first(where: { !$0.hasPassedAway })
        let initialScope = firstHuman.map { Self.scopeKey(kind: .human, id: $0.id.uuidString) }
            ?? pets.first(where: { !$0.hasPassedAway }).map {
                Self.scopeKey(kind: .pet, id: $0.id.uuidString)
            }
            ?? Self.scopeKey(kind: .island, id: AchievementScopeReference.islandID)
        _selectedScopeKey = State(initialValue: initialScope)
        _selectedRecipientID = State(initialValue: firstHuman?.id)
    }

    var body: some View {
        Group {
            if isLoading, snapshot.items.isEmpty {
                loadingView
            } else if let loadErrorMessage, snapshot.items.isEmpty {
                failureView(message: loadErrorMessage)
            } else if snapshot.items.isEmpty {
                emptyView
            } else {
                loadedView
            }
        }
        .task(id: snapshotLoadID) {
            await loadSnapshot()
        }
        .onAppear {
            synchronizeInitialRecipient()
        }
        .onChange(of: activeHumans.map(\.id)) { _, _ in
            synchronizeInitialRecipient()
        }
        .onChange(of: activeHumanIDRaw) { _, _ in
            synchronizeInitialRecipient()
        }
        .sheet(item: $detailItem) { item in
            AchievementSnapshotDetailSheet(
                item: item,
                appLanguage: appLanguage,
                scopeName: scopeName(for: item.scope),
                recipientName: selectedRecipient?.name,
                canClaim: item.isClaimable && selectedRecipient != nil && !isClaiming,
                onClaim: {
                    detailItem = nil
                    prepareClaim([item])
                }
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            claimConfirmationTitle,
            isPresented: $showsClaimConfirmation,
            titleVisibility: .visible
        ) {
            Button(claimConfirmationButtonTitle) {
                performPendingClaim()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(claimConfirmationMessage)
        }
        .alert(item: $claimMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.detail),
                dismissButton: .default(Text(l.tr(zh: "好", en: "OK", de: "OK")))
            )
        }
        .accessibilityIdentifier("achievement-unified-wall")
    }

    private var loadedView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                progressHeader
                scopeControls
                filterControls

                if let nextTarget {
                    nextTargetCard(nextTarget)
                }

                claimAllSection

                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        l.tr(zh: "没有符合筛选的成就", en: "No matching achievements", de: "Keine passenden Erfolge"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(l.tr(
                            zh: "调整范围、状态或类别后再试。",
                            en: "Try another scope, status, or category.",
                            de: "Versuche einen anderen Bereich, Status oder eine andere Kategorie."
                        ))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            achievementCard(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .refreshable {
            await loadSnapshot()
        }
        .accessibilityIdentifier("achievement-unified-wall")
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "成长总览", en: "Growth overview", de: "Wachstumsübersicht"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "已解锁 \(selectedItems.count(where: \.isUnlocked)) / \(selectedItems.count)",
                        en: "Unlocked \(selectedItems.count(where: \.isUnlocked)) of \(selectedItems.count)",
                        de: "\(selectedItems.count(where: \.isUnlocked)) von \(selectedItems.count) freigeschaltet"
                    ))
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(selectedItems.count(where: \.isUnlocked))/\(selectedItems.count)")
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }

            ProgressView(value: progressValue)
                .tint(Color.goPrimary)

            if snapshot.claimableCount > 0 {
                Label(
                    l.tr(
                        zh: "全岛还有 \(snapshot.claimableCount) 项奖励可领取",
                        en: "\(snapshot.claimableCount) island rewards are ready",
                        de: "\(snapshot.claimableCount) Inselbelohnungen sind bereit"
                    ),
                    systemImage: "gift.fill"
                )
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color(hex: "C77800"))
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
    }

    private var scopeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成就范围", en: "Achievement scope", de: "Erfolgsbereich"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)

            Picker(
                l.tr(zh: "成就范围", en: "Achievement scope", de: "Erfolgsbereich"),
                selection: $selectedScopeKey
            ) {
                ForEach(scopeOptions) { option in
                    Label(option.title, systemImage: option.icon)
                        .tag(option.key)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if activeHumans.isEmpty {
                Label(
                    l.tr(
                        zh: "没有有效 Human；已解锁奖励会保留，添加 Human 后即可领取。",
                        en: "No active Human. Unlocked rewards stay ready until a Human is added.",
                        de: "Kein aktiver Mensch. Freigeschaltete Belohnungen bleiben bis dahin erhalten."
                    ),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                HStack(spacing: 8) {
                    Text(l.tr(zh: "奖励接收人", en: "Reward recipient", de: "Belohnungsempfänger"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Picker(
                        l.tr(zh: "奖励接收人", en: "Reward recipient", de: "Belohnungsempfänger"),
                        selection: $selectedRecipientID
                    ) {
                        ForEach(activeHumans) { human in
                            Text(human.name).tag(Optional(human.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var filterControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                statusPicker
                categoryPicker
            }
            VStack(spacing: 10) {
                statusPicker
                categoryPicker
            }
        }
    }

    private var statusPicker: some View {
        Picker(
            l.tr(zh: "状态", en: "Status", de: "Status"),
            selection: $selectedStatus
        ) {
            ForEach(AchievementWallStatusFilter.allCases) { filter in
                Text(filter.title(l: l)).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    private var categoryPicker: some View {
        Picker(
            l.tr(zh: "类别", en: "Category", de: "Kategorie"),
            selection: $selectedCategoryRaw
        ) {
            Text(l.tr(zh: "全部类别", en: "All categories", de: "Alle Kategorien"))
                .tag(Self.allFilterKey)
            ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                Text(categoryTitle(category)).tag(category.rawValue)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    @ViewBuilder
    private var claimAllSection: some View {
        let claimable = filteredItems.filter(\.isClaimable)
        if !claimable.isEmpty {
            Button {
                prepareClaim(claimable)
            } label: {
                HStack(spacing: 8) {
                    if isClaiming {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "gift.fill")
                    }
                    Text(l.tr(
                        zh: "领取当前 \(claimable.count) 项奖励",
                        en: "Claim \(claimable.count) visible rewards",
                        de: "\(claimable.count) sichtbare Belohnungen abholen"
                    ))
                    Spacer()
                    Text(rewardSummary(claimable))
                        .monospacedDigit()
                }
                .font(OhanaFont.callout(.black))
                .frame(maxWidth: .infinity)
                .padding(14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .foregroundStyle(Color.arkInk)
            .disabled(selectedRecipient == nil || isClaiming)
            .accessibilityHint(recipientAccessibilityHint)
        }
    }

    private func nextTargetCard(_ item: AchievementWallItemSnapshot) -> some View {
        Button {
            detailItem = item
        } label: {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(OhanaFont.title2(.bold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "下一目标", en: "Next target", de: "Nächstes Ziel"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                    Text(item.title.value(languageCode: appLanguage))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(item.condition.value(languageCode: appLanguage))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.goPrimary.opacity(0.11), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func achievementCard(_ item: AchievementWallItemSnapshot) -> some View {
        Button {
            detailItem = item
        } label: {
            ZStack(alignment: .topLeading) {
                Image(item.artworkName)
                    .resizable()
                    .scaledToFill()
                    .opacity(item.isUnlocked ? 0.28 : 0.09)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [Color.ohanaCardSurface.opacity(0.58), Color.ohanaCardSurface.opacity(0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(item.emoji)
                            .font(OhanaFont.title2(.bold))
                            .accessibilityHidden(true)
                        Spacer()
                        achievementStateLabel(item)
                    }

                    Text(item.title.value(languageCode: appLanguage))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.leading)

                    Text(item.condition.value(languageCode: appLanguage))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)

                    Spacer(minLength: 2)

                    HStack(spacing: 9) {
                        Label("\(item.reward.coconuts)", systemImage: "circle.fill")
                        if item.reward.stardust > 0 {
                            Label("\(item.reward.stardust)✦", systemImage: "sparkles")
                        }
                        Spacer()
                        Text(scopeName(for: item.scope))
                    }
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 210 : 188, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
                    .strokeBorder(item.isClaimable ? Color.goPrimary : Color.ohanaDivider, lineWidth: item.isClaimable ? 1.5 : 0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cardAccessibilityLabel(item))
        .accessibilityHint(l.tr(zh: "打开成就详情", en: "Open achievement details", de: "Erfolgsdetails öffnen"))
    }

    private func achievementStateLabel(_ item: AchievementWallItemSnapshot) -> some View {
        let state = statePresentation(item)
        return Label(state.title, systemImage: state.icon)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(state.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(state.color.opacity(0.12), in: Capsule())
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.goPrimary)
            Text(l.tr(zh: "正在整理成就…", en: "Preparing achievements…", de: "Erfolge werden vorbereitet…"))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground())
        .accessibilityIdentifier("achievement-wall-loading")
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView {
            Label(
                l.tr(zh: "无法载入成就", en: "Unable to load achievements", de: "Erfolge konnten nicht geladen werden"),
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(message)
        } actions: {
            Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) {
                refreshRevision += 1
            }
        }
        .accessibilityIdentifier("achievement-wall-failed")
    }

    private var emptyView: some View {
        ContentUnavailableView(
            l.tr(zh: "暂无成就", en: "No achievements yet", de: "Noch keine Erfolge"),
            systemImage: "trophy",
            description: Text(l.tr(
                zh: "添加一位 Human 或 Pet 后，成长目标会出现在这里。",
                en: "Add a Human or Pet to begin your growth story.",
                de: "Füge einen Menschen oder ein Tier hinzu, um zu beginnen."
            ))
        )
        .accessibilityIdentifier("achievement-wall-empty")
    }

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var activeHumans: [Human] { humans.filter { !$0.hasPassedAway } }
    private var l: L10n { L10n(appLanguage) }

    private var scopes: [AchievementScopeReference] {
        activeHumans.map { .human($0.id) }
            + activePets.map { .pet($0.id) }
            + [.island]
    }

    private var snapshotLoadID: String {
        let scopeSignature = scopes
            .map { Self.scopeKey(kind: $0.kind, id: $0.id) }
            .joined(separator: "|")
        return "\(refreshRevision):\(scopeSignature)"
    }

    private var scopeOptions: [AchievementScopeOption] {
        let humanOptions = activeHumans.map {
            AchievementScopeOption(
                key: Self.scopeKey(kind: .human, id: $0.id.uuidString),
                title: $0.name,
                icon: "person.fill"
            )
        }
        let petOptions = activePets.map {
            AchievementScopeOption(
                key: Self.scopeKey(kind: .pet, id: $0.id.uuidString),
                title: $0.name,
                icon: "pawprint.fill"
            )
        }
        return humanOptions + petOptions + [
            AchievementScopeOption(
                key: Self.scopeKey(kind: .island, id: AchievementScopeReference.islandID),
                title: l.tr(zh: "全岛", en: "Island", de: "Insel"),
                icon: "globe.asia.australia.fill"
            )
        ]
    }

    private var selectedItems: [AchievementWallItemSnapshot] {
        snapshot.items.filter { Self.scopeKey(kind: $0.scope.kind, id: $0.scope.id) == selectedScopeKey }
    }

    private var filteredItems: [AchievementWallItemSnapshot] {
        selectedItems
            .filter { item in
                let categoryMatches = selectedCategoryRaw == Self.allFilterKey
                    || item.category.rawValue == selectedCategoryRaw
                return categoryMatches && selectedStatus.includes(item)
            }
            .sorted { lhs, rhs in
                let lhsRank = itemRank(lhs)
                let rhsRank = itemRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.title.value(languageCode: appLanguage)
                    .localizedStandardCompare(rhs.title.value(languageCode: appLanguage)) == .orderedAscending
            }
    }

    private var nextTarget: AchievementWallItemSnapshot? {
        selectedItems.first(where: { !$0.isUnlocked })
    }

    private var selectedRecipient: Human? {
        guard let selectedRecipientID else { return nil }
        return activeHumans.first(where: { $0.id == selectedRecipientID })
    }

    private var gridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 250, maximum: 380), spacing: 12)]
    }

    private var progressValue: Double {
        guard !selectedItems.isEmpty else { return 0 }
        return Double(selectedItems.count(where: \.isUnlocked)) / Double(selectedItems.count)
    }

    private var claimConfirmationTitle: String {
        guard let recipient = selectedRecipient else {
            return l.tr(zh: "暂时无法领取", en: "Unable to claim", de: "Abholen nicht möglich")
        }
        return l.tr(
            zh: "奖励发给 \(recipient.name)？",
            en: "Send rewards to \(recipient.name)?",
            de: "Belohnungen an \(recipient.name) senden?"
        )
    }

    private var claimConfirmationMessage: String {
        guard selectedRecipient != nil else {
            return l.tr(
                zh: "需要先添加一位有效 Human；奖励不会消失。",
                en: "Add an active Human first. The rewards will remain available.",
                de: "Füge zuerst einen aktiven Menschen hinzu. Die Belohnungen bleiben verfügbar."
            )
        }
        return l.tr(
            zh: "本次领取 \(pendingClaimItems.count) 项：\(rewardSummary(pendingClaimItems))。椰子、星光和领取回执会一起保存。",
            en: "Claim \(pendingClaimItems.count) rewards: \(rewardSummary(pendingClaimItems)). Coconuts, stardust, and receipts save together.",
            de: "\(pendingClaimItems.count) Belohnungen: \(rewardSummary(pendingClaimItems)). Kokosnüsse, Sternenstaub und Belege werden gemeinsam gespeichert."
        )
    }

    private var claimConfirmationButtonTitle: String {
        l.tr(zh: "确认领取", en: "Confirm claim", de: "Abholen bestätigen")
    }

    private var recipientAccessibilityHint: String {
        guard let recipient = selectedRecipient else {
            return l.tr(
                zh: "没有有效 Human，奖励会保持可领取",
                en: "No active Human; rewards remain claimable",
                de: "Kein aktiver Mensch; Belohnungen bleiben verfügbar"
            )
        }
        return l.tr(
            zh: "奖励将发给 \(recipient.name)",
            en: "Rewards will go to \(recipient.name)",
            de: "Belohnungen gehen an \(recipient.name)"
        )
    }

    @MainActor
    private func synchronizeInitialRecipient() {
        if let storedID = UUID(uuidString: activeHumanIDRaw),
           activeHumans.contains(where: { $0.id == storedID }) {
            selectedRecipientID = storedID
        } else if selectedRecipient == nil {
            selectedRecipientID = activeHumans.first?.id
        }
        if !scopeOptions.contains(where: { $0.key == selectedScopeKey }),
           let first = scopeOptions.first {
            selectedScopeKey = first.key
        }
    }

    @MainActor
    private func prepareClaim(_ items: [AchievementWallItemSnapshot]) {
        let claimable = items.filter(\.isClaimable)
        guard !claimable.isEmpty else { return }
        pendingClaimItems = claimable
        showsClaimConfirmation = true
    }

    @MainActor
    private func performPendingClaim() {
        guard !isClaiming else { return }
        guard let recipientID = selectedRecipient?.id else {
            claimMessage = AchievementClaimMessage(
                title: l.tr(zh: "奖励已保留", en: "Rewards saved", de: "Belohnungen bleiben erhalten"),
                detail: l.tr(
                    zh: "添加一位有效 Human 后再领取。",
                    en: "Add an active Human, then claim again.",
                    de: "Füge einen aktiven Menschen hinzu und versuche es erneut."
                )
            )
            return
        }
        isClaiming = true
        let result = AchievementCommandActor(context: modelContext).claim(
            keys: pendingClaimItems.map(\.achievementKey),
            recipientID: recipientID
        )
        isClaiming = false
        if result.didClaim {
            pendingClaimItems = []
            OhanaFeedback.success()
            claimMessage = AchievementClaimMessage(
                title: l.tr(zh: "奖励已领取", en: "Rewards claimed", de: "Belohnungen abgeholt"),
                detail: l.tr(
                    zh: "获得 \(result.coconutAmount)🥥 与 \(result.stardustAmount)✦。",
                    en: "Received \(result.coconutAmount)🥥 and \(result.stardustAmount)✦.",
                    de: "\(result.coconutAmount)🥥 und \(result.stardustAmount)✦ erhalten."
                )
            )
            refreshRevision += 1
        } else if let failure = result.failure {
            OhanaFeedback.error()
            claimMessage = claimFailureMessage(failure)
        }
    }

    @MainActor
    private func loadSnapshot() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            let progression = AchievementProgressionActor(modelContainer: modelContext.container)
            _ = try await progression.reconcile(
                AchievementProgressionRequest(affectedScopes: scopes, reason: .wallOpened)
            )
            guard !Task.isCancelled else { return }
            let reader = AchievementWallReadActor(modelContainer: modelContext.container)
            snapshot = try await reader.load(scopes: scopes)
            synchronizeInitialRecipient()
        } catch is CancellationError {
            return
        } catch {
            loadErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func claimFailureMessage(_ failure: AchievementClaimFailure) -> AchievementClaimMessage {
        let detail: String = switch failure {
        case .missingRecipient, .inactiveRecipient:
            l.tr(
                zh: "请选择一位有效 Human 作为奖励接收人。",
                en: "Choose an active Human to receive the rewards.",
                de: "Wähle einen aktiven Menschen als Empfänger."
            )
        case .alreadyClaimed:
            l.tr(zh: "这些奖励已经领取。", en: "These rewards were already claimed.", de: "Diese Belohnungen wurden bereits abgeholt.")
        case .locked:
            l.tr(zh: "部分成就尚未解锁，请刷新后重试。", en: "Some achievements are still locked. Refresh and try again.", de: "Einige Erfolge sind noch gesperrt. Aktualisiere und versuche es erneut.")
        case .persistenceBusy:
            l.tr(zh: "正在备份或处理另一笔写入，请稍后重试。", en: "A backup or another save is in progress. Try again shortly.", de: "Eine Sicherung oder ein anderer Speichervorgang läuft. Versuche es gleich erneut.")
        case let .persistenceFailed(message):
            message
        }
        return AchievementClaimMessage(
            title: l.tr(zh: "领取未完成", en: "Claim not completed", de: "Abholen nicht abgeschlossen"),
            detail: detail
        )
    }

    private func rewardSummary(_ items: [AchievementWallItemSnapshot]) -> String {
        let coconuts = items.reduce(0) { $0 + $1.reward.coconuts }
        let stardust = items.reduce(0) { $0 + $1.reward.stardust }
        return stardust > 0 ? "\(coconuts)🥥 + \(stardust)✦" : "\(coconuts)🥥"
    }

    private func scopeName(for scope: AchievementScopeReference) -> String {
        switch scope.kind {
        case .human:
            activeHumans.first(where: { $0.id.uuidString == scope.id })?.name
                ?? l.tr(zh: "Human", en: "Human", de: "Mensch")
        case .pet:
            activePets.first(where: { $0.id.uuidString == scope.id })?.name
                ?? l.tr(zh: "Pet", en: "Pet", de: "Tier")
        case .island:
            l.tr(zh: "全岛", en: "Island", de: "Insel")
        case .legacyUnknown:
            l.tr(zh: "旧记录", en: "Legacy", de: "Altdaten")
        }
    }

    private func categoryTitle(_ category: AchievementCategory) -> String {
        switch category {
        case .care: l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .health: l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .movement: l.tr(zh: "运动", en: "Movement", de: "Bewegung")
        case .memory: l.tr(zh: "回忆", en: "Memory", de: "Erinnerung")
        case .profile: l.tr(zh: "档案", en: "Profile", de: "Profil")
        case .economy: l.tr(zh: "经济", en: "Economy", de: "Wirtschaft")
        case .companion: l.tr(zh: "伙伴", en: "Companion", de: "Begleiter")
        case .gacha: l.tr(zh: "盲盒", en: "Blind box", de: "Blindbox")
        case .island: l.tr(zh: "全岛", en: "Island", de: "Insel")
        }
    }

    private func statePresentation(_ item: AchievementWallItemSnapshot) -> (title: String, icon: String, color: Color) {
        if item.isClaimed {
            return (l.tr(zh: "已领取", en: "Claimed", de: "Abgeholt"), "checkmark.seal.fill", Color.green)
        }
        if item.isClaimable {
            return (l.tr(zh: "可领取", en: "Ready", de: "Bereit"), "gift.fill", Color(hex: "C77800"))
        }
        if item.isUnlocked {
            return (l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet"), "lock.open.fill", Color.goPrimary)
        }
        return (l.tr(zh: "未解锁", en: "Locked", de: "Gesperrt"), "lock.fill", Color.ohanaSecondaryText)
    }

    private func cardAccessibilityLabel(_ item: AchievementWallItemSnapshot) -> String {
        let state = statePresentation(item).title
        return "\(item.title.value(languageCode: appLanguage)), \(state), \(item.condition.value(languageCode: appLanguage)), \(rewardSummary([item]))"
    }

    private func itemRank(_ item: AchievementWallItemSnapshot) -> Int {
        if item.isClaimable { return 0 }
        if item.isUnlocked { return 1 }
        return 2
    }

    private static func scopeKey(kind: AchievementScopeKind, id: String) -> String {
        "\(kind.rawValue):\(id.lowercased())"
    }
}

private nonisolated enum AchievementWallStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case claimable
    case unlocked
    case locked

    var id: String { rawValue }

    func includes(_ item: AchievementWallItemSnapshot) -> Bool {
        switch self {
        case .all: true
        case .claimable: item.isClaimable
        case .unlocked: item.isUnlocked
        case .locked: !item.isUnlocked
        }
    }

    func title(l: L10n) -> String {
        switch self {
        case .all: l.tr(zh: "全部状态", en: "All statuses", de: "Alle Status")
        case .claimable: l.tr(zh: "可领取", en: "Claimable", de: "Abholbereit")
        case .unlocked: l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        case .locked: l.tr(zh: "未解锁", en: "Locked", de: "Gesperrt")
        }
    }
}

private struct AchievementScopeOption: Identifiable {
    let key: String
    let title: String
    let icon: String

    var id: String { key }
}

private struct AchievementClaimMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct AchievementSnapshotDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: AchievementWallItemSnapshot
    let appLanguage: String
    let scopeName: String
    let recipientName: String?
    let canClaim: Bool
    let onClaim: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        Text(item.emoji)
                            .font(OhanaFont.largeTitle(.bold))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title.value(languageCode: appLanguage))
                                .font(OhanaFont.title2(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(scopeName)
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(Color.goPrimary)
                        }
                    }

                    detailSection(
                        title: l.tr(zh: "完成条件", en: "Requirement", de: "Bedingung"),
                        text: item.condition.value(languageCode: appLanguage)
                    )

                    if let unlockedAt = item.unlockedAt {
                        detailSection(
                            title: l.tr(zh: "完成日期", en: "Completed", de: "Abgeschlossen"),
                            text: unlockedAt.formatted(date: .long, time: .omitted)
                        )
                    }

                    detailSection(
                        title: l.tr(zh: "奖励", en: "Reward", de: "Belohnung"),
                        text: item.reward.stardust > 0
                            ? "\(item.reward.coconuts)🥥 + \(item.reward.stardust)✦"
                            : "\(item.reward.coconuts)🥥"
                    )

                    if item.isClaimable {
                        if let recipientName {
                            Button {
                                onClaim()
                            } label: {
                                Label(
                                    l.tr(
                                        zh: "领取给 \(recipientName)",
                                        en: "Claim for \(recipientName)",
                                        de: "Für \(recipientName) abholen"
                                    ),
                                    systemImage: "gift.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.goPrimary)
                            .foregroundStyle(Color.arkInk)
                            .disabled(!canClaim)
                        } else {
                            Label(
                                l.tr(
                                    zh: "奖励已保留；添加有效 Human 后即可领取。",
                                    en: "Reward saved. Add an active Human to claim it.",
                                    de: "Belohnung bleibt erhalten. Füge zum Abholen einen aktiven Menschen hinzu."
                                ),
                                systemImage: "person.crop.circle.badge.exclamationmark"
                            )
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }

                    ShareLink(
                        item: shareText,
                        subject: Text(item.title.value(languageCode: appLanguage))
                    ) {
                        Label(l.tr(zh: "分享成就", en: "Share achievement", de: "Erfolg teilen"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
            }
            .background(OhanaAppBackground())
            .navigationTitle(l.tr(zh: "成就详情", en: "Achievement", de: "Erfolg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) { dismiss() }
                }
            }
        }
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var shareText: String {
        "\(item.emoji) \(item.title.value(languageCode: appLanguage))\n\(item.condition.value(languageCode: appLanguage))"
    }
}
