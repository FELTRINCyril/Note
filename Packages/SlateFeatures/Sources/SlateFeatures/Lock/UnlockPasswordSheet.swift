import SwiftUI
import SlateUI

/// Boite de dialogue "Utiliser le mot de passe" (design P3, artboard C : lien
/// secondaire de `LockedNoteView`, et repli quand Touch ID est indisponible).
///
/// `onSubmit` retourne `Bool` (succes/echec) plutot qu'un `throws` : un mot de passe
/// incorrect est une issue NORMALE de ce flux (voir `LockService.unlock(_:password:)`),
/// pas une anomalie -- meme convention que `LockService` lui-meme.
struct UnlockPasswordSheet: View {
    let onSubmit: (String) -> Bool
    let onCancel: () -> Void

    @State private var password = ""
    @State private var showsIncorrectPasswordError = false
    @FocusState private var isPasswordFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "lock.unlockPassword.title", bundle: .module))
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SecureField(String(localized: "lock.unlockPassword.field", bundle: .module), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($isPasswordFieldFocused)
                    .onChange(of: password) { showsIncorrectPasswordError = false }
                    .onSubmit(submit)

                if showsIncorrectPasswordError {
                    errorLine
                }
            }

            HStack {
                Spacer()
                Button(String(localized: "action.cancel", bundle: .module), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "lock.unlockPassword.confirm", bundle: .module), action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 320)
        .onAppear { isPasswordFieldFocused = true }
    }

    private var errorLine: some View {
        Label {
            Text(String(localized: "lock.unlockPassword.incorrect", bundle: .module))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.semanticError)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .slateIconFont(SlateGeometry.searchFieldIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.semanticError)
        }
        .accessibilityElement(children: .combine)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        guard onSubmit(password) else {
            showsIncorrectPasswordError = true
            password = ""
            return
        }
    }
}

#Preview("UnlockPasswordSheet") {
    UnlockPasswordSheet(onSubmit: { _ in false }, onCancel: {})
}
