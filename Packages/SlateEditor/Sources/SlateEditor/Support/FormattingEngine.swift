import Foundation
import SlateModel

/// Marque de formatage BOOLEENNE (sans payload), sous-ensemble d'`InlineMark`
/// (`SlateModel`) qui bascule simplement present/absent sur une plage -- distinct de
/// `.highlight`/`.textColor`/`.link` (payload, geres separement par
/// `EditorController+Formatting.swift` : une couleur/URL n'a pas de sens "bascule",
/// voir `setHighlight`/`setTextColor`/`setLink`).
public enum FormattingMarkKind: CaseIterable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case inlineCode

    /// `InlineMark` correspondante (voir `RichText.apply`/`remove`, `SlateModel`).
    var inlineMark: InlineMark {
        switch self {
        case .bold: .bold
        case .italic: .italic
        case .underline: .underline
        case .strikethrough: .strikethrough
        case .inlineCode: .inlineCode
        }
    }
}

/// Logique PURE (aucune dependance AppKit) de detection/application du formatage
/// inline sur une plage de `RichText` (docs/07_typographie_formatage.md). Separee
/// d'`EditorController+Formatting.swift` pour la meme raison que `BlockLifecycle`/
/// `BlockOrdering` sont separes d'`EditorController` : rester testable directement,
/// sans construire de `Note`/`Block`, sur un `RichText` isole.
enum FormattingEngine {
    /// URL de repli utilisee UNIQUEMENT pour les appels a `RichText.remove(.link(_:),
    /// from:)` : la documentation de `RichText.remove(_:from:)` garantit explicitement
    /// que le payload d'un retrait est ignore (seule la nature de la marque compte),
    /// cette valeur n'est donc jamais lue -- `URL(fileURLWithPath:)` ne peut pas echouer
    /// (contrairement a `URL(string:)`), evitant tout optionnel/force-unwrap ici.
    static let dummyURL = URL(fileURLWithPath: "/")

    /// `true` si TOUS les runs de `range` portent `kind` (bascule attendue : appliquer
    /// `kind` sur une plage ou il est deja present PARTOUT doit le retirer plutot que de
    /// l'appliquer une seconde fois sans effet). Une plage vide n'est jamais "active".
    static func isMarkActive(
        _ kind: FormattingMarkKind, in text: RichText, range: Range<AttributedString.Index>
    ) -> Bool {
        guard range.lowerBound < range.upperBound else { return false }
        return text.attributedString[range].runs.allSatisfy { run in
            switch kind {
            case .bold: run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
            case .italic: run.inlinePresentationIntent?.contains(.emphasized) == true
            case .strikethrough: run.inlinePresentationIntent?.contains(.strikethrough) == true
            case .underline: run.slateUnderline == true
            case .inlineCode: run.slateInlineCode == true
            }
        }
    }

    /// Couleur de surlignage commune a TOUS les runs de `range`, ou `nil` si la plage
    /// est vide, MELANGEE (au moins un run differe d'un autre), ou entierement sans
    /// surlignage -- utilise pour l'etat "coche" de la palette (artboard P1 B) : une
    /// coche n'est honnete que si la plage entiere partage la meme valeur.
    static func uniformHighlight(in text: RichText, range: Range<AttributedString.Index>) -> SlateHighlightColor? {
        guard range.lowerBound < range.upperBound else { return nil }
        var result: SlateHighlightColor?
        var isFirst = true
        for run in text.attributedString[range].runs {
            let value = run.slateHighlight
            if isFirst {
                result = value
                isFirst = false
            } else if value != result {
                return nil
            }
        }
        return result
    }

    /// Symmetrique de `uniformHighlight(in:range:)` pour la couleur de texte.
    static func uniformTextColor(in text: RichText, range: Range<AttributedString.Index>) -> SlateTextColor? {
        guard range.lowerBound < range.upperBound else { return nil }
        var result: SlateTextColor?
        var isFirst = true
        for run in text.attributedString[range].runs {
            let value = run.slateTextColor
            if isFirst {
                result = value
                isFirst = false
            } else if value != result {
                return nil
            }
        }
        return result
    }

    /// Symmetrique de `uniformHighlight(in:range:)` pour le lien -- `nil` si la plage ne
    /// porte pas un SEUL et MEME lien de bout en bout (etat "desactive" du bouton lien
    /// sur une selection multi-liens, voir docs/07 point "Etats des boutons").
    static func uniformLink(in text: RichText, range: Range<AttributedString.Index>) -> URL? {
        guard range.lowerBound < range.upperBound else { return nil }
        var result: URL?
        var isFirst = true
        for run in text.attributedString[range].runs {
            let value = run.link
            if isFirst {
                result = value
                isFirst = false
            } else if value != result {
                return nil
            }
        }
        return result
    }
}
