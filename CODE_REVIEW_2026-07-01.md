# Code Review — 2026-07-01 (overnight pass)

Full pass over every project script (`scripts/`, excluding the vendored Scribble library) and every object event script (`objects/`), plus a spot-check of object-hierarchy `.yy` files and object properties. Ordered roughly by severity. Anything touching guard/defend/combat/attack/siege FSM wiring was flagged before being changed, per standing project rules.

**Update:** items 1, 2, 4, and the typo/JSDoc items under 5 were fixed same day, per your go-ahead. Item 3 (castles) turned out to be intentional, not a gap. See the note under each section below.

## 1. `global.resources` — both teams share the same struct (critical, not yet triggered) — FIXED

`oMatchControl/Create_0.gml`:

```
global.resources = array_create(2, {
    wood: 0, wheat: 0, ... coins: 0
});
```

`array_create(size, value)` fills every slot with the same *reference* when `value` is a struct — it does not deep-copy per slot. That struct literal is evaluated once, so `global.resources[TEAM.PLAYER]` and `global.resources[TEAM.ENEMY]` are literally the same object. This is a documented GameMaker gotcha, not a guess on my part.

Right now this is dormant because nothing calls `Purchase()`/`CanAfford()` in actual gameplay yet. The moment purchasing is wired up, player and enemy resources will silently pool together — spending gold as the player will also drain the AI's stockpile and vice versa.

**Fixed:** `oMatchControl/Create_0.gml` now does `global.resources = array_create(2, undefined);` followed by a `for` loop that assigns a fresh struct literal to each slot, so `TEAM.PLAYER` and `TEAM.ENEMY` genuinely own separate structs.

## 2. Attack/Combat/Siege sprite state never touches the real unit (FSM-adjacent) — FIXED

`sprite_index`, `image_index`, and `image_speed` are written as bare variables (no `_unit.` prefix, no `with(_unit)`) throughout `Attack_Enter`/`Attack_Step` (UnitStateAttackMelee.gml), `Combat_Enter`/`Combat_Step` (UnitStateCombat.gml), `Siege_Enter`/`Siege_Step` (UnitStateSiege.gml), and in `UnitBeginSwing`/`UnitEndSwing`/`UnitAttackAnimComplete` (UnitCombatHelpers.gml).

The problem: these functions are called as `currentState.onStep(owner, self)` from inside `StateMachine.Step()`, and GML rebinds `self` to whatever struct owns the function being dot-called. That means `self` inside `Attack_Step` etc. is the small `State` struct (`{onEnter, onStep, onDraw, onExit}`) that `AddState()` created — not the unit instance. So `sprite_index = _unit.sprAttack;` isn't writing to the unit's real displayed sprite; it's creating/overwriting a `sprite_index` field on that scratch `State` struct, which nothing else reads. Same story for `image_index`/`image_speed`.

You can see the correct pattern already established elsewhere in the same codebase: `UnitUpdateSprite()` (UnitScripts.gml) always writes through `_unit.sprite_index =` / `_unit.image_xscale =` explicitly, and `Guard_Step`/`Defend_Step` route anything that needs real instance semantics through `with(_unit) { ... }`. Attack/Combat/Siege don't follow that.

Practical effect: `UnitBeginSwing` never actually switches the unit to its attack sprite on the real instance, and `UnitAttackAnimComplete`'s `image_index >= sprite_get_number(...) - 1` check reads a frozen, never-incremented struct field instead of the unit's real (auto-animating) `image_index` — so swing completion is effectively decoupled from the actual animation. In practice `UnitIdleInPlace`/`UnitPursueTarget` (which correctly call `UnitUpdateSprite(_unit)` every frame) are probably masking this visually by continuously resetting the unit back to idle/walk sprite, so combat may look like it "works" at a glance while the swing-timing logic underneath is running on bogus data.

**Fixed:** every bare `sprite_index =`/`image_index =`/`image_speed =` (and the one `sprite_index !=` check) in `UnitStateAttackMelee.gml`, `UnitStateCombat.gml`, `UnitStateSiege.gml`, and `UnitCombatHelpers.gml` (`UnitBeginSwing`, `UnitEndSwing`, `UnitAttackAnimComplete`) now goes through `_unit.` — matches the pattern `UnitUpdateSprite()` already used.

## 3. `oPlayerCastle` / `oEnemyCastle` don't inherit `oBuildingParent` — INTENTIONAL, no action

Both `.yy` files have `parentObjectId: null`, and neither object has any event scripts at all (no Create event — just a sprite/collision mask from the .yy). Per your own documented hierarchy (`oBuildingParent — has team, always 48×48`), castles read like they should be buildings but currently aren't part of that family.

Concretely, this means: castles never get a `team` or `radius` field; `GatherNearbyObstacles()` won't find them (it only queries `oBuildingParent`), so units don't treat castles as obstacles to avoid; `move_and_collide(_delta, [oBuildingParent, oEnvironmentSolid])` doesn't include them either, so as far as I can tell units can currently walk straight through both castles; and the `"defend"`/`"attack"` order target validators (`object_is_ancestor(_instance.object_index, oBuildingParent)`) will always reject a castle as a target, so those two orders can never be pointed at a castle — only `"siege"` can ever reach one, via `GetEnemyCastle()`.

**Resolved (no change made):** confirmed intentional — castles aren't a placeable building in the game's logic and play a different role in the game loop than `oBuildingParent`'s family, so they're deliberately not part of that hierarchy.

## 4. `oBuildingPlot`'s `team` Object Property defaults to the string `"player"`, not the `TEAM` enum — FIXED

In `oBuildingPlot.yy`, the `team` Object Property has `varType: 2` (String) with default value `"player"`, while `inside`/`far`/`blocked` are correctly `varType: 3` (Boolean). Everywhere else in the codebase, team is the numeric `TEAM` enum (`TEAM.PLAYER` = 0, `TEAM.ENEMY` = 1). `SpawnBuildingPlot()` always immediately overwrites `.team` with the real enum value right after `instance_create_layer`, so this is currently dead — every plot in the game today goes through that function. But the property panel default is real-typed-wrong, so if a plot is ever placed directly in a room via the IDE (bypassing `SpawnBuildingPlot`), or someone edits the per-instance override in the Room Editor, it'll silently hold a string that will never `==` `TEAM.PLAYER`/`TEAM.ENEMY`. **Fixed:** `team`'s Object Property is now `varType: 1` (Integer) with default `"0"` (`TEAM.PLAYER`), matching how the field is actually used everywhere else. Confirmed the `varType` enum ordering (`Real, Integer, String, Boolean, Expression, Asset, List, Colour`) against GameMaker's own `.yy` typings before editing, rather than guessing at the numeric code.

## 5. Minor items

The pre-alpha disclaimer text (`oAlphaDisclaimer/Create_0.gml`) had a typo: "You may encoutner bugs" → "encounter." **Fixed.**

`Vector2.Set(_x, _y)` (Math.gml) accepts either two reals or a single `Vector2` as `_x` (there's an `is_struct(_x)` branch); its JSDoc `@param` types now document both accepted forms instead of just `{Real}`. **Fixed.**

Still open, not addressed this round: `oUnitParent/Draw_0.gml` has `if mask_index = sM_UnitMask{` — GML treats `=` as valid equality in a condition so this isn't broken, just inconsistent with the `==` used everywhere else. `oUnitControl/Draw_64.gml` unconditionally draws the selection array + order-menu state to the GUI every frame, not gated behind the F1 debug-overlay toggle like `oGameControl`'s debug log — may be intentional for early dev. `UnitTryDealDamage`'s damage-calculation `TODO` is still open (already clearly marked as a stub in its own comments).

## Status

Items 1, 2, 4, and the typo/JSDoc items under 5 are fixed and verified in-repo. Item 3 needed no change (confirmed intentional). The two remaining minor items under 5 are still open, low-priority, and not yet actioned.

I didn't deep-audit room instance placement data (`rmTestGameplay.yy` etc.) beyond what earlier work already touched, sprite/asset content, or the vendored Scribble library (per your standing instruction — those files aren't yours).
