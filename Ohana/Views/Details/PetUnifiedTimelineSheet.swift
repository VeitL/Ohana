//
//  PetUnifiedTimelineSheet.swift
//  Ohana
//
//  岁月史书 — 分层高光时间线
//

import SwiftUI
import SwiftData

struct PetUnifiedTimelineSheet: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.fallbackCode
    @State private var selectedMode: PetTimelineDisplayMode = .highlights

    private var l: L10n { L10n(appLanguageRaw) }

    private var sections: [PetTimelineArchiveSection] {
        PetTimelineItemsBuilder.archiveSections(for: pet, mode: selectedMode, l: l)
    }

    private var highlightCount: Int {
        PetTimelineItemsBuilder.archiveItems(for: pet, mode: .highlights, l: l).count
    }

    private var memoryCount: Int {
        PetTimelineItemsBuilder.archiveItems(for: pet, mode: .memories, l: l).count
    }

    private var totalCount: Int {
        PetTimelineItemsBuilder.archiveItems(for: pet, mode: .all, l: l).count
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    metrics
                    filterChips

                    if sections.isEmpty {
                        emptyState
                            .padding(.top, 36)
                    } else {
                        timelineSections
                    }

                    Color.clear.frame(height: 34)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tint(Color.goPrimary)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 44,
                backgroundOpacity: 0.14,
                transparentScale: 0.78,
                transparentYOffset: 0.04
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "岁月史书", en: "Life Chronicle", de: "Lebenschronik"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var metrics: some View {
        HStack(spacing: 18) {
            metric(l.tr(zh: "高光", en: "Highlights", de: "Highlights"), "\(highlightCount)", Color.goPrimary)
            metric(l.tr(zh: "回忆", en: "Memories", de: "Erinnerungen"), "\(memoryCount)", Color.goPurple)
            metric(l.tr(zh: "全部", en: "All", de: "Alle"), "\(totalCount)", Color.goTeal)
        }
        .animation(GoMotion.stateChange, value: highlightCount)
        .animation(GoMotion.stateChange, value: memoryCount)
        .animation(GoMotion.stateChange, value: totalCount)
    }

    private func metric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(OhanaFont.metric(size: 26))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PetTimelineDisplayMode.allCases) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedMode = mode
                        }
                    } label: {
                        Text(mode.title(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(selectedMode == mode ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selectedMode == mode ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var timelineSections: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(section.title)
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(section.subtitle)
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            if item.style == .story {
                                storyRow(item)
                            } else {
                                railRow(item, isLast: index == section.items.count - 1)
                            }
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(GoMotion.stateChange, value: selectedMode)
    }

    private func storyRow(_ item: UnifiedLogItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(item.color.opacity(0.18))
                Image(systemName: item.iconName)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(item.color)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Text(item.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func railRow(_ item: UnifiedLogItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.18))
                    Image(systemName: item.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(item.color)
                }
                .frame(width: 30, height: 30)

                if !isLast {
                    Rectangle()
                        .fill(Color.ohanaSecondaryText.opacity(0.15))
                        .frame(width: 1, height: 22)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Text(item.date, format: .dateTime.hour().minute())
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.65))
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedMode == .highlights ? "sparkles" : "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.goPrimary)

            VStack(spacing: 4) {
                Text(l.tr(zh: "还没有故事", en: "No stories yet", de: "Noch keine Geschichten"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "记录今天的小事", en: "Capture a small moment today", de: "Halte heute einen kleinen Moment fest"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Button { dismiss() } label: {
                Text(l.tr(zh: "去记录", en: "Record", de: "Notieren"))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
