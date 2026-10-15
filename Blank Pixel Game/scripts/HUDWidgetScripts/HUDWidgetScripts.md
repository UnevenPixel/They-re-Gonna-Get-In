# HUDWidgetScripts

Fixed-position top-level HUD readouts alongside the resource bar (`DrawResourceBar`, `ResourceUIScripts.gml`) that don't fit that file's "one row of resource-icon counts" scope: Castle Health Widget and Army Limit Widget.

## Castle Health Widget

`DrawCastleHealthWidget(_team)` draws "[icon] current/max" at `(CASTLE_HEALTH_WIDGET_X, CASTLE_HEALTH_WIDGET_Y)`. No-ops if `_team` has no castle instance.

`sCastleHealthIcon` has an off-center custom origin (11,10 of 24x22), unlike the resource bar's clean middle-center icons -- the X anchor is corrected by adding the sprite's own `xoffset` so its drawn LEFT edge lands exactly on `CASTLE_HEALTH_WIDGET_X`. Y is used directly as the shared anchor for icon + text (same "one Y for both" pattern as `DrawResourceBar`'s `_cy`) -- a ~1px approximation of true vertical centering since the icon's yoffset isn't exactly half its height.

Text uses `fntResource` in `HOVER_CARD_TEXT_COLOR` with a manually-replicated 1px drop shadow (two plain `draw_text` calls, since this widget has no Scribble element to call `DrawCardTextWithShadow` on) -- `DrawResourceBar` itself has no shadow; this widget deliberately does.

## Army Limit Widget

Also CLICKABLE -- clicking its icon opens `ArmyLimitMenu` (`ArmyLimitMenu.gml`). This file only owns the passive readout (icon + count/max) and the icon hit-rect; the menu itself lives in `ArmyLimitMenu.gml` (same file-per-menu split as `CastleGarrisonMenu.gml`).

Positioned `ARMY_LIMIT_WIDGET_GAP_Y` below the Castle Health icon's bottom edge, same X anchor. `ArmyLimitWidgetY()` derives the shared vertical anchor from both icons' real dimensions/origins (recomputed each call, not cached).

"current" = live units (`GatherTeamUnits`) + stationed (`CountTeamStationedUnits`) -- matches the established convention that stationed units count against `global.armyLimit`. Deliberately excludes queued (still-training) units. "max" = `global.armyLimit[_team]`.

## API

- `DrawCastleHealthWidget(_team)`.
- `ArmyLimitWidgetY()`, `ArmyLimitWidgetIconRect()` → hit-rect for click-to-open, `DrawArmyLimitWidget(_team)`.

## Speed buttons (2026-10-15)

`DrawSpeedButtons`, `SpeedButtonAtMouse`, `SpeedButtonCenter`, `SpeedButtonSprite` + `SPEED_BUTTON_*` macros. Four 20x20 sprites (`sSpeedButtonPause`, `sSpeedButton1`-`3`) at native (960x540 view-space) origin positions (816 + 23*i, 501), drawn at the UI's 2x scale (GUI 1632 + 46*i, 1002). Frame 1 is the button matching `global.matchSpeed` (0 = pause, 1-3 = speed multiplier), frame 0 the rest. Clicking one sets `global.matchSpeed` directly (`oUnitControl/Step_0.gml`, after the XP-bar click block; unreachable while the Fate Engine / pause menu / Dealer scene / tutorial restriction owns input).

- Coordinates read as native view space (x2 to GUI) -- as raw GUI px (816, 501) would sit mid-screen, off the HUD.
- `sSpeedButton3`'s sprite origin is (0,0) while the other three are (10,10) (likely an oversight). Positions compensate via each sprite's own origin so all four are centered on their slots; fixing the origin in the editor changes nothing.
- While the pause menu / Fate Engine zero `matchSpeed`, the Pause button shows as active.
