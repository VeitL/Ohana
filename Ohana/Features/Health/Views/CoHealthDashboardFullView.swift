//
//  CoHealthDashboardFullView.swift
//  Ohana
//
//  模块5：人宠共健仪表盘全屏页

import SwiftData
import SwiftUI

struct CoHealthDashboardFullContentView: View {
    let human: Human
    let snapshot: CoHealthDashboardSnapshot

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool {
        human.isPrivate(.weight, viewedBy: activeHumanId) || human.isPrivate(.workout, viewedBy: activeHumanId)
    }

    private var associatedPets: [CoHealthPetSnapshot] {
        snapshot.associatedPets(for: human.id, dogsOnly: false)
    }

    private var thisMonthWalkKm: Double {
        snapshot.thisMonthWalkKm(for: human.id, pets: associatedPets)
    }

    private var petWeightDelta: Double? {
        snapshot.petWeightDelta(for: associatedPets)
    }

    private var l: L10n { L10n(appLanguage) }

    private var summaryText: String {
        let petName = associatedPets.first?.name ?? l.tr(zh: "毛孩子", en: "your pets", de: "deine Tiere")
        let km = String(format: "%.1f", thisMonthWalkKm)
        if let delta = petWeightDelta {
            let amount = String(format: "%.1f", abs(delta))
            return delta < 0
                ? l.tr(zh: "本月你带 \(petName) 走了 \(km)km\n\(petName)瘦了 \(amount)kg 🎉", en: "You walked \(km) km with \(petName) this month\n\(petName) is down \(amount) kg 🎉", de: "Du bist diesen Monat \(km) km mit \(petName) gegangen\n\(petName) hat \(amount) kg abgenommen 🎉")
                : l.tr(zh: "本月你带 \(petName) 走了 \(km)km\n\(petName)胖了 \(amount)kg 🎉", en: "You walked \(km) km with \(petName) this month\n\(petName) is up \(amount) kg 🎉", de: "Du bist diesen Monat \(km) km mit \(petName) gegangen\n\(petName) hat \(amount) kg zugenommen 🎉")
        }
        return l.tr(zh: "本月你带 \(petName) 走了 \(km)km\n继续加油！💪", en: "You walked \(km) km with \(petName) this month\nKeep going! 💪", de: "Du bist diesen Monat \(km) km mit \(petName) gegangen\nWeiter so! 💪")
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 趣味文案卡
                        summaryCard
                            .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            HumanPrivateDataNotice(human: human, field: .workout)
                            HumanPrivateDataNotice(human: human, field: .weight)
                        }
                        .padding(.horizontal, 20)

                        // 遛狗历史柱状图
                        walkBarSection
                            .padding(.horizontal, 20)

                        // 体重对比折线图
                        weightCompareSection
                            .padding(.horizontal, 20)

                        // 宠物健康摘要
                        if !associatedPets.isEmpty {
                            petHealthSection
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle(l.tr(zh: "人宠共健", en: "Co-health", de: "Gemeinsame Gesundheit"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyLockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.metric(size: 44))
                .foregroundStyle(Color.goYellow)
            Text(l.tr(zh: "共健数据仅本人可见", en: "Co-health data is private", de: "Gemeinsame Gesundheitsdaten sind privat"))
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this profile to view it.", de: "Wechsle zu diesem Profil, um es zu sehen."))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HumanAvatarPipelineView(human: human, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(human.name + " × " + l.tr(zh: "毛孩子", en: "Pets", de: "Tiere"))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "人宠共健报告", en: "Co-health Report", de: "Gemeinsamer Gesundheitsbericht"))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                Spacer()
                Text("🏃").font(OhanaFont.adaptive(size: 36)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }

            Text(summaryText)
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .lineSpacing(4)
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    // MARK: - Walk Bar Section
    private var walkBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "🦮 遛狗里程（近7天）", en: "🦮 Walk Distance (7 Days)", de: "🦮 Gassi-Distanz (7 Tage)"))

            let data = last7DaysWalkData
            if data.allSatisfy({ $0.km == 0 }) {
                emptyLabel(l.tr(zh: "暂无遛狗记录", en: "No walk records yet", de: "Noch keine Spaziergänge"))
            } else {
                OhanaMinimalBarChart(
                    points: data.enumerated().map { index, pt in
                        OhanaMinimalChartPoint(
                            date: Date(timeIntervalSinceReferenceDate: Double(index) * 86400),
                            value: pt.km,
                            label: pt.label,
                            id: pt.id.uuidString
                        )
                    },
                    tint: Color.goPrimary,
                    showsLabels: true,
                    maxBarHeight: 92
                )
                .frame(height: 130)
            }
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    private var last7DaysWalkData: [CoHealthWalkDayPoint] {
        snapshot.last7DaysWalkData(for: human.id, pets: associatedPets)
    }

    // MARK: - Weight Compare Section
    private var weightCompareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l.tr(zh: "⚖️ 体重对比趋势", en: "⚖️ Weight Trend Comparison", de: "⚖️ Gewichtstrend-Vergleich"))
            CoHealthDashboardContentView(human: human, snapshot: snapshot)
                .allowsHitTesting(false)
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    // MARK: - Pet Health Section
    private var petHealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(l.tr(zh: "🐾 毛孩子健康摘要", en: "🐾 Pet Health Summary", de: "🐾 Gesundheitsübersicht der Tiere"))
            ForEach(associatedPets) { pet in
                HStack(spacing: 14) {
                    PetAvatarPortraitView(
                        cacheID: pet.id,
                        imageSignature: pet.avatarImageSignature,
                        petModelID: pet.petModelID,
                        fallbackText: pet.avatarEmoji,
                        themeColor: Color(hex: pet.themeColorHex),
                        size: 44,
                        backgroundOpacity: 0.18
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pet.name)
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        if let w = pet.latestWeightKg {
                            Text(l.tr(zh: "最新体重 \(String(format: "%.1f", w)) kg", en: "Latest weight \(String(format: "%.1f", w)) kg", de: "Letztes Gewicht \(String(format: "%.1f", w)) kg"))
                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        }
                    }
                    Spacer()
                    let monthWalk = snapshot.thisMonthWalkKm(for: human.id, pets: [pet])
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f km", monthWalk))
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                        Text(l.tr(zh: "本月同行", en: "Together this month", de: "Diesen Monat zusammen")).font(OhanaFont.adaptive(size: 9)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.3)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                }
            }
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    // MARK: - Helpers
    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText)
    }

    private func emptyLabel(_ t: String) -> some View {
        Text(t)
            .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
}
