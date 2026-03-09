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
                .background(Color.goLime, in: Capsule())
                .shadow(color: Color.goLime.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.bottom, 28)
        }
        .navigationTitle("里程碑")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) { addMilestoneSheet }
        .sheet(item: $selectedMilestone) { m in MilestoneDetailSheet(milestone: m, pet: pet) }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 56, height: 56).clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2))
            } else {
                Text(pet.avatarEmoji).font(.system(size: 40))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(sortedMilestones.count) 个重要时刻")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
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
                            Rectangle().fill(.white.opacity(0.1)).frame(width: 2, height: 16)
                        }
                        ZStack {
                            Circle()
                                .fill(pet.themeColor.color.opacity(0.3))
                                .frame(width: 36, height: 36)
                            Text(milestone.emoji).font(.system(size: 18))
                        }
                        if idx < sortedMilestones.count - 1 {
                            Rectangle().fill(.white.opacity(0.1)).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 36)

                    // 内容卡（点击进详情）
                    Button { selectedMilestone = milestone } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(milestone.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
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
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(2)
                            }
                            if let photoData = milestone.photoData, let img = UIImage(data: photoData) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08), lineWidth: 1))
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
                .foregroundStyle(.white)
            Text("记录 \(pet.name) 的每一个重要时刻")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Add Sheet（多巴胺深色渐变风格）
    private var addMilestoneSheet: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [Color.goDarkBlue, Color(hex: "1a1060"), Color.goPrimary.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            // 装饰圆
            Circle()
                .fill(Color.goLime.opacity(0.07))
                .frame(width: 260)
                .offset(x: 100, y: -130)
                .blur(radius: 40)

            VStack(spacing: 0) {
                // 把手
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12).padding(.bottom, 20)

                // 标题行
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.goLime.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Text("🎉").font(.system(size: 26))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记录里程碑")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(pet.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
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
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal, 4)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(["🎉","🏆","🌟","💉","✂️","🏠","✈️","🐾","❤️","🎂","🌈","💊","🦷","🏋️","🎓","🌱"], id: \.self) { e in
                                        Button { newEmoji = e } label: {
                                            Text(e).font(.system(size: 26))
                                                .frame(width: 46, height: 46)
                                                .background(newEmoji == e ? Color.goLime.opacity(0.25) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(newEmoji == e ? Color.goLime.opacity(0.6) : .white.opacity(0.12), lineWidth: 1))
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
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 1))
                                .foregroundStyle(.white)
                            TextField("里程碑标题", text: $newTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .tint(Color.goLime)
                                .padding(.horizontal, 14).padding(.vertical, 14)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(newTitle.isEmpty ? .white.opacity(0.12) : Color.goLime.opacity(0.5), lineWidth: 1))
                                .frame(maxWidth: .infinity)
                        }

                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.goLime)
                            Text("日期")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            DatePicker("", selection: $newDate, displayedComponents: .date)
                                .datePickerStyle(.compact).tint(Color.goLime).labelsHidden()
                                .colorScheme(.dark)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1))

                        // 地址
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.goYellow)
                            TextField("地址（可选）", text: $newLocation)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .tint(Color.goYellow)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 1))

                        // 备注
                        TextField("备注（可选）", text: $newNotes, axis: .vertical)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .tint(Color.goLime)
                            .lineLimit(3...5)
                            .padding(14)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1))

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
                                        .foregroundStyle(Color.goLime)
                                    Text("添加照片（可选）")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.goLime)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.goLime.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.goLime.opacity(0.3), lineWidth: 1))
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
                    .foregroundStyle(newTitle.isEmpty ? .white.opacity(0.4) : Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: newTitle.isEmpty
                                ? [Color.goLime.opacity(0.25), Color.goLime.opacity(0.15)]
                                : [Color.goLime, Color(hex: "A8E44A")],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .shadow(color: newTitle.isEmpty ? .clear : Color.goLime.opacity(0.4), radius: 10, y: 4)
                }
                .disabled(newTitle.isEmpty)
                .padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 8)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
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
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(milestone.date, format: .dateTime.year().month().day())
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .background(.white.opacity(0.08), in: Capsule())
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
                                        Text("地址").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                                        Text(milestone.location).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
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
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(milestone.notes)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
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
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).foregroundStyle(.white.opacity(0.6))
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
