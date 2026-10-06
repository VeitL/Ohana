//
//  OhanaFont.swift
//  Ohana
//

import SwiftUI

// MARK: - Rounded semantic type with a warm, stronger hierarchy
enum OhanaFont {
    static func adaptive(
        size: CGFloat,
        weight: Font.Weight = .medium,
        design: Font.Design = .rounded
    ) -> Font {
        let style: Font.TextStyle = switch size {
        case ..<11:
            .caption2
        case ..<13:
            .caption
        case ..<15:
            .footnote
        case ..<17:
            .callout
        case ..<20:
            .headline
        case ..<23:
            .title3
        case ..<28:
            .title2
        case ..<34:
            .title
        default:
            .largeTitle
        }
        return .system(style, design: design).weight(weight)
    }

    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .rounded).weight(weight == .semibold ? .bold : weight)
    }

    static func title(_ weight: Font.Weight = .bold) -> Font {
        .system(.title, design: .rounded).weight(weight == .semibold ? .bold : weight)
    }

    static func title2(_ weight: Font.Weight = .bold) -> Font {
        .system(.title2, design: .rounded).weight(weight == .semibold ? .bold : weight)
    }

    static func title3(_ weight: Font.Weight = .bold) -> Font {
        .system(.title3, design: .rounded).weight(weight == .semibold ? .bold : weight)
    }

    static func headline(_ weight: Font.Weight = .bold) -> Font {
        .system(.headline, design: .rounded).weight(weight == .semibold ? .bold : weight)
    }

    static func body(_ weight: Font.Weight = .medium) -> Font {
        .system(.body, design: .rounded).weight(weight)
    }

    static func callout(_ weight: Font.Weight = .medium) -> Font {
        .system(.callout, design: .rounded).weight(weight)
    }

    static func subheadline(_ weight: Font.Weight = .medium) -> Font {
        .system(.subheadline, design: .rounded).weight(weight)
    }

    static func footnote(_ weight: Font.Weight = .medium) -> Font {
        .system(.footnote, design: .rounded).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .rounded).weight(weight)
    }

    static func caption2(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption2, design: .rounded).weight(weight)
    }

    static func metric(size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        adaptive(size: size, weight: weight).monospacedDigit()
    }

    static func brandTitle(_ style: Font.TextStyle = .title2, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    static func brandMetric(size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        adaptive(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
