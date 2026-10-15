# UnitStateAttackRanged

FSM state "attackRanged" -- ranged counterpart to "attack" (`UnitStateAttackMelee.gml`). Dispatched into instead of "attack" for units tagged "ranged" -- see the "attack" order's `onIssue` (`OrderWiring.gml`).

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## Why a near-total duplicate of UnitStateAttackMelee

Deliberately a near-total structural duplicate of `Attack_Enter`/`Attack_Step`/`Attack_Exit` rather than a branch inside them: this codebase already hit (and fixed) a bug from sharing one state's functions across multiple orders (see `PATCH_NOTES.md`, "attack and Siege orders were silently dead code" -- both were wired to combat's functions instead of their own). Each order gets its own dedicated state functions here for the same reason, even though it means the two files read almost identically.

The ONLY behavioral difference is at the swing trigger: `UnitTryFireProjectile` spawns a projectile (fire-and-forget, damage resolves later when it lands) instead of `UnitTryDealDamage` applying damage on the spot.

Reuses `ATTACK_PHASE_APPROACH`/`SWING`/`RECOVER`/`DEFENDER`, `ATTACK_BUILDING_HALF`, and `NearestBuildingEdgePoint` from `UnitStateAttackMelee.gml` -- GML macros and functions are global regardless of which file defines them, nothing to redeclare here.

## API

- `AttackRanged_Enter(_unit, _machine)`, `AttackRanged_Step(_unit, _machine)`, `AttackRanged_Exit(_unit, _machine)` -- same shape as their `Attack_*` counterparts, see `UnitStateAttackMelee.md`.
