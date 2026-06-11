//
//  OverviewQuickActionManagementSheets.swift
//  Ohana
//
//  Quick action management and add sheets.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - QA Manage Sheet
struct QAManageSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    @Binding var savedItems: [QuickActionItem]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @State private var showingAddSheet = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(savedItems, id: \.id) { item in
                    HStack(spacing: 12) {
                        OhanaQuickActionIcon(
                            actionType: item.actionType,
                            fallbackSystemName: item.icon,
                            size: 28,
                            color: Color.ohanaFunctionalIcon
                        )
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                                Text(pet.name)
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            } else {
                                Text(l.tr(zh: "通用", en: "General", de: "Allgemein"))
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indices in
                    savedItems.remove(atOffsets: indices)
                }
                .onMove { indices, newOffset in
                    savedItems.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle(l.tr(zh: "编辑快捷操作", en: "Edit quick actions", de: "Schnellaktionen bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showingAddSheet = true } label: {
                            Image(systemName: "plus") // a11y: allow decorative icon covered by surrounding text or control
                        }
                        Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) { dismiss() }
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddQuickActionSheet(
                    pets: pets,
                    defaultPetId: defaultPetId,
                    existingItems: savedItems
                ) { newItem in
                    if let petId = newItem.petId,
                       let pet = pets.first(where: { $0.id == petId }),
                       QuickActionLimit.count(for: pet, in: savedItems) >= QuickActionLimit.maxItemsPerEntity {
                        return
                    }
                    savedItems.append(newItem)
                }
            }
        }
    }
}

// MARK: - Add Quick Action Sheet
struct AddQuickActionSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    let existingItems: [QuickActionItem]
    let onAdd: (QuickActionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @State private var step: Int = 1
    @State private var selectedPet: Pet? = nil
    @State private var showLimitAlert = false

    private var l: L10n { L10n(appLanguage) }

    /// F3: 实时读取 AppStorage 中的 item 数量（而非快照）
    private var liveItems: [QuickActionItem] {
        (try? JSONDecoder().decode([QuickActionItem].self, from: Data(quickActionItemsJSON.utf8))) ?? []
    }

    private var selectedPetItemCount: Int {
        guard let pet = selectedPet else { return 0 }
        return QuickActionLimit.count(for: pet, in: liveItems)
    }

    private var quickActionLimitTitle: String {
        l.tr(
            zh: QuickActionLimit.title,
            en: "Quick actions are full",
            de: "Schnellaktionen sind voll"
        )
    }

    private var quickActionLimitMessage: String {
        l.tr(
            zh: QuickActionLimit.message,
            en: "You can add up to 8 quick actions here. More features are available in All Features.",
            de: "Hier sind bis zu 8 Schnellaktionen möglich. Weitere Funktionen findest du unter Alle Funktionen."
        )
    }

    private func availableActions(for pet: Pet) -> [QuickActionPickerCatalog.Option] {
        let existingTypes = Set(liveItems.filter { $0.petId == pet.id }.map(\.actionType))
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existingTypes)
    }

    @State private var pressedActionId: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.22))
                .zIndex(1)

            VStack(spacing: 0) {
                Color.clear.frame(height: 22)
                if step == 1 {
                    petStep
                } else {
                    actionStep
                }
                Spacer(minLength: 32)
            }
        }
        .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        .onAppear {
            if let pid = defaultPetId, let pet = pets.first(where: { $0.id == pid }) {
                selectedPet = pet
                step = 2
            }
        }
        .alert(quickActionLimitTitle, isPresented: $showLimitAlert) {
            Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {}
        } message: {
            Text(quickActionLimitMessage)
        }
    }

    private var petStep: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "选择宠物", en: "Choose pet", de: "Tier auswählen"))
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "为哪只宠物添加快速入口", en: "Choose where to add the shortcut", de: "Wähle das Tier für den Schnellzugriff"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // 宠物列表
            VStack(spacing: 10) {
                ForEach(pets) { pet in
                    Button {
                        selectedPet = pet
                        withAnimation(GoMotion.selection) { step = 2 }
                    } label: {
                        HStack(spacing: 14) {
                            PetAvatarPortraitView(
                                imageData: pet.avatarImageData,
                                fallbackText: pet.avatarEmoji,
                                themeColor: Color(hex: pet.safeThemeColorHex),
                                size: 48,
                                backgroundOpacity: 0.22
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text("\(pet.species) · \(pet.breed)")
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color(hex: pet.themeColorHex))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var actionStep: some View {
        VStack(spacing: 20) {
            // 头部：返回按鈕 + 宠物头像与名字融为一体
            HStack(spacing: 12) {
                Button {
                    withAnimation(GoMotion.selection) { step = 1 }
                } label: {
                    Image(systemName: "chevron.left") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 15, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                if let pet = selectedPet {
                    PetAvatarPortraitView(
                        imageData: pet.avatarImageData,
                        fallbackText: pet.avatarEmoji,
                        themeColor: Color(hex: pet.safeThemeColorHex),
                        size: 36,
                        backgroundOpacity: 0.2
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pet.name)
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(zh: "选择快捷功能", en: "Choose quick action", de: "Schnellaktion auswählen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // iOS 控制中心风格图标网格
            if let pet = selectedPet {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        let available = availableActions(for: pet)
                        if selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity {
                            VStack(spacing: 8) {
                                Text(l.tr(zh: "最多 8 个快捷操作", en: "Up to 8 quick actions", de: "Bis zu 8 Schnellaktionen"))
                                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(l.tr(zh: "更多功能可以去「全部功能」里查看。", en: "More features are available in All Features.", de: "Weitere Funktionen findest du unter Alle Funktionen."))
                                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if available.isEmpty {
                            Text(l.tr(zh: "所有快捷入口已添加", en: "All shortcuts added", de: "Alle Schnellzugriffe hinzugefügt"))
                                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                        ForEach(available) { action in
                            let accentColor = Color.ohanaFunctionalIcon
                            let isPressed = pressedActionId == action.id
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                guard selectedPetItemCount < QuickActionLimit.maxItemsPerEntity else {
                                    showLimitAlert = true
                                    return
                                }
                                onAdd(QuickActionItem(
                                    label: action.label,
                                    icon: action.icon, colorHex: action.colorHex,
                                    petId: pet.id, actionType: action.id
                                ))
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    OhanaQuickActionIcon(
                                        actionType: action.id,
                                        fallbackSystemName: action.icon,
                                        size: 34,
                                        color: Color.ohanaFunctionalIcon
                                    )
                                    .frame(width: 44, height: 44)
                                    Text(action.label)
                                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isPressed ? accentColor.opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                                )
                                .scaleEffect(isPressed ? 0.90 : 1.0)
                                .animation(GoMotion.tap, value: isPressed)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in pressedActionId = action.id }
                                    .onEnded { _ in pressedActionId = nil }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Quick Feed Sheet
struct QuickFeedSheet: View {
    let pet: Pet
    let actionType: String
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.detectedCode
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var amountText: String = ""
    @State private var setAsDefault = false

    private var l: L10n { L10n(appLanguage) }
    private var isWater: Bool { actionType == "water" }
    private var unit: String { isWater ? "ml" : "g" }
    private var defaultAmount: Double { isWater ? 200 : pet.dailyPortionGrams }
    private var isCasual: Bool { !isWater && pet.foodTrackingMode == .casual }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                VStack(spacing: 24) {
                    petHeader
                    HStack {
                        ExecutorPickerBarRouteContainer(tint: Color.goPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    if isCasual {
                        casualBody
                    } else {
                        preciseBody
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("")
            .onDisappear {
                commandQueue.cancelAll()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 52,
                backgroundOpacity: 0.15
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.body(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(quickFeedSubtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
            }
            Spacer()
            Text(isWater ? "💧" : "🍗").font(OhanaFont.adaptive(size: 30)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .padding(.horizontal, 20)
    }

    private var casualBody: some View {
        VStack(spacing: 20) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text(casualCopyText)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(l.tr(zh: "打卡后获得 +1🥥 椰子奖励", en: "Check in to earn +1🥥", de: "Einchecken für +1🥥"))
                        .font(OhanaFont.footnote(.medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                .padding(24)
            }
            .padding(.horizontal, 20)

            Button { commitFeed(amount: 0) } label: {
                HStack(spacing: 8) {
                    Text("✅")
                    Text(l.tr(zh: "确认喂食  +1🥥", en: "Confirm feed  +1🥥", de: "Fütterung bestätigen  +1🥥"))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    private var preciseBody: some View {
        VStack(spacing: 16) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text(isWater ? l.tr(zh: "输入饮水量", en: "Enter water amount", de: "Wassermenge eingeben") : l.tr(zh: "输入喂食量", en: "Enter food amount", de: "Futtermenge eingeben"))
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    InlineNumericInput(
                        text: $amountText,
                        placeholder: l.tr(zh: "默认 \(Int(defaultAmount))", en: "Default \(Int(defaultAmount))", de: "Standard \(Int(defaultAmount))"),
                        unit: unit,
                        maxFractionDigits: 0,
                        accent: Color.goPrimary,
                        step: isWater ? 50 : 5,
                        valueFont: OhanaFont.metric(size: 32),
                        unitFont: OhanaFont.title3(.bold),
                        fill: Color.ohanaControlFill,
                        cornerRadius: OhanaRadius.control,
                        horizontalPadding: 12,
                        verticalPadding: 10
                    )
                    Toggle(isOn: $setAsDefault) {
                        Text(isWater ? l.tr(zh: "设为默认饮水量", en: "Set as default water", de: "Als Standardwasser setzen") : l.tr(zh: "设为默认每日份量", en: "Set as default daily portion", de: "Als Tagesportion setzen"))
                            .font(OhanaFont.footnote(.medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    }
                    .tint(Color.goPrimary)
                }
                .padding(20)
            }
            .padding(.horizontal, 20)

            Button {
                let amount = CountryDecimalInput.parse(amountText, countryCode: AppCountry.code) ?? defaultAmount
                commitFeed(amount: amount)
            } label: {
                Text(l.tr(zh: "打卡 +1🥥", en: "Check in +1🥥", de: "Einchecken +1🥥"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    private var quickFeedSubtitle: String {
        if isWater {
            return l.tr(zh: "喂水打卡", en: "Water check-in", de: "Wasser eintragen")
        }
        if isCasual {
            return l.tr(zh: "佛系喂食 🐾", en: "Casual feeding 🐾", de: "Lockere Fütterung 🐾")
        }
        return l.tr(zh: "精准喂食 📊", en: "Precise feeding 📊", de: "Präzise Fütterung 📊")
    }

    private var casualCopyText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 10:
            return l.tr(zh: "早餐时间到了！\n主子今天胃口好吗？🌅", en: "Breakfast time!\nHow is the appetite today? 🌅", de: "Frühstückszeit!\nWie ist der Appetit heute? 🌅")
        case 10 ..< 14:
            return l.tr(zh: "午饭打卡！\n记得让 \(pet.name) 多喝水哦 💦", en: "Lunch check-in!\nKeep \(pet.name) hydrated too 💦", de: "Mittag eintragen!\nDenk auch an Wasser für \(pet.name) 💦")
        case 14 ..< 18:
            return l.tr(zh: "下午喂食 ☀️\n\(pet.name) 今天乖吗？", en: "Afternoon feeding ☀️\nHow is \(pet.name) doing today?", de: "Nachmittagsfütterung ☀️\nWie macht sich \(pet.name) heute?")
        case 18 ..< 22:
            return l.tr(zh: "晚餐时间！\n今天辛苦啦，\(pet.name) 也一样 🌙", en: "Dinner time!\nYou did well today, and so did \(pet.name) 🌙", de: "Abendessen!\nDu warst heute stark, \(pet.name) auch 🌙")
        default:
            return l.tr(zh: "\(pet.name) 的宵夜时间？\n记录一下也没关系 😄", en: "Late snack for \(pet.name)?\nLogging it is totally fine 😄", de: "Später Snack für \(pet.name)?\nEintragen ist völlig okay 😄")
        }
    }

    private func commitFeed(amount: Double) {
        let executorId = appServices.activeHumanSelection.currentHumanId
        let requestedAmount = isWater ? (amount > 0 ? amount : defaultAmount) : amount
        let shouldSaveDefault = !isWater && !isCasual && setAsDefault && amount > 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: isWater ? "water" : "feed")) {
            _ = OverviewQuickCareCommandExecutor(
                context: modelContext,
                careEvents: appServices.careEvents,
                revisions: appServices.domainRevisions
            ).record(
                pet: pet,
                actionType: actionType,
                amount: requestedAmount,
                saveAsDefault: shouldSaveDefault,
                executorId: executorId
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}
