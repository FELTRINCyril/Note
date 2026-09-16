import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Rendu d'un bloc `databaseView` (Phase 17, `docs/17_base_de_donnees.md`, "les deux
/// hebergements") : base inline, portee par `Block.databaseView`. `SlateEditor` ne
/// depend pas de `SlateFeatures` (sens des dependances, `docs/00_architecture.md`) : ce
/// rendu est donc un CLIENT DIRECT et complet de `DatabaseQueryEngine`/`SlateUI`, pas un
/// point d'injection vers le moteur complet de `SlateFeatures` (celui-la, plus riche --
/// Kanban/Calendrier/Galerie/filtres -- reste reserve a l'hebergement pleine page, voir
/// `SlateFeatures.DatabaseFullPageView`/`DatabaseHostView`).
///
/// Volontairement plus modeste que la vue Grille pleine page : CRUD de lignes, edition
/// en place par type de cellule, ajout de champ (types simples uniquement, sans options
/// de selection configurables ici) - une base inline reellement fonctionnelle, jamais
/// une facade qui aurait l'air d'agir sans rien faire (regle d'honnetete d'interface du
/// projet). Limite assumee et documentee dans le rapport de livraison de la phase.
struct DatabaseViewBlockContentView: View {
    let block: Block
    let editorController: EditorController

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let database = block.databaseView {
            InlineDatabaseGridView(database: database, modelContext: modelContext)
        } else {
            InlineDatabaseMissingView()
        }
    }
}

private struct InlineDatabaseMissingView: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "tablecells")
                .slateIconFont(SlateGeometry.sidebarIconSize)
                .foregroundStyle(SlateColor.textTertiary)
            Text(EditorStrings.databaseViewMissing)
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textTertiary)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall).fill(SlateColor.surfaceSecondary))
        .accessibilityElement(children: .combine)
    }
}
