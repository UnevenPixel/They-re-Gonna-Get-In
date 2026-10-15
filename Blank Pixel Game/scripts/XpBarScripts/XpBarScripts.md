# XpBarScripts

The lower HUD's XP bar widget: bar backer + fill + animated 20%-mark "milestone" reveals + a tossed Fate Token coin every time a milestone is first reached + (2026-08-16) a scatter of static Fate Token icons in the region below the bar, tracking the player's current unspent Fate Token count.

## Sprites

- `sXpBar` -- backer/frame, custom origin so drawing it and `sXpBarFill` at the same point lines the fill up inside the border automatically.
- `sXpBarFill` -- progress fill, drawn via `draw_sprite_part_ext` so only `_percent` of its width shows.
- `sXpBarMilestone` -- 1px-wide tick line, reveals top-to-bottom the same way.
- `sFateTokenSmall` -- the tossed coin.

## Milestones

Layered on top of `ProgressionScripts.gml`'s existing Fate Token system -- `GainXP` awards a token at every 20/40/60/80/100% mark of `AgeXpRequired(global.age[team])`. This widget visualizes 4 of those 5 marks (20/40/60/80%; the 5th coincides with the age-up/bar-reset, not a milestone tick) at 4 fixed pixel offsets from the widget's origin. Percent-fill math re-reads `AgeXpRequired` every call, so the bar's effective "100%" updates automatically as the team ages up.

Each milestone stays invisible (0px reveal) until its threshold is actually met, then reveals top-to-bottom and stays fully revealed for the rest of the bar's cycle.

`XP_BAR_ORIGIN_X/Y` and the milestone offsets are GUI-space coordinates that already account for the 2x render scale -- only sprite rendering needs the explicit `xscale`/`yscale = XP_BAR_SCALE`, not the positions.

## Region tokens (2026-08-16 request)

**"In the space below the XP bar, extending down 100px from the bottom of the xp bar widget, whenever a new fate token is gained, draw one token in a random location in that region. Use the small fate token sprite."** A SEPARATE mechanic from the milestone toss-coin system above -- that one fires on XP-bar-FILL milestones (a purely visual flourish tied to `XpBarFillPercent`), not actual `global.resources[team].fateTokens` gains. This one is the reverse: it watches the real resource value.

**Detected via before/after diffing in `Step()`, not a hook at each grant site.** `fateTokens` currently has THREE separate `+=` call sites scattered across the project (`DealerIntroScripts.gml`'s one-time scripted grant, `ProgressionScripts.gml`'s XP-milestone grant, `Economy.gml`'s generic cost/reward resolution) and one spend site (`FateEngineOverlayScripts.gml`'s `Spin()`). Rather than adding a call into all three grant sites (fragile -- a FUTURE fourth grant site would silently miss the visual), `_SyncRegionTokens()` compares `global.resources[team].fateTokens` against a stored `lastFateTokens` every `Step()` -- the exact same before/after-diff idiom this struct's own age-up detection (`lastAge`) already uses. Catches every gain regardless of source, present or future, with zero coupling to the grant sites themselves.

**Region = the bar's own width × `XP_BAR_TOKEN_REGION_HEIGHT` (100px) starting at the bar's bottom edge**, computed via `_RegionRect()`, built directly off the existing `XpBarWidgetHitRect()` (so it can't drift out of sync with the bar's actual rendered bounds/position).

**Tracks CURRENT unspent count, not a permanent log of every gain ever.** A decrease (any spend, e.g. `Spin()`'s `fateTokens -= 1`) removes an equal number of `regionTokens` entries. This wasn't explicitly requested -- the request only describes what happens on a GAIN -- but was chosen deliberately: without removal, the region would accumulate an unbounded, ever-growing pile of icons over a long match (most of them representing already-spent tokens), which reads as broken/confusing rather than informative. Flag if a permanent, never-removed "log of every token ever earned" was actually intended instead -- that would be a one-line change (drop the `_delta < 0` branch in `_SyncRegionTokens()`).

**Static, no animation.** Unlike the milestone toss-coins (which arc up, spin, flip, and fall under gravity), region tokens just sit at their randomly-rolled position for as long as they're "held" -- no tumble/fade was requested, and none was added. Drawn at `XP_BAR_SCALE` (2x) to match every other sprite in this widget, using `sFateTokenSmall` frame 0, same sprite/frame the toss-coins already use.

**No inset for the sprite's own size** -- the random `(x, y)` is rolled anywhere within `_RegionRect()`'s full bounds, including right up to its edges, so a token drawn near an edge can visually hang slightly outside the 100px band depending on `sFateTokenSmall`'s own origin. Matches the toss-coin code's own precedent (no such inset there either) -- flag if tokens should be inset by half their own scaled size to stay strictly inside the region.

## Token drag-to-activate (2026-08-16 follow-up request)

**"Click and hold from this portion of the UI (while the fate engine is open), have the large fate token draw at the mouse position, and one of the tokens be removed. If you drag this token up to the center of the screen (roughly where the machine is), spend the token to 'activate the machine'... by having the token disappear and a number of purple and gold particles rise up from where the token disappeared to."** A THIRD mechanic layered on top of the milestone toss-coins and the region-token pile above -- this one lets the player pick a region token back UP and drag it onto the machine. See `FateEngineOverlayScripts.md`'s "Machine activation" section for the machine-side half (dim/lit drums, fade, particle burst) -- this section only covers the drag/drop half, which lives entirely here.

**State machine (`StepTokenDrag()`, called first thing from `Step(_fateEngineOverlay)`).** `dragging` (bool) plus `dragX`/`dragY` (GUI-space, only meaningful while dragging) are the whole state. While not dragging, a `mouse_check_button_pressed(mb_left)` inside `_RegionRect()` with at least one region token available picks up the LAST-pushed entry (`array_delete` from the end) and starts dragging -- the region is treated as one pickup zone, not per-icon hit-testing, which is the simplest reading of "click and hold from this portion of the UI." While dragging, `dragX`/`dragY` track the mouse every step (no easing -- player-driven, same convention the Spin lever's own drag leg uses in `FateEngineOverlayScripts.gml`). On release, either the token activates the machine or falls back into the region pile -- see below.

**Drop-eligibility check reaches into `FateEngineOverlay`.** A release counts as a successful drop only if BOTH `_fateEngineOverlay._TokenActivateEligible()` (fully popped up, not closing, not interaction-locked -- same three-condition gate the buttons/lever already use) AND `_fateEngineOverlay._DistanceToMachineCenter(mouseX, mouseY) <= XP_BAR_TOKEN_ACTIVATE_RADIUS` (220px, untuned judgment call -- the request only said "roughly where the machine is," no exact radius given) are true. A release that fails either check just returns the token to a fresh random spot in `_RegionRect()`, same as a fresh gain would -- no separate "rejected drop" animation or feedback was requested.

**Token spend happens HERE, not through `_SyncRegionTokens()`'s own diff.** The dragged token was already removed from `regionTokens` at pickup time, so a successful drop decrements `global.resources[team].fateTokens` directly and immediately re-syncs `lastFateTokens` to the new value -- letting the next `Step()`'s before/after diff "see" this same spend too would incorrectly try to remove a SECOND region-token entry that no longer exists. This is a deliberate, narrow exception to the "always go through the diff" convention the region-token system otherwise follows, made necessary by the token having left `regionTokens` before the resource value itself changed.

**Gated on `_fateEngineOverlay.isOpen`, per request ("while the fate engine is open").** If the overlay isn't open, pickup can't start; if it CLOSES mid-drag (not explicitly covered by the request -- some other input could force it shut), the in-progress drag is dropped back into the region pile rather than lost or left stuck. `Step()` was re-signatured to `Step(_fateEngineOverlay)` for this reason -- `oUnitControl/Step_0.gml` now calls it from BOTH its own "Independent systems" block (the normal path) AND from inside the `fateEngineOverlay.isOpen` early-exit branch (which would otherwise skip `xpBarWidget.Step()` entirely while the overlay is open, since that branch `exit`s before ever reaching the Independent-systems block) -- see `oUnitControl.md`.

**No spatial conflict with the machine's own buttons/lever.** Confirmed by inspection: the buttons live near the TOP of the screen (`FATE_ENGINE_BUTTON_TOP_Y = 30`) and the lever's grab rect is offset from the body center -- neither overlaps the region-pickup rect (below the XP bar, bottom of screen) or the drop-zone radius (centered on the middle drum). No `consumedClick`-style guard was added between this drag and the machine's own click handling.

**Draw order/scale for the dragged token.** `sFateTokenLarge` (48x48, confirmed via the sprite asset) drawn at NATIVE (1,1) scale, not `XP_BAR_SCALE` -- unlike `sFateTokenSmall`, which this widget always upscales, the large sprite is already full-size. Drawn LAST in `Draw()` so it's never occluded by the bar/fill/milestones/other tokens mid-drag.

## API

- `XpBarMilestonePercent(_index)` → fill fraction (0-1) for a milestone index.
- `XpBarFillPercent(_team)` → current fill fraction against `AgeXpRequired`.
- `XpBarWidgetHitRect()` → GUI-space rect of the bar's backer sprite, derived from the same anchor/offset/scale math `Draw()` uses. Clicking it opens the Fate Engine overlay (`oUnitControl/Step_0.gml`).
- `XpBarWidget(_team)` -- plain struct, owner calls `Step(_fateEngineOverlay)`/`Draw()`. **2026-08-16 follow-up: `Step()` now takes `_fateEngineOverlay`** (needed by `StepTokenDrag()`) -- both call sites in `oUnitControl/Step_0.gml` updated, see Token drag-to-activate above.
  - `SpawnToken(_x)` -- launches one tossed coin; tumbles up then falls under gravity, spinning/flipping, until it's fallen `XP_BAR_TOKEN_FALL_DISTANCE` px or `XP_BAR_TOKEN_MAX_LIFE` steps pass.
  - `_RegionRect()`, `_SyncRegionTokens()` (2026-08-16, new) -- see "Region tokens" above.
  - `regionTokens` field (2026-08-16, new) -- array of `{ x, y }`, one per currently-held Fate Token.
  - `StepTokenDrag(_fateEngineOverlay)` (2026-08-16 follow-up, new) -- see "Token drag-to-activate" above.
  - `dragging`, `dragX`, `dragY` fields (2026-08-16 follow-up, new) -- see "Token drag-to-activate" above.
