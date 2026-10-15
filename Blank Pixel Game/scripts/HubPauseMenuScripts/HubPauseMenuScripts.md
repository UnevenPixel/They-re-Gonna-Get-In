# HubPauseMenuScripts

2026-08-13 request: an Escape pause menu for screens outside of gameplay and outside the title screen -- currently `rmHubTown`, `rmPreRun`, and (later the same day) `rmWarRoom` ("other locations in the hub town that will get menus soon" -- `folders/Menus/WarRoom.yy` existed as an empty folder at the time this was written, and became a real screen shortly after, see `WarRoomMenuScripts.md`). More locations may still follow.

Deliberately separate from `PauseMenuScripts.gml`'s `PauseMenu` (gameplay-only, lives in `oUnitControl`, has Resume/Restart/Settings/Quit to Desktop/End Match). That menu's options don't make sense outside of a match -- there's no match to resume/restart/end. `HubPauseMenu` is the minimal non-gameplay equivalent: `["Options", "Return to Desktop", "Return to Title Menu"]`. Both menus share the same `DropDownMenuScripts.gml` visual language (title + row sprites, `PositionDropDownMenuCentered`, `DropDownMenuHitTest`, etc.) so they look and feel consistent despite being different structs.

## Actions

- **Options** -- opens the shared `SettingsOverlay` sub-menu (constructor param, same "instantiate settings first, pass it into the pause menu" pattern `oUnitControl` already uses for `PauseMenu`).
- **Return to Desktop** -- 2026-08-13: now confirms first. Clicking it swaps the main list for a "Return to Desktop?" Yes/No sub-menu (`pendingConfirm`/`RequestConfirm()`/`CancelConfirm()`), same shape as `PauseMenuScripts.gml`'s confirm flow. "Yes" calls `game_end()`; "No" OR any other click while the confirm is showing cancels back to the main list (mirrors `PauseMenu.Update()`'s confirm branch exactly -- any non-"Yes" click cancels, whether it landed on "No" or missed the menu entirely). Escape also cancels back to main instead of closing the whole menu.
- **Return to Title Menu** -- `room_goto(rmTitleMenu)`, immediately, no confirm -- leaving to the title screen isn't destructive the way closing the app is, matches Restart's no-confirm treatment in the gameplay `PauseMenu`.

`DrawMenuList(_title, _options, _hoveredIndex)` is shared between the main list and the confirm sub-menu (same refactor `PauseMenuScripts.gml` already uses) rather than duplicating the row-drawing loop.

## Click-outside-closes

**New interaction pattern for this codebase** -- no other overlay dismisses on an outside click (`PauseMenuScripts.gml`'s main list is explicit that a miss-click is "deliberately not a dismiss -- Resume/Escape only"). `_MenuRect()` returns the full on-screen bounds (title bar + every row); a left-click that hits neither a row (`hoveredIndex == -1`) NOR falls inside that full rect closes the menu. A click on the title bar itself (inside the rect, but not a row) is a no-op -- neither a dismiss nor an action, matching how clicking a non-interactive area of any other menu in this project already behaves.

**Only applies to the main list, not the confirm sub-menu.** While `pendingConfirm` is showing, any click that isn't "Yes" cancels back to the main list regardless of where it landed -- there's no separate "outside the confirm box" case, matching `PauseMenuScripts.gml`'s own confirm-branch behavior exactly (not a new pattern there).

## Owner wiring (`oHubTownMenu`, `oPreRunMenu`, `oWarRoomMenu`)

Same shape all three places, following `oUnitControl`'s established pause-menu convention:

- **Create**: `settingsOverlay = new SettingsOverlay(); hubPauseMenu = new HubPauseMenu(settingsOverlay);` -- each object gets its OWN `SettingsOverlay` instance (matches `oTitleMenu`/`oUnitControl` precedent; all instances read/write the same `global.gameSettings`, so this is safe/expected, not a bug).
- **Step**: `if (hubPauseMenu.isOpen) { hubPauseMenu.Update(); exit; }` then `if (keyboard_check_pressed(vk_escape)) { hubPauseMenu.Open(); exit; }`, mirroring `oUnitControl`'s two-gate Escape pattern.
  - `oHubTownMenu` additionally suppresses the Escape-to-open check while `hubTownMenu.dialogueOverlay.isOpen` -- the Beggar's dialogue has no Escape-to-dismiss of its own (exit button only, by design -- see `DialogueOverlayScripts.md`), so without this guard, Escape mid-conversation would pop the pause menu on top of an open dialogue box. Not an issue on `oPreRunMenu`/`oWarRoomMenu` today (no dialogue overlay in either yet) -- `oWarRoomMenu` will need the same guard once its own dialogue tree (see `WarRoomMenuScripts.md`) is built.
- **Draw**: `hubPauseMenu.Draw();` called absolutely last, after the screen's own `.Draw()` -- matches `oUnitControl`'s "pauseMenu.Draw() absolutely LAST" convention.

## Known assumptions / scope limits (flag if wrong)

- Options and Return to Title Menu still have no confirm step -- only Return to Desktop does (2026-08-13, requested explicitly). Flag if either of the other two should also confirm.
- Escape suppression while a dialogue is open (hub town only, for now) assumes Escape shouldn't interrupt a conversation -- revisit for `oWarRoomMenu` once its dialogue tree exists.
