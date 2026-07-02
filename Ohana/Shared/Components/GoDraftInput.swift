//
//  GoDraftInput.swift
//  Ohana
//
//  Lightweight draft-backed inputs for large Go Focus sheets.
//

import SwiftUI
import UIKit

private final class GoKeyboardResponderBox {
    weak var responder: UIResponder?
}

enum GoKeyboard {
    private static let responderBox = GoKeyboardResponderBox()

    @MainActor
    static func dismiss() {
        responderBox.responder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.ohanaCaptureFirstResponder(_:)), to: nil, from: responderBox, for: nil)
        responderBox.responder?.resignFirstResponder()
    }
}

private extension UIResponder {
    @objc func ohanaCaptureFirstResponder(_ sender: Any) {
        (sender as? GoKeyboardResponderBox)?.responder = self
    }
}

struct GoDraftTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var commitDelayNanoseconds: UInt64 = 180_000_000
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var capitalization: TextInputAutocapitalization = .sentences
    var disablesAutocorrection = true
    var autoFocusDelay: Double?
    var onCommit: ((String) -> Void)?

    @State private var draftText: String
    @State private var commitTask: Task<Void, Never>? = nil
    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        commitDelayNanoseconds: UInt64 = 180_000_000,
        keyboardType: UIKeyboardType = .default,
        submitLabel: SubmitLabel = .done,
        capitalization: TextInputAutocapitalization = .sentences,
        disablesAutocorrection: Bool = true,
        autoFocusDelay: Double? = nil,
        onCommit: ((String) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.commitDelayNanoseconds = commitDelayNanoseconds
        self.keyboardType = keyboardType
        self.submitLabel = submitLabel
        self.capitalization = capitalization
        self.disablesAutocorrection = disablesAutocorrection
        self.autoFocusDelay = autoFocusDelay
        self.onCommit = onCommit
        self._draftText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        TextField(placeholder, text: $draftText, axis: axis) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            .focused($isFocused)
            .keyboardType(keyboardType)
            .submitLabel(submitLabel)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(disablesAutocorrection)
            .onChange(of: draftText) { _, newValue in
                scheduleCommit(newValue)
            }
            .onChange(of: text) { _, newValue in
                if newValue != draftText {
                    draftText = newValue
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commitNow()
                }
            }
            .onSubmit {
                commitNow()
                isFocused = false
                GoKeyboard.dismiss()
            }
            .onAppear {
                guard let autoFocusDelay else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + autoFocusDelay) {
                    isFocused = true
                }
            }
            .onDisappear {
                commitNow()
            }
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private func scheduleCommit(_ value: String) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: commitDelayNanoseconds)
            if !Task.isCancelled {
                commit(value)
            }
        }
    }

    private func commitNow() {
        commitTask?.cancel()
        commitTask = nil
        commit(draftText)
    }

    private func commit(_ value: String) {
        if text != value {
            text = value
        }
        onCommit?(value)
    }
}

struct GoDraftTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 80
    var commitDelayNanoseconds: UInt64 = 220_000_000
    var onCommit: ((String) -> Void)?

    @State private var draftText: String
    @State private var commitTask: Task<Void, Never>? = nil
    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 80,
        commitDelayNanoseconds: UInt64 = 220_000_000,
        onCommit: ((String) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.commitDelayNanoseconds = commitDelayNanoseconds
        self.onCommit = onCommit
        self._draftText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if draftText.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.75))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draftText)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
        }
        .onChange(of: draftText) { _, newValue in
            scheduleCommit(newValue)
        }
        .onChange(of: text) { _, newValue in
            if newValue != draftText {
                draftText = newValue
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                commitNow()
            }
        }
        .onDisappear {
            commitNow()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func scheduleCommit(_ value: String) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: commitDelayNanoseconds)
            if !Task.isCancelled {
                commit(value)
            }
        }
    }

    private func commitNow() {
        commitTask?.cancel()
        commitTask = nil
        commit(draftText)
    }

    private func commit(_ value: String) {
        if text != value {
            text = value
        }
        onCommit?(value)
    }
}

extension View {
    func goKeyboardDoneToolbar(title: String = "完成") -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(title) {
                    GoKeyboard.dismiss()
                }
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
            }
        }
    }
}
