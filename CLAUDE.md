# CLAUDE.md — Instructions pour Claude Code

> Ce fichier est lu automatiquement par Claude Code au démarrage de chaque session dans ce dossier.
> Il définit **comment travailler** sur ce projet. Le **quoi faire et dans quel ordre** est décrit dans `PLAN.md`.

---

## 1. Le projet en une phrase

**Slate** (nom de code — modifiable) est une application **native macOS écrite en SwiftUI**, pensée comme une fusion entre l'app **Notes d'Apple** (design, dossiers, dates, verrouillage) et **Notion / AppFlowy** (éditeur de blocs, commandes `/`, bases de données, IA). iOS viendra dans un second temps à partir du même code.

### Décisions techniques verrouillées (ne pas rediscuter sans accord de Cyril)

| Sujet | Choix |
|---|---|
| UI | **SwiftUI** (code partagé macOS + iOS) |
| Persistance | **SwiftData** |
| Synchronisation | **CloudKit** (iCloud privé, comme Notes) |
| macOS minimum | **macOS 15 Sequoia** |
| Langage | Swift 6 (mode concurrence stricte) |
| Architecture | MVVM léger + `@Observable`, séparé en modules Swift Package |
| Éditeur | Modèle de **blocs** (block-based), pas un simple TextView |

---

## 2. Protocole de travail « GO » ⚠️ IMPORTANT

Le projet est découpé en **phases** (voir `PLAN.md`). Chaque phase a son propre document dans `docs/`.

**Règle d'or : tu ne travailles que sur UNE phase à la fois.**

1. Au début d'une session, lis `PLAN.md` et identifie la **première phase non cochée**.
2. Ouvre le document `docs/NN_xxx.md` correspondant et **annonce à Cyril** :
   - le numéro et le nom de la phase,
   - ce que tu vas construire,
   - **si cette phase nécessite un design de Claude Design** (voir §4),
   - le plan d'exécution avec les sous-agents que tu vas lancer.
3. **Attends que Cyril réponde `go`** avant d'écrire du code.
4. Exécute la phase intégralement (via sous-agents, voir §3).
5. À la fin : lance la phase de vérification, coche la phase dans `PLAN.md`, fais un court récap, puis **arrête-toi** et propose de passer à la phase suivante.

Ne jamais enchaîner deux phases sans un `go` explicite.

---

## 3. Stratégie de sous-agents (obligatoire)

Pour chaque phase, tu **délègues** le travail à des sous-agents spécialisés (définis dans `.claude/agents/`) via l'outil `Task`. Tu restes l'orchestrateur : tu découpes, tu lances en parallèle ce qui est indépendant, tu recolles.

> ⚙️ **Setup unique** : les définitions d'agents sont livrées dans `sous-agents/`. À la toute première session, copie-les dans `.claude/agents/` (`cp sous-agents/*.md .claude/agents/` en excluant le README). Ensuite elles sont actives.

Agents disponibles :

- **`data-modeler`** — modèles SwiftData, migrations, CloudKit, requêtes.
- **`swiftui-builder`** — vues SwiftUI, navigation, composants d'UI.
- **`editor-specialist`** — tout ce qui touche l'éditeur de blocs (rendu, focus, saisie, `/`, drag & drop, colonnes).
- **`design-integrator`** — intègre les specs/tokens/maquettes de Claude Design dans le code (couleurs, typo, espacements, composants).
- **`swift-reviewer`** — relit, compile mentalement, vérifie la concurrence Swift 6, écrit/lance les tests, signale les régressions.

Règles :
- Lance en **parallèle** les tâches indépendantes (ex : `data-modeler` sur un modèle pendant que `swiftui-builder` fait une vue placeholder).
- Termine **chaque** phase par un passage `swift-reviewer`.
- Un sous-agent ne doit modifier que le périmètre qu'on lui confie.

---

## 4. Handoff avec Claude Design ⚠️

Certaines phases sont marquées 🎨 **DESIGN REQUIS** dans `PLAN.md`. Pour celles-ci :

1. Quand tu atteins une phase 🎨, **arrête-toi avant de coder l'UI** et dis clairement à Cyril :
   > « 🎨 Cette phase a besoin du design. Ouvre Claude Design et demande-lui les écrans suivants : [...]. Colle-moi ensuite le résultat (SwiftUI, tokens de couleur/typo, ou captures) dans le dossier `design/`. Dis `go` quand c'est prêt. »
2. Indique **précisément** quels écrans / composants sont attendus (la liste est dans `DESIGN_HANDOFF.md`).
3. Cyril déposera les livrables design dans `design/NN_nom/`. Tu les intègres via l'agent `design-integrator`.
4. Si aucun design n'est fourni, tu peux proposer un rendu par défaut basé sur les tokens de `design/tokens.md`, mais tu le signales comme provisoire.

---

## 5. Conventions de code

- **Structure** : monorepo Xcode + Swift Packages locaux (voir `docs/00_architecture.md`).
- **Nommage** : anglais pour le code (types, fonctions), français autorisé pour les commentaires.
- **State** : `@Observable` (Observation framework), pas d'`ObservableObject` sauf nécessité.
- **Vues** : petites, composables, une vue par fichier. Previews SwiftUI systématiques.
- **Pas de force-unwrap** (`!`) en dehors des tests. Gestion d'erreurs explicite.
- **Accessibilité** : labels, Dynamic Type, contraste — dès la première implémentation.
- **Localisation** : chaînes via `String(localized:)`, base FR + EN.
- **Commits** : un commit par étape logique, message clair (`feat:`, `fix:`, `refactor:`…).
- **Tests** : Swift Testing (`import Testing`) pour la logique ; previews pour l'UI.

### ⚠️ Piège récurrent : détacher un bloc ne le supprime PAS du store

Trouvé et corrigé **trois fois** (phases 8, 10 et 15). `BlockOrdering.remove(_:)` et
`BlockOperations` ne font que **détacher** un bloc du graphe en mémoire (`note = nil`,
`parent = nil`) : ils n'appellent jamais `ModelContext.delete(_:)`. Un bloc retiré sans
purge explicite reste donc persisté indéfiniment, invisible dans l'interface mais bien
réel - et synchronisé vers CloudKit.

**Règle** : tout chemin qui retire définitivement un bloc (suppression, dissolution de
structure, annulation d'une insertion) doit faire un `modelContext?.delete(...)` explicite.

**Et surtout** : un test qui vérifie seulement `note.blocks` **ne voit rien** de ce bug.
Il faut un vrai `ModelContainer` en mémoire et un `context.fetch(FetchDescriptor<Block>())`
après `save()`. Motif de référence : `EditorControllerDeletionPurgeTests`.

---

## 6. Ce que tu ne fais PAS

- Tu n'ajoutes pas de dépendance tierce sans la proposer d'abord à Cyril.
- Tu ne codes pas une phase future « en avance ».
- Tu ne supprimes pas de fichier design fourni par Cyril.
- Tu ne changes pas les décisions du tableau §1 sans validation.

---

## 7. Démarrage rapide

À la toute première session, la phase 0 (`docs/00_architecture.md` puis `docs/01_setup_projet.md`) crée le projet Xcode et la structure. Commence par lire `PLAN.md`, puis suis le protocole §2.
