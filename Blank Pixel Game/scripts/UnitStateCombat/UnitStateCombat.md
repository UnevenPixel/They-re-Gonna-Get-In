# UnitStateCombat

FSM state "combat" -- the melee fight state a unit enters from "guard" or "defend" when it needs to fight (see `UnitEnterCombat`, `UnitCombatHelpers.gml`). Cycles PURSUE -> ATTACK -> RECOVER against `_unit.combatTarget`.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## Combat_Step

If `combatTarget` no longer exists, picks a fresh one via `ChooseCombatTarget()`; if none is found, reverts to whichever of guard/defend it was interrupted from (`UnitRevertFromCombat`, `UnitCombatHelpers.gml`). Also reverts if the target leashes out of `attackLeashRange`. "combat" is only ever entered from guard/defend (`UnitEnterCombat`), so there's always a previous state to go back to.

## API

- `COMBAT_PHASE_PURSUE/ATTACK/RECOVER` -- also reused by `UnitStateCombatRanged.gml`.
- `Combat_Enter(_unit, _machine)`, `Combat_Step(_unit, _machine)`, `Combat_Exit(_unit, _machine)`.
