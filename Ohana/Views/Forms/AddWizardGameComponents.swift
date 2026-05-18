//
//  AddWizardGameComponents.swift
//  Ohana
//
//  Shared lightweight RPG-style creation components for human and pet wizards.
//

import SwiftUI

struct AddWizardStageItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let systemImage: String
}

struct AddWizardStageProgress: View {
    let stages: [AddWizardStageItem]
    let currentIndex: Int
    var accent: Color = Color.goPrimary
    var onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stages) { stage in
                    Button {
                        onSelect(stage.id)
                    } label: {
                        stageCell(stage)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(stage.title)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 52)
        .animation(GoMotion.selection, value: currentIndex)
    }

    private func stageCell(_ stage: AddWizardStageItem) -> some View {
        let isCurrent = stage.id == currentIndex
        let isDone = stage.id < currentIndex

        return HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isCurrent ? accent : isDone ? accent.opacity(0.26) : Color.ohanaCardSurfaceElevated)
                    .frame(width: 28, height: 28)
                Image(systemName: isDone ? "checkmark" : stage.systemImage)
                    .font(.system(size: 12, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isCurrent ? Color.arkInk : isDone ? accent : Color.ohanaSecondaryText)
            }
            if isCurrent {
                Text(stage.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, isCurrent ? 12 : 4)
        .padding(.vertical, 5)
        .frame(minHeight: 44)
        .background(
            isCurrent ? Color.ohanaCardSurfaceElevated : Color.clear,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(isCurrent ? accent.opacity(0.34) : Color.clear, lineWidth: 1)
        )
    }
}

struct AddWizardStatusBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = Color.goPrimary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
    }
}

struct AddWizardJoinCelebrationOverlay: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = Color.goPrimary

    var body: some View {
        ZStack {
            Color.ohanaPrimaryText.opacity(0.26)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                    Image(systemName: systemImage)
                        .font(.system(size: 30, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.arkInk)
                }
                VStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: min(ScreenCompat.width - 42, 360))
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}
