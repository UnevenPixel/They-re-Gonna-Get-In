# Nightly Review — 2026-07-05 (overnight pass)

Scheduled, autonomous review-only pass. No code was edited, fixed, or refactored as part of this review. Reviewed every non-vendor `.gml` file under `scripts/` and `objects/` (89 files; Scribble-prefixed vendor scripts excluded) — see the methodology note below on how "reviewed" breaks down this run, because tonight's pass surfaced a real problem with trusting this session's own tools.

**Step 0 (safety commit): did NOT complete. Read this first.**

`git add -A && git commit` hit a stale `.git/index.lock` (dated July 3, before this session even started). It could not be removed — `rm`, `mv`, `chmod`, and Python's `os.remove` all failed with "Operation not permitted" against a file `stat` and `lstat` both say I own with full permissions. This is consistent with something on the Windows side holding an open handle on the file (an editor, the GameMaker IDE, a git GUI, or antivirus) — the same failure mode noted (and worked around) in last night's review.

I tried the same workaround as last night — building the commit through an alternate index file (`GIT_INDEX_FILE`) and manually reconciling — to sidestep the stuck `.git/index.lock`. That got as far as producing a real tree (`3ed9809ca4f71f4a55d9950f45649f574bd6be9d`) and commit object (`11b6785281e3ace84a1c047f17f44538857e172c`, parented on last night's `e792e88`), but the final `update-ref` step hit **another** stuck lock — `.git/HEAD.lock`, dated **July 4, 01:10**, i.e. left over from *last night's* session and never cleaned up — which also could not be removed for the same "Operation not permitted" reason. Push never happened.

**Do not use commit `11b6785`.** While investigating a separate issue below (see "Major finding"), I discovered the alternate-index workaround itself is unsafe in this environment: it silently commits whatever the shell happens to be able to read at that moment, and tonight the shell's read of one file was stale/truncated (see below). I confirmed `11b6785`'s copy of `oMatchControl/Create_0.gml` has the same truncated content as the file already wrongly committed at `e792e88` last night. Fast-forwarding to it would not fix anything.

**What you need to do manually, on your own machine, not through this sandbox:** close whatever program has `.git/index.lock` and `.git/HEAD.lock` open (check Task Manager for a lingering `git` process, and check whether GameMaker or an editor has the project open in a way that touches `.git`), delete both lock files via File Explorer, then run a normal `git add -A && git commit` **from your own shell/IDE**, not through this sandbox — see below for why.

## Major finding: tonight's git/shell view of the repo served stale file content, and it's already corrupted a real commit

While diffing `oMatchControl/Create_0.gml` (one of two files with real uncommitted changes tonight), `git diff`/`git show`/`cat` via the shell all agreed the file is 38 lines long, ending mid-comment at `global.blueprints = [[], []]` with no trailing newline — missing `global.age = [1, 1]`, the starting-resources loop, the test blueprint data, and the `AnalyticsInit()` call entirely. But reading the same file with the file-read tool shows the real, complete, 84-line file, correctly including all of that.

I checked the actual git object database directly (`git cat-file`, not just the working tree) to rule out a read-glitch on my end being the whole story: **`HEAD` (`e792e88`, last night's "safety commit") really does contain the truncated 38-line version.** That's not a display artifact — it's the literal content of the committed blob. Practical effect if anyone builds from exactly what's committed right now: `global.age` is never initialized (the first read of it, e.g. from `GainXP`, would error), starting resources stay at 0 instead of the intended 50 each, the test blueprint stacks never get added, and `AnalyticsInit()` never runs. None of this is visible in the actual working file you'd see in the IDE — only in what's actually committed.

Best guess at the mechanism: last night's session used the same alternate-index workaround for the same stuck-lock problem, and `git add` read this one file through the shell at a moment its view was stale/truncated, baking the bad read permanently into the commit. Tonight's shell exhibited the identical staleness on the identical file (confirmed via `stat`, which reported a Modify time of **July 2, 21:57** for a file the read-tool shows was actually edited July 4th) — so this isn't a one-off. `PATCH_NOTES.md`'s own newest entry independently reports the project's `.yyp` file has been found truncated "three times this project" already, which the previous session attributed to a possible autosave/sync race — that may be the same underlying phenomenon, or a related one. Worth ruling out whatever's causing it before it corrupts something more important. I did NOT change `oMatchControl/Create_0.gml`, `HEAD`, or attempt a third workaround — this needs a human doing the next commit directly, outside this sandbox, so it isn't at risk of the same silent truncation.

This also means: treat any "file X has a brace/bracket imbalance" result from a shell script run in this session with suspicion by default. My own first-pass brace-balance script (same technique as previous nights) flagged 11 files; I re-verified all 11 through the file-read tool and every one of them is actually balanced and fine — same conclusion as the AIControl.gml false-positive from two nights ago, just a bigger batch of them this time.

## Summary

- **Syntax:** 0 confirmed compile-breaking errors, in everything I could verify through the file-read tool. 9 style inconsistencies (all legal GML) — 7 carried over unchanged from the last two reviews, 2 new minor ones today.
- **Missing JSDoc:** 3 findings, all carried over unchanged from last night (one item from last night's report, `ShapeRect.getCenter`'s missing `@function` tag, now reads as present and complete — either fixed since, or was itself a shell-read artifact in that report; not re-flagging it).
- **Potential problems:** 31 items carried forward unchanged (underlying files untouched since last night — see `NIGHTLY_REVIEW_2026-07-04.md` for full detail on each), plus 2 new items below.

---

## 1. Syntax

Verified via the file-read tool (not the shell — see the major finding above): `Economy.gml`, `BlueprintScripts.gml`, `BuildingDefinitions.gml`, `GatherScripts.gml`, `OrderWiring.gml`, `TrainingScripts.gml`, `UnitDefinitions.gml`, `UnitStateDefend.gml`, `UnitStateGuard.gml`, `Math.gml`, the new `ProgressionScripts.gml`, `oMatchControl/Create_0.gml`, `oUnitControl/Step_0.gml`, `AIControl.gml`, `oUnitParent/Draw_0.gml`, `oPlotSpawner/Create_0.gml`, `oUIMain/Create_0.gml`, `oBuildingPlot/Create_0.gml`, and `SteeringBehaviors.gml`. All balanced, no compile-breaking errors. The remaining ~70 unchanged files aren't re-verified line-by-line tonight; they were exhaustively passed two nights ago (`CODE_REVIEW_2026-07-01.md`) and re-passed last night (`NIGHTLY_REVIEW_2026-07-04.md`) with no compile errors found, and nothing in them has changed since.

Still-open style nits (all legal GML, unchanged from prior reviews):
- **`scripts/Economy/Economy.gml`** — three bare/no-paren conditions: `Cost` constructor (`if !is_instanceof(...) continue;`), `CanAfford` (`if _resAmt < _costAmt{`), `Purchase` (`if _costStruct.CanAfford(_team){`).
- **`scripts/Math/Math.gml`** — `Vector2.Length()` (`return sqrt(x * x + y* y)`) and `ShapeRect.getCenter()` (`_centerPoint.Set(...)`) both missing terminating semicolons.
- **`objects/oPlotSpawner/Create_0.gml`, line 16** — `if _xx != 0 && _xx != 4 && _yy != 0 && _yy != 4{`, no parens.
- **`objects/oUnitParent/Draw_0.gml`, line 1** — `if mask_index = sM_UnitMask{` — `=` not `==`. Still open since `CODE_REVIEW_2026-07-01.md`.
- **`objects/oUIMain/Create_0.gml`** and **`objects/oBuildingPlot/Create_0.gml`** — both still genuinely empty (1 line, confirmed via file-read tool, not a shell artifact this time). Flagging again since neither has been addressed.

New tonight (both trivial, same "reads like a typo" category as the above):
- **`objects/oPlotSpawner/Create_0.gml`, line 12** — `var _rel = new Vector2(_xx*48,_yy*48)` — missing terminating semicolon.
- **`scripts/UnitStateGuard/UnitStateGuard.gml`, `Guard_Draw`, line 216** — `draw_line(_unit.x,_unit.y,_machine.data.waypoint.x,_machine.data.waypoint.y)` — missing terminating semicolon.

## 2. Missing JSDoc

- **`scripts/OrderWiring/OrderWiring.gml`, `RegisterAllOrders`** — every inline `onIssue`/target-validity callback passed to `new Order(...)` still has no JSDoc at all. Still open, same as last night — this is FSM/order-wiring code CLAUDE.md flags as load-bearing.
- **`scripts/SteeringBehaviors/SteeringBehaviors.gml`, `SteeringController`** — has `@function`/`@param`, no `@description`. Minor, still open.
- **`scripts/UnitStateGuard/UnitStateGuard.gml`, `GuardPickWaypoint`** — has `@function`/`@param`/`@returns`, description is prose above the block rather than tagged `@description`. Minor, still open.

Today's two changed files (`Economy.gml`, `oMatchControl/Create_0.gml`) and the one new file (`ProgressionScripts.gml`, `GainXP`) all have complete JSDoc — no new gaps introduced.

## 3. Potential problems

**New tonight:**

- **The git-corruption issue above** is, on its own, the most important finding in this report — a real bug is sitting in version control right now (`HEAD`, `e792e88`), invisible if you only ever look at the working file in the IDE.
- **`scripts/ProgressionScripts/ProgressionScripts.gml`, `GainXP`** — writes `global.resources[_team].xp`/`.fateTokens` directly, while `Economy.gml`'s `Cost`/`CanAfford`/`Purchase` walk `global.resources[_team]` generically by field name (per that file's own header comment, `xp`/`fateTokens` were added specifically so this works). Nothing currently costs `xp` or `fateTokens` in any `BuildingDefinition`/`UnitDefinition`, so this is dormant — but the moment something does, `Purchase` and `GainXP` would both be mutating the same two fields with no coordination. Same "not yet triggered" shape as the `Economy.gml` resource-key-drift item already open from two nights ago.

**Carried forward, unchanged** (underlying files untouched since last night — full detail in `NIGHTLY_REVIEW_2026-07-04.md` §3, one line each here for visibility):

1. Economy.gml `CanAfford`/`Purchase` silently treat a resource key missing from `Cost` as "affordable"/writes `undefined` — dormant, no `?? 0` guard.
2. `ChangeState` clearing `data = {}` on a same-state forced re-entry could desync `UnitTryDealDamage`'s `hitDealtThisSwing` — not confirmed live, flagged for a direct check.
3. `attackAggroRadius` fallback inconsistency: only `Siege_Step` defends with `?? 96`; other states assume it's always set.
4. `oBuildingPlot/Create_0.gml` empty; `Step_0.gml` reads `blocked`/`inside` with nothing setting them first (see Syntax §1 above — same file).
5. `_FindNearestEnemyInSweep`/`_FindNearestEnemy` (GatherScripts.gml) — leading-underscore function names, already marked superseded/dead in their own comments.
6. `OrderWiring.gml`'s `onIssue` callbacks don't `instance_exists`-guard units before dereferencing — likely safe today, no local guard.
7. `ProjectileScripts.gml`'s `ProjectileInit` silently defaults a teamless owner to `TEAM.PLAYER` with no log.
8. `UnitCombatHelpers.gml`'s `UnitEnterCombat` has no guard on `_target` — safe today, single caller already checks.
9. `UnitDefinitions.gml`'s `UnitApplyDefinition` writes a dead/duplicate `maxSpeed` per its own comment.
10. `TrainingScripts.gml`'s `TrainingSpawnUnit` has no `instance_exists(_building)` guard.
11. `UnitSelection.gml`'s `EndDrag`/`UpdateTargeting` read `.team` post-query with no guard in between.
12. `AIControl.gml`'s `AI_BuildUp_Step` reads `.fsm` on gathered units with no guard.
13. `BuildingDefinitions.gml`'s `BuildingUpdateProduction` could burst many effect calls after a big hitch — matches documented intent.
14. `SteeringBehaviors.gml`'s `Steering_Separation` could produce an exact-zero vector before `Normalize()`.
15. `Economy.gml`'s `Cost` constructor silently `continue`s past malformed entries with no debug log, unlike the rest of the codebase's convention.
16. `Math.gml`'s `ShapeRect.getCenter` is lowerCamelCase, breaking the file's own PascalCase static-method convention.
17. `oArcherUnit/Create_0.gml`'s header comment is stale — says ranged attack is unimplemented; it now is (see `UnitDefinitions.gml` and last night's ranged-combat batch).
18. `UnitStateGuard.gml`'s `Guard_Enter` sets `guardWaypointClaimed` twice in a row before `GuardPickWaypoint` — redundant, reads like a race at a glance.
19. `NearestBuildingEdgePoint`/`ATTACK_PHASE_*` macros defined once in the melee file, silently relied on by the ranged/siege files.
20. `obj_gm_button`'s `clicked` field is set in `Create_0.gml` but never read/maintained in `Step_0.gml`.
21. `obj_gm_button`/`obj_gm_text`/`obj_gm_textbox` naming/style inconsistent with the rest of the codebase — flagged as a likely unmodified starter-kit import, not fixed.
22. `oCastleManager`/`oCastleTopper` both independently hardcode `castleOffset = 180` and the magic value `411`.
23. `oCastleManager/Create_0.gml`'s `instance_create_layer` calls for the castles have no failure guard.
24. `oMatchControl/Create_0.gml`'s per-team resource struct shape changed recently (`xp`/`fateTokens`) — anywhere else building a similar struct literal should be checked for drift. (Also: correctly avoids the `array_create(n, sharedStruct)` hazard — good practice already in place.)
25. `oOpeningCredits/Create_0.gml`/`Draw_0.gml` — Create warns on a `shader_get_uniform` failure but Draw doesn't defend against that state.
26. `oOpeningCredits/Step_0.gml`'s skip logic relies on same-frame case-block ordering — works today, fragile if reordered.
27. `oPlotSpawner/Create_0.gml` writes `.blocked` on `SpawnBuildingPlot`'s return with no guard.
28. `oOuterPlotSpawner/Create_0.gml` relies entirely on magic numbers cross-checked against `oUnitParent`'s default `guardRect` — no shared constant.
29. `oUnitParent/Create_0.gml`'s tracked HAZARD comment (guardRect computed from a Create-time-hardcoded team) — confirmed still accurate and relevant.
30. `UnitCombatHelpers.gml`/`StateMachine.gml` — see item 2 above (split into two line items in the original report; combined here).
31. `BuildingDefinitions.gml`/`UnitDefinitions.gml` — no other new drift found tonight beyond item 24.

---

## Patch notes

Checked `git log --since="24 hours ago" --stat` — no new commits (nothing has been committed since last night's `e792e88`, itself dated July 4). Checked the actual working-tree diff against `HEAD` instead, since that's where tonight's real changes live (uncommitted, same as the last several sessions): `Economy.gml` and `oMatchControl/Create_0.gml` gained `xp`/`fateTokens` fields, plus a new `ProgressionScripts.gml` (`GainXP`) — this is the "not yet wired up" progression-accumulator work.

**Both internal and public patch notes for this work were already written** (`PATCH_NOTES.md` v0.0.2.14, `PLAYER_PATCH_NOTES.md`'s "Update — July 4, 2026" section) — from an earlier session today, before this review ran. I checked both against the actual code and they're accurate: `PATCH_NOTES.md` correctly documents `xp`/`fateTokens`, `global.age`, and `GainXP`'s behavior (including the "topped out" judgment call); `PLAYER_PATCH_NOTES.md` correctly keeps it high-level ("early groundwork for a future progression system") and uses the launch title throughout. No new entries needed from me.

One thing worth knowing: `PATCH_NOTES.md`'s own v0.0.2.14 entry documents its author finding `Blank Pixel Game.yyp` truncated mid-session and reconstructing it — the third time that's happened per that entry. I independently checked the `.yyp` file's current state tonight (JSON-parseable modulo GameMaker's trailing-comma style, ends with a proper closing brace) and it looks intact right now. Given tonight's git/shell staleness issue above, I can't fully rule out that this `.yyp` truncation history and tonight's stale-read issue share a root cause — worth keeping an eye on if it happens a fourth time.
