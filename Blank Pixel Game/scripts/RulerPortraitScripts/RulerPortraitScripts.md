# RulerPortraitScripts

Animated ruler portraits for the UI. One sprite per ruler holds every animation as consecutive frame ranges (e.g. `sConeliusPortrait`: 30 frames covering 6 clips back to back). `RulerAnimationDefinition`/`RulerPortraitDefinition` describe that layout as static data (mirrors `UnitDefinition`/`BuildingDefinition`'s registry pattern); `RulerPortraitController` is the live, per-instance state machine that actually plays it.

2026-07-11 request's behavior, in the controller's terms: play a clip to completion at the portrait's `frameAdvance` rate, land on whichever idle frame (Left/Right) matches the clip's `endFacing`, sit there for a random wait, then pick a new clip at random from whatever's legal to START from that facing, and repeat. "Legal to start" is data, not hardcoded -- `RulerAnimationDefinition.startFacing`/`endFacing` let the same controller drive any future ruler's portrait without new code, as long as its definition is authored correctly (every non-idle clip needs a matching idle clip registered for whatever facing it can start from).

## RulerAnimationDefinition

One named animation clip within a portrait's sprite strip -- a contiguous frame run played in order. `name` is a human-readable label for debugging/logging only, never looked up by name at runtime. `startFacing` is which way the portrait must ALREADY be facing for this clip to be eligible to start; `endFacing` is which way it's facing on the clip's last frame, determining which idle clip it rests on afterward. `isIdle` marks the single-frame "resting" clips (e.g. Idle Looking Left/Right) -- idle clips are never picked as the "next animation" by the controller; they're the rest state a real animation lands ON, not something played on their own initiative.

## RulerPortraitDefinition

Static per-ruler portrait data: which sprite strip, what animation clips live in it, and how fast they play. `frameAdvance` defaults to `RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE` (`10/60`, ~10fps at this project's 60fps room speed) -- matches `sConeliusPortrait`'s own authored sequence `playbackSpeed` (10.0, see the sprite's `.yy`), not an arbitrary pick. Override per-portrait if a future ruler's strip is authored at a different speed.

`GetIdleAnimation(_facing)`: finds the resting clip for a given facing (`isIdle == true && startFacing == _facing`). Returns undefined if this portrait has no idle clip for that facing -- treat as a data-authoring gap; every registered portrait should have both an Idle Left and an Idle Right clip.

`GetPlayableAnimations(_facing)`: every non-idle clip eligible to start from the given facing -- the pool `RulerPortraitController` picks a random entry from once the idle wait expires.

## Registry

`global.__rulerPortraitRegistry` keyed by a plain string name (`global.selectedRuler` indexes into this) -- mirrors `RegisterOrder`/`GetOrder`'s registry pattern (`UnitSelection.gml`). `RegisterAllRulerPortraits()` is called once at game start (`oGameControl`'s Create event, alongside `RegisterAllOrders`/`RegisterAllUnitDefinitions`/`RegisterAllBuildingDefinitions`).

**Conelius** (`sConeliusPortrait`, 30 frames 0-29 across 6 clips, per the 2026-07-11 data sheet): 1 (Idle Left) + 4 (Blink Left to Right) + 1 (Idle Right) + 5 (Blink Right) + 5 (Mustache Wiggle) + 14 (Looking Around) = 30, laid out back to back in that order. Only "Blink Left to Right" starts from LEFT -- every other real animation starts from RIGHT, and only "Looking Around" ends back on LEFT. So from Idle Left, the only thing that can ever play is "Blink Left to Right"; everything else waits for Conelius to look left again via "Looking Around" first. Matches the request's example exactly ("animations that start with him looking left cannot start until he looks left again").

## RulerPortraitController

Drives one ruler portrait: plays a chosen clip to completion at `frameAdvance` rate, rests on the matching idle frame for a random duration, then picks a new clip at random from whatever's legal to start from the current facing. One instance per portrait shown on screen -- `oUnitControl` owns the player's.

Starts in `state = "idle"` facing `FACING.LEFT`, resolving to Conelius' "Idle Looking Left" clip -- the natural resting default. `state` is a plain string ("idle"/"playing"), not a `#macro`/enum, since nothing outside this struct reads it (unlike `FACING`, which crosses into `RulerAnimationDefinition`'s data). A future ruler whose data doesn't register an Idle Left clip would start with `currentAnimation` undefined -- not guarded against, since every ruler is expected to have both idle clips.

**Idle wait timing** (ASSUMPTION, flag if the feel is off in-engine): a random 2-5 sec at matchSpeed 1 (`RULER_PORTRAIT_IDLE_MIN_STEPS`/`_MAX_STEPS`, in steps at this project's 60fps room speed) -- not specified by the original request, picked to read as "occasionally fidgets" rather than constantly animating or standing frozen.

`Step()`: scaled by `global.matchSpeed` throughout (both animation playback and the idle wait), same idiom as `_unit.image_speed = global.matchSpeed` elsewhere. If the idle timer expires and `GetPlayableAnimations` returns an empty pool (a data-authoring gap -- every registered portrait should have at least one), doesn't spin re-checking every Step -- just waits and tries again.

`CurrentImageIndex()`: the sprite frame to draw this Step.

`Draw(_x, _y, _scale)`: draws using the portrait sprite's own origin (bottom-left for every portrait registered so far). Default `_scale` is 2, matching `HOVER_CARD_SCALE`, this project's standard UI upscale factor.

## API

- `RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle)`.
- `RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE`, `RulerPortraitDefinition(_sprite, _animations, _frameAdvance)` -- `.GetIdleAnimation(_facing)`, `.GetPlayableAnimations(_facing)`.
- `global.__rulerPortraitRegistry`, `RegisterRulerPortrait(_name, _def)`, `GetRulerPortraitDefinition(_name)`, `RegisterAllRulerPortraits()`.
- `RULER_PORTRAIT_IDLE_MIN_STEPS`, `RULER_PORTRAIT_IDLE_MAX_STEPS`, `RulerPortraitController(_def)` -- `.Step()`, `.CurrentImageIndex()`, `.Draw(_x, _y, _scale)`.
