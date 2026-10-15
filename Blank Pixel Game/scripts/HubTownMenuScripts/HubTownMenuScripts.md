# HubTownMenuScripts

The hub town screen, between the title screen and gameplay. Owned by `oHubTownMenu` (`rmHubTown`), same "plain struct + thin object wrapper" split as every other screen/controller (`TitleMenu`, `PauseMenu`, `FateEngineOverlay`, ...).

## Assets

`folders/Menus/HubTown.yy`, all middle-center origin except the background:

- `sTownBack` -- 1920x1080, top-left origin, matches the room 1:1. Draws at native scale (`HUBTOWN_SCALE = 1`).
- `sBeggarTown` -- 592x628, positioned at (296, 766) (center point). Click opens the Beggar's dialogue tree.
- `sCastleTown` -- 356x304, positioned at (854, 160) (center point). Click → `room_goto(rmWarRoom)` (2026-08-10: was a direct `room_goto(rmTestGameplay)`; 2026-08-13: now routes through the new War Room screen first, which itself routes on to the pre-run Campaign-select screen -- see `WarRoomMenuScripts.md`).

## Hover-dim effect

Hovering either option dims every OTHER option plus the background 25% toward black (`HUBTOWN_DIM_AMOUNT`); the hovered option stays full brightness; nothing dims when nothing's hovered. Per-element `dimLerp` (0..1) advanced each Step via `lerp(dimLerp, target, HUBTOWN_DIM_LERP_RATE)`, fed into `merge_color(c_white, c_black, HUBTOWN_DIM_AMOUNT * dimLerp)` at draw time. `HUBTOWN_DIM_LERP_RATE` (0.25) matches `TITLE_MENU_HOVER_LERP` for a consistent feel across screens.

No entrance transition (unlike `TitleMenu`) -- immediately interactive on room load.

## Beggar dialogue tree

```
main ("Spare a few Groats?", 4 responses)
  -> A: A1 ("No lad, not goats!...") -> A2 ("...called Kyrii...") -> back to main
  -> B: B1 ("You DO look sharp...") -> back to main
  -> C: C1 ("Who taught you to say that?...") -> back to main
  -> D: D1 ("Ahhh... you have big aspirations...") -> back to main
```

Every A1/A2/B1/C1/D1 node has one italicized `[Continue]` response (2026-08-10: was `[Back]` on A2/B1/C1/D1, now consistently `[Continue]` everywhere past the main node's 4 choices); the main node's 4 aren't italicized.

**Bug found the same day: the literal string `"[Continue]"` rendered as BLANK, not as visible text.** `[`/`]` are Scribble's own command-tag delimiters (`SCRIBBLE_COMMAND_TAG_OPEN`/`CLOSE`, `__scribble_gen_2_parser.gml`) -- Scribble parsed `[Continue]` as an attempted (unrecognized) tag and consumed it instead of displaying it, rather than showing the bracket characters literally. This was true for A1's `[Continue]` too, from the very first time this dialogue tree shipped -- it's a general Scribble gotcha, not something the `[Back]` -> `[Continue]` text swap introduced. Fixed by doubling the opening bracket, `"[[Continue]"` -- Scribble's parser treats `[[` as an escaped literal `[` (confirmed by tracing `__scribble_gen_2_parser.gml`'s `_state_command_tag_flipflop` handling), after which the rest of the string (`Continue]`) is just plain text since parsing never entered tag mode. The closing `]` needs no escaping -- it's only special while actively inside an open tag. Name drawn in `c_yellow`; option/name text still use the standard `HOVER_CARD_TEXT_COLOR`, but the speaker body line now uses its own near-black `DIALOGUE_SPEAKER_TEXT_COLOR` (`DialogueOverlayScripts.gml`). Exit button stays enabled on every node (not just the main screen) so the player is never trapped in a dead-end sub-screen.

Auto-opens once, gated by `global.playerSaveData.hasSeenBeggarIntro` (`PlayerSaveDataScripts.gml`) -- genuinely "first time ever," survives a restart, resettable via Settings' "Restart Tutorial" button. **2026-08-10: the auto-open and the click-to-reopen path both now go through `HubControl` (`HubControlScripts.gml`)** instead of `HubTownMenu` deciding this itself -- `hubControl.StartBeggarTutorial()` replaces the old direct `_OpenBeggarMain()` call + immediate flag-set on first visit, and the Beggar option is unavailable (no hover, no click) for the duration via `hubControl.IsOptionAvailable("beggar")`. `hasSeenBeggarIntro` is now saved when the tutorial dialogue CLOSES, not when it opens -- see `HubControlScripts.md` for why. Manual re-clicks after the intro route through `hubControl.GetDialogueOpener("beggar")` rather than calling `_OpenBeggarMain()` directly, so a future NPC/dialogue-tree change only touches `HubControlScripts.gml`.

**2026-08-13:** all six `dialogueOverlay.Open(...)` calls in this tree now pass `sBeggarPortrait` as the 9th argument, so the Beggar's portrait shows bottom-left anchored (slides in from further left on fade-in) for every node of the conversation (main + all five follow-ups) -- see `DialogueOverlayScripts.md`'s "Position & portrait" section for the draw math. The same change also repositioned the dialogue box itself -- originally right-hugged, later (same day) changed to centered within a 1280px slot -- which applies globally to `DialogueOverlay` and isn't Beggar-specific.

**Also 2026-08-13:** the hub town screen now has its own Escape pause menu (`hubPauseMenu`, `HubPauseMenuScripts.gml`), wired into `oHubTownMenu` alongside this struct -- see `HubPauseMenuScripts.md`. Escape is suppressed while `dialogueOverlay.isOpen` so it can't pop up mid-conversation with the Beggar.

**2026-08-13 (second pass):** all six `dialogueOverlay.Open(...)` calls now also pass `aBeggarSpeak` as the new `_speakerSound` argument, so the Beggar's lines play a throttled per-character blip while typing out -- see `DialogueOverlayScripts.md`'s "Per-character speaker sound" section.

**Important -- the seven `_OpenBeggarX`/`_OnBeggarMainSelect` functions are deliberately NOT `static`,** unlike every other method in this file. They're passed around and stored as bare callback values (`dialogueOverlay`'s `onSelect` param) and invoked later from inside `DialogueOverlay.Update()` -- a different struct entirely. A `static` function called through a stored reference uses the CALLER's `self`, not the struct it was declared on, so as `static` these crashed with "variable not set" the moment a response was clicked (confirmed in-engine). Plain (non-static) methods stay bound to their originating instance regardless of how they're later invoked -- the correct shape for anything handed off as a callback. Don't "clean up" these back to `static` to match the rest of the file.

## API

- `HubTownOption(_sprite, _action, _x, _y)` -- one hoverable/clickable element's state.
- `HubTownMenu()` -- the screen. `Update()`/`Draw()` called once per Step/Draw GUI by `oHubTownMenu`. Owns a `hubControl` (`HubControlScripts.gml`) that gates option availability and resolves dialogue openers -- see that file for the tutorial-gating mechanism.
