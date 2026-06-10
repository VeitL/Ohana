//
//  MemberProfileRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for member profile destinations.
//

import SwiftData
import SwiftUI

struct AppPetRouteContainer: View {
    @Query private var pets: [Pet]
    let initialTab: PetDetailTab

    init(id: UUID, initialTab: PetDetailTab) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.initialTab = initialTab
    }

    var body: some View {
        if let pet = pets.first {
            if initialTab == .health {
                PetHealthDetailView(pet: pet)
            } else {
                PetBasicInfoDetailView(pet: pet)
            }
        } else {
            MemberProfileMissingEntityView(kind: "pet")
        }
    }
}

struct AppHumanRouteContainer: View {
    @Query private var humans: [Human]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query private var allPendingReminders: [Reminder]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]

    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    init(
        id: UUID,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        let humanKey = id.uuidString
        let humanType = "Human"
        let pendingStatus = "pending"
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        _allPendingReminders = Query(
            filter: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus &&
                    reminder.event?.relatedEntityType == humanType &&
                    reminder.event?.relatedEntityId == humanKey
            },
            sort: \.scheduledAt
        )
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
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        if let human = humans.first {
            HumanDetailView(
                human: human,
                allPets: allPets,
                allHumans: allHumans,
                allPendingReminders: allPendingReminders,
                allMeds: allMeds,
                allReports: allReports,
                onPresentCoconutLog: onPresentCoconutLog
            )
        } else {
            MemberProfileMissingEntityView(kind: "human")
        }
    }
}

private struct MemberProfileMissingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
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
