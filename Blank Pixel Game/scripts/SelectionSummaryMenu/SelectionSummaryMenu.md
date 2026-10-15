# SelectionSummaryMenu

Top-left panel shown whenever 2+ units are selected. Title "Selected". Shares background/title/hover-frame rendering with `DropDownMenuScripts.gml`; owns only its row content (icon + name + right-aligned value), reusing `CASTLE_MENU_ICON_GAP`/`CASTLE_MENU_COUNT_MARGIN` from `CastleGarrisonMenu.gml`.

No `Open()`/`Close()` -- passive, recomputed from the current selection every Step (same architecture as `UnitSelectHoverController`, which owns the same top-left corner for the single-unit case; mutually exclusive since this only engages at 2+ selected).

## Two modes (derived from selection, no explicit state)

- **GROUPED** -- selection spans 2+ distinct unit types: one row per type (icon, name, "x#" count). Hovering shows the GENERAL unit hover card (`ShowUnitHoverCard` with no live instance, max HP only). Clicking narrows the selection to just the CURRENTLY SELECTED units of that type.
- **INDIVIDUAL** -- selection is 2+ units all sharing one type: one row per unit instance (value = current/max HP). Hovering shows the DETAILED hover card (exact remaining HP). Clicking replaces the selection with just that one unit.

`consumedClick` -- set only when a click actually lands on a row (narrower than `CastleGarrisonMenu`'s version, since this panel isn't modal -- clicks elsewhere on screen must keep working normally while it's visible).

## API

- `SelectionSummaryRow(_unitType, _icon, _name, _valueText, _unit)` -- `_unit` is `noone` for a grouped row, a real instance for an individual row.
- `BuildSelectionSummaryRows(_selected)` → `Array<Struct.SelectionSummaryRow>`.
- `SelectionSummaryMenu()` -- `Step(_selectionController)` (call after `PruneDeadSelected()`), `Draw()`.
