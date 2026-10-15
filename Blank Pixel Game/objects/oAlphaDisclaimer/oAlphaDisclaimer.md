# oAlphaDisclaimer

Pre-alpha disclaimer splash screen, shown before the title menu.

## Create_0

Builds the disclaimer text via Scribble (`scribble(...)`) with a typewriter effect (`scribble_typist()`), wrapped to 55% of room width, centered.

## Step_0

Any key/gamepad face button press advances to `rmTitleMenu` (2026-07-13 request: "wire in the disclaimer screen to go to this menu instead") -- the title menu's own "Play" button is what now goes to `rmTestGameplay`.

## Draw_64

Clears to black, draws the typewriter-animated disclaimer text centered near the top third of the screen.
