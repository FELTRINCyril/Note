# design/tokens.md — Source de vérité du Design System

> **Valeurs par défaut « macOS natif »** pré-remplies (inspirées des couleurs système Apple, SF Pro, matériaux translucides).
> Elles donnent un rendu cohérent macOS immédiat. Claude Design peut les affiner en Phase 13, mais elles sont utilisables telles quelles.
> Tout le code de `SlateUI` doit dériver de ces tokens — **aucune couleur / taille / police / espacement / durée codés en dur ailleurs**.
> Notation : `rgba(...)` = couleur semi-transparente (dynamique) ; sinon hex opaque. Préférer les **couleurs système SwiftUI** quand un équivalent existe (indiqué en *italique*).

---

## 1. Couleurs — Fonds & surfaces
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `bg.window` | #ECECEC | #1E1E1E | Fond de fenêtre (*windowBackground*) |
| `bg.sidebar` | Matériau translucide `.sidebar` (base #F2F2F5) | Matériau `.sidebar` (base #232326) | Fond barre latérale |
| `bg.list` | #FFFFFF | #1E1E1E | Fond colonne liste |
| `bg.editor` | #FFFFFF | #1C1C1E | Fond zone d'édition |
| `surface.primary` | #FFFFFF | #2A2A2C | Cartes, panneaux, popovers |
| `surface.secondary` | #F2F2F5 | #2C2C2E | Champs, zones secondaires |
| `surface.tertiary` | #E5E5EA | #3A3A3C | Fonds enfoncés/inset |
| `overlay.scrim` | rgba(0,0,0,0.20) | rgba(0,0,0,0.45) | Voile derrière modales |

## 2. Couleurs — Texte
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `text.primary` | rgba(0,0,0,0.85) | rgba(255,255,255,0.85) | Texte principal (*label*) |
| `text.secondary` | rgba(0,0,0,0.50) | rgba(255,255,255,0.55) | Métadonnées (*secondaryLabel*) |
| `text.tertiary` | rgba(0,0,0,0.26) | rgba(255,255,255,0.26) | Texte discret (*tertiaryLabel*) |
| `text.placeholder` | rgba(0,0,0,0.25) | rgba(255,255,255,0.25) | Placeholders |
| `text.disabled` | rgba(0,0,0,0.25) | rgba(255,255,255,0.25) | Texte désactivé |
| `text.link` | = `accent.default` | = `accent.default` | Liens hypertextes |
| `text.onAccent` | #FFFFFF | #FFFFFF | Texte sur fond d'accent |
| `text.inverse` | #FFFFFF | #000000 | Tooltips, contrastes inversés |

## 3. Couleurs — Accent & états interactifs
> Accent par défaut = **bleu système macOS** (personnalisable, cf. §7).

| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `accent.default` | #007AFF | #0A84FF | Accent principal (*accentColor*) |
| `accent.hover` | #0A6CE0 | #3D9BFF | Accent au survol |
| `accent.pressed` | #0857B8 | #2E7FE0 | Accent pressé |
| `accent.subtle` | rgba(0,122,255,0.12) | rgba(10,132,255,0.22) | Fond d'accent atténué |
| `state.hover` | rgba(0,0,0,0.05) | rgba(255,255,255,0.07) | Survol générique |
| `state.pressed` | rgba(0,0,0,0.10) | rgba(255,255,255,0.12) | Pressé générique |
| `state.selected` | = `accent.default` | = `accent.default` | Ligne/bloc sélectionné (fenêtre active) |
| `state.selectedInactive` | rgba(0,0,0,0.10) | rgba(255,255,255,0.13) | Sélection quand fenêtre inactive |
| `state.selectedText` | rgba(0,122,255,0.28) | rgba(10,132,255,0.35) | Sélection de texte |
| `focusRing` | rgba(0,122,255,0.60) | rgba(10,132,255,0.65) | Contour focus clavier (*keyboardFocus*) |

## 4. Couleurs — Sémantiques
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `semantic.error` | #FF3B30 | #FF453A | Erreurs, suppression |
| `semantic.warning` | #FF9500 | #FF9F0A | Avertissements |
| `semantic.success` | #34C759 | #30D158 | Succès, tâche cochée |
| `semantic.info` | #007AFF | #0A84FF | Informations |

## 5. Couleurs — Séparateurs & bordures
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `separator` | rgba(0,0,0,0.10) | rgba(255,255,255,0.15) | Séparateurs (*separator*) |
| `border.default` | rgba(0,0,0,0.12) | rgba(255,255,255,0.15) | Bordures champs/cartes |
| `border.strong` | rgba(0,0,0,0.22) | rgba(255,255,255,0.28) | Bordures accentuées |

## 6. Couleurs — Surlignage de texte (marques inline)
> Pastel discret, texte = `text.primary` par-dessus.

| Nom | Fond clair | Fond sombre |
|---|---|---|
| Jaune | #FFF3B0 | #4D4A2E |
| Vert | #D7F0D0 | #2E4632 |
| Bleu | #D0E4FF | #2C3E52 |
| Rose | #FBD5E4 | #4A2E3B |
| Rouge | #FFD6D2 | #4D2E2C |
| Gris | #E3E3E6 | #3A3A3C |

## 7. Couleurs — Palette d'accents proposés
> Reprend les **couleurs d'accent système macOS**. `accent.default` = Bleu.

| Nom | Clair | Sombre |
|---|---|---|
| Bleu (défaut) | #007AFF | #0A84FF |
| Violet | #AF52DE | #BF5AF2 |
| Rose | #FF2D55 | #FF375F |
| Rouge | #FF3B30 | #FF453A |
| Orange | #FF9500 | #FF9F0A |
| Jaune | #FFCC00 | #FFD60A |
| Vert | #34C759 | #30D158 |
| Graphite | #8E8E93 | #98989D |

## 8. Couleurs — Icônes de dossiers / notes
> Mêmes teintes que la palette d'accents (§7). Le jaune sert d'icône de dossier par défaut, façon Notes.

---

## 9. Typographie
- `font.sans` = **SF Pro** (police système `.system`)
- `font.serif` = **New York** (`.serif`, optionnel pour un style « note »)
- `font.mono` = **SF Mono** (`.monospaced`) — activer les **chiffres tabulaires**

| Rôle | Police | Taille | Poids | Interligne | Notes |
|---|---|---|---|---|---|
| `title.note` | sans | 28 | Bold | 1.15 | Titre de note (éditeur) |
| `title.secondary` | sans | 22 | Bold | 1.2 | Titre secondaire |
| `subtitle` | sans | 17 | Regular | 1.3 | Sous-titre (couleur `text.secondary`) |
| `h1` | sans | 26 | Bold | 1.2 | |
| `h2` | sans | 22 | Semibold | 1.25 | |
| `h3` | sans | 20 | Semibold | 1.3 | |
| `h4` | sans | 17 | Semibold | 1.3 | |
| `h5` | sans | 15 | Semibold | 1.35 | |
| `h6` | sans | 13 | Semibold | 1.4 | Légère capitalisation possible |
| `body` | sans | 15 | Regular | 1.5 | Corps de texte |
| `bodyEmphasis` | sans | 15 | Semibold | 1.5 | |
| `mono` | mono | 13 | Regular | 1.45 | Bloc/inline code |
| `quote` | sans | 15 | Regular (italique) | 1.5 | Citation |
| `callout` | sans | 14 | Regular | 1.45 | |
| `caption` | sans | 12 | Regular | 1.35 | Légende (`text.secondary`) |
| `label` | sans | 13 | Regular | 1.3 | Libellés UI / boutons |
| `sidebarItem` | sans | 13 | Regular | 1.3 | Ligne de sidebar |
| `listTitle` | sans | 14 | Semibold | 1.3 | Titre cellule de note |
| `listSnippet` | sans | 13 | Regular | 1.35 | Extrait (`text.secondary`) |

> Exprimer en **Dynamic Type** (échelle relative aux `Font.TextStyle`), pas seulement en points fixes.

---

## 10. Espacements (échelle, pt)
| Token | Valeur |
|---|---|
| `space.2xs` | 2 |
| `space.xs` | 4 |
| `space.s` | 8 |
| `space.m` | 12 |
| `space.l` | 16 |
| `space.xl` | 24 |
| `space.2xl` | 32 |
| `space.3xl` | 48 |

## 11. Rayons de coin (pt)
| Token | Valeur | Usage |
|---|---|---|
| `radius.s` | 6 | Champs, petits boutons |
| `radius.m` | 8 | Cartes, blocs |
| `radius.l` | 12 | Popovers, modales |
| `radius.full` | 999 | Pastilles, avatars |

## 12. Épaisseurs de trait & focus (pt)
| Token | Valeur |
|---|---|
| `stroke.hairline` | 1 (0.5 sur écran Retina) |
| `stroke.regular` | 1.5 |
| `focusRing.width` | 3 |
| `focusRing.offset` | 1 |

## 13. Ombres / élévation
> macOS reste sobre : matériaux + ombres légères.

| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `elevation.low` | y:1 blur:3 rgba(0,0,0,0.08) | y:1 blur:3 rgba(0,0,0,0.30) | Cartes survolées |
| `elevation.medium` | y:4 blur:12 rgba(0,0,0,0.12) | y:4 blur:12 rgba(0,0,0,0.40) | Popovers, menus |
| `elevation.high` | y:10 blur:30 rgba(0,0,0,0.20) | y:10 blur:30 rgba(0,0,0,0.55) | Modales, drag |

## 14. Opacités
| Token | Valeur |
|---|---|
| `opacity.disabled` | 0.4 |
| `opacity.hoverOverlay` | 0.06 |
| `opacity.dragGhost` | 0.6 |

## 15. Tailles d'icônes & contrôles (pt)
| Token | Valeur | Usage |
|---|---|---|
| `icon.s / m / l` | 14 / 16 / 20 | Icônes UI |
| `control.height.s / m / l` | 22 / 28 / 36 | Boutons/champs |
| `row.height.sidebar` | 28 | Ligne de dossier |
| `row.height.noteCell` | 64 | Cellule de note (titre+extrait+date) |
| `handle.size` | 18 | Poignée de bloc ⋮⋮ |
| `checkbox.size` | 18 | Case à cocher |

---

## 16. Tokens spécifiques à l'éditeur & aux blocs
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `editor.maxContentWidth` | 720 pt | — | Largeur max colonne de texte |
| `editor.blockSpacing` | 4 pt | — | Espace vertical entre blocs |
| `editor.paragraphLineHeight` | 1.5 | — | Interligne du corps |
| `code.block.bg` | #F5F5F7 | #2A2A2C | Fond bloc de code |
| `code.inline.bg` | rgba(0,0,0,0.06) | rgba(255,255,255,0.10) | Fond code en ligne |
| `code.inline.text` | #BF2600 | #FF7B72 | Texte code en ligne |
| `quote.barColor` | #D1D1D6 | #48484A | Barre latérale de citation |
| `quote.text` | rgba(0,0,0,0.65) | rgba(255,255,255,0.65) | Texte de citation |
| `callout.bg` | #F2F2F5 | #2C2C2E | Fond callout neutre (variantes = `semantic.*` en `.subtle`) |
| `callout.border` | rgba(0,0,0,0.08) | rgba(255,255,255,0.10) | Bordure de callout |
| `divider.color` | = `separator` | = `separator` | Bloc séparateur |
| `todo.checkbox.border` | rgba(0,0,0,0.30) | rgba(255,255,255,0.35) | Case non cochée |
| `todo.checkbox.fill` | = `accent.default` | = `accent.default` | Case cochée |
| `todo.text.done` | = `text.tertiary` (barré) | = `text.tertiary` (barré) | Tâche cochée |
| `table.header.bg` | #F2F2F5 | #2C2C2E | En-tête de tableau |
| `table.border` | = `separator` | = `separator` | Bordures de cellules |
| `table.rowStripe` | rgba(0,0,0,0.02) | rgba(255,255,255,0.03) | Ligne alternée (optionnel) |
| `block.selected.bg` | rgba(0,122,255,0.12) | rgba(10,132,255,0.20) | Bloc sélectionné |
| `block.dropIndicator` | = `accent.default` | = `accent.default` | Ligne d'insertion (drag) |
| `column.gap` | 24 pt | — | Espace entre colonnes |
| `column.resizer` | = `separator` | = `separator` | Séparateur de colonnes |
| `pageLink.text` / `pageLink.icon` | = `text.link` / `accent` | idem | Lien de page interne |

## 17. Tokens barre latérale & liste
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `sidebar.item.selected.bg` | = `accent.default` | = `accent.default` | Ligne sélectionnée (texte = `text.onAccent`) |
| `sidebar.item.hover.bg` | = `state.hover` | = `state.hover` | Ligne survolée |
| `sidebar.sectionHeader.text` | rgba(0,0,0,0.45) | rgba(255,255,255,0.45) | En-têtes (11 pt Semibold, majuscules) |
| `sidebar.indent.step` | 16 pt | — | Indentation par niveau |
| `sidebar.chevron` | = `text.tertiary` | = `text.tertiary` | Chevron de pliage |
| `list.dateHeader.text` | = `text.secondary` | = `text.secondary` | En-tête « Aujourd'hui »… (13 Semibold) |
| `list.cell.selected.bg` | = `accent.default` | = `accent.default` | Cellule sélectionnée |
| `list.indicator.pinned/locked/favorite` | = `accent` / `text.secondary` / `semantic.warning` | idem | Icônes d'état |

## 18. Tokens base de données (Phase 17)
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `db.grid.headerBg` | #F2F2F5 | #2C2C2E | En-tête de colonne |
| `db.grid.cellBorder` | = `separator` | = `separator` | Grille |
| `db.tag.bg` (par couleur) | teintes `.subtle` de §7 | idem | Étiquettes (select) |
| `db.kanban.columnBg` | #F2F2F5 | #232326 | Colonne Kanban |
| `db.card.bg` | #FFFFFF | #2A2A2C | Carte (kanban/galerie) |
| `db.card.shadow` | = `elevation.low` | = `elevation.low` | Ombre de carte |
| `db.calendar.today` | = `accent.subtle` | = `accent.subtle` | Jour courant |
| `db.calendar.eventBg` | = `accent.subtle` | = `accent.subtle` | Événement |

## 19. Tokens IA (Phase 18)
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `ai.panel.bg` | #F8F8FA | #232326 | Panneau assistant |
| `ai.bubble.user` | = `accent.subtle` | = `accent.subtle` | Bulle utilisateur |
| `ai.bubble.assistant` | #FFFFFF | #2A2A2C | Bulle assistant |
| `ai.source.chipBg` | = `surface.secondary` | = `surface.secondary` | Puce de source RAG |
| `ai.streamingCursor` | = `accent.default` | = `accent.default` | Curseur de génération |

---

## 20. Mouvement / animations
| Token | Valeur | Usage |
|---|---|---|
| `motion.duration.fast` | 120 ms | Survols, petits changements |
| `motion.duration.base` | 200 ms | Transitions standard |
| `motion.duration.slow` | 300 ms | Apparitions de panneaux |
| `motion.easing.standard` | `.easeInOut` | Courbe par défaut |
| `motion.easing.emphasis` | `.spring(response: 0.35, dampingFraction: 0.8)` | Entrées/sorties marquées |
| `motion.reduceMotionFallback` | Fondu simple (opacité), aucun déplacement | Si « Réduire les animations » |

---

## Contraintes transverses (à respecter par Claude Design)
- **Deux thèmes obligatoires** : chaque couleur a une valeur clair + sombre.
- **Accessibilité** : contraste AA minimum (texte), support « Increase Contrast » et « Reduce Transparency ».
- **Dynamic Type** : typo en échelle relative.
- **Accent personnalisable** : les tokens `accent.*` se recolorent selon le choix utilisateur (§7) sans casser les contrastes.
- **Matériaux macOS** : privilégier `Material` SwiftUI (`.sidebar`, `.regular`, `.thin`) pour sidebar/popovers plutôt que des fonds opaques quand c'est pertinent.
