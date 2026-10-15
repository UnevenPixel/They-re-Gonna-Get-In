# oMatchControl

Owns match-scoped global state -- initialized once per match at Create, ticked at Step.

## Create_0

Sets up every per-match global:

- `global.matchSpeed = 1` -- global (not instance-scoped) since other systems (currently `BuildingUpdateProduction`) also need to scale by it. A direct multiplier (2 = 2x speed), not an index into a preset table.
- `global.resources[team]` -- per-team resource struct (wood/wheat/water/iron/gold/meat/bones/coal/weapons/coins/xp/fateTokens). Built via a loop assigning a FRESH struct literal per team, deliberately NOT `array_create(2, {...})` -- that form evaluates the struct literal once and stores the SAME reference in both array slots, so both teams would silently share one resource pool. `xp`/`fateTokens` (added 2026-07-04) live in this same per-team struct so `Cost`/`CanAfford`/`Purchase` (`Economy.gml`) keep working generically, even though xp isn't spent the way the other resources are -- `GainXP` consumes it automatically as it fills each age's bar.
- `global.blueprints = [[], []]` -- array of `BlueprintStack` per team. Written as two separate literal `[]`, NOT `array_create(2, [])`, for the same shared-reference reason as `global.resources`.
- `global.age = [1, 1]` -- current age per team (1-4, see `AGE_MAX`, `ProgressionScripts.gml`). A plain 2-slot array is safe here (not the `array_create` hazard) since both start at the same flat number, not a shared object reference. Age/blueprint-tier-acquisition odds aren't designed yet (2026-07-04) -- this only tracks the number; nothing reads it to affect blueprint odds yet.
- `global.ageUpReady = [false, false]` -- per-team "age bar is full, waiting on a manual Age Up" flag (see `TryAgeUp`, `ProgressionScripts.gml`). 2026-07-06: age no longer advances the instant XP fills -- `GainXP` raises this, `TryAgeUp` (not yet wired to any UI) is what actually spends resources and advances.
- `global.unitsDeployed = [[], []]` -- per-team set of unit types ever deployed (`TrainingSpawnUnit`), for "First deployment of unit type" Strategic XP (2026-07-06 doc). Same `[[], []]` shared-reference avoidance as `global.blueprints`.
- `global.armyLimit = [6, 6]` -- per-team cap on total live + queued units, regardless of type or station status (see `TrainingTryQueueUnit`). Plain 2-slot array is safe here for the same reason as `global.age`.

**Starting resources** (per econ clarification, 2026-07-03): every side starts each match with 100 wood/water/iron/gold/wheat, applied symmetrically to both teams since the AI opponent needs the same economy as the player to actually build/train (see `AI_TryPlaceBlueprints`/`AI_TryTrainComposition`, `AIControl.gml`). Everything else (meat/bones/coal/weapons/coins) stays at 0 -- coins isn't part of the starting loadout. Wheat Field's cost was corrected 2026-07-05 to 20 water + 10 wood, so it's fully affordable from this starting loadout same as every other tier-1 building.

**Starting blueprints** (FINALIZED 2026-08-13, supersedes the old test-data note below): both sides now start with exactly 4 blueprint types -- Water Pump, Sawmill, Wheat Field, Peasant Ward ("peasant hut"). Every other blueprint (including Gold Mine/Iron Mine, and every training building besides Peasant Ward) is earned through the Fate Engine instead of being handed out at match start. Symmetric between player and opponent, same loop as before.

**Flag: doesn't match the earlier 2026-07-05 planning note.** That note anticipated the final starting set being Water Pump/Sawmill/Gold Mine/Iron Mine + Wheat Field (all 4 tier-1 resource buildings, no training building at all) -- the actual instruction received this pass explicitly drops Gold Mine/Iron Mine and ADDS Peasant Ward instead. Implemented exactly as newly instructed; flagging the discrepancy from the older plan in case Gold Mine/Iron Mine's omission was an oversight rather than a deliberate change of plan.

~~**Old test data** (2026-07-05 request, now replaced): one of every registered building blueprint per side, for playtesting.~~

- `global.tutorialGuide = new TutorialGuide()` (2026-08-13) -- Booger's guided-tutorial HUD presence, created unconditionally (same as everything else in this event) so `BlueprintScripts.gml`'s `TryPlaceBlueprint` can always safely read it. `StartIntroScript()` only actually fires while `global.tutorialActive` -- see `TutorialGuideScripts.md`.

Finally calls `AnalyticsInit()` to reset this match's local playtest-analytics counters.

## Step_0

Calls `AnalyticsUpdateMatchTime()` -- real (wall-clock, unscaled by `matchSpeed`) elapsed-time tracking for this match.
