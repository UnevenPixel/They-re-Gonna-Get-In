# SettingsOverlayScripts

The shared settings menu, opened as a sub-menu from `PauseMenu.OpenSettings()` (mid-match), `TitleMenu._OpenSettings()` (title screen), and (2026-08-13) `HubPauseMenu.OpenSettings()` (`oHubTownMenu`/`oPreRunMenu`). Every owner takes a `SettingsOverlay` instance and delegates `Update()`/`Draw()` to it first whenever `isOpen`.

Multiple separate `SettingsOverlay` instances exist (one per owner, never coexisting), but all read/write the same `global.gameSettings` struct, so a value changed on one screen persists and is visible on the others.

Same 0.75-alpha black dim every overlay uses; stacks harmlessly on top of PauseMenu's own dim when opened mid-match.

## Tabs

Five tabs, buttons along the top of the panel: Gameplay, Controls, Audio, Graphics, Accessibility.

- **Gameplay** -- "Restart Tutorial" (real, calls `PlayerSaveDataScripts.gml`'s `ResetTutorialProgress()`) and "Restart Progress" (still a stub -- see Known gaps). Restart Progress opens a Yes/No confirm (shared `DropDownMenuScripts.gml` helpers). Two hover-data delay sliders ("Bottom Bar" = blueprint panel hover cards, "World Items" = plot/building/castle hover cards), both real/live, read directly every Step by `BLUEPRINT_HOVER_DELAY_STEPS`/`PLOT_HOVER_DELAY_STEPS`. Range 0..`SETTINGS_HOVER_DELAY_MAX_SECONDS` (5), default 1s each, snapped to `SETTINGS_HOVER_DELAY_SNAP_SECONDS` (0.5s) increments while dragging.

  **2026-08-13: Restart Tutorial is now conditionally hidden**, via `_ShouldShowRestartTutorial()` -- `(room == rmTitleMenu) && !global.tutorialActive`. Neither drawn nor hit-tested when the condition is false (`DrawGameplayTab()`/`_UpdateGameplayTab()` both gate on it); "Restart Progress" stays in its row-1 position regardless -- the layout isn't reflowed when Restart Tutorial disappears, so there's a visible gap above it in that case. Not requested either way; flag if the row should collapse upward instead. `global.tutorialActive` is a cross-room mirror of `HubControl.tutorialActive` -- see `HubControlScripts.md`'s "Global mirror" section for why a global was needed instead of a direct reference.
- **Controls** -- visual-only readout of the game's real current control scheme (`GetControlsList()`, read straight off every `keyboard_check`/`mouse_check_button` call in the project). No rebinding.
- **Audio** -- Master/Music/SFX sliders. Master has NO mute toggle and stays LINEAR (`audio_master_gain()` is the engine's real master-bus gain, already multiplying onto everything else -- squaring it too would double-apply the curve). Music and SFX each keep a mute toggle and use `PerceptualGain()`'s squared curve. Music is real/live (`audio_sound_gain()` on the title music instance). **2026-08-13: SFX now has a real consumer** -- `DialogueOverlayScripts.gml`'s per-character speaker blip reads `sfxVolume`/`sfxMuted` live at play-time (each blip is a one-shot with no persistent instance, unlike Music, so there's nothing for `ApplyGameSettings()` to push updates into later). See `DialogueOverlayScripts.md`'s "Pitch variation + SFX volume" section.
- **Graphics** -- Fullscreen toggle (real) + Borderless Fullscreen toggle (modifier of Fullscreen, uses the real `window_enable_borderless_fullscreen()`, GameMaker 2024.2+ -- only visibly does anything once Fullscreen is on). Aspect-ratio letterboxing still depends on `options_windows.yy`'s scaling option being "Keep Aspect Ratio" (see `PATCH_NOTES.md`). Gamma slider -- stored/persisted but NOT applied yet; real gamma correction needs a full-screen post-process shader (a genuine engine-level change, deliberately out of scope here).
- **Accessibility** -- stub, 3 greyed-out non-interactive placeholder ideas (colorblind team colors, UI text scale, reduce screen shake/flash). None wired to anything real.

## Persistence

`global.gameSettings` loaded once at boot (`LoadAndApplyGameSettings()`, `oGameControl`'s Create event) from `SETTINGS_SAVE_FILE` (`settings.ini`, GameMaker's `ini_*` functions), falling back to `DefaultGameSettings()` per missing key. Every value change calls `SaveGameSettings()` immediately, and `ApplyGameSettings()` too where the value has a real runtime effect today (master volume, music volume/mute, fullscreen, borderless).

`settings.ini` is for user PREFERENCES only. Player SAVE DATA (progression, tutorial flags) lives separately in `PlayerSaveDataScripts.gml`'s JSON file.

## PerceptualGain

Squares a linear 0..1 slider value (`_linear * _linear`) so volume feels evenly spread across the slider instead of crammed into the first ~20% (human hearing is roughly logarithmic). Applies to Music and SFX. Master deliberately stays linear -- squaring it too (on top of Music/SFX's own squared gain) would compound into an overly steep curve near 0.

## Known gaps

- **`ResetPlayerProgress()` ("Restart Progress") is still a stub.** Today `hasSeenBeggarIntro` is the only save field, so wiring this now would duplicate Restart Tutorial. Real implementation: overwrite `global.playerSaveData` with `DefaultPlayerSaveData()` + `SavePlayerSaveData()`, once there's more to reset.
- Gamma is stored/persisted but not applied to anything real yet (no gamma shader). SFX volume/mute now has a real consumer (dialogue speaker blips, see Audio above) -- no longer an open gap.
- Settings always resets to the Gameplay tab on `Open()` (not remembered across visits) -- judgment call for predictability.

## API

- `DefaultGameSettings()`, `LoadGameSettings()`, `SaveGameSettings()`, `ApplyGameSettings()`, `LoadAndApplyGameSettings()` -- same load/save/apply split as `PlayerSaveDataScripts.gml`.
- `PerceptualGain(_linear)` → `Real`.
- `GetControlsList()` → `Array<Struct>` of `{ action, key }`.
- `SettingsOverlay()` -- plain struct, owner calls `Update()`/`Draw()`.
  - `Open()`, `Close()`, `RestartTutorial()`, `ResetPlayerProgress()`, `_ShouldShowRestartTutorial()`.

## 2026-10-15: cursorScale

New setting `cursorScale` (int, `SETTINGS_CURSOR_SCALE_MIN`..`MAX` = 1..3, default 2): Graphics tab slider snapped to whole numbers, row 3 below Gamma, stored as [Graphics] cursorScale, clamped/rounded on load. Read live by `CURSOR_SCALE` (CursorScripts.gml).
