import Foundation
import SlateModel
import SlateServices
import SlateUI
import SwiftData

/// Actions sur les blocs media (`BlockType.image`/`.file`, Phase 9,
/// docs/09_medias_pieces_jointes.md) : import/remplacement/suppression d'une piece
/// jointe, palier d'alignement/largeur d'une image, legende -- meme motif de separation
/// que `EditorController+SpecialBlocks.swift`/`+Table.swift`, aucune nouvelle surface
/// publique qui ne soit pas portee par `EditorController` lui-meme.
///
/// ## `AttachmentService`, jamais reimplemente ici
/// Tout import/suppression/remplacement passe PAR `AttachmentService` (`SlateServices`,
/// deja livre) : ce fichier ne fait que router entre l'UI et ce service, avec le
/// `ModelContext` que ce dernier exige. Voir sa documentation de tete pour le pourquoi
/// de l'ordre exact des operations (`replaceAttachment(of:with:in:)`, en particulier :
/// detacher puis supprimer l'ancienne piece jointe AVANT de brancher la nouvelle, sous
/// peine de crash SwiftData reel).
extension EditorController {
    // MARK: - Import (image)

    /// Importe une image depuis un fichier sur disque et l'attache a `block` (import
    /// initial ou remplacement, `AttachmentService` gere les deux cas de facon
    /// identique cote stockage). Efface toute cause d'echec anterieure pour ce bloc en
    /// cas de succes ; l'enregistre sinon (voir `attachmentImportFailures`).
    public func importImageFile(at url: URL, into block: Block) {
        runImageImport(into: block) { try AttachmentService().importImage(fileURL: url) }
    }

    /// Importe une image depuis des octets bruts (glisser-depose, coller) -- meme
    /// contrat que `importImageFile(at:into:)`.
    public func importImageData(_ data: Data, filename: String, into block: Block) {
        runImageImport(into: block) { try AttachmentService().importImage(data: data, filename: filename) }
    }

    private func runImageImport(into block: Block, _ importer: () throws -> ImportedImage) {
        guard block.type == .image else { return }
        do {
            applyImportedImage(try importer(), into: block)
        } catch {
            recordAttachmentImportFailure(error, for: block)
        }
    }

    /// Branche un `ImportedImage` DEJA DECODE (voir `AttachmentService`) sur `block` --
    /// point d'entree utilise par `runImageImport(into:_:)` ci-dessus ET par l'UI
    /// (`ImageBlockContentView`) quand le decodage/la recompression a ete fait au
    /// prealable HORS de l'acteur principal (`Task.detached`, pour ne jamais bloquer
    /// l'interface sur une image volumineuse) : cette methode-ci, elle, ne fait qu'une
    /// mutation SwiftData bon marche, a la charge legitime de l'acteur principal.
    public func applyImportedImage(_ imported: ImportedImage, into block: Block) {
        // Garde AVANT toute autre lecture de `block` : ce point d'entree est atteint
        // depuis `ImageBlockContentView` APRES un `await` (`Task.detached`, decodage
        // hors acteur principal). Entre le lancement de l'import et son retour, rien
        // n'empeche l'utilisateur de supprimer ce bloc precis (menu "Supprimer", plage
        // multi-blocs) -- `deleteBlock(_:)`/`deleteSelectionRange()` suppriment et
        // SAUVEGARDENT de facon synchrone, sans egard pour un import en cours.
        // `block.isDeleted` seul ne suffit pas : une fois la suppression SAUVEGARDEE,
        // SwiftData le repasse a `false` alors que le backing store a deja purge
        // l'objet -- toucher `block.attributes` a cet instant crashe reellement
        // ("Unexpectedly failed to find a value for a composite future"), constate en
        // test (`applyImportedImageIgnoresABlockDeletedWhileImporting`). Seul
        // `block.modelContext == nil` reste vrai dans ce cas : c'est le signal fiable,
        // verifie AVANT `isDeleted` et avant tout attribut de `block`.
        guard block.modelContext != nil, !block.isDeleted, block.type == .image, let modelContext else { return }
        let attachment = Attachment(
            filename: imported.filename,
            uti: imported.uti,
            data: imported.data,
            width: imported.width,
            height: imported.height
        )
        attach(attachment, to: block, in: modelContext)
        attachmentImportFailures[block.id] = nil
        if block.attributes.imageAlignment == nil {
            setImageAlignment(.left, in: block)
        } else {
            persistStructuralChange()
        }
    }

    // MARK: - Import (fichier joint)

    /// Importe un fichier joint quelconque depuis un fichier sur disque et l'attache a
    /// `block` -- meme contrat que `importImageFile(at:into:)`.
    public func importAttachedFile(at url: URL, into block: Block) {
        // Meme garde-fou que `applyImportedImage(_:into:)` : ce point d'entree est
        // parfois atteint depuis `FileBlockContentView.handleDrop` apres un `await`
        // asynchrone (`NSItemProvider.loadObject`), donc `block` peut avoir ete
        // supprime entre-temps.
        guard block.modelContext != nil, !block.isDeleted, block.type == .file else { return }
        do {
            applyImportedFile(try AttachmentService().importFile(fileURL: url), into: block)
        } catch {
            recordAttachmentImportFailure(error, for: block)
        }
    }

    /// Branche un `ImportedFile` DEJA DECODE sur `block` -- meme motif et meme raison
    /// que `applyImportedImage(_:into:)`.
    public func applyImportedFile(_ imported: ImportedFile, into block: Block) {
        // Voir la garde equivalente dans `applyImportedImage(_:into:)` : ce chemin est
        // synchrone aujourd'hui (`importAttachedFile` n'utilise pas `Task.detached`),
        // mais garde le meme reflexe defensif que ses cousins pour rester coherent si
        // l'import de fichier gagne un jour son propre traitement hors acteur principal.
        guard block.modelContext != nil, !block.isDeleted, block.type == .file, let modelContext else { return }
        let attachment = Attachment(filename: imported.filename, uti: imported.uti, data: imported.data)
        attach(attachment, to: block, in: modelContext)
        attachmentImportFailures[block.id] = nil
        persistStructuralChange()
    }

    /// Enregistre la cause d'un echec d'import (voir `attachmentImportFailures`).
    /// Public : l'UI decode parfois elle-meme HORS acteur principal (voir
    /// `applyImportedImage(_:into:)`) et doit pouvoir remonter une erreur survenue la-bas
    /// sans dupliquer cette logique de formatage.
    public func recordAttachmentImportFailure(_ error: Error, for block: Block) {
        // `block.id` reste lisible sur un objet supprime (c'est un attribut trivial,
        // pas une relation), mais n'a plus aucun sens a enregistrer : rien ne
        // l'affichera jamais, et la cle resterait a vie dans `attachmentImportFailures`
        // (l'entree n'est purgee que par un import reussi ou une suppression explicite
        // sur CE bloc). Voir la garde equivalente dans `applyImportedImage(_:into:)`.
        guard block.modelContext != nil, !block.isDeleted else { return }
        attachmentImportFailures[block.id] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    /// Branche `attachment` sur `block`, en remplacant proprement l'existante le cas
    /// echeant (voir la documentation de tete de fichier). Commun aux deux types de
    /// bloc media.
    private func attach(_ attachment: Attachment, to block: Block, in context: ModelContext) {
        let service = AttachmentService()
        if block.attachment != nil {
            service.replaceAttachment(of: block, with: attachment, in: context)
        } else {
            attachment.block = block
            block.attachment = attachment
            context.insert(attachment)
        }
    }

    // MARK: - Suppression

    /// Retire la piece jointe de `block` (image ou fichier), en purgeant vraiment
    /// l'`Attachment` du store -- jamais un simple `block.attachment = nil`, voir la
    /// documentation de tete de `AttachmentService.removeAttachment(from:in:)`. Le bloc
    /// lui-meme n'est PAS supprime : il retombe dans son etat vide/depot.
    public func removeAttachment(from block: Block) {
        guard let modelContext else { return }
        AttachmentService().removeAttachment(from: block, in: modelContext)
        attachmentImportFailures[block.id] = nil
        persistStructuralChange()
    }

    // MARK: - Alignement / palier de largeur (`BlockType.image`, artboard A)

    /// Fixe le palier d'alignement/largeur d'une image (`BlockAttributes.
    /// imageAlignment`, identifiant `SlateImageAlignment.rawValue`) ET la largeur
    /// memorisee correspondante (`BlockAttributes.imageWidth`, en points -- `nil` pour
    /// `.fullWidth`, qui n'a pas de largeur fixe). Sans effet si `block` n'est pas une
    /// `.image`, ou si `alignment` est deja le palier courant.
    public func setImageAlignment(_ alignment: SlateImageAlignment, in block: Block) {
        guard block.type == .image else { return }
        guard block.attributes.imageAlignment != alignment.rawValue else { return }
        block.attributes.imageAlignment = alignment.rawValue
        block.attributes.imageWidth = Self.width(forImageAlignment: alignment)
        persistStructuralChange()
    }

    /// Opt+Left/Right (artboard A : "passent d'un palier au suivant... annoncent la
    /// largeur"). Avance/recule d'UN palier dans `SlateImageAlignment.allCases`, borne
    /// aux extremites (pas de bouclage : rester sur `.fullWidth` apres Opt+Right repete
    /// est le comportement attendu, pas revenir a `.left`). Retourne le palier
    /// resultant (identique au palier courant si `block` etait deja a une extremite) --
    /// l'appelant AppKit poste l'annonce VoiceOver correspondante
    /// (`SlateImageAlignment.accessibilityAnnouncement`), `nil` si `block` n'est pas une
    /// `.image`.
    @discardableResult
    public func cycleImageAlignment(forward: Bool, in block: Block) -> SlateImageAlignment? {
        guard block.type == .image else { return nil }
        let all = Self.availableImageAlignments
        let current = SlateImageAlignment(rawValue: block.attributes.imageAlignment ?? "") ?? .left
        guard let index = all.firstIndex(of: current) else { return current }
        let nextIndex = forward ? min(index + 1, all.count - 1) : max(index - 1, 0)
        let next = all[nextIndex]
        setImageAlignment(next, in: block)
        return next
    }

    /// Paliers de largeur REELLEMENT proposes a l'utilisateur, source de verite unique
    /// partagee par la barre d'alignement et par le cycle clavier Alt-fleches.
    ///
    /// Le design en decrit cinq, mais les deux paliers hors colonne (`.overflow` 960 pt
    /// et `.fullWidth`) exigent que `EditorContentColumn` sache laisser un bloc sortir de
    /// la colonne de 720 pt, ce qu'il ne sait pas faire : il enveloppe toute la liste de
    /// blocs d'un coup, pas chaque bloc. Ils sont donc retires de la liste au lieu d'etre
    /// affiches sans effet -- meme regle d'honnetete d'interface qu'en phase 6, ou seuls
    /// les types de bloc au rendu reel figurent au menu `/`. La sortie de colonne arrive
    /// avec la mise en colonnes (phase 10), qui doit de toute facon revoir ce conteneur :
    /// il suffira alors de rendre `SlateImageAlignment.allCases` ici.
    static let availableImageAlignments: [SlateImageAlignment] = [.left, .center, .right]

    /// Largeur fixe (en points) d'un palier -- `nil` pour `.fullWidth`, qui suit la
    /// largeur disponible plutot qu'une valeur figee. Gauche/Centre/Droite partagent le
    /// meme palier de largeur (colonne), voir la documentation de `SlateImageAlignment`.
    static func width(forImageAlignment alignment: SlateImageAlignment) -> Double? {
        switch alignment {
        case .left, .center, .right:
            Double(SlateGeometry.mediaColumnWidth)
        case .overflow:
            Double(SlateGeometry.mediaOverflowWidth)
        case .fullWidth:
            nil
        }
    }

    // MARK: - Legende (`BlockType.image`)

    /// Change la legende d'une image (`BlockAttributes.imageCaption`, `nil` si vide --
    /// voir sa documentation : "nil = aucune legende"). Sans effet si `block` n'est pas
    /// une `.image`, ou si `caption` est deja la valeur courante.
    public func setImageCaption(_ caption: String, in block: Block) {
        guard block.type == .image else { return }
        let normalized = caption.isEmpty ? nil : caption
        guard block.attributes.imageCaption != normalized else { return }
        block.attributes.imageCaption = normalized
        persistStructuralChange()
    }
}
