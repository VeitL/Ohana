//
//  AddPlantView.swift
//  Ohana
//
//  GO UI：由 `AddEntityView` 提供 `GoIslandWizardBackdrop`，本页使用岛景上的玻璃卡与自适应主色强调。
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddPlantView: View {
    let onComplete: () -> Void
    var onPlantSaved: ((UUID) -> Void)?
    let existingPlantSnapshots: [PlantDuplicateScanSnapshot]
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @StateObject var media = MemberAvatarMediaCoordinator()
    @State var currentStep: AddPlantCreationStep = .plant
    @State var name = ""
    @State var isCustomizingName = false
    @State var species = ""
    @State var roomName = ""
    @State var location = ""
    @State var avatarEmoji = "🌱"
    @State var avatarImageData: Data?
    @State var decodedAvatarImage: UIImage?
    @State var selectedAvatarSource: PlantCreationAvatarSource = .builtIn
    @State var catalogQuery = ""
    @State var selectedCatalogID = ""
    @State var selectedCatalogGroup: PlantCatalogBrowsingGroup = .recommended
    @State var wateringInterval = 7
    @State var fertilizingInterval = 30
    @State var potDiameterCm = 0.0
    @State var potMaterial = ""
    @State var soilType = ""
    @State var isIndoor = true
    @State var windowDirection: PlantWindowDirection = .unknown
    @State var lightLevel: PlantLightLevel = .medium
    @State var lightMeasurementLux = 0
    @State var humidityPreference: PlantHumidityPreference = .standard
    @State var temperaturePreference: PlantTemperaturePreference = .standard
    @State var isNearClimateSource = false
    @State var potHasDrainage = true
    @State var hasAcquiredDate = false
    @State var acquiredDate = Date()
    @State var acquisitionSource = ""
    @State var currentHeightCm = 0.0
    @State var currentSpreadCm = 0.0
    @State var isHydroponic = false
    @State var isSucculent = false
    @State var healthStatus: PlantHealthStatus = .stable
    @State var isToxicToCats = false
    @State var isToxicToDogs = false
    @State var isToxicToChildren = false
    @State var remindersEnabled = true
    @State var isSaving = false
    @State var showDuplicateAlert = false
    @State var showingOptionalPlantDetails = false
    @State var showingCustomRoomField = false
    @State var showingCustomLocationField = false
    @State var didShowSuccess = false
    @State var saveFailureMessage: String?
    @State var isPreparingCamera = false
    @State var cropPresentationTask: Task<Void, Never>?
    @State var duplicateAcknowledgementKey = ""
    @State var inlineFocusField: AddPlantFocusField?
    @State var inlineFocusRequestID = 0
    @FocusState var focusedField: AddPlantFocusField?

    var body: some View {
        plantCreationFlow
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                    GoKeyboard.dismiss()
                    focusedField = nil
                }
                .accessibilityIdentifier("add-plant-keyboard-done")
            }
        }
        .onChange(of: media.photoItem) { _, item in
            handlePlantPhotoPickerItem(item)
        }
        .photosPicker(
            isPresented: Binding(
                get: { media.isPhotoPickerPresented },
                set: { isPresented in
                    if !isPresented, media.isPhotoPickerPresented {
                        media.route = nil
                        finishPlantAvatarMediaPresentation()
                    }
                }
            ),
            selection: $media.photoItem,
            matching: .images
        )
        .fullScreenCover(
            isPresented: Binding(
                get: { media.isCameraPresented },
                set: { isPresented in
                    if !isPresented, media.isCameraPresented {
                        media.route = nil
                        finishPlantAvatarMediaPresentation()
                    }
                }
            )
        ) {
            MemberCameraCaptureView(maxPixel: 2000) { image in
                media.route = nil
                Task {
                    let prepared = await Task.detached(priority: .userInitiated) { // smoothness: allow route-scoped camera image normalization matching member avatar capture; result returns to this sheet before crop presentation.
                        MemberAvatarImageProcessor.normalized(image)
                    }.value
                    await MainActor.run {
                        presentPlantAvatarCrop(
                            MemberPortraitCropItem(source: .image(prepared)),
                            delayMilliseconds: 320
                        )
                    }
                }
            } onCancel: {
                media.route = nil
                finishPlantAvatarMediaPresentation()
            }
        }
        .sheet(
            item: Binding<MemberPortraitCropItem?>(
                get: { media.cropItem },
                set: { item in
                    if item == nil, media.cropItem != nil {
                        media.route = nil
                    }
                }
            )
        ) { item in
            MemberPortraitCropView(item: item) { data in
                applyPlantAvatarImageData(data)
                media.route = nil
                finishPlantAvatarMediaPresentation()
            } onCancel: {
                media.route = nil
                finishPlantAvatarMediaPresentation()
            }
            .presentationDetents([.large]) // ui-v4: allow portrait crop editor needs full-height working area
        }
        .onChange(of: roomName) { _, newValue in
            if commonRoomOptions.contains(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                showingCustomRoomField = false
                if focusedField == .room { focusedField = nil }
            }
        }
        .onChange(of: location) { _, newValue in
            if commonSpotOptions.contains(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                showingCustomLocationField = false
                if focusedField == .location { focusedField = nil }
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
            cropPresentationTask?.cancel()
            cropPresentationTask = nil
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar"), isPresented: plantPermissionAlertBinding) {
            Button(l.done, role: .cancel) {
                media.route = nil
                finishPlantAvatarMediaPresentation()
            }
        } message: {
            Text(l.tr(zh: "请在系统设置中允许 Ohana 访问相机，或在支持相机的设备上使用。", en: "Allow camera access in Settings, or use a device with a camera.", de: "Erlaube den Kamerazugriff in den Einstellungen oder nutze ein Gerät mit Kamera."))
        }
        .alert(l.tr(zh: "可能已经建过档", en: "This may already exist", de: "Vielleicht schon angelegt"), isPresented: $showDuplicateAlert) {
            Button(l.tr(zh: "返回检查", en: "Go back and check", de: "Zurück und prüfen"), role: .cancel) {}
            Button(l.tr(zh: "仍然添加", en: "Add anyway", de: "Trotzdem hinzufügen")) {
                duplicateAcknowledgementKey = currentDuplicateAcknowledgementKey
                savePlant()
            }
        } message: {
            Text(duplicateAlertMessage)
        }
        .alert(l.tr(zh: "保存失败", en: "Save failed", de: "Speichern fehlgeschlagen"), isPresented: saveFailureAlertBinding) {
            Button(l.done, role: .cancel) {
                saveFailureMessage = nil
            }
        } message: {
            Text(saveFailureMessage ?? l.tr(zh: "请稍后重试。", en: "Please try again later.", de: "Bitte später erneut versuchen."))
        }
    }

    private var addPlantSimpleHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goTeal.opacity(0.16))
                    .frame(width: 54, height: 54)
                Text(avatarEmoji)
                    .font(OhanaFont.adaptive(size: 28))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                    .font(OhanaFont.adaptive(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(profilePreviewName) · \(profilePreviewSpecies)")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("add-plant-name-summary-value")
                Text(carePlanPreviewSummary)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-plant-simple-header")
    }

    private var plantSpeciesPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "选择品种", en: "Choose species", de: "Art wählen"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(l.tr(
                zh: "先选大类，再选品种。选中后会自动填写名称、浇水、施肥和基础环境。",
                en: "Pick a group, then a species. Ohana fills the name, watering, fertilizer, and basic care defaults.",
                de: "Wähle erst eine Gruppe, dann eine Art. Ohana füllt Name, Gießen, Düngen und Basiswerte."
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

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

            Text(selectedCatalogGroup.subtitle(l))
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                catalogSearchResultsList
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(groupedCatalogEntries) { entry in
                        commonPlantChoiceButton(entry)
                    }
                }
                .accessibilityElement(children: .contain)
            }

            catalogSearchField
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-species-picker")
    }

    func catalogGroupButton(_ group: PlantCatalogBrowsingGroup) -> some View {
        let isSelected = selectedCatalogGroup == group
        return Button {
            selectedCatalogGroup = group
            catalogQuery = ""
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(group.title(l))
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(group.title(l))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-catalog-group-\(group.rawValue)")
    }

    func commonPlantChoiceButton(_ entry: PlantCatalogEntry) -> some View {
        let isSelected = selectedCatalogID == entry.id
        return Button {
            applyCatalog(entry)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.localizedCommonName)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(l.tr(
                    zh: "\(entry.defaultWateringDays)天浇水",
                    en: "Water \(entry.defaultWateringDays)d",
                    de: "\(entry.defaultWateringDays) T. gießen"
                ))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("add-plant-common-catalog-\(entry.id)")
    }

    private var nameAndPlaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "名称和位置", en: "Name and place", de: "Name und Ort"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            plantNameSummarySection

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-name-place")
    }

    @ViewBuilder
    var plantNameSummarySection: some View {
        if selectedCatalog != nil, !isCustomizingName {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(zh: "植物名字", en: "Plant name", de: "Pflanzenname"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)

                    Text(trimmedName.isEmpty ? (selectedCatalog?.localizedCommonName ?? "") : trimmedName)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .accessibilityIdentifier("add-plant-name-summary-secondary-value")
                }

                Spacer(minLength: 8)

                Button {
                    isCustomizingName = true
                    requestInlineFocusAfterMount(.name)
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"), systemImage: "pencil")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill.opacity(0.66), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "编辑植物名字", en: "Edit plant name", de: "Pflanzennamen bearbeiten"))
                .accessibilityIdentifier("add-plant-name-edit-action")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(Color.ohanaControlFill.opacity(0.44), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("add-plant-name-summary")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                inlineFormField(
                    l.tr(zh: "植物名字", en: "Plant name", de: "Pflanzenname"),
                    text: $name,
                    placeholder: selectedCatalog?.localizedCommonName ?? l.tr(zh: "我的绿萝", en: "My pothos", de: "Meine Efeutute"),
                    identifier: "add-plant-name-input",
                    focusField: .name,
                    submitLabel: .next
                )

                if let selectedCatalog {
                    Button {
                        name = selectedCatalog.localizedCommonName
                        isCustomizingName = false
                        focusedField = nil
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(
                            l.tr(zh: "使用品种名称", en: "Use species name", de: "Artnamen verwenden"),
                            systemImage: "leaf"
                        )
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .foregroundStyle(Color.goTeal)
                    .accessibilityIdentifier("add-plant-name-use-catalog-action")
                }
            }
        }
    }

    private var essentialCareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(zh: "自动护理计划", en: "Automatic care plan", de: "Automatischer Pflegeplan"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedCatalog == nil ? "sparkles" : "checkmark.seal.fill") // a11y: allow decorative care-plan glyph; adjacent text describes the generated plan.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(selectedCatalog == nil ? Color.goTeal : Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background((selectedCatalog == nil ? Color.goTeal : Color.goPrimary).opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(carePlanPreviewSummary)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(carePlanPreviewDetail)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(l.tr(zh: "植物提醒", en: "Plant reminders", de: "Pflanzenerinnerungen"), isOn: $remindersEnabled)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-essential-care")
    }

    private var optionalPlantDetailsSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(GoMotion.quick) {
                    showingOptionalPlantDetails.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative optional-details glyph; button text labels the action.
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 44, height: 44)
                        .background(Color.goTeal.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(zh: "可选细节", en: "Optional details", de: "Optionale Details"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "调整品种备注、头像、照护周期、盆器、来源、光照和健康状态。",
                            en: "Adjust species notes, avatar, care cadence, pot, source, light, and health.",
                            de: "Artnotiz, Symbol, Pflegezyklus, Topf, Quelle, Licht und Zustand anpassen."
                        ))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down") // a11y: allow decorative disclosure glyph; button value exposes expanded state.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .rotationEffect(.degrees(showingOptionalPlantDetails ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("add-plant-optional-details-toggle")
            .accessibilityLabel(l.tr(zh: "可选细节", en: "Optional details", de: "Optionale Details"))
            .accessibilityValue(showingOptionalPlantDetails ? l.tr(zh: "已展开", en: "Expanded", de: "Geöffnet") : l.tr(zh: "已收起", en: "Collapsed", de: "Geschlossen"))

            if showingOptionalPlantDetails {
                VStack(spacing: 12) {
                    speciesOverrideSection
                    avatarPickerSection
                    careAdjustmentSection
                    environmentSection
                    potSection
                    sourceSection
                    healthSection
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("add-plant-optional-details-content")
            }
        }
        .accessibilityIdentifier("add-plant-optional-details")
    }

    private var speciesOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "品种备注", en: "Species note", de: "Artnotiz"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            inlineFormField(
                l.tr(zh: "显示品种", en: "Shown species", de: "Angezeigte Art"),
                text: $species,
                placeholder: l.tr(zh: "如果没有选到准确品种，可手动备注", en: "Add a note if the catalog match is not exact", de: "Notiz ergänzen, falls der Katalogtreffer nicht exakt ist"),
                identifier: "add-plant-species-input",
                focusField: .species,
                submitLabel: .next
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-species-override")
    }

    private var careAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "调整护理周期", en: "Adjust care cadence", de: "Pflegezyklus anpassen"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            Stepper(l.tr(zh: "浇水：每 \(wateringInterval) 天", en: "Water: every \(wateringInterval) days", de: "Gießen: alle \(wateringInterval) Tage"), value: $wateringInterval, in: 1 ... 90)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)

            Stepper(l.tr(zh: "施肥：每 \(fertilizingInterval) 天", en: "Fertilize: every \(fertilizingInterval) days", de: "Düngen: alle \(fertilizingInterval) Tage"), value: $fertilizingInterval, in: 1 ... 365)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-care-adjustments")
    }

    private var avatarPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "植物图标", en: "Plant icon", de: "Pflanzensymbol"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                ForEach(plantEmojis, id: \.self) { emoji in
                    Button {
                        avatarEmoji = emoji
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(emoji)
                            .font(OhanaFont.adaptive(size: 28))
                            .frame(width: 46, height: 46)
                            .background(
                                avatarEmoji == emoji
                                    ? Color.goPrimary.opacity(0.22)
                                    : Color.ohanaControlFill.opacity(0.68),
                                in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                                    .strokeBorder(
                                        avatarEmoji == emoji ? Color.goPrimary.opacity(0.55) : Color.ohanaCardSurface.opacity(0.16),
                                        lineWidth: avatarEmoji == emoji ? 1.5 : 1
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "选择植物图标 \(emoji)", en: "Choose plant icon \(emoji)", de: "Pflanzensymbol \(emoji) wählen"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
        .accessibilityIdentifier("add-plant-avatar-picker")
    }

    var catalogSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass") // a11y: allow decorative search glyph; text field placeholder labels the search input.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .accessibilityHidden(true)
            TextField(l.tr(zh: "搜索绿萝、Monstera、吊兰…", en: "Search pothos, Monstera, spider plant...", de: "Efeutute, Monstera, Grünlilie suchen..."), text: $catalogQuery) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .catalogSearch)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.catalogSearch) }
                .accessibilityIdentifier("add-plant-catalog-search-input")

            if !catalogQuery.isEmpty {
                Button {
                    catalogQuery = ""
                    focusedField = nil
                } label: {
                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative clear-search glyph; button has an explicit accessibility label.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "清空搜索", en: "Clear search", de: "Suche löschen"))
                .accessibilityIdentifier("add-plant-catalog-search-clear")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, catalogQuery.isEmpty ? 14 : 2)
        .frame(minHeight: 48)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    var catalogSearchResultsList: some View {
        VStack(spacing: 8) {
            if catalogMatches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "没有找到匹配", en: "No match found", de: "Kein Treffer"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "可以直接填写名称保存；以后在详情里再补品种。",
                        en: "You can save with a custom name and add the species later from details.",
                        de: "Du kannst mit eigenem Namen speichern und die Art später ergänzen."
                    ))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            } else {
                ForEach(catalogMatches) { result in
                    catalogMatchButton(result)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func catalogMatchButton(_ result: PlantCatalogSearchResult) -> some View {
        let entry = result.entry
        return Button {
            applyCatalog(entry)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedCatalogID == entry.id ? "checkmark.circle.fill" : "leaf.circle")
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(selectedCatalogID == entry.id ? Color.goPrimary : Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.localizedCommonName)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(entry.latinName)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                    Text(l.tr(
                        zh: "浇水 \(entry.defaultWateringDays) 天 · 施肥 \(entry.defaultFertilizingDays) 天",
                        en: "Water \(entry.defaultWateringDays)d · fertilize \(entry.defaultFertilizingDays)d",
                        de: "Gießen \(entry.defaultWateringDays) T. · düngen \(entry.defaultFertilizingDays) T."
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                catalogChip(
                    entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren
                        ? l.tr(zh: "误食风险", en: "Risk", de: "Risiko")
                        : l.tr(zh: "低风险", en: "Low risk", de: "Gering"),
                    foreground: entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren ? Color.arkInk : Color.ohanaPrimaryText,
                    background: entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren ? Color.goYellow : Color.ohanaControlFill.opacity(0.78)
                )
            }
            .padding(12)
            .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(entry.localizedCommonName), \(entry.latinName), \(result.matchSummary)")
        .accessibilityIdentifier("add-plant-catalog-result-\(entry.id)")
    }

    func catalogChip(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var potSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "盆土", en: "Pot and soil", de: "Topf und Erde"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            Stepper(l.tr(zh: "盆径 \(Int(potDiameterCm)) cm", en: "Pot diameter \(Int(potDiameterCm)) cm", de: "Topfdurchmesser \(Int(potDiameterCm)) cm"), value: $potDiameterCm, in: 0 ... 80, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            Toggle(l.tr(zh: "花盆有排水孔", en: "Pot has drainage hole", de: "Topf hat Abzugsloch"), isOn: $potHasDrainage)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见盆材质", en: "Common pot materials", de: "Häufige Topfmaterialien"),
                options: commonPotMaterialOptions,
                selection: $potMaterial,
                identifierPrefix: "add-plant-pot-material-choice"
            )
            TextField(l.tr(zh: "盆材质，如陶盆、塑料盆", en: "Pot material, e.g. terracotta or plastic", de: "Topfmaterial, z. B. Ton oder Kunststoff"), text: $potMaterial) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .focused($focusedField, equals: .potMaterial)
                .submitLabel(.next)
                .onSubmit { focusAfterSubmit(.potMaterial) }
                .accessibilityIdentifier("add-plant-pot-material-input")
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见土壤", en: "Common soil", de: "Häufige Erde"),
                options: commonSoilOptions,
                selection: $soilType,
                identifierPrefix: "add-plant-soil-choice"
            )
            TextField(l.tr(zh: "土壤类型，如疏松排水型通用土", en: "Soil type, e.g. loose well-draining mix", de: "Erdtyp, z. B. lockere gut drainierende Erde"), text: $soilType) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .focused($focusedField, equals: .soil)
                .submitLabel(.done)
                .onSubmit { focusAfterSubmit(.soil) }
                .accessibilityIdentifier("add-plant-soil-input")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "来源与类型", en: "Source and type", de: "Quelle und Typ"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
            Toggle(l.tr(zh: "记录购入日期", en: "Record acquired date", de: "Kaufdatum erfassen"), isOn: $hasAcquiredDate)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            if hasAcquiredDate {
                DatePicker(l.tr(zh: "购入日期", en: "Acquired date", de: "Kaufdatum"), selection: $acquiredDate, displayedComponents: .date)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goPrimary)
            }
            OhanaChoiceChipRow(
                title: l.tr(zh: "常见来源", en: "Common sources", de: "Häufige Quellen"),
                options: commonSourceOptions,
                selection: $acquisitionSource,
                identifierPrefix: "add-plant-source-choice"
            )
            TextField(l.tr(zh: "来源，如花市、朋友分株", en: "Source, e.g. market or friend's cutting", de: "Quelle, z. B. Markt oder Ableger von Freunden"), text: $acquisitionSource) // ui-v4: allow existing plant launch form input while OhanaTextField migration remains tracked.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .focused($focusedField, equals: .source)
                .submitLabel(.done)
                .onSubmit { focusAfterSubmit(.source) }
                .accessibilityIdentifier("add-plant-source-input")
            Stepper(l.tr(zh: "当前高度 \(Int(currentHeightCm)) cm", en: "Current height \(Int(currentHeightCm)) cm", de: "Aktuelle Höhe \(Int(currentHeightCm)) cm"), value: $currentHeightCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            Stepper(l.tr(zh: "冠幅 \(Int(currentSpreadCm)) cm", en: "Spread \(Int(currentSpreadCm)) cm", de: "Breite \(Int(currentSpreadCm)) cm"), value: $currentSpreadCm, in: 0 ... 300, step: 1)
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            Toggle(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"), isOn: $isHydroponic)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            Toggle(l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus"), isOn: $isSucculent)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    func inlineFormField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        identifier: String,
        focusField: AddPlantFocusField,
        submitLabel: SubmitLabel
    ) -> some View {
        PlantCreationBufferedTextField(
            title: title,
            text: text,
            placeholder: placeholder,
            identifier: identifier,
            focusRequestID: inlineFocusRequestID(for: focusField),
            submitLabel: submitLabel
        ) {
            focusAfterSubmit(focusField)
        }
    }

    func customInlineEntryButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: "plus")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.goTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(Color.ohanaControlFill.opacity(0.42), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
    }

    private func goFormField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        identifier: String,
        focusField: AddPlantFocusField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .textCase(.uppercase)
                .tracking(0.6)
            TextField(placeholder, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(14)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(
                            focusedField == focusField ? Color.goTeal.opacity(0.58) : Color.ohanaCardSurface.opacity(0.18),
                            lineWidth: focusedField == focusField ? 1.5 : 1
                        )
                )
                .focused($focusedField, equals: focusField)
                .submitLabel(focusField == .location ? .done : .next)
                .onSubmit { focusAfterSubmit(focusField) }
                .accessibilityIdentifier(identifier)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    @ViewBuilder
    var keyboardFocusSpacer: some View {
        if focusedField != nil {
            Color.clear
                .frame(height: 74)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    func inlineFocusRequestID(for field: AddPlantFocusField) -> Int {
        inlineFocusField == field ? inlineFocusRequestID : 0
    }

    func requestInlineFocusAfterMount(_ field: AddPlantFocusField) {
        focusedField = nil
        OhanaFrameScheduler.runAfterNextFrame {
            requestInlineFocus(field)
        }
    }

    func requestInlineFocus(_ field: AddPlantFocusField) {
        inlineFocusField = field
        inlineFocusRequestID += 1
    }

    func focusBinding(for field: AddPlantFocusField) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { isFocused in
                if isFocused {
                    focusedField = field
                } else if focusedField == field {
                    focusedField = nil
                }
            }
        )
    }

    func focusAfterSubmit(_ field: AddPlantFocusField) {
        switch field {
        case .name:
            if showingCustomRoomField || usesCustomRoomEntry {
                requestInlineFocusAfterMount(.room)
            } else if showingCustomLocationField || usesCustomLocationEntry {
                requestInlineFocusAfterMount(.location)
            } else {
                GoKeyboard.dismiss()
                focusedField = nil
            }
        case .species:
            focusedField = .room
        case .catalogSearch:
            focusedField = nil
        case .room:
            if showingCustomLocationField || usesCustomLocationEntry {
                requestInlineFocusAfterMount(.location)
            } else {
                GoKeyboard.dismiss()
                focusedField = nil
            }
        case .location, .soil, .source:
            GoKeyboard.dismiss()
            focusedField = nil
        case .potMaterial:
            focusedField = .soil
        }
    }

    func revealCustomRoomField() {
        showingCustomRoomField = true
        focusedField = nil
        requestInlineFocusAfterMount(.room)
    }

    func revealCustomLocationField() {
        showingCustomLocationField = true
        focusedField = nil
        requestInlineFocusAfterMount(.location)
    }

    func applyCatalog(_ entry: PlantCatalogEntry) {
        let previousCatalogName = selectedCatalog?.localizedCommonName ?? ""
        let shouldUseCatalogName = trimmedName.isEmpty || (!previousCatalogName.isEmpty && trimmedName == previousCatalogName)
        let defaults = PlantProfileUXPolicy.catalogDefaults(for: entry)
        selectedCatalogID = entry.id
        catalogQuery = ""
        if shouldUseCatalogName {
            name = defaults.name
            isCustomizingName = false
        }
        species = defaults.species
        wateringInterval = defaults.wateringIntervalDays
        fertilizingInterval = defaults.fertilizingIntervalDays
        lightLevel = defaults.lightLevel
        soilType = defaults.soilTypeRaw
        isIndoor = defaults.isIndoor
        humidityPreference = defaults.humidityPreference
        temperaturePreference = defaults.temperaturePreference
        potHasDrainage = defaults.potHasDrainage
        isHydroponic = defaults.isHydroponic
        isSucculent = defaults.isSucculent
        isToxicToCats = entry.isToxicToCats
        isToxicToDogs = entry.isToxicToDogs
        isToxicToChildren = entry.isToxicToChildren
        focusedField = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func clearSelectedPlantCatalog() {
        selectedCatalogID = ""
        catalogQuery = ""
        name = ""
        species = ""
        isCustomizingName = false
        focusedField = nil
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func savePlant() {
        let finalName = resolvedPlantName
        guard !finalName.isEmpty, !isSaving else { return }
        if requiresDuplicateAcknowledgement {
            showDuplicateAlert = true
            return
        }
        let catalog = selectedCatalog

        let input = PlantCreationCommandInput(
            name: finalName,
            species: species,
            location: location,
            avatarEmoji: avatarEmoji,
            avatarImageData: avatarImageData,
            wateringIntervalDays: wateringInterval,
            fertilizingIntervalDays: fertilizingInterval,
            roomNameRaw: roomName,
            potDiameterCm: potDiameterCm,
            potMaterialRaw: potMaterial,
            soilTypeRaw: soilType,
            isIndoor: isIndoor,
            windowDirection: windowDirection,
            lightLevel: lightLevel,
            lastLightMeasurementLux: lightMeasurementLux,
            lastLightMeasurementDate: lightMeasurementLux > 0 ? Date() : nil,
            humidityPreference: humidityPreference,
            temperaturePreference: temperaturePreference,
            isNearClimateSource: isNearClimateSource,
            potHasDrainage: potHasDrainage,
            acquiredDate: hasAcquiredDate ? acquiredDate : nil,
            acquisitionSourceRaw: acquisitionSource,
            currentHeightCm: currentHeightCm,
            currentSpreadCm: currentSpreadCm,
            isHydroponic: isHydroponic,
            isSucculent: isSucculent,
            healthStatus: healthStatus,
            catalogSpeciesId: selectedCatalogID,
            isToxicToCats: isToxicToCats,
            isToxicToDogs: isToxicToDogs,
            isToxicToChildren: isToxicToChildren,
            isIndoorSuitable: catalog?.isIndoorSuitable ?? true,
            remindersEnabled: remindersEnabled
        )
        let command = DomainCommand.memberCreation(entityID: input.id, kind: EntityKind.plant.rawValue)

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            let result = PlantCreationCommandExecutor(context: modelContext, services: appServices).createPlant(
                input: input,
                note: "plant.creation"
            )
            guard result.didPersist else {
                isSaving = false
                saveFailureMessage = plantCreationSaveFailureMessage(result.persistenceErrorDescription)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onPlantSaved?(result.plantID)
            withAnimation(GoMotion.sheetEnter) {
                didShowSuccess = true
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 260 : 620) {
                onComplete()
            }
        }
    }

    private var saveFailureAlertBinding: Binding<Bool> {
        Binding(
            get: { saveFailureMessage != nil },
            set: { isPresented in
                if !isPresented { saveFailureMessage = nil }
            }
        )
    }

    private func plantCreationSaveFailureMessage(_ errorDescription: String?) -> String {
        if let errorDescription, !errorDescription.isEmpty {
            return l.tr(
                zh: "无法保存植物档案：\(errorDescription)",
                en: "Could not save the plant profile: \(errorDescription)",
                de: "Das Pflanzenprofil konnte nicht gespeichert werden: \(errorDescription)"
            )
        }
        return l.tr(
            zh: "无法保存植物档案，请稍后重试。",
            en: "Could not save the plant profile. Please try again later.",
            de: "Das Pflanzenprofil konnte nicht gespeichert werden. Bitte später erneut versuchen."
        )
    }

    var duplicateAlertMessage: String {
        guard let first = duplicateCandidates.first else {
            return l.tr(zh: "Ohana 没找到明显重复项，可以继续添加。", en: "Ohana did not find an obvious duplicate. You can keep adding it.", de: "Ohana hat kein offensichtliches Duplikat gefunden. Du kannst fortfahren.")
        }
        return l.tr(
            zh: "找到相似植物：\(first.title)。原因：\(first.reason)。如果这是另一盆植物，可以继续添加。",
            en: "Similar plant found: \(first.title). Reason: \(first.reason). If this is another pot, you can still add it.",
            de: "Ähnliche Pflanze gefunden: \(first.title). Grund: \(first.reason). Wenn es ein anderer Topf ist, kannst du sie trotzdem hinzufügen."
        )
    }
}
