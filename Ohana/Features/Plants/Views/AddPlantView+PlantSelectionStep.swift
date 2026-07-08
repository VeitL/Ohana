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
        VStack(alignment: .leading, spacing: 16) {
            PlantCreationSection(
                title: l.tr(zh: "选择植物", en: "Choose plant", de: "Pflanze wählen"),
                icon: "leaf.fill"
            ) {
                if let selectedCatalog {
                    selectedPlantSummaryCard(selectedCatalog)
                } else {
                    plantCatalogGroupScroller
                    Text(selectedCatalogGroup.subtitle(l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    plantSelectionCatalogList
                    catalogSearchField
                }
            }

            PlantCreationSection(
                title: l.tr(zh: "名字", en: "Name", de: "Name"),
                icon: "text.cursor"
            ) {
                plantNameSummarySection
            }

            PlantCreationSection(
                title: l.tr(zh: "房间信息", en: "Room info", de: "Rauminfo"),
                icon: "house.fill"
            ) {
                roomAndSpotControls
            }

            if !canAdvanceStep {
                plantSelectionRequirementHint
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-plant-room")
        }
    }

    func selectedPlantSummaryCard(_ entry: PlantCatalogEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PlantCreationAvatarPreview(
                image: nil,
                catalog: entry,
                size: 54
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.localizedCommonName)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(entry.latinName)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                HStack(spacing: 5) {
                    PlantCreationMetricPill(
                        icon: "speedometer",
                        title: entry.localizedCareDifficulty
                    )
                    PlantCreationMetricPill(
                        icon: "sun.max.fill",
                        title: entry.lightRequirement.displayName
                    )
                    PlantCreationMetricPill(
                        icon: "humidity.fill",
                        title: entry.localizedHumidity
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 4)

            Button {
                clearSelectedPlantCatalog()
            } label: {
                Text(l.tr(zh: "更换", en: "Change", de: "Ändern"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(minWidth: 56, minHeight: 44)
                    .background(Color.ohanaControlFill.opacity(0.66), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("add-plant-change-catalog-action")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.goPrimary.opacity(0.90),
            in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-plant-selected-catalog-summary")
    }

    var plantCatalogGroupScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlantCatalogBrowsingGroup.allCases) { group in
                    catalogGroupButton(group)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
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
            HStack(alignment: .center, spacing: 12) {
                PlantCreationAvatarPreview(
                    image: nil,
                    catalog: entry,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.localizedCommonName)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(entry.latinName)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.arkInk.opacity(0.62) : Color.ohanaTertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }

                    HStack(spacing: 5) {
                        PlantCreationMetricPill(
                            icon: "speedometer",
                            title: entry.localizedCareDifficulty,
                            isSelected: isSelected
                        )
                        PlantCreationMetricPill(
                            icon: "sun.max.fill",
                            title: entry.lightRequirement.displayName,
                            isSelected: isSelected
                        )
                        PlantCreationMetricPill(
                            icon: "humidity.fill",
                            title: entry.localizedHumidity,
                            isSelected: isSelected
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let matchSummary {
                        Text(matchSummary)
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.arkInk.opacity(0.70) : Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }

                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.58),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.goPrimary.opacity(0.42) : Color.ohanaCardSurface.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName), \(entry.localizedCareDifficulty), \(entry.lightRequirement.displayName), \(entry.localizedHumidity)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-common-catalog-\(entry.id)")
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
