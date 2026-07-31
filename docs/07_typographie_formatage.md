# Phase 7 — Typographie & formatage

## Objectif
Formatage de texte inline complet + styles de titres. Gras, italique, souligné, barré, code en ligne, surlignage couleur, liens hypertextes ; et les niveaux de titre H1–H6.

## Prérequis
Phase 5 (RichTextBlockView) et idéalement 6.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- La **barre de formatage flottante** qui apparaît sur sélection de texte (boutons gras/italique/souligné/barré/code/surlignage/lien).
- Le sélecteur de **couleur de surlignage** (palette).
- Le style visuel exact de **H1 à H6** (tailles, poids, espacements) et du code inline.
- Le popover d'édition de **lien** (URL + texte).

Déposer dans `design/07_formatage/`. Dire `go`.

---

## Spécifications fonctionnelles
### Formatage inline (sur sélection)
- Gras, italique, souligné, barré.
- Code en ligne (police mono, fond léger).
- **Surlignage couleur** : plusieurs couleurs (jaune, vert, bleu, rose, gris…) + couleur de texte.
- Liens hypertextes : ajouter/éditer/supprimer, ouverture au clic (avec Cmd).
- Raccourcis clavier : ⌘B, ⌘I, ⌘U, ⌘⇧X (barré), ⌘E (code inline), ⌘K (lien).
- La **barre flottante** apparaît au-dessus de la sélection.

### Titres
- H1 à H6 comme types de bloc (déjà dans l'enum), avec styles typographiques distincts et cohérents avec le design system.

## Détails techniques
- Implémenter le formatage via les attributs d'`AttributedString` (marks stockées dans `Block.text`, cf. Phase 2). Ajouter attributs custom pour surlignage/couleur.
- `FormattingController` : applique/retire une marque sur la sélection courante du `RichTextBlockView`.
- Barre flottante : vue SwiftUI positionnée sur le rect de sélection (via TextKit 2).
- Assurer la (dé)sérialisation correcte vers SwiftData et CloudKit.

## Sous-agents
- `editor-specialist` : application des marques, barre flottante, raccourcis, liens.
- `design-integrator` : barre flottante, palette de surlignage, styles H1–H6.
- `swift-reviewer` : tests d'application/retrait de marques, persistance des attributs, ouverture de liens.

## Critères d'acceptation
- Sélectionner du texte et appliquer chaque style fonctionne, y compris cumulés.
- Surlignage couleur et liens persistent et se rechargent.
- Raccourcis clavier opérationnels.
- H1–H6 rendus distinctement.

## Vérification
Tests des marques + persistance + essai manuel. Capture comparée au design. Cocher Phase 7.
