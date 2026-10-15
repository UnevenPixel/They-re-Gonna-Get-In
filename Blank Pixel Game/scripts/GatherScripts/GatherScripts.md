# GatherScripts

Spatial query helpers: nearby obstacles/allies for steering, castle lookups, room-wide team queries, and weighted combat target selection (`ChooseCombatTarget`).

## GatherNearbyObstacles

Gathers nearby buildings and environment solids into the `{ pos, radius }` shape `Steering_AvoidObstacles` expects. Buildings of the unit's OWN team are excluded (a unit shouldn't treat its own castle/barracks as an obstacle); environment solids have no team and are always included.

`UNIT_OBSTACLE_LOOK_RADIUS` was widened from 96 -- that left barely any margin beyond `Steering_AvoidObstacles`' own feeler length (up to 80, more for a longer siege-march feeler, see `UnitPursueTarget`), so obstacles were only ever spotted right at the tip of the feeler with almost no room to steer around them smoothly. Widening this doesn't change avoidance LOGIC, just how early an obstacle is seen -- part of the fix for siege units getting caught on buildings en route to the castle.

## Castle lookups

`GetEnemyCastle(_unit)` returns the OPPOSING team's castle for a given unit. `GetTeamCastle(_team)` is the inverse -- takes a TEAM directly and returns that same team's own castle, added for AI castle-defense threat detection (`AI_CastleUnderThreat`, `AIControl.gml`), which needs to check proximity to a team's own castle rather than the enemy's.

## Room-wide queries

`GatherTeamUnits(_team)` -- every `oUnitParent` instance belonging to `_team`, anywhere in the room. No fog-of-war filtering yet -- the only currently-hidden area is inside castle walls, and nothing spawns there yet, so every unit is visible to everyone. Centralizing "what can team X see" here (rather than scattering ad-hoc queries at every call site) means that when fog of war extends past castle walls in the future, a visibility filter only needs to be added in these functions.

## Superseded functions (kept, not deleted)

`_FindNearestEnemyInSweep` and `_FindNearestEnemy` are SUPERSEDED -- no longer called anywhere, replaced by `ChooseCombatTarget` below (which folds `_FindNearestEnemyInSweep`'s castle-weighting in as an optional axis via `_castlePos`, and replaces every call site `_FindNearestEnemy` fed: `Guard_Step`, `Defend_Step`, `Attack_Step`, `AttackRanged_Step`). Left in place rather than deleted -- flag before removing outright, in case something still wants a plain/castle-weighted nearest-enemy lookup with no other criteria.

## ChooseCombatTarget

Replaces the old "always returns noone" stub that used to live in `UnitScripts.gml` (moved here to sit next to the two functions it supersedes). Unifies every previous unweighted "just grab the nearest enemy" pick into one real, tunable decision.

Called wherever combat/attack/siege need to pick which enemy UNIT to fight: entering "combat"/"combatRanged" and re-acquiring when the current target dies (`Combat_Step`/`CombatRanged_Step`), the defender-interrupt in "attack"/"attackRanged" (`Attack_Step`/`AttackRanged_Step`), the aggro trigger in "guard"/"defend" (`Guard_Step`/`Defend_Step`), and the guard-sweep in "siege" (`Siege_Step`). NOT used for picking what BUILDING or CASTLE to attack -- that's still player-order-driven (`attackBuildingTarget`) or `GetEnemyCastle()`, untouched.

Scores every candidate on four weighted criteria (health remaining, attack damage, proximity, current activity via `_CombatTargetActivityScore`), plus an optional 5th (closeness to a castle being sieged) when `_castlePos` is passed -- only `Siege_Step` should ever pass that. Weights (`COMBAT_TARGET_WEIGHT_*`) are explicit placeholders -- tune freely, nothing else depends on the specific numbers. Health/proximity/castle axes are normalized 0..1 before weighting; `attackDamage` is NOT normalized (its raw value is multiplied by its weight directly) -- fine for a first-pass placeholder since every candidate is compared on the same combined scale, but flag if every axis should be normalized to 0..1 for easier tuning later.

`_CombatTargetActivityScore` scores what a candidate is currently doing: sieging our castle scores highest (1.0, the biggest threat), attacking one of our buildings next (0.7), already fighting one of our units next (0.3), idle (guard/defend) scores 0.

Returns `noone` if no enemy unit is in range -- same contract the old stub and `_FindNearestEnemy` both had, so every caller's existing `if (_unit.combatTarget == noone)` check keeps working unchanged.

## API

- `UNIT_OBSTACLE_LOOK_RADIUS`, `GatherNearbyObstacles(_unit, _radius)`, `GatherNearbyAllies(_unit, _radius)`.
- `GetEnemyCastle(_unit)`, `GetTeamCastle(_team)`.
- `GatherTeamUnits(_team)`.
- `_FindNearestEnemyInSweep(_unit, _castlePos, _radius)`, `_FindNearestEnemy(_unit, _radius)` -- superseded, see above.
- `COMBAT_TARGET_WEIGHT_HEALTH/ATTACK/PROXIMITY/ACTIVITY/CASTLE`.
- `_CombatTargetActivityScore(_candidate)`.
- `ChooseCombatTarget(_unit, _radius, _castlePos)`.
