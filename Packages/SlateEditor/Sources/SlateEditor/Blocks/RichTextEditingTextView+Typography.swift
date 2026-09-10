import AppKit
import SlateModel
import SlateUI
import SwiftUI

/// Typographie de `RichTextEditingTextView` (docs/07_typographie_formatage.md) --
/// extrait de `RichTextEditingTextView.swift` pour rester sous la limite de longueur de
/// fichier de `CLAUDE.md` §5. Tous les helpers restent `private` : ils ne sont appeles
/// QUE depuis `applyTypography(for:)`, dans ce meme fichier.
extension RichTextEditingTextView {
    /// Police et interligne du bloc (design/tokens.md §16, spec E4 : "Corps 15 pt,
    /// interligne 1,5" ; design/tokens.md §9 pour H1-H6, Phase 7). Rappele a chaque
    /// `updateNSView` (voir `RichTextBlockView`) avec le `BlockType` COURANT du bloc --
    /// c'est la seule facon de suivre a la fois un changement de Dynamic Type systeme
    /// ET une conversion de type de bloc (Cmd+Opt+1..3, `EditorController.convertBlock`)
    /// en cours de vie de la meme instance de vue, AppKit n'offrant pas de notification
    /// dediee equivalente a l'environnement SwiftUI `\.dynamicTypeSize`.
    ///
    /// `blockType` par defaut a `.paragraph` : conserve la signature utilisable sans
    /// argument pour `configureAppearance()` (appele avant que le premier `Block` ne
    /// soit connu de ce type, purement generique -- voir la documentation de tete de
    /// `RichTextEditingTextView.swift`).
    func applyTypography(for blockType: BlockType = .paragraph) {
        let style = Self.textStyle(for: blockType)
        let scaledFont = Self.scaledFont(for: style)
        let paragraphStyle = Self.paragraphStyle(for: scaledFont)
        font = scaledFont
        textColor = NSColor(SlateColor.textPrimary)
        defaultParagraphStyle = paragraphStyle
        typingAttributes = [
            .font: scaledFont,
            .foregroundColor: NSColor(SlateColor.textPrimary),
            .paragraphStyle: paragraphStyle
        ]
    }

    /// `SlateTextStyle` du corps de texte, ou du titre correspondant si `blockType` est
    /// l'un des 6 niveaux de titre (Phase 7, point 6 : "H1-H6 reellement editables").
    /// Les autres types (liste, citation, code) restent hors perimetre de cette phase
    /// (blocs speciaux, Phase 8) : ils retombent sur le corps de texte, ce qui n'a
    /// aujourd'hui aucun effet observable puisqu'ils ne sont pas encore routes vers
    /// `RichTextBlockView` (voir `BlockContentRouterView`).
    private static func textStyle(for blockType: BlockType) -> SlateTextStyle {
        switch BlockRenderRouting.kind(for: blockType) {
        case let .heading(level): HeadingStyle.font(forLevel: level)
        default: SlateFont.body
        }
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
