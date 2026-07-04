# Nightly Review — 2026-07-03 (overnight pass)

Review-only pass over every non-vendored project script (`scripts/`, excluding the Scribble library) and every object event script (`objects/`) — 71 `.gml` files. No edits made; this is a report for the morning.

**Summary:** 0 compile-breaking syntax errors found; 6 files flagged for legal-but-inconsistent GML style. 7 functions have an incomplete JSDoc header (all missing the `@function` tag; no missing `@param`/`@returns` found anywhere). 2 new/carried-forward potential problems, plus confirmation that both bugs flagged in the last audit (JSDOC_AUDIT.md) are now fixed in-tree. A large amount of uncommitted work has landed since the last commit (base-building economy loop) — see the patch notes section at the bottom.

Tooling note: the shell/bash tool in this environment served a stale, occasionally truncated copy of the repo during this pass (one file read via bash was cut off mid-statement; the same file read via the file-editing tool was complete and well-formed). Everything below was read via the file tool directly, not bash — flagging this in case it affects other automated tooling pointed at this repo.

---

## 1. Syntax

No file failed brace/paren/bracket balance or showed anything that would actually fail to compile. Everything below is legal GML that's stylistically inconsistent with the rest of its own file or the codebase's established convention (parenthesized conditions, semicolon-terminated statements, `==` for comparison).

- **`objects/oUnitParent/Draw_0.gml:1`** — `if mask_index = sM_UnitMask{`. Uses `=` instead of `==`; GML treats `=` as valid equality in a condition, so this compiles and behaves correctly, but it's the one spot in the reviewed set that doesn't use `==`. Carried forward from the 2026-07-01 review (flagged then as "still open, not addressed this round") — still open.
- **`scripts/Economy/Economy.gml:29,79,99`** — three `if` conditions without parentheses (`if !is_instanceof(...) continue;`, `if _resAmt < _costAmt{`, `if _costStruct.CanAfford(_team){`), inconsistent with parenthesized conditions used everywhere else.
- **`scripts/Math/Math.gml:160,414`** — `Vector2.Length()` (`return sqrt(x * x + y* y)`) and `ShapeRect.getCenter()` are both missing a trailing semicolon; otherwise the file is semicolon-consistent throughout.
- **`objects/oPlotSpawner/Create_0.gml:12,16`** — `var _rel = new Vector2(...)` missing a semicolon (sibling line has one), and an unparenthesized `if` condition on line 16.
- **`objects/obj_gm_button/Create_0.gml:5`** and **`Step_0.gml:4,11,14,19`** — missing semicolons throughout. This object (plus `obj_gm_text`, `obj_gm_textbox`, and their sprites/fonts) looks like an imported GameMaker UI-template asset pack rather than hand-authored code — same "not yours, don't refactor" category as the vendored Scribble library, flagging rather than fixing.

`objects/oBuildingPlot/Create_0.gml` and `objects/oUIMain/Create_0.gml` are empty files — checked, not a problem: `inside`/`far`/`blocked`/`team` on `oBuildingPlot` are Object Properties (set in the `.yy`, confirmed `varType` Boolean/Integer as expected), which GameMaker initializes before Create runs, so there's nothing to put in that Create event.

## 2. Missing JSDoc

The codebase has actually converged on full compliance almost everywhere — every function found has a doc block, every declared parameter has a `@param`, and every value-returning function has `@returns`. The one gap across the whole 71-file set is a handful of functions missing the `@function` tag specifically:

**`scripts/Economy/Economy.gml`**
- `Cost` (constructor, line 17) — missing `@function`.

**`scripts/Math/Math.gml`**
- `Set` (line 26) — missing `@function`.

**`scripts/GatherScripts/GatherScripts.gml`**
- `GatherNearbyObstacles` (line 3) — missing `@function`.
- `GatherNearbyAllies` (line 36) — missing `@function`.

**`scripts/OrderMenu/OrderMenu.gml`**
- `Open` (line 16) — missing `@function`.
- `Update` (line 48) — missing `@function`.
- `Draw` (line 83) — missing `@function`.

**`scripts/UnitStateGuard/UnitStateGuard.gml`**
- `GuardPickWaypoint` (line 24) — has a `@function` tag, but it's placed mid-block (line 19) instead of as the first `///` line. Ordering inconsistency, not a missing tag.

Side note: `JSDOC_AUDIT.md` at the repo root describes the project's house style as `@param`/`@return` (no `@function`, singular `@return`) — that's now stale. The codebase has converged on the CLAUDE.md-preferred style (`@function` + `@returns`) everywhere except the 7 functions above. Worth updating or retiring that file so it doesn't mislead anyone later.

## 3. Potential problems

**Both bugs flagged in the last audit (`JSDOC_AUDIT.md`) are now fixed:**
- `UnitStateAttackMelee.gml`'s call to `_FindNearestEnemy(_unit, _unit.attackAggroRadius)` — the function now exists (`GatherScripts.gml` lines 132–163, correct 2-arg signature), separate from the pre-existing 3-arg `_FindNearestEnemyInSweep` that `UnitStateSiege.gml` uses. No longer a runtime-error risk.
- `UnitStateGuard.gml`'s `GuardPickWaypoint` ally-scan — now correctly reads `if (!variable_instance_exists(_other, "team")) continue;` (checks the candidate ally, not the picker, and skips on *missing* rather than *present*). The anti-overlap claim check runs as intended. A comment at lines 40–43 documents this explicitly.

**New findings:**
- **`scripts/Math/Math.gml:409`** — `ShapeRect.getCenter()` is camelCase; every other static method in this file and across the codebase (`Vector2.Copy`, `.Set`, `.GetAdd`, etc.) is PascalCase per CLAUDE.md. Currently unused outside this file, so low urgency, but flagging per convention rather than silently renaming it (would need a call-site update if ever called as `.GetCenter()`).
- **`objects/oUnitParent/Draw_0.gml:1`** — see Syntax section above; functionally fine, still inconsistent, still open.

**Specifically checked and found clean** (worth recording since these are exactly the classes of bug this project has hit before): the `self`-rebinding hazard that previously broke Attack/Combat/Siege sprite state — no regressions in any state file, `StateMachine.Step`/`ChangeState` still pass `owner` explicitly. The `array_create(n, sharedLiteral)` reference-sharing gotcha that previously broke `global.resources` — checked every new global array (`global.blueprints`, `global.armyLimit`, `global.analytics`) and all correctly avoid it. The team-gets-overwritten-after-`instance_create_layer` pattern — `TrainingSpawnUnit` correctly re-derives `guardRect` after overriding `team`, same fix pattern `BlueprintController.EndDrag` uses for buildings. `move_and_collide` → `SyncFromInstance`, knockback/stagger scaling, TEAM enum usage, and the degrees-only-at-the-API-boundary convention were all spot-checked across the new/changed files and found consistent.

**Not independently verified:** `Steering_AvoidObstacles`'s left/right cross-product sign convention wasn't re-verified against GML's y-down screen space (would need in-engine testing, not a static read) — looked internally consistent, flagging as unverified rather than asserting it's correct.

**Known, already-tracked, not re-flagged per your standing instructions:** `PlayResourceProducedEffect` (stub), `ChooseCombatTarget` (stub), `UnitTryDealDamage`'s damage-calc TODO. `AnalyticsRecordKill`/`AnalyticsRecordDeath` are new but exist for exactly the same reason — there's still no "unit died" event to call them from; they're pre-wired for whenever real damage resolution lands.

---

## Patch notes for today's changes

No new git commits landed in the last 24 hours (last commit: `5012d06`, "Add unit definitions and outer building plots," 2026-07-01). However, the working tree has substantial **uncommitted** changes — a full base-building economy loop was added between 2026-07-01 22:02 and 2026-07-03 00:42. Since that's clearly the actual day-over-day work and not yet captured anywhere, internal and public patch notes for it are below (appended to `PATCH_NOTES.md` / `PLAYER_PATCH_NOTES.md`), covering everything since the `v0.0.2.0` entry. Recommend committing this work once you're back at the keyboard — right now a crash or `git checkout` would lose all of it.
