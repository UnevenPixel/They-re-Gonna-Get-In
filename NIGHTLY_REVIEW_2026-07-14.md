# Nightly Review — 2026-07-14

**Summary: 0 syntax errors, 0 missing-JSDoc functions, 5 potential-problem findings (1 worth real attention, 1 worth confirming as intentional, 3 lower-priority/latent) — plus a blocked safety commit (see §0) that needs Micah's attention before anything else.**

## 0. Safety commit — BLOCKED, could not complete

Step 0 (`git add -A && git commit` before reviewing) failed. `.git/index.lock` already existed in the repo, 0 bytes, owned by this same sandbox user, and every attempt to remove it (`rm -f`, `chmod 777` then `rm`, retried after the mechanical review finished) returned `Operation not permitted` — not a permissions issue in the usual sense (same uid/gid, mode 0700), more consistent with the mounted-folder driver or an active host-side process holding the file open. `git add -A` itself then fails with GameMaker's usual "Another git process seems to be running" message.

**Nothing was committed or pushed tonight.** The working tree currently has 6 uncommitted files sitting on top of last night's commit — `Blank Pixel Game.yyp`, `options_windows.yy`, `TitleMenuScripts.gml`/`.yy`, `PATCH_NOTES.md`, `PUBLIC_PATCH_NOTES.md` — none of that is lost, it's just not snapshotted. Since this is a review-only pass anyway, no code was touched by me on top of that. Micah: worth checking whether GameMaker's IDE, a git GUI, or another terminal has this repo open and holding a lock, then manually deleting `.git/index.lock` before the next run.

Given the lock, I did not attempt `git push` either. Read-only git commands (`log`, `diff`, `show`) all worked fine throughout — only index-writing operations are blocked.

## 1. Syntax errors

None found. Two passes: (1) an automated brace/paren/bracket balance check (ignoring `//`, `/* */`, and string literals) across all 134 non-Scribble `.gml` files under `scripts/` and `objects/` — clean, 0 imbalances. (2) A full line-by-line read of every file touched by last night's 98dc912 commit (the large Title Menu / Fate Engine / HUD widgets add) via three parallel review passes, specifically looking for anything that wouldn't compile (mismatched types, invalid syntax, obvious typos) on top of the mechanical check. Nothing found.

## 2. Missing JSDoc

None found. Ran the same check as prior nights: every `function Name(...)` and every `static Name = function(...)` across all 134 files (in `scripts/` — object event files don't define named functions) has a preceding `///` Feather block with `@function`, an `@param` line covering every parameter, and `@returns` wherever the function actually returns a value. 298 top-level functions + 177 static/constructor methods checked mechanically; 0 flagged. The three review passes below also read this same code closely and didn't surface any doc gaps the mechanical check might have missed.

## 3. Potential problems

### Worth real attention

- **`objects/oUnitControl/Step_0.gml` — `orderMenu` has no `consumedClick` guard, unlike the three other dropdowns.** Lines 151-161 explicitly guard the frame's main left-click handler against `castleGarrisonMenu.consumedClick`, `selectionSummaryMenu.consumedClick`, `armyLimitMenu.consumedClick`, and `_clickedBlueprintArrow` — the comment there even documents this exact bug class being fixed for those three ("a latent gap ... fixed here for both since SelectionSummaryMenu's click-to-select makes it immediately observable"). `orderMenu.Update()` runs earlier (line 66) and can consume that same physical left-click (clicking a non-targeted order row, e.g. "Guard" or "Siege" — see `IssueOrder`, `UnitSelection.gml` line 294-309, which clears `selected = []` immediately for those). Because `orderMenu` isn't in the line-161 guard, that same click can fall through into the drag-select/deploy/dropdown logic below it in the same frame — e.g. starting a fresh `BeginDrag()` or hitting the Army Limit icon/castle mask, depending on where the order row happened to sit in room-space coordinates. Targeted orders (defend/attack) are safe from this because `BeginTargeting` routes the same press into `UpdateTargeting`'s own swallow guard instead. Recommend giving `OrderMenu` the same `consumedClick` treatment the other three dropdowns just got.

### Worth confirming as intentional

- **`AIControl.gml`, `AI_CastleDefense_Step` (~line 664-669) — the castle-defense recall sweep excludes units in `"attack"` state.** It pulls units back from `"guard"`, `"defend"`, and `"siege"` but deliberately not `"attack"` or the combat states — the doc comment justifies this as not yanking actively-fighting units out of a fight to their deaths. That reasoning holds for units already engaged, but `AI_TryAttackSurplusAtCap` (line ~1492) can commit the team's *entire surplus army* to `"attack"` in one shot, including units still travelling toward the target and not yet engaged. If the AI's own castle comes under threat while that whole surplus force is still marching (not yet fighting), none of it comes home — only whatever `AI_MinDefensiveReserve` already held back responds. This may well be the intended trade-off (siege was called out as newly-recalled while attack wasn't, so the asymmetry looks deliberate), but worth a quick confirm since "attack" now represents a much larger, more discretionary commitment than it used to.

### Lower-priority / edge cases

- **`AIControl.gml`, `AI_TryMaintainDefensiveSpread` (~line 366-369)** pairs `_guards[i]` with `_uncovered[i]` purely by array index, with no distance/tier check on which guard goes to which building. Currently masked because `AI_SPREAD_ATTEMPTS_PER_TICK == 1`, so only index 0 on each side ever pairs up. If that macro is ever raised above 1, a guard standing right next to a front-tier building could get walked across the map to cover a rear building purely because of array order, while a closer guard sits idle. Worth a proximity-based match before that knob is touched.
- **`FateEngineDrumScripts.gml`, `FateEngineRollReward()` (~line 115-116)** — `var _buildingType = _buildingTypes[irandom(array_length(_buildingTypes) - 1)];` has no guard for `global.__buildingDefRegistry` being empty. If the "blueprint" branch of the 50/50 roll is ever hit while that registry is empty, `irandom(-1)` plus an out-of-bounds index would throw. Low likelihood (the registry is populated at match start with core building types) but no defensive check exists the way other "should always exist" assumptions elsewhere in this same commit (e.g. `GetTeamCastle`) do guard themselves.
- **`ProgressionScripts.gml`, `AgeXpRequired(_age)` / `AgeUpCost(_age)` (lines ~64-67, ~74-77)** — both guard the upper bound (`_age >= AGE_MAX`) but not `_age <= 0` before indexing `global.ageXpRequired[_age - 1]`/`global.ageUpCost[_age - 1]`. Not reachable today (`global.age` starts at `[1, 1]` and only ever increments), but nothing structurally prevents a future debug/cheat/save-load path from writing `0` directly and silently negative-indexing.

### Investigated and ruled out

- One review pass initially flagged `RemoveBlueprintOne` (`BlueprintScripts.gml` line 53-65) as a possible reference-sharing bug — the concern being that `array_delete` on a locally-held `_stacks` variable might not propagate back to `global.blueprints[_team]` under a "copy-on-write" array model. Checked this directly: GameMaker arrays are true references (confirmed via the GameMaker manual and community documentation), not copy-on-write, so `array_delete`/`array_push`/element writes through any variable holding the same array reference do mutate the shared underlying array. Not a bug — noting it here only so the lead doesn't get re-chased on a future pass.

## 4. Patch notes for today's changes

Not written tonight — they already exist. `PATCH_NOTES.md` and `PUBLIC_PATCH_NOTES.md` both already have full, detailed entries for everything in the working tree covering v0.0.4.11 through v0.0.5.0 (title menu polish, the social-icon hover/entrance squash animations, the "Press Any Key" typewriter fix, the button hit-box fix, and the version bump), written before this run started and currently sitting uncommitted alongside the code changes they describe. I read through both and they're accurate against the diffs I reviewed — nothing to add. These will get committed once the §0 git lock is cleared.
