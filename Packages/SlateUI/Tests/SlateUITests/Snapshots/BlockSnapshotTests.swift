import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle des blocs (Phases 7-8, design/tokens.md §16/§16 bis) : callout
/// dans ses 4 variantes, citation, separateur, item de liste a puces/numerotee, item a
/// cocher coche/non coche, barre d'outils de bloc de code -- clair ET sombre. Voir
/// `SnapshotRenderer` pour la technique et sa limite (SwiftUI pur uniquement, ce dont
/// tous ces composants relevent : aucun d'eux n'utilise `ScrollView`, materiau
/// translucide ou pont AppKit).
@MainActor
@Suite("Verification visuelle - blocs (Phases 7-8)")
struct BlockSnapshotTests {
    @Test("Callout - 4 variantes, clair et sombre")
    func calloutVariants() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                calloutGallery.environment(\.colorScheme, scheme),
                named: "block_callout_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Citation - clair et sombre")
    func quote() throws {
        for scheme in ColorScheme.allCases {
            let view = QuoteBlockView {
                Text("La citation garde la barre quote.barColor de 3 pt et le texte a 65 %.")
            }
            .slateFont(SlateFont.body)
            .padding(Spacing.lg)
            .frame(width: 480)
            .background(SlateColor.bgEditor)
            .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(view, named: "block_quote_\(scheme.snapshotSuffix)")
        }
    }

    @Test("Separateur - clair et sombre")
    func divider() throws {
        for scheme in ColorScheme.allCases {
            let view = VStack {
                Text("Au-dessus").slateFont(SlateFont.body).foregroundStyle(SlateColor.textPrimary)
                DividerBlockView()
                Text("En dessous").slateFont(SlateFont.body).foregroundStyle(SlateColor.textPrimary)
            }
            .padding(Spacing.lg)
            .frame(width: 480)
            .background(SlateColor.bgEditor)
            .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(view, named: "block_divider_\(scheme.snapshotSuffix)")
        }
    }

    @Test("Items de liste - puces et numeros, clair et sombre")
    func listItems() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                listItemGallery.environment(\.colorScheme, scheme),
                named: "block_list_items_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Items a cocher - coche et non coche, clair et sombre")
    func checklistItems() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                ChecklistGallery().environment(\.colorScheme, scheme),
                named: "block_checklist_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Barre d'outils de bloc de code - clair et sombre")
    func codeBlockToolbar() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                CodeBlockToolbarGallery().environment(\.colorScheme, scheme),
                named: "block_code_toolbar_\(scheme.snapshotSuffix)"
            )
        }
    }

    private var calloutGallery: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SlateCalloutVariant.allCases) { variant in
                CalloutBlockView(variant) {
                    Text("Texte du callout \(variant.rawValue).")
                }
            }
        }
        .padding(Spacing.lg)
        .frame(width: 560)
        .background(SlateColor.bgEditor)
    }

    private var listItemGallery: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListItemView(.bullet(level: 0)) { Text("Premier niveau - puce ronde") }
            ListItemView(.bullet(level: 1)) { Text("Deuxieme niveau - chevron plein") }
            ListItemView(.bullet(level: 2)) { Text("Troisieme niveau - carre") }
            ListItemView(.ordered(index: 9, level: 0)) { Text("Neuf") }
            ListItemView(.ordered(index: 10, level: 0)) { Text("Dix - colonne stable") }
            ListItemView(.ordered(index: 1, level: 1)) { Text("Deuxieme niveau en lettres") }
            ListItemView(.ordered(index: 1, level: 2)) { Text("Troisieme niveau en romains") }
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}

/// `ChecklistItemView.isDone` est un `Binding` : un `@State` a besoin d'une vue hote
/// dediee, comme dans le `#Preview` source.
private struct ChecklistGallery: View {
    @State private var done = true
    @State private var notDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChecklistItemView(isDone: $done) { Text("Tache faite - barree et attenuee") }
            ChecklistItemView(isDone: $notDone) { Text("Tache a faire") }
            ChecklistItemView(isDone: $notDone, level: 1) { Text("Sous-tache imbriquee") }
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}

private struct CodeBlockToolbarGallery: View {
    @State private var language = "swift"

    var body: some View {
        CodeBlockToolbar(language: $language, didCopy: false, onCopy: {})
            .background(SlateColor.codeBlockBackground)
            .padding(Spacing.lg)
            .background(SlateColor.bgEditor)
    }
}

extension ColorScheme {
    /// Suffixe de nom de fichier stable, independant de la description par defaut de
    /// `ColorScheme` (qui n'est pas garantie par l'API publique).
    var snapshotSuffix: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        @unknown default: "unknown"
        }
    }
}
