//
//  PetRetentionHubView.swift
//  Ohana
//
//  V4 growth archive dashboard for one pet.
//

import SwiftUI

struct PetRetentionHubView: View {
    let pet: Pet
    var showsCloseButton: Bool = false

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var isRenderingPDF = false
    @State private var pdfShare: PetArchivePDFShare?

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var archiveSnapshot: ArchiveMemorySnapshot { ArchiveMemorySnapshot(pet: pet) }
    private var screenModel: PetRetentionHubScreenModel { PetRetentionHubScreenModel(pet: pet) }

    private var latestWeightText: String {
        guard let latest = pet.weightLogs.sorted(by: { $0.date < $1.date }).last else {
            return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")
        }
        return String(format: "%.1fkg", latest.weight)
    }

    private var healthBaselineText: String {
        if !pet.weightLogs.isEmpty { return latestWeightText }
        if !pet.healthLogs.isEmpty {
            return l.tr(zh: "\(pet.healthLogs.count) 条健康记录", en: "\(pet.healthLogs.count) health logs", de: "\(pet.healthLogs.count) Gesundheitsdaten")
        }
        return l.tr(zh: "缺少健康基线", en: "Missing baseline", de: "Basis fehlt")
    }

    private var memoryCount: Int { pet.photoLogs.count + pet.milestones.count }
    private var protectionCount: Int { pet.documents.count + pet.insurances.count }

    private var expiringProtectionCount: Int {
        let expiringDocs = pet.documents.count(where: { $0.isExpired || $0.isExpiringSoon })
        let expiringInsurances = pet.insurances.count(where: { $0.daysUntilRenewal <= 30 })
        return expiringDocs + expiringInsurances
    }

    private var protectionStatus: String {
        if expiringProtectionCount > 0 {
            return l.tr(zh: "\(expiringProtectionCount) 项需关注", en: "\(expiringProtectionCount) needs attention", de: "\(expiringProtectionCount) prüfen")
        }
        if protectionCount > 0 {
            return l.tr(zh: "保障资料正常", en: "Coverage looks good", de: "Schutz ist aktuell")
        }
        return l.tr(zh: "还没有证件", en: "No documents yet", de: "Noch keine Dokumente")
    }

    private var recentMemoryText: String {
        let latestPhoto = pet.photoLogs.sorted { $0.date > $1.date }.first?.date
        let latestMilestone = pet.milestones.sorted { $0.date > $1.date }.first?.date
        guard let latest = [latestPhoto, latestMilestone].compactMap(\.self).max() else {
            return l.tr(zh: "还没有回忆", en: "No memories yet", de: "Noch keine Erinnerungen")
        }
        return latest.formatted(.relative(presentation: .named))
    }

    private var profileStatus: String {
        if archiveSnapshot.score >= archiveSnapshot.total {
            return l.tr(zh: "档案完整", en: "Complete", de: "Vollständig")
        }
        return l.tr(zh: "还差 \(archiveSnapshot.total - archiveSnapshot.score) 项", en: "\(archiveSnapshot.total - archiveSnapshot.score) left", de: "\(archiveSnapshot.total - archiveSnapshot.score) offen")
    }

    private var achievementProgress: (unlocked: Int, total: Int) {
        screenModel.achievementProgress
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if pet.hasPassedAway {
                            memorialSummary
                        }

                        archiveOverview
                        nextStepCard

                        sectionTitle(l.tr(zh: "核心档案", en: "Core archive", de: "Kernarchiv"))
                        coreArchiveCards

                        sectionTitle(l.tr(zh: "更多", en: "More", de: "Mehr"))
                        secondaryActions
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $pdfShare) { share in
                PetVetPDFShareSheet(pdfURL: share.url, pet: pet)
                    // ui-v4: allow PDF share uses document preview sheet
                    .presentationBackground(.clear)
            }
        }
        .petMemorialTone(isActive: pet.hasPassedAway)
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: pet.avatarImageData,
                emoji: pet.avatarEmoji,
                fallback: pet.speciesEmoji,
                tint: themeColor
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "成长档案", en: "Growth Archive", de: "Entwicklungsarchiv"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text("\(pet.name) · \(profileStatus)")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if showsCloseButton {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
    }

    private var archiveOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("\(archiveSnapshot.score)/\(archiveSnapshot.total)")
                    .font(OhanaFont.adaptive(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion("\(archiveSnapshot.score)")
                Text(l.tr(zh: "档案完整度", en: "archive complete", de: "Archiv komplett"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
            }

            ProgressView(value: Double(archiveSnapshot.score), total: Double(archiveSnapshot.total))
                .tint(Color.goPrimary)

            HStack(spacing: 16) {
                metric(title: l.tr(zh: "回忆", en: "Memories", de: "Erinnerungen"), value: "\(memoryCount)")
                metric(title: l.tr(zh: "保障", en: "Protection", de: "Schutz"), value: "\(protectionCount)")
                metric(title: l.tr(zh: "健康基线", en: "Baseline", de: "Basis"), value: healthBaselineText)
            }
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextStepCard: some View {
        NavigationLink(destination: nextStepDestination(archiveSnapshot.nextStep.kind)) {
            HStack(spacing: 12) {
                Image(systemName: archiveSnapshot.nextStep.icon)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(archiveSnapshot.nextStep.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(archiveSnapshot.nextStep.subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var coreArchiveCards: some View {
        VStack(spacing: 10) {
            archiveNavigationCard(
                icon: "person.text.rectangle.fill",
                accent: Color(hex: "6B82C4"),
                title: l.tr(zh: "身份资料", en: "Profile", de: "Profil"),
                value: pet.breed.isEmpty ? pet.species : pet.breed,
                subtitle: l.tr(zh: "名字、品种、生日、到家日", en: "Name, breed, birthday, home day", de: "Name, Rasse, Geburtstag, Einzug"),
                destination: PetBasicInfoDetailView(pet: pet)
            )

            archiveNavigationCard(
                icon: "photo.on.rectangle.angled",
                accent: Color(hex: "EC4899"),
                title: l.tr(zh: "成长回忆", en: "Memories", de: "Erinnerungen"),
                value: "\(memoryCount)",
                subtitle: l.tr(zh: "最近：\(recentMemoryText)", en: "Latest: \(recentMemoryText)", de: "Zuletzt: \(recentMemoryText)"),
                destination: PetMomentsHubRouteContainer(pet: pet)
            )

            archiveNavigationCard(
                icon: "doc.text.fill",
                accent: Color(hex: "94A3B8"),
                title: l.tr(zh: "保障文件", en: "Documents", de: "Dokumente"),
                value: "\(protectionCount)",
                subtitle: protectionStatus,
                destination: DocumentsListView(pet: pet)
            )
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                compactNavigationAction(
                    icon: "clock.arrow.circlepath",
                    title: l.tr(zh: "记录中心 · 全部", en: "Moments · All", de: "Momente · Alle"),
                    value: "\(timelineCount)",
                    tint: Color(hex: "8B5CF6"),
                    destination: PetMomentsHubRouteContainer(pet: pet)
                )

                compactNavigationAction(
                    icon: "trophy.fill",
                    title: l.tr(zh: "成就墙", en: "Awards", de: "Erfolge"),
                    value: "\(achievementProgress.unlocked)/\(achievementProgress.total)",
                    tint: Color(hex: "F59E0B"),
                    destination: AchievementWallView(pet: pet)
                )
            }

            Button { renderPDF() } label: {
                HStack(spacing: 12) {
                    Image(systemName: isRenderingPDF ? "hourglass" : "square.and.arrow.up.fill")
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "导出兽医档案", en: "Export Vet File", de: "Tierarztakte exportieren"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "PDF · 体重、健康、用药、证件", en: "PDF · weight, health, meds, documents", de: "PDF · Gewicht, Gesundheit, Medikamente, Dokumente"))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isRenderingPDF {
                        ProgressView()
                            .tint(Color.goPrimary)
                    } else {
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
            }
            .disabled(isRenderingPDF)
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var memorialSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(l.tr(zh: "纪念档案", en: "Memorial archive", de: "Gedenkarchiv"), systemImage: "sparkles")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(memorialDetail)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memorialDetail: String {
        let days = pet.daysTogetherAtPassing
        if let date = pet.passedAwayDate {
            return l.tr(
                zh: "离世 \(date.formatted(.dateTime.year().month().day())) · 相伴 \(days) 天 · 保留照片、故事和证件",
                en: "Passed \(date.formatted(.dateTime.year().month().day())) · \(days) days together · photos, stories, and documents remain",
                de: "Verstorben am \(date.formatted(.dateTime.year().month().day())) · \(days) Tage zusammen · Fotos, Geschichten und Dokumente bleiben"
            )
        }
        return l.tr(
            zh: "相伴 \(days) 天 · 保留照片、故事和证件",
            en: "\(days) days together · photos, stories, and documents remain",
            de: "\(days) Tage zusammen · Fotos, Geschichten und Dokumente bleiben"
        )
    }

    private var timelineCount: Int {
        pet.photoLogs.count + pet.milestones.count + pet.healthLogs.count + pet.weightLogs.count + pet.careLogs.count + pet.walkLogs.count
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.horizontal, 2)
    }

    private func archiveNavigationCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        subtitle: String,
        destination: some View
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(value.isEmpty ? "--" : value)
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(accent)
                    }
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func compactNavigationAction(
        icon: String,
        title: String,
        value: String,
        tint: Color,
        destination: some View
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(tint)
                    Spacer()
                    Text(value)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func nextStepDestination(_ kind: ArchiveMemoryNextStepKind) -> some View {
        switch kind {
        case .basicInfo:
            PetBasicInfoDetailView(pet: pet)
        case .documents:
            DocumentsListView(pet: pet)
        case .moments:
            PetMomentsHubRouteContainer(pet: pet)
        case .weight:
            WeightHistoryView(pet: pet)
        case .retention:
            PetMomentsHubRouteContainer(pet: pet)
        }
    }

    private func renderPDF() {
        guard !isRenderingPDF else { return }
        isRenderingPDF = true
        Task {
            let url = await PetVetSummaryPDFRenderer.render(pet: pet)
            await MainActor.run {
                isRenderingPDF = false
                if let url {
                    pdfShare = PetArchivePDFShare(url: url)
                }
            }
        }
    }
}

private struct PetArchivePDFShare: Identifiable {
    let id = UUID()
    let url: URL
}
