//
//  ExpandedQuickActionEditController.swift
//  Ohana
//
//  Small state holder for expanded-card quick action edit mode.
//

import Combine
import SwiftUI

@MainActor
final class ExpandedQuickActionEditController: ObservableObject {
    @Published var isEditMode = false
    @Published var jiggle = false
    @Published var items: [QuickActionItem] = []
    @Published var draggingItemId: String?

    private var jiggleSession = UUID()

    func enter(with items: [QuickActionItem], animation: Animation) {
        let session = UUID()
        jiggleSession = session
        self.items = items
        draggingItemId = nil
        jiggle = false
        withAnimation(animation) {
            isEditMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard self.jiggleSession == session, self.isEditMode else { return }
            withAnimation(nil) {
                self.jiggle = true
            }
        }
    }

    func exit(animation: Animation) {
        jiggleSession = UUID()
        draggingItemId = nil
        withAnimation(nil) {
            jiggle = false
        }
        withAnimation(animation) {
            isEditMode = false
        }
    }

    func reset() {
        jiggleSession = UUID()
        draggingItemId = nil
        isEditMode = false
        jiggle = false
    }
}
