# Patch Notes

## v0.0.1.0 — 2026-07-01

Early development pass: documentation cleanup, several load-bearing bug fixes, and the first version of the computer opponent.

### Fixed

- **Order menu wouldn't open after selecting units.** `oUnitControl`'s Step event was checking for a menu-opening right-click *after* processing the menu's own Update() in the wrong order, so a click that opened the menu was immediately re-read as a "dismiss" click in the same frame. Reordered so the menu's Update() always sees the state of the mouse from the *start* of the frame.
- **Attack and Siege orders were silently dead code.** Both were wired to the "combat" state's Enter/Step/Exit functions in `oUnitParent`'s state machine setup instead of their own dedicated functions. Units issued "attack" or "siege" were actually just running combat logic. Fixed the state machine wiring so each order runs its own state.
- **Guard waypoint anti-overlap logic was a no-op.** A leftover line in `GuardPickWaypoint` (`scripts/UnitStateGuard`) short-circuited the loop that checks for waypoints already claimed by another guarding ally, so units could pile onto the same spot. Removed the offending line; the claim-check now actually runs.
- **Economy typo:** `Puchase` → `Purchase` in `scripts/Economy`.
- **Defend/Attack target validation was hardcoded to the player's perspective.** The target-eligibility checks for the "Defend Building" and "Attack Building" orders assumed `TEAM.PLAYER` was always "my side." Reworked so the validator receives the issuing side's own team and compares against that instead — same code now works correctly no matter which side (player or AI) issues the order.

### Added

- **First pass at a computer-controlled opponent** (`oAIControl` / `AIBrain`). Runs a decision cycle roughly every 3/4 second; currently masses idle guarding units and sends them to siege the enemy castle once it has enough. Built on the same order-dispatch path (`IssueOrderToUnits`) the player uses, so player and AI units behave identically once an order is issued. This is a scaffold — defending, expanding, and building/unit purchasing are not implemented yet, but the plumbing (perception → decision → dispatch) is proven end to end.
- **`GatherTeamUnits`** — room-wide "every unit on team X" query for AI/high-level decision-making, written so a future fog-of-war visibility filter (once building placement ships) only needs to be added in one place.
- **`_FindNearestEnemy`** — plain nearest-enemy-unit lookup used by the aggro-interrupt check in the Attack state.

### Changed

- **Unified team representation onto the `TEAM` enum.** Team was previously represented two ways — the raw strings `"player"`/`"enemy"` in some places, and the `TEAM.PLAYER`/`TEAM.ENEMY` enum (needed for indexing `global.resources`, since GML arrays can't take string keys) in others. Everything now uses the enum consistently (`oUnitParent`, `oBuildingParent`, `oUnitControl`, `GetEnemyCastle`).
- **Full Feather/JSDoc documentation pass** across every non-vendor Script Asset (140 functions across 16 files). Every function now has `@function`, `@param`, and `@returns` tags so Feather reliably shows hover info while writing code against these libraries. Vendored Scribble library files were left untouched.

### Known issues (flagged, not yet addressed)

- The `"station"` order appears in units' `availableOrders` but is never registered in `RegisterAllOrders()` — picking it currently does nothing.
- A second, unused `UnitOrders` enum (GUARD/DEFEND/ATTACK/SIEGE/STATION) exists alongside the raw order-name strings actually used everywhere — a similar duplication to the team-representation issue that was just resolved, but not yet raised for a decision.

### Build

- Windows export version set to `0.0.1.0` to reflect actual development stage (was defaulted to `1.0.0.0`). Going forward: bump the 4th number for routine small changes; bump the 3rd number when patch notes are requested.
