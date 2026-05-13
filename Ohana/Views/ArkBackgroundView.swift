//
//  ArkBackgroundView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import UIKit
import Foundation
import Combine

enum AppPerformanceMode {
    static let powerSavingKey = "appPowerSavingMode"

    static var systemPrefersReducedWork: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || UIAccessibility.isReduceMotionEnabled
    }
}

@MainActor
final class AppPerformanceMonitor: ObservableObject {
    struct Sample: Identifiable {
        let id = UUID()
        let name: String
        let valueMS: Double
        let timestamp: Date
        let note: String?
    }

    static let shared = AppPerformanceMonitor()

    @Published private(set) var samples: [Sample] = []
    private var starts: [String: CFAbsoluteTime] = [:]

    private init() {}

    func markStart(_ key: String) {
        starts[key] = CFAbsoluteTimeGetCurrent()
    }

    func markEnd(_ key: String, name: String, note: String? = nil) {
        guard let startedAt = starts.removeValue(forKey: key) else { return }
        record(name, startedAt: startedAt, note: note)
    }

    func record(_ name: String, startedAt: CFAbsoluteTime, note: String? = nil) {
        let elapsed = max(0, (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000)
        record(name, valueMS: elapsed, note: note)
    }

    func record(_ name: String, valueMS: Double, note: String? = nil) {
        samples.insert(Sample(name: name, valueMS: valueMS, timestamp: Date(), note: note), at: 0)
        if samples.count > 80 {
            samples.removeLast(samples.count - 80)
        }
    }

    func clear() {
        starts.removeAll()
        samples.removeAll()
    }
}

// MARK: - 背景风格枚举
enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case goDefault   = "go_default"
    /// GO Focus 首页同款：深蓝竖向渐变，可在子页复用。
    case goIsland    = "go_island"
    case cleanBlueGray = "clean_blue_gray"
    case deepAmbient = "deep_ambient"
    case aurora      = "aurora"
    case midnight    = "midnight"
    case sunsetGlow  = "sunset_glow"
    case sakuraMist  = "sakura_mist"
    case forestGlade = "forest_glade"
    case paperCream  = "paper_cream"
    case neonGrid    = "neon_grid"
    case customPhoto = "custom_photo"

    var id: String { rawValue }

    static var settingsOptions: [AppBackgroundStyle] {
        [.goIsland, .cleanBlueGray, .paperCream, .forestGlade, .deepAmbient, .customPhoto]
    }

    static var officialPairOptions: [AppBackgroundStyle] {
        [.goIsland, .cleanBlueGray, .paperCream, .forestGlade, .deepAmbient]
    }

    var displayName: String {
        switch self {
        case .goDefault:   return "Go 默认"
        case .goIsland:    return "GO 岛屿"
        case .cleanBlueGray: return "清爽蓝灰"
        case .deepAmbient: return "深邃光球"
        case .aurora:      return "极光"
        case .midnight:    return "午夜"
        case .sunsetGlow:  return "落日熔金"
        case .sakuraMist:  return "樱雾"
        case .forestGlade: return "森谷"
        case .paperCream:  return "暖纸"
        case .neonGrid:    return "霓虹格"
        case .customPhoto: return "自定义照片"
        }
    }

    func localizedName(_ lang: String) -> String {
        switch self {
        case .goIsland:
            return L10n(lang).tr(zh: "岛屿蓝", en: "Island Blue", de: "Inselblau")
        case .cleanBlueGray:
            return L10n(lang).tr(zh: "清爽天空", en: "Clear Sky", de: "Klarer Himmel")
        case .paperCream:
            return L10n(lang).tr(zh: "柔和纸面", en: "Soft Paper", de: "Weiches Papier")
        case .forestGlade:
            return L10n(lang).tr(zh: "森林浅雾", en: "Forest Mist", de: "Waldnebel")
        case .deepAmbient:
            return L10n(lang).tr(zh: "星云光感", en: "Nebula Glow", de: "Nebelglanz")
        case .customPhoto:
            return L10n(lang).tr(zh: "自定义照片", en: "Custom photo", de: "Eigenes Foto")
        default:
            return displayName
        }
    }

    func localizedSubtitle(_ lang: String) -> String {
        switch self {
        case .goIsland:
            return L10n(lang).tr(zh: "浅色蓝灰，深色深海", en: "Blue-gray light, deep ocean dark", de: "Blaugrau hell, Tiefsee dunkel")
        case .cleanBlueGray:
            return L10n(lang).tr(zh: "干净、冷静、适合日常", en: "Clean, calm, daily-use friendly", de: "Klar, ruhig, alltagstauglich")
        case .paperCream:
            return L10n(lang).tr(zh: "温暖柔和，阅读舒适", en: "Warm, soft, comfortable to read", de: "Warm, weich, angenehm lesbar")
        case .forestGlade:
            return L10n(lang).tr(zh: "自然、有氧、低压力", en: "Natural, airy, low-pressure", de: "Natürlich, luftig, entspannt")
        case .deepAmbient:
            return L10n(lang).tr(zh: "更酷的光感背景", en: "Cooler ambient light style", de: "Kühler Lichtstil")
        case .customPhoto:
            return L10n(lang).tr(zh: "上传一张全局背景", en: "Use your own app background", de: "Eigenes App-Hintergrundbild")
        default:
            return ""
        }
    }

    func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        switch self {
        case .goDefault:
            return colorScheme == .dark
                ? [Color(hex: "0A0A0C"), .goPrimary, .goBlue]
                : [Color(hex: "E7EFFC"), Color(hex: "D6E2F4"), Color(hex: "C8D8EF")]
        case .goIsland:
            return colorScheme == .dark
                ? [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")]
                : [Color(hex: "E6EEFB"), Color(hex: "D5E0F2"), Color(hex: "C8D6EA")]
        case .cleanBlueGray:
            return colorScheme == .dark
                ? [Color(hex: "0C1640"), Color(hex: "152560"), Color(hex: "081126")]
                : [Color(hex: "E1EBFA"), Color(hex: "D1DDEC"), Color(hex: "BFCDD8")]
        case .paperCream:
            return colorScheme == .dark
                ? [Color(hex: "1C1917"), Color(hex: "292524"), Color(hex: "1C1917")]
                : [Color(hex: "F4EEE5"), Color(hex: "E9DDCD"), Color(hex: "D9C7B3")]
        case .forestGlade:
            return colorScheme == .dark
                ? [Color(hex: "052E1F"), Color(hex: "064E3B"), Color(hex: "021B14")]
                : [Color(hex: "E2F0E8"), Color(hex: "D0E3D8"), Color(hex: "BFD5CB")]
        case .deepAmbient:
            return colorScheme == .dark
                ? [Color(hex: "030712"), Color(hex: "1D4ED8"), Color(hex: "6D28D9")]
                : [Color(hex: "E6EAFB"), Color(hex: "D8DDF4"), Color(hex: "C8D0EA")]
        case .aurora:
            return [Color(hex: "0A0A0C"), Color(hex: "00C9A7"), Color(hex: "845EC2")]
        case .midnight:
            return [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "21262D")]
        case .sunsetGlow:
            return [Color(hex: "1A0A12"), Color(hex: "FF6B35"), Color(hex: "FF8E9E")]
        case .sakuraMist:
            return [Color(hex: "120810"), Color(hex: "EC4899"), Color(hex: "A78BFA")]
        case .neonGrid:
            return [Color(hex: "050510"), Color(hex: "22D3EE"), Color(hex: "A855F7")]
        case .customPhoto:
            return colorScheme == .dark
                ? [Color(hex: "0F172A"), Color.goPrimary, Color(hex: "94A3B8")]
                : [Color(hex: "DDE8F6"), Color(hex: "BFD0E6"), Color(hex: "91A8C3")]
        }
    }

    var previewColors: [Color] {
        gradientColors(for: .dark)
    }
}

enum CustomAppBackgroundStore {
    private static let folderName = "Ohana"
    private static let fileName = "custom-background.jpg"

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(fileName)
    }

    static var image: UIImage? {
        UIImage(contentsOfFile: fileURL.path)
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func saveImageData(_ data: Data) throws {
        guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let optimized = optimizedBackgroundImage(image)
        guard let jpegData = optimized.jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpegData.write(to: fileURL, options: [.atomic])
    }

    static func deleteImage() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func optimizedBackgroundImage(_ image: UIImage) -> UIImage {
        let maxPixel: CGFloat = 2_400
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - ArkBackgroundView（根据用户设置切换背景风格）
struct ArkBackgroundView: View {
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage("appCustomBackgroundVersion") private var customBackgroundVersion = 0
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var style: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goDefault
    }

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    var body: some View {
        switch style {
        case .goDefault:   shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(GoDefaultBackground())
        case .goIsland:    GoIslandBackground()
        case .cleanBlueGray: CleanBlueGrayBackground()
        case .deepAmbient: shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(DeepAmbientBackground())
        case .aurora:      shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.previewColors)) : AnyView(AuroraBackground())
        case .midnight:    MidnightBackground()
        case .sunsetGlow:  shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.previewColors)) : AnyView(SunsetGlowBackground())
        case .sakuraMist:  shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.previewColors)) : AnyView(SakuraMistBackground())
        case .forestGlade: shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.gradientColors(for: colorScheme))) : AnyView(ForestGladeBackground())
        case .paperCream:  PaperCreamBackground()
        case .neonGrid:    shouldReduceWork ? AnyView(StaticGradientBackground(colors: style.previewColors)) : AnyView(NeonGridBackground())
        case .customPhoto: CustomPhotoBackground(version: customBackgroundVersion)
        }
    }
}

private struct StaticGradientBackground: View {
    let colors: [Color]

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay {
                NoiseTextureView()
                    .opacity(0.014)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
            }
    }
}

/// Single app-wide screen backdrop. Use this for full-screen views and sheets so
/// Settings > Background Style applies consistently across the app.
struct OhanaAppBackground: View {
    var body: some View {
        ArkBackgroundView()
            .ignoresSafeArea()
    }
}

// MARK: - 1. Go 默认（三球 Blob）
private struct GoDefaultBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    @State private var blob1Offset: CGSize = .zero
    @State private var blob2Offset: CGSize = .zero
    @State private var blob3Offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color(hex: isDark ? "0A0A0C" : "F0F4FF")
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(isDark ? 0.55 : 0.35))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -80 + blob1Offset.width, y: -160 + blob1Offset.height)

                Circle()
                    .fill(Color.goBlue.opacity(isDark ? 0.45 : 0.25))
                    .frame(width: 300)
                    .blur(radius: 90)
                    .offset(x: 110 + blob2Offset.width, y: 60 + blob2Offset.height)

                Circle()
                    .fill(Color.goPurple.opacity(isDark ? 0.55 : 0.30))
                    .frame(width: 220)
                    .blur(radius: 60)
                    .offset(x: -40 + blob3Offset.width, y: 280 + blob3Offset.height)
            }

            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blob1Offset = CGSize(width: 40, height: -30)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                blob2Offset = CGSize(width: -50, height: 35)
            }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                blob3Offset = CGSize(width: 30, height: -40)
            }
        }
    }
}

// MARK: - 1b. GO 岛屿（GO UI 首页壁纸 — 仅渐变 + 轻噪点，避免全 App 重复跑天气粒子 Timer）
private struct GoIslandBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")]
            : [Color(hex: "E6EEFB"), Color(hex: "D5E0F2"), Color(hex: "C8D6EA")]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.022 : 0.010)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct CleanBlueGrayBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "0C1640"), Color(hex: "152560"), Color(hex: "081126")]
                    : [Color(hex: "E1EBFA"), Color(hex: "D1DDEC"), Color(hex: "BFCDD8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.goBlue.opacity(colorScheme == .dark ? 0.16 : 0.14))
                .frame(width: 280)
                .blur(radius: 90)
                .offset(x: 110, y: -180)

            Circle()
                .fill(Color(hex: "64748B").opacity(colorScheme == .dark ? 0.18 : 0.13))
                .frame(width: 260)
                .blur(radius: 80)
                .offset(x: -120, y: 220)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.018 : 0.012)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct CustomPhotoBackground: View {
    let version: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = CustomAppBackgroundStore.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 22)
                        .overlay(readabilityOverlay)
                } else {
                    GoIslandBackground()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .id(version)
    }

    private var readabilityOverlay: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "020617").opacity(0.76), Color(hex: "0F172A").opacity(0.70), Color.black.opacity(0.78)]
                    : [Color(hex: "DDE8F6").opacity(0.68), Color(hex: "C7D4E7").opacity(0.62), Color(hex: "AEBFD4").opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(colorScheme == .dark ? 0.10 : 0.12)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.02 : 0.015)
                .blendMode(colorScheme == .dark ? .overlay : .multiply)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 2. 深邃光球（Dynamic Ambient — 用户提供的设计稿）
private struct DeepAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [Color(hex: "030712"), Color(hex: "0F172A"), Color(hex: "111827")]
                        : [Color(hex: "E6EAFB"), Color(hex: "D8DDF4"), Color(hex: "C8D0EA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: isDark ? "1D4ED8" : "93C5FD"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.40 : 0.30)
                    .offset(
                        x: isAnimating ? 150 : -100,
                        y: isAnimating ? -120 : 80
                    )
                    .scaleEffect(isAnimating ? 1.3 : 0.9)

                Circle()
                    .fill(Color(hex: isDark ? "6D28D9" : "C4B5FD"))
                    .frame(width: min(geo.size.width * 0.7, 500))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.35 : 0.28)
                    .offset(
                        x: isAnimating ? -150 : 80,
                        y: isAnimating ? 120 : -100
                    )
                    .scaleEffect(isAnimating ? 1.4 : 0.8)

                Circle()
                    .fill(Color(hex: isDark ? "0369A1" : "67E8F9"))
                    .frame(width: min(geo.size.width * 0.9, 700))
                    .blur(radius: 120)
                    .opacity(isDark ? 0.40 : 0.22)
                    .offset(
                        x: isAnimating ? 100 : -120,
                        y: isAnimating ? 150 : -100
                    )
                    .scaleEffect(isAnimating ? 1.2 : 0.9)

                Circle()
                    .fill(Color(hex: isDark ? "4338CA" : "818CF8"))
                    .frame(width: min(geo.size.width * 0.8, 600))
                    .blur(radius: 100)
                    .opacity(isDark ? 0.35 : 0.24)
                    .offset(
                        x: isAnimating ? -120 : 140,
                        y: isAnimating ? -140 : 110
                    )
                    .scaleEffect(isAnimating ? 0.9 : 1.4)

                NoiseTextureView()
                    .opacity(0.02)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 3. 极光
private struct AuroraBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "0A0A0C").ignoresSafeArea()

            ZStack {
                // 绿→青渐变条
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Color(hex: "00C9A7").opacity(0.5), Color(hex: "00B4D8").opacity(0.3)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 500, height: 120)
                    .blur(radius: 60)
                    .offset(y: -200 + phase * 30)
                    .rotationEffect(.degrees(Double(-15 + phase * 5)))

                // 紫色光带
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Color(hex: "845EC2").opacity(0.4), Color(hex: "D65DB1").opacity(0.25)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 450, height: 100)
                    .blur(radius: 50)
                    .offset(y: -140 + phase * 20)
                    .rotationEffect(.degrees(Double(10 - phase * 3)))

                // 青蓝色光条
                Ellipse()
                    .fill(Color(hex: "0096C7").opacity(0.3))
                    .frame(width: 380, height: 80)
                    .blur(radius: 45)
                    .offset(y: -100 + phase * 15)
                    .rotationEffect(.degrees(Double(-8 + phase * 4)))
            }

            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

// MARK: - 4. 午夜（纯深色 + 微光）
private struct MidnightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "0D1117")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 微光
            Circle()
                .fill(Color(hex: "30363D").opacity(0.3))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(y: -200)

            NoiseTextureView()
                .opacity(0.02)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - 5. 落日熔金
private struct SunsetGlowBackground: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(hex: "1A0A12").ignoresSafeArea()

            Circle()
                .fill(Color(hex: "FF6B35").opacity(0.45))
                .frame(width: 320)
                .blur(radius: 85)
                .offset(x: pulse ? 60 : -40, y: pulse ? -140 : -180)

            Circle()
                .fill(Color(hex: "FF8E9E").opacity(0.35))
                .frame(width: 280)
                .blur(radius: 75)
                .offset(x: pulse ? -80 : 20, y: pulse ? 200 : 160)

            Circle()
                .fill(Color(hex: "FBBF24").opacity(0.22))
                .frame(width: 240)
                .blur(radius: 70)
                .offset(x: 30, y: pulse ? 40 : 80)

            NoiseTextureView()
                .opacity(0.018)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - 6. 樱雾
private struct SakuraMistBackground: View {
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "120810").ignoresSafeArea()

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "EC4899").opacity(0.35), Color(hex: "A78BFA").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 420, height: 200)
                .blur(radius: 70)
                .offset(x: -40 + drift * 20, y: -160)

            Ellipse()
                .fill(Color(hex: "F472B6").opacity(0.22))
                .frame(width: 360, height: 160)
                .blur(radius: 60)
                .offset(x: 50 - drift * 15, y: 120)

            NoiseTextureView()
                .opacity(0.016)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = 1 }
        }
    }
}

// MARK: - 7. 森谷
private struct ForestGladeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var sway = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "052E1F") : Color(hex: "E8F5EF"))
                .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "059669").opacity(colorScheme == .dark ? 0.4 : 0.28))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: sway ? -70 : -100, y: -120)

            Circle()
                .fill(Color(hex: "34D399").opacity(colorScheme == .dark ? 0.28 : 0.22))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: sway ? 100 : 70, y: 180)

            Circle()
                .fill(Color(hex: "065F46").opacity(colorScheme == .dark ? 0.35 : 0.12))
                .frame(width: 340)
                .blur(radius: 90)
                .offset(y: sway ? 20 : -10)

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.02 : 0.012)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { sway = true }
        }
    }
}

// MARK: - 8. 暖纸（浅色偏暖 / 深色暖灰）
private struct PaperCreamBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: "1C1917"), Color(hex: "292524"), Color(hex: "1C1917")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "78716C").opacity(0.2))
                    .frame(width: 280)
                    .blur(radius: 75)
                    .offset(x: -60, y: -140)
            } else {
                LinearGradient(
                    colors: [Color(hex: "FAF7F2"), Color(hex: "F0E8DC"), Color(hex: "E8DDD0")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "D6C4B0").opacity(0.35))
                    .frame(width: 320)
                    .blur(radius: 90)
                    .offset(x: 80, y: -100)

                Circle()
                    .fill(Color(hex: "C9B8A4").opacity(0.2))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -100, y: 200)
            }

            NoiseTextureView()
                .opacity(colorScheme == .dark ? 0.025 : 0.035)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - 9. 霓虹格（暗色底 + 青紫光）
private struct NeonGridBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "050510").ignoresSafeArea()

            // 细网格感（低对比）
            Canvas { context, size in
                let step: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
            }
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "22D3EE").opacity(0.28))
                .frame(width: 280)
                .blur(radius: 75)
                .offset(x: -30 + phase * 40, y: -140 + phase * 20)

            Circle()
                .fill(Color(hex: "A855F7").opacity(0.26))
                .frame(width: 300)
                .blur(radius: 85)
                .offset(x: 40 - phase * 30, y: 160 - phase * 25)

            NoiseTextureView()
                .opacity(0.02)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}

// MARK: - GO 岛屿向导底（与 GO Focus 渐变 + 浮动色球一致）
/// 添加宠物 / 家庭成员等全屏向导使用，避免误用 `ArkBackgroundView` 的 `go_default` 浅色底。
struct GoIslandWizardBackdrop: View {
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blobPulse = false

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.goLime)
                        .frame(width: 260, height: 260)
                        .blur(radius: 80)
                        .opacity(shouldReduceWork ? 0.12 : 0.22)
                        .offset(x: blobPulse ? -50 : -70, y: blobPulse ? -70 : -90)

                    Circle()
                        .fill(Color(hex: "5B6AFF"))
                        .frame(width: 300, height: 300)
                        .blur(radius: 90)
                        .opacity(shouldReduceWork ? 0.20 : 0.40)
                        .offset(x: blobPulse ? geo.size.width - 80 : geo.size.width - 100,
                                y: blobPulse ? 180 : 220)

                    Circle()
                        .fill(Color(hex: "A855F7"))
                        .frame(width: 240, height: 240)
                        .blur(radius: 90)
                        .opacity(shouldReduceWork ? 0.14 : 0.30)
                        .offset(x: blobPulse ? -40 : -60,
                                y: blobPulse ? geo.size.height * 0.55 : geo.size.height * 0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            NoiseTextureView()
                .opacity(0.022)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !shouldReduceWork else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                blobPulse = true
            }
        }
    }
}

#Preview {
    ArkBackgroundView()
}
