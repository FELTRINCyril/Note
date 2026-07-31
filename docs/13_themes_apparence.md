# Phase 13 — Thèmes & apparence

## Objectif
Mode sombre / clair (+ « système ») et couleur d'accent personnalisable, appliqués via le design system.

## Prérequis
Phase 3+ (UI en place). S'appuie sur les tokens de `SlateUI`.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- Les **tokens de couleur** clair ET sombre (fond, surfaces, texte, séparateurs, accent, surlignages).
- La **typographie** (échelle : titre note, H1–H6, corps, mono, légende).
- La **palette d'accents** proposés + l'UI de personnalisation.
- Espacements/rayons/ombres du design system.

Déposer dans `design/13_themes/` et **surtout** consolider dans `design/tokens.md` (référence unique). Dire `go`.

---

## Spécifications fonctionnelles
- Sélecteur d'apparence : **Système / Clair / Sombre**.
- **Couleur d'accent** personnalisable (palette + éventuellement couleur custom).
- Application immédiate et globale, persistée (préférences app, par workspace en v2).
- Respect de l'accessibilité : contrastes AA, Increase Contrast, Reduce Transparency.

## Détails techniques
- Centraliser **tous** les tokens dans `SlateUI` (couleurs sémantiques, pas de couleur en dur ailleurs). Rétro-appliquer si des vues antérieures ont des couleurs codées en dur.
- `ThemeManager` `@Observable` exposant le thème courant via `@Environment`.
- `.preferredColorScheme` piloté par le réglage.
- Accent : `tint` global + tokens dérivés.

## Sous-agents
- `design-integrator` : **agent principal** — traduit `design/tokens.md` en code SlateUI, remplace les couleurs en dur.
- `swiftui-builder` : écran d'apparence, `ThemeManager`.
- `swift-reviewer` : vérifie clair/sombre sur tous les écrans, contrastes, absence de couleurs en dur.

## Critères d'acceptation
- Bascule clair/sombre/système propre sur toute l'app.
- Accent personnalisable et appliqué partout.
- Aucune couleur codée en dur hors design system.

## Vérification
Audit des couleurs en dur (grep) + captures clair/sombre de chaque écran. Cocher Phase 13.
