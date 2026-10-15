# AnalyticsScripts

Playtest analytics -- LOCAL COLLECTION ONLY for now. Every `AnalyticsRecord*` function updates the in-memory `global.analytics` struct immediately. The actual Steam Stats API calls that would upload each number are written out but commented out, since none of these stat names exist yet on the Steamworks control panel -- see each function below for the exact API name it expects. Those need to be created there (as Integer stats, matching `steam_set_stat_int`'s type) before uncommenting anything.

**Scope**: tracked per-team (`global.analytics[TEAM.PLAYER]`/`[TEAM.ENEMY]`), mirroring `global.resources`/`global.blueprints`/`global.armyLimit`. Only `TEAM.PLAYER`'s numbers are ever meaningful to actually send to Steam -- there's no Steam account for the AI side -- so every commented Steam call is gated behind `if (_team == TEAM.PLAYER)`, even though the local struct keeps both teams' numbers (useful for internal balance analysis regardless of what ever reaches Steam).

**Lifetime vs. per-match**: Steam stats are LIFETIME/persistent per Steam account by design (see `steam_set_stat_int`'s own manual example: read the existing value, add the delta, set it back -- `steam_set_stat_int("Total_XP", steam_get_stat_int("Total_XP") + 100)`). The local `global.analytics` struct, by contrast, resets every match (`AnalyticsInit` runs once from `oMatchControl`'s Create). That mismatch is intentional: locally you get this match's numbers; the (currently commented) Steam call accumulates the all-time total the same way the manual's own example does.

**Lethality gap**: kills/deaths per unit type is the one metric that ISN'T wired to anything yet -- see `AnalyticsRecordKill`/`AnalyticsRecordDeath` below for why, and flag back whether "lethality" should end up meaning raw kills, a kills/deaths ratio, or something damage-based once real combat resolution exists to compute it from.

## AnalyticsInit

Resets all local playtest analytics for a new match. Call once from `oMatchControl`'s Create event, alongside `global.resources`/`global.blueprints`/`global.armyLimit`.

`resourceProduced`/`resourceSpent` include `xp`/`fateTokens` alongside the 10 base resources -- added 2026-07-06 after `GainXP` (`ProgressionScripts.gml`) started calling `AnalyticsRecordResourceProduced(_team, "xp", ...)`/`(_team, "fateTokens", ...)`, but neither key existed on this struct yet, so `struct_get` returned undefined and `undefined + _amt` crashed the instant any XP was ever actually awarded (first repro: `TrainingSpawnUnit`'s first-deployment Strategic XP). Added to `resourceSpent` too for symmetry -- nothing spends xp/fateTokens as a `Cost` today, but `Cost`/`ResourceCost` already support both as a resource type, so this heads off the identical crash the moment something does.

## AnalyticsStatName

Builds a Steam-API-friendly stat name from an object type, e.g. `("units_trained", oPeasantUnit)` -> `"units_trained_peasantunit"`. Strips the leading "o" from the object name (this codebase's object-naming convention, per CLAUDE.md) so stat names read cleanly on the Steamworks dashboard.

## AnalyticsMapIncrement

Shared `ds_map` "increment or initialize to 1" helper, used by every count-based Record function below.

## Record functions

- `AnalyticsRecordUnitTrained(_team, _unitType)`: wired from `TrainingSpawnUnit` (`TrainingScripts.gml`) -- fires once per unit that actually finishes training, not once per queue slot filled. Steam stat: `"units_trained_<type>"`.
- `AnalyticsRecordKill(_team, _unitType)` / `AnalyticsRecordDeath(_team, _unitType)`: **NOT WIRED ANYWHERE YET** -- there's no "unit died" event in the codebase to call these from. `UnitTryDealDamage`'s actual damage calculation is still an unimplemented TODO (`UnitCombatHelpers.gml`), so nothing currently determines when a unit dies, let alone who killed it. These exist so "lethality" has somewhere to record to the moment real damage/death logic exists -- call both from wherever a unit's HP finally reaches 0. Deliberately not inventing death detection here; combat/damage resolution is out of scope for this task and flagged separately. Steam stats: `"kills_<type>"`/`"deaths_<type>"`.
- `AnalyticsRecordBuildingBuilt(_team, _buildingType)`: wired from `BlueprintController.EndDrag` (`BlueprintScripts.gml`) -- fires once per building actually placed on a plot, not once per blueprint granted. Steam stat: `"buildings_built_<type>"`.
- `AnalyticsRecordResourceProduced(_team, _resource, _amt)`: wired from `BuildingUpdateProduction` (`BuildingDefinitions.gml`). Steam stat: `"resource_produced_<resource>"`.
- `AnalyticsRecordResourceSpent(_team, _resource, _amt)`: wired from `Purchase` (`Economy.gml`) -- the single choke point every cost (building placement, unit training) already flows through, so this covers every spend automatically without touching each call site individually. Steam stat: `"resource_spent_<resource>"`.

## AnalyticsUpdateMatchTime

Accumulates real (wall-clock) elapsed seconds for the current match -- deliberately NOT scaled by `global.matchSpeed`, since "time spent in a match" is about actual playtest session length, not simulated game time, and deliberately keeps counting through a matchSpeed-0 pause for the same reason. Call once per Step (`oMatchControl/Step_0.gml`). Steam stat: `"match_time_seconds"` (LIFETIME total across every match played -- read-add-set, same idiom as every other Record function, NOT a per-match overwrite).

Deliberately does NOT call `steam_set_stat_int` every Step even once uncommented -- that's an enormous number of API calls over a play session for one slowly-growing number. Batch it instead: call the commented block periodically (e.g. once every N seconds via its own timer, or once at whatever "match over" ends up being) rather than every frame.

## API

- `AnalyticsInit()`.
- `AnalyticsStatName(_prefix, _objectIndex)`, `AnalyticsMapIncrement(_map, _key)`.
- `AnalyticsRecordUnitTrained(_team, _unitType)`, `AnalyticsRecordKill(_team, _unitType)`, `AnalyticsRecordDeath(_team, _unitType)`, `AnalyticsRecordBuildingBuilt(_team, _buildingType)`, `AnalyticsRecordResourceProduced(_team, _resource, _amt)`, `AnalyticsRecordResourceSpent(_team, _resource, _amt)`.
- `AnalyticsUpdateMatchTime()`.
