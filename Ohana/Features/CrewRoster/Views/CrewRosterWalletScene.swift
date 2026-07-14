//
//  CrewRosterWalletScene.swift
//  Ohana
//
//  Ordered roster scene using the same portrait card surface as Home.
//

import SwiftData
import SwiftUI

struct CrewRosterWalletScene: View {
    let cards: [FocusCard]
    let mediaRequestsByID: [UUID: VerticalSolidHomeMediaPreloadRequest]
    let safeBottom: CGFloat
    let reduceMotion: Bool
    let onSelect: (FocusCard) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: CrewRosterGridMetrics.minimumCardWidth,
                            maximum: CrewRosterGridMetrics.maximumCardWidth
                        ),
                        spacing: CrewRosterGridMetrics.columnSpacing,
                        alignment: .top
                    )
                ],
                alignment: .center,
                spacing: CrewRosterGridMetrics.rowSpacing
            ) {
                ForEach(cards) { card in
                    CrewRosterWalletCard(
                        card: card,
                        mediaRequest: mediaRequestsByID[card.id],
                        reduceMotion: reduceMotion,
                        localization: l,
                        onSelect: onSelect
                    )
                }
            }
            .padding(.horizontal, CrewRosterGridMetrics.horizontalInset)
            .padding(.top, 8)
            .padding(.bottom, max(24, safeBottom + 16))
        }
        .accessibilityIdentifier("crew-roster-member-grid")
    }
}

private struct CrewRosterWalletCard: View {
    let card: FocusCard
    let mediaRequest: VerticalSolidHomeMediaPreloadRequest?
    let reduceMotion: Bool
    let localization: L10n
    let onSelect: (FocusCard) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var avatarCacheRevision = 0
    @State private var loadedAvatarSource: FocusHomeFrozenAvatarSource?

    var body: some View {
        Button {
            OhanaFeedback.light()
            onSelect(card)
        } label: {
            GeometryReader { proxy in
                FocusHomeVerticalSolidCardSurface(
                    card: card,
                    progress: 0,
                    reduceMotion: reduceMotion,
                    localization: localization,
                    frozenAvatarSource: loadedAvatarSource,
                    allowsLiveAvatarFallback: true
                )
                .id(avatarCacheRevision)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(alignment: .bottomTrailing) {
                    if card.homePrimaryMetricValue != "\(card.coconutBalance)"
                        || card.homePrimaryMetricUnit != "c" {
                        Label("\(card.coconutBalance)", systemImage: "wallet.bifold.fill")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.goYellow, in: Capsule())
                            .padding(12)
                            .accessibilityHidden(true)
                    }
                }
            }
            .aspectRatio(
                1 / FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio,
                contentMode: .fit
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(
            cornerRadius: CrewRosterGridMetrics.cardCornerRadius,
            style: .continuous
        ))
        .accessibilityLabel(localization.tr(
            zh: "\(card.name)，\(card.coconutBalance) 个椰子",
            en: "\(card.name), \(card.coconutBalance) coconuts",
            de: "\(card.name), \(card.coconutBalance) Kokosnüsse"
        ))
        .accessibilityHint(localization.tr(
            zh: "打开成员详情与钱包",
            en: "Open member details and wallet",
            de: "Mitgliedsdetails und Wallet öffnen"
        ))
        .accessibilityIdentifier(cardAccessibilityIdentifier)
        .task(id: mediaRequest?.avatarSignature ?? "") {
            await loadAvatarIfNeeded()
        }
    }

    private var cardAccessibilityIdentifier: String {
        let kind = if card.isPlant {
            "plant"
        } else if card.isHuman {
            "human"
        } else {
            "pet"
        }
        return "crew-roster-card-\(kind)-\(card.name)"
    }

    private func loadAvatarIfNeeded() async {
        loadedAvatarSource = nil
        avatarCacheRevision &+= 1
        guard let mediaRequest,
              mediaRequest.wantsAvatar,
              !mediaRequest.avatarSignature.isEmpty else { return }

        if let cached = FocusWalletAvatarCache.cachedEntry(
            for: mediaRequest.id,
            signature: mediaRequest.avatarSignature
        ), let image = cached.image {
            loadedAvatarSource = FocusHomeFrozenAvatarSource(
                image: image,
                isTransparent: cached.isTransparent
            )
            avatarCacheRevision &+= 1
            return
        }

        await OhanaFrameScheduler.waitAfterNextFrame()
        guard !Task.isCancelled else { return }
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        let data: Data? = switch mediaRequest.source {
        case .pet:
            await loader.petAvatarImageData(modelID: mediaRequest.modelID)
        case .human:
            await loader.humanAvatarImageData(modelID: mediaRequest.modelID)
        }
        guard !Task.isCancelled, let data, !data.isEmpty else { return }
        _ = await FocusWalletAvatarCache.preload(payloads: [
            FocusWalletAvatarCache.Payload(id: mediaRequest.id, data: data)
        ])
        guard !Task.isCancelled else { return }
        let resolvedSignature = FocusWalletAvatarCache.signature(for: data)
        guard let entry = FocusWalletAvatarCache.cachedEntry(
            for: mediaRequest.id,
            signature: resolvedSignature
        ), let image = entry.image else { return }
        loadedAvatarSource = FocusHomeFrozenAvatarSource(
            image: image,
            isTransparent: entry.isTransparent
        )
        avatarCacheRevision &+= 1
    }
}

private enum CrewRosterGridMetrics {
    static let horizontalInset: CGFloat = 18
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 14
    static let minimumCardWidth: CGFloat = 142
    static let maximumCardWidth: CGFloat = 172
    static let cardCornerRadius: CGFloat = 30
}

enum CrewRosterProfileContinuityMetrics {
    static let horizontalInset: CGFloat = 18
    static let summaryTopInset: CGFloat = 178
    static let summaryDetailGap: CGFloat = 12
}

struct CrewRosterProfileSummarySnapshot: Equatable {
    let memberKindText: String
    let memberKindIcon: String
    let statusText: String?
    let statusIcon: String
    let eyebrow: String
    let summaryText: String
    let metrics: [CrewRosterProfileSummaryMetric]
    let rows: [CrewRosterProfileSummaryRow]

    static func make(card: FocusCard, l: L10n) -> CrewRosterProfileSummarySnapshot {
        let memberKindIcon: String
        let memberKindText: String
        if card.isHuman {
            memberKindIcon = "person.fill"
            memberKindText = l.tr(zh: "人类", en: "Human", de: "Mensch")
        } else if card.actions.contains(where: { $0.icon == "leaf.fill" }) {
            memberKindIcon = "leaf.fill"
            memberKindText = l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        } else {
            memberKindIcon = "pawprint.fill"
            memberKindText = l.tr(zh: "宠物", en: "Pet", de: "Tier")
        }

        var metrics: [CrewRosterProfileSummaryMetric] = []
        metrics.append(.init(
            id: "coconuts",
            title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"),
            value: "\(card.coconutBalance)",
            icon: "circle.hexagongrid.fill"
        ))
        if card.streak > 0 {
            metrics.append(.init(
                id: "streak",
                title: l.tr(zh: "连击", en: "Streak", de: "Serie"),
                value: "\(card.streak)",
                icon: "flame.fill"
            ))
        }

        var rows: [CrewRosterProfileSummaryRow] = []
        if let age = card.ageText, !age.isEmpty {
            rows.append(.init(id: "age", title: l.tr(zh: "年龄", en: "Age", de: "Alter"), value: age, icon: "calendar"))
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            rows.append(.init(id: "together", title: l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), value: days, icon: "heart.fill"))
        }
        if let gender = card.genderText, !gender.isEmpty {
            rows.append(.init(id: "gender", title: l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), value: gender, icon: "person.fill"))
        }
        if let zodiac = card.zodiacText, !zodiac.isEmpty {
            rows.append(.init(id: "zodiac", title: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: zodiac, icon: "sparkles"))
        }
        if let mbti = card.mbtiText, !mbti.isEmpty {
            rows.append(.init(id: "mbti", title: "MBTI", value: mbti, icon: "brain.head.profile"))
        }
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(id: "breed", title: l.tr(zh: "品种", en: "Breed", de: "Rasse"), value: card.breed, icon: "tag.fill"))
        }
        if rows.count < 4, !card.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(id: "type", title: l.tr(zh: "类型", en: "Type", de: "Typ"), value: card.kind, icon: memberKindIcon))
        }

        let statusText = card.statusBadgeText?.trimmingCharacters(in: .whitespacesAndNewlines)

        return .init(
            memberKindText: memberKindText,
            memberKindIcon: memberKindIcon,
            statusText: statusText?.isEmpty == false ? statusText : nil,
            statusIcon: card.statusBadgeIsWarning ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
            eyebrow: l.tr(zh: "基本信息", en: "Profile", de: "Profil"),
            summaryText: card.personalityHint ?? secondaryIdentityText(for: card),
            metrics: metrics,
            rows: Array(rows.prefix(4))
        )
    }

    private static func secondaryIdentityText(for card: FocusCard) -> String {
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return card.breed
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            return days
        }
        return card.kind
    }
}

struct CrewRosterProfileSummaryMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct CrewRosterProfileSummaryRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct CrewRosterProfileSummaryHeader: View {
    let snapshot: CrewRosterProfileSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                inlineFact(snapshot.memberKindText, icon: snapshot.memberKindIcon)
                if let status = snapshot.statusText {
                    inlineFact(status, icon: snapshot.statusIcon)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.eyebrow)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.64))
                        .textCase(.uppercase)
                    Text(snapshot.summaryText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.84))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }
                .shadow(color: Color.arkInk.opacity(0.34), radius: 6, y: 2) // ui-v4: allow readability shadow on image card

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(snapshot.metrics) { metric in
                        plainMetric(metric)
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 9) {
                ForEach(snapshot.rows) { row in
                    compactInfoTile(row)
                }
            }
        }
    }

    private func inlineFact(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
            Text(text)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
        }
        .foregroundStyle(Color.goCardWhite.opacity(0.78))
        .shadow(color: Color.arkInk.opacity(0.30), radius: 5, y: 2) // ui-v4: allow text readability shadow on image card
    }

    private func plainMetric(_ metric: CrewRosterProfileSummaryMetric) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: metric.icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(metric.value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.goCardWhite)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
            Text(metric.title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .shadow(color: Color.arkInk.opacity(0.32), radius: 6, y: 2) // ui-v4: allow text readability shadow on image card
    }

    private func compactInfoTile(_ row: CrewRosterProfileSummaryRow) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(row.title)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .shadow(color: Color.arkInk.opacity(0.30), radius: 5, y: 2) // ui-v4: allow text readability shadow on image card
    }
}
