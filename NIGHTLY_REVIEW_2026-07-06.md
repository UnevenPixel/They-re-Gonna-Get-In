# Nightly Review — 2026-07-06 (overnight pass)

Scheduled, autonomous review-only pass. No code was edited, fixed, or refactored as part of this review. Reviewed every non-vendor `.gml` file under `scripts/` and `objects/` (96 files; Scribble-prefixed vendor scripts excluded) — 65 object event files + 31 script library files.

**Read this first — same class of problem as the last two nights, and it just corrupted tonight's safety commit.**

## Step 0 (safety commit): completed, but the commit is suspect. Do not push it as-is.

`git add -A && git commit -m "Review 2026-07-06 Safety Commit"` succeeded this time (no stuck lock like 07-05) — commit `a76cba6`. `git push origin main` then failed: `fatal: could not read Username for 'https://github.com'` — this sandbox has no stored GitHub credentials, so nothing reached the remote. That's actually good news given what I found next.

**This sandbox's shell has two different views of the repo, and the stale one just got committed.** The `Read` file tool and the shell (`bash`/`git`) do not agree on the content of the 5 files touched most recently tonight:

- `Blank Pixel Game/objects/oFateEngineDrumTest/Draw_64.gml`
- `Blank Pixel Game/objects/oFateEngineDrumTest/Step_0.gml`
- `Blank Pixel Game/objects/oFateEngineDrumTest/Create_0.gml`
- `Blank Pixel Game/scripts/BlueprintScripts/BlueprintScripts.gml`
- `Blank Pixel Game/scripts/FateEngineDrumScripts/FateEngineDrumScripts.gml`

The `Read` tool shows complete, correctly-closed files for all five (verified by hand — braces/parens balance, files end where they should). The shell's `cat`/`wc` shows `Draw_64.gml` truncated at 673 bytes, cut off mid-statement inside the first `for` loop (`draw_rectangle(_drum.x - 50, ..., _dru` — nothing after). `git cat-file`/`git show HEAD` confirms the *committed* blob has this same truncated content — this isn't a display glitch, `a76cba6` really does contain a broken copy of at least this file, and almost certainly the other four (all touched in the same window, all showed the same mechanical brace-imbalance symptom before I checked them by hand).

This is the exact failure mode `NIGHTLY_REVIEW_2026-07-05.md` already documented and warned about (that night it was `oMatchControl/Create_0.gml` at `HEAD` via a different workaround). Same root cause, different files. Waiting a few seconds and re-reading via the shell didn't help — it's not a lag, the shell's mount is just frozen on a stale snapshot for whatever was mid-write when this session's sandbox started.

**What this means for you:** `a76cba6` ("Review 2026-07-06 Safety Commit") is sitting in your local repo only — it never reached GitHub, since I have no push credentials here. Recommend you don't push it as-is. Easiest fix: from your own machine/IDE, `git reset --soft HEAD~1` (or just amend it) and re-commit through a git client that's actually reading your live filesystem, then push normally. The live files on disk are fine — I verified all five read back complete and syntactically sound through the direct file-read path; it's only the sandbox's git snapshot that's wrong.

Because of this, every finding below that touches those 5 files (and, out of caution, anything else recently touched) was verified against the direct file-read tool, not the shell — noted inline where it matters.

## Summary

- **Syntax:** 0 confirmed compile-breaking errors. A mechanical brace/paren scan initially flagged the same 3 files above (plus one more via the same stale-mount effect) — all confirmed fine on direct read. A handful of pre-existing cosmetic style items (missing semicolons, unparenthesized `if`s) carry forward unchanged from prior reviews — see §1.
- **Missing JSDoc:** 9 functions — 5 in `StateMachine.gml` missing the `/// @function` header line entirely (real gap, not previously called out), 4 constructors missing `@returns` (judgment calls). See §2.
- **Potential problems:** ~40 items total; the large majority are carried forward unchanged from `CODE_REVIEW_2026-07-01.md` / `NIGHTLY_REVIEW_2026-07-04.md` / `NIGHTLY_REVIEW_2026-07-05.md` (same files, still untouched). New-tonight items are called out explicitly in §3.

---

## 1. Syntax

96 files walked (65 `objects/`, 31 `scripts/`). Mechanical brace/paren balance check + direct read-through for anything that looked structurally off.

Zero compile-breaking errors found once verified against the direct file-read tool. The mechanical scan's false positives (`Draw_64.gml`, `Step_0.gml` under `oFateEngineDrumTest`, and `FateEngineDrumScripts.gml`) were the stale-mount artifact described above, not real bugs — all three are correctly balanced and complete in the live file.

Carried-forward cosmetic style items (all legal GML, none block compilation):
- `scripts/Economy/Economy.gml` — unparenthesized `if` conditions (`Cost` constructor, `CanAfford`, `Purchase`).
- `scripts/Math/Math.gml` — `Vector2.Length()` and `ShapeRect.getCenter()` both missing terminating semicolons, plus a `y* y` spacing typo in `Length()`.
- `objects/oUnitParent/Draw_0.gml`, line 1 — `if mask_index = sM_UnitMask{` — assignment, not comparison. Legal GML (always truthy), so this never actually branches. Open since `CODE_REVIEW_2026-07-01.md`, still not normalized.
- `objects/oUIMain/Create_0.gml` and `objects/oBuildingPlot/Create_0.gml` — both still genuinely empty files. Open since 07-05.

## 2. Missing JSDoc

**New this round — `scripts/StateMachine/StateMachine.gml`:** `Current`, `ChangeState`, `RevertToPrevious`, `Step`, and `Draw` all have full `@param`/`@returns`/description text but are missing the `/// @function Name(...)` header line itself — `AddState`/`HasState`/`Is` in the same file have it. This is the FSM engine underlying every unit's state machine; worth a quick pass to add the five header lines since it's otherwise fully documented.

**Judgment calls — constructors missing `@returns` despite instances being used elsewhere** (not hard violations, flagging for consistency):
- `scripts/UnitScripts/UnitScripts.gml` — `UnitDataBlock()`
- `scripts/UnitSelection/UnitSelection.gml` — `Order(...)`, `SelectionController(...)`
- `scripts/UnitDefinitions/UnitDefinitions.gml` — `UnitDefinition(...)`

**Carried forward, unchanged:**
- `scripts/SteeringBehaviors/SteeringBehaviors.gml`, `SteeringController` — has `@function`/`@param`, no `@description`.
- `scripts/UnitStateGuard/UnitStateGuard.gml`, `GuardPickWaypoint` — description is prose above the block instead of a tagged `@description`.
- `scripts/GatherScripts/GatherScripts.gml` — several functions use `@description`/`@desc` inconsistently vs. the file's own plain-prose norm. Cosmetic.

No missing JSDoc in: AIControl, AnalyticsScripts, Animation, BuildingDefinitions, CameraScripts, Economy, Enumerators, Math, OrderMenu, OrderWiring, PlotScripts, ProgressionScripts, ProjectileScripts, ResourceParticleScripts, ResourceUIScripts, Steamworks_Definitions, SteeringBehaviors (besides the one note above), TrainingScripts, UnitCombatHelpers, BlueprintScripts, FateEngineDrumScripts, all 7 `UnitState*` files.

## 3. Potential problems

### New tonight

- **`objects/oUnitParent/Create_0.gml` (~lines 23-31, 46-52) — FLAG FOR REVIEW (load-bearing FSM).** FSM setup registers `guard`/`defend`/`combat`/`combatRanged`/`attack`/`attackRanged`/`siege`. `combatRanged`/`attackRanged` register `undefined` for their Draw callback while `guard` has a real one (`Guard_Draw`). No confirmed bug, but this asymmetry (no draw hook for the ranged states) is worth a direct look — flagging per standing FSM policy rather than touching it.
- **`scripts/UnitStateAttackMelee.gml` / `UnitStateAttackRanged.gml` / `UnitStateSiege.gml` — FLAG FOR REVIEW (load-bearing FSM).** Same pattern repeated across all three: the DEFENDER/ENGAGE_GUARD early-exit phase transitions call `UnitEndSwing` but skip resetting `hitDealtThisSwing`, unlike every other entry point in these files, which resets it explicitly. Not proven live (the next `UnitBeginSwing` resets it before it's read again), but consistent enough across three files to look like a copy-paste gap rather than three independent decisions.
- **`scripts/UnitStateAttackMelee.gml` / `UnitStateAttackRanged.gml` — FLAG FOR REVIEW (load-bearing FSM).** The aggro-interrupt check only excludes the `SWING` phase, meaning a defender can interrupt mid-`RECOVER`. Might be intentional (recovery is vulnerable, that's a reasonable design), but it's a combat-feel decision worth confirming rather than assuming.
- **`scripts/UnitStateCombat.gml` / `UnitStateCombatRanged.gml` — FLAG FOR REVIEW (load-bearing FSM).** The target-reacquire call is `ChooseCombatTarget(_unit)` with no `_radius` argument, which defaults to aggro range — but everywhere else in the same function the wider leash range is used. Could mean a unit prematurely drops combat when its target dies but another enemy is inside leash range yet outside aggro radius. Worth confirming intentional.
- **`scripts/UnitStateDefend.gml`, `Defend_Exit` — FLAG FOR REVIEW (load-bearing FSM).** Comment says waypoints are cleared on exit; code only clears `defendTarget`, not `_machine.data.waypoints`/`waypointIndex`. Not a live bug today (`Defend_Enter` unconditionally rebuilds waypoints on the way back in), but the comment and the code disagree.
- **`scripts/SteeringBehaviors/SteeringBehaviors.gml`, `Steering_AvoidObstacles`** — the doc comment claims it picks the "most-intersecting" obstacle; the implementation actually picks nearest-by-distance. Comment/implementation mismatch, not a crash.
- **`scripts/StateMachine/StateMachine.gml`** — callbacks are invoked as `currentState.onEnter(owner, self)`; `self` inside that call binds to the `State` struct, not the caller — the same self-rebinding class of hazard `CODE_REVIEW_2026-07-01.md` item 2 already fixed for the sprite-write case. Nothing proven broken today (every current callback body appears to route through the passed `_owner`/`_machine` args, not bare `self`), but it's an easy trap for the next state added to this file — worth calling out as a contract ("never read/write bare `self` inside an `onEnter`/`onStep`/`onDraw`/`onExit` body") rather than something in code comments today.

### Carried forward, unchanged (full detail in prior reports — one line each here)

1. `oBuildingPlot/Step_0.gml`'s `image_index = (!blocked) + (!inside)` collides two unrelated states onto the same sprite frame — known, deferred pending design input on what the 3 `sPlot` frames mean (see `PATCH_NOTES.md` v0.0.2.21 "Noted, not acted on").
2. `obj_gm_button`'s `clicked` field set in `Create_0` but never read in `Step_0` — dead variable, unfinished click-latch.
3. `obj_gm_button`/`obj_gm_text`/`obj_gm_textbox` naming breaks the project's `o*PascalCase` convention — reads like an unrenamed imported UI kit.
4. `oUnitParent/Draw_0.gml`'s `=` vs `==` (see §1).
5. `attackAggroRadius` fallback inconsistency: only `Siege_Step` (ASSAULT/RECOVER) defends with `?? 96`; every other caller assumes the field is always set. The `96` should be a named constant if the fallback is intentional.
6. `Economy.gml`'s `CanAfford`/`Purchase` treat a resource key missing from `Cost` as "affordable" / write `undefined` with no `?? 0` guard.
7. `_FindNearestEnemyInSweep`/`_FindNearestEnemy` (`GatherScripts.gml`) are dead code, already self-marked superseded.
8. `OrderWiring.gml`'s `onIssue` callbacks don't `instance_exists`-guard units before dereferencing.
9. `ProjectileScripts.gml`'s `SpawnProjectile` dereferences `_unit` with no `instance_exists` guard.
10. `UnitCombatHelpers.gml`'s `UnitEnterCombat` has no guard on `_target` — safe today, single caller already checks.
11. `TrainingScripts.gml`'s `TrainingSpawnUnit` has no `instance_exists(_building)` guard.
12. `UnitSelection.gml`'s default `onIssue` (`Order` constructor) dereferences `_units[i]` with no guard.
13. `AIControl.gml`'s `AI_BuildUp_Step` reads `.fsm`/`.Is("guard")` on gathered units with no guard.
14. `SteeringBehaviors.gml`'s `Steering_Separation` could produce an exact-zero vector before `Normalize()`.
15. `Math.gml`'s `ShapeRect.getCenter` and `Vector2.toString` are camelCase, breaking the file's own PascalCase static-method convention (`toString` is likely a deliberate GML string-coercion exception; `getCenter` isn't).
16. `GatherScripts.gml`'s `_FindNearestEnemyInSweep`/`_FindNearestEnemy`/`_CombatTargetActivityScore` use leading-underscore function names (elsewhere underscore means "parameter," not "function") — file comments indicate deliberate "superseded" signaling.
17. `UnitSelection.gml`'s `global.__orderRegistry` — double-underscore prefix, a one-off naming style not used elsewhere.
18. `oCastleManager`/`oCastleTopper` both independently hardcode `castleOffset = 180` and the magic value `411` — no shared constant.
19. `oOuterPlotSpawner/Create_0.gml` relies on magic numbers cross-checked against `oUnitParent`'s default `guardRect` — no shared constant.
20. `UnitStateGuard.gml`'s `Guard_Enter` sets `guardWaypointClaimed` twice in a row before `GuardPickWaypoint` — redundant, reads like a leftover race.
21. `UnitDefinitions.gml`'s `GetDamageTaken`/`SetDamageTaken` have no internal `instance_exists` guard — safe today only because every current call site guards upstream.
22. `UnitScripts.gml`'s `UnitUpdateSprite` reads `_unit.sprAttack`/`_unit.agent.velocity` with no existence guard — likely safe if `oUnitParent`'s Create always sets these, not independently re-verified this round.

Everything else in `objects/` (60 files: oAIControl, oArcherProjectile/Unit, oArcheryRange, oBarracks, oBogFoundry, oBombGoblinUnit, oBoomHut, oBuildingParent, oCastleManager/Topper, oEnvironmentSolid, oGameControl, oGoldMine, oInit, oIronMine, oKnightUnit, oMatchControl, oMudGolemUnit, oOpeningCredits, oOuterPlotSpawner, oPeasantUnit/Ward, oPlotSpawner, oProjectileParent, oResourceBuildingParent, oResourceProducedParticle, oRoundTable, oSawmill, oSoldierUnit, oTrainingBuildingParent, oUnitControl, oUnitParent Step/Draw, oWaterPump, oWheatField, obj_gm_text/obj_gm_textbox Draw) and the remaining `scripts/` files (PlotScripts, ProgressionScripts, ResourceParticleScripts, CameraScripts, Enumerators, Steamworks_Definitions, AnalyticsScripts, BuildingDefinitions except the note below) came back clean this round.

- `BuildingDefinitions.gml` — Wheat Field's cost was corrected 2026-07-05 to match the design sheet's "Wheat Farm" row; already-known and already-documented (`PATCH_NOTES.md` v0.0.2.20), not a new defect, noted only so it's on your radar as intentional if you see the diff.

---

## Patch notes for today's actual changes

`git log --since="24 hours ago" --stat` shows one real commit besides tonight's own safety commit: `b8bba3d` ("Fate Engine drums + resource economy systems", 2026-07-05 23:44) — the safety commit itself doesn't count per standing instructions, so I looked at what it (and the working-tree state it captured) actually contains.

**Internal notes:** `PATCH_NOTES.md` already has thorough, accurate, specific write-ups for all of tonight's/today's work (v0.0.2.15 through v0.0.2.26 — Purchase() struct-binding fix, the 4 remaining tier-1 resource buildings, resource-produced particle effects + draw-order fix, resource bar HUD + icon translation, Wheat Field cost correction, blueprint playtest seeding, blueprint UI resize/reposition, selection-drag UI gating, and the 3-pass Fate Engine drum-render prototype including tonight's landing-easing change). I spot-checked the two most recent entries (particle depth, drum landing-easing) against the live `FateEngineDrumScripts.gml`/`oResourceProducedParticle` files directly — both match the code exactly. No new internal entry needed from me; same as last night's finding, this was written up same-day by the session that did the work.

One caveat worth flagging inline: those entries are all labeled "uncommitted — working tree only" — that's stale now that `b8bba3d` exists, but given tonight's commit-corruption issue above, I'd hold off updating that labeling until you've re-committed cleanly from your own machine.

**Public notes:** `PLAYER_PATCH_NOTES.md` was NOT current — its newest entry is "July 4, 2026," so none of the resource-building completion, Wheat Field fix, particle effects, or UI resizing work from the last two days had a player-facing writeup yet. I added a new "Update — July 5-6, 2026" section covering the player-visible pieces (4 new resource buildings, a production balance fix, resource-collection visual feedback, and blueprint tray readability). I deliberately left out the Fate Engine drum work — `oFateEngineDrumTest` is explicitly a temporary, throwaway test harness with no real reward logic behind it yet (per its own file header), not something a player can actually reach in a real match, so it doesn't belong in a player-facing update yet.
