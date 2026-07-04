//
//  AddPlantCreationSupport.swift
//  Ohana
//
//  Lightweight card-step support for the Add Plant flow.
//

import SwiftUI
import UIKit

enum PlantCreationAvatarSource: String, Equatable {
    case builtIn
    case customImage
}

enum AddPlantCreationStep: String, CaseIterable, Identifiable {
    case plant
    case avatar
    case care
    case confirm

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .plant:
            l.tr(zh: "植物与房间", en: "Plant and room", de: "Pflanze und Raum")
        case .avatar:
            l.tr(zh: "头像", en: "Avatar", de: "Avatar")
        case .care:
            l.tr(zh: "养护信息", en: "Care info", de: "Pflegeinfos")
        case .confirm:
            l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
        }
    }
}

struct PlantCreationStepIndicator: View {
    let steps: [AddPlantCreationStep]
    let currentStep: AddPlantCreationStep
    let l: L10n

    private var currentIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentStep.title(l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("\(currentIndex + 1) / \(steps.count)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? Color.goTeal : Color.ohanaControlFill.opacity(0.74))
                        .frame(width: index == currentIndex ? 26 : 9, height: 7)
                        .animation(GoMotion.selection, value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 42, alignment: .bottom)
    }
}

struct PlantCreationCardSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.ohanaCardSurfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct PlantCreationBufferedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let identifier: String
    let focusRequestID: Int
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    @State private var draftText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)

            TextField(placeholder, text: $draftText) // ui-v4: allow buffered add-plant input; parent draft commits on submit/blur to avoid whole-sheet invalidation per keystroke.
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.goTeal.opacity(0.58) : Color.ohanaCardSurface.opacity(0.18),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .focused($isFocused)
                .submitLabel(submitLabel)
                .onSubmit {
                    commitDraft()
                    onSubmit()
                    isFocused = false
                }
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            draftText = text
            focusIfRequested(focusRequestID)
        }
        .onDisappear {
            commitDraft()
        }
        .onChange(of: text) { _, newValue in
            guard !isFocused, draftText != newValue else { return }
            draftText = newValue
        }
        .onChange(of: focusRequestID) { _, newValue in
            focusIfRequested(newValue)
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                commitDraft()
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func commitDraft() {
        guard text != draftText else { return }
        text = draftText
    }

    private func focusIfRequested(_ requestID: Int) {
        guard requestID > 0 else { return }
        OhanaFrameScheduler.runAfterNextFrame {
            isFocused = true
        }
    }
}

struct PlantCreationSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlantCreationMetricPill: View {
    let icon: String
    let title: String
    var isSelected = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText)
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(
            isSelected ? Color.goPrimary.opacity(0.96) : Color.ohanaControlFill.opacity(0.72),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }
}

struct PlantCreationAvatarPreview: View {
    let image: UIImage?
    let catalog: PlantCatalogEntry?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.goTeal.opacity(0.16))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let catalogImage {
                Image(uiImage: catalogImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            } else {
                Image(systemName: "leaf.fill") // a11y: allow decorative fallback avatar glyph; the avatar preview is hidden from VoiceOver.
                    .font(OhanaFont.adaptive(size: max(18, size * 0.36), weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.goTeal.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var catalogImage: UIImage? {
        UIImage(named: catalog?.catalogImageAssetName ?? "")
    }
}

struct PlantCreationInfoRow<Control: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 28, height: 28) // a11y: allow decorative row glyph; surrounding row text provides the accessible content.
                    .background(Color.goTeal.opacity(0.13), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            control()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }
}
