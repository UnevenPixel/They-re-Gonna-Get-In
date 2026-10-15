# UnitStateDefend

FSM state "defend" -- patrols the four corners around a building (or, for a castle, along its front wall) via `defendTarget`, fighting off any enemy that wanders into aggro range.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## Waypoints

`DefendBuildingWaypoints(_building)` builds the four patrol corner waypoints around a 48x48 building. `NearestWaypointIndex` picks up the patrol from whichever corner is nearest the unit on entry, rather than always snapping to corner 0.

`defendTarget` can also be a castle (`oPlayerCastle`/`oEnemyCastle`, via `AI_CastleDefense_Step`, `AIControl.gml`) -- neither is an `oBuildingParent` descendant, so `!object_is_ancestor(..., oBuildingParent)` reliably tells the two apart without hardcoding either castle object name. A castle gets `CastleDefendWaypoints` (patrol spread along its actual front wall, `CastleScripts.gml`) instead of the 4-corner box, which assumes a 48x48 building and would be wrong for a much larger castle.

`DEFEND_PATROL_MARGIN`/`DEFEND_ARRIVE_RADIUS` were tightened together from earlier, larger values ("4 px should look better") -- the old arrive-radius was nearly as big as an entire corner-to-corner patrol leg at the new, smaller margin, which would have kept units decelerating for almost the whole loop instead of ever reaching normal patrol speed.

## Defend_Step

Proximity aggro is checked first, every step, same pattern as `Guard_Step` -- "combat" is an interim state defend pops into when it needs to fight (see `UnitEnterCombat`, `UnitCombatHelpers.gml`).

The `oBuildingParent` exclusion from `move_and_collide` is the same project-wide change as `UnitCombatHelpers.md`/`UnitStateGuard.md` describe. The building actually being defended is never in that collision list to begin with (patrol waypoints already sit outside it) -- this only affects OTHER buildings a unit might pass near while patrolling.

## Defend_Exit -- critical bugfix, do not "simplify"

`Defend_Exit` is deliberately EMPTY and must stay that way. It used to unconditionally clear `defendTarget` (`_unit.defendTarget = noone`), which broke two real cases:

1. **Reassigning an already-defending unit to a different building.** The AI (`AI_Defending_Step`/`AI_TryMaintainDefensiveSpread`/`AI_CastleDefense_Step`, all via the "defend" order's `onIssue`, `OrderWiring.gml`) sets the new `defendTarget` BEFORE calling `ChangeState("defend", true)`. Because that call re-enters the SAME state name, `ChangeState` runs the old `Defend_Exit` first -- if it cleared `defendTarget`, it would wipe the freshly-assigned new target back to `noone` before `Defend_Enter` ever read it, and `Defend_Enter` would then see `!instance_exists(noone)` and bounce straight to "guard". The unit's `defendTarget` field would look correct from the outside, but the unit itself fell back to aimless guard patrol instead of marching to the new building. This was the reported bug: units already posted to defend one building would not respond when the AI tried to redirect them to a newly-threatened one.
2. **Surviving a combat interruption.** "combat"/"combatRanged" is only ever entered FROM "guard" or "defend" (`UnitEnterCombat`) and reverts back via `RevertToPrevious` (`UnitRevertFromCombat`, `UnitCombatHelpers.gml`) once the fight ends. A defending unit that aggros into combat would exit "defend" (wiping the target, pre-fix), then later revert back to "defend" -- `Defend_Enter` would find its own target already gone and, again, silently demote the unit to "guard" instead of resuming its patrol. Every defend assignment should survive a combat interruption; this was quietly breaking that too.

Nothing reads `defendTarget` while NOT in "defend" (every reader -- `Defend_Enter`, `Defend_Step`, `AI_UncoveredBuildingsByTier` -- either runs only during "defend" or explicitly checks `fsm.Is("defend")` first), and every path that ENTERS "defend" (the order's `onIssue`, `TrainingSpawnUnit`) always sets `defendTarget` immediately beforehand -- so there's no stale-value hazard left to guard against by clearing it here. The matching half of this fix is in `OrderWiring.gml`'s "defend" `onIssue`, which now passes `_force = true`.

## API

- `DEFEND_BUILDING_HALF`, `DEFEND_PATROL_MARGIN`, `DEFEND_WAYPOINT_REACH`, `DEFEND_ARRIVE_RADIUS`.
- `DefendBuildingWaypoints(_building)`, `NearestWaypointIndex(_pos, _waypoints)`.
- `Defend_Enter(_unit, _machine)`, `Defend_Step(_unit, _machine)`, `Defend_Exit(_unit, _machine)` -- intentionally empty, see above.
