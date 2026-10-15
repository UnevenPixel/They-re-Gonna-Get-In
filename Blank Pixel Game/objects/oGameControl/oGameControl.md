# oGameControl

Persistent (`persistent:true`), runs before any room -- one-time game-start registration/setup plus the Steamworks update/shutdown lifecycle.

## Create_0

Calls every `RegisterAll*` function once (`RegisterAllOrders`, `RegisterAllUnitDefinitions`, `RegisterAllBuildingDefinitions`, `RegisterAllRulerPortraits`), then `PaletteSwapInit()`/`TitleMenuFlagWaveInit()` to cache their respective shaders' sampler/uniform handles once.

`LoadAndApplyGameSettings()` (2026-07-14): player settings (audio/fullscreen/borderless/gamma), loaded from `settings.ini` (falling back to defaults on first-ever boot) and immediately applied to the actual runtime/window state. See `SettingsOverlayScripts.gml`'s file header for exactly what "applied" means per setting today -- some (master volume/fullscreen) are fully live; others (music/SFX volume, gamma) are stored/persisted but not hooked up to anything real yet.

`LoadAndApplyPlayerSaveData()` (2026-08-06): player SAVE DATA (progression/unlocks/tutorial-seen flags), distinct from the preferences above -- loaded from `PLAYER_SAVE_FILE` (JSON, not ini), falling back to defaults per-field for a missing/corrupt/incomplete save. See `PlayerSaveDataScripts.gml`'s file header for the full defensive-loading behavior.

`global.selectedRuler = "conelius"` -- which ruler's portrait/data is active this match. Hardcoded for now (only ruler registered). Set here (game start, not per-match) so it's available before `oUnitControl`'s Create runs and looks it up. Replace with a real character-select flow once one exists.

`global.isGameRestarting = false` -- guard flag for the Steamworks shutdown lifecycle, see Other_3 below.

## Step_0

`steam_update()` -- required by the Steamworks extension; certain async events (including Steam Async Event callbacks) only fire when this is called every Step. `steam_init()` itself is automatic and should NOT be called manually.

F1 toggles the debug overlay.

## Other_3 (Game End)

Steamworks requires `steam_shutdown()` when the game actually ends, but NOT when ending because of a `game_restart()` call (Steam itself stays running across a restart). `global.isGameRestarting` is the guard -- whatever code calls `game_restart()` should set it `true` immediately beforehand:
```
global.isGameRestarting = true;
game_restart();
```
so this event skips the shutdown call for that one case, then resets the flag back to `false`.
