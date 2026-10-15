# ProjectileScripts

Spawned by ranged units (`UnitTryFireProjectile`, `UnitCombatHelpers.gml`) instead of dealing damage instantly. A projectile's REAL position (`x`/`y`, what everything else in the game sees for collision/logic) travels in a flat straight line from launch point to target point; the parabolic "arcs upward then lands" look is purely cosmetic, applied only in the Draw event (`ProjectileDraw`) as a vertical offset plus a separately-computed rotation. `image_angle` is set once at spawn to the flat straight-line direction and never touched again -- see `ProjectileInit`/`ProjectileDraw` for the split.

Only one projectile type exists so far (`oArcherProjectile`), but this is written generically (`oProjectileParent` + `UnitDefinition.projectileObject`) so future ranged units can register their own without touching this file.

## SpawnProjectile

Spawns a unit's registered projectile object (`UnitDefinition.projectileObject`) at the unit's position, aimed at the target's position at THIS moment (not homing -- see `ProjectileInit`). Snapshots the unit's current `attackDamage` as the projectile's damage, so a later buff/debuff doesn't retroactively change a shot already in flight. Logs and no-ops if the unit's `UnitDefinition` has no `projectileObject` registered.

## ProjectileInit

Sets up a freshly-created projectile's per-instance state -- call once immediately after `instance_create_layer`, same pattern as `BuildingApplyDefinition`/`UnitApplyDefinition`/`TrainingSpawnUnit` (Create sets safe defaults, a script function fills in the real values right after).

`targetPos` is captured ONCE (the target's position at the moment of firing) -- the projectile is not homing. If the target is destroyed mid-flight, the projectile keeps flying to that fixed point and simply finds no one home when it lands (`ProjectileResolveHit`).

`owner` is stored for kill-credit (`ApplyDamage`'s `_source`) and so a stray shot can be attributed to someone even after the owner itself is gone by the time it lands.

Default `_speed` is 240px/sec at 1x match speed, default `_arcHeight` is 24px (Draw-event only, see `ProjectileArcOffset`).

## ProjectileUpdateMovement

Advances the projectile's REAL position a fraction of the way from `startPos` to `targetPos`, straight-line, match-speed-scaled -- same `delta_time`/`global.matchSpeed` idiom as `BuildingUpdateProduction`/`TrainingUpdateQueue`. Resolves the hit (`ProjectileResolveHit`) the instant `progress` reaches 1, including immediately on the same step if `travelTime` is 0 (target was already standing on the launch point). Call once per Step (`oProjectileParent/Step_0.gml`).

## ProjectileResolveHit

Called the moment a projectile reaches the end of its flight. Applies damage via `ApplyDamage` if the target is still around to hit, then destroys the projectile either way -- a target that died mid-flight just means the shot whiffs, it doesn't crash or linger.

## ProjectileArcOffset / ProjectileDraw

`ProjectileArcOffset`: visual-only vertical offset for the parabolic arc -- 0 at launch and landing, peaking at `-arcHeight` (negative = up on screen, since GameMaker's y grows downward) at the midpoint of flight. Purely cosmetic: the real `x`/`y` (what `ProjectileResolveHit` acts on) stay on the flat line the whole flight -- only the DRAWN position is affected.

`ProjectileDraw`: draws the sprite offset by its current arc height, with a rotation that follows the arc's tangent -- steep nose-up at launch, level at the apex, steep nose-down at landing -- instead of the flat stored `image_angle` (which stays the straight-line launch direction for the whole flight). Samples the arc's slope numerically (drawn position a hair further along the flight, vs. right now) rather than differentiating `ProjectileArcOffset` by hand, so the visible angle can never drift out of sync with the visible offset -- they're computed from the exact same function. At the very last frame (`_p1 >= 1`), falls back to the flat stored `image_angle` rather than feeding `point_direction` two identical points (which returns 0, snapping the sprite level right before impact). Call once per Draw (`oProjectileParent/Draw_0.gml`) -- replaces the default sprite draw entirely; this object should NOT also get a default (event-less) draw.

## API

- `SpawnProjectile(_unit, _target)`.
- `ProjectileInit(_proj, _owner, _target, _damage, _speed, _arcHeight)`.
- `ProjectileUpdateMovement(_proj)`.
- `ProjectileResolveHit(_proj)`.
- `ProjectileArcOffset(_proj, _progress)`, `ProjectileDraw(_proj)`.
