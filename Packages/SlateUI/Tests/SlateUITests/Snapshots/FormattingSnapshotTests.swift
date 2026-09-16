import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle du formatage (Phase 7, design/tokens.md §9/§6) : styles de
/// titre H1-H6, corps, code inline, les 6 surlignages -- clair ET sombre.
///
/// ## Hors perimetre : la barre de formatage flottante
/// `FormatBarButton`/le survol de selection vivent dans `SlateEditor`
/// (`Document/FormatBarButton.swift`), pas dans `SlateUI` : ce paquet n'a aucune
/// dependance vers `SlateEditor` (sens interdit, voir `Package.swift`), et le type est
/// `internal` a son module d'origine. Rendre cette barre depuis les tests `SlateUI`
/// n'est donc pas possible sans deplacer le composant -- hors du perimetre de cette
/// mission (`Packages/SlateUI/Tests/`). Voir le rapport de livraison.
///
/// Ni H1-H6/corps/code-inline/surlignage n'ont de vue `SlateUI` dediee : ce sont des
/// TOKENS (`SlateFont`, `SlateColor.codeInline*`, `SlateHighlightToken`) appliques par
/// `SlateEditor` a du texte attribue dans un `NSTextView` pont AppKit (voir
/// `RichTextDisplayAttributes.swift`), donc lui-meme hors de portee d'`ImageRenderer`.
/// Les galeries ci-dessous reconstruisent la meme application de tokens sur un `Text`
/// SwiftUI pur, pour verifier au moins visuellement le rendu des tokens eux-memes
/// (tailles, poids, couleurs) independamment du pont AppKit.
@MainActor
@Suite("Verification visuelle - formatage (Phase 7)")
struct FormattingSnapshotTests {
    @Test("Echelle de titres H1-H6 et corps, clair et sombre")
    func headingScale() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                headingGallery.environment(\.colorScheme, scheme),
                named: "formatting_headings_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Code inline, clair et sombre")
    func codeInline() throws {
        for scheme in ColorScheme.allCases {
            // `Text + Text` (concatenation) ne compose pas `.background` par segment :
            // le chip `code.inline.bg`/`code.inline.text` est donc reconstruit avec un
            // `HStack` de deux `Text` distincts plutot qu'une seule phrase concatenee,
            // pour verifier les DEUX tokens de couleur (pas seulement la police).
            let view = HStack(spacing: 4) {
                Text("Utiliser").slateFont(SlateFont.body).foregroundStyle(SlateColor.textPrimary)
                Text("SlateFont.mono")
                    .font(inlineCodeFont)
                    .foregroundStyle(SlateColor.codeInlineText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(SlateColor.codeInlineBackground, in: RoundedRectangle(cornerRadius: 4))
                Text("pour le code inline.").slateFont(SlateFont.body).foregroundStyle(SlateColor.textPrimary)
            }
            .padding(Spacing.lg)
            .frame(width: 460)
            .background(SlateColor.bgEditor)
            .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(view, named: "formatting_code_inline_\(scheme.snapshotSuffix)")
        }
    }

    @Test("Les 6 surlignages, clair et sombre")
    func highlights() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                highlightGallery.environment(\.colorScheme, scheme),
                named: "formatting_highlights_\(scheme.snapshotSuffix)"
            )
        }
    }

    /// `.font(...)` direct plutot que `.slateFont(SlateFont.mono)` : cette derniere
    /// s'appuie sur `@ScaledMetric`, un `ViewModifier` a part entiere qui ne se
    /// concatene pas dans une composition `Text + Text` (limite de l'API `Text`, pas de
    /// `SlateFont`).
    private var inlineCodeFont: Font {
        .system(size: SlateFont.mono.size, weight: SlateFont.mono.weight, design: .monospaced)
    }

    private var headingGallery: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Titre H1").slateFont(SlateFont.h1)
            Text("Titre H2").slateFont(SlateFont.h2)
            Text("Titre H3").slateFont(SlateFont.h3)
            Text("Titre H4").slateFont(SlateFont.h4)
            Text("Titre H5").slateFont(SlateFont.h5)
            Text("Titre H6").slateFont(SlateFont.h6)
            Text("Corps de texte standard, 15 pt Regular.").slateFont(SlateFont.body)
        }
        .foregroundStyle(SlateColor.textPrimary)
        .padding(Spacing.lg)
        .frame(width: 480, alignment: .leading)
        .background(SlateColor.bgEditor)
    }

    private var highlightGallery: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(SlateHighlightToken.allCases, id: \.self) { token in
                Text("Surlignage \(token.rawValue)")
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                    .padding(.horizontal, Spacing.xs)
                    .background(token.background)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320, alignment: .leading)
        .background(SlateColor.bgEditor)
    }
}
