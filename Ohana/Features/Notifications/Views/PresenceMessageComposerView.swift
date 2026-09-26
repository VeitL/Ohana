//
//  PresenceMessageComposerView.swift
//  Ohana
//

import MessageUI
import SwiftUI

nonisolated enum PresenceMessageComposerOutcome: Equatable, Sendable {
    case sent
    case cancelled
    case failed
}

@MainActor
struct PresenceMessageComposerView: UIViewControllerRepresentable {
    let draft: PresenceSafetyMessageDraft
    let onCompletion: (PresenceMessageComposerOutcome) -> Void

    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = draft.recipients
        controller.body = draft.body
        return controller
    }

    func updateUIViewController(_: MFMessageComposeViewController, context _: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onCompletion: (PresenceMessageComposerOutcome) -> Void

        init(onCompletion: @escaping (PresenceMessageComposerOutcome) -> Void) {
            self.onCompletion = onCompletion
        }

        func messageComposeViewController(
            _: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            switch result {
            case .sent:
                onCompletion(.sent)
            case .cancelled:
                onCompletion(.cancelled)
            case .failed:
                onCompletion(.failed)
            @unknown default:
                onCompletion(.failed)
            }
        }
    }
}

@MainActor
struct PresenceMessageCopyFallbackView: View {
    let contact: SafetyContactSnapshot
    let draft: PresenceSafetyMessageDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var copiedValue: CopiedValue?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        copy(
                            zh: "联系人",
                            en: "Contact",
                            de: "Kontakt",
                            es: "Contacto",
                            pt: "Contato",
                            fr: "Contact",
                            ja: "連絡先",
                            ko: "연락처",
                            it: "Contatto"
                        ),
                        value: contact.name
                    )
                    Text(contact.phoneNumber)
                        .textSelection(.enabled)
                        .accessibilityLabel(phoneAccessibilityLabel)
                    Text(draft.body)
                        .textSelection(.enabled)
                        .accessibilityLabel(messageAccessibilityLabel)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = contact.phoneNumber
                        copiedValue = .phoneNumber
                    } label: {
                        Label(copyPhoneTitle, systemImage: "doc.on.doc")
                    }
                    .accessibilityHint(copyPhoneHint)

                    Button {
                        UIPasteboard.general.string = draft.body
                        copiedValue = .message
                    } label: {
                        Label(copyMessageTitle, systemImage: "text.quote")
                    }
                    .accessibilityHint(copyMessageHint)
                } footer: {
                    Text(fallbackExplanation)
                }
            }
            .navigationTitle(fallbackTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) { dismiss() }
                }
            }
            .alert(item: $copiedValue) { value in
                Alert(
                    title: Text(value == .phoneNumber ? copiedPhoneNotice : copiedMessageNotice),
                    dismissButton: .default(Text(doneTitle))
                )
            }
        }
    }

    private enum CopiedValue: String, Identifiable {
        case phoneNumber
        case message

        var id: String { rawValue }
    }

    private func copy(
        zh: String,
        en: String,
        de: String,
        es: String,
        pt: String,
        fr: String,
        ja: String,
        ko: String,
        it: String
    ) -> String {
        l.tr(zh: zh, en: en, de: de, es: es, pt: pt, fr: fr, ja: ja, ko: ko, it: it)
    }

    private var fallbackTitle: String {
        copy(
            zh: "复制联系信息",
            en: "Copy contact details",
            de: "Kontaktdaten kopieren",
            es: "Copiar datos de contacto",
            pt: "Copiar dados de contato",
            fr: "Copier les coordonnées",
            ja: "連絡情報をコピー",
            ko: "연락처 정보 복사",
            it: "Copia i dati di contatto"
        )
    }

    private var fallbackExplanation: String {
        copy(
            zh: "此设备无法发送短信。你可以复制号码和文案，再用可用的通讯方式联系对方。",
            en: "This device cannot send text messages. Copy the number and message, then use an available communication method.",
            de: "Dieses Gerät kann keine SMS senden. Kopiere Nummer und Text und nutze einen verfügbaren Kontaktweg.",
            es: "Este dispositivo no puede enviar SMS. Copia el número y el mensaje y usa otro medio disponible.",
            pt: "Este dispositivo não pode enviar SMS. Copie o número e a mensagem e use outro meio disponível.",
            fr: "Cet appareil ne peut pas envoyer de SMS. Copiez le numéro et le message, puis utilisez un autre moyen disponible.",
            ja: "このデバイスではSMSを送信できません。番号と文面をコピーし、利用可能な連絡手段を使ってください。",
            ko: "이 기기에서는 문자를 보낼 수 없습니다. 번호와 문구를 복사해 사용 가능한 연락 수단을 이용하세요.",
            it: "Questo dispositivo non può inviare SMS. Copia numero e messaggio e usa un metodo di contatto disponibile."
        )
    }

    private var copyPhoneTitle: String {
        copy(
            zh: "复制电话号码",
            en: "Copy phone number",
            de: "Telefonnummer kopieren",
            es: "Copiar número de teléfono",
            pt: "Copiar número de telefone",
            fr: "Copier le numéro",
            ja: "電話番号をコピー",
            ko: "전화번호 복사",
            it: "Copia numero di telefono"
        )
    }

    private var copyMessageTitle: String {
        copy(
            zh: "复制短信文案",
            en: "Copy message",
            de: "Nachricht kopieren",
            es: "Copiar mensaje",
            pt: "Copiar mensagem",
            fr: "Copier le message",
            ja: "メッセージをコピー",
            ko: "문구 복사",
            it: "Copia messaggio"
        )
    }

    private var copiedPhoneNotice: String {
        copy(
            zh: "电话号码已复制",
            en: "Phone number copied",
            de: "Telefonnummer kopiert",
            es: "Número copiado",
            pt: "Número copiado",
            fr: "Numéro copié",
            ja: "電話番号をコピーしました",
            ko: "전화번호를 복사했습니다",
            it: "Numero copiato"
        )
    }

    private var copiedMessageNotice: String {
        copy(
            zh: "短信文案已复制",
            en: "Message copied",
            de: "Nachricht kopiert",
            es: "Mensaje copiado",
            pt: "Mensagem copiada",
            fr: "Message copié",
            ja: "メッセージをコピーしました",
            ko: "문구를 복사했습니다",
            it: "Messaggio copiato"
        )
    }

    private var doneTitle: String {
        copy(
            zh: "完成",
            en: "Done",
            de: "Fertig",
            es: "Listo",
            pt: "Concluído",
            fr: "Terminé",
            ja: "完了",
            ko: "완료",
            it: "Fine"
        )
    }

    private var phoneAccessibilityLabel: String { "\(copyPhoneTitle): \(contact.phoneNumber)" }
    private var messageAccessibilityLabel: String { "\(copyMessageTitle): \(draft.body)" }
    private var copyPhoneHint: String { copiedPhoneNotice }
    private var copyMessageHint: String { copiedMessageNotice }
}
