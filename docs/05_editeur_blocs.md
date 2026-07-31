# Phase 5 — Éditeur de blocs (le cœur) ⭐

## Objectif
Construire le moteur d'édition par blocs façon Notion/AppFlowy : chaque bloc est une unité éditable indépendante, on navigue et on édite au clavier, on ajoute/supprime/convertit des blocs de façon fluide. **C'est la phase la plus complexe** — elle est découpée en sous-étapes internes ci-dessous.

## Prérequis
Phases 2, 3, 4.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- La zone d'édition (marges, largeur de ligne, en-tête titre + icône + cover).
- La **poignée de bloc** (⋮⋮ à gauche, pour drag & menu) et le bouton **+** d'ajout.
- États d'un bloc : focus, survol, sélectionné, placeholder (« Tapez / pour les commandes »).
- Le caret et le comportement visuel entre blocs.

Déposer dans `design/05_editeur/`. Dire `go`.

---

## Décision d'architecture d'édition ⚠️
Le point le plus délicat : comment rendre du **texte riche éditable** par bloc.

Options (à trancher avec `editor-specialist`) :
1. **Un `TextField`/`TextEditor` SwiftUI par bloc texte** — simple, mais contrôle limité du caret entre blocs et du formatage inline riche.
2. **`NSViewRepresentable` autour de `NSTextView` (TextKit 2) par bloc** — contrôle total (caret, formatage, raccourcis), plus de code. **Recommandé pour la qualité visée**, avec un composant `RichTextBlockView` réutilisable.
3. **Un seul grand `NSTextView` TextKit 2** avec des blocs modélisés par paragraphes/attributs — le plus proche d'un vrai éditeur mais le plus complexe.

Recommandation : **option 2** — un `RichTextBlockView` (TextKit 2) par bloc texte, orchestré par une vue liste de blocs. Bon compromis contrôle/complexité et réutilisable pour toutes les phases suivantes (formatage, `/`, markdown).

---

## Sous-étapes internes (dans cet ordre)

### 5.1 Rendu en lecture seule
Afficher une note = rendre sa liste de `Block` ordonnés, chaque type avec son apparence (paragraphe, titres, listes, citation, code, divider…). Titre de note éditable en haut. Pas encore d'édition du corps.

### 5.2 Édition d'un bloc texte
Rendre un bloc paragraphe éditable (`RichTextBlockView`), sauvegarde du texte dans SwiftData (débounce). Placeholder sur bloc vide.

### 5.3 Cycle de vie des blocs au clavier
- **Entrée** en fin de bloc → crée un nouveau bloc en dessous et déplace le focus.
- **Retour arrière** en début de bloc vide → fusionne avec le précédent / supprime.
- **Flèches haut/bas** → déplacent le caret entre blocs (bord supérieur/inférieur).
- Gestion propre de `order` et du focus (`@FocusState` ou coordination via l'éditeur).

### 5.4 Poignée & menu de bloc
- Poignée ⋮⋮ au survol : ouvre un menu (convertir en…, dupliquer, supprimer, déplacer).
- Bouton **+** : insère un bloc / ouvre le menu `/` (Phase 6).

### 5.5 Conversion de type
Convertir un bloc d'un type à un autre (paragraphe ↔ titre ↔ liste ↔ citation…), en conservant le texte.

### 5.6 Sélection multi-blocs (base)
Sélectionner plusieurs blocs (clic + shift, ou glisser) pour supprimer/déplacer en lot. (Le drag & drop visuel complet est en Phase 10.)

---

## Détails techniques
- Vue `BlockEditorView` (dans `SlateEditor`) : itère sur `note.blocks` triés par `order`, rend chaque bloc via un routeur `BlockView(block:)`.
- `EditorController` `@Observable` : gère focus courant, insertion/suppression/conversion, coordination clavier.
- Sauvegarde débouncée vers SwiftData (éviter d'écrire à chaque frappe).
- Performance : recycler/paresser le rendu pour les notes longues.

## Sous-agents
- `editor-specialist` : **agent principal** pour tout ce doc (RichTextBlockView, EditorController, logique clavier, conversions).
- `design-integrator` : poignées, boutons +, placeholders, marges selon design.
- `swift-reviewer` : tests de l'`EditorController` (insertion/fusion/split/conversion), non-régression du focus, perf sur note longue.

## Critères d'acceptation
- On tape du texte, Entrée crée un bloc, Backspace fusionne, les flèches naviguent.
- On convertit un paragraphe en titre/liste/citation sans perdre le texte.
- Le contenu persiste et se recharge fidèlement.
- Fluidité correcte sur une note de 200+ blocs.

## Vérification
Suite de tests de l'`EditorController` + test manuel de saisie + capture design. Cocher Phase 5.
