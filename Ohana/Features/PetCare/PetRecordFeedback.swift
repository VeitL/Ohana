import SwiftUI

/// Success is supplied only by a committed domain command.
struct PetRecordReceiptView: View {
    let onView: () -> Void
    let onDismiss: () -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    var body: some View {
        let copy = PetCareExperienceCopy(l: L10n(appLanguage))
        HStack(spacing: 12) {
            Label(copy.recorded, systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.goPrimary)
            Spacer(minLength: 0)
            Button(copy.viewRecord, action: onView)
                .accessibilityIdentifier("pet-record-view-saved")
            Button(action: onDismiss) {
                Image(systemName: "xmark").accessibilityHidden(true)
            }
            .accessibilityLabel(L10n(appLanguage).tr(zh: "关闭", en: "Close", de: "Schließen", es: "Cerrar", pt: "Fechar", fr: "Fermer", ja: "閉じる", ko: "닫기", it: "Chiudi"))
            .frame(minWidth: 44, minHeight: 44)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.card))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityIdentifier("pet-record-committed")
    }
}

private struct PetRecordFeedbackModifier: ViewModifier {
    @Binding var receipt: PetRecordReference?
    @State private var presentedRecord: PetRecordReference?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if let receipt {
                    PetRecordReceiptView(
                        onView: { presentedRecord = receipt },
                        onDismiss: { self.receipt = nil }
                    )
                }
            }
            .sheet(item: $presentedRecord) { reference in
                AppPetDetailSheetRouteContainer(
                    id: reference.petID,
                    destination: .momentHistory(reference.route),
                    onMissing: { presentedRecord = nil }
                )
            }
    }
}

extension View {
    func petRecordFeedback(_ receipt: Binding<PetRecordReference?>) -> some View {
        modifier(PetRecordFeedbackModifier(receipt: receipt))
    }
}
