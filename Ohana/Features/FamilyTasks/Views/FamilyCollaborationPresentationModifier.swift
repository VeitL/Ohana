//
//  FamilyCollaborationPresentationModifier.swift
//  Ohana
//
//  Sheet route host for family collaboration.
//

import SwiftUI

struct FamilyCollaborationPresentationModifier<MoreContent: View>: ViewModifier {
    @Binding var sheetRoute: FamilyCollaborationSheetRoute?
    let title: String
    let doneTitle: String
    let onDismiss: () -> Void
    @ViewBuilder var moreContent: () -> MoreContent

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheetRoute, onDismiss: onDismiss) { route in
                sheetDestination(for: route)
            }
    }

    @ViewBuilder
    private func sheetDestination(for route: FamilyCollaborationSheetRoute) -> some View {
        switch route {
        case .moreCollaboration:
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    moreContent()
                        .padding(20)
                        .padding(.bottom, 24)
                }
                .background(OhanaAppBackground().ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(doneTitle) {
                            sheetRoute = nil
                        }
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                    }
                }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow more collaboration is a long overview
        }
    }
}

extension View {
    func familyCollaborationPresentations(
        sheetRoute: Binding<FamilyCollaborationSheetRoute?>,
        title: String,
        doneTitle: String,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder moreContent: @escaping () -> some View
    ) -> some View {
        modifier(
            FamilyCollaborationPresentationModifier(
                sheetRoute: sheetRoute,
                title: title,
                doneTitle: doneTitle,
                onDismiss: onDismiss,
                moreContent: moreContent
            )
        )
    }
}
