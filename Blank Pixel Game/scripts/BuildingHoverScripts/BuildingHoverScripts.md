# BuildingHoverScripts

Hover/tooltip overlay for placed building instances (`oBuildingParent`, in-world) AND blueprint UI slots (`BlueprintController`, GUI-space). Second real consumer of the general-purpose `HoverCard` base (`HoverCardScripts.gml`), after `PlotHoverScripts.gml`.

Reuses `PlotHoverScripts.gml`'s dwell/fade/anchor constants (`PLOT_HOVER_DELAY_STEPS`/`PLOT_HOVER_FADE_STEPS`/`PLOT_HOVER_CURSOR_GAP`) -- building hover uses the SAME timing as plot hover, not a separate copy.

First consumer to need more than HoverCard's built-in name+body+flavor slots: production/training buildings show an extra "icon row" above the body text (building icon, timer/rate readout, produced item's icon). `HoverCardScripts.gml`'s `_topContentHeight`/`_bottomContentHeight` `Show()` params exist specifically to let this row (and a blueprint-only cost row) reserve space without touching `PlotHoverController`'s own call site. `BuildingHoverExtras` draws that row itself, using `HoverCard.GetContentTopY()`/`GetContentBottomY()` rather than duplicating HoverCard's internal layout math.

## Icon row layout

Reads left to right: `[ Building Window ] [ Timer ] [ Item/Unit Window ]` -- Building Window anchors to the body's left margin, Timer sits immediately right of it, Item/Unit Window immediately right of Timer. All three columns' top edges align. (Building icon in the top-left, not top-right -- an early pass had this backwards, corrected once flagged.)

## Placed building vs. blueprint slot

Both contexts share all the data-gathering/drawing logic (`BuildingHoverExtras` etc.) but differ in exactly two ways, threaded through an `_isBlueprint` bool:

- **Placed building** (`BuildingHoverController`, driven by `oUnitControl`'s Step/Draw): resource-limit reads as "remaining/total" (e.g. "300/400"), read off the LIVE INSTANCE's own `resourceLimit`/`producedTotal` -- not the `BuildingDefinition`'s base value, since a Distant-plot building's limit may already be +50% boosted by `ApplyPlotBonuses`. Health reads the same way (`GetCurrentHealth` off the live instance). No cost row (already paid for).
- **Blueprint slot** (`BlueprintController`): resource-limit reads as the flat `BuildingDefinition.resourceLimit` (no instance exists yet); health reads as the flat `maxHealth`. Plus a cost row along the bottom, one "`[icon]Base (Discount)`" run per resource (`CostToScribbleTextWithDiscount`). Base price and the parenthesized discount price color red independently by `_team`'s current affordability; the discount price additionally renders in `BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG` (dark gray) whenever no currently open plot would actually grant the discount, regardless of its own affordability. The card's TITLE (building name) renders red if the building can't be placed anywhere right now at all.

Placed TRAINING buildings show a queue row in that same bottom slot instead (mutually exclusive with the cost row -- a blueprint has no queue, a placed building has no cost left to pay): the trained unit's small icon + queued count, a progress bar toward the next completion (plain drawn rectangle, black background filled in `HOVER_CARD_TEXT_COLOR`), then seconds remaining (ceil'd so it doesn't misleadingly hit "0s" early). Reads `trainQueue`/`trainProgress`/`trainTime` straight off the live instance (`TrainingScripts.gml` owns updating them). This row is TEAM.PLAYER-only -- enemy buildings show neither queue nor progress. Placed non-training (resource) buildings show neither row.

## Body/flavor text

The "what it does" body text (e.g. "Produces [icon]Wheat"/"Trains [icon]Peasant") is auto-generated from `BuildingDefinition` fields via `BuildingHoverDescriptionText`, not authored -- preceded by the resource's/unit's own icon (`ResourceIconTag`/`UnitIconTag`). Singular unit names are used as-is ("Trains Peasant") rather than inventing pluralization rules that could break on irregular names.

The flavor window reuses `BuildingDefinition.description` -- a field that already existed on every registered building but was never actually displayed anywhere before this. These are PLACEHOLDER flavor text until real, document-sourced versions arrive -- don't treat current wording as final.

## Suppression / mutual exclusion

A building can never be hovered while its plot shows plot-hover data, because `PlotHoverController` only triggers on un-occupied plots -- a placed building's plot is occupied by definition, so no extra guard is needed there. The Blueprint UI panel is the real conflict: it's a GUI-space overlay drawn on top of the game world, so the mouse can simultaneously sit over a filled blueprint slot (GUI-space) AND whatever world-space plot/building renders underneath that same screen position. Fixed via `BlueprintController.IsMouseOverPanel()` (checks the whole grid's bounding rect, not just filled slots), which both `PlotHoverSuppressed` and `BuildingHoverSuppressed` treat as a suppression condition.

**2026-08-15 bugfix:** `BuildingHoverSuppressed()` now also checks `TutorialCharacterSpeaking()` (`PlotHoverScripts.gml`) -- see that file's own Suppression section for the full bug/fix writeup (a hover card used to freeze on screen, covering a tutorial character's dialogue, instead of fading away). `CastleBonusHoverController` reuses `BuildingHoverSuppressed()` directly, so it's covered by this fix too without any change of its own.

## Paired unit card

Placed/blueprint TRAINING buildings show a paired `UnitHoverScripts.gml` card alongside this one (`BuildingHoverController.unitCard`/`unitExtras`), positioned via `PositionHoverCardPair` with `_secondaryAlwaysRight = true` -- the unit card always sits to the building card's right regardless of cursor quadrant. No live unit instance exists to read from (a training building isn't tied to one specific trained unit), so it always shows max-HP-only stats. Its cost row is always shown -- even for an already-placed building, the unit's own training cost is directly relevant (it's what queuing another one will spend).

## API

- `BuildingHoverTitleCase(_word)`, `BuildingHoverDescriptionText(_def)`, `BuildingHoverTimerText(_def, _building, _isBlueprint, _team)`, `BuildingHoverResourceLimitText(_def, _building, _isBlueprint)`, `BuildingHoverHealthText(_def, _building, _isBlueprint)`, `BuildingHoverItemIcon(_def)`.
- `BuildingHoverExtras()` -- owns the icon-row/cost-row/queue-row Scribble elements. `Layout(_def, _building, _isBlueprint, _team)` returns `{ topContentHeight, bottomContentHeight }` to feed into `HoverCard.Show()`. `Draw(_card, _alpha)` call right after `_card.Draw(_alpha)`.
- `BuildingHoverSuppressed(_selectionController, _blueprintController)`.
- `BuildingHoverController()` -- owns a `HoverCard` + `BuildingHoverExtras` (+ paired unit card). `Step(_selectionController, _blueprintController)`/`Draw()`.

## Known assumptions / scope limits (flag if wrong)

- `BuildingHoverTimerText`'s displayed rate/time reflects `_team`'s live stationed-unit bonuses (`GetStationedPassiveBonuses`), colored green/red vs. the base value when a bonus makes it better/worse. Rounding (rate to 0.01, time to 0.1) is a readability judgment call, not spec'd.
- `BuildingHoverController` shows hover data for ANY team's buildings (informational only, not restricted to the player's own) -- flag if this should be player-only.

## 2026-10-14: icon row layout

The Item/Unit window is now right-anchored: its right edge sits `HOVER_CARD_BODY_MARGIN_X` from the card's right edge (same buffer as the Building Window's left). The Timer icon + text are centered horizontally between the Building Window's right edge and the Item window's left edge (or the right margin line when there's no item icon), replacing the old fixed `BUILDING_HOVER_ICON_GAP_X` chain. `BUILDING_HOVER_ICON_GAP_X` is now unused by `Draw()`.
