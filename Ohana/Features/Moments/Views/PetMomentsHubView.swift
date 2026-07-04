//
//  PetMomentsHubView.swift
//  Ohana
//
//  V4 pet moments hub. This is the single surface for highlights, diary,
//  archive history, and photos.
//

import PhotosUI
import SwiftData
import SwiftUI

private enum PetMomentsTab: String, CaseIterable, Identifiable {
    case highlights
    case timeline
    case photos

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .highlights: l.tr(zh: "高光", en: "Highlights", de: "Highlights")
        case .timeline: l.tr(zh: "时光", en: "Diary", de: "Tagebuch")
        case .photos: l.tr(zh: "相册", en: "Album", de: "Album")
        }
    }

    var icon: String {
        switch self {
        case .highlights: "sparkles"
        case .timeline: "clock.arrow.circlepath"
        case .photos: "photo.on.rectangle"
        }
    }
}

private enum PetMomentsArchiveFilter: String, CaseIterable, Identifiable {
    case memories
    case all
    case health
    case care
    case expense

    var id: String { rawValue }

    var mode: PetTimelineDisplayMode {
        switch self {
        case .memories: .memories
        case .all: .all
        case .health: .health
        case .care: .care
        case .expense: .expense
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .memories: l.tr(zh: "记录", en: "Notes", de: "Notizen")
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        case .health: l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .care: l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .expense: l.tr(zh: "花费", en: "Costs", de: "Kosten")
        }
    }
}

private struct PendingSharedSessionDelete: Identifiable {
    let id: UUID
    let title: String
}

struct PetMomentsHubView: View {
    let pet: Pet
    let sharedCareSessions: [SharedCareSession]
    let renderData: PetMomentsHubRenderData
    let albumRenderData: PetPhotoAlbumRenderData
    let dataRevision: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""

    @State private var tab: PetMomentsTab = .highlights
    @State private var archiveFilter: PetMomentsArchiveFilter = .memories
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showingQuickMoment = false
    @State private var pendingSharedSessionDelete: PendingSharedSessionDelete?

    init(
        pet: Pet,
        sharedCareSessions: [SharedCareSession],
        renderData: PetMomentsHubRenderData = .empty,
        albumRenderData: PetPhotoAlbumRenderData = .empty,
        dataRevision: Int = 0
    ) {
        self.pet = pet
        self.sharedCareSessions = sharedCareSessions
        self.renderData = renderData
        self.albumRenderData = albumRenderData
        self.dataRevision = dataRevision
    }

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }

    private var highlightCount: Int {
        renderData.highlightCount
    }

    private var memoryCount: Int {
        renderData.memoryCount
    }

    private var realPhotoCount: Int {
        renderData.realPhotoCount
    }

    private var currentSections: [PetTimelineRenderSection] {
        switch tab {
        case .highlights:
            renderData.highlightSections
        case .timeline:
            renderData.sections(for: archiveFilter.mode)
        case .photos:
            []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                OhanaAppBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                    overview
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    tabSwitch
                        .padding(.horizontal, 16)
                        .padding(.bottom, tab == .timeline ? 8 : 12)

                    if tab == .timeline {
                        filterChips
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    if tab == .photos {
                        PetPhotoAlbumView(pet: pet, renderData: albumRenderData, hubPickerSelection: $photosPickerItems)
                    } else {
                        archiveScroll
                    }
                }
                .onChange(of: photosPickerItems) { _, newItems in
                    PetPhotoAlbumView.consumePickerItems(
                        newItems,
                        pet: pet,
                        modelContext: modelContext,
                        services: appServices
                    )
                    photosPickerItems = []
                }

                activeAddButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                pendingSharedSessionDelete?.title ?? l.tr(zh: "删除共同记录？", en: "Delete shared record?", de: "Gemeinsamen Eintrag löschen?"),
                isPresented: sharedSessionDeleteBinding,
                titleVisibility: .visible
            ) {
                Button(l.tr(zh: "删除整组共同记录", en: "Delete shared record", de: "Gemeinsamen Eintrag löschen"), role: .destructive) {
                    deletePendingSharedSession()
                }
                Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                    pendingSharedSessionDelete = nil
                }
            } message: {
                Text(l.tr(
                    zh: "会同时删除这次共同记录下所有宠物的子记录、账本投影和共享会话。",
                    en: "This removes every pet entry, ledger projection, and the shared session for this action.",
                    de: "Dies entfernt alle Haustier-Einträge, Ledger-Projektionen und die gemeinsame Sitzung."
                ))
            }
            .overlay {
                if showingQuickMoment {
                    QuickMomentSheet(
                        pet: pet,
                        onRemove: nil,
                        onClose: {
                            showingQuickMoment = false
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageCacheID: "pet-moments-hub-\(pet.id.uuidString)",
                imageSignature: pet.avatarThumbnailSignature,
                petModelID: pet.persistentModelID,
                emoji: pet.avatarEmoji,
                fallback: pet.speciesEmoji,
                tint: themeColor
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "记录中心", en: "Moments", de: "Momente"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(pet.name) · \(l.tr(zh: "高光、时光、相册", en: "highlights, diary, album", de: "Highlights, Tagebuch, Album"))")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var overview: some View {
        HStack(spacing: 10) {
            metric(l.tr(zh: "故事", en: "Stories", de: "Storys"), "\(memoryCount)")
            metric(l.tr(zh: "照片", en: "Photos", de: "Fotos"), "\(realPhotoCount)")
            metric(l.tr(zh: "高光", en: "Highlights", de: "Highlights"), "\(highlightCount)")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .animation(GoMotion.stateChange, value: value)
    }

    private var tabSwitch: some View {
        HStack(spacing: 8) {
            ForEach(PetMomentsTab.allCases) { target in
                tabButton(target)
            }
        }
        .padding(5)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    private func tabButton(_ target: PetMomentsTab) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.selection) { tab = target }
        } label: {
            Label(target.title(l), systemImage: target.icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(tab == target ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(tab == target ? Color.goPrimary : Color.clear, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PetMomentsArchiveFilter.allCases) { filter in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) { archiveFilter = filter }
                    } label: {
                        Text(filter.title(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(archiveFilter == filter ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(archiveFilter == filter ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var archiveScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if currentSections.isEmpty {
                    emptyState
                } else {
                    timelineSections
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 110)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(GoMotion.stateChange, value: tab)
        .animation(GoMotion.stateChange, value: archiveFilter)
    }

    private var timelineSections: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(currentSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(section.title)
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text(section.subtitle)
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .padding(.horizontal, 18)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            if item.style == .story {
                                storyRow(item)
                            } else {
                                railRow(item, isLast: index == section.items.count - 1)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                }
            }
        }
    }

    private func storyRow(_ item: PetTimelineRenderItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: item.iconName)
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(item.colorToken.color)
                    .frame(width: 22, height: 22) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(item.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                Spacer()
                Text(item.date, format: .dateTime.hour().minute())
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                sharedSessionActionMenu(for: item)
            }

            photoCollage(item.photos)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func railRow(_ item: PetTimelineRenderItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(item.colorToken.color.opacity(0.18))
                    Image(systemName: item.iconName)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(item.colorToken.color)
                }
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent

                if !isLast {
                    Rectangle()
                        .fill(Color.ohanaSecondaryText.opacity(0.15))
                        .frame(width: 1, height: 22) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Text(item.date, format: .dateTime.hour().minute())
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.65))
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
            sharedSessionActionMenu(for: item)
        }
    }

    @ViewBuilder
    private func sharedSessionActionMenu(for item: PetTimelineRenderItem) -> some View {
        if item.sharedSessionID != nil {
            Menu {
                Button(role: .destructive) {
                    requestDeleteSharedSession(item)
                } label: {
                    Label(l.tr(zh: "删除整组共同记录", en: "Delete shared record", de: "Gemeinsamen Eintrag löschen"), systemImage: "trash")
                }
            } label: {
                Label(l.tr(zh: "共同记录操作", en: "Shared record actions", de: "Aktionen für gemeinsamen Eintrag"), systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy icon token; menu frame carries the hit target in compact rows.
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(l.tr(zh: "共同记录操作", en: "Shared record actions", de: "Aktionen für gemeinsamen Eintrag"))
        }
    }

    private var sharedSessionDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingSharedSessionDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingSharedSessionDelete = nil
                }
            }
        )
    }

    private func requestDeleteSharedSession(_ item: PetTimelineRenderItem) {
        guard let sharedSessionID = item.sharedSessionID else { return }
        pendingSharedSessionDelete = PendingSharedSessionDelete(id: sharedSessionID, title: item.title)
    }

    private func deletePendingSharedSession() {
        guard let pending = pendingSharedSessionDelete,
              let session = sharedCareSessions.first(where: { $0.id == pending.id }) else {
            pendingSharedSessionDelete = nil
            return
        }

        let result = SharedCareSessionMaintenance.deleteCascade(
            session,
            context: modelContext,
            deletedByHumanId: activeHumanId.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        appServices.domainRevisions.publishSharedCareSessionDelete(
            result,
            sourcePetID: pet.id,
            note: "petMoments.sharedSession.delete"
        )
        pendingSharedSessionDelete = nil
    }

    @ViewBuilder
    private func photoCollage(_ photos: [PetTimelinePhotoReference]) -> some View {
        let validPhotos = photos.filter(\.canAttemptImageAttachmentLoad)
        if validPhotos.count == 1, let photo = validPhotos.first {
            AsyncDecodedImageView(
                cacheID: "pet-moment-collage-\(photo.id.uuidString)",
                sourceSignature: photo.sourceSignature,
                maxPixel: 420,
                asyncDataProvider: {
                    await photoData(for: photo)
                }
            ) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 182)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            } placeholder: {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.ohanaCardSurface)
                    .frame(height: 182)
            }
        } else if !validPhotos.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(validPhotos.prefix(3).enumerated()), id: \.element.id) { _, photo in
                    AsyncDecodedImageView(
                        cacheID: "pet-moment-collage-\(photo.id.uuidString)",
                        sourceSignature: photo.sourceSignature,
                        maxPixel: 320,
                        asyncDataProvider: {
                            await photoData(for: photo)
                        }
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            .fill(Color.ohanaCardSurface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                    }
                }
            }
        }
    }

    private func photoData(for photo: PetTimelinePhotoReference) async -> Data? {
        guard photo.canAttemptImageAttachmentLoad else {
            return nil
        }
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        return await loader.petPhotoLogImageData(modelID: photo.modelID)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: tab == .highlights ? "sparkles" : "sparkles.rectangle.stack.fill")
                .font(OhanaFont.adaptive(size: 38, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
            Text(emptyTitle)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(emptySubtitle)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
            if tab == .highlights {
                Button {
                    withAnimation(GoMotion.selection) { tab = .timeline }
                } label: {
                    Text(l.tr(zh: "去记录", en: "Add a Moment", de: "Moment speichern"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 20)
                        .frame(height: 46)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button { showingQuickMoment = true } label: {
                    Text(l.tr(zh: "记录第一刻", en: "Add First Moment", de: "Ersten Moment speichern"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 20)
                        .frame(height: 46)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 20)
    }

    private var emptyTitle: String {
        switch tab {
        case .highlights:
            l.tr(zh: "还没有高光", en: "No highlights yet", de: "Noch keine Highlights")
        case .timeline:
            l.tr(zh: "还没有时光记录", en: "No moments yet", de: "Noch keine Momente")
        case .photos:
            l.tr(zh: "还没有照片", en: "No photos yet", de: "Noch keine Fotos")
        }
    }

    private var emptySubtitle: String {
        switch tab {
        case .highlights:
            l.tr(zh: "生日、相伴日和重要记录会自动出现在这里。", en: "Birthdays, together-days, and key records appear here.", de: "Geburtstage, gemeinsame Tage und wichtige Einträge erscheinen hier.")
        case .timeline:
            l.tr(zh: "写一句话、拍一张照片，慢慢就会变成 \(pet.name) 的故事。", en: "A line or a photo becomes \(pet.name)'s story over time.", de: "Ein Satz oder Foto wird mit der Zeit zu \(pet.name)s Geschichte.")
        case .photos:
            l.tr(zh: "添加照片后会组成 \(pet.name) 的相册。", en: "Add photos to build \(pet.name)'s album.", de: "Füge Fotos hinzu, um \(pet.name)s Album aufzubauen.")
        }
    }

    private var addMomentButton: some View {
        Button { showingQuickMoment = true } label: {
            addButtonLabel(
                icon: "plus",
                title: l.tr(zh: "记录", en: "Add", de: "Speichern")
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var activeAddButton: some View {
        switch tab {
        case .highlights:
            EmptyView()
        case .timeline:
            addMomentButton
        case .photos:
            PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 12, matching: .images) {
                addButtonLabel(
                    icon: "plus",
                    title: l.tr(zh: "添加", en: "Add", de: "Hinzufügen")
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func addButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 22)
        .frame(height: 54)
        .background(Color.goPrimary, in: Capsule())
    }
}
