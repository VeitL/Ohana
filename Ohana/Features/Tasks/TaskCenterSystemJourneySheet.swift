//
//  TaskCenterSystemJourneySheet.swift
//  Ohana
//
//  Lightweight explanation and confirmation surface for household starter tasks.
//

import SwiftUI

enum TaskCenterSystemJourneyMutationOutcome {
    case success
    case failure(String)
}

struct TaskCenterSystemJourneySheet: View {
    let item: TaskCenterItemSnapshot
    let taskState: HouseholdStarterJourneyTaskState?
    let onOpenDestination: () -> Void
    let onClaim: () -> TaskCenterSystemJourneyMutationOutcome
    let onRecordResolution: (
        HouseholdStarterJourneyCheckpoint,
        HouseholdStarterJourneyResolution
    ) -> TaskCenterSystemJourneyMutationOutcome
    let onClose: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var recordedResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution] = [:]
    @State private var errorMessage: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    if let taskState {
                        progress(taskState)
                    }
                    Text(explanation)
                        .font(OhanaFont.callout())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(Color.goRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("task-center-starter-journey-error")
                    }

                    if isRewardReady {
                        claimButton
                    } else {
                        openButton
                        resolutionSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
            .background(OhanaAppBackground().ignoresSafeArea())
            .navigationTitle(l.tr(zh: "新手成长计划", en: "Starter journey", de: "Starter-Reise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark") // a11y: allow owning button has localized label
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    .accessibilityIdentifier("task-center-starter-journey-close")
                }
            }
        }
        .accessibilityIdentifier("task-center-starter-journey-sheet-\(item.systemDestination?.rawValue ?? "unknown")")
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.symbol)
                .font(OhanaFont.adaptive(size: 22, weight: .bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 52, height: 52)
                .background(Color.goPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("+\(item.rewardCoconuts) 🥥")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func progress(_ state: HouseholdStarterJourneyTaskState) -> some View {
        let completed = min(
            state.requiredCheckpointCount,
            max(state.completedCheckpointCount, completedCheckpoints.count)
        )
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(l.tr(zh: "已确认", en: "Reviewed", de: "Geprüft"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text("\(completed)/\(state.requiredCheckpointCount)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(completed), total: Double(max(1, state.requiredCheckpointCount)))
                .tint(Color.goPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var openButton: some View {
        Button {
            OhanaFeedback.light()
            onOpenDestination()
        } label: {
            Label(openActionTitle, systemImage: "arrow.up.right")
                .font(OhanaFont.callout(.black))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityIdentifier("task-center-starter-journey-open-\(item.systemDestination?.rawValue ?? "unknown")")
    }

    private var claimButton: some View {
        Button {
            switch onClaim() {
            case .success:
                errorMessage = nil
                OhanaFeedback.success()
            case let .failure(message):
                errorMessage = message
                OhanaFeedback.error()
            }
        } label: {
            Text(l.tr(
                zh: "领取 \(item.rewardCoconuts) 椰子",
                en: "Claim \(item.rewardCoconuts) coconuts",
                de: "\(item.rewardCoconuts) Kokosnüsse abholen"
            ))
            .font(OhanaFont.callout(.black))
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .accessibilityIdentifier("task-center-starter-journey-claim-\(item.systemDestination?.rawValue ?? "unknown")")
    }

    @ViewBuilder
    private var resolutionSection: some View {
        if !availableCheckpoints.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "确认当前状态", en: "Confirm current status", de: "Aktuellen Status bestätigen"))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "不知道、不适用或不愿透露都可以如实选择，不需要为了奖励填写资料。",
                        en: "Unknown, not applicable, and prefer not to say are valid choices. Never add information just for a reward.",
                        de: "Unbekannt, nicht zutreffend und keine Angabe sind gültige Optionen."
                    ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(Array(availableCheckpoints.enumerated()), id: \.element.rawValue) { index, checkpoint in
                        resolutionRow(checkpoint)
                        if index < availableCheckpoints.count - 1 {
                            Divider().overlay(Color.ohanaCardStroke)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    Color.ohanaCardSurface,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
            }
        }
    }

    private func resolutionRow(_ checkpoint: HouseholdStarterJourneyCheckpoint) -> some View {
        HStack(spacing: 10) {
            Text(checkpointTitle(checkpoint))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if completedCheckpoints.contains(checkpoint) {
                Label(
                    l.tr(zh: "已确认", en: "Reviewed", de: "Geprüft"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goTeal)
                .frame(minHeight: 44)
                .accessibilityIdentifier("task-center-starter-resolution-complete-\(checkpoint.rawValue)")
            } else {
                Menu {
                    ForEach(allowedResolutions(for: checkpoint), id: \.rawValue) { resolution in
                        Button(resolutionTitle(resolution, checkpoint: checkpoint)) {
                            record(resolution, for: checkpoint)
                        }
                    }
                } label: {
                    Text(l.tr(zh: "选择", en: "Choose", de: "Wählen"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(Color.ohanaControlFill, in: Capsule())
                }
                .accessibilityLabel("\(checkpointTitle(checkpoint)), \(l.tr(zh: "选择状态", en: "Choose status", de: "Status wählen"))")
                .accessibilityIdentifier("task-center-starter-resolution-\(checkpoint.rawValue)")
            }
        }
        .frame(minHeight: 56)
    }

    private func record(
        _ resolution: HouseholdStarterJourneyResolution,
        for checkpoint: HouseholdStarterJourneyCheckpoint
    ) {
        switch onRecordResolution(checkpoint, resolution) {
        case .success:
            recordedResolutions[checkpoint] = resolution
            errorMessage = nil
            OhanaFeedback.selection()
            if let taskState,
               completedCheckpoints.count >= taskState.requiredCheckpointCount {
                onClose()
            }
        case let .failure(message):
            errorMessage = message
            OhanaFeedback.error()
        }
    }

    private var availableCheckpoints: [HouseholdStarterJourneyCheckpoint] {
        guard let taskState else { return [] }
        return HouseholdStarterJourneyCheckpoint.allCases.filter {
            $0.task == taskState.task && taskState.availableResolutionCheckpoints.contains($0)
        }
    }

    private var completedCheckpoints: Set<HouseholdStarterJourneyCheckpoint> {
        let persisted = taskState?.completedCheckpoints ?? []
        return persisted.union(recordedResolutions.keys)
    }

    private var isRewardReady: Bool {
        if let taskState { return taskState.status == .claimable }
        return item.systemJourneyPresentationState == .rewardReady
    }

    private func allowedResolutions(
        for checkpoint: HouseholdStarterJourneyCheckpoint
    ) -> [HouseholdStarterJourneyResolution] {
        let stableOrder: [HouseholdStarterJourneyResolution] = [
            .reviewed,
            .unknown,
            .notApplicable,
            .preferNotToSay
        ]
        return stableOrder.filter(checkpoint.allowedResolutions.contains)
    }

    private func resolutionTitle(
        _ resolution: HouseholdStarterJourneyResolution,
        checkpoint: HouseholdStarterJourneyCheckpoint
    ) -> String {
        switch resolution {
        case .reviewed:
            if checkpoint == .acceptedRecommendedCarePlan {
                l.tr(zh: "采用推荐计划", en: "Use recommended plan", de: "Empfohlenen Plan verwenden")
            } else if checkpoint == .petDailyCare {
                l.tr(zh: "沿用当前设置", en: "Use current setup", de: "Aktuelle Einstellung verwenden")
            } else {
                l.tr(zh: "已确认", en: "Reviewed", de: "Geprüft")
            }
        case .unknown:
            l.tr(zh: "暂不清楚", en: "Not sure yet", de: "Noch unklar")
        case .notApplicable:
            l.tr(zh: "不适用", en: "Not applicable", de: "Nicht zutreffend")
        case .preferNotToSay:
            l.tr(zh: "不愿透露", en: "Prefer not to say", de: "Keine Angabe")
        }
    }

    private func checkpointTitle(_ checkpoint: HouseholdStarterJourneyCheckpoint) -> String {
        switch checkpoint {
        case .humanAppearance: l.tr(zh: "头像与个性", en: "Avatar and style", de: "Avatar und Stil")
        case .humanOptionalDetails: l.tr(zh: "可选资料", en: "Optional details", de: "Optionale Angaben")
        case .petLifeStage: l.tr(zh: "年龄与到家信息", en: "Age and home details", de: "Alter und Zuhause")
        case .petBodyProfile: l.tr(zh: "身体资料", en: "Body profile", de: "Körperprofil")
        case .petPersonalityAppearance: l.tr(zh: "性格与外观", en: "Personality and appearance", de: "Charakter und Aussehen")
        case .petDailyCare: l.tr(zh: "日常照护设置", en: "Daily care setup", de: "Tägliche Pflege")
        case .petIdentityDocuments: l.tr(zh: "身份与证件", en: "Identity and documents", de: "Identität und Dokumente")
        case .petEmergencyContact: l.tr(zh: "兽医与紧急联系", en: "Vet and emergency contact", de: "Tierarzt und Notfallkontakt")
        case .petHealthProtection: l.tr(zh: "疫苗与保健", en: "Vaccines and preventive care", de: "Impfungen und Vorsorge")
        case .acceptedRecommendedCarePlan: l.tr(zh: "系统推荐照护计划", en: "Recommended care plan", de: "Empfohlener Pflegeplan")
        }
    }

    private var openActionTitle: String {
        switch taskState?.task {
        case .humanProfile: l.tr(zh: "查看人类资料", en: "Review human profile", de: "Menschenprofil prüfen")
        case .petProfile: l.tr(zh: "查看宠物资料", en: "Review pet profile", de: "Haustierprofil prüfen")
        case .identityProtection: l.tr(zh: "查看证件与保障", en: "Review identity and protection", de: "Dokumente und Schutz prüfen")
        case .healthProtection: l.tr(zh: "查看疫苗与保健", en: "Review preventive care", de: "Vorsorge prüfen")
        case .carePlan: l.tr(zh: "设置照护计划", en: "Set up care plan", de: "Pflegeplan einrichten")
        case .firstCare: l.tr(zh: "记录一次照护", en: "Record a care action", de: "Pflege erfassen")
        case nil: l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    private var explanation: String {
        switch taskState?.task {
        case .humanProfile:
            l.tr(zh: "确认这张成员卡符合你的使用习惯。敏感资料始终可留空。", en: "Make this member card useful to you. Sensitive details can always stay blank.", de: "Passe die Mitgliedskarte an. Sensible Angaben dürfen leer bleiben.")
        case .petProfile:
            l.tr(zh: "补充真正有助于日常照护的资料，不需要一次填满。", en: "Add details that genuinely help daily care. You do not need to fill everything at once.", de: "Ergänze hilfreiche Pflegedaten. Es muss nicht alles sofort ausgefüllt werden.")
        case .identityProtection:
            l.tr(zh: "记录已有证件或兽医联系方式；没有、未知或不适用也可以如实确认。", en: "Record available documents or vet contacts. None, unknown, and not applicable are valid too.", de: "Erfasse Dokumente oder Tierarztkontakte. Unbekannt oder nicht zutreffend ist ebenfalls gültig.")
        case .healthProtection:
            l.tr(zh: "确认疫苗、驱虫或体检状态。Ohana 不会要求你编造健康记录。", en: "Review vaccines, deworming, or checkups. Ohana never asks you to invent a health record.", de: "Prüfe Impfungen, Entwurmung oder Kontrollen. Erfinde keine Gesundheitsdaten.")
        case .carePlan:
            l.tr(zh: "选择一个适合当前宠物的照护节奏，也可以确认沿用现有建议。", en: "Choose a suitable care rhythm, or confirm that the current recommendations work for you.", de: "Wähle einen passenden Pflegerhythmus oder bestätige die aktuellen Empfehlungen.")
        case .firstCare:
            l.tr(zh: "完成一次真实的喂食、喂水或其他适用照护后即可领取。", en: "Record one real feeding, watering, or other suitable care action to unlock this reward.", de: "Erfasse eine echte Fütterung, Wasser- oder andere passende Pflege.")
        case nil:
            l.tr(zh: "完成这项小任务后即可领取椰子。", en: "Finish this small task to claim coconuts.", de: "Schließe diese kleine Aufgabe ab, um Kokosnüsse zu erhalten.")
        }
    }
}
