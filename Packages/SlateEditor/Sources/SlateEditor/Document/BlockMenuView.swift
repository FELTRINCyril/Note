import SlateUI
import SwiftUI

/// Contenu du menu ouvert par la poignee de bloc (sous-etape 5.4, docs/05_editeur_blocs.md :
/// "convertir en..., dupliquer, supprimer, deplacer"). Presente en `.popover` par
/// `BlockTreeView` (voir sa documentation pour le declenchement souris/clavier) plutot
/// que via un `Menu` natif : `BlockHandle` (`SlateUI`) reutilise le MEME bouton pour
/// "cliquer -> menu" et "glisser -> deplacer" (spec E4 : "La poignee ouvre le menu au
/// clic, deplace au glisser"), ce qui exclut d'attacher directement un `Menu` SwiftUI a
/// ce bouton (son geste de presentation entrerait en conflit avec `.draggable`).
///
/// GAP DE TOKEN SIGNALE (voir rapport de livraison) : la spec E4 ne definit aucune
/// geometrie ni etat de survol dedies au CONTENU du menu de bloc (seule la poignee qui
/// l'ouvre y est specifiee) -- ce composant reutilise donc uniquement des tokens
/// EXISTANTS (`Spacing`, `SlateColor.textPrimary/textSecondary`), sans rien inventer,
/// en attendant un passage dedie de `design-integrator`.
struct BlockMenuView: View {
    /// `false` si `block` est deja le premier de sa fratrie (voir `BlockOperations.moveUp(_:)`) :
    /// l'entree correspondante est desactivee plutot que masquee, pour que sa PRESENCE
    /// reste previsible d'un bloc a l'autre.
    let canMoveUp: Bool
    /// Symmetrique de `canMoveUp` pour "Deplacer vers le bas".
    let canMoveDown: Bool
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Convertir en..." arrive en sous-etape 5.5 (docs/05_editeur_blocs.md).
            // Regle d'honnetete d'interface du projet : jamais un controle qui a l'air
            // actionnable sans agir -- desactive, avec une explication (`.help`), pas un
            // item silencieusement inoperant.
            row(title: EditorStrings.blockMenuConvertTitle, systemImage: "arrow.triangle.2.circlepath", action: {})
                .disabled(true)
                .help(EditorStrings.blockMenuConvertDisabledHelp)

            Divider()

            row(title: EditorStrings.blockMenuDuplicateTitle, systemImage: "plus.square.on.square", action: onDuplicate)

            Divider()

            row(title: EditorStrings.blockMenuMoveUpTitle, systemImage: "arrow.up", action: onMoveUp)
                .disabled(!canMoveUp)
            row(title: EditorStrings.blockMenuMoveDownTitle, systemImage: "arrow.down", action: onMoveDown)
                .disabled(!canMoveDown)

            Divider()

            row(title: EditorStrings.blockMenuDeleteTitle, systemImage: "trash", action: onDelete)
        }
        .padding(Spacing.xs)
        .frame(minWidth: 200)
    }

    private func row(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(SlateColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .contentShape(Rectangle())
    }
}

#Preview("BlockMenuView") {
    BlockMenuView(canMoveUp: true, canMoveDown: false, onDuplicate: {}, onMoveUp: {}, onMoveDown: {}, onDelete: {})
        .background(SlateColor.bgEditor)
}
