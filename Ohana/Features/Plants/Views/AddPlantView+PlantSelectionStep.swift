//
//  AddPlantView+PlantSelectionStep.swift
//  Ohana
//
//  Step 1: choose plant, optional name, and room placement.
//

import SwiftUI
import UIKit

extension AddPlantView {
    var plantSelectionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            PlantCreationSection(
                title: l.tr(zh: "选择植物", en: "Choose plant", de: "Pflanze wählen"),
                icon: "leaf.fill"
            ) {
                if isUnknownSpeciesSelected {
                    Button {
                        isUnknownSpeciesSelected = false
                    } label: {
                        Label(l.tr(zh: "暂不确定品种 · 更换", en: "Species unknown · Change", de: "Art unbekannt · Ändern"), systemImage: "leaf")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("add-plant-change-unknown-species")
                } else if let selectedCatalog {
                    selectedPlantSummaryCard(selectedCatalog)
                } else {
                    plantCatalogSearchField
                    plantCatalogGroupScroller
                    if catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(selectedCatalogGroup.subtitle(l))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    plantSelectionCatalogList
                    Button {
                        selectedCatalogID = ""
                        species = ""
                        name = l.tr(zh: "我的植物", en: "My plant", de: "Meine Pflanze")
                        isUnknownSpeciesSelected = true
                        isCustomizingName = true
                        focusedField = nil
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(l.tr(zh: "暂不确定品种", en: "I am not sure of the species", de: "Art noch nicht bekannt"), systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("add-plant-unknown-species-action")
                }
            }

            if !canAdvanceStep {
                plantSelectionRequirementHint
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-plant-room")
        }
    }

    var plantCatalogSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 13, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)

            TextField(
                l.tr(
                    zh: "搜索绿萝、龟背竹…",
                    en: "Search pothos, Monstera...",
                    de: "Efeutute, Monstera suchen..."
                ),
                text: $catalogQuery
            )
            .textFieldStyle(.plain)
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityIdentifier("add-plant-catalog-search")

            if !catalogQuery.isEmpty {
                Button {
                    catalogQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 16, weight: .bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l.tr(zh: "清除搜索", en: "Clear search", de: "Suche löschen"))
                .accessibilityIdentifier("add-plant-catalog-search-clear")
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .frame(minHeight: 46)
        .background(Color.goCardWhite.opacity(0.54), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(Color.arkInk.opacity(0.08), lineWidth: 1)
        }
    }

    func selectedPlantSummaryCard(_ entry: PlantCatalogEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PlantCreationAvatarPreview(
                image: nil,
                catalog: entry,
                size: 54
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.localizedCommonName)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(entry.latinName)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(plantCatalogCareSummary(entry))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Spacer(minLength: 4)

            Button {
                clearSelectedPlantCatalog()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 44, height: 44)
                    .background(Color.goCardWhite.opacity(0.52), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "更换植物", en: "Change plant", de: "Pflanze ändern"))
            .accessibilityIdentifier("add-plant-change-catalog-action")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.goTeal.opacity(0.14),
            in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(Color.goTeal.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-plant-selected-catalog-summary")
    }

    var plantCatalogGroupScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlantCatalogBrowsingGroup.allCases) { group in
                    plantCreationCatalogGroupButton(group)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
    }

    func plantCreationCatalogGroupButton(_ group: PlantCatalogBrowsingGroup) -> some View {
        let isSelected = selectedCatalogGroup == group
        return Button {
            selectedCatalogGroup = group
            catalogQuery = ""
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(group.title(l))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(isSelected ? Color.goTeal : Color.ohanaSecondaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(
                    isSelected ? Color.goTeal.opacity(0.14) : Color.goCardWhite.opacity(0.42),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.goTeal.opacity(0.34) : Color.arkInk.opacity(0.06), lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(group.title(l))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-catalog-group-\(group.rawValue)")
    }

    @ViewBuilder
    var plantSelectionCatalogList: some View {
        if catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(groupedCatalogEntries) { entry in
                    plantSelectionCandidateButton(entry)
                }
            }
            .accessibilityElement(children: .contain)
        } else {
            VStack(spacing: 8) {
                if catalogMatches.isEmpty {
                    plantSelectionEmptySearchState
                } else {
                    ForEach(catalogMatches) { result in
                        plantSelectionCandidateButton(result.entry, matchSummary: result.matchSummary)
                    }
                }
            }
        }
    }

    func plantSelectionCandidateButton(
        _ entry: PlantCatalogEntry,
        matchSummary: String? = nil
    ) -> some View {
        let isSelected = selectedCatalogID == entry.id
        return Button {
            applyCatalog(entry)
        } label: {
            HStack(alignment: .center, spacing: 11) {
                PlantCreationAvatarPreview(
                    image: nil,
                    catalog: entry,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.localizedCommonName)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(entry.latinName)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text(matchSummary ?? plantCatalogCareSummary(entry))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark" : "chevron.right")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaTertiaryText)
                    .frame(width: 30, height: 30) // a11y: allow glyph sits inside the full-width row button
                    .background(isSelected ? Color.goTeal : Color.goCardWhite.opacity(0.48), in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.goTeal.opacity(0.15) : Color.goCardWhite.opacity(0.46),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.goTeal.opacity(0.36) : Color.arkInk.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName), \(entry.localizedCareDifficulty), \(entry.lightRequirement.displayName), \(entry.localizedHumidity)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-common-catalog-\(entry.id)")
    }

    func plantCatalogCareSummary(_ entry: PlantCatalogEntry) -> String {
        "\(entry.localizedCareDifficulty) · \(entry.lightRequirement.displayName) · \(entry.localizedHumidity)"
    }

    var plantSelectionEmptySearchState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.tr(zh: "没有找到匹配", en: "No match found", de: "Kein Treffer"))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "可以先用“暂不确定品种”建档。", en: "You can add it with an unknown species for now.", de: "Du kannst sie vorerst mit unbekannter Art anlegen.",
                es: "Puedes añadirla con la especie sin identificar.", pt: "Você pode adicioná-la sem identificar a espécie.", fr: "Vous pouvez l’ajouter sans identifier l’espèce.",
                ja: "品種未確定のまま追加できます。", ko: "품종을 몰라도 추가할 수 있어요.", it: "Puoi aggiungerla senza identificare la specie."
            ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    var roomAndSpotControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            OhanaChoiceChipRow(
                title: l.tr(zh: "房间", en: "Room", de: "Raum"),
                options: commonRoomOptions,
                selection: $roomName,
                identifierPrefix: "add-plant-room-choice"
            )

            if showingCustomRoomField || usesCustomRoomEntry {
                inlineFormField(
                    l.tr(zh: "自定义房间", en: "Custom room", de: "Eigener Raum"),
                    text: $roomName,
                    placeholder: l.tr(zh: "客厅、阳台…", en: "Living room, balcony...", de: "Wohnzimmer, Balkon..."),
                    identifier: "add-plant-room-input",
                    focusField: .room,
                    submitLabel: .next
                )
            } else {
                customInlineEntryButton(
                    title: l.tr(zh: "自定义房间", en: "Custom room", de: "Eigener Raum"),
                    identifier: "add-plant-room-custom-toggle"
                ) {
                    revealCustomRoomField()
                }
            }

            OhanaChoiceChipRow(
                title: l.tr(zh: "具体位置", en: "Exact spot", de: "Genauer Standort"),
                options: commonSpotOptions,
                selection: $location,
                identifierPrefix: "add-plant-location-choice"
            )

            if showingCustomLocationField || usesCustomLocationEntry {
                inlineFormField(
                    l.tr(zh: "自定义位置", en: "Custom spot", de: "Eigener Standort"),
                    text: $location,
                    placeholder: l.tr(zh: "南窗边、书桌、花架…", en: "South window, desk, plant stand...", de: "Südfenster, Schreibtisch, Pflanzenregal..."),
                    identifier: "add-plant-location-input",
                    focusField: .location,
                    submitLabel: .done
                )
            } else {
                customInlineEntryButton(
                    title: l.tr(zh: "自定义位置", en: "Custom spot", de: "Eigener Standort"),
                    identifier: "add-plant-location-custom-toggle"
                ) {
                    revealCustomLocationField()
                }
            }
        }
    }

    var plantSelectionRequirementHint: some View {
        Label(
            l.tr(zh: "选择品种，或先以未知品种建档。", en: "Choose a species, or add it without one for now.", de: "Wähle eine Art oder lege die Pflanze zunächst ohne Art an."),
            systemImage: "info.circle.fill"
        )
        .font(OhanaFont.caption(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(Color.ohanaControlFill.opacity(0.42), in: Capsule())
        .accessibilityIdentifier("add-plant-step-requirement")
    }
}
