# BlueprintScripts

A team's placeable-building inventory (`Blueprint`/`BlueprintStack`), the placement-cost/discount rules, and the `BlueprintController` UI panel that lets a player drag a blueprint onto a plot to build it.

## Blueprint inventory

Each team owns an array of `BlueprintStack` entries (`global.blueprints[team]`) -- one entry per building type, holding how many are currently available to place. Stacks are removed entirely once exhausted (`RemoveBlueprintOne`), and the UI grid renders stacks directly into slots in array order, so an exhausted stack's slot is simply taken over by whatever comes after it -- no compaction step needed anywhere.

`global.blueprints` itself is initialized in `oMatchControl/Create_0.gml` as `[[], []]` rather than `array_create(2, [])`, for the same shared-reference hazard `global.resources` has there -- each `[]` literal is evaluated fresh, so it's safe. See that file's comments.

## Placement cost and plot discounts

`GetPlacementCost(_def, _plot)` returns `_def.cost` after any plot-based discount (2026-07-07 "plot bonuses" request, realizing what `oOuterPlotSpawner`'s header already described as intended): resource buildings placed OUTSIDE the castle (covers both Exterior and Distant plots) cost `PLOT_BONUS_DISCOUNT_FRACTION` (50%) less; training buildings placed INSIDE the castle cost the same 50% less. A building is never both a resource and training building today, and a plot is never both inside and outside, so at most one discount ever applies -- no stacking logic needed. If neither condition is met, returns `_def.cost` unchanged (same instance, not a copy -- callers only read it).

Distant plots also grant a separate stat bonus (maxHealth, resourceLimit) on top of whichever discount applies here -- that's `ApplyPlotBonuses` (`BuildingDefinitions.gml`), applied to the building after creation since it affects stats, not cost.

`BuildingGetsDiscountOnPlot(_def, _plot)` is the discount-eligibility rule factored out of `GetPlacementCost` (2026-07-09) so `GetBestAvailablePlacementCost` can reuse the identical condition instead of re-deriving it and risking drift.

`GetBestAvailablePlacementCost(_team, _def)` scans every `oBuildingPlot` the team owns that's currently placeable (not blocked, not occupied) and returns the cheapest cost achievable right now, plus whether any placeable plot exists at all (2026-07-09 request: "can't afford the blueprint anywhere, including any plots that would give it a discount"). Since the discount is a binary per-building-type/plot-side switch (never partial), "cheapest available" collapses to: the discounted cost if at least one available plot would grant it, otherwise the full cost, as long as at least one available plot exists of any kind. Also returns `discountAvailable` separately so callers showing both the base and discounted price side by side (`CostToScribbleTextWithDiscount`, `ResourceUIScripts.gml`) don't have to re-scan plots themselves.

## Placement

`TryPlaceBlueprint(_team, _buildingType, _plot)` resolves a placement attempt: valid target is an owned, unblocked, unoccupied plot; if valid and affordable, purchases the cost, spawns the building, applies the plot's Distant bonus if any, marks the plot occupied, consumes one blueprint, and records analytics. Every rejection is logged via `show_debug_message` and returns `false` -- the caller decides what "stays in the UI" means.

**2026-08-13: gated by `global.tutorialGuide.restrictionActive` first**, `TEAM.PLAYER` only -- rejects (same `show_debug_message`/`return false` shape) anything whose type isn't in `global.tutorialGuide.allowedBuildingTypes` (an array, since one guided-tutorial phase can allow more than one eligible type -- e.g. Wheat Field and Sawmill), or whose plot is on the wrong side. **The plot-side check is `global.tutorialGuide.requireInside ? _plot.inside : !_plot.inside`** (2026-08-13, was hardcoded `!_plot.inside` until the Peasant Ward phase needed the opposite) -- `_plot != noone` is checked first via `&&` short-circuit so the ternary never touches `.inside` on `noone`. On a placement that satisfies eligibility, calls `global.tutorialGuide.CompleteRestriction(_buildingType)` right before returning `true` -- that call only actually advances/ends the tutorial once EVERY requirement the current phase has (every required building type placed AND, if the phase has any, every unit-training count met -- see `NotifyUnitTrained`/`TrainingScripts.md`) is satisfied, not on the first eligible placement. See `TutorialGuideScripts.md`'s "Player action restriction" section for the full picture, including why this lives here rather than only in `oUnitControl/Step_0.gml`.

Extracted from `BlueprintController.EndDrag` so both the player's mouse-drag flow and a programmatic caller (the AI -- see `AI_TryPlaceBlueprints`, `AIControl.gml`) go through identical cost/analytics/occupancy handling. `EndDrag` just resolves `_plot` from the cursor and calls this.

## BlueprintController (UI panel)

A paginated 5x2 grid of 48x48 slots (rendered/interacted at `BLUEPRINT_UI_SCALE`), fixed top-left GUI anchor (`BLUEPRINT_UI_ORIGIN_X/Y`, replaced the old bottom-centered origin per 2026-07-05 request). Drag a filled slot onto a plot the dragging team owns to place that building, if affordable.

One instance per player-facing controller, currently created by `oUnitControl` (mirrors how it owns `selectionController`/`orderMenu`). An AI-driven controller could use its own instance the same way `SelectionController` already supports `TEAM.ENEMY`.

**Pagination**: `GetStackIndexAtSlot`/`GetSlotRect` key off `page`, so a second page works automatically once inventory exceeds `BLUEPRINT_SLOTS_PER_PAGE`. Prev/next arrows flank the panel (2026-07-13), plus scroll-wheel paging while the mouse sits over the panel or arrows. Pages are contiguous slices of a flat array (no sparse middle pages -- `RemoveBlueprintOne`/`array_delete` always shifts down), so placing the last blueprint on a page can only ever empty the LAST page; `ClampPage()` (called from `EndDrag` and every `UpdatePaging` tick) snaps `page` back to the new last valid page, satisfying "go to an earlier page" with a plain clamp, no special-case logic.

**Hover card dwell delay history**: instant (no delay) from 2026-07-09 ("remove the delay to show info") until 2026-08-05, when a settings-driven delay was added back -- `BLUEPRINT_HOVER_DELAY_STEPS` reads `global.gameSettings.hoverDelayBottomBar` (Gameplay tab's "Bottom Bar Hover Delay" slider, `SettingsOverlayScripts.gml`, default 1 second) fresh every reference via the same "#macro as dynamic expression" trick `PLOT_HOVER_DELAY_STEPS` uses (`PlotHoverScripts.gml`) -- a `#macro` is text substitution, not a compile-time literal, so this reads live without a per-frame lookup at each call site. `hoverTimer` was removed in the 2026-07-09 pass and reinstated for this.

`UpdateHover` also shows a paired unit hover card (2026-07-11) when the hovered blueprint trains a unit, WITH a cost-to-produce row (unlike the placed-building hover context, since this building doesn't exist yet) -- mirrors `BuildingHoverController`'s identical fields.

**Affordability coloring** (2026-07-12, "quicker visuals to see what you can build"): a filled slot's border is `BLUEPRINT_AFFORDABLE_BORDER_COLOR` (white) if that building can be placed AND afforded at at least one open plot anywhere (same `GetBestAvailablePlacementCost` scan the hover title-color check uses), or `BLUEPRINT_UNAFFORDABLE_BORDER_COLOR` (dark gray) otherwise. Empty slots always get the affordable-color border -- nothing to afford.

**Page arrows**: originally plain triangles (no sprite existed). 2026-10-14: replaced with `sLeftArrow`/`sRightArrow` (8x13, 2 frames) drawn at `BLUEPRINT_UI_SCALE`. Frame 0 idle; frame 1 when hovered AND a page is available; 50% alpha (frame 0) when no page is available. Each arrow's edge opposite its pointing direction sits `BLUEPRINT_PAGE_ARROW_GAP` (4 native px, scaled) from the panel's matching side, vertically centered on the panel. `GetPageArrowRects()` now returns sprite-sized rects (was full panel height x 16px), so click/hover hit areas shrank to the sprite. Draw offsets by `sprite_get_xoffset/yoffset` since the two sprites have different origins (left: 8,6; right: 0,0). Removed `BLUEPRINT_PAGE_ARROW_WIDTH`/`_COLOR`/`_DISABLED_COLOR` macros (unused).

`IsMouseOverPanel()` is used by `PlotHoverSuppressed` (`PlotHoverScripts.gml`) and `BuildingHoverSuppressed` (`BuildingHoverScripts.gml`) to keep world-space hover data from showing underneath this GUI-space panel -- see `BuildingHoverScripts.gml`'s header for why that conflict exists. Also true over either page arrow (2026-07-13) since they're visually part of the panel.

## API

- `BlueprintStack(_buildingType, _count)` constructor.
- `AddBlueprint(_team, _buildingType, _count = 1)`, `RemoveBlueprintOne(_team, _buildingType)`.
- `GetPlacementCost(_def, _plot)`, `BuildingGetsDiscountOnPlot(_def, _plot)`, `GetBestAvailablePlacementCost(_team, _def)`.
- `TryPlaceBlueprint(_team, _buildingType, _plot)`.
- `BlueprintController(_team)` constructor -- `GetOrigin`, `GetSlotRect`, `GetStackIndexAtSlot`, `GetPageCount`, `ClampPage`, `NextPage`, `PrevPage`, `GetPageArrowRects`, `UpdatePaging`, `TryBeginDrag`, `CancelDrag`, `EndDrag`, `IsMouseOverPanel`, `GetHoveredStackIndex`, `UpdateHover`, `DrawHoverCard`, `Draw`, `DrawPageArrows`, `DrawOnePageArrow`.

## Carry animation (2026-10-15)

`dragging`/`dragStackIndex` still mean "mouse is held"; a separate `carry` struct drives the visual and outlives the drag through the place/return animation. `UpdateCarry()` must be called every Step (both `oUnitControl/Step_0.gml` call sites, next to `UpdateHover()`).

- **Anchor:** the cursor holds the sprite at `BLUEPRINT_CARRY_ANCHOR_FRACTION` (25%) down from its top, horizontally centered. Rotation pivots about that grab point (the sprite origin position is the rotated offset from it).
- **Phases:** `grab` (slot -> cursor, 10 steps, smoothstep, target tracks the live cursor), `held`, `place` (cursor -> the new building's position, 14 steps, rotation eases to 0, scale eases to the world draw scale), `return` (cursor -> slot, 8 steps).
- **Swing:** per step, target angle = `-mouseDeltaX * 1.5` clamped to +/-35 degrees; a damped spring (stiffness 0.15, damping 0.8) chases it. Moving left gives positive rotation (bottom swings right).
- **Placement:** `EndDrag` calls `TryPlaceBlueprint` as before. On success the building (created immediately, purchase/occupancy/tutorial callbacks unchanged) is set `visible = false` until the carry lands, then revealed with a dust burst. Found via `instance_position` at the plot. On failure (bad plot, unaffordable, tutorial-gated, dropped nowhere) the sprite returns to its slot and a commented-out `sndPlacementFailed` call marks where the failure sound goes. Right-click cancel also returns (no sound line).
- **Dust:** 22 world-space particles from the building's base, random 360 degree directions flattened vertically (0.6), friction 0.92, 20-36 steps, colors 9F8155 / AE8C5B / 8E6D47. Drawn in GUI space by converting from world each frame (so it draws above the world, not behind the building).
- Judgment calls/untuned: all timings, swing constants, particle counts. The hidden building still exists and runs logic for the 14-step landing.
