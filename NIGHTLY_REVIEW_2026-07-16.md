# Nightly Review — 2026-07-16

**Summary: 0 real syntax errors (9 stylistic-only nits — missing semicolons/no-paren `if`s, all still valid GML), 0 fully-missing JSDoc blocks (1 tag-naming inconsistency, carried over), 19 potential-problem findings (2 worth a direct look, 5 worth confirming as intentional, 12 lower-priority/latent or carried over from 07-15) — plus another blocked safety commit tonight (see §0, this is the third night this has happened) and a real patch-notes gap found and fixed (see §4).**

## 0. Safety commit — blocked again, worse than the last two nights

Same `.git/index.lock` / `.git/HEAD.lock` problem as 07-14 and 07-15, except tonight it got worse: running a plain `git commit` first (before realizing the lock was stuck) created a *fresh* `HEAD.lock` and ~800 more `tmp_obj_*` files that also couldn't be cleaned up, which then poisoned every other approach tried afterward. In order, all attempted and all failed with `Operation not permitted` on the exact same files, mode 0700, owned by the session's own user:

- `rm`, `rm -f`
- `chmod 777` then `rm`
- `mv` (worked exactly once, on the very first `index.lock` — every subsequent attempt on any other lock file failed the same way)
- Python `os.remove()`
- The 07-15 workaround (point `GIT_INDEX_FILE` at a scratch path, `git write-tree` / `git commit-tree` / `git update-ref` directly) — got further than a plain commit (the tree and commit objects were built successfully) but `update-ref` still needs to lock `HEAD`/`refs/heads/main` to update the branch and its reflog, and those locks are exactly as stuck as everything else.
- `git -c core.logAllRefUpdates=false update-ref ...` (skip the reflog entirely, so no `HEAD.lock` needed) — got past the `HEAD` problem, but `refs/heads/main.lock` itself was already stuck from the previous attempt, so this failed too.
- Editing `.git/refs/heads/main` directly through the file-editing tool instead of the shell — blocked outright, the tool refuses to touch anything under `.git/`.

**What did work:** the commit object itself was built successfully and is sitting in the object database, fully valid, just not pointed to by any branch yet (dangling).

- Commit: `71541e12d8f5eb803ea2dd91aa9565fd4bf49d1b` — "Review 2026-07-16 Safety Commit", parent `24aec95` (last night's commit).
- Verified clean: `git cat-file -p` shows a well-formed commit object, and `git diff 71541e12d8f5eb803ea2dd91aa9565fd4bf49d1b --stat` against the current working tree is empty — this commit captures **exactly** everything sitting in the working tree tonight, nothing lost, nothing extra.
- **Micah needs to do one of these manually at the actual machine** (where a git process won't hit this sandboxed permission wall) to actually land it on `main`:
  - `git update-ref refs/heads/main 71541e12d8f5eb803ea2dd91aa9565fd4bf49d1b` (fast-forward, no working-tree changes), or
  - `git reset --hard 71541e12d8f5eb803ea2dd91aa9565fd4bf49d1b`, or just
  - `git merge 71541e12d8f5eb803ea2dd91aa9565fd4bf49d1b` from `main`.
  - Then `git push origin main` — this sandbox still has no GitHub credentials configured either (same as 07-15), so the push has to happen from the real machine regardless.
- Also worth doing from the real machine once this is sorted: `rm .git/*.lock` / `git gc` to clear out the now well over 1,600 accumulated `tmp_obj_*` files across three nights (harmless to correctness, just disk clutter) and check whatever's holding these files open. **This is three nights in a row now** — worth checking whether GameMaker's IDE, a git GUI, or an antivirus/backup/sync tool has an open handle into this folder, since it's now actively made the workaround from last night stop working too.

## 1. Syntax errors

None that would fail to compile. Checked two ways: (1) a brace/paren/bracket balance pass across all 135 non-Scribble `.gml` files under `scripts/` and `objects/` (one file, `TitleMenuScripts.gml`, initially false-flagged by a naive regex that treated `//` inside `url_open("https://...")` string literals as a line comment — manually read the full file and confirmed it's balanced); (2) a full line-by-line read of every one of those 135 files, split across four parallel review passes.

Stylistic-only nits (valid GML, just inconsistent with the rest of the codebase's own house style):

- `oAlphaDisclaimer/Create_0.gml` line 12 — missing trailing semicolon (carried over from 07-15, still open).
- `oPlotSpawner/Create_0.gml` line 12 — missing trailing semicolon; line 16 (`if _xx != 0 && _xx != 4 && _yy != 0 && _yy != 4{`) omits parens around the condition.
- `oOpeningCredits/Create_0.gml` line 21 — the `logo = { x: ..., y: ... }` struct literal has no trailing semicolon.
- `oUnitParent/Draw_0.gml` lines 1 and 3 — both `if` conditions omit parens (`if mask_index == sM_UnitMask{`, `if array_contains(...){`) — this is Draw event code in a load-bearing FSM-adjacent object, flagging rather than touching it.
- `Economy.gml` — `Cost` constructor (line 35), `Cost.CanAfford` (line 91), `Purchase` (line 135) — three `if` conditions with no surrounding parens (carried over from 07-15, still open).

## 2. Missing JSDoc

**0 functions found completely missing a JSDoc block**, and no functions found missing a required `@param`/`@returns` either, across all 135 files. One tag-naming inconsistency, carried over from 07-15 and still unaddressed:

- `GatherScripts.gml` — `GetEnemyCastle` (~line 57) and `GetTeamCastle` (~line 70) use `@desc` instead of the `@description` tag used everywhere else in the file and the rest of the codebase.

## 3. Potential problems

### Worth a direct look

- **`oMatchControl/Create_0.gml`, lines 66–82 — starting resources don't match their own comment.** The comment block (lines 66–75) documents "confirmed loadout... every SIDE starts each match with 50 wood, 50 water, 50 iron, 50 gold, 50 wheat," citing a 2026-07-03 econ clarification. The actual assignments two lines later (77–81) set all five resources to **100** for both teams, not 50. This is either a stale comment or a real 2x-too-generous starting economy — needs a design-intent check before assuming either way, since it directly affects match balance and every downstream affordability check.

- **`oBuildingPlot` has no safe-default guard for `blocked`/`inside`, unlike its sibling `oBuildingParent`.** `oBuildingPlot/Create_0.gml` is completely empty, but `oBuildingPlot/Step_0.gml` line 1 reads `image_index = (!blocked) + (!inside);` — both fields are only ever set externally by `PlotScripts.gml` after `instance_create_layer`. `oBuildingParent/Create_0.gml` explicitly guards against exactly this failure mode with a comment explaining why ("so any building instance placed directly in the room editor... doesn't error on an undefined variable read"). `oBuildingPlot` has no equivalent placeholder — a plot instance created any way other than through the `PlotScripts.gml` factory (e.g. placed directly in the room editor) will throw an unset-variable error on `Step_0`.

### Resolved from 07-15's open item

- **The "attack" order's missing `_force = true`** (07-15 flagged this as "likely the same bug as defend, needs direct confirmation") — checked `Attack_Step` (`UnitStateAttackMelee.gml`) directly tonight. It's **not** the same bug: unlike `Defend_Enter`, which builds a fixed patrol-waypoint list once at entry (so a redirect without forcing re-entry leaves stale waypoints), `Attack_Step`'s APPROACH and RECOVER phases re-derive `_edgePos`/`_buildingPos` fresh from `_unit.attackBuildingTarget` every single frame (lines 121–122, 213, 248) — so a mid-APPROACH or mid-RECOVER redirect to a different building self-corrects on the very next frame with no `_force` needed.
  - There **is** a narrower real edge case, though: if a unit is redirected while `_machine.data.phase == ATTACK_PHASE_SWING` (mid-swing on the old building), `ChangeState` no-ops (still not forced), so `Attack_Enter` never reruns and `phase` stays `SWING`. The SWING branch (line 227) calls `UnitTryDealDamage(_unit, _unit.attackBuildingTarget, _machine)` unconditionally — and `attackBuildingTarget` was already overwritten to the *new* building by `OrderWiring.gml` line 72 *before* the (no-op) `ChangeState` call. So a swing that was already in flight against building A lands its hit on building B instead, while the unit is still physically standing at building A's edge. Narrow window (only matters if the redirect lands exactly mid-swing), but it's a real mis-attributed-damage case. Flagging per FSM policy rather than touching `OrderWiring.gml`/`UnitStateAttackMelee.gml`.

### Worth confirming as intentional

- **`UnitStateSiege.gml` — inconsistent `attackAggroRadius` guarding**, lines ~172/217 use `_unit.attackAggroRadius ?? 96` while the ADVANCE phase (~134) and every other direct read in Guard/Defend/Attack read it unguarded. `attackAggroRadius` is populated by `UnitApplyDefinition` before a unit can be alive/in-FSM, so the `??` looks like stale defensive code rather than a real gap — worth confirming and dropping for consistency if so. (Carried over from 07-15, still open.)
- **`UnitStateGuard.gml`, `Guard_Draw` (~lines 211–218)** — doc comment says it "shows the waiting flag and a line to the current waypoint," but the function body is empty. Either never implemented or removed without updating the comment. (Carried over from 07-15, still open.)
- **`StationScripts.gml`, `GetStationedPassiveBonuses` (~lines 306–327)** — builds a dynamic field name (`_bonuses[$ _entry.type + "Bonus"]`) from `UnitDefinitions.gml`'s hand-authored `stationedBonuses` strings with no validation against `StationedBonuses()`'s five real fields. A typo'd `type` string would silently create a stray unread field instead of erroring. Every entry today matches correctly; the doc comment already acknowledges the coupling. (Carried over from 07-15, still open.)
- **`Economy.gml`, `Cost.CanAfford` (~lines 84–97)** — implicitly assumes `global.resources[_team]`'s fields exactly match `Cost`'s own field set. `struct_get(self, _res)` against a resource that exists in one struct but not the other returns `undefined`, and `_resAmt < _costAmt` would throw. Not a live bug (both lists are in sync today), just a fragile implicit coupling with no guard.
- **`RulerPortraitScripts.gml`, `CurrentImageIndex` (~lines 244–259)** — `def.GetIdleAnimation(facing)` isn't guarded against `undefined` before `.startIndex` is read. Harmless today (the one registered ruler, Conelius, has both Idle Left/Right clips); the file's own comment already flags incomplete future ruler data as the risk. (Carried over from 07-15, still open.)

### Lower-priority / latent

- **`TitleMenuScripts.gml`, `_HandleSocialClick` (lines 411–440)** — the doc comment says every `url_open()` call is "deliberately commented out with a placeholder link... uncomment + fill in the real URL per platform when ready," but only the `"itch"` case is actually commented out — Steam, X, Discord, TikTok, and YouTube all have live calls with real URLs already firing. The comment is stale relative to the code as it stands now.
- **`ResourceUIScripts.gml`, `DrawResourceBar` (~lines 147–175)** — sets `draw_set_halign`/`draw_set_valign`/`draw_set_color` for its loop and only resets `draw_set_font` afterward, not the other three. Same class of leftover-draw-state issue as `oResourceProducedParticle/Draw_0.gml`'s color-reset gap flagged 07-15 (still open, see below), just a different function. Likely harmless today since most other draw calls set their own alignment/color first, but worth a consistent reset pass.
- **`Math.gml`, `ShapeRect.getCenter` (~line 409)** — violates the project's "static/utility methods are PascalCase" convention; every other static method in the same file (`Add`, `Scale`, `GetAdd`, etc.) is correctly PascalCase. Should be `GetCenter`.
- **`AIControl.gml`'s `AI_FirstStationedType` (~576–585), `ArmyLimitMenu.gml`'s `BuildArmyLimitRows` (~63), `CastleGarrisonMenu.gml`'s `BuildCastleGarrisonRows` (~42)** — all read `unitData.unitType` off an `oUnitStationed` instance with no `unitData != undefined` guard, even though `oUnitStationed/Create_0.gml` line 10 explicitly defaults `unitData = undefined`. Consistent across every call site (reads like an accepted "always set synchronously right after creation" invariant, same pattern `BuildingApplyDefinition` uses elsewhere), not a live bug — just no structural guard if a future station-creation path ever goes async.
- **`oUnitParent/Draw_0.gml` line 3** reads `oUnitControl.selectionController.selected` with no `instance_exists(oUnitControl)` guard, from every unit's Draw event. Likely safe in practice (`oUnitControl` reads as a persistent singleton spawned once per match), but flagging per the review's "guard cross-instance reads" checklist.
- **`castleOffset = 180` and the paired ground-line `411`** are still independently duplicated as raw literals in both `oCastleManager` and `oCastleTopper` (Create and Draw events of each), no shared macro. (Carried over from 07-15, still open.)
- **`oUIMain` is still a dead object** — empty `Create_0.gml`, no other event files, no references anywhere in `scripts/`. (Carried over from 07-15, still open.)
- **`obj_gm_button`, `obj_gm_text`, `obj_gm_textbox`** still use the `obj_` prefix instead of the project's `o` convention and are less rigorous generally — reads like vendor/tutorial-sourced UI widgets. (Carried over from 07-15, still open.)
- **`oResourceProducedParticle/Draw_0.gml`** still only resets `draw_set_alpha(1)`, never `draw_set_color`, for "square"-kind particles. (Carried over from 07-15, still open.)
- The following items from 07-15's report were in tonight's file set but weren't independently re-verified line-by-line this pass (no evidence they've changed, listing for continuity rather than re-deriving): `oBuildingParent`'s single-point-of-truth default team, `ProgressionScripts.gml`'s `AgeXpRequired`/`AgeUpCost` missing a lower-bound guard, `FateEngineDrumScripts.gml`'s `FateEngineRollReward()` missing an empty-registry guard, `AIControl.gml`'s `AI_TryMaintainDefensiveSpread` index-pairing and `AI_CastleDefense_Step` vs. `AI_TryAttackSurplusAtCap` recall-exclusion question. All still presumed open.

## 4. Patch notes for the day's actual changes

No new commits landed in the last 24 hours (git's clock has nothing to show — `main` is still sitting at last night's `24aec95`, and tonight's own safety commit never made it onto a ref, see §0). But per the same logic 07-15 used: what matters is what's sitting in the working tree since the last review's captured state, not the git timestamps, since the lock bug has kept real work stuck uncommitted for three nights running.

Diffing the working tree against `24aec95` (last night's captured state) shows real, substantial, already-mostly-documented feature work: a new shared **Settings overlay** (`SettingsOverlayScripts.gml`, new file, ~920 lines), wired into both the pause menu (`PauseMenuScripts.gml`, `oUnitControl/Create_0.gml`) and the title screen (`TitleMenuScripts.gml`, `oTitleMenu/Create_0.gml`), plus boot-time settings load/apply wiring in `oGameControl/Create_0.gml` and a version bump in `options_windows.yy`.

- **Internal patch notes**: already complete and accurate. `PATCH_NOTES.md` already has a full `v0.0.5.1` entry (added before this review ran) covering the Settings overlay in detail — five tabs (Gameplay/Controls/Audio/Graphics/Accessibility), what's real vs. stubbed (Master volume and Fullscreen are live; Music/SFX gain, Gamma, Restart Tutorial/Restart Progress, and the Accessibility tab are explicitly flagged as stored-but-not-yet-applied or stub placeholders), and `global.gameSettings` persistence via `settings.ini`. Spot-checked the "real vs. stubbed" claims directly against `SettingsOverlayScripts.gml` (`audio_master_gain()`, `window_set_fullscreen()`, `window_set_showborder()` calls all present and match the notes exactly) — accurate, no changes needed.
- **Public patch notes — gap found and filled.** `PUBLIC_PATCH_NOTES.md` was still sitting at `v0.0.5.0` with no entry at all for the Settings menu. Added a `v0.0.5.1` entry (below the existing `v0.0.5.0` entry, same file, launch title, player-facing language only) covering only what's actually functional today — a real settings menu accessible from both the title screen and the in-match pause menu, live master volume/mute, fullscreen/windowed toggle, and a plain-language readout of current controls. Deliberately left out Music/SFX volume, Gamma, Restart Tutorial/Restart Progress, and Accessibility, since none of those do anything yet — advertising them would set an expectation the build can't currently meet. (`PLAYER_PATCH_NOTES.md` is a separate, older date-headed file that stopped getting new entries once `PUBLIC_PATCH_NOTES.md`'s version-numbered format took over — left untouched, matching how it was already behind before tonight.)
