# RulerPortraitScripts

Animated ruler portraits for the UI. One sprite per ruler holds every animation as consecutive frame ranges; this library describes that layout as data and drives it as a small per-instance state machine.

## Core idea

A ruler's portrait sprite is a single strip of frames. Each animation ("clip") is a contiguous run within that strip, tagged with which direction the portrait must already be facing to start it, and which direction it's facing by the last frame. The controller plays a clip, rests on the matching idle frame, waits a random interval, then picks a new clip at random from whatever's legal to start given the current facing.

This makes the system fully data-driven — adding a new ruler is just a new `RulerPortraitDefinition` registration, no new controller code, as long as every non-idle clip has a matching idle clip registered for whatever facing it starts from.

## API

### `RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle = false)`

One animation clip.

| Field | Type | Meaning |
|---|---|---|
| `name` | String | Debug label only, never looked up by name. |
| `startIndex` | Real | First `image_index` frame in the portrait's sprite. |
| `frameCount` | Real | Consecutive frames played in order. |
| `startFacing` | `FACING` | Must match the portrait's current facing for this clip to be eligible to start. |
| `endFacing` | `FACING` | Facing on the clip's last frame — decides which idle clip it rests on afterward. |
| `isIdle` | Bool | True for the single-frame resting clips. Idle clips are never picked as the "next animation" — they're a rest state, not something played on their own initiative. |

### `RulerPortraitDefinition(_sprite, _animations, _frameAdvance = RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE)`

Static per-ruler data.

- `sprite` — the single multi-index sprite every clip's `startIndex` indexes into.
- `animations` — array of `RulerAnimationDefinition`.
- `frameAdvance` — frames advanced per Step at `global.matchSpeed == 1`. Default ~10fps (matches this project's 60fps room speed and the reference sprite's own authored sequence speed).
- `GetIdleAnimation(_facing)` → the idle clip for that facing, or `undefined` if the portrait's data doesn't register one (treat as an authoring bug).
- `GetPlayableAnimations(_facing)` → array of every non-idle clip eligible to start from that facing.

### Registry

- `RegisterRulerPortrait(_name, _def)` — keyed by a plain string (e.g. `"conelius"`).
- `GetRulerPortraitDefinition(_name)` → `RulerPortraitDefinition` or `undefined`.
- `RegisterAllRulerPortraits()` — registers every playable ruler. Call once at game start (`oGameControl`'s Create event, alongside `RegisterAllOrders`/`RegisterAllUnitDefinitions`/`RegisterAllBuildingDefinitions`).

### `RulerPortraitController(_def)`

Live per-instance playback state. One per portrait shown on screen.

- `Step()` — call once per Step event. Advances the current clip's frame, or counts down the idle wait and picks a new clip when it expires. Scaled by `global.matchSpeed` throughout (playback speed AND idle wait), so it pauses/fast-forwards with the rest of the match.
- `CurrentImageIndex()` → the sprite frame to draw this Step.
- `Draw(_x, _y, _scale = 2)` — call once per Draw GUI event. Draws at `(_x, _y)` using the sprite's own origin (bottom-left for every portrait registered so far).

## Global state

- `global.selectedRuler` — string key into the registry (e.g. `"conelius"`), set once at game start in `oGameControl`'s Create event. No character-select flow exists yet — this is a hardcoded default to replace later.

## Usage

```gml
// Game start (oGameControl Create)
RegisterAllRulerPortraits();
global.selectedRuler = "conelius";

// Owner Create (oUnitControl)
rulerPortraitController = new RulerPortraitController(GetRulerPortraitDefinition(global.selectedRuler));

// Owner Step
rulerPortraitController.Step();

// Owner Draw GUI
rulerPortraitController.Draw(27, 1080, 2);
```

## Registered rulers

### Conelius (`sConeliusPortrait`, 30 frames)

| # | Clip | Frames | Start → End facing | Idle? |
|---|---|---|---|---|
| 1 | Idle Looking Left | 1 (index 0) | Left → Left | Yes |
| 2 | Blink Left to Right | 4 (1-4) | Left → Right | No |
| 3 | Idle Looking Right | 1 (index 5) | Right → Right | Yes |
| 4 | Blink Right | 5 (6-10) | Right → Right | No |
| 5 | Mustache Wiggle | 5 (11-15) | Right → Right | No |
| 6 | Looking Around | 14 (16-29) | Right → Left | No |

Only "Blink Left to Right" can start from Idle Left; every other real clip starts from Right, and only "Looking Around" returns him to Left. So from Idle Left, the only thing that ever plays is "Blink Left to Right" — everything else waits for "Looking Around" to bring him back around first.

## Known assumptions (flag if wrong)

- Idle wait between clips: random 2-5 seconds at `matchSpeed == 1` (`RULER_PORTRAIT_IDLE_MIN_STEPS`/`MAX_STEPS`). Not specified by the original request — picked to read as "occasionally fidgets."
- `frameAdvance` scales with `global.matchSpeed`, so the portrait pauses when the match pauses. Could reasonably go the other way (portrait keeps idly animating through a pause) — went with match-speed scaling for consistency with everything else animated in this codebase.
