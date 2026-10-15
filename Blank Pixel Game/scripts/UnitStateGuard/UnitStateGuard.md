# UnitStateGuard

FSM state "guard" -- a unit's default idle behavior: wander between random waypoints inside `guardRect` (its team's patrol zone, see `GetTeamGuardRect`, `UnitScripts.gml`), waiting a random dwell time at each, while watching for nearby enemies to fight.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## Waypoint claiming

`GuardPickWaypoint(_unit, _rect)` picks a random point inside `_rect` that isn't already claimed by another waiting ally, retrying up to `GUARD_PICK_RETRIES` times and keeping the best (furthest-from-any-claim) candidate found even if every retry hits a conflict. Claimed positions are read from nearby units' `guardWaypointClaimed` field, which every guard unit writes to itself when it picks a waypoint and clears on `Guard_Exit`.

Two defensive checks in the claim-gathering loop:
- Room-start instance-creation-order hazard: all room-placed instances exist before any of their Create events run, so a sibling found via `collision_rectangle_list` may not have reached `team = TEAM.PLAYER/ENEMY` in its own Create yet. Skipped rather than crashing.
- `guardWaypointClaimed` can legitimately be `undefined` between a unit's own Create running and `Guard_Enter` assigning it a real `Vector2` -- skipped via `is_struct()` rather than trusting the value blindly.

## Guard_Step

Proximity aggro (`ChooseCombatTarget` within `attackAggroRadius`) is checked first, every step, highest priority -- "combat" is an interim state guard pops into when it needs to fight (see `UnitEnterCombat`, `UnitCombatHelpers.gml`). The OTHER combat trigger, reactive-on-hit, lives in `ApplyDamage` instead, since it needs to fire the instant damage lands, not once per step.

While waiting at a waypoint: `waitTimer` decrements by `global.matchSpeed`, so it's 0 at matchSpeed 0 -- the wait freezes instead of ticking down during a pause. `UnitIdleInPlace` (not a true freeze) still applies knockback and collision so the unit isn't frozen solid if hit while waiting.

On arrival at a waypoint (within `GUARD_ARRIVE_THRESHOLD`): residual velocity is zeroed so the unit doesn't keep nudging back and forth around the waypoint during the wait.

The `oBuildingParent` exclusion from the `move_and_collide` list is the same project-wide change described in `UnitCombatHelpers.md` (`UnitPursueTarget`) -- units only hard-collide with `oEnvironmentSolid`; `Steering_AvoidObstacles` still steers around buildings cosmetically.

## API

- `GUARD_ARRIVE_RADIUS`, `GUARD_ARRIVE_THRESHOLD`, `GUARD_WAIT_MIN/MAX`, `GUARD_EDGE_PADDING`, `GUARD_MIN_SEPARATION`, `GUARD_PICK_RETRIES`.
- `GuardPickWaypoint(_unit, _rect)`.
- `Guard_Enter(_unit, _machine)`, `Guard_Step(_unit, _machine)`, `Guard_Draw(_unit, _machine)` (currently empty -- no debug visualization implemented yet), `Guard_Exit(_unit, _machine)` (releases the waypoint claim).
