//
//  DesignSpecPaletteV4.swift
//  Ohana
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DesignSpecPaletteV4 {
    let selection: DesignSpecSelectionV4
    let mode: DesignPreviewModeV4

    var isDark: Bool { mode == .dark }

    var accent: Color {
        switch selection.accent {
        case "blue": return Color.goBlue
        case "coral": return Color.goOrange
        case "violet": return Color.goPurple
        default: return isDark ? Color.goPrimary : Color.goBlue
        }
    }

    var secondaryAccent: Color {
        switch selection.accent {
        case "blue": return Color.goTeal
        case "coral": return Color.goYellow
        case "violet": return Color.goBlue
        default: return isDark ? Color.goTeal : Color.goTeal
        }
    }

    var accentText: Color {
        if selection.accent == "blue" || selection.accent == "violet" { return .white }
        if selection.accent == "lime" && !isDark { return .white }
        return Color.arkInk
    }

    var resolvedAccentName: String {
        switch selection.accent {
        case "blue": return "blue"
        case "coral": return "coral"
        case "violet": return "violet"
        default: return isDark ? "lime" : "blue"
        }
    }

    var background: Color {
        if isDark {
            switch selection.background {
            case "deep": return Color(hex: "100B2E")
            case "plain": return Color(hex: "10131A")
            default: return Color.goDeepNavy
            }
        } else {
            switch selection.background {
            case "soft": return Color(hex: "F4F7FF")
            case "plain": return Color(hex: "F7F8FB")
            default: return Color(hex: "EEF2FF")
            }
        }
    }

    var primaryText: Color { isDark ? .white : Color(hex: "101424") }
    var secondaryText: Color { isDark ? .white.opacity(0.66) : Color(hex: "303750").opacity(0.70) }
    var tertiaryText: Color { isDark ? .white.opacity(0.46) : Color(hex: "303750").opacity(0.48) }
    var stroke: Color { isDark ? .white.opacity(0.14) : .black.opacity(0.075) }
    var fieldFill: Color { isDark ? .white.opacity(0.09) : .black.opacity(0.045) }
    var controlFill: Color { isDark ? .white.opacity(0.08) : .white.opacity(0.74) }
    var cardFill: Color { isDark ? .white.opacity(0.075) : .white.opacity(0.62) }
    var solidCard: Color { isDark ? Color(hex: "171B2A") : .white }
    var flatBlock: Color { isDark ? Color(hex: "1A2030") : Color(hex: "EEF1F6") }
    var flatField: Color { isDark ? Color(hex: "202638") : Color(hex: "E9EDF4") }
    var warning: Color { Color.goYellow }
    var success: Color { Color.goTeal }
    var danger: Color { Color.goRed }

    var resolvedTokenSummary: [String: String] {
        [
            "mode": mode.rawValue,
            "accent": selection.accent,
            "resolvedAccent": resolvedAccentName,
            "background": isDark ? "darkBackground" : "lightBackground",
            "primaryText": isDark ? "white" : "#101424",
            "secondaryText": isDark ? "white 66%" : "#303750 70%",
            "stroke": isDark ? "white 14%" : "black 7.5%"
        ]
    }
}

enum DesignSpecButtonKindV4 {
    case primary
    case secondary
    case destructive
    case icon
    case ghost
}

struct DesignSpecTokenButtonStyleV4: ButtonStyle {
    let kind: DesignSpecButtonKindV4
    let palette: DesignSpecPaletteV4
    let selection: DesignSpecSelectionV4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: kind == .icon ? 13 : 13, weight: kind == .primary ? .black : .bold, design: fontDesign))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .icon ? 10 : 14)
            .padding(.vertical, selection.button == "compact" ? 9 : 11)
            .frame(minHeight: kind == .icon ? 36 : 42)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .brightness(configuration.isPressed && selection.tap == "bright" ? 0.08 : 0)
            .modifier(
                OhanaButtonPressFeedbackModifier(
                    isPressed: configuration.isPressed,
                    isEnabled: true,
                    pressedScale: 1,
                    pressedOffset: 0,
                    pressedOpacity: 1,
                    addsDepth: false
                )
            )
            .animation(buttonAnimation, value: configuration.isPressed)
    }

    private var radius: CGFloat {
        switch selection.button {
        case "round": return 14
        case "square": return 10
        default: return 999
        }
    }

    private var pressScale: CGFloat {
        switch selection.tap {
        case "tiny": return 0.985
        case "deep": return 0.93
        default: return 0.96
        }
    }

    private var fontDesign: Font.Design {
        selection.type == "mono" ? .monospaced : .rounded
    }

    private var buttonAnimation: Animation {
        switch selection.tap {
        case "tiny": return .easeOut(duration: 0.12)
        case "deep": return .spring(response: 0.22, dampingFraction: 0.66)
        default: return .spring(response: 0.2, dampingFraction: 0.72)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return palette.accentText
        case .destructive: return Color.goRed
        default: return palette.primaryText
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return palette.accent
        case .destructive: return Color.goRed.opacity(0.12)
        case .ghost: return .clear
        default: return palette.controlFill
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: return .clear
        case .destructive: return Color.goRed.opacity(0.26)
        case .ghost: return .clear
        default: return palette.stroke
        }
    }
}

enum DesignSpecUIV4 {
    static func typeFont(_ size: CGFloat, weight: Font.Weight, selection: DesignSpecSelectionV4) -> Font {
        let adjusted: CGFloat
        switch selection.type {
        case "compact": adjusted = size * 0.96
        case "editorial": adjusted = size * 1.06
        default: adjusted = size
        }
        let design: Font.Design = selection.type == "mono" ? .monospaced : .rounded
        return .system(size: adjusted, weight: weight, design: design)
    }

    static func density(_ compact: CGFloat, _ balanced: CGFloat, _ airy: CGFloat, selection: DesignSpecSelectionV4) -> CGFloat {
        switch selection.density {
        case "compact": return compact
        case "airy": return airy
        default: return balanced
        }
    }

    static func iconName(_ icon: String, selection: DesignSpecSelectionV4) -> String {
        selection.icon == "monochromePrimary" ? icon : icon.replacingOccurrences(of: ".fill", with: "")
    }

    static func iconWeight(_ selection: DesignSpecSelectionV4) -> Font.Weight {
        selection.icon == "monochromePrimary" ? .semibold : .medium
    }

    static func motionAnimation(_ selection: DesignSpecSelectionV4) -> Animation {
        switch selection.motion {
        case "reduced": return .easeOut(duration: 0.12)
        case "quick": return .easeOut(duration: 0.18)
        case "playful": return .spring(response: 0.34, dampingFraction: 0.58)
        default: return .spring(response: 0.28, dampingFraction: 0.72)
        }
    }

    static func controlChangeAnimation(_ selection: DesignSpecSelectionV4) -> Animation {
        switch selection.motion {
        case "reduced": return .easeInOut(duration: 0.14)
        case "quick": return .spring(response: 0.20, dampingFraction: 0.82)
        case "playful": return .spring(response: 0.34, dampingFraction: 0.56)
        default: return .spring(response: 0.26, dampingFraction: 0.74)
        }
    }

    static func cardRadius(_ selection: DesignSpecSelectionV4) -> CGFloat {
        switch selection.card {
        case "solid": return 17
        case "flat": return 16
        case "elevated": return 24
        default: return 21
        }
    }

    static func innerRadius(_ selection: DesignSpecSelectionV4) -> CGFloat {
        max(12, cardRadius(selection) - 7)
    }

    static func glassOpacity(_ selection: DesignSpecSelectionV4) -> Double {
        switch selection.glass {
        case "refractive": return 0.08
        case "nativeRegular": return 0.0
        case "calendarWidget": return 0.46
        case "clear": return 0.0
        case "edgePrism": return 0.12
        default: return 0.72
        }
    }

    static func sheetOpacity(_ selection: DesignSpecSelectionV4) -> Double {
        switch selection.sheetTransparency {
        case "clear": return 0.58
        case "frosted": return 0.92
        case "solid": return 1
        default: return 0.78
        }
    }

    static func fieldRadius(_ selection: DesignSpecSelectionV4) -> CGFloat {
        switch selection.input {
        case "underline": return 7
        case "compact": return 12
        case "flat": return 14
        default: return innerRadius(selection)
        }
    }

    static func fieldFill(selection: DesignSpecSelectionV4, palette: DesignSpecPaletteV4) -> Color {
        switch selection.input {
        case "filled": return palette.controlFill
        case "flat": return palette.flatField
        case "underline": return .clear
        default: return palette.fieldFill
        }
    }

    static func triggerHaptic(_ selection: DesignSpecSelectionV4) {
        #if canImport(UIKit)
        switch selection.haptic {
        case "off":
            break
        case "rigid":
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        #endif
    }
}
