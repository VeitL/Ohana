import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func planEditorSheet(_ kind: FeedRuleKind) -> some View {
        let tint = kind == .manualReminder ? Color.goPurple : Color.goTeal
        let hasExistingPlan = !FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents).isEmpty

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inlineSheetScrollTopMarker
                sheetHero(
                    icon: kind.iconName,
                    title: kind == .manualReminder ? l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan") : l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"),
                    tint: tint
                )
                compactNotice(
                    icon: kind.iconName,
                    text: kind == .manualReminder
                        ? l.tr(zh: "到点提醒你确认打卡；每餐可单独设置干粮/湿粮和克数。", en: "Reminds you to confirm meals. Each meal can set food type and grams.", de: "Erinnert dich. Jede Mahlzeit hat Sorte und Gramm.")
                        : l.tr(zh: "不提醒、不等待确认；App 打开或进入本页时会自动补记并扣余粮。", en: "No reminder or confirmation. The app backfills due meals and deducts stock.", de: "Keine Erinnerung. Fällige Mahlzeiten werden automatisch eingetragen."),
                    tint: tint
                )
                if sameSpeciesFeedPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "目标宠物", en: "Pets", de: "Tiere"),
                        subtitle: "\(selectedPlanTargets.count)只\(pet.species)",
                        pets: sameSpeciesFeedPets,
                        selectedPetIds: $draftStore.selectedSharedPlanPetIds,
                        tint: tint
                    )
                }

                HStack(spacing: 12) {
                    planStepperCard(
                        title: l.tr(zh: "每天", en: "Per day", de: "Pro Tag"),
                        value: "\(draftStore.planCount)",
                        tint: tint
                    ) {
                        Stepper("", value: $draftStore.planCount, in: 1 ... 6)
                            .labelsHidden()
                            .onChange(of: draftStore.planCount) { _, newValue in
                                syncPlanTimesCount(newValue)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(zh: "每餐", en: "Meals", de: "Mahlzeiten"))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    ForEach(Array(draftStore.planMeals.indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(FeedRuleMetadata.mealName(for: draftStore.planMeals[index].time), systemImage: "clock.fill")
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(tint)
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { draftStore.planMeals[index].time },
                                    set: { draftStore.planMeals[index].time = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()

                            foodKindSegmentedControl(selection: draftStore.planMeals[index].foodKind) { foodKind in
                                withAnimation(GoMotion.feedback) {
                                    draftStore.planMeals[index].foodKind = foodKind
                                }
                                UISelectionFeedbackGenerator().selectionChanged()
                            }

                            planMealGramEditor(index: index, tint: tint)
                        }
                        .padding(10)
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
                    }
                }

                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }
            }
            .padding(18)
            .padding(.bottom, hasExistingPlan ? 126 : 78)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: sameSpeciesFeedPets.count > 1 ? 690 : 620,
                maxHeight: 860,
                chromePadding: 70
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            planEditorFooter(kind: kind, tint: tint, hasExistingPlan: hasExistingPlan)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FeedScrollBounceConfigurator(isBouncingEnabled: false))
        .coordinateSpace(name: FeedInlineSheetScrollCoordinateSpace.name)
        .onPreferenceChange(FeedInlineSheetScrollTopPreferenceKey.self) { value in
            inlineSheetScrollTopOffset = value
            if value < -8 {
                inlineSheetTopPullDismissArmed = false
            }
        }
        .simultaneousGesture(inlineSheetTopPullDismissGesture)
        .navigationTitle(kind == .manualReminder ? l.tr(zh: "计划", en: "Plan", de: "Plan") : l.tr(zh: "自动", en: "Auto", de: "Auto"))
    }

    func planEditorFooter(kind: FeedRuleKind, tint: Color, hasExistingPlan: Bool) -> some View {
        VStack(spacing: 10) {
            FoodPrimaryButton(
                title: draftStore.isSavingFeedPlan
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : (kind == .manualReminder ? l.tr(zh: "保存计划", en: "Save plan", de: "Plan speichern") : l.tr(zh: "保存自动记录", en: "Save auto feeder", de: "Automat speichern")),
                icon: draftStore.isSavingFeedPlan ? "hourglass" : "checkmark",
                tint: tint
            ) {
                savePlan(kind)
            }
            .disabled(draftStore.isSavingFeedPlan)
            .opacity(draftStore.isSavingFeedPlan ? 0.72 : 1)

            if hasExistingPlan {
                Button(role: .destructive) {
                    deletePlan(kind)
                } label: {
                    Label(l.tr(zh: "删除当前计划", en: "Delete current plan", de: "Aktuellen Plan löschen"), systemImage: "trash")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(draftStore.isSavingFeedPlan)
                .opacity(draftStore.isSavingFeedPlan ? 0.72 : 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background {
            LinearGradient(
                colors: [
                    Color.ohanaCardSurface.opacity(0.70),
                    Color.ohanaCardSurface.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
