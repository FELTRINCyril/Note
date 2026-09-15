# Environnement de développement

État constaté le 31/07/2026 sur la machine de Cyril. À relire si un build échoue de façon inexplicable.

| Élément | Version |
|---|---|
| macOS | 26.5 |
| Xcode | 26.6 (build 17F113) |
| Swift (toolchain Xcode) | 6.3.3 |
| SDK macOS | 26.5 |
| Cible de déploiement du projet | macOS 15.0 |
| XcodeGen | 2.46.0 |

---

## Piège n°1 : `xcode-select` pointe sur les Command Line Tools

`xcode-select -p` renvoie `/Library/Developer/CommandLineTools`, pas Xcode. Ce toolchain
**ne fournit pas** :

- les macros SwiftData -> `@Model` échoue avec
  `External macro implementation type 'SwiftDataMacros.PersistentModelMacro' could not be found` ;
- le framework swift-testing -> `import Testing` échoue avec `No such module 'Testing'` ;
- `xcodebuild` tout court (`tool 'xcodebuild' requires Xcode`).

**Conséquence : toute commande de build ou de test doit être préfixée par `DEVELOPER_DIR`.**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Build / test d'un package isolé
cd Packages/SlateModel && swift build && swift test

# Build / test du projet Xcode
xcodebuild -project Slate.xcodeproj -scheme Slate -configuration Debug build
```

Si un `.build/` a été produit avec le mauvais toolchain, le nettoyer (`rm -rf .build`) avant
de relancer, sinon les erreurs de macro persistent.

Pour rendre le changement permanent (à faire par Cyril, demande un mot de passe admin) :

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Tant que ce n'est pas fait, `DEVELOPER_DIR` reste obligatoire. Cette contrainte vaut aussi
pour les sous-agents : elle est rappelée dans leurs consignes.

---

## SwiftLint

Installé via Homebrew (`brew install swiftlint`, version 0.65.0). Configuration à la
racine : `.swiftlint.yml`.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # obligatoire
swiftlint              # lint
swiftlint --fix        # corrections automatiques
```

`DEVELOPER_DIR` est requis ici aussi : SwiftLint charge `sourcekitd` depuis Xcode et
échoue sinon sur `Loading sourcekitdInProc.framework failed`.

SwiftLint tourne également comme phase de build de la cible `Slate` (après compilation).
Il n'échoue pas le build s'il n'est pas installé, il émet un avertissement. Deux règles
sont en **erreur** et non en avertissement, car ce sont des règles dures de `CLAUDE.md`
§5 : `force_unwrapping` et `implicitly_unwrapped_optional`.

Une règle personnalisée `ascii_punctuation` fait respecter la règle typographique du
`CLAUDE.md` global dans le code Swift : elle signale les em-dash, guillemets
typographiques, ellipse, flèches, puces unicode, signe multiplication, espace insécable
et coches. Les lettres accentuées restent autorisées, elles sont nécessaires aux chaînes
d'interface françaises.

**Note** : `ENABLE_USER_SCRIPT_SANDBOXING` est à `NO` sur la seule cible `Slate`, parce
que SwiftLint doit lire tout l'arbre de sources. Le réglage reste à `YES` au niveau du
projet.

---

## Génération du projet Xcode

`Slate.xcodeproj` n'est **pas** versionné. La source de vérité est `project.yml` (XcodeGen).

```bash
xcodegen generate      # régénère Slate.xcodeproj depuis project.yml
```

À relancer après tout ajout de package, de cible, d'entitlement ou de réglage de build.
Ne jamais modifier les réglages depuis l'interface d'Xcode : la modification serait perdue
à la prochaine génération. Tout passe par `project.yml`.

---

## Configurations de build

| Config | CloudKit | Entitlements | Signature |
|---|---|---|---|
| **Debug** | désactivé (flag `SLATE_CLOUDKIT` absent) | `App/Slate-Local.entitlements` (sandbox seul) | ad-hoc (`-`), aucun compte développeur requis |
| **Release** | activé (`SLATE_CLOUDKIT` défini) | `App/Slate.entitlements` (iCloud + CloudKit + APS) | nécessite `DEVELOPMENT_TEAM` |

Le dev quotidien se fait en Debug, donc **sans iCloud** : pas besoin de container ni de
compte payant pour lancer l'app. Pour tester la synchronisation, il faut au préalable :

1. créer le container `iCloud.com.gemaddis.slate` dans le portail Apple Developer ;
2. renseigner `DEVELOPMENT_TEAM` et passer `CODE_SIGN_STYLE` à `Automatic` dans `project.yml` ;
3. régénérer le projet et builder en Release.

---

## Piège n°2 : SwiftData et les propriétés `Codable` à conteneur unkeyed

Constaté en phase 2 en voulant stocker `RichText` (qui encapsule un `AttributedString`)
directement comme propriété `@Model`. Au premier accès, le process **meurt** sur :

```
SwiftData/ModelCoders.swift:98: Fatal error: Composite Coder only supports Keyed Container
```

C'est un `fatalError`, pas une erreur Swift récupérable : aucun `try` ne le rattrape, et
rien n'apparaît à la compilation.

Cause : le "composite coder" de SwiftData, qui sérialise les propriétés `Codable` d'un
`@Model`, ne sait descendre que dans des conteneurs **keyed**. L'encodage d'un
`AttributedString` produit en interne un conteneur **unkeyed** (un tableau de runs). Le
type de plus haut niveau peut très bien être keyed, comme l'est `RichText` : c'est le
conteneur imbriqué qui casse.

**Règle** : toute propriété `@Model` dont l'encodage `Codable` contient un conteneur
unkeyed imbriqué doit être stockée en `Data` (propriété privée) et exposée via un
accesseur calculé qui encode/décode explicitement en JSON. C'est le motif appliqué à
`Block.textData` / `Block.text`.

Un `Codable` "plat" comme `BlockAttributes` ne pose aucun problème et peut rester une
propriété `@Model` normale.

---

## Piège n°2 bis : ajouter un champ `Bool` non-optionnel à une struct `Codable` déjà en
circulation casse l'ouverture de tout store existant (et aucun test en mémoire ne le voit)

Constaté en pratique sur le store réel de Cyril, après l'ajout de `isHeaderRow` à
`BlockAttributes` (Phase 8, tableaux). L'app affichait "Impossible de démarrer Slate -
SwiftDataError erreur 1" au lancement. L'erreur réelle, masquée par ce message
générique, était :

```
NSCocoaErrorDomain 134110
Cannot migrate store in-place: Validation error missing attribute values on mandatory
destination attribute
entity=Block, attribute=isHeaderRow
```

**Cause** : `BlockAttributes` (voir piège n°2 ci-dessus, un `Codable` "plat", donc
stockée directement comme propriété `@Model` de `Block`) est **aplatie par SwiftData en
autant de colonnes Core Data distinctes que de champs de la struct** ("composite
coder") - `ZHEADINGLEVEL`, `ZISCHECKED`, `ZCOLUMNCOUNT`, etc. dans la table `ZBLOCK`, une
colonne par propriété, pas une seule colonne encodée. Un champ `Bool` non-optionnel
ajouté à une telle struct *après* la mise en circulation d'un store existant devient un
attribut Core Data obligatoire sans valeur pour toutes les lignes déjà présentes, et
fait échouer la migration légère : le `= false` de l'initialiseur Swift est une valeur
par défaut de **construction d'instance**, elle ne joue aucun rôle de valeur par défaut
d'attribut Core Data au moment de la migration.

**Piège dans le correctif lui-même** : la réponse instinctive ("stockage privé
optionnel + accesseur public non-optionnel", le motif déjà utilisé par
`Folder.colorIndex`/`colorToken` mais pour exposer un *type différent*, pas pour
masquer l'optionnalité d'un même type) **casse silencieusement la persistance**, pas
seulement la migration : le "composite coder" exige que le nom Swift du champ stocké
corresponde **exactement** au nom de cas utilisé dans `CodingKeys`/`init(from:)`/
`encode(to:)`. Renommer le stockage brut (ex. `isHeaderRowRaw`, privé) tout en gardant
la clé `CodingKeys` d'origine (`isHeaderRow`) fait qu'une valeur écrite via
`encode(to:)` n'est jamais relue par `init(from:)` après un vrai passage par le disque -
la mutation "survit" en mémoire dans le même process (ce qui masque totalement le
problème si on ne teste qu'avec des instances déjà chargées), mais se perd
silencieusement dès qu'un `ModelContext` frais relit la ligne. Aucune erreur, aucun
avertissement : juste une valeur qui redevient `false` au prochain lancement.

**Règle** : pour tout champ ajouté à une struct `Codable` stockée directement comme
propriété `@Model` (motif `BlockAttributes`) :
- s'il doit tolérer un store déjà en circulation, il **doit** être un type authentiquement
  optionnel (`String?`, `Int?`, `Double?`, `UUID?`... ou, si c'est un booléen,
  `Bool?` avec `discouraged_optional_boolean` désactivé ligne par ligne en
  connaissance de cause - un booléen non-optionnel avec valeur par défaut n'est
  sûr QUE pour un champ présent depuis la toute première version de la struct,
  jamais pour un champ ajouté après coup, voir `isChecked` vs `isHeaderRow` dans
  `BlockAttributes.swift`) ;
- **le nom de la propriété Swift, le nom du cas `CodingKeys`, et les clés utilisées
  dans `init(from:)`/`encode(to:)` doivent rester rigoureusement identiques** - ne
  jamais introduire d'indirection de type "stockage privé renommé + accesseur public".
  C'est plus strict que ce que `Codable` exige d'ordinaire (où seul le
  `CodingKeys.rawValue` compte, le nom de propriété étant libre) : ce cas précis viole
  cette liberté habituelle.

**Aucun test en mémoire (`SlateContainer.make(inMemory: true)`) ne peut jamais
attraper ce genre de régression** : un container en mémoire est toujours un store
neuf, jamais une migration. Voir `FolderExpandedStateMigrationTests`,
`FolderColorIndexMigrationTests` et `BlockAttributesHeaderRowMigrationTests`
(`Tests/SlateModelTests`) pour le motif de test qui ouvre un store réel sur disque,
construit avec l'ancienne forme du schéma, via `SlateContainer.make(storeURL:)`. Ce
motif de test doit être reproduit à chaque évolution de champ qui touche une struct
`Codable` stockée directement comme propriété `@Model`, pas seulement pour les
entités `@Model` elles-mêmes.

---

## Contrainte CloudKit à ne jamais oublier (vaut pour la phase 2)

Tout modèle SwiftData synchronisé via CloudKit doit avoir **toutes ses propriétés avec une
valeur par défaut ou optionnelles**, et **toutes ses relations optionnelles**. Les gros
binaires (images, fichiers joints) passent par `externalStorage` / CKAsset, jamais en base.
Une propriété non optionnelle sans valeur par défaut fait échouer le chargement du store,
pas la compilation : l'erreur n'apparaît qu'au lancement.
