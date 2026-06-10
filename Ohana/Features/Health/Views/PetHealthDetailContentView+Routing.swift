//
//  PetHealthDetailContentView+Routing.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension PetHealthDetailContentView {
    var sheetHealthPlusDestination: Binding<HealthPlusDestination?> {
        Binding(
            get: {
                guard healthPlusDestination?.usesInlineRecordPopup != true else { return nil }
                return healthPlusDestination
            },
            set: { newValue in
                if newValue == nil, healthPlusDestination?.usesInlineRecordPopup != true {
                    healthPlusDestination = nil
                } else if newValue?.usesInlineRecordPopup != true {
                    healthPlusDestination = newValue
                }
            }
        )
    }

    func openInitialSectionIfNeeded() {
        guard !didOpenInitialSection, let initialSection else { return }
        didOpenInitialSection = true
        DispatchQueue.main.async {
            switch initialSection {
            case .preventive:
                activeHealthSheet = .preventiveOverview
            case .medication:
                activeHealthSheet = .medicationOverview
            case .symptomVisit:
                activeHealthSheet = .symptomVisitOverview
            }
        }
    }

    @ViewBuilder
    func healthRecordInlineOverlay(_ destination: HealthPlusDestination) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(isDark ? 0.18 : 0.08), // ui-v4: allow modal scrim
                        Color.black.opacity(isDark ? 0.42 : 0.22) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closeHealthRecordPopup()
                }

                PetHealthRecordInlinePopup(
                    pet: pet,
                    initialType: healthRecordInitialType(for: destination),
                    entryMode: healthRecordEntryMode(for: destination),
                    onClose: {
                        closeHealthRecordPopup()
                    },
                    onSaved: {
                        healthAlerts = appServices.healthAlerts.scanAlerts(pets: [pet])
                        OhanaFeedback.success()
                        closeHealthRecordPopup(feedback: false)
                    }
                )
                .frame(maxHeight: min(proxy.size.height * 0.86, 680))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
                .transition(healthInlinePopupTransition)
            }
            .animation(GoMotion.sheet, value: healthPlusDestination?.id)
        }
        .ignoresSafeArea()
        .zIndex(40)
    }

    func healthRecordInitialType(for destination: HealthPlusDestination) -> HealthLogType {
        switch destination {
        case let .guided(mode):
            mode == .preventive ? .vaccine : .surgery
        case let .direct(type):
            type
        default:
            .general
        }
    }

    func healthRecordEntryMode(for destination: HealthPlusDestination) -> HealthRecordEntryMode? {
        if case let .guided(mode) = destination { return mode }
        return nil
    }

    var medicationInlineOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(isDark ? 0.16 : 0.08), // ui-v4: allow modal scrim
                        Color.black.opacity(isDark ? 0.42 : 0.22) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closeMedicationPopup()
                }

                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: true,
                    onClose: {
                        closeMedicationPopup()
                    },
                    onSaved: {
                        medicationDoseRefreshToken = UUID()
                        appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
                        OhanaFeedback.success()
                        closeMedicationPopup(feedback: false)
                    }
                )
                .frame(maxHeight: min(proxy.size.height * 0.88, 690))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
                .transition(healthInlinePopupTransition)
            }
            .animation(GoMotion.sheet, value: showingMedicationPopup)
        }
        .ignoresSafeArea()
        .zIndex(42)
    }
}
