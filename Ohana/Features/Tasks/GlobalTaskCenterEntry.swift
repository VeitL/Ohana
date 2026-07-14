//
//  GlobalTaskCenterEntry.swift
//  Ohana
//
//  Shared toolbar entry for normal pushed detail pages. Editors and transient
//  confirmation surfaces intentionally do not apply this modifier.
//

import SwiftUI

private struct GlobalTaskCenterToolbarModifier: ViewModifier {
    let action: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        OhanaFeedback.light()
                        action()
                    } label: {
                        Image(systemName: "checklist") // a11y: allow decorative symbol inside the labeled 44pt toolbar button
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(L10n(appLanguage).tr(
                        zh: "打开待办中心",
                        en: "Open task center",
                        de: "Aufgabenzentrum öffnen"
                    ))
                    .accessibilityIdentifier("global-task-center-action")
                }
            }
    }
}

extension View {
    func globalTaskCenterToolbar(action: @escaping () -> Void) -> some View {
        modifier(GlobalTaskCenterToolbarModifier(action: action))
    }
}
