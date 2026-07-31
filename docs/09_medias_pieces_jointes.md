# Phase 9 — Médias & pièces jointes

## Objectif
Insérer des images (avec redimensionnement) et des fichiers joints dans les notes, avec stockage compatible CloudKit.

## Prérequis
Phases 2 (Attachment), 5, 6.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- Le **bloc image** : états (vide/drop zone, chargement, affichée), poignées de redimensionnement, alignement, légende.
- Le **bloc fichier joint** : icône par type, nom, taille, bouton ouvrir/télécharger.
- La zone de **drag & drop** d'un fichier dans l'éditeur.

Déposer dans `design/09_medias/`. Dire `go`.

---

## Spécifications fonctionnelles
### Images
- Insertion via : `/`, glisser-déposer, coller (⌘V), ou bouton +.
- **Redimensionnement** par poignées + largeur mémorisée (`attributes.width`).
- Alignement (gauche/centre) optionnel, légende optionnelle.
- Formats courants (PNG, JPEG, HEIC, GIF).

### Fichiers joints
- Tout type de fichier ; affichage icône + nom + taille.
- Ouvrir dans l'app par défaut / révéler dans le Finder.

### Pièces jointes façon Notes
- Support du glisser-déposer multiple.
- Vignette pour PDF/images.

## Détails techniques ⚠️ (stockage)
- **Ne pas** stocker les gros binaires directement dans SwiftData/CloudKit.
- Images/fichiers → `externalStorage` SwiftData et/ou **CKAsset** pour la sync ; ne garder en base que métadonnées + référence.
- Compression/redimensionnement des images à l'import pour limiter le poids.
- Service `AttachmentService` dans `SlateServices` : import, compression, stockage, récupération, suppression.

## Sous-agents
- `swiftui-builder` : blocs image et fichier, poignées de redimensionnement, drop zones.
- `design-integrator` : intégration du design.
- `data-modeler`/`SlateServices` : stratégie de stockage `externalStorage`/CKAsset.
- `swift-reviewer` : import/suppression, persistance, taille mémoire, sync.

## Critères d'acceptation
- Insérer/glisser/coller une image, la redimensionner, ça persiste.
- Joindre un fichier et l'ouvrir depuis la note.
- Les binaires n'alourdissent pas la base (stockage externe/CKAsset).

## Vérification
Tests d'import + inspection du stockage + essai manuel drag & drop. Cocher Phase 9.
