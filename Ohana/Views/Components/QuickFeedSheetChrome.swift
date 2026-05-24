//
//  QuickFeedSheetChrome.swift
//  Ohana
//
//  Shared sheet, surface, and celebration chrome for feeding views.
//

import SwiftUI
import UIKit

struct TreatCelebrationOverlay: View {
    let tint: Color
    @State private var isVisible = false
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var shouldRunCelebrationMotion: Bool {
        workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible)
    }

    var body: some View {
        ZStack {
            if shouldRunCelebrationMotion {
                TimelineView(.animation) { timeline in
                    celebrationContent(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                celebrationContent(at: 0)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
    }

    private func celebrationContent(at t: TimeInterval) -> some View {
        ZStack {
            Color.arkInk.opacity(0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                ZStack {
                    ForEach(0..<10, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2) ? "heart.fill" : "sparkle")
                            .font(.system(size: index.isMultiple(of: 2) ? 13 : 10, weight: .black))
                            .foregroundStyle(index.isMultiple(of: 2) ? tint : Color(hex: "FF69B4"))
                            .offset(
                                x: cos(t * 1.8 + Double(index)) * CGFloat(48 + index * 3),
                                y: sin(t * 1.6 + Double(index)) * CGFloat(28 + index * 2)
                            )
                            .opacity(0.9)
                    }
                    if UIImage(named: "feed_treat_celebration") != nil {
                        Image("feed_treat_celebration")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 138, height: 138)
                            .scaleEffect(1 + sin(t * 4.0) * 0.035)
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 72, weight: .black))
                            .foregroundStyle(tint)
                            .scaleEffect(1 + sin(t * 4.0) * 0.035)
                    }
                }
                Text("零食已记录")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .padding(24)
            .feedGlassSurface(cornerRadius: 28, tint: tint, tintOpacity: 0.045)
        }
    }
}

struct ConditionalFeedGlassSurface: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat
    var tint: Color = .clear
    var tintOpacity: Double = 0

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.feedGlassSurface(cornerRadius: cornerRadius, tint: tint, tintOpacity: tintOpacity)
        } else {
            content
        }
    }
}

enum FeedInlineSheetScrollCoordinateSpace {
    static let name = "FeedInlineSheetScrollCoordinateSpace"
}

struct FeedInlineSheetScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FeedScrollBounceConfigurator: UIViewRepresentable {
    let isBouncingEnabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            configureScrollView(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(from: uiView)
        }
    }

    private func configureScrollView(from view: UIView) {
        var parent = view.superview
        while let current = parent {
            if let scrollView = current as? UIScrollView {
                scrollView.bounces = isBouncingEnabled
                scrollView.alwaysBounceVertical = isBouncingEnabled
                scrollView.alwaysBounceHorizontal = false
                return
            }
            parent = current.superview
        }
    }
}

extension View {
    func feedSheetScrollChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
    }

    func feedGlassSurface(
        cornerRadius: CGFloat,
        tint: Color = .clear,
        tintOpacity: Double = 0
    ) -> some View {
        self
            .background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                ZStack {
                    shape
                        .fill(.ultraThinMaterial) // ui-v4: allow calendar-widget glass blur
                        .opacity(0.13)
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(light: Color(hex: "EAF8FF").opacity(0.035), dark: Color(hex: "130727").opacity(0.080)),
                                    Color(light: Color(hex: "DDEEFF").opacity(0.018), dark: Color(hex: "21093A").opacity(0.045)),
                                    Color(light: Color.white.opacity(0.006), dark: Color.black.opacity(0.012)) // ui-v4: allow calendar-widget deep glass shade
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if tintOpacity > 0 {
                        shape
                            .fill(tint.opacity(tintOpacity * 0.075))
                    }
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10), // ui-v4: allow calendar-widget glass edge highlight
                            Color.white.opacity(0.015), // ui-v4: allow calendar-widget soft highlight
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.72, y: 0.82)
                    )
                    .clipShape(shape)
                    RadialGradient(
                        colors: [
                            Color(hex: "00D6E8").opacity(0.040),
                            Color(hex: "0A7DFF").opacity(0.010),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.16, y: 0.08),
                        startRadius: 0,
                        endRadius: 210
                    )
                    .clipShape(shape)
                    .blendMode(.screen)
                    RadialGradient(
                        colors: [
                            Color(hex: "7B3DFF").opacity(0.022),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.80, y: 0.18),
                        startRadius: 8,
                        endRadius: 220
                    )
                    .clipShape(shape)
                    .blendMode(.screen)
                }
            }
            .overlay {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24), // ui-v4: allow calendar-widget glass bright rim
                                Color.white.opacity(0.045), // ui-v4: allow calendar-widget glass inner rim
                                Color(hex: "806BFF").opacity(0.070),
                                Color.black.opacity(0.018) // ui-v4: allow calendar-widget subtle depth rim
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                    .overlay {
                        shape
                            .strokeBorder(Color.ohanaGlassStroke.opacity(0.16), lineWidth: 0.5)
                            .blur(radius: 0.16)
                    }
            }
            .shadow(color: Color(hex: "00D6E8").opacity(0.014), radius: 6, x: -2, y: -2) // ui-v4: allow calendar-widget glass cyan glow
            .shadow(color: Color.black.opacity(0.038), radius: 9, x: 0, y: 6) // ui-v4: allow calendar-widget glass depth
    }

    func feedFlatBlockSurface(cornerRadius: CGFloat) -> some View {
        self
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func feedingTextFieldStyle(tint: Color) -> some View {
        self
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(14)
            .feedFlatBlockSurface(cornerRadius: 16)
    }
}

enum FeedSheetGlassMode {
    case regular
    case clear
}

struct FeedNativeSheetGlassSurface: View {
    let cornerRadius: CGFloat
    let glassMode: FeedSheetGlassMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            switch glassMode {
            case .regular:
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow single-layer native sheet background
            case .clear:
                shape
                    .fill(.clear)
                    .glassEffect(.clear.interactive(false), in: shape) // ui-v4: allow single-layer clear sheet comparison
            }
        }
    }
}

struct FeedInlineSheetGlassSurface: View {
    let cornerRadius: CGFloat
    let glassMode: FeedSheetGlassMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            switch glassMode {
            case .regular:
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow single-layer inline sheet glass
            case .clear:
                shape
                    .fill(.clear)
                    .glassEffect(.clear.interactive(false), in: shape) // ui-v4: allow clear inline sheet comparison
            }
        }
    }
}
