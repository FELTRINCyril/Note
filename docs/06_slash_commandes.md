# Phase 6 — Menu de commandes `/`

## Objectif
Taper `/` dans un bloc vide (ou en cours) ouvre un menu de commandes pour insérer/convertir en n'importe quel type de bloc, façon Notion.

## Prérequis
Phase 5 (éditeur fonctionnel).

## 🎨 Design
Léger. Réutiliser les tokens `SlateUI`. Un design optionnel du popover peut être demandé si Cyril le souhaite, sinon rendu par défaut (liste filtrable avec icône + nom + description + raccourci).

---

## Spécifications fonctionnelles
- `/` ouvre un **popover** ancré au caret.
- Filtrage en temps réel pendant qu'on tape après le `/` (fuzzy match sur nom + alias).
- Navigation clavier : ↑/↓ pour parcourir, Entrée pour valider, Échap pour fermer.
- Catégories : **Basique** (paragraphe, titres H1–H6, listes, tâche, citation, divider), **Média** (image, fichier), **Avancé** (code, callout, tableau, colonnes), et plus tard (v2) : lien de page, vue base de données, IA.
- Sélectionner une commande **convertit le bloc courant** (s'il est vide) ou **insère un nouveau bloc**.
- Chaque commande : icône, libellé, description courte, alias de recherche.

## Détails techniques
- `SlashMenuController` `@Observable` dans `SlateEditor` : détecte le `/`, gère la requête de filtre, expose les résultats.
- Registre de commandes `SlashCommand { id, title, aliases, icon, category, action }` — extensible (les phases suivantes y ajouteront leurs blocs).
- Le déclenchement s'intègre au `RichTextBlockView` (détection de la frappe `/` en début ou après espace).

## Sous-agents
- `editor-specialist` : détection `/`, popover, filtrage, exécution des commandes.
- `swift-reviewer` : tests du filtrage fuzzy, de la conversion vs insertion, navigation clavier.

## Critères d'acceptation
- `/` ouvre le menu, le filtrage marche, ↑/↓/Entrée/Échap marchent.
- Chaque type de bloc existant est insérable via `/`.
- Le registre est facilement extensible pour les phases suivantes.

## Vérification
Tests du registre + filtrage, essai manuel de chaque commande. Cocher Phase 6.
