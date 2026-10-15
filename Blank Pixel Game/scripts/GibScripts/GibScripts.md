# GibScripts

Gibbing/blood-particle system for all units on death or hit (except Mud Golem, handled separately). Owns the physics for flying debris (`oGibDebris`), spawn helpers that configure one for a specific job (general chunk / a unit's own unique gib / a single-pixel blood particle), the instant (no-physics) blood splatter stamp, and the two orchestrators everything else calls: `SpawnUnitHitBlood` (non-lethal hit) and `SpawnUnitDeathGibs` (death) -- both called from `ApplyDamage` (`UnitCombatHelpers.gml`), the one choke point ALL damage in this game already routes through (melee AND ranged/projectile alike), so hooking there is the only place this needed to be wired in.

Mud Golem is excluded from BOTH orchestrators entirely (hard-exits immediately) per explicit request -- "except the golem, we will handle his" covers hit particles too, not just the death sequence, since he's hit constantly in normal play and the request was clear this should be fully hands-off for him.

Every landed piece of debris (and every instant splatter) gets stamped onto `global.gibSurface` (`oGibSurfaceControl.gml`) and then either destroys itself (debris) or was never a live instance at all (splatter) -- gore accumulates as pixels on one surface, not as a permanently growing pile of live instances.

## Debris physics (oGibDebris)

`GibDebrisStep` -- ground position (x, y) slides via vx/vy, dragged down every step by `GIB_GROUND_FRICTION` (the "flung away from who killed them" half). `z` is a SEPARATE, purely visual height, pulled back down by `GIB_GRAVITY` every step (the "arch" half) -- it never feeds back into x/y. Landing is detected the instant `z` crosses back down through 0 having been above it (guards against triggering on the spawn frame, before the initial "pop" has even been applied) -- at that point `GibDebrisLand` stamps + destroys it.

`GibDebrisDraw` draws at `(x, y - z)` -- the z offset is what makes the arch visible. `kind == "pixel"` draws a flat-color square (same `draw_rectangle` idiom as `oResourceProducedParticle`'s "square" kind); `kind == "sprite"` draws `gibSprite`'s frame with current rotation.

`GibDebrisLand` stamps the debris's current appearance onto `global.gibSurface` at its final resting position, then destroys the instance. No-ops the stamp (still destroys) if the surface has been lost and not yet recreated this frame -- belt-and-suspenders, `oGibSurfaceControl.Step` normally beats every `oGibDebris` to it.

## Spawn helpers

`GibFlingAngle` computes the direction debris should travel: straight out along the line from the killer through the victim, plus random scatter. Falls back to a fully random angle if no attributable killer position is given.

`SpawnGibDebrisSprite` spawns one sprite-kind debris -- used for both the shared `sGeneralChunks` burst and a unit's own unique `gibSprite`. Picks a random frame if the sprite has more than one (general chunks/splatters do; per-unit gibs are single-frame, no-op there).

`SpawnColorPixel` spawns one pixel-kind debris -- a single 1px flat-color dot, randomly interpolated between a dark and bright color (same `merge_color(..., random(1))` idiom `SpawnResourceProducedParticles` uses). Generalized from an earlier `SpawnBloodPixel` (hardcoded to blood-red) so `SpawnBuildingHitParticles`' gray particles can reuse the exact same physics profile -- the `BLOOD_PIXEL_*` physics macro names are stale (kept as-is to avoid an unrelated rename) but now describe "single pixel particle" physics generically, not blood specifically.

`SpawnBloodPixel` is a thin `BLOOD_PIXEL_COLOR_DARK`/`BRIGHT` wrapper around `SpawnColorPixel` -- unchanged signature from before the generalization.

`DrawBloodSplatterInstant` stamps one random `sGeneralSplatters` frame directly onto `global.gibSurface` -- NO live instance, no physics, an instant draw.

## Orchestrators

`SpawnUnitHitBlood(_unit, _source)` -- spawns 2-4 blood pixels at a unit's position on every non-lethal hit. Mud Golem excluded (hard exit).

`SpawnBuildingHitParticles(_building, _source)` -- the building equivalent, 2-4 gray particles on every non-lethal hit, reusing the same pixel-kind physics as blood but in gray tones (buildings don't bleed). No Mud Golem-style exclusion (buildings have no such concept). Reads an optional per-building color override off `BuildingDefinition.hitParticleColorDark`/`Bright`; falls back to the shared gray macros when unset (every building today).

`SpawnUnitDeathGibs(_unit, _source)` -- the full on-death sequence, in order: (1) instant blood splatter, always, including Bomb Goblin; (2) 3-5 general chunks, only if `UnitDefinition.usesGeneralChunks` is true (false only for Bomb Goblin); (3) the unit's own unique gib, only if `UnitDefinition.gibSprite` is registered; (4) 4-8 more blood pixels, always. Mud Golem excluded (hard exit). Must be called BEFORE the caller destroys the unit -- reads `_unit.x`/`_unit.y`/`_unit.object_index`, which need the instance to still exist.

## Macros

`GIB_GRAVITY`/`GIB_GROUND_FRICTION`/`GIB_SPIN_SPEED` -- placeholder physics tuning, not tuned against any real fall-time target. `GIB_FLING_SPEED_MIN/MAX`/`GIB_FLING_SPREAD`/`GIB_POP_MIN/MAX` -- general chunks + unique gibs. `BLOOD_PIXEL_*` -- smaller/quicker/wider-scattering than chunks (see spawn helpers above re: the stale naming). `GIB_HIT_PARTICLE_MIN/MAX` (2-4), `GIB_DEATH_PARTICLE_MIN/MAX` (4-8), `GIB_CHUNK_COUNT_MIN/MAX` (3-5, not spec'd -- picked to read as "a few pieces," not a pile). `BUILDING_HIT_PARTICLE_COLOR_DARK/BRIGHT` -- flat grays, explicit placeholder ("default everything to shades of gray for now"); `BuildingDefinition.hitParticleColorDark/Bright` lets a future pass override per building type without touching this file. `GIB_BUILDING_HIT_PARTICLE_MIN/MAX` (2-4) -- count not spec'd, matched to the unit hit-particle range for a consistent feel.

## API

- `GibDebrisStep(_debris)`, `GibDebrisDraw(_debris)`, `GibDebrisLand(_debris)` -- called from oGibDebris's own Step/Draw events.
- `GibFlingAngle(_x, _y, _sourceX, _sourceY, _spread)`.
- `SpawnGibDebrisSprite(_x, _y, _sourceX, _sourceY, _sprite)`, `SpawnColorPixel(_x, _y, _sourceX, _sourceY, _colorDark, _colorBright)`, `SpawnBloodPixel(_x, _y, _sourceX, _sourceY)`.
- `DrawBloodSplatterInstant(_x, _y)`.
- `SpawnUnitHitBlood(_unit, _source)`, `SpawnBuildingHitParticles(_building, _source)`, `SpawnUnitDeathGibs(_unit, _source)`.
