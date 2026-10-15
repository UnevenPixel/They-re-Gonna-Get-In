# PreRunMenuScripts

The pre-run screen: reached from the hub town's castle (`HubTownMenuScripts.gml`'s "castle" option, `HubControlScripts.gml`'s `GetDialogueOpener`-style indirection doesn't apply here -- castle routing is still a plain `room_goto` in `_HandleOptionAction`), sits between the hub town and actual gameplay. 2026-08-10 request: "we do need the pre-run screen" -- lets the player pick a Campaign before a match starts. Owned by `oPreRunMenu` (`rmPreRun`), same "plain struct + thin object wrapper" split as every other screen.

## Scope note -- more screens coming (RESOLVED 2026-08-13)

The request that added this screen also mentioned "there will be another screen before the one we will add next" -- that screen has now landed: the **War Room** (`WarRoomMenuScripts.gml`), which sits between the hub town and this screen. `HubTownMenuScripts.gml`'s "castle" option now points at `rmWarRoom`, and War Room's own Continue button points at `rmPreRun`. This screen's own campaign actions still just `room_goto(rmTestGameplay)` for now -- that part of the chain hasn't grown yet.

## Visuals -- all placeholders pending real art

No sprite assets exist yet for this screen -- everything below is drawn with primitives, the same "temporary primitive shape" idiom already used for Blueprint's page arrows and the Fate Engine overlay's buttons when no art exists, except the exit button, which reuses the real `sDialogueUIExit` sprite from `DialogueOverlayScripts.gml` directly (explicitly requested: "add the exit button from dialogue"). Swap in real sprites for everything else when available; the macros below are the only things that need to change.

- `PRERUN_BG_COLOR` -- dull aged-wood brown, a full-screen `draw_rectangle` fill. Picked as a plausible "dull brown"; flag if a specific reference color was meant.
- `PRERUN_PALETTE_BASE` -- pale bronze, the palette's base tone. `PRERUN_PALETTE_LIGHT`/`PRERUN_PALETTE_DARK` are `merge_color` blends toward white/black (35% each way) rather than hand-picked swatches, so every tone stays visibly related to the base if it's tweaked later. Used for every panel/button's fill (dark tone, lerping to light on hover) and border (base tone, or light for a selected-but-unhovered campaign entry -- see Campaigns below).
- Text is white (`PRERUN_TEXT_COLOR`) with a black drop shadow via `DrawCardTextWithShadow` (`HoverCardScripts.gml`) -- the same shadow helper `DialogueOverlay`/`HoverCard` already use. Font is `HOVER_CARD_BODY_FONT` ("fntDataCard"), explicitly requested as "the same font we were using for dialogue body text."

## Layout

2026-08-10: Campaigns moved from the right side to the left (`PRERUN_PANEL_MARGIN_LEFT` from the GUI's left edge now, was `PRERUN_PANEL_MARGIN_RIGHT` from the right). Header ("Campaigns") over a vertical stack of entry buttons, one per `CampaignEntry`.

**Exit button** -- top-left corner, `PRERUN_EXIT_MARGIN` (8px) buffer on both axes, reusing `sDialogueUIExit` at `PRERUN_EXIT_SCALE` (= `DIALOGUE_SCALE`, so it renders at the same size it does in a dialogue box). Click routes to `rmWarRoom` (2026-08-13: was `rmHubTown` -- changed, not explicitly requested, so backing out goes one screen at a time now that the War Room sits between the hub town and this screen, instead of skipping over it. Flag if this should still jump straight back to the hub town).

**Flavor-text box** -- sits between the Campaigns panel and the Start Campaign button. Left edge = Campaigns panel's right edge + `PRERUN_PANEL_GAP` (6px). Right edge is derived, not fixed: it mirrors the left edge around the screen's horizontal center (`display_get_gui_width() - _x1`), which is what "wide enough that it centers itself on the screen" works out to mathematically -- the box's own midpoint lands exactly on the screen's midpoint. Top edge matches the top (first) campaign entry's top edge (`_EntryRect(0).y1`). Bottom edge is `PRERUN_FLAVOR_BOTTOM_MARGIN` (64px) up from the screen's bottom edge.

**Start Campaign button** -- right of the flavor box, same `PRERUN_PANEL_GAP` (6px) buffer the flavor box uses on its OTHER side (explicitly "the same horizontal buffer"). Width matches the Campaigns entry buttons' width (`PRERUN_PANEL_WIDTH`) per explicit request. Bottom edge aligns with the flavor box's bottom edge per explicit request; height was NOT specified, so it reuses `PRERUN_ENTRY_HEIGHT` (`PRERUN_START_BUTTON_HEIGHT` macro, currently just an alias) for visual consistency with the campaign buttons -- flag if a different height was intended. Because of how the flavor box's right edge is derived (mirrors its own left edge around center), the Start button's own right edge works out to be exactly `PRERUN_PANEL_MARGIN_LEFT` from the screen's right edge -- the whole layout is left/right symmetric as a side effect of the math, not a separately hand-tuned number.

## Campaign selection vs. launching

2026-08-10 addition: clicking a Campaigns entry no longer launches it directly -- it SELECTS it (`_SelectCampaign`), which updates the flavor box's text (rewrapped to the flavor box's current width) and gives that entry's border the "light" palette tone even when the mouse isn't over it, so the selection stays visible after the cursor moves away. `selectedIndex` defaults to `0` and `_SelectCampaign(0)` runs once at construction, so the flavor box shows Talos's text immediately without requiring a click -- matches the request describing Talos's flavor text as the screen's current/default state, not something gated behind an interaction. Launching now only happens via the Start Campaign button, which calls `campaigns[selectedIndex].action()`.

`campaigns` is an array of `CampaignEntry` (name + action + flavor text), mirroring `HubTownOption`'s/`BlueprintStack`'s "array of small structs, one per list item" shape used everywhere else in this project's UI code. Only one entry exists: **Talos**, the tutorial campaign. Its flavor text (Talos invading Kyrii, the player as Kyrii's advisor, destroy the temporary base) was fleshed out from the request's 2-sentence brief into a full paragraph, matching the light, slightly wry in-universe tone the Beggar's dialogue already established ("Spare a few Groats?") rather than writing it grimdark.

`_PlayTalos()` always `room_goto(rmTestGameplay)` for now. Per the request: once the tutorial's actual in-gameplay pop-ups exist, this entry should branch -- pre-completion routes into the tutorial run, post-completion instead faces "the same Talos AI, but without tutorial pop-ups." Neither the tutorial pop-up system nor a completion flag exists yet -- there was nothing to branch on, so both states currently collapse to the same plain gameplay room. The `TODO` comment on `_PlayTalos` marks exactly where that branch goes; no flag or second destination was invented ahead of that system existing.

**2026-08-13 update: the completion flag now exists** -- `global.playerSaveData.tutorialCompleted` (`PlayerSaveDataScripts.gml`), set via `CompleteTutorial()` once the player's first run ends. See `WarRoomMenuScripts.md`'s "Tutorial completion" section. The branch itself still isn't wired up here -- wasn't part of that request either, just noting the flag is ready whenever this TODO gets picked up. The in-gameplay tutorial pop-up system itself still doesn't exist.

`_PlayTalos` is `static`, unlike the Beggar dialogue's `_OpenBeggarX` functions (`HubTownMenuScripts.gml`), because it never touches `self` -- it's just a `room_goto` call, so it doesn't matter what `self` resolves to when it's invoked via `campaigns[selectedIndex].action()`. If a future campaign's action needs instance state, give it the same non-static treatment `_OpenBeggarX` needed, for the same self-binding reason -- see that file's header comment.

## Pause menu

2026-08-13: `oPreRunMenu` now owns a `HubPauseMenu` (`hubPauseMenu`, `HubPauseMenuScripts.gml`), opened via Escape, independent of `PreRunMenu` itself -- `Escape opens/closes` and the "click outside closes" behavior live entirely in `HubPauseMenu`, not in this struct. No conflict with this screen's own exit button (`_ExitRect()`/`room_goto(rmWarRoom)` on click, see Layout above) -- that's a distinct, always-available mouse-only affordance; Escape now ALSO gets you out (via the pause menu's "Return to Title Menu"/"Return to Desktop"), but through a different path with different destinations. See `HubPauseMenuScripts.md` for the full menu/wiring details.

## API

- `CampaignEntry(_name, _action, _flavorText)` -- one Campaigns list row.
- `PreRunMenu()` -- the screen. `Update()`/`Draw()` called once per Step/Draw GUI by `oPreRunMenu`.
