# Phase 12 — Verrouillage de note

## Objectif
Verrouiller une note façon Notes d'Apple : contenu masqué tant qu'on ne s'authentifie pas (Touch ID / Face ID, avec repli mot de passe).

## Prérequis
Phase 2 (`isLocked`), Phase 5.

## 🎨 Design
Léger. Demander (optionnel) : l'écran « note verrouillée » (icône cadenas + bouton déverrouiller) et la boîte de dialogue de définition du mot de passe.

---

## Spécifications fonctionnelles
- **Verrouiller / déverrouiller** une note (`isLocked`).
- Une note verrouillée affiche un **écran de verrou** au lieu du contenu (titre visible ou masqué selon réglage).
- Déverrouillage via **LocalAuthentication** : Touch ID / Face ID, repli sur mot de passe de l'app.
- Définition d'un **mot de passe de verrouillage** (au niveau app/workspace, comme Notes), stocké de façon sûre.
- Re-verrouillage automatique : à la fermeture de la note, après inactivité, ou au verrouillage de l'app.
- Indicateur 🔒 dans la liste (Phase 4) et la sidebar.

## Détails techniques ⚠️ sécurité
- `LockService` dans `SlateServices` utilisant **LocalAuthentication** (`LAContext`).
- Secret/mot de passe stocké dans le **Keychain** (jamais en clair, jamais dans SwiftData/CloudKit).
- Envisager le **chiffrement du contenu** des notes verrouillées (au minimum, ne pas exposer le texte via recherche/aperçu quand verrouillé). Option avancée : chiffrer les blocs avec une clé dérivée (CryptoKit) — à discuter avec Cyril selon le niveau de sécurité voulu.
- La recherche (Phase 4) doit **exclure** le contenu des notes verrouillées.

## Sous-agents
- `swift-reviewer` (sécurité) : revue attentive du stockage Keychain, de l'exclusion de recherche, du re-verrouillage.
- `swiftui-builder` : écran de verrou, dialogues.
- `SlateServices` : `LockService`, intégration LocalAuthentication/CryptoKit.

## Critères d'acceptation
- Verrouiller masque le contenu ; déverrouiller via biométrie/mot de passe le révèle.
- Le mot de passe est dans le Keychain, pas en clair.
- Aperçus et recherche n'exposent pas les notes verrouillées.
- Re-verrouillage automatique fonctionne.

## Vérification
Revue de sécurité dédiée + tests du cycle verrou/déverrou + vérif exclusion recherche. Cocher Phase 12.
