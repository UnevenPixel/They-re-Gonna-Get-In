# CastleBonusHoverScripts

Hover panel over the player's own castle listing every currently active stationed passive bonus. 2026-07-12 request.

## Core idea

Same dwell/fade/cursor-anchor `HoverCard` pattern as `PlotHoverController`/`BuildingHoverController` (`PlotHoverScripts.gml`/`BuildingHoverScripts.gml`), targeting `oPlayerCastle` specifically, and additionally suppressed whenever `CastleGarrisonMenu.isOpen` is true so the two panels never overlap.

## API

### `CastleBonusHoverBodyText(_bonuses)` → `String`

Turns a `Struct.StationedBonuses` (`StationScripts.gml`) into one `"+X% Label"` line per non-zero field, joined with `"\n"`. Falls back to `"No active bonuses."` if every field is 0.

### `CastleBonusHoverController()`

- `Step(_selectionController, _blueprintController, _garrisonMenuOpen)` — call once per Step event. Resolves the hover candidate (mouse over `oPlayerCastle`, unless `_garrisonMenuOpen` or `BuildingHoverSuppressed`), advances/resets the dwell timer, eases `alpha`. On show, calls `GetStationedPassiveBonuses(TEAM.PLAYER)` and shows the card via `CastleBonusHoverBodyText`.
- `Draw()` — call once per Draw GUI event. No-ops while fully faded out.

Reuses `PLOT_HOVER_DELAY_STEPS`/`PLOT_HOVER_FADE_STEPS`/`PLOT_HOVER_CURSOR_GAP` (`PlotHoverScripts.gml`) rather than inventing new timing macros for a third near-identical hover controller.

## Usage

```gml
// Owner Create (oUnitControl)
castleBonusHoverController = new CastleBonusHoverController();

// Owner Step -- after buildingHoverController.Step(...)
castleBonusHoverController.Step(selectionController, blueprintController, castleGarrisonMenu.isOpen);

// Owner Draw GUI -- after buildingHoverController.Draw()
castleBonusHoverController.Draw();
```

## Known assumptions (flag if wrong)

- Player-castle-only (`oPlayerCastle`, not `oEnemyCastle`) — matches `CastleGarrisonMenu`'s existing restriction; showing the enemy's stationed bonuses would be an informational advantage not asked for.
- Title text "Castle Bonuses" — not specified by the request, picked to read clearly alongside the garrison dropdown's "Castle" title without colliding with it.
