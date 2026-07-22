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
                if let selectedCatalog {
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
                }
            }

            if selectedCatalog != nil {
                PlantCreationSection(
                    title: l.tr(zh: "名字", en: "Name", de: "Name"),
                    icon: "text.cursor"
                ) {
                    plantNameSummarySection
                }

                PlantCreationSection(
                    title: l.tr(zh: "摆放位置", en: "Placement", de: "Standort"),
                    icon: "house.fill"
                ) {
                    roomAndSpotControls
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
                    .font(OhanaFont.callout(.black))
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
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
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
                .font(OhanaFont.caption(.black))
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
                        .font(OhanaFont.callout(.black))
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
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(isSelected ? Color.goCardWhite : Color.ohanaTertiaryText)
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
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "先选择资料库里的相近植物，添加后可以在详情里继续改品种备注。",
                en: "Choose the closest catalog plant first; the species note can be edited later.",
                de: "Wähle zuerst den nächsten Katalogtreffer; die Artnotiz lässt sich später bearbeiten."
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
            l.tr(zh: "请选择植物后继续，房间可以现在补上。", en: "Choose a plant to continue; room can be added now.", de: "Wähle eine Pflanze, um fortzufahren; der Raum kann jetzt ergänzt werden."),
            systemImage: "info.circle.fill"
        )
        .font(OhanaFont.caption(.black))
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(Color.ohanaControlFill.opacity(0.42), in: Capsule())
        .accessibilityIdentifier("add-plant-step-requirement")
    }
}
