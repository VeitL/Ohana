//
//  AddEntityView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

enum EntityType: String, CaseIterable {
    case pet
    case human
    case plant
    
    var icon: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .human: return "person.fill"
        case .plant: return "leaf.fill"
        }
    }
    
    var emoji: String {
        switch self {
        case .pet: return "🐾"
        case .human: return "👤"
        case .plant: return "🌱"
        }
    }
    
    var color: Color {
        switch self {
        case .pet: return Color.goPrimary
        case .human: return Color(hex: "7DA2FF")
        case .plant: return Color.goLime
        }
    }

    var isAvailable: Bool {
        switch self {
        case .pet, .human, .plant: return true
        }
    }
}

struct AddEntityView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @State private var selectedType: EntityType?

    private var l: L10n { L10n(appLanguage) }

    init(initialType: EntityType? = nil) {
        _selectedType = State(initialValue: initialType)
    }

    private var navigationTitleText: String {
        guard let t = selectedType else { return l.addEntityNavRoot }
        switch t {
        case .pet: return l.addEntityPetTitle
        case .human: return l.addEntityHumanTitle
        case .plant: return l.addEntityPlantTitle
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()

                if let type = selectedType {
                    switch type {
                    case .pet:
                        AddPetWizardView(onComplete: { dismiss() })
                    case .human:
                        AddHumanWizardView(onComplete: { dismiss() })
                    case .plant:
                        AddPlantView(onComplete: { dismiss() })
                    }
                } else {
                    entitySelector
                }
            }
            .id(selectedType?.rawValue ?? "selector")
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedType != nil {
                        Button(l.addEntityBack) {
                            withAnimation(.easeInOut(duration: 0.22)) { selectedType = nil }
                        }
                        .foregroundStyle(Color.goLime)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.addEntityClose) { dismiss() }
                        .foregroundStyle(Color.goLime)
                }
            }
        }
    }
    
    private var entitySelector: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 6) {
                Text(l.addEntityHeadline)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(l.addEntitySub)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(EntityType.allCases, id: \.self) { type in
                    Button {
                        guard type.isAvailable else { return }
                        withAnimation(.spring(response: 0.4)) { selectedType = type }
                    } label: {
                        entityCard(type)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!type.isAvailable)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func entityCard(_ type: EntityType) -> some View {
        let ring = type.color.opacity(type.isAvailable ? 0.55 : 0.2)
        let fgOpacity: Double = type.isAvailable ? 1 : 0.45

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(type.isAvailable ? 0.1 : 0.05))
                    .frame(width: 56, height: 56)
                    .overlay(Circle().strokeBorder(ring, lineWidth: 1.5))
                Text(type.emoji)
                    .font(.system(size: 28))
                    .opacity(fgOpacity)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entityTitle(type))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(fgOpacity))
                    if !type.isAvailable {
                        Text(l.addEntityWIP)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.goLime.opacity(0.15), in: Capsule())
                    }
                }
                Text(entityBlurb(type))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(type.isAvailable ? 0.62 : 0.32))
            }

            Spacer()

            Image(systemName: type.isAvailable ? "chevron.right" : "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white.opacity(type.isAvailable ? 0.5 : 0.28))
        }
        .padding(18)
        .goTranslucentCard(cornerRadius: 28)
        .opacity(type.isAvailable ? 1 : 0.65)
    }
    
    private func entityTitle(_ type: EntityType) -> String {
        switch type {
        case .pet: return l.addEntityPetTitle
        case .human: return l.addEntityHumanTitle
        case .plant: return l.addEntityPlantTitle
        }
    }

    private func entityBlurb(_ type: EntityType) -> String {
        switch type {
        case .pet: return l.addEntityPetBlurb
        case .human: return l.addEntityHumanBlurb
        case .plant: return l.addEntityPlantBlurb
        }
    }
}

#Preview {
    AddEntityView()
        .modelContainer(SharedModelContainer.make())
}
