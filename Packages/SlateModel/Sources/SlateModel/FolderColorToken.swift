import Foundation

/// Identifiant d'une entree de la palette de couleurs de dossier/note decrite dans
/// `design/tokens.md` §7 ("Couleurs - Palette d'accents proposes") et §8 ("Couleurs -
/// Icones de dossiers/notes", qui reutilise explicitement la meme palette). Ces deux
/// sections listent **8 teintes**, dans cet ordre : Bleu (defaut), Violet, Rose, Rouge,
/// Orange, Jaune, Vert, Graphite.
///
/// ## Regle d'architecture dure : aucune couleur concrete ici
///
/// `SlateModel` ne doit connaitre aucune valeur de rendu (ni `Color`, ni hex clair/sombre
/// #007AFF/#0A84FF...) : ce type ne porte qu'un **identifiant de position dans la
/// palette**. La resolution vers une vraie couleur (avec sa variante clair/sombre)
/// appartient exclusivement a `SlateUI`, qui possede deja la table de tokens et le
/// theme courant. Ce decouplage permet aussi de faire evoluer la palette visuelle sans
/// toucher au modele de donnees.
///
/// `rawValue` est l'`Int` stocke en base (`Folder.colorIndex`) : ne jamais reordonner
/// les cas existants ni changer leur `rawValue` une fois des donnees ecrites, pour la
/// meme raison que documentee sur `BlockType`.
public enum FolderColorToken: Int, CaseIterable, Sendable {
    case blue = 0
    case purple = 1
    case pink = 2
    case red = 3
    case orange = 4
    case yellow = 5
    case green = 6
    case graphite = 7
}
