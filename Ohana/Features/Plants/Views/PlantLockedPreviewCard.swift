import SwiftUI

struct PlantLockedPreviewCard: View {
    let currentLevel: Int
    let currentEnergy: Int
    let appLanguage: String

    @State private var favoriteIDs: Set<String> = []

    private var l: L10n { L10n(appLanguage) }
    private var levelsRemaining: Int {
        PlantLockedPreviewPolicy.levelsRemaining(currentLevel: currentLevel)
    }

    private var energyRemaining: Int {
        PlantLockedPreviewPolicy.energyRemainingForUnlock(currentEnergy: currentEnergy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header

            Text(PlantUnlockCopy.lockedDetail(language: appLanguage))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                previewMetric(icon: "arrow.up.forward.circle.fill", text: levelText)
                previewMetric(icon: "bolt.fill", text: energyText)
            }

            VStack(alignment: .leading, spacing: 8) {
                expectationRow(
                    icon: "bookmark.fill",
                    text: l.tr(
                        zh: "现在可以先收藏植物资料；Lv.4 后再一键建档。",
                        en: "Save catalog plants now; create profiles after Lv.4.",
                        de: "Pflanzen jetzt merken; Profile nach Lv.4 anlegen."
                    )
                )
                expectationRow(
                    icon: "bell.slash.fill",
                    text: l.tr(
                        zh: "锁定期间不会生成浇水、施肥或复查提醒。",
                        en: "No watering, fertilizing, or follow-up reminders are created while locked.",
                        de: "Solange gesperrt, entstehen keine Giess-, Duenge- oder Nachfass-Erinnerungen."
                    )
                )
            }

            Divider()
                .overlay(Color.ohanaDivider.opacity(0.7))

            VStack(alignment: .leading, spacing: 9) {
                Text(l.tr(zh: "可先收藏的资料", en: "Catalog to save now", de: "Katalog zum Merken"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                ForEach(PlantCatalog.entries.prefix(3)) { entry in
                    PlantLockedPreviewCatalogRow(
                        entry: entry,
                        isFavorite: favoriteIDs.contains(entry.id),
                        appLanguage: appLanguage
                    ) {
                        toggleFavorite(entry.id)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .onAppear {
            favoriteIDs = PlantCatalogFavoriteStore.favoriteIDs()
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "leaf.fill") // a11y: allow decorative locked-preview glyph; card title owns the label.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; parent card text carries meaning.
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(PlantUnlockCopy.lockedTitle(language: appLanguage))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l.tr(
                    zh: "植物会进入 Ohana，但要等宠物核心照护习惯稳定后再开始。",
                    en: "Plants are part of Ohana, but they start after core pet care is steady.",
                    de: "Pflanzen gehoeren zu Ohana, starten aber nach stabiler Haustierpflege."
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
    }

    private var levelText: String {
        l.tr(
            zh: "还差 \(levelsRemaining) 级",
            en: "\(levelsRemaining) levels left",
            de: "Noch \(levelsRemaining) Level"
        )
    }

    private var energyText: String {
        l.tr(
            zh: "预计还差 \(energyRemaining) XP",
            en: "\(energyRemaining) XP to go",
            de: "Noch \(energyRemaining) XP"
        )
    }

    private func previewMetric(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.ohanaControlFill, in: Capsule())
    }

    private func expectationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 20, height: 20) // a11y: allow decorative non-interactive checklist glyph; row text carries meaning.
            Text(text)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleFavorite(_ id: String) {
        PlantCatalogFavoriteStore.toggleFavorite(id: id)
        favoriteIDs = PlantCatalogFavoriteStore.favoriteIDs()
        OhanaFeedback.light()
    }
}

private struct PlantLockedPreviewCatalogRow: View {
    let entry: PlantCatalogEntry
    let isFavorite: Bool
    let appLanguage: String
    let onToggleFavorite: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.isIndoorSuitable ? "house.fill" : "sun.max.fill") // a11y: allow decorative catalog glyph; row text carries meaning.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; bookmark is the only row control.
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.localizedCommonName) · \(entry.localizedCareDifficulty)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(entry.latinName)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(isFavorite ? Color.goPrimary : Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(favoriteLabel)
        }
        .padding(.vertical, 2)
    }

    private var favoriteLabel: String {
        if isFavorite {
            return l.tr(zh: "取消收藏 \(entry.localizedCommonName)", en: "Unsave \(entry.localizedCommonName)", de: "\(entry.localizedCommonName) nicht mehr merken")
        }
        return l.tr(zh: "收藏 \(entry.localizedCommonName)", en: "Save \(entry.localizedCommonName)", de: "\(entry.localizedCommonName) merken")
    }
}

enum PlantUnlockCopy {
    static func lockedTitle(language: String) -> String {
        switch language {
        case "en":
            "Plant care unlocks at Life Canopy Lv.4"
        case "de":
            "Pflanzenpflege ab Lebenskrone Lv.4"
        default:
            PlantUnlockPolicy.lockedTitleZh
        }
    }

    static func lockedDetail(language: String) -> String {
        switch language {
        case "en":
            "Build core pet-care habits first; once the island is steady, plants can move into Ohana too."
        case "de":
            "Baue zuerst die Kernroutine fuer Haustiere auf; wenn die Insel stabil ist, ziehen Pflanzen auch in Ohana ein."
        default:
            PlantUnlockPolicy.lockedDetailZh
        }
    }
}
