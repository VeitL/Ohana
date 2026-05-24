//
//  CrewRosterExpandedMemberOverlay.swift
//  Ohana
//
//  Expanded member detail card for the Ohana roster.
//

import SwiftUI

struct CrewRosterExpandedMemberOverlay: View {
    let pet: Pet?
    let human: Human?
    let onClose: () -> Void
    let onOpenPet: (Pet) -> Void
    let onOpenHuman: (Human) -> Void

    @Namespace private var cardNamespace
    @Namespace private var heroNamespace
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            Color.arkInk.opacity(colorScheme == .dark ? 0.38 : 0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        if let pet {
                            petCard(pet)
                            petDetails(pet)
                            openButton(title: l.tr(zh: "打开首页卡片", en: "Open home card", de: "Startkarte öffnen")) {
                                onOpenPet(pet)
                            }
                        } else if let human {
                            humanCard(human)
                            humanDetails(human)
                            openButton(title: l.tr(zh: "打开首页卡片", en: "Open home card", de: "Startkarte öffnen")) {
                                onOpenHuman(human)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: pet == nil ? "person.fill" : "pawprint.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 36, height: 36)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(pet?.name ?? human?.name ?? l.tr(zh: "成员", en: "Member", de: "Mitglied"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.tr(zh: "基本信息", en: "Profile", de: "Profil"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                OhanaFeedback.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 40, height: 40)
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private func petCard(_ pet: Pet) -> some View {
        FocusWalletCardView(
            card: FocusCard.from(pet, includeAvatarData: true),
            namespace: cardNamespace,
            heroNS: heroNamespace,
            expandedId: pet.id,
            isHeroExpanded: true,
            heroProgress: 1,
            avatarCacheRevision: 0,
            usesMatchedGeometry: false
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityLabel(pet.name)
    }

    private func humanCard(_ human: Human) -> some View {
        FocusWalletCardView(
            card: FocusCard.from(human, includeAvatarData: true),
            namespace: cardNamespace,
            heroNS: heroNamespace,
            expandedId: human.id,
            isHeroExpanded: true,
            heroProgress: 1,
            avatarCacheRevision: 0,
            usesMatchedGeometry: false
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityLabel(human.name)
    }

    private func petDetails(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            metricStrip([
                .init(title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"), value: "\(pet.coconutBalance)", icon: "circle.hexagongrid.fill"),
                .init(title: l.tr(zh: "连击", en: "Streak", de: "Serie"), value: "\(pet.currentStreak)", icon: "flame.fill"),
                .init(title: l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), value: pet.hasPassedAway ? "\(pet.daysTogetherAtPassing)d" : "\(pet.daysTogether)d", icon: "heart.fill")
            ])

            detailGroup(
                title: l.tr(zh: "身份", en: "Identity", de: "Identität"),
                rows: [
                    .init(l.tr(zh: "物种", en: "Species", de: "Art"), pet.species.isEmpty ? l.tr(zh: "未填写", en: "Not set", de: "Nicht gesetzt") : pet.species, "pawprint.fill"),
                    .init(l.tr(zh: "品种", en: "Breed", de: "Rasse"), pet.breed.isEmpty ? l.tr(zh: "未填写", en: "Not set", de: "Nicht gesetzt") : pet.breed, "tag.fill"),
                    .init(l.tr(zh: "年龄", en: "Age", de: "Alter"), pet.hasPassedAway ? pet.ageAtPassingText : pet.ageText, "calendar"),
                    .init(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), petGenderText(pet), "person.fill")
                ]
            )

            detailGroup(
                title: l.tr(zh: "照护", en: "Care", de: "Pflege"),
                rows: [
                    .init(l.tr(zh: "到家", en: "Home date", de: "Zuhause seit"), formattedDate(pet.homeDate), "house.fill"),
                    .init(l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), formattedDate(pet.birthday), "gift.fill"),
                    .init(l.tr(zh: "主粮", en: "Main food", de: "Hauptfutter"), petFoodText(pet), "fork.knife"),
                    .init(l.tr(zh: "粮仓", en: "Stock", de: "Vorrat"), petStockText(pet), "shippingbox.fill"),
                    .init(l.tr(zh: "体重", en: "Weight", de: "Gewicht"), latestPetWeightText(pet), "scalemass.fill")
                ]
            )

            if !pet.vetClinicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !pet.microchipID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                detailGroup(
                    title: l.tr(zh: "保障", en: "Protection", de: "Schutz"),
                    rows: [
                        .init(l.tr(zh: "芯片", en: "Microchip", de: "Mikrochip"), emptyDash(pet.microchipID), "number"),
                        .init(l.tr(zh: "医院", en: "Clinic", de: "Praxis"), emptyDash(pet.vetClinicName), "cross.case.fill"),
                        .init(l.tr(zh: "证件", en: "Documents", de: "Dokumente"), "\(pet.documents.count)", "doc.text.fill")
                    ]
                )
            }
        }
    }

    private func humanDetails(_ human: Human) -> some View {
        let viewerId = UUID(uuidString: activeHumanIdStr)
        let weightText: String = {
            guard !human.isPrivate(.weight, viewedBy: viewerId) else {
                return l.tr(zh: "隐私", en: "Private", de: "Privat")
            }
            return latestHumanWeightText(human)
        }()

        return VStack(alignment: .leading, spacing: 12) {
            metricStrip([
                .init(title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"), value: "\(human.coconutBalance)", icon: "circle.hexagongrid.fill"),
                .init(title: l.tr(zh: "角色", en: "Role", de: "Rolle"), value: HumanPermissionRole.title(for: human.role), icon: HumanPermissionRole.icon(for: human.role)),
                .init(title: l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), value: "\(human.daysTogetherAtPassing)d", icon: "heart.fill")
            ])

            detailGroup(
                title: l.tr(zh: "身份", en: "Identity", de: "Identität"),
                rows: [
                    .init(l.tr(zh: "年龄", en: "Age", de: "Alter"), human.hasPassedAway ? human.ageAtPassingText : human.ageText, "calendar"),
                    .init(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), HumanGenderIdentity.title(for: human.genderRaw), "person.fill"),
                    .init(l.tr(zh: "血型", en: "Blood", de: "Blut"), emptyDash(human.bloodType), "drop.fill"),
                    .init("MBTI", emptyDash(human.mbti.uppercased()), "sparkles")
                ]
            )

            detailGroup(
                title: l.tr(zh: "身体", en: "Body", de: "Körper"),
                rows: [
                    .init(l.tr(zh: "身高", en: "Height", de: "Größe"), human.heightCm > 0 ? "\(Int(human.heightCm)) cm" : "—", "ruler.fill"),
                    .init(l.tr(zh: "体重", en: "Weight", de: "Gewicht"), weightText, "scalemass.fill"),
                    .init(l.tr(zh: "地区", en: "Region", de: "Region"), humanRegionText(human), "location.fill")
                ]
            )

            if !human.privateFields.isEmpty {
                detailGroup(
                    title: l.tr(zh: "隐私", en: "Privacy", de: "Privatsphäre"),
                    rows: [
                        .init(l.tr(zh: "隐藏项目", en: "Hidden fields", de: "Versteckte Felder"), "\(human.privateFields.count)", "lock.fill")
                    ]
                )
            }
        }
    }

    private func metricStrip(_ metrics: [RosterMetric]) -> some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                    Text(metric.value)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                    Text(metric.title)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func detailGroup(title: String, rows: [RosterInfoRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)

            VStack(spacing: 1) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.icon)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 22)

                        Text(row.title)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)

                        Spacer(minLength: 8)

                        Text(row.value)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(minHeight: 38)
                    .padding(.horizontal, 12)
                }
            }
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func openButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func emptyDash(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func petGenderText(_ pet: Pet) -> String {
        let base: String
        switch pet.gender {
        case "male": base = l.tr(zh: "男孩", en: "Male", de: "Männlich")
        case "female": base = l.tr(zh: "女孩", en: "Female", de: "Weiblich")
        default: base = l.tr(zh: "未填写", en: "Not set", de: "Nicht gesetzt")
        }
        return pet.isNeutered ? "\(base) · \(l.tr(zh: "已绝育", en: "neutered", de: "kastriert"))" : base
    }

    private func petFoodText(_ pet: Pet) -> String {
        let kind = pet.mainFoodKind == .wet
            ? l.tr(zh: "湿粮", en: "Wet", de: "Nass")
            : l.tr(zh: "干粮", en: "Dry", de: "Trocken")
        let grams = pet.dailyPortionGrams > 0 ? "\(Int(pet.dailyPortionGrams))g" : l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
        return "\(kind) · \(grams)"
    }

    private func petStockText(_ pet: Pet) -> String {
        let days = pet.remainingFoodDays
        guard days > 0 else { return l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") }
        return l.tr(zh: "约 \(days) 天", en: "About \(days)d", de: "Etwa \(days) T")
    }

    private func latestPetWeightText(_ pet: Pet) -> String {
        guard let latest = pet.weightLogs.max(by: { $0.date < $1.date }) else { return "—" }
        let kg = latest.weightInKg
        return kg >= 10 ? String(format: "%.1f kg", kg) : String(format: "%.2f kg", kg)
    }

    private func latestHumanWeightText(_ human: Human) -> String {
        guard let latest = human.weightLogs.max(by: { $0.date < $1.date }) else { return "—" }
        return String(format: "%.1f kg", latest.weight)
    }

    private func humanRegionText(_ human: Human) -> String {
        let parts = [human.city, human.nationality]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

private struct RosterMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

private struct RosterInfoRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String

    init(_ title: String, _ value: String, _ icon: String) {
        self.title = title
        self.value = value
        self.icon = icon
    }
}
