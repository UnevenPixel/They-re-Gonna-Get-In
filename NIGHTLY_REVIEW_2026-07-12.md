# Nightly Review — 2026-07-12

**Summary: 0 real syntax errors, 0 missing-JSDoc functions, 0 new potential problems — but 1 CRITICAL environment/data-integrity issue (read first) and 2 previously-critical/minor issues from earlier reports confirmed FIXED this pass.**

## 0. Read this first — the safety commit may contain corrupted files

Step 0 ran as usual: working tree had uncommitted changes (a full session's worth of station/garrison-UI/dropdown-menu work, see §4), so I ran `git add -A && git commit -m "Review 2026-07-12 Safety Commit"` → commit `d6cee307dce717de45af086412dcf7ed362d6a66`. `git push origin main` failed with the same `fatal: could not read Username for 'https://github.com'` this environment always hits — the commit is local-only, nothing reached GitHub.

While diagnosing a false-positive brace-imbalance flag (§1), I found something more serious: **the sandbox's shell/git view of the repo and the actual editor-visible files disagree on the content of at least 5 files**, and the commit above captured the shell's (wrong) version.

- `scripts/OrderWiring/OrderWiring.gml` — the real file (confirmed via direct file read) is 125 lines and ends cleanly at `}` closing `RegisterAllOrders()`. The shell/git version is **94 lines**, cut off mid-comment (`// whose Purchase fails is sim` — trails off with no closing punctuation, function body never closes).
- `objects/oUnitControl/Step_0.gml` — real file 146 lines; shell/git version 106 lines, cut off mid-statement.
- `scripts/BuildingHoverScripts/BuildingHoverScripts.gml` — real file 802 lines; shell/git version 781 lines, cut off mid-comment.
- `scripts/TrainingScripts/TrainingScripts.gml` — real file 340 lines; shell/git version 334 lines, cut off mid-statement.
- `scripts/UnitDefinitions/UnitDefinitions.gml` — real file 473 lines; shell/git version 468 lines, cut off mid-string.

I confirmed this is not a one-off race: re-checking the same file a few seconds apart gave the same truncated byte count and the same MD5 each time, and `git show HEAD:<path> | wc -l` matches the shell's short count exactly — i.e. **the commit really did capture the truncated content**, not just my read of the working tree. I cross-checked line counts for the other 19 files touched today (via direct file reads vs. the shell) and found no further discrepancies — this appears to be isolated to these 5 files, not a wholesale corruption.

**Practically:** the actual files on your machine are fine — nothing is lost on disk. The problem is narrower but still real: local commit `d6cee307` now contains truncated (and, for at least `OrderWiring.gml`, syntactically broken — the function never closes) versions of these 5 files. Since the push failed, this hasn't propagated to GitHub. I did not attempt to fix or re-commit anything myself (git-repair beyond step 0 isn't something this pass is scoped to do unattended). Recommend either amending/redoing that commit once you're able to confirm the environment's file sync is caught up, or at minimum diffing `d6cee307` against the real files for those 5 paths before trusting it as a base for anything.

Everything else in this report (syntax/JSDoc/bugs below) was evaluated against the **real, complete files**, not the shell's truncated view — so those findings are trustworthy regardless of the above.

## 1. Syntax errors

None found in the real code. Full pass over every `.gml` file under `scripts/` and `objects/` (121 files, Scribble excluded): brace/paren/bracket balance checked, plus a direct read of every file touched since the last review (24 files — see §4 for the list) and a spot-check of the rest.

The brace-balance script (run via shell) flagged 5 files as imbalanced — these are exactly the 5 files described in §0 above. Reading each one directly confirmed they're fully balanced and well-formed in reality; the imbalance was an artifact of the shell's truncated view, not a real bug. No other file, in the shell's view or the real one, showed any imbalance.

Two long-standing, non-blocking style inconsistencies remain open (carried forward from 07-09/07-11/07-01 reports, not part of today's changes, still legal GML, still not fixed):

- `scripts/Economy/Economy.gml` (lines 35, 91, 135) — mixes parenthesis-less `if` (`if !is_instanceof(...) continue;`, `if _resAmt < _costAmt{`) with the parenthesized style used everywhere else.
- `scripts/Math/Math.gml` line 409 — `ShapeRect.getCenter()` is camelCase; every other static method in the codebase is PascalCase.

## 2. Missing JSDoc

None. Every function/constructor/static method defined or touched in today's 24 changed/new files has a full `/// @function` + `@param`/`@returns` block (checked by direct read, not just regex). Confirmed on: `OrderWiring.gml`, `UnitDefinitions.gml`, `UnitSelection.gml`, `TrainingScripts.gml`, `BuildingHoverScripts.gml`, `HoverCardScripts.gml`, `BlueprintScripts.gml`, `CameraScripts.gml`, `ResourceUIScripts.gml`, `RulerPortraitScripts.gml`, `CastleGarrisonMenu.gml`, `SelectionSummaryMenu.gml`, `DropDownMenuScripts.gml`, `StationScripts.gml`, `UnitStateStation.gml`, plus the touched object event files (no bare functions there — object events call into library functions, consistent with the rest of the codebase).

Combined with the 07-11 report's fresh full-pass finding of 0 missing JSDoc across the other 86 untouched files, the codebase as a whole is fully documented as of tonight.

## 3. Potential problems

### Resolved since the last report (worth knowing about, not action items)

- **The critical selection-pruning crash is fixed.** 07-09/07-11 flagged that a unit dying while selected would crash the next Step or the next order issued to it. `SelectionController.PruneDeadSelected()` now exists (`UnitSelection.gml`) and is called as the very first line of `oUnitControl/Step_0.gml`, before anything else that frame reads `selected`. `Order`'s default `onIssue` and the "defend"/"attack"/"siege" `onIssue` callbacks (`OrderWiring.gml`) also gained `instance_exists` guards. Verified by direct read, not just a comment claiming it's fixed.
- **`oUnitParent/Draw_0.gml`'s `=`-instead-of-`==` typo is fixed.** Open since `CODE_REVIEW_2026-07-01.md`, still open as of 07-11 — now reads `if mask_index == sM_UnitMask{`.
- **`Economy.gml`'s `Purchase` function is correctly spelled** (an older `JSDOC_AUDIT.md`, undated relative to these nightly reports, recorded it as `Puchase` at some point) — confirmed correct in the current file.

### New from tonight's changes

None found. I read all 24 changed/new files in full (not just diffed) looking for scoping bugs, uninitialized reads, reference-sharing hazards, struct-method self-rebinding, off-by-ones, TEAM misuse, and missing `instance_exists`/`variable_instance_exists` guards. A few places read `oUnitStationed.unitData` inside a `with` block without an existence guard (`BuildCastleGarrisonRows` in `CastleGarrisonMenu.gml`, `DeployStationedUnit` in `StationScripts.gml`) — traced this through and it's safe: `UnitBecomeStationed` sets `.team`/`.unitData` on a freshly-created `oUnitStationed` in the same synchronous call that creates it (`instance_create_layer`'s Create event has already run and returned before those assignments execute), so nothing else in this single-threaded engine can ever observe the instance with `unitData` still at its Create-time `undefined` default. Not a bug.

Today's author (per the extensive in-code comments) already self-flagged every real judgment call — e.g. "station" reusing `CastleFrontEdgePoint` since there's no literal "gate" concept, `DeployStationedUnit` picking an arbitrary garrisoned unit when more than one of a type exists, the FSM getting a new additive `"station"` state — these are documented decisions, not bugs, and match CLAUDE.md's "flag load-bearing FSM touches" convention already.

## 4. Patch notes for today's changes

`git log --since="24 hours ago" --stat` shows only tonight's own safety commit (`d6cee307`) as a real commit — same as most recent nights, actual day-to-day work here isn't being committed incrementally, it's accumulating in the working tree and only landing in git via these nightly safety commits. What that commit captured (excluding itself) is a full session's worth of work: a new unit-stationing system (`UnitStateStation.gml`, `StationScripts.gml`, `oUnitStationed`), a castle garrison dropdown (`CastleGarrisonMenu.gml`) with click-to-deploy, a station/deploy gold economy, a new `SelectionSummaryMenu` for multi-unit selection, a shared drop-down-menu sprite system (`DropDownMenuScripts.gml`) retrofitted onto every menu, an animated ruler portrait system (`RulerPortraitScripts.gml`), and a training-building queue progress bar — roughly 20 files, versions `v0.0.3.1` through `v0.0.3.9`.

**Internal patch notes already exist and are thorough — no action needed.** `PATCH_NOTES.md` already has complete, detailed, per-version entries for every one of these changes (`v0.0.3.1` through `v0.0.3.9`, each with Added/Changed/Fixed/Flagged sections naming the real functions and files touched) — written before tonight's run, presumably during the session that did the work. I read through all of them against the actual code and they're accurate. One small staleness note: every entry through `v0.0.3.9` is still labeled "(uncommitted — working tree only, not yet committed)" — that's no longer true as of tonight's safety commit (`d6cee307`, still unpushed). Left as-is since updating those labels wasn't asked for and isn't a code change, but worth knowing the labels are now slightly out of date.

**Public patch notes skipped, per CLAUDE.md's own convention.** CLAUDE.md and `PATCH_NOTES.md`'s own `v0.0.3.0` entry both establish that public/`PUBLIC_PATCH_NOTES.md`-style notes are written "only when explicitly requested," not automatically every session — `PUBLIC_PATCH_NOTES.md` currently only covers through `v0.0.3.0`, and I left it there rather than proactively drafting an entry for `v0.0.3.1`–`3.9` that nobody asked for. Say the word if you'd like one written.
