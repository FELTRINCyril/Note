import SlateUI
import SwiftUI

/// Contenu du menu de commandes "/" (sous-etape 6.5, docs/06_slash_commandes.md).
/// Presente en overlay SwiftUI positionne par calcul par l'appelant (`SlashMenuOverlay`,
/// voir sa documentation de tete pour la raison precise -- un `.popover` prendrait le
/// focus clavier de la fenetre et couperait la frappe dans le `NSTextView` du bloc)
/// plutot que via un `Menu` natif : meme raisonnement que `BlockMenuView` (voir sa
/// documentation de tete) -- une liste filtrable pilotee entierement au CLAVIER
/// (fleches, Entree, Echap) n'a pas d'equivalent direct dans les controles natifs
/// `Menu`, qui gerent leur propre navigation clavier de facon opaque a l'appelant.
///
/// ## Le piege central : une SEULE source de verite pour la ligne mise en avant
/// Cette vue ne porte AUCUN `@State` de survol local. `selectedItemID` est fourni par
/// l'appelant (pilote au clavier) ; le survol souris ne fait que le lui SIGNALER via
/// `onHover`, sans jamais peindre lui-meme un etat different. Une variante avec un
/// `@State private var hoveredItemID` local doublerait cette source de verite : la ligne
/// survolee et la ligne "active" (celle qu'Entree validerait) pourraient alors diverger
/// visuellement de la ligne reellement active -- exactement le defaut qu'un menu "/"
/// doit eviter, puisque Entree doit toujours valider ce que l'utilisateur voit en
/// surbrillance, qu'il ait bouge la souris ou les fleches pour l'atteindre. C'est pour
/// cette meme raison que `onHover` ne declenche jamais `onSelect` : il ne fait que
/// remonter l'information de position, le controleur decide seul de deplacer
/// `selectedItemID` en reponse (ou pas, s'il ignore le survol dans un contexte donne).
///
/// ## Offsets de caracteres, pas d'UTF-16
/// `Item.matchedTitleOffsets` indexe `title` en CARACTERES (`String.Character`, comme
/// `RichTextOffset` -- voir `Support/RichTextOffset.swift` -- meme si ce type n'est pas
/// reutilise ici : il modelise des positions dans le texte d'un BLOC edite, pas dans un
/// libelle d'UI ponctuel comme celui-ci, et le contrat de cette vue fixe volontairement
/// `[Int]` bruts). La mise en evidence ci-dessous avance donc dans `AttributedString.
/// characters` (une vue par GRAPHEME, alignee sur les offsets fournis), jamais via
/// `NSString`/les vues UTF-16 de `String` : un emoji ou un sigle compose avant un
/// caractere mis en evidence deciderait sinon un decalage silencieux, le meme defaut deja
/// corrige une fois dans `RichTextOffset` (voir sa documentation de tete).
///
/// ## Geometrie : gaps de token signales, pas combles ici
/// Aucun token dedie n'existe dans `design/tokens.md` pour la largeur/hauteur maximale de
/// CE popover precis, ni pour une icone "generique" de menu (le §15 documente `icon.s/m/l`
/// mais `SlateGeometry` n'expose que des alias contextuels -- `sidebarIconSize`,
/// `searchFieldIconSize`... -- jamais de constante nommee neutre). Deux choix suivent le
/// PRECEDENT DEJA ETABLI par `BlockMenuView`, qui fixe lui aussi une largeur de popover en
/// litteral (`frame(minWidth: 200)`) plutot que d'inventer un token : `menuWidth`/
/// `menuMaxHeight` ci-dessous sont des litteraux documentes, pas de nouveaux tokens
/// `SlateUI`. L'icone de commande reutilise `SlateGeometry.sidebarIconSize` (14 pt) : sa
/// valeur numerique est bien celle d'`icon.s`, seul son nom porte encore un contexte
/// (sidebar) qui ne lui correspond pas ici -- meme compromis que `searchFieldIconSize`,
/// qui documente explicitement la meme reutilisation.
///
/// ## Rendu du survol/de la selection clavier
/// Reutilise strictement `SlateColor.stateHover` (le MEME token que `BlockMenuRow`) pour
/// peindre la ligne mise en avant -- clavier ou souris, seule `selectedItemID` compte (voir
/// plus haut). Aucune nouvelle convention de survol n'est introduite.
struct SlashMenuView: View {
    /// Une entree de commande, deja resolue par le registre de commandes (hors perimetre
    /// de ce fichier) : titre/sous-titre localises, glyphe SF, et les offsets de
    /// caracteres de `title` a mettre en evidence pour la requete tapee.
    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let systemImage: String
        /// Offsets de CARACTERES dans `title` correspondant a la requete tapee. Vide si
        /// le match ne vient pas du titre (voir la doc de tete : "Offsets de caracteres,
        /// pas d'UTF-16").
        let matchedTitleOffsets: [Int]
    }

    /// Une categorie de commandes deja localisee (ex. "Basique", "Media"...).
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let items: [Item]
    }

    let sections: [Section]
    /// Item actuellement mis en avant, pilote au CLAVIER par le controleur. Seule source
    /// de verite du rendu "en surbrillance" -- voir la doc de tete.
    let selectedItemID: String?
    /// Message a afficher quand aucune section ne contient d'item (deja localise).
    let emptyStateMessage: String
    /// Validation d'un item : clic souris, ou Entree relayee par le controleur.
    let onSelect: (String) -> Void
    /// Survol souris : ne peint RIEN par lui-meme, se contente de signaler au controleur
    /// qu'il peut deplacer `selectedItemID` vers cet item.
    let onHover: (String) -> Void

    /// Largeur fixe du popover : voir la doc de tete, "Geometrie". Choisie assez large
    /// pour un sous-titre d'une ligne sans tronquer le titre le plus long du registre de
    /// commandes typique (icone + libelle + description courte), sans jamais varier
    /// pendant qu'on filtre -- c'est le point qui compte pour l'utilisateur (le popover ne
    /// doit pas "sauter" a chaque frappe).
    private static let menuWidth: CGFloat = 280

    /// Hauteur maximale avant defilement : voir la doc de tete, "Geometrie". Environ sept
    /// lignes visibles a la taille de corps par defaut -- au-dela, `ScrollView` prend le
    /// relais plutot que de laisser le popover grandir sans limite.
    private static let menuMaxHeight: CGFloat = 320

    /// Sections effectivement affichees : une section sans item ne doit rien produire du
    /// tout, pas meme son en-tete (evite un en-tete "orphelin" au-dessus de rien).
    private var nonEmptySections: [Section] {
        sections.filter { !$0.items.isEmpty }
    }

    var body: some View {
        Group {
            if nonEmptySections.isEmpty {
                emptyState
            } else {
                menuList
            }
        }
        .frame(width: Self.menuWidth)
    }

    private var emptyState: some View {
        Text(emptyStateMessage)
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(Spacing.lg)
    }

    private var menuList: some View {
        // `ScrollViewReader` est le complement OBLIGATOIRE de cette liste, pas une simple
        // amelioration : sans lui, deplacer `selectedItemID` au clavier au-dela de la
        // fenetre visible du `ScrollView` laisserait la ligne en surbrillance sortir de
        // l'ecran -- inutilisable a la fleche bas/haut sur un registre de commandes un peu
        // long. Meme motif que `NoteDocumentView.scrollToFocusedBlockIfNeeded(_:proxy:)`.
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nonEmptySections) { section in
                        SidebarSectionHeader(section.title)
                        ForEach(section.items) { item in
                            SlashMenuItemRow(
                                item: item,
                                isSelected: item.id == selectedItemID,
                                onSelect: { onSelect(item.id) },
                                onHover: { onHover(item.id) }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .frame(maxHeight: Self.menuMaxHeight)
            // `anchor: nil` (jamais anime), meme convention que `NoteDocumentView` : un
            // saut instantane vers la ligne selectionnee plutot qu'un defilement anime qui
            // ne ferait que retarder la lisibilite du resultat pendant une navigation
            // clavier rapide (repetition de fleche bas/haut).
            .onChange(of: selectedItemID) { _, newValue in
                guard let newValue else { return }
                scrollProxy.scrollTo(newValue, anchor: nil)
            }
        }
    }
}

/// Ligne d'une commande du menu "/". Type dedie (comme `BlockMenuRow`) plutot qu'une
/// fonction : porte son propre acces a `@Environment(\.accessibilityReduceMotion)`, mais
/// AUCUN `@State` de survol local -- voir la doc de tete de `SlashMenuView`, "Le piege
/// central".
private struct SlashMenuItemRow: View {
    let item: SlashMenuView.Item
    let isSelected: Bool
    let onSelect: () -> Void
    let onHover: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(SlateColor.textSecondary)
                    .frame(width: SlateGeometry.sidebarIconSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SlashMenuTitleText(title: item.title, matchedOffsets: item.matchedTitleOffsets)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .slateFont(SlateFont.caption)
                            .foregroundStyle(SlateColor.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            // Ne remonte que l'ENTREE dans la ligne : la sortie n'a rien a signaler
            // (voir la doc de tete -- c'est au controleur de decider ce qui devient "en
            // surbrillance" ensuite, jamais a cette vue de l'anticiper).
            guard hovering else { return }
            onHover()
        }
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isSelected
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: some View {
        isSelected ? SlateColor.stateHover : Color.clear
    }

    private var accessibilityLabel: String {
        item.subtitle.isEmpty ? item.title : "\(item.title). \(item.subtitle)"
    }
}

/// Titre d'une commande, avec mise en evidence des caracteres de `matchedOffsets` (voir
/// la doc de tete de `SlashMenuView`, "Offsets de caracteres, pas d'UTF-16").
///
/// Type dedie a `@ScaledMetric` plutot qu'une fonction : la taille du run mis en evidence
/// doit suivre le Dynamic Type au meme rythme que `SlateFont.label` (applique au `Text`
/// entier via `slateFont(_:)`), donc etre mise a l'echelle par le MEME mecanisme -- exact
/// pendant de `SlateFontModifier` (`SlateUI/SlateFont.swift`), reimplemente ici plutot que
/// reutilise car il applique sa mise a l'echelle a un `Text` complet, jamais a une portion
/// de `AttributedString`.
private struct SlashMenuTitleText: View {
    let title: String
    let matchedOffsets: [Int]

    @ScaledMetric private var matchedFontSize: CGFloat

    init(title: String, matchedOffsets: [Int]) {
        self.title = title
        self.matchedOffsets = matchedOffsets
        _matchedFontSize = ScaledMetric(wrappedValue: SlateFont.label.size, relativeTo: SlateFont.label.relativeTo)
    }

    var body: some View {
        Text(highlightedTitle)
            .slateFont(SlateFont.label)
            .lineLimit(1)
            .foregroundStyle(SlateColor.textPrimary)
    }

    /// Les runs SANS attribut explicite retombent sur le `.slateFont`/`.foregroundStyle`
    /// appliques au `Text` porteur ci-dessus (comportement documente d'`AttributedString`
    /// compose avec `Text` : un attribut de run n'ecrase que la portion qui le porte
    /// explicitement, le reste herite de l'environnement). Seuls les runs mis en evidence
    /// recoivent donc un `.font`/`.foregroundColor` explicite ci-dessous.
    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(title)
        guard !matchedOffsets.isEmpty else { return attributed }

        // Vue par GRAPHEME (`Character`), alignee sur la convention "offsets de
        // caracteres" du contrat -- jamais les vues UTF-16 de `String`. Voir la doc de
        // tete de `SlashMenuView`.
        let characterIndices = Array(attributed.characters.indices)
        let matchedFont = Font.system(size: matchedFontSize, weight: .semibold)

        for offset in matchedOffsets where characterIndices.indices.contains(offset) {
            let start = characterIndices[offset]
            let end = attributed.characters.index(after: start)
            attributed[start..<end].font = matchedFont
            attributed[start..<end].foregroundColor = SlateColor.accentDefault
        }
        return attributed
    }
}

#Preview("SlashMenuView - liste complete") {
    SlashMenuView(
        sections: [
            SlashMenuView.Section(
                id: "basic",
                title: "Basique",
                items: [
                    SlashMenuView.Item(
                        id: "paragraph",
                        title: "Texte",
                        subtitle: "Paragraphe simple",
                        systemImage: "text.alignleft",
                        matchedTitleOffsets: []
                    ),
                    SlashMenuView.Item(
                        id: "heading1",
                        title: "Titre 1",
                        subtitle: "Grand titre de section",
                        systemImage: "textformat.size.larger",
                        matchedTitleOffsets: []
                    ),
                    SlashMenuView.Item(
                        id: "todo",
                        title: "Case a cocher",
                        subtitle: "Suivre une tache",
                        systemImage: "checklist",
                        matchedTitleOffsets: []
                    )
                ]
            ),
            SlashMenuView.Section(
                id: "media",
                title: "Media",
                items: [
                    SlashMenuView.Item(
                        id: "image",
                        title: "Image",
                        subtitle: "Importer une image",
                        systemImage: "photo",
                        matchedTitleOffsets: []
                    )
                ]
            )
        ],
        selectedItemID: "heading1",
        emptyStateMessage: "Aucune commande trouvee",
        onSelect: { _ in },
        onHover: { _ in }
    )
    .padding(Spacing.sm)
    .background(SlateColor.surfacePrimary)
}

#Preview("SlashMenuView - liste filtree avec mise en evidence") {
    SlashMenuView(
        sections: [
            SlashMenuView.Section(
                id: "basic",
                title: "Basique",
                items: [
                    SlashMenuView.Item(
                        id: "todo",
                        title: "Case a cocher",
                        subtitle: "Suivre une tache",
                        systemImage: "checklist",
                        // "Ca" tape par l'utilisateur -> les deux premiers caracteres du
                        // titre "Case a cocher" sont mis en evidence.
                        matchedTitleOffsets: [0, 1]
                    )
                ]
            )
        ],
        selectedItemID: "todo",
        emptyStateMessage: "Aucune commande trouvee",
        onSelect: { _ in },
        onHover: { _ in }
    )
    .padding(Spacing.sm)
    .background(SlateColor.surfacePrimary)
}

#Preview("SlashMenuView - etat vide") {
    SlashMenuView(
        sections: [],
        selectedItemID: nil,
        emptyStateMessage: "Aucune commande trouvee",
        onSelect: { _ in },
        onHover: { _ in }
    )
    .padding(Spacing.sm)
    .background(SlateColor.surfacePrimary)
}
