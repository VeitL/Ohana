//
//  CrewRosterDeleteConfirmationSheet.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct CrewRosterDeleteConfirmationSheet: View {
    let title: String
    let name: String
    let warning: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var confirmName = ""

    private var l: L10n { L10n(appLanguage) }

    private var canDelete: Bool {
        ConfirmationNameMatcher.matches(confirmName, expectedName: name)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(l.tr(zh: "输入名字后才能继续", en: "Type the name to continue", de: "Zum Fortfahren Namen eingeben"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Text(warning)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))

                TextField(name, text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.callout(.bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                            .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text(l.cancel)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: onDelete) {
                        Text(l.tr(zh: "删除", en: "Delete", de: "Loeschen"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(canDelete ? Color.ohanaPrimaryActionText : Color.primary.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                }
            }
            .padding(20)
        }
    }
}
