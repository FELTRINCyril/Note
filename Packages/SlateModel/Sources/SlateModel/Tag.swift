import Foundation
import SwiftData

/// Libelle transversal reutilisable, independant de l'arborescence de dossiers.
/// Prepare en Phase 2, exploite par les bases de donnees (Phase 17). Voir
/// `docs/GLOSSAIRE.md` §1.
///
/// Aucune relation pour l'instant : la Phase 2 ne definit pas encore comment un `Tag`
/// s'associe a une `Note` ou a une ligne de base de donnees (ce sera tranche en
/// Phase 17, quand l'usage reel sera connu). Ajouter cette relation maintenant serait
/// deviner un besoin non specifie. Volontairement, `Tag` ne participe donc a aucune
/// regle de suppression en cascade : une etiquette survit a la suppression des notes
/// qui l'utilisaient (voir `docs/02_modele_donnees.md`, "Attention a ne pas mettre de
/// cascade sur Tag").
@Model
public final class Tag {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String = "#8E8E93"

    public init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String = "#8E8E93"
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
