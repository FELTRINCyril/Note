import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Base pleine page (17, "les deux hebergements" : `hostMode == .fullPage`) : meme
/// `DatabaseHostView` que l'hebergement inline, juste presente comme le contenu complet
/// d'une colonne/fenetre plutot qu'imbrique dans un bloc de note.
///
/// Non branchee dans la navigation principale (barre laterale/liste de notes) par cette
/// phase : `docs/17_base_de_donnees.md` (17.3/17.5/17.6) porte les VUES elles-memes, pas
/// le parcours de creation/ouverture d'une base pleine page depuis la coquille de l'app
/// (hors perimetre explicite de cette livraison, voir le rapport de livraison). Ce type
/// est neanmoins un point d'integration pret a l'emploi pour une phase de navigation
/// ulterieure : il ne lui manque qu'un appelant.
public struct DatabaseFullPageView: View {
    private let database: Database
    @State private var viewModel: DatabaseViewModel

    public init(database: Database, modelContext: ModelContext, relatedDatabases: [Database] = []) {
        self.database = database
        let model = DatabaseViewModel(
            database: database, modelContext: modelContext, relatedDatabases: relatedDatabases
        )
        self._viewModel = State(initialValue: model)
    }

    public var body: some View {
        DatabaseHostView(viewModel: viewModel)
            .background(SlateColor.bgEditor)
    }
}
