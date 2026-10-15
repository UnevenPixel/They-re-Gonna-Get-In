# WarRoomMenuScripts

2026-08-13 request: a new screen between the hub town and the pre-run (Campaign select) screen. Today it's storytelling/tutorial staging ground; eventually it's where the player picks their leader. Owned by `oWarRoomMenu` (`rmWarRoom`), same "plain struct + thin object wrapper" split as every other screen in this chain.

This is the `folders/Menus/WarRoom.yy` folder (and its `sWarRoomBG`/`sConneliusWarRoom`/`sWarRoomContinueButton` sprites) that already existed in the project before this pass -- confirms this was a planned screen, referenced back in `HubPauseMenuScripts.md`'s "other locations in the hub town that will get menus soon."

## Flow change

Was: Hub Town (castle) → Pre-Run → Gameplay.
Now: Hub Town (castle) → **War Room** → Pre-Run → Gameplay.

- `HubTownMenuScripts.gml`'s `"castle"` case now routes to `rmWarRoom` (was `rmPreRun`).
- **`PreRunMenuScripts.gml`'s own exit button now routes to `rmWarRoom` instead of `rmHubTown`.** Not explicitly requested -- changed so backing out goes one screen at a time instead of skipping over the newly-inserted War Room. Flag if Pre-Run's exit should instead still jump straight back to the hub town.
- War Room's own exit button routes to `rmHubTown` -- unambiguous, since War Room is the first screen after the hub town in this chain.

## Layout

Everything placed at literal coordinates per the request, all at `WARROOM_SCALE = 1` (native, matching `sWarRoomBG`'s 1920x1080 size to the room 1:1 -- same "background sprite IS the room" idiom `sTownBack`/`HUBTOWN_SCALE` uses in `HubTownMenuScripts.gml`).

- **Background** -- `sWarRoomBG`, drawn at `(0, 0)`, no positioning math needed (top-left origin, full-screen).
- **Leader portrait** -- `sConneliusWarRoom`, drawn at `(933, 348)`. The sprite's own origin is middle-center (`xorigin: 153, yorigin: 126`, confirmed from the `.yy`), so `draw_sprite_ext` naturally centers it there with no extra offset math -- the literal coordinates in the request ARE the center point.
- **Continue button** -- `sWarRoomContinueButton`, drawn at `(1077, 609)`. Top-left origin, so the given coordinates are the sprite's top-left corner. Routes to `rmPreRun`. `_ContinueRect()` derives its hit-test rect from `sprite_get_xoffset`/`sprite_get_yoffset` rather than hardcoding "top-left origin" as an assumption -- same origin-agnostic defensiveness `DialogueOverlay._PortraitDrawPosition()` uses, so this keeps working if the sprite's origin is ever changed in the IDE.
- **Exit button** -- reuses `sDialogueUIExit` at `DIALOGUE_SCALE`, same sprite/scale `PreRunMenuScripts.gml`'s exit button already uses ("the Exit button found in other setups"). `WARROOM_EXIT_MARGIN` (8px) buffers both axes from the top-left corner, per explicit request.

## Continue button hover feedback

`sWarRoomContinueButton` has only one frame (no dedicated hover frame, unlike `sDialogueUIExit`'s 2 frames). 2026-08-13 request: a faint pulsing white tint while hovering, oscillating between 0.1 and 0.4 alpha on a sine wave, peak and valley landing roughly 1 second apart, always starting at 0.1 the instant a fresh hover begins.

**Why additive blending, not a color tint.** `draw_sprite_ext`'s color param is multiplicative -- tinting toward white is the identity operation (can't brighten past the source image), so a "white tint" needs actual additive blending to read as a highlight/glow rather than a darken (which is what the previous pass's `merge_color(c_white, c_black, ...)` approach did instead, before this request explicitly asked for a lighten effect). Implementation draws the button normally first, then -- only while `hoveredContinue` -- redraws the SAME sprite tinted `c_white` at `continuePulseAlpha`, wrapped in `gpu_set_blendmode(bm_add)`/`gpu_set_blendmode(bm_normal)`. Additive blending respects the sprite's own alpha channel/silhouette (unlike a plain translucent rectangle overlay, which would bleed past the button's actual visible pixels), and is genuinely capable of brightening past the source colors, which a multiplicative tint cannot do. **First use of `gpu_set_blendmode` in this codebase** -- flag if a different technique was actually intended.

**Timing.** `continuePulseTimer` accumulates in real seconds via `delta_time / 1000000` (same microseconds-to-seconds idiom `BuildingUpdateProduction`/`ProjectileScripts.gml`/`TitleMenu.Update()` already use), NOT frame-count-based, so the pulse speed doesn't drift with frame rate. `WARROOM_CONTINUE_PULSE_PERIOD = 2` (seconds) is a full sine cycle; a peak and the following valley are `PULSE_PERIOD / 2 = 1` second apart, matching "roughly peak and valley at 1 second intervals" as literally as a sine wave allows (the request describes a half-period, not a full period).

**"Always start at 0.1 when hovering."** `alpha(t) = MID - AMP * cos(phase)`, where `phase = (2*pi / PULSE_PERIOD) * t`. At `t = 0`, `cos(0) = 1`, so `alpha = MID - AMP = MIN` (0.1) -- the trough, by construction, not by clamping. `continuePulseTimer` resets to `0` the instant `hoveredContinue` transitions from `false` to `true` (tracked via `_wasHoveredContinue`), so every fresh hover restarts the wave at the trough exactly as requested, rather than continuing wherever a previous hover's phase left off. Moving the mouse off and back on resets it again; a continuous hover just keeps riding the same wave.

## Leader portrait -- static for now

`leaderSprite = sConneliusWarRoom` is a plain field assignment, not yet driven by any selection state -- per the request, this becomes swappable between Connelius and two other rulers once leader selection is built. Kept as a simple field (not a function/constant) specifically so a future `Update()` branch can reassign it without restructuring `Draw()`.

## Pause menu

`oWarRoomMenu` owns its own `SettingsOverlay` + `HubPauseMenu`, wired exactly like `oHubTownMenu`/`oPreRunMenu` (see `HubPauseMenuScripts.md`). 2026-08-13: now that this room has its own dialogue tree (see below), `oWarRoomMenu/Step_0.gml` gained the same Escape-suppression guard `oHubTownMenu` uses for the Beggar (`if (!warRoomMenu.dialogueOverlay.isOpen && keyboard_check_pressed(vk_escape))`), so Escape can't pop the pause menu on top of an open conversation.

## Connelius's tutorial dialogue tree (2026-08-13)

Auto-opens once, gated by `global.playerSaveData.hasSeenWarRoomIntro` (new field, `PlayerSaveDataScripts.gml`) -- same "genuinely first time ever, survives a restart" shape `hasSeenBeggarIntro` already uses, checked at the tail of `WarRoomMenu()`'s constructor exactly where `HubTownMenu()`'s tail checks `hasSeenBeggarIntro`. `hasSeenWarRoomIntro` is set (and saved) the instant `dialogueOverlay.isOpen` transitions `true` -> `false` -- tracked via a local `wasDialogueOverlayOpen` flag in `Update()`, since this struct has no `HubControl`-equivalent to lean on. This fires on ANY close, not just reaching the tree's natural end -- exiting early via the dialogue's own exit button also marks it seen, matching `HubControl`'s "any close counts" behavior for the Beggar. **2026-08-13 (second pass): node L now hands off to Booger's full A-M tree, not a stub that closes immediately** -- see "Booger's tutorial dialogue tree" below. That tree's own final exit ("[To the Wall]") does NOT go through this same-room close-tracking path at all; it leaves `rmWarRoom` outright, so it sets `hasSeenWarRoomIntro` explicitly instead -- see that section.

Tree shape (letters match the request verbatim):

```
A ("Hey! You! Servant boy!", [Continue]) -> B
B ("Fetch me more wine and my horse!", 3 responses)
  -> 1: C -> D -> E (monologue) -> back to B
  -> 2: F -> G -> back to B
  -> 3: H -> I -> J (monologue) -> K -> L ("BOOGER!!!", shaking) -> Booger's tree (see below)
```

Branches 1 and 2 are pure loops (always land back on B, no natural end -- the dialogue's own exit button is the only way out of that loop, same shape the Beggar's tree already uses). Branch 3 is the one-way "hired as advisor" arc and does NOT loop back -- it's the only path that reaches a real ending.

**Functions are NOT `static`**, same reason as `HubTownMenuScripts.gml`'s `_OpenBeggarX` family: they're passed around as bare callback values (`onSelect`) and invoked later from inside `DialogueOverlay.Update()`, a different struct entirely -- `static` methods called through a stored reference resolve `self` to the CALLER, not the struct they were declared on, and crash. See that file's header comment for the full explanation; same fix, same reason, applied here.

`_OnConneliusBSelect(_index, _text)` dispatches B's three responses to C/F/H -- the only node in this tree needing a dispatcher, since every other multi-option node's choices all lead to the SAME next node (C/D both -> their single next node directly; only the wording of the player's response differs, not the destination) and can pass that next-node function straight through as `_onSelect`.

**`"[[Continue]"` escaping**: every literal `[Continue]` option (nodes A, E, F, G, L) uses the same `[[` doubled-bracket escape the Beggar's tree established -- `[`/`]` are Scribble's own command-tag delimiters, and an unescaped `"[Continue]"` renders blank. See `DialogueOverlayScripts.md`'s "Gotcha" section.

**`[shake]` on node L is a REAL Scribble command tag, not escaped text** -- `"BOOGER!!!"` is deliberately wrapped as `"[shake]BOOGER!!![/shake]"` to realize the request's "(text shaking)" stage direction using Scribble's built-in shake effect (`__effects_map[? "shake"] = 2`, confirmed in the vendored `__scribble_system.gml`) rather than hand-rolling a custom shake animation. No parameters passed -- using the effect's defaults; tune if the shake amplitude/speed isn't strong enough once seen in-engine.

**Speaker color/name**: `c_yellow` name color throughout, matching the Beggar's tree -- no color was specified for Connelius, so the existing convention was reused rather than inventing a new one. Flag if Connelius (a king) should read differently from a Beggar.

**Typo corrected 2026-08-13 (second pass)**: node F's body text originally read "...I hate Booker and my Mother." (a "Booger"/"Booker" inconsistency, flagged in the first pass and left un-fixed pending confirmation). User confirmed "Booger" is correct -- text now reads "Ugh. You sound like Booger. Or my mother. I hate Booger and my Mother." throughout.

## Booger's tutorial dialogue tree (2026-08-13, second pass)

Node L's Continue now hands off to a full 13-node (A-M) Booger/Boog tree instead of the earlier placeholder stub. Tree shape (letters match the request verbatim):

```
A ("Yes my lord!!", [Continue]) -> B
B ("Servant, where is the King?...", 3 responses)
  -> 1: C ("...repercussions...") -> back to B
  -> 2: D ("Oh. Greaaaat.") -> back to B
  -> 3: E ("...I don't have to do this anymore?!") -> F ("Oh. Geaaaat.") -> G (name reveal, "Boog") -> H
H ("Talos has declared war...", 2 responses, both -> I)
I ("Were you kicked in the head...", 2 responses, both -> J)
J ("Oh my God. We are doomed.") -> K
K (signing line -- text input + "[Sign]") -> L, or back to K if the signature is empty
L ("Your name is {name}?...", Yes -> M, "let me change it" -> back to K)
M ("Ok {name}!... Let's get to the wall!", [To the Wall]) -> gameplay
```

Branch 1/2 (C, D) are pure loops back to B, same shape Connelius's B->C/F->back-to-B branches use. Branch 3 (E onward) is the one-way "urgent news" arc that eventually reaches the signing scene and gameplay.

**Name change at G ("Boog").** The request says to change the speaker's display name to "Boog" "after this dialogue" -- node G itself is still spoken under the "Booger" name (the reveal line), and every node from H onward uses `"Boog"` as `Open()`'s `_name` argument. `sBoogerPortrait`/`aBoogerSpeak` (portrait/sound) are unchanged across the rename -- only the displayed name string changes, the underlying character/assets don't.

**"Oh. Geaaaat." (node F) vs. "Oh. Greaaaat." (node D) -- NOT unified.** Two visually similar but distinctly-spelled lines, reproduced exactly as dictated. Flag if F was meant to match D's spelling.

**The signing line (node K)** uses `DialogueOverlay`'s new text-input support (`DialogueOverlayScripts.md`'s "Text input" section) -- `_OpenBoogerK()` passes `_textInputEnabled = true` and seeds it with `advisorName` (a new `WarRoomMenu` field, `""` until first signed), so re-opening K via L's "let me change it" preserves whatever was previously signed rather than clearing it. `_OnBoogerSign()` reads `dialogueOverlay.textInputValue`, and if it's empty/whitespace-only after `string_trim()`, silently RE-OPENS K instead of advancing to L -- **not explicitly specified**, added defensively so the game can't reach L's "Your name is ?" with a blank name. `advisorName` itself is only written on a non-empty signature.

**`{name}` substitution (L, M)** uses GML's `$"...{advisorName}..."` string-interpolation syntax (already used elsewhere in this codebase, e.g. `DialogueOverlayScripts.gml`'s debug-message calls) rather than a manual `string_replace`.

**"[To the Wall]" (node M) routes straight to `room_goto(rmTestGameplay)`, bypassing Pre-Run entirely.** The request says the option simply "Goes to gameplay" -- read as the signing scene functioning as starting the Talos tutorial campaign directly (the same destination `PreRunMenuScripts.gml`'s `_PlayTalos()` uses), rather than routing back through the Pre-Run campaign-select screen first. **This is an inference, flag if the intent was actually to land on Pre-Run instead** and let the player confirm the campaign choice there.

**Gotcha caught and handled: `hasSeenWarRoomIntro` needed an explicit write at the gameplay hand-off.** Every other exit from this tree (dialogue's own exit button, reaching a natural end that just calls `dialogueOverlay.Close()`) stays in `rmWarRoom`, so `Update()`'s generic `wasDialogueOverlayOpen` transition-tracker catches the close on a later frame and writes the flag. `_OnBoogerToWall()` instead calls `room_goto(rmTestGameplay)` WHILE `dialogueOverlay.isOpen` is still `true` -- the room change destroys this `WarRoomMenu` instance before any later `Update()` call could ever observe the `isOpen` transition, so the generic tracker silently never fires for this specific exit path. `_OnBoogerToWall()` therefore duplicates the same guarded write (`if (!hasSeenWarRoomIntro) { ...; SavePlayerSaveData(); }`) directly, before the `room_goto`. Worth double-checking in-engine that a first-time playthrough actually persists the flag correctly through this path.

**Speech sounds (2026-08-13, second pass).** `aConneliusSpeak`/`aBoogerSpeak` (`sounds/Dialogue/`) are now wired into every `Open()` call in this file via the new `_speakerSound` argument (`DialogueOverlayScripts.md`'s "Per-character speaker sound" section) -- Connelius's whole tree uses `aConneliusSpeak`, Booger/Boog's tree uses `aBoogerSpeak` throughout (the G-node name change doesn't affect which sound plays).

**Portrait/fade limitation carries over unchanged from the first pass**: Connelius still has no dialogue portrait sprite (`portrait = undefined` throughout his nodes), and node-to-node portrait swaps are still instant, not a cross-fade -- see `DialogueOverlayScripts.md`'s "Position & portrait" section. This no longer blocks anything content-wise (Booger's tree is real now, not a stub), but the underlying cross-fade capability still doesn't exist.

## Tutorial completion (2026-08-13, spans beyond this file)

Request: "tutorial will end after your first run has ended, either due to match ending, winning or losing, or from pause ending." This redefines "the tutorial" as a single flow spanning the Beggar's hub-town intro -> this War Room intro -> the player's first match, NOT ending at either dialogue individually.

- **`global.tutorialActive`** (declared in `HubControlScripts.gml`) is no longer cleared when the Beggar's or Connelius's own dialogue closes -- it now stays `true` across the whole flow, only clearing via `CompleteTutorial()` (`PlayerSaveDataScripts.gml`), called from `PauseMenuScripts.gml`'s `DoQuitOrEndMatch` (fires on BOTH "Quit to Desktop" and "End Match" -- see that file's .md for why both, not just End Match).
- **`global.playerSaveData.tutorialCompleted`** (new persisted field) is the permanent counterpart -- flips `true` the first time `CompleteTutorial()` runs and stays `true` forever after (idempotent, safe to call on every later run's end too). This is the flag `PreRunMenuScripts.gml`'s `_PlayTalos()` TODO comment has been waiting on ("once the tutorial's actual in-gameplay pop-ups exist, this entry should branch on its completion flag") -- it now exists and is ready to use, but the actual branch was NOT wired up in this pass since it wasn't requested this time around.
- **GAP, flagged prominently: no win/loss detection exists anywhere in this project yet.** Grepped the whole codebase for match-end/victory/defeat logic -- `oMatchControl` only tracks elapsed time and `global.matchSpeed`, nothing resolves a match's outcome. So `CompleteTutorial()` can only be wired to the one ending path that actually exists today (Pause Menu's Quit/End Match). Once real win/loss resolution is built, call `CompleteTutorial()` from wherever that resolution lands, the same way `DoQuitOrEndMatch` does.

## Known assumptions / scope limits (flag if wrong)

- Pre-Run's exit target changed to `rmWarRoom` (see Flow change above) -- flag if it should have stayed pointed at `rmHubTown`.
- `gpu_set_blendmode` is new to this codebase (see Continue button hover feedback above) -- flag if there's a project-wide reason to avoid it that isn't evident from the code alone.
- `[Continue]`-style option speed-through the typewriter: nothing gates response clicks behind the typewriter finishing (see `DialogueOverlayScripts.md`) -- a player CAN click a response before `speakerText` finishes typing out. Not requested either way; flag if responses should be disabled/hidden until typing completes.
- "Quit to Desktop" also completes the tutorial, not just "End Match" -- an inference, not literally stated (see Tutorial completion above).
- No win/loss detection exists yet, so that leg of "match ending, winning or losing" isn't wired to anything (see Tutorial completion above).
- **"[To the Wall]" skips Pre-Run entirely**, routing straight to `rmTestGameplay` -- an inference (see Booger's tutorial dialogue tree above), flag if it should land on Pre-Run's campaign-select screen instead.
- **Empty-signature guard on node K** (silently re-opens K instead of advancing) wasn't specified -- see Booger's tutorial dialogue tree above.
- Node F's "Booker"/"Booger" spelling inconsistency -- CORRECTED 2026-08-13 (second pass) per user confirmation, no longer an open flag.
- Node F's "Oh. Geaaaat." vs. node D's "Oh. Greaaaat." spelling difference reproduced verbatim, not unified -- flag if unintentional.

## API

- `WarRoomMenu()` -- the screen. `Update()`/`Draw()` called once per Step/Draw GUI by `oWarRoomMenu`. Owns a `dialogueOverlay` (`DialogueOverlayScripts.gml`) for Connelius/Booger's tutorial tree, and an `advisorName` field (player-typed name from Booger's signing line).
