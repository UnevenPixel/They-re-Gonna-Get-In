# UnitStateCombatRanged

FSM state "combatRanged" -- ranged counterpart to "combat" (`UnitStateCombat.gml`). Entered via `UnitEnterCombat` (`UnitCombatHelpers.gml`) instead of "combat" for units tagged "ranged" -- same dispatch the "attack" order uses to pick "attack" vs "attackRanged" (`OrderWiring.gml`).

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

Deliberately a structural duplicate of `Combat_Enter`/`Combat_Step`/`Combat_Exit` rather than a branch inside them -- same reasoning as `UnitStateAttackRanged.gml` (see its `.md`): this codebase already hit a bug from sharing one state's functions across multiple orders, so each gets its own dedicated functions even at the cost of near-identical files. The only behavioral difference from "combat" is at the attack trigger: `UnitTryFireProjectile` spawns a projectile instead of `UnitTryDealDamage` applying damage on the spot.

Reuses the `COMBAT_PHASE_PURSUE`/`ATTACK`/`RECOVER` macros from `UnitStateCombat.gml` -- GML macros are global regardless of which file defines them, nothing to redeclare here.

## API

- `CombatRanged_Enter(_unit, _machine)`, `CombatRanged_Step(_unit, _machine)`, `CombatRanged_Exit(_unit, _machine)` -- same shape as their `Combat_*` counterparts.
