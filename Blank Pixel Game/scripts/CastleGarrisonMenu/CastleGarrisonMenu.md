# CastleGarrisonMenu

A GUI-space dropdown shown when the player left-clicks their own castle's wall. Lists what's currently stationed there (icon, name, "x#" count). Clicking a row deploys ONE unit of that type via `DeployStationedUnit` (`StationScripts.gml`, called from `oUnitControl/Step_0.gml` off this menu's `Update()` return value). Title "Castle". Shares sprite/title/hit-test rendering with every other drop-down menu (`DropDownMenuScripts.gml`) -- only owns its own row content (icon + name + right-aligned count).

Opens anchored away from the triggering click (`PositionDropDownMenuFromClick`).

`consumedClick` -- true for exactly the Step a left click was handled while open (row click or dismiss). `oUnitControl/Step_0.gml` skips its own room-space left-click handling when true, so the same click can't also start a drag-select this same frame.

## API

- `CastleGarrisonRow(_unitType, _icon, _name, _count)` -- one display row. All fields `undefined` except `_name = "--"` for the "nothing garrisoned" placeholder row.
- `BuildCastleGarrisonRows(_team)` → `Array<Struct.CastleGarrisonRow>` -- aggregates every live `oUnitStationed` into one row per distinct type, ordered by first-seen. Returns a single `"--"` placeholder row if nothing's stationed.
- `CastleGarrisonMenu()` -- `Open(_x, _y, _rows)`, `Close()`, `Update()` → clicked `unitType` or `undefined`, `Draw()`.
