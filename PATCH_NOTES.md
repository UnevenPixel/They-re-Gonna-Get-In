# Patch Notes

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
- **Peasant's stats didn't match the design spec** (`scripts/UnitDefinitions/UnitDefinitions.gml`): `maxHealth` 20→10, `attackDamage` 3→2, `cost` was `10 wheat + 5 coins` → now `20 water` (this also brings it in line with `oPeasantWard.trainCost`, which was alrea