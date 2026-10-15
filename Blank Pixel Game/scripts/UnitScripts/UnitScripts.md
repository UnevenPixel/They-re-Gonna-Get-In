# UnitScripts

Grab-bag of shared unit utilities that don't belong to any one system: per-unit scratch data, sprite/facing updates, the play area rect, team guard zones, and shared order dispatch.

`ChooseCombatTarget` used to be a stub here (always returned noone) -- it's now a real weighted implementation in `GatherScripts.gml`, next to the `_FindNearestEnemy`/`_FindNearestEnemyInSweep` functions it supersedes.

## UnitDataBlock

Per-unit scratch data that doesn't belong on the base object variables -- damage taken, active status effects, and which `UnitDefinition` this unit is (see `UnitApplyDefinition`, `UnitDefinitions.gml`). Deliberately the ONLY state a stationed unit needs to remember: when `oUnitStationed` is built, it should hold nothing but a `UnitDataBlock`, and redeploy by handing this struct to the new instance and calling `UnitApplyDefinition` again -- `unitType` is what tells it which definition to reapply.

## Sprite and facing

`UnitUpdateSprite` sets `sprite_index` (idle vs walk), `image_xscale` (facing), and `image_speed` (match-speed-scaled) from the agent's current velocity. Rules: never interrupts an in-progress attack animation's `sprite_index`, but `image_speed` still refreshes every frame even mid-swing so a pause/speed-change is honored immediately rather than only at swing start. `image_xscale` only updates above `UNIT_FACE_THRESHOLD` (higher than `UNIT_WALK_THRESHOLD`) so facing locks in during deceleration instead of flickering as the unit stops. Only flips on meaningful horizontal movement (`|velocity.x| > 0.1`) so purely-vertical movement keeps the last facing direction. Every state's Step routes through this (directly or via `UnitPursueTarget`/`UnitIdleInPlace`) every frame, including mid-swing, so it's the one place that needs to track `global.matchSpeed` for all of a unit's animation.

## Play area

`InitPlayArea` sets `global.playAreaRect` once at room start -- call with real room coordinates ("between the two castle fronts and above the UI strip"). `PLAY_AREA_CONTAIN_MARGIN`/`PLAY_AREA_CONTAIN_WEIGHT` feed `Steering_Contain` (`SteeringBehaviors.gml`) as a soft, low-weight nudge rather than a hard wall.

## Team guard zones

`GetTeamGuardRect(_team)` returns a team's default guard patrol zone (what `oUnitParent` assigns to `guardRect` at Create time). The player's zone is authored directly, just in front of the player castle; every other team's zone is derived by mirroring across `room_width` -- the same axis `oCastleManager` uses for `oPlayerCastle`/`oEnemyCastle` and `oOuterPlotSpawner` uses for its plots -- so the enemy's zone ends up the same size and distance from its own castle.

## Shared order dispatch

`IssueOrderToUnits(_orderName, _units, _context)` issues a named order to an array of unit instances. Used by BOTH the player's `SelectionController` and the AI controller, so both paths go through the same `Order.onIssue` callback. Does NOT handle targeting mode -- that's a player-UI concern owned by `SelectionController`. When the AI issues an order that would normally require a target click (e.g. "defend"), it passes the target directly as `_context`; the `onIssue` callback receives it either way.

## API

- `UnitDataBlock()`.
- `UNIT_WALK_THRESHOLD`, `UNIT_FACE_THRESHOLD`, `UnitUpdateSprite(_unit)`.

**2026-10-14 fix (facing regression from the unit speed halving, v0.0.7.1):** `UNIT_FACE_THRESHOLD` was 0.75, which only worked while unit `maxSpeed`s were 0.9-2.2. After halving, only Bomb Goblin (1.1) could exceed it, so everyone else never updated `image_xscale` (never flipped left). Retuned: `UNIT_FACE_THRESHOLD` 0.75 → 0.2 (must stay below the slowest `maxSpeed`, Mud Golem 0.3, and above `UNIT_WALK_THRESHOLD` for the anti-flicker margin), `UNIT_WALK_THRESHOLD` 0.25 → 0.125 (Mud Golem's 0.3 max was barely clearing the old value, so its walk animation would have been unreliable too), and the `abs(_vel.x)` guard 0.1 → 0.05. Any future `maxSpeed` change needs these re-checked.
- `InitPlayArea(_x1, _y1, _x2, _y2)`, `PLAY_AREA_CONTAIN_MARGIN`, `PLAY_AREA_CONTAIN_WEIGHT`.
- `GetTeamGuardRect(_team)`.
- `IssueOrderToUnits(_orderName, _units, _context)`.
