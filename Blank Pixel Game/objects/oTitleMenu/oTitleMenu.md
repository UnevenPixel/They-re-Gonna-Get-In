# oTitleMenu

Title/main menu screen (2026-07-13 request). See `TitleMenuScripts.gml` for the full state sequence and every layout/animation constant -- this object is thin delegation plus setup ordering.

## Create_0

`settingsOverlay = new SettingsOverlay()` (2026-07-14) and `creditsOverlay = new CreditsOverlay()` (2026-08-06) are both instantiated BEFORE `titleMenu` below, which takes them as constructor params -- Settings/Credits are real sub-menus (`_OpenSettings()`/`_OpenCredits()`) rather than stubs.

`titleMenu = new TitleMenu(settingsOverlay, creditsOverlay)`.

**Title screen music** (2026-08-05): looped via `audio_play_sound(sndTitleMusic, 10, true)`, respects the Settings menu's Master volume/mute (`audio_master_gain()` is a global multiplier, nothing extra needed here). Fades out over 1 second and stops when "Play" is pressed -- see `TitleMenuScripts.gml`'s `_HandleButtonAction("play")` case for that half. Stored as `global.titleMusicInstance` (not a local var) so that button handler, which lives on the `TitleMenu` struct rather than this object, can reach it.

`ApplyGameSettings()` is called again here (2026-08-06) -- it already ran once at boot (`oGameControl`'s Create, before this room even loads), but `global.titleMusicInstance` didn't exist yet at that point, so its Music-volume guard no-opped. Calling it again now, with the instance actually alive, makes the loaded setting take effect on it immediately instead of playing at full volume until the player touches the Music slider.

## Step_0 / Draw_64

`titleMenu.Update()` / `titleMenu.Draw()`.
