import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct HumanLabImportIdleView: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onScanPaperReport: () -> Void
    let onChoosePDF: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            localPrivacyNotice

            HumanLabImportCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(HumanLabScanCopy.text(.chooseReportSource, l: l))
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { sourceActions }
                        VStack(spacing: 10) { sourceActions }
                    }

                    Text(HumanLabScanCopy.text(.sourceGuidance, l: l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }

            HumanLabImportCard {
                Label {
                    Text(HumanLabScanCopy.text(.medicalDisclaimer, l: l))
                    .font(OhanaFont.callout(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "cross.case.fill").accessibilityHidden(true)
                        .foregroundStyle(Color.goYellow)
                }
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var sourceActions: some View {
        if VNDocumentCameraViewController.isSupported {
            Button {
                onScanPaperReport()
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HumanLabImportSourceActionLabel(
                    icon: "doc.viewfinder.fill",
                    title: HumanLabScanCopy.text(.scanPaperReport, l: l),
                    tint: .goTeal
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-lab-import-camera-action")
        }

        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: HumanLabDocumentCameraView.maximumPageCount,
            matching: .images
        ) {
            HumanLabImportSourceActionLabel(
                icon: "photo.on.rectangle.angled",
                title: HumanLabScanCopy.text(.choosePhotos, l: l),
                tint: .goOrange
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-lab-import-photos-action")

        Button {
            onChoosePDF()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HumanLabImportSourceActionLabel(
                icon: "doc.fill",
                title: HumanLabScanCopy.text(.choosePDF, l: l),
                tint: .goBlue
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-lab-import-pdf-action")
    }

    private var localPrivacyNotice: some View {
        HumanLabImportCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "iphone.and.arrow.forward.inward").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 44, height: 44)
                    .background(Color.goTeal.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(HumanLabScanCopy.text(.privacyTitle, l: l))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(HumanLabScanCopy.text(.privacyDetail, l: l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .accessibilityIdentifier("human-lab-import-local-privacy-notice")
    }
}

struct HumanLabImportRecognizingView: View {
    let onCancel: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.goTeal)
            Text(HumanLabScanCopy.text(.recognizingTitle, l: l))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(HumanLabScanCopy.text(.recognizingDetail, l: l))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button(role: .cancel, action: onCancel) {
                Text(HumanLabScanCopy.text(.cancelRecognition, l: l))
                    .font(OhanaFont.callout(.bold))
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("human-lab-import-cancel-recognition-action")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}

struct HumanLabImportRecognitionFailureView: View {
    let failureDescription: String?
    let onRetry: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass").accessibilityHidden(true)
                .font(OhanaFont.metric(size: 42, .bold))
                .foregroundStyle(Color.goOrange)
            Text(HumanLabScanCopy.text(.recognitionFailureTitle, l: l))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)
            Text(failureDescription ?? HumanLabScanCopy.text(.genericRecognitionFailure, l: l))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                Label(HumanLabScanCopy.text(.chooseAnotherReport, l: l), systemImage: "arrow.clockwise")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 46)
                    .background(Color.goTeal, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-lab-import-recognition-retry-action")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

struct HumanLabImportCompletedView: View {
    let importedCount: Int

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.metric(size: 48, .bold))
                .foregroundStyle(Color.goTeal)
            Text(HumanLabScanCopy.text(.completedTitle, l: l))
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.text(HumanLabScanCopy.completedDetail(importedCount: importedCount)))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .accessibilityIdentifier("human-lab-import-completed-state")
    }
}

struct HumanLabImportSourceActionLabel: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(tint)
            Text(title)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct HumanLabImportCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}
