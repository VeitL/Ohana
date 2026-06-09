//
//  FamilyCollaborationPlaygroundView.swift
//  Ohana
//
//  Developer-only fixture playground for testing family collaboration concepts.
//

import SwiftUI

struct FamilyCollaborationPlaygroundView: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case board
        case map
        case race

        var id: String { rawValue }
    }

    private enum PreviewMode: String, CaseIterable, Identifiable {
        case dark
        case light

        var id: String { rawValue }
        var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    }

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var scenario: Scenario = .board
    @State private var previewMode: PreviewMode = .dark
    @State private var completedSlots: Set<String> = []
    @State private var selectedPetID = "lilo"
    @State private var boostedMemberID = "mama"

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    previewSwitch
                    scenarioPicker
                    previewSurface
                    designNotes
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(l.tr(zh: "协作体验测试", en: "Collab Playground", de: "Zusammenarbeit testen"))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(previewMode.colorScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l.tr(zh: "家庭协作实验台", en: "Family collaboration lab", de: "Familien-Labor"))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "这里全是假数据，用来比较协作页的真实手感。",
                en: "Fixture data only, for comparing collaboration layouts.",
                de: "Nur Beispieldaten, um Layouts zu vergleichen."
            ))
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private var previewSwitch: some View {
        HStack(spacing: 8) {
            ForEach(PreviewMode.allCases) { mode in
                Button {
                    withAnimation(GoMotion.feedback) { previewMode = mode }
                } label: {
                    Text(mode == .dark ? l.tr(zh: "深色", en: "Dark", de: "Dunkel") : l.tr(zh: "浅色", en: "Light", de: "Hell"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(previewMode == mode ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(previewMode == mode ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var scenarioPicker: some View {
        HStack(spacing: 8) {
            scenarioButton(.board, icon: "gamecontroller.fill", title: l.tr(zh: "任务盘", en: "Board", de: "Brett"))
            scenarioButton(.map, icon: "map.fill", title: l.tr(zh: "宠物地图", en: "Map", de: "Karte"))
            scenarioButton(.race, icon: "flag.checkered", title: l.tr(zh: "家人竞赛", en: "Race", de: "Rennen"))
        }
    }

    private func scenarioButton(_ value: Scenario, icon: String, title: String) -> some View {
        let selected = scenario == value
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.page) { scenario = value }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var previewSurface: some View {
        switch scenario {
        case .board:
            boardPreview
        case .map:
            mapPreview
        case .race:
            racePreview
        }
    }

    private var boardPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressHeader(title: l.tr(zh: "今日任务盘", en: "Today board", de: "Tagesbrett"), progress: Double(completedSlots.count) / 3)
            boardSlot(id: "mine", icon: "person.crop.circle.badge.clock", tint: Color.goPurple, title: l.tr(zh: "待我", en: "Mine", de: "Meine"), subtitle: l.tr(zh: "Lilo 18:30 喂食", en: "Lilo feed at 18:30", de: "Lilo 18:30 füttern"))
            boardSlot(id: "gap", icon: "pawprint.fill", tint: Color.goYellow, title: l.tr(zh: "缺口", en: "Gap", de: "Lücke"), subtitle: l.tr(zh: "Momo 还没陪玩", en: "Momo still needs play", de: "Momo braucht Spielzeit"))
            boardSlot(id: "bounty", icon: "target", tint: Color.goTeal, title: l.tr(zh: "悬赏", en: "Bounty", de: "Prämie"), subtitle: l.tr(zh: "+20🥥 清理猫砂", en: "+20🥥 clean litter", de: "+20🥥 Katzenklo"))
        }
    }

    private func boardSlot(id: String, icon: String, tint: Color, title: String, subtitle: String) -> some View {
        let done = completedSlots.contains(id)
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(GoMotion.feedback) {
                if done {
                    completedSlots.remove(id)
                } else {
                    completedSlots.insert(id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.seal.fill" : icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(done ? l.tr(zh: "已完成", en: "Done", de: "Fertig") : subtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text(done ? "OK" : l.tr(zh: "点按", en: "Tap", de: "Tippen"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.goPrimary, in: Capsule())
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressHeader(title: l.tr(zh: "宠物地图", en: "Pet map", de: "Tierkarte"), progress: 0.64)
            ZStack {
                Circle()
                    .stroke(Color.ohanaCardStroke, lineWidth: 1)
                    .frame(height: 238)
                petNode(id: "lilo", emoji: "🐱", name: "Lilo", badge: "2", x: -92, y: -54, tint: Color.goYellow)
                petNode(id: "momo", emoji: "🐶", name: "Momo", badge: "1", x: 88, y: -18, tint: Color.goPurple)
                petNode(id: "rio", emoji: "🐟", name: "Rio", badge: "✓", x: -20, y: 82, tint: Color.goTeal)
                VStack(spacing: 3) {
                    Image(systemName: "house.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 24, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                    Text(l.tr(zh: "家", en: "Home", de: "Zuhause"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            selectedPetInfo
        }
    }

    private func petNode(id: String, emoji: String, name: String, badge: String, x: CGFloat, y: CGFloat, tint: Color) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.feedback) { selectedPetID = id }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(emoji)
                        .font(OhanaFont.adaptive(size: 34))
                        .frame(width: 68, height: 68)
                        .background(selectedPetID == id ? tint.opacity(0.24) : Color.ohanaCardSurface, in: Circle())
                        .overlay(Circle().strokeBorder(selectedPetID == id ? tint : Color.ohanaCardStroke, lineWidth: selectedPetID == id ? 2 : 1))
                    Text(badge)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 22, height: 22) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .background(tint, in: Circle())
                        .offset(x: 2, y: -2)
                }
                Text(name)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .offset(x: x, y: y)
    }

    private var selectedPetInfo: some View {
        let label: String = {
            switch selectedPetID {
            case "lilo": return l.tr(zh: "Lilo 需要喂食和铲屎", en: "Lilo needs feed and litter", de: "Lilo braucht Futter und Klo")
            case "momo": return l.tr(zh: "Momo 需要陪玩", en: "Momo needs play", de: "Momo braucht Spiel")
            default: return l.tr(zh: "Rio 今日已完成", en: "Rio is covered today", de: "Rio ist heute erledigt")
            }
        }()
        return HStack(spacing: 10) {
            Image(systemName: "sparkles").accessibilityHidden(true)
                .foregroundStyle(Color.goPrimary)
            Text(label)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var racePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressHeader(title: l.tr(zh: "家人竞赛", en: "Family race", de: "Familienrennen"), progress: 0.72)
            raceRow(id: "mama", emoji: "👩", name: "Mia", score: boostedMemberID == "mama" ? 86 : 72, tint: Color.goPurple)
            raceRow(id: "baba", emoji: "🧑", name: "Ben", score: boostedMemberID == "baba" ? 82 : 66, tint: Color.goTeal)
            raceRow(id: "kid", emoji: "🧒", name: "Noa", score: boostedMemberID == "kid" ? 78 : 58, tint: Color.goYellow)
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").accessibilityHidden(true)
                    .foregroundStyle(Color.goOrange)
                Text(l.tr(zh: "连击、悬赏和今日完成数会一起推动排名。", en: "Streaks, bounties, and check-ins drive rank.", de: "Serien, Prämien und Check-ins bestimmen den Rang."))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func raceRow(id: String, emoji: String, name: String, score: Int, tint: Color) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.feedback) { boostedMemberID = id }
        } label: {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(OhanaFont.adaptive(size: 28))
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text("\(score)")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(tint)
                            .monospacedDigit()
                    }
                    ProgressView(value: Double(score), total: 100)
                        .tint(tint)
                }
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func progressHeader(title: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(OhanaFont.metric(size: 24, .black))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, proxy.size.width * progress))
                }
            }
            .frame(height: 10)
        }
    }

    private var designNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(l.tr(zh: "测试页不会读取或修改真实数据", en: "This page does not read or mutate real data", de: "Diese Seite liest oder ändert keine echten Daten"), systemImage: "checkmark.shield.fill")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Label(l.tr(zh: "选定方向后再合并到真实 Ohana 成员页", en: "Pick a direction before merging into the real member page", de: "Erst auswählen, dann in die echte Mitgliederseite übernehmen"), systemImage: "wand.and.stars")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(.top, 2)
    }
}

