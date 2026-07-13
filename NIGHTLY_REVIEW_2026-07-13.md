# Nightly Review — 2026-07-13

**Summary: 0 syntax errors, 0 missing-JSDoc functions, 19 potential-problem findings (2 worth real attention, rest are style nits, documented/low-risk edge cases, or load-bearing-FSM awareness flags with no actual bug found) — plus 1 live environment bug that left `PLAYER_PATCH_NOTES.md` uncommitted tonight (read §0.5 first).**

## 0.5 — Read this first: file-sync bug hit tonight, `PLAYER_PATCH_NOTES.md` needs a manual look

Last night's report (07-12, §0) flagged that this sandbox's shell/git view of some files can disagree with their real content. It recurred tonight, on a file I edited myself, in the opposite direction.

While adding the public patch-note entry (§4), my file-editing tool wrote the update to `PLAYER_PATCH_NOTES.md` successfully (confirmed — the tool's own re-read shows the full, correct file: the new July 12 entry plus every pre-existing section intact through the "Internal note" line at the end). But every check through the shell/git side of the sandbox (`cat`, `wc -l`, `git diff`) sees a **truncated 79-line version that cuts off mid-sentence** ("...You can now drag b") partway through the July 3 entry — the July 1 entry and the closing internal-note line are missing from the shell's view entirely. I rewrote the file a second time to rule out a one-off write glitch; the shell's view stayed truncated at the same cut point both times, and didn't resolve after a retry with a delay. Checksums confirm the two views are genuinely different, not a caching illusion I misread.

**I did not commit `PLAYER_PATCH_NOTES.md` tonight.** Since I can't get the shell/git side of this sandbox to agree with what my own edit actually wrote, committing through git right now risks permanently baking the truncated version into history — worse than leaving it uncommitted. The file is left as a local, uncommitted change; `git status` will show it as modified.

**What to do:** open `PLAYER_PATCH_NOTES.md` directly on your machine (not through this session) and check whether the July 12 entry is there and whether the file still ends with the July 1 section and the "Internal note" line. If it looks complete, it's safe to `git add`/commit yourself — the corruption appears to be confined to this sandbox's view, not your actual disk (same conclusion last night's report reached about its own 5 affected files). If it's actually truncated on your end too, the content to restore is in this session's history (or just ask me to regenerate the July 12 entry next run).

This same desync could in principle affect other files touched this way; I did not do a full re-audit of every file for this specific failure mode beyond what §0 and §1 already checked through the (separately-verified-fine) shell view.

## 0. Safety commit

Working tree had a full session's worth of uncommitted changes (station/garrison system, unit gibbing, AI rebalance — see §4). `git add -A && git commit -m "Review 2026-07-13 Safety Commit"` succeeded as commit **`ae06f81`**.

Before it could run, three stale lock files were blocking git entirely: `.git/index.lock`, `.git/HEAD.lock`, and `.git/objects/maintenance.lock`, all timestamped 2026-07-12 01:08 — leftover from last night's safety commit, which apparently completed (its content is in `d6cee30`) but never cleaned up its own lock files. Deletion of files under `.git/` is blocked by default in this environment; each had to be individually approved before `rm` would work. Worth knowing this could recur — if a future nightly run reports it can't commit due to lock files, this is why.

`git push` failed: `fatal: could not read Username for 'https://github.com'` — no git credentials in this sandbox, same as every prior nightly run. Commit `ae06f81` is local-only; needs a manual `git push` from your machine.

Also worth noting: last night's report (`NIGHTLY_REVIEW_2026-07-12.md`, §0) flagged that the sandbox's shell/git view of 5 files (`OrderWiring.gml`, `oUnitControl/Step_0.gml`, `BuildingHoverScripts.gml`, `TrainingScripts.gml`, `UnitDefinitions.gml`) disagreed with their real on-disk content, and that last night's commit may have captured truncated versions. I spot-checked all 5 tonight — each now ends cleanly at a closing brace with no truncation, and the content committed tonight looks complete. Whatever caused that mismatch either resolved itself or was specific to that session; flagging in case it recurs, but nothing to act on tonight.

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

- `objects/oBuildingPlot/Step_0.gml:1` — `image_index = (!blocked) + (!inside);` maps `blocked && !inside` and `!blocked && inside` to the same index (1), while `blocked && inside` → 0 and `!blocked && !inside` → 2. Worth confirming the 3-frame sprite is intentionally a "bad/mixed/good" indicator rather than expecting 4 distinct visuals.
- `scripts/UnitHoverScripts/UnitHoverScripts.gml`, `UnitSelectHoverController.Step` (~line 286) — reads `_selectionController.selected[0].object_index` with no `instance_exists` guard. If the selected unit is destroyed earlier in the same frame before `selected` is pruned, this reads a stale instance id.
- `scripts/UnitStateGuard/UnitStateGuard.gml`, `GuardPickWaypoint` (~line 24) — `_bestDist` starts at 0 and only updates on strictly-greater distance; if every candidate this tick lands at exactly 0, `_best` stays undefined and the caller's next `.Distance(...)` call would throw. Astronomically unlikely with continuous random floats, flagging for completeness only. Guard state — load-bearing, not touched.
- `scripts/UnitStateDefend/UnitStateDefend.gml`, `Defend_Enter` — `_isCastle = !object_is_ancestor(_target.object_index, oBuildingParent)` infers "castle" from "not a building descendant" rather than a positive castle check. Correct today (castles are the only non-`oBuildingParent` thing ever assigned to `defendTarget`), but will silently misclassify anything else added later. Defend state — load-bearing, not touched.
- `scripts/UnitStateAttackRanged/UnitStateAttackRanged.gml` and `scripts/UnitStateCombatRanged/UnitStateCombatRanged.gml` both set/reset `_machine.data.hitDealtThisSwing`, but neither file ever reads it — looks like scaffolding copied over from the melee state files. Not a functional bug as far as these two files show; worth a quick confirmation it isn't meant to gate something.
- `scripts/Economy/Economy.gml`, `Cost.CanAfford`/`Purchase` (~lines 84–148) — iterates `struct_get_names(global.resources[_team])` and reads the matching `Cost` field via `struct_get` with no existence guard. Assumes `global.resources`'s keys and `Cost`'s 12 hardcoded fields stay in exact lockstep; a future key added to one without the other throws a real+undefined arithmetic error.
- `scripts/StationScripts/StationScripts.gml`, `GetStationedPassiveBonuses` (~lines 256–277) — same class of issue: `_bonuses[$ _fieldName] += _entry.amount` with no existence check if a future `stationedBonuses` `type` string doesn't match one of the 5 hardcoded fields. The function's own doc comment already flags this as a known risk, so not a silent landmine, but still no defensive guard in place.

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

`git di