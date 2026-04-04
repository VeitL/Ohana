//
//  PetMilestoneListView.swift
//  Ohana
//
//  FIX 7: 里程碑页面全面升级（照片 + 时间轴 UI）

import SwiftUI
import SwiftData
import PhotosUI
import MapKit

struct PetMilestoneListView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet  = false
    @State private var newTitle      = ""
    @State private var newEmoji      = "🎉"
    @State private var newDate       = Date()
    @State private var newNotes      = ""
    @State private var newLocation   = ""
    @State private var showingLocationPicker = false
    @State private var newPhotoItem: PhotosPickerItem? = nil
    @State private var newPhotoData: Data? = nil
    @State private var selectedMilestone: PetMilestone? = nil

    private var sortedMilestones: [PetMilestone] {
        pet.milestones.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView().ignoresSafeArea()

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
                    Image(systemName: "plus").font(.system(size: 14, weight: .black))
                    Text("记录里程碑")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
                .shadow(color: Color.goPrimary.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.bottom, 28)
        }
        .navigationTitle("里程碑")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { addMilestoneSheet }
        .sheet(item: $selectedMilestone) { m in MilestoneDetailSheet(milestone: m, pet: pet) }
        .onAppear { autoCreateMilestones() }
    }

    // MARK: - 自动生成里程碑（生日、到家日、最重/最轻体重）
    private func autoCreateMilestones() {
        let existingTitles = Set(pet.milestones.map { $0.title })

        // 生日
        if let bday = pet.birthday {
            let title = "\(pet.name)的生日 🎂"
            if !existingTitles.contains(title) {
                let m = PetMilestone(date: bday, title: title, emoji: "🎂",
                    notes: "出生啦！", pet: pet)
                modelContext.insert(m)
            }
        }

        // 到家日（领养/购买）
        if let homeDate = pet.homeDate {
            let title = "\(pet.name)到家了 🏠"
            if !existingTitles.contains(title) {
                let m = PetMilestone(date: homeDate, title: title, emoji: "🏠",
                    notes: "第一天回家!", pet: pet)
                modelContext.insert(m)
            }
        }

        // 最重体重记录
        if let heaviest = pet.weightLogs.max(by: { $0.weight < $1.weight }) {
            let title = "最重记录：\(String(format: "%.1f", heaviest.weight))kg"
            if !existingTitles.contains(title) {
                let m = PetMilestone(date: heaviest.date, title: title, emoji: "⚖️",
                    notes: "历史最高体重记录", pet: pet)
                modelContext.insert(m)
            }
        }

        modelContext.safeSave()
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 56, height: 56).clipShape(Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 2))
            } else {
                Text(pet.avatarEmoji).font(.system(size: 40))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(sortedMilestones.count) 个重要时刻")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
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
                            Rectangle().fill(.primary.opacity(0.1)).frame(width: 2, height: 16)
                        }
                        ZStack {
                            Circle()
                                .fill(pet.themeColor.color.opacity(0.3))
                                .frame(width: 36, height: 36)
                            Text(milestone.emoji).font(.system(size: 18))
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
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.25))
                            }
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                            if !milestone.location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.goYellow)
                                    Text(milestone.location)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.goYellow.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            if !milestone.notes.isEmpty {
                                Text(milestone.notes)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.primary.opacity(0.4))
                                    .lineLimit(1)
                            }
                            if let photoData = milestone.photoData, let img = UIImage(data: photoData) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌱").font(.system(size: 56))
            Text("还没有里程碑记录")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("记录 \(pet.name) 的每一个重要时刻")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Sheet（多巴胺深色渐变风格）
    private var addMilestoneSheet: some View {
        VStack(spacing: 0) {
                // 把手
                Capsule()
                    .fill(.primary.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 20)

                // 标题行
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Text("🎉").font(.system(size: 26))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记录里程碑")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(pet.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Emoji 快捷选
                        VStack(alignment: .leading, spacing: 8) {
                            Text("快捷 Emoji")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                                .padding(.horizontal, 4)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(["🎉","🏆","🌟","💉","✂️","🏠","✈️","🐾","❤️","🎂","🌈","💊","🦷","🏋️","🎓","🌱"], id: \.self) { e in
                                        Button { newEmoji = e } label: {
                                            Text(e).font(.system(size: 26))
                                                .frame(width: 46, height: 46)
                                                .glassEffect(newEmoji == e ? .regular.tint(Color.goPrimary.opacity(0.3)) : .regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Emoji + 标题
                        HStack(spacing: 12) {
                            TextField("🎉", text: $newEmoji)
                                .font(.system(size: 28))
                                .multilineTextAlignment(.center)
                                .frame(width: 56, height: 56)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.primary)
                            TextField("里程碑标题", text: $newTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .tint(Color.goPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 14)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .frame(maxWidth: .infinity)
                        }

                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.goPrimary)
                            Text("日期")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            DatePicker("", selection: $newDate, displayedComponents: .date)
                                .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // 地址选择 (地图搜索)
                        Button {
                            showingLocationPicker = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.goYellow)
                                if newLocation.isEmpty {
                                    Text("地点（点此从地图选择）")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary.opacity(0.4))
                                } else {
                                    Text(newLocation)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.25))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        // 备注
                        TextField("备注（可选）", text: $newNotes, axis: .vertical)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .tint(Color.goPrimary)
                            .lineLimit(3...5)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // 照片选择
                        PhotosPicker(selection: $newPhotoItem, matching: .images) {
                            if let data = newPhotoData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            newPhotoData = nil
                                            newPhotoItem = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(.white)
                                                .padding(8)
                                        }
                                    }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.goPrimary)
                                    Text("添加照片（可选）")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.goPrimary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
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

                // 保存按钮（渐变）
                Button {
                    guard !newTitle.isEmpty else { return }
                    let m = PetMilestone(
                        date: newDate,
                        title: newTitle,
                        emoji: newEmoji.isEmpty ? "🎉" : newEmoji,
                        notes: newNotes,
                        pet: pet,
                        photoData: newPhotoData,
                        location: newLocation
                    )
                    modelContext.insert(m)
                    modelContext.safeSave()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    newTitle = ""; newEmoji = "🎉"; newNotes = ""; newLocation = ""
                    newPhotoData = nil; newPhotoItem = nil
                    showAddSheet = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .black))
                        Text("保存里程碑").font(.system(size: 16, weight: .black, design: .rounded))
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
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .shadow(color: newTitle.isEmpty ? .clear : Color.goPrimary.opacity(0.4), radius: 10, y: 4)
                }
                .disabled(newTitle.isEmpty)
                .padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
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

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("搜索地点、医院、公园…", text: $searchText)
                            .foregroundStyle(.primary)
                            .tint(Color.goYellow)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }
                        if !searchText.isEmpty {
                            Button { searchText = ""; results = [] } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    if isSearching {
                        ProgressView()
                            .tint(Color.goYellow)
                            .padding(.top, 40)
                        Spacer()
                    } else if results.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.slash").font(.system(size: 36)).foregroundStyle(.primary.opacity(0.3))
                            Text("没有找到匹配地点")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                        }.padding(.top, 60)
                        Spacer()
                    } else if results.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 36)).foregroundStyle(Color.goYellow.opacity(0.4))
                            Text("输入地名开始搜索")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.4))
                        }.padding(.top, 60)
                        Spacer()
                    } else {
                        List(results, id: \.self) { item in
                            Button {
                                selectedLocation = item.name ?? item.placemark.title ?? ""
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知地点")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    if let addr = item.placemark.title, addr != item.name {
                                        Text(addr)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
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
                        Button("搜索") { performSearch() }
                            .foregroundStyle(Color.goYellow)
                            .fontWeight(.bold)
                    }
                }
            }
            .onChange(of: searchText) { _, new in
                if new.count >= 2 { performSearch() }
                else if new.isEmpty { results = [] }
            }
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: req)
        search.start { resp, _ in
            DispatchQueue.main.async {
                isSearching = false
                results = resp?.mapItems ?? []
            }
        }
    }
}

// MARK: - P6: 里程碑详情页
private struct MilestoneDetailSheet: View {
    let milestone: PetMilestone
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingPhoto = false
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 头部 Emoji + 标题 + 日期
                        VStack(spacing: 10) {
                            Text(milestone.emoji).font(.system(size: 56))
                            Text(milestone.title)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .glassEffect(.regular, in: Capsule())
                        }
                        .padding(.top, 8)

                        // 照片（可点击全屏预览）
                        if let data = milestone.photoData, let img = UIImage(data: data) {
                            Button { showingPhoto = true } label: {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.black.opacity(0.45), in: Circle())
                                            .padding(10)
                                    }
                            }
                            .buttonStyle(.plain)
                            .fullScreenCover(isPresented: $showingPhoto) {
                                ZStack {
                                    Color.black.ignoresSafeArea()
                                    Image(uiImage: img).resizable().scaledToFit().ignoresSafeArea()
                                    VStack { HStack { Spacer(); Button { showingPhoto = false } label: {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(.white).padding(16)
                                    }}; Spacer() }
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
                                        RoundedRectangle(cornerRadius: 10).fill(Color.goYellow.opacity(0.15)).frame(width: 36, height: 36)
                                        Image(systemName: "mappin.circle.fill").font(.system(size: 18)).foregroundStyle(Color.goYellow)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("地址").font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.4))
                                        Text(milestone.location).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square").font(.system(size: 14)).foregroundStyle(Color.goYellow.opacity(0.7))
                                }
                                .padding(14)
                                .goTranslucentCard(cornerRadius: 16)
                            }
                            .buttonStyle(.plain)
                        }

                        // 备注
                        if !milestone.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("备注", systemImage: "note.text")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Text(milestone.notes)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .goTranslucentCard(cornerRadius: 16)
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
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).foregroundStyle(.primary.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingDeleteAlert = true } label: {
                        Image(systemName: "trash").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.goRed)
                    }
                }
            }
            .alert("删除里程碑？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    modelContext.delete(milestone)
                    modelContext.safeSave()
                    dismiss()
                }
            } message: { Text("「\(milestone.title)」将被永久删除。") }
        }
    }
}
