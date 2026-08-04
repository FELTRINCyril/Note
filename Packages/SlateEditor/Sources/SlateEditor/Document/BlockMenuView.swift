import SlateModel
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
    /// Type courant de `block`, deja resolu en libelle localise (`EditorStrings.blockTypeLabel(_:)`)
    /// par l'appelant. Reste visible meme quand le sous-menu "Convertir en..." n'est
    /// pas ouvert (sous-etape 5.5, point explicite de la tache : "le libelle du type
    /// courant doit etre visible pour que l'utilisateur sache d'ou il part").
    let currentTypeLabel: String
    /// Types cibles proposes par `BlockConversion.availableTargets(for:)`. Vide pour
    /// un type qui n'a pas de rendu textuel reel aujourd'hui (`divider`, `image`...) ou
    /// reserve a une phase ulterieure -- voir la documentation de `BlockConversion`.
    let availableConversionTargets: [BlockType]
    /// `false` si `block` est deja le premier de sa fratrie (voir `BlockOperations.moveUp(_:)`) :
    /// l'entree correspondante est desactivee plutot que masquee, pour que sa PRESENCE
    /// reste previsible d'un bloc a l'autre.
    let canMoveUp: Bool
    /// Symmetrique de `canMoveUp` pour "Deplacer vers le bas".
    let canMoveDown: Bool
    let onConvert: (BlockType) -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            convertRow

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

    /// "Convertir en..." (sous-etape 5.5) : un sous-menu listant `availableConversionTargets`
    /// quand la liste n'est pas vide, sinon la MEME entree desactivee qu'en 5.4 -- mais
    /// avec une explication a jour (`blockMenuConvertUnavailableHelp`, plus "bientot
    /// disponible") -- regle d'honnetete d'interface du projet : jamais un controle qui
    /// a l'air actionnable sans agir, toujours une explication s'il est desactive.
    @ViewBuilder
    private var convertRow: some View {
        if availableConversionTargets.isEmpty {
            row(title: EditorStrings.blockMenuConvertTitle, systemImage: "arrow.triangle.2.circlepath", action: {})
                .disabled(true)
                .help(EditorStrings.blockMenuConvertUnavailableHelp)
        } else {
            Menu {
                ForEach(availableConversionTargets, id: \.self) { target in
                    Button(EditorStrings.blockTypeLabel(target)) { onConvert(target) }
                }
            } label: {
                Label(EditorStrings.blockMenuConvertTitle, systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(SlateColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .help(EditorStrings.blockMenuConvertCurrentType(currentTypeLabel))
        }
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
    BlockMenuView(
        currentTypeLabel: EditorStrings.blockTypeLabel(.paragraph),
        availableConversionTargets: BlockConversion.convertibleTypes.filter { $0 != .paragraph },
        canMoveUp: true,
        canMoveDown: false,
        onConvert: { _ in },
        onDuplicate: {},
        onMoveUp: {},
        onMoveDown: {},
        onDelete: {}
    )
    .background(SlateColor.bgEditor)
}
