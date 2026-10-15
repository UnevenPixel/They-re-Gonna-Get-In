# ArmyLimitMenu

A GUI-space dropdown shown when the player clicks the Army Limit Widget's icon (fixed HUD icon, not a room-space click). Lists every unit type the player has (live + stationed), per row: icon, name, "count/limit". Clicking a row selects every currently DEPLOYED (live, not stationed) unit of that type via `SelectionController.SelectAllOfType` (`UnitSelection.gml`). Title "Unit Limits". Mirrors `CastleGarrisonMenu.gml` structurally, reuses its `CASTLE_MENU_ICON_GAP`/`CASTLE_MENU_COUNT_MARGIN` directly.

**One deliberate difference from every other menu in this project:** `Open()` does NOT take a click position -- it always opens at a fixed anchor (`ARMY_LIMIT_MENU_ANCHOR_X`, `ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y`), bottom-edge-aligned, growing UPWARD (last row highest, first row lowest, right above the anchor) rather than downward from a top-left. The anchor Y equals `SELECTION_DRAG_MIN_GUI_Y` (`UnitSelection.gml`) -- both mark the same "top of the bottom HUD panel" boundary.

## API

- `ArmyLimitRow(_unitType, _icon, _name, _count, _limit)` -- one row. All fields undefined except `_name = "--"` for the placeholder.
- `BuildArmyLimitRows(_team)` → `Array<Struct.ArmyLimitRow>` -- aggregates live `oUnitParent` + `oUnitStationed` into one row per type (count = live + stationed combined, limit = `TrainingTypeLimit`). Placeholder row if nothing exists.
- `ArmyLimitMenu()` -- `Open(_rows)`, `Close()`, `Update()` → clicked `unitType` or `undefined`, `Draw()`.
