# TitleMenuScripts

The title/main menu screen. Owned by `oTitleMenu` (`rmTitleMenu`), same plain-struct + thin-object-wrapper split as every other controller.

## State sequence

1. **fadeIn** -- screen fades in from black.
2. **titleDrop** -- title falls from off-screen-top to center using `_EaseOutBounce`, bouncing once on landing.
3. **prompt** -- "Press Any Key" typewriters in below the title (Scribble typist, `[wave]` tag), white with a manually-drawn black outline (see `DrawPrompt()`). Waits for any key/click/gamepad face button.
4. **transition** -- prompt slides off the bottom, title eases from center to the docked top-right corner, all four menu buttons slide in from off-screen-right (staggered per row), social icons slide in from below (staggered right-to-left, overshoot + squash). All concurrent, not staged.
5. **menu** -- buttons interactive: hover shifts a button left smoothly, click fires its action. Exit opens a Yes/No confirm (mirrors `PauseMenu`'s confirm shape, built on `DropDownMenuScripts.gml`) before `game_end()`.

## Sizing

`sTitleBackground`/`sTitle`/button sprites are authored at half the room's 1920x1080 resolution; `TITLE_MENU_SCALE` (2) applied to every sprite draw. Text draws at native/unscaled size. Button sprites share middle-right origin; `sTitle` is top-right origin -- both match the corner each anchors to once docked/resting.

## Music

`sndTitleMusic` started looped in `oTitleMenu`'s Create event, stored on `global.titleMusicInstance`. Respects Settings' Master volume automatically. Fades out over 1s and stops the instant "Play" is pressed (the only action that does this -- Settings/Credits are sub-menus, not a real exit; Exit goes straight to `game_end()`).

## Prompt outline technique

`DrawPrompt()` draws the black copy 8x at a small pixel offset behind the white copy (standard font-agnostic outline trick) rather than Scribble's SDF `.outline()`, since `fntResource` is a plain bitmap font with no SDF configuration. Uses two separate `scribble_typist`s (black/white) -- a shared typist resets its reveal progress whenever the element it just ticked differs from the previous one, so alternating one typist between two elements only ever revealed the first character.

## Social row

Order: Steam, X, Itch.io, Discord, TikTok, YouTube (order doesn't matter functionally). Only Discord animates (4-frame idle/blink cycle, ~5-6s between blinks). Real link clicks are wired for every platform except Itch.io (`url_open()` commented out, placeholder pending the real URL).

## Flag-wave hover shader

`shFlagWave` (see `shaders/shFlagWave/shFlagWave.fsh`) applied to the 4 option buttons during `transition`/`menu`. Intensity derived directly from each button's hover offset (0 at rest = shader renders identically to unshaded). `TitleMenuFlagWaveInit()` caches uniform handles once at boot (`oGameControl`'s Create event).

## API

- `TitleMenuFlagWaveInit()` -- call once at boot.
- `TitleMenuButton(_sprite, _action)`, `TitleMenuSocialButton(_sprite, _platform, _animated)` -- per-element animated state.
- `TitleMenu(_settingsOverlay, _creditsOverlay)` -- plain struct, owner calls `Update()`/`Draw()`.
