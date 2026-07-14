# Patch Notes

## v0.0.4.8 — 2026-07-13 (uncommitted — working tree only, not yet committed)

New title/main menu screen (rmTitleMenu, oTitleMenu, TitleMenuScripts.gml), wired in after the disclaimer. Also fixes a pre-existing, unrelated `Blank Pixel Game.yyp` corruption discovered while registering the new assets.

### Added

- **`TitleMenuScripts.gml`** (new file, `TitleMenu()` struct owned by `oTitleMenu` — same "plain struct + thin object wrapper" split as `PauseMenu`/`FateEngineOverlay`/`BlueprintController`) — full title-screen sequence: `fadeIn` (background fades in from black) → `titleDrop` (`sTitle` falls from off-screen-top to screen-center on both axes via a standard easeOutBounce curve, landing with a visible bounce) → `prompt` ("Press Any Key" typewriters in below the title via Scribble's `scribble_typist`, `[wave]` tag, white text with a manually 8-way-offset black outline — see below) → `transition` (on any key/gamepad-face/click: prompt slides off the bottom, title eases to the docked top-right corner at `TITLE_MENU_PADDING`, all four buttons slide in from off-screen-right staggered per row — all three run concurrently) → `menu` (buttons hover-shift left by `TITLE_MENU_BUTTON_HOVER_SHIFT`, smoothly both ways; click fires that button's action).
- **Menu buttons, in request order** — Play (`room_goto(rmTestGameplay)`), Settings (explicit no-op stub), Credits (explicit no-op stub, "we will add this shortly" per the request), Exit (opens a Yes/No confirm sub-panel — mirrors `PauseMenu`'s `RequestConfirm`/`CancelConfirm` shape and reuses the same shared `DropDownMenuScripts.gml` row/title helpers, but isn't the literal same struct instance, since `PauseMenu`'s instance lives on `oUnitControl` in the gameplay room and doesn't exist on the title screen — "Yes" calls `game_end()`, "No"/Escape/a miss-click cancels, same rule `PauseMenu`'s own confirm sub-menu already uses).
- **`oTitleMenu`** (new object, `Menus/TitleScreen` folder) — Create/Step/Draw GUI wrapper (`titleMenu = new TitleMenu();` / `.Update()` / `.Draw()`).
- **`rmTitleMenu`** (new room, `Menus/TitleScreen` folder) — 1920x1080, `enableViews:false`, matching `rmDisclaimer`/`rmOpeningCredits`/`rmInit` exactly (same "GUI-space-drawn, no camera view" shape). Inserted into `RoomOrderNodes` between `rmDisclaimer` and `rmTestGameplay`.

### Changed

- **`oAlphaDisclaimer/Step_0.gml`** — "press any key to continue" now goes to `rmTitleMenu` instead of straight to `rmTestGameplay`, per explicit request ("Wire in the disclaimer screen to go to this menu instead"). `oOpeningCredits`'s own target (`rmDisclaimer`) was left untouched — not part of this request, and the disclaimer still needs to show before the title menu.

### Fixed

- **`Blank Pixel Game.yyp` was found silently corrupted** (truncated mid-string partway through the sprites section, invalid JSON — same recurring "IDE reopened the project while a save was in flight" cause documented several times earlier in this file, e.g. the 2026-07-05 entries) while trying to register the new title-screen assets — unrelated to anything from this session, but it meant the project would not have opened in GameMaker at all regardless of this feature. Reconstructed the full `resources` array from disk ground truth (scanned every real `sprites/objects/scripts/rooms/fonts/shaders/extensions/*/*.yy` self-named resource file, 362 total, sorted case-insensitively to match the project's existing convention) rather than hand-patching the truncated file or blindly reverting to the last git commit (which predates several sessions' worth of still-uncommitted work, e.g. `PauseMenuScripts`, the four title-screen option sprites, and `sTitle`/`sTitleBackground` itself — reverting would have silently dropped all of it). The file's header (`Folders`/`configs`/etc., through the `"resources":[` line) and its trailing `RoomOrderNodes`/`TextureGroups` structure were preserved/reconstructed from the last known-good commit, with `rmTitleMenu` inserted into `RoomOrderNodes`. Verified: resource count (362), zero brace/bracket imbalance, and spot-checked that every asset referenced by this pass's own new code (and everything else already known to be in use, e.g. `oWheatField`, `sWheatField`, `DropDownMenuScripts`) is present exactly once.

### Flagged

- **`_OpenSettings()`/`_OpenCredits()` are explicit empty stubs** for this pass, per your own answer to the earlier clarifying question ("stub Settings like Credits for now") — clicking either currently does nothing observable. No shared `SettingsOverlay` object was built this pass.
- **Manual 8-offset outline instead of Scribble's built-in `.outline()`/`.sdf_outline()`** — that feature exists in this project's bundled Scribble build (`__scribble_class_element.gml`) but its own comments tie it to SDF-imported fonts, and `fntResource` is a plain bitmap font with no SDF configuration. Rather than risk an outline that silently doesn't render (or renders incorrectly) on a non-SDF font, went with the standard font-agnostic "draw the text 8 times at a 1px offset in black, then once in white on top" trick instead. Confirmed this is safe to call multiple times per frame against one shared `scribble_typist` — its reveal state is keyed off `current_time` (frame-constant), not a per-call counter, so it doesn't type any faster than a single draw would.
- **Button entrance stagger (`TITLE_MENU_BUTTON_STAGGER`, 0.08s/row) and all animation durations are first-pass judgment calls**, not specified by the request — easy to retune, all are named macros at the top of `TitleMenuScripts.gml`.
- **Mouse click added to the "press any key" trigger**, alongside the keyboard/gamepad combo `oAlphaDisclaimer` already uses — not explicitly requested, but conventional for a title screen.
- **Title's move to the docked corner and the button slide-ins are eased/tweened animations**, not an instant snap — not specified either way by the request; flag if an instant snap was actually wanted for the docking step specifically.
- No `TitleMenuScripts.md` Notion doc exists yet — same longstanding gap noted in prior passes for other libraries.

### Build

- Windows export version bumped `0.0.4.7` → `0.0.4.8` — 4th-digit bump, routine convention.

## v0.0.4.7 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Bugfix: melee/ranged units attacking a building could end up standing inside its footprint (reported as "soldiers in the center of the wheat field"), confusing nearby allies' steering.

### Fixed

- **`NearestBuildingEdgePoint(_building, _fromPos)`** (`UnitStateAttackMelee.gml`, shared by `Attack_Step` and `AttackRanged_Step`) — previously computed the "nearest edge point" with a plain `clamp()` of `_fromPos` to the building's box, which only returns a true edge point when `_fromPos` starts OUTSIDE the box. If a unit was already standing inside (reachable because buildings were dropped from units' hard collision list on 2026-07-06 — `move_and_collide` only checks `oEnvironmentSolid` now, and `Steering_AvoidObstacles` is a soft lookahead force a unit can clip past, especially with several allies converging on a small building and pushing each other via separation), `clamp()` was a no-op and handed back the unit's own current position as the "edge" — `_distToEdge` read as ~0 and the unit just locked in place wherever it was, including dead center. Fixed by detecting the inside case explicitly and pushing out to whichever side has the shallowest penetration depth, matching the same "always a real point on the perimeter, never the interior" guarantee `CastleFrontEdgePoint` (`CastleScripts.gml`) already has for castle sieging. Self-heals units already stuck from before this fix — the function is called fresh every step, so the very next frame steers them back out to the corrected edge point (nothing physically stops that walk-out, same reason they could get in).

### Build

- Windows export version bumped `0.0.4.6` → `0.0.4.7` — 4th-digit bump, routine convention.

## v0.0.4.6 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Order menu now opens instantly the moment a selection is made (instead of waiting for a right-click) and gets a per-row mnemonic hotkey. Melee-attack-vs-building edge targeting was checked against the request and confirmed already implemented from an earlier pass — no code change needed there.

### Added

- **`OrderMenu.OpenCentered(_orders)`** (`OrderMenu.gml`) — a second entry point alongside the existing click-anchored `Open()`, for auto-open call sites with no triggering click to anchor away from. Uses `PositionDropDownMenuCentered` (`DropDownMenuScripts.gml`, added last pass for `PauseMenu`).
- **Mnemonic hotkeys** (`OrderMenu.gml`) — `AssignMnemonics()` picks one letter per currently-shown order (the label's own first letter, or the next unclaimed letter in that label if an earlier row in the same menu already claimed it — e.g. "Siege Castle" and "Station" both start with S, so one of them falls back to its second letter), recomputed every time the menu (re)opens since which orders show up depends on the current selection. `Update()` now checks each row's assigned letter (`keyboard_check_pressed`) before mouse handling — pressing it acts exactly like clicking that row, same return-value contract. `Draw()` recolors that one letter `c_white` (against the rest of the label's `HOVER_CARD_TEXT_COLOR`) rather than underlining it — checked this project's bundled Scribble build (`__scribble_gen_2_parser.gml`'s `_command_tag_lookup_accelerator_map`) and confirmed there is no underline tag (only font/colour/alpha/scale/alignment/`b`/`i`/`bi`/etc.), so the request's explicit fallback applies.
- **Instant auto-open on selection** (`oUnitControl/Step_0.gml`) — the order menu now opens the moment the selection becomes non-empty, from every path that populates `selectionController.selected`: `EndDrag()` (covers both a drag-box and a single-unit click) opens click-anchored via `orderMenu.Open()` at the release point, same anchoring rule the manual right-click path already used; `SelectAllOfType()` (Army Limit Widget row click) and `SelectionSummaryMenu`'s row-narrow click both open centered via `orderMenu.OpenCentered()`, since neither has a playfield click position to anchor away from. All three no-op via `Open()`/`OpenCentered()`'s own empty-orders guard if the resulting selection has no common order (or is empty). The existing manual right-click-to-open path is unchanged and still works (e.g. to bring the menu back after dismissing it without changing selection).

### Investigated, no change made

- **Melee-attack-vs-building edge targeting** (the request: "let them sit on the outside edge of that building, not the center of it") — already implemented (`NearestBuildingEdgePoint`, `UnitCombatHelpers.gml`; consumed by `Attack_Step`'s APPROACH/RECOVER phases, `UnitStateAttackMelee.gml`) from an earlier pass, predating this session's visible history. Sieging the castle has its own equivalent (`CastleFrontEdgePoint`, `UnitStateSiege.gml`). No `PATCH_NOTES.md` entry for it was found, so flagging this explicitly rather than silently re-doing (or silently skipping) it — if something about the current edge-targeting behavior isn't matching what's actually observed in-game, let me know specifics (which unit/building/state) and I'll dig further.

### Flagged

- **Auto-open repositions the menu on every selection change**, including a shift-click that only adds one unit to an already-selected group — if the player is mid-multi-select in different screen areas, the menu will jump to re-anchor at each new click point rather than staying put. Matches the request's literal "open it with the same anchoring rules it normally uses" read literally per-click, but worth double-checking it doesn't feel twitchy in practice.
- **Mnemonic collision resolution picks the next unclaimed letter in reading order**, not necessarily the most memorable one (e.g. "Station"'s "t" rather than something more distinctive) — simplest rule that satisfies "the first letter if possible, unless it is used by another order," but a hand-picked mapping might read better if this comes up in practice (today only "Siege Castle"/"Station" can collide, since "Guard"/"Defend Building"/"Attack Building" all have unique first letters).
- No `OrderMenu.md`/`DropDownMenuScripts.md` Notion doc exists yet — flagged again, still not closed (same longstanding gap noted in prior passes for other libraries).

### Build

- Windows export version bumped `0.0.4.5` → `0.0.4.6` — 4th-digit bump, routine convention.

## v0.0.4.5 — 2026-07-13 (uncommitted — working tree only, not yet committed)

The pause menu — Escape dims the screen, freezes the match, and centers a Resume/Restart/Settings/Quit to Desktop/End Match list, with a Yes/No confirm step on the two destructive options.

### Added

- **`PauseMenuScripts.gml`** (new file) — `PauseMenu` struct, built on the shared drop-down menu sprite set (`DropDownMenuScripts.gml`) same as `OrderMenu`/`CastleGarrisonMenu`/`ArmyLimitMenu`, but centered on screen rather than click-anchored (new `PositionDropDownMenuCentered(_rowCount)` helper, `DropDownMenuScripts.gml`, since Escape has no click position to anchor away from). `Open(...)` takes the same 5 cross-controller dependencies `FateEngineOverlay.Open()` does, for the same reason: saves/zeroes `global.matchSpeed`, clears selection, closes every other dropdown, cancels a blueprint drag. Main list: Resume / Restart / Settings / Quit to Desktop / End Match, in that order. Quit to Desktop and End Match both open a Yes/No confirm sub-menu (`RequestConfirm`/`CancelConfirm`) before doing anything — "No", Escape, or a click that misses "Yes" all cancel back to the main list. Restart calls `room_restart()`; Quit/End Match's "Yes" calls `game_end()` for both, per explicit request. Settings is an explicit stub (`OpenSettings()`, intentionally empty) — clicking that row does nothing yet.
- **`PositionDropDownMenuCentered(_rowCount)`** (`DropDownMenuScripts.gml`) — centers a drop-down menu on screen, parallel to the existing `PositionDropDownMenuFromClick`.

### Changed

- **`oUnitControl/Create_0.gml`** — instantiates `pauseMenu = new PauseMenu()`.
- **`oUnitControl/Step_0.gml`** — Escape opens the pause menu (checked right after the Fate Engine overlay's own early-exit, before the XP-bar click check) — same `isOpen` early-exit pattern as the Fate Engine overlay, which is also what makes the two overlays mutually exclusive: the Fate Engine overlay's own check runs first and exits if it's open (blocking Escape that frame), and the pause menu's early-exit sits before the XP-bar check (blocking the Fate Engine overlay from opening while paused).
- **`oUnitControl/Draw_64.gml`** — `pauseMenu.Draw()` is the LAST call in the event, on top of the UI bar and every other HUD element — the opposite draw-order choice from the Fate Engine overlay (which stays behind the bar). See Flagged.

### Flagged

- **Draw-order deviation from the Fate Engine overlay**: the request said pause should do "the same black overlay" as the Fate Engine overlay, which draws its dim FIRST so the persistent UI bar stays visible on top of it. Pausing reads as a different, more total kind of interruption (leaving the play state entirely, not just consulting a HUD widget), so the pause menu's dim/panel are drawn LAST instead, covering the UI bar too. Flag if the Fate-Engine-style "stay behind the bar" placement was actually wanted here.
- **Open trigger is Escape** — not specified in the request (no button/icon was described this time); Escape is the universal pause convention and nothing else in the project currently uses `vk_escape` (confirmed via grep), so there was no conflict to resolve.
- **Click-away on the main list does nothing** (must pick an option or use Escape/Resume) — a deliberate choice so a stray click near the menu's edge can't silently resume the match. Click-away on the confirm sub-menu, by contrast, cancels back to the main list (treated as an implicit "No") — different behavior between the two lists, worth double-checking it feels right.
- **`DoQuitOrEndMatch(_action)` takes `_action` but ignores it today** — both branches call `game_end()`. Kept as one function with the parameter in place so a future pass that actually diverges "quit" vs. "end match" behavior only needs to change this one function.
- **Settings row is a true no-op** — clicking it doesn't close the menu or show any feedback, per explicit "leave it as a stub" instruction; flagging so it isn't mistaken for a bug during a playtest.

### Build

- Windows export version bumped `0.0.4.4` → `0.0.4.5` — 4th-digit bump, routine convention.

## v0.0.4.4 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Two independent additions: paginated Blueprint UI (prev/next arrows + scroll-wheel) now that inventories can exceed one page, and destroying an enemy building grants the destroyer a blueprint of that building type.

### Added

- **Blueprint panel pagination** (`BlueprintScripts.gml`) — `GetPageCount()`/`ClampPage()`/`NextPage()`/`PrevPage()`/`GetPageArrowRects()`/`UpdatePaging()`/`DrawPageArrows()`/`DrawOnePageArrow()`. Prev/next arrows (plain triangles — no arrow/button sprite asset exists anywhere in the project yet) flank the grid, greyed out when that direction isn't valid. `UpdatePaging()` handles both an arrow click and scroll-wheel paging (up = previous, down = next) while the mouse sits anywhere over the panel or either arrow (`IsMouseOverPanel()` extended to cover the arrows too). A small "page N/M" counter is drawn centered under the grid, only once there's more than one page. `ClampPage()` is called from `EndDrag()` right after a placement AND every `UpdatePaging()` tick, so placing the last blueprint on the current (necessarily last) page snaps `page` back to an earlier one immediately — pages are always contiguous slices of the flat inventory array (`RemoveBlueprintOne` always shifts everything down), so a plain clamp is sufficient; no special-casing needed.
- **Blueprint reward on building kill** (`UnitCombatHelpers.gml`'s `ApplyDamage`) — in the building-destroyed branch, the killer's team now receives one blueprint (`AddBlueprint`) of the destroyed building's own type, cross-team only (`_source.team != _target.team` — no reward for self-destruction, e.g. a Bomb Goblin detonating near your own building) and only if the building type is actually registered (`GetBuildingDefinition != undefined` — excludes `oPlayerCastle`/`oEnemyCastle`, which aren't in `global.__buildingDefRegistry` and have no placeable blueprint to hand out). "Prevents lockouts where neither side can get blueprints."

### Changed

- **`oUnitControl/Step_0.gml`** — `blueprintController.UpdatePaging()` now runs early (same "must run before this frame's open-click handling" tier as the other menus' `.Update()` calls), and its return value gates the big left-click block the same way `castleGarrisonMenu.consumedClick`/etc. already do, so an arrow click doesn't also fall through to blueprint-drag/selection-drag logic.

### Flagged

- **Page-arrow visuals are plain triangles**, not a sprite — no arrow/button asset exists anywhere in the project yet (confirmed via grep), same reasoning as the Fate Engine overlay's temporary buttons last pass.
- **Scroll direction convention (up = previous page, down = next page)** is a judgment call, not specified — flag if the opposite reads better.
- **AI blueprint-on-kill**: `AI_TryPlaceBlueprints`/combat AI code is untouched — the AI benefits from this the same way the player does (it routes through the same `ApplyDamage`), no separate AI-specific wiring was needed or added.

### Build

- Windows export version bumped `0.0.4.3` → `0.0.4.4` — 4th-digit bump, routine convention.

## v0.0.4.3 — 2026-07-13 (uncommitted — working tree only, not yet committed)

The Fate Engine drums now roll a real reward table instead of a display-only placeholder, run on their own clock independent of match speed, and `oFateEngineDrumTest` (the old test harness, fully superseded by last pass's overlay) is deleted.

### Added

- **`FateEngineRollReward()`** (`FateEngineDrumScripts.gml`) — replaces `FateDrumRandomPlaceholderItem`. Coin-flips (`FATE_ENGINE_REWARD_BLUEPRINT_CHANCE`, 0.5) between a blueprint (uniform over every currently-registered building type, `global.__buildingDefRegistry`) and a resource bundle (uniform over `global.fateEngineRewardResourceTypes` — the 5 CURRENTLY ACTIVE base resources: wood/wheat/water/iron/gold — amount uniform between `FATE_ENGINE_REWARD_RESOURCE_MIN`/`MAX`, 20-60). Deliberately excludes meat/bones/coal/weapons/coins from `global.resourceIconOrder` — confirmed via grep that nothing produces or spends those yet, so rewarding them would be inert.
- **`FateEngineItem`'s `rewardType`/`rewardData` fields** (`FateEngineDrumScripts.gml`) — the constructor was already deliberately generic for this; now actually carries `"resource"` (`{ resourceName, amount }`) or `"blueprint"` (`{ buildingType }`) so a landed spin can be applied for real.
- **`FateEngineOverlay.Cashout()` now grants real rewards** (`FateEngineOverlayScripts.gml`) — no longer a stub. Applies each banked `pendingRewards` entry: `resource` adds `rewardData.amount` to `global.resources[TEAM.PLAYER][rewardData.resourceName]`; `blueprint` calls `AddBlueprint(TEAM.PLAYER, rewardData.buildingType, 1)`.

### Changed

- **`FateDrum.Step()`** (`FateEngineDrumScripts.gml`) — no longer scales spin/decel/landing by `global.matchSpeed`; every rate is now a flat per-step value. The drums are a UI mechanic independent of the battlefield's speed control — and since `FateEngineOverlay.Open()` forces `global.matchSpeed` to 0 anyway, leaving them coupled would have frozen them solid the instant the overlay opened.
- **`FateEngineOverlay.Update()`** (`FateEngineOverlayScripts.gml`) — removed the temporary `global.matchSpeed = 1 ... = 0` flip around the drums' `Step()` calls from last pass; no longer needed now that the drums don't read it at all.
- **`FateEngineOverlay.Open()`/`Leave()`** now set/clear `global.fateEngineOverlayActive` — this was pre-existing suppression infrastructure in `PlotHoverScripts.gml`/`BuildingHoverScripts.gml` (their own hover-suppression checks already OR it in) explicitly built ahead of time for "the real overlay" to flip later, and last pass's overlay never did. `Step_0.gml`'s `isOpen` early-exit guard already made this behaviorally redundant (those controllers' `Step()` never runs while the overlay is open), but leaving a pre-wired hook permanently false was an inconsistency worth closing while touching this area.

### Removed

- **`oFateEngineDrumTest`** (object + `.yyp` registration) — the old visual-only test harness, deleted per explicit request. Confirmed via grep it was never placed in any room, so nothing else referenced it. Stale comments in `PlotHoverScripts.gml`/`XpBarScripts.gml`/`FateEngineOverlayScripts.gml`'s own header that described it as "not yet built"/a live reference point were updated to stop pointing at a deleted object.

### Flagged

- **`FATE_ENGINE_REWARD_BLUEPRINT_CHANCE`/`_RESOURCE_MIN`/`_RESOURCE_MAX` are a first-pass placeholder split**, not a tuned design — no corruption-scaling or event-type rewards exist yet either (per `FateEngineDrumScripts.gml`'s own longstanding note).
- **Only 5 of the 10 base resources are reward-eligible** (wood/wheat/water/iron/gold) — a judgment call reading "current resource types" as "resources actually in play," not the full `resourceIconOrder` strip. Revisit once meat/bones/coal/weapons/coins are wired to any real building/cost.
- No `FateEngineDrumScripts.md`/`FateEngineOverlayScripts.md` Notion doc exists yet — flagged, still not closed.

### Build

- Windows export version bumped `0.0.4.2` → `0.0.4.3` — 4th-digit bump, routine convention.

## v0.0.4.2 — 2026-07-13 (uncommitted — working tree only, not yet committed)

The real Fate Engine session overlay: clicking the XP bar now freezes the match, dims the screen, and opens the drum machine with temporary Leave/Spin/Cashout buttons. Replaces `oFateEngineDrumTest` as the "later task" that object's own header comment always said this would be.

### Added

- **`FateEngineOverlayScripts.gml`** (new file) — `FateEngineOverlay` struct: `Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)` saves and zeroes `global.matchSpeed`, clears selection (`SelectionController.Deselect()`, new — see below), closes every dropdown menu, and cancels an in-progress blueprint drag. `Leave()` restores `global.matchSpeed` and closes the overlay — no-ops while a session is active (see Flagged). `Spin()` is a bare function call per explicit request ("I will add a lever later... make the 'spin' a simple function call"): spends one `TEAM.PLAYER` Fate Token to start a session if none is active (no-op if none held), then spins all 3 drums and starts a fixed-length decel timer (`FATE_ENGINE_SPIN_DURATION_STEPS`) before calling `Stop()` on each. `Cashout()` ends the session and clears `pendingRewards` — a STUB, see Flagged. `Update()`/`Draw()` are called from `oUnitControl`'s Step/Draw GUI (see below).
- **`SelectionController.Deselect()`** (`UnitSelection.gml`) — clears `selected` and cancels targeting if active. Didn't exist before; the only prior way to clear selection was two inline `selected = []` assignments inside `IssueOrder`/`UpdateTargeting`, neither reachable from an external caller wanting a clean-slate reset.
- **`XpBarWidgetHitRect()`** (`XpBarScripts.gml`) — GUI-space hit-rect for `sXpBar`, derived from `XP_BAR_ORIGIN_X/Y`/`XP_BAR_SCALE`/the sprite's own xoffset/yoffset, same "derive, don't hardcode" idiom as `ArmyLimitWidgetIconRect`. Read by `oUnitControl/Step_0.gml`'s new click-to-open check.
- **`FateEngineButtonRects()`** (`FateEngineOverlayScripts.gml`) — GUI-space rects for the 3 temporary buttons, centered as a row along the top of the screen (`FATE_ENGINE_BUTTON_*` macros).

### Changed

- **`oUnitControl/Create_0.gml`** — instantiates `fateEngineOverlay = new FateEngineOverlay()`.
- **`oUnitControl/Step_0.gml`** — new block at the very top, before everything else: if `fateEngineOverlay.isOpen`, calls `fateEngineOverlay.Update()` and `exit`s — every other Step system (selection, drag, menus, camera pan, all hover controllers) is skipped entirely while the overlay is open, satisfying "hovering over anything not on the UI bar will not display hover data." Just below that, a left-click landing on `XpBarWidgetHitRect()` calls `fateEngineOverlay.Open(...)` and `exit`s, ahead of the targeting/dragging/menu-click logic below (safe because `Open()` already resets all of that itself).
- **`oUnitControl/Draw_64.gml`** — `fateEngineOverlay.Draw()` is now the FIRST draw call, before `sRulerBar`/`sMainUIBarBottom`/`sUISpellsCloth` — its 0.75-alpha black dim rectangle therefore sits behind the persistent UI bar (drawn immediately after) rather than covering it, satisfying "everything behind the ui bar will be dimmed."

### Flagged

- **Fate Token spend timing (assumption)**: read as "one token spends the session, further spins within it are free" — `Spin()` only checks/decrements `fateTokens` while `!isSessionActive`. If every individual spin should cost a token, `Spin()`'s gate needs to move.
- **`Cashout()` is a stub.** The real weighted reward table still doesn't exist (`FateEngineDrumScripts.gml`'s own header confirms this), and `FateEngineItem` only carries `{sprite, subimg, label}` — nothing structured enough to convert into a real resource/blueprint grant. `Cashout()` currently just ends the session and drops `pendingRewards` on the floor.
- **`global.matchSpeed` hack in `Update()`**: `FateDrum.Step()` scales all of its own animation by `global.matchSpeed` by design, but `Open()` forces that to 0 to freeze the match — left alone, the drums would never spin while the overlay that pauses the match is open. `Update()` temporarily sets it to 1 around the drums' `Step()` calls only, then restores 0 immediately after. Safe today (nothing else runs mid-frame since `Step_0.gml`'s early-exit guard IS the freeze), but worth knowing about if match-speed-dependent logic is ever added elsewhere in this same window.
- **"Leave" gating (assumption)**: read the request's "only able to be pressed if a session is not active with a fate token" as "disabled for the whole time a session is active" (must `Cashout` first). Flag if that's not the intended reading.
- **Buttons are plain rectangles + text**, per the request's explicit "temporary" framing — no generic button sprite/pattern exists yet elsewhere in the project.
- **`oFateEngineDrumTest` was left untouched** — not explicitly asked to remove it, but it's now fully superseded by this overlay; candidate for deletion once this is confirmed working in-editor.
- **Spin deceleration duration (`FATE_ENGINE_SPIN_DURATION_STEPS`, 90) is an arbitrary placeholder** — there's no lever yet to tie real timing to.
- No `FateEngineOverlayScripts.md`/updated `FateEngineDrumScripts.md` Notion doc exists yet — flagged, still not closed.

### Build

- Windows export version bumped `0.0.4.1` → `0.0.4.2` — 4th-digit bump, routine convention.

## v0.0.4.1 — 2026-07-13 (uncommitted — working tree only, not yet committed)

First pass at the post-playtesting AI checklist, worked top to bottom: (1) Age I proactively defends production buildings only, (2) the AI gets random blueprints instead of Fate Tokens (which it has no way to spend), (3) a "defending" AI with zero live units now un-garrisons + trains reinforcements, backed by a standing gold reserve, and (4) a capped-out AI now attacks ordinary enemy buildings with its surplus once it can afford to replace losses, instead of just waiting on the (unchanged) siege threshold.

### Added

- **`AI_CanReplaceDeployedUnits(_team)` / `AI_TryAttackSurplusAtCap(_brain, _surplus)`** (`AIControl.gml`) — "using the AI's deployed units when unit cap is reached... after the AI determines it can either replace those units with resources and training, or once it can train other units in their place." `AI_CanReplaceDeployedUnits` is true if EITHER at least one owned training building can currently afford its own `trainCost` ("resources and training" ready) OR the team's owned training buildings collectively train 2+ distinct unit types ("train other units in their place"). Deliberately does NOT check `TrainingTypeLimit`/`global.armyLimit` — those caps are exactly what sending units off to attack is about to relieve, so gating on them being already-clear would be circular. `AI_TryAttackSurplusAtCap` is called from `AI_BuildUp_Step` between `AI_TryProbeAttack` and the existing siege check: once `AI_TeamAtArmyLimit` AND `AI_CanReplaceDeployedUnits`, sends the entire remaining surplus to attack a random ordinary enemy `oBuildingParent` (never the castle) via the existing `"attack"` order. Per explicit clarification, this does NOT change `AI_SiegePowerThreshold` or its existing at-cap behavior — if the enemy has no non-castle buildings left, `_surplus` passes through untouched and the unchanged siege check handles it exactly as before.
- **`AI_GOLD_RESERVE_UNIT_COUNT` / `AI_CheapestStationCost()` / `AI_GoldReserveAmount(_team)` / `AI_HideGoldReserve(_team)` / `AI_RestoreGoldReserve(_team, _hiddenAmount)`** (`AIControl.gml`) — "make sure the AI is keeping a reserve of gold for this reason." The reserve is sized to cover redeploying `AI_GOLD_RESERVE_UNIT_COUNT` (2) stationed units at the cheapest registered `stationCost`. `AI_BuildUp_Step` now hides that amount from `global.resources[team].gold` before calling `AI_TryPlaceBlueprints`/`AI_TryTrainComposition`, and restores it immediately after — so ordinary economy spending can only ever touch the surplus above the floor. Deliberately NOT applied around `AI_TryReinforceDefense`'s own spending (below) — the whole point of the reserve is to have money on hand for exactly that emergency.
- **`AI_TryReinforceDefense(_team)` / `AI_FirstStationedType(_team)`** (`AIControl.gml`) — "when the AI is 'defending threatened buildings', check if it has any deployed units. If not, have it either train more or un-garrison units from the castle to defend with." Called from `AI_Defending_Step` the instant the team has zero live units of any kind: un-garrisons every stationed unit it can afford (one `DeployStationedUnit` call at a time, any type each pass, bounded by the new `AI_REINFORCE_MAX_DEPLOYS` safety cap) AND queues training via `AI_TryTrainComposition` in the same tick — neither gates the other, both fire together. This is the one exception to `AI_Defending_Step`'s documented "pauses economy/training while defending" rule, and is NOT reserve-gated (see above).

### Changed

- **`AI_UncoveredBuildingsByTier(_team)`** (`AIControl.gml`) — while `global.age[_team] == 1` (Age I), `oTrainingBuildingParent` buildings are excluded from the proactive defensive-spread list entirely; only production buildings (and the castle, handled separately) get a standing defender posted ahead of time. Per explicit clarification, this is PROACTIVE COVERAGE ONLY — a training building actually under attack still triggers `"defending"` and pulls responders exactly as before (`AI_DetectThreat`/`AI_DetectThreats` untouched).
- **`GainXP(_team, _amount)`** (`ProgressionScripts.gml`) — for `TEAM.ENEMY` only, each XP milestone crossed now grants `irandom_range(1, 3)` random blueprints (`AddBlueprint`, each independently a random registered building type via `global.__buildingDefRegistry`, same idiom `FateDrumRandomPlaceholderItem` already uses) instead of incrementing `fateTokens`. Reasoning: the AI has no Fate Engine UI to ever spend a token on (that whole payout pipeline still isn't built — `FateEngineDrumScripts.gml`'s drum remains a visual-only test harness), so tokens would just accumulate uselessly. This simulates "the player receiving blueprints from the fate engine" directly. `TEAM.PLAYER` is completely unaffected.

### Flagged

- **`AI_TryAttackSurplusAtCap` sends the ENTIRE surplus at once**, with no cooldown/window the way `AI_TryProbeAttack` has — a judgment call, not an explicit spec answer. Flag if a partial commitment or its own cooldown reads better once playtested.
- **`AI_CanReplaceDeployedUnits`'s "resource-ready" check ignores `TrainingTypeLimit`/`global.armyLimit` on purpose** (see its own doc comment) — this is deliberate, not an oversight, since checking those caps while still at the army cap would always fail.
- **`AI_TryReinforceDefense` un-garrisons units mid-combat threat** — it doesn't wait for the un-garrisoned units to actually reach the threatened building before `AI_Defending_Step`'s normal redirect logic runs the same tick; a freshly-deployed unit becomes "available" and gets folded into that same tick's nearest-building assignment immediately, which is the intended fast response, but worth knowing it isn't a separate two-tick sequence.
- **`AI_GOLD_RESERVE_UNIT_COUNT` (2) and `AI_REINFORCE_MAX_DEPLOYS` (20)** are placeholders, not tuned against a real balance pass, same status as every other AI constant in this file.
- No `AIControl.md` Notion-compatible doc exists yet — flagged again, still not closed this pass (now flagged across five consecutive AI-touching sessions).

### Build

- Windows export version bumped `0.0.4.0` → `0.0.4.1` — 4th-digit bump, routine convention.

## v0.0.4.0 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Version bump only — player-facing patch notes requested, covering everything since v0.0.3.0. Per the 3rd-digit-bump-on-requested-patch-notes convention (see v0.0.2.51 → v0.0.3.0's Build note).

### Added

- **`PUBLIC_PATCH_NOTES.md`** — new v0.0.4.0 section added, covering v0.0.3.0 through v0.0.3.20 (garrisoning/stationing and its passive bonuses, gib/blood combat feedback, the Knight/Bomb Goblin combat fixes, four rounds of AI rebalancing, the animated ruler portrait, training-building queue readouts, the Castle Health and Army Limit HUD widgets + Unit Limits menu, the drop-down menu re-skin and new click-anchored positioning, and the selection summary panel), organized by player-facing category (Build & Economy, Combat, The Computer Opponent, Interface & Info, Also) rather than chronologically. Every internal system/function/asset name translated to its player-facing effect, per CLAUDE.md's public-notes convention. Purely additive/no-op for the game itself.

### Fixed

- **"defend" order reassignment silently no-op'd on a unit already in "defend"** (`StateMachine.gml`'s `ChangeState` skips re-entering a state it's already in unless forced) -- diagnosed from a report that AI archers already posted to defend their own archer-training building did nothing when the player attacked a different (resource) building, even after the AI's "Defending threatened building" posture engaged. Root cause was two-part:
  - **`OrderWiring.gml`'s `"defend"` onIssue** now calls `fsm.ChangeState("defend", true)` (forced) instead of the unforced call. Previously, reassigning an already-defending unit to a NEW building (`AI_Defending_Step`/`AI_TryMaintainDefensiveSpread`/`AI_CastleDefense_Step`, AIControl.gml -- all route through this same order) updated `defendTarget` on the unit but never re-ran `Defend_Enter`, so the unit's patrol waypoints were never rebuilt around the new target -- it just kept patrolling its OLD building forever, never getting close enough to the actual threat to fight back.
  - **`Defend_Exit` (`UnitStateDefend.gml`)** no longer clears `defendTarget` on exit. It used to unconditionally wipe it, which -- once the above fix forces re-entry into the SAME state -- would have run Exit first and wiped the brand-new target before Enter ever read it, undoing the fix. This also fixes a second, previously-unreported related bug: a defending unit that aggros into combat (a normal, frequent occurrence -- "combat" is only ever entered from guard/defend and always reverts back to whichever one afterward) would have its `defendTarget` wiped on the "defend"→"combat" exit, then silently fall back to "guard" instead of resuming its patrol once the fight ended. Confirmed nothing else reads `defendTarget` outside of "defend" itself (every reader either runs only during that state or explicitly checks `fsm.Is("defend")` first), so there's no stale-value hazard left by no longer clearing it.
  - **FLAG per CLAUDE.md** ("flag before touching FSM/state wiring for guard, defend, combat, attack, siege"): this touches the "defend" state's Enter/Exit contract and its order-dispatch call site directly. Scoped narrowly to "defend" only -- confirmed `"attack"`'s onIssue (`OrderWiring.gml`) has the exact same unforced-`ChangeState` shape and would likely exhibit the same reassign-while-already-attacking gap, but that's out of scope for this request and was NOT touched; flagging it as a similar-shaped latent issue worth a look later.
  - No version bump for this fix, per explicit request -- folded into this same still-uncommitted v0.0.4.0 entry.

### Build

- Windows export version bumped `0.0.3.20` → `0.0.4.0` — 3rd-digit bump (patch notes explicitly requested this time, unlike the routine 4th-digit bumps every entry back to v0.0.3.1 used). No further bump for the "defend" reassignment fix above, per explicit request.

## v0.0.3.20 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Reworks how OrderMenu and CastleGarrisonMenu position themselves when opened: instead of opening flush at the click point (with only a far-edge overflow clamp), they now use the same mouse-dependent, quadrant-anchor-away-from-cursor logic every hover card already uses. ArmyLimitMenu (fixed HUD-icon anchor) and SelectionSummaryMenu (fixed top-left panel) are explicitly unchanged, per request.

### Added

- **`PositionDropDownMenuFromClick(_mx, _my, _rowCount)`** (`DropDownMenuScripts.gml`) — shared positioning helper for click-triggered drop-down menus. Mirrors `PositionHoverCardPair`'s (`HoverCardScripts.gml`) "quadrant-anchor-away-from-cursor + screen-edge clamp" logic: which screen half the click landed in (horizontally and vertically, independently) decides which side of the click the menu grows into, offset by `PLOT_HOVER_CURSOR_GAP` (`PlotHoverScripts.gml`, reused directly — same precedent `HOVER_CARD_PAIR_GAP` already set), then clamped fully on-screen. Returns `{ x, y }`.

### Changed

- **`OrderMenu.Open(_x, _y, _orders)`** — now calls `PositionDropDownMenuFromClick` instead of setting `x`/`y` directly to the click point with only a right/bottom overflow clamp.
- **`CastleGarrisonMenu.Open(_x, _y, _rows)`** — same change as `OrderMenu.Open`.

### Flagged

- **ArmyLimitMenu and SelectionSummaryMenu are deliberately untouched**, per explicit request — the former opens from a fixed HUD icon (no click position to anchor from), the latter is a fixed top-left panel (never opened from a click at all). Neither calls `PositionDropDownMenuFromClick`.
- **Visible behavior change**: `OrderMenu`/`CastleGarrisonMenu` no longer open with their top-left corner exactly at the cursor — they now open offset by `PLOT_HOVER_CURSOR_GAP` (8px) away from the cursor, on whichever side keeps them on-screen and growing back toward center. This matches hover card behavior but is a different feel from before; flagging in case the previous "flush at click" placement was relied upon anywhere.
- `CastleGarrisonMenu.gml`'s file-header comment ("Structurally mirrors OrderMenu.gml... screen-edge containment on Open") is still accurate in spirit (both menus are still contained on-screen) but the underlying mechanism changed — not edited further since it doesn't misstate anything.

### Build

- Windows export version bumped `0.0.3.19` → `0.0.3.20` — 4th-digit bump, routine convention.

## v0.0.3.19 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Second of the two new HUD widgets: an Army Limit Widget (army usage readout, "[icon] current/max") 10px below the Castle Health Widget, clickable to open a new "Unit Limits" dropdown listing every unit type the player has and its per-type cap usage; clicking a row selects all deployed units of that type.

### Added

- **`ArmyLimitWidgetY()` / `ArmyLimitWidgetIconRect()` / `DrawArmyLimitWidget(_team)`** (`HUDWidgetScripts.gml`, extends the file added for the Castle Health Widget) — `ArmyLimitWidgetY()` computes the shared icon/text Y from the exact edge-to-edge geometry requested ("10px below this one, from the bottom edge of the Health Icon sprite to the top edge of the army limit icon sprite"): `sCastleHealthIcon`'s bottom edge + the 10px gap + `sArmyLimitIcon`'s own yoffset. `ArmyLimitWidgetIconRect()` reuses that same math for the GUI-space hit-rect so the click target can never drift from the drawn position. `DrawArmyLimitWidget` draws `sArmyLimitIcon` then "current/max" using the same font/color/shadow parameters as `DrawCastleHealthWidget`. "Current" is live (`GatherTeamUnits`) + stationed (`CountTeamStationedUnits`) — deliberately excludes queued-in-training units. "Max" is `global.armyLimit[_team]`.
- **`ARMY_LIMIT_WIDGET_X`/`_GAP_Y`** (new macros, `HUDWidgetScripts.gml`) — X matches `CASTLE_HEALTH_WIDGET_X` (452); gap is the requested 10px.
- **`ArmyLimitMenu.gml`** (new script, registered in `.yyp`) — `ArmyLimitRow`/`BuildArmyLimitRows(_team)`/`ArmyLimitMenu` constructor, structurally mirroring `CastleGarrisonMenu.gml` (Open/Close/Update/Draw, shared `DropDownMenuScripts.gml` rendering/hit-test, reuses `CASTLE_MENU_ICON_GAP`/`CASTLE_MENU_COUNT_MARGIN` rather than redeclaring). `BuildArmyLimitRows` scans live `oUnitParent` + `oUnitStationed` instances (not the full unit-type registry) so only types the player actually has get a row; each row shows icon, name, and "count/limit" via `TrainingTypeLimit`. Title "Unit Limits", per the request.
- **`ArmyLimitMenu.Open(_rows)`** — new pattern for this codebase: takes no click position and always opens at a FIXED anchor (`ARMY_LIMIT_MENU_ANCHOR_X` 408, `ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y` 812), growing upward from the bottom edge instead of downward from a top-left click point like every other menu here. Triggered by clicking the Army Limit Widget's icon (`oUnitControl/Step_0.gml`, checked first in the click-handling chain, ahead of the castle-wall/training-building/blueprint-drag checks).
- **`SelectionController.SelectAllOfType(_unitType)`** (`UnitSelection.gml`) — new selection helper; selects every live instance of `_unitType` on the controller's team, replacing the current selection. Used when an `ArmyLimitMenu` row is clicked ("select all deployed units of that type"). Deliberately live-only — stationed units of the same type are excluded (different object, no FSM, never selectable).
- Wired into `oUnitControl`: `armyLimitMenu = new ArmyLimitMenu()` (`Create_0.gml`); `armyLimitMenu.Update()` + row-click → `SelectAllOfType` dispatch, plus the icon hit-test and `consumedClick` guard added to the main click gate (`Step_0.gml`); `DrawArmyLimitWidget(TEAM.PLAYER)` and `armyLimitMenu.Draw()` (`Draw_64.gml`, drawn last, same "on top of everything" ordering as the other dropdowns).

### Flagged

- **`ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y` (812) matches `SELECTION_DRAG_MIN_GUI_Y`** (`UnitSelection.gml`) exactly — confirmed intentional (both mark "top of the bottom HUD panel"), not treated as coincidence, documented in the macro's own comment.
- **"Current" unit count excludes queued-in-training units** — a judgment call: the request says "number of units," which I read as units that already exist, not ones still being trained. Queued units still count toward whether MORE can be queued (`TrainingTryQueueUnit`'s own check is unaffected).
- **`SelectAllOfType` only selects deployed (live) units, never stationed ones** — directly from the request's "select all deployed units of that type" wording, reinforced by stationed units having no FSM/selection presence at all.
- **`ArmyLimitMenu.Open()`'s fixed-anchor, grows-upward behavior is a new pattern** — every other dropdown in this project opens top-left-from-a-click; flagging in case this diverges from an unstated expectation for how the menu should feel to open.
- No Notion-compatible doc yet for `HUDWidgetScripts.gml` or `ArmyLimitMenu.gml` — same ongoing gap noted in v0.0.3.18, now applies to two files.

### Build

- Windows export version bumped `0.0.3.18` → `0.0.3.19` — 4th-digit bump, routine convention.

## v0.0.3.18 — 2026-07-13 (uncommitted — working tree only, not yet committed)

First of two new HUD widgets (Army Limit Widget planned to follow): a Castle Health Widget showing the player's castle HP as "[icon] current/max", top-left anchored at (452, 856).

### Added

- **`HUDWidgetScripts.gml`** (new script, registered in `Blank Pixel Game.yyp`) — new home for fixed-position top-level HUD readouts that sit alongside the resource bar but don't fit `ResourceUIScripts.gml`'s specific scope. Houses the new `DrawCastleHealthWidget(_team)` this pass, with an Army Limit Widget planned to join it next.
- **`DrawCastleHealthWidget(_team)`** — draws `sCastleHealthIcon` followed by "current/max" castle health text, using `fntResource`/`HOVER_CARD_TEXT_COLOR` (matching `DrawResourceBar`'s established HUD number styling) plus a 1px drop shadow (`HOVER_CARD_SHADOW_COLOR`/`_OFFSET`, hand-rolled via a second `draw_text` call since this widget doesn't use Scribble). Reads `GetTeamCastle(_team)` → `GetCurrentHealth(_castle)` for current HP and `_castle.maxHealth` for max (not the flat `CASTLE_MAX_HEALTH` macro directly, matching how `GetCurrentHealth` itself always reads the instance field, futureproofing against a per-instance max HP bonus later). No-ops if the team has no castle instance.
- **`CASTLE_HEALTH_WIDGET_X`/`_Y`/`_TEXT_GAP`** (new macros, `HUDWidgetScripts.gml`) — (452, 856) anchor and a 10px icon-to-text gap (matching `RESOURCE_BAR_TEXT_GAP`'s value for visual consistency).
- Wired into `objects/oUnitControl/Draw_64.gml`, right after `DrawResourceBar(TEAM.PLAYER)`.

### Flagged

- **X/Y anchor math are handled differently, per the request's own wording.** `sCastleHealthIcon` has a Custom sprite origin (11,10 of a 24x22 frame), not a clean Middle-Center origin like `sResourceIcons`. X: the icon is drawn at `CASTLE_HEALTH_WIDGET_X + sprite_get_xoffset(sCastleHealthIcon)`, which lands its rendered LEFT EDGE exactly on the anchor. Y: `CASTLE_HEALTH_WIDGET_Y` is used directly, unmodified, as the shared vertical anchor for both the icon and the text (same "one Y for both" pattern `DrawResourceBar` uses) -- no yoffset correction, per the request's explicit "sprite is center aligned" framing. Since yoffset (10) isn't exactly half of 22, this is a ~1px approximation of true vertical centering, not pixel-exact -- flagging in case a tighter vertical fit is wanted later.
- **The shadow reuses `HOVER_CARD_SHADOW_COLOR`/`_OFFSET` (`HoverCardScripts.gml`) but not the mechanism they were built for.** Those constants are otherwise only ever applied via Scribble's `.blend()/.draw()` (`DrawCardTextWithShadow`); this widget doesn't use Scribble, so the same shadow-then-text draw order is replicated with two plain `draw_text` calls instead. `DrawResourceBar` itself (the widget's closest visual neighbor) has NO shadow -- this widget deliberately doesn't match that specific example, since the request explicitly asked for one here.
- `CASTLE_HEALTH_WIDGET_TEXT_GAP` (10) is not an explicit spec number -- borrowed from `RESOURCE_BAR_TEXT_GAP` for visual consistency with the resource bar it sits next to.
- No Notion-compatible doc exists yet for `HUDWidgetScripts.gml` -- new file, flagging per the established convention (same ongoing gap as `AIControl.md`).

### Build

- Windows export version bumped `0.0.3.17` → `0.0.3.18` -- 4th-digit bump, routine convention.

## v0.0.3.17 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Closes the flag from v0.0.3.16: the per-type training cap now also counts stationed units of that type, matching the army-wide cap's same correction.

### Changed

- **`TrainingTryQueueUnit`'s type-limit check (`TrainingScripts.gml`)** — `_typeExisting` now sums `CountTeamUnitsOfType` (live) + `CountTeamStationedUnitsOfType` (new, stationed) against `TrainingTypeLimit`, instead of live only. A stationed Peasant now counts against "how many Peasants can this team ever have via Peasant Wards," the same way it already counted against the army-wide cap as of v0.0.3.16. Applies identically to both teams -- same shared function, same reasoning as the army-wide fix.
- **`AI_WouldTrainSucceed`'s dry-run (`AIControl.gml`)** — matching update, so the debug readout's training preview stays consistent with what `TrainingTryQueueUnit` actually does.
- **File header comment (`TrainingScripts.gml`)** — updated to describe both caps as counting live + stationed + queued, and to state explicitly that station status never lets a team exceed either cap.

### Added

- **`CountTeamStationedUnitsOfType(_team, _unitType)`** (`StationScripts.gml`) — stationed counterpart to `CountTeamUnitsOfType` (`TrainingScripts.gml`), which can only ever see LIVE instances of a unit's object type and has no way to see a stationed one (a stationed unit is a different object, `oUnitStationed`, with its original type preserved only in `unitData.unitType`).

### Build

- Windows export version bumped `0.0.3.16` → `0.0.3.17` -- 4th-digit bump, routine convention.

## v0.0.3.16 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Correction to v0.0.3.15: stationed units still count against `global.armyLimit` -- they always should have, for both teams, but `TrainingTryQueueUnit`'s army-wide check only ever summed live units + queued, never stationed ones. This meant a team (player OR AI) could station units and then keep training past the intended cap indefinitely -- stationing was never actually shrinking the army for cap purposes, it just wasn't being counted. v0.0.3.15's "station-at-cap frees a slot for new training" and "inside-plot training bypasses the army cap" claims were both built on this same gap and are corrected below.

### Changed

- **`TrainingTryQueueUnit` (`TrainingScripts.gml`)** — the army-wide cap check now sums live units + `CountTeamStationedUnits` + queued against `global.armyLimit`, instead of just live + queued. Applies identically to both teams since this one function gates every training queue attempt, player and AI alike. The per-type cap (`TrainingTypeLimit`/`CountTeamUnitsOfType`) is unchanged and still doesn't count stationed units of that type -- flagged as a related but separate question, not part of this request.
- **`AI_TeamAtArmyLimit`/`AI_WouldTrainSucceed` (`AIControl.gml`)** — both updated to the same corrected math, so the AI's own "am I at cap" decisions (siege threshold, station reserve floor) and the debug readout's dry-run training preview stay consistent with what `TrainingTryQueueUnit` will actually do.
- **`AI_CurrentStationedCount`** — now a thin wrapper around the new shared `CountTeamStationedUnits` (was duplicating the same `with (oUnitStationed)` loop locally).
- **`AI_DebugQuotasText`'s "Army" line** — now shows live/stationed/queued all three (`{live}L+{stationed}S+{queued}Q/{limit}`) instead of just live+queued, so the readout doesn't imply room exists that's actually already used up by stationed units.
- **Corrected doc comments/patch-note claims (`AIControl.gml`, this file)** — every place that said stationing "frees a slot under `global.armyLimit`" or that inside-plot training "bypasses the army cap" has been corrected: stationing only moves a unit from the live bucket to the stationed bucket, it does not shrink the army for cap purposes. The at-cap station-reserve relaxation and inside-plot placement preference from v0.0.3.15 are still worthwhile on their own merits (passive bonus value; discounted placement + skipping a manual station order) -- neither actually works around the cap.

### Added

- **`CountTeamStationedUnits(_team)`** (`StationScripts.gml`) — single shared source of truth for "how many units does this team currently have stationed," used by both `TrainingTryQueueUnit` (core, both sides) and `AIControl.gml`'s `AI_TeamAtArmyLimit`/`AI_WouldTrainSucceed`/`AI_CurrentStationedCount`, replacing what used to be a duplicated `with (oUnitStationed)` loop in the AI file alone.

### Flagged

- The per-type training cap (`TrainingTypeLimit`) still does not count stationed units of that type -- e.g. a stationed Peasant doesn't count against "how many Peasants can this team ever have via Peasant Wards." Not addressed here since the request specifically called out the army-wide cap; flagging in case the per-type cap should eventually match.
- This was a real, pre-existing gap in `TrainingTryQueueUnit` -- not something introduced by v0.0.3.14/v0.0.3.15's AI work, just not noticed until the AI-side `AI_TeamAtArmyLimit` copy of the same (incomplete) logic was added and reviewed.

### Build

- Windows export version bumped `0.0.3.15` → `0.0.3.16` -- 4th-digit bump, routine convention.

## v0.0.3.15 — 2026-07-13 (uncommitted — working tree only, not yet committed)

Follow-up to v0.0.3.14's siege-power-threshold diagnosis (a 6-unit `global.armyLimit` army of Peasants/Archers can never mathematically reach the flat 300-power siege bar): the AI now reacts once it's actually AT that army cap instead of stalling there forever, prefers placing station-favoring training buildings (Peasant Ward) on inside plots so trained units go straight to the garrison without ever touching the cap, and the top-right debug readout now shows the AI's live quotas and a preview of its next intended action.

### Changed

- **`AI_SiegePowerThreshold` (`AIControl.gml`)** — now takes `_team`. Once `AI_TeamAtArmyLimit(_team)` is true (live + queued units at `global.armyLimit`), the fraction drops from `AI_SIEGE_POWER_FRACTION` (0.6) to the much smaller `AI_SIEGE_POWER_FRACTION_AT_CAP` (0.15) — a capped-out, mostly-weak-unit army still eventually commits to siege instead of idling at the cap indefinitely. Unchanged for a team still below its cap (still gated by the full 300-power bar). Call site in `AI_BuildUp_Step` updated to pass `_brain.team`.
- **`AI_TryStationUnits`** — the reserve floor it won't station below drops from `AI_STATION_MIN_GUARD_RESERVE` (3) to `AI_STATION_MIN_GUARD_RESERVE_AT_CAP` (1) once `AI_TeamAtArmyLimit` is true. Holding back 3 idle guards exists to protect a future training pipeline — but once the team is at cap, nothing new can be queued regardless of how many of those units are guard vs. stationed (stationed units still count against `global.armyLimit`, see the v0.0.3.16 correction below), so there's nothing left to protect either way. Converting more of them to stationed at that point is purely for their own passive-bonus value, not an army-cap workaround.
- **`AI_FindEmptyOwnedPlot`** — new optional `_preferInside` parameter (default `false`). When true, does a first pass restricted to `inside == true` plots, falling back to the normal any-plot search if none are free.
- **`AI_TryPlaceBlueprints`'s second (greedy) pass** — for a training-building blueprint whose trained unit favors stationing (new `AI_UnitFavorsStationing`), now calls `AI_FindEmptyOwnedPlot` with `_preferInside = true`. Placing that building's training slot inside the castle means every unit it ever trains spawns directly as stationed (`TrainingSpawnUnit`'s existing `if (_building.inside)` branch → `StationSpawnDirectly`), skipping the manual "train live, then separately order it to station" step (it does NOT bypass `global.armyLimit` — see v0.0.3.16). Resource-building placement (pass 1) and non-station-favoring training buildings are unaffected.
- **`oAIControl/Draw_64.gml`** — top-right AI debug text now shows two additional lines: `Next:` (a live preview of the AI's next intended action — placing a blueprint, training a unit, posting a defender, stationing a unit, attacking/sieging, probing, or idle) and a quotas block (army count vs. limit + CAP flag, stationed count vs. max, tank/ranged composition vs. target, and current siege power vs. threshold).

### Added

- **`AI_TeamAtArmyLimit(_team)`** (`AIControl.gml`) — factored out of `TrainingTryQueueUnit`'s own saturation check (`TrainingScripts.gml`): true once live + queued units reach `global.armyLimit[_team]`. Shared by `AI_SiegePowerThreshold` and `AI_TryStationUnits`.
- **`AI_UnitDefPowerScore(_def)`** — definition-level counterpart to `AI_UnitPowerScore`, evaluated off `maxHealth`/`attackDamage` directly rather than a live instance's current HP (needed to compare unit TYPES before any instance necessarily exists, e.g. deciding where to place a not-yet-built training building).
- **`AI_UnitFavorsStationing(_def)`** — true when a unit type has a nonzero `AI_UnitStationedBonusValue` AND its `AI_UnitDefPowerScore` sits below the new flat `AI_STATION_FAVOR_POWER_CEILING` (20) cutoff. Only Peasant (14) clears this today; Soldier (33)/Knight (40)/Mud Golem (65)/Bomb Goblin (102, skewed high by its one-shot `attackDamage`) all sit above it.
- **AI debug introspection block** (`AIControl.gml`, end of file) — `AI_WouldTrainSucceed`, `AI_NextAffordableBlueprintName`, `AI_NextTrainableUnitName`, `AI_TeamHasSpareGuard`, `AI_NextStationCandidateName`, `AI_DebugIntent`, `AI_DebugQuotasText`. All read-only, debug-readout use only — none issue orders, spend resources, or mutate a queue.

### Flagged

- **`AI_STATION_FAVOR_POWER_CEILING` (20)** is a flat cutoff, not a relative "weakest of all registered unit types" comparison — simpler, and doesn't need to iterate `global.__unitDefRegistry`, but it's an arbitrary number like every other placeholder in this file. Revisit if a future weak-but-useful unit type should also qualify, or if Peasant's own stats change enough to fall outside it.
- **`AI_SIEGE_POWER_FRACTION_AT_CAP` (0.15)** was chosen so a mixed 6-unit army of Peasants/Archers (~75-114 power depending on mix) clears it comfortably; not validated against an actual playtest, same "placeholder, not tuned" status as every other AI constant here.
- **`AI_WouldTrainSucceed` duplicates `TrainingTryQueueUnit`'s three gates** (type limit, army limit, affordability) as a dry run, since no non-mutating variant exists to call instead. If `TrainingTryQueueUnit`'s gating logic changes later, this needs a matching update or the debug readout will quietly drift out of sync with real behavior (display-only drift, not a functional bug).
- **`AI_DebugIntent` is an approximation**, not a perfect predictor — it re-checks the same priority cascade `AI_BuildUp_Step` uses but doesn't fully re-derive every internal rule (e.g. `AI_NextAffordableBlueprintName` ignores the resource-priority first pass). Good enough for a debug readout; state can also shift between the preview and the next real think tick.
- No `AIControl.md` Notion-compatible doc exists yet — flagged again, still not closed this pass (now flagged across three consecutive AI-touching sessions).

### Build

- Windows export version bumped `0.0.3.14` → `0.0.3.15` -- 4th-digit bump, routine convention.

## v0.0.3.14 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Four related AI rebalance changes aimed at the "I can just steam-roll this AI" problem: siege commitments now always leave a real fraction of the army behind instead of a flat 2-unit reserve, the AI throws small early-game probe attacks at ordinary enemy buildings, it preferentially stations units that are worth more in the garrison than on the field (Peasants, per the request's own example), and its standing defenders now proactively spread across every owned building with rear (castle-adjacent) plots getting covered before front (exposed) ones.

### Changed

- **`AI_ReserveGuardUnits` replaced with `AI_ReserveDefensiveUnits`/`AI_MinDefensiveReserve` (`AIControl.gml`)** — the old flat `AI_SIEGE_GUARD_RESERVE` (2 guard units, guard-only) is gone. The new floor is `ceil(totalArmy * AI_MIN_DEFENSIVE_ARMY_FRACTION)` (25%), where `totalArmy` counts every live unit PLUS every currently-stationed unit, and it reserves already-posted `defend` units FIRST (idle `guard` units only fill whatever gap remains) — protects standing building defenders instead of just padding out idle roamers. `AI_BuildUp_Step` now carves this floor out of the available pool BEFORE either probing or sieging, so both respect it.
- **`AI_Defending_Step`** — the nearest-threatened-building assignment is now `distance + tier penalty` instead of pure distance, via the new `AI_DEFEND_TIER_WEIGHT` macro. REAR (inside-castle) buildings get no penalty, MID and FRONT get progressively larger ones, so responders bias toward defending rear buildings when the choice is close, without overriding a unit that's overwhelmingly closer to a front one.
- **`AI_TryStationUnits`** — no longer cheapest-first across every idle guard. Now only units with a nonzero `stationedBonuses` total are even eligible (stationing an Archer today is pure waste — 0 benefit either way), and among those, the WEAKEST in combat (`AI_UnitPowerScore`) go first, `stationCost` only as a tiebreaker — directly implements "units that have higher benefits to station than to be abroad" (Peasant: weak melee, real production bonus).

### Added

- **`AI_BuildingPlotTier`/`AI_PLOT_TIER_REAR`/`_MID`/`_FRONT` (`AIControl.gml`)** — classifies a building's defensive tier off the SAME `oBuildingPlot.inside`/`far` fields `SpawnBuildingPlot` (`PlotScripts.gml`) already tags every plot with (`oPlotSpawner`'s castle grid = rear, `oOuterPlotSpawner`'s near/far bands = mid/front) — "the different groups of plots" the request refers to are this existing grouping, not a new geometry system.
- **`AI_TryMaintainDefensiveSpread`/`AI_UncoveredBuildingsByTier`** — proactively posts idle guards to `defend` any owned building with zero current defenders, rear-tier first, up to `AI_SPREAD_ATTEMPTS_PER_TICK` per think tick. Called from `AI_BuildUp_Step` before stationing — physical coverage takes priority over the passive stationing optimization.
- **`AI_TryProbeAttack`/`AIBrain.age`/`AIBrain.probeCooldown`** — early-game harassment. While the brain's `age` is within `AI_PROBE_WINDOW_FRAMES` (~60s) and its cooldown (`AI_PROBE_INTERVAL_FRAMES`, ~15s) has expired, sends up to `AI_PROBE_ATTACK_SIZE` (2) surplus units to `attack` a random standing enemy building — the same order/state a player's "Attack Building" order uses, never the castle. Draws from the SAME post-reserve surplus siege does, so it can't violate the 25% floor either.
- **`AI_PartitionByPosture`/`AI_UnitStationedBonusValue`** — small shared helpers the above all build on (split a unit array into guard/defend; sum a `UnitDefinition`'s `stationedBonuses` into one rough value score).

### Flagged

- All new macros (`AI_MIN_DEFENSIVE_ARMY_FRACTION`, `AI_DEFEND_TIER_WEIGHT`, `AI_SPREAD_ATTEMPTS_PER_TICK`, `AI_PROBE_WINDOW_FRAMES`/`_INTERVAL_FRAMES`/`_ATTACK_SIZE`) are placeholders, same "not tuned against a real balance pass" status as every other AI constant in this file.
- `AI_TryMaintainDefensiveSpread` only guarantees ONE defender per building, not a particular garrison size — a high-value building doesn't get extra weight beyond its tier. Flag if specific buildings (e.g. a resource producer close to depleting) should outrank a flat "one defender each."
- `AI_TryProbeAttack` doesn't scout or evaluate the target building's defenses first — it can and will send raiders to their deaths against a defended building. Treated as expected probe behavior (per the request's own "probe" framing), not a bug; revisit if the intent was closer to "safe harassment only."
- `AI_MinDefensiveReserve`'s floor is a snapshot at COMMIT time (when siege/probe is about to be issued) — it does not actively recall units later if losses subsequently drop the live defensive count below 25%. Only `castle_defense` still does any active recall, and only for the AI's own castle.
- No AIControl.gml Notion-compatible doc exists yet — a pre-existing gap flagged repeatedly across prior passes, not closed here either.

### Build

- Windows export version bumped `0.0.3.13` → `0.0.3.14` -- 4th-digit bump, routine convention.

## v0.0.3.13 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Blueprint slot borders now signal affordability at a glance, Knight's long-flagged "bonus damage against production buildings" passive is finally real (+50%), and Bomb Goblin now actually dies the instant its swing lands, matching its own flavor text ("Dies on detonation").

### Changed

- **`BlueprintController.Draw` (`BlueprintScripts.gml`)** -- a filled slot's border is now white (`BLUEPRINT_AFFORDABLE_BORDER_COLOR`) if that building can currently be placed AND afforded at at least one open plot anywhere, or dark gray (`BLUEPRINT_UNAFFORDABLE_BORDER_COLOR`) otherwise -- reuses the exact same `GetBestAvailablePlacementCost` scan the hover card's title-color check already used (2026-07-09), just applied to every filled slot every frame instead of only the hovered one. Empty slots keep the plain white border.
- **`UnitTryDealDamage` (`UnitCombatHelpers.gml`)** -- the single melee damage choke point (attack/combat/siege all route through it) now: (1) multiplies damage by `UnitDefinition.productionBuildingDamageBonus` when the attacker has one and the target is an `oResourceBuildingParent` (production building only, not training buildings or the castle); (2) sets `pendingSelfDestruct` on the attacker when it's a Bomb Goblin.
- **`oUnitParent`** -- new `pendingSelfDestruct` field (every unit, default `false`), consumed in `Step_0.gml` right after `fsm.Step()` finishes for the frame -- deferred rather than destroying the unit synchronously inside `UnitTryDealDamage`, since that function runs mid-FSM-step and every caller (Attack_Step/UnitStateCombat/UnitStateSiege) keeps reading the attacker's fields immediately after it returns. When consumed, self-damages for `maxHealth` through `ApplyDamage` (source `noone`) so it gets the normal lethal branch -- gibs, Strategic XP, analytics -- without crediting anyone Combat XP for it.
- **Knight's `UnitDefinition`** -- `productionBuildingDamageBonus: 0.5` (new field, `UnitDefinitions.gml`), 50% per the request ("Make it 50% more damage for now"). "Deployed Effect" flavor text updated from "NOT implemented" to state the bonus directly.
- **Bomb Goblin's `UnitDefinition`** -- flavor text updated to reflect the new self-destruct behavior; AoE (hitting units OTHER than the single `_target`) is still explicitly not implemented, only self-destruct-on-hit.

### Added

- **`UnitDefinition.productionBuildingDamageBonus`** (new optional field, `UnitDefinitions.gml`, defaults to `0`) -- fractional bonus damage vs `oResourceBuildingParent` targets specifically, scoped to match Knight's own flavor text wording ("against production buildings"), not a generic vs-any-building bonus.
- **`BLUEPRINT_AFFORDABLE_BORDER_COLOR` / `BLUEPRINT_UNAFFORDABLE_BORDER_COLOR`** (new macros, `BlueprintScripts.gml`) -- `c_white` / `c_dkgray`, the latter matching `BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG`'s existing color as a real draw color constant instead of a Scribble tag string.

### Flagged

- `UnitTryDealDamage`/`oUnitParent` are both load-bearing combat/FSM surfaces per project convention -- flagging explicitly rather than treating the change as routine. The fix avoids touching any state's transition logic directly; `pendingSelfDestruct` is a plain deferred-effect flag consumed after the FSM step fully completes, specifically to avoid destroying an instance mid-step out from under its own caller.
- `productionBuildingDamageBonus` is a single scalar scoped to ONE building category (production). If a future unit needs a bonus against a different building category (training buildings, the castle), this field's shape will need revisiting rather than reusing it as-is.
- Blueprint border affordability is recomputed fresh every Draw call for every filled slot (matches this codebase's existing "recompute fresh, don't cache" convention for `GetStationedPassiveBonuses`/`TrainingTypeLimit`) -- fine at today's scale (max 10 slots), flag if the plot scan ever needs caching at a larger blueprint inventory size.

### Build

- Windows export version bumped `0.0.3.12` → `0.0.3.13` -- 4th-digit bump, routine convention.

## v0.0.3.12 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Follow-up to v0.0.3.11's gibbing pass: the gib surface now draws behind everything instead of on top, hover cards for production/training buildings show the LIVE bonus-adjusted rate/time (colored green/red when a stationed bonus is actively helping/hurting it), and buildings now kick up gray placeholder particles when hit, mirroring the unit blood-pixel reaction.

### Changed

- **`oGibSurfaceControl`** -- `depth` flipped from `-room_height - 1` (draws on top of every y-sorted instance) to `room_height + 1` (positive -- draws BEHIND all of them), per explicit follow-up request ("change the gib surface to below everything"). `Create_0.gml`/`Draw_0.gml` header comments and `GibScripts.md` updated to match.
- **`BuildingHoverTimerText` (`BuildingHoverScripts.gml`)** -- now takes a `_team` param and shows the LIVE stationed-bonus-adjusted production rate/train time (same `GetStationedPassiveBonuses` source `BuildingUpdateProduction`/`TrainingUpdateQueue` already apply every tick) instead of the static definition value. Wrapped in `PLOT_HOVER_GOOD_COLOR_TAG` (green) when the bonus makes the number more beneficial than base (more per second, or less time to train), `PLOT_HOVER_BAD_COLOR_TAG` (red) if it's worse (no bonus does this today, kept symmetric for future negative modifiers), and left uncolored when unchanged. Blueprint hover shows what the bonus would currently grant on placement. Rate rounds to the nearest 0.01, time to the nearest 0.1, only when a bonus actually skews the value off the base whole number.

### Added

- **`SpawnBuildingHitParticles` (`GibScripts.gml`)** -- building equivalent of `SpawnUnitHitBlood`: 2-4 gray single-pixel particles on every non-lethal building hit, reusing the same pixel-kind `oGibDebris` physics (`SpawnColorPixel`, generalized out of the old hardcoded-red `SpawnBloodPixel`). Colors default to `BUILDING_HIT_PARTICLE_COLOR_DARK`/`BRIGHT` (flat grays); wired into `ApplyDamage`'s non-lethal branch (building/else case), which previously had zero hit-reaction for buildings.
- **`BuildingDefinition.hitParticleColorDark`/`hitParticleColorBright` (new optional fields, `BuildingDefinitions.gml`)** -- per-building-type override for the above, both `undefined` today (every building uses the shared gray) -- placeholder for a future pass giving each building type its own color, per the request ("we will make specific color coded particles for each building later").

### Flagged

- No building DEATH-particle equivalent to `SpawnUnitDeathGibs` was added -- the request only covered the hit reaction ("when they are hit"), not destruction. `ApplyDamage`'s lethal/building branch still only calls `BuildingFreePlot`.
- Hover-card rate/time rounding precision (0.01 / 0.1) is a judgment call, not specified by the request -- flag if a different precision reads better once bonuses are actually visible on a real card.
- `BLOOD_PIXEL_*` physics macro names (`GibScripts.gml`) are now stale -- they describe generic "single pixel particle" physics shared by blood AND building-hit particles, not blood specifically. Left as-is to avoid an unrelated rename; flag if the naming should be revisited.

### Build

- Windows export version bumped `0.0.3.11` → `0.0.3.12` -- 4th-digit bump, routine convention.

## v0.0.3.11 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Units now gib on death (chunks, unique per-unit gib, instant blood splatter) and bleed single-pixel blood particles both when hit and when they die, all permanently stamped onto a persistent gib surface instead of piling up as live instances. Mud Golem is fully excluded this pass -- its own death treatment is a separate future request.

### Added

- **`GibScripts.gml` (new file)** -- the gibbing/blood-particle system. See `GibScripts.md` for the full API; summary below.
  - **`oGibSurfaceControl` (new object, one per match)** -- owns `global.gibSurface`, a room-sized surface every landed gib/splatter gets permanently stamped onto. Drawn at `depth = -room_height - 1` (same "on top of every y-sorted instance" formula `oResourceProducedParticle` already used), per the request's explicit depth spec.
  - **`oGibDebris` (new object)** -- generic flying-then-landing debris shared by general chunks, each unit's own unique gib, and single-pixel blood particles. Fake-gravity physics: a real ground position that slides away from the killer with friction, plus a separate purely-visual height that pops up and falls in an arch. Lands (stamps to the surface, destroys itself) the instant the arch completes.
  - **On-death sequence (`SpawnUnitDeathGibs`)**, per unit (Mud Golem excluded entirely): instant blood splatter (`sGeneralSplatters`, always) → 3-5 general chunks (`sGeneralChunks`, skipped for Bomb Goblin -- see below) → the unit's own unique gib sprite if one exists (`sPeasantGib`/`sSoldierGib`/`sArcherGib`/`sKnightGib` -- none yet for Bomb Goblin) → 4-8 death blood pixels.
  - **On-hit blood (`SpawnUnitHitBlood`)** -- every non-lethal hit against a unit (Mud Golem excluded) now spawns 2-4 blood pixels.
  - **`UnitDefinition.gibSprite`/`usesGeneralChunks` (new optional fields, `UnitDefinitions.gml`)** -- gibSprite registered for Peasant/Soldier/Archer/Knight; `usesGeneralChunks: false` for Bomb Goblin only (it already has its own explosion animation and no unique gib sprite, so generic debris would look mismatched -- it still gets the splatter and blood pixels).

### Changed

- **`ApplyDamage` (`UnitCombatHelpers.gml`)** -- the FIRST on-hit/on-death visual hook in this codebase (previously "nothing in this codebase runs on unit death at all," per Mud Golem's own Deployed Effect note). Non-lethal unit hits call `SpawnUnitHitBlood`; the instant a unit dies, BEFORE `instance_destroy`, `SpawnUnitDeathGibs` runs. Buildings are unaffected either way (no `fsm` -- gibbing is unit-only). Routes through this one function for both melee and ranged/projectile damage, so no other combat file needed to change.

### Flagged

- Mud Golem is excluded from the ENTIRE system (hit particles too, not just death) -- confirmed explicitly rather than assumed, since he's hit constantly in normal play.
- Chunk count (3-5), all `GIB_*`/`BLOOD_PIXEL_*` physics constants, and Bomb Goblin's `usesGeneralChunks: false` treatment are judgment calls -- the request didn't specify exact counts/magnitudes. See `GibScripts.md`'s "Known assumptions" for the full list, including the "stopped moving" interpretation (the vertical arc completing, not a separate horizontal-velocity-near-zero check) and lost-surface recovery losing prior stamps.
- This is the first `surface_create` usage in the project -- flag if surface lifetime/memory needs a closer look later (e.g. very long matches with heavy combat).

### Build

- Windows export version bumped `0.0.3.10` → `0.0.3.11` -- 4th-digit bump, routine convention.

## v0.0.3.10 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Stationed units now grant real passive bonuses (production/training speed, unit HP/damage), visible on a new castle hover panel. The AI opponent now stations units for those bonuses itself, reacts to threats near-instantly instead of on the next think tick, splits its defenders across multiple threatened buildings instead of dog-piling one, and holds back a standing guard reserve instead of committing everything to a siege. AI debug text moved to the top-right, out of the way of the top-left UI.

### Added

- **`UnitDefinition.stationedBonuses` (new field, `UnitDefinitions.gml`)** -- the functional counterpart to each unit's "Stationed Effect" flavor text. Array of `{type, amount}` (amount is a fractional bonus, 0.05 = +5%), stacking linearly per unit stationed. Registered for Peasant (`allResourceProduction` +5%), Bomb Goblin (`goldProduction` +15%), Mud Golem (`unitHealth` +5%), Soldier (`unitHealth` +5% / `unitDamage` +5%), and Knight (`trainingSpeed` +5%). Archer's "Ranged attacks from the wall" is deliberately left unimplemented (`stationedBonuses: []`) -- a real garrisoned-unit-fires-projectiles mechanic, not a stat multiplier; explicitly out of scope per user clarification this pass.
- **`StationedBonuses` / `GetStationedPassiveBonuses(_team)` (`StationScripts.gml`)** -- aggregates every live `oUnitStationed` on a team into one bonus struct, one linear stack per unit. Recomputed fresh every call, not cached (same convention as `TrainingTypeLimit`). See `StationScripts.md`.
- **`CastleBonusHoverScripts.gml` (new file)** -- hover panel over the player's own castle listing every currently active stationed bonus as "+X% Label" lines, or "No active bonuses." Same dwell/fade/HoverCard pattern as `PlotHoverController`/`BuildingHoverController`; suppressed while `CastleGarrisonMenu.isOpen`, per the request ("only visible if the garrison menu isn't open"). Player-castle-only, same restriction as the garrison dropdown. See `CastleBonusHoverScripts.md`.
- **`AI_TryStationUnits`/`AI_CurrentStationedCount` (`AIControl.gml`)** -- the AI now deliberately stations some of its own idle "guard" units (cheapest-first, up to `AI_STATION_MAX_STATIONED`, one per think tick, never dropping below `AI_STATION_MIN_GUARD_RESERVE` guards) to pick up the same passive bonuses above. Called from `AI_BuildUp_Step`; paused whenever the AI is defending.
- **`AI_DetectThreats` (plural, `AIControl.gml`)** -- returns every currently threatened owned building, not just the first. `AI_Defending_Step` now assigns each available unit to whichever threatened building is NEAREST to it and issues one grouped "defend" order per building, instead of dumping every available unit on the single first-found threat and leaving any other simultaneously-threatened building undefended.
- **`AI_ReserveGuardUnits` (`AIControl.gml`)** -- `AI_BuildUp_Step` now holds back up to `AI_SIEGE_GUARD_RESERVE` idle "guard" units before committing the rest to a siege, so committing to offense doesn't strip the AI's own territory to zero defenders.
- **AIBrain urgency interrupt (`AIControl.gml`)** -- `AIBrain.Step` now checks for a threat EVERY frame (not just on the normal ~0.75s think tick) and zeroes `thinkTimer` the instant one appears while the brain hasn't already reacted, so the AI's first response to being attacked is near-instant instead of waiting out the rest of `AI_THINK_INTERVAL`. The full decision cycle (training/blueprints/composition/siege/station math) still only runs on an actual think tick -- only the cheap threat check itself runs every frame.

### Changed

- **`BuildingUpdateProduction` (`BuildingDefinitions.gml`)** -- resource production rate now scaled by the producing building's team's `allResourceProductionBonus` + (`goldProductionBonus` if producing gold).
- **`TrainingUpdateQueue` (`TrainingScripts.gml`)** -- training progress now scaled by the training building's team's `trainingSpeedBonus`.
- **`UnitApplyDefinition` (`UnitDefinitions.gml`)** -- `maxHealth`/`attackDamage` now scaled by the unit's team's `unitHealthBonus`/`unitDamageBonus` (rounded to the nearest whole number), baked in ONCE at spawn/redeploy time -- not retroactively applied to already-live units, and not removed if the stationed unit providing the bonus later redeploys. See `StationScripts.md`'s "Known assumptions" for why full dynamic re-application is out of scope this pass.
- **`TrainingSpawnUnit` (`TrainingScripts.gml`)** -- now re-calls `UnitApplyDefinition` right after overriding the spawned unit's team (same pattern `DeployStationedUnit` already used). Necessary fix, not cosmetic: `UnitApplyDefinition` now reads team-scoped bonuses, and the original Create-time call ran before the team override, so an AI-trained unit would previously have picked up `TEAM.PLAYER`'s bonuses instead of its own team's.
- **`oAIControl`'s debug text (`Draw_64.gml`)** -- moved from top-left `(8, 24)` to top-right (right-aligned, 8px from the GUI's right edge), out of the way of the top-left drop-down menus and selection cards it used to overlap.

### Flagged

- Stationed HP/damage bonuses are spawn-time-only, not a dynamic army-wide recompute (see `StationScripts.md`).
- Archer's "Ranged attacks from the wall" passive remains flavor-text-only -- skipped per explicit user decision this pass, not an oversight.
- Knight's stationed-effect flavor text doesn't say "(stacks per Knight stationed)" the way every other unit's does; applied the same linear-stacking rule anyway for consistency with the mechanism -- flagging the wording gap, not treating it as a "no stacking" spec.
- `AIControl.gml`, `CastleGarrisonMenu.gml`, `DropDownMenuScripts.gml`, and `SelectionSummaryMenu.gml` still have no Notion-compatible markdown doc despite the CLAUDE.md convention (only `RulerPortraitScripts.md`, and now `StationScripts.md`/`CastleBonusHoverScripts.md`, exist) -- a pre-existing gap, not created by this pass but not closed by it either; flagging rather than silently expanding scope to backfill every library's docs unasked.

### Build

- Windows export version bumped `0.0.3.9` → `0.0.3.10` -- 4th-digit bump, same convention as every routine (non-explicitly-requested) pass; 3rd digit is reserved for when a version-scheme bump is explicitly requested, per the established convention (see the `0.0.2.51` → `0.0.3.0` entry).

## v0.0.3.9 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Every drop-down/panel menu (orders, castle garrison, unit selection) now uses the new drop-down sprite set with a title instead of a plain drawn rectangle. Enemy training buildings no longer show their queue or progress.

### Added

- **`DropDownMenuScripts.gml` (new file)** -- shared sprite-based rendering for every drop-down/panel menu, built on 3 new sprites (`sDropDownMenuTop`, `sDropDownMenuMiddle`, `sDropDowmMenuBottom` -- the bottom one's actual asset name has a pre-existing typo, "Dropdowm" not "DropDown"; used verbatim rather than renamed). Per the request:
  - **Title** (`sDropDownMenuTop`, single frame) -- centered text, never hoverable/clickable.
  - **Bottom-most option row** (`sDropDowmMenuBottom`, 2 frames) -- frame 0 normal, frame 1 on hover.
  - **Every option row above it** (`sDropDownMenuMiddle`, 2 frames) -- same frame 0/1 hover convention.
  - All three drawn at 2x scale, stacked seamlessly (title, then middle rows in creation order, then the bottom row last). Option text is left-aligned, 6 native px in from the row's left edge (scaled like everything else -- see file header for that native-vs-scaled call, since the request didn't specify). Exposes shared sizing/hit-test helpers (`DropDownMenuWidth`, `DropDownMenuTitleHeight`, `DropDownMenuRowHeight`, `DropDownMenuTotalHeight`, `DropDownMenuHitTest`) plus draw helpers (`DrawDropDownMenuTitle`, `DrawDropDownMenuRowBackground`, `DropDownMenuRowContentX`) that each menu's own row-content drawing builds on.

### Changed

- **`OrderMenu.gml`** -- title "Orders". Rebuilt on the shared helpers above; retired `ORDER_MENU_ITEM_HEIGHT`/`ORDER_MENU_WIDTH`/`ORDER_MENU_PADDING` (fully superseded, confirmed unused elsewhere) and the old hover highlight rectangle (now the sprite's own hover frame).
- **`CastleGarrisonMenu.gml`** -- title "Castle". Same rebuild; kept its own icon+name+right-aligned-count row content (that part didn't change), retired `CASTLE_MENU_ITEM_HEIGHT`/`CASTLE_MENU_WIDTH`/`CASTLE_MENU_PADDING` (`CASTLE_MENU_ICON_GAP`/`CASTLE_MENU_COUNT_MARGIN` are still meaningful and kept).
- **`SelectionSummaryMenu.gml`** -- title "Selected". Same rebuild; kept its own icon+name+right-aligned-value row content.

### Fixed

- **Enemy training buildings no longer show a queue or progress** -- `DrawTrainingQueueBars` (`TrainingScripts.gml`, the always-on world-space bar) now skips any `oTrainingBuildingParent` whose `team != TEAM.PLAYER`; this was previously flagged in its own doc comment as an intentional "not team-restricted... flag if enemy queues shouldn't be passively visible" -- now flipped per this request. `BuildingHoverExtras.Layout`'s `showQueueRow` (`BuildingHoverScripts.gml`, the hover-card queue row) now additionally requires `_team == TEAM.PLAYER` -- `_team` here is the HOVERED BUILDING's own team (confirmed via the call site, `BuildingHoverController.Step`, which passes `hoverTarget.team`), so this correctly hides the row only for enemy buildings, not for the player's own. Neither buildings' name/description/health/cost hover content changed -- only the queue-specific row/bar.

### Build

- Windows export version bumped `0.0.3.8` → `0.0.3.9` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.8 — 2026-07-12 (uncommitted — working tree only, not yet committed)

A new top-left panel appears whenever 2+ units are selected -- grouped by type at first, drilling down to individual units (and finally a single unit) as the player clicks through it. Also fixes a click-passthrough gap that would have broken it.

### Added

- **`SelectionSummaryMenu` (new file, `SelectionSummaryMenu.gml`)** -- a top-left panel (same corner `UnitSelectHoverController` uses for the single-unit case, and mutually exclusive with it) shown whenever `selectionController.selected` has 2+ units. Visual style/row layout deliberately reuses `CastleGarrisonMenu`'s macros (`CASTLE_MENU_*`) rather than redeclaring near-duplicates, per "similar visual to the castle dropdown." Unlike `OrderMenu`/`CastleGarrisonMenu`, there's no `Open()`/`Close()` -- it's a passive panel recomputed fresh every Step from the current selection, same architecture as `UnitSelectHoverController`.
  - **GROUPED mode** -- selection spans 2+ distinct unit types: one row per type (icon, name, "x#" count of how many of that type are selected).
  - **INDIVIDUAL mode** -- selection is 2+ units that all share ONE type: one row per actual unit instance (icon/name repeat per row; the row's value column shows that unit's current/max HP instead of a count, since "x#" doesn't mean anything per-unit).
  - **Hover** -- a grouped row shows the GENERAL unit hover card (`ShowUnitHoverCard` with no live instance -- max HP only, the same "no specific instance" treatment `UnitHoverExtras` already uses for the blueprint-UI/placed-training-building contexts), per the request: "no specific health value, so use max health." An individual row shows the DETAILED card (the real instance -- exact remaining HP), identical to `UnitSelectHoverController`'s single-selected treatment. Drawn immediately to the panel's right.
  - **Click** -- a grouped row narrows `selectionController.selected` down to the CURRENTLY SELECTED units of that type only (not every unit of that type on the map -- the row's own count is exactly that subset, so narrowing to it keeps things consistent), which flips the panel into individual mode next frame. An individual row replaces the selection with JUST that one unit, which hides this panel and shows `UnitSelectHoverController`'s single-unit card instead -- with no one-frame lag, since `SelectionSummaryMenu.Step()` runs before `unitSelectHoverController.Step()` in the same `Step` event.

### Fixed

- **Click-passthrough gap**: neither `CastleGarrisonMenu` nor the new `SelectionSummaryMenu` suppressed `oUnitControl`'s room-space left-click handling, so clicking a row would ALSO be read as a world click by the castle/training/blueprint/drag-select logic later in the same `Step` -- for `SelectionSummaryMenu` this would have immediately clobbered whatever selection the row click just set (a drag-select starting on the same press would overwrite it moments later on release). Both menus gained a `consumedClick` flag, checked by `oUnitControl/Step_0.gml` before its left-click block runs. Scoped differently per menu's own behavior: `CastleGarrisonMenu.consumedClick` is true for ANY left click while it's open (it's an explicit, modal-ish dropdown the player opened -- even a dismiss-elsewhere click shouldn't also act on the world); `SelectionSummaryMenu.consumedClick` is true ONLY when a click lands ON a row (it's a passive, always-visible-when-applicable panel -- clicks elsewhere must keep working normally, e.g. picking a different unit or starting a fresh drag). This was a latent gap in `CastleGarrisonMenu` since last pass too (deploying doesn't touch selection, so it never surfaced there) -- fixed for both while touching this code path.

### Build

- Windows export version bumped `0.0.3.7` → `0.0.3.8` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.7 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Stationing and deploying now cost gold, and the castle garrison dropdown's rows are clickable -- clicking one deploys a unit of that type back onto the battlefield.

### Added

- **Click-to-deploy on the castle garrison dropdown** (`CastleGarrisonMenu.gml`) -- clicking a row now deploys ONE unit of that row's type via the new `DeployStationedUnit(_team, _unitType)` (`StationScripts.gml`). `CastleGarrisonRow` gained a `unitType` field (undefined on the "--" placeholder row, so clicking it is a safe no-op); `CastleGarrisonMenu.Update()` now returns the clicked row's `unitType` (mirrors `OrderMenu.Update()`'s "returns what was clicked" convention) and gained the same hover-highlight `Draw()` treatment `OrderMenu` already has. Wired from `oUnitControl/Step_0.gml`.
- **`DeployStationedUnit(_team, _unitType)`** (new, `StationScripts.gml`) -- charges `GetUnitStationCost` (below) via `Purchase` BEFORE anything else happens, so an unaffordable deploy is a pure no-op. If affordable: finds one live `oUnitStationed` of that type belonging to `_team` (arbitrary pick if more than one is garrisoned -- see Flagged below), spawns a fresh live instance just outside the team's castle (`StationDeploySpawnPoint`, below), overrides its team (same override pattern `TrainingSpawnUnit`/`StationSpawnDirectly` use, including the stale-`guardRect` correction), swaps in the stationed unit's preserved `UnitDataBlock` (so `damageTaken`/`statusEffects` survive the round trip), and re-runs `UnitApplyDefinition` -- the exact redeploy sequence already documented on `UnitDataBlock` (`UnitScripts.gml`). Destroys the `oUnitStationed`. Defaults to `"guard"` (the fsm's own starting state, untouched here).
- **`GetUnitStationCost(_unitType)`** (new, `StationScripts.gml`) -- wraps `UnitDefinition.stationCost` (a flat gold amount that already existed as unit-hover-card display data, added 2026-07-11 from the "Project Azurite Data Sheets") into a spendable `Cost` struct (`Economy.gml`). Shared by both directions -- station and deploy are priced identically, per that field's own doc comment ("Gold cost to station/deploy this unit type").
- **`StationDeploySpawnPoint(_castle)`** (new, `StationScripts.gml`) -- a point just outside the castle's front edge (same side `CastleFrontEdgePoint` picks) with a little random vertical jitter, mirroring `TrainingGetSpawnPoint`'s "just outside, don't stack back-to-back spawns" reasoning.

### Changed

- **The `"station"` order now actually costs gold** (`OrderWiring.gml`) -- charges each unit's `GetUnitStationCost` via `Purchase` before dispatching it into the `"station"` FSM state; a unit that can't be afforded is simply skipped (not sent marching, nothing spent for it).
- **Issuing `"station"` to multiple selected units sorts them CHEAPEST FIRST** before the affordability pass above, per the request: "If multiple units are selected to station, and the player can't afford to station all of them... selecting the cheapest options to station, and do as many as the player can afford." The affordability loop skips (rather than stops at) the first unaffordable unit and keeps checking the rest -- see Flagged below for why.
- **`UnitDefinition.stationCost`'s doc comment** (`UnitDefinitions.gml`) updated -- it previously said this field was purely informational display data that "nothing deducts gold or gates a station action on it"; that's no longer true as of this pass, so the comment now points at `GetUnitStationCost`/`DeployStationedUnit`/the `"station"` order instead of asserting it's inert.

### Flagged

- **The cheapest-first affordability loop skips-and-continues rather than stopping at the first unaffordable unit.** Today's `stationCost` is gold-only, so once the cheapest remaining unit can't be afforded, nothing pricier after it can either -- stopping outright would behave identically right now. Chose skip-and-continue anyway so this stays correct if `stationCost` ever grows into a multi-resource `Cost` (e.g. a unit that's cheap in gold but expensive in iron shouldn't necessarily block a later unit that's expensive in gold but free in iron).
- **`DeployStationedUnit` picks whichever matching `oUnitStationed` instance is found first** when more than one of the same type is garrisoned -- GameMaker's `with` iteration order isn't a meaningful "oldest"/"healthiest" pick, just "any one of them." A request that cares which specific one gets redeployed (e.g. always the least-damaged) would need a different selection rule than what's built here.
- **A deployed unit defaults to `"guard"`** (the fsm's own built-in starting state, untouched by `DeployStationedUnit`) rather than any more specific order -- a deployed unit has no training-building context to default to `"defend"` against the way `TrainingSpawnUnit`'s units do. Judgment call, not an explicit spec answer.
- **`StationDeploySpawnPoint` re-derives which side of the castle is "front"** instead of calling `CastleFrontEdgePoint` -- that function clamps toward a caller position (there's no unit marching toward the castle here, just a castle to spawn just outside of) and doesn't expose which side it picked for the "push further outward" math to reuse. Small (~10-line) duplication of that function's side-selection logic; flagging in case a future change to one needs to be mirrored in the other.

### Build

- Windows export version bumped `0.0.3.6` → `0.0.3.7` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.6 — 2026-07-12 (uncommitted — working tree only, not yet committed)

Stationing and deploying units: a new "station" order walks a unit home and garrisons it invisibly at the castle; training buildings on an inside plot now garrison units directly instead of spawning them live; and a new dropdown on the castle wall lists what's currently garrisoned.

### Added

- **"station" order + `Station_Enter`/`Station_Step`** (new file, `UnitStateStation.gml`, registered as a new `"station"` state on every unit's `fsm`, `oUnitParent/Create_0.gml`) -- walks the unit to its OWN team's castle front edge (`CastleFrontEdgePoint`, `CastleScripts.gml` -- the same point `siege` already marches units toward against the ENEMY castle; there's no separate literal "gate" concept anywhere in the project, see Flagged below), same longer obstacle-avoidance feeler `Siege_Step`'s advance phase uses (`120`, vs. the default `80`) since this can be just as long a march. On arrival (within `STATION_GATE_REACH`, `12`px, mirrors `DEFEND_WAYPOINT_REACH`), hands off to `UnitBecomeStationed`.
- **`StationScripts.gml` (new file)**:
  - `UnitBecomeStationed(_unit)` -- creates an `oUnitStationed` at the unit's team's castle corner, hands it the unit's EXISTING `UnitDataBlock` as-is (preserving `damageTaken`/`statusEffects`/`unitType` per unit, not just an aggregate count -- per the pre-existing doc comment on `UnitDataBlock`, `UnitScripts.gml`, which already specified this exact design), then destroys the live unit directly (not through `ApplyDamage` -- confirmed `STRATEGIC_XP_LOSE_UNIT` only fires from there and `oUnitParent` has no Destroy event, so this can't misfire a "lost a unit" penalty).
  - `StationCastleCorner(_castle)` -- the fixed storage point, `(bbox_left, bbox_top)`.
  - `StationSpawnDirectly(_team, _unitType)` -- builds a stationed unit for `_team` without ever putting a live one on the battlefield; used by the inside-plot training branch below.
- **`oUnitStationed` (new object)** -- no sprite, `visible = false`, no Step/Draw, holds nothing but `team` + the handed-over `unitData`. Per the request: "Stationed units (for now) just need to be stored at the corner of the castle with no rendering."
- **Training buildings on an inside plot now build stationed units directly** instead of live ones (`TrainingSpawnUnit`, `TrainingScripts.gml`, new early branch checking `_building.inside`, calling `StationSpawnDirectly`) -- per the request: "Any training buildings that builds a unit when on an inside plot will immediately build a stationed unit instead." Deliberately does NOT award `STRATEGIC_XP_FIRST_DEPLOYMENT` for this branch (see Flagged below).
  - `_building.inside` is new: `TryPlaceBlueprint` (`BlueprintScripts.gml`) now copies the target plot's own `inside` flag onto the spawned building instance. `oBuildingParent/Create_0.gml` also gained a safe `inside = false` default (same "Create sets a placeholder" pattern already used for `maxHealth`/`damageTaken` there) so a building placed directly in the room editor -- never touching `TryPlaceBlueprint` -- doesn't crash `TrainingSpawnUnit`'s new check on an undefined variable.
- **Castle garrison dropdown** (new file, `CastleGarrisonMenu.gml`) -- left-clicking the player's own castle wall (`oPlayerCastle`, excluding inside plots -- see `oUnitControl/Step_0.gml`) opens a GUI-space dropdown listing every stationed unit type: icon, name, and "x#" count, left to right, one row per type; shows a single "--" row if nothing's garrisoned. Structurally mirrors `OrderMenu.gml` (`Open`/`Close`/`Update`/`Draw`, screen-edge containment) but needed its own row renderer for the icon+name+count layout. View-only for now (see Flagged below). Wired into `oUnitControl` (`Create_0.gml`/`Step_0.gml`/`Draw_64.gml`).

### Changed

- **`OrderWiring.gml`'s `"station"` order** -- replaced its intentional no-op stub (left in place since stationing wasn't designed yet) with real dispatch: `fsm.ChangeState("station")` per selected unit, same dead-unit-guard pattern as `"defend"`/`"attack"`/`"siege"`.

### Flagged

- **"Castle gate" doesn't exist as a literal concept anywhere in the code** (confirmed via project-wide search) -- reused `CastleFrontEdgePoint` as the walk-target, the same point `siege` already uses against the enemy castle. Worth noting `oUnitParent/Create_0.gml` already had a comment anticipating almost this exact wording ("whatever redeploys a stationed unit back out through the castle gate"), which supports the interpretation but isn't a confirmed spec answer.
- **This pass adds a new state (`"station"`) to the same `fsm` chain as `guard`/`defend`/`combat`/`attack`/`siege`** (`oUnitParent/Create_0.gml`) -- per CLAUDE.md, flagging any touch to that wiring. The change is purely additive (a new `.AddState(...)` appended to the existing chain); no other state's wiring was touched.
- **`oUnitStationed`'s storage position** (`StationCastleCorner`) is just the castle's `(bbox_left, bbox_top)` corner -- arbitrary, since the object never renders. Only matters if a future redeploy feature uses it as a spawn point.
- **Inside-plot-trained (auto-stationed) units skip `STRATEGIC_XP_FIRST_DEPLOYMENT`** -- reasoning: that XP is for a unit's first appearance ON the battlefield, which a directly-stationed unit never has. Judgment call, not an explicit spec answer -- easy to reverse if "deployment" was meant more loosely.
- **The garrison dropdown is view-only and player-castle-only** -- the request described the listing but not an interaction, so clicking a row just dismisses the menu like clicking anywhere else (no redeploy action yet); restricted to `oPlayerCastle` since nothing asked for an enemy-castle equivalent. One related edge case: clicking the castle wall again WHILE the dropdown is already open dismisses-then-immediately-reopens it that same frame rather than toggling closed (same class of same-frame double-click-processing `OrderMenu`'s own right-click-reopen edge case already has) -- clicking anywhere else does correctly dismiss it.

### Build

- Windows export version bumped `0.0.3.5` → `0.0.3.6` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.5 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Follow-up polish on last pass's training-building hover work: correct icon, a truly centered progress bar, and the paired unit card now always sits on the building card's right with its training cost always shown.

### Changed

- **Queue row icon** (`BuildingHoverExtras`, `BuildingHoverScripts.gml`): now uses `UnitDefinition.icon` (the small inline icon, e.g. `sPeasantIcon`, 8x8 middle-center anchored) instead of `smallSprite` (the bigger, bottom-anchored Item/Unit Window sprite) -- was `smallSprite` last pass, corrected per request. This also fixes an unflagged bug from that pass: `smallSprite`'s bottom-center anchor needed a vertical re-centering offset (same as the icon row's `itemIconOffsetY`) that the queue row never applied, so it would have drawn slightly off-center; `icon`'s middle-center anchor needs no such offset.
- **Queue progress bar is now centered on the card's full width**, not sized around the time-remaining text. Its left edge sits a fixed offset in from the card's left edge (margin + icon + gap + count text + gap); its right edge now mirrors that SAME offset in from the card's right edge, instead of being positioned to leave just enough room for the time text. The time-remaining text now trails the bar's right edge (switched from right-aligned-on-the-row to left-aligned-after-the-bar) rather than pinning to the row's fixed right edge.
- **The training building's paired unit card now always sits on the building card's right**, regardless of cursor position -- `PositionHoverCardPair` (`HoverCardScripts.gml`) gained a `_secondaryAlwaysRight` parameter (default `false`, every other caller unaffected); `BuildingHoverController.Step` passes `true`. Tradeoff worth flagging: the overall pair still anchors away from the cursor and clamps to the screen edges as before, but when the cursor's in the right half of the screen, the BUILDING card is no longer guaranteed nearest the cursor in this mode (the unit card is, since it's forced to the building card's right while the pair's right edge still anchors near the cursor) -- accepted since "always on the right" was explicit.
- **The paired unit card's cost-to-produce row is now always shown** for placed training buildings (was blueprint-only). Even though the building itself is already placed, the unit's training cost is still directly relevant -- it's exactly what `TrainingTryQueueUnit` (`TrainingScripts.gml`) will spend the next time a unit is queued.

### Build

- Windows export version bumped `0.0.3.4` → `0.0.3.5` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.4 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Training buildings now show an always-on queue progress bar above the world, and switch to a second sprite frame while actively training.

### Added

- **`WorldToGui(_x, _y)`** (new, `CameraScripts.gml`) -- converts a room-space coordinate to its current on-screen GUI-space equivalent, accounting for view camera 0's pan position. Needed for any room-space element that has to be drawn from a Draw GUI event so it renders above every room-space Draw call (units, particles, other buildings) regardless of instance depth -- Draw GUI always runs after every room-layer Draw event.
- **`DrawTrainingQueueBars()`** (new, `TrainingScripts.gml`, called once per Draw GUI event from `oUnitControl/Draw_64.gml`) -- a 1px-tall (exactly 1 on-screen pixel, independent of camera zoom) bar drawn 2px below every live training building's `bbox_bottom`, spanning its bbox width. Black background, filled left-to-right in `HOVER_CARD_TEXT_COLOR` by `trainProgress / trainTime` -- same fill convention as last pass's hover-card queue row, just always-on instead of hover-gated, so there's a signal even when no hover card is showing. Routed through `WorldToGui` and drawn from Draw GUI per the request, so it stays on top of units/particles/other buildings regardless of world-space depth. Not team-restricted -- matches `BuildingHoverController`'s existing "informational, not ownership-gated" precedent; flag if enemy queues shouldn't be passively visible like this.

### Changed

- **`TrainingUpdateQueue`** (`TrainingScripts.gml`) now sets the building's `image_index` -- frame 1 while `trainQueue > 0`, frame 0 otherwise. Placeholder ambient signal ahead of a real training animation, per the request; every training sprite gets pointed at frame 1 regardless of whether it's actually been authored with a second frame yet (GameMaker wraps `image_index` via `mod(image_index, image_number)` for default instance drawing, so this is harmless on sprites that don't have one).

### Deferred (per request)

- **Per-building training particle effects** -- explicitly held off; each training building will eventually get its own distinct effect, planned as a separate pass.

### Build

- Windows export version bumped `0.0.3.3` → `0.0.3.4` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.3 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Fixed a pre-existing missing-argument bug in the UI bar's background draws; placed training buildings now show a live queue/progress readout in their hover card.

### Fixed

- **`oUnitControl/Draw_64.gml`'s `sMainUIBarBottom`/`sUISpellsCloth` `draw_sprite_ext` calls were missing their rotation argument** (8 args where 9 are required) -- flagged last pass, fixed now. Added `0` for `rot` to both, matching the already-correct `sRulerBar` call on the line above them.

### Added

- **Placed training buildings now show a queue row in their hover card**, in the same bottom slot the blueprint cost row occupies (`BuildingHoverExtras`, `BuildingHoverScripts.gml`) -- the trained unit's small icon + how many are currently queued (bottom-left), a progress bar toward the next completion (black background, filled in `HOVER_CARD_TEXT_COLOR` -- a plain drawn rectangle, not a sprite/Scribble element), and the seconds remaining until that completion (right edge, ceil'd, "-" when nothing's queued). Reads `trainQueue`/`trainProgress`/`trainTime` straight off the live instance. Mutually exclusive with the blueprint cost row (one's blueprint-only, the other's placed-training-only) -- resource buildings and blueprints are unaffected.

### Investigated, not changed

- **Unit-training queuing already existed** (`TrainingScripts.gml`: `TrainingTryQueueUnit`/`TrainingUpdateQueue`, wired since earlier sessions) -- confirmed it already does everything the request asked for: queuing spends the cost immediately (`Purchase(_building.trainCost, _team)` inside `TrainingTryQueueUnit`, before the queue increments), and both the per-type cap (`TrainingTypeLimit`) and the army-wide cap (`global.armyLimit`) are checked against existing units PLUS everything queued across EVERY training building the team owns (`TrainingQueuedCountForType`/`TrainingQueuedCountAll`), not just the building being clicked. Nothing new needed here.

### Build

- Windows export version bumped `0.0.3.2` → `0.0.3.3` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.2 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Game-wide text now matches the hover-data color; the resource bar switched to its dedicated font; and the first animated ruler portrait (Conelius) is live on the UI bar.

### Added

- **`RulerPortraitScripts.gml` (new file)** -- animated ruler portrait system. A ruler's portrait is a single sprite strip; each animation is a data-described contiguous frame range (`RulerAnimationDefinition`: name, startIndex, frameCount, startFacing, endFacing, isIdle), grouped into one `RulerPortraitDefinition` per ruler (sprite + animation list + playback speed), registered by string key (`RegisterRulerPortrait`/`GetRulerPortraitDefinition`/`RegisterAllRulerPortraits`) the same way `Order`/`UnitDefinition`/`BuildingDefinition` are. `RulerPortraitController` is the live per-instance state machine: plays a clip to completion, rests on whichever idle frame (Left/Right) matches the clip's end facing for a random 2-5 sec wait, then picks a new clip at random from whatever's legal to start given the current facing -- exactly the behavior requested, and fully data-driven so a future ruler needs only a new definition, not new controller code.
  - **`FACING` enum** (new, `Enumerators.gml`) -- `LEFT`/`RIGHT`, used by animation definitions to gate which clips can start from which facing.
  - **Conelius registered** (`sConeliusPortrait`, 30 frames / 6 clips: Idle Left, Blink Left to Right, Idle Right, Blink Right, Mustache Wiggle, Looking Around) -- only "Blink Left to Right" starts from Left, so from his Idle Left resting pose the only thing that can ever play is that one clip; everything else waits for "Looking Around" to bring him back around to Left first, matching the request's example exactly.
  - **`global.selectedRuler`** (new global, set in `oGameControl`'s Create event) -- hardcoded to `"conelius"` for now, no character-select flow exists yet.
  - Wired into `oUnitControl`: `rulerPortraitController` created in `Create_0.gml`, stepped in `Step_0.gml`, drawn in `Draw_64.gml` at `(27, 1080)` scale 2x (bottom-left anchored, matching the portrait sprite's own origin), on top of the existing `sRulerBar` background sprite.
  - **`RulerPortraitScripts.md` (new file, alongside the script)** -- Notion-compatible API doc, per CLAUDE.md's standing per-library documentation requirement. First library this session to actually get one; every earlier library still lacks this doc -- flagging the backlog, not backfilling it here unasked.

### Changed

- **Game text now matches `HOVER_CARD_TEXT_COLOR`** (the tan `F1DEB6` every hover-data card already uses) instead of `c_white`, in: the resource bar's counts (`DrawResourceBar`, `ResourceUIScripts.gml`), the order menu's item labels (`OrderMenu.gml`), a blueprint slot's stack-count number (`BlueprintScripts.gml`), and the "Select target for: ..." targeting-cursor label (`UnitSelection.gml`). Per this session's scoping discussion: the AI debug overlay (`oAIControl`'s "AI State:" text), the Fate Engine drum test harness, and the pre-alpha disclaimer splash screen were deliberately left alone -- dev-only or a special-case splash screen, not ongoing player-facing UI.
- **`DrawResourceBar`** (`ResourceUIScripts.gml`) now draws its resource-count text in `fntResource` instead of the default GML font -- explicitly requested. Resets to the default font (`draw_set_font(-1)`) after, since nothing else in this project calls `draw_set_font` and a lingering font change would otherwise leak into every draw_text call later in the same Draw GUI event.

### Noted, not acted on

- **`oUnitControl/Draw_64.gml` line 2, `draw_sprite_ext(sMainUIBarBottom,0,0,1080,2,2,c_white,1);`, appears to be missing its rotation argument** -- 8 arguments where `draw_sprite_ext` needs 9 (sprite, subimg, x, y, xscale, yscale, rot, colour, alpha). As written, `c_white` lands in the `rot` slot and `1` lands in `colour`, with `alpha` unsupplied. Stumbled onto this while wiring the ruler portrait draw call in the same file -- pre-existing, unrelated to this pass's work, not fixed here per CLAUDE.md ("don't refactor unrelated legacy code unless asked"). Worth a look; if the bottom bar renders correctly today despite this, GameMaker may be more lenient about missing trailing built-in-function arguments than expected.

### Build

- Windows export version bumped `0.0.3.1` → `0.0.3.2` -- 4th-digit bump, same convention as every non-milestone pass.

## v0.0.3.1 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Corrections from the nightly codebase scan (`NIGHTLY_REVIEW_2026-07-09.md`) -- one real crash fixed, one flagged finding turned out to be stale/inaccurate and was left alone, two trivial cleanups applied.

### Fixed

- **Selected units weren't pruned when they died, crashing the next Step or the next order issued to them** (§3.1, critical). `ApplyDamage` (`UnitCombatHelpers.gml`) destroys units directly with no hook back into `SelectionController.selected`, so a selected unit dying in combat (normal RTS occurrence) would crash on the very next Step via `UnitSelectHoverController.Step` reading the freed instance, or immediately on issuing any order (guard/defend/attack/siege) to a selection containing it.
  - **`SelectionController.PruneDeadSelected()`** (new, `UnitSelection.gml`) -- filters dead instances out of `selected`. Called once per Step from `oUnitControl/Step_0.gml`, as the very first line, before anything else that frame reads `selected` (order menu, `IssueOrder`, the unit-select hover card).
  - **`instance_exists` guards added inside the order-dispatch loops themselves** -- `Order`'s default `onIssue` (`UnitSelection.gml`) and the "defend"/"attack"/"siege" `onIssue` callbacks (`OrderWiring.gml`). This covers `IssueOrderToUnits`'s OTHER caller (the AI controller), which doesn't go through `SelectionController`/`PruneDeadSelected` at all, and closes the gap for the instant between the per-Step prune and the callback actually running.
  - **FLAG per CLAUDE.md ("flag before touching FSM/state wiring for guard, defend, combat, attack, siege"):** this touches the order-dispatch loops that call `fsm.ChangeState(...)` for guard/defend/attack/siege. No state's `Enter`/`Step`/`Exit` logic itself was touched -- only an early-`continue` guard added around each loop's per-unit body -- but it's adjacent enough to the load-bearing FSM wiring to call out explicitly rather than let it pass silently.
- **`oUnitParent/Draw_0.gml` used `=` instead of `==`** (§3.3, minor; open since `CODE_REVIEW_2026-07-01.md`). `if mask_index = sM_UnitMask{` → `if mask_index == sM_UnitMask{`. Legal GML either way (bare `=` in a condition reads as equality), behavior was already correct -- purely a readability/consistency fix, now matches every other comparison in the codebase.
- **`oUnitParent/Create_0.gml` set two dead fields, `pos` and `moveVec`** (§3.4, minor). Removed both lines. Re-confirmed via project-wide search that nothing reads `unit.pos` or `unit.moveVec` -- all real position/velocity state lives on `unit.agent.pos` (the `SteeringAgent`); these were a future-reader trap, not read anywhere.

### Investigated, not fixed

- **§3.2 (moderate), `oBuildingPlot`'s `image_index`:** the nightly report describes this as a stale-Object-Property-default bug in `Create_0.gml` with no Step event to correct it. That description doesn't match the current code -- `oBuildingPlot/Create_0.gml` is empty, and `image_index = (!blocked) + (!inside)` lives in `Step_0.gml`, recomputing every frame (confirmed against this file's own history: this has been the case since v0.0.2.20, 2026-07-05). The report's finding here appears to be inaccurate/stale, so no fix was made against it.
  - The REAL, still-open issue in this formula was already identified and investigated on 2026-07-05 (see that date's patch notes, "Investigated (not yet fixed -- pending design confirmation)"): the formula only produces 3 output values for 4 possible `(blocked, inside)` combinations, so an unblocked INSIDE plot and a blocked OUTSIDE plot render identically. That was deliberately left unfixed pending a design answer for what `sPlot`'s 3 frames are actually meant to represent -- still true today, still needs that input before it can be touched.

### Noted, not acted on (style only, not counted among the report's "4 potential problems")

- `scripts/Economy/Economy.gml` mixes parenthesis-less `if` conditions with parenthesized ones used everywhere else in the file. Not touched -- fixing pure style on working legacy code wasn't requested.
- `scripts/Math/Math.gml` line 409, `ShapeRect.getCenter()` is camelCase against every other static method's PascalCase convention (should probably be `GetCenter()`). Not touched for the same reason -- flagging here in case it's worth a deliberate rename pass later.
- The nightly report separately flags that `NIGHTLY_REVIEW_2026-07-07.md` and `-08.md` are both missing despite a "Review 2026-07-07 Safety Commit" existing in git history -- suggests the scheduled task didn't complete a full run on at least one of those two nights. Nothing to fix in the codebase; surfacing in case the scheduling harness itself needs a look.

### Build

- Windows export version bumped `0.0.3.0` → `0.0.3.1` — 4th-digit bump, same convention as every routine fix pass.

## v0.0.3.0 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Version bump only — player-facing patch notes requested, covering everything since v0.0.2.0. Per the 3rd-digit-bump-on-requested-patch-notes convention (see v0.0.1.0/v0.0.2.10's Build notes).

### Added

- **`PUBLIC_PATCH_NOTES.md` (new file, repo root)** — the launch-title-facing summary covering v0.0.2.0 through v0.0.2.51, organized by player-visible category (Build & Economy, Combat, The Computer Opponent, Interface & Info) rather than chronologically. Written from this file's existing entries; every internal system/function/asset name was translated to its player-facing effect, per CLAUDE.md's public-notes convention. Purely additive/no-op for the game itself.

### Build

- Windows export version bumped `0.0.2.51` → `0.0.3.0` — 3rd-digit bump (patch notes explicitly requested this time, unlike the routine 4th-digit bumps every prior entry back to v0.0.2.1 used).

## v0.0.2.51 — 2026-07-11 (uncommitted — working tree only, not yet committed)

New unit hover card -- a second, paired card showing a trained unit type's own stats/passives, alongside a training building's blueprint/placed-building card, or standalone in the top-left corner when a single unit is selected.

### Added

- **`UnitHoverScripts.gml` (new file)** -- the unit hover card, shown in 3 contexts:
  - Paired with a training building's blueprint-UI card (`BlueprintController.UpdateHover`) -- max HP only, WITH a cost-to-produce row along the bottom.
  - Paired with a training building's placed-instance hover card (`BuildingHoverController.Step`) -- max HP only, no cost row (nothing left to produce).
  - Standalone, fixed in the GUI's top-left corner, whenever exactly one unit is selected (new `UnitSelectHoverController`, wired into `oUnitControl`) -- shows that unit's own live remaining/max HP, no cost row, appears/disappears instantly with selection state (no dwell or fade -- it's tied to a deliberate player action, not a hover).
  - Layout (shared by all 3): the unit's full-size sprite (`UnitDefinition.sprites.idle`, NOT the smaller `smallSprite`) centered inside an `sHoverCardBuildingWindow`-sized box using the same bottom-anchor centering math as the existing Item/Unit Window; literal "HP: X" / "DMG: Y" text lines beside the box; the "Deployed Effect" passive description as the card's main body; and, in the card's usual flavor-text position, "Station/Deploy Cost: [gold icon]\<amount\>" followed by the "Stationed Effect" passive description -- rendered in the normal (non-italic) font rather than the usual italic flavor font, per the request.
- **`UnitDefinition.stationCost` field** (`UnitDefinitions.gml`) -- Gold cost to station/deploy each unit, per the "Project Azurite Data Sheets" (2026-07-03) column that was previously flagged as having no home in this struct. Real values supplied directly by the user this pass: Peasant 20, Bomb Goblin 15, Mud Golem 25, Soldier 30, Archer 15, Knight 50. Still purely display data for the hover card above -- nothing deducts gold or gates a station action on it yet (no station/deploy economy system exists).
- **`HoverCard.Show()` gained an optional trailing `_flavorFont` param** (`HoverCardScripts.gml`) -- defaults to the existing italic `HOVER_CARD_FLAVOR_FONT`, so every existing caller is unaffected; the unit hover card is the first to pass `HOVER_CARD_BODY_FONT` instead, repurposing the flavor window for non-italic content.
- **`PositionHoverCardPair(_mx, _my, _primaryCard, _secondaryCard, _cardGap)`** (`HoverCardScripts.gml`) -- positions a primary card and an optional paired secondary card as one anchored group: the quadrant-flip and screen-edge clamp are computed against their COMBINED width/height, per the request ("anchoring... should be in relation to both cards, not just the core building card"), rather than clamping each independently in a way that could separate them. The primary card always sits nearest the cursor; the secondary extends further away. Passing `noone` for the secondary reproduces the exact single-card math every hover controller used before this pass -- `BuildingHoverController.Step` and `BlueprintController.UpdateHover` both now route through this shared function instead of each keeping their own copy of the old anchor/clamp math.

### Assumptions / scope boundaries (flag if wrong)

- **"HP"/"DMG" are drawn as literal text labels**, not icons like `BuildingHoverExtras`' `sUIHeart`/`sUIHammer` -- the request explicitly wrote them as text ("written as HP and DMG").
- **The unit card's stat text is vertically centered against the image box**, and the box sits flush against the card's left margin (mirroring the building icon row's position) -- neither exact alignment was specified, flagging for a visual sanity check in-engine.
- **The gap between the two paired cards (`HOVER_CARD_PAIR_GAP`, 8px) matches the existing mouse-to-card gap** (`PLOT_HOVER_CURSOR_GAP`) by coincidence, not because they're the same concept -- kept as separate macros in case they should diverge later.
- **The single-unit-selected card ignores team** -- it shows for any selected unit regardless of TEAM.PLAYER/TEAM.ENEMY, matching this project's existing "hover data is informational, not ownership-gated" precedent (BuildingHoverController). Flag if enemy units shouldn't reveal this when selected (note: today only the player's own units are selectable at all, per `SelectionController(oUnitParent, TEAM.PLAYER)` in `oUnitControl/Create_0.gml`, so this is currently moot in practice).
- **Discovered while implementing this (unrelated to this feature): `UnitDefinitions.gml` currently sets `palette: sMudGolemPallete` for Mud Golem**, contradicting the v0.0.2.49/v0.0.2.50 patch notes' statement that "only Mud Golem doesn't have a Pallete sprite yet." The sprite now exists on disk and is already wired in -- the patch notes text is simply stale, no code fix needed. Flagging so the discrepancy doesn't cause confusion later.

### Build

- Windows export version bumped `0.0.2.50` → `0.0.2.51` -- 4th-digit bump, same convention as last time.

## v0.0.2.50 — 2026-07-11 (uncommitted — working tree only, not yet committed)

Fixed AI/enemy units not recoloring at all under `shPaletteSwap` (v0.0.2.49).

### Fixed

- **`PaletteSwapDrawUnit` (`PaletteSwapScripts.gml`) was reading the wrong elements out of `sprite_get_uvs()`'s return array.** The original code assumed an 8-element TL/TR/BR/BL corner layout and read indices `[4]`/`[5]` as the bottom-right UV corner. GameMaker's actual documented layout is a 4-element `(left, top, right, bottom)` rect at indices `[0..3]` — indices `[4..7]` are unrelated trim-crop metadata (pixels trimmed from the sprite's left/top edge, plus width/height fractions retained on the page), not a second corner. Since this project's palette sprites have no transparent margin to trim, `[4]`/`[5]` were simply `0` for every unit, collapsing `u_paletteFromRect`/`u_paletteToRect` to `(u0, v0, 0, 0)` — the shader was sampling far outside each sprite's actual region on the texture page, so the from-color read at every row was garbage and never matched a drawn pixel closely enough to trigger a swap. Net effect: the shader ran every frame but silently did nothing, which is why AI/enemy units looked completely unrecolored. Fixed by reading indices `[2]`/`[3]` (the real right/bottom) instead. Both `PaletteSwapScripts.gml` and `shPaletteSwap.fsh`'s header comment are corrected and now document the real `sprite_get_uvs()` layout so this isn't re-introduced.

### Assumptions / scope boundaries (flag if wrong)

- **`sSoldierPallete` and `sKnightPallete` use byte-for-byte identical source images** (same two PNG files, verified via direct pixel inspection) — Soldier and Knight currently recolor to the exact same replacement palette. This predates this fix and wasn't introduced by it; flagging in case it's an asset-authoring copy/paste that should actually be two distinct palettes.

### Build

- Windows export version bumped `0.0.2.49` → `0.0.2.50` — 4th-digit bump, same convention as last time.

## v0.0.2.49 — 2026-07-10 (uncommitted — working tree only, not yet committed)

New `shPaletteSwap` shader for team-based unit recoloring — AI opponent units draw with swapped colors, player units draw unedited.

### Added

- **`shPaletteSwap` (`shaders/shPaletteSwap/`)** — a search-based palette-swap shader. Each unit type gets its own 1px-wide, 2-frame "Pallete" sprite (matching this project's existing spelling of that asset name): frame 0 lists the unit's original swappable colors (one texel per row), frame 1 lists that same row's replacement. Per fragment, the shader linearly scans frame 0's rows for a close-enough color match (`distance() < u_tolerance`) against the current pixel and, if found, substitutes the same row's frame-1 color; unmatched pixels (skin tones, outlines, anything not explicitly listed) pass through unchanged. Both palette frames are bound as separate texture stages (`u_paletteFrom`/`u_paletteTo`, point-filtered, no repeat) rather than one shared image, since GameMaker doesn't guarantee sprite frames land adjacent on a texture page. Follows this project's existing `shDitherDissolve` conventions: PascalCase shader name, uniform/sampler handles resolved once (not per draw), a `show_debug_message` warning if any handle resolves invalid, and a fixed-constant-bound for-loop with an early `break` to work around GLSL ES 1.0's compile-time-constant loop-bound restriction (`MAX_PALETTE_ROWS = 16`, today's real max is 7 rows — Soldier/Knight).
- **`UnitDefinition.palette` field** (`UnitDefinitions.gml`) — optional, defaults to `undefined`. Set for 5 of 6 units: `sPeasantPallete`, `sArcherPallete`, `sSoldierPallete`, `sKnightPallete`, and Bomb Goblin's `sBombGolbinPallete` (see Assumptions below re: that spelling). Mud Golem has no Pallete sprite yet and is intentionally left unset. Copied onto the live instance by `UnitApplyDefinition` alongside every other stat.
- **`PaletteSwapScripts.gml` (new file)** — `PaletteSwapInit()` caches `shPaletteSwap`'s sampler/uniform handles once, wired into `oGameControl`'s Create event alongside the other `RegisterAll*()` calls. `PaletteSwapDrawUnit(_unit)` replaces the bare `draw_self()` in `oUnitParent/Draw_0.gml`: draws unshaded for `TEAM.PLAYER` units and any unit with no `palette` set, and binds `shPaletteSwap` (resolving each palette frame's actual sub-rectangle on its texture page via `sprite_get_uvs()`, not raw 0-1 UVs) for `TEAM.ENEMY` units that have one. Per the request, the player's units always draw with unedited/frame-0-aligned colors — no shader involved for that team at all.

### Assumptions / scope boundaries (flag if wrong)

- **`sBombGolbinPallete` is a pre-existing misspelled asset name** ("Golbin" not "Goblin") — used as-is, not renamed, since every other `sBombGoblin*` asset in the project uses the correct spelling. Flagged inline in `UnitDefinitions.gml` in case you want it renamed in-editor.
- **Assumes palette sprites are never stored rotated on their texture page** (GameMaker's "Allow sprite rotating" is off project-wide, per current settings) — `sprite_get_uvs()`'s corner extraction in `shPaletteSwap.fsh`'s comment block explains why a rotated palette sprite would sample the wrong axis and scramble colors. Flag if that setting ever changes.
- **`PALETTE_SWAP_TOLERANCE` (0.02) and `MAX_PALETTE_ROWS`/`PALETTE_SWAP_MAX_ROWS` (16)** are tunable constants (`PaletteSwapScripts.gml` and `shPaletteSwap.fsh` respectively) — the two row-count constants are kept in sync by convention only, no automatic check enforces it. Bump both together if a future unit needs more than 16 palette rows.
- **Mud Golem renders unshaded on both teams** until it gets a Pallete sprite — `PaletteSwapDrawUnit` degrades gracefully rather than crashing or defaulting to a placeholder recolor.

### Build

- Windows export version bumped `0.0.2.48` → `0.0.2.49` — 4th-digit bump, same convention as last time.

## v0.0.2.48 — 2026-07-09 (uncommitted — working tree only, not yet committed)

Four blueprint/building-hover follow-ups: unit small-sprite centering, instant + affordability-aware blueprint hover, a health row under production amount, and icons before resource/unit names.

### Changed

- **`BuildingHoverItemIcon` (`BuildingHoverScripts.gml`) now uses each unit's new `smallSprite`** (`UnitDefinition.smallSprite`, e.g. `sPeasantSmall`) instead of `sprites.idle` inside the Item/Unit Window. Since unit sprites are bottom-center anchored, `BuildingHoverExtras.Layout`/`Draw` now compute `itemIconOffsetY` (half the sprite's own height) and draw the icon that far below the window's center -- centers the sprite in the window regardless of its exact height. Resource icons (`sResourceIcons`, middle-center anchored) get no offset, unchanged.
- **Blueprint slot hover (`BlueprintController.UpdateHover`, `BlueprintScripts.gml`) now shows instantly** -- the dwell-delay gate (`PLOT_HOVER_DELAY_STEPS`) is gone for this context only; it still fades in/out over `PLOT_HOVER_FADE_STEPS` rather than popping. The `hoverTimer` field this used for the delay has been removed (served no other purpose). Plot hover and placed-building hover are UNCHANGED -- they still require the 1-second dwell.
- **Blueprint hover cost row now shows "[icon]Base (Discount)" per resource**, base price and the parenthesized discount price colored INDEPENDENTLY of each other (new `CostToScribbleTextWithDiscount`, `ResourceUIScripts.gml`): each renders red if `_team` can't currently afford that specific amount. The discount price additionally renders in dark gray (new `BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG`, `BlueprintScripts.gml`) whenever no currently open plot would actually grant the discount, overriding the red/default check -- it's purely informational in that case, not a real price. `GetBestAvailablePlacementCost(_team, _def)` (`BlueprintScripts.gml`) now also exposes `discountAvailable` alongside its existing `anyPlotAvailable`/`cost`, so this and the title-red check (below) don't have to re-scan plots separately. The card's own title (the building's name) still renders red if the building can't be placed ANYWHERE right now -- no open owned plot, or unaffordable even at the cheapest available price.
- **`GetPlacementCost` (`BlueprintScripts.gml`) refactored**, no behavior change -- its discount-eligibility check is now a shared `BuildingGetsDiscountOnPlot(_def, _plot)` function, reused by `GetBestAvailablePlacementCost` so the two can't drift out of sync.
- **New health row under the production-amount label.** `BuildingHoverHealthText(_def, _building, _isBlueprint)` (`BuildingHoverScripts.gml`) always returns a value (every building has `maxHealth`, unlike the production-amount line which only applies to resource buildings) -- blueprint hover shows the flat `maxHealth`, placed-building hover shows `remaining/max` via `GetCurrentHealth`. Rendered as a second line under the existing production-amount line (or the only line, for training buildings), each prefixed with its own icon: `sUIHammer` for production, `sUIHeart` for health.
- **Icons now precede resource/unit names.** `BuildingHoverDescriptionText`'s auto-generated body text ("Produces Wheat" / "Trains Peasant") now reads "Produces [icon]Wheat" / "Trains [icon]Peasant". New `UnitIconTag(_unitDef)` (`UnitDefinitions.gml`) mirrors `ResourceIconTag`'s shape but resolves via `sprite_get_name` since each unit has its own distinct icon sprite asset rather than one shared frame-strip.

### Added

- **`UnitDefinition` gained two new optional fields**, set for all 6 registered units: `icon` (the unit's small 8x8 `sXIcon` sprite, used by `UnitIconTag`) and `smallSprite` (the unit's ~16x20 bottom-anchored `sXSmall` sprite, used by `BuildingHoverItemIcon`).

### Assumptions / scope boundaries (flag if wrong)

- **`sPeasantIcon`'s origin is Top Left (0,0)**, while every other unit icon (`sArcherIcon`/`sBombGoblinIcon`/`sKnightIcon`/`sMudGolemIcon`/`sSoldierIcon`) and `sResourceIcons` are Middle Center. Scribble's inline sprite tags draw each sprite at its own origin, so `sPeasantIcon` will likely render visibly offset (shifted down-right by ~4px) relative to every other icon rendered the same way. Did NOT change the sprite asset myself -- flagging for you to fix `sPeasantIcon`'s origin in-editor if this is unintentional (looked like an oversight, not a deliberate choice).
- "Placeable anywhere" (for the title-red check) only looks at plots the hovering team already owns and can see today (unblocked, unoccupied) -- it doesn't account for plots that might unblock later, nor does it consider AI/enemy-side plots (irrelevant per-team by design).
- Health/production text still renders in the card's standard text color regardless of cost-row coloring -- only the cost row's own base/discount amounts and the title get the red/gray treatment.
- The discount price shown is always `GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION)` -- the flat 50% math -- not scoped to any specific plot; "is the discount available at all right now" and "what would the discount amount be" are deliberately kept separate, since the discount fraction itself doesn't vary by plot, only its availability does.

### Build

- Windows export version bumped `0.0.2.47` → `0.0.2.48` — 4th-digit bump, same convention as last time.

## v0.0.2.47 — 2026-07-08 (uncommitted — working tree only, not yet committed)

Added building hover tooltips in two contexts: hovering a placed building in-world, and hovering a filled blueprint slot in the Blueprint UI.

### Added

- **`HoverCard` (`HoverCardScripts.gml`) extended with two new optional trailing `Show()` params**, `_topContentHeight`/`_bottomContentHeight` (both default `0`, fully backward-compatible — `PlotHoverController`'s existing call site is unchanged and behaves identically). These reserve vertical space above/below the card's own body/flavor content so a specialized overlay can draw its own extra content without touching HoverCard's core layout math. Two new getters, `GetContentTopY()`/`GetContentBottomY()`, expose exactly where that extra content should be drawn.
- **`BuildingHoverScripts.gml` (new file)** — shared data-gathering and drawing logic for building hover tooltips, used by both contexts below via an `_isBlueprint` bool threaded through every function:
  - `BuildingHoverDescriptionText(_def)` — "Produces {Resource}" / "Trains {UnitName}" / falls back to `_def.description`.
  - `BuildingHoverTimerText(_def, _building, _isBlueprint)` — "{rate} /sec" or "{trainTime} sec".
  - `BuildingHoverResourceLimitText(_def, _building, _isBlueprint)` — blueprint shows the flat limit only; a placed building shows `"{limit - producedTotal}/{limit}"`, read off the **live instance** so a Distant-plot-boosted building shows its actual current cap, not the unboosted definition value.
  - `BuildingHoverItemIcon(_def)` — the produced resource's icon, or the trained unit's idle sprite.
  - `BuildingHoverExtras()` — owns the icon-row (Building Window, Timer, Item/Unit Window, left-to-right, Building Window top-left of the body) and, for blueprints only, a cost row along the bottom (`[Resource Icon][Amount]` repeating, via the existing `CostToScribbleText`). `Layout()` returns the `topContentHeight`/`bottomContentHeight` to hand to `HoverCard.Show()`; `Draw()` renders both rows anchored off the card's `GetContentTopY()`/`GetContentBottomY()`.
  - `BuildingHoverController()` — placed-building context: 5-second dwell + fade, same pattern as `PlotHoverController`, targeting `oBuildingParent` via `instance_position` validated against `GetBuildingDefinition`. Flavor text is sourced from `BuildingDefinition.description` — an existing field that was never actually displayed anywhere before this patch (confirmed via project-wide grep); reused instead of adding a redundant new field. Current `description` values are placeholder text pending the real flavor-text document.
- **`BlueprintController` (`BlueprintScripts.gml`) gained a second hover tooltip** for the Blueprint UI panel — `IsMouseOverPanel()`, `GetHoveredStackIndex()`, `UpdateHover()`, `DrawHoverCard()` — using the same `BuildingHoverExtras`/`HoverCard` pair in `_isBlueprint = true` mode: the resource-limit widget shows the flat limit (no partial), and the cost row appears along the bottom in place of a partial-limit readout.
- **Mutual-suppression fix** — `PlotHoverSuppressed()` and the new `BuildingHoverSuppressed()` both now also suppress while `_blueprintController.IsMouseOverPanel()` is true. The Blueprint UI panel is a GUI-space overlay drawn on top of the game world, so without this the mouse could sit over both a filled blueprint slot and a world-space plot/building underneath it at the same screen position, showing two tooltips simultaneously.

### Assumptions / scope boundaries (flag if wrong)

- Icon-row order is **Building Window (top-left), then Timer, then Item/Unit Window** — matches `sHoverCardBuildingWindow`'s original spec wording. (An earlier draft of this patch had the Building Window top-right instead; corrected same-day before shipping, per user catch.)
- Unit sprite dimensions inside the 28×28 Item/Unit Window are unverified in-engine — `AnimationLibrary.idle` is used directly with no explicit scale-to-fit; may need a follow-up pass if a trained unit's idle sprite doesn't fit cleanly.
- "Trains {UnitName}" uses the unit's singular name as-is (no pluralization logic).
- The blueprint cost row shows the **base** cost, not the plot-discounted cost — no plot is chosen yet at blueprint-hover time, so `GetPlacementCost` can't be evaluated.
- Building hover is currently **team-agnostic** — it works for both `TEAM.PLAYER` and `TEAM.ENEMY` buildings, not restricted to the player's own. Flag if enemy buildings should be hidden from this instead.
- The `PLOT_HOVER_*` prefix (delay/fade/cursor-gap macros) is now shared across three systems (plot, building, blueprint hover) — a naming misnomer at this point, called out in comments but not renamed to avoid an unrelated rename sweep.
- `BuildingDefinition.description`/flavor text is placeholder content until the real flavor-text document is provided.

### Build

- Windows export version bumped `0.0.2.46` → `0.0.2.47` — 4th-digit bump, same convention as last time.

## v0.0.2.46 — 2026-07-07 (uncommitted — working tree only, not yet committed)

Rewrote plot bonus text as a direct, color-coded bullet list, and fixed a color-blending bug that would have washed out the new colors.

### Fixed

- **`DrawCardTextWithShadow`'s main draw pass no longer blends with `HOVER_CARD_TEXT_COLOR`** (`HoverCardScripts.gml`) -- confirmed via `__shd_scribble.vsh` (`v_vColour = in_Colour * u_vColourBlend`) that Scribble's `.blend()` MULTIPLIES onto each glyph's own baked-in colour rather than overriding it. Blending with `HOVER_CARD_TEXT_COLOR` -- itself already the colour every glyph was baked with via `.starting_format()` -- was multiplying every glyph against itself, since v0.0.2.43/44: plain card text has been rendering slightly darker/more saturated than the actual F1DEB6 value the whole time. It also would have washed any inline colour-tagged text toward F1DEB6 instead of showing its real colour, which would have broken this patch's colored bonus text below. Now blends with `c_white` (the multiplicative identity) instead -- plain text renders at the exact starting colour, and colour-tagged runs render true. The shadow pass is unaffected (black multiplied by anything is still black).

### Changed

- **`PlotHoverBonusText` (`PlotHoverScripts.gml`) rewritten as a direct, color-coded bullet list**, per request -- a plain-color category header line (e.g. "Resource Buildings:") followed by one line per effect, each wrapped in a new Scribble inline colour tag: lime green for beneficial effects (every effect today), red reserved for detrimental ones (none exist yet). Two new macros, `PLOT_HOVER_GOOD_COLOR_TAG`/`PLOT_HOVER_BAD_COLOR_TAG`, hold the tag names (`"c_lime"`/`"c_red"` -- both pre-registered by Scribble, no `scribble_color_set()` needed). Distant plots show two category blocks (Resource Buildings, then All Buildings) since their bonus splits by building type; Castle and Exterior plots show one each. Example (Distant plot):
  ```
  Resource Buildings:
  -50% Build Cost
  +50% Production Yield
  All Buildings:
  +50% Health
  ```

### Assumptions / scope boundaries (flag if wrong)

- No "bad" (red) effect exists anywhere in the current bonus data, so `PLOT_HOVER_BAD_COLOR_TAG` is unused -- kept as the documented convention for whenever one exists (e.g. if Distant plots' "greater exposure to attack" flavor line ever becomes a real mechanical penalty).
- The blend-multiply fix changes the exact on-screen shade of EVERY existing hover card's plain text (name/body/flavor), not just the new colored bonus lines -- a visual change beyond what was asked, but necessary for the requested colors to render correctly at all. Flagging in case the previous (slightly darker) shade was actually preferred.

### Build

- Windows export version bumped `0.0.2.45` → `0.0.2.46` — 4th-digit bump, same convention as last time.

## v0.0.2.45 — 2026-07-07 (uncommitted — working tree only, not yet committed)

Centered hover card titles, and made the plot placement bonus system (previously only described in hover-card flavor text) actually real.

### Changed

- **Hover card titles are now horizontally centered** (`HoverCardScripts.gml`) -- `nameText`'s Scribble alignment changed from `fa_left` to `fa_center` (constructor AND `Show()` -- both needed the same change; caught a mismatch between them during verification), and its draw position now targets the card's horizontal center instead of `HOVER_CARD_NAME_OFFSET_X`. Body and flavor text are unchanged, still left-aligned, per explicit request. `HOVER_CARD_NAME_OFFSET_X` is now unused -- kept in case a future specialized card variant wants the old left-anchor behavior; flag if it should just be deleted.

### Added

- **Plot placement bonuses are now real**, not just described in hover text -- realizes the split `oOuterPlotSpawner`'s header comment already stated as intended:
  - `GetPlacementCost(_def, _plot)` (new, `BlueprintScripts.gml`): resource buildings placed on an OUTSIDE plot (Exterior or Distant, `_plot.inside == false`) cost 50% less; training buildings placed on a CASTLE plot (`_plot.inside == true`) cost 50% less. `TryPlaceBlueprint` now charges/checks affordability against this instead of `_def.cost` directly.
  - `GetDiscountedCost(_cost, _fraction)` (new, `Economy.gml`): returns a new `Cost` with every resource field scaled by `(1 - _fraction)` and rounded to the nearest whole unit (resources are whole-integer-only in this project).
  - `ApplyPlotBonuses(_building, _plot)` (new, `BuildingDefinitions.gml`): any building placed on a Distant ("far") plot gets +50% `maxHealth`; production (resource) buildings there ALSO get +50% `resourceLimit`. Training buildings never have a `resourceLimit` field to begin with, so the "health only for training buildings" rule falls out naturally without an explicit building-type check. Called from `TryPlaceBlueprint` right after the building instance is created.
  - `PlotHoverBonusText` (`PlotHoverScripts.gml`) now states the real numbers (e.g. "Training buildings cost 50% less to place here.") instead of the previous qualitative-only wording, which had explicitly flagged itself as "overpromising before it's real."

### Assumptions / scope boundaries (flag if wrong)

- Discounted costs round to the nearest whole unit (`round()`, not `floor()`/`ceil()`) -- not specified by the request. At current cost values (all >= 8 per resource) this never rounds to 0.
- A building is assumed to be either a resource building OR a training building, never both -- true for every `BuildingDefinition` registered today, so no stacking/precedence logic was written for a building that's somehow both.
- `AI_FindEmptyOwnedPlot` (`AIControl.gml`) still grabs the first unblocked/unoccupied plot with no preference for the type of bonus it grants -- its doc comment previously said no such bonus system existed yet; that's no longer true, so the comment was corrected to instead flag this as a real (if minor) AI inefficiency. Not fixed here -- teaching the AI to seek out the best plot for a given building type was out of scope for "set up those bonuses."
- No UI currently displays the discounted cost before placement (the Blueprint panel only shows the building's icon, not its price) -- the discount is real and charged correctly, but a player has no in-UI way to see the price difference yet.

### Build

- Windows export version bumped `0.0.2.44` → `0.0.2.45` — 4th-digit bump, same convention as last time.

Data card typography/color pass, plus a new flavor-text region for building-plot hover cards.

### Changed

- **All `HoverCard` text now uses the new font assets** (`HoverCardScripts.gml`) -- `fntDataCard` for both the name plate and the normal body text (previously `fnt_gm_20`/`fnt_gm_15`). A new second region, italic `FntDataCardItalics`, is drawn inside `sHoverCardDataWindow` below the body when `Show()` is given non-empty flavor text (new optional 5th param, default `""` = no flavor region at all). `HoverCardFlavorWrapWidth()`/`HoverCardRequiredHeight()`'s new `_hasFlavor` param account for it in card-size selection.
- **All card text now renders in `HOVER_CARD_TEXT_COLOR` (F1DEB6)** with a 1px downward drop shadow (`HOVER_CARD_SHADOW_COLOR`) via a new `DrawCardTextWithShadow()` helper -- a manual double-draw (shadow copy offset 1px down, then main copy on top). Scribble has no built-in runtime shadow effect; the existing `scribble_font_bake_shadow.gml` bakes an entirely new font asset via a shader, a heavier one-time step not used anywhere else in this project, so the lighter double-draw was used instead.
- **Building-plot hover text now split across both regions** (`PlotHoverScripts.gml`): `PlotHoverBonusText` (new, normal body/`fntDataCard`) states the plot's placement bonus per `oOuterPlotSpawner`'s header comment; `PlotHoverFlavorText` (renamed from `PlotHoverBody`, italic/`FntDataCardItalics`, in `sHoverCardDataWindow`) carries the previous pass's descriptive one-liners. `PlotHoverController.Step`'s `card.Show(...)` call now passes both.

### Assumptions / scope boundaries (flag if wrong)

- Drop shadow color defaults to `c_black` -- not specified by the request.
- The placement-bonus mechanic described in `PlotHoverBonusText` is still NOT implemented anywhere in code (`AI_FindEmptyOwnedPlot`'s doc comment in `AIControl.gml` confirms it's aspirational). The new body text describes it qualitatively -- which building type benefits -- without inventing a number, since none exists. Flag if this reads as overpromising before the mechanic is real.
- The "Blocked Plot" flavor line ("Whatever this plot could become remains sealed for now") is newly-invented atmospheric text, not sourced from any existing spec.

### Build

- Windows export version bumped `0.0.2.43` → `0.0.2.44` — 4th-digit bump, same convention as last time.

## v0.0.2.43 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Same-day correction to v0.0.2.42's 2x scale pass: "text can be rendered at 1x scale in terms of UI, it does not need to be scaled up with everything else."

### Changed

- **`HoverCard`'s text no longer scales** (`HoverCardScripts.gml`) -- removed the `.scale(HOVER_CARD_SCALE)` call from both `nameText` and `bodyText` (constructor and `Show()`). Glyphs now render at native (1x) size regardless of `HOVER_CARD_SCALE`. The card SPRITE still renders at 2x, and all LAYOUT math (name/body offsets, margins, wrap width) still scales by `HOVER_CARD_SCALE` -- unchanged from last pass -- so native-sized text is still correctly positioned within the visually-2x card; it just no longer draws bigger to match. Practical effect: more (smaller) text now fits per line and the auto-sized card will more often land on Short/Mid than before, since the wrap width is unchanged (scaled) but glyphs take less of it.

### Build

- Windows export version bumped `0.0.2.42` → `0.0.2.43` — 4th-digit bump, same convention as last time.

## v0.0.2.42 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Two follow-up requests on the hover card system: render at 2x (matching the rest of the UI), and make card placement position-sensitive so it never opens toward the nearest screen edge. Also re-added `HoverCardScripts`'s `.yyp` registration, which had silently dropped out between sessions (see below) -- that's what caused the "HoverCard not set before reading" crash report.

### Fixed

- **`HoverCardScripts` was missing from `Blank Pixel Game.yyp`.** The script files were still on disk, but with no `.yyp` entry GameMaker never compiled them in, so the `HoverCard` constructor didn't exist at runtime -- `new HoverCard()` in `PlotHoverController` resolved to a variable read instead of a function call, producing the reported "Variable ....HoverCard(...) not set before reading it" crash. Re-added the entry. If this recurs, it's likely the GameMaker IDE overwriting the `.yyp` from its own in-memory resource list while the project is open during an editing session -- reloading the project after a batch of changes should keep it in sync.

### Changed

- **`HoverCard` now renders at `HOVER_CARD_SCALE` (2x)** (`HoverCardScripts.gml`), matching the "most UI items render at 2x" convention already used by `XpBarWidget`/`FateDrum`. Unlike those two (which only scale sprites, since they have no text), the card's Scribble text elements now carry `.scale(HOVER_CARD_SCALE)` -- a PRE-render scale baked into Scribble's text layout model (confirmed via `__scribble_class_element.gml`: changing it dirties the model/bbox cache), so `.wrap()`/`.get_height()` measure against the already-scaled glyphs. Every layout constant (name offset, body margins, wrap width) stays NATIVE (1x) in the macros and gets multiplied by `HOVER_CARD_SCALE` at the point of use, so `ChooseHoverCardSprite`'s Short/Mid/Tall comparisons and the actual on-screen render stay in sync. New `HoverCard.GetWidth()`/`GetHeight()` expose the real on-screen footprint for positioning code.
- **Position-sensitive card placement** (`PlotHoverController.Step`, `PlotHoverScripts.gml`): the card now anchors away from whichever half of the screen the mouse is in, independently on each axis -- mouse in the left half anchors the card's left edge near the mouse (opens rightward), mouse in the right half anchors the right edge (opens leftward), same logic for top/bottom. `PLOT_HOVER_CURSOR_GAP` (8px) sits between the mouse and the card's nearest edge in the direction of its anchor -- e.g. mouse in the bottom-right quadrant puts the card's bottom-right corner 8px up and 8px left of the mouse. Replaces the old flat +18/+18 cursor offset and its edge-nudge fallback; a defensive clamp remains as a safety net for extreme cases (e.g. a very narrow window).

### Assumptions / scope boundaries (flag if wrong)

- The anchor test uses screen HALVES (mouse position vs. `display_get_gui_width()/height() / 2`), not the specific card's own footprint vs. the nearest edge -- simpler and matches the request's literal "below the center of the screen" framing, but means a card could in rare cases anchor "away" from a screen half it wasn't actually close to running off of. The safety-net clamp catches any resulting overflow regardless.
- 2x scale currently only affects `HoverCard` (and therefore plot hover data). The specialized building/unit/timer window sprites planned for later passes aren't touched yet.

### Build

- Windows export version bumped `0.0.2.41` → `0.0.2.42` — 4th-digit bump, same convention as last time.

## v0.0.2.41 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Hover data for un-occupied building plots -- the first real consumer of the general-purpose HoverCard base from v0.0.2.40.

### Added

- **`HoverCard.Draw()` (`HoverCardScripts.gml`) now takes an optional `_alpha` (default 1)**, applied via `draw_sprite_ext` for the card sprite and Scribble's `.blend()` for both text elements. Purely additive -- every existing no-argument call still renders fully opaque exactly as before.
- **`PlotHoverScripts.gml`** (new script asset):
  - `PlotHoverName(_plot)`/`PlotHoverBody(_plot)` classify an un-occupied `oBuildingPlot` into one of 4 kinds, using its existing `blocked`/`inside`/`far` fields: `"Blocked Plot"` (meta-progression-locked, checked first since it can coexist with `inside`), `"Castle Plot"` (buildable, inside the walls), `"Distant Plot"` (buildable, far outer ground), `"Exterior Plot"` (buildable, near outer ground). Body text describes each plainly -- deliberately does NOT mention the inside/outside placement bonus described in `oOuterPlotSpawner`'s header comment, since `AI_FindEmptyOwnedPlot`'s doc (`AIControl.gml`) already flags that bonus as unimplemented.
  - `PlotHoverSuppressed(_selectionController, _blueprintController)` -- true while the player is targeting an order, dragging a blueprint, or (once wired) the Fate Engine overlay is open.
  - `PlotHoverController()` -- owns one `HoverCard`. Tracks continuous dwell time on whatever un-occupied plot the mouse is over; once `PLOT_HOVER_DELAY_STEPS` (300 = 5 sec at the true 60fps game speed) is reached uninterrupted, fades the card in over `PLOT_HOVER_FADE_STEPS` (~1/3 sec); fades back out at the same rate the instant the mouse leaves the plot, the plot becomes occupied, or suppression kicks in. The card freezes its last content/position while fading out rather than snapping away.
  - New `global.fateEngineOverlayActive` flag -- suppression hook for the Fate Engine overlay. **Nothing sets this true yet**: the only Fate Engine object in the project today (`oFateEngineDrumTest`) is an explicitly temporary test harness with no open/closed state of its own. This flag exists so the real overlay (not yet built) can wire into suppression later without another pass through this file.
- Wired into `oUnitControl`: `plotHoverController` created in `Create_0`, stepped (passing `selectionController`/`blueprintController`) in `Step_0`, drawn last in `Draw_64` (so it renders on top of the rest of the HUD).

### Assumptions / scope boundaries (flag if wrong)

- The request's exact casing was "castle plot" (lowercase) alongside 3 Title-Case names -- normalized to "Castle Plot" to match the other 3 and every other order/label string in this project.
- The dwell timer and fade deliberately do NOT scale with `global.matchSpeed`, unlike most gameplay timers in this project (e.g. `CastleStep`'s no-damage XP timer) -- a UI dwell/fade is treated as real-time so it still works while the game is paused (`matchSpeed` 0), rather than never triggering.
- Hover data shows for plots on EITHER team, not just the player's own -- the request didn't specify a team restriction, and the info conveyed (which of the 4 plot kinds this is) isn't sensitive.
- The card follows the mouse cursor (offset +18/+18) the whole time it's visible, not just at the moment it first appears -- this matches typical tooltip behavior but wasn't explicitly specified.
- `global.fateEngineOverlayActive` is inert plumbing until the real Fate Engine session overlay is built -- flagged above, not guessed at.

### Build

- Windows export version bumped `0.0.2.40` → `0.0.2.41` — 4th-digit bump, same convention as last time.

## v0.0.2.40 — 2026-07-06 (uncommitted — working tree only, not yet committed)

First pass on the hover/tooltip data overlay system -- step 1 of 4 (general-purpose base first, then unit/building/event data layered on top per the request). New sprite assets for this (`sHoverCardShort/Mid/Tall`, `sHoverCardBuildingWindow`, `sHoverCardDataWindow`, `sHoverCardTimer`, `sHoverCardUnitWindow`, all in "In Game/UI/Assets/DataOverlays") were already added to the project ahead of this batch.

### Added

- **`HoverCardScripts.gml`** (new script asset): `HoverCard()` constructor -- a name plate + wrapped body text, auto-picking the smallest of the 3 card sprites (Short 148px / Mid 185px / Tall 222px tall, all 133px wide) that fits the body text via Scribble's `.wrap()`/`.get_height()`, capped at Tall. `Show(_name, _body, _x, _y)` sets content + GUI position and picks the sprite; `Hide()`; `Draw()` renders the card, the name (left-middle aligned, anchored at (5, 11) relative to the card's top-left, per spec) and the wrapped body (starting `HOVER_CARD_BODY_MARGIN_TOP` px below the name plate strip). Same "plain struct, owner drives Show/Hide/Draw" pattern as `BlueprintController`/`FateDrum`/`XpBarWidget` -- no `Step()` needed, nothing animates.
- Uses **Scribble** (already wired into the project -- `oAlphaDisclaimer`'s disclaimer text, `ResourceUIScripts.gml`'s `CostToScribbleText`) rather than raw `draw_text_ext`, specifically because `.wrap()`/`.get_height()` is what makes "does this text fit in card X" answerable before drawing.
- Not yet wired into any object/hover-detection code, and the specialized sprites (Building/Data/Timer/Unit windows) aren't touched yet -- this pass is only the reusable base.

### Assumptions / scope boundaries (flag if wrong)

- Name-plate font `fnt_gm_20` and body font `fnt_gm_15` are both pre-existing generic GM fonts already in the project -- no new font asset was created this pass. The italic flavor-text font mentioned in the request ("we can make a font for it") is deferred to the building-data pass, where it's actually needed.
- Body margins (6px left/right, 4px top gap below the name plate, 6px bottom gap) are my own placeholder spacing -- not specified in the request beyond the name plate's exact (5, 11) anchor, which IS followed precisely.
- If body text is long enough to overflow even the Tall card, `Show()` sets an `overflowed` flag but nothing currently truncates or scrolls -- text will just run past the card's bottom edge. Flagging in case that's a real scenario once actual flavor text is written.
- `HoverCard` has no hover-detection logic of its own (no mouse-over-instance check) -- it's purely "given a name/body/position, display it." Wiring it to actual mouse-over-a-unit/building detection is follow-up work.

### Build

- Windows export version bumped `0.0.2.39` → `0.0.2.40` — 4th-digit bump, same convention as last time.

## v0.0.2.39 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Castle-side AI defense, closing the scope gap explicitly flagged in v0.0.2.38: "if it is under siege, top priority should be to defeat enemies attacking the castle."

### Added

- **`GetTeamCastle(_team)`** (`GatherScripts.gml`) — a team's OWN castle instance, the inverse of the existing `GetEnemyCastle(_unit)`.
- **`CastleDefendWaypoints(_castle)`** (`CastleScripts.gml`) — patrol waypoints spread along a castle's actual front wall (reusing the same "whichever bbox edge faces the room's center" logic as `CastleFrontEdgePoint`), instead of `DefendBuildingWaypoints`' 4-corner box, which assumes a 48x48 building and is wrong for a 350x411 castle. New macro `CASTLE_DEFEND_WAYPOINT_COUNT` (6, placeholder) controls how many points are spread down the wall.
- **`Defend_Enter`** (`UnitStateDefend.gml`) now branches on target type: `!object_is_ancestor(_target.object_index, oBuildingParent)` tells a castle apart from an ordinary building (neither castle object is an `oBuildingParent` descendant), and picks `CastleDefendWaypoints` instead of `DefendBuildingWaypoints` accordingly. This is the only unit-level FSM change in this batch — flagging per CLAUDE.md's "flag before touching FSM/state wiring for guard/defend/combat/attack/siege" rule, though it's purely additive (existing building-defense behavior is untouched).
- **`AI_CastleUnderThreat(_team)`** (`AIControl.gml`) — true if any enemy unit is within new macro `AI_CASTLE_THREAT_RADIUS` (300, placeholder) of `_team`'s own castle. The castle-scoped counterpart to the existing building-scoped `AI_DetectThreat`.
- **New `AIBrain` state `"castle_defense"`**, the AI's highest priority — checked first in both `"build_up"` and `"defending"`, ahead of the ordinary building-threat check. `AI_CastleDefense_Step` recalls every unit currently in `"guard"`, `"defend"`, OR `"siege"` (including a siege already committed against the enemy castle) and redirects them to `"defend"` the home castle via `CastleDefendWaypoints`. Units already actively fighting (combat/combatRanged/attack/attackRanged) are left alone rather than yanked out of a live engagement. Reverts to `"build_up"` the instant the castle clears.

### Changed (behavior, not code shape)

- The AI will now abandon an in-progress siege against the enemy castle to save its own — explicitly the opposite of v0.0.2.38's scope boundary ("deliberately does NOT recall units already mid-siege"). This is intentional per this request: castle survival outranks an offensive push.

### Assumptions / scope boundaries (flag if wrong)

- `AI_CASTLE_THREAT_RADIUS` (300) is a placeholder, sized somewhat larger than `AI_THREAT_RADIUS` (250) since it's measured from the castle's origin and the castle itself is much bigger than an ordinary building — not tuned against real approach distances.
- Recall scope was a judgment call: `"guard"`/`"defend"`/`"siege"` get pulled back, but units already in an active fight (combat/combatRanged/attack/attackRanged) don't — pulling a unit out of a live engagement seemed more likely to get it killed mid-retreat than to help. Worth revisiting if castle losses still happen with units "stuck" fighting elsewhere while the castle burns.
- No new "castle destroyed" / loss-condition handling was touched here — this only affects the AI's own decision-making, not match end-state logic.

### Build

- Windows export version bumped `0.0.2.38` → `0.0.2.39` — 4th-digit bump, same convention as last time.

## v0.0.2.38 — 2026-07-06 (uncommitted — working tree only, not yet committed)

First real pass on AI decision-making (`AIControl.gml`), following a discuss-first design conversation about what the AI's priorities should be given the win condition (reduce the opponent's castle HP to zero). Full rewrite of the file's decision logic; no unit-level FSM states (guard/defend/combat/attack/siege) were touched -- this is entirely the layer that decides which orders to issue, not how those orders execute.

### Fixed

- **The AI likely never reached its own siege threshold.** `TrainingSpawnUnit` (`TrainingScripts.gml`) sends every freshly trained unit straight into `"defend"` (patrolling the building that trained it), not `"guard"` -- a unit only falls back to `"guard"` if that specific building is later destroyed. But the old `AI_BuildUp_Step` only counted units in `"guard"` toward its idle-massing threshold. In normal play, that count would likely never climb past zero. New `AI_GatherAvailableUnits(_team)` now treats `"guard"` OR `"defend"` as available for redirection; committed states (attack/attackRanged/combat/combatRanged/siege) are still correctly excluded.

### Added

- **Reactive defense.** New `AI_DetectThreat(_team)` finds the first owned building (`oBuildingParent`) with an enemy unit within `AI_THREAT_RADIUS` (250px, placeholder) of it. `AIBrain` gained a second state, `"defending"`: entered the instant a threat is detected, it sends every available unit to `"defend"` the threatened building (reusing the existing player-facing order/state completely unchanged -- responders patrol it and auto-engage via `Defend_Step`'s existing proximity-aggro check, no new combat logic needed) and reverts to `"build_up"` once nothing's threatened. Deliberately building-scoped, not castle-scoped: `"defend"`'s patrol waypoints (`DefendBuildingWaypoints`) hardcode a 48x48-ish box, which would be wrong for the castle (350x411) the same way it was for siege before `CastleFrontEdgePoint` -- castle-side defense (recalling an army mid-siege to save your own castle) is flagged as a reasonable next increment, not built here. Economy/training pauses while `"defending"`, by choice, not oversight.
- **Strength-based siege commitment.** Replaced the flat `AI_ATTACK_GROUP_SIZE = 5` headcount with `AI_ArmyPower(units)` (sum of `AI_UnitPowerScore` per unit: current HP × 0.4 + attackDamage × 5, both placeholder weights) compared against `AI_SiegePowerThreshold()` = 60% of `CASTLE_MAX_HEALTH`. The AI now commits when its available force has SOME rough sense of scale relative to the castle it's attacking, instead of "5 of anything, including 5 unarmed peasants."
- **Composition-aware economy.** New `AI_MissingResourceProducers(_team)` reports which of the 5 tier-1 resources (wheat/water/wood/gold/iron) the team has zero live producers for -- resource buildings self-destroy on depletion and nothing replaced them before this. `AI_TryPlaceBlueprints` now spends on a missing producer first, falling back to the old "spend whatever's affordable" greedy behavior once every resource is covered.
- **Composition-aware training.** New `AI_ArmyTagFraction(_team, _tag)` measures what fraction of the team's live army carries a given `UnitDefinition` tag. `AI_TryTrainComposition` (replaces `AI_TryTrainAtAllBuildings`) checks this against `AI_TANK_TARGET_RATIO`/`AI_RANGED_TARGET_RATIO` (25% each, placeholders) and gives training buildings for the most under-represented tag first crack at the tick's budget, before falling back to attempting every other owned training building same as before.

### Assumptions / scope boundaries (flag if wrong)

- All weights/ratios/radii introduced here (`AI_THREAT_RADIUS`, `AI_SIEGE_POWER_FRACTION`, `AI_POWER_HEALTH_WEIGHT`/`AI_POWER_DAMAGE_WEIGHT`, `AI_TANK_TARGET_RATIO`/`AI_RANGED_TARGET_RATIO`) are placeholders in the same spirit as every other untuned number in this project (`CASTLE_MAX_HEALTH`, building costs, etc.) -- functional, not balanced.
- Castle-side reactive defense (pulling a besieging army home if the AI's OWN castle comes under attack) is explicitly out of scope this pass -- `AI_DetectThreat` only watches ordinary buildings, for the size-mismatch reason above.
- The AI does not keep building/training while `"defending"` -- a deliberate simplification, flagged in case a more concurrent posture is wanted later.
- `AI_TryTrainComposition`'s tag-priority check only looks at "tank" and "ranged" -- it doesn't reason about the other tags (`"suicide"`, `"fast"`, `"cheap"`, `"heavy"`) at all; those units still get trained in the same building's "everything else gets a chance" fallback pass, just without any deliberate weighting.

### Build

- Windows export version bumped `0.0.2.37` → `0.0.2.38` — 4th-digit bump, same convention as last time.

## v0.0.2.37 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Crash fix: `DoAdd :2: undefined value` in `AnalyticsRecordResourceProduced`, first triggered by `oTrainingBuildingParent`'s Step event the moment a unit actually finished training (`TrainingSpawnUnit` -> first-deployment Strategic XP -> `GainXP` -> the crash).

### Root cause

`GainXP` (`ProgressionScripts.gml`, added in the v0.0.2.29 XP-doc batch) calls `AnalyticsRecordResourceProduced(_team, "xp", _toAdd)` and `(_team, "fateTokens", _tokensEarned)` to log XP/Fate Token gains through the existing analytics pipeline. But `AnalyticsInit`'s `resourceProduced` struct (`AnalyticsScripts.gml`) only ever had keys for the 10 literal economic resources (wood/wheat/water/iron/gold/meat/bones/coal/weapons/coins) -- "xp" and "fateTokens" were never added when `GainXP` started using them. `struct_get` on a missing key silently returns `undefined` rather than erroring, so the crash didn't happen at the call site -- it happened one line later, in `AnalyticsRecordResourceProduced` itself, on `undefined + _amt`. This sat latent since the XP batch because nothing had actually triggered a `GainXP` call in a live playtest until now.

### Fixed

- **`AnalyticsInit`** (`AnalyticsScripts.gml`): added `xp:0, fateTokens:0` to both the `resourceProduced` AND `resourceSpent` struct literals. `resourceSpent` isn't hit by today's crash (nothing currently spends xp/fateTokens as a `Cost`), but `Cost`/`ResourceCost` already supports both as a resource type (added earlier this session), so this heads off the identical crash the moment something does spend one.

### Build

- Windows export version bumped `0.0.2.36` → `0.0.2.37` — 4th-digit bump, same convention as last time.

## v0.0.2.36 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Units no longer physically collide with buildings, per explicit request ("it doesn't make a difference if they actually clip through them"). Purely a movement/collision change -- the cosmetic steering-around-buildings behavior is untouched.

### Changed

- **Every unit movement call site** now drops `oBuildingParent` from its `move_and_collide` collision list, leaving only `oEnvironmentSolid` (real static geometry -- map bounds, terrain, etc.): `Guard_Step` (`UnitStateGuard.gml`), `Defend_Step` (`UnitStateDefend.gml`), and the two shared movement helpers `UnitPursueTarget`/`UnitIdleInPlace` (`UnitCombatHelpers.gml`) -- which between them cover every other state (attack, attackRanged, combat, combatRanged, siege). That's the complete set; grepped for every `move_and_collide` call in the project to confirm nothing was missed.
- **`Steering_AvoidObstacles` is completely unchanged**, as is `GatherNearbyObstacles` (`GatherScripts.gml`, still gathers `oBuildingParent` instances). Units still steer around buildings cosmetically; they just aren't physically blocked if avoidance doesn't fully route around one in time, which is accepted as harmless per the request.

### Assumptions (flag if wrong)

- Castles (`oPlayerCastle`/`oEnemyCastle`) were already fully non-solid before this batch (`parentObjectId: null`, `solid: false`, never in any collision list) -- this change doesn't affect siege behavior at all, only ordinary buildings (resource + training).
- Knockback (`ApplyKnockback`/`SteeringController.Apply`) still routes through the same `move_and_collide` call as normal movement, so a knocked-back unit can now be shoved straight through a building instead of being stopped by it -- a real, if minor, behavior change worth knowing about, not called out separately since it follows directly from "no longer collide with buildings" rather than being a separate decision.

### Build

- Windows export version bumped `0.0.2.35` → `0.0.2.36` — 4th-digit bump, same convention as last time.

## v0.0.2.35 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Four requested tweaks: deselect-on-order, a tighter defend patrol radius, siege obstacle-avoidance tuning, and a real fix for siege units sliding through the castle wall instead of stopping.

### Changed

- **`SelectionController.IssueOrder`/`UpdateTargeting`** (`UnitSelection.gml`): `selected` is now cleared the moment an order actually goes out -- immediately for a no-target order (guard/siege/station), or on the successful-click branch of `UpdateTargeting` for a targeted order (defend/attack). A canceled targeting attempt leaves the selection untouched, since nothing was actually issued.
- **`DEFEND_PATROL_MARGIN`** (`UnitStateDefend.gml`): `20` → `4` px outside the building edge, per request. Also tightened **`DEFEND_ARRIVE_RADIUS`** `48` → `16` alongside it -- the old value was nearly as large as an entire corner-to-corner patrol leg at the new, much smaller margin, which would have kept units decelerating for almost the whole loop instead of ever reaching a normal patrol speed. Flagging since only the margin was explicitly requested.
- **`UNIT_OBSTACLE_LOOK_RADIUS`** (`GatherScripts.gml`): `96` → `140`. At 96 there was barely any margin beyond `Steering_AvoidObstacles`' own feeler length, so obstacles were only ever spotted right at the tip of the feeler with no room to curve around smoothly -- a likely contributor to units snagging on buildings. This is a global detection-radius change (affects every steering user, not just siege), but only changes how early an obstacle is seen, not the avoidance logic itself.
- **`UnitPursueTarget`** (`UnitCombatHelpers.gml`): added an optional `_feelerLength` parameter (default `80`, so every existing call site is unaffected). `Siege_Step`'s ADVANCE phase now passes `120` -- a longer lookahead for the long march across open ground toward the castle, where getting snagged was reported.

### Added

- **`SteeringAgent.Brake(_friction)`** (new, `SteeringBehaviors.gml`): decays `velocity` toward zero, same `power(friction, matchSpeed)` idiom knockback already decays with. **`UnitIdleInPlace`** (`UnitCombatHelpers.gml`) now calls it before applying steering. Root cause of "siege units bound in and out of the castle walls": `Steering_Controller.Apply()` with zero `Add()` calls (i.e. "idle") does NOT stop a unit -- every `Steering_*` behavior decelerates by computing desired-minus-velocity, but adding nothing at all leaves whatever velocity a unit already had completely untouched, forever. A unit that reached attack range still carried full pursuit-speed momentum into `UnitIdleInPlace` and just kept gliding in that direction indefinitely (castles have zero collision -- `oPlayerCastle`/`oEnemyCastle` are `parentObjectId: null`, `solid: false` -- so nothing physically arrested that drift either). Braking on entry to idle fixes this for every `UnitIdleInPlace` caller (attack/attackRanged/combat/combatRanged/siege), not just siege.

### Assumptions / honesty check (flag if wrong)

- The obstacle-avoidance tuning (wider look radius, longer siege feeler) is a meaningful reliability improvement, not a guarantee. This project's steering is pure reactive Craig Reynolds-style (per CLAUDE.md -- context steering was tried and dropped), which has no concept of a real path around a fully-enclosed dead end; only actual pathfinding (navmesh/grid) can make "always reaches the castle" a mathematical certainty. Flagging this now rather than overpromising -- if units are still getting stuck in specific building layouts after this, that's a sign real pathfinding is the next real step, not another round of steering-weight tuning.

### Build

- Windows export version bumped `0.0.2.34` → `0.0.2.35` — 4th-digit bump, same convention as last time.

## v0.0.2.34 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Root-caused and fixed "the targeting reticle sometimes doesn't come up" for "Defend Building" (and every other `requiresTarget` order): a same-frame input double-read, not a targeting-logic bug. `oUnitControl/Step_0.gml` calls `orderMenu.Update()` (which reads the menu click and can call `IssueOrder` -> `BeginTargeting`, setting `isTargeting = true`) and then, in that SAME Step, immediately calls `UpdateTargeting()` since `isTargeting` is now true. `mouse_check_button_pressed(mb_left)` is still true for the rest of that Step -- it's the exact same physical press that selected the menu item -- so `UpdateTargeting` read it as the player's target click, resolved against wherever the cursor happened to be sitting on the order menu (almost never a valid target), and canceled targeting mode before the reticle was ever drawn. Reproduces intermittently because it depends on whether anything happens to occupy that stale room-space position.

### Added

- **`SelectionController._targetingJustBegan`** (new internal field, `UnitSelection.gml`): set `true` by `BeginTargeting`, checked and cleared at the top of `UpdateTargeting` -- swallows exactly the one same-frame press that opened targeting mode, so the first REAL click read happens on the next Step, after the menu-selection press has actually ended. Also cleared by `CancelTargeting` for cleanliness.

### Build

- Windows export version bumped `0.0.2.33` → `0.0.2.34` — 4th-digit bump, same convention as last time.

## v0.0.2.33 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Correction to v0.0.2.32: that batch's fix incorrectly assumed `oBuildingPlot.blocked` meant "has a building on it." Per explicit correction, `blocked` is unrelated to building presence -- it's a meta-progression-owned flag (see `oPlotSpawner/Create_0.gml`: the inner 3x3 of each 5x5 inside-castle plot grid is marked `blocked` at spawn to keep those slots un-buildable until some future progression system unlocks them; the outer ring is left `false`). Conflating that with "a building is standing here" was wrong. Introduced a separate `occupied` field for the latter and rewired everything v0.0.2.32 touched to use it instead, leaving `blocked` completely untouched by building placement/destruction from here on.

### Added

- **`oBuildingPlot.occupied`** (new Object Property, default `False`, same declaration style as `inside`/`far`/`blocked`/`team`): true exactly while a building currently stands on this plot. Also set explicitly in `SpawnBuildingPlot` (`PlotScripts.gml`), matching how `blocked` is already explicitly re-set there for parity even though the property default already covers it.

### Changed

- **`TryPlaceBlueprint`** (`BlueprintScripts.gml`): validity check is now `_plot.blocked || _plot.occupied` (was just `_plot.blocked`) -- rejects both a meta-locked slot AND an already-occupied one. Sets `_plot.occupied = true` on placement (was incorrectly setting `_plot.blocked = true`).
- **`BuildingFreePlot`** (`PlotScripts.gml`, added in v0.0.2.32): now clears `occupied` instead of `blocked`. Docstring corrected to state plainly that it never touches `blocked`.
- **`UpdateTargeting`**'s click-through fix (`UnitSelection.gml`, added in v0.0.2.32): now checks `_clicked.occupied` instead of `_clicked.blocked` when deciding whether a clicked `oBuildingPlot` should be treated as click-through in favor of the building on top of it.
- **`AI_FindEmptyOwnedPlot`** (`AIControl.gml`): now checks `!blocked && !occupied` (was just `!blocked`) -- without this, the AI would have started treating every occupied plot as buildable again the moment `TryPlaceBlueprint` stopped setting `blocked` on placement.

### Assumptions (flag if wrong)

- `blocked`'s real semantics (meta-progression plot unlocks) aren't implemented anywhere beyond `oPlotSpawner`'s spawn-time interior-grid lockout -- nothing currently *unblocks* a blocked plot. Not this batch's concern; noted so it isn't mistaken for another building-presence bug later.

### Build

- Windows export version bumped `0.0.2.32` → `0.0.2.33` — 4th-digit bump, same convention as last time.

## v0.0.2.32 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Root-caused and fixed "can't get units to defend the wheat fields": a blocked `oBuildingPlot` is never destroyed once a building is placed on it (`TryPlaceBlueprint`, `BlueprintScripts.gml` -- it only sets `blocked = true`), and it sits at the exact same x/y as the building, so `instance_position(..., all)` in the "Defend Building"/"Attack Building" click-targeting flow (`UpdateTargeting`, `UnitSelection.gml`) could resolve to the plot instead of the building. The plot always fails the `oBuildingParent`-ancestor `targetValidator`, so the click would silently do nothing -- no error, no feedback, just a targeting click that appeared to be ignored.

### Changed

- **`UpdateTargeting`** (`UnitSelection.gml`): if the clicked instance is a *blocked* `oBuildingPlot`, it's now treated as click-through -- the click is re-resolved against `oBuildingParent`, which correctly finds the building sitting on top of it. An unblocked plot (nothing built on it) is unaffected and still a normal target. Considered an actual mask/sprite swap first (strip the plot's collision mask while blocked, restore it once free) per initial direction, but every mask sprite in this project (`sPlot` included) is rectangle/bbox collision, not precise -- a real "no collision" mask would need a new, hand-authored sprite asset (something not done anywhere else this session). This delivers the identical player-facing result in pure GML instead, with no new assets.
- **`ApplyDamage`** (`UnitCombatHelpers.gml`): the building-death branch now always calls the new `BuildingFreePlot` before destroying the building, regardless of whether there's an attributable killer (XP is still killer-gated, unchanged).
- **`BuildingUpdateProduction`** (`BuildingDefinitions.gml`): the resource-depletion self-destroy path now also calls `BuildingFreePlot` before `instance_destroy`.

### Added

- **`BuildingFreePlot(_building)`** (new, `PlotScripts.gml`): finds the `oBuildingPlot` at a destroyed building's position and clears `blocked`, so the plot becomes buildable again *and* (via the `UpdateTargeting` change above) clickable/targetable again the moment nothing is built on it. No plot reference is stored on building instances -- looked up by position instead, relying on the existing invariant that `TryPlaceBlueprint` always spawns a building at its plot's exact x/y.

### Assumptions (flag if wrong)

- Before this batch, a destroyed building's plot was **never** unblocked by anything in the codebase -- combat death and resource depletion both `instance_destroy`d the building but left `_plot.blocked = true` forever, permanently sterilizing that plot. This wasn't reported as a symptom yet (probably because nothing had been destroyed/depleted in a playtest so far), but it's fixed as a necessary part of "regain its mask once nothing's built on it."

### Build

- Windows export version bumped `0.0.2.31` → `0.0.2.32` — 4th-digit bump, same convention as last time.

## v0.0.2.31 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Siege now targets anywhere along a castle's actual front wall instead of a single fixed point, per explicit 2026-07-06 request: "make the siege action target the front bounding box of each castle, allowing attacks to happen anywhere along its front edge (the edge facing towards the center of the room)."

### Added

- **`CastleFrontEdgePoint(_castle, _fromPos)`** (`CastleScripts.gml`): returns the point on a castle's real collision box (`bbox_left`/`bbox_right`, GameMaker built-ins — already world-space and sprite-mask-accurate) closest to the room's horizontal center, at whatever height the approaching unit is at (`_fromPos.y` clamped to `bbox_top`/`bbox_bottom`). Deliberately layout-agnostic — it doesn't read `_castle.team` or hardcode "player is left / enemy is right," it just picks whichever bbox edge geometrically faces `room_width / 2`, so it keeps working if castle placement ever changes.

### Changed

- **`Siege_Step`** (`UnitStateSiege.gml`): the `_edgePos` a besieging unit paths toward now comes from `CastleFrontEdgePoint` instead of the generic `NearestBuildingEdgePoint` (`UnitStateAttackMelee.gml`). That function hardcodes `ATTACK_BUILDING_HALF = 24` (assumes every building is 48×48) and clamps against all 4 sides — both wrong for a 350×411 castle. No other siege phase logic (ADVANCE/ASSAULT/SWING/RECOVER/ENGAGE_GUARD, cooldowns, state transitions) was touched.
- **Corrected a stale comment in `CastleScripts.gml`**: the file header previously claimed "nothing in the codebase currently targets a castle in combat." That was wrong — `Siege_Step` already called `UnitTryDealDamage` directly on the castle instance via `GetEnemyCastle()`, bypassing the `oBuildingParent`-ancestry gate that blocks the generic "attack Building" order from ever reaching a castle. Left a correction in place rather than silently rewriting history.

### Not covered by this batch

- `NearestBuildingEdgePoint` itself is untouched — it's still correct for its actual use case (48×48 buildings via the "attack" order), which was confirmed to never include castles.

### Build

- Windows export version bumped `0.0.2.30` → `0.0.2.31` — 4th-digit bump, same convention as last time.

## v0.0.2.30 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Resource depletion, sourced from the uploaded "Resource_Infrastructure Buildings +VISUALS" doc -- unblocks Economic XP, which the previous batch (v0.0.2.29) flagged as blocked for lack of exactly this mechanic.

### Added

- **`BuildingDefinition.resourceLimit`** (new optional field, `BuildingDefinitions.gml`): the TOTAL lifetime units a resource building may ever produce. Omitted (`undefined`) = unlimited, same as before -- only affects buildings that set it.
- **All 5 Tier 1 resource buildings** (Wheat Field, Water Pump, Sawmill, Gold Mine, Iron Mine) now set `resourceLimit: 300`, per the doc's "Resource Limit: 300" line on every one of them.
- **`BuildingUpdateProduction`** now caps production at `resourceLimit`: a tick that would push a building's lifetime `producedTotal` past its limit is clamped to exactly fill the remaining room (never overshoots), and the instant the cap is hit, the building awards its team `ECONOMIC_XP_DEPLETION` (8 XP -- the exact "Economic XP" value from the earlier XP Age Progression doc) and self-destroys via `instance_destroy`. This is the same bare removal combat-death already uses here (`ApplyDamage`) -- there's no dedicated building-destroy cleanup step anywhere in the codebase to mirror, so depletion doesn't skip anything combat-death doesn't already skip too. **No depletion VFX/SFX exists yet** -- the building just vanishes; flag if a visual cue (crumbling, dust, etc.) is wanted.

### Changed

- **`maxHealth` on all 5 Tier 1 resource buildings**: `150` → `100`, per explicit 2026-07-06 direction ("each resource building should keep their 100 max health"). Every other building type (training buildings, etc.) is untouched.

### Not covered by this batch

- The doc also lists Tier 2/3 resource + facility buildings (Village Well, Windmill, Armory, Treasury, Royal Stables, Archer Tower, and many more) with their own resource limits, costs, and special mechanics (production multipliers, resource-consuming production, morale buffs, etc.) -- none of those buildings exist in the codebase yet. This batch only applied the depletion mechanic + doc-sourced numbers to the 5 Tier 1 resource buildings that are already implemented.

### Build

- Windows export version bumped `0.0.2.29` → `0.0.2.30` — 4th-digit bump, same convention as last time.

## v0.0.2.29 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Reconciled the codebase against the uploaded "XP Age Progression System" design doc: per-age XP requirements, a gated (manual, paid) Age Up instead of an automatic one, and wired up most of the doc's actual XP sources (Combat, Strategic, Defensive). Economic XP is flagged as blocked, not wired.

### Changed

- **`AgeXpRequired`/`global.ageXpRequired`** (`ProgressionScripts.gml`): `AGE_XP_REQUIRED` (flat 1000 for every age) replaced with a per-transition lookup — Age I→II 100, II→III 150, III→IV 200, per the doc. `GainXP` and the Fate Token milestone math (`AGE_FATE_TOKEN_INTERVALS`) are unaffected in concept, just now read the current age's requirement instead of one flat constant.
- **`XpBarFillPercent`** (`XpBarScripts.gml`, new): replaces the 3 inline `clamp(xp / AGE_XP_REQUIRED, 0, 1)` call sites (constructor catch-up, `Step()`, `Draw()`) so the bar automatically tracks whichever age is current.
- **Age Up is no longer automatic.** Per the doc's "Age Advances" section: filling the bar now only sets `global.ageUpReady[team]` (new, `oMatchControl/Create_0.gml`) — advancing the age, resetting XP to 0, and clearing the flag all happen in the new `TryAgeUp(_team)`, which also spends a per-age gold cost (`global.ageUpCost`/`AgeUpCost`, using the existing `Cost`/`Purchase` pattern from `Economy.gml`). **No HUD button calls `TryAgeUp` yet** — the data/logic layer is complete and callable, but there's no way to actually trigger an age-up in a running match yet. Flagging as a follow-up.
- **`UnitDefinition.tier`** (`UnitDefinitions.gml`, new field, default `1`): drives Combat XP payout by victim tier. All 6 registered units (Peasant, Bomb Goblin, Mud Golem, Soldier, Archer, Knight) explicitly set `tier: 1` — **assumption, confirmed 2026-07-06: every current unit is Tier 1 for the MVP build; no real tier design exists yet.**

### Added

- **Combat XP** (`ApplyDamage`, `UnitCombatHelpers.gml`): on a lethal hit with an attributable killer, the killer's team gains XP —
  - Killing a unit: by the victim's `UnitDefinition.tier` (Tier 1 = 1 XP, Tier 2 = 3, Tier 3 = 5; only Tier 1 is reachable today).
  - Destroying a building: +5 (`COMBAT_XP_STRUCTURE`). If that building is also an `oResourceBuildingParent`, an additional +5 (`COMBAT_XP_RESOURCE_BLDG`) stacks on top — **+10 total confirmed 2026-07-06**, not a either/or.
- **Strategic XP** (`ApplyDamage` + `TrainingScripts.gml`):
  - Losing a unit: the losing team always gets +1 XP (`STRATEGIC_XP_LOSE_UNIT`), regardless of whether there's an attributable killer.
  - First deployment of a unit type: +5 XP (`STRATEGIC_XP_FIRST_DEPLOYMENT`) the first time a team ever trains a given unit type, tracked via new `global.unitsDeployed[team]` (`oMatchControl/Create_0.gml`). Every subsequent spawn of that type is a no-op.
- **Defensive XP + castle HP** (new `CastleScripts.gml`, wired into `oPlayerCastle`/`oEnemyCastle` Create/Step): neither castle object had *any* events before this — they were pure visual masks with no HP concept at all. Added `CastleInit`/`CastleStep` reusing the same `maxHealth`/`damageTaken` shape every other damageable entity uses (so `ApplyDamage`/`GetCurrentHealth`/`GetDamageTaken` work on castles with zero changes there beyond a generic `noDamageTimer` reset-on-hit hook). Awards +5 XP every 120 real seconds (7200 steps at 1x match speed) a castle goes without taking damage, per the doc's "no damage for 120s" line. **`CASTLE_MAX_HEALTH` (500) is an untuned placeholder — set up with damage-taken plumbing per 2026-07-06 clarification, not a balance decision.** Also: nothing in the codebase currently targets castles in combat, so in practice this timer will just run indefinitely until real siege-targeting against castles exists.

### Blocked

- **Economic XP** ("resource building depletes naturally" per the doc) is **not wired** — no resource-depletion mechanic exists anywhere in the codebase; buildings currently produce forever. Needs a depletion design before this can be built. Not silently dropped — flagging here per standing instruction to surface gaps rather than guess.

### Assumptions (flag if wrong)

- Excess XP beyond a bar's requirement is discarded, not banked/carried into the next age's bar (`GainXP` clamps `_toAdd` to `_roomLeft`).
- All 6 current units are Tier 1 for Combat XP purposes (confirmed 2026-07-06, MVP-only, real tiers to come later).
- Resource-building destruction XP stacks to +10 total (confirmed 2026-07-06), not +5.
- Castle max HP (500) and the "damage taken" plumbing pattern (mirroring units/buildings) are set up per explicit direction, but the actual number is untuned/placeholder.
- No Age Up UI button exists yet — `TryAgeUp` is fully wired but unreachable in a live match until a HUD control calls it.

### Build

- Windows export version bumped `0.0.2.28` → `0.0.2.29` — 4th-digit bump, same convention as last time.

## v0.0.2.28 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Token rewarding frequency change (25%→20% marks) + a milestone-visibility bug fix.

### Changed

- **`AGE_FATE_TOKEN_INTERVALS`** (`ProgressionScripts.gml`): `4` → `5`. `GainXP` now awards a Fate Token every 20% of `AGE_XP_REQUIRED` (20/40/60/80/100%) instead of every 25% -- the token-awarding math was already generic over this macro, so no logic changes were needed there, just the constant + doc comments.
- **`global.xpBarMilestoneOffsets`** (`XpBarScripts.gml`): added a 4th offset, `186px` (48/94/140/186 -- evenly spaced 46px apart), mapping 1:1 to the new 20/40/60/80% marks via the existing `XpBarMilestonePercent` formula (already generic over the array's length, so it "just worked" once the 4th offset was added).

### Fixed

- **Milestone reveal was animating in regardless of whether its threshold had actually been met** (`XpBarWidget.Step()`, `XpBarScripts.gml`): the reveal-progress advance wasn't gated on `milestoneHit`, only the hit-detection/token-toss was -- so every milestone silently drew itself in during its first `XP_BAR_MILESTONE_REVEAL_STEPS` after the widget existed, whether or not that XP mark had been reached. Now gated on `milestoneHit[i]`, so an unmet milestone stays at 0px tall (invisible) until its threshold is actually crossed, per 2026-07-06 clarification.

### Build

- Windows export version bumped `0.0.2.27` → `0.0.2.28` — 4th-digit bump, same convention as last time.

## v0.0.2.27 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Lower HUD: XP bar widget -- fill, quarter-mark milestone reveals, and tossed Fate Token coins.

### Added

- **New `XpBarScripts.gml`**: `XpBarWidget(_team)`, a plain struct (same "owner calls Step()/Draw()" pattern as `BlueprintController`/`FateDrum`) for the lower HUD's XP bar. Wired into `oUnitControl` for `TEAM.PLAYER` (`xpBarWidget`, alongside `blueprintController`).
  - **Backer** (`sXpBar`) and **fill** (`sXpBarFill`) drawn at `XP_BAR_ORIGIN_X/Y` (1616, 842), both at 2x scale. The fill uses `draw_sprite_part_ext` so only `xp / AGE_XP_REQUIRED` (already tracked by `ProgressionScripts.gml`) of its 121px native width shows -- 0% = nothing, 100% = the full width.
  - **Milestones** (`sXpBarMilestone`, a 1px-wide vertical tick): 3 fixed x-offsets (48/94/140px from the origin, per spec) mapped 1:1 to the 25/50/75% quarter-marks `GainXP` already awards Fate Tokens at (the 4th, 100%, coincides with the age-up/bar-reset instead of getting a tick). Each reveals top-to-bottom via the same `draw_sprite_part_ext` approach, animated over `XP_BAR_MILESTONE_REVEAL_STEPS`, and stays fully revealed afterward until the next age resets all 3.
  - **Tossed Fate Token coin** (`sFateTokenSmall`): spawned once per milestone, horizontally aligned to that milestone's x, at the bar's top edge. Tumbles up then falls under `XP_BAR_TOKEN_GRAVITY`, spinning (`image_angle`-equivalent, random clockwise/counterclockwise) and flipping (`image_yscale`-equivalent, via `cos()` on a phase value) the whole way, until it's fallen `XP_BAR_TOKEN_FALL_DISTANCE` past its start (or `XP_BAR_TOKEN_MAX_LIFE` steps pass). Drawn last in `Draw()` so coins always render in front of the bar.
  - A widget created with xp already past a mark (e.g. wired in mid-session) shows that milestone as already-revealed instead of animating/tossing a coin retroactively.

### Assumptions (flag if wrong)

- The 3 milestone offsets (48/94/140px) are the literal spec values, used as-is -- they don't divide 121px (the fill's native width) into exact quarters, so if that was meant to line up exactly, the offsets (or the fill width) need reconciling.
- Milestone i (by list order) maps to the i-th quarter-mark (25/50/75%) in ascending order -- not stated explicitly, inferred from both lists being given smallest-to-largest.
- Coins are plain struct data drawn manually in `Draw()` (not real GM instances, unlike `oResourceProducedParticle`), since they're part of a GUI-space widget rather than a world-space effect -- same category as `FateDrum`'s items.
- No per-library Notion-compatible markdown doc was added for `XpBarScripts` -- flagging that this hasn't actually been done for any script library in the repo yet (checked: none exist), despite the CLAUDE.md convention. Worth a decision on whether to start.

### Build

- Windows export version bumped `0.0.2.26` → `0.0.2.27` — 4th-digit bump, same convention as last time.

## v0.0.2.26 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Two small visual fixes: resource-produced particles draw-order, and a smooth drum landing. Also folds in a few manual tuning tweaks made directly in the IDE tonight.

### Tuned (manual)

- **`FATE_DRUM_SLOT_COUNT`** (`FateEngineDrumScripts.gml`): `8` → `5`.
- **`BLUEPRINT_UI_ORIGIN_X`/`_Y`** (`BlueprintScripts.gml`): `640`/`810` → `660`/`830`.
- **`BLUEPRINT_SLOT_PADDING`** (`BlueprintScripts.gml`): `4` → `1`.

### Changed

- **`oResourceProducedParticle`**: now sets `depth = -room_height - 1` in `Create_0`. Most instances in this project sort with `depth = -y` (see `oUnitParent`), which only ever ranges from `-room_height` to `0` -- pushing particles past that most-negative end guarantees they draw on top of everything, regardless of where in the room they spawn.
- **`FateDrum` (`FateEngineDrumScripts.gml`)**: landing is no longer an instant snap. Once deceleration (`"stopping"`) slows below the threshold, the drum now hands off to a new `"landing"` state that eases `spinAngle` toward the nearest slot boundary (`landingTarget`) over several steps (`FATE_DRUM_LAND_EASE_RATE`, new macro) instead of jumping there in one frame. The eased delta is normalized to the shortest way around the circle first, so if deceleration overshot slightly past the boundary, the drum "rubber-bands" back up to it rather than snapping forward to the next one -- per 2026-07-06 request. Snaps exactly to `landingTarget` (and applies `pendingResult`, same as before) once within `FATE_DRUM_LAND_SNAP_EPSILON` (0.5°).
  - `oFateEngineDrumTest`'s click handler treats `"landing"` the same as `"spinning"`/`"stopping"` (no-op) -- you can't re-spin until the drum is fully `"stopped"`, same as before.

### Build

- Windows export version bumped `0.0.2.25` → `0.0.2.26` — 4th-digit bump, same convention as last time.

## v0.0.2.25 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Engine layout pass 3: drum position + hover/click hit-test fix.

### Changed

- **`oFateEngineDrumTest`**: drums shifted DOWN by their own whole height (orbit diameter, `2 * radius` = 112px) relative to the body -- only the drums moved, the body/overlay/rects didn't.
- **Hover + click hit test switched from circular to rectangular** (`Draw_64`/`Step_0`, same fix in both): the old `point_distance(...) > radius + 48` circular test used a 104px radius, but drums are only 104px apart center-to-center, so adjacent drums' hit zones overlapped and could highlight/click more than one at once. Now tested as independent width/height bounds (`abs(dx) > halfW || abs(dy) > halfH`) -- half-width is a new, much narrower placeholder (44px, leaves a gap at the 52px half-spacing), half-height keeps the old generous tolerance (`radius + 48`) since items can still sit well above/below center via the depth-based offset.

### Build

- Windows export version bumped `0.0.2.24` → `0.0.2.25` — 4th-digit bump, same convention as last time.

## v0.0.2.24 — 2026-07-06 (uncommitted — working tree only, not yet committed)

Fate Engine layout pass 2: clear the UI bottom bar, add the modal-overlay dark backdrop, and give each drum a backing card.

### Changed

- **`oFateEngineDrumTest`**: whole engine (body + drums) shifted up 268px so it sits above the UI's bottom bar -- `bodyBottomY` (instance var, set in `Create_0`) now anchors `sFateEngineBody`'s bottom edge, and drum Y is derived from it (`bodyBottomY - 338`) instead of the raw GUI height.
  - Added a full-screen dark overlay (`c_black` @ 0.6 alpha) drawn first, behind everything else, so the Fate Engine reads as a modal over the rest of the UI.
  - Added a backing rectangle per drum -- `#E1D3EA`, 50x69, centered on the drum -- drawn after the overlay but before that drum's icons, so it sits behind the spinning items and in front of the dark backdrop.

### Build

- Windows export version bumped `0.0.2.23` → `0.0.2.24` — 4th-digit bump, same convention as last time.

## v0.0.2.23 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fate Engine drum visuals quick-fix: real placeholder art + final GUI layout.

### Changed

- **`FateEngineDrumScripts.gml`**: `FateDrumRandomPlaceholderItem()` now draws from real Fate Engine art instead of the generic `sResourceIcons` stand-in -- a coin-flip between a "resource stack" item (`sFateEngineResources`, indexed by `global.resourceIconOrder`, same 10-frame order confirmed against `sResourceIcons`) and a "blueprint" item (a random registered building's own sprite, read generically off `global.__buildingDefRegistry` via `GetBuildingDefinition`/`ds_map_keys_to_array` so this never goes stale as buildings are added). All drum items are 48x48 at native size.
  - New `FATE_DRUM_ITEM_SCALE` macro (2) -- every item now draws at 2x (96x96) inside `FateDrum.Draw()`, layered on top of the existing depth-based shrink. Callers keep working entirely in GUI space; the scale is invisible to them.
- **`oFateEngineDrumTest`**: repositioned the 3 drums to the real GUI layout -- centered horizontally, anchored 338px up from the GUI bottom edge, at -104/0/+104 from center. Orbit `radius` bumped `48` → `56` (placeholder/tunable -- not specified, chosen because items now render up to 96x96 and looked cramped at the old radius). Now also draws `sFateEngineBody` at 2x scale, bottom-center-anchored flush with the GUI bottom edge, AFTER the drums so the body renders in front of them. Hover/click hit-test radius padded +48 to roughly account for the larger (96x96) visual footprint of items relative to the drum's geometric orbit radius -- still an approximation, not a real per-item bounding box.

### Fixed (mid-session)

- **`Blank Pixel Game.yyp` truncated again** (cut off mid-string inside `TextureGroups`, same underlying IDE-reopen cause as every previous occurrence) and **`oFateEngineDrumTest/Step_0.gml` was found truncated mid-statement** (cut off inside the `else if` on a stopped-drum click handler) partway through this batch -- both reconstructed from known-correct content and reverified.

### Build

- Windows export version bumped `0.0.2.22` → `0.0.2.23` — 4th-digit bump, same convention as last time.

## v0.0.2.22 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fate Engine, part 1: the drum render. First piece of the roguelike meta-progression slot machine (design discussed 2026-07-05) -- just the spinning-cylinder visual and lock-and-read mechanic, no session flow/odds/corruption yet.

### Added

- **New `FateEngineDrumScripts.gml`**: `FateEngineItem` (generic sprite/subimg/label struct -- deliberately reward-agnostic so the real reward table can hand a drum any resolved result later) and `FateDrum`, a faked-3D cylinder (classic 2D "carousel" trick: `FATE_DRUM_SLOT_COUNT` items spaced around a vertical ellipse, `depth = cos(angle)` and `offsetY = radius * sin(angle)` per slot). Only the front hemisphere (`depth > 0`) is drawn; the back hemisphere is where a slot's item gets silently swapped to a new one the instant it crosses in, so the reel appears to cycle through endless items without ever showing the swap (requirement 1).
  - `FateDrum` is a plain struct driven by an owner's Step/Draw, same pattern as `BlueprintController`/`SelectionController` -- not a GM instance.
  - `Spin()`/`Stop(_targetItem)` control state (`"stopped"`/`"spinning"`/`"stopping"`); stopping decelerates then snaps to the nearest slot boundary. `Stop` already accepts an optional `_targetItem` so the future weighted-reward task can force a specific landing result without touching this file again -- unused for now.
  - `GetLockedItem()` returns whichever item sits at the front/landing position, but only once `state == "stopped"` -- this is the "read the item it locked to" requirement (2), meant for a hover tooltip (or eventually cash-out payout).
  - Slots are populated by `FateDrumRandomPlaceholderItem()` -- a STUB that just cycles the 10 base-resource icons (`sResourceIcons`/`global.resourceIconOrder`). The real weighted reward table (resource building / training building / resource bundle / event, scaled by corruption) isn't designed yet -- this only exists so the spin/swap/lock mechanic is visually testable now.
- **`oFateEngineDrumTest`** (new object, temporary) -- spawns 3 `FateDrum`s, spins them on room start, click a spinning drum to stop it / a stopped one to re-spin, hover a stopped drum to see its locked item's label. Wired into `rmTestGameplay`. Explicitly a throwaway harness -- remove once the real Fate Engine overlay (lock buttons, spin/cash-out flow) exists.

### Build

- Windows export version bumped `0.0.2.21` → `0.0.2.22` — 4th-digit bump, same convention as last time.

## v0.0.2.21 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Resource buildings now fire a little particle burst every time they produce.

### Added

- **`oResourceProducedParticle`** (new object, `Effects` folder) -- a short-lived particle: drifts by its own `vx`/`vy`, gathers `RESOURCE_PARTICLE_GRAVITY`, fades out over `life`/`lifeMax`, then self-destroys. Draws either the resource's actual `sResourceIcons` frame (`kind == "icon"`) or a tiny flat-color square (`kind == "square"`) -- one object handles both since they share identical drift/fade/destroy behavior and only differ in what Draw does with them.
- **New `ResourceParticleScripts.gml`**: `SpawnResourceProducedParticles(_building, _resource)` spawns 1 icon particle (drifts straight up) + `RESOURCE_PARTICLE_SQUARE_COUNT` (6) square particles (1-2px, random outward burst angle/speed with an upward bias, color randomly interpolated between `RESOURCE_PARTICLE_GOLD_COLOR` (gold, #FFD700) and `c_white` via `merge_color`) at the building's position.
- **`PlayResourceProducedEffect` (`BuildingDefinitions.gml`) is no longer a debug-log stub** -- it now calls `SpawnResourceProducedParticles`, so every whole unit of resource `BuildingUpdateProduction` produces gets a real burst (still fires once per unit even when several are produced in the same frame).

### Fixed (mid-session)

- **`BuildingDefinitions.gml` was found truncated mid-edit** (cut off mid-word inside the new `PlayResourceProducedEffect` doc comment, missing the rest of the function) -- same underlying cause as the recurring `.yyp` truncation (the IDE open and saving alongside this session). Reconstructed from the known-correct content (this file's own just-written edit, not git history, since git predates this session's building/particle work) and reverified brace/paren balance. `Blank Pixel Game.yyp` needed the same fix again too, same procedure as every previous time.

### Noted, not acted on

- Per clarification: `blocked` correctly means "this plot can never be built on again" -- it's tied to a roguelike meta-progression mechanic (gaining more castle plots between runs), not a bug. The OTHER issue flagged last time (the `image_index = (!blocked) + (!inside)` formula in `oBuildingPlot/Step_0.gml` collides two unrelated states onto the same sprite frame) is still unresolved and independent of this clarification -- still holding off on touching it until you say what the 3 `sPlot` frames should actually represent.

### Build

- Windows export version bumped `0.0.2.20` → `0.0.2.21` — 4th-digit bump, same convention as last time.

## v0.0.2.20 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Wheat Field cost corrected, and playtest blueprint seeding now covers every registered building.

### Changed

- **Wheat Field's cost corrected to the sheet's "Wheat Farm" row**: 20 water + 10 wood (was 15 wood + 10 coins, which pre-dated this exact sheet row being consulted). Starting resources (50 wood/water/iron/gold/wheat) already fully cover it.
- **`oMatchControl`'s starting blueprint seed now gives each team one of every registered building** (Wheat Field, Peasant Ward, Boom Hut, Bog Foundry, Barracks, Archery Range, Round Table, Water Pump, Sawmill, Gold Mine, Iron Mine) instead of just 3x Wheat Field + 1x Peasant Ward -- playtest-only, per request. The final build will only start the player with one of each tier-1 RESOURCE blueprint specifically; noted in the comment so this doesn't get mistaken for the intended shipping loadout later.

### Investigated (not yet fixed -- pending design confirmation)

- **Why building plots visibly change appearance the instant a building is placed on them:** `oBuildingPlot/Step_0.gml` recomputes `image_index = (!blocked) + (!inside)` every single frame. `inside` (and `far`, unused here) are set once at plot spawn (`PlotScripts.gml`) and never change -- so in practice the only thing that ever changes this formula's result during a match is `blocked` flipping true the moment `TryPlaceBlueprint` places a building (`BlueprintScripts.gml`, `_plot.blocked = true`). That single flip always shifts `image_index` down by exactly 1 (since `!blocked` drops from 1 to 0), which is the visible "changes when built on" symptom.
  - There's a second, independent bug in the same formula: it only has 3 output values (0/1/2) for 4 possible (blocked, inside) combinations, so two unrelated states collide onto the same frame -- an unblocked INSIDE plot and a blocked OUTSIDE plot both compute to `image_index = 1` and render identically.
  - Sprite `sPlot` has exactly 3 frames, which just about fits the additive formula's range, but nothing documents what each frame is actually supposed to represent, and the raw PNGs don't make a confident semantic reading possible from code alone (frame 0 looks like a distinct paved/brick texture, frame 1 plain ground, frame 2 has a highlighted border). Not fixing this blind -- need to know the intended mapping (does "occupied" deserve its own dedicated frame regardless of inside/outside? should inside/outside still show through once blocked?) before touching it.

### Build

- Windows export version bumped `0.0.2.19` → `0.0.2.20` — 4th-digit bump, same convention as last time.

## v0.0.2.19 — 2026-07-05 (uncommitted — working tree only, not yet committed)

The remaining 4 tier-1 resource buildings are in: Water Pump, Sawmill, Gold Mine, Iron Mine.

### Added

- **`oWaterPump`, `oSawmill`, `oGoldMine`, `oIronMine`** -- new objects, all parented to `oResourceBuildingParent` (same inheritance chain as `oWheatField`: team/radius from `oBuildingParent`, then `BuildingApplyDefinition` + the Step-event production tick, all driven by the registered `BuildingDefinition` -- nothing building-specific in `Create_0.gml` beyond `event_inherited()`). Sprites (`sWaterPump`/`sSawmill`/`sGoldMine`/`sIronMine`) and their `Resource/` subfolders already existed in the project, pre-sized 48x48 with center origin to match every other building.
- **4 new `BuildingDefinition` registrations** (`BuildingDefinitions.gml`) -- cost and production rate are REAL, sheet-sourced values from the Item Costs sheet's "Production Buildings" section, not placeholders:
  - Water Pump: 20 wood → 1 water/sec.
  - Sawmill: 40 water → 1 wood/sec.
  - Gold Mine: 70 water + 30 iron → 1 gold/sec.
  - Iron Mine: 30 water + 60 wood → 1 iron/sec.
  - `maxHealth` is the one placeholder value (150, matching Wheat Field) -- the sheet has no building-HP column, same gap as every other building.
- **Not seeded into starting blueprints.** Following the same precedent set by the 5 tier-1 training buildings (Boom Hut/Bog Foundry/Barracks/Archery Range/Round Table) -- only Wheat Field/Peasant Ward are in the `oMatchControl` test-seed list, so these 4 are fully defined/placeable but won't appear in a fresh match until the real blueprint-acquisition system exists (still not designed) or someone adds test seeding for them.

### Known issues (flagged, not touched)

- **The sheet's "Wheat Farm" row (20 water + 10 wood → 1 wheat/sec) doesn't match this project's already-implemented Wheat Field cost** (15 wood + 10 coins, per the `oMatchControl/Create_0.gml` comment). Out of scope for this request (only asked for the other 4), but worth a look since it means Wheat Field was built before this exact sheet section was consulted, or the sheet changed since.

### Build

- Windows export version bumped `0.0.2.18` → `0.0.2.19` — 4th-digit bump, same convention as last time.

## v0.0.2.18 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Resource icon translation for Scribble text, plus the player's resource bar HUD.

### Added

- **New `ResourceUIScripts.gml`**, built around `global.resourceIconOrder` (wood, wheat, water, iron, gold, meat, bones, coal, weapons, coins -- a plain global array set once, not a `#macro`, since a macro array literal would re-allocate every read) matching `sResourceIcons`' 10 frames 1:1. xp/fateTokens intentionally have no icon (per request -- they sit outside the base resources).
  - **`ResourceIconIndex(_resource)`** -- name to frame index (0-9), or -1 if not a base resource.
  - **`ResourceIconTag(_resource)`** -- name to Scribble inline-sprite tag, `"[sResourceIcons,N]"`.
  - **`CostToScribbleText(_cost)`** -- the actual translator requested: takes a `Cost` struct and returns a ready-to-draw Scribble string, one `"[sResourceIcons,N]<amount>"` run per non-zero base resource (double-space separated). Nothing calls this yet -- no tooltip/description UI reads `BuildingDefinition.description`/`UnitDefinition.description` today, so this is the primitive future tooltip work will use, not wired to a specific screen.
  - **`DrawResourceBar(_team)`** -- renders all 10 icons in a row, first (Wood) icon centered at `(RESOURCE_BAR_ORIGIN_X, RESOURCE_BAR_ORIGIN_Y)` = (466, 1060), each next icon `RESOURCE_BAR_ICON_SPACING` (152px) to the right center-to-center, with `_team`'s live count drawn `RESOURCE_BAR_TEXT_GAP` (10px) off each icon's right EDGE (icon center + half its width + the gap), vertically centered on the icon. Wired into `oUnitControl/Draw_64.gml` as `DrawResourceBar(TEAM.PLAYER)`, alongside the other player-HUD draws.

### Build

- Windows export version bumped `0.0.2.17` → `0.0.2.18` — 4th-digit bump, same convention as last time.

## v0.0.2.17 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Unit selection no longer starts from a press in the bottom UI panel area.

### Changed

- **`SelectionController.BeginDrag()` (`UnitSelection.gml`) now no-ops if the press starts at or below `SELECTION_DRAG_MIN_GUI_Y` (812, out of a 1920x1080 GUI, per request).** Below that line is bottom-panel UI real estate (the blueprint panel, etc.), not the playfield -- a press there should never start a world-space selection box, including over empty panel padding that a widget's own hit-test doesn't claim (`BlueprintController.TryBeginDrag` only claims filled slots, so gaps between/around slots were previously falling through to a normal selection drag).
  - Since this codebase implements a plain click-select as a very-short drag (`EndDrag`'s `_isClick` heuristic), gating `BeginDrag` covers both drag-box selection AND single-click selection in one place -- a click starting below the line selects nothing, not just "doesn't start a box."
  - Only the drag's START is checked, per request -- a drag that begins above the line and is dragged down past it while held is unaffected.
  - Room-space `mouse_x`/`mouse_y` aren't usable for this check (camera-relative), so it reads `device_mouse_y_to_gui(0)`, the same GUI-space approach `BlueprintController` already uses for its own hit-testing.

### Build

- Windows export version bumped `0.0.2.16` → `0.0.2.17` — 4th-digit bump, same convention as last time.

## v0.0.2.16 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Blueprint UI panel repositioned and enlarged, per request.

### Changed

- **`BlueprintController.GetOrigin()` (`BlueprintScripts.gml`) now returns a fixed top-left anchor** (`BLUEPRINT_UI_ORIGIN_X/Y` = 660, 830) instead of the old bottom-center-of-GUI calculation. No longer depends on `display_get_gui_width/height`.
- **New `BLUEPRINT_UI_SCALE = 2` macro drives the whole panel's size.** `GetSlotRect` (the single source of truth both `Draw` and `TryBeginDrag` already read from) now multiplies `BLUEPRINT_SLOT_SIZE`/`BLUEPRINT_SLOT_PADDING` by this scale, so the clickable area and the drawn area stay identical automatically — nothing render-only or hit-test-only to keep in sync. Both `draw_sprite` calls (in-slot icon, dragged icon following the cursor) switched to `draw_sprite_ext` with `xscale`/`yscale` = `BLUEPRINT_UI_SCALE` so the building icons themselves scale up too, not just the slot borders.
- **Not scaled: the stack-count text** (`draw_text` for `_stack.count`). Wasn't asked for, and scaling text needs `draw_text_transformed` instead of a quick multiply -- left as-is against the now-2x slots. Flagging in case it reads too small once you see it in place.

### Build

- Windows export version bumped `0.0.2.15` → `0.0.2.16` — 4th-digit bump, same convention as last time.

## v0.0.2.15 — 2026-07-05 (uncommitted — working tree only, not yet committed)

Fixed a pre-existing `Purchase` bug the AI's build-up state finally triggered.

### Fixed

- **`Purchase(_costStruct, _team)` (`Economy.gml`) deducted against the wrong struct.** `Purchase` is a plain top-level function, not a `Cost` method, so `self` inside its body is whatever the *caller's* `self` happened to be — not `_costStruct`. Since `Purchase` is always called several plain-call frames deep (`TryPlaceBlueprint`/`TrainingScripts` → `Purchase`), and those chains are frequently entered via a dot-call on some other struct (a `State` struct via `currentState.onStep(owner, self)` for the AI path, `BlueprintController` for the player drag-to-place path), `self` at the point `Purchase` ran was that unrelated struct, not the `Cost` instance. `struct_get(self, _res)` then returned `undefined` for every resource key (starting with `wood`, first in iteration order), and `_resAmt - _costAmt` threw the reported `DoSub : undefined value` the moment a purchase actually got past `CanAfford`.
  - This was already present in `HEAD` before this session's XP/resource work touched the file — confirmed via `git show HEAD` — so it wasn't introduced by the new `xp`/`fateTokens` fields, it just needed a successful AI (or player) purchase to actually reach line 116 and fire. Likely the first time the AI's build-up state got resources + a valid plot at the same time.
  - `CanAfford` (the `static` method a few lines up) does NOT have this bug — it's called via `_costStruct.CanAfford(_team)`, a proper dot-call, which correctly binds `self` to `_costStruct` for that call.
  - Fix: read the cost amount off `_costStruct` explicitly (`struct_get(_costStruct, _res)`) instead of relying on the ambient `self`.
  - Worth a smoke test of both the AI build-up path and the player's manual drag-to-place, since both were exposed to this and neither may have been confirmed to fully complete a real deduction before.

### Build

- Windows export version bumped `0.0.2.14` → `0.0.2.15` — 4th-digit bump, same convention as last time.

## v0.0.2.14 — 2026-07-04 (uncommitted — working tree only, not yet committed)

Two new resources (XP, Fate Tokens) and a `GainXP` accumulator to drive them, plus a bug fix: three script files from the last two sessions' ranged-combat work were never actually registered with the project and would not have compiled.

### Added

- **`xp` and `fateTokens`** — two new per-team resources, added to `global.resources[_team]` (`oMatchControl/Create_0.gml`) and to `Cost`/`ResourceCost` (`Economy.gml`) alongside the existing 10, so `CanAfford`/`Purchase` pick them up for free (both already walk `global.resources` generically by field name). Both start at 0 for both teams — no starting loadout change.
- **`global.age`** (`oMatchControl/Create_0.gml`) — per-team current age, `[1, 1]` at match start. Ages and blueprint-tier-acquisition odds are explicitly NOT designed yet (per 2026-07-04 discussion) — nothing reads this to affect blueprints. It's just the counter.
- **`GainXP(_team, _amount)`** (new `ProgressionScripts.gml`) — the requested entry point for awarding XP; nothing calls it yet (XP sources aren't wired up — that's next). Adds `_amount` to the team's current age bar (`AGE_XP_REQUIRED` = 1000, flat placeholder, no per-age scaling designed):
  - Awards one Fate Token for each of the bar's 4 equal quarter-marks (`AGE_FATE_TOKEN_INTERVALS`) crossed by the gain, computed from before/after position so a large single gain still awards every token earned, not just one. Filling the bar outright nets exactly 4 tokens, with the 4th landing on the same call that ages the team up.
  - Advances `global.age[_team]` (capped at `AGE_MAX = 4`) each time the bar fills, carrying overflow into the next age's bar via a while-loop — a big enough gain can advance more than one age in one call.
  - **Judgment call, flagged for sanity-check:** once already at `AGE_MAX`, the bar stops at full instead of looping/prestiging — further XP past that point is discarded rather than granting more tokens indefinitely. Revisit once ages are actually designed.
  - Both the XP added and any Fate Tokens earned are recorded via the existing `AnalyticsRecordResourceProduced` hook, same as building production.

### Fixed

- **`ProjectileScripts.gml`, `UnitStateAttackRanged.gml`, and `UnitStateCombatRanged.gml` had no `.yy` files and were never added to `Blank Pixel Game.yyp`'s resource list.** These were created across the last two sessions' ranged-combat batches (projectile spawning/`SpawnProjectile`, the `attackRanged` state, and the `combatRanged` state) but a GameMaker script only compiles if it's a registered project resource — a loose `.gml` file on disk with no matching `.yy`/`.yyp` entry doesn't exist as far as the IDE/compiler is concerned. Net effect: `SpawnProjectile`, `AttackRanged_Enter/Step/Exit`, and `CombatRanged_Enter/Step/Exit` would have been undefined-function errors at runtime despite reading correctly in the source. Created the three missing `.yy` files and added all three to the `.yyp` (alphabetically, matching existing ordering). Worth a project reload + smoke test of an Archer fighting something, since this is the first time this code has had a chance to actually run.
- **`Blank Pixel Game.yyp` was found truncated again mid-session** (same failure mode as before — missing tail: `RoomOrderNodes` entries, `templateType`, `TextureGroups`, final `}`), discovered while validating this batch's edits. Reconstructed the same way as last time: working-tree content up to the truncation point + the stable tail from git HEAD (`RoomOrderNodes`/`templateType`/`TextureGroups` haven't changed all session), verified via JSON parse + duplicate-name check. This has now happened three times this project — may be worth checking whether something (an editor autosave, a sync tool) is racing writes to this file.

### Build

- Windows export version bumped `0.0.2.13` → `0.0.2.14` — 4th-digit bump, same convention as last time.

## v0.0.2.13 — 2026-07-03 (uncommitted — working tree only, not yet committed)

`ChooseCombatTarget` is a real weighted decision now, and every existing unweighted "just grab the nearest enemy" pick across guard/defend/attack/attackRanged/siege now routes through it.

### Added

- **`ChooseCombatTarget(_unit, _radius, _castlePos)`** (`GatherScripts.gml`, moved from the stub that used to live in `UnitScripts.gml`) — scores every enemy unit within `_radius` on four weighted criteria and returns the best one (or `noone` if nothing's in range, same contract the old stub and `_FindNearestEnemy` both had):
  - **Health remaining** (`COMBAT_TARGET_WEIGHT_HEALTH = 1.0`) — rewards low health (`damageTaken / maxHealth`), i.e. finishing off the wounded.
  - **Attack stat** (`COMBAT_TARGET_WEIGHT_ATTACK = 0.4`) — rewards high `attackDamage`, i.e. focusing the biggest threat. Raw value, not normalized -- flagged in the doc comment as a placeholder simplification.
  - **Proximity** (`COMBAT_TARGET_WEIGHT_PROXIMITY = 1.2`) — rewards closeness to the deciding unit.
  - **Activity** (`COMBAT_TARGET_WEIGHT_ACTIVITY = 1.0`, via new `_CombatTargetActivityScore`) — rewards a candidate currently attacking one of ours: sieging our castle scores highest, then attacking one of our buildings, then already fighting one of our units, then idle (guard/defend) scores 0. This is the "whether it is attacking a unit, building, or castle" criterion.
  - **Castle proximity** (`COMBAT_TARGET_WEIGHT_CASTLE = 0.8`, only when `_castlePos` is passed) — not one of the four requested criteria, added to preserve `_FindNearestEnemyInSweep`'s existing castle-proximity weighting for siege specifically, rather than silently dropping that behavior. Flagging this addition explicitly since it goes beyond what was asked for -- worth a sanity check.
  - All five weights are placeholders per instruction -- tune freely, nothing else depends on these specific numbers.
- **Every previous unweighted target pick now goes through it:** `Guard_Step`/`Defend_Step`'s aggro trigger, `Attack_Step`/`AttackRanged_Step`'s defender-interrupt, and all three guard-sweep checks in `Siege_Step` (ADVANCE/ASSAULT/RECOVER phases) were all calling `_FindNearestEnemy` or `_FindNearestEnemyInSweep` directly -- all now call `ChooseCombatTarget` instead. `Combat_Step`/`CombatRanged_Step`'s re-acquire-on-death call didn't need to change (it already called `ChooseCombatTarget(_unit)` with the stub; the real implementation's `_radius` parameter defaults to `_unit.attackAggroRadius` via the same `??=`-in-the-body idiom `UnitPursueTarget` already uses, since a parameter default can't reference an earlier parameter directly in GML).

### Known issues (new)

- **`_FindNearestEnemy`/`_FindNearestEnemyInSweep` (`GatherScripts.gml`) are now unused dead code**, left in place rather than deleted -- flagged in their own doc comments as superseded, in case something still wants a plain unweighted lookup. Candidates for removal if nothing ends up needing them.

### Build

- Windows export version bumped `0.0.2.12` → `0.0.2.13` — 4th-digit bump, same convention as last time.

## v0.0.2.12 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Buildings now use the same damage-taken setup as units, and "combat" is finally wired up the way it was originally designed: an interim state guard/defend pop into when they need to fight, then return from.

### Added

- **Building HP.** `BuildingDefinition` (`BuildingDefinitions.gml`) gained `maxHealth` (optional, defaults to 200 -- an unbalanced placeholder, same status every cost/rate number in that file already had; the data sheet has no building-HP column). `BuildingApplyDefinition` now sets `maxHealth`/`damageTaken` directly on every building instance, alongside its existing production/training fields. `oBuildingParent/Create_0.gml` also sets defensive `maxHealth = 0` / `damageTaken = 0` defaults, same "Create sets placeholders, a script function fills in the real ones right after" pattern as units/projectiles.
- **`ApplyDamage`/`GetCurrentHealth` generalized to work against buildings, not just units.** New `GetDamageTaken(_instance)`/`SetDamageTaken(_instance, _value)` (`UnitDefinitions.gml`) abstract over where damageTaken actually lives: nested at `unitData.damageTaken` for units (so it survives a station/redeploy swap) vs. a flat `damageTaken` directly on the instance for buildings (which have no station/redeploy concept to preserve it across). `UnitCurrentHealth` renamed to `GetCurrentHealth` to match -- grep confirmed exactly one caller (`ApplyDamage`) at rename time. Melee and ranged attacks against buildings now do real damage instead of silently no-opping.
- **"combat" is reachable for the first time.** It was registered in every unit's FSM since early on but nothing ever transitioned into it -- confirmed dead code as of last session. Per design, it's an interim state `guard`/`defend` pop into when they need to fight:
  - **Proximity aggro** -- `Guard_Step`/`Defend_Step` now check `_FindNearestEnemy(_unit, _unit.attackAggroRadius)` first thing every step (same mechanism `Attack_Step`'s defender-interrupt already used), and hand off to combat via new `UnitEnterCombat(_unit, _target)` (`UnitCombatHelpers.gml`) the instant something's in range.
  - **Reactive-on-hit** -- `ApplyDamage` now calls `UnitEnterCombat` the instant a non-lethal hit lands on a unit currently in `"guard"` or `"defend"`, using the attacker as the target. A unit already fighting (attack/attackRanged/siege/combat/combatRanged) is left alone -- taking a hit doesn't retarget it.
  - **`UnitEnterCombat`** picks `"combat"` or `"combatRanged"` based on the unit's `"ranged"` tag -- same dispatch the `"attack"` order already used for `"attack"` vs `"attackRanged"`.
  - **`UnitRevertFromCombat(_machine)`** replaces `Combat_Step`'s two hardcoded `ChangeState("guard")` exits (no target / target leashed) with `_machine.RevertToPrevious()` (`StateMachine.gml` -- already existed, never used until now), so a unit correctly goes back to whichever of guard/defend it was interrupted from, not always guard. Falls back to `"guard"` if `previousName` is somehow unset, so a unit can never get stuck in combat with nowhere to revert to.
  - **New `"combatRanged"` state** (`scripts/UnitStateCombatRanged.gml`) -- structural duplicate of `"combat"` (same reasoning as `"attackRanged"`/`"attack"`: this codebase already hit a bug from sharing state functions across orders), swapping `UnitTryFireProjectile` in for `UnitTryDealDamage` at the attack phase. Registered in `oUnitParent/Create_0.gml` alongside the other states.

### Known issues (new)

- **`ChooseCombatTarget` is still a stub** (always returns `noone`). When a unit's combat target dies mid-fight, it reverts to guard/defend rather than picking a new one -- if another enemy is still in aggro range, the outer proximity check (now running every Guard_Step/Defend_Step) picks it back up on the next step regardless, so this mostly self-heals, but a true "keep fighting whoever's closest" re-target was not built this session.
- **Reactive-on-hit only fires from `"guard"`/`"defend"`.** A unit mid-`"attack"`/`"siege"` that takes a hit from a THIRD party (not its current target) doesn't do anything differently -- only `"attack"`/`"attackRanged"`'s own built-in defender-interrupt (proximity-based, not damage-based) handles that case.

### Build

- Windows export version bumped `0.0.2.11` → `0.0.2.12` — 4th-digit bump, same convention as last time.

## v0.0.2.11 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Real damage/death for the first time, plus a ranged attack system (projectile spawn, spawn/arc/land, hit resolution) built on top of it. Archer is the first unit to use it.

### Fixed

- **`Blank Pixel Game.yyp` was truncated mid-write** (cut off partway through the sprite resource list, missing the closing `resources` bracket and the entire `RoomOrderNodes`/`templateType`/`TextureGroups` tail) by an external save that landed while this session was mid-edit. Reconstructed by taking the working tree's content up to the truncation point (which already had every object this session and prior sessions added) and appending the missing tail from the last commit (`54e76cd`) unchanged. Verified: parses cleanly, no duplicate resource names, every object added this session and prior sessions is still present exactly once.
- **`UnitTryDealDamage`'s "TODO: damage calculation" stub is gone.** It now calls the new `ApplyDamage` (see Added). This is the actual fix requested this session -- everything else below follows from it.

### Added

- **`ApplyDamage(_target, _amount, _source)`** (`UnitCombatHelpers.gml`) — the first real damage-application function in the codebase. Increments `unitData.damageTaken` (clamped to `maxHealth`) rather than tracking a separate "current health" value, so a future max-health buff/debuff never needs a second number rewritten in lockstep — `UnitCurrentHealth` (`UnitDefinitions.gml`, already existed) always derives the live value from the one stored number. Destroys `_target` the instant health reaches 0 — the first place anything in this codebase can actually die — and calls `AnalyticsRecordDeath`/`AnalyticsRecordKill` (`AnalyticsScripts.gml`), which existed already but had no death event to call them from until now. Buildings have no `unitData`/hp concept yet — calling `ApplyDamage` against one logs and no-ops rather than crashing; that's a separate, undesigned system, flagged rather than guessed at.
- **Ranged attack system**, generalized beyond just Archer:
  - **`oProjectileParent`** (root object) + **`oArcherProjectile`** (its first child, sprite `sArcherProjectile`). New `scripts/ProjectileScripts.gml`: `SpawnProjectile`/`ProjectileInit` (set up per-instance state right after `instance_create_layer`, same pattern as `BuildingApplyDefinition`/`UnitApplyDefinition`/`TrainingSpawnUnit`), `ProjectileUpdateMovement` (real x/y position — straight-line `Vector2.Lerp` from launch point to the target's position *at the moment of firing*, not homing, match-speed-scaled same `delta_time` idiom as `BuildingUpdateProduction`), `ProjectileResolveHit` (calls `ApplyDamage` if the target's still there when it arrives, then destroys the projectile either way), `ProjectileArcOffset`/`ProjectileDraw` (the cosmetic parabolic arc: a per-instance vertical draw offset that's 0 at launch/landing and peaks at the midpoint, with a rotation numerically sampled from that same offset function so the drawn angle can't drift out of sync with the drawn position — nose-up at launch, level at the apex, nose-down at landing). The projectile's real, stored `image_angle` is set once at launch to the flat straight-line direction and never touched again; the arc-following rotation is computed separately in `ProjectileDraw` and used only for that draw call.
  - **`UnitTryFireProjectile`** (`UnitCombatHelpers.gml`) — ranged counterpart to `UnitTryDealDamage`, same once-per-swing/hit-frame gating, calls `SpawnProjectile` instead of applying damage on the spot.
  - **`"attackRanged"` FSM state** (new `scripts/UnitStateAttackRanged.gml`) — ranged counterpart to `"attack"` (`UnitStateAttackMelee.gml`). Deliberately a structural duplicate (approach/swing/recover/defender, same as `"attack"`) rather than a branch inside it, matching this codebase's existing precedent of one dedicated state per order rather than shared/branching state logic (see the `"attack"`/`"siege"` dead-code bug from `v0.0.1.0`). The only actual difference from `"attack"` is that both swing points call `UnitTryFireProjectile` instead of `UnitTryDealDamage`.
  - **`UnitDefinition.projectileObject`** (`UnitDefinitions.gml`) — optional field, the projectile a ranged unit fires. Set for Archer (`oArcherProjectile`); left unset (melee) for everyone else.
- **FLAG (FSM/order wiring — CLAUDE.md calls `attack`/`combat`/etc. load-bearing):** `oUnitParent/Create_0.gml` now registers `"attackRanged"` alongside the existing states (purely additive). The `"attack"` order's `onIssue` (`OrderWiring.gml`) now picks `"attackRanged"` vs `"attack"` per unit based on `UnitHasTag(unit, "ranged")` — the one line that changed in that function.

### Known issues (new)

- **Buildings still have no HP.** `ApplyDamage` logs and no-ops against them. Melee units can still swing at buildings (nothing about that changed), it just doesn't do anything yet.
- **The `"combat"` FSM state is unreachable dead code** — discovered this session while scoping where ranged behavior needed to hook in. Nothing anywhere calls `fsm.ChangeState("combat")`; the only currently-reachable attack path is the `"attack"`/`"attackRanged"` order (with its own built-in defender-interrupt sub-phase). Not touched this session since it's unreachable regardless, but worth knowing if `"combat"` is ever wired up for real — it would need the same ranged/melee split `"attack"` just got.
- **`"siege"` was not touched.** A ranged unit sieging a castle still goes through whatever `"siege"` does today (untouched, not investigated this session for building-HP reasons above).
- **Archer's `attackRange` (96) is still a judgment-call placeholder**, not sheet-sourced — the ranged mechanic is now real, but its numbers aren't tuned.

### Build

- Windows export version bumped `0.0.2.10` → `0.0.2.11` — 4th-digit bump, same convention as last time.

## v0.0.2.10 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Peasant stat correction + five tier-1 training buildings/units, sourced from the Project Azurite Data Sheets spreadsheet (Unit Stats + Item Costs tabs).

### Fixed

- **`PATCH_NOTES.md` was truncated in the working tree**, cutting off mid-sentence partway through the v0.0.2.0 entry and dropping the entire v0.0.1.0 entry below it. Restored from the last commit (`54e76cd`, "V. 0.0.3.0") before adding this entry. Worth a quick look separately: that commit's message says `0.0.3.0` but `options_windows.yy` at that same commit is `0.0.2.9` — a mismatch between the commit title and the actual file, not something this session tried to resolve.
- **Peasant's stats didn't match the design spec** (`scripts/UnitDefinitions/UnitDefinitions.gml`): `maxHealth` 20→10, `attackDamage` 3→2, `cost` was `10 wheat + 5 coins` → now `20 water` (this also brings it in line with `oPeasantWard.trainCost`, which was already correct). Training cost/time (20 water / 10 sec) and Peasant Ward's build cost (40 wheat + 40 water) were already correct and untouched.

### Added

- **Five tier-1 buildings**: `oBoomHut` (trains Bomb Goblins), `oBogFoundry` (Mud Golems), `oBarracks` (Soldiers), `oArcheryRange` (Archers), `oRoundTable` (Knights). Each is a plain `oTrainingBuildingParent` child (`event_inherited()` only, same pattern as `oPeasantWard`) registered in `scripts/BuildingDefinitions/BuildingDefinitions.gml` with build cost, `trainsUnit`, `unitsPerBuilding`, `trainCost`, and `trainTime` all sourced from the data sheet. No changes needed to `TrainingScripts.gml` or `oTrainingBuildingParent` itself — the training pipeline was already fully data-driven.
- **Five tier-1 units**: `oBombGoblinUnit`, `oMudGolemUnit`, `oSoldierUnit`, `oArcherUnit`, `oKnightUnit`. Each is a plain `oUnitParent` child (`event_inherited()` only, same pattern as `oPeasantUnit`), registered in `scripts/UnitDefinitions/UnitDefinitions.gml` with sheet-sourced `maxHealth`/`attackDamage`/`cost`. Combat-timing fields with no sheet equivalent (`attackRange`, `attackLeashRange`, `attackHitFrame`, `attackCooldownMax`, `attackAggroRadius`, `siegeSweepRadius`, `maxSpeed`) are judgment-call placeholders, same status Peasant's always had.
- Each new unit's sheet "Stationed Effect"/"Deployed Effect" text is now captured in its `UnitDefinition.passives` array (inert data, per that field's existing documented convention — no station/deploy system exists yet to execute any of it).
- All 10 new objects registered in `Blank Pixel Game.yyp`.

### Known issues (new — flagged rather than guessed at)

- **No station/deploy economy exists.** The data sheet adds a per-unit "Station Deploy Cost (GOLD)" and per-unit "Upkeep (Stationed)" (e.g. Archer: 1 wheat/3 sec) on top of training cost. Neither has a field anywhere (`UnitDefinition` or `BuildingDefinition`) — deliberately not guessing at a shape for a system that isn't designed. The `"station"` order is still the no-op stub it's been since it was registered.
- **`UnitTryDealDamage` (`UnitCombatHelpers.gml`) is still a TODO stub** — no unit has ever actually dealt damage or died. This was already true before this batch, but it means several of this batch's signature mechanics can't be real yet either: Bomb Goblin's AoE (currently a flat `20` on `attackDamage`) and its self-destruct-on-hit, Mud Golem's on-death mud/slow zone (no on-death hook exists at all), and Knight's bonus damage vs. production buildings (`Attack_Step` doesn't distinguish building types).
- **Archer has no ranged attack.** Only a melee attack state (`UnitStateAttackMelee.gml`) exists — no projectile/ranged state. Archer is registered with a longer `attackRange` as a rough stand-in, but it will walk into range and melee-swing like every other unit. `sArcherProjectile` is wired into its `AnimationLibrary` as a named `"projectile"` sprite, ready for whenever a real ranged state gets built.
- Sheet data-quality notes carried over from the earlier review (not re-litigated here): Shinobi's Source Building is blank in Unit Stats but Item Costs' "Hidden Village" (tagged tier 1) is almost certainly it; Recruiter is a real tier-3 unit (50 Gold Coins, per Item Costs) with no stat block in Unit Stats; Jester/Necrotic Lich's unit limit is the string `"1 (HARD CAP)"` while Hellhounds' is a plain `1` — `TrainingTypeLimit` (`TrainingScripts.gml`) has no flat-cap path yet, only `sum(unitsPerBuilding × live buildings)`.

### Build

- Windows export version bumped `0.0.2.9` → `0.0.2.10` — 4th-digit bump, per the documented convention (3rd digit only when patch notes are explicitly requested, which wasn't the case this session).

## v0.0.2.8 — 2026-07-03 (uncommitted — working tree only, not yet committed)

Base-building economy loop: drag-to-place buildings, resource production, unit training with dual caps, edge-pan camera, local playtest analytics, and a Steamworks SDK integration scaffold. Also carries the fixes from the 2026-07-01 code review, which were made same-day but hadn't been written up yet.

### Added

- **Blueprint system** (`scripts/BlueprintScripts.gml`). `BlueprintStack`/`AddBlueprint`/`RemoveBlueprintOne` manage a per-team placeable-building inventory (`global.blueprints`, initialized `[[], []]` in `oMatchControl/Create_0.gml` — deliberately not `array_create(2, [])`, same shared-reference hazard `global.resources` had, see Fixed below). `BlueprintController` is the drag-to-place UI: a paginated 5x2 GUI-space grid, wired into `oUnitControl` (`Create_0`/`Step_0`/`Draw_64`) alongside `selectionController`/`orderMenu`. Dragging a filled slot onto an owned, unblocked `oBuildingPlot` checks affordability, purchases the cost, spawns the building, and consumes one blueprint.
- **`BuildingDefinition` system** (`scripts/BuildingDefinitions.gml`) — static per-building-type data (name, description, cost, sprite, optional resource production, optional unit training), registered per object type via `RegisterAllBuildingDefinitions()` (called from `oGameControl`'s Create, alongside `RegisterAllUnitDefinitions()`). Mirrors `UnitDefinition`'s registry pattern. `BuildingApplyDefinition(_building)` applies production/training fields onto an instance at Create time.
- **Resource production** — `oResourceBuildingParent` (new parent) and `oWheatField` (first resource building). `BuildingUpdateProduction()` is a frame-rate-independent, match-speed-scaled tick using a fractional accumulator (so partial progress isn't lost or double-counted across frames), ticked from `oResourceBuildingParent/Step_0.gml`. Calls the existing `PlayResourceProducedEffect` stub once per whole unit produced.
- **Unit training** — `oTrainingBuildingParent` (new parent) and `oPeasantWard` (first training building). `scripts/TrainingScripts.gml` enforces two independent caps before queueing a unit: a per-type cap (`TrainingTypeLimit` — sum of `unitsPerBuilding` across a team's live training buildings of that type) and an army-wide cap (`global.armyLimit`, `[6, 6]` starting value). Both caps count existing units *and* everything queued across every training building the team owns. Clicking an owned training building (`oUnitControl/Step_0.gml`, via `instance_position`) calls `TrainingTryQueueUnit`; `TrainingUpdateQueue` (ticked from `oTrainingBuildingParent/Step_0.gml`) is duration-based (not rate-based) and spawns via `TrainingSpawnUnit`, which overrides the spawned unit's team (same pattern `BlueprintController.EndDrag` uses for buildings) and re-derives `guardRect` for the correct team before sending the unit into `"defend"`, patrolling the building that trained it.
- **`UpdateCameraPan()`** (`scripts/CameraScripts.gml`) — edge-of-screen camera panning on view camera 0, ramping linearly with cursor proximity to the screen edge, clamped to room bounds. Called once per Step from `oUnitControl`.
- **Local playtest analytics** (`scripts/AnalyticsScripts.gml`) — per-team (`global.analytics[TEAM.PLAYER/ENEMY]`) counters for units trained, buildings built, resource produced/spent, and match time, reset each match via `AnalyticsInit()` (`oMatchControl`'s Create). Wired into `TrainingSpawnUnit`, `BlueprintController.EndDrag`, `BuildingUpdateProduction`, `Purchase` (`Economy.gml`), and `oMatchControl/Step_0.gml`. Steam Stats API calls (`steam_set_stat_int`) are written but left commented out — the stat names don't exist on the Steamworks control panel yet. `AnalyticsRecordKill`/`AnalyticsRecordDeath` exist but aren't wired to anything yet — there's still no "unit died" event.
- **Steamworks SDK extension** (`extensions/Steamworks/`, `scripts/Steamworks_Definitions.gml`) integrated. `global.isGameRestarting` flag added (`oGameControl`'s Create) — needs to be set `true` immediately before any future `game_restart()` call so `steam_shutdown()` is correctly skipped on restart, then reset to `false` right after.
- A generic GameMaker UI widget starter kit (`obj_gm_button`, `obj_gm_text`, `obj_gm_textbox` + matching sprites/fonts) was imported alongside the Steamworks asset package. Not yet wired into any room or gameplay object — sitting unused for now.
- Starting resources for `TEAM.PLAYER`: 50 wood/water/iron/gold/wheat (`oMatchControl/Create_0.gml`). A few Wheat Field and Peasant Ward blueprints are granted as test data so the new flows are testable end-to-end before a real blueprint-acquisition system exists.
- Windows build version bumped to `0.0.2.8`.

### Fixed (made 2026-07-01, written up now)

- **`global.resources` array-sharing bug.** `oMatchControl/Create_0.gml` now builds `global.resources` via `array_create(2, undefined)` followed by a loop assigning a fresh struct literal per team, instead of `array_create(2, {...})`, which evaluated the struct literal once and gave both teams the same reference.
- **Attack/Combat/Siege sprite-state self-rebinding bug.** `sprite_index`/`image_index`/`image_speed` writes in `UnitStateAttackMelee.gml`, `UnitStateCombat.gml`, `UnitStateSiege.gml`, and `UnitCombatHelpers.gml` now go through `_unit.` explicitly instead of bare variables, so they land on the real unit instance instead of the scratch `State` struct.
- **`oBuildingPlot`'s `team` Object Property** changed from String (default `"player"`) to Integer (default `0` / `TEAM.PLAYER`), matching how `team` is used as the `TEAM` enum everywhere else.
- Typo fix in the pre-alpha disclaimer text (`oAlphaDisclaimer`): "encoutner" → "encounter".

### Known issues (new or still open)

- `objects/oUnitParent/Draw_0.gml` still has `if mask_index = sM_UnitMask{` (`=` instead of `==`) — legal GML, functionally fine, still not normalized after being flagged twice now.
- The Wheat Field's placement cost (15 wood + 10 coins) can't actually be paid yet — coins isn't part of the starting loadout and there's no acquisition/trading system to earn it. The Peasant Ward is unaffected and fully testable.
- The new `obj_gm_button`/`obj_gm_text`/`obj_gm_textbox` widget kit is imported but unused.
- `AnalyticsRecordKill`/`AnalyticsRecordDeath` have no death event to call them from yet (same root cause as `UnitTryDealDamage`'s open damage-calc TODO).
- **This entire entry describes uncommitted working-tree changes** — nothing above has been committed to git yet (last commit: `5012d06`). Recommend committing before doing anything that could touch the working tree.

## v0.0.2.0 — 2026-07-01

Base-building foundations: unit type data, castle building plots (both sides), and team-symmetric guard zones.

### Added

- **`UnitDefinition` system** (`scripts/UnitDefinitions`). Static per-unit-type data — name, description, `Cost`, combat stats, sprite library, tags, `availableOrders`, and a placeholder `passives` array — registered per object type (keyed by `object_index`, e.g. `oPeasantUnit`) rather than a string name, so it ties directly to `instance_create_layer` for later stationed-unit redeploy. `UnitApplyDefinition(_unit)` applies a unit's registered definition onto the instance at Create time; `oPeasantUnit`'s Create event is now just `event_inherited()` since sprites/orders come from its definition instead of being hardcoded twice. Peasant is the first (and only) unit type defined — its cost and stats are placeholders, not balanced.
- **`UnitDataBlock.unitType`** — the struct meant to survive a station/redeploy swap (damage taken, status effects) now also remembers which `UnitDefinition` to reapply. `UnitCurrentHealth(_unit)` derives current health from `maxHealth - unitData.damageTaken` rather than storing it separately, so nothing can drift out of sync across that swap.
- **`UnitHasTag(_unit, _tag)`** — first search-script helper built on `UnitDefinition.tags`.
- **Outer building plots.** 12 plots per side (8 "near" the castle wall in two groups of 4, 4 "far" into the battlefield in two groups of 2, aligned on a single shared column) outside each castle, mirrored player/enemy via `room_width - x` (same axis `oCastleManager` mirrors the castles on). New `scripts/PlotScripts` (`SpawnBuildingPlot`) and `oOuterPlotSpawner`. Classification reuses `oBuildingPlot`'s existing `inside`/`far` fields — no new schema needed. Resource buildings get a placement bonus outside the castle, unit-training buildings get theirs inside, and *far* plots get a bonus on top of that regardless of building type, since they're the most exposed to attack.
- **`GetTeamGuardRect(_team)`** (`UnitScripts.gml`). The default guard patrol zone a unit gets at Create time is now derived per-team instead of being one hardcoded rectangle. Player's zone is authored directly; every other team's is the same rectangle mirrored across `room_width`, so it sits the same distance in front of its own castle.

### Fixed

- **`oPlotSpawner`'s inside-castle plot grid never set which team owned a plot.** Only the player's grid existed, and even it wasn't team-tagged. Rewrote it to spawn both the player's grid and a mirrored enemy grid, both correctly tagged via `SpawnBuildingPlot` — the enemy castle had zero inside plots before this.
- **Guard zone was shared, unmirrored, across both teams.** Every unit — player or enemy — got the literal same `ShapeRect(328,8,480,400)`, which sits in front of the *player's* castle only. Now routed through `GetTeamGuardRect`.
- Outer plot placement went through two iterations this session: shifted clear of the default guard zone (was overlapping it), spread further from the play area's vertical center, and the "far" plots collapsed onto one shared column instead of two.

### Known issues (unchanged from v0.0.1.0, still open)

- `"station"` order is registered but intentionally a no-op — castle-interior stationing isn't designed yet.
- `UnitDefinition.passives` is inert data with no execution hook — no passive-ability system exists yet.
- `defend`/`attack` order target validators now take an issuing team, but nothing except the player's `SelectionController` calls them yet — the AI still bypasses targeting entirely.

### Build

- Windows export version bumped to `0.0.2.0` (patch notes requested — per the versioning convention, 3rd digit bumps here, 4th digit bumps on routine small changes).

## v0.0.1.0 — 2026-07-01

Early development pass: documentation cleanup, several load-bearing bug fixes, and the first version of the computer opponent.

### Fixed

- **Order menu wouldn't open after selecting units.** `oUnitControl`'s Step event was checking for a menu-opening right-click *after* processing the menu's own Update() in the wrong order, so a click that opened the menu was immediately re-read as a "dismiss" click in the same frame. Reordered so the menu's Update() always sees the state of the mouse from the *start* of the frame.
- **Attack and Siege orders were silently dead code.** Both were wired to the "combat" state's Enter/Step/Exit functions in `oUnitParent`'s state machine setup instead of their own dedicated functions. Units issued "attack" or "siege" were actually just running combat logic. Fixed the state machine wiring so each order runs its own state.
- **Guard waypoint anti-overlap logic was a no-op.** A leftover line in `GuardPickWaypoint` (`scripts/UnitStateGuard`) short-circuited the loop that checks for waypoints already claimed by another guarding ally, so units could pile onto the same spot. Removed the offending line; the claim-check now actually runs.
- **Economy typo:** `Puchase` → `Purchase` in `scripts/Economy`.
- **Defend/Attack target validation was hardcoded to the player's perspective.** The target-eligibility checks for the "Defend Building" and "Attack Building" orders assumed `TEAM.PLAYER` was always "my side." Reworked so the validator receives the issuing side's own team and compares against that instead — same code now works correctly no matter which side (player or AI) issues the order.

### Added

- **First pass at a computer-controlled opponent** (`oAIControl` / `AIBrain`). Runs a decision cycle roughly every 3/4 second; currently masses idle guarding units and sends them to siege the enemy castle once it has enough. Built on the same order-dispatch path (`IssueOrderToUnits`) the player uses, so player and AI units behave identically once an order is issued. This is a scaffold — defending, expanding, and building/unit purchasing are not implemented yet, but the plumbing (perception → decision → dispatch) is proven end to end.
- **`GatherTeamUnits`** — room-wide "every unit on team X" query for AI/high-level decision-making, written so a future fog-of-war visibility filter (once building placement ships) only needs to be added in one place.
- **`_FindNearestEnemy`** — plain nearest-enemy-unit lookup used by the aggro-interrupt check in the Attack state.

### Changed

- **Unified team representation onto the `TEAM` enum.** Team was previously represented two ways — the raw strings `"player"`/`"enemy"` in some places, and the `TEAM.PLAYER`/`TEAM.ENEMY` enum (needed for indexing `global.resources`, since GML arrays can't take string keys) in others. Everything now uses the enum consistently (`oUnitParent`, `oBuildingParent`, `oUnitControl`, `GetEnemyCastle`).
- **Full Feather/JSDoc documentation pass** across every non-vendor Script Asset (140 functions across 16 files). Every function now has `@function`, `@param`, and `@returns` tags so Feather reliably shows hover info while writing code against these libraries. Vendored Scribble library files were left untouched.

### Known issues (flagged, not yet addressed)

- The `"station"` order appears in units' `availableOrders` but is never registered in `RegisterAllOrders()` — picking it currently does nothing.
- A second, unused `UnitOrders` enum (GUARD/DEFEND/ATTACK/SIEGE/STATION) exists alongside the raw order-name strings actually used everywhere — a similar duplication to the team-representation issue that was just resolved, but not yet raised for a decision.

### Build

- Windows export version set to `0.0.1.0` to reflect actual development stage (was defaulted to `1.0.0.0`). Going forward: bump the 4th number for routine small changes; bump the 3rd number when patch notes are requested.
