# Patch Notes

## v0.0.2.8 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Base-building economy loop: drag-to-place buildings, resource production, unit training with dual caps, edge-pan camera, local playtest analytics, and a Steamworks SDK integration scaffold. Also carries the fixes from the 2026-07-01 code review, which were made same-day but hadn't been written up yet.

### Added

- **Blueprint system** (`scripts/BlueprintScripts.gml`). `BlueprintStack`/`AddBlueprint`/`RemoveBlueprintOne` manage a per-team placeable-building inventory (`global.blueprints`, initialized `[[], []]` in `oMatchControl/Create_0.gml` — deliberately not `array_create(2, [])`, same shared-reference hazard `global.resources` had, see Fixed below). `BlueprintController` is the drag-to-place UI: a paginated 5x2 GUI-space grid, wired into `oUnitControl` (`Create_0`/`Step_0`/`Draw_64`) alongside `selectionController`/`orderMenu`. Dragging a filled slot onto an owned, unblocked `oBuildingPlot` checks affordability, purchases the cost, spawns the building, and consumes one blueprint.
- **`BuildingDefinition` system** (`scripts/BuildingDefinitions.gml`) — static per-building-type data (name, description, cost, sprite, optional resource production, optional unit training), registered per object type via `RegisterAllBuildingDefinitions()` (called from `oGameControl`'s Create, alongside `RegisterAllUnitDefinitions()`). Mirrors `UnitDefinition`'s registry pattern. `BuildingApplyDefinition(_building)` applies production/training fields onto an instance at Create time.
- **Resource production** — `oResourceBuildingParent` (new parent) and `oWheatField` (first resource building). `BuildingUpdateProduction()` is a frame-rate-independent, match-speed-scaled tick using a fractional accumulator (so partial progress isn't lost or double-counted across frames), ticked from `oResourceBuildingParent/Step_0.gml`. Calls the existing `PlayResourceProducedEffect` stub once per whole unit produced.
- **Unit training** — `oTrainingBuildingParent` (new parent) and `oPeasantWard` (first training building). `scripts/TrainingScripts.gml` enforces two independent caps before queueing a unit: a per-type cap (`TrainingTypeLimit` — sum of `unitsPerBuilding` across a team's live training buildings of that type) and an army-wide cap (`global.armyLimit`, `[6, 6]` starting value). Both caps count existing units *and* everything queued across every training building the team owns. Clicking an owned training building (`oUnitControl/Step_0.gml`, via `instance_position`) calls `TrainingTryQueueUnit`; `TrainingUpdateQueue` (ticked from `oTrainingBuildingParent/Step_0.gml`) is duration-based (not rate-based) and spawns via `TrainingSpawnUnit`, which overrides the spawned unit's team (same pattern `BlueprintController.EndDrag` uses for buildings) and re-derives `guardRect` for the correct team before sending the unit into `"defend"`, patrolling the building that trained it.
- **`UpdateCameraPan()`** (`scripts/CameraScripts.gml`) — edge-of-screen camera panning on view camera 0, ramping linearly with cursor proximity to the screen edge, clamped to room bounds. Called once per Step from `oUnitControl`.
- **Local playtest analytics** (`scripts/AnalyticsScripts.gml`) — per-team (`global.analytics[TEAM.PLAYER/ENEMY]`) counters for units trained, buildings built, resource produced/spent, and match time, reset each match via `AnalyticsInit()` (`oMatchControl`'s Create). Wired into `TrainingSpawnUnit`, `BlueprintController.EndDrag`, `BuildingUpdateProduction`, `Purchase` (`Economy.gml`), and `oMatchControl/Step_0.gml`. Steam Stats API calls (`steam_set_stat_int`) are written but left commented out — the stat names don't exist on the Steamworks control panel yet. `AnalyticsRecordKill`/`AnalyticsRecordDeath` exist but aren't wired to anything yet — there's still no "unit died" event.
- **Steamworks SDK extension** (`extensions/Steamworks/`, `scripts/Steamworks_Definitions.gml`) integrated. `global.isGameRestarting` flag added (`oGameControl`'s Create) — needs to be set `true` immediately before any future `game_restart()` call so `steam_shutdown()` is correctly skipped on restart, then reset to `false` right after.
- A generic GameMaker UI widget starter kit (`obj_gm_button`, `obj_gm_text`, `obj_gm_textbox` + matching sprites/fonts) was imported alongside the Steamworks asset package. Not yet wired into any room or gameplay object — sitting unused for now.
- Starting resources for `TEAM.PLAYER`: 50 wood/water/iron/gold/wheat (`oMatchControl/Create_0.gml`). A few Wheat Field and Peasant Ward blueprints are granted as test data so the new flows are testable end-to-end before a real blueprint-acquisition system exists.
- Windows build version bumped to `0.0.2.8`.

### Fixed (made 2026-07-01, written up now)

- **`global.resources` array-sharing bug.** `oMatchControl/Create_0.gml` now builds `global.resources` via `array_create(2, undefined)` followed by a loop assigning a fresh struct literal per team, instead of `array_create(2, {...})`, which evaluated the struct literal once and gave both teams the same reference.
- **Attack/Combat/Siege sprite-state self-rebinding bug.** `sprite_index`/`image_index`/`image_speed` writes in `UnitStateAttackMelee.gml`, `UnitStateCombat.gml`, `UnitStateSiege.gml`, and `UnitCombatHelpers.gml` now go through `_unit.` explicitly instead of bare variables, so they land on the real unit instance instead of the scratch `State` struct.
- **`oBuildingPlot`'s `team` Object Property** changed from String (default `"player"`) to Integer (default `0` / `TEAM.PLAYER`), matching how `team` is used as the `TEAM` enum everywhere else.
- Typo fix in the pre-alpha disclaimer text (`oAlphaDisclaimer`): "encoutner" → "encounter".

### Known issues (new or still open)

- `objects/oUnitParent/Draw_0.gml` still has `if mask_index = sM_UnitMask{` (`=` instead of `==`) — legal GML, functionally fine, still not normalized after being flagged twice now.
- The Wheat Field's placement cost (15 wood + 10 coins) can't actually be paid yet — coins isn't part of the starting loadout and there's no acquisition/trading system to earn it. The Peasant Ward is unaffected and fully testable.
- The new `obj_gm_button`/`obj_gm_text`/`obj_gm_textbox` widget kit is imported but unused.
- `AnalyticsRecordKill`/`AnalyticsRecordDeath` have no death event to call them from yet (same root cause as `UnitTryDealDamage`'s open damage-calc TODO).
- **This entire entry describes uncommitted working-tree changes** — nothing above has been committed to git yet (last commit: `5012d06`). Recommend committing before doing anything that could touch the working tree.

## v0.0.2.0 — 2026-07-01

Base-building foundations: unit type data, castle building plots (both sides), and team-symmetric guard zones.

### Added

- **`UnitDefinition` system** (`scripts/UnitDefinitions`). Static per-unit-type data — name, description, `Cost`, combat stats, sprite library, tags, `availableOrders`, and a placeholder `passives` array — registered per object type (keyed by `object_index`, e.g. `oPeasantUnit`) rather than a string name, so it ties directly to `instance_create_layer` for later stationed-unit redeploy. `UnitApplyDefinition(_unit)` applies a unit's registered definition onto the instance at Create time; `oPeasantUnit`'s Create event is now just `event_inherited()` since sprites/orders come from its definition instead of being hardcoded twice. Peasant is the first (and only) unit type defined — its cost and stats are placeholders, not balanced.
- **`UnitDataBlock.unitType`** — the struct meant to survive a station/redeploy swap (damage taken, status effects) now also remembers which `UnitDefinition` to reapply. `UnitCurrentHealth(_unit)` derives current health from `maxHealth - unitData.damageTaken` rather than storing it separately, so nothing can drift out of sync across that swap.
- **`UnitHasTag(_unit, _tag)`** — first search-script helper built on `UnitDefinition.tags`.
- **Outer building plots.** 12 plots per side (8 "near" the castle wall in two groups of 4, 4 "far" into the battlefield in two groups of 2, aligned on a single shared column) outside each castle, mirrored player/enemy via `room_width - x` (same axis `oCastleManager` mirrors the castles on). New `scripts/PlotScripts` (`SpawnBuildingPlot`) and `oOuterPlotSpawner`. Classification reuses `oBuildingPlot`'s existing `inside`/`far` fields — no new schema needed. Resource buildings get a placement bonus outside the castle, unit-training buildings get theirs inside, and *far* plots get a bonus on top of that regardless of building type, since they're the most exposed to attack.
- **`GetTeamGuardRect(_team)`** (`UnitScripts.gml`). The default guard patrol zone a unit gets at Create time is now derived per-team instead of being one hardcoded rectangle. Player's zone is authored directly; every other team's is the same rectangle mirrored across `room_width`, so it sits the same distance in front of its own castle.

### Fixed

- **`oPlotSpawner`'s inside-castle plot grid never set which team owned a plot.** Only the player's grid existed, and even it wasn't team-tagged. Rewrote it to spawn both the player's grid and a mirrored enemy grid, both correctly tagged via `SpawnBuildingPlot` — the enemy castle had zero inside plots before this.
- **Guard zone was shared, unmirrored, across both teams.** Every unit — player or enemy — got the literal same `ShapeRect(328,8,480,400)`, which sits in front of the *player's* castle only. Now routed through `GetTeamGuardRect`.
- Outer plot placement went through two iterations this session: shifted clear of the default guard zone (was overlapping it), spread further from the play area's vertical center, and the "far" plots collapsed onto one shared column instead of two.

### Known issues (unchanged from v0.0.1.0, still open)

- `"station"` order is registered but intentionally a no-op — castle-interior stationing isn't designed yet.
- `UnitDefinition.passives` is inert data with no execution hook — no passive-ability system exists yet.
- `defend`/`attack` order target validators now take an issuing team, but nothing except the player's `SelectionController` calls them yet — the AI still bypasses targeting entirely.

### Build

- Windows export version bumped to `0.0.2.0` (patch notes requested — per the versioning convention, 3rd digit bumps here, 4th digit bumps on routine small changes).

## v0.0.1.0 — 2026-07-01

Early development pass: documentation cleanup, several load-bearing bug fixes, and the first version of the computer opponent.

### Fixed

- **Order menu wouldn't open after selecting units.** `oUnitControl`'s Step event was checking for a menu-opening right-click *after* processing the menu's own Update() in the wrong order, so a click that opened the menu was immediately re-read as a "dismiss" click in the same frame. Reordered so the menu's Update() always sees the state of the mouse from the *start* of the frame.
- **Attack and Siege orders were silently dead code.** Both were wired to the "combat" state's Enter/Step/Exit functions in `oUnitParent`'s state machine setup instead of their own dedicated functions. Units issued "attack" or "siege" were actually just running combat logic. Fixed the state machine wiring so each order runs its own state.
- **Guard waypoint anti-overlap logic was a no-op.** A leftover line in `GuardPickWaypoint` (`scripts/UnitStateGuard`) short-circuited the loop that checks for waypoints already claimed by another guarding ally, so units could pile onto the same spot. Removed the offending line; the claim-check now actually runs.
- **Economy typo:** `Puchase` → `Purchase` in `scripts/Economy`.
- **Defend/Attack target validation was hardcoded to the player's perspective.** The target-eligibility checks for the "Defend Building" and "Attack Building" orders assumed `TEAM.PLAYER` was always "my side." Reworked so the validator receives the issuing side's own team and compares against that instead — same code now works correctly no matter which side (player or AI) issues the order.

### Added

- **First pass at a computer-controlled opponent** (`oAIControl` / `AIBrain`). Runs a decision cycle roughly every 3/4 second; currently masses idle guarding units and sends them to siege the enemy castle once it has enough. Built on the same order-dispatch path (`IssueOrderToUnits`) the player uses, so player and AI units behave identically once an order is issued. This is a scaffold — defending, expanding, and building/unit purchasing are not implemented yet, but the plumbing (perception → decision → dispatch) is proven end to end.
- **`GatherTeamUnits`** — room-wide "every unit on team X" query for AI/high-level decision-making, written so a future fog-of-war visibility filter (once building placement ships) only needs to be added in one place.
- **`_FindNearestEnemy`** — plain nearest-enemy-unit lookup used by the aggro-interrupt check in the Attack state.

### Changed

- **Unified team representation onto the `TEAM` enum.** Team was previously represented two ways — the raw strings `"player"`/`"enemy"` in some places, and the `TEAM.PLAYER`/`TEAM.ENEMY` enum (needed for indexing `global.resources`, since GML arrays can't take string keys) in others. Everything now uses the enum consistently (`oUnitParent`, `oBuildingParent`, `oUnitControl`, `GetEnemyCastle`).
- **Full Feather/JSDoc documentation pass** across every non-vendor Script Asset (140 functions across 16 files). Every function now has `@function`, `@param`, and `@returns` tags so Feather reliably shows hover info while writing code against these libraries. Vendored Scribble library files were left untouched.

### Known issues (flagged, not yet addressed)

- The `"station"` order appears in units' `availableOrders` but is never registered in `RegisterAllOrders()` — picking it currently does nothing.
- A second, unused `UnitOrders` enum (GUARD/DEFEND/ATTACK/SIEGE/STATION) exists alongside the raw order-name strings actually used everywhere — a similar duplication to the team-representation issue that was just resolved, but not yet raised for a decision.

### Build

- Windows export version set to `0.0.1.0` to reflect actual development stage (was defaulted to `1.0.0.0`). Going forward: bump the 4th number for routine small changes; bump the 3rd number when patch notes are requested.
