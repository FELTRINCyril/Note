import SwiftUI

/// Couleurs specifiques aux bases de donnees (design/tokens.md §18, Phase 17,
/// `Slate P5 - Bases de donnees.dc.html`).
///
/// Plusieurs tokens de §18 sont des ALIAS explicites de tokens deja existants (voir
/// chaque doc-commentaire) : ils ne sont pas redefinis avec une nouvelle valeur, pour ne
/// pas dupliquer une teinte deja mesuree ailleurs.
public extension SlateColor {
    /// `db.grid.headerBg` = `table.header.bg` (Phase 8, `TableHeaderCell.swift`) : meme
    /// valeur exacte (`#F2F2F5` / `#2C2C2E`), reutilisee telle quelle. Alias nomme pour
    /// la tracabilite avec §18, PAS une nouvelle teinte.
    static let databaseGridHeaderBackground = tableHeaderBg

    /// `db.grid.cellBorder` = `table.border` (= `separator`). Alias nomme.
    static let databaseGridCellBorder = tableBorder

    /// `db.kanban.columnBg`. Fond d'une colonne de groupe Kanban.
    static let databaseKanbanColumnBackground = slateAdaptiveColor(
        light: SlateRGB(hex: "#F2F2F5") ?? .white,
        dark: SlateRGB(hex: "#232326") ?? .black
    )

    /// `db.card.bg`. Meme valeur exacte que `surface.primary` (`#FFFFFF` / `#2A2A2C`) :
    /// alias nomme, pas une nouvelle teinte.
    static let databaseCardBackground = surfacePrimary

    /// `db.card.shadow` = `elevation.low` (design/tokens.md §13 : "y:1 blur:3
    /// rgba(0,0,0,0.08) / rgba(0,0,0,0.30)"). Aucun token `elevation.low` n'existait
    /// encore cote couleur (seuls `elevation.medium`/`elevation.high` sont poses dans
    /// `Editor/EditorColors.swift`) : ajoute ici plutot que la-bas, ce module est le
    /// premier consommateur.
    static let databaseCardShadow = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.08),
        dark: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.30)
    )

    /// `db.calendar.today` = `accent.subtle`. Alias nomme.
    static let databaseCalendarToday = accentSubtle

    /// `db.calendar.eventBg` = `accent.subtle`. Meme valeur que `databaseCalendarToday`
    /// (design/tokens.md §18 donne la meme formule aux deux lignes) ; alias distinct pour
    /// que l'appelant nomme son intention (jour courant vs pastille d'evenement) sans
    /// dependre du fait qu'ils coincident aujourd'hui.
    static let databaseCalendarEventBackground = accentSubtle

    /// Fond d'une etiquette/statut NEUTRE (sans accent), artboard A : "securite"
    /// (`rgba(0,0,0,0.06)` / cette meme valeur en blanc cote sombre, mesuree sur la
    /// pastille "A faire" du Kanban artboard B). Distincte de `surface.secondary`
    /// (`#F2F2F5`, alpha 100%) : §18 ne documente pas explicitement cette valeur, ajoutee
    /// ici car aucun token existant ne la porte deja.
    static let databaseNeutralPillBackground = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.06),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.10)
    )

    /// Libelle d'une etiquette/statut NEUTRE. PAS `text.secondary` : mesure honnetement
    /// (composite reel, voir `DatabaseContrastTests`), une couleur alpha sur
    /// `databaseNeutralPillBackground` (elle-meme translucide) ne tient PAS l'AA texte
    /// (3,87:1). Reprend `code.syntax.comment` (design/tokens.md §16 ter, meme teinte
    /// grise deja mesuree a l'AA sur un fond clair voisin), variante sombre ajustee a
    /// `#A8B0B8` (mesuree ici sur `db.card.bg` sombre) plutot que `#96A3AE`
    /// (`code.syntax.comment` sombre, mesure sur `code.block.bg` -- fond legerement
    /// different).
    static let databaseNeutralPillLabel = slateAdaptiveColor(
        light: SlateRGB(hex: "#5A626B") ?? .black,
        dark: SlateRGB(hex: "#A8B0B8") ?? .white
    )
}
