//
//  SharedCareTargetPicker.swift
//  Ohana
//
//  Compact target chips for same-species shared care popups.
//

import SwiftUI

struct SharedCareTargetPicker: View {
    let title: String
    let subtitle: String
    let pets: [Pet]
    @Binding var selectedPetIds: Set<UUID>
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pets) { pet in
                        targetChip(pet)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func targetChip(_ pet: Pet) -> some View {
        let isSelected = selectedPetIds.contains(pet.id)
        return Button {
            withAnimation(GoMotion.feedback) {
                if isSelected, selectedPetIds.count > 1 {
                    selectedPetIds.remove(pet.id)
                } else {
                    selectedPetIds.insert(pet.id)
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 7) {
                    PetAvatarPortraitView(
                        pet: pet,
                        size: 28,
                    showsBackground: !(pet.avatarImageData.map { PetAvatarTransparencyCache.isTransparentAvatar($0) } ?? false),
                    backgroundOpacity: 0.14,
                    transparentScale: 0.92,
                    transparentYOffset: 0.04
                )
                Text(pet.name)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaSecondaryText.opacity(0.65))
            }
            .padding(.leading, 6)
            .padding(.trailing, 9)
            .padding(.vertical, 7)
            .background(isSelected ? tint : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
