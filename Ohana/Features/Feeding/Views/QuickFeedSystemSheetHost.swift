//
//  QuickFeedSystemSheetHost.swift
//  Ohana
//
//  System sheet modifier extracted from QuickFeedDetailSheet.
//

import SwiftUI

struct QuickFeedSystemSheetHost: ViewModifier {
    let systemSheet: Binding<ActiveFeedSheet?>
    let makeContent: (ActiveFeedSheet) -> AnyView

    func body(content: Content) -> some View {
        content.sheet(item: systemSheet) { sheet in
            makeContent(sheet)
                .ohanaSheetPagePresentation() // ui-v4: allow quick feed nested history/settings sheets share page chrome
        }
    }
}
