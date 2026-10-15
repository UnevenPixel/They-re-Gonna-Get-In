# FateEngineDrumScripts

The Fate Engine's spinning drum render.

## Fake-3D carousel mechanic

Each drum is a faked 3D cylinder: `FATE_DRUM_SLOT_COUNT` items sit evenly spaced around a vertical ellipse (a classic 2D "fake carousel" trick, same idea as a rotating coin/wheel menu). Angle 0 is the front/landing position -- straight ahead, facing the player, at the drum's vertical center. As `spinAngle` advances, each slot's angle maps to depth (`cos`) and vertical offset (`radius * sin`), recomputed every step:

- depth `+1` at the front (angle 0) -- full size, fully opaque.
- depth `0` at the sides (angle 90/270) -- edge-on, thin sliver.
- depth `-1` at the back (angle 180) -- directly behind the front slot, same screen position, hidden.

Only slots with depth > 0 (the front hemisphere) are drawn at all -- the back hemisphere is conceptually occluded by the drum's own body. That's exactly where item swapping happens: the instant a slot crosses into the back zone (`FATE_DRUM_BACK_ZONE_MIN`/`MAX`), its item is silently rerolled, so the "reel" appears to cycle through endless items without the player ever seeing a swap happen (requirement 1 from the 2026-07-05 Fate Engine drum-render task).

Once stopped, `GetLockedItem()` reads back whichever item is sitting at the front/landing position (angle 0) -- what a hover tooltip (or eventually the cash-out payout) reads off (requirement 2).

All drum items are 48x48 (`sFateEngineResources`' native size, and every building sprite -- `oBuildingParent` is always 48x48). Drawing them at `FATE_DRUM_ITEM_SCALE` (2x, per 2026-07-05 request) is handled entirely in `Draw()` -- callers just position drums in GUI space and don't need to think about the scale themselves.

**Independent of match speed** (2026-07-13): drum animation (spin/decel/landing, `Step()`) no longer scales by `global.matchSpeed` -- the drums are a UI mechanic independent of the battlefield's speed control, and `FateEngineOverlay` freezes `global.matchSpeed` to 0 while open anyway (`FateEngineOverlayScripts.gml`), which would have frozen the drums too if they'd stayed coupled to it. Every rate is a flat degrees/step (or fraction/step) value.

## Reward roll (FateEngineRollReward)

The real weighted Fate Engine reward table (2026-07-13) -- a straight coin-flip (`FATE_ENGINE_REWARD_BLUEPRINT_CHANCE`) between:
- A blueprint: uniform over every currently-registered building type (`global.__buildingDefRegistry`, read generically so this doesn't need updating as buildings are added -- same idiom `GainXP`'s AI blueprint grant already uses, `ProgressionScripts.gml`).
- A resource bundle: uniform over `global.fateEngineRewardResourceTypes` (the 5 CURRENTLY ACTIVE base resources -- wood/wheat/water/iron/gold; the other 5 slots in `global.resourceIconOrder` -- meat/bones/coal/weapons/coins -- aren't produced or spent by anything yet, confirmed via grep, so rewarding them would just be inert), amount uniformly between `FATE_ENGINE_REWARD_RESOURCE_MIN`/`MAX`.

This replaces the old `FateDrumRandomPlaceholderItem` stub, which only ever produced a LOOK (sprite/subimg/label) with no data behind it -- `FateEngineItem` now carries `rewardType`/`rewardData` too so `FateEngineOverlay.Cashout()` (`FateEngineOverlayScripts.gml`) can actually grant what a drum landed on.

Odds/amounts are a first-pass judgment call, not a tuned design (no corruption-scaling/event-type rewards exist yet either) -- see `PATCH_NOTES.md` for the full list of what's still a placeholder here. `Stop()` already accepts an optional `_targetItem` so a future weighted-odds-by-corruption pass can still force a drum to land on a specific resolved result without touching this file's mechanics again.

## FateEngineItem

One item shown on a Fate Engine drum -- an icon/label to draw plus, since 2026-07-13, enough data to actually GRANT the reward it represents. Still deliberately generic on the display side (sprite/subimg/label) so a future event-type reward can reuse the same shape; `rewardType`/`rewardData` is where the actual payload lives (`"resource"`: `{resourceName, amount}`; `"blueprint"`: `{buildingType}`).

## FateDrum

A single Fate Engine drum. Not a GM instance -- a plain struct, same pattern as `BlueprintController`/`SelectionController` (`BlueprintScripts.gml`/`UnitSelection.gml`): an owning object calls `Step()`/`Draw()` once per frame.

`slots` holds one `{item, wasInBackZone}` entry per slot -- `wasInBackZone` gates the swap-on-entry so a slot rerolls exactly ONCE per pass through the back zone, not every step while it happens to be sitting there.

**State machine**: `"stopped"` -> `Spin()` -> `"spinning"` -> `Stop()` -> `"stopping"` -> (once slow enough) `"landing"` -> `"stopped"`.

- `Spin()`: starts at full speed (`FATE_DRUM_SPIN_SPEED`). No-op if already spinning/stopping.
- `Stop(_targetItem)`: begins decelerating. If `_targetItem` is given, that slot's item is forced to `_targetItem` the moment it lands, so a future weighted reward roll can dictate the actual result rather than leaving it to whatever was already spinning there.
- `Step()`'s "stopping" branch decelerates by `FATE_DRUM_STOP_DECEL` per step; once slow enough (`spinSpeed <= FATE_DRUM_STOP_DECEL * 4`), hands off to "landing" rather than snapping straight to the nearest slot boundary -- an instant snap would read as a jerk/pop. `landingTarget` is fixed the moment "landing" begins.
- `Step()`'s "landing" branch eases the remaining gap to `landingTarget` down every step (2026-07-06 request: smooth landing instead of a hard snap) by `FATE_DRUM_LAND_EASE_RATE`, snapping exactly once within `FATE_DRUM_LAND_SNAP_EPSILON`. The gap is normalized to `(-180, 180]` first so the drum always eases along the SHORT way around -- since decel can overshoot slightly past the nearest boundary, that short way is sometimes backward ("rubber-banding" back up to the slot it just passed), which is expected and fine here.

`Draw()`: draws every slot currently in the front hemisphere (depth > 0), positioned/scaled/faded by its depth so the drum reads as a spinning cylinder rather than a flat list. Every item is drawn at `FATE_DRUM_ITEM_SCALE` on top of its depth-based shrink -- e.g. a 48x48 item at full front depth draws at 96x96. Scale shrinks toward the top/bottom edge but never all the way to 0 (`0.35 + 0.65 * depth`). Text (hover tooltips etc.) is a separate concern for the caller and is NOT scaled by this.

`GetLockedItem()`: the item at the front/landing position, only meaningful once the drum has actually stopped -- while spinning or decelerating there's no single stable answer, so this returns undefined.

## API

- `FATE_DRUM_SLOT_COUNT`, `FATE_DRUM_SPIN_SPEED`, `FATE_DRUM_STOP_DECEL`, `FATE_DRUM_BACK_ZONE_MIN`, `FATE_DRUM_BACK_ZONE_MAX`, `FATE_DRUM_ITEM_SCALE`, `FATE_DRUM_LAND_EASE_RATE`, `FATE_DRUM_LAND_SNAP_EPSILON`.
- `FATE_ENGINE_REWARD_BLUEPRINT_CHANCE`, `FATE_ENGINE_REWARD_RESOURCE_MIN`, `FATE_ENGINE_REWARD_RESOURCE_MAX`, `global.fateEngineRewardResourceTypes`.
- `FateEngineItem(_sprite, _subimg, _label, _rewardType, _rewardData)`.
- `FateEngineRollReward()`.
- `FateDrum(_x, _y, _radius)` -- `.GetSlotAngle(_slotIndex)`, `.Spin()`, `.Stop(_targetItem)`, `.Step()`, `.Draw()`, `.GetLockedItem()`.
