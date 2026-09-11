import AppKit
import SlateModel
import SlateUI
import SwiftUI

/// Typographie de `RichTextEditingTextView` (docs/07_typographie_formatage.md,
/// docs/08_blocs_speciaux.md) -- extrait de `RichTextEditingTextView.swift` pour rester
/// sous la limite de longueur de fichier de `CLAUDE.md` §5. Tous les helpers restent
/// `private` : ils ne sont appeles QUE depuis `applyTypography(for:isChecked:)`, dans ce
/// meme fichier.
extension RichTextEditingTextView {
    /// Police, interligne, enroulement de ligne et style "coche" du bloc
    /// (design/tokens.md §16, spec E4 : "Corps 15 pt, interligne 1,5" ; §9 pour H1-H6 ;
    /// §16 (Phase 8) pour la police mono du bloc code). Rappele a chaque `updateNSView`
    /// (voir `RichTextEditingRepresentable`) avec le `BlockType`/etat COURANTS du bloc --
    /// c'est la seule facon de suivre a la fois un changement de Dynamic Type systeme,
    /// une conversion de type de bloc et une bascule de case a cocher en cours de vie de
    /// la meme instance de vue, AppKit n'offrant pas de notification dediee equivalente
    /// a l'environnement SwiftUI.
    ///
    /// `blockType`/`isChecked` par defaut : conserve la signature utilisable sans
    /// argument pour `configureAppearance()` (appele avant que le premier `Block` ne
    /// soit connu de ce type, purement generique -- voir la documentation de tete de
    /// `RichTextEditingTextView.swift`).
    ///
    /// ## Bloc a cocher barre/estompe (Phase 8, docs/08 : "texte barre et estompe quand
    /// cochee")
    /// `isChecked` ne pilote QUE `typingAttributes` ici -- c'est-a-dire l'apparence des
    /// caracteres qui seraient tapes MAINTENANT. Le style du contenu DEJA affiche est
    /// applique separement, sur tout le `NSTextStorage`, par
    /// `RichTextEditingRepresentable.Coordinator.apply(_:to:)` (seul endroit qui
    /// reconstruit l'attribut `NSAttributedString` complet) : les deux chemins doivent
    /// rester coherents, voir sa documentation pour le detail du declenchement (le
    /// contenu affiche n'est repousse que si le modele texte OU l'etat coche a change
    /// depuis la derniere synchronisation).
    ///
    /// ## Bloc code non enroule (Phase 8, docs/08 : "jamais de retour a la ligne force")
    /// Pour tout type SAUF `.code`, le conteneur de texte suit la largeur du bloc
    /// (`widthTracksTextView = true`, comportement historique depuis la Phase 5). Pour
    /// `.code`, il est fixe a une largeur INFINIE une fois pour toutes : aucune ligne ne
    /// retombe jamais, le debordement horizontal est gere par un `ScrollView(.horizontal)`
    /// SwiftUI parent (`CodeBlockContentView`), jamais par un `NSScrollView` autour de ce
    /// `NSTextView` (exclu par la doc de tache de la Phase 5). Voir
    /// `intrinsicSize(forProposedWidth:)` pour la remontee de la largeur NATURELLE du
    /// contenu dans ce cas.
    func applyTypography(for blockType: BlockType = .paragraph, isChecked: Bool = false) {
        let style = Self.textStyle(for: blockType)
        let scaledFont = Self.font(for: style, blockType: blockType)
        let paragraphStyle = Self.paragraphStyle(for: scaledFont)
        let isDoneTodo = blockType == .todo && isChecked
        let color = isDoneTodo ? NSColor(SlateColor.todoTextDone) : NSColor(SlateColor.textPrimary)

        font = scaledFont
        textColor = color
        defaultParagraphStyle = paragraphStyle

        var attributes: [NSAttributedString.Key: Any] = [
            .font: scaledFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        if isDoneTodo {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        typingAttributes = attributes

        applyWrapping(for: blockType)
    }

    /// Configure l'enroulement du conteneur de texte -- voir la documentation de
    /// `applyTypography(for:isChecked:)`, "Bloc code non enroule".
    private func applyWrapping(for blockType: BlockType) {
        let wraps = blockType != .code
        guard let textContainer else { return }
        textContainer.widthTracksTextView = wraps
        if !wraps {
            textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        isHorizontallyResizable = !wraps
    }

    /// `SlateTextStyle` du corps de texte, ou du titre correspondant si `blockType` est
    /// l'un des 6 niveaux de titre (Phase 7, point 6). Les items de liste/citation/
    /// callout retombent sur le corps de texte (aucune typographie propre demandee par
    /// leur spec) ; le bloc code retombe aussi sur le corps pour sa TAILLE (sa police
    /// devient mono via `font(for:blockType:)` ci-dessous, la taille de base reste
    /// identique au corps de texte).
    private static func textStyle(for blockType: BlockType) -> SlateTextStyle {
        switch BlockRenderRouting.kind(for: blockType) {
        case let .heading(level): HeadingStyle.font(forLevel: level)
        default: SlateFont.body
        }
    }

    /// Police finale : la police systeme mise a l'echelle Dynamic Type
    /// (`scaledFont(for:)`), remplacee par son equivalent a CHASSE FIXE pour un bloc
    /// code (Phase 8, docs/08 : "Police mono, fond dedie").
    private static func font(for style: SlateTextStyle, blockType: BlockType) -> NSFont {
        let base = scaledFont(for: style)
        guard blockType == .code else { return base }
        return NSFont.monospacedSystemFont(ofSize: base.pointSize, weight: .regular)
    }

    /// Approxime la mise a l'echelle Dynamic Type d'un `SlateTextStyle`
    /// (`@ScaledMetric`, cf. `SlateFont.swift`) pour un `NSTextView` autonome, sans
    /// equivalent direct de `@ScaledMetric` en AppKit pur. `NSFont.preferredFont(
    /// forTextStyle:)` est l'API AppKit qui suit reellement le reglage systeme "Texte
    /// plus grand", interrogee pour le `Font.TextStyle` DE REFERENCE du token
    /// (`style.relativeTo`, pas toujours `.body` -- Phase 7, chaque niveau de titre a le
    /// sien, voir `SlateFont.h1`/`h2`/`h3`) ; `NSFont.systemFontSize` (13 pt) est la
    /// taille de reference macOS a l'echelle 100 % -- meme principe de calcul de ratio
    /// que `@ScaledMetric`, applique a la taille de base du token plutot qu'a la taille
    /// systeme par defaut.
    private static func scaledFont(for style: SlateTextStyle) -> NSFont {
        let referenceSize = NSFont.systemFontSize
        let preferredSize = NSFont.preferredFont(forTextStyle: nsTextStyle(for: style.relativeTo)).pointSize
        let scale = referenceSize > 0 ? preferredSize / referenceSize : 1
        return NSFont.systemFont(ofSize: style.size * scale, weight: nsWeight(for: style.weight))
    }

    /// `Font.TextStyle` (SwiftUI) -> `NSFont.TextStyle` (AppKit), pour interroger
    /// `NSFont.preferredFont(forTextStyle:)` avec le style de reference REEL du token
    /// (voir `scaledFont(for:)`), pas systematiquement `.body`.
    private static func nsTextStyle(for style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }

    /// `Font.Weight` (SwiftUI) -> `NSFont.Weight` (AppKit). Gras du corps de bloc =
    /// Semibold (artboard P1 D : "le gras passe en Semibold et non en Bold") -- ce
    /// mappage ne concerne QUE l'epaisseur de BASE du bloc (paragraphe/titre), le gras
    /// APPLIQUE PAR L'UTILISATEUR (marque `.bold`) est traduit separement par
    /// `RichTextDisplayAttributes` (Phase 7, "Rendu des marques").
    private static func nsWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }

    /// Interligne de 1,5 (`SlateGeometry.editorParagraphLineHeight`) impose via les
    /// bornes min/max de `NSParagraphStyle` -- l'equivalent AppKit du `.lineSpacing`
    /// SwiftUI utilise par `ParagraphBlockContentView` en lecture seule. Meme
    /// multiplicateur pour les titres (voir `HeadingStyle.firstLineHeight(forLevel:)`,
    /// deja aligne sur cette meme constante).
    private static func paragraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let lineHeight = font.pointSize * SlateGeometry.editorParagraphLineHeight
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return style
    }
}
