# Nightly Review — 2026-07-11

Safety commit: **done**, but push failed. Working tree had one untracked file (`NIGHTLY_REVIEW_2026-07-09.md`, left over from the 07-09 run, which never got committed). Ran `git add -A && git commit -m "Review 2026-07-11 Safety Commit"` — commit `e78d109`. `git push origin main` failed: `fatal: could not read Username for 'https://github.com': No such device or address` — this sandbox has no GitHub credentials configured, so the commit is local-only. Worth checking that this environment can authenticate to `origin` if pushes from these runs matter; otherwise these safety commits are only ever landing locally and won't show up on GitHub until someone pushes manually.

Also hit a stale `.git/index.lock` at the very start of the run (left over from something that didn't clean up after itself, dated Jul 9 22:02, no live git process holding it) that blocked `git add` until removed.

No code changed since the 07-09 review (`git log d3695c7..HEAD` shows only the "Update Windows options metadata and names" commit, which had already landed before 07-09 ran, plus tonight's own safety commit). Full pass repeated anyway per standing instructions, not skipped — see note in §3 about a correction to the previous report.

Full pass over every `.gml` file under `scripts/` (40 files) and `objects/` (74 event-script files), Scribble library excluded. Read-only pass — nothing below has been fixed.

**Summary: 0 syntax issues, 0 missing-JSDoc functions, 3 potential problems (1 critical, 2 minor) — down from 4 in the 07-09 report because one of those (the `oBuildingPlot` moderate finding) turned out to be a misattribution in that report, corrected below.**

## 1. Syntax errors

None found. Brace/paren/bracket balance checked programmatically across all 114 files (zero imbalanced files after stripping comments and string literals), plus a manual read of every script file for compile-breaking issues. Nothing found that would fail to compile.

Same two non-blocking style inconsistencies as 07-09 (legal GML, not syntax errors, still open):

- `scripts/Economy/Economy.gml` line 35 — `if !is_instanceof(_costs[i], ResourceCost) continue;` mixes parenthesis-less `if` with the parenthesized style used everywhere else in the file.
- `scripts/Math/Math.gml` line 409 — `ShapeRect.getCenter()` is camelCase; every other static/utility method in the codebase is PascalCase (`Add`, `Subtract`, `GetAdd`, etc.). Should probably be `GetCenter()`.

## 2. Missing JSDoc

None found. Verified programmatically this time (regex over both `function Name(...)` and `Name = function(...)` struct-method forms, checking for a `/// @function` block and one `@param` per parameter): 314 functions total across `scripts/` (206 top-level + 108 struct-method assignments), all fully documented. Matches the 07-09 count exactly, consistent with no code having changed.

## 3. Potential problems

### 3.1 CRITICAL — Selected units aren't pruned when they die; next Step (or next order) crashes

Same finding as 07-09, re-verified line-by-line tonight, still open:

- `scripts/UnitHoverScripts/UnitHoverScripts.gml`, `UnitSelectHoverController.Step` (line 284-286): `if (array_length(_selectionController.selected) != 1) return; var _unit = _selectionController.selected[0]; var _def = GetUnitDefinition(_unit.object_index);` — no `instance_exists` guard. Runs unconditionally every Step whenever exactly one unit is selected.
- `scripts/OrderWiring/OrderWiring.gml`, "defend" `onIssue` (lines 14-19) and "attack" `onIssue` (lines 49-54): both loop `for (i = 0; i < array_length(_units); i++) { _units[i].defendTarget = ...; _units[i].fsm.ChangeState(...); }` with no existence check.
- `scripts/UnitCombatHelpers/UnitCombatHelpers.gml`, `ApplyDamage` (line 125): calls `instance_destroy(_target)` directly with no hook back into `SelectionController.selected` to prune the dead reference.
- `scripts/UnitSelection/UnitSelection.gml`: `selected` is populated in `EndDrag()` (line 182) and cleared in two places (`ClearSelection`-style reset at 228, post-order-issue reset at 338), but never pruned mid-lifetime.

Practical effect unchanged from 07-09: select a unit, let it die in combat, and the game crashes on the next Step from the hover card alone, or on the next guard/defend/attack/siege order issued to that selection. Load-bearing FSM/order territory — flagging per CLAUDE.md rather than fixing.

### 3.2 CORRECTION to 07-09 report — the `oBuildingPlot.image_index` finding was based on a misattributed file

The 07-09 report described a moderate bug: `image_index = (!blocked) + (!inside);` allegedly living in `objects/oBuildingPlot/Create_0.gml`, computed once from stale Object Property defaults before `SpawnBuildingPlot` sets the real `.blocked`/`.inside` values, with "no Step event to ever correct it."

That's not what's actually in the repo. `objects/oBuildingPlot/Create_0.gml` is a 0-byte empty file (has been since the initial commit, per `git log --follow`). The `image_index = (!blocked) + (!inside);` line actually lives in **`objects/oBuildingPlot/Step_0.gml`**, which does exist and does run every frame. Since it recalculates from the live `blocked`/`inside` fields every Step — after `SpawnBuildingPlot` has set them — there's no staleness bug here at all; the previous report's line attribution and its "no Step event" claim were both wrong. No action needed on this one; flagging the correction so it's not carried forward into future reports as an open item.

### 3.3 MINOR — `oUnitParent/Draw_0.gml` uses `=` instead of `==` in a condition (still open from 2026-07-01 review)

Line 1: `if mask_index = sM_UnitMask{`. Re-verified tonight, unchanged. Legal GML (bare `=` in a condition reads as equality), and the only place in the codebase using this idiom instead of `==`. Flagged in `CODE_REVIEW_2026-07-01.md` §5, still open 10 days later.

### 3.4 MINOR — `oUnitParent/Create_0.gml` sets dead fields `pos` / `moveVec`

Lines 3 and 21: `pos = new Vector2(x,y);` and `moveVec = new Vector2(0,0);`. Re-checked tonight with a project-wide search — every real position read in `scripts/` uses `_unit.agent.pos` (SteeringAgent), never bare `.pos` or `.moveVec` on the unit itself. Still harmless, still a name collision waiting to confuse a future reader.

### Checked and clean

- `array_create(n, ref)` shared-struct-reference gotcha: scanned every `array_create` call in non-vendored scripts — all fill values are primitives (`undefined`, `false`, `0`) or omitted, never a shared mutable struct/array. Not present.
- Bare `self.` references in struct methods (GML self-rebinding hazard): zero hits in `scripts/`. State machine callbacks all take explicit `(_unit, _machine)` params instead.

**3 potential problems found (1 critical, 2 minor), plus 1 correction to the prior report.**

## 4. Patch notes

Skipped — no gameplay-relevant commits landed in the last 24 hours (the only commits since the last review are tonight's own safety commit and "Update Windows options metadata and names," which predates 07-09 and isn't gameplay-facing). Nothing to write patch notes for.
