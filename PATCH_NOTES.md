# Patch Notes

## v0.0.2.14 — 2026-07-04 (uncommitted — working tree only, not yet committed)

Two new resources (XP, Fate Tokens) and a `GainXP` accumulator to drive them, plus a bug fix: three script files from the last two sessions' ranged-combat work were never actually registered with the project and would not have compiled.

### Added

- **`xp` and `fateTokens`** — two new per-team resources, added to `global.resources[_team]` (`oMatchControl/Create_0.gml`) and to `Cost`/`ResourceCost` (`Economy.gml`) alongside the existing 10, so `CanAfford`/`Purchase` pick them up for free (both already walk `global.resources` generically by field name). Both start at 0 for both teams — no starting loadout change.
- **`global.age`** (`oMatchControl/Create_0.gml`) — per-team current age, `[1, 1]` at match start. Ages and blueprint-tier-acquisition odds are explicitly NOT designed yet (per 2026-07-04 discussion) — nothing reads this to affect blueprints. It's just the counter.
- **`GainXP(_team, _amount)`** (new `ProgressionScripts.gml`) — the requested entry point for awarding XP; nothing calls it yet (XP sources aren't wired up — that's next). Adds `_amount` to the team's current age bar (`AGE_XP_REQUIRED` = 1000, flat placeholder, no per-age scaling designed):
  - Awards one Fate Token for each of the bar's 4 equal quarter-marks (`AGE_FATE_TOKEN_INTERVALS`) crossed by the gain, computed from before/after position so a large single gain still awards every token earned, not just one. Filling the bar outright nets exactly 4 tokens, with the 4th landing on the same call that ages the team up.
  - Advances `global.age[_team]` (capped at `AGE_MAX = 4`) each time the bar fills, carrying overflow into the next age's bar via a while-loop — a big enough gain can advance more than one age in one call.
  - **Judgment call, flagged for sanity-check:** once already at `AGE_MAX`, the bar stops at full instead of looping/prestiging — further XP past that point is discarded rather than granting more tokens indefinitely. Revisit once ages are actually designed.
  - Both the XP added and any Fate Tokens earned are recorded via the existing `AnalyticsRecordResourceProduced` hook, same as building production.

### Fixed

- **`ProjectileScripts.gml`, `UnitStateAttackRanged.gml`, and `UnitStateCombatRanged.gml` had no `.yy` files and were never added to `Blank Pixel Game.yyp`'s resource list.** These were created across the last two sessions' ranged-combat batches (projectile spawning/`SpawnProjectile`, the `attackRanged` state, and the `combatRanged` state) but a GameMaker script only compiles if it's a registered project resource — a loose `.gml` file on disk with no matching `.yy`/`.yyp` entry doesn't exist as far as the IDE/compiler is concerned. Net effect: `SpawnProjectile`, `AttackRanged_Enter/Step/Exit`, and `CombatRanged_Enter/Step/Exit` would have been undefined-function errors at runtime despite reading correctly in the source. Created the three missing `.yy` files and added all three to the `.yyp` (alphabetically, matching existing ordering). Worth a project reload + smoke test of an Archer fighting something, since this is the first time this code has had a chance to actually run.
- **`Blank Pixel Game.yyp` was found truncated again mid-session** (same failure mode as before — missing tail: `RoomOrderNodes` entries, `templateType`, `TextureGroups`, final `}`), discovered while validating this batch's edits. Reconstructed the same way as last time: working-tree content up to the truncation point + the stable tail from git HEAD (`RoomOrderNodes`/`templateType`/`TextureGroups` haven't changed all session), verified via JSON parse + duplicate-name check. This has now happened three times this project — may be worth checking whether something (an editor autosave, a sync tool) is racing writes to this file.

### Build

- Windows export version bumped `0.0.2.13` → `0.0.2.14` — 4th-digit bump, same convention as last time.

## v0.0.2.13 — 2026-07-03 (uncommitted — working tree only, not yet committed)

`ChooseCombatTarget` is a real weighted decision now, and every existing unweighted "just grab the nearest enemy" pick across guard/defend/attack/attackRanged/siege now routes through it.

### Added

- **`ChooseCombatTarget(_unit, _radius, _castlePos)`** (`GatherScripts.gml`, moved from the stub that used to live in `UnitScripts.gml`) — scores every enemy unit within `_radius` on four weighted criteria and returns the best one (or `noone` if nothing's in range, same contract the old stub and `_FindNearestEnemy` both had):
  - **Health remaining** (`COMBAT_TARGET_WEIGHT_HEALTH = 1.0`) — rewards low health (`damageTaken / maxHealth`), i.e. finishing off the wounded.
  - **Attack stat** (`COMBAT_TARGET_WEIGHT_ATTACK = 0.4`) — rewards high `attackDamage`, i.e. focusing the biggest threat. Raw value, not normalized -- flagged in the doc comment as a placeholder simplification.
  - **Proximity** (`COMBAT_TARGET_WEIGHT_PROXIMITY = 1.2`) — rewards closeness to the deciding unit.
  - **Activity** (`COMBAT_TARGET_WEIGHT_ACTIVITY = 1.0`, via new `_CombatTargetActivityScore`) — rewards a candidate currently attacking one of ours: sieging our castle scores highest, then attacking one of our buildings, then already fighting one of our units, then idle (guard/defend) scores 0. This is the "whether it is attacking a unit, building, or castle" criterion.
  - **Castle proximity** (`COMBAT_TARGET_WEIGHT_CASTLE = 0.8`, only when `_castlePos` is passed) — not one of the four requested criteria, added to preserve `_FindNearestEnemyInSweep`'s existing castle-proximity weighting for siege specifically, rather than silently dropping that behavior. Flagging this addition explicitly since it goes beyond what was asked for -- worth a sanity check.
  - All five weights are placeholders per instruction -- tune freely, nothing else depends on these specific numbers.
- **Every previous unweighted target pick now goes through it:** `Guard_Step`/`Defend_Step`'s aggro trigger, `Attack_Step`/`AttackRanged_Step`'s defender-interrupt, and all three guard-sweep checks in `Siege_Step` (ADVANCE/ASSAULT/RECOVER phases) were all calling `_FindNearestEnemy` or `_FindNearestEnemyInSweep` directly -- all now call `ChooseCombatTarget` instead. `Combat_Step`/`CombatRanged_Step`'s re-acquire-on-death call didn't need to change (it already called `ChooseCombatTarget(_unit)` with the stub; the real implementation's `_radius` parameter defaults to `_unit.attackAggroRadius` via the same `??=`-in-the-body idiom `UnitPursueTarget` already uses, since a parameter default can't reference an earlier parameter directly in GML).

### Known issues (new)

- **`_FindNearestEnemy`/`_FindNearestEnemyInSweep` (`GatherScripts.gml`) are now unused dead code**, left in place rather than deleted -- flagged in their own doc comments as superseded, in case something still wants a plain unweighted lookup. Candidates for removal if nothing ends up needing them.

### Build

- Windows export version bumped `0.0.2.12` → `0.0.2.13` — 4th-digit bump, same convention as last time.

## v0.0.2.12 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Buildings now use the same damage-taken setup as units, and "combat" is finally wired up the way it was originally designed: an interim state guard/defend pop into when they need to fight, then return from.

### Added

- **Building HP.** `BuildingDefinition` (`BuildingDefinitions.gml`) gained `maxHealth` (optional, defaults to 200 -- an unbalanced placeholder, same status every cost/rate number in that file already had; the data sheet has no building-HP column). `BuildingApplyDefinition` now sets `maxHealth`/`damageTaken` directly on every building instance, alongside its existing production/training fields. `oBuildingParent/Create_0.gml` also sets defensive `maxHealth = 0` / `damageTaken = 0` defaults, same "Create sets placeholders, a script function fills in the real ones right after" pattern as units/projectiles.
- **`ApplyDamage`/`GetCurrentHealth` generalized to work against buildings, not just units.** New `GetDamageTaken(_instance)`/`SetDamageTaken(_instance, _value)` (`UnitDefinitions.gml`) abstract over where damageTaken actually lives: nested at `unitData.damageTaken` for units (so it survives a station/redeploy swap) vs. a flat `damageTaken` directly on the instance for buildings (which have no station/redeploy concept to preserve it across). `UnitCurrentHealth` renamed to `GetCurrentHealth` to match -- grep confirmed exactly one caller (`ApplyDamage`) at rename time. Melee and ranged attacks against buildings now do real damage instead of silently no-opping.
- **"combat" is reachable for the first time.** It was registered in every unit's FSM since early on but nothing ever transitioned into it -- confirmed dead code as of last session. Per design, it's an interim state `guard`/`defend` pop into when they need to fight:
  - **Proximity aggro** -- `Guard_Step`/`Defend_Step` now check `_FindNearestEnemy(_unit, _unit.attackAggroRadius)` first thing every step (same mechanism `Attack_Step`'s defender-interrupt already used), and hand off to combat via new `UnitEnterCombat(_unit, _target)` (`UnitCombatHelpers.gml`) the instant something's in range.
  - **Reactive-on-hit** -- `ApplyDamage` now calls `UnitEnterCombat` the instant a non-lethal hit lands on a unit currently in `"guard"` or `"defend"`, using the attacker as the target. A unit already fighting (attack/attackRanged/siege/combat/combatRanged) is left alone -- taking a hit doesn't retarget it.
  - **`UnitEnterCombat`** picks `"combat"` or `"combatRanged"` based on the unit's `"ranged"` tag -- same dispatch the `"attack"` order already used for `"attack"` vs `"attackRanged"`.
  - **`UnitRevertFromCombat(_machine)`** replaces `Combat_Step`'s two hardcoded `ChangeState("guard")` exits (no target / target leashed) with `_machine.RevertToPrevious()` (`StateMachine.gml` -- already existed, never used until now), so a unit correctly goes back to whichever of guard/defend it was interrupted from, not always guard. Falls back to `"guard"` if `previousName` is somehow unset, so a unit can never get stuck in combat with nowhere to revert to.
  - **New `"combatRanged"` state** (`scripts/UnitStateCombatRanged.gml`) -- structural duplicate of `"combat"` (same reasoning as `"attackRanged"`/`"attack"`: this codebase already hit a bug from sharing state functions across orders), swapping `UnitTryFireProjectile` in for `UnitTryDealDamage` at the attack phase. Registered in `oUnitParent/Create_0.gml` alongside the other states.

### Known issues (new)

- **`ChooseCombatTarget` is still a stub** (always returns `noone`). When a unit's combat target dies mid-fight, it reverts to guard/defend rather than picking a new one -- if another enemy is still in aggro range, the outer proximity check (now running every Guard_Step/Defend_Step) picks it back up on the next step regardless, so this mostly self-heals, but a true "keep fighting whoever's closest" re-target was not built this session.
- **Reactive-on-hit only fires from `"guard"`/`"defend"`.** A unit mid-`"attack"`/`"siege"` that takes a hit from a THIRD party (not its current target) doesn't do anything differently -- only `"attack"`/`"attackRanged"`'s own built-in defender-interrupt (proximity-based, not damage-based) handles that case.

### Build

- Windows export version bumped `0.0.2.11` → `0.0.2.12` — 4th-digit bump, same convention as last time.

## v0.0.2.11 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Real damage/death for the first time, plus a ranged attack system (projectile spawn, spawn/arc/land, hit resolution) built on top of it. Archer is the first unit to use it.

### Fixed

- **`Blank Pixel Game.yyp` was truncated mid-write** (cut off partway through the sprite resource list, missing the closing `resources` bracket and the entire `RoomOrderNodes`/`templateType`/`TextureGroups` tail) by an external save that landed while this session was mid-edit. Reconstructed by taking the working tree's content up to the truncation point (which already had every object this session and prior sessions added) and appending the missing tail from the last commit (`54e76cd`) unchanged. Verified: parses cleanly, no duplicate resource names, every object added this session and prior sessions is still present exactly once.
- **`UnitTryDealDamage`'s "TODO: damage calculation" stub is gone.** It now calls the new `ApplyDamage` (see Added). This is the actual fix requested this session -- everything else below follows from it.

### Added

- **`ApplyDamage(_target, _amount, _source)`** (`UnitCombatHelpers.gml`) — the first real damage-application function in the codebase. Increments `unitData.damageTaken` (clamped to `maxHealth`) rather than tracking a separate "current health" value, so a future max-health buff/debuff never needs a second number rewritten in lockstep — `UnitCurrentHealth` (`UnitDefinitions.gml`, already existed) always derives the live value from the one stored number. Destroys `_target` the instant health reaches 0 — the first place anything in this codebase can actually die — and calls `AnalyticsRecordDeath`/`AnalyticsRecordKill` (`AnalyticsScripts.gml`), which existed already but had no death event to call them from until now. Buildings have no `unitData`/hp concept yet — calling `ApplyDamage` against one logs and no-ops rather than crashing; that's a separate, undesigned system, flagged rather than guessed at.
- **Ranged attack system**, generalized beyond just Archer:
  - **`oProjectileParent`** (root object) + **`oArcherProjectile`** (its first child, sprite `sArcherProjectile`). New `scripts/ProjectileScripts.gml`: `SpawnProjectile`/`ProjectileInit` (set up per-instance state right after `instance_create_layer`, same pattern as `BuildingApplyDefinition`/`UnitApplyDefinition`/`TrainingSpawnUnit`), `ProjectileUpdateMovement` (real x/y position — straight-line `Vector2.Lerp` from launch point to the target's position *at the moment of firing*, not homing, match-speed-scaled same `delta_time` idiom as `BuildingUpdateProduction`), `ProjectileResolveHit` (calls `ApplyDamage` if the target's still there when it arrives, then destroys the projectile either way), `ProjectileArcOffset`/`ProjectileDraw` (the cosmetic parabolic arc: a per-instance vertical draw offset that's 0 at launch/landing and peaks at the midpoint, with a rotation numerically sampled from that same offset function so the drawn angle can't drift out of sync with the drawn position — nose-up at launch, level at the apex, nose-down at landing). The projectile's real, stored `image_angle` is set once at launch to the flat straight-line direction and never touched again; the arc-following rotation is computed separately in `ProjectileDraw` and used only for that draw call.
  - **`UnitTryFireProjectile`** (`UnitCombatHelpers.gml`) — ranged counterpart to `UnitTryDealDamage`, same once-per-swing/hit-frame gating, calls `SpawnProjectile` instead of applying damage on the spot.
  - **`"attackRanged"` FSM state** (new `scripts/UnitStateAttackRanged.gml`) — ranged counterpart to `"attack"` (`UnitStateAttackMelee.gml`). Deliberately a structural duplicate (approach/swing/recover/defender, same as `"attack"`) rather than a branch inside it, matching this codebase's existing precedent of one dedicated state per order rather than shared/branching state logic (see the `"attack"`/`"siege"` dead-code bug from `v0.0.1.0`). The only actual difference from `"attack"` is that both swing points call `UnitTryFireProjectile` instead of `UnitTryDealDamage`.
  - **`UnitDefinition.projectileObject`** (`UnitDefinitions.gml`) — optional field, the projectile a ranged unit fires. Set for Archer (`oArcherProjectile`); left unset (melee) for everyone else.
- **FLAG (FSM/order wiring — CLAUDE.md calls `attack`/`combat`/etc. load-bearing):** `oUnitParent/Create_0.gml` now registers `"attackRanged"` alongside the existing states (purely additive). The `"attack"` order's `onIssue` (`OrderWiring.gml`) now picks `"attackRanged"` vs `"attack"` per unit based on `UnitHasTag(unit, "ranged")` — the one line that changed in that function.

### Known issues (new)

- **Buildings still have no HP.** `ApplyDamage` logs and no-ops against them. Melee units can still swing at buildings (nothing about that changed), it just doesn't do anything yet.
- **The `"combat"` FSM state is unreachable dead code** — discovered this session while scoping where ranged behavior needed to hook in. Nothing anywhere calls `fsm.ChangeState("combat")`; the only currently-reachable attack path is the `"attack"`/`"attackRanged"` order (with its own built-in defender-interrupt sub-phase). Not touched this session since it's unreachable regardless, but worth knowing if `"combat"` is ever wired up for real — it would need the same ranged/melee split `"attack"` just got.
- **`"siege"` was not touched.** A ranged unit sieging a castle still goes through whatever `"siege"` does today (untouched, not investigated this session for building-HP reasons above).
- **Archer's `attackRange` (96) is still a judgment-call placeholder**, not sheet-sourced — the ranged mechanic is now real, but its numbers aren't tuned.

### Build

- Windows export version bumped `0.0.2.10` → `0.0.2.11` — 4th-digit bump, same convention as last time.

## v0.0.2.10 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Peasant stat correction + five tier-1 training buildings/units, sourced from the Project Azurite Data Sheets spreadsheet (Unit Stats + Item Costs tabs).

### Fixed

- **`PATCH_NOTES.md` was truncated in the working tree**, cutting off mid-sentence partway through the v0.0.2.0 entry and dropping the entire v0.0.1.0 entry below it. Restored from the last commit (`54e76cd`, "V. 0.0.3.0") before adding this entry. Worth a quick look separately: that commit's message says `0.0.3.0` but `options_windows.yy` at that same commit is `0.0.2.9` — a mismatch between the commit title and the actual file, not something this session tried to resolve.
- **Peasant's stats didn't match the design spec** (`scripts/UnitDefinitions/UnitDefinitions.gml`): `maxHealth` 20→10, `attackDamage` 3→2, `cost` was `10 wheat + 5 coins` → now `20 water` (this also brings it in line with `oPeasantWard.trainCost`, which was already correct). Training cost/time (20 water / 10 sec) and Peasant Ward's build cost (40 wheat + 40 water) were already correct and untouched.

### Added

- **Five tier-1 buildings**: `oBoomHut` (trains Bomb Goblins), `oBogFoundry` (Mud Golems), `oBarracks` (Soldiers), `oArcheryRange` (Archers), `oRoundTable` (Knights). Each is a plain `oTrainingBuildingParent` child (`event_inherited()` only, same pattern as `oPeasantWard`) registered in `scripts/BuildingDefinitions/BuildingDefinitions.gml` with build cost, `trainsUnit`, `unitsPerBuilding`, `trainCost`, and `trainTime` all sourced from the data sheet. No changes needed to `TrainingScripts.gml` or `oTrainingBuildingParent` itself — the training pipeline was already fully data-driven.
- **Five tier-1 units**: `oBombGoblinUnit`, `oMudGolemUnit`, `oSoldierUnit`, `oArcherUnit`, `oKnightUnit`. Each is a plain `oUnitParent` child (`event_inherited()` only, same pattern as `oPeasantUnit`), registered in `scripts/UnitDefinitions/UnitDefinitions.gml` with sheet-sourced `maxHealth`/`attackDamage`/`cost`. Combat-timing fields with no sheet equivalent (`attackRange`, `attackLeashRange`, `attackHitFrame`, `attackCooldownMax`, `attackAggroRadius`, `siegeSweepRadius`, `maxSpeed`) are judgment-call placeholders, same status Peasant's always had.
- Each new unit's sheet "Stationed Effect"/"Deployed Effect" text is now captured in its `UnitDefinition.passives` array (inert data, per that field's existing documented convention — no station/deploy system exists yet to execute any of it).
- All 10 new objects registered in `Blank Pixel Game.yyp`.

### Known issues (new — flagged rather than guessed at)

- **No station/deploy economy exists.** The data sheet adds a per-unit "Station Deploy Cost (GOLD)" and per-unit "Upkeep (Stationed)" (e.g. Archer: 1 wheat/3 sec) on top of training cost. Neither has a field anywhere (`UnitDefinition` or `BuildingDefinition`) — deliberately not guessing at a shape for a system that isn't designed. The `"station"` order is still the no-op stub it's been since it was registered.
- **`UnitTryDealDamage` (`UnitCombatHelpers.gml`) is still a TODO stub** — no unit has ever actually dealt damage or died. This was already true before this batch, but it means several of this batch's signature mechanics can't be real yet either: Bomb Goblin's AoE (currently a flat `20` on `attackDamage`) and its self-destruct-on-hit, Mud Golem's on-death mud/slow zone (no on-death hook exists at all), and Knight's bonus damage vs. production buildings (`Attack_Step` doesn't distinguish building types).
- **Archer has no ranged attack.** Only a melee attack state (`UnitStateAttackMelee.gml`) exists — no projectile/ranged state. Archer is registered with a longer `attackRange` as a rough stand-in, but it will walk into range and melee-swing like every other unit. `sArcherProjectile` is wired into its `AnimationLibrary` as a named `"projectile"` sprite, ready for whenever a real ranged state gets built.
- Sheet data-quality notes carried over from the earlier review (not re-litigated here): Shinobi's Source Building is blank in Unit Stats but Item Costs' "Hidden Village" (tagged tier 1) is almost certainly it; Recruiter is a real tier-3 unit (50 Gold Coins, per Item Costs) with no stat block in Unit Stats; Jester/Necrotic Lich's unit limit is the string `"1 (HARD CAP)"` while Hellhounds' is a plain `1` — `TrainingTypeLimit` (`TrainingScripts.gml`) has no flat-cap path yet, only `sum(unitsPerBuilding × live buildings)`.

### Build

- Windows export version bumped `0.0.2.9` → `0.0.2.10` — 4th-digit bump, per the documented convention (3rd digit only when patch notes are explicitly requested, which wasn't the case this session).

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
