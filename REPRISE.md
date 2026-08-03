# REPRISE — continuer Slate sur un autre Mac

> Ce fichier voyage avec le dépôt GitHub. Sur le nouveau Mac, il te donne l'ordre exact des messages à coller.
> État au moment de la pause : **phases 0 → 4 terminées**, prochaine = **phase 5 (éditeur de blocs)**, marquée 🎨.

---

## 0. Préparer le nouveau Mac (une fois)
- Installer **Xcode** (avec macOS 15 SDK) et se connecter à un **compte iCloud** (pour CloudKit).
- Cloner le dépôt : `git clone https://github.com/FELTRINCyril/Note.git`
- Ouvrir le dossier dans **Claude Code**.
- (Pour les captures d'écran de vérification) autoriser **Switchboard** dans *Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran*, puis le quitter/relancer.

---

## 1. Prompt de REPRISE (premier message à Claude Code)

> Je reprends le projet Slate sur un nouveau Mac. Le code vient d'être cloné depuis https://github.com/FELTRINCyril/Note dans ce dossier.
> Avant de coder quoi que ce soit :
> 1. Lis `CLAUDE.md`, `PLAN.md` et `STATUT.md`, puis résume-moi en 3 lignes où on en est et quelle est la prochaine phase.
> 2. Vérifie que les sous-agents sont actifs : si `.claude/agents/` est absent ou vide, copie-y `sous-agents/*.md` (sauf le README).
> 3. Vérifie que l'environnement du nouveau Mac est bon : que le projet compile et que la suite de tests passe (build + tests SPM / scheme Xcode). Signale-moi tout ce qui manque (version Xcode, SDK macOS 15, réglage iCloud/CloudKit, autorisation Switchboard).
> Ne lance aucune phase tant que je n'ai pas dit `go`.

---

## 2. Prompt à donner à CLAUDE DESIGN (écran de la phase 5)
*(joindre `design/01-brief-design.md` et `design/tokens.md`)*

> Tu conçois Slate, une app macOS native (SwiftUI, macOS 15) : un hybride entre l'app Notes d'Apple et Notion. Les deux fichiers joints sont ta référence : 01-brief-design.md et tokens.md (respecte-les strictement, appelle les tokens par leur nom). Reste cohérent avec les écrans déjà conçus E1/E2 (coquille + sidebar) et E3 (liste) : ici c'est la 3e colonne, l'éditeur, colonne de texte centrée à 720 pt max.
>
> Livre-moi l'écran E4 — Éditeur de note, en thème clair ET sombre, avec tous les états. De préférence en code SwiftUI utilisant les tokens (pas de couleurs en dur) ; sinon des maquettes annotées + specs.
>
> E4 — Éditeur de note :
> - En-tête : zone icône/emoji optionnel + image de couverture optionnelle, titre (title.note), sous-titre.
> - Corps : pile verticale de blocs, colonne centrée (editor.maxContentWidth 720), espacement inter-blocs (editor.blockSpacing).
> - Poignée de bloc ⋮⋮ + bouton + à gauche, révélés au survol.
> - États d'un bloc : normal, survol, focus (caret actif), sélectionné (block.selected.bg), placeholder « Tapez / pour les commandes ».
> - Comportement visuel du caret entre blocs et de la sélection multi-blocs.
> - Rendu de quelques types de base pour caler la hiérarchie et l'espacement : paragraphe, H1–H3, liste à puces, case à cocher (cochée/décochée), citation. (Le détail des blocs spéciaux et de la barre de formatage viendra dans des écrans ultérieurs.)
>
> Donne-moi aussi les composants : BlockHandle (poignée ⋮⋮ + bouton +) et le gabarit d'une rangée de bloc éditable. Deux thèmes, accessibilité (contraste AA — vérifie sur l'accent, Dynamic Type, focus clavier distinct de la sélection).

Déposer le résultat dans `design/05_editeur/`.

---

## 3. Le VRAI prompt de travail (à Claude Code, après avoir déposé le design)

> Le design de la phase 5 est dans `design/05_editeur/`. D'abord je valide les trois points en suspens de la phase 4 :
> 1. **Aplat de sélection** à 2 valeurs par thème (via la règle générale) : OK, on garde — la règle protège le contraste quand l'accent deviendra personnalisable en phase 13.
> 2. **Increase Contrast** plus sombre : OK, c'est le but du mode.
> 3. **Date à J-7** (« 27 juil. » vs « Lundi ») : aligne le format sur le groupe — toutes les entrées de « 7 jours précédents » en nom de jour.
>
> Ensuite, lance la **phase 5 (éditeur de blocs)** :
> - **Architecture d'édition** : pars sur l'option recommandée du doc (un `RichTextBlockView` par bloc via `NSViewRepresentable` / TextKit 2), sauf vrai bloquant — dans ce cas, arrête-toi et explique-moi avant de coder.
> - Respecte le **découpage en sous-étapes 5.1 → 5.6** du doc ; petit point à la fin de chaque sous-étape.
> - **Périmètre** : le menu `/` (phase 6), le formatage inline (phase 7) et les blocs spéciaux (phase 8) restent hors périmètre — prévois seulement les points d'accroche.
> - Implémente le design via `design-integrator`, termine par `swift-reviewer` (tests de l'`EditorController` : insertion / fusion / split / conversion, focus, perf sur note longue).
> - Coche la phase 5 dans `PLAN.md` et **mets à jour `STATUT.md`** en fin de phase (garde-le, c'est mon récap maintenu hors workflow, ne le supprime pas).
> Puis `go`.

---

## Rappel du cycle
Design → dépôt dans `design/05_editeur/` → prompt §3 → Claude Code code par sous-étapes → vérif → coche → il s'arrête. Rien n'avance sans ton `go`.
