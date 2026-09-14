import Observation
import Foundation

/// Etat observable des reglages de COMPORTEMENT de l'editeur (par opposition a
/// `ThemeManager`, qui porte l'apparence). Premier -- et pour l'instant seul --
/// reglage : "convertir le markdown colle en blocs" (docs/15_markdown_natif.md,
/// "Coller du markdown -> conversion optionnelle en blocs (reglage)").
///
/// ## Meme motif de persistance que `ThemeManager`
/// `UserDefaults.standard`, pas `@AppStorage` : cette classe est un simple
/// `@Observable`, pas une `View` -- voir la documentation de tete de `ThemeManager` pour
/// la justification complete (combiner `@AppStorage` et `@Observable` sur la meme
/// propriete stockee n'est pas supporte). Meme regle : lecture au demarrage, ecriture a
/// chaque changement, singleton partage (`shared`) plutot qu'une instance par ecran,
/// pour que l'editeur (`SlateEditor`) et l'ecran de reglages (`SlateFeatures`) lisent/
/// ecrivent TOUJOURS la meme valeur.
///
/// ## Pas de miroir thread-safe (contrairement a `ThemeManager`/`SlateThemeState`)
/// `ThemeManager` a besoin d'un miroir verrouille parce que ses valeurs sont lues
/// pendant le CALCUL DE TOKENS (`SlateColor`/`SlateFont`), qui peut se produire hors du
/// thread principal (tests Swift Testing notamment). `convertsMarkdownOnPaste` n'est lu
/// qu'a un seul endroit : la reaction AppKit a Cmd+V dans un `NSTextView` d'edition
/// (`RichTextEditingTextView.paste(_:)`), TOUJOURS sur le thread principal -- aucun
/// miroir necessaire.
@MainActor
@Observable
public final class EditorPreferences {
    /// Instance partagee. Voir la note "Meme motif de persistance" ci-dessus.
    public static let shared = EditorPreferences()

    /// "Convertir le markdown colle en blocs" (docs/15). `true` par defaut : c'est le
    /// comportement le plus utile pour la majorite des collages (texte copie depuis un
    /// fichier `.md`, un README, un message redige en markdown) -- desactivable pour qui
    /// prefere coller du texte brut tel quel, syntaxe markdown incluse.
    public var convertsMarkdownOnPaste: Bool {
        didSet {
            UserDefaults.standard.set(convertsMarkdownOnPaste, forKey: DefaultsKey.convertsMarkdownOnPaste)
        }
    }

    private enum DefaultsKey {
        static let convertsMarkdownOnPaste = "slate.editor.convertsMarkdownOnPaste"
    }

    private init() {
        let defaults = UserDefaults.standard
        convertsMarkdownOnPaste = defaults.object(forKey: DefaultsKey.convertsMarkdownOnPaste) as? Bool ?? true
    }
}
