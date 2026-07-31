# Phase 16 — Liens internes & sous-pages

## Objectif (v2)
Mentionner des pages existantes et créer des sous-pages à la volée, façon Notion (`@` ou `[[`).

## Prérequis
Phases 2, 5, 6.

## 🎨 Design
Léger. Popover de recherche de page (réutilise le style du menu `/`).

---

## Spécifications fonctionnelles
- Taper `@` (ou `[[`) ouvre un **sélecteur de page** : recherche parmi les notes existantes.
- Sélectionner insère un **lien de page** (`pageLink`) cliquable qui navigue vers la note.
- Option **« Créer la page "X" »** si aucun résultat → crée une sous-page et insère le lien.
- **Sous-pages** : une note peut contenir un bloc `pageLink` vers une note enfant (hiérarchie de pages en plus des dossiers).
- **Backlinks** : afficher « mentionnée dans… » sur la page cible (optionnel mais précieux).

## Détails techniques
- Type de bloc `pageLink` (déjà prévu Phase 2) référençant l'`id` d'une `Note`.
- `PageLinkController` : recherche, insertion, création à la volée, résolution du titre (mise à jour si la cible est renommée).
- Backlinks : requête inverse sur les `pageLink` pointant vers la note courante.
- Gérer la suppression de la cible (lien orphelin → état « page supprimée »).

## Sous-agents
- `editor-specialist` : déclencheur `@`, popover, insertion.
- `data-modeler` : relation pageLink, backlinks, gestion des orphelins.
- `swift-reviewer` : navigation, création à la volée, renommage propagé, orphelins.

## Critères d'acceptation
- `@` trouve et insère un lien vers une page ; clic navigue.
- Création d'une nouvelle page à la volée fonctionne.
- Backlinks affichés ; renommage propagé ; orphelins gérés.

## Vérification
Tests des liens + navigation + backlinks. Cocher Phase 16.
