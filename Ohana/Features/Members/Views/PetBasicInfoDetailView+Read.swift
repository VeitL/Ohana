//
//  PetBasicInfoDetailView+Read.swift
//  Ohana
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

extension PetBasicInfoDetailView {
    var readContent: some View {
        VStack(spacing: 16) {
            // 品种护理小贴士（有品种且有数据时显示）
            if !pet.breed.isEmpty, let tips = PetBreedDatabase.careTips(for: pet.breed) {
                breedTipsCard(breed: pet.breed, tips: tips)
            }

            infoSection(title: "基本信息", icon: "pawprint.fill", iconColor: Color.goPrimary) {
                infoRow(label: "名字", value: pet.name)
                infoRow(label: "物种", value: pet.species)
                infoRow(label: "品种", value: pet.breed.isEmpty ? "未填写" : pet.breed)
                infoRow(label: "性别", value: pet.genderSymbol + (pet.isNeutered ? "（已绝育）" : "（未绝育）"))
                if let birthday = pet.birthday {
                    infoRow(label: "生日", value: birthday.formatted(.dateTime.year().month().day()))
                }
                if let homeDate = pet.homeDate {
                    infoRow(label: "到家日", value: homeDate.formatted(.dateTime.year().month().day()))
                }
                infoRow(label: "相处天数", value: "\(pet.daysTogether) 天")
                infoRow(label: "成长椰子", value: "\(pet.coconutBalance) 🥥")
                infoRow(label: "主题色", value: "#\(pet.safeThemeColorHex.uppercased())")
            }
            if !pet.coatColor.isEmpty || !pet.eyeColor.isEmpty {
                infoSection(title: "外貌特征", icon: "eye.fill", iconColor: Color.goCardCyan) {
                    if !pet.coatColor.isEmpty { infoRow(label: "毛色", value: pet.coatColor) }
                    if !pet.eyeColor.isEmpty  { infoRow(label: "眼色", value: pet.eyeColor) }
                }
            }
            infoSection(title: "健康与医疗", icon: "cross.circle.fill", iconColor: Color.goRed) {
                infoRow(label: "芯片号", value: pet.microchipID.isEmpty ? "未登记" : pet.microchipID)
                infoRow(label: "诊所名称", value: pet.vetClinicName.isEmpty ? "未填写" : pet.vetClinicName)
                infoRow(label: "主治医生", value: pet.vetDoctorName.isEmpty ? "未填写" : pet.vetDoctorName)
                infoRow(label: "联系电话", value: pet.vetContact.isEmpty   ? "未填写" : pet.vetContact)
                if !pet.vetAddress.isEmpty {
                    infoRow(label: "诊所地址", value: pet.vetAddress)
                }
                infoRow(label: "过敏原", value: pet.allergies.isEmpty ? "无记录" : pet.allergies)
            }
            vetVisitSummaryCard
            infoSection(title: "证件信息", icon: "doc.badge.fill", iconColor: Color.goYellow) {
                infoRow(label: "护照编号", value: pet.passportNumber.isEmpty ? "未填写" : pet.passportNumber)
                if let expiry = pet.passportExpiryDate {
                    infoRow(label: "护照有效期", value: expiry.formatted(.dateTime.year().month().day()))
                } else {
                    infoRow(label: "护照有效期", value: "未填写")
                }
            }
            if !pet.formerName.isEmpty || !pet.lineageInfo.isEmpty || !pet.birthCountry.isEmpty {
                infoSection(title: "血统来源", icon: "list.star", iconColor: Color.goMint) {
                    if !pet.formerName.isEmpty {
                        infoRow(label: "曾用名", value: pet.formerName)
                    }
                    if !pet.birthCountry.isEmpty {
                        infoRow(label: "出生地", value: pet.birthCountry + (pet.birthCity.isEmpty ? "" : " · \(pet.birthCity)"))
                    }
                    if !pet.lineageInfo.isEmpty {
                        infoRow(label: "血统", value: pet.lineageInfo)
                    }
                }
            }
            if !pet.notes.isEmpty {
                infoSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                    Text(pet.notes)
                        .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            rainbowBridgeSection
            deleteDangerZone
        }
    }

    func breedTipsCard(breed: String, tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(GoMotion.selection) { breedTipsExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goYellow)
                        .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(breed) · 护理贴士")
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("基于品种特点的个性化建议")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Image(systemName: breedTipsExpanded ? "chevron.up" : "chevron.down")
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            if breedTipsExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.goYellow.opacity(0.7))
                                .frame(width: 5, height: 5) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                .padding(.top, 5)
                            Text(tip)
                                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.75))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 16)
    }

    // MARK: - Edit View
}
