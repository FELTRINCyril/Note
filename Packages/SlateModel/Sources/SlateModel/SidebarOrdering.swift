import Foundation

/// Ordre deterministe applique aux entites affichees dans la sidebar
/// (`docs/03_sidebar_navigation.md`) : n'importe quel appelant obtient toujours le
/// meme ordre pour le meme contenu, y compris dans les tests.
///
/// Regle commune a `Space` et `Folder` : `sortIndex` croissant en premier (c'est le
/// champ que le glisser-deposer/reordonnancement manuel fait varier), puis nom en
/// ordre naturel (`localizedStandardCompare`, insensible a la casse et aux accents,
/// coherent avec le Finder), puis `id` en dernier recours pour garantir un ordre total
/// meme dans le cas limite ou deux freres partagent a la fois le meme `sortIndex` et
/// le meme nom.
enum SidebarOrdering {
    static func compare(
        sortIndex lhsSortIndex: Int,
        name lhsName: String,
        id lhsID: UUID,
        to rhsSortIndex: Int,
        name rhsName: String,
        id rhsID: UUID
    ) -> Bool {
        if lhsSortIndex != rhsSortIndex {
            return lhsSortIndex < rhsSortIndex
        }
        let nameComparison = lhsName.localizedStandardCompare(rhsName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhsID.uuidString < rhsID.uuidString
    }
}

extension Space {
    /// Comparateur pour trier des `Space` freres de facon deterministe. Voir
    /// `SidebarOrdering`.
    public static func sidebarOrder(_ lhs: Space, _ rhs: Space) -> Bool {
        SidebarOrdering.compare(
            sortIndex: lhs.sortIndex, name: lhs.name, id: lhs.id,
            to: rhs.sortIndex, name: rhs.name, id: rhs.id
        )
    }
}

extension Folder {
    /// Comparateur pour trier des `Folder` freres (racines d'une `Space` ou
    /// sous-dossiers d'un `Folder`) de facon deterministe. Voir `SidebarOrdering`.
    public static func sidebarOrder(_ lhs: Folder, _ rhs: Folder) -> Bool {
        SidebarOrdering.compare(
            sortIndex: lhs.sortIndex, name: lhs.name, id: lhs.id,
            to: rhs.sortIndex, name: rhs.name, id: rhs.id
        )
    }

    /// Nombre de notes portees par ce dossier, **recursif** (inclut les notes de tous
    /// les sous-dossiers, a n'importe quelle profondeur), en excluant les notes de la
    /// corbeille (`isTrashed`).
    ///
    /// Decision documentee : la maquette visuelle de la Phase 3
    /// (`docs/03_sidebar_navigation.md`) affiche un compteur sur chaque ligne de
    /// dossier, y compris sur des dossiers qui ont des sous-dossiers. Un compteur
    /// "direct seulement" y serait trompeur : un dossier avec 3 sous-dossiers pleins
    /// de notes et 0 note a sa propre racine afficherait "0", ce qui se lit comme
    /// "vide" alors qu'il ne l'est pas. C'est aussi le comportement de l'app Notes
    /// d'Apple (dont ce projet reprend explicitement le design des dossiers, voir
    /// `CLAUDE.md` §1) : le compteur d'un dossier compte tout ce qu'il contient,
    /// recursivement.
    ///
    /// Les notes de la corbeille sont exclues a chaque niveau : une note supprimee ne
    /// doit pas continuer a gonfler le compteur du dossier dont elle vient d'etre
    /// retiree logiquement.
    public var noteCount: Int {
        let direct = (notes ?? []).count { !$0.isTrashed }
        let nested = (subfolders ?? []).reduce(0) { $0 + $1.noteCount }
        return direct + nested
    }
}
