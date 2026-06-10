//
//  PetMilestoneListView.swift
//  Ohana
//
//  FIX 7: 里程碑页面全面升级（照片 + 时间轴 UI）

import MapKit
import PhotosUI
import SwiftData
import SwiftUI

struct PetMilestoneListView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newEmoji = "🎉"
    @State private var newDate = Date()
    @State private var newNotes = ""
    @State private var newLocation = ""
    @State private var showingLocationPicker = false
    @State private var newPhotoItem: PhotosPickerItem? = nil
    @State private var newPhotoData: Data? = nil
    @State private var selectedMilestone: PetMilestone? = nil
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var sortedMilestones: [PetMilestone] {
        pet.milestones.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    if sortedMilestones.isEmpty {
                        emptyState.padding(.top, 60)
                    } else {
                        timelineList.padding(.horizontal, 20)
                    }
                    Spacer(minLength: 90)
                }
            }

            Button { showAddSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("记录里程碑")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
            }
            .padding(.bottom, 28)
        }
        .navigationTitle("里程碑")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { addMilestoneSheet }
        .sheet(item: $selectedMilestone) { m in MilestoneDetailSheet(milestone: m, pet: pet) }
        .onAppear { seedSystemMilestones() }
    }

    // MARK: - 自动生成里程碑（生日、到家日、最重/最轻体重）
    private func seedSystemMilestones() {
        commandQueue.enqueue(.petMilestoneSeed(petID: pet.id)) {
            PetMilestoneCommandExecutor(context: modelContext, services: appServices).seedSystemMilestones(
                for: pet,
                note: "petMilestone.seed"
            )
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 56,
                backgroundOpacity: 0.18
            )
            .overlay(Circle().strokeBorder(Color.ohanaSecondaryText.opacity(0.2), lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(sortedMilestones.count) 个重要时刻")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            }
            Spacer()
        }
    }

    // MARK: - Timeline
    private var timelineList: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedMilestones.enumerated()), id: \.element.id) { idx, milestone in
                HStack(alignment: .top, spacing: 14) {
                    // 时间轴
                    VStack(spacing: 0) {
                        if idx > 0 {
                            Rectangle().fill(.primary.opacity(0.1)).frame(width: 2, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        }
                        ZStack {
                            Circle()
                                .fill(pet.themeColor.color.opacity(0.3))
                                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            Text(milestone.emoji).font(OhanaFont.adaptive(size: 18)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        }
                        if idx < sortedMilestones.count - 1 {
                            Rectangle().fill(.primary.opacity(0.1)).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 36)

                    // 内容卡（点击进详情）
                    Button { selectedMilestone = milestone } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(milestone.title)
                                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Spacer()
                                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                            }
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            if !milestone.location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 10)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.goYellow)
                                    Text(milestone.location)
                                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.goYellow.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            if !milestone.notes.isEmpty {
                                Text(milestone.notes)
                                    .font(OhanaFont.adaptive(size: 12, weight: .regular)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                    .lineLimit(1)
                            }
                            if let photoData = milestone.photoData {
                                AsyncDecodedImageView(data: photoData) { image in
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                                        .fill(Color.ohanaCardSurface)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 120)
                                }
                            }
                        }
                        .padding(12)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌱").font(OhanaFont.adaptive(size: 56)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text("还没有里程碑记录")
                .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Text("记录 \(pet.name) 的每一个重要时刻")
                .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Sheet（多巴胺深色渐变风格）
    private var addMilestoneSheet: some View {
        VStack(spacing: 0) {
            // 把手
            Capsule()
                .fill(.primary.opacity(0.2))
                .frame(width: 40, height: 4) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .padding(.top, 12).padding(.bottom, 20)

            // 标题行
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Text("🎉").font(OhanaFont.adaptive(size: 26)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录里程碑")
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Emoji 快捷选
                    VStack(alignment: .leading, spacing: 8) {
                        Text("快捷 Emoji")
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            .padding(.horizontal, 4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(["🎉", "🏆", "🌟", "💉", "✂️", "🏠", "✈️", "🐾", "❤️", "🎂", "🌈", "💊", "🦷", "🏋️", "🎓", "🌱"], id: \.self) { e in
                                    Button { newEmoji = e } label: {
                                        Text(e).font(OhanaFont.adaptive(size: 26)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .frame(width: 46, height: 46)
                                            .goSelectableSurface(isSelected: newEmoji == e, tint: Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                                    }.buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    }

                    // Emoji + 标题
                    HStack(spacing: 12) {
                        GoDraftTextField("🎉", text: $newEmoji) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                            .font(OhanaFont.adaptive(size: 28)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .multilineTextAlignment(.center)
                            .frame(width: 56, height: 56)
                            .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                            "里程碑标题",
                            text: $newTitle,
                            capitalization: .sentences
                        )
                        .font(OhanaFont.adaptive(size: 16, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .tint(Color.goPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                        .frame(maxWidth: .infinity)
                    }

                    // 日期
                    HStack {
                        Image(systemName: "calendar") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                        Text("日期")
                            .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        DatePicker("", selection: $newDate, displayedComponents: .date)
                            .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                    // 地址选择 (地图搜索)
                    Button {
                        showingLocationPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goYellow)
                            if newLocation.isEmpty {
                                Text("地点（点此从地图选择）")
                                    .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                            } else {
                                Text(newLocation)
                                    .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // 备注
                    GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                        "备注（可选）",
                        text: $newNotes,
                        axis: .vertical
                    )
                    .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goPrimary)
                    .lineLimit(3 ... 5)
                    .padding(14)
                    .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

                    // 照片选择
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        if let data = newPhotoData {
                            AsyncDecodedImageView(data: data) { image in
                                Image(uiImage: image)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            newPhotoData = nil
                                            newPhotoItem = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(Color.ohanaCardSurface)
                                                .padding(8)
                                        }
                                    }
                            } placeholder: {
                                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                                    .fill(Color.ohanaCardSurface)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 140)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 16, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goPrimary)
                                Text("添加照片（可选）")
                                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goPrimary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row))
                            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row)
                                .strokeBorder(Color.goPrimary.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .onChange(of: newPhotoItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                await MainActor.run { newPhotoData = data }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            // 保存按钮（渐变）
            Button {
                GoKeyboard.dismiss()
                guard !newTitle.isEmpty else { return }
                let input = PetMilestoneCommandInput(
                    date: newDate,
                    title: newTitle,
                    emoji: newEmoji,
                    notes: newNotes,
                    photoData: newPhotoData,
                    location: newLocation
                )
                commandQueue.enqueue(.petMilestoneRecord(petID: pet.id)) {
                    PetMilestoneCommandExecutor(context: modelContext, services: appServices).createMilestone(
                        input: input,
                        pet: pet,
                        note: "petMilestone.record"
                    )
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newTitle = ""
                newEmoji = "🎉"
                newNotes = ""
                newLocation = ""
                newPhotoData = nil
                newPhotoItem = nil
                showAddSheet = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("保存里程碑").font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(newTitle.isEmpty ? .primary.opacity(0.4) : Color.arkInk)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: newTitle.isEmpty
                            ? [Color.goPrimary.opacity(0.25), Color.goPrimary.opacity(0.15)]
                            : [Color.goPrimary, Color(hex: "A8E44A")],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge)
                )
            }
            .disabled(newTitle.isEmpty)
            .padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 8)
        }
        .ohanaSheetPagePresentation() // ui-v4: allow long milestone editor
        .goKeyboardDoneToolbar()
        .sheet(isPresented: $showingLocationPicker) {
            MapLocationPickerSheet(selectedLocation: $newLocation)
        }
    }
}

// MARK: - 地图地点搜索选择器
struct MapLocationPickerSheet: View {
    @Binding var selectedLocation: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                        GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                            "搜索地点、医院、公园…",
                            text: $searchText,
                            commitDelayNanoseconds: 220_000_000,
                            submitLabel: .search,
                            capitalization: .never
                        )
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .tint(Color.goYellow)
                        if !searchText.isEmpty {
                            Button {
                                searchTask?.cancel()
                                searchText = ""
                                results = []
                                isSearching = false
                            } label: {
                                Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    if isSearching {
                        ProgressView()
                            .tint(Color.goYellow)
                            .padding(.top, 40)
                        Spacer()
                    } else if results.isEmpty, !searchText.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.slash").font(OhanaFont.adaptive(size: 36)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.3)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text("没有找到匹配地点")
                                .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }.padding(.top, 60)
                        Spacer()
                    } else if results.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").font(OhanaFont.adaptive(size: 36)).foregroundStyle(Color.goYellow.opacity(0.4)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text("输入地名开始搜索")
                                .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }.padding(.top, 60)
                        Spacer()
                    } else {
                        List(results, id: \.self) { item in
                            Button {
                                selectedLocation = mapItemTitle(item)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知地点")
                                        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                    if let addr = mapItemAddress(item), addr != item.name {
                                        Text(addr)
                                            .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(.primary.opacity(0.1))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !searchText.isEmpty {
                        Button("搜索") {
                            GoKeyboard.dismiss()
                            performSearch()
                        }
                        .foregroundStyle(Color.goYellow)
                        .fontWeight(.bold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        GoKeyboard.dismiss()
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goLime)
                }
            }
            .onChange(of: searchText) { _, new in
                queueSearch(for: new)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func queueSearch(for rawQuery: String) {
        searchTask?.cancel()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            isSearching = false
            if query.isEmpty {
                results = []
            }
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            performSearch(query: query)
        }
    }

    private func performSearch(query rawQuery: String? = nil) {
        let query = (rawQuery ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        let search = MKLocalSearch(request: req)
        search.start { resp, _ in
            DispatchQueue.main.async {
                guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
                isSearching = false
                results = resp?.mapItems ?? []
            }
        }
    }

    private func mapItemTitle(_ item: MKMapItem) -> String {
        item.name ?? mapItemAddress(item) ?? ""
    }

    private func mapItemAddress(_ item: MKMapItem) -> String? {
        item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            ?? item.address?.shortAddress
            ?? item.address?.fullAddress
    }
}

// MARK: - P6: 里程碑详情页
private struct MilestoneDetailSheet: View {
    let milestone: PetMilestone
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var showingPhoto = false
    @State private var showingDeleteAlert = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 头部 Emoji + 标题 + 日期
                        VStack(spacing: 10) {
                            Text(milestone.emoji).font(OhanaFont.adaptive(size: 56)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            Text(milestone.title)
                                .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .multilineTextAlignment(.center)
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .goGlassBackground(Capsule())
                        }
                        .padding(.top, 8)

                        // 照片（可点击全屏预览）
                        if let data = milestone.photoData {
                            Button { showingPhoto = true } label: {
                                AsyncDecodedImageView(data: data) { image in
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 12, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaCardSurface)
                                                .padding(8)
                                                .background(Color.arkInk.opacity(0.45), in: Circle())
                                                .padding(10)
                                        }
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                                        .fill(Color.ohanaCardSurface)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .fullScreenCover(isPresented: $showingPhoto) {
                                ZStack {
                                    Color.arkInk.ignoresSafeArea()
                                    AsyncDecodedImageView(data: data) { image in
                                        Image(uiImage: image).resizable().scaledToFit().ignoresSafeArea()
                                    } placeholder: {
                                        ProgressView()
                                            .tint(Color.ohanaCardSurface)
                                    }
                                    VStack { HStack { Spacer()
                                        Button { showingPhoto = false } label: {
                                            Image(systemName: "xmark.circle.fill").font(OhanaFont.adaptive(size: 28)).foregroundStyle(Color.ohanaCardSurface).padding(16) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        }
                                    }
                                    Spacer()
                                    }
                                }
                            }
                        }

                        // 地址（点击跳苹果地图）
                        if !milestone.location.isEmpty {
                            Button {
                                let encoded = milestone.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: OhanaRadius.badge).fill(Color.goYellow.opacity(0.15)).frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                        Image(systemName: "mappin.circle.fill").font(OhanaFont.adaptive(size: 18)).foregroundStyle(Color.goYellow) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("地址").font(OhanaFont.adaptive(size: 11, weight: .medium)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.4)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        Text(milestone.location).font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText).lineLimit(2) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square").font(OhanaFont.adaptive(size: 14)).foregroundStyle(Color.goYellow.opacity(0.7)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                }
                                .padding(14)
                                .goTranslucentCard(cornerRadius: OhanaRadius.control)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // 备注
                        if !milestone.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("备注", systemImage: "note.text")
                                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                Text(milestone.notes)
                                    .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .goTranslucentCard(cornerRadius: OhanaRadius.control)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("里程碑详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).foregroundStyle(Color.ohanaPrimaryText.opacity(0.6)) // a11y: allow decorative icon covered by surrounding text or control
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingDeleteAlert = true } label: {
                        Image(systemName: "trash").font(OhanaFont.adaptive(size: 14, weight: .semibold)).foregroundStyle(Color.goRed) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                }
            }
            .alert("删除里程碑？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    commandQueue.enqueue(.petMilestoneDelete(petID: pet.id, milestoneID: milestone.id)) {
                        PetMilestoneCommandExecutor(context: modelContext, services: appServices).deleteMilestone(
                            milestone,
                            pet: pet,
                            note: "petMilestone.delete"
                        )
                    }
                    dismiss()
                }
            } message: { Text("「\(milestone.title)」将被永久删除。") }
        }
    }
}
