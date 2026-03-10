//
//  SitterCardPreviewSheet.swift
//  Ohana
//
//  寄养名片：一页纸宠物信息 + 截图分享

import SwiftUI

struct SitterCardPreviewSheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage? = nil
    @State private var isSharing = false
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 16) {
                        sitterCard
                            .padding(.horizontal, 16)
                        Text("点击右上角分享按钮，将名片发给宠物保姆")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("🏷️ 寄养名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await renderAndShare() }
                    } label: {
                        if isRendering {
                            ProgressView().tint(Color.goLime).scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.goLime)
                        }
                    }
                    .disabled(isRendering)
                }
            }
            .sheet(isPresented: $isSharing) {
                if let img = shareImage {
                    ShareSheet(image: img)
                }
            }
        }
    }

    // MARK: - Sitter Card View
    private var sitterCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：头像 + 名字 + 物种
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: pet.themeColorHex).opacity(0.25))
                        .frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(Color(hex: pet.themeColorHex).opacity(0.5), lineWidth: 2))
                    if let data = pet.avatarImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    } else {
                        Text(pet.avatarEmoji).font(.system(size: 36))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        capsuleTag(pet.species)
                        if !pet.breed.isEmpty { capsuleTag(pet.breed) }
                        capsuleTag(pet.genderSymbol + (pet.isNeutered ? " 已绝育" : ""))
                    }
                }
                Spacer()
            }
            .padding(20)

            GoDashedDivider().padding(.horizontal, 16)

            // 基本信息区
            VStack(spacing: 0) {
                if let birthday = pet.birthday {
                    sitterRow(icon: "birthday.cake.fill", color: Color.goYellow,
                              label: "生日",
                              value: birthday.formatted(.dateTime.year().month().day()) + " · \(pet.ageText)")
                    GoDashedDivider().padding(.leading, 52)
                }
                if let homeDate = pet.homeDate {
                    sitterRow(icon: "house.fill", color: Color.goMint,
                              label: "到家日",
                              value: homeDate.formatted(.dateTime.year().month().day()) + " · \(pet.daysTogether) 天")
                    GoDashedDivider().padding(.leading, 52)
                }
                if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                    sitterRow(icon: "scalemass.fill", color: Color.goCardCyan,
                              label: "体重",
                              value: String(format: "%.1f kg", w.weight) + " · " + w.date.formatted(.dateTime.year().month().day()))
                    GoDashedDivider().padding(.leading, 52)
                }
                if !pet.birthCountry.isEmpty {
                    sitterRow(icon: "globe", color: Color.goMint,
                              label: "出生地",
                              value: pet.birthCountry + (pet.birthCity.isEmpty ? "" : " · \(pet.birthCity)"))
                    GoDashedDivider().padding(.leading, 52)
                }
                sitterRow(icon: "fork.knife", color: Color.goOrange,
                          label: "每日喂食",
                          value: pet.dailyPortionGrams > 0
                              ? "\(Int(pet.dailyPortionGrams))g · \(pet.foodBrand.isEmpty ? "未填写品牌" : pet.foodBrand)"
                              : "未设置")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            GoDashedDivider().padding(.horizontal, 16)

            // 医疗信息区
            VStack(spacing: 0) {
                if !pet.vetContact.isEmpty {
                    sitterRow(icon: "cross.circle.fill", color: Color.goRed,
                              label: "兽医联系", value: pet.vetContact)
                    GoDashedDivider().padding(.leading, 52)
                }
                sitterRow(icon: "exclamationmark.shield.fill", color: Color.goRed,
                          label: "过敏原",
                          value: pet.allergies.isEmpty ? "无已知过敏原" : pet.allergies)
                if !pet.microchipID.isEmpty {
                    GoDashedDivider().padding(.leading, 52)
                    sitterRow(icon: "cpu.fill", color: Color.goCardCyan,
                              label: "芯片号", value: pet.microchipID)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 备注
            if !pet.notes.isEmpty {
                GoDashedDivider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 6) {
                    Label("特别说明", systemImage: "note.text")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                    Text(pet.notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // 底部 Ohana 品牌水印
            HStack {
                Spacer()
                Text("Made with Ohana 🏝️")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.2))
                    .padding(.bottom, 16)
                    .padding(.trailing, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "2A1F6B"), Color(hex: "1A0E4B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(hex: pet.themeColorHex).opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    // MARK: - Row Builder
    private func sitterRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func capsuleTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.white.opacity(0.1), in: Capsule())
    }

    // MARK: - Share
    @MainActor
    private func renderAndShare() async {
        isRendering = true
        defer { isRendering = false }
        let renderer = ImageRenderer(content:
            sitterCard
                .frame(width: 360)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        if let img = renderer.uiImage {
            shareImage = img
            isSharing = true
        }
    }
}
