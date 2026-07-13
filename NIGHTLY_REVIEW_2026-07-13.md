# Nightly Review — 2026-07-13

**Summary: 0 syntax errors, 0 missing-JSDoc functions, 19 potential-problem findings (2 worth real attention, rest are style nits, documented/low-risk edge cases, or load-bearing-FSM awareness flags with no actual bug found) — plus 1 environment bug hit and worked around while writing this report (read §0.5).**

## 0.5 — File-sync bug hit tonight while writing this report (resolved, but worth knowing about)

Last night's report (07-12, §0) flagged that this sandbox's shell/git view of some files can disagree with their real content. It recurred tonight, on files I wrote myself, in the opposite direction.

While adding the public patch-note entry (§4) and drafting this report, my file-editing tool's writes to `PLAYER_PATCH_NOTES.md` and to a draft of this file were confirmed complete by the tool itself, but every check through the shell/git side of the sandbox (`cat`, `wc -l`, `git diff`, and even a direct Python `os.stat`/file read, to rule out a shell-utility-specific quirk) saw a **truncated version cut off mid-sentence**, missing the last several sections. This wasn't a brief caching lag — it didn't resolve after retries or an 8-second delay.

Root cause, best guess: the file-editing tool and this sandbox's shell write through two different channels to the same underlying files, and there's a propagation race between them — writes made through the editing tool aren't always fully visible to the shell/git side by the time a subsequent shell command reads them back. Files that already existed before this session (all the `.gml` files reviewed in §1-§3, the pre-existing parts of `PLAYER_PATCH_NOTES.md`) read back fine through the shell all night; only content freshly written by the editing tool this session hit the problem.

**Workaround used:** wrote both affected files' final content directly through the shell (`cat` with a heredoc) instead of through the editing tool, then verified with `wc -l`/`tail`/`git diff --stat` that the shell's view is complete and the resulting diff is clean (pure additions, nothing clobbered). Both `PLAYER_PATCH_NOTES.md` and this report file are confirmed intact and committed correctly as of this run (see §4 and the commit note below). No content was lost — the affected files just needed to be written a second way to get a version the shell/git side would commit correctly.

Flagging this because it's the same class of bug last night's report hit, just inverted, and worth knowing about if a future run reports something similar: prefer writing/verifying through the shell directly when a discrepancy shows up, rather than trusting either side blindly.

## 1. Syntax errors

None. Full pass over all 129 non-Scribble `.gml` files under `scripts/` and `objects/`: automated brace/paren/bracket balance check (0 imbalances) plus a direct read of every file, split across four parallel review passes.

One cosmetic nit, not a compile error: `scripts/Math/Math.gml`, `ShapeRect.getCenter()` (~line 414) — the statement inside is missing a trailing semicolon while every other statement in the file has one. Doesn't affect compilation.

## 2. Missing JSDoc

None. Every `function` definition (including constructors and static methods nested inside constructors) across all 129 files has a complete preceding Feather block — `@function`, `@param` per parameter, `@returns` where a value is returned. Spot-checked signature-to-`@param` parity on several multi-parameter functions and all matched exactly.

Two cosmetic tag-naming nits (not missing-doc violations, since `@function`/`@param`/`@returns` are all present):
- `scripts/GatherScripts/GatherScripts.gml`, `GetEnemyCastle`/`GetTeamCastle` (lines ~57, ~70) use `@desc` instead of the `@description` tag used everywhere else.
- Several functions across `DropDownMenuScripts.gml`, `UnitStateAttackMelee.gml`, `UnitStateDefend.gml`, `SelectionSummaryMenu.gml` use a bare description line instead of an explicit `@description` tag — still technically complete, just inconsistent style.

## 3. Potential problems

### Worth real attention

- **`objects/oBuildingPlot/Create_0.gml` is completely empty — no defensive defaults.** `AI_BuildingPlotTier`/`AI_FindEmptyOwnedPlot` (`AIControl.gml`) read `plot.inside`, `plot.far`, `plot.blocked`, `plot.occupied`, and `plot.team` on `oBuildingPlot` instances. `oBuildingParent/Create_0.gml` explicitly sets placeholder defaults "so nothing crashes if some future path runs without reaching the real init" — `oBuildingPlot` has no equivalent. If a plot is ever created outside its intended spawner path (dropped in the room editor, a future new spawn path), every one of those field reads is an uninitialized-variable read. Recommend either matching `oBuildingParent`'s defensive-default pattern, or confirming the spawner is genuinely the only creation path and documenting that assumption in the file.

- **`scripts/FateEngineDrumScripts/FateEngineDrumScripts.gml` — `GetSlotAngle`/`GetLockedItem`/`Stop()`'s pending-result logic uses exact float equality** (`GetSlotAngle(i) == 0`) to find the "front" slot. Only works today because `FATE_DRUM_SLOT_COUNT = 5` divides 360 evenly. If that macro is ever retuned to a value that doesn't divide cleanly, floating-point drift could make the exact-zero check never match — `GetLockedItem()` silently returns `undefined` and the slot-forcing loop in `Step()` silently falls through. Recommend an epsilon comparison before this constant is ever touched again.

### Lower-priority / edge cases

- `objects/oBuildingPlot/Step_0.gml:1` — `image_index = (!blocked) + (!inside);` maps `blocked && !inside` and `!blocked && inside` to the same index (1), while `blocked && inside` -> 0 and `!blocked && !inside` -> 2. Worth confirming the 3-frame sprite is intentionally a "bad/mixed/good" indicator rather than expecting 4 distinct visuals.
- `scripts/UnitHoverScripts/UnitHoverScripts.gml`, `UnitSelectHoverController.Step` (~line 286) — reads `_selectionController.selected[0].object_index` with no `instance_exists` guard. If the selected unit is destroyed earlier in the same frame before `selected` is pruned, this reads a stale instance id.
- `scripts/UnitStateGuard/UnitStateGuard.gml`, `GuardPickWaypoint` (~line 24) — `_bestDist` starts at 0 and only updates on strictly-greater distance; if every candidate this tick lands at exactly 0, `_best` stays undefined and the caller's next `.Distance(...)` call would throw. Astronomically unlikely with continuous random floats, flagging for completeness only. Guard state — load-bearing, not touched.
- `scripts/UnitStateDefend/UnitStateDefend.gml`, `Defend_Enter` — `_isCastle = !object_is_ancestor(_target.object_index, oBuildingParent)` infers "castle" from "not a building descendant" rather than a positive castle check. Correct today (castles are the only non-`oBuildingParent` thing ever assigned to `defendTarget`), but will silently misclassify anything else added later. Defend state — load-bearing, not touched.
- `scripts/UnitStateAttackRanged/UnitStateAttackRanged.gml` and `scripts/UnitStateCombatRanged/UnitStateCombatRanged.gml` both set/reset `_machine.data.hitDealtThisSwing`, but neither file ever reads it — looks like scaffolding copied over from the melee state files. Not a functional bug as far as these two files show; worth a quick confirmation it isn't meant to gate something.
- `scripts/Economy/Economy.gml`, `Cost.CanAfford`/`Purchase` (~lines 84-148) — iterates `struct_get_names(global.resources[_team])` and reads the matching `Cost` field via `struct_get` with no existence guard. Assumes `global.resources`'s keys and `Cost`'s 12 hardcoded fields stay in exact lockstep; a future key added to one without the other throws a real+undefined arithmetic error.
- `scripts/StationScripts/StationScripts.gml`, `GetStationedPassiveBonuses` (~lines 256-277) — same class of issue: `_bonuses[$ _fieldName] += _entry.amount` with no existence check if a future `stationedBonuses` `type` string doesn't match one of the 5 hardcoded fields. The function's own doc comment already flags this as a known risk, so not a silent landmine, but still no defensive guard in place.

### Style / convention nits (flagged per CLAUDE.md, not fixed)

- `scripts/Math/Math.gml`, `ShapeRect.getCenter()` — lowercase-first, breaks the file's own PascalCase static-method convention.
- `objects/oPlotSpawner/Create_0.gml` (~lines 13, 16) — an `if` condition without parens and two statements missing trailing semicolons, inconsistent with the rest of the file.
- `objects/obj_gm_button`, `objects/obj_gm_text`, `objects/obj_gm_textbox` — `obj_gm_` snake_case naming instead of the `o` + PascalCase convention used everywhere else (`oUnitParent`, `oBuildingPlot`). Pre-existing/legacy, asset-rename not a code fix.
- `objects/obj_gm_button/Create_0.gml:5`, `objects/obj_gm_text/Create_0.gml:2-3`, `objects/oOpeningCredits/Create_0.gml:18-21` — scattered missing trailing semicolons on assignment statements, inconsistent with adjacent lines in the same files.
- `scripts/Economy/Economy.gml` (lines 35, 91, 135) — bare `if condition statement;` without parens, inconsistent with the parenthesized style used elsewhere in the same file. Carried forward from prior reports (07-09/07-11/07-12), still open.
- `scripts/Steamworks_Definitions/Steamworks_Definitions.gml:287` — `LOCAL_Max = 3999` is mixed-case inside an otherwise all-caps enum; almost certainly a verbatim port of Valve's own SDK header casing, probably not worth fixing against upstream.

### FSM/state files touched this pass — flagged per CLAUDE.md, no bugs found

Reviewed only, not modified, per the standing instruction to flag rather than silently touch guard/defend/combat/attack/siege wiring: `UnitStateAttackMelee.gml`, `UnitStateCombat.gml`, `UnitStateDefend.gml`, `UnitStateAttackRanged.gml`, `UnitStateCombatRanged.gml`, `UnitStateGuard.gml`, `UnitStateSiege.gml`, `oUnitParent/Create_0.gml` (registers the full FSM chain), `OrderWiring.gml` (`ChangeState` dispatch for defend/attack/siege/station), `UnitSelection.gml` (`Order.onIssue`/`IssueOrder` generic `ChangeState`), `UnitStateStation.gml`. Nothing structurally broken found in any of them beyond the specific items already called out above.

### Verified safe (false leads, no action needed)

- `objects/oCastleManager/Draw_0.gml` reads `castleOffset`, which isn't set in that file — confirmed it's set in the sibling `Create_0.gml` (`= 180`), outside this batch. Safe, just a cross-file dependency worth knowing about.
- `scripts/PaletteSwapScripts/PaletteSwapScripts.gml`, `PaletteSwapDrawUnit` reads `_unit.palette` with no guard — confirmed `UnitApplyDefinition` (`UnitDefinitions.gml:358`) unconditionally sets `.palette` (even if `undefined`) for every unit type. Safe.
- No reference-sharing bugs (`array_create(n, sharedStruct)`) found anywhere. No struct-method `self`-rebinding hazards found. No TEAM/enum misuse found. No missing `instance_exists`/`variable_instance_exists` guards found beyond the one noted above (`UnitHoverScripts.gml`).

Skipped per standing instructions (already tracked, known stubs): `PlayResourceProducedEffect`, `ChooseCombatTarget`, `UnitTryDealDamage`'s damage-calc TODO.

## 4. Patch notes for today's changes

`git diff --stat` between last night's safety commit (`d6cee30`) and tonight's (`ae06f81`) shows 83 files changed, ~2,884 insertions -- a full session's worth of work: a unit-stationing/garrison system (`StationScripts.gml`, `UnitStateStation.gml`, `oUnitStationed`, click-to-deploy on the castle garrison dropdown), passive stationed-unit bonuses plus a new castle bonus panel (`CastleBonusHoverScripts.gml`), a full unit-gibbing/blood-particle system (`GibScripts.gml`, `oGibDebris`, `oGibSurfaceControl`, new gib sprites), an AI rebalance (defensive-reserve floor, tiered defend response, early-game probe attacks, AI self-stationing), a new multi-unit selection summary panel, a shared drop-down-menu sprite system retrofitted onto every menu, Knight's production-building damage bonus, Bomb Goblin's self-destruct-on-hit, blueprint-slot affordability borders, and hiding enemy training-queue info -- versions `v0.0.3.1` through `v0.0.3.14`.

**Internal patch notes: no action needed.** `PATCH_NOTES.md` already has complete, accurate, per-version entries for every one of these changes (written during the actual work sessions, before tonight's run) -- read through all of them against the real code and they check out. They were still labeled "(uncommitted -- working tree only, not yet committed)"; that's now stale as of `ae06f81` but left as-is since relabeling wasn't asked for.

**Public patch notes: added.** Unlike last night's report (which skipped this per CLAUDE.md's "only when explicitly requested" default), tonight's task explicitly calls for public patch notes when there are meaningful changes, so I wrote one. Added a new **"Update -- July 12, 2026"** entry to `PLAYER_PATCH_NOTES.md` (the actively-maintained per-date public log -- used that over `PUBLIC_PATCH_NOTES.md`, which is a separate one-off milestone-summary doc last touched at the `v0.0.3.0` milestone and not the right shape for a day-to-day update). Covers garrisoning/stationing, the AI improvements, the gib/blood system, the new selection panel, and the combat/UI tweaks in player-facing language, using the launch title throughout. Note: `PLAYER_PATCH_NOTES.md` was already stale before tonight -- its last entry was "July 5-6" while internal notes go up through `v0.0.3.14` (07-12) -- so there's a backlog of undocumented public-facing work between those two dates that tonight's entry does not attempt to backfill (out of scope for a same-day patch note pass); flagging in case you want a consolidated catch-up entry written.

**Commit note:** the first attempt to commit this report and the `PLAYER_PATCH_NOTES.md` update (commit `f2d7cf1`) was made before the file-sync bug in §0.5 was caught, and its copy of this report file is truncated partway through this section. This write (direct through the shell) supersedes it -- see the commit immediately following `f2d7cf1` for the corrected, verified-complete version of both files.
