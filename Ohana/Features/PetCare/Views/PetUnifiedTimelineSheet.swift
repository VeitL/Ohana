//
//  PetUnifiedTimelineSheet.swift
//  Ohana
//
//  Compatibility wrapper. The standalone Life Chronicle surface has been
//  merged into PetMomentsHubView.
//

import SwiftUI

struct PetUnifiedTimelineSheet: View {
    let pet: Pet

    var body: some View {
        PetMomentsHubRouteContainer(pet: pet)
    }
}
