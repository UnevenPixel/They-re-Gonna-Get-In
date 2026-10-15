# StationScripts

Stationing: turning a live unit into an invisible, no-fsm garrison entry stored at its team's castle, and creating one directly (skipping the live/walk-to-castle step) for training buildings placed on an inside plot. See `UnitStateStation.gml` for the "station" order's walk-to-castle FSM state that calls `UnitBecomeStationed` on arrival.

## Counting

`CountTeamStationedUnits(_team)` -- total live `oUnitStationed` belonging to `_team`, any type. Stationed units count against `global.armyLimit` (`TrainingScripts.gml`) -- a correction from an earlier version where they didn't, meaning a team could station units to quietly train PAST its intended army-wide cap (stationing never freed real capacity, it just wasn't being counted). Shared by `TrainingTryQueueUnit`'s army-wide check (so player and AI are bound by the same math) and `AIControl.gml`'s `AI_TeamAtArmyLimit`/`AI_CurrentStationedCount` -- one source of truth instead of duplicating the same `with` loop in two files.

`CountTeamStationedUnitsOfType(_team, _unitType)` -- the stationed counterpart to `CountTeamUnitsOfType` (`TrainingScripts.gml`), which only sees LIVE instances of `_unitType` and can't see a stationed one (a completely different object, `oUnitStationed`, with its original type preserved only inside `unitData`). Used by `TrainingTryQueueUnit`'s per-type cap check alongside `AI_WouldTrainSucceed`'s matching dry-run, so a stationed Peasant counts against "how many Peasants can this team ever have," not just a live one.

## UnitBecomeStationed / StationSpawnDirectly

`UnitBecomeStationed(_unit)` creates an `oUnitStationed` at the team's castle corner (`StationCastleCorner` -- an arbitrary fixed point, since `oUnitStationed` has no sprite and never renders; only matters as a stable spawn point for a future redeploy), hands it `_unit`'s existing `UnitDataBlock` as-is, then destroys `_unit` directly. Destroying directly (not through `ApplyDamage`) is deliberate -- `STRATEGIC_XP_LOSE_UNIT` is only awarded from `ApplyDamage`, and `oUnitParent` has no Destroy event, so this can't misfire a "lost a unit" penalty for what is actually a successful station. Falls back to `_unit`'s current position if the team somehow has no castle (shouldn't normally happen -- `Station_Enter` already falls back to "guard" when that's true).

`StationSpawnDirectly(_team, _unitType)` builds a stationed unit for `_team` without ever putting a live unit on the battlefield -- used by `TrainingSpawnUnit` (`TrainingScripts.gml`) when a training building sits on an inside plot ("any training buildings that builds a unit when on an inside plot will immediately build a stationed unit instead"). Spawns a real instance just to get a correctly `UnitApplyDefinition`-stamped `UnitDataBlock`, then immediately hands it to `UnitBecomeStationed`, which destroys it the same step before it ever runs a Step or Draw event -- nothing is ever visible on the battlefield. Deliberately does NOT award `STRATEGIC_XP_FIRST_DEPLOYMENT` (`TrainingScripts.gml`) -- that XP is for a unit's first appearance ON the battlefield, which a directly-stationed unit never has. A judgment call, not an explicit spec answer.

## Station/deploy economy

`UnitDefinition.stationCost` (a flat gold amount from the "Project Azurite Data Sheets") already existed as display-only data for the unit hover card; `GetUnitStationCost` is what makes it actually spend, priced identically both directions ("Gold cost to station/deploy this unit type").

`StationDeploySpawnPoint(_castle)` -- point just outside the castle's FRONT edge (same side `CastleFrontEdgePoint`, `CastleScripts.gml`, picks) with small random vertical jitter so back-to-back deploys don't land stacked (mirrors `TrainingGetSpawnPoint`'s spacing reasoning). Re-derives the front side itself rather than calling `CastleFrontEdgePoint` -- that function clamps toward a caller position (there's no unit marching toward the castle here, just a spawn point needed just outside it), and doesn't expose which side it picked for the "push further outward" math to reuse.

`DeployStationedUnit(_team, _unitType)` -- the castle garrison dropdown's click-to-deploy action (`CastleGarrisonMenu.gml`). Charges `GetUnitStationCost` via `Purchase` BEFORE anything else happens, so an unaffordable deploy is a pure no-op. Picks whichever live `oUnitStationed` instance of this type is found first if more than one is garrisoned -- GameMaker's `with` iteration order isn't a meaningful "oldest"/"healthiest" pick, just "any one of them"; a request that cares WHICH specific one would need a different selection rule. Creates a fresh instance just outside the castle, overrides its team, swaps in the stationed unit's preserved `UnitDataBlock`, and re-runs `UnitApplyDefinition` -- the exact redeploy sequence `UnitDataBlock`'s doc comment (`UnitScripts.gml`) specifies. Defaults to "guard" (the fsm's own built-in starting state) since a deployed unit has no training-building context to default to "defend" against like `TrainingSpawnUnit`'s units do -- a judgment call, not an explicit spec answer. `_unitType == undefined` is a safe no-op, letting `CastleGarrisonMenu`'s "--" placeholder row / an outside click pass straight through without a separate guard at the call site.

## Passive stationed bonuses

Every registered unit's "Stationed Effect" passive (`UnitDefinitions.gml`) was flavor-text-only before this; `UnitDefinition.stationedBonuses` is the real, structured counterpart, and `GetStationedPassiveBonuses` is what every consumer (production rate, training speed, unit HP/damage at spawn) actually calls. Archer's "Ranged attacks from the wall" is deliberately NOT represented -- see `stationedBonuses`' own doc comment (`UnitDefinitions.gml`) for why (a real combat mechanic, not a multiplier -- out of scope for now).

**Scope note**: HP/damage bonuses (`unitHealthBonus`/`unitDamageBonus`) are applied ONCE, at a unit's spawn/redeploy moment (`UnitApplyDefinition`), NOT dynamically re-applied to every already-live unit the instant a new Mud Golem/Soldier gets stationed, and not removed retroactively if that unit is later deployed back out. Doing this fully dynamically would mean tracking each unit's BASE stats separately from its EFFECTIVE stats and recomputing every live unit's HP/damage on every station/deploy change -- a real systemic change to how combat health is tracked, not folded in silently here. This keeps the simpler "current team bonus baked in at spawn time" behavior, same spirit as `stationCost`'s own incremental rollout.

`StationedBonuses()` field names are exactly `"<type>Bonus"` for each `stationedBonuses` type string -- `GetStationedPassiveBonuses` writes to them via dynamic struct access, so a new type string needs a matching field added here too. `counts` (object name -> live-stationed count) is for the castle hover panel/debugging, not itself a bonus field.

`GetStationedPassiveBonuses` is recomputed fresh every call, not cached -- same "simplicity over micro-optimization" convention as `TrainingTypeLimit` (`TrainingScripts.gml`); called at most once per producing/training building per Step and once per unit spawn, a small enough `oUnitStationed` count at this game's scale not to need a cached/dirty-flag layer.

## API

- `CountTeamStationedUnits(_team)`, `CountTeamStationedUnitsOfType(_team, _unitType)`.
- `StationCastleCorner(_castle)`.
- `UnitBecomeStationed(_unit)`, `StationSpawnDirectly(_team, _unitType)`.
- `STATION_DEPLOY_SPAWN_MARGIN`, `GetUnitStationCost(_unitType)`, `StationDeploySpawnPoint(_castle)`, `DeployStationedUnit(_team, _unitType)`.
- `StationedBonuses()`, `GetStationedPassiveBonuses(_team)`.

## Castle roam (2026-10-14)

`CastleRoamPathPoint`, `CastleRoamInit`, `CastleRoamStep`, `CastleRoamDraw` + `CASTLE_ROAM_*` macros drive the cosmetic stationed-unit crowd. Full rationale in `oUnitStationed.md`.
