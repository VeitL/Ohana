//
//  HumanDetailSheetRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for human detail sheets.
//

import SwiftData
import SwiftUI

enum AppHumanDetailSheetDestination: Hashable {
    case basicInfo
    case medication
    case weight
    case workout
    case workoutDashboard
    case metrics
    case report
    case expense
    case wishlist
    case note
}

struct HumanAllFeaturesRouteContainer: View {
    @Query private var humans: [Human]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]
    @Query private var allExpenses: [PetExpenseLog]

    let onMissing: () -> Void
    let onOpenDestination: (UUID, HumanAllFeatureDestination) -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onOpenDestination: @escaping (UUID, HumanAllFeatureDestination) -> Void
    ) {
        let humanKey = id.uuidString
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id && human.trashedAt == nil
        })
        _allMeds = Query(
            filter: #Predicate<HumanMedication> { med in
                med.humanId == humanKey
            },
            sort: \.createdAt
        )
        _allReports = Query(
            filter: #Predicate<HumanHealthReport> { report in
                report.humanId == humanKey
            },
            sort: \.reportDate,
            order: .reverse
        )
        _allExpenses = Query(
            filter: #Predicate<PetExpenseLog> { expense in
                expense.executorId == humanKey
            },
            sort: \.date,
            order: .reverse
        )
        self.onMissing = onMissing
        self.onOpenDestination = onOpenDestination
    }

    var body: some View {
        if let human = humans.first {
            HumanAllFeaturesSheet(
                human: human,
                allMeds: allMeds,
                allReports: allReports,
                allExpenses: allExpenses,
                onOpenDestination: { destination in
                    onOpenDestination(human.id, destination)
                }
            )
        } else {
            HumanRouteMissingEntityView(kind: "human")
                .onAppear(perform: onMissing)
        }
    }
}

struct AppHumanDetailSheetRouteContainer: View {
    @Query private var humans: [Human]
    let destination: AppHumanDetailSheetDestination
    let onMissing: () -> Void
    let onHumanDoseTaken: (UUID) -> Void

    init(
        id: UUID,
        destination: AppHumanDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in }
    ) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id && human.trashedAt == nil
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onHumanDoseTaken = onHumanDoseTaken
    }

    var body: some View {
        if let human = humans.first {
            humanDestination(for: human)
        } else {
            HumanRouteMissingEntityView(kind: "human")
                .onAppear(perform: onMissing)
        }
    }

    @ViewBuilder
    private func humanDestination(for human: Human) -> some View {
        switch destination {
        case .basicInfo:
            NavigationStack { HumanBasicInfoDetailView(human: human) }
        case .medication:
            NavigationStack {
                HumanMedicationView(
                    human: human,
                    showsDoneButton: true,
                    onDoseTaken: {
                        onHumanDoseTaken(human.id)
                    }
                )
            }
        case .weight:
            NavigationStack { HumanWeightHistoryView(human: human) }
        case .workout:
            HumanWorkoutHistoryView(human: human)
        case .workoutDashboard:
            CoHealthDashboardFullView(human: human)
        case .metrics:
            HumanHealthCheckupView(human: human)
        case .report:
            HumanHealthReportView(human: human)
        case .expense:
            NavigationStack { HumanExpenseDetailView(human: human) }
        case .wishlist:
            HumanWishlistView(human: human)
        case .note:
            HumanNoteHistorySheet(human: human)
        }
    }
}

private struct HumanRouteMissingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text("内容已不可用")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
