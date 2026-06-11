//
//  PetMomentsHubRouteContainer.swift
//  Ohana
//
//  Route-scoped data boundary for the pet moments hub.
//

import SwiftData
import SwiftUI

struct PetMomentsHubRouteContainer: View {
    let pet: Pet

    @Query private var sharedCareSessions: [SharedCareSession] // smoothness: allow route-scoped moments history mounts only after explicit navigation.

    init(pet: Pet) {
        self.pet = pet
        _sharedCareSessions = Query(sort: \SharedCareSession.date, order: .reverse)
    }

    var body: some View {
        PetMomentsHubView(pet: pet, sharedCareSessions: sharedCareSessions)
    }
}
