import Testing
@testable import SlateFeatures

/// Test de non-conflit du registre de raccourcis (Phase 14, `docs/14_raccourcis_clavier.md` :
/// "eviter les conflits"). LE test de cette phase : deux raccourcis ACTIFS de MEME
/// portee ne peuvent jamais partager la meme combinaison touche+modificateurs. Doit
/// echouer des qu'un futur ajout introduit un doublon -- c'est une garde PREVENTIVE,
/// aucun conflit reel n'existe dans le registre a la livraison de cette phase (l'exercice
/// de recensement, phases 5 a 13, n'en a fait remonter aucun).
///
/// `global` et `noteActions` sont en plus verifies ENSEMBLE (au-dela de la portee
/// stricte demandee) : les deux sont "toujours actifs" (barre de menu), donc tout aussi
/// susceptibles de se percuter reellement l'un l'autre qu'a l'interieur de leur propre
/// portee.
@Suite("KeyboardShortcutRegistry")
struct KeyboardShortcutRegistryTests {
    private struct Combo: Hashable {
        let key: String
        let modifiers: Set<SlateShortcutModifier>
    }

    @Test("Aucun conflit entre raccourcis actifs de meme portee")
    func noConflictWithinScope() {
        for scope in SlateShortcutScope.allCases {
            let entries = SlateShortcutRegistry.all.filter { $0.isActive && $0.scope == scope }
            assertNoDuplicateCombo(in: entries, context: scope.rawValue)
        }
    }

    @Test("Aucun conflit entre les portees toujours actives (global + actions de note)")
    func noConflictBetweenAlwaysOnScopes() {
        let entries = SlateShortcutRegistry.all.filter {
            $0.isActive && ($0.scope == .global || $0.scope == .noteActions)
        }
        assertNoDuplicateCombo(in: entries, context: "global+noteActions")
    }

    private func assertNoDuplicateCombo(in entries: [SlateShortcutSpec], context: String) {
        var seen: [Combo: SlateShortcutSpec] = [:]
        for entry in entries {
            let combo = Combo(key: entry.key, modifiers: entry.modifiers)
            if let existing = seen[combo] {
                Issue.record(
                    "Conflit dans \(context) : \(existing.id) et \(entry.id) partagent la meme combinaison"
                )
            }
            seen[combo] = entry
        }
    }
}
