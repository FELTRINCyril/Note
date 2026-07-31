import Foundation
import SwiftData

// Placeholder de Phase 1.
//
// Objectif unique : valider que la pile SwiftData (+ CloudKit optionnel) persiste
// correctement un modele minimal. Le vrai schema de donnees (Workspace, Space, Folder,
// Note, Block, Attachment, Tag...) arrive en Phase 2 - voir docs/02_modele_donnees.md
// et docs/GLOSSAIRE.md. Ce type sera remplace, pas etendu.
//
// Contrainte CloudKit (docs/01_setup_projet.md, etape 1.4) : toute propriete d'un
// modele synchronise doit avoir une valeur par defaut ou etre optionnelle. C'est le
// cas ici pour les quatre proprietes.
@Model
public final class Note {
    public var id: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date.now
    public var modifiedAt: Date = Date.now

    public init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
