# oOpeningCredits

Studio logo splash screen -- fade in, hold, fade out via `shDitherDissolve`, then `room_goto(rmDisclaimer)`. Any key press skips ahead within the current phase (FADE_IN completes instantly; HOLD ends immediately) rather than skipping the whole sequence, per `ECreditsState` (`Enumerators.gml`).

## Create_0

Caches `shDitherDissolve`'s `u_progress`/`u_invert` uniform handles once. Initializes the state machine (`state = ECreditsState.FADE_IN`, `progress`, `holdTimer`), timing (`fadeDuration = 2`, `holdDuration = 1.5` seconds), and the logo's centered position.

## Step_0

Delta-time-based state machine, `_dt` unscaled (not `global.matchSpeed` -- this runs before any match exists). FADE_IN advances `progress` toward 1 (any key press snaps it there) then transitions to HOLD; HOLD counts `holdTimer` toward `holdDuration` (any key press snaps it there) then resets `progress` and transitions to FADE_OUT; FADE_OUT advances `progress` toward 1 then transitions to DONE and calls `room_goto(rmDisclaimer)`.

## Draw_0

Clears to black. No-ops (exits) once `state == ECreditsState.DONE`. Maps the current state to the shader's `progress`/`invert` uniforms (HOLD holds at full progress, no invert; FADE_OUT reuses `progress` but sets `invert = 1` to reverse the dissolve direction), then draws the studio logo through `shDitherDissolve`.
