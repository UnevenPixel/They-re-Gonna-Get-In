# PauseMenuScripts

The pause menu. Opened via Escape. Dims the screen, forces `global.matchSpeed` to 0 (restored on Resume). Built on the shared drop-down menu sprite set (`DropDownMenuScripts.gml`), centered on screen (`PositionDropDownMenuCentered`) since Escape has no click position to anchor from.

Mutually exclusive with the Fate Engine overlay -- `oUnitControl/Step_0.gml` checks `fateEngineOverlay.isOpen` first.

**Draw-order note:** unlike the Fate Engine overlay (dim drawn first, behind the UI bar), this menu's dim/panel draw LAST, on top of everything -- pausing is treated as fully leaving the play state, not a lighter interruption.

## Menus

- Main: Resume / Restart / Settings / Quit to Desktop / End Match.
- Confirm (Yes/No): shown after Quit to Desktop or End Match. No/Escape/click-away all cancel back to main.
- Settings opens the real shared `SettingsOverlay` as a sub-menu (`Update()`/`Draw()` delegate to it first, same "isOpen early-exit" idiom used elsewhere).

Restart just calls `room_restart()` -- `oMatchControl`/`oUnitControl` are both non-persistent, so their Create events re-run from scratch and already reset every match-related global.

Quit to Desktop calls `game_end()`. **2026-08-13: End Match now branches separately** -- `DoQuitOrEndMatch(_action)` checks `_action == "endMatch"` and calls `room_goto(rmHubTown)` instead, leaving the match without closing the game. Previously both actions were identical (both called `game_end()`, `_action` was ignored) -- this was flagged as a known gap in the 2026-08-10 pass and is now closed. No cleanup of `global.matchSpeed` is needed before the `room_goto` -- `oMatchControl`'s Create event resets it to `1` unconditionally the next time `rmTestGameplay` loads, same as it already does after `room_restart()`.

**2026-08-13 (later same day): `DoQuitOrEndMatch` also calls `CompleteTutorial()`** (`PlayerSaveDataScripts.gml`), unconditionally, before branching on `_action` -- both Quit to Desktop AND End Match now mark the tutorial complete if it wasn't already. Idempotent, so this is a no-op on every non-tutorial run. Only "End Match" was explicitly named in the request ("tutorial will end... from pause ending"); "Quit to Desktop" was included too on the reasoning that BOTH actions leave the current run, and NOT completing the tutorial on a Quit would otherwise leave a player who exits mid-tutorial permanently stuck in "tutorial in progress" state on their next launch (since `hasSeenBeggarIntro`/`hasSeenWarRoomIntro` would already both be `true` by then, but `tutorialCompleted` would still read `false` forever unless they specifically finish a match). Flagged in `WarRoomMenuScripts.md` as an inference beyond the literal request, not a direct instruction.

## API

- `PauseMenu(_settingsOverlay)` -- plain struct.
  - `Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)`, `Close()` (= Resume).
  - `OpenSettings()`, `RequestConfirm(_action)`, `CancelConfirm()`, `DoRestart()`, `DoQuitOrEndMatch(_action)`.
