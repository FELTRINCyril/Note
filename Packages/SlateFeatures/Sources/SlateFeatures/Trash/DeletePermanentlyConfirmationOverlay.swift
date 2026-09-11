import SwiftUI
import SlateUI

/// Confirmation de suppression definitive (design P3, artboard B) - la SEULE action de
/// toute l'app a porter un bouton destructif rouge PLEIN (`SlateColor.semanticErrorFill`,
/// pas `semanticError` : voir sa documentation, `semanticError` ne tient pas l'AA texte
/// avec du blanc).
///
/// **Pourquoi pas `.alert(_:isPresented:actions:)` natif** : le design exige que le
/// bouton destructif porte le focus clavier PAR DEFAUT sans etre declenche par Entree
/// seule (il faut Cmd+Entree ou un clic). Un `.alert` natif se bridge sur `NSAlert`, qui
/// lie TOUJOURS son premier bouton a la touche Entree des qu'il est visuellement le
/// bouton par defaut - il n'existe aucune option pour dissocier "focus par defaut" et
/// "declenchement par Entree" sur un vrai `NSAlert`. Cette vue reconstruit donc l'alerte
/// a la main (overlay + voile), ce qui permet de lier Cmd+Entree explicitement au bouton
/// "Supprimer" SANS jamais lier la touche Entree seule a une action.
///
/// **Non verifiable dans cette session** : aucune fenetre n'a ete ouverte pour confirmer
/// au runtime qu'Entree seule ne declenche reellement rien - seule la logique (absence
/// de tout `.keyboardShortcut(.defaultAction)`/`.keyboardShortcut(.return)` sans
/// modificateur sur le bouton "Supprimer") le garantit par construction.
struct DeletePermanentlyConfirmationOverlay: View {
    let noteTitle: String
    let attachmentCount: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @FocusState private var isDeleteButtonFocused: Bool

    var body: some View {
        ZStack {
            SlateColor.overlayScrim
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: Spacing.sm) {
                iconBadge
                Text(title)
                    .slateFont(SlateFont.bodyEmphasis)
                    .foregroundStyle(SlateColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: Spacing.sm) {
                    Button(String(localized: "action.cancel", bundle: .module), action: onCancel)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                        .frame(maxWidth: .infinity)

                    Button(String(localized: "trash.deleteAlert.confirm", bundle: .module), action: onConfirm)
                        .buttonStyle(DestructiveFillButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .focused($isDeleteButtonFocused)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.lg)
            .frame(width: 340)
            .background(SlateColor.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusLarge))
            .shadow(radius: SlateGeometry.radiusMedium)
        }
        .onAppear { isDeleteButtonFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var iconBadge: some View {
        let diameter = SlateGeometry.radiusLarge * 2 + Spacing.xs
        return Circle()
            .fill(SlateColor.semanticErrorFill.opacity(SlateOpacity.badgeSubtleFill))
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: "trash")
                    .slateIconFont(SlateGeometry.pickerGlyphSize, weight: .medium, relativeTo: .title3)
                    .foregroundStyle(SlateColor.semanticErrorFill)
            }
    }

    private var title: String {
        let template = String(localized: "trash.deleteAlert.title", bundle: .module)
        return String(format: template, noteTitle)
    }

    private var message: String {
        switch attachmentCount {
        case 0:
            return String(localized: "trash.deleteAlert.message.noAttachments", bundle: .module)
        case 1:
            return String(localized: "trash.deleteAlert.message.oneAttachment", bundle: .module)
        default:
            let template = String(localized: "trash.deleteAlert.message.manyAttachments", bundle: .module)
            return String(format: template, attachmentCount)
        }
    }
}

/// Style du bouton "Supprimer" : `semanticErrorFill` plein + texte blanc
/// (`textOnAccent`), reserve a `DeletePermanentlyConfirmationOverlay` (voir sa
/// documentation).
private struct DestructiveFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .slateFont(SlateFont.bodyEmphasis)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(SlateColor.semanticErrorFill.opacity(configuration.isPressed ? SlateOpacity.pressedFill : 1))
            .foregroundStyle(SlateColor.textOnAccent)
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
    }
}

#Preview("DeletePermanentlyConfirmationOverlay") {
    DeletePermanentlyConfirmationOverlay(
        noteTitle: "Ancien plan de lancement",
        attachmentCount: 2,
        onCancel: {},
        onConfirm: {}
    )
    .frame(width: 760, height: 480)
    .background(SlateColor.bgList)
}
