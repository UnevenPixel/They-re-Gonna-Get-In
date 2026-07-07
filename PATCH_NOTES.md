# Patch Notes

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

Root-caused and fixed "the targeting reticle sometimes doesn't come up" for "Defend Building" (and every other `requiresTarget` order): a same-frame input double-read, not a targeting-logic bug. `oUnitControl/Step_0.gml` calls `orderMenu.Update()` (which reads the menu click and can call `IssueOrder` -> `BeginTargeting`, setting `isTargeting = true`) and then, in that SAME Step, immediately calls `UpdateTargeting()` since `isTargeting` is now true. `mouse_check_button_pressed(mb_left)` is still true for the rest of that Step -- it's the exact same physical press that selected the menu item -- so `UpdateTargeting` read it as the player's target click, resolved against wherever the cursor happened to be sitting on the order menu (almost never a valid target), and c