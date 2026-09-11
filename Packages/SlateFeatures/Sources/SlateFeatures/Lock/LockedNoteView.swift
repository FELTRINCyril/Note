import SwiftUI
import SlateUI

/// Ecran affiche a la place du contenu d'une note verrouillee (design P3, artboard C).
///
/// **Regle de securite absolue de ce fichier** : cette vue ne recoit et ne lit JAMAIS
/// `Note.blocks`/`plainText`/`snippetText` -- seul `noteTitle` (une `String` deja
/// extraite par l'appelant) et `passwordHint` (lisible sans authentification, voir
/// `LockService.passwordHint`) lui parviennent. C'est `NoteDetailColumnView` qui
/// garantit qu'aucune instance de `SlateEditor.NoteDocumentView` n'est meme construite
/// tant que la note reste verrouillee -- voir sa documentation.
///
/// **Regle de design ferme** (artboard C) : sans Touch ID/Face ID disponible, le bouton
/// principal devient "Saisir le mot de passe" et le lien secondaire disparait --
/// jamais un bouton grise qui laisserait croire a une panne.
struct LockedNoteView: View {
    let noteTitle: String
    let passwordHint: String?
    let isBiometricsAvailable: Bool
    let onUnlockWithBiometrics: () -> Void
    let onUsePassword: () -> Void

    @AccessibilityFocusState private var isPrimaryActionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            LockedNoteHeaderBar(title: noteTitle)
            content
        }
        .background(SlateColor.bgEditor)
    }

    private var content: some View {
        VStack(spacing: Spacing.md) {
            iconBadge
            Text(String(localized: "lock.lockedNote.title", bundle: .module))
                .slateFont(SlateFont.titleSecondary)
                .foregroundStyle(SlateColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(String(localized: "lock.lockedNote.description", bundle: .module))
                .slateFont(SlateFont.subtitle)
                .foregroundStyle(SlateColor.textSecondary)
                .multilineTextAlignment(.center)
            if let passwordHint, !passwordHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hintLine(passwordHint)
            }

            Button(action: primaryAction) {
                Label(primaryLabel, systemImage: primaryIconName)
            }
            .buttonStyle(LockedNotePrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .accessibilityFocused($isPrimaryActionFocused)
            .padding(.top, Spacing.xs)

            if isBiometricsAvailable {
                Button(action: onUsePassword) {
                    Text(String(localized: "lock.lockedNote.usePassword", bundle: .module))
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.textLink)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isPrimaryActionFocused = true }
    }

    private static let iconBadgeDiameter = SlateGeometry.pickerHitTarget + Spacing.md

    private var iconBadge: some View {
        Circle()
            .fill(SlateColor.surfaceSecondary)
            .frame(width: Self.iconBadgeDiameter, height: Self.iconBadgeDiameter)
            .overlay {
                Image(systemName: "lock.fill")
                    .slateIconFont(SlateGeometry.pickerGlyphSize + Spacing.sm, weight: .regular, relativeTo: .title2)
                    .foregroundStyle(SlateColor.textSecondary)
            }
            .accessibilityHidden(true)
    }

    private func hintLine(_ hint: String) -> some View {
        let template = String(localized: "lock.lockedNote.hint", bundle: .module)
        return Text(String(format: template, hint))
            .slateFont(SlateFont.caption)
            .foregroundStyle(SlateColor.textTertiary)
            .multilineTextAlignment(.center)
    }

    private var primaryLabel: String {
        isBiometricsAvailable
            ? String(localized: "lock.lockedNote.unlockWithBiometrics", bundle: .module)
            : String(localized: "lock.lockedNote.enterPassword", bundle: .module)
    }

    private var primaryIconName: String {
        isBiometricsAvailable ? "touchid" : "lock"
    }

    private func primaryAction() {
        if isBiometricsAvailable {
            onUnlockWithBiometrics()
        } else {
            onUsePassword()
        }
    }
}

/// Bouton principal plein-accent de `LockedNoteView` (design P3, artboard C : fond
/// `accent.default`, texte blanc, anneau de focus visible par defaut).
private struct LockedNotePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .slateFont(SlateFont.bodyEmphasis)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                (configuration.isPressed ? SlateColor.accentPressed : SlateColor.accentDefault)
                    .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium))
            )
            .foregroundStyle(SlateColor.textOnAccent)
    }
}

#Preview("LockedNoteView - Touch ID disponible, clair") {
    LockedNoteView(
        noteTitle: "Comptes bancaires",
        passwordHint: nil,
        isBiometricsAvailable: true,
        onUnlockWithBiometrics: {},
        onUsePassword: {}
    )
    .frame(width: 600, height: 400)
}

#Preview("LockedNoteView - sans Touch ID, avec indice, sombre") {
    LockedNoteView(
        noteTitle: "Comptes bancaires",
        passwordHint: "Le nom de mon premier chat",
        isBiometricsAvailable: false,
        onUnlockWithBiometrics: {},
        onUsePassword: {}
    )
    .frame(width: 600, height: 400)
    .preferredColorScheme(.dark)
}
