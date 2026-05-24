//
//  FocusHomeAuxiliaryViews.swift
//  Ohana
//
//  Small rendering-only helpers used by FocusStackHomeTestView.
//

import SwiftUI

struct ExpandedQuickMenuOption: Identifiable {
    let id: String
    let icon: String
    let title: String
    let tint: Color
}

struct TodayFocusQuestCardHost: View {
    let pets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePet: Pet?
    var presentation: TodayFocusCardPresentation = .board
    var onOpenQuest: (IslandQuest) -> Void
    var onCompleteQuest: (IslandQuest) -> Void
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void
    var onTapOasis: () -> Void
    var onTapFamilyTask: (FamilyCollaborationTask) -> Void

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var privacyVisibleHumans: [Human] {
        PrivacyService.unlockedHumans(for: .weight, from: humans, viewedBy: activeHumanId)
    }

    var body: some View {
        TodayFocusCard(
            pets: pets,
            plants: plants,
            quests: IslandQuestEngine.todayQuests(
                pets: pets,
                reminders: reminders,
                plants: plants,
                events: events,
                humans: privacyVisibleHumans
            ),
            humans: privacyVisibleHumans,
            activePet: activePet,
            presentation: presentation,
            onOpenQuest: onOpenQuest,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapOasis: onTapOasis,
            onTapFamilyTask: onTapFamilyTask
        )
    }
}

struct WalkLaunchBurst: View {
    @State private var animate = false

    private let paws: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-92, 50, 0.00), (-48, 18, 0.06), (-6, 42, 0.12),
        (38, 10, 0.18), (82, 34, 0.24)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.goLime.opacity(animate ? 0.22 : 0.04),
                            Color.goTeal.opacity(animate ? 0.16 : 0.03),
                            .clear
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .scaleEffect(animate ? 1.02 : 0.96)

            HStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 20, weight: .black))
                Text("开始巡岛")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.goPrimary, in: Capsule())
            .scaleEffect(animate ? 1 : 0.72)
            .opacity(animate ? 1 : 0)

            ForEach(paws.indices, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.goLime.opacity(0.88))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 16))
                    .offset(
                        x: animate ? paws[index].x : paws[index].x - 28,
                        y: animate ? paws[index].y - 64 : paws[index].y
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.78).delay(paws[index].delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            withAnimation(HeroAnim.fabSpring) {
                animate = true
            }
        }
    }
}

struct FocusHumanPortrait: View {
    let emoji: String
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .fill(color.mix(with: .white, by: 0.45).opacity(0.30))
                    .frame(width: g.size.width * 0.65)
                    .offset(x: -g.size.width * 0.18, y: -g.size.height * 0.14)
                Text(emoji)
                    .font(.system(size: g.size.height * 0.44))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -g.size.height * 0.04)
            }
        }
    }
}

struct ExpandedQuickActionMenuPanel: View {
    let icon: String
    let title: String
    let status: String
    let accent: Color
    let isLocked: Bool
    let lockedText: String?
    let quickTitle: String
    let detailTitle: String?
    let isQuickDisabled: Bool
    let quickOptions: [ExpandedQuickMenuOption]
    let onQuick: () -> Void
    let onDetail: () -> Void
    let onOption: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                .padding(.top, 8)
                .gesture(
                    DragGesture(minimumDistance: 12).onEnded { value in
                        if value.translation.height > 32 {
                            onClose()
                        }
                    }
                )

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(status)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            VStack(spacing: 10) {
                if isLocked {
                    lockedBlock
                } else if !quickOptions.isEmpty {
                    optionGrid
                } else {
                    actionButton(
                        title: quickTitle,
                        icon: isQuickDisabled ? "checkmark.circle.fill" : "bolt.fill",
                        tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                        foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                        isDisabled: isQuickDisabled,
                        action: onQuick
                    )
                }

                if !isLocked, let detailTitle {
                    actionButton(
                        title: detailTitle,
                        icon: "chart.line.uptrend.xyaxis",
                        tint: Color.ohanaControlFill,
                        foreground: Color.ohanaPrimaryText,
                        isDisabled: false,
                        action: onDetail
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        .shadow(color: Color.black.opacity(0.34), radius: 30, x: 0, y: -8) // ui-v4: allow lifted overlay shadow
    }

    private var lockedBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(lockedText ?? "")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var optionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quickTitle)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(quickOptions) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onOption(option.id)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(option.tint)
                            Text(option.title)
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        foreground: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                Text(title)
                    .font(OhanaFont.body(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint, in: Capsule())
        }
        .disabled(isDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
}
