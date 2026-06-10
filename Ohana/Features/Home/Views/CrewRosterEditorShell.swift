//
//  CrewRosterEditorShell.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct CrewRosterEditorShell<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goCardWhite)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("取消")

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.goCardWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.goCardWhite.opacity(0.66))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    onSave()
                } label: {
                    Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("保存")
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    content()
                }
                .padding(.bottom, 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arkInk.opacity(0.50), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 0.75)
        )
    }
}
