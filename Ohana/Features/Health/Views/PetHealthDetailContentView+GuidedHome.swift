//
//  PetHealthDetailContentView+GuidedHome.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension PetHealthDetailContentView {
    // MARK: - Guided Health Home
    var healthHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: chromeAccent,
                size: 46,
                backgroundOpacity: isDark ? 0.18 : 0.12
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "健康", en: "Health", de: "Gesundheit"))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                OhanaFeedback.light()
                dismiss()
                onFullDismiss?()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 40, height: 40) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 4)
    }

    var healthAddMenu: some View {
        VStack(alignment: .trailing, spacing: 14) {
            if isHealthFabExpanded {
                ForEach(Array(healthFabActionKinds.enumerated()), id: \.element.id) { index, action in
                    HomeFabActionRow(
                        item: HomeFabFunctionShortcut(
                            label: action.label(l, isRenderingPDF: isRenderingPDF),
                            icon: action.icon,
                            isAvailable: action != .pdf || !isRenderingPDF
                        ),
                        rowHeight: 48
                    )
                    .ohanaStaggeredMenuItem(isVisible: healthFabItemsVisible, index: index, total: healthFabActionKinds.count)
                    .onTapGesture {
                        performHealthFabAction(action)
                    }
                    .allowsHitTesting(healthFabItemsVisible && (action != .pdf || !isRenderingPDF))
                    .accessibilityHidden(!healthFabItemsVisible)
                }
            }

            HomeFabMainButton(
                isExpanded: isHealthFabExpanded,
                accessibilityLabel: isHealthFabExpanded
                    ? l.tr(zh: "收起健康菜单", en: "Collapse health menu", de: "Gesundheitsmenü schließen")
                    : l.tr(zh: "展开健康菜单", en: "Open health menu", de: "Gesundheitsmenü öffnen"),
                action: toggleHealthFabMenu
            )
        }
    }

    var healthFabActionKinds: [HealthFabActionKind] {
        guard pet.canWriteHealthFacts else {
            return [.vaccinePassport, .archive, .pdf]
        }
        var actions: [HealthFabActionKind] = [
            .preventive,
            .visit,
            .medication,
            .vaccinePassport,
            .archive,
            .pdf,
            .symptom
        ]
        if !pet.isNeutered {
            actions.append(.heatCycle)
        }
        return actions
    }

    func openHealthFabMenu() {
        guard !isHealthFabExpanded else { return }
        healthFabItemsVisible = false
        withAnimation(GoMotion.fab) {
            isHealthFabExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(GoMotion.fab) {
                healthFabItemsVisible = true
            }
        }
    }

    func closeHealthFabMenu() {
        guard isHealthFabExpanded else { return }
        withAnimation(GoMotion.fab) {
            healthFabItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if isHealthFabExpanded, !healthFabItemsVisible {
                withAnimation(GoMotion.fab) {
                    isHealthFabExpanded = false
                }
            }
        }
    }

    func toggleHealthFabMenu() {
        OhanaFeedback.medium()
        isHealthFabExpanded ? closeHealthFabMenu() : openHealthFabMenu()
    }

    func performHealthFabAction(_ action: HealthFabActionKind) {
        guard action != .pdf || !isRenderingPDF else { return }
        OhanaFeedback.light()
        healthFabItemsVisible = false
        withAnimation(GoMotion.fab) {
            isHealthFabExpanded = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            switch action {
            case .preventive:
                openHealthRecord(.guided(.preventive), feedback: false)
            case .visit:
                openHealthRecord(.guided(.visit), feedback: false)
            case .medication:
                openMedicationPopup(feedback: false)
            case .vaccinePassport:
                showingPassport = true
            case .archive:
                showingHistory = true
            case .pdf:
                renderHealthPDF()
            case .symptom:
                openHealthRecord(.symptom, feedback: false)
            case .heatCycle:
                openHealthRecord(.heatCycle, feedback: false)
            }
        }
    }

    var healthInlinePopupTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.965, anchor: .bottom)),
            removal: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .bottom))
        )
    }

    func openHealthRecord(_ destination: HealthPlusDestination, feedback: Bool = true) {
        guard pet.canWriteHealthFacts else { return }
        if feedback { OhanaFeedback.light() }
        activeHealthSheet = nil
        withAnimation(GoMotion.sheet) {
            healthPlusDestination = destination
        }
    }

    func closeHealthRecordPopup(feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.sheet) {
            healthPlusDestination = nil
        }
    }

    func openHealthOverview(_ sheet: ActiveHealthSheet, feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.page) {
            activeHealthSheet = sheet
        }
    }

    func closeHealthOverview() {
        OhanaFeedback.light()
        withAnimation(GoMotion.page) {
            activeHealthSheet = nil
        }
    }

    func openMedicationPopup(feedback: Bool = true) {
        guard pet.canWriteHealthFacts else { return }
        if feedback { OhanaFeedback.light() }
        activeHealthSheet = nil
        healthPlusDestination = nil
        withAnimation(GoMotion.sheet) {
            showingMedicationPopup = true
        }
    }

    func closeMedicationPopup(feedback: Bool = true) {
        if feedback { OhanaFeedback.light() }
        withAnimation(GoMotion.sheet) {
            showingMedicationPopup = false
        }
    }

    func renderHealthPDF() {
        guard !isRenderingPDF else { return }
        isRenderingPDF = true
        Task {
            pdfURL = await PetVetSummaryPDFRenderer.render(pet: pet)
            isRenderingPDF = false
            if pdfURL != nil { showingPDFPreview = true }
        }
    }

    var healthHeroCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(healthStatusTitle)
                    .font(OhanaFont.adaptive(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(healthStatusSubtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(healthStatusColor)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    statusPill(icon: "shield.checkered", value: "\(max(0, preventiveTypes.count - duePreventiveCount))/\(preventiveTypes.count)")
                    statusPill(icon: "pill.fill", value: medicationStatusText)
                }
            }
            Spacer()
            Image(systemName: (healthAlerts.isEmpty && duePreventiveCount == 0) ? "checkmark.seal.fill" : "heart.text.square.fill")
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(healthStatusColor)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    func statusPill(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
            Text(value)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(isDark ? 0.10 : 0.06), in: Capsule())
    }

    var compactAlertsCard: some View {
        VStack(spacing: 10) {
            ForEach(healthAlerts.prefix(2)) { alert in
                HStack(spacing: 10) {
                    Image(systemName: alertIcon(for: alert.type))
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(alertColor(alert))
                        .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .background(alertColor(alert).opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(alert.detail)
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    severityBadge(alert.severity)
                }
            }
        }
        .padding(14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.input)
    }

    var healthDashboardCards: some View {
        VStack(spacing: 12) {
            healthDashboardCard(
                title: l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge"),
                value: nextPreventiveStatusText,
                detail: preventiveDashboardDetail,
                icon: "shield.checkered",
                tint: preventionTint,
                primaryTitle: l.tr(zh: "记录", en: "Log", de: "Eintragen"),
                secondaryTitle: l.tr(zh: "疫苗本", en: "Passport", de: "Impfpass"),
                primaryAction: { openHealthRecord(.guided(.preventive)) },
                secondaryAction: {
                    OhanaFeedback.light()
                    showingPassport = true
                },
                cardAction: { openHealthOverview(.preventiveOverview) }
            )
            healthDashboardCard(
                title: l.tr(zh: "用药", en: "Medication", de: "Medikamente"),
                value: medicationStatusText,
                detail: nextMedicationDoseText,
                icon: "pill.fill",
                tint: medicationTint,
                primaryTitle: medicationPrimaryButtonTitle,
                secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
                primaryAction: handleMedicationPrimaryAction,
                secondaryAction: {
                    OhanaFeedback.light()
                    healthPlusDestination = .medications
                },
                cardAction: { openHealthOverview(.medicationOverview) }
            )
            healthDashboardCard(
                title: l.tr(zh: "异常/就诊", en: "Symptoms & visits", de: "Auffälligkeiten & Besuche"),
                value: symptomStatusText,
                detail: symptomVisitDashboardDetail,
                icon: "waveform.path.ecg",
                tint: symptomVisitTint,
                primaryTitle: l.tr(zh: "症状", en: "Symptom", de: "Symptom"),
                secondaryTitle: l.tr(zh: "就诊", en: "Visit", de: "Besuch"),
                primaryAction: { openHealthRecord(.symptom) },
                secondaryAction: { openHealthRecord(.guided(.visit)) },
                cardAction: { openHealthOverview(.symptomVisitOverview) }
            )
        }
    }

    func healthDashboardCard(
        title: String,
        value: String,
        detail: String,
        icon: String,
        tint: Color,
        primaryTitle: String,
        secondaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        cardAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(tint.opacity(isDark ? 0.20 : 0.13))
                    .frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button {
                    primaryAction()
                } label: {
                    Text(primaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 64, height: 34)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    secondaryAction()
                } label: {
                    Text(secondaryTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 64, height: 34)
                        .background(Color.primary.opacity(isDark ? 0.10 : 0.07), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .onTapGesture(perform: cardAction)
    }
}
