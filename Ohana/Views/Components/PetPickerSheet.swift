//
//  PetPickerSheet.swift
//  Ohana
//
//  T3: Quick Access 先选宠物再执行动作
//

import SwiftUI
import SwiftData

struct PetPickerSheet: View {
    let pets: [Pet]
    let actionId: String
    let onSelect: (Pet) -> Void

    @Environment(\.dismiss) private var dismiss

    private var actionTitle: String {
        switch actionId {
        case "walk":   return "选择要遛的狗"
        case "health": return "选择宠物查看健康"
        case "groom":  return "选择要护理的宠物"
        case "potty":  return "选择宠物记录排泄"
        default:       return "选择宠物"
        }
    }

    private var actionEmoji: String {
        switch actionId {
        case "walk":   return "🦮"
        case "health": return "❤️"
        case "groom":  return "✂️"
        case "potty":  return "💩"
        default:       return "🐾"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Text(actionEmoji)
                        .font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                        Text("选择一只宠物继续")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ForEach(pets) { pet in
                        Button {
                            onSelect(pet)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                // 头像
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: pet.themeColorHex).opacity(0.2))
                                        .frame(width: 52, height: 52)
                                    if let data = pet.avatarImageData,
                                       let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 52, height: 52)
                                            .clipShape(Circle())
                                    } else {
                                        Text(pet.species == "狗" ? "🐶" : pet.species == "猫" ? "🐱" : "🐾")
                                            .font(.system(size: 26))
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pet.name)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.black)
                                    Text("\(pet.species) · \(pet.breed)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 40)
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
