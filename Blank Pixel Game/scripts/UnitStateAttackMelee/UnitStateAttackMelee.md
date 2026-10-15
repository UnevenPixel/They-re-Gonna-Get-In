# UnitStateAttackMelee

FSM state "attack" -- melee assault on `attackBuildingTarget`, cycling through APPROACH -> SWING -> RECOVER, with a DEFENDER sub-phase that interrupts to fight off a nearby enemy unit before resuming the building.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## NearestBuildingEdgePoint -- critical bugfix, read before touching

Returns the nearest point on the building's bounding box edge to `_fromPos`, so the unit targets the building's surface rather than its center (which would put the attack trigger point 24px inside the building).

**Bugfix** (fixed a "soldiers in the center of the wheat field" report): a plain `clamp()` of `_fromPos` to the box only produces a point ON the edge when `_fromPos` starts OUTSIDE the box -- if `_fromPos` is already INSIDE (both axes within range), `clamp()` is a no-op and just hands back `_fromPos` itself, i.e. "the nearest edge point" degenerates into wherever the unit already happens to be standing, dead center included. That's reachable in practice because buildings were dropped from units' hard collision list (`move_and_collide` only checks `oEnvironmentSolid` now) -- `Steering_AvoidObstacles` is a soft lookahead force, not a wall, so a unit converging on a small building alongside allies (separation pressure) or approaching at a sharp angle can clip past the corner the feeler missed and end up inside. Once inside, `Attack_Step`/`AttackRanged_Step` read `_distToEdge` as ~0 and the unit just locks in place right there instead of continuing out to the real surface.

The fix explicitly detects the inside case and pushes back out to whichever side has the least penetration depth -- same "always a real point on the actual perimeter, never the interior" guarantee `CastleFrontEdgePoint` (`CastleScripts.gml`) already gives for the castle (which sidesteps this entirely by always returning a fixed edge-line X rather than blending toward `_fromPos`). Since this function is called fresh every step, a unit already stuck inside from before this fix self-corrects the very next frame -- `UnitPursueTarget` just steers it out to the newly-correct edge point (buildings still don't hard-block movement, so nothing stops it walking back out).

**Do not revert to a plain `clamp()`** -- that's exactly the regression this fixed.

## Attack_Step phase structure

DEFENDER phase is checked first, every step, highest priority. If a defender was engaged, the unit keeps fighting it until it's gone or retreats out of `attackLeashRange`, then falls back to the building via APPROACH (not SWING, so distance/cooldown get rechecked cleanly). Pursues and attacks the defender using the same three-sub-phase logic as the combat state, but driven from inside attack's DEFENDER phase rather than a separate FSM state, so the building target is preserved throughout.

Aggro check runs every frame outside DEFENDER phase, but only interrupts APPROACH or RECOVER, never mid-SWING -- a swing already in progress always completes first.

APPROACH seeks the nearest edge point (not center) so the attack range triggers at the building's surface. SWING deals damage via `UnitTryDealDamage` each frame until the anim completes. RECOVER hugs the building edge during cooldown so the unit is already in position when it expires.

The `oBuildingParent` exclusion from `move_and_collide` (referenced throughout) is the same project-wide change described in `UnitCombatHelpers.md`.

## API

- `ATTACK_BUILDING_HALF`, `ATTACK_PHASE_APPROACH/SWING/RECOVER/DEFENDER` -- also reused by `UnitStateAttackRanged.gml` (GML macros are global regardless of which file defines them).
- `NearestBuildingEdgePoint(_building, _fromPos)` -- also reused by `UnitStateAttackRanged.gml`.
- `Attack_Enter(_unit, _machine)`, `Attack_Step(_unit, _machine)`, `Attack_Exit(_unit, _machine)`.
