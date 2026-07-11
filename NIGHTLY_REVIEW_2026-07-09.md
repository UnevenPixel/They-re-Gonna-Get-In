# Nightly Review — 2026-07-09

Safety commit/push: **skipped**. Working tree was already clean at run start (nothing to commit) — last commit is `3e7cb3d` "Update Windows options metadata and names" (2026-07-07). Note: `git status` threw a one-time warning (`unable to unlink '.git/index.lock': Operation not permitted`) but still completed and reported a clean tree correctly; if this warning starts blocking real git operations it's worth a look, but it didn't tonight.

Full pass over every `.gml` file under `scripts/` (40 files, ~9,780 lines) and `objects/` (74 event-script files, ~871 lines), Scribble library excluded, per standing instructions. Read-only pass — nothing below has been fixed.

**Summary: 0 syntax issues, 0 missing-JSDoc functions, 4 potential problems (1 critical, 1 moderate, 2 minor).**

## 1. Syntax errors

None found. Brace/paren/bracket balance was checked programmatically across all 114 files (zero imbalanced files), followed by a full manual read of every file for compile-breaking issues — mismatched types, malformed literals, wrong argument counts, stray `=`/`==` confusion, degrees/radians boundary mistakes. Nothing found that would fail to compile.

Two non-blocking style inconsistencies surfaced during the read (not counted above — legal GML, not syntax errors, flagged per CLAUDE.md's "push back on inconsistencies" guidance):

- `scripts/Economy/Economy.gml` — `Cost` constructor and `Purchase()` mix parenthesis-less `if` conditions (`if !is_instanceof(_costs[i], ResourceCost) continue;`, `if _resAmt < _costAmt{`) with parenthesized ones used everywhere else in the file.
- `scripts/Math/Math.gml` — `ShapeRect.getCenter()` (line 409) is camelCase; every other static/utility method in the file (and codebase) is PascalCase (`Add`, `Subtract`, `GetAdd`, etc.). Should probably be `GetCenter()`.

## 2. Missing JSDoc

None found. Every function across all 40 `scripts/` files — plain functions, constructors, and nested `static` struct methods (~314 total) — has a complete `/// @function` block: every parameter has a matching `@param`, and every value-returning function has `@returns`. Documentation discipline here is solid; nothing to action.

## 3. Potential problems

### 3.1 CRITICAL — Selected units aren't pruned when they die; next Step (or next order) crashes

`scripts/UnitSelection/UnitSelection.gml` (`SelectionController.selected`) + `scripts/UnitHoverScripts/UnitHoverScripts.gml` (`UnitSelectHoverController.Step`, ~line 281) + `scripts/OrderWiring/OrderWiring.gml` ("defend"/"attack" `onIssue`, lines 14–19 and 49–54) + `scripts/UnitScripts/UnitScripts.gml` (`IssueOrderToUnits`'s default `onIssue`, `UnitSelection.gml` line 28–32).

`selected` is populated once in `EndDrag()` and never pruned afterward. `ApplyDamage` (`UnitCombatHelpers.gml` line 125) calls `instance_destroy(_target)` directly with no hook back into selection state. Every other cross-instance reference in this codebase (`attackBuildingTarget`, `combatTarget`, `defendTarget`, castle refs) is guarded with `instance_exists`/`variable_instance_exists` — `selected` is the one place that pattern is missing, and `GetCommonOrders` (same file) already does guard defensively, so the omission elsewhere reads as an oversight, not a deliberate choice.

Confirmed by reading both consumers directly:

- `UnitSelectHoverController.Step` runs unconditionally every Step whenever exactly one unit is selected: `var _unit = _selectionController.selected[0]; var _def = GetUnitDefinition(_unit.object_index);` — no existence check. If that one selected unit died last Step, this throws a hard runtime error on the very next Step, with no order needing to be issued at all.
- `Order.onIssue` for "defend"/"attack" (`OrderWiring.gml`) and the default `onIssue` (`UnitSelection.gml`) all loop `for (i = 0; i < array_length(_units); i++) { _units[i].defendTarget = ...; _units[i].fsm.ChangeState(...); }` with no existence check — issuing any order (guard/defend/attack/siege) to a selection that includes a since-died unit crashes immediately.

Practical effect: select a unit, let it die in combat (normal RTS occurrence), and the game will crash on the next Step purely from the top-left selection hover card trying to read it — or on the next order if hover isn't wired in yet. This is genuinely load-bearing (touches order/FSM dispatch), flagging per CLAUDE.md rather than fixing.

### 3.2 MODERATE — `oBuildingPlot`'s `image_index` is set from stale Object Property defaults, not the real per-plot classification

`objects/oBuildingPlot/Create_0.gml` line 1: `image_index = (!blocked) + (!inside);` runs against `blocked`/`inside`'s IDE-level Object Property defaults (both `"False"` per `oBuildingPlot.yy`), which GameMaker applies before Create runs. `SpawnBuildingPlot` (`scripts/PlotScripts/PlotScripts.gml`) only overwrites `.inside`/`.blocked`/`.far`/`.team` *after* `instance_create_layer` returns, i.e. after this line has already computed and cached `image_index` from the stale defaults. Since every plot in the game is spawned via `SpawnBuildingPlot`, `image_index` ends up `2` for literally every plot regardless of its real classification (Castle/Exterior/Distant/Blocked), and there's no Step event on `oBuildingPlot` (`Step_0.gml` is empty) to ever correct it. Purely cosmetic — `blocked`/`inside`/`occupied` still work correctly for gameplay logic and hover text — but the plot's visual sprite frame never reflects its actual state.

### 3.3 MINOR — `oUnitParent/Draw_0.gml` uses `=` instead of `==` in a condition (still open from 2026-07-01 review)

Line 1: `if mask_index = sM_UnitMask{`. Legal GML (bare `=` in a condition is equality here, not assignment) and the logic that follows reads as intentional — but it's the only place in the codebase using this idiom instead of `==`. This was already flagged as an open, unaddressed item in `CODE_REVIEW_2026-07-01.md` §5 and is still unaddressed tonight — noting it's now been open 8 days in case it just needs someone to make the trivial edit.

### 3.4 MINOR — `oUnitParent/Create_0.gml` sets dead fields `pos` / `moveVec`

Lines 3 and 21: `pos = new Vector2(x,y);` and `moveVec = new Vector2(0,0);`. A project-wide search found nothing that ever reads `unit.pos` or `unit.moveVec` — all real position state lives on `agent.pos` (the unit's `SteeringAgent`). Harmless today, but a future reader could easily mistake `unit.pos` for authoritative position instead of `unit.agent.pos`, especially given how similar the names are.

### Checked and clean (called out per the task's specific watch-list)

- `array_create(n, ref)` shared-struct-reference gotcha (the exact bug fixed in the 07-01 review): not present anywhere currently — `global.resources`, `global.blueprints`, `global.unitsDeployed`, etc. all correctly loop and assign fresh struct literals per slot.
- GML struct-method `self`-rebinding hazard in the StateMachine: `onEnter`/`onStep`/`onExit` callbacks all take explicit `(_unit, _machine)` params and never rely on `self` — a project-wide grep found zero bare `self.` references in `scripts/`, so this known GML hazard is designed around, not stumbled into.

**4 potential problems found (1 critical, 1 moderate, 2 minor).**

## 4. Patch notes

Skipped — `git log --since="24 hours ago"` returned no commits. Nothing has changed in the repo since the last commit (`3e7cb3d`, 2026-07-07), so there's nothing to write patch notes for. Also worth flagging separately from the review itself: there's no `NIGHTLY_REVIEW_2026-07-07.md` or `NIGHTLY_REVIEW_2026-07-08.md` in the repo even though a "Review 2026-07-07 Safety Commit" exists in git history — looks like this scheduled task didn't complete a full run (or didn't run at all) on at least one of those two nights.
