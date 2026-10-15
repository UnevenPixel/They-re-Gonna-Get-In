# TrainingScripts

Training buildings: unit queueing, per-type and army-wide unit limits, spawning, and the ambient queue progress bar. Every `oTrainingBuildingParent` instance gets its training fields (`trainsUnit`/`unitsPerBuilding`/`trainCost`/`trainTime`/`trainQueue`/`trainProgress`) from `BuildingApplyDefinition` (`BuildingDefinitions.gml`), the same way resource buildings get their production fields.

## Two independent caps

Per the design spec, every new unit is gated by:

1. **Per-type cap**: `unitsPerBuilding` summed across every LIVE training building of that team that trains this unit type (`TrainingTypeLimit`). Destroying a training building lowers this cap immediately but never removes existing units -- the intentional "limit break": units already trained stay alive, but nothing new can be queued for that type until either more training buildings go up, or losses bring the count back under the (now lower) cap.
2. **Army-wide cap**: `global.armyLimit[team]`, regardless of unit type.

Both caps count existing units (LIVE + STATIONED -- see `CountTeamStationedUnits`/`CountTeamStationedUnitsOfType`, `StationScripts.gml`) plus everything currently queued ACROSS EVERY training building the team owns (not just the one being clicked) -- "the queue + existing friendly units + other friendly queues cannot exceed either limit," per the design spec. Station status never lets a team exceed either cap -- converting a live unit to stationed moves it between buckets, it doesn't shrink the army for cap purposes. (This was a correction from an earlier version where stationed units weren't counted at all, letting a team quietly train past its caps.)

`TrainingTryQueueUnit` checks, in order: (1) per-type cap, (2) army-wide cap, (3) affordability of `trainCost`. Deducts cost and increments the queue only if every check passes. Every rejection is logged via `show_debug_message` and simply leaves the queue unchanged -- same convention as `BlueprintController.EndDrag`'s rejection paths, no popup yet.

## TrainingSpawnUnit

Creates one instance just outside the building, assigns it to the building's team (overriding `oUnitParent`'s Create-time hardcoded TEAM.PLAYER default -- same override pattern `BlueprintController.EndDrag` uses for buildings), then sends it into "defend", patrolling the training building -- per the design, units built from training buildings default to defend, pointed at the building that trained them.

Two post-override re-derivations are needed because `oUnitParent`'s Create already ran (inside `instance_create_layer`, synchronously) using the stale default team:
- `guardRect` is recomputed for the correct team -- in practice harmless either way (`Guard_Enter`'s wasted waypoint pick is immediately discarded and `Guard_Exit` cleans up `guardWaypointClaimed` the moment `ChangeState("defend")` runs below), but the stale value would otherwise linger on the instance for whenever it later returns to "guard." A minimal, self-contained fix rather than changing `oUnitParent`'s Create to accept a team parameter, which would touch every unit spawn path.
- `UnitApplyDefinition` is re-run -- it now bakes in the unit's team's current `unitHealthBonus`/`unitDamageBonus` (stationed passives), and the stale Create-time call would have read the WRONG team's bonuses. `DeployStationedUnit` (`StationScripts.gml`) already did this; `TrainingSpawnUnit` didn't need to before this bonus system existed, since every other stat `UnitApplyDefinition` sets is team-independent.

Awards `STRATEGIC_XP_FIRST_DEPLOYMENT` the first time a team ever spawns a given unit type, tracked via `global.unitsDeployed[team]` (`oMatchControl/Create_0.gml`) -- "First deployment of unit type" from the "XP Age Progression System" doc. Every subsequent spawn of that type is a no-op here.

If `_building.inside` is true (set from the plot it was placed on, see `TryPlaceBlueprint`, `BlueprintScripts.gml`), skips all of the above entirely and instead calls `StationSpawnDirectly` (`StationScripts.gml`), per "any training buildings that builds a unit when on an inside plot will immediately build a stationed unit instead." Deliberately does NOT award `STRATEGIC_XP_FIRST_DEPLOYMENT` for that path -- see `StationSpawnDirectly`'s doc comment (a judgment call, not an explicit spec answer).

**2026-08-13: calls `global.tutorialGuide.NotifyUnitTrained(_building.team, _building.trainsUnit)` on BOTH branches** (right after each's existing `AnalyticsRecordUnitTrained` call -- the only other per-spawn hook already shared by both paths), for the guided tutorial's Peasant Ward phase ("train 2 peasants from it"). No-ops unless the tutorial actually has an active restriction waiting on that team+unit type -- see `TutorialGuideScripts.md`'s "Player action restriction" section. This is a TEAM-WIDE completion count, not tied to a specific building instance -- deliberate, since nothing else in this file tracks per-instance completions to hook into either (see that doc for the full reasoning).

## TrainingUpdateQueue

Time-based, match-speed-scaled progress. Unlike `BuildingUpdateProduction`'s rate-based accumulator (units/sec), this is duration-based (`trainTime` seconds per unit), so it uses a `while` loop instead of a single `floor()` -- at high match speeds a single frame's delta can cross more than one `trainTime`, and every whole completion in that frame should still spawn its unit, not just one per frame.

`trainProgress` resets to 0 once the queue empties -- leftover partial progress is NOT banked for a future queued unit added later. A deliberate simplification; flag if partial progress should persist across an empty gap.

Sets `image_index` -- frame 1 while actively training (`trainQueue > 0`), frame 0 otherwise. A placeholder ambient "something's happening here" signal ahead of a real animation; every training sprite gets pointed at frame 1 regardless of whether it's actually been authored with one yet -- GameMaker's default instance drawing wraps `image_index` via `mod(image_index, image_number)`, so this is a no-op glitch-wise on any sprite without a second frame ("won't harm anything"). Set BEFORE the no-op early return so idle buildings still correctly revert to frame 0.

No-op (for progress purposes) if nothing is queued, or if `trainTime` isn't configured (`<= 0` would otherwise loop forever). Progress accrues faster by the team's current `trainingSpeedBonus` (Knight's stationed passive), same "team's current stationed bonuses" pattern `BuildingUpdateProduction` uses for resource rate.

## Ambient queue progress bar

A 1px-tall bar just below every training building's bbox, always drawn (not hover-gated) so there's a signal even when no hover card is showing. Drawn from a Draw GUI event (`DrawTrainingQueueBars`) rather than each building's own room-space Draw so it renders above every room-space Draw call -- units, particles, other buildings -- regardless of instance depth ("make sure it draws to the UI layer... stays over units, particles, and other buildings").

Black background, filled left-to-right in `HOVER_CARD_TEXT_COLOR` by `trainProgress / trainTime` -- same fill/background convention as the hover card's queue row (`BuildingHoverScripts.gml`), just always-on instead of hover-gated.

TEAM.PLAYER only -- "enemy buildings do not show training queues or progress." This is an explicit exception to `BuildingHoverController`'s general "informational, not ownership-gated" precedent, not a change to that precedent itself.

Only X needs the room->GUI conversion to track camera pan/zoom correctly; Y is converted once (left/right share the same world Y) and the bar is then drawn exactly 1 GUI px tall directly in screen space -- converting two world Y's and taking their difference could render thicker/thinner than 1px if the camera's ever zoomed relative to the GUI (not currently true per `UpdateCameraPan`'s "no vertical panning" comment, but this stays correct either way).

## API

- `STRATEGIC_XP_FIRST_DEPLOYMENT`.
- `CountTeamUnitsOfType(_team, _unitType)` -- deliberately narrower than `GatherTeamUnits` (filters in the `with` loop instead of allocating a full array).
- `TrainingTypeLimit(_team, _unitType)`, `TrainingQueuedCountForType(_team, _unitType)`, `TrainingQueuedCountAll(_team)`.
- `TrainingTryQueueUnit(_building)`.
- `TrainingGetSpawnPoint(_building)`, `TrainingSpawnUnit(_building)`.
- `TrainingUpdateQueue(_building)`.
- `TRAINING_QUEUE_BAR_GAP_Y`, `DrawTrainingQueueBars()`.
