# CursorScripts

Game-wide custom cursor. `CursorInit()` (called from `oGameControl`'s Create) hides the system cursor via `window_set_cursor(cr_none)`; `oGameControl`'s Draw GUI End event calls `CursorDraw()`, so the cursor draws above all GUI. `oGameControl` is persistent, so this covers every room.

## Sprite selection (`GetCursorSprite`)

Priority, highest first:
1. `sCursorCarry` -- `oUnitControl.blueprintController.dragging` (dragging a building to the play area) OR `xpBarWidget.dragging` (dragging a Fate Token; added v0.0.7.9).
2. `sCursorFlag` -- `selectionController.isTargeting` (choosing an order target).
3. `sCursorSelect` -- `selectionController.dragging` AND the mouse has moved >= `CURSOR_SELECT_MIN_DRAG` (4) world px from the drag start, so a plain click doesn't flash the select cursor (matches `SelectionController.EndDrag`'s own click threshold).
4. `sCursorBase` -- everything else, including all menus.

## Hidden rooms

`CursorHiddenInRoom`: `rmInit`, `rmOpeningCredits` (studio splash), `rmDisclaimer` (alpha warning). Both the system cursor and the custom one are invisible there.

## Assumptions

- Drawn at `CURSOR_SCALE` 1 in GUI space (native size; was 2 in v0.0.7.8); sprites are 16x16 with origins base (1,1), others (0,0) -- the hotspot is each sprite's own origin.
- Hidden-room set assumes `rmDisclaimer` is the alpha warning screen.
- Hardware cursor sprites aren't used (software draw), so the cursor follows the game's frame rate.
- The system cursor stays hidden while the window is focused; it isn't restored over window chrome or when the game is not focused.

## 2026-10-15: scale setting

`CURSOR_SCALE` now reads `global.gameSettings.cursorScale` (Graphics tab 'Cursor Size' slider, whole numbers 1-3, default 2, persisted in settings.ini under [Graphics]).
