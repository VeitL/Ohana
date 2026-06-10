//
//  AchievementWallContentView+Layout.swift
//  Ohana
//

import SwiftUI
import UIKit

extension AchievementWallContentView {
    var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "成就解锁", en: "Badges", de: "Abzeichen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(activeMemberName)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            CoconutBalanceCapsule(
                balance: activeCoconutBalance,
                showsDeltaAnimation: true,
                deltaAnimationContext: "achievementWall:\(activeSubject.id)"
            ) {
                onPresentCoconutLog?(activeCoconutLogSubject)
            }
            .accessibilityLabel(l.tr(zh: "椰子历史", en: "Coconut history", de: "Kokosnuss-Verlauf"))

            Button { dismiss() } label: {
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

    var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(subjects) { subject in
                    let isSelected = activeSubject == subject
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedSubject = subject
                        }
                    } label: {
                        VStack(spacing: 5) {
                            memberAvatar(for: subject, size: 44, isSelected: isSelected)
                            Text(memberName(for: subject))
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaSecondaryText)
                                .lineLimit(1)
                                .frame(width: 58)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    var progressHero: some View {
        let total = max(achievements.count, 1)
        let percent = Double(unlocked.count) / Double(total)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                activeMemberAvatar(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(unlocked.count)/\(achievements.count)")
                        .font(OhanaFont.metric(size: 42))
                        .foregroundStyle(Color.goPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(l.tr(zh: "已解锁", en: "unlocked", de: "freigeschaltet"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(percent * 100))%")
                        .font(OhanaFont.metric(size: 30))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(l.tr(zh: "\(claimable.count) 个可领取", en: "\(claimable.count) rewards", de: "\(claimable.count) Belohnungen"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(claimable.isEmpty ? Color.ohanaSecondaryText : Color.goPrimary)
                }
            }

            progressBar(percent, tint: Color.goPrimary)

            if let next = nextAchievement {
                Button { selectedAchievement = next } label: {
                    nextTargetRow(next)
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                completedRow
            }

            if !claimable.isEmpty {
                Button { claimAllRewards() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill") // a11y: allow decorative icon covered by surrounding text or control
                        Text(l.tr(
                            zh: "领取全部 +\(claimable.count * rewardPerAchievement)🥥",
                            en: "Claim all +\(claimable.count * rewardPerAchievement)🥥",
                            de: "Alle abholen +\(claimable.count * rewardPerAchievement)🥥"
                        ))
                    }
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .animation(GoMotion.stateChange, value: unlocked.count)
        .animation(GoMotion.stateChange, value: claimable.count)
    }

    func nextTargetRow(_ badge: Achievement) -> some View {
        let info = progress(for: badge)
        return HStack(spacing: 12) {
            Text(badge.emoji)
                .font(OhanaFont.adaptive(size: 30)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .frame(width: 52, height: 52)
                .background(badge.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(zh: "下一枚", en: "Next badge", de: "Nächstes Abzeichen"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
                Text(badge.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                progressBar(info.fraction, tint: badge.color)
                Text(info.summary)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var completedRow: some View {
        HStack(spacing: 12) {
            Text("🏆").font(OhanaFont.adaptive(size: 30)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "全部成就已解锁", en: "All badges unlocked", de: "Alle Abzeichen freigeschaltet"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "继续记录，新的徽章会从这些故事里长出来", en: "Keep logging; future badges grow from these stories", de: "Weitere Abzeichen wachsen aus euren Geschichten"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementFilter.allCases, id: \.self) { filter in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(selectedFilter == filter ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selectedFilter == filter ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    var achievementGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedAchievements) { badge in
                achievementCard(badge)
            }
        }
        .animation(GoMotion.stateChange, value: selectedFilter)
    }

    func achievementCard(_ badge: Achievement) -> some View {
        let info = progress(for: badge)
        let state = rewardState(for: badge)
        let backgroundName = achievementBackgroundName(for: badge)
        let usesArtwork = backgroundName != nil
        let foreground = usesArtwork ? artworkCardForeground(for: state) : cardForeground(for: state)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.sheet) {
                selectedAchievement = badge
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                achievementArtworkBackground(backgroundName, state: state, tint: badge.color)

                stateMark(state, tint: badge.color, foreground: foreground.primary)
                    .padding(14)
                    .shadow(color: Color.arkInk.opacity(usesArtwork ? 0.24 : 0), radius: 4, x: 0, y: 2) // ui-v4: allow artwork icon readability without image wash

                VStack(alignment: .leading, spacing: 9) {
                    Spacer(minLength: 0)
                    Text(badge.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(foreground.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(stateText(for: badge, state: state, info: info))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(foreground.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    progressBar(info.fraction, tint: foreground.progressTint, track: foreground.progressTrack)
                }
                .padding(14)
                .shadow(color: Color.arkInk.opacity(usesArtwork ? 0.34 : 0), radius: 5, x: 0, y: 2) // ui-v4: allow artwork text readability without image wash
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.arkInk.opacity(usesArtwork ? 0.08 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    func stateMark(_ state: AchievementRewardState, tint: Color, foreground: Color? = nil) -> some View {
        let resolvedForeground = foreground ?? Color.ohanaPrimaryText
        switch state {
        case .claimable:
            Image(systemName: "gift.fill") // a11y: allow decorative icon covered by surrounding text or control
                .foregroundStyle(foreground ?? Color.arkInk)
        case .claimed:
            Image(systemName: "checkmark.seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                .foregroundStyle(resolvedForeground)
        case .unlocked:
            Image(systemName: "seal.fill") // a11y: allow decorative icon covered by surrounding text or control
                .foregroundStyle(resolvedForeground)
        case .locked:
            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(foreground ?? Color.ohanaSecondaryText)
        }
    }

    func achievementBackgroundName(for badge: Achievement) -> String? {
        Self.achievementBackgroundNames[badge.id]
    }

    @ViewBuilder
    func achievementArtworkBackground(_ imageName: String?, state: AchievementRewardState, tint: Color) -> some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .saturation(state == .locked ? 0.24 : 1)
                .opacity(state == .locked ? 0.58 : 1)
                .overlay {
                    if state == .locked {
                        artworkReadabilityWash(for: state)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            cardBackground(for: state, tint: tint)
        }
    }

    func artworkReadabilityWash(for state: AchievementRewardState) -> LinearGradient {
        let top = state == .locked ? 0.84 : 0.64
        let middle = state == .claimable ? 0.44 : 0.54
        let bottom = state == .locked ? 0.30 : 0.16
        return LinearGradient(
            colors: [
                Color.goCardWhite.opacity(top),
                Color.goCardWhite.opacity(middle),
                Color.arkInk.opacity(bottom)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func cardBackground(for state: AchievementRewardState, tint: Color) -> Color {
        switch state {
        case .claimable: return Color.goPrimary
        case .claimed, .unlocked: return Color.ohanaCardSurfaceElevated
        case .locked: return Color.ohanaCardSurface
        }
    }

    func cardForeground(for state: AchievementRewardState) -> (primary: Color, secondary: Color, progressTint: Color, progressTrack: Color) {
        switch state {
        case .claimable:
            return (
                Color.arkInk,
                Color.arkInk.opacity(0.74),
                Color.arkInk,
                Color.arkInk.opacity(0.18)
            )
        case .claimed, .unlocked:
            return (
                Color.ohanaPrimaryText,
                Color.ohanaSecondaryText,
                Color.goPrimary,
                Color.ohanaControlFill
            )
        case .locked:
            return (
                Color.ohanaSecondaryText,
                Color.ohanaTertiaryText,
                Color.ohanaSecondaryText,
                Color.ohanaControlFill
            )
        }
    }

    func artworkCardForeground(for state: AchievementRewardState) -> (primary: Color, secondary: Color, progressTint: Color, progressTrack: Color) {
        switch state {
        case .claimable, .claimed, .unlocked:
            return (
                Color.goCardWhite,
                Color.goCardWhite.opacity(0.82),
                Color.goCardWhite,
                Color.goCardWhite.opacity(0.28)
            )
        case .locked:
            return (
                Color.arkInk.opacity(0.62),
                Color.arkInk.opacity(0.48),
                Color.arkInk.opacity(0.45),
                Color.arkInk.opacity(0.10)
            )
        }
    }

    func stateText(for badge: Achievement, state: AchievementRewardState, info: ProgressInfo) -> String {
        switch state {
        case .claimable:
            return l.tr(zh: "可领取 +\(rewardPerAchievement)🥥", en: "Claim +\(rewardPerAchievement)🥥", de: "+\(rewardPerAchievement)🥥 abholen")
        case .claimed:
            return l.tr(zh: "奖励已领取", en: "Reward claimed", de: "Belohnung abgeholt")
        case .unlocked:
            return l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        case .locked:
            return info.summary
        }
    }

    func achievementMomentLine(for badge: Achievement) -> String {
        switch badge.id {
        case "iron_gut": return l.tr(zh: "这是一段稳定又安心的照护节奏。", en: "A steady care rhythm worth keeping.", de: "Ein ruhiger Pflegerhythmus, der bleibt.")
        case "iron_paw": return l.tr(zh: "一步一步，你们把日常走成了远方。", en: "Step by step, ordinary walks became distance.", de: "Schritt für Schritt wurde Alltag zu Strecke.")
        case "walk_streak": return l.tr(zh: "连续出门的日子，会慢慢变成习惯。", en: "Daily walks quietly turn into a habit.", de: "Tägliche Wege werden leise zur Gewohnheit.")
        case "health_hero": return l.tr(zh: "平稳健康，是最值得庆祝的小事。", en: "Steady health is a quiet thing to celebrate.", de: "Stabile Gesundheit ist ein leiser Grund zum Feiern.")
        case "nutritionist": return l.tr(zh: "每一餐都被认真记住了。", en: "Every meal was remembered with care.", de: "Jede Mahlzeit wurde achtsam festgehalten.")
        case "happy_birthday": return l.tr(zh: "今天属于这个被爱着的小生命。", en: "Today belongs to this well-loved little life.", de: "Heute gehört diesem geliebten kleinen Leben.")
        case "hundred_days": return l.tr(zh: "一百天的小事，已经长成一段陪伴。", en: "A hundred small days have become companionship.", de: "Hundert kleine Tage wurden zu Begleitung.")
        case "first_record": return l.tr(zh: "第一条记录，是你们故事的起点。", en: "The first record is where the story begins.", de: "Der erste Eintrag ist der Anfang eurer Geschichte.")
        case "day_one_checkin": return l.tr(zh: "今天也被好好照顾到了。", en: "Today got its little act of care.", de: "Auch heute gab es diesen kleinen Moment Fürsorge.")
        case "old_friend": return l.tr(zh: "熟悉感，是每天都回来一次。", en: "Familiarity is coming back, day after day.", de: "Vertrautheit heißt, jeden Tag wiederzukommen.")
        case "long_runner": return l.tr(zh: "这一次，你们真的走了很远。", en: "This time, you really went the distance.", de: "Diesmal seid ihr wirklich weit gegangen.")
        case "medication_complete": return l.tr(zh: "坚持到最后，是温柔也可靠的照护。", en: "Finishing the course is care that follows through.", de: "Bis zum Ende dranzubleiben ist verlässliche Fürsorge.")
        case "photo_enthusiast": return l.tr(zh: "镜头里留下了好多被爱的瞬间。", en: "So many loved moments made it into the frame.", de: "So viele geliebte Momente blieben im Bild.")
        case "expense_tracker": return l.tr(zh: "爱也有账本，清楚一点更安心。", en: "Care has a ledger too, and clarity feels good.", de: "Auch Fürsorge hat ein kleines Kassenbuch.")
        case "weight_manager": return l.tr(zh: "变化被看见，身体就更容易被照顾。", en: "When change is visible, care gets easier.", de: "Wenn Veränderung sichtbar wird, wird Fürsorge leichter.")
        case "hydration_buddy": return l.tr(zh: "一碗清水，也是一件被放在心上的事。", en: "A fresh bowl of water is care in its simplest form.", de: "Eine frische Schale Wasser ist Fürsorge ganz schlicht.")
        case "play_champion": return l.tr(zh: "玩耍不是奖励，是关系本身。", en: "Play is not a bonus; it is part of the bond.", de: "Spiel ist kein Extra, sondern Teil der Bindung.")
        case "clean_keeper": return l.tr(zh: "干净舒适的角落，藏着很多认真。", en: "A clean corner holds a lot of quiet effort.", de: "Eine saubere Ecke trägt viel stille Mühe.")
        case "treat_scout": return l.tr(zh: "小零食有小快乐，也有认真记录。", en: "Tiny treats carry tiny joy and careful notes.", de: "Kleine Snacks tragen kleine Freude und gute Notizen.")
        case "food_kind_explorer": return l.tr(zh: "口味被照顾到，日子也更丰富。", en: "Different tastes make daily care richer.", de: "Unterschiedliche Vorlieben machen den Alltag reicher.")
        case "auto_feeder_pilot": return l.tr(zh: "自动喂养也被纳入了照护节奏。", en: "Automated feeding joined the care rhythm.", de: "Automatisches Füttern gehört nun zum Rhythmus.")
        case "stock_keeper": return l.tr(zh: "粮仓有余，心里就更稳。", en: "A stocked pantry makes care feel ready.", de: "Ein gefüllter Vorrat macht Fürsorge gelassen.")
        case "protection_ready": return l.tr(zh: "重要的保障，已经被妥善收好。", en: "The important safeguards are now in place.", de: "Wichtige Absicherung ist gut aufgehoben.")
        case "vaccine_keeper": return l.tr(zh: "健康本里，多了一份安心。", en: "The health record now carries more peace of mind.", de: "Im Gesundheitsheft steckt nun mehr Sicherheit.")
        case "symptom_watcher": return l.tr(zh: "异常被看见，本身就是一种保护。", en: "Noticing what is unusual is protection too.", de: "Auffälligkeiten zu bemerken ist auch Schutz.")
        case "care_streak_keeper": return l.tr(zh: "连续照护，把零散日常串成可靠节奏。", en: "Steady care turns scattered days into rhythm.", de: "Stete Fürsorge macht aus Tagen einen Rhythmus.")
        case "meal_archivist": return l.tr(zh: "餐桌上的习惯，正在被清楚记住。", en: "Mealtime habits are becoming clear records.", de: "Fütterungsgewohnheiten werden klar sichtbar.")
        case "water_guardian": return l.tr(zh: "清水被反复放好，照护也更稳定。", en: "Fresh water, repeated with care, keeps the routine steady.", de: "Frisches Wasser hält die Routine stabil.")
        case "memory_collector": return l.tr(zh: "相册越来越厚，陪伴也有了形状。", en: "The album grows, and companionship gains shape.", de: "Das Album wächst, Begleitung bekommt Form.")
        case "weight_rhythm": return l.tr(zh: "体重变化有了节奏，判断也更有底。", en: "Weight changes now have a visible rhythm.", de: "Gewichtsverläufe bekommen einen sichtbaren Rhythmus.")
        case "year_companion": return l.tr(zh: "一年同行，已经不是短暂相遇。", en: "A year together is no brief encounter.", de: "Ein Jahr zusammen ist keine kurze Begegnung.")
        case "global_island_crew": return l.tr(zh: "这不是一个人的岛，是一家人的小队。", en: "This island belongs to the whole crew.", de: "Diese Insel gehört der ganzen Crew.")
        case "global_first_critter": return l.tr(zh: "第一个 Oasis 伙伴醒来了。", en: "The first Oasis companion has awakened.", de: "Der erste Oasis-Begleiter ist erwacht.")
        case "global_legendary_critter": return l.tr(zh: "稀有的相遇，也被故事收下了。", en: "A rare meeting found its place in the story.", de: "Eine seltene Begegnung fand ihren Platz.")
        case "global_critter_collector": return l.tr(zh: "小伙伴越来越多，岛也更热闹了。", en: "More companions make the island feel alive.", de: "Mehr Begleiter machen die Insel lebendig.")
        case "global_critter_star": return l.tr(zh: "成长发光的时候，一眼就看得见。", en: "Growth has a way of shining through.", de: "Wachstum beginnt sichtbar zu leuchten.")
        case "global_critter_caretaker": return l.tr(zh: "轻轻互动，也会养出默契。", en: "Small interactions grow into familiarity.", de: "Kleine Interaktionen wachsen zu Vertrautheit.")
        case "global_first_blind_box": return l.tr(zh: "第一份惊喜，正式打开。", en: "The first surprise has officially opened.", de: "Die erste Überraschung ist geöffnet.")
        case "global_blind_box_collector": return l.tr(zh: "收藏架上，开始有了自己的宇宙。", en: "The collection shelf is becoming its own universe.", de: "Das Sammlerregal bekommt sein eigenes Universum.")
        case "global_secret_blind_box": return l.tr(zh: "隐藏款出现的瞬间，运气也有了形状。", en: "A secret pull gave luck a shape.", de: "Ein geheimer Fund gab dem Glück eine Form.")
        case "global_gacha_series_complete": return l.tr(zh: "一整个系列，被你完整收进故事里。", en: "A whole series now lives in your story.", de: "Eine ganze Serie lebt nun in deiner Geschichte.")
        case "global_gacha_jackpot": return l.tr(zh: "这一次，椰子像阳光一样落下来。", en: "This time, coconuts landed like sunlight.", de: "Diesmal fielen Kokosnüsse wie Sonnenlicht.")
        case "human_profile_ready": return l.tr(zh: "你的身份卡，让 Ohana 更懂边界和照顾。", en: "Your profile helps Ohana care with better context.", de: "Dein Profil hilft Ohana, achtsamer zu begleiten.")
        case "human_first_record": return l.tr(zh: "自己的第一条记录，也值得被纪念。", en: "Your first record deserves to be remembered too.", de: "Auch dein erster Eintrag verdient Erinnerung.")
        case "human_weight_starter": return l.tr(zh: "建立基线，是照顾自己的第一步。", en: "A baseline is a gentle first step in self-care.", de: "Eine Basislinie ist ein sanfter erster Schritt.")
        case "human_weight_keeper": return l.tr(zh: "趋势被看见，身体的声音就更清楚。", en: "Seeing the trend makes the body's signals clearer.", de: "Der Trend macht Körpersignale klarer.")
        case "human_expense_tracker": return l.tr(zh: "家庭里的花费，也开始有迹可循。", en: "Household spending now has a clearer trail.", de: "Familienausgaben werden nun nachvollziehbarer.")
        case "human_medication_setup": return l.tr(zh: "计划建好了，照顾就少一点慌张。", en: "With a plan in place, care feels calmer.", de: "Mit Plan fühlt sich Fürsorge ruhiger an.")
        case "human_medication_keeper": return l.tr(zh: "按时完成的小事，最能托住日常。", en: "Small on-time routines can hold the day together.", de: "Pünktliche kleine Routinen tragen den Alltag.")
        case "human_workout_starter": return l.tr(zh: "开始活动，就是身体收到的第一封回信。", en: "Starting to move is the body's first reply.", de: "Loszugehen ist die erste Antwort des Körpers.")
        case "human_workout_rhythm": return l.tr(zh: "运动有了节奏，生活也跟着顺起来。", en: "Once movement has rhythm, life follows more easily.", de: "Wenn Bewegung Rhythmus findet, folgt der Alltag.")
        case "human_workout_hero": return l.tr(zh: "运动记录堆起来，身体会给出答案。", en: "Movement records add up, and the body answers.", de: "Bewegung summiert sich, der Körper antwortet.")
        case "human_coconut_saver": return l.tr(zh: "一点点攒起来，也会变成看得见的底气。", en: "Saved bit by bit, confidence becomes visible.", de: "Stück für Stück wird Rückhalt sichtbar.")
        case "human_coconut_elite": return l.tr(zh: "稳定积累，本身也是一种掌控感。", en: "Steady saving is its own kind of control.", de: "Stetiges Sammeln gibt ein Gefühl von Kontrolle.")
        case "human_old_friend": return l.tr(zh: "你也和 Ohana 变熟了。", en: "You and Ohana have become familiar now.", de: "Du und Ohana seid vertrauter geworden.")
        case "human_year_friend": return l.tr(zh: "一年之后，Ohana 已经住进你的日常。", en: "After a year, Ohana has become part of your days.", de: "Nach einem Jahr gehört Ohana zu deinem Alltag.")
        default: return badge.description
        }
    }

    func achievementCompletionText(for badge: Achievement, state: AchievementRewardState) -> String {
        guard badge.isUnlocked else {
            return l.tr(zh: "尚未完成", en: "Not completed yet", de: "Noch nicht abgeschlossen")
        }

        if let date = achievementCompletionDate(for: badge) {
            let formatted = date.formatted(.dateTime.year().month().day())
            return l.tr(zh: "完成于 \(formatted)", en: "Completed \(formatted)", de: "Abgeschlossen \(formatted)")
        }

        return l.tr(zh: "已完成", en: "Completed", de: "Abgeschlossen")
    }
}
