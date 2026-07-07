//
//  DesignSpecVividGlassBackdrop.swift
//  Ohana
//
//  Extracted animated glass backdrop used by the design preview canvas.
//

import SwiftUI

struct DesignSpecVividGlassBackdrop: View {
    let mode: DesignPreviewModeV4
    let isVisible: Bool
    @ObservedObject var workloadPolicy: AppWorkloadPolicy

    var body: some View {
        Group {
            if workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible) {
                TimelineView(.animation) { timeline in // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                    DesignSpecVividGlassBackdropFrame(
                        mode: mode,
                        phase: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            } else {
                DesignSpecVividGlassBackdropFrame(mode: mode, phase: 0)
            }
        }
    }
}

private struct DesignSpecVividGlassBackdropFrame: View {
    let mode: DesignPreviewModeV4
    let phase: TimeInterval

    private var wave: Double {
        sin(phase * 0.34)
    }

    private var drift: Double {
        cos(phase * 0.26)
    }

    var body: some View {
        ZStack {
            Color(hex: mode == .dark ? "080B28" : "EAF7FF")
            VividGlassLineLayer(wave: wave, drift: drift)
            VividGlassCapsuleLayer(wave: wave, drift: drift)
            VividGlassDenseTextLayer(mode: mode, wave: wave, drift: drift)
            VividGlassAmbientTextLayer(mode: mode, wave: wave, drift: drift)
            VividGlassGlareLayer(wave: wave, drift: drift)
        }
        .animation(.linear(duration: 0.18), value: wave) // ui-v4: allow tiny continuous preview animation
    }
}

private struct VividGlassLineLayer: View {
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 16, id: \.self) { index in
            VividGlassLine(index: index, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassLine: View {
    let index: Int
    let wave: Double
    let drift: Double

    private var width: CGFloat {
        CGFloat(220 + (index % 4) * 42)
    }

    private var height: CGFloat {
        CGFloat(index % 3 == 0 ? 8 : 5)
    }

    private var xOffset: CGFloat {
        let baseOffset = CGFloat(index) * 36 - 240
        let waveOffset = CGFloat(wave) * 28
        let driftOffset = CGFloat(index % 4) * CGFloat(drift) * 8
        return baseOffset + waveOffset + driftOffset
    }

    private var yOffset: CGFloat {
        let baseOffset = CGFloat((index * 31) % 180) - 78
        return baseOffset + CGFloat(drift) * 22
    }

    var body: some View {
        RoundedRectangle(cornerRadius: OhanaRadius.pill, style: .continuous)
            .fill(vividGlassLineColor(index).opacity(index % 5 == 0 ? 0.96 : 0.78))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -23 : 18))
            .offset(x: xOffset, y: yOffset)
            .blur(radius: index % 6 == 0 ? 0.6 : 0)
    }
}

private struct VividGlassCapsuleLayer: View {
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 8, id: \.self) { index in
            VividGlassCapsule(index: index, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassCapsule: View {
    let index: Int
    let wave: Double
    let drift: Double

    private var size: CGSize {
        CGSize(width: CGFloat(72 + index * 16), height: CGFloat(22 + index * 5))
    }

    var body: some View {
        Capsule()
            .stroke(vividGlassLineColor(index + 8).opacity(0.55), lineWidth: 2)
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(Double(index * 17) + wave * 8))
            .offset(
                x: CGFloat(index * 28) - 110 + CGFloat(drift) * 18,
                y: CGFloat(index * 19) - 64
            )
    }
}

private struct VividGlassDenseTextLayer: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ZStack {
            VividGlassDenseRows(mode: mode, wave: wave, drift: drift)
            VividGlassVerticalRows(mode: mode, wave: wave, drift: drift)
        }
        .allowsHitTesting(false)
    }
}

private struct VividGlassDenseRows: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 15, id: \.self) { index in
            VividGlassDenseTextRow(index: index, mode: mode, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassDenseTextRow: View {
    let index: Int
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    private var foregroundColor: Color {
        vividGlassLineColor(index).opacity(mode == .dark ? 0.42 : 0.58)
    }

    var body: some View {
        Text(vividDenseGlassLine(index))
            .font(OhanaFont.adaptive(size: 8.5, weight: .black, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .frame(width: 520, alignment: .leading)
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.5 : 2.5))
            .offset(
                x: -210 + CGFloat(drift) * CGFloat(20 - index % 6),
                y: CGFloat(index * 15) - 112 + CGFloat(wave) * CGFloat(7 + index % 4)
            )
    }
}

private struct VividGlassVerticalRows: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 10, id: \.self) { index in
            VividGlassVerticalTextRow(index: index, mode: mode, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassVerticalTextRow: View {
    let index: Int
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Text(l.tr(zh: "0123456789  文字穿过玻璃  LENS", en: "0123456789  TEXT THROUGH GLASS  LENS"))
            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(Color.ohanaPrimaryActionText.opacity(mode == .dark ? 0.22 : 0.34)) // ui-v4: allow vivid glass lab text contrast
            .rotationEffect(.degrees(90))
            .offset(
                x: CGFloat(index * 40) - 184 + CGFloat(wave) * 10,
                y: CGFloat(drift) * 14
            )
    }
}

private struct VividGlassAmbientTextLayer: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ZStack {
            VividGlassPhraseRows(mode: mode, wave: wave, drift: drift)
            VividGlassLabelRows(mode: mode, wave: wave, drift: drift)
        }
        .allowsHitTesting(false)
    }
}

private struct VividGlassPhraseRows: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 9, id: \.self) { index in
            VividGlassPhraseTextRow(index: index, mode: mode, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassPhraseTextRow: View {
    let index: Int
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    private var fontSize: CGFloat {
        CGFloat(20 + (index % 5) * 4)
    }

    private var foregroundColor: Color {
        let baseColor = index.isMultiple(of: 2) ? Color.ohanaPrimaryActionText : Color(hex: "C9FF27")
        return baseColor.opacity(mode == .dark ? 0.33 : 0.46)
    }

    var body: some View {
        Text(vividGlassBackdropPhrase(index))
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(foregroundColor) // ui-v4: allow vivid glass lab text contrast
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 8))
            .offset(
                x: CGFloat(index * 43) - 178 + CGFloat(wave) * CGFloat(22 + index * 2),
                y: CGFloat((index * 31) % 184) - 90 + CGFloat(drift) * CGFloat(12 + index)
            )
            .blur(radius: index == 3 ? 0.35 : 0)
    }
}

private struct VividGlassLabelRows: View {
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    var body: some View {
        ForEach(0 ..< 14, id: \.self) { index in
            VividGlassLabelTextRow(index: index, mode: mode, wave: wave, drift: drift)
        }
    }
}

private struct VividGlassLabelTextRow: View {
    let index: Int
    let mode: DesignPreviewModeV4
    let wave: Double
    let drift: Double

    private var foregroundColor: Color {
        vividGlassLineColor(index + 2).opacity(mode == .dark ? 0.48 : 0.60)
    }

    var body: some View {
        Text("GLASS \(index + 1) · 12345 · UI")
            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(foregroundColor)
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? 17 : -14))
            .offset(
                x: CGFloat(index * 31) - 178 + CGFloat(drift) * 16,
                y: CGFloat((index * 21) % 184) - 92 + CGFloat(wave) * 11
            )
    }
}

private struct VividGlassGlareLayer: View {
    let wave: Double
    let drift: Double

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.ohanaPrimaryActionText.opacity(0.34), .clear], // ui-v4: allow vivid glass preview glare
                center: UnitPoint(x: 0.18 + 0.18 * CGFloat(drift), y: 0.12 + 0.10 * CGFloat(wave)),
                startRadius: 8,
                endRadius: 250
            )
            RadialGradient(
                colors: [Color(hex: "00E5FF").opacity(0.28), .clear],
                center: UnitPoint(x: 0.78 + 0.10 * CGFloat(wave), y: 0.22 + 0.16 * CGFloat(drift)),
                startRadius: 12,
                endRadius: 180
            )
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.20)], // ui-v4: allow vivid glass preview depth
                startPoint: .top,
                endPoint: .bottom
            )
            .hueRotation(.degrees(wave * 8))
        }
    }
}

private func vividDenseGlassLine(_ index: Int) -> String {
    switch index % 4 {
    case 0: "OHANA UI GLASS LAB  ·  文字穿过玻璃  ·  0123456789"
    case 1: "REFRACTION TEST  ·  CONTROL GAUSSIAN  ·  ABCDEFG"
    case 2: "深色浅色开关参数  ·  controlFill stroke accent"
    default: "LENS MAGNIFIER  ·  moving text behind sheet glass"
    }
}

private func vividGlassBackdropPhrase(_ index: Int) -> String {
    switch index % 5 {
    case 0: "OHANA GLASS"
    case 1: "高斯控件"
    case 2: "LENS TEST"
    case 3: "文字穿透"
    default: "REFRACTION"
    }
}

private func vividGlassLineColor(_ index: Int) -> Color {
    switch index % 6 {
    case 0: Color(hex: "00E5FF")
    case 1: Color(hex: "C9FF27")
    case 2: Color(hex: "FF3DA6")
    case 3: Color(hex: "7A3DFF")
    case 4: Color(hex: "FFB000")
    default: Color(hex: "35FFB5")
    }
}
