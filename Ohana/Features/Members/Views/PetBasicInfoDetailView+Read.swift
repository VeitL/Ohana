//
//  PetBasicInfoDetailView+Read.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

extension PetBasicInfoDetailView {
    var readContent: some View {
        VStack(spacing: 16) {
            // 品种护理小贴士（有品种且有数据时显示）
            if !pet.breed.isEmpty, let tips = PetBreedDatabase.careTips(for: pet.breed) {
                breedTipsCard(breed: pet.breed, tips: tips)
            }

            infoSection(title: l.tr(zh: "基本信息", en: "Basic info", de: "Basisdaten"), icon: "pawprint.fill", iconColor: Color.goPrimary) {
                infoRow(label: l.tr(zh: "名字", en: "Name", de: "Name"), value: pet.name)
                infoRow(label: l.tr(zh: "物种", en: "Species", de: "Art"), value: pet.localizedSpeciesName(l: l))
                infoRow(label: l.tr(zh: "品种", en: "Breed", de: "Rasse"), value: pet.breed.isEmpty ? petProfileEmptyValue : pet.breed)
                infoRow(label: l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), value: localizedPetGenderSummary)
                if let birthday = pet.birthday {
                    infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: birthday.formatted(.dateTime.year().month().day()))
                }
                if let homeDate = pet.homeDate {
                    infoRow(label: l.tr(zh: "到家日", en: "Home date", de: "Einzugstag"), value: homeDate.formatted(.dateTime.year().month().day()))
                }
                infoRow(label: l.tr(zh: "相处天数", en: "Days together", de: "Gemeinsame Tage"), value: localizedPetDays(pet.daysTogether))
                infoRow(label: l.tr(zh: "成长椰子", en: "Growth coconuts", de: "Wachstums-Kokosnuesse"), value: "\(pet.coconutBalance) 🥥")
                infoRow(label: l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), value: "#\(pet.safeThemeColorHex.uppercased())")
            }
            if !pet.coatColor.isEmpty || !pet.eyeColor.isEmpty {
                infoSection(title: l.tr(zh: "外貌特征", en: "Appearance", de: "Aussehen"), icon: "eye.fill", iconColor: Color.goCardCyan) {
                    if !pet.coatColor.isEmpty { infoRow(label: l.tr(zh: "毛色", en: "Coat color", de: "Fellfarbe"), value: pet.coatColor) }
                    if !pet.eyeColor.isEmpty { infoRow(label: l.tr(zh: "眼色", en: "Eye color", de: "Augenfarbe"), value: pet.eyeColor) }
                }
            }
            infoSection(title: l.tr(zh: "健康与医疗", en: "Health & medical", de: "Gesundheit & Medizin"), icon: "cross.circle.fill", iconColor: Color.goRed) {
                infoRow(label: l.tr(zh: "芯片号", en: "Microchip", de: "Mikrochip"), value: pet.microchipID.isEmpty ? l.tr(zh: "未登记", en: "Not registered", de: "Nicht registriert") : pet.microchipID)
                infoRow(label: l.tr(zh: "诊所名称", en: "Clinic", de: "Praxis"), value: pet.vetClinicName.isEmpty ? petProfileEmptyValue : pet.vetClinicName)
                infoRow(label: l.tr(zh: "主治医生", en: "Doctor", de: "Tierarzt"), value: pet.vetDoctorName.isEmpty ? petProfileEmptyValue : pet.vetDoctorName)
                infoRow(label: l.tr(zh: "联系电话", en: "Phone", de: "Telefon"), value: pet.vetContact.isEmpty ? petProfileEmptyValue : pet.vetContact)
                if !pet.vetAddress.isEmpty {
                    infoRow(label: l.tr(zh: "诊所地址", en: "Clinic address", de: "Praxisadresse"), value: pet.vetAddress)
                }
                infoRow(label: l.tr(zh: "过敏原", en: "Allergies", de: "Allergien"), value: pet.allergies.isEmpty ? l.tr(zh: "无记录", en: "No record", de: "Kein Eintrag") : pet.allergies)
            }
            vetVisitSummaryCard
            infoSection(title: l.tr(zh: "证件信息", en: "Documents", de: "Dokumente"), icon: "doc.badge.fill", iconColor: Color.goYellow) {
                infoRow(label: l.tr(zh: "护照编号", en: "Passport number", de: "Passnummer"), value: pet.passportNumber.isEmpty ? petProfileEmptyValue : pet.passportNumber)
                if let expiry = pet.passportExpiryDate {
                    infoRow(label: l.tr(zh: "护照有效期", en: "Passport expiry", de: "Pass gueltig bis"), value: expiry.formatted(.dateTime.year().month().day()))
                } else {
                    infoRow(label: l.tr(zh: "护照有效期", en: "Passport expiry", de: "Pass gueltig bis"), value: petProfileEmptyValue)
                }
            }
            if !pet.formerName.isEmpty || !pet.lineageInfo.isEmpty || !pet.birthCountry.isEmpty {
                infoSection(title: l.tr(zh: "血统来源", en: "Lineage", de: "Herkunft"), icon: "list.star", iconColor: Color.goMint) {
                    if !pet.formerName.isEmpty {
                        infoRow(label: l.tr(zh: "曾用名", en: "Former name", de: "Frueherer Name"), value: pet.formerName)
                    }
                    if !pet.birthCountry.isEmpty {
                        infoRow(label: l.tr(zh: "出生地", en: "Birthplace", de: "Geburtsort"), value: pet.birthCountry + (pet.birthCity.isEmpty ? "" : " · \(pet.birthCity)"))
                    }
                    if !pet.lineageInfo.isEmpty {
                        infoRow(label: l.tr(zh: "血统", en: "Lineage", de: "Abstammung"), value: pet.lineageInfo)
                    }
                }
            }
            if !pet.notes.isEmpty {
                infoSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
                    Text(pet.notes)
                        .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("pet-basic-info-notes-readback")
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
                        .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(l.tr(zh: "\(breed) · 护理贴士", en: "\(breed) · Care tips", de: "\(breed) · Pflegetipps"))
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "基于品种特点的个性化建议", en: "Personalized suggestions based on breed traits", de: "Personalisierte Tipps nach Rasseeigenschaften"))
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
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
    }

    // MARK: - Edit View

    var petProfileEmptyValue: String {
        l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
    }

    var localizedPetGenderSummary: String {
        let neuterStatus = pet.isNeutered
            ? l.tr(zh: "已绝育", en: "neutered", de: "kastriert")
            : l.tr(zh: "未绝育", en: "not neutered", de: "nicht kastriert")
        return "\(pet.genderSymbol) (\(neuterStatus))"
    }

    func localizedPetDays(_ days: Int) -> String {
        l.tr(zh: "\(days) 天", en: "\(days) days", de: "\(days) Tage")
    }
}
