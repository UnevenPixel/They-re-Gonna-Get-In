# HubControlScripts

2026-08-10 request: a dedicated place that decides what's currently available in the hub town and which dialogue tree opens for a given NPC, instead of that logic being embedded ad hoc in `HubTownMenu`. Introduced alongside the requirement that the Beggar's tutorial auto-runs without a click and can't be re-triggered by clicking while it's still running. Built to extend to future townsfolk without redesigning -- today only the Beggar has an entry in `IsOptionAvailable`/`GetDialogueOpener`, everything else falls through to "always available, no special opener."

## Ownership

One `HubControl` instance per `HubTownMenu`, held as a field (`hubControl`) and constructed with a reference back to its owning `HubTownMenu` -- same composition pattern `dialogueOverlay` uses, not a global singleton. It only reads `hubTownMenu.dialogueOverlay.isOpen` and calls `hubTownMenu`'s own `_OpenBeggarX` functions, so it needs that reference but doesn't duplicate any state.

## Tutorial gating

`tutorialActive` is the single flag standing in for "the tutorial (today: just the Beggar's conversation) is still in progress." `HubTownMenu`'s constructor calls `hubControl.StartBeggarTutorial()` instead of opening the dialogue directly when `!global.playerSaveData.hasSeenBeggarIntro` -- this sets `tutorialActive = true` before opening, so the Beggar option is already unavailable by the time the first Step runs.

`Update()` must run every frame regardless of whether `dialogueOverlay` is currently open (unlike `HubTownMenu.Update()`, which returns early while a dialogue is open) -- it's the only thing watching for the tutorial's dialogue to close. It compares `tutorialActive` against `dialogueOverlay.isOpen` going from true to false; on that transition it flips `tutorialActive` off and, only then, marks `global.playerSaveData.hasSeenBeggarIntro = true` and saves.

2026-08-10: `dialogueOverlay.isOpen` now stays `true` through the overlay's fade-out animation (see `DialogueOverlayScripts.md`'s Fade in/out section) and only goes `false` once the box has actually finished disappearing -- so this check now naturally waits for the fade to complete before marking the tutorial done, instead of firing the instant the exit button is clicked. No change needed here to get that; it was already watching the right field.

**This changed WHEN `hasSeenBeggarIntro` gets set** -- previously (`HubTownMenuScripts.gml`, before this pass) it was set true immediately before the dialogue even opened; now it's set on the dialogue actually closing. Closer to what "seen" should mean, and makes the Beggar-disabled-during-tutorial gate meaningful instead of vacuous, but flag if the old fire-immediately timing was intentional for some reason not evident here.

Today the Beggar's dialogue tree is a single node that loops on itself (every `[Continue]` leads back to `_OpenBeggarMain`), so it only ever "closes" via the exit button, and `tutorialActive` only ever toggles once, at that point. `Update()` doesn't assume that shape though -- it just watches `dialogueOverlay.isOpen`, so a future multi-step tutorial that closes and reopens the overlay between steps would need its own way to keep `tutorialActive` true across that gap (this file doesn't handle that yet).

## Global mirror (`global.tutorialActive`) -- NO LONGER a strict mirror (2026-08-13)

2026-08-13 (first pass): the Settings menu's "Restart Tutorial" button needs to hide while the tutorial is currently active, but `HubControl` (and its `tutorialActive` field) only exists per-`HubTownMenu`, which only exists while physically inside `rmHubTown` -- there's no singleton reference to it, and `SettingsOverlay` can be opened from other rooms that have no way to reach a `HubTownMenu` instance even if one happens to exist. Rather than build a singleton-reference plumbing path, `global.tutorialActive` was introduced as a direct mirror of `tutorialActive` -- set alongside it in `StartBeggarTutorial()`, cleared alongside it in `Update()`. Declared once at the top of this script file (same "runs once at game start" idiom `global.__dialogueOverlayNextId = 0` uses in `DialogueOverlayScripts.gml`), defaulting to `false`.

**2026-08-13 (later same day): decoupled.** The request adding the War Room's dialogue tree redefined "the tutorial" as a single flow spanning the Beggar's hub-town intro -> the War Room's Connelius/Booger intro -> the player's first match, not ending until that first run itself ends (see `WarRoomMenuScripts.md`'s "Tutorial completion" section). `global.tutorialActive` now represents THAT broader flow -- still set `true` in `StartBeggarTutorial()`, but **no longer cleared** when the Beggar's own dialogue closes; `Update()` below only clears the LOCAL `tutorialActive` field now (Beggar-conversation-specific, still gates `IsOptionAvailable("beggar")` exactly as before). `global.tutorialActive` instead clears via `CompleteTutorial()` (`PlayerSaveDataScripts.gml`), called once the player's run actually ends (`PauseMenuScripts.gml`'s `DoQuitOrEndMatch`, and eventually whatever resolves win/loss once that system exists).

`SettingsOverlay._ShouldShowRestartTutorial()`'s `room == rmTitleMenu && !global.tutorialActive` check is UNCHANGED and still correct -- `global.tutorialActive` can never be `true` while `room == rmTitleMenu` regardless of how far its lifetime now extends (the tutorial flow never visits the title screen), so that specific consumer's behavior doesn't change. But the REASONING behind the first pass's "close to redundant with a plain room check" note no longer holds -- it argued `tutorialActive` could only ever be `true` inside `rmHubTown`; that's no longer true, it can now also be `true` in `rmWarRoom` and `rmTestGameplay`. The conclusion (redundant for Restart Tutorial specifically) survives by coincidence, not by the original argument.

## Availability / dialogue resolution

`IsOptionAvailable(_action)` gates both the hover-highlight loop and the click handler in `HubTownMenu` -- an unavailable option neither highlights on hover nor dims its siblings, not just "doesn't respond to clicks." `GetDialogueOpener(_action)` resolves which function actually opens that NPC's tree; `HubTownMenu._HandleOptionAction` calls through this instead of hardcoding `_OpenBeggarMain()`, so a future NPC (or a Beggar whose tree changes based on some other state) only needs a new `case` in these two functions, not a change to `HubTownMenu`'s click-handling shape.

## API

- `HubControl(_hubTownMenu)` constructor.
- `StartBeggarTutorial()`, `Update()`.
- `IsOptionAvailable(_action)`, `GetDialogueOpener(_action)`.
