//
//  PetBasicInfoDetailView.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

struct PetBasicInfoDetailView: View {
    let pet: Pet
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var isEditing = false
    @State var breedTipsExpanded = true

    @State var showingRainbowBridgeAlert = false
    @State var showingUndoPassingAlert = false
    @State var rainbowBridgeDate = Date()

    // Edit state mirrors
    @State var eName = ""
    @State var eSpecies = ""
    @State var eBreed = ""
    @State var eGender = ""
    @State var eIsNeutered = false
    @State var eHasBirthday = false
    @State var eBirthday = Date()
    @State var eHasHomeDate = false
    @State var eHomeDate = Date()
    @State var eCoatColor = ""
    @State var eEyeColor = ""
    @State var eMicrochipID = ""
    @State var eVetContact = "" // 电话
    @State var eVetClinicName = ""
    @State var eVetDoctorName = ""
    @State var eVetAddress = ""
    @State var eAllergies = ""
    @State var ePassportNumber = ""
    @State var eHasPassportExpiry = false
    @State var ePassportExpiry = Date()
    @State var eFormerName = ""
    @State var eBirthCountry = ""
    @State var eBirthCity = ""
    @State var eLineageInfo = ""
    @State var eNotes = ""
    @State var eThemeColorHex = ""
    @State var eAvatarImageData: Data? = nil

    let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    let themePresets: [(String, String)] = [
        ("FF6B6B", "coral"), ("4ECDC4", "ocean"), ("B8A9C9", "lavender"),
        ("95E1D3", "mint"), ("F38181", "sunset"), ("AA96DA", "berry"),
        ("F472B6", "rose"), ("A8E6CF", "sage"), ("FFD3B6", "peach"), ("95ADBE", "slate")
    ]

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    avatarSection
                    if isEditing {
                        editContent
                    } else {
                        readContent
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("\(pet.name) 的信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        saveChanges()
                        withAnimation { isEditing = false }
                    } label: {
                        Text("保存")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goPrimary)
                    }
                } else {
                    Button {
                        loadEditState()
                        withAnimation { isEditing = true }
                    } label: {
                        Image(systemName: "pencil.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { withAnimation { isEditing = false } }
                }
            }
        }
    }

    // MARK: - Read View
}
