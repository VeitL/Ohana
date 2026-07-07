//
//  SitterCardPreviewSheet.swift
//  Ohana
//
//  寄养名片：一页纸宠物信息 + 截图分享

import SwiftData
import SwiftUI

struct SitterCardPreviewSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var shareImage: UIImage? = nil
    @State private var isSharing = false
    @State private var isRendering = false
    @State private var latestWeight: PetProfileLatestWeight?
    @State private var latestWeightLoadTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        sitterCard
                            .padding(.horizontal, 16)
                        Text(l.tr(
                            zh: "点击右上角分享按钮，将名片发给宠物保姆",
                            en: "Tap the share button in the top right to send this card to a sitter.",
                            de: "Tippe oben rechts auf Teilen, um die Karte an den Sitter zu senden."
                        ))
                            .font(OhanaFont.adaptive(size: 12, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(l.tr(zh: "寄养名片", en: "Sitter card", de: "Sitter-Karte"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schliessen")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await renderAndShare() }
                    } label: {
                        if isRendering {
                            ProgressView().tint(Color.goPrimary).scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 15, weight: .semibold))
                                .foregroundStyle(Color.goPrimary)
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
            .onAppear {
                scheduleLatestWeightLoad()
            }
            .onDisappear {
                latestWeightLoadTask?.cancel()
                latestWeightLoadTask = nil
            }
        }
    }

    // MARK: - Sitter Card View
    private var sitterCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：头像 + 名字 + 物种
            HStack(spacing: 16) {
                PetAvatarPortraitView(
                    pet: pet,
                    fallbackText: pet.avatarEmoji,
                    themeColor: Color(hex: pet.safeThemeColorHex),
                    size: 72,
                    backgroundOpacity: 0.25,
                    transparentScale: 0.78
                )
                .overlay(Circle().strokeBorder(Color(hex: pet.safeThemeColorHex).opacity(0.5), lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    HStack(spacing: 6) {
                        capsuleTag(pet.localizedSpeciesName(l: l))
                        if !pet.breed.isEmpty { capsuleTag(pet.breed) }
                        capsuleTag(pet.genderSymbol + (pet.isNeutered ? " " + l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert") : ""))
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
                              label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"),
                              value: birthday.formatted(.dateTime.year().month().day()) + " · \(pet.ageText)")
                    GoDashedDivider().padding(.leading, 52)
                }
                if let homeDate = pet.homeDate {
                    sitterRow(icon: "house.fill", color: Color.goMint,
                              label: l.tr(zh: "到家日", en: "Home date", de: "Einzug"),
                              value: homeDate.formatted(.dateTime.year().month().day()) + " · " + l.tr(zh: "\(pet.daysTogether) 天", en: "\(pet.daysTogether) days", de: "\(pet.daysTogether) Tage"))
                    GoDashedDivider().padding(.leading, 52)
                }
                if let latestWeight {
                    sitterRow(icon: "scalemass.fill", color: Color.goCardCyan,
                              label: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                              value: latestWeight.compactText(fractionDigits: 1, unitSpacing: " "))
                    GoDashedDivider().padding(.leading, 52)
                }
                if !pet.birthCountry.isEmpty {
                    sitterRow(icon: "globe", color: Color.goMint,
                              label: l.tr(zh: "出生地", en: "Birthplace", de: "Geburtsort"),
                              value: pet.birthCountry + (pet.birthCity.isEmpty ? "" : " · \(pet.birthCity)"))
                    GoDashedDivider().padding(.leading, 52)
                }
                sitterRow(icon: "fork.knife", color: Color.goOrange,
                          label: l.tr(zh: "每日喂食", en: "Daily food", de: "Taegliches Futter"),
                          value: pet.dailyPortionGrams > 0
                              ? "\(Int(pet.dailyPortionGrams))g · \(pet.foodBrand.isEmpty ? l.tr(zh: "未填写品牌", en: "No brand added", de: "Keine Marke angegeben") : pet.foodBrand)"
                              : l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            GoDashedDivider().padding(.horizontal, 16)

            // 医疗信息区
            VStack(spacing: 0) {
                if !pet.vetContact.isEmpty {
                    sitterRow(icon: "cross.circle.fill", color: Color.goRed,
                              label: l.tr(zh: "兽医联系", en: "Vet contact", de: "Tierarztkontakt"), value: pet.vetContact)
                    GoDashedDivider().padding(.leading, 52)
                }
                sitterRow(icon: "exclamationmark.shield.fill", color: Color.goRed,
                          label: l.tr(zh: "过敏原", en: "Allergies", de: "Allergien"),
                          value: pet.allergies.isEmpty ? l.tr(zh: "无已知过敏原", en: "No known allergies", de: "Keine bekannten Allergien") : pet.allergies)
                if !pet.microchipID.isEmpty {
                    GoDashedDivider().padding(.leading, 52)
                    sitterRow(icon: "cpu.fill", color: Color.goCardCyan,
                              label: l.tr(zh: "芯片号", en: "Microchip ID", de: "Mikrochip-ID"), value: pet.microchipID)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 备注
            if !pet.notes.isEmpty {
                GoDashedDivider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 6) {
                    Label(l.tr(zh: "特别说明", en: "Special notes", de: "Besondere Hinweise"), systemImage: "note.text")
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    Text(pet.notes)
                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // 底部 Ohana 品牌水印
            HStack {
                Spacer()
                Text(l.tr(zh: "由 Ohana 生成 🏝️", en: "Made with Ohana 🏝️", de: "Erstellt mit Ohana 🏝️"))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
                    .padding(.bottom, 16)
                    .padding(.trailing, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "2A1F6B"), Color(hex: "1A0E4B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color(hex: pet.themeColorHex).opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }

    // MARK: - Row Builder
    private func sitterRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(OhanaFont.adaptive(size: 12, weight: .medium))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func capsuleTag(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .goGlassBackground(Capsule())
    }

    // MARK: - Share
    private func scheduleLatestWeightLoad() {
        latestWeightLoadTask?.cancel()
        let petID = pet.id
        latestWeightLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            latestWeight = PetBasicInfoHealthSummary.latestWeight(petID: petID, context: modelContext)
            latestWeightLoadTask = nil
        }
    }

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
