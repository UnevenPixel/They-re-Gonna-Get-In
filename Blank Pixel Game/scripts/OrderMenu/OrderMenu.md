# OrderMenu

A GUI-space right-click order menu, built on the shared drop-down sprite set (`DropDownMenuScripts.gml`). Title "Orders", one row per order, no icons.

Two entry points: `Open(_x, _y, _orders)` (click-anchored, via `PositionDropDownMenuFromClick`) and `OpenCentered(_orders)` (for auto-open paths with no triggering click, e.g. the Army Limit Widget's SelectAllOfType, SelectionSummaryMenu's row-narrow click). `oUnitControl/Step_0.gml` auto-opens this menu the instant a selection populates, choosing whichever entry point fits how the selection was made.

## Mnemonic hotkeys

One letter per row, assigned fresh every time `options` changes (`AssignMnemonics()`): prefers the label's own first letter; if an earlier row already claimed it, the next unclaimed letter in the label is used. No underline tag exists in this project's Scribble build, so the mnemonic letter is recolored white instead (per fallback). The hotkey acts exactly like clicking that row.

## API

- `OrderMenu()` -- `Open(_x, _y, _orders)`, `OpenCentered(_orders)`, `Close()`, `Update()` → clicked order's `name` or `undefined` (caller issues the order), `Draw()`.
