# Design complet — correspondance page ↔ phase

Ce dossier contient **tout le design restant** de Slate, livré par Claude Design en un seul batch.
Plus aucune phase n'a besoin d'un nouveau passage par Claude Design : pour chaque phase 🎨, la maquette est ici.

| Page (fichier `.dc.html`) | Phase(s) concernée(s) |
|---|---|
| `Slate E1-E3.dc.html` | 3 (coquille + sidebar), 4 (liste) — déjà intégrées |
| `Slate E4 - Éditeur.dc.html` | 5 (éditeur) — déjà intégrée |
| `Slate P1 - Formatage & blocs.dc.html` | **7** (typographie & formatage), **8** (blocs spéciaux), **10** (colonnes / drag & drop) |
| `Slate P2 - Médias & pièces jointes.dc.html` | **9** (médias & pièces jointes) |
| `Slate P3 - Organisation & sécurité.dc.html` | **11** (organisation), **12** (verrouillage) |
| `Slate P4 - Réglages & apparence.dc.html` | **13** (thèmes & apparence) |
| `Slate P5 - Bases de données.dc.html` | **17** (bases de données) |
| `Slate P6 - Assistant IA.dc.html` | **18** (fonctionnalités IA) |
| `Slate P7 - Workspaces.dc.html` | **19** (espaces de travail) |
| `Slate P8 - États système.dc.html` | transverse (états vides, chargement, sync, erreur) |
| `Slate P9 - iOS & iPad.dc.html` | **20** (portage iOS) |

Le dossier `SlateUI/` contient les composants SwiftUI de référence produits par Claude Design (dont `BlockViews.swift`, `BlockTokens.swift` pour la phase 8). Le dossier `_ds/` contient le design system exporté (tokens CSS).

**Pour l'intégrateur (`design-integrator`)** : à chaque phase, lire la page correspondante ci-dessus, s'appuyer sur `SlateUI/` et sur `design/tokens.md`. Ne plus demander de design à Cyril.
