# CastleScripts

Gives `oPlayerCastle`/`oEnemyCastle` real HP, tracked the same way as every other damageable thing (`maxHealth` + `damageTaken`, via `GetDamageTaken`/`SetDamageTaken`/`GetCurrentHealth`, `UnitDefinitions.gml`, and `ApplyDamage`, `UnitCombatHelpers.gml`), plus a rolling "no damage taken" timer that awards Defensive XP per the "XP Age Progression System" doc ("No castle damage for 120 secs: +5 XP"). Neither castle object had ANY events before this system existed (both were pure visual masks, invisible, no Create/Step) -- this was genuinely new infrastructure, not a small wiring tweak.

**Note on targetability**: siege already calls `UnitTryDealDamage` directly on the castle instance (`UnitStateSiege.gml`, SWING phase) via `GetEnemyCastle()`, bypassing the generic "attack" order's `oBuildingParent`-ancestry gate entirely -- so castles not being parented to `oBuildingParent` never mattered for siege specifically, only for the player-issued generic "attack Building" order, which genuinely can't target a castle. (An earlier version of this doc incorrectly called castles fully untargeted -- corrected.)

`CastleFrontEdgePoint` is what siege approaches instead of the generic `NearestBuildingEdgePoint` (`UnitStateAttackMelee.gml`) -- that function assumes every building is 48x48, which castles aren't anywhere close to (350x411).

## CastleInit / CastleStep

`CastleInit(_instance, _team)`: call once from a castle's Create event. Sets up the same `maxHealth`/`damageTaken` shape every other damageable thing uses, plus `noDamageTimer` (steps at 1x match speed since the last hit or spawn, generically reset to 0 by `ApplyDamage` on any hit).

`CastleStep(_instance)`: call once per Step. Advances `noDamageTimer` and awards `CASTLE_NO_DAMAGE_XP_AMOUNT` Defensive XP for every full `CASTLE_NO_DAMAGE_XP_STEPS` interval reached without interruption -- floor-division against the running timer (same "don't lose progress, handle more than one interval in a single jump" approach `GainXP`'s Fate Token math uses), so a big `matchSpeed` step crossing more than one interval at once can't under- or over-award. Does NOT reset after awarding -- rolls forward and keeps paying out every subsequent interval for as long as the castle goes untouched, only ever reset to 0 by taking damage.

## CastleFrontEdgePoint

The nearest point on the castle's FRONT edge to a given position -- "front" meaning whichever vertical edge of the castle's actual collision box (`bbox_left`/`bbox_right`, already world-space and sprite-mask-accurate, unlike `NearestBuildingEdgePoint`'s hardcoded building-size assumption) sits closer to the room's horizontal center (`room_width / 2`). Deliberately layout-agnostic -- doesn't assume "player is on the left" or read `_castle.team` at all, just picks whichever side actually faces the middle of the room, so it keeps working even if castle placement ever changes.

The X coordinate returned is always exactly that edge (never clamped/blended toward the approach position -- the front is a single vertical line, not an area); the Y coordinate is the approach position's Y clamped to `[bbox_top, bbox_bottom]`, so a unit approaching from any height along the wall gets a point directly across from it rather than being funneled to one fixed spot -- per the 2026-07-06 request "allowing attacks to happen anywhere along its front edge." Used by `Siege_Step` (`UnitStateSiege.gml`) in place of `NearestBuildingEdgePoint`.

## CastleDefendWaypoints

Patrol waypoints along the castle's front wall, for a unit assigned to defend the castle itself rather than an ordinary `oBuildingParent` -- added 2026-07-06 for AI castle-under-siege defense (`AI_CastleDefense_Step`, `AIControl.gml`). `DefendBuildingWaypoints` (`UnitStateDefend.gml`) hardcodes a 4-corner box sized off `DEFEND_BUILDING_HALF` (24, i.e. a 48x48 building) -- completely wrong for a 350x411 castle, the same size-mismatch reason `CastleFrontEdgePoint` exists instead of `NearestBuildingEdgePoint` for siege targeting.

Reuses the same "front wall" concept as `CastleFrontEdgePoint` (whichever bbox edge faces the room's horizontal center) but spreads `CASTLE_DEFEND_WAYPOINT_COUNT` points evenly down the full height instead of a single point, so multiple defenders patrol the whole wall rather than stacking on one spot. Offset outward from the wall by `DEFEND_PATROL_MARGIN` (`UnitStateDefend.gml`) -- the same margin ordinary building defense uses, referenced directly rather than duplicated.

## API

- `CASTLE_MAX_HEALTH`, `CASTLE_NO_DAMAGE_XP_STEPS`, `CASTLE_NO_DAMAGE_XP_AMOUNT`.
- `CastleInit(_instance, _team)`, `CastleStep(_instance)`.
- `CastleFrontEdgePoint(_castle, _fromPos)`.
- `CASTLE_DEFEND_WAYPOINT_COUNT`, `CastleDefendWaypoints(_castle)`.
