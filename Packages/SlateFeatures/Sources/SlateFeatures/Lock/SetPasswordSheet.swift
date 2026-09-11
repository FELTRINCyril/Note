import SwiftUI
import SlateUI

/// Boite de dialogue "Definir un mot de passe" (design P3, artboard C).
///
/// Deux exigences fermes du design :
/// - Le bouton "Definir" reste desactive tant que la confirmation ne correspond pas au
///   mot de passe (`isSubmitDisabled`).
/// - Le message d'erreur ("Les deux mots de passe ne correspondent pas") ne s'affiche
///   qu'A LA PERTE DE FOCUS du champ de confirmation, pas a chaque frappe -- voir
///   `hasBlurredConfirmationField`/`focusedField`.
///
/// L'erreur est portee par la bordure du champ ET par une ligne de texte a icone
/// (`mismatchLine`), jamais par la couleur seule.
struct SetPasswordSheet: View {
    /// Vrai si Touch ID/Face ID est disponible sur cette machine
    /// (`LockService.isBiometricsAvailable`) : sans biometrie disponible, proposer la
    /// case "Autoriser Touch ID" n'aurait aucun sens.
    let isBiometricsAvailable: Bool
    /// `password`/`hint` (`nil` si vide)/`allowBiometrics` -> vrai si l'enregistrement
    /// a reussi (voir `LockService.setPassword(_:hint:allowBiometrics:)`, qui peut
    /// echouer si le Keychain refuse l'ecriture).
    let onSubmit: (String, String?, Bool) -> Bool
    let onCancel: () -> Void

    private enum Field: Hashable {
        case password
        case confirmation
        case hint
    }

    @State private var password = ""
    @State private var confirmation = ""
    @State private var hint = ""
    @State private var allowsBiometrics = true
    @State private var hasBlurredConfirmationField = false
    @State private var showsSaveFailureAlert = false
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "lock.setPassword.title", bundle: .module))
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            Text(String(localized: "lock.setPassword.explanation", bundle: .module))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)

            passwordField
            confirmationField
            hintField

            if isBiometricsAvailable {
                Toggle(String(localized: "lock.setPassword.allowBiometrics", bundle: .module), isOn: $allowsBiometrics)
                    .toggleStyle(.switch)
            }

            HStack {
                Spacer()
                Button(String(localized: "action.cancel", bundle: .module), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "lock.setPassword.confirm", bundle: .module), action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSubmitDisabled)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 380)
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .confirmation, newValue != .confirmation {
                hasBlurredConfirmationField = true
            }
        }
        .alert(
            String(localized: "lock.setPassword.saveFailure.title", bundle: .module),
            isPresented: $showsSaveFailureAlert
        ) {
            Button(String(localized: "action.ok", bundle: .module), role: .cancel) {}
        }
    }

    // MARK: - Champs

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "lock.setPassword.passwordLabel", bundle: .module))
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
            SecureField(String(localized: "lock.setPassword.passwordField", bundle: .module), text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
            if !password.isEmpty {
                strengthGauge
            }
        }
    }

    private var strengthGauge: some View {
        let strength = PasswordStrength.evaluate(password)
        return HStack(spacing: Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(SlateColor.borderDefault)
                    Capsule()
                        .fill(strength.fillColor)
                        .frame(width: proxy.size.width * strength.fillFraction)
                }
            }
            .frame(height: Spacing.xs)
            Text(strength.localizedLabel)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strengthAccessibilityLabel(for: strength))
    }

    private func strengthAccessibilityLabel(for strength: PasswordStrength) -> String {
        let template = String(localized: "lock.setPassword.strength.accessibilityLabel", bundle: .module)
        return String(format: template, strength.localizedLabel)
    }

    private var confirmationField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "lock.setPassword.confirmationLabel", bundle: .module))
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
            SecureField(String(localized: "lock.setPassword.confirmationField", bundle: .module), text: $confirmation)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .confirmation)
                .overlay {
                    if showsMismatchError {
                        RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                            .strokeBorder(SlateColor.semanticError, lineWidth: SlateGeometry.strokeHairline)
                    }
                }
            if showsMismatchError {
                mismatchLine
            }
        }
    }

    private var mismatchLine: some View {
        Label {
            Text(String(localized: "lock.setPassword.mismatch", bundle: .module))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.semanticError)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .slateIconFont(SlateGeometry.searchFieldIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.semanticError)
        }
        .accessibilityElement(children: .combine)
    }

    private var hintField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "lock.setPassword.hintLabel", bundle: .module))
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
            TextField(String(localized: "lock.setPassword.hintField", bundle: .module), text: $hint)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .hint)
        }
    }

    // MARK: - Validation / soumission

    private var showsMismatchError: Bool {
        hasBlurredConfirmationField && !confirmation.isEmpty && confirmation != password
    }

    private var isSubmitDisabled: Bool {
        password.isEmpty || confirmation != password
    }

    private func submit() {
        guard !isSubmitDisabled else { return }
        let trimmedHint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded = onSubmit(password, trimmedHint.isEmpty ? nil : trimmedHint, allowsBiometrics)
        guard succeeded else {
            showsSaveFailureAlert = true
            return
        }
    }
}

#Preview("SetPasswordSheet - Touch ID disponible") {
    SetPasswordSheet(isBiometricsAvailable: true, onSubmit: { _, _, _ in true }, onCancel: {})
        .preferredColorScheme(.dark)
}

#Preview("SetPasswordSheet - sans Touch ID") {
    SetPasswordSheet(isBiometricsAvailable: false, onSubmit: { _, _, _ in true }, onCancel: {})
        .preferredColorScheme(.dark)
}
