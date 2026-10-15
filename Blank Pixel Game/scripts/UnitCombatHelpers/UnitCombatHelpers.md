# UnitCombatHelpers

Shared damage-application and melee/ranged attack-swing helpers, called from unit FSM states (guard/defend/attack/siege/combat) but not itself part of the flagged state-wiring files.

## ApplyDamage

The one real damage-application function in the codebase -- both melee (`UnitTryDealDamage`) and ranged (`ProjectileResolveHit`, `ProjectileScripts.gml`) route through this rather than touching health directly. Works against units AND buildings (both carry `maxHealth` + `damageTaken`, see `GetDamageTaken`/`UnitDefinitions.gml` for where each stores it).

Damage is tracked ONLY as `damageTaken`, never a separate "current health" field -- `maxHealth` can change later (a buff/debuff, a station/redeploy swap reapplying a `UnitDefinition`) without having to rewrite a second number in lockstep. `GetCurrentHealth` always derives the live value fresh from `maxHealth - damageTaken`, one source of truth. `damageTaken` is clamped to `maxHealth` so it can never overshoot into "more dead than dead."

Resets `_target.noDamageTimer` to 0 on any hit, lethal or not, if that field exists -- generic hook for `oPlayerCastle`/`oEnemyCastle`'s "no damage for 120s" Defensive XP timer (`CastleScripts.gml`); harmless no-op for anything else.

Destroys `_target` the instant its health reaches 0 -- the first place in the codebase anything can actually die. Closes the loop on `AnalyticsRecordKill`/`AnalyticsRecordDeath` and awards XP per the "XP Age Progression System" design doc:

- **Unit target** (has `fsm`): the LOSING team always gets `STRATEGIC_XP_LOSE_UNIT`, regardless of `_source`. If `_source` is a valid, team-tagged killer, its team also gets Combat XP scaled by the victim's `UnitDefinition.tier` (`COMBAT_XP_TIER_1/2/3`).
- **Building target** (no `fsm`): if `_source` is a valid killer, its team gets `COMBAT_XP_STRUCTURE`, PLUS `COMBAT_XP_RESOURCE_BLDG` on top (not instead of) if the building is also an `oResourceBuildingParent` (confirmed stacking, +10 total). The killer, if on a DIFFERENT team than the building (no reward for self-destruction), also receives one blueprint of the destroyed building's own type (`AddBlueprint`) -- "prevents lockouts where neither side can get blueprints." No-ops if the building type isn't actually registered (`GetBuildingDefinition` returns undefined for `oPlayerCastle`/`oEnemyCastle` -- destroying a castle correctly grants nothing rather than creating a permanently-stuck blueprint slot).

Economic XP ("resource building depletes naturally") is NOT wired anywhere -- no depletion mechanic exists yet.

Non-lethal hits also drive combat's reactive-on-hit trigger: combat is an interim state guard/defend pop into when they need to fight, alongside the proximity-aggro trigger in `Guard_Step`/`Defend_Step` (see `UnitEnterCombat` below). Only fires if `_target` is a unit currently in "guard" or "defend"; a unit already fighting just keeps doing what it was doing.

Gib/particle hooks (the first on-hit/on-death visual hooks in this codebase): every non-lethal hit against a UNIT spawns 2-4 blood pixels (`SpawnUnitHitBlood`, `GibScripts.gml`); a non-lethal hit against a BUILDING spawns 2-4 gray placeholder particles (`SpawnBuildingHitParticles`). The instant a unit dies, BEFORE `instance_destroy`, it gets the full gib sequence (`SpawnUnitDeathGibs`) -- splatter + general chunks + its own unique gib + 4-8 more blood pixels. Both hit and death hooks hard-exit immediately for Mud Golem specifically (excluded entirely per explicit request -- see `GibScripts.gml`).

## UnitEnterCombat / UnitRevertFromCombat

`UnitEnterCombat` is the shared entry point for both of combat's triggers (proximity aggro, checked every step via `_FindNearestEnemy` in `Guard_Step`/`Defend_Step`; reactive-on-hit, from `ApplyDamage`). Picks "combat" or "combatRanged" based on the unit's "ranged" tag -- same `UnitHasTag` dispatch the "attack" order uses to pick "attack" vs "attackRanged".

`UnitRevertFromCombat` is the shared "combat is done -- go back to whatever guard/defend was interrupted" exit path. Combat is only ever entered via `UnitEnterCombat`, called from guard/defend, so `_machine.previousName` is always "guard" or "defend" at that point -- `RevertToPrevious` goes back to exactly that. Falls back to "guard" in the (should-never-happen) case combat was entered with no recorded previous state, so a unit can never get stuck in combat forever.

## UnitTryDealDamage / UnitTryFireProjectile

The single melee damage choke point -- attack-vs-building, attack's DEFENDER sub-phase vs a unit, combat, AND siege all route through `UnitTryDealDamage` (see each state's own file), so bonus-damage logic lives here rather than in any one state:

- Knight's `productionBuildingDamageBonus` (+50%) applies when `_target` is an `oResourceBuildingParent` (production building only, not training buildings or the castle), per its own flavor text.
- Bomb Goblin sets `_unit.pendingSelfDestruct = true` the instant its swing connects, instead of destroying it synchronously here -- this function runs INSIDE the attacking unit's own FSM step (`_unit == id`), and every caller keeps reading `_unit`'s fields immediately after this call returns (`UnitAttackAnimComplete`, `UnitEndSwing`, etc.); destroying it here would run that code against an already-destroyed instance. The flag is consumed AFTER `fsm.Step()` finishes for the frame, in `oUnitParent/Step_0.gml`, once it's safe.

Knockback on hit is not implemented -- left as a TODO in the code (the shape it would take: apply `_target.agent.ApplyKnockback` along the attacker-to-target direction, scaled by a knockback-strength value that doesn't exist yet).

`UnitTryFireProjectile` is the ranged counterpart -- same once-per-swing/hit-frame gating, but spawns a projectile (`SpawnProjectile`, `ProjectileScripts.gml`) aimed at `_target` instead of applying damage immediately. Damage resolves later, when the projectile arrives (`ProjectileResolveHit`), not the frame this returns true.

## UnitPursueTarget / UnitIdleInPlace

`UnitPursueTarget` is the standard pursue + separation + obstacle avoidance + play area containment bundle, reused across combat/attack/siege/defend pursuit phases. Calls `UnitUpdateSprite` after movement. `_feelerLength` defaults to 80 except where a caller (Siege's ADVANCE phase) opts into a longer one -- that's a long, deliberate march across open ground where units were reported getting snagged on buildings; earlier obstacle detection gives the avoidance logic more room to curve around smoothly instead of reacting at the last moment, which is what tends to catch on corners. `oBuildingParent` is deliberately absent from the `move_and_collide` collision list -- units no longer physically collide with buildings, only real static geometry (`oEnvironmentSolid`); `Steering_AvoidObstacles` still sees buildings and steers around them cosmetically, so a unit can clip through one if avoidance doesn't fully route around it (accepted as harmless).

`UnitIdleInPlace` idles in place (zero steering, still applies knockback/collision). Brakes the agent first (`SteeringAgent.Brake`) -- "zero steering" does NOT mean "zero speed" on its own: `Begin()`/`Apply()` with no `Add()` calls leaves `agent.velocity` completely untouched (every `Steering_*` behavior decelerates by computing desired-minus-velocity, but doing nothing provides no opposing force at all), so without braking, a unit arriving here with leftover momentum just keeps gliding indefinitely. This fixed siege units sliding into/through the castle wall after reaching attack range instead of stopping to fight, and the same latent issue for every other caller (attack/attackRanged/combat/combatRanged).

## UnitBeginSwing / UnitEndSwing

`UnitBeginSwing` enters the attack animation and resets swing tracking -- deliberately does NOT touch `image_xscale`, so the unit keeps facing whatever direction it was already facing when the swing started. `UnitEndSwing` restores the idle sprite and writes cooldown back to the instance; call at the end of any swing and from all Exit callbacks.

## XP macros

`COMBAT_XP_TIER_1/2/3` (1/3/5), `COMBAT_XP_STRUCTURE` (5), `COMBAT_XP_RESOURCE_BLDG` (5, additional/stacking on top of `COMBAT_XP_STRUCTURE`), `STRATEGIC_XP_LOSE_UNIT` (1, to the losing team on every unit death) -- from the "XP Age Progression System" design doc.

## API

- `ApplyDamage(_target, _amount, _source)` -- returns true if this call killed `_target`.
- `UnitEnterCombat(_unit, _target)`, `UnitRevertFromCombat(_machine)`.
- `UnitTryDealDamage(_unit, _target, _machine)`, `UnitTryFireProjectile(_unit, _target, _machine)`.
- `UnitAttackAnimComplete(_unit)`.
- `UnitPursueTarget(_unit, _targetPos, _targetVelocity, _feelerLength)`, `UnitIdleInPlace(_unit)`.
- `UnitBeginSwing(_unit, _machine)`, `UnitEndSwing(_unit, _machine)`.
