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
/// GAP DE TOKEN SIGNALE ET TRANCHE EN PHASE 5 (voir rapport de livraison de l'agent
/// 5.4) : la spec E4 ne definit aucune geometrie ni etat de survol dedies au CONTENU du
/// menu de bloc (seule la poignee qui l'ouvre y est specifiee). Les deux menus
/// comparables du projet n'apportent pas de troisieme style a copier tel quel : le menu
/// contextuel de sidebar (`FolderRow`) est un `Menu`/`.contextMenu` NATIF qui se
/// survole lui-meme sans aucun token ; `FolderIconPickerSheet` (grille de choix
/// d'icone), seul autre menu "custom" du projet, ne porte pas non plus d'etat de
/// survol dedie (seulement un etat "selectionne" statique). Ce composant-ci n'est PAS
/// un `Menu` natif (voir la doc ci-dessus sur le conflit clic/glisser de `BlockHandle`)
/// : ses lignes ont donc besoin d'un retour de survol explicite pour rester utilisables
/// a la souris, comme n'importe quelle ligne cliquable de l'app -- `BlockMenuRow`
/// reutilise donc le MEME token et le MEME motif deja etablis pour CE besoin ailleurs
/// dans `SlateUI` (`SlateColor.stateHover`, fond anime en `SlateMotion.durationFast`,
/// exactement comme `SidebarRow`/`ListCell`), plutot que d'inventer une troisieme
/// convention de survol.
struct BlockMenuView: View {
    /// Type courant de `block`, deja resolu en libelle localise (`EditorStrings.blockTypeLabel(_:)`)
    /// par l'appelant. Reste visible meme quand le sous-menu "Convertir en..." n'est
    /// pas ouvert (sous-etape 5.5, point explicite de la tache : "le libelle du type
    /// courant doit etre visible pour que l'utilisateur sache d'ou il part"). Ignore
    /// quand `selectionCount` n'est pas `nil` (voir sa documentation) : une plage
    /// heterogene n'a pas de "type courant" unique a annoncer.
    let currentTypeLabel: String
    /// `nil` (par defaut) pour le menu d'un bloc UNIQUE (sous-etapes 5.4/5.5,
    /// comportement inchange). Non-`nil` -- le NOMBRE de blocs de la plage -- quand ce
    /// menu agit sur une SELECTION MULTIPLE (sous-etape 5.6, point explicite de la
    /// tache : "le menu de bloc doit refleter qu'on agit sur une plage... libelles au
    /// pluriel ou nombre de blocs, pour que l'utilisateur sache sur quoi il agit").
    /// Affiche un bandeau de synthese en tete de menu et pluralise "Supprimer" ; masque
    /// "Dupliquer", qui n'a pas d'equivalent en lot dans cette sous-etape (base).
    let selectionCount: Int?
    /// Types cibles proposes par `BlockConversion.availableTargets(for:)` (bloc unique)
    /// ou `BlockConversion.convertibleTypes` (plage, voir `EditorController.
    /// availableConversionTargetsForSelectionRange()`). Vide pour un type/une plage sans
    /// aucun bloc convertible aujourd'hui -- voir la documentation de `BlockConversion`.
    let availableConversionTargets: [BlockType]
    /// `false` si `block` (ou la plage entiere) est deja en tete de sa fratrie (voir
    /// `BlockOperations.moveUp(_:)`/`BlockSelectionOperations.canMoveRange(_:in:by:)`) :
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

    init(
        currentTypeLabel: String,
        selectionCount: Int? = nil,
        availableConversionTargets: [BlockType],
        canMoveUp: Bool,
        canMoveDown: Bool,
        onConvert: @escaping (BlockType) -> Void,
        onDuplicate: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.currentTypeLabel = currentTypeLabel
        self.selectionCount = selectionCount
        self.availableConversionTargets = availableConversionTargets
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onConvert = onConvert
        self.onDuplicate = onDuplicate
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectionCount {
                Text(EditorStrings.blockMenuSelectionSummary(selectionCount))
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                Divider()
            }

            convertRow

            Divider()

            if selectionCount == nil {
                row(
                    title: EditorStrings.blockMenuDuplicateTitle,
                    systemImage: "plus.square.on.square",
                    action: onDuplicate
                )
                Divider()
            }

            row(title: EditorStrings.blockMenuMoveUpTitle, systemImage: "arrow.up", action: onMoveUp)
                .disabled(!canMoveUp)
            row(title: EditorStrings.blockMenuMoveDownTitle, systemImage: "arrow.down", action: onMoveDown)
                .disabled(!canMoveDown)

            Divider()

            row(title: deleteTitle, systemImage: "trash", action: onDelete)
        }
        .padding(Spacing.xs)
        .frame(minWidth: 200)
    }

    /// "Supprimer" pluralise avec le nombre de blocs en mode plage (voir la
    /// documentation de `selectionCount`) -- inchange ("Supprimer") pour un bloc unique.
    private var deleteTitle: String {
        selectionCount.map(EditorStrings.blockMenuDeleteRangeTitle) ?? EditorStrings.blockMenuDeleteTitle
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
        BlockMenuRow(title: title, systemImage: systemImage, action: action)
    }
}

/// Ligne d'action du menu de bloc (voir la doc de `BlockMenuView` sur le choix de son
/// etat de survol). Type dedie (plutot qu'une simple fonction, voir l'ancienne version)
/// pour porter son propre `@State` de survol, sur le meme principe que `SidebarRow`/
/// `ListCell` (`SlateUI`).
private struct BlockMenuRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(SlateColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            guard isEnabled else { return }
            isHovering = hovering
        }
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isHovering
        )
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isHovering {
            SlateColor.stateHover
        } else {
            Color.clear
        }
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
