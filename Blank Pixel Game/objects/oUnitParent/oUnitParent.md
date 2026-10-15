# oUnitParent

Base object for every unit type (`oPeasantUnit`, `oArcherUnit`, etc. all inherit this). Sets up the FSM, steering agent, and live combat state; per-type stats are applied afterward by `UnitApplyDefinition`.

**Load-bearing** (per CLAUDE.md -- this is where guard/defend/combat/attack/siege state wiring actually happens): `Create_0` registers every FSM state (`fsm.AddState(...)` for guard/defend/combat/combatRanged/attack/attackRanged/siege/station) and starts in "guard". Flag before touching this registration.

## Create_0

`unitData = new UnitDataBlock()`, `team = TEAM.PLAYER` (default, overridden by spawn paths like `TrainingSpawnUnit`/`DeployStationedUnit`/`StationSpawnDirectly`), `wanderWait = true`.

**HAZARD, load-bearing**: `guardRect = GetTeamGuardRect(team)` is derived from `team` AT THIS MOMENT -- always the `TEAM.PLAYER` default, since `instance_create_layer()` runs Create synchronously before the caller gets a chance to override `team`. Any future spawn path that creates a unit then overrides `team` afterward MUST also recompute `guardRect = GetTeamGuardRect(team)` afterward (see `TrainingSpawnUnit` for the pattern), and must ensure nothing team-dependent (a guard waypoint, a patrol side) gets picked before that correction lands.

FSM states registered: `"guard"` (`Guard_Enter/Step/Draw/Exit`), `"defend"` (`Defend_Enter/Step`, no Draw, `Defend_Exit`), `"combat"`, `"combatRanged"` (ranged counterpart to "combat", see `UnitStateCombatRanged.gml`; dispatched by `UnitEnterCombat` for "ranged"-tagged units), `"attack"`, `"attackRanged"` (ranged counterpart to "attack", see `UnitStateAttackRanged.gml`; dispatched by the "attack" order for "ranged"-tagged units), `"siege"`, `"station"` (walks to the unit's own castle then hands off to `UnitBecomeStationed`, dispatched by the "station" order). Starts in `"guard"`.

`agent`/`controller` (`SteeringAgent`/`SteeringController`) -- `maxSpeed`/`maxForce`/`mass` passed here are placeholders; `UnitApplyDefinition` overwrites `agent.maxSpeed` afterward.

Live/runtime combat state only (`combatTarget`, `attackCooldown`, `attackBuildingTarget`) -- base stats (attackRange/attackDamage/attackCooldownMax/sprites/availableOrders/etc.) come from the unit's `UnitDefinition`, applied by `UnitApplyDefinition` at the bottom of this event.

`pendingSelfDestruct = false` (2026-07-12, "update the Bomb Goblin to die when it explodes") -- generic on every unit (cheap bool, harmless default) rather than a Bomb-Goblin-only field, so `UnitTryDealDamage` can set it unconditionally without a `variable_instance_exists` guard. Consumed (and reset) in `Step_0` AFTER `fsm.Step()` -- see that event and `UnitTryDealDamage`'s doc comment for why it can't be acted on synchronously the instant it's set.

**`guardWaypointClaimed` is intentionally NOT initialized here, load-bearing**: `Guard_Enter` (`UnitStateGuard.gml`) already sets it the moment `fsm.ChangeState("guard")` runs above; `Guard_Step`/`Guard_Exit` own it from there. A stray `guardWaypointClaimed = undefined;` used to sit here and clobber that value right after `Guard_Enter` set it, which caused a real crash (a sibling unit's clobbered `undefined` claim got read as a Vector2 by another unit's `GuardPickWaypoint`). **Do not re-add an assignment here.**

`UnitApplyDefinition(self)` resolves this unit's `UnitDefinition` (keyed by `object_index`, so it correctly picks up `oPeasantUnit`/etc. even though this is running as `oUnitParent`'s inherited Create code) and applies every static stat -- must run after fsm/agent/unitData above, and after `RegisterAllUnitDefinitions()` has run at game start.

## Step_0

`depth = -y` (standard y-sort). `fsm.Step()`.

`pendingSelfDestruct` handling (2026-07-12) runs AFTER `fsm.Step()` has fully finished this frame -- see `UnitTryDealDamage`'s doc comment for why it can't destroy the unit synchronously the instant its swing lands. Self-damage for `maxHealth` (not a raw `instance_destroy`) so it goes through `ApplyDamage`'s normal lethal branch -- `SpawnUnitDeathGibs`, Strategic XP for the losing team, analytics -- same bookkeeping as any other death, just self-inflicted. `_source` is `noone`, not `id`, so no team is credited Combat XP for "killing" its own unit.

## Draw_0

Selection mask draw (shadow + selection ring) gated on `mask_index == sM_UnitMask`, checking membership in `oUnitControl.selectionController.selected`.

`PaletteSwapDrawUnit(id)` (2026-07-10): `TEAM.ENEMY` units with a registered palette (`UnitDefinition.palette`) draw recolored via `shPaletteSwap`; everyone else (`TEAM.PLAYER`, or any unit without a palette yet) draws exactly as before.

`fsm.Draw()`.
