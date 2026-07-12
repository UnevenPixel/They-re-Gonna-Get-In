# Patch Notes

## v0.0.3.9 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Every drop-down/panel menu (orders, castle garrison, unit selection) now uses the new drop-down sprite set with a title instead of a plain drawn rectangle. Enemy training buildings no longer show their queue or progress.

### Added

- **`DropDownMenuScripts.gml` (new file)** -- shared sprite-based rendering for every drop-down/panel menu, built on 3 new sprites (`sDropDownMenuTop`, `sDropDownMenuMiddle`, `sDropDowmMenuBottom` -- the bottom one's actual asset name has a pre-existing typo, "Dropdowm" not "DropDown"; used verbatim rather than renamed). Per the request:
  - **Title** (`sDropDownMenuTop`, single frame) -- centered text, never hoverable/clickable.
  - **Bottom-most option row** (`sDropDowmMenuBottom`, 2 frames) -- frame 0 normal, frame 1 on hover.
  - **Every option row above it** (`sDropDownMenuMiddle`, 2 frames) -- same frame 0/1 hover convention.
  - All three drawn at 2x scale, stacked seamlessly (title, then middle rows in creation order, then the bottom row last). Option text is left-aligned, 6 native px in from the row's left edge (scaled like everything else -- see file header for that native-vs-scaled call, since the request didn't specify). Exposes shared sizing/hit-test helpers (`DropDownMenuWidth`, `DropDownMenuTitleHeight`, `DropDownMenuRowHeight`, `DropDownMenuTotalHeight`, `DropDownMenuHitTest`) plus draw helpers (`DrawDropDownMenuTitle`, `DrawDropDownMenuRowBackground`, `DropDownMenuRowContentX`) that each menu's own row-content drawing builds on.

### Changed

- **`OrderMenu.gml`** -- title "Orders". Rebuilt on the shared helpers above; retired `ORDER_MENU_ITEM_HEIGHT`/`ORDER_MENU_WIDTH`/`ORDER_MENU_PADDING` (fully superseded, confirmed unused elsewhere) and the old hover highlight rectangle (now the sprite's own hover frame).
- **`CastleGarrisonMenu.gml`** -- title "Castle". Same rebuild; kept its own icon+name+right-aligned-count row content (that part didn't change), retired `CASTLE_MENU_ITEM_HEIGHT`/`CASTLE_MENU_WIDTH`/`CASTLE_MENU_PADDING` (`CASTLE_MENU_ICON_GAP`/`CASTLE_MENU_COUNT_MARGIN` are still meaningful and kept).
- **`SelectionSummaryMenu.gml`** -- title "Selected". Same rebuild; kept its own icon+name+right-aligned-value row content.

### Fixed

- **Enemy training buildings no longer show a queue or progress** -- `DrawTrainingQueueBars` (`TrainingScripts.gml`, the always-on world-space bar) now skips any `oTrainingBuildingParent` whose `team != TEAM.PLAYER`; this was previously flagged in its own doc comment as an intentional "not team-restricted... flag if enemy queues shouldn't be passively visible" -- now flipped per this request. `BuildingHoverExtras.Layout`'s `showQueueRow` (`BuildingHoverScripts.gml`, the hover-card queue row) now additionally requires `_team == TEAM.PLAYER` -- `_team` here is the HOVERED BUILDING's own team (confirmed via the call site, `BuildingHoverController.Step`, which passes `hoverTarget.team`), so this correctly hides the row only for enemy buildings, not for the player's own. Neither buildings' name/description/health/cost hover content changed -- only the queue-specific row/bar.

### Build

- Windows export version bumped `0.0.3.8` → `0.0.3.9` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.8 — 2026-07-12 (uncommitted — working tree only, not yet committed)

A new top-left panel appears whenever 2+ units are selected -- grouped by type at first, drilling down to individual units (and finally a single unit) as the player clicks through it. Also fixes a click-passthrough gap that would have broken it.

### Added

- **`SelectionSummaryMenu` (new file, `SelectionSummaryMenu.gml`)** -- a top-left panel (same corner `UnitSelectHoverController` uses for the single-unit case, and mutually exclusive with it) shown whenever `selectionController.selected` has 2+ units. Visual style/row layout deliberately reuses `CastleGarrisonMenu`'s macros (`CASTLE_MENU_*`) rather than redeclaring near-duplicates, per "similar visual to the castle dropdown." Unlike `OrderMenu`/`CastleGarrisonMenu`, there's no `Open()`/`Close()` -- it's a passive panel recomputed fresh every Step from the current selection, same architecture as `UnitSelectHoverController`.
  - **GROUPED mode** -- selection spans 2+ distinct unit types: one row per type (icon, name, "x#" count of how many of that type are selected).
  - **INDIVIDUAL mode** -- selection is 2+ units that all share ONE type: one row per actual unit instance (icon/name repeat per row; the row's value column shows that unit's current/max HP instead of a count, since "x#" doesn't mean anything per-unit).
  - **Hover** -- a grouped row shows the GENERAL unit hover card (`ShowUnitHoverCard` with no live instance -- max HP only, the same "no specific instance" treatment `UnitHoverExtras` already uses for the blueprint-UI/placed-training-building contexts), per the request: "no specific health value, so use max health." An individual row shows the DETAILED card (the real instance -- exact remaining HP), identical to `UnitSelectHoverController`'s single-selected treatment. Drawn immediately to the panel's right.
  - **Click** -- a grouped row narrows `selectionController.selected` down to the CURRENTLY SELECTED units of that type only (not every unit of that type on the map -- the row's own count is exactly that subset, so narrowing to it keeps things consistent), which flips the panel into individual mode next frame. An individual row replaces the selection with JUST that one unit, which hides this panel and shows `UnitSelectHoverController`'s single-unit card instead -- with no one-frame lag, since `SelectionSummaryMenu.Step()` runs before `unitSelectHoverController.Step()` in the same `Step` event.

### Fixed

- **Click-passthrough gap**: neither `CastleGarrisonMenu` nor the new `SelectionSummaryMenu` suppressed `oUnitControl`'s room-space left-click handling, so clicking a row would ALSO be read as a world click by the castle/training/blueprint/drag-select logic later in the same `Step` -- for `SelectionSummaryMenu` this would have immediately clobbered whatever selection the row click just set (a drag-select starting on the same press would overwrite it moments later on release). Both menus gained a `consumedClick` flag, checked by `oUnitControl/Step_0.gml` before its left-click block runs. Scoped differently per menu's own behavior: `CastleGarrisonMenu.consumedClick` is true for ANY left click while it's open (it's an explicit, modal-ish dropdown the player opened -- even a dismiss-elsewhere click shouldn't also act on the world); `SelectionSummaryMenu.consumedClick` is true ONLY when a click lands ON a row (it's a passive, always-visible-when-applicable panel -- clicks elsewhere must keep working normally, e.g. picking a different unit or starting a fresh drag). This was a latent gap in `CastleGarrisonMenu` since last pass too (deploying doesn't touch selection, so it never surfaced there) -- fixed for both while touching this code path.

### Build

- Windows export version bumped `0.0.3.7` → `0.0.3.8` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.7 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Stationing and deploying now cost gold, and the castle garrison dropdown's rows are clickable -- clicking one deploys a unit of that type back onto the battlefield.

### Added

- **Click-to-deploy on the castle garrison dropdown** (`CastleGarrisonMenu.gml`) -- clicking a row now deploys ONE unit of that row's type via the new `DeployStationedUnit(_team, _unitType)` (`StationScripts.gml`). `CastleGarrisonRow` gained a `unitType` field (undefined on the "--" placeholder row, so clicking it is a safe no-op); `CastleGarrisonMenu.Update()` now returns the clicked row's `unitType` (mirrors `OrderMenu.Update()`'s "returns what was clicked" convention) and gained the same hover-highlight `Draw()` treatment `OrderMenu` already has. Wired from `oUnitControl/Step_0.gml`.
- **`DeployStationedUnit(_team, _unitType)`** (new, `StationScripts.gml`) -- charges `GetUnitStationCost` (below) via `Purchase` BEFORE anything else happens, so an unaffordable deploy is a pure no-op. If affordable: finds one live `oUnitStationed` of that type belonging to `_team` (arbitrary pick if more than one is garrisoned -- see Flagged below), spawns a fresh live instance just outside the team's castle (`StationDeploySpawnPoint`, below), overrides its team (same override pattern `TrainingSpawnUnit`/`StationSpawnDirectly` use, including the stale-`guardRect` correction), swaps in the stationed unit's preserved `UnitDataBlock` (so `damageTaken`/`statusEffects` survive the round trip), and re-runs `UnitApplyDefinition` -- the exact redeploy sequence already documented on `UnitDataBlock` (`UnitScripts.gml`). Destroys the `oUnitStationed`. Defaults to `"guard"` (the fsm's own starting state, untouched here).
- **`GetUnitStationCost(_unitType)`** (new, `StationScripts.gml`) -- wraps `UnitDefinition.stationCost` (a flat gold amount that already existed as unit-hover-card display data, added 2026-07-11 from the "Project Azurite Data Sheets") into a spendable `Cost` struct (`Economy.gml`). Shared by both directions -- station and deploy are priced identically, per that field's own doc comment ("Gold cost to station/deploy this unit type").
- **`StationDeploySpawnPoint(_castle)`** (new, `StationScripts.gml`) -- a point just outside the castle's front edge (same side `CastleFrontEdgePoint` picks) with a little random vertical jitter, mirroring `TrainingGetSpawnPoint`'s "just outside, don't stack back-to-back spawns" reasoning.

### Changed

- **The `"station"` order now actually costs gold** (`OrderWiring.gml`) -- charges each unit's `GetUnitStationCost` via `Purchase` before dispatching it into the `"station"` FSM state; a unit that can't be afforded is simply skipped (not sent marching, nothing spent for it).
- **Issuing `"station"` to multiple selected units sorts them CHEAPEST FIRST** before the affordability pass above, per the request: "If multiple units are selected to station, and the player can't afford to station all of them... selecting the cheapest options to station, and do as many as the player can afford." The affordability loop skips (rather than stops at) the first unaffordable unit and keeps checking the rest -- see Flagged below for why.
- **`UnitDefinition.stationCost`'s doc comment** (`UnitDefinitions.gml`) updated -- it previously said this field was purely informational display data that "nothing deducts gold or gates a station action on it"; that's no longer true as of this pass, so the comment now points at `GetUnitStationCost`/`DeployStationedUnit`/the `"station"` order instead of asserting it's inert.

### Flagged

- **The cheapest-first affordability loop skips-and-continues rather than stopping at the first unaffordable unit.** Today's `stationCost` is gold-only, so once the cheapest remaining unit can't be afforded, nothing pricier after it can either -- stopping outright would behave identically right now. Chose skip-and-continue anyway so this stays correct if `stationCost` ever grows into a multi-resource `Cost` (e.g. a unit that's cheap in gold but expensive in iron shouldn't necessarily block a later unit that's expensive in gold but free in iron).
- **`DeployStationedUnit` picks whichever matching `oUnitStationed` instance is found first** when more than one of the same type is garrisoned -- GameMaker's `with` iteration order isn't a meaningful "oldest"/"healthiest" pick, just "any one of them." A request that cares which specific one gets redeployed (e.g. always the least-damaged) would need a different selection rule than what's built here.
- **A deployed unit defaults to `"guard"`** (the fsm's own built-in starting state, untouched by `DeployStationedUnit`) rather than any more specific order -- a deployed unit has no training-building context to default to `"defend"` against the way `TrainingSpawnUnit`'s units do. Judgment call, not an explicit spec answer.
- **`StationDeploySpawnPoint` re-derives which side of the castle is "front"** instead of calling `CastleFrontEdgePoint` -- that function clamps toward a caller position (there's no unit marching toward the castle here, just a castle to spawn just outside of) and doesn't expose which side it picked for the "push further outward" math to reuse. Small (~10-line) duplication of that function's side-selection logic; flagging in case a future change to one needs to be mirrored in the other.

### Build

- Windows export version bumped `0.0.3.6` → `0.0.3.7` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.6 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Stationing and deploying units: a new "station" order walks a unit home and garrisons it invisibly at the castle; training buildings on an inside plot now garrison units directly instead of spawning them live; and a new dropdown on the castle wall lists what's currently garrisoned.

### Added

- **"station" order + `Station_Enter`/`Station_Step`** (new file, `UnitStateStation.gml`, registered as a new `"station"` state on every unit's `fsm`, `oUnitParent/Create_0.gml`) -- walks the unit to its OWN team's castle front edge (`CastleFrontEdgePoint`, `CastleScripts.gml` -- the same point `siege` already marches units toward against the ENEMY castle; there's no separate literal "gate" concept anywhere in the project, see Flagged below), same longer obstacle-avoidance feeler `Siege_Step`'s advance phase uses (`120`, vs. the default `80`) since this can be just as long a march. On arrival (within `STATION_GATE_REACH`, `12`px, mirrors `DEFEND_WAYPOINT_REACH`), hands off to `UnitBecomeStationed`.
- **`StationScripts.gml` (new file)**:
  - `UnitBecomeStationed(_unit)` -- creates an `oUnitStationed` at the unit's team's castle corner, hands it the unit's EXISTING `UnitDataBlock` as-is (preserving `damageTaken`/`statusEffects`/`unitType` per unit, not just an aggregate count -- per the pre-existing doc comment on `UnitDataBlock`, `UnitScripts.gml`, which already specified this exact design), then destroys the live unit directly (not through `ApplyDamage` -- confirmed `STRATEGIC_XP_LOSE_UNIT` only fires from there and `oUnitParent` has no Destroy event, so this can't misfire a "lost a unit" penalty).
  - `StationCastleCorner(_castle)` -- the fixed storage point, `(bbox_left, bbox_top)`.
  - `StationSpawnDirectly(_team, _unitType)` -- builds a stationed unit for `_team` without ever putting a live one on the battlefield; used by the inside-plot training branch below.
- **`oUnitStationed` (new object)** -- no sprite, `visible = false`, no Step/Draw, holds nothing but `team` + the handed-over `unitData`. Per the request: "Stationed units (for now) just need to be stored at the corner of the castle with no rendering."
- **Training buildings on an inside plot now build stationed units directly** instead of live ones (`TrainingSpawnUnit`, `TrainingScripts.gml`, new early branch checking `_building.inside`, calling `StationSpawnDirectly`) -- per the request: "Any training buildings that builds a unit when on an inside plot will immediately build a stationed unit instead." Deliberately does NOT award `STRATEGIC_XP_FIRST_DEPLOYMENT` for this branch (see Flagged below).
  - `_building.inside` is new: `TryPlaceBlueprint` (`BlueprintScripts.gml`) now copies the target plot's own `inside` flag onto the spawned building instance. `oBuildingParent/Create_0.gml` also gained a safe `inside = false` default (same "Create sets a placeholder" pattern already used for `maxHealth`/`damageTaken` there) so a building placed directly in the room editor -- never touching `TryPlaceBlueprint` -- doesn't crash `TrainingSpawnUnit`'s new check on an undefined variable.
- **Castle garrison dropdown** (new file, `CastleGarrisonMenu.gml`) -- left-clicking the player's own castle wall (`oPlayerCastle`, excluding inside plots -- see `oUnitControl/Step_0.gml`) opens a GUI-space dropdown listing every stationed unit type: icon, name, and "x#" count, left to right, one row per type; shows a single "--" row if nothing's garrisoned. Structurally mirrors `OrderMenu.gml` (`Open`/`Close`/`Update`/`Draw`, screen-edge containment) but needed its own row renderer for the icon+name+count layout. View-only for now (see Flagged below). Wired into `oUnitControl` (`Create_0.gml`/`Step_0.gml`/`Draw_64.gml`).

### Changed

- **`OrderWiring.gml`'s `"station"` order** -- replaced its intentional no-op stub (left in place since stationing wasn't designed yet) with real dispatch: `fsm.ChangeState("station")` per selected unit, same dead-unit-guard pattern as `"defend"`/`"attack"`/`"siege"`.

### Flagged

- **"Castle gate" doesn't exist as a literal concept anywhere in the code** (confirmed via project-wide search) -- reused `CastleFrontEdgePoint` as the walk-target, the same point `siege` already uses against the enemy castle. Worth noting `oUnitParent/Create_0.gml` already had a comment anticipating almost this exact wording ("whatever redeploys a stationed unit back out through the castle gate"), which supports the interpretation but isn't a confirmed spec answer.
- **This pass adds a new state (`"station"`) to the same `fsm` chain as `guard`/`defend`/`combat`/`attack`/`siege`** (`oUnitParent/Create_0.gml`) -- per CLAUDE.md, flagging any touch to that wiring. The change is purely additive (a new `.AddState(...)` appended to the existing chain); no other state's wiring was touched.
- **`oUnitStationed`'s storage position** (`StationCastleCorner`) is just the castle's `(bbox_left, bbox_top)` corner -- arbitrary, since the object never renders. Only matters if a future redeploy feature uses it as a spawn point.
- **Inside-plot-trained (auto-stationed) units skip `STRATEGIC_XP_FIRST_DEPLOYMENT`** -- reasoning: that XP is for a unit's first appearance ON the battlefield, which a directly-stationed unit never has. Judgment call, not an explicit spec answer -- easy to reverse if "deployment" was meant more loosely.
- **The garrison dropdown is view-only and player-castle-only** -- the request described the listing but not an interaction, so clicking a row just dismisses the menu like clicking anywhere else (no redeploy action yet); restricted to `oPlayerCastle` since nothing asked for an enemy-castle equivalent. One related edge case: clicking the castle wall again WHILE the dropdown is already open dismisses-then-immediately-reopens it that same frame rather than toggling closed (same class of same-frame double-click-processing `OrderMenu`'s own right-click-reopen edge case already has) -- clicking anywhere else does correctly dismiss it.

### Build

- Windows export version bumped `0.0.3.5` → `0.0.3.6` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.5 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Follow-up polish on last pass's training-building hover work: correct icon, a truly centered progress bar, and the paired unit card now always sits on the building card's right with its training cost always shown.

### Changed

- **Queue row icon** (`BuildingHoverExtras`, `BuildingHoverScripts.gml`): now uses `UnitDefinition.icon` (the small inline icon, e.g. `sPeasantIcon`, 8x8 middle-center anchored) instead of `smallSprite` (the bigger, bottom-anchored Item/Unit Window sprite) -- was `smallSprite` last pass, corrected per request. This also fixes an unflagged bug from that pass: `smallSprite`'s bottom-center anchor needed a vertical re-centering offset (same as the icon row's `itemIconOffsetY`) that the queue row never applied, so it would have drawn slightly off-center; `icon`'s middle-center anchor needs no such offset.
- **Queue progress bar is now centered on the card's full width**, not sized around the time-remaining text. Its left edge sits a fixed offset in from the card's left edge (margin + icon + gap + count text + gap); its right edge now mirrors that SAME offset in from the card's right edge, instead of being positioned to leave just enough room for the time text. The time-remaining text now trails the bar's right edge (switched from right-aligned-on-the-row to left-aligned-after-the-bar) rather than pinning to the row's fixed right edge.
- **The training building's paired unit card now always sits on the building card's right**, regardless of cursor position -- `PositionHoverCardPair` (`HoverCardScripts.gml`) gained a `_secondaryAlwaysRight` parameter (default `false`, every other caller unaffected); `BuildingHoverController.Step` passes `true`. Tradeoff worth flagging: the overall pair still anchors away from the cursor and clamps to the screen edges as before, but when the cursor's in the right half of the screen, the BUILDING card is no longer guaranteed nearest the cursor in this mode (the unit card is, since it's forced to the building card's right while the pair's right edge still anchors near the cursor) -- accepted since "always on the right" was explicit.
- **The paired unit card's cost-to-produce row is now always shown** for placed training buildings (was blueprint-only). Even though the building itself is already placed, the unit's training cost is still directly relevant -- it's exactly what `TrainingTryQueueUnit` (`TrainingScripts.gml`) will spend the next time a unit is queued.

### Build

- Windows export version bumped `0.0.3.4` → `0.0.3.5` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.4 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Training buildings now show an always-on queue progress bar above the world, and switch to a second sprite frame while actively training.

### Added

- **`WorldToGui(_x, _y)`** (new, `CameraScripts.gml`) -- converts a room-space coordinate to its current on-screen GUI-space equivalent, accounting for view camera 0's pan position. Needed for any room-space element that has to be drawn from a Draw GUI event so it renders above every room-space Draw call (units, particles, other buildings) regardless of instance depth -- Draw GUI always runs after every room-layer Draw event.
- **`DrawTrainingQueueBars()`** (new, `TrainingScripts.gml`, called once per Draw GUI event from `oUnitControl/Draw_64.gml`) -- a 1px-tall (exactly 1 on-screen pixel, independent of camera zoom) bar drawn 2px below every live training building's `bbox_bottom`, spanning its bbox width. Black background, filled left-to-right in `HOVER_CARD_TEXT_COLOR` by `trainProgress / trainTime` -- same fill convention as last pass's hover-card queue row, just always-on instead of hover-gated, so there's a signal even when no hover card is showing. Routed through `WorldToGui` and drawn from Draw GUI per the request, so it stays on top of units/particles/other buildings regardless of world-space depth. Not team-restricted -- matches `BuildingHoverController`'s existing "informational, not ownership-gated" precedent; flag if enemy queues shouldn't be passively visible like this.

### Changed

- **`TrainingUpdateQueue`** (`TrainingScripts.gml`) now sets the building's `image_index` -- frame 1 while `trainQueue > 0`, frame 0 otherwise. Placeholder ambient signal ahead of a real training animation, per the request; every training sprite gets pointed at frame 1 regardless of whether it's actually been authored with a second frame yet (GameMaker wraps `image_index` via `mod(image_index, image_number)` for default instance drawing, so this is harmless on sprites that don't have one).

### Deferred (per request)

- **Per-building training particle effects** -- explicitly held off; each training building will eventually get its own distinct effect, planned as a separate pass.

### Build

- Windows export version bumped `0.0.3.3` → `0.0.3.4` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.3 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Fixed a pre-existing missing-argument bug in the UI bar's background draws; placed training buildings now show a live queue/progress readout in their hover card.

### Fixed

- **`oUnitControl/Draw_64.gml`'s `sMainUIBarBottom`/`sUISpellsCloth` `draw_sprite_ext` calls were missing their rotation argument** (8 args where 9 are required) -- flagged last pass, fixed now. Added `0` for `rot` to both, matching the already-correct `sRulerBar` call on the line above them.

### Added

- **Placed training buildings now show a queue row in their hover card**, in the same bottom slot the blueprint cost row occupies (`BuildingHoverExtras`, `BuildingHoverScripts.gml`) -- the trained unit's small icon + how many are currently queued (bottom-left), a progress bar toward the next completion (black background, filled in `HOVER_CARD_TEXT_COLOR` -- a plain drawn rectangle, not a sprite/Scribble element), and the seconds remaining until that completion (right edge, ceil'd, "-" when nothing's queued). Reads `trainQueue`/`trainProgress`/`trainTime` straight off the live instance. Mutually exclusive with the blueprint cost row (one's blueprint-only, the other's placed-training-only) -- resource buildings and blueprints are unaffected.

### Investigated, not changed

- **Unit-training queuing already existed** (`TrainingScripts.gml`: `TrainingTryQueueUnit`/`TrainingUpdateQueue`, wired since earlier sessions) -- confirmed it already does everything the request asked for: queuing spends the cost immediately (`Purchase(_building.trainCost, _team)` inside `TrainingTryQueueUnit`, before the queue increments), and both the per-type cap (`TrainingTypeLimit`) and the army-wide cap (`global.armyLimit`) are checked against existing units PLUS everything queued across EVERY training building the team owns (`TrainingQueuedCountForType`/`TrainingQueuedCountAll`), not just the building being clicked. Nothing new needed here.

### Build

- Windows export version bumped `0.0.3.2` → `0.0.3.3` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.2 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Game-wide text now matches the hover-data color; the resource bar switched to its dedicated font; and the first animated ruler portrait (Conelius) is live on the UI bar.

### Added

- **`RulerPortraitScripts.gml` (new file)** -- animated ruler portrait system. A ruler's portrait is a single sprite strip; each animation is a data-described contiguous frame range (`RulerAnimationDefinition`: name, startIndex, frameCount, startFacing, endFacing, isIdle), grouped into one `RulerPortraitDefinition` per ruler (sprite + animation list + playback speed), registered by string key (`RegisterRulerPortrait`/`GetRulerPortraitDefinition`/`RegisterAllRulerPortraits`) the same way `Order`/`UnitDefinition`/`BuildingDefinition` are. `RulerPortraitController` is the live per-instance state machine: plays a clip to completion, rests on whichever idle frame (Left/Right) matches the clip's end facing for a random 2-5 sec wait, then picks a new clip at random from whatever's legal to start given the current facing -- exactly the behavior requested, and fully data-driven so a future ruler needs only a new definition, not new controller code.
  - **`FACING` enum** (new, `Enumerators.gml`) -- `LEFT`/`RIGHT`, used by animation definitions to gate which clips can start from which facing.
  - **Conelius registered** (`sConeliusPortrait`, 30 frames / 6 clips: Idle Left, Blink Left to Right, Idle Right, Blink Right, Mustache Wiggle, Looking Around) -- only "Blink Left to Right" starts from Left, so from his Idle Left resting pose the only thing that can ever play is that one clip; everything else waits for "Looking Around" to bring him back around to Left first, matching the request's example exactly.
  - **`global.selectedRuler`** (new global, set in `oGameControl`'s Create event) -- hardcoded to `"conelius"` for now, no character-select flow exists yet.
  - Wired into `oUnitControl`: `rulerPortraitController` created in `Create_0.gml`, stepped in `Step_0.gml`, drawn in `Draw_64.gml` at `(27, 1080)` scale 2x (bottom-left anchored, matching the portrait sprite's own origin), on top of the existing `sRulerBar` background sprite.
  - **`RulerPortraitScripts.md` (new file, alongside the script)** -- Notion-compatible API doc, per CLAUDE.md's standing per-library documentation requirement. First library this session to actually get one; every earlier library still lacks this doc -- flagging the backlog, not backfilling it here unasked.

### Changed

- **Game text now matches `HOVER_CARD_TEXT_COLOR`** (the tan `F1DEB6` every hover-data card already uses) instead of `c_white`, in: the resource bar's counts (`DrawResourceBar`, `ResourceUIScripts.gml`), the order menu's item labels (`OrderMenu.gml`), a blueprint slot's stack-count number (`BlueprintScripts.gml`), and the "Select target for: ..." targeting-cursor label (`UnitSelection.gml`). Per this session's scoping discussion: the AI debug overlay (`oAIControl`'s "AI State:" text), the Fate Engine drum test harness, and the pre-alpha disclaimer splash screen were deliberately left alone -- dev-only or a special-case splash screen, not ongoing player-facing UI.
- **`DrawResourceBar`** (`ResourceUIScripts.gml`) now draws its resource-count text in `fntResource` instead of the default GML font -- explicitly requested. Resets to the default font (`draw_set_font(-1)`) after, since nothing else in this project calls `draw_set_font` and a lingering font change would otherwise leak into every draw_text call later in the same Draw GUI event.

### Noted, not acted on

- **`oUnitControl/Draw_64.gml` line 2, `draw_sprite_ext(sMainUIBarBottom,0,0,1080,2,2,c_white,1);`, appears to be missing its rotation argument** -- 8 arguments where `draw_sprite_ext` needs 9 (sprite, subimg, x, y, xscale, yscale, rot, colour, alpha). As written, `c_white` lands in the `rot` slot and `1` lands in `colour`, with `alpha` unsupplied. Stumbled onto this while wiring the ruler portrait draw call in the same file -- pre-existing, unrelated to this pass's work, not fixed here per CLAUDE.md ("don't refactor unrelated legacy code unless asked"). Worth a look; if the bottom bar renders correctly today despite this, GameMaker may be more lenient about missing trailing built-in-function arguments than expected.

### Build

- Windows export version bumped `0.0.3.1` → `0.0.3.2` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.1 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Corrections from the nightly codebase scan (`NIGHTLY_REVIEW_2026-07-09.md`) -- one real crash fixed, one flagged finding turned out to be stale/inaccurate and was left alone, two trivial cleanups applied.

### Fixed

- **Selected units weren't pruned when they died, crashing the next Step or the next order issued to them** (§3.1, critical). `ApplyDamage` (`UnitCombatHelpers.gml`) destroys units directly with no hook back into `SelectionController.selected`, so a selected unit dying in combat (normal RTS occurrence) would crash on the very next Step via `UnitSelectHoverController.Step` reading the freed instance, or immediately on issuing any order (guard/defend/attack/siege) to a selection containing it.
  - **`SelectionController.PruneDeadSelected()`** (new, `UnitSelection.gml`) -- filters dead instances out of `selected`. Called once per Step from `oUnitControl/Step_0.gml`, as the very first line, before anything else that frame reads `selected` (order menu, `IssueOrder`, the unit-select hover card).
  - **`instance_exists` guards added inside the order-dispatch loops themselves** -- `Order`'s default `onIssue` (`UnitSelection.gml`) and the "defend"/"attack"/"siege" `onIssue` callbacks (`OrderWiring.gml`). This covers `IssueOrderToUnits`'s OTHER caller (the AI controller), which doesn't go through `SelectionController`/`PruneDeadSelected` at all, and closes the gap for the instant between the per-Step prune and the callback actually running.
  - **FLAG per CLAUDE.md ("flag before touching FSM/state wiring for guard, defend, combat, attack, siege"):** this touches the order-dispatch loops that call `fsm.ChangeState(...)` for guard/defend/attack/siege. No state's `Enter`/`Step`/`Exit` logic itself was touched -- only an early-`continue` guard added around each loop's per-unit body -- but it's adjacent enough to the load-bearing FSM wiring to call out explicitly rather than let it pass silently.
- **`oUnitParent/Draw_0.gml` used `=` instead of `==`** (§3.3, minor; open since `CODE_REVIEW_2026-07-01.md`). `if mask_index = sM_UnitMask{` → `if mask_index == sM_UnitMask{`. Legal GML either way (bare `=` in a condition reads as equality), behavior was already correct -- purely a readability/consistency fix, now matches every other comparison in the codebase.
- **`oUnitParent/Create_0.gml` set two dead fields, `pos` and `moveVec`** (§3.4, minor). Removed both lines. Re-confirmed via project-wide search that nothing reads `unit.pos` or `unit.moveVec` -- all real position/velocity state lives on `unit.agent.pos` (the `SteeringAgent`); these were a future-reader trap, not read anywhere.

### Investigated, not fixed

- **§3.2 (moderate), `oBuildingPlot`'s `image_index`:** the nightly report describes this as a stale-Object-Property-default bug in `Create_0.gml` with no Step event to correct it. That description doesn't match the current code -- `oBuildingPlot/Create_0.gml` is empty, and `image_index = (!blocked) + (!inside)` lives in `Step_0.gml`, recomputing every frame (confirmed against this file's own history: this has been the case since v0.0.2.20, 2026-07-05). The report's finding here appears to be inaccurate/stale, so no fix was made against it.
  - The REAL, still-open issue in this formula was already identified and investigated on 2026-07-05 (see that date's patch notes, "Investigated (not yet fixed -- pending design confirmation)"): the formula only produces 3 output values for 4 possible `(blocked, inside)` combinations, so an unblocked INSIDE plot and a blocked OUTSIDE plot render identically. That was deliberately left unfixed pending a design answer for what `sPlot`'s 3 frames are actually meant to represent -- still true today, still needs that input before it can be touched.

### Noted, not acted on (style only, not counted among the report's "4 potential problems")

- `scripts/Economy/Economy.gml` mixes parenthesis-less `if` conditions with parenthesized ones used everywhere else in the file. Not touched -- fixing pure style on working legacy code wasn't requested.
- `scripts/Math/Math.gml` line 409, `ShapeRect.getCenter()` is camelCase against every other static method's PascalCase convention (should probably be `GetCenter()`). Not touched for the same reason -- flagging here in case it's worth a deliberate rename pass later.
- The nightly report separately flags that `NIGHTLY_REVIEW_2026-07-07.md` and `-08.md` are both missing despite a "Review 2026-07-07 Safety Commit" existing in git history -- suggests the scheduled task didn't complete a full run on at least one of those two nights. Nothing to fix in the codebase; surfacing in case the scheduling harness itself needs a look.

### Build

- Windows export version bumped `0.0.3.0` → `0.0.3.1` — 4th-digit bump, same convention as every routine fix pass.

## v0.0.3.0 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Version bump only — player-facing patch notes requested, covering everything since v0.0.2.0. Per the 3rd-digit-bump-on-requested-patch-notes convention (see v0.0.1.0/v0.0.2.10's Build notes).

### Added

- **`PUBLIC_PATCH_NOTES.md` (new file, repo root)** — the launch-title-facing summary covering v0.0.2.0 through v0.0.2.51, organized by player-visible category (Build & Economy, Combat, The Computer Opponent, Interface & Info) rather than chronologically. Written from this file's existing entries; every internal system/function/asset name was translated to its player-facing effect, per CLAUDE.md's public-notes convention. Purely additive/no-op for the game itself.

### Build

- Windows export version bumped `0.0.2.51` → `0.0.3.0` — 3rd-digit bump (patch notes explicitly requested this time, unlike the routine 4th-digit bumps every prior entry back to v0.0.2.1 used).

## v0.0.2.51 — 2026-07-11 (uncommitted — working tree only, not yet committed)

New unit hover card -- a second, paired card showing a trained unit type's own stats/passives, alongside a training building's blueprint/placed-building card, or standalone in the top-left corner when a single unit is selected.

### Added

- **`UnitHoverScripts.gml` (new file)** -- the unit hover card, shown in 3 contexts:
  - Paired with a training building's blueprint-UI card (`BlueprintController.UpdateHover`) -- max HP only, WITH a cost-to-produce row along the bottom.
  - Paired with a training building's placed-instance hover card (`BuildingHoverController.Step`) -- max HP only, no cost row (nothing left to produce).
  - Standalone, fixed in the GUI's top-left corner, whenever exactly one unit is selected (new `UnitSelectHoverController`, wired into `oUnitControl`) -- shows that unit's own live remaining/max HP, no cost row, appears/disappears instantly with selection state (no dwell or fade -- it's tied to a deliberate player action, not a hover).
  - Layout (shared by all 3): the unit's full-size sprite (`UnitDefinition.sprites.idle`, NOT the smaller `smallSprite`) centered inside an `sHoverCardBuildingWindow`-sized box using the same bottom-anchor centering math as the existing Item/Unit Window; literal "HP: X" / "DMG: Y" text lines beside the box; the "Deployed Effect" passive description as the card's main body; and, in the card's usual flavor-text position, "Station/Deploy Cost: [gold icon]\<amount\>" followed by the "Stationed Effect" passive description -- rendered in the normal (non-italic) font rather than the usual italic flavor font, per the request.
- **`UnitDefinition.stationCost` field** (`UnitDefinitions.gml`) -- Gold cost to station/deploy each unit, per the "Project Azurite Data Sheets" (2026-07-03) column that was previously flagged as having no home in this struct. Real values supplied directly by the user this pass: Peasant 20, Bomb Goblin 15, Mud Golem 25, Soldier 30, Archer 15, Knight 50. Still purely display data for the hover card above -- nothing deducts gold or gates a station action on it yet (no station/deploy economy system exists).
- **`HoverCard.Show()` gained an optional trailing `_flavorFont` param** (`HoverCardScripts.gml`) -- defaults to the existing italic `HOVER_CARD_FLAVOR_FONT`, so every existing caller is unaffected; the unit hover card is the first to pass `HOVER_CARD_BODY_FONT` instead, repurposing the flavor window for non-italic content.
- **`PositionHoverCardPair(_mx, _my, _primaryCard, _secondaryCard, _cardGap)`** (`HoverCardScripts.gml`) -- positions a primary card and an optional paired secondary card as one anchored group: the quadrant-flip and screen-edge clamp are computed against their COMBINED width/height, per the request ("anchoring... should be in relation to both cards, not just the core building card"), rather than clamping each independently in a way that could separate them. The primary card always sits nearest the cursor; the secondary extends further away. Passing `noone` for the secondary reproduces the exact single-card math every hover controller used before this pass -- `BuildingHoverController.Step` and `BlueprintController.UpdateHover` both now route through this shared function instead of each keeping their own copy of the old anchor/clamp math.

### Assumptions / scope boundaries (flag if wrong)

- **"HP"/"DMG" are drawn as literal text labels**, not icons like `BuildingHoverExtras`' `sUIHeart`/`sUIHammer` -- the request explicitly wrote them as text ("written as HP and DMG").
- **The unit card's stat text is vertically centered against the image box**, and the box sits flush against the card's left margin (mirroring the building icon row's position) -- neither exact alignment was specified, flagging for a visual sanity check in-engine.
- **The gap between the two paired cards (`HOVER_CARD_PAIR_GAP`, 8px) matches the existing mouse-to-card gap** (`PLOT_HOVER_CURSOR_GAP`) by coincidence, not because they're the same concept -- kept as separate macros in case they should diverge later.
- **The single-unit-selected card ignores team** -- it shows for any selected unit regardless of TEAM.PLAYER/TEAM.ENEMY, matching this project's existing "hover data is informational, not ownership-gated" precedent (BuildingHoverController). Flag if enemy units shouldn't reveal this when selected (note: today only the player's own units are selectable at all, per `SelectionController(oUnitParent, TEAM.PLAYER)` in `oUnitControl/Create_0.gml`, so this is currently moot in practice).
- **Discovered while implementing this (unrelated to this feature): `UnitDefinitions.gml` currently sets `palette: sMudGolemPallete` for Mud Golem**, contradicting the v0.0.2.49/v0.0.2.50 patch notes' statement that "only Mud Golem doesn't have a Pallete sprite yet." The sprite now exists on disk and is already wired in -- the patch notes text is simply stale, no code fix needed. Flagging so the discrepancy doesn't cause confusion later.

### Build

- Windows export version bumped `0.0.2.50` → `0.0.2.51` -- 4th-digit bump, same convention as last time.

## v0.0.2.50 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Fixed AI/enemy units not recoloring at all under `shPaletteSwap` (v0.0.2.49).

### Fixed

- **`PaletteSwapDrawUnit` (`PaletteSwapScripts.gml`) was reading the wrong elements out of `sprite_get_uvs()`'s return array.** The original code assumed an 8-element TL/TR/BR/BL corner layout and read indices `[4]`/`[5]` as the bottom-right UV corner. GameMaker's actual documented layout is a 4-element `(left, top, right, bottom)` rect at indices `[0..3]` — indices `[4..7]` are unrelated trim-crop metadata (pixels trimmed from the sprite's left/top edge, plus width/height fractions retained on the page), not a second corner. Since this project's palette sprites have no transparent margin to trim, `[4]`/`[5]` were simply `0` for every unit, collapsing `u_paletteFromRect`/`u_paletteToRect` to `(u0, v0, 0, 0)` — the shader was sampling far outside each sprite's actual region on the texture page, so the from-color read at every row was garbage and never matched a drawn pixel closely enough to trigger a swap. Net effect: the shader ran every frame but silently did nothing, which is why AI/enemy units looked completely unrecolored. Fixed by reading indices `[2]`/`[3]` (the real right/bottom) instead. Both `PaletteSwapScripts.gml` and `shPaletteSwap.fsh`'s header comment are corrected and now document the real `sprite_get_uvs()` layout so this isn't re-introduced.

### Assumptions / scope boundaries (flag if wrong)

- **`sSoldierPallete` and `sKnightPallete` use byte-for-byte identical source images** (same two PNG files, verified via direct pixel inspection) — Soldier and Knight currently recolor to the exact same replacement palette. This predates this fix and wasn't introduced by it; flagging in case it's an asset-authoring copy/paste that should actually be two distinct palettes.

### Build

- Windows export version bumped `0.0.2.49` → `0.0.2.50` — 4th-digit bump, same convention as last time.

## v0.0.2.49 — 2026-07-10 (uncommitted — working tree only, not yet committed)

New `shPaletteSwap` shader for team-based unit recoloring — AI opponent units draw with swapped colors, player units draw unedited.

### Added

- **`shPaletteSwap` (`shaders/shPaletteSwap/`)** — a search-based palette-swap shader. Each unit type gets its own 1px-wide, 2-frame "Pallete" sprite (matching this project's existing spelling of that asset name): frame 0 lists the unit's original swappable colors (one texel per row), frame 1 lists that same row's replacement. Per fragment, the shader linearly scans frame 0's rows for a close-enough color match (`distance() < u_tolerance`) against the current pixel and, if found, substitutes the same row's frame-1 color; unmatched pixels (skin tones, outlines, anything not explicitly listed) pass through unchanged. Both palette frames are bound as separate texture stages (`u_paletteFrom`/`u_paletteTo`, point-filtered, no repeat) rather than one shared image, since GameMaker doesn't guarantee sprite frames land adjacent on a texture page. Follows this project's existing `shDitherDissolve` conventions: PascalCase shader name, uniform/sampler handles resolved once (not per draw), a `show_debug_message` warning if any handle resolves invalid, and a fixed-constant-bound for-loop with an early `break` to work around GLSL ES 1.0's compile-time-constant loop-bound restriction (`MAX_PALETTE_ROWS = 16`, today's real max is 7 rows — Soldier/Knight).
- **`UnitDefinition.palette` field** (`UnitDefinitions.gml`) — optional, defaults to `undefined`. Set for 5 of 6 units: `sPeasantPallete`, `sArcherPallete`, `sSoldierPallete`, `sKnightPallete`, and Bomb Goblin's `sBombGolbinPallete` (see Assumptions below re: that spelling). Mud Golem has no Pallete sprite yet and is intentionally left unset. Copied onto the live instance by `UnitApplyDefinition` alongside every other stat.
- **`PaletteSwapScripts.gml` (new file)** — `PaletteSwapInit()` caches `shPaletteSwap`'s sampler/uniform handles once, wired into `oGameControl`'s Create event alongside the other `RegisterAll*()` calls. `PaletteSwapDrawUnit(_unit)` replaces the bare `draw_self()` in `oUnitParent/Draw_0.gml`: draws unshaded for `TEAM.PLAYER` units and any unit with no `palette` set, and binds `shPaletteSwap` (resolving each palette frame's actual sub-rectangle on its texture page via `sprite_get_uvs()`, not raw 0-1 UVs) for `TEAM.ENEMY` units that have one. Per the request, the player's units always draw with unedited/frame-0-aligned colors — no shader involved for that team at all.

### Assumptions / scope boundaries (flag if wrong)

- **`sBombGolbinPallete` is a pre-existing misspelled asset name** ("Golbin" not "Goblin") — used as-is, not renamed, since every other `sBombGoblin*` asset in the project uses the correct spelling. Flagged inline in `UnitDefinitions.gml` in case you want it renamed in-editor.
- **Assumes palette sprites are never stored rotated on their texture page** (GameMaker's "Allow sprite rotating" is off project-wide, per current settings) — `sprite_get_uvs()`'s corner extraction in `shPaletteSwap.fsh`'s comment block explains why a rotated palette sprite would sample the wrong axis and scramble colors. Flag if that setting ever changes.
- **`PALETTE_SWAP_TOLERANCE` (0.02) and `MAX_PALETTE_ROWS`/`PALETTE_SWAP_MAX_ROWS` (16)** are tunable constants (`PaletteSwapScripts.gml` and `shPaletteSwap.fsh` respectively) — the two row-count constants are kept in sync by convention only, no automatic check enforces it. Bump both together if a future unit needs more than 16 palette rows.
- **Mud Golem renders unshaded on both teams** until it gets a Pallete sprite — `PaletteSwapDrawUnit` degrades gracefully rather than crashing or defaulting to a placeholder recolor.

### Build

- Windows export version bumped `0.0.2.48` → `0.0.2.49` — 4th-digit bump, same convention as last time.

## v0.0.2.48 — 2026-07-09 (uncommitted — working tree only, not yet committed)

Four blueprint/building-hover follow-ups: unit small-sprite centering, instant + affordability-aware blueprint hover, a health row under production amount, and icons before resource/unit names.

### Changed

- **`BuildingHoverItemIcon` (`BuildingHoverScripts.gml`) now uses each unit's new `smallSprite`** (`UnitDefinition.smallSprite`, e.g. `sPeasantSmall`) instead of `sprites.idle` inside the Item/Unit Window. Since unit sprites are bottom-center anchored, `BuildingHoverExtras.Layout`/`Draw` now compute `itemIconOffsetY` (half the sprite's own height) and draw the icon that far below the window's center -- centers the sprite in the window regardless of its exact height. Resource icons (`sResourceIcons`, middle-center anchored) get no offset, unchanged.
- **Blueprint slot hover (`BlueprintController.UpdateHover`, `BlueprintScripts.gml`) now shows instantly** -- the dwell-delay gate (`PLOT_HOVER_DELAY_STEPS`) is gone for this context only; it still fades in/out over `PLOT_HOVER_FADE_STEPS` rather than popping. The `hoverTimer` field this used for the delay has been removed (served no other purpose). Plot hover and placed-building hover are UNCHANGED -- they still require the 1-second dwell.
- **Blueprint hover cost row now shows "[icon]Base (Discount)" per resource**, base price and the parenthesized discount price colored INDEPENDENTLY of each other (new `CostToScribbleTextWithDiscount`, `ResourceUIScripts.gml`): each renders red if `_team` can't currently afford that specific amount. The discount price additionally renders in dark gray (new `BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG`, `BlueprintScripts.gml`) whenever no currently open plot would actually grant the discount, overriding the red/default check -- it's purely informational in that case, not a real price. `GetBestAvailablePlacementCost(_team, _def)` (`BlueprintScripts.gml`) now also exposes `discountAvailable` alongside its existing `anyPlotAvailable`/`cost`, so this and the title-red check (below) don't have to re-scan plots separately. The card's own title (the building's name) still renders red if the building can't be placed ANYWHERE right now -- no open owned plot, or unaffordable even at the cheapest available price.
- **`GetPlacementCost` (`BlueprintScripts.gml`) refactored**, no behavior change -- its discount-eligibility check is now a shared `BuildingGetsDiscountOnPlot(_def, _plot)` function, reused by `GetBestAvailablePlacementCost` so the two can't drift out of sync.
- **New health row under the production-amount label.** `BuildingHoverHealthText(_def, _building, _isBlueprint)` (`BuildingHoverScripts.gml`) always returns a value (every building has `maxHealth`, unlike the production-amount line which only applies to resource buildings) -- blueprint hover shows the flat `maxHealth`, placed-building hover shows `remaining/max` via `GetCurrentHealth`. Rendered as a second line under the existing production-amount line (or the only line, for training buildings), each prefixed with its own icon: `sUIHammer` for production, `sUIHeart` for health.
- **Icons now precede resource/unit names.** `BuildingHoverDescriptionText`'s auto-generated body text ("Produces Wheat" / "Trains Peasant") now reads "Produces [icon]Wheat" / "Trains [icon]Peasant". New `UnitIconTag(_unitDef)` (`UnitDefinitions.gml`) mirrors `ResourceIconTag`'s shape but resolves via `sprite_get_name` since each unit has its own distinct icon sprite asset rather than one shared frame-strip.

### Added

- **`UnitDefinition` gained two new optional fields**, set for all 6 registered units: `icon` (the unit's small 8x8 `sXIcon` sprite, used by `UnitIconTag`) and `smallSprite` (the unit's ~16x20 bottom-anchored `sXSmall` sprite, used by `BuildingHoverItemIcon`).

### Assumptions / scope boundaries (flag if wrong)

- **`sPeasantIcon`'s origin is Top Left (0,0)**, while every other unit icon (`sArcherIcon`/`sBombGoblinIcon`/`sKnightIcon`/`sMudGolemIcon`/`sSoldierIcon`) and `sResourceIcons` are Middle Center. Scribble's inline sprite tags draw each sprite at its own origin, so `sPeasantIcon` will likely render visibly offset (shifted down-right by ~4px) relative to every other icon rendered the same way. Did NOT change the sprite asset myself -- flagging for you to fix `sPeasantIcon`'s origin in-editor if this is unintentional (looked like an oversight, not a deliberate choice).
- "Placeable anywhere" (for the title-red check) only looks at plots the hovering team already owns and can see today (unblocked, unoccupied) -- it doesn't account for plots that might unblock later, nor does it consider AI/enemy-side plots (irrelevant per-team by design).
- Health/production text still renders in the card's standard text color regardless of cost-row coloring -- only the cost row's own base/discount amounts and the title get the red/gray treatment.
- The discount price shown is always `GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION)` -- the flat 50% math -- not scoped to any specific plot; "is the discount available at all right now" and "what would the discount amount be" are deliberately kept separate, since the discount fraction itself doesn't vary by plot, only its availability does.

### Build

- Windows export version bumped `0.0.2.47` → `0.0.2.48` — 4th-digit bump, same convention as last time.

## v0.0.2.47 — 2026-07-08 (uncommitted — working tree only, not yet committed)

Added building hover tooltips in two contexts: hovering a placed building in-world, and hovering a filled blueprint slot in the Blueprint UI.

### Added

- **`HoverCard` (`HoverCardScripts.gml`) extended with two new optional trailing `Show()` params**, `_topContentHeight`/`_bottomContentHeight` (both default `0`, fully backward-compatible — `PlotHoverController`'s existing call site is unchanged and behaves identically). These reserve vertical space above/below the card's own body/flavor content so a specialized overlay can draw its own extra content without touching HoverCard's core layout math. Two new getters, `GetContentTopY()`/`GetContentBottomY()`, expose exactly where that extra content should be drawn.
- **`BuildingHoverScripts.gml` (new file)** — shared data-gathering and drawing logic for building hover tooltips, used by both contexts below via an `_isBlueprint` bool threaded through every function:
  - `BuildingHoverDescriptionText(_def)` — "Produces {Resource}" / "Trains {UnitName}" / falls back to `_def.description`.
  - `BuildingHoverTimerText(_def, _building, _isBlueprint)` — "{rate} /sec" or "{trainTime} sec".
  - `BuildingHoverResourceLimitText(_def, _building, _isBlueprint)` — blueprint shows the flat limit only; a placed building shows `"{limit - producedTotal}/{limit}"`, read off the **live instance** so a Distant-plot-boosted building shows its actual current cap, not the unboosted definition value.
  - `BuildingHoverItemIcon(_def)` — the produced resource's icon, or the trained unit's idle sprite.
  - `BuildingHoverExtras()` — owns the icon-row (Building Window, Timer, Item/Unit Window, left-to-right, Building Window top-left of the body) and, for blueprints only, a cost row along the bottom (`[Resource Icon][Amount]` repeating, via the existing `CostToScribbleText`). `Layout()` returns the `topContentHeight`/`bottomContentHeight` to hand to `HoverCard.Show()`; `Draw()` renders both rows anchored off the card's `GetContentTopY()`/`GetContentBottomY()`.
  - `BuildingHoverController()` — placed-building context: 5-second dwell + fade, same pattern as `PlotHoverController`, targeting `oBuildingParent` via `instance_position` validated against `GetBuildingDefinition`. Flavor text is sourced from `BuildingDefinition.description` — an existing field that was never actually displayed anywhere before this patch (confirmed via project-wide grep); reused instead of adding a redundant new field. Current `description` values are placeholder text pending the real flavor-text document.
- **`BlueprintController` (`BlueprintScripts.gml`) gained a second hover tooltip** for the Blueprint UI panel — `IsMouseOverPanel()`, `GetHoveredStackIndex()`, `UpdateHover()`, `DrawHoverCard()` — using the same `BuildingHoverExtras`/`HoverCard` pair in `_isBlueprint = true` mode: the resource-limit widget shows the flat limit (no partial), and the cost row appears along the bottom in place of a partial-limit readout.
- **Mutual-suppression fix** — `PlotHoverSuppressed()` and the new `BuildingHoverSuppressed()` both now also suppress while `_blueprintController.IsMouseOverPanel()` is true. The Blueprint UI panel is a GUI-space overlay drawn on top of the game world, so without this the mouse could sit over both a filled blueprint slot and a world-space plot/building underneath it at the same screen position, showing two tooltips simultaneously.

### Assumptions / scope boundaries (flag if wrong)

- Icon-row order is **Building Window (top-left), then Timer, then Item/Unit Window** — matches `sHoverCardBuildingWindow`'s original spec wording. (An earlier draft of this patch had the Building Window top-right instead; corrected same-day before shipping, per user catch.)
- Unit sprite dimensions inside the 28×28 Item/Unit Window are unverified in-engine — `AnimationLibrary.idle` is used directly with no explicit scale-to-fit; may need a follow-up pass if a trained unit's idle sprite doesn't fit cleanly.
- "Trains {UnitName}" uses the unit's singular name as-is (no pluralization logic).
- The blueprint cost row shows the **base** cost, not the plot-discounted cost — no plot is chosen yet at blueprint-hover time, so `GetPlacementCost` can't be evaluated.
- Building hover is currently **team-agnostic** — it works for both `TEAM.PLAYER` and `TEAM.ENEMY` buildings, not restricted to the player's own. Flag if enemy buildings should be hidden from this instead.
- The `PLOT_HOVER_*` prefix (delay/fade/cursor-gap macros) is now shared across three systems (plot, building, blueprint hover) — a naming misnomer at this point, called out in comments but not renamed to avoid an unrelated rename sweep.
- `BuildingDefinition.description`/flavor text is placeholder content until the real flavor-text document is provided.

### Build

- Windows export version bumped `0.0.2.46` → `0.0.2.47` — 4th-digit bump, same convention as last time.

## v0.0.2.46 — 2026-07-07 (uncommitted — working tree only, not yet committed)

Rewrote plot bonus text as a direct, color-coded bullet list, and fixed a color-blending bug that would have washed out the new colors.

### Fixed

- **`DrawCardTextWithShadow`'s main draw pass no longer blends with `HOVER_CARD_TEXT_COLOR`** (`HoverCardScripts.gml`) -- confirmed via `__shd_scribble.vsh` (`v_vColour = in_Colour * u_vColourBlend`) that Scribble's `.blend()` MULTIPLIES onto each glyph's own baked-in colour rather than overriding it. Blending with `HOVER_CARD_TEXT_COLOR` -- itself already the colour every glyph was baked with via `.starting_format()` -- was multiplying every glyph against itself, since v0.0.2.43/44: plain card text has been rendering slightly darker/more saturated than the actual F1DEB6 value the whole time. It also would have washed any inline colour-tagged text toward F1DEB6 instead of showing its real colour, which would have broken this patch's colored bonus text below. Now blends with `c_white` (the multiplicative identity) instead -- plain text renders at the exact starting colour, and colour-tagged runs render true. The shadow pass is unaffected (black multiplied by anything is still black).

### Changed

- **`PlotHoverBonusText` (`PlotHoverScripts.gml`) rewritten as a direct, color-coded bullet list**, per request -- a plain-color category header line (e.g. "Resource Buildings:") followed by one line per effect, each wrapped in a new Scribble inline colour tag: lime green for beneficial effects (every effect today), red reserved for detrimental ones (none exist yet). Two new macros, `PLOT_HOVER_GOOD_COLOR_TAG`/`PLOT_HOVER_BAD_COLOR_TAG`, hold the tag names (`"c_lime"`/`"c_red"` -- both pre-registered by Scribble, no `scribble_color_set()` needed). Distant plots show two category blocks (Resource Buildings, then All Buildings) since their bonus splits by building type; Castle and Exterior plots show one each. Example (Distant plot):
  ```
  Resource Buildings:
  -50% Build Cost
  +50% Production Yield
  All Buildings:
  +50% Health
  ```

### Assumptions / scope boundaries (flag if wrong)

- No "bad" (red) effect exists anywhere in the current bonus data, so `PLOT_HOVER_BAD_COLOR_TAG` is unused -- kept as the documented convention for whenever one exists (e.g. if Distant plots' "greater exposure to attack" flavor line ever becomes a real mechanical penalty).
- The blend-multiply fix changes the exact on-screen shade of EVERY existing hover card's plain text (name/body/flavor), not just the new colored bonus lines -- a visual change beyond what was asked, but necessary for the requested colors to render correctly at all. Flagging in case the previous (slightly darker) shade was actually preferred.

### Build

- Windows export version bumped `0.0.2.45` → `0.0.2.46` — 4th-digit bump, same convention as last time.

## v0.0.2.45 — 2026-07-07 (uncommitted — working tree only, not yet committed)

Centered hover card titles, and made the plot placement bonus system (previously only described in hover-card flavor text) actually real.

### Changed

- **Hover card titles are now horizontally centered** (`HoverCardScripts.gml`) -- `nameText`'s Scribble alignment changed from `fa_left` to `fa_center` (constructor AND `Show()` -- both needed the same change; caught a mismatch between them during verification), and its draw position now targets the card's horizontal center instead of `HOVER_CARD_NAME_OFFSET_X`. Body and flavor text are unchanged, still left-aligned, per explicit request. `HOVER_CARD_NAME_OFFSET_X` is now unused -- kept in case a future specialized card variant wants the old left-anchor behavior; flag if it should just be deleted.

### Added

- **Plot placement bonuses are now real**, not just described in hover text -- realizes the split `oOuterPlotSpawner`'s header comment already stated as intended:
  - `GetPlacementCost(_def, _plot)` (new, `BlueprintScripts.gml`): resource buildings placed on an OUTSIDE plot (Exterior or Distant, `_plot.inside == false`) cost 50% less; training buildings placed on a CASTLE plot (`_plot.inside == true`) cost 50% less. `TryPlaceBlueprint` now charges/checks affordability against this instead of `_def.cost` directly.
  - `GetDiscountedCost(_cost, _fraction)` (new, `Economy.gml`): returns a new `Cost` with every resource field scaled by `(1 - _fraction)` and rounded to the nearest whole unit (resources are whole-integer-only in this project).
  - `ApplyPlotBonuses(_building, _plot)` (new, `BuildingDefinitions.gml`): any building placed on a Distant ("far") plot gets +50% `maxHealth`; production (resource) buildings there ALSO get +50% `resourceLimit`. Training buildings never have a `resourceLimit` field to begin with, so the "health only for training buildings" rule falls out naturally without an explicit building-type check. Called from `TryPlaceBlueprint` right after the building instance is created.
  - `PlotHoverBonusText` (`PlotHoverScripts.gml`) now states the real numbers (e.g. "Training buildings cost 50% less to place here.") instead of the previous qualitative-only wording, which had explicitly flagged itself as "overpromising before it's real."

### Assumptions / scope boundaries (flag if wrong)

- Discounted costs round to the nearest whole unit (`round()`, not `floor()`/`ceil()`) -- not specified by the request. At current cost values (all >= 8 per resource) this never rounds to 0.
- A building is assumed to be either a resource building OR a training building, never both -- true for every `BuildingDefinition` registered today, so no stacking/precedence logic was written for a building that's somehow both.
- `AI_FindEmptyOwnedPlot` (`AIControl.gml`) still grabs the first unblocked/unoccupied plot with no preference for the type of bonus it grants -- its doc comment previously said no such bonus system existed yet; that's no longer true, so the comment was corrected to instead flag this as a real (if minor) AI inefficiency. Not fixed here -- teaching the AI to seek out the best plot for a given building type was out of scope for "set up those bonuses."
- No UI currently displays the discounted cost before placement (the Blueprint panel only shows the building's icon, not its price) -- the discount is real and charged correctly, but a player has no in-UI way to see the price difference yet.

### Build

- Windows export version bumped `0.0.2.44` → `0.0.2.45` — 4th-digit bump, same convention as last time.

Data card typography/color pass, plus a new flavor-text region for building-plot hover cards.

### Changed

- **All `HoverCard` text now uses the new font assets** (`HoverCardScripts.gml`) -- `fntDataCard` for both the name plate and the normal body text (previously `fnt_gm_20`/`fnt_gm_15`). A new second region, italic `FntDataCardItalics`, is drawn inside `sHoverCardDataWindow` below the body when `Show()` is given non-empty flavor text (new optional 5th param, default `""` = no flavor region at all). `HoverCardFlavorWrapWidth()`/`HoverCardRequiredHeight()`'s new `_hasFlavor` param account for it in card-size selection.
- **All card text now renders in `HOVER_CARD_TEXT_COLOR` (F1DEB6)** with a 1px downward drop shadow (`HOVER_CARD_SHADOW_COLOR`) via a new `DrawCardTextWithShadow()` helper -- a manual double-draw (shadow copy offset 1px down, then main copy on top). Scribble has no built-in runtime shadow effect; the existing `scribble_font_bake_shadow.gml` bakes an entirely new font asset via a shader, a heavier one-time step not used anywhere else in this project, so the lighter double-draw was used instead.
- **Building-plot hover text now split across both regions** (`PlotHoverScripts.gml`): `PlotHoverBonusText` (new, normal body/`fntDataCard`) states the plot's placement bonus per `oOuterPlotSpawner`'s header comment; `PlotHoverFlavorText` (renamed from `PlotHoverBody`, italic/`FntDataCardItalics`, in `sHoverCardDataWindow`) carries the previous pass's descriptive one-liners. `PlotHoverController.Step`'s `card.Show(...)` call now passes both.

### Assumptions / scope boundaries (flag if wrong)

- Drop shadow color defaults to `c_black` -- not specified by the request.
- The placement-bonus mechanic described in `PlotHoverBonusText` is still NOT implemented anywhere in code (`AI_FindEmptyOwnedPlot`'s doc comment in `AIControl.gml` confirms it's aspirational). The new body text describes it qualitatively -- which building type benefits -- without inventing a number, since none exists. Flag if this reads as overpromising before the mechanic is real.
- The "Blocked Plot" flavor line ("Whatever this plot could become remains sealed for now") is newly-invented atmospheric text, not sourced from any existing spec.

### Build

- Windows export version bumped `0.0.2.43` → `0.0.2.44` — 4th-digit bump, same convention as last time.

## v0.0.2.43 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Same-day correction to v0.0.2.42's 2x scale pass: "text can be rendered at 1x scale in terms of UI, it does not need to be scaled up with everything else."

### Changed

- **`HoverCard`'s text no longer scales** (`HoverCardScripts.gml`) -- removed the `.scale(HOVER_CARD_SCALE)` call from both `nameText` and `bodyText` (constructor and `Show()`). Glyphs now render at native (1x) size regardless of `HOVER_CARD_SCALE`. The card SPRITE still renders at 2x, and all LAYOUT math (name/body offsets, margins, wrap width) still scales by `HOVER_CARD_SCALE` -- unchanged from last pass -- so native-sized text is still correctly positioned within the visually-2x card; it just no longer draws bigger to match. Practical effect: more (smaller) text now fits per line and the auto-sized card will more often land on Short/Mid than before, since the wrap width is unchanged (scaled) but glyphs take less of it.

### Build

- Windows export version bumped `0.0.2.42` → `0.0.2.43` — 4th-digit bump, same convention as last time.

## v0.0.2.42 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Two follow-up requests on the hover card system: render at 2x (matching the rest of the UI), and make card placement position-sensitive so it never opens toward the nearest screen edge. Also re-added `HoverCardScripts`'s `.yyp` registration, which had silently dropped out between sessions (see below) -- that's what caused the "HoverCard not set before reading" crash report.

### Fixed

- **`HoverCardScripts` was missing from `Blank Pixel Game.yyp`.** The script files were still on disk, but with no `.yyp` entry GameMaker never compiled them in, so the `HoverCard` constructor didn't exist at runtime -- `new HoverCard()` in `PlotHoverController` resolved to a variable read instead of a function call, producing the reported "Variable ....HoverCard(...) not set before reading it" crash. Re-added the entry. If this recurs, it's likely the GameMaker IDE overwriting the `.yyp` from its own in-memory resource list while the project is open during an editing session -- reloading the project after a batch of changes should keep it in sync.

### Changed

- **`HoverCard` now renders at `HOVER_CARD_SCALE` (2x)** (`HoverCardScripts.gml`), matching the "most UI items render at 2x" convention already used by `XpBarWidget`/`FateDrum`. Unlike those two (which only scale sprites, since they have no text), the card's Scribble text elements now carry `.scale(HOVER_CARD_SCALE)` -- a PRE-render scale baked into Scribble's text layout model (confirmed via `__scribble_class_element.gml`: changing it dirties the model/bbox cache), so `.wrap()`/`.get_height()` measure against the already-scaled glyphs. Every layout constant (name offset, body margins, wrap width) stays NATIVE (1x) in the macros and gets multiplied by `HOVER_CARD_SCALE` at the point of use, so `ChooseHoverCardSprite`'s Short/Mid/Tall comparisons and the actual on-screen render stay in sync. New `HoverCard.GetWidth()`/`GetHeight()` expose the real on-screen footprint for positioning code.
- **Position-sensitive card placement** (`PlotHoverController.Step`, `PlotHoverScripts.gml`): the card now anchors away from whichever half of the screen the mouse is in, independently on each axis -- mouse in the left half anchors the card's left edge near the mouse (opens rightward), mouse in the right half anchors the right edge (opens leftward), same logic for top/bottom. `PLOT_HOVER_CURSOR_GAP` (8px) sits between the mouse and the card's nearest edge in the direction of its anchor -- e.g. mouse in the bottom-right quadrant puts the card's bottom-right corner 8px up and 8px left of the mouse. Replaces the old flat +18/+18 cursor offset and its edge-nudge fallback; a defensive clamp remains as a safety net for extreme cases (e.g. a very narrow window).

### Assumptions / scope boundaries (flag if wrong)

- The anchor test uses screen HALVES (mouse position vs. `display_get_gui_width()/height() / 2`), not the specific card's own footprint vs. the nearest edge -- simpler and matches the request's literal "below the center of the screen" framing, but means a card could in rare cases anchor "away" from a screen half it wasn't actually close to running off of. The safety-net clamp catches any resulting overflow regardless.
- 2x scale currently only affects `HoverCard` (and therefore plot hover data). The specialized building/unit/timer window sprites planned for later passes aren't touched yet.

### Build

- Windows export version bumped `0.0.2.41` → `0.0.2.42` — 4th-digit bump, same convention as last time.

## v0.0.2.41 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Hover data for un-occupied building plots -- the first real consumer of the general-purpose HoverCard base from v0.0.2.40.

### Added

- **`HoverCard.Draw()` (`HoverCardScripts.gml`) now takes an optional `_alpha` (default 1)**, applied via `draw_sprite_ext` for the card sprite and Scribble's `.blend()` for both text elements. Purely additive -- every existing no-argument call still renders fully opaque exactly as before.
- **`PlotHoverScripts.gml`** (new script asset):
  - `PlotHoverName(_plot)`/`PlotHoverBody(_plot)` classify an un-occupied `oBuildingPlot` into one of 4 kinds, using its existing `blocked`/`inside`/`far` fields: `"Blocked Plot"` (meta-progression-locked, checked first since it can coexist with `inside`), `"Castle Plot"` (buildable, inside the walls), `"Distant Plot"` (buildable, far outer ground), `"Exterior Plot"` (buildable, near outer ground). Body text describes each plainly -- deliberately does NOT mention the inside/outside placement bonus described in `oOuterPlotSpawner`'s header comment, since `AI_FindEmptyOwnedPlot`'s doc (`AIControl.gml`) already flags that bonus as unimplemented.
  - `PlotHoverSuppressed(_selectionController, _blueprintController)` -- true while the player is targeting an order, dragging a blueprint, or (once wired) the Fate Engine overlay is open.
  - `PlotHoverController()` -- owns one `HoverCard`. Tracks continuous dwell time on whatever un-occupied plot the mouse is over; once `PLOT_HOVER_DELAY_STEPS` (300 = 5 sec at the true 60fps game speed) is reached uninterrupted, fades the card in over `PLOT_HOVER_FADE_STEPS` (~1/3 sec); fades back out at the same rate the instant the mouse leaves the plot, the plot becomes occupied, or suppression kicks in. The card freezes its last content/position while fading out rather than snapping away.
  - New `global.fateEngineOverlayActive` flag -- suppression hook for the Fate Engine overlay. **Nothing sets this true yet**: the only Fate Engine object in the project today (`oFateEngineDrumTest`) is an explicitly temporary test harness with no open/closed state of its own. This flag exists so the real overlay (not yet built) can wire into suppression later without another pass through this file.
- Wired into `oUnitControl`: `plotHoverController` created in `Create_0`, stepped (passing `selectionController`/`blueprintController`) in `Step_0`, drawn last in `Draw_64` (so it renders on top of the rest of the HUD).

### Assumptions / scope boundaries (flag if wrong)

- The request's exact casing was "castle plot" (lowercase) alongside 3 Title-Case names -- normalized to "Castle Plot" to match the other 3 and every other order/label string in this project.
- The dwell timer and fade deliberately do NOT scale with `global.matchSpeed`, unlike most gameplay timers in this project (e.g. `CastleStep`'s no-damage XP timer) -- a UI dwell/fade is treated as real-time so it still works while the game is paused (`matchSpeed` 0), rather than never triggering.
- Hover data shows for plots on EITHER team, not just the player's own -- the request didn't specify a team restriction, and the info conveyed (which of the 4 plot kinds this is) isn't sensitive.
- The card follows the mouse cursor (offset +18/+18) the whole time it's visible, not just at the moment it first appears -- this matches typical tooltip behavior but wasn't explicitly specified.
- `global.fateEngineOverlayActive` is inert plumbing until the real Fate Engine session overlay is built -- flagged above, not guessed at.

### Build

- Windows export version bumped `0.0.2.40` → `0.0.2.41` — 4th-digit bump, same convention as last time.

## v0.0.2.40 — 2026-07-06 (uncommitted — working tree only, not yet committed)

First pass on the hover/tooltip data overlay system -- step 1 of 4 (general-purpose base first, then unit/building/event data layered on top per the request). New sprite assets for this (`sHoverCardShort/Mid/Tall`, `sHoverCardBuildingWindow`, `sHoverCardDataWindow`, `sHoverCardTimer`, `sHoverCardUnitWindow`, all in "In Game/UI/Assets/DataOverlays") were already added to the project ahead of this batch.

### Added

- **`HoverCardScripts.gml`** (new script asset): `HoverCard()` constructor -- a name plate + wrapped body text, auto-picking the smallest of the 3 card sprites (Short 148px / Mid 185px / Tall 222px tall, all 133px wide) that fits the body text via Scribble's `.wrap()`/`.get_height()`, capped at Tall. `Show(_name, _body, _x, _y)` sets content + GUI position and picks the sprite; `Hide()`; `Draw()` renders the card, the name (left-middle aligned, anchored at (5, 11) relative to the card's top-left, per spec) and the wrapped body (starting `HOVER_CARD_BODY_MARGIN_TOP` px below the name plate strip). Same "plain struct, owner drives Show/Hide/Draw" pattern as `BlueprintController`/`FateDrum`/`XpBarWidget` -- no `Step()` needed, nothing animates.
- Uses **Scribble** (already wired into the project -- `oAlphaDisclaimer`'s disclaimer text, `ResourceUIScripts.gml`'s `CostToScribbleText`) rather than raw `draw_text_ext`, specifically because `.wrap()`/`.get_height()` is what makes "does this text fit in card X" answerable before drawing.
- Not yet wired into any object/hover-detection code, and the specialized sprites (Building/Data/Timer/Unit windows) aren't touched yet -- this pass is only the reusable base.

### Assumptions / scope boundaries (flag if wrong)

- Name-plate font `fnt_gm_20` and body font `fnt_gm_15` are both pre-existing generic GM fonts already in the project -- no new font asset was created this pass. The italic flavor-text font mentioned in the request ("we can make a font for it") is deferred to the building-data pass, where it's actually needed.
- Body margins (6px left/right, 4px top gap below the name plate, 6px bottom gap) are my own placeholder spacing -- not specified in the request beyond the name plate's exact (5, 11) anchor, which IS followed precisely.
- If body text is long enough to overflow even the Tall card, `Show()` sets an `overflowed` flag but nothing currently truncates or scrolls -- text will just run past the card's bottom edge. Flagging in case that's a real scenario once actual flavor text is written.
- `HoverCard` has no hover-detection logic of its own (no mouse-over-instance check) -- it's purely "given a name/body/position, display it." Wiring it to actual mouse-over-a-unit/building detection is follow-up work.

### Build

- Windows export version bumped `0.0.2.39` → `0.0.2.40` — 4th-digit bump, same convention as last time.

## v0.0.2.39 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Castle-side AI defense, closing the scope gap explicitly flagged in v0.0.2.38: "if it is under siege, top priority should be to defeat enemies attacking the castle."

### Added

- **`GetTeamCastle(_team)`** (`GatherScripts.gml`) — a team's OWN castle instance, the inverse of the existing `GetEnemyCastle(_unit)`.
- **`CastleDefendWaypoints(_castle)`** (`CastleScripts.gml`) — patrol waypoints spread along a castle's actual front wall (reusing the same "whichever bbox edge faces the room's center" logic as `CastleFrontEdgePoint`), instead of `DefendBuildingWaypoints`' 4-corner box, which assumes a 48x48 building and is wrong for a 350x411 castle. New macro `CASTLE_DEFEND_WAYPOINT_COUNT` (6, placeholder) controls how many points are spread down the wall.
- **`Defend_Enter`** (`UnitStateDefend.gml`) now branches on target type: `!object_is_ancestor(_target.object_index, oBuildingParent)` tells a castle apart from an ordinary building (neither castle object is an `oBuildingParent` descendant), and picks `CastleDefendWaypoints` instead of `DefendBuildingWaypoints` accordingly. This is the only unit-level FSM change in this batch — flagging per CLAUDE.md's "flag before touching FSM/state wiring for guard/defend/combat/attack/siege" rule, though it's purely additive (existing building-defense behavior is untouched).
- **`AI_CastleUnderThreat(_team)`** (`AIControl.gml`) — true if any enemy unit is within new macro `AI_CASTLE_THREAT_RADIUS` (300, placeholder) of `_team`'s own castle. The castle-scoped counterpart to the existing building-scoped `AI_DetectThreat`.
- **New `AIBrain` state `"castle_defense"`**, the AI's highest priority — checked first in both `"build_up"` and `"defending"`, ahead of the ordinary building-threat check. `AI_CastleDefense_Step` recalls every unit currently in `"guard"`, `"defend"`, OR `"siege"` (including a siege already committed against the enemy castle) and redirects them to `"defend"` the home castle via `CastleDefendWaypoints`. Units already actively fighting (combat/combatRanged/attack/attackRanged) are left alone rather than yanked out of a live engagement. Reverts to `"build_up"` the instant the castle clears.

### Changed (behavior, not code shape)

- The AI will now abandon an in-progress siege against the enemy castle to save its own — explicitly the opposite of v0.0.2.38's scope boundary ("deliberately does NOT recall units already mid-siege"). This is intentional per this request: castle survival outranks an offensive push.

### Assumptions / scope boundaries (flag if wrong)

- `AI_CASTLE_THREAT_RADIUS` (300) is a placeholder, sized somewhat larger than `AI_THREAT_RADIUS` (250) since it's measured from the castle's origin and the castle itself is much bigger than an ordinary building — not tuned against real approach distances.
- Recall scope was a judgment call: `"guard"`/`"defend"`/`"siege"` get pulled back, but units already in an active fight (combat/combatRanged/attack/attackRanged) don't — pulling a unit out of a live engagement seemed more likely to get it killed mid-retreat than to help. Worth revisiting if castle losses still happen with units "stuck" fighting elsewhere while the castle burns.
- No new "castle destroyed" / loss-condition handling was touched here — this only affects the AI's own decision-making, not match end-state logic.

### Build

- Windows export version bumped `0.0.2.38` → `0.0.2.39` — 4th-digit bump, same convention as last time.

## v0.0.2.38 — 2026-07-06 (uncommitted — working tree only, not yet committed)

First real pass on AI decision-making (`AIControl.gml`), following a discuss-first design conversation about what the AI's priorities should be given the win condition (reduce the opponent's castle HP to zero). Full rewrite of the file's decision logic; no unit-level FSM states (guard/defend/combat/attack/siege) were touched -- this is entirely the layer that decides which orders to issue, not how those orders execute.

### Fixed

- **The AI likely never reached its own siege threshold.** `TrainingSpawnUnit` (`TrainingScripts.gml`) sends every freshly trained unit straight into `"defend"` (patrolling the building that trained it), not `"guard"` -- a unit only falls back to `"guard"` if that specific building is later destroyed. But the old `AI_BuildUp_Step` only counted units in `"guard"` toward its idle-massing threshold. In normal play, that count would likely never climb past zero. New `AI_GatherAvailableUnits(_team)` now treats `"guard"` OR `"defend"` as available for redirection; committed states (attack/attackRanged/combat/combatRanged/siege) are still correctly excluded.

### Added

- **Reactive defense.** New `AI_DetectThreat(_team)` finds the first owned building (`oBuildingParent`) with an enemy unit within `AI_THREAT_RADIUS` (250px, placeholder) of it. `AIBrain` gained a second state, `"defending"`: entered the instant a threat is detected, it sends every available unit to `"defend"` the threatened building (reusing the existing player-facing order/state completely unchanged -- responders patrol it and auto-engage via `Defend_Step`'s existing proximity-aggro check, no new combat logic needed) and reverts to `"build_up"` once nothing's threatened. Deliberately building-scoped, not castle-scoped: `"defend"`'s patrol waypoints (`DefendBuildingWaypoints`) hardcode a 48x48-ish box, which would be wrong for the castle (350x411) the same way it was for siege before `CastleFrontEdgePoint` -- castle-side defense (recalling an army mid-siege to save your own castle) is flagged as a reasonable next increment, not built here. Economy/training pauses while `"defending"`, by choice, not oversight.
- **Strength-based siege commitment.** Replaced the flat `AI_ATTACK_GROUP_SIZE = 5` headcount with `AI_ArmyPower(units)` (sum of `AI_UnitPowerScore` per unit: current HP × 0.4 + attackDamage × 5, both placeholder weights) compared against `AI_SiegePowerThreshold()` = 60% of `CASTLE_MAX_HEALTH`. The AI now commits when its available force has SOME rough sense of scale relative to the castle it's attacking, instead of "5 of anything, including 5 unarmed peasants."
- **Composition-aware economy.** New `AI_MissingResourceProducers(_team)` reports which of the 5 tier-1 resources (wheat/water/wood/gold/iron) the team has zero live producers for -- resource buildings self-destroy on depletion and nothing replaced them before this. `AI_TryPlaceBlueprints` now spends on a missing producer first, falling back to the old "spend whatever's affordable" greedy behavior once every resource is covered.
- **Composition-aware training.** New `AI_ArmyTagFraction(_team, _tag)` measures what fraction of the team's live army carries a given `UnitDefinition` tag. `AI_TryTrainComposition` (replaces `AI_TryTrainAtAllBuildings`) checks this against `AI_TANK_TARGET_RATIO`/`AI_RANGED_TARGET_RATIO` (25% each, placeholders) and gives training buildings for the most under-represented tag first crack at the tick's budget, before falling back to attempting every other owned training building same as before.

### Assumptions / scope boundaries (flag if wrong)

- All weights/ratios/radii introduced here (`AI_THREAT_RADIUS`, `AI_SIEGE_POWER_FRACTION`, `AI_POWER_HEALTH_WEIGHT`/`AI_POWER_DAMAGE_WEIGHT`, `AI_TANK_TARGET_RATIO`/`AI_RANGED_TARGET_RATIO`) are placeholders in the same spirit as every other untuned number in this project (`CASTLE_MAX_HEALTH`, building costs, etc.) -- functional, not balanced.
- Castle-side reactive defense (pulling a besieging army home if the AI's OWN castle comes under attack) is explicitly out of scope this pass -- `AI_DetectThreat` only watches ordinary buildings, for the size-mismatch reason above.
- The AI does not keep building/training while `"defending"` -- a deliberate simplification, flagged in case a more concurrent posture is wanted later.
- `AI_TryTrainComposition`'s tag-priority check only looks at "tank" and "ranged" -- it doesn't reason about the other tags (`"suicide"`, `"fast"`, `"cheap"`, `"heavy"`) at all; those units still get trained in the same building's "everything else gets a chance" fallback pass, just without any deliberate weighting.

### Build

- Windows export version bumped `0.0.2.37` → `0.0.2.38` — 4th-digit bump, same convention as last time.

## v0.0.2.37 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Crash fix: `DoAdd :2: undefined value` in `AnalyticsRecordResourceProduced`, first triggered by `oTrainingBuildingParent`'s Step event the moment a unit actually finished training (`TrainingSpawnUnit` -> first-deployment Strategic XP -> `GainXP` -> the crash).

### Root cause

`GainXP` (`ProgressionScripts.gml`, added in the v0.0.2.29 XP-doc batch) calls `AnalyticsRecordResourceProduced(_team, "xp", _toAdd)` and `(_team, "fateTokens", _tokensEarned)` to log XP/Fate Token gains through the existing analytics pipeline. But `AnalyticsInit`'s `resourceProduced` struct (`AnalyticsScripts.gml`) only ever had keys for the 10 literal economic resources (wood/wheat/water/iron/gold/meat/bones/coal/weapons/coins) -- "xp" and "fateTokens" were never added when `GainXP` started using them. `struct_get` on a missing key silently returns `undefined` rather than erroring, so the crash didn't happen at the call site -- it happened one line later, in `AnalyticsRecordResourceProduced` itself, on `undefined + _amt`. This sat latent since the XP batch because nothing had actually triggered a `GainXP` call in a live playtest until now.

### Fixed

- **`AnalyticsInit`** (`AnalyticsScripts.gml`): added `xp:0, fateTokens:0` to both the `resourceProduced` AND `resourceSpent` struct literals. `resourceSpent` isn't hit by today's crash (nothing currently spends xp/fateTokens as a `Cost`), but `Cost`/`ResourceCost` already supports both as a resource type (added earlier this session), so this heads off the identical crash the moment something does spend one.

### Build

- Windows export version bumped `0.0.2.36` → `0.0.2.37` — 4th-digit bump, same convention as last time.

## v0.0.2.36 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Units no longer physically collide with buildings, per explicit request ("it doesn't make a difference if they actually clip through them"). Purely a movement/collision change -- the cosmetic steering-around-buildings behavior is untouched.

### Changed

- **Every unit movement call site** now drops `oBuildingParent` from its `move_and_collide` collision list, leaving only `oEnvironmentSolid` (real static geometry -- map bounds, terrain, etc.): `Guard_Step` (`UnitStateGuard.gml`), `Defend_Step` (`UnitStateDefend.gml`), and the two shared movement helpers `UnitPursueTarget`/`UnitIdleInPlace` (`UnitCombatHelpers.gml`) -- which between them cover every other state (attack, attackRanged, combat, combatRanged, siege). That's the complete set; grepped for every `move_and_collide` call in the project to confirm nothing was missed.
- **`Steering_AvoidObstacles` is completely unchanged**, as is `GatherNearbyObstacles` (`GatherScripts.gml`, still gathers `oBuildingParent` instances). Units still steer around buildings cosmetically; they just aren't physically blocked if avoidance doesn't fully route around one in time, which is accepted as harmless per the request.

### Assumptions (flag if wrong)

- Castles (`oPlayerCastle`/`oEnemyCastle`) were already fully non-solid before this batch (`parentObjectId: null`, `solid: false`, never in any collision list) -- this change doesn't affect siege behavior at all, only ordinary buildings (resource + training).
- Knockback (`ApplyKnockback`/`SteeringController.Apply`) still routes through the same `move_and_collide` call as normal movement, so a knocked-back unit can now be shoved straight through a building instead of being stopped by it -- a real, if minor, behavior change worth knowing about, not called out separately since it follows directly from "no longer collide with buildings" rather than being a separate decision.

### Build

- Windows export version bumped `0.0.2.35` → `0.0.2.36` — 4th-digit bump, same convention as last time.

## v0.0.2.35 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Four requested tweaks: deselect-on-order, a tighter defend patrol radius, siege obstacle-avoidance tuning, and a real fix for siege units sliding through the castle wall instead of stopping.

### Changed

- **`SelectionController.IssueOrder`/`UpdateTargeting`** (`UnitSelection.gml`): `selected` is now cleared the moment an order actually goes out -- immediately for a no-target order (guard/siege/station), or on the successful-click branch of `UpdateTargeting` for a targeted order (defend/attack). A canceled targeting attempt leaves the selection untouched, since nothing was actually issued.
- **`DEFEND_PATROL_MARGIN`** (`UnitStateDefend.gml`): `20` → `4` px outside the building edge, per request. Also tightened **`DEFEND_ARRIVE_RADIUS`** `48` → `16` alongside it -- the old value was nearly as large as an entire corner-to-corner patrol leg at the new, much smaller margin, which would have kept units decelerating for almost the whole loop instead of ever reaching a normal patrol speed. Flagging since only the margin was explicitly requested.
- **`UNIT_OBSTACLE_LOOK_RADIUS`** (`GatherScripts.gml`): `96` → `140`. At 96 there was barely any margin beyond `Steering_AvoidObstacles`' own feeler length, so obstacles were only ever spotted right at the tip of the feeler with no room to curve around smoothly -- a likely contributor to units snagging on buildings. This is a global detection-radius change (affects every steering user, not just siege), but only changes how early an obstacle is seen, not the avoidance logic itself.
- **`UnitPursueTarget`** (`UnitCombatHelpers.gml`): added an optional `_feelerLength` parameter (default `80`, so every existing call site is unaffected). `Siege_Step`'s ADVANCE phase now passes `120` -- a longer lookahead for the long march across open ground toward the castle, where getting snagged was reported.

### Added

- **`SteeringAgent.Brake(_friction)`** (new, `SteeringBehaviors.gml`): decays `velocity` toward zero, same `power(friction, matchSpeed)` idiom knockback already decays with. **`UnitIdleInPlace`** (`UnitCombatHelpers.gml`) now calls it before applying steering. Root cause of "siege units bound in and out of the castle walls": `Steering_Controller.Apply()` with zero `Add()` calls (i.e. "idle") does NOT stop a unit -- every `Steering_*` behavior decelerates by computing desired-minus-velocity, but adding nothing at all leaves whatever velocity a unit already had completely untouched, forever. A unit that reached attack range still carried full pursuit-speed momentum into `UnitIdleInPlace` and just kept gliding in that direction indefinitely (castles have zero collision -- `oPlayerCastle`/`oEnemyCastle` are `parentObjectId: null`, `solid: false` -- so nothing physically arrested that drift either). Braking on entry to idle fixes this for every `UnitIdleInPlace` caller (attack/attackRanged/combat/combatRanged/siege), not just siege.

### Assumptions / honesty check (flag if wrong)

- The obstacle-avoidance tuning (wider look radius, longer siege feeler) is a meaningful reliability improvement, not a guarantee. This project's steering is pure reactive Craig Reynolds-style (per CLAUDE.md -- context steering was tried and dropped), which has no concept of a real path around a fully-enclosed dead end; only actual pathfinding (navmesh/grid) can make "always reaches the castle" a mathematical certainty. Flagging this now rather than overpromising -- if units are still getting stuck in specific building layouts after this, that's a sign real pathfinding is the next real step, not another round of steering-weight tuning.

### Build

- Windows export version bumped `0.0.2.34` → `0.0.2.35` — 4th-digit bump, same convention as last time.

## v0.0.2.34 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Root-caused and fixed "the targeting reticle sometimes doesn't come up" for "Defend Building" (and every other `requiresTarget` order): a same-frame input double-read, not a targeting-logic bug. `oUnitControl/Step_0.gml` calls `orderMenu.Update()` (which reads the menu click and can call `IssueOrder` -> `BeginTargeting`, setting `isTargeting = true`) and then, in that SAME Step, immediately calls `UpdateTargeting()` since `isTargeting` is now true. `mouse_check_button_pressed(mb_left)` is still true for the rest of that Step -- it's the exact same physical press that selected the menu item -- so `UpdateTargeting` read it as the player's target click, resolved against wherever the cursor happened to be sitting on the order menu (almost never a valid target), and canceled targeting mode before the reticle was ever drawn. Reproduces intermittently because it depends on whether anything happens to occupy that stale room-space position.

### Added

- **`SelectionController._targetingJustBegan`** (new internal field, `UnitSelection.gml`): set `true` by `BeginTargeting`, checked and cleared at the top of `UpdateTargeting` -- swallows exactly the one same-frame press that opened targeting mode, so the first REAL click read happens on the next Step, after the menu-selection press has actually ended. Also cleared by `CancelTargeting` for cleanliness.

### Build

- Windows export version bumped `0.0.2.33` → `0.0.2.34` — 4th-digit bump, same convention as last time.

## v0.0.2.33 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Correction to v0.0.2.32: that batch's fix incorrectly assumed `oBuildingPlot.blocked` meant "has a building on it." Per explicit correction, `blocked` is unrelated to building presence -- it's a meta-progression-owned flag (see `oPlotSpawner/Create_0.gml`: the inner 3x3 of each 5x5 inside-castle plot grid is marked `blocked` at spawn to keep those slots un-buildable until some future progression system unlocks them; the outer ring is left `false`). Conflating that with "a building is standing here" was wrong. Introduced a separate `occupied` field for the latter and rewired everything v0.0.2.32 touched to use it instead, leaving `blocked` completely untouched by building placement/destruction from here on.

### Added

- **`oBuildingPlot.occupied`** (new Object Property, default `False`, same declaration style as `inside`/`far`/`blocked`/`team`): true exactly while a building currently stands on this plot. Also set explicitly in `SpawnBuildingPlot` (`PlotScripts.gml`), matching how `blocked` is already explicitly re-set there for parity even though the property default already covers it.

### Changed

- **`TryPlaceBlueprint`** (`BlueprintScripts.gml`): validity check is now `_plot.blocked || _plot.occupied` (was just `_plot.blocked`) -- rejects both a meta-locked slot AND an already-occupied one. Sets `_plot.occupied = true` on placement (was incorrectly setting `_plot.blocked = true`).
- **`BuildingFreePlot`** (`PlotScripts.gml`, added in v0.0.2.32): now clears `occupied` instead of `blocked`. Docstring corrected to state plainly that it never touches `blocked`.
- **`UpdateTargeting`**'s click-through fix (`UnitSelection.gml`, added in v0.0.2.32): now checks `_clicked.occupied` instead of `_clicked.blocked` when deciding whether a clicked `oBuildingPlot` should be treated as click-through in favor of the building on top of it.
- **`AI_FindEmptyOwnedPlot`** (`AIControl.gml`): now checks `!blocked && !occupied` (was just `!blocked`) -- without this, the AI would have started treating every occupied plot as buildable again the moment `TryPlaceBlueprint` stopped setting `blocked` on placement.

### Assumptions (flag if wrong)

- `blocked`'s real semantics (meta-progression plot unlocks) aren't implemented anywhere beyond `oPlotSpawner`'s spawn-time interior-grid lockout -- nothing currently *unblocks* a blocked plot. Not this batch's concern; noted so it isn't mistaken for another building-presence bug later.

### Build

- Windows export version bumped `0.0.2.32` → `0.0.2.33` — 4th-digit bump, same convention as last time.

## v0.0.2.32 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Root-caused and fixed "can't get units to defend the wheat fields": a blocked `oBuildingPlot` is never destroyed once a building is placed on it (`TryPlaceBlueprint`, `BlueprintScripts.gml` -- it only sets `blocked = true`), and it sits at the exact same x/y as the building, so `instance_position(..., all)` in the "Defend Building"/"Attack Building" click-targeting flow (`UpdateTargeting`, `UnitSelection.gml`) could resolve to the plot instead of the building. The plot always fails the `oBuildingParent`-ancestor `targetValidator`, so the click would silently do nothing -- no error, no feedback, just a targeting click that appeared to be ignored.

### Changed

- **`UpdateTargeting`** (`UnitSelection.gml`): if the clicked instance is a *blocked* `oBuildingPlot`, it's now treated as click-through -- the click is re-resolved against `oBuildingParent`, which correctly finds the building sitting on top of it. An unblocked plot (nothing built on it) is unaffected and still a normal target. Considered an actual mask/sprite swap first (strip the plot's collision mask while blocked, restore it once free) per initial direction, but every mask sprite in this project (`sPlot` included) is rectangle/bbox collision, not precise -- a real "no collision" mask would need a new, hand-authored sprite asset (something not done anywhere else this session). This delivers the identical player-facing result in pure GML instead, with no new assets.
- **`ApplyDamage`** (`UnitCombatHelpers.gml`): the building-death branch now always calls the new `BuildingFreePlot` before destroying the building, regardless of whether there's an attributable killer (XP is still killer-gated, unchanged).
- **`BuildingUpdateProduction`** (`BuildingDefinitions.gml`): the resource-depletion self-destroy path now also calls `BuildingFreePlot` before `instance_destroy`.

### Added

- **`BuildingFreePlot(_building)`** (new, `PlotScripts.gml`): finds the `oBuildingPlot` at a destroyed building's position and clears `blocked`, so the plot becomes buildable again *and* (via the `UpdateTargeting` change above) clickable/targetable again the moment nothing is built on it. No plot reference is stored on building instances -- looked up by position instead, relying on the existing invariant that `TryPlaceBlueprint` always spawns a building at its plot's exact x/y.

### Assumptions (flag if wrong)

- Before this batch, a destroyed building's plot was **never** unblocked by anything in the codebase -- combat death and resource depletion both `instance_destroy`d the building but left `_plot.blocked = true` forever, permanently sterilizing that plot. This wasn't reported as a symptom yet (probably because nothing had been destroyed/depleted in a playtest so far), but it's fixed as a necessary part of "regain its mask once nothing's built on it."

### Build

- Windows export version bumped `0.0.2.31` → `0.0.2.32` — 4th-digit bump, same convention as last time.

## v0.0.2.31 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Siege now targets anywhere along a castle's actual front wall instead of a single fixed point, per explicit 2026-07-06 request: "make the siege action target the front bounding box of each castle, allowing attacks to happen anywhere along its front edge (the edge facing towards the center of the room)."

### Added

- **`CastleFrontEdgePoint(_castle, _fromPos)`** (`CastleScripts.gml`): returns the point on a castle's real collision box (`bbox_left`/`bbox_right`, GameMaker built-ins — already world-space and sprite-mask-accurate) closest to the room's horizontal center, at whatever height the approaching unit is at (`_fromPos.y` clamped to `bbox_top`/`bbox_bottom`). Deliberately layout-agnostic — it doesn't read `_castle.team` or hardcode "player is left / enemy is right," it just picks whichever bbox edge geometrically faces `room_width / 2`, so it keeps working if castle placement ever changes.

### Changed

- **`Siege_Step`** (`UnitStateSiege.gml`): the `_edgePos` a besieging unit paths toward now comes from `CastleFrontEdgePoint` instead of the generic `NearestBuildingEdgePoint` (`UnitStateAttackMelee.gml`). That function hardcodes `ATTACK_BUILDING_HALF = 24` (assumes every building is 48×48) and clamps against all 4 sides — both wrong for a 350×411 castle. No other siege phase logic (ADVANCE/ASSAULT/SWING/RECOVER/ENGAGE_GUARD, cooldowns, state transitions) was touched.
- **Corrected a stale comment in `CastleScripts.gml`**: the file header previously claimed "nothing in the codebase currently targets a castle in combat." That was wrong — `Siege_Step` already called `UnitTryDealDamage` directly on the castle instance via `GetEnemyCastle()`, bypassing the `oBuildingParent`-ancestry gate that blocks the generic "attack Building" order from ever reaching a castle. Left a correction in place rather than silently rewriting history.

### Not covered by this batch

- `NearestBuildingEdgePoint` itself is untouched — it's still correct for its actual use case (48×48 buildings via the "attack" order), which was confirmed to never include castles.

### Build

- Windows export version bumped `0.0.2.30` → `0.0.2.31` — 4th-digit bump, same convention as last time.

## v0.0.2.30 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Resource depletion, sourced from the uploaded "Resource_Infrastructure Buildings +VISUALS" doc -- unblocks Economic XP, which the previous batch (v0.0.2.29) flagged as blocked for lack of exactly this mechanic.

### Added

- **`BuildingDefinition.resourceLimit`** (new optional field, `BuildingDefinitions.gml`): the TOTAL lifetime units a resource building may ever produce. Omitted (`undefined`) = unlimited, same as before -- only affects buildings that set it.
- **All 5 Tier 1 resource buildings** (Wheat Field, Water Pump, Sawmill, Gold Mine, Iron Mine) now set `resourceLimit: 300`, per the doc's "Resource Limit: 300" line on every one of them.
- **`BuildingUpdateProduction`** now caps production at `resourceLimit`: a tick that would push a building's lifetime `producedTotal` past its limit is clamped to exactly fill the remaining room (never overshoots), and the instant the cap is hit, the building awards its team `ECONOMIC_XP_DEPLETION` (8 XP -- the exact "Economic XP" value from the earlier XP Age Progression doc) and self-destroys via `instance_destroy`. This is the same bare removal combat-death already uses here (`ApplyDamage`) -- there's no dedicated building-destroy cleanup step anywhere in the codebase to mirror, so depletion doesn't skip anything combat-death doesn't already skip too. **No depletion VFX/SFX exists yet** -- the building just vanishes; flag if a visual cue (crumbling, dust, etc.) is wanted.

### Changed

- **`maxHealth` on all 5 Tier 1 resource buildings**: `150` → `100`, per explicit 2026-07-06 direction ("each resource building should keep their 100 max health"). Every other building type (training buildings, etc.) is untouched.

### Not covered by this batch

- The doc also lists Tier 2/3 resource + facility buildings (Village Well, Windmill, Armory, Treasury, Royal Stables, Archer Tower, and many more) with their own resource limits, costs, and special mechanics (production multipliers, resource-consuming production, morale buffs, etc.) -- none of those buildings exist in the codebase yet. This batch only applied the depletion mechanic + doc-sourced numbers to the 5 Tier 1 resource buildings that are already implemented.

### Build

- Windows export version bumped `0.0.2.29` → `0.0.2.30` — 4th-digit bump, same convention as last time.

## v0.0.2.29 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Reconciled the codebase against the uploaded "XP Age Progression System" design doc: per-age XP requirements, a gated (manual, paid) Age Up instead of an automatic one, and wired up most of the doc's actual XP sources (Combat, Strategic, Defensive). Economic XP is flagged as blocked, not wired.

### Changed

- **`AgeXpRequired`/`global.ageXpRequired`** (`ProgressionScripts.gml`): `AGE_XP_REQUIRED` (flat 1000 for every age) replaced with a per-transition lookup — Age I→II 100, II→III 150, III→IV 200, per the doc. `GainXP` and the Fate Token milestone math (`AGE_FATE_TOKEN_INTERVALS`) are unaffected in concept, just now read the current age's requirement instead of one flat constant.
- **`XpBarFillPercent`** (`XpBarScripts.gml`, new): replaces the 3 inline `clamp(xp / AGE_XP_REQUIRED, 0, 1)` call sites (constructor catch-up, `Step()`, `Draw()`) so the bar automatically tracks whichever age is current.
- **Age Up is no longer automatic.** Per the doc's "Age Advances" section: filling the bar now only sets `global.ageUpReady[team]` (new, `oMatchControl/Create_0.gml`) — advancing the age, resetting XP to 0, and clearing the flag all happen in the new `TryAgeUp(_team)`, which also spends a per-age gold cost (`global.ageUpCost`/`AgeUpCost`, using the existing `Cost`/`Purchase` pattern from `Economy.gml`). **No HUD button calls `TryAgeUp` yet** — the data/logic layer is complete and callable, but there's no way to actually trigger an age-up in a running match yet. Flagging as a follow-up.
- **`UnitDefinition.tier`** (`UnitDefinitions.gml`, new field, default `1`): drives Combat XP payout by victim tier. All 6 registered units (Peasant, Bomb Goblin, Mud Golem, Soldier, Archer, Knight) explicitly set `tier: 1` — **assumption, confirmed 2026-07-06: every current unit is Tier 1 for the MVP build; no real tier design exists yet.**

### Added

- **Combat XP** (`ApplyDamage`, `UnitCombatHelpers.gml`): on a lethal hit with an attributable killer, the killer's team gains XP —
  - Killing a unit: by the victim's `UnitDefinition.tier` (Tier 1 = 1 XP, Tier 2 = 3, Tier 3 = 5; only Tier 1 is reachable today).
  - Destroying a building: +5 (`COMBAT_XP_STRUCTURE`). If that building is also an `oResourceBuildingParent`, an additional +5 (`COMBAT_XP_RESOURCE_BLDG`) stacks on top — **+10 total confirmed 2026-07-06**, not a either/or.
- **Strategic XP** (`ApplyDamage` + `TrainingScripts.gml`):
  - Losing a unit: the losing team always gets +1 XP (`STRATEGIC_XP_LOSE_UNIT`), regardless of whether there's an attributable killer.
  - First deployment of a unit type: +5 XP (`STRATEGIC_XP_FIRST_DEPLOYMENT`) the first time a team ever trains a given unit type, tracked via new `global.unitsDeployed[team]` (`oMatchControl/Create_0.gml`). Every subsequent spawn of that type is a no-op.
- **Defensive XP + castle HP** (new `CastleScripts.gml`, wired into `oPlayerCastle`/`oEnemyCastle` Create/Step): neither castle object had *any* events before this — they were pure visual masks with no HP concept at all. Added `CastleInit`/`CastleStep` reusing the same `maxHealth`/`damageTaken` shape every other damageable entity uses (so `ApplyDamage`/`GetCurrentHealth`/`GetDamageTaken` work on castles with zero changes there beyond a generic `noDamageTimer` reset-on-hit hook). Awards +5 XP every 120 real seconds (7200 steps at 1x match speed) a castle goes without taking damage, per the doc's "no damage for 120s" line. **`CASTLE_MAX_HEALTH` (500) is an untuned placeholder — set up with damage-taken plumbing per 2026-07-06 clarification, not a balance decision.** Also: nothing in the codebase currently targets castles in combat, so in practice this timer will just run indefinitely until real siege-targeting against castles exists.

### Blocked

- **Economic XP** ("resource building depletes naturally" per the doc) is **not wired** — no resource-depletion mechanic exists anywhere in the codebase; buildings currently produce forever. Needs a depletion design before this can be built. Not silently dropped — flagging here per standing instruction to surface gaps rather than guess.

### Assumptions (flag if wrong)

- Excess XP beyond a bar's requirement is discarded, not banked/carried into the next age's bar (`GainXP` clamps `_toAdd` to `_roomLeft`).
- All 6 current units are Tier 1 for Combat XP purposes (confirmed 2026-07-06, MVP-only, real tiers to come later).
- Resource-building destruction XP stacks to +10 total (confirmed 2026-07-06), not +5.
- Castle max HP (500) and the "damage taken" plumbing pattern (mirroring units/buildings) are set up per explicit direction, but the actual number is untuned/placeholder.
- No Age Up UI button exists yet — `TryAgeUp` is fully wired but unreachable in a live match until a HUD control calls it.

### Build

- Windows export version bumped `0.0.2.28` → `0.0.2.29` — 4th-digit bump, same convention as last time.

## v0.0.2.28 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Token rewarding frequency change (25%→20% marks) + a milestone-visibility bug fix.

### Changed

- **`AGE_FATE_TOKEN_INTERVALS`** (`ProgressionScripts.gml`): `4` → `5`. `GainXP` now awards a Fate Token every 20% of `AGE_XP_REQUIRED` (20/40/60/80/100%) instead of every 25% -- the token-awarding math was already generic over this macro, so no logic changes were needed there, just the constant + doc comments.
- **`global.xpBarMilestoneOffsets`** (`XpBarScripts.gml`): added a 4th offset, `186px` (48/94/140/186 -- evenly spaced 46px apart), mapping 1:1 to the new 20/40/60/80% marks via the existing `XpBarMilestonePercent` formula (already generic over the array's length, so it "just worked" once the 4th offset was added).

### Fixed

- **Milestone reveal was animating in regardless of whether its threshold had actually been met** (`XpBarWidget.Step()`, `XpBarScripts.gml`): the reveal-progress advance wasn't gated on `milestoneHit`, only the hit-detection/token-toss was -- so every milestone silently drew itself in during its first `XP_BAR_MILESTONE_REVEAL_STEPS` after the widget existed, whether or not that XP mark had been reached. Now gated on `milestoneHit[i]`, so an unmet milestone stays at 0px tall (invisible) until its threshold is actually crossed, per 2026-07-06 clarification.

### Build

- Windows export version bumped `0.0.2.27` → `0.0.2.28` — 4th-digit bump, same convention as last time.

## v0.0.2.27 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Lower HUD: XP bar widget -- fill, quarter-mark milestone reveals, and tossed Fate Token coins.

### Added

- **New `XpBarScripts.gml`**: `XpBarWidget(_team)`, a plain struct (same "owner calls Step()/Draw()" pattern as `BlueprintController`/`FateDrum`) for the lower HUD's XP bar. Wired into `oUnitControl` for `TEAM.PLAYER` (`xpBarWidget`, alongside `blueprintController`).
  - **Backer** (`sXpBar`) and **fill** (`sXpBarFill`) drawn at `XP_BAR_ORIGIN_X/Y` (1616, 842), both at 2x scale. The fill uses `draw_sprite_part_ext` so only `xp / AGE_XP_REQUIRED` (already tracked by `ProgressionScripts.gml`) of its 121px native width shows -- 0% = nothing, 100% = the full width.
  - **Milestones** (`sXpBarMilestone`, a 1px-wide vertical tick): 3 fixed x-offsets (48/94/140px from the origin, per spec) mapped 1:1 to the 25/50/75% quarter-marks `GainXP` already awards Fate Tokens at (the 4th, 100%, coincides with the age-up/bar-reset instead of getting a tick). Each reveals top-to-bottom via the same `draw_sprite_part_ext` approach, animated over `XP_BAR_MILESTONE_REVEAL_STEPS`, and stays fully revealed afterward until the next age resets all 3.
  - **Tossed Fate Token coin** (`sFateTokenSmall`): spawned once per milestone, horizontally aligned to that milestone's x, at the bar's top edge. Tumbles up then falls under `XP_BAR_TOKEN_GRAVITY`, spinning (`image_angle`-equivalent, random clockwise/counterclockwise) and flipping (`image_yscale`-equivalent, via `cos()` on a phase value) the whole way, until it's fallen `XP_BAR_TOKEN_FALL_DISTANCE` past its start (or `XP_BAR_TOKEN_MAX_LIFE` steps pass). Drawn last in `Draw()` so coins always render in front of the bar.
  - A widget created with xp already past a mark (e.g. wired in mid-session) shows that milestone as already-revealed instead of animating/tossing a coin retroactively.

### Assumptions (flag if wrong)

- The 3 milestone offsets (48/94/140px) are the literal spec values, used as-is -- they don't divide 121px (the fill's native width) into exact quarters, so if that was meant to line up exactly, the offsets (or the fill width) need reconciling.
- Milestone i (by list order) maps to the i-th quarter-mark (25/50/75%) in ascending order -- not stated explicitly, inferred from both lists being given smallest-to-largest.
- Coins are plain struct data drawn manually in `Draw()` (not real GM instances, unlike `oResourceProducedParticle`), since they're part of a GUI-space widget rather than a world-space effect -- same category as `FateDrum`'s items.
- No per-library Notion-compatible markdown doc was added for `XpBarScripts` -- flagging that this hasn't actually been done for any script library in the repo yet (checked: none exist), despite the CLAUDE.md convention. Worth a decision on whether to start.

### Build

- Windows export version bumped `0.0.2.26` → `0.0.2.27` — 4th-digit bump, same convention as last time.

## v0.0.2.26 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Two small visual fixes: resource-produced particles draw-order, and a smooth drum landing. Also folds in a few manual tuning tweaks made directly in the IDE tonight.

### Tuned (manual)

- **`FATE_DRUM_SLOT_COUNT`** (`FateEngineDrumScripts.gml`): `8` → `5`.
- **`BLUEPRINT_UI_ORIGIN_X`/`_Y`** (`BlueprintScripts.gml`): `640`/`810` → `660`/`830`.
- **`BLUEPRINT_SLOT_PADDING`** (`BlueprintScripts.gml`): `4` → `1`.

### Changed

- **`oResourceProducedParticle`**: now sets `depth = -room_height - 1` in `Create_0`. Most instances in this project sort with `depth = -y` (see `oUnitParent`), which only ever ranges from `-room_height` to `0` -- pushing particles past that most-negative end guarantees they draw on top of everything, regardless of where in the room they spawn.
- **`FateDrum` (`FateEngineDrumScripts.gml`)**: landing is no longer an instant snap. Once deceleration (`"stopping"`) slows below the threshold, the drum now hands off to a new `"landing"` state that eases `spinAngle` toward the nearest slot boundary (`landingTarget`) over several steps (`FATE_DRUM_LAND_EASE_RATE`, new macro) instead of jumping there in one frame. The eased delta is normalized to the shortest way around the circle first, so if deceleration overshot slightly past the boundary, the drum "rubber-bands" back up to it rather than snapping forward to the next one -- per 2026-07-06 request. Snaps exactly to `landingTarget` (and applies `pendingResult`, same as before) once within `FATE_DRUM_LAND_SNAP_EPSILON` (0.5°).
  - `oFateEngineDrumTest`'s click handler treats `"landing"` the same as `"spinning"`/`"stopping"` (no-op) -- you can't re-spin until the drum is fully `"stopped"`, same as before.

### Build

- Windows export version bumped `0.0.2.25` → `0.0.2.26` — 4th-digit bump, same convention as last time.

## v0.0.2.25 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Engine layout pass 3: drum position + hover/click hit-test fix.

### Changed

- **`oFateEngineDrumTest`**: drums shifted DOWN by their own whole height (orbit diameter, `2 * radius` = 112px) relative to the body -- only the drums moved, the body/overlay/rects didn't.
- **Hover + click hit test switched from circular to rectangular** (`Draw_64`/`Step_0`, same fix in both): the old `point_distance(...) > radius + 48` circular test used a 104px radius, but drums are only 104px apart center-to-center, so adjacent drums' hit zones overlapped and could highlight/click more than one at once. Now tested as independent width/height bounds (`abs(dx) > halfW || abs(dy) > halfH`) -- half-width is a new, much narrower placeholder (44px, leaves a gap at the 52px half-spacing), half-height keeps the old generous tolerance (`radius + 48`) since items can still sit well above/below center via the depth-based offset.

### Build

- Windows export version bumped `0.0.2.24` → `0.0.2.25` — 4th-digit bump, same convention as last time.

## v0.0.2.24 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Engine layout pass 2: clear the UI bottom bar, add the modal-overlay dark backdrop, and give each drum a backing card.

### Changed

- **`oFateEngineDrumTest`**: whole engine (body + drums) shifted up 268px so it sits above the UI's bottom bar -- `bodyBottomY` (instance var, set in `Create_0`) now anchors `sFateEngineBody`'s bottom edge, and drum Y is derived from it (`bodyBottomY - 338`) instead of the raw GUI height.
  - Added a full-screen dark overlay (`c_black` @ 0.6 alpha) drawn first, behind everything else, so the Fate Engine reads as a modal over the rest of the UI.
  - Added a backing rectangle per drum -- `#E1D3EA`, 50x69, centered on the drum -- drawn after the overlay but before that drum's icons, so it sits behind the spinning items and in front of the dark backdrop.

### Build

- Windows export version bumped `0.0.2.23` → `0.0.2.24` — 4th-digit bump, same convention as last time.

## v0.0.2.23 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fate Engine drum visuals quick-fix: real placeholder art + final GUI layout.

### Changed

- **`FateEngineDrumScripts.gml`**: `FateDrumRandomPlaceholderItem()` now draws from real Fate Engine art instead of the generic `sResourceIcons` stand-in -- a coin-flip between a "resource stack" item (`sFateEngineResources`, indexed by `global.resourceIconOrder`, same 10-frame order confirmed against `sResourceIcons`) and a "blueprint" item (a random registered building's own sprite, read generically off `global.__buildingDefRegistry` via `GetBuildingDefinition`/`ds_map_keys_to_array` so this never goes stale as buildings are added). All drum items are 48x48 at native size.
  - New `FATE_DRUM_ITEM_SCALE` macro (2) -- every item now draws at 2x (96x96) inside `FateDrum.Draw()`, layered on top of the existing depth-based shrink. Callers keep working entirely in GUI space; the scale is invisible to them.
- **`oFateEngineDrumTest`**: repositioned the 3 drums to the real GUI layout -- centered horizontally, anchored 338px up from the GUI bottom edge, at -104/0/+104 from center. Orbit `radius` bumped `48` → `56` (placeholder/tunable -- not specified, chosen because items now render up to 96x96 and looked cramped at the old radius). Now also draws `sFateEngineBody` at 2x scale, bottom-center-anchored flush with the GUI bottom edge, AFTER the drums so the body renders in front of them. Hover/click hit-test radius padded +48 to roughly account for the larger (96x96) visual footprint of items relative to the drum's geometric orbit radius -- still an approximation, not a real per-item bounding box.

### Fixed (mid-session)

- **`Blank Pixel Game.yyp` truncated again** (cut off mid-string inside `TextureGroups`, same underlying IDE-reopen cause as every previous occurrence) and **`oFateEngineDrumTest/Step_0.gml` was found truncated mid-statement** (cut off inside the `else if` on a stopped-drum click handler) partway through this batch -- both reconstructed from known-correct content and reverified.

### Build

- Windows export version bumped `0.0.2.22` → `0.0.2.23` — 4th-digit bump, same convention as last time.

## v0.0.2.22 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fate Engine, part 1: the drum render. First piece of the roguelike meta-progression slot machine (design discussed 2026-07-05) -- just the spinning-cylinder visual and lock-and-read mechanic, no session flow/odds/corruption yet.

### Added

- **New `FateEngineDrumScripts.gml`**: `FateEngineItem` (generic sprite/subimg/label struct -- deliberately reward-agnostic so the real reward table can hand a drum any resolved result later) and `FateDrum`, a faked-3D cylinder (classic 2D "carousel" trick: `FATE_DRUM_SLOT_COUNT` items spaced around a vertical ellipse, `depth = cos(angle)` and `offsetY = radius * sin(angle)` per slot). Only the front hemisphere (`depth > 0`) is drawn; the back hemisphere is where a slot's item gets silently swapped to a new one the instant it crosses in, so the reel appears to cycle through endless items without ever showing the swap (requirement 1).
  - `FateDrum` is a plain struct driven by an owner's Step/Draw, same pattern as `BlueprintController`/`SelectionController` -- not a GM instance.
  - `Spin()`/`Stop(_targetItem)` control state (`"stopped"`/`"spinning"`/`"stopping"`); stopping decelerates then snaps to the nearest slot boundary. `Stop` already accepts an optional `_targetItem` so the future weighted-reward task can force a specific landing result without touching this file again -- unused for now.
  - `GetLockedItem()` returns whichever item sits at the front/landing position, but only once `state == "stopped"` -- this is the "read the item it locked to" requirement (2), meant for a hover tooltip (or eventually cash-out payout).
  - Slots are populated by `FateDrumRandomPlaceholderItem()` -- a STUB that just cycles the 10 base-resource icons (`sResourceIcons`/`global.resourceIconOrder`). The real weighted reward table (resource building / training building / resource bundle / event, scaled by corruption) isn't designed yet -- this only exists so the spin/swap/lock mechanic is visually testable now.
- **`oFateEngineDrumTest`** (new object, temporary) -- spawns 3 `FateDrum`s, spins them on room start, click a spinning drum to stop it / a stopped one to re-spin, hover a stopped drum to see its locked item's label. Wired into `rmTestGameplay`. Explicitly a throwaway harness -- remove once the real Fate Engine overlay (lock buttons, spin/cash-out flow) exists.

### Build

- Windows export version bumped `0.0.2.21` → `0.0.2.22` — 4th-digit bump, same convention as last time.

## v0.0.2.21 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Resource buildings now fire a little particle burst every time they produce.

### Added

- **`oResourceProducedParticle`** (new object, `Effects` folder) -- a short-lived particle: drifts by its own `vx`/`vy`, gathers `RESOURCE_PARTICLE_GRAVITY`, fades out over `life`/`lifeMax`, then self-destroys. Draws either the resource's actual `sResourceIcons` frame (`kind == "icon"`) or a tiny flat-color square (`kind == "square"`) -- one object handles both since they share identical drift/fade/destroy behavior and only differ in what Draw does with them.
- **New `ResourceParticleScripts.gml`**: `SpawnResourceProducedParticles(_building, _resource)` spawns 1 icon particle (drifts straight up) + `RESOURCE_PARTICLE_SQUARE_COUNT` (6) square particles (1-2px, random outward burst angle/speed with an upward bias, color randomly interpolated between `RESOURCE_PARTICLE_GOLD_COLOR` (gold, #FFD700) and `c_white` via `merge_color`) at the building's position.
- **`PlayResourceProducedEffect` (`BuildingDefinitions.gml`) is no longer a debug-log stub** -- it now calls `SpawnResourceProducedParticles`, so every whole unit of resource `BuildingUpdateProduction` produces gets a real burst (still fires once per unit even when several are produced in the same frame).

### Fixed (mid-session)

- **`BuildingDefinitions.gml` was found truncated mid-edit** (cut off mid-word inside the new `PlayResourceProducedEffect` doc comment, missing the rest of the function) -- same underlying cause as the recurring `.yyp` truncation (the IDE open and saving alongside this session). Reconstructed from the known-correct content (this file's own just-written edit, not git history, since git predates this session's building/particle work) and reverified brace/paren balance. `Blank Pixel Game.yyp` needed the same fix again too, same procedure as every previous time.

### Noted, not acted on

- Per clarification: `blocked` correctly means "this plot can never be built on again" -- it's tied to a roguelike meta-progression mechanic (gaining more castle plots between runs), not a bug. The OTHER issue flagged last time (the `image_index = (!blocked) + (!inside)` formula in `oBuildingPlot/Step_0.gml` collides two unrelated states onto the same sprite frame) is still unresolved and independent of this clarification -- still holding off on touching it until you say what the 3 `sPlot` frames should actually represent.

### Build

- Windows export version bumped `0.0.2.20` → `0.0.2.21` — 4th-digit bump, same convention as last time.

## v0.0.2.20 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Wheat Field cost corrected, and playtest blueprint seeding now covers every registered building.

### Changed

- **Wheat Field's cost corrected to the sheet's "Wheat Farm" row**: 20 water + 10 wood (was 15 wood + 10 coins, which pre-dated this exact sheet row being consulted). Starting resources (50 wood/water/iron/gold/wheat) already fully cover it.
- **`oMatchControl`'s starting blueprint seed now gives each team one of every registered building** (Wheat Field, Peasant Ward, Boom Hut, Bog Foundry, Barracks, Archery Range, Round Table, Water Pump, Sawmill, Gold Mine, Iron Mine) instead of just 3x Wheat Field + 1x Peasant Ward -- playtest-only, per request. The final build will only start the player with one of each tier-1 RESOURCE blueprint specifically; noted in the comment so this doesn't get mistaken for the intended shipping loadout later.

### Investigated (not yet fixed -- pending design confirmation)

- **Why building plots visibly change appearance the instant a building is placed on them:** `oBuildingPlot/Step_0.gml` recomputes `image_index = (!blocked) + (!inside)` every single frame. `inside` (and `far`, unused here) are set once at plot spawn (`PlotScripts.gml`) and never change -- so in practice the only thing that ever changes this formula's result during a match is `blocked` flipping true the moment `TryPlaceBlueprint` places a building (`BlueprintScripts.gml`, `_plot.blocked = true`). That single flip always shifts `image_index` down by exactly 1 (since `!blocked` drops from 1 to 0), which is the visible "changes when built on" symptom.
  - There's a second, independent bug in the same formula: it only has 3 output values (0/1/2) for 4 possible (blocked, inside) combinations, so two unrelated states collide onto the same frame -- an unblocked INSIDE plot and a blocked OUTSIDE plot both compute to `image_index = 1` and render identically.
  - Sprite `sPlot` has exactly 3 frames, which just about fits the additive formula's range, but nothing documents what each frame is actually supposed to represent, and the raw PNGs don't make a confident semantic reading possible from code alone (frame 0 looks like a distinct paved/brick texture, frame 1 plain ground, frame 2 has a highlighted border). Not fixing this blind -- need to know the intended mapping (does "occupied" deserve its own dedicated frame regardless of inside/outside? should inside/outside still show through once blocked?) before touching it.

### Build

- Windows export version bumped `0.0.2.19` → `0.0.2.20` — 4th-digit bump, same convention as last time.

## v0.0.2.19 — 2026-07-05 (uncommitted — working tree only, not yet committed)

The remaining 4 tier-1 resource buildings are in: Water Pump, Sawmill, Gold Mine, Iron Mine.

### Added

- **`oWaterPump`, `oSawmill`, `oGoldMine`, `oIronMine`** -- new objects, all parented to `oResourceBuildingParent` (same inheritance chain as `oWheatField`: team/radius from `oBuildingParent`, then `BuildingApplyDefinition` + the Step-event production tick, all driven by the registered `BuildingDefinition` -- nothing building-specific in `Create_0.gml` beyond `event_inherited()`). Sprites (`sWaterPump`/`sSawmill`/`sGoldMine`/`sIronMine`) and their `Resource/` subfolders already existed in the project, pre-sized 48x48 with center origin to match every other building.
- **4 new `BuildingDefinition` registrations** (`BuildingDefinitions.gml`) -- cost and production rate are REAL, sheet-sourced values from the Item Costs sheet's "Production Buildings" section, not placeholders:
  - Water Pump: 20 wood → 1 water/sec.
  - Sawmill: 40 water → 1 wood/sec.
  - Gold Mine: 70 water + 30 iron → 1 gold/sec.
  - Iron Mine: 30 water + 60 wood → 1 iron/sec.
  - `maxHealth` is the one placeholder value (150, matching Wheat Field) -- the sheet has no building-HP column, same gap as every other building.
- **Not seeded into starting blueprints.** Following the same precedent set by the 5 tier-1 training buildings (Boom Hut/Bog Foundry/Barracks/Archery Range/Round Table) -- only Wheat Field/Peasant Ward are in the `oMatchControl` test-seed list, so these 4 are fully defined/placeable but won't appear in a fresh match until the real blueprint-acquisition system exists (still not designed) or someone adds test seeding for them.

### Known issues (flagged, not touched)

- **The sheet's "Wheat Farm" row (20 water + 10 wood → 1 wheat/sec) doesn't match this project's already-implemented Wheat Field cost** (15 wood + 10 coins, per the `oMatchControl/Create_0.gml` comment). Out of scope for this request (only asked for the other 4), but worth a look since it means Wheat Field was built before this exact sheet section was consulted, or the sheet changed since.

### Build

- Windows export version bumped `0.0.2.18` → `0.0.2.19` — 4th-digit bump, same convention as last time.

## v0.0.2.18 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Resource icon translation for Scribble text, plus the player's resource bar HUD.

### Added

- **New `ResourceUIScripts.gml`**, built around `global.resourceIconOrder` (wood, wheat, water, iron, gold, meat, bones, coal, weapons, coins -- a plain global array set once, not a `#macro`, since a macro array literal would re-allocate every read) matching `sResourceIcons`' 10 frames 1:1. xp/fateTokens intentionally have no icon (per request -- they sit outside the base resources).
  - **`ResourceIconIndex(_resource)`** -- name to frame index (0-9), or -1 if not a base resource.
  - **`ResourceIconTag(_resource)`** -- name to Scribble inline-sprite tag, `"[sResourceIcons,N]"`.
  - **`CostToScribbleText(_cost)`** -- the actual translator requested: takes a `Cost` struct and returns a ready-to-draw Scribble string, one `"[sResourceIcons,N]<amount>"` run per non-zero base resource (double-space separated). Nothing calls this yet -- no tooltip/description UI reads `BuildingDefinition.description`/`UnitDefinition.description` today, so this is the primitive future tooltip work will use, not wired to a specific screen.
  - **`DrawResourceBar(_team)`** -- renders all 10 icons in a row, first (Wood) icon centered at `(RESOURCE_BAR_ORIGIN_X, RESOURCE_BAR_ORIGIN_Y)` = (466, 1060), each next icon `RESOURCE_BAR_ICON_SPACING` (152px) to the right center-to-center, with `_team`'s live count drawn `RESOURCE_BAR_TEXT_GAP` (10px) off each icon's right EDGE (icon center + half its width + the gap), vertically centered on the icon. Wired into `oUnitControl/Draw_64.gml` as `DrawResourceBar(TEAM.PLAYER)`, alongside the other player-HUD draws.

### Build

- Windows export version bumped `0.0.2.17` → `0.0.2.18` — 4th-digit bump, same convention as last time.

## v0.0.2.17 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Unit selection no longer starts from a press in the bottom UI panel area.

### Changed

- **`SelectionController.BeginDrag()` (`UnitSelection.gml`) now no-ops if the press starts at or below `SELECTION_DRAG_MIN_GUI_Y` (812, out of a 1920x1080 GUI, per request).** Below that line is bottom-panel UI real estate (the blueprint panel, etc.), not the playfield -- a press there should never start a world-space selection box, including over empty panel padding that a widget's own hit-test doesn't claim (`BlueprintController.TryBeginDrag` only claims filled slots, so gaps between/around slots were previously falling through to a normal selection drag).
  - Since this codebase implements a plain click-select as a very-short drag (`EndDrag`'s `_isClick` heuristic), gating `BeginDrag` covers both drag-box selection AND single-click selection in one place -- a click starting below the line selects nothing, not just "doesn't start a box."
  - Only the drag's START is checked, per request -- a drag that begins above the line and is dragged down past it while held is unaffected.
  - Room-space `mouse_x`/`mouse_y` aren't usable for this check (camera-relative), so it reads `device_mouse_y_to_gui(0)`, the same GUI-space approach `BlueprintController` already uses for its own hit-testing.

### Build

- Windows export version bumped `0.0.2.16` → `0.0.2.17` — 4th-digit bump, same convention as last time.

## v0.0.2.16 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Blueprint UI panel repositioned and enlarged, per request.

### Changed

- **`BlueprintController.GetOrigin()` (`BlueprintScripts.gml`) now returns a fixed top-left anchor** (`BLUEPRINT_UI_ORIGIN_X/Y` = 660, 830) instead of the old bottom-center-of-GUI calculation. No longer depends on `display_get_gui_width/height`.
- **New `BLUEPRINT_UI_SCALE = 2` macro drives the whole panel's size.** `GetSlotRect` (the single source of truth both `Draw` and `TryBeginDrag` already read from) now multiplies `BLUEPRINT_SLOT_SIZE`/`BLUEPRINT_SLOT_PADDING` by this scale, so the clickable area and the drawn area stay identical automatically — nothing render-only or hit-test-only to keep in sync. Both `draw_sprite` calls (in-slot icon, dragged icon following the cursor) switched to `draw_sprite_ext` with `xscale`/`yscale` = `BLUEPRINT_UI_SCALE` so the building icons themselves scale up too, not just the slot borders.
- **Not scaled: the stack-count text** (`draw_text` for `_stack.count`). Wasn't asked for, and scaling text needs `draw_text_transformed` instead of a quick multiply -- left as-is against the now-2x slots. Flagging in case it reads too small once you see it in place.

### Build

- Windows export version bumped `0.0.2.15` → `0.0.2.16` — 4th-digit bump, same convention as last time.

## v0.0.2.15 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fixed a pre-existing `Purchase` bug the AI's build-up state finally triggered.

### Fixed

- **`Purchase(_costStruct, _team)` (`Economy.gml`) deducted against the wrong struct.** `Purchase` is a plain top-level function, not a `Cost` method, so `self` inside its body is whatever the *caller's* `self` happened to be — not `_costStruct`. Since `Purchase` is always called several plain-call frames deep (`TryPlaceBlueprint`/`TrainingScripts` → `Purchase`), and those chains are frequently entered via a dot-call on some other struct (a `State` struct via `currentState.onStep(owner, self)` for the AI path, `BlueprintController` for the player drag-to-place path), `self` at the point `Purchase` ran was that unrelated struct, not the `Cost` instance. `struct_get(self, _res)` then returned `undefined` for every resource key (starting with `wood`, first in iteration order), and `_resAmt - _costAmt` threw the reported `DoSub : undefined value` the moment a purchase actually got past `CanAfford`.
  - This was already present in `HEAD` before this session's XP/resource work touched the file — confirmed via `git show HEAD` — so it wasn't introduced by the new `xp`/`fateTokens` fields, it just needed a successful AI (or player) purchase to actually reach line 116 and fire. Likely the first time the AI's build-up state got resources + a valid plot at the same time.
  - `CanAfford` (the `static` method a few lines up) does NOT have this bug — it's called via `_costStruct.CanAfford(_team)`, a proper dot-call, which correctly binds `self` to `_costStruct` for that call.
  - Fix: read the cost amount off `_costStruct` explicitly (`struct_get(_costStruct, _res)`) instead of relying on the ambient `self`.
  - Worth a smoke test of both the AI build-up path and the player's manual drag-to-place, since both were exposed to this and neither may have been confirmed to fully complete a real deduction before.

### Build

- Windows export version bumped `0.0.2.14` → `0.0.2.15` — 4th-digit bump, same convention as last time.

## v0.0.2.14 — 2026-07-04 (uncommitted — working tree only, not yet committed)

Two new resources (XP, Fate Tokens) and a `GainXP` accumulator to drive them, plus a bug fix: three script files from the last two sessions' ranged-combat work were never actually registered with the project and would not have compiled.

### Added

- **`xp` and `fateTokens`** — two new per-team resources, added to `global.resources[_team]` (`oMatchControl/Create_0.gml`) and to `Cost`/`ResourceCost` (`Economy.gml`) alongside the existing 10, so `CanAfford`/`Purchase` pick them up for free (both already walk `global.resources` generically by field name). Both start at 0 for both teams — no starting loadout change.
- **`global.age`** (`oMatchControl/Create_0.gml`) — per-team current age, `[1, 1]` at match start. Ages and blueprint-tier-acquisition odds are explicitly NOT designed yet (per 2026-07-04 discussion) — nothing reads this to affect blueprints. It's just the counter.
- **`GainXP(_team, _amount)`** (new `ProgressionScripts.gml`) — the requested entry point for awarding XP; nothing calls it yet (XP sources aren't wired up — that's next). Adds `_amount` to the team's current age bar (`AGE_XP_REQUIRED` = 1000, flat placeholder, no per-age scaling designed):
  - Awards one Fate Token for each of the bar's 4 equal quarter-marks (`AGE_FATE_TOKEN_INTERVALS`) crossed by the gain, computed from before/after position so a large single gain still awards every token earned, not just one. Filling the bar outright nets exactly 4 tokens, with the 4th landing on the same call that ages the team up.
  - Advances `global.age[_team]` (capped at `AGE_MAX = 4`) each time the bar fills, carrying overflow into the next age's bar via a while-loop — a big enough gain can advance more than one age in one call.
  - **Judgment call, flagged for sanity-check:** once already at `AGE_MAX`, the bar stops at full instead of looping/prestiging — further XP past that point is discarded rather than granting more tokens indefinitely. Revisit once ages are actually designed.
  - Both the XP added and any Fate Tokens earned are recorded via the existing `AnalyticsRecordResourceProduced` hook, same as building production.

### Fixed

- **`ProjectileScripts.gml`, `UnitStateAttackRanged.gml`, and `UnitStateCombatRanged.gml` had no `.yy` files and were never added to `Blank Pixel Game.yyp`'s resource list.** These were created across the last two sessions' ranged-combat batches (projectile spawning/`SpawnProjectile`, the `attackRanged` state, and the `combatRanged` state) but a GameMaker script only compiles if it's a registered project resource — a loose `.gml` file on disk with no matching `.yy`/`.yyp` entry doesn't exist as far as the IDE/compiler is concerned. Net effect: `SpawnProjectile`, `AttackRanged_Enter/Step/Exit`, and `CombatRanged_Enter/Step/Exit` would have been undefined-function errors at runtime despite reading correctly in the source. Created the three missing `.yy` files and added all three to the `.yyp` (alphabetically, matching existing ordering). Worth a project reload + smoke test of an Archer fighting something, since this is the first time this code has had a chance to actually run.
- **`Blank Pixel Game.yyp` was found truncated again mid-session** (same failure mode as before — missing tail: `RoomOrderNodes` entries, `templateType`, `TextureGroups`, final `}`), discovered while validating this batch's edits. Reconstructed the same way as last time: working-tree content up to the truncation point + the stable tail from git HEAD (`RoomOrderNodes`/`templateType`/`TextureGroups` haven't changed all session), verified via JSON parse + duplicate-name check. This has now happened three times this project — may be worth checking whether something (an editor autosave, a sync tool) is racing writes to this file.

### Build

- Windows export version bumped `0.0.2.13` → `0.0.2.14` — 4th-digit bump, same convention as last time.

## v0.0.2.13 — 2026-07-03 (uncommitted — working tree only, not yet committed)

`ChooseCombatTarget` is a real weighted decision now, and every existing unweighted "just grab the nearest enemy" pick across guard/defend/attack/attackRanged/siege now routes through it.

### Added

- **`ChooseCombatTarget(_unit, _radius, _castlePos)`** (`GatherScripts.gml`, moved from the stub that used to live in `UnitScripts.gml`) — scores every enemy unit within `_radius` on four weighted criteria and returns the best one (or `noone` if nothing's in range, same contract the old stub and `_FindNearestEnemy` both had):
  - **Health remaining** (`COMBAT_TARGET_WEIGHT_HEALTH = 1.0`) — rewards low health (`damageTaken / maxHealth`), i.e. finishing off the wounded.
  - **Attack stat** (`COMBAT_TARGET_WEIGHT_ATTACK = 0.4`) — rewards high `attackDamage`, i.e. focusing the biggest threat. Raw value, not normalized -- flagged in the doc comment as a placeholder simplification.
  - **Proximity** (`COMBAT_TARGET_WEIGHT_PROXIMITY = 1.2`) — rewards closeness to the deciding unit.
  - **Activity** (`COMBAT_TARGET_WEIGHT_ACTIVITY = 1.0`, via new `_CombatTargetActivityScore`) — rewards a candidate currently attacking one of ours: sieging our castle scores highest, then attacking one of our buildings, then already fighting one of our units, then idle (guard/defend) scores 0. This is the "whether it is attacking a unit, building, or castle" criterion.
  - **Castle proximity** (`COMBAT_TARGET_WEIGHT_CASTLE = 0.8`, only when `_castlePos` is passed) — not one of the four requested criteria, added to preserve `_FindNearestEnemyInSweep`'s existing castle-proximity weighting for siege specifically, rather than silently dropping that behavior. Flagging this addition explicitly since it goes beyond what was asked for -- worth a sanity check.
  - All five weights are placeholders per instruction -- tune freely, nothing else depends on these specific numbers.
- **Every previous unweighted target pick now goes through it:** `Guard_Step`/`Defend_Step`'s aggro trigger, `Attack_Step`/`AttackRanged_Step`'s defender-interrupt, and all three guard-sweep checks in `Siege_Step` (ADVANCE/ASSAULT/RECOVER phases) were all calling `_FindNearestEnemy` or `_FindNearestEnemyInSweep` directly -- all now call `ChooseCombatTarget` instead. `Combat_Step`/`CombatRanged_Step`'s re-acquire-on-death call didn't need to change (it already called `ChooseCombatTarget(_unit)` with the stub; the real implementation's `_radius` parameter defaults to `_unit.attackAggroRadius` via the same `??=`-in-the-body idiom `UnitPursueTarget` already uses, since a parameter default can't reference an earlier parameter directly in GML).

### Known issues (new)

- **`_FindNearestEnemy`/`_FindNearestEnemyInSweep` (`GatherScripts.gml`) are now unused dead code**, left in place rather than deleted -- flagged in their own doc comments as superseded, in case something still wants a plain unweighted lookup. Candidates for removal if nothing ends up needing them.

### Build

- Windows export version bumped `0.0.2.12` → `0.0.2.13` — 4th-digit bump, same convention as last time.

## v0.0.2.12 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Buildings now use the same damage-taken setup as units, and "combat" is finally wired up the way it was originally designed: an interim state guard/defend pop into when they need to fight, then return from.

### Added

- **Building HP.** `BuildingDefinition` (`BuildingDefinitions.gml`) gained `maxHealth` (optional, defaults to 200 -- an unbalanced placeholder, same status every cost/rate number in that file already had; the data sheet has no building-HP column). `BuildingApplyDefinition` now sets `maxHealth`/`damageTaken` directly on every building instance, alongside its existing production/training fields. `oBuildingParent/Create_0.gml` also sets defensive `maxHealth = 0` / `damageTaken = 0` defaults, same "Create sets placeholders, a script function fills in the real ones right after" pattern as units/projectiles.
- **`ApplyDamage`/`GetCurrentHealth` generalized to work against buildings, not just units.** New `GetDamageTaken(_instance)`/`SetDamageTaken(_instance, _value)` (`UnitDefinitions.gml`) abstract over where damageTaken actually lives: nested at `unitData.damageTaken` for units (so it survives a station/redeploy swap) vs. a flat `damageTaken` directly on the instance for buildings (which have no station/redeploy concept to preserve it across). `UnitCurrentHealth` renamed to `GetCurrentHealth` to match -- grep confirmed exactly one caller (`ApplyDamage`) at rename time. Melee and ranged attacks against buildings now do real damage instead of silently no-opping.
- **"combat" is reachable for the first time.** It was registered in every unit's FSM since early on but nothing ever transitioned into it -- confirmed dead code as of last session. Per design, it's an interim state `guard`/`defend` pop into when they need to fight:
  - **Proximity aggro** -- `Guard_Step`/`Defend_Step` now check `_FindNearestEnemy(_unit, _unit.attackAggroRadius)` first thing every step (same mechanism `Attack_Step`'s defender-interrupt already used), and hand off to combat via new `UnitEnterCombat(_unit, _target)` (`UnitCombatHelpers.gml`) the instant something's in range.
  - **Reactive-on-hit** -- `ApplyDamage` now calls `UnitEnterCombat` the instant a non-lethal hit lands on a unit currently in `"guard"` or `"defend"`, using the attacker as the target. A unit already fighting (attack/attackRanged/siege/combat/combatRanged) is left alone -- taking a hit doesn't retarget it.
  - **`UnitEnterCombat`** picks `"combat"` or `"combatRanged"` based on the unit's `"ranged"` tag -- same dispatch the `"attack"` order already used for `"attack"` vs `"attackRanged"`.
  - **`UnitRevertFromCombat(_machine)`** replaces `Combat_Step`'s two hardcoded `ChangeState("guard")` exits (no target / target leashed) with `_machine.RevertToPrevious()` (`StateMachine.gml` -- already existed, never used until now), so a unit correctly goes back to whichever of guard/defend it was interrupted from, not always guard. Falls back to `"guard"` if `previousName` is somehow unset, so a unit can never get stuck in combat with nowhere to revert to.
  - **New `"combatRanged"` state** (`scripts/UnitStateCombatRanged.gml`) -- structural duplicate of `"combat"` (same reasoning as `"attackRanged"`/`"attack"`: this codebase already hit a bug from sharing state functions across orders), swapping `UnitTryFireProjectile` in for `UnitTryDealDamage` at the attack phase. Registered in `oUnitParent/Create_0.gml` alongside the other states.

### Known issues (new)

- **`ChooseCombatTarget` is still a stub** (always returns `noone`). When a unit's combat target dies mid-fight, it reverts to guard/defend rather than picking a new one -- if another enemy is still in aggro range, the outer proximity check (now running every Guard_Step/Defend_Step) picks it back up on the next step regardless, so this mostly self-heals, but a true "keep fighting whoever's closest" re-target was not built this session.
- **Reactive-on-hit only fires from `"guard"`/`"defend"`.** A unit mid-`"attack"`/`"siege"` that takes a hit from a THIRD party (not its current target) doesn't do anything differently -- only `"attack"`/`"attackRanged"`'s own built-in defender-interrupt (proximity-based, not damage-based) handles that case.

### Build

- Windows export version bumped `0.0.2.11` → `0.0.2.12` — 4th-digit bump, same convention as last time.

## v0.0.2.11 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Real damage/death for the first time, plus a ranged attack system (projectile spawn, spawn/arc/land, hit resolution) built on top of it. Archer is the first unit to use it.

### Fixed

- **`Blank Pixel Game.yyp` was truncated mid-write** (cut off partway through the sprite resource list, missing the closing `resources` bracket and the entire `RoomOrderNodes`/`templateType`/`TextureGroups` tail) by an external save that landed while this session was mid-edit. Reconstructed by taking the working tree's content up to the truncation point (which already had every object this session and prior sessions added) and appending the missing tail from the last commit (`54e76cd`) unchanged. Verified: parses cleanly, no duplicate resource names, every object added this session and prior sessions is still present exactly once.
- **`UnitTryDealDamage`'s "TODO: damage calculation" stub is gone.** It now calls the new `ApplyDamage` (see Added). This is the actual fix requested this session -- everything else below follows from it.

### Added

- **`ApplyDamage(_target, _amount, _source)`** (`UnitCombatHelpers.gml`) — the first real damage-application function in the codebase. Increments `unitData.damageTaken` (clamped to `maxHealth`) rather than tracking a separate "current health" value, so a future max-health buff/debuff never needs a second number rewritten in lockstep — `UnitCurrentHealth` (`UnitDefinitions.gml`, already existed) always derives the live value from the one stored number. Destroys `_target` the instant health reaches 0 — the first place anything in this codebase can actually die — and calls `AnalyticsRecordDeath`/`AnalyticsRecordKill` (`AnalyticsScripts.gml`), which existed already but had no death event to call them from until now. Buildings have no `unitData`/hp concept yet — calling `ApplyDamage` against one logs and no-ops rather than crashing; that's a separate, undesigned system, flagged rather than guessed at.
- **Ranged attack system**, generalized beyond just Archer:
  - **`oProjectileParent`** (root object) + **`oArcherProjectile`** (its first child, sprite `sArcherProjectile`). New `scripts/ProjectileScripts.gml`: `SpawnProjectile`/`ProjectileInit` (set up per-instance state right after `instance_create_layer`, same pattern as `BuildingApplyDefinition`/`UnitApplyDefinition`/`TrainingSpawnUnit`), `ProjectileUpdateMovement` (real x/y position — straight-line `Vector2.Lerp` from launch point to the target's position *at the moment of firing*, not homing, match-speed-scaled same `delta_time` idiom as `BuildingUpdateProduction`), `ProjectileResolveHit` (calls `ApplyDamage` if the target's still there when it arrives, then destroys the projectile either way), `ProjectileArcOffset`/`ProjectileDraw` (the cosmetic parabolic arc: a per-instance vertical draw offset that's 0 at launch/landing and peaks at the midpoint, with a rotation numerically sampled from that same offset function so the drawn angle can't drift out of sync with the drawn position — nose-up at launch, level at the apex, nose-down at landing). The projectile's real, stored `image_angle` is set once at launch to the flat straight-line direction and never touched again; the arc-following rotation is computed separately in `ProjectileDraw` and used only for that draw call.
  - **`UnitTryFireProjectile`** (`UnitCombatHelpers.gml`) — ranged counterpart to `UnitTryDealDamage`, same once-per-swing/hit-frame gating, calls `SpawnProjectile` instead of applying damage on the spot.
  - **`"attackRanged"` FSM state** (new `scripts/UnitStateAttackRanged.gml`) — ranged counterpart to `"attack"` (`UnitStateAttackMelee.gml`). Deliberately a structural duplicate (approach/swing/recover/defender, same as `"attack"`) rather than a branch inside it, matching this codebase's existing precedent of one dedicated state per order rather than shared/branching state logic (see the `"attack"`/`"siege"` dead-code bug from `v0.0.1.0`). The only actual difference from `"attack"` is that both swing points call `UnitTryFireProjectile` instead of `UnitTryDealDamage`.
  - **`UnitDefinition.projectileObject`** (`UnitDefinitions.gml`) — optional field, the projectile a ranged unit fires. Set for Archer (`oArcherProjectile`); left unset (melee) for everyone else.
- **FLAG (FSM/order wiring — CLAUDE.md calls `attack`/`combat`/etc. load-bearing):** `oUnitParent/Create_0.gml` now registers `"attackRanged"` alongside the existing states (purely additive). The `"attack"` order's `onIssue` (`OrderWiring.gml`) now picks `"attackRanged"` vs `"attack"` per unit based on `UnitHasTag(unit, "ranged")` — the one line that changed in that function.

### Known issues (new)

- **Buildings still have no HP.** `ApplyDamage` logs and no-ops against them. Melee units can still swing at buildings (nothing about that changed), it just doesn't do anything yet.
- **The `"combat"` FSM state is unreachable dead code** — discovered this session while scoping where ranged behavior needed to hook in. Nothing anywhere calls `fsm.ChangeState("combat")`; the only currently-reachable attack path is the `"attack"`/`"attackRanged"` order (with its own built-in defender-interrupt sub-phase). Not touched this session since it's unreachable regardless, but worth knowing if `"combat"` is ever wired up for real — it would need the same ranged/melee split `"attack"` just got.
- **`"siege"` was not touched.** A ranged unit sieging a castle still goes through whatever `"siege"` does today (untouched, not investigated this session for building-HP reasons above).
- **Archer's `attackRange` (96) is still a judgment-call placeholder**, not sheet-sourced — the ranged mechanic is now real, but its numbers aren't tuned.

### Build

- Windows export version bumped `0.0.2.10` → `0.0.2.11` — 4th-digit bump, same convention as last time.

## v0.0.2.10 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Peasant stat correction + five tier-1 training buildings/units, sourced from the Project Azurite Data Sheets spreadsheet (Unit Stats + Item Costs tabs).

### Fixed

- **`PATCH_NOTES.md` was truncated in the working tree**, cuttin