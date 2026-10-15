# PlotHoverScripts

Hover/tooltip data overlay for un-occupied `oBuildingPlot` instances. First real consumer of the general-purpose `HoverCard` base (`HoverCardScripts.gml`). Classifies a plot into one of 4 kinds (name + normal "bonus" body text + italic flavor text) and drives a `HoverCard`'s visibility through a dwell timer + fade in/out, suppressed while the player is mid-action elsewhere.

Also owns the shared hover-timing macros (`PLOT_HOVER_DELAY_STEPS`/`PLOT_HOVER_FADE_STEPS`/`PLOT_HOVER_CURSOR_GAP`) that `BuildingHoverScripts.gml` and `CastleBonusHoverScripts.gml` both reuse rather than duplicate -- the "PLOT_HOVER_" prefix is a bit of a misnomer now that 3 systems share these, but nothing has been renamed without being asked.

## Plot classification

See `oBuildingPlot`'s `inside`/`far`/`blocked` fields (`PlotScripts.gml`, `oPlotSpawner`/`oOuterPlotSpawner` Create events):

| Condition | Name |
|---|---|
| `blocked` | "Blocked Plot" (meta-progression-locked; only ever true on inside plots -- the interior 3x3 lock) |
| `inside` (unblocked) | "Castle Plot" |
| `!inside, far` | "Distant Plot" |
| `!inside, !far` | "Exterior Plot" |

These 4 are mutually exclusive and exhaustive. `blocked` is checked first since it can coexist with `inside` and always wins.

## Bonus text

`PlotHoverBonusText()` states the REAL placement bonus each plot type grants, matching `GetPlacementCost` (`BlueprintScripts.gml`) and `ApplyPlotBonuses` (`BuildingDefinitions.gml`) exactly -- this file's text is a human-readable restatement of that logic and can drift out of sync if the numbers change there without a matching edit here. Format: a category header line (plain color) followed by one line per bonus effect, each wrapped in a `PLOT_HOVER_GOOD_COLOR_TAG` (lime) or `PLOT_HOVER_BAD_COLOR_TAG` (red) Scribble color tag. Distant plots have two category blocks (Resource Buildings, then All Buildings) since their bonus applies differently by building type. Every effect today is "good" -- `PLOT_HOVER_BAD_COLOR_TAG` is unused but kept for whenever a plot type gets a real downside (e.g. Distant plots' flavor-text-only "greater exposure to attack" becoming mechanical).

`PlotHoverFlavorText()` carries the italic descriptive one-liners shown in the flavor window.

## Suppression

`PlotHoverSuppressed()` returns true (hover should not trigger/should hide) during: `SelectionController.isTargeting` (attack/defend target selection), `BlueprintController.dragging` (placing a building), the mouse sitting over the Blueprint UI panel (`IsMouseOverPanel()` -- the panel is GUI-space, drawn on top of the game world, so without this check the mouse could sit over both a filled blueprint slot and a world-space plot underneath it at once), `global.fateEngineOverlayActive`, or (2026-08-15) `TutorialCharacterSpeaking()`. The Fate Engine check is belt-and-suspenders -- `oUnitControl`'s own `isOpen` guard already stops `Step()` from running while that overlay is open.

**`TutorialCharacterSpeaking()` (2026-08-15 bugfix).** True while Booger (`global.tutorialGuide.state == "idle"`) or The Dealer (`global.dealerIntro.IsSuppressingInput()`) is actively up with dialogue showing. Fixes a real bug: a mouse-hover card already on screen the instant a tutorial character popped up used to FREEZE in place (fully visible, at its last-known position/content) rather than fade away, because `oUnitControl/Step_0.gml` used to skip the hover controllers' `Step()` calls entirely during those windows -- and `Step()` is what drives the dwell/fade logic in the first place, so skipping it meant nothing ever told the card to start fading. The fix has two parts: `Step_0.gml` was changed to ALWAYS call the hover controllers' `Step()` during a guided-tutorial restriction and the whole Dealer-scene suppression window (previously conditional/skipped, see `oUnitControl.md`), and this new function was added to `PlotHoverSuppressed()`/`BuildingHoverSuppressed()` (the latter also covers `CastleBonusHoverController`, which reuses `BuildingHoverSuppressed()`) so `Step()` running during those windows resets `hoverTarget` to `noone` and eases `alpha` toward 0 -- the same graceful "freeze and fade" mechanism `global.fateEngineOverlayActive` already drove, just extended to a second trigger. `UnitSelectHoverController` (the fixed top-left selected-unit card, `UnitHoverScripts.gml`) was deliberately left OUT of this fix -- it's not a cursor-following card and isn't positioned anywhere near either tutorial character's speech bubble, so there was no reported/expected overlap; flag if it also needs covering.

## Dwell / fade timing

`PLOT_HOVER_DELAY_STEPS` reads `global.gameSettings.hoverDelayWorldItems` (Gameplay tab's "World Item Hover Delay" slider, default 1.0 sec) live every reference, since `#macro` is plain text substitution -- every consumer (Plot/Building/CastleBonusHoverController) picks up setting changes automatically. Continuous hover on the SAME plot for the full delay is required; switching targets resets the timer. While fading out, the card keeps its last content/position ("freeze and fade" rather than snap-away).

## API

- `PLOT_HOVER_DELAY_STEPS`, `PLOT_HOVER_FADE_STEPS`, `PLOT_HOVER_CURSOR_GAP` -- shared timing/spacing macros, also used by BuildingHoverScripts.gml / CastleBonusHoverScripts.gml.
- `PLOT_HOVER_GOOD_COLOR_TAG`/`PLOT_HOVER_BAD_COLOR_TAG` -- Scribble inline color tag names (pre-registered by Scribble, no `scribble_color_set()` needed).
- `global.fateEngineOverlayActive` -- suppression flag, set/cleared by `FateEngineOverlay.Open()`/`Leave()`.
- `TutorialCharacterSpeaking()` (2026-08-15) -- suppression check for Booger/The Dealer, see Suppression above.
- `PlotHoverName(_plot)`, `PlotHoverBonusText(_plot)`, `PlotHoverFlavorText(_plot)`.
- `PlotHoverSuppressed(_selectionController, _blueprintController)`.
- `PlotHoverController()` -- plain struct, owner calls `Step(_selectionController, _blueprintController)`/`Draw()`.
