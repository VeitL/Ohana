//
//  OhanaStateComponents.swift
//  Ohana
//
//  Canonical permission education and resilient feedback surfaces. These
//  views emit typed UI intent through closures and never request permissions,
//  mutate persistence, or own feature work.
//

import SwiftUI

enum OhanaPermissionKind: Equatable, Sendable {
    case location
    case notifications
    case photos

    fileprivate var systemImage: String {
        switch self {
        case .location:
            "location.fill"
        case .notifications:
            "bell.badge.fill"
        case .photos:
            "photo.fill"
        }
    }
}

enum OhanaPermissionState: Equatable, Sendable {
    case notRequested
    case denied
    case granted

    fileprivate var palette: OhanaStatusPalette {
        switch self {
        case .notRequested:
            .info
        case .denied:
            .warning
        case .granted:
            .success
        }
    }
}

/// Pre-permission and recovery surface. The caller supplies localized copy and
/// owns the actual permission request or Settings route.
struct OhanaPermissionCard: View {
    let permission: OhanaPermissionKind
    let state: OhanaPermissionState
    let title: String
    let stateLabel: String
    let message: String
    var actionLabel: String?
    var accessibilityIdentifier: String?
    var action: (() -> Void)?

    private var palette: OhanaStatusPalette { state.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: permission.systemImage)
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(palette.icon, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(stateLabel)
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(message)
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let actionLabel {
                actionSurface(label: actionLabel)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .if(accessibilityIdentifier != nil) { view in
            view.accessibilityIdentifier(accessibilityIdentifier ?? "ohana-permission-card")
        }
    }

    @ViewBuilder
    private func actionSurface(label: String) -> some View {
        if let action {
            Button(action: action) {
                Text(label)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(state == .granted ? Color.ohanaPrimaryText : Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(actionFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("\(accessibilityIdentifier ?? "ohana-permission-card")-action")
        } else {
            Text(label)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
    }

    private var actionFill: Color {
        state == .granted ? Color.ohanaCardSurface : Color.goPrimary
    }
}

enum OhanaFeedbackStateKind: Equatable, Sendable {
    case empty
    case loading
    case error
    case offline
    case success

    fileprivate var palette: OhanaStatusPalette {
        switch self {
        case .empty, .loading:
            .info
        case .error:
            .error
        case .offline:
            .warning
        case .success:
            .success
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .empty:
            "tray"
        case .loading:
            "arrow.triangle.2.circlepath"
        case .error:
            "exclamationmark.triangle.fill"
        case .offline:
            "wifi.slash"
        case .success:
            "checkmark.circle.fill"
        }
    }
}

/// Shared empty/loading/error/offline/success surface. Copy remains owned by
/// the caller so localization and feature meaning stay explicit.
struct OhanaFeedbackState: View {
    let state: OhanaFeedbackStateKind
    let title: String
    let message: String
    var actionLabel: String?
    var accessibilityIdentifier: String?
    var action: (() -> Void)?

    private var palette: OhanaStatusPalette { state.palette }

    var body: some View {
        VStack(spacing: 16) {
            stateIcon

            VStack(spacing: 8) {
                Text(title)
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(OhanaFont.callout())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionLabel {
                feedbackAction(label: actionLabel)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(palette.background, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .if(accessibilityIdentifier != nil) { view in
            view.accessibilityIdentifier(accessibilityIdentifier ?? "ohana-feedback-state")
        }
    }

    @ViewBuilder private var stateIcon: some View {
        if state == .loading {
            ProgressView()
                .controlSize(.large)
                .tint(palette.icon)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
        } else {
            Image(systemName: state.systemImage)
                .font(OhanaFont.title2(.bold))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 56, height: 56)
                .background(palette.icon, in: Circle())
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func feedbackAction(label: String) -> some View {
        if let action {
            Button(action: action) {
                Text(label)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("\(accessibilityIdentifier ?? "ohana-feedback-state")-action")
        } else {
            Text(label)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(palette.text)
                .frame(minHeight: 44)
        }
    }
}

private struct OhanaStatusPalette {
    let background: Color
    let border: Color
    let text: Color
    let icon: Color

    static let info = OhanaStatusPalette(
        background: .alertInfoBg,
        border: .alertInfoBorder,
        text: .alertInfoText,
        icon: .alertInfoIcon
    )
    static let warning = OhanaStatusPalette(
        background: .alertWarningBg,
        border: .alertWarningBorder,
        text: .alertWarningText,
        icon: .alertWarningIcon
    )
    static let error = OhanaStatusPalette(
        background: .alertErrorBg,
        border: .alertErrorBorder,
        text: .alertErrorText,
        icon: .alertErrorIcon
    )
    static let success = OhanaStatusPalette(
        background: .alertSuccessBg,
        border: .alertSuccessBorder,
        text: .alertSuccessText,
        icon: .alertSuccessIcon
    )
}
