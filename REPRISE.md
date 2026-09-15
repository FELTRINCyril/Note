# REPRISE — continuer Slate sur un autre ordinateur

> Ce fichier voyage avec le dépôt GitHub. Il te donne l'ordre exact des messages à coller
> dans une nouvelle session Claude Code.
>
> **État au 15/09/2026 : phases 0 → 16 terminées.** Jalon v1 complet, jalon v2 entamé.
> **Prochaine phase : 17 — Bases de données.**
> Source de vérité des cases cochées : `PLAN.md`. Contexte détaillé : `STATUT.md`.

---

## 0. Préparer le nouvel ordinateur (une seule fois)

### Installer

- **Xcode** (SDK macOS 15 minimum) et se connecter à un compte iCloud (nécessaire seulement
  pour tester la synchronisation CloudKit, pas pour développer en Debug).
- **Homebrew**, puis :
  ```bash
  brew install xcodegen swiftlint
  ```
  `xcodegen` est **indispensable** : `Slate.xcodeproj` n'est pas versionné, il se régénère
  depuis `project.yml`. Sans lui, pas de projet Xcode. `swiftlint` est requis par la
  configuration de build et par la règle « 0 violation » du projet.

### Cloner et générer

```bash
git clone https://github.com/FELTRINCyril/Note.git
cd Note
xcodegen generate
```

### Piège d'environnement à connaître tout de suite

`xcode-select -p` pointe peut-être sur les Command Line Tools, qui ne fournissent ni les
macros SwiftData ni le module `Testing`. Dans ce cas **toute** commande de build ou de test
doit être préfixée :

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Le détail complet est dans `docs/DEV_ENV.md`, à lire avant de s'étonner d'une erreur de build.

### Pour la vérification visuelle

Autoriser le terminal (et/ou Switchboard) dans *Réglages Système → Confidentialité et
sécurité → Enregistrement de l'écran*, puis le quitter et le relancer. **Sans cette
autorisation, aucune capture d'écran n'est possible** et la conformité visuelle au design ne
peut pas être contrôlée — c'est aujourd'hui la principale limite du projet.

---

## 1. Premier message à Claude Code

> Je reprends le projet Slate sur un nouvel ordinateur. Le dépôt vient d'être cloné.
> Avant de coder quoi que ce soit :
> 1. Lis `CLAUDE.md`, `PLAN.md` et `STATUT.md`, puis résume-moi en 3 lignes où on en est et quelle est la prochaine phase.
> 2. Vérifie que les sous-agents sont actifs : `.claude/agents/` doit contenir les 5 définitions. S'il est absent ou vide, copie-y `sous-agents/*.md` (sauf le README).
> 3. Vérifie que l'environnement est bon : `xcodegen generate` a bien produit `Slate.xcodeproj`, le projet compile, et la suite de tests passe sur les 5 packages. Signale-moi tout ce qui manque (Xcode, SDK macOS 15, xcodegen, swiftlint, `DEVELOPER_DIR`).
> Ne lance aucune phase tant que je n'ai pas dit `go`.

---

## 2. Lancer la phase suivante

Le design de **toutes** les phases restantes est déjà livré dans `design/_design_complet/` :
plus aucun aller-retour avec Claude Design n'est nécessaire. `design/_design_complet/MAPPING.md`
donne la correspondance page → phase.

> Lance la **phase 17 (bases de données)**. Ouvre `docs/17_base_de_donnees.md`, prends la
> maquette correspondante dans `design/_design_complet/` via `MAPPING.md` (c'est
> « P5 - Bases de données »), et découpe la phase en sous-étapes : c'est la plus grosse du
> projet, son doc prévoit explicitement ce découpage. Point d'étape à la fin de chaque
> sous-étape. Termine par une revue, coche la phase dans `PLAN.md`, mets `STATUT.md` à jour,
> commit et push.
> Puis `go`.

Même schéma ensuite pour les phases 18 (IA, maquette P6), 19 (workspaces, P7) et 20 (iOS, P9).

---

## 3. Ce qu'une nouvelle session doit absolument savoir

Ces points ont coûté cher à découvrir. Ils sont documentés en détail dans `CLAUDE.md` §5 et
`docs/DEV_ENV.md`, mais les voici en résumé :

- **Détacher un bloc ne le supprime PAS du store.** `BlockOrdering`/`BlockOperations` ne font
  que détacher : il faut un `modelContext?.delete(...)` explicite, sinon les blocs restent
  persistés et partent vers CloudKit. Trouvé trois fois (phases 8, 10, 15).
- **Un champ ajouté à `BlockAttributes` doit être OPTIONNEL.** SwiftData aplatit cette struct
  `Codable` en colonnes Core Data ; un champ non optionnel casse l'ouverture de tout store
  existant. L'app a cessé de démarrer à cause de ça (phase 8, découvert en phase 16).
- **Un test en mémoire ne voit ni l'un ni l'autre.** Il faut un vrai `ModelContainer` sur
  disque et un `fetch` après `save()`. Motifs de référence : `EditorControllerDeletionPurgeTests`
  et `BlockAttributesHeaderRowMigrationTests`.
- **Pas de `MainActor.assumeIsolated` dans le calcul d'un token de couleur** : Swift Testing
  exécute les tests non isolés hors du thread principal, et ça provoque un SIGTRAP. Passer par
  le miroir verrouillé de `SlateThemeState`.
- **`swift test` en ligne de commande ne compile pas les `.xcstrings`** : `String(localized:)`
  y renvoie la clé brute. Ne jamais comparer un test à du texte traduit figé.
- **Ne pas lancer `swift test` en parallèle sur plusieurs packages** : le `.build` partagé
  produit des échecs fantômes. En cas de symbole « introuvable » qui existe pourtant :
  `rm -rf .build` dans le package concerné.

---

## 4. Le cycle de chaque phase

Annonce de la phase → `go` → implémentation (via sous-agents) → vérification → coche dans
`PLAN.md` → mise à jour de `STATUT.md` → commit et push → arrêt.

Rien n'avance sans un `go` explicite (`CLAUDE.md` §2).
