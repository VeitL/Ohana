//
//  OhanaFont.swift
//  Ohana
//

import SwiftUI

// MARK: - Ohana Font System (SF Pro Rounded, always use these)
enum OhanaFont {
    static func adaptive(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
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

    static func largeTitle(_ weight: Font.Weight = .black) -> Font {
        adaptive(size: 34, weight: weight, design: .rounded)
    }

    static func title(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 24, weight: weight, design: .rounded)
    }

    static func title2(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 20, weight: weight, design: .rounded)
    }

    static func title3(_ weight: Font.Weight = .semibold) -> Font {
        adaptive(size: 17, weight: weight, design: .rounded)
    }

    static func headline(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 16, weight: weight, design: .rounded)
    }

    static func body(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 15, weight: weight, design: .rounded)
    }

    static func callout(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 14, weight: weight, design: .rounded)
    }

    static func subheadline(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 13, weight: weight, design: .rounded)
    }

    static func footnote(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 12, weight: weight, design: .rounded)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 11, weight: weight, design: .rounded)
    }

    static func caption2(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 10, weight: weight, design: .rounded)
    }

    static func metric(size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        adaptive(size: size, weight: weight, design: .rounded)
    }
}
