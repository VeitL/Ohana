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

            HStack(spacing: 8) {
                previewMetric(icon: "arrow.up.forward.circle.fill", text: levelText)
                previewMetric(icon: "bolt.fill", text: energyText)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(l.tr(
                    zh: "可先收藏", en: "Save for later", de: "Für später merken",
                    es: "Guardar para después", pt: "Salvar para depois", fr: "Enregistrer pour plus tard",
                    ja: "あとで使うため保存", ko: "나중을 위해 저장", it: "Salva per dopo"
                ))
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
            }

            Spacer(minLength: 8)
        }
    }

    private var levelText: String {
        l.tr(
            zh: "还差 \(levelsRemaining) 级",
            en: "\(levelsRemaining) levels left",
            de: "Noch \(levelsRemaining) Level",
            es: "Faltan \(levelsRemaining) niveles",
            pt: "Faltam \(levelsRemaining) níveis",
            fr: "Encore \(levelsRemaining) niveaux",
            ja: "あと\(levelsRemaining)レベル",
            ko: "\(levelsRemaining)레벨 남음",
            it: "Mancano \(levelsRemaining) livelli"
        )
    }

    private var energyText: String {
        l.tr(
            zh: "预计还差 \(energyRemaining) XP",
            en: "\(energyRemaining) XP to go",
            de: "Noch \(energyRemaining) XP",
            es: "Faltan \(energyRemaining) XP",
            pt: "Faltam \(energyRemaining) XP",
            fr: "Encore \(energyRemaining) XP",
            ja: "あと\(energyRemaining) XP",
            ko: "\(energyRemaining) XP 남음",
            it: "Mancano \(energyRemaining) XP"
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
        L10n(language).tr(
            zh: PlantUnlockPolicy.lockedTitleZh,
            en: "Plant care unlocks at Life Canopy Lv.4",
            de: "Pflanzenpflege ab Lebenskrone Lv.4",
            es: "El cuidado de plantas se desbloquea en Vida Lv.4",
            pt: "O cuidado de plantas desbloqueia no nível 4",
            fr: "Le soin des plantes se débloque au niveau 4",
            ja: "植物ケアは生命樹Lv.4で解放",
            ko: "식물 돌봄은 생명의 나무 Lv.4에서 잠금 해제",
            it: "La cura delle piante si sblocca al livello 4"
        )
    }
}
