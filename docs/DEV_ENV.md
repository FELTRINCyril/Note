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

## Contrainte CloudKit à ne jamais oublier (vaut pour la phase 2)

Tout modèle SwiftData synchronisé via CloudKit doit avoir **toutes ses propriétés avec une
valeur par défaut ou optionnelles**, et **toutes ses relations optionnelles**. Les gros
binaires (images, fichiers joints) passent par `externalStorage` / CKAsset, jamais en base.
Une propriété non optionnelle sans valeur par défaut fait échouer le chargement du store,
pas la compilation : l'erreur n'apparaît qu'au lancement.
