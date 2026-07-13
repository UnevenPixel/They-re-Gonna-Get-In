# GibScripts

Gibbing/blood-particle system: on-hit blood pixels, on-death chunks/unique gib/splatter/blood pixels, and the shared "fake gravity arc, land, stamp to a persistent surface" physics behind all of it. 2026-07-12 request.

## Core idea

Every "gore" system in this game (`oGibDebris`) shares ONE physics model: a real ground position (`x, y`) that slides via `vx, vy` with friction (the "flung away from who killed them" component), and a purely visual height (`z, vz`) that pops up and falls back down under fake gravity (the "arch" component). Landing — `z` crossing back through 0 — is "stopped moving": the debris stamps its current appearance onto a persistent surface (`global.gibSurface`, owned by `oGibSurfaceControl`) and destroys itself. Blood splatters skip all of this and stamp instantly, no live instance at all.

Everything is wired into `ApplyDamage` (`UnitCombatHelpers.gml`) — the single choke point every damage source (melee AND ranged/projectile) already routes through — so no other combat file needed to change.

**Mud Golem is excluded from the entire system** (hit particles AND death gibs), per explicit request ("we will handle his").

## API

### `oGibSurfaceControl` (object, one instance per match)

Owns `global.gibSurface` (`surface_create(room_width, room_height)`), recreates it if lost (`Step`), and draws it (`Draw`) at `depth = room_height + 1` (positive, changed 2026-07-12 follow-up) — since `depth = -y` for every y-sorted instance in this project only ever ranges `-room_height` to `0`, any positive depth draws BEFORE all of them, so the gib surface now renders behind units/buildings instead of on top.

### `oGibDebris` (object, one instance per flying chunk/gib/blood pixel)

Fields set by the spawn helpers below (not meaningful before that): `kind` (`"sprite"` or `"pixel"`), `gibSprite`/`frame`/`angle`/`spinSpeed` (kind `"sprite"`), `pixelColor`/`pixelSize` (kind `"pixel"`), `vx`/`vy`/`z`/`vz` (physics).

- `GibDebrisStep(_debris)` — one step of the physics model above. Called from the object's own Step event.
- `GibDebrisDraw(_debris)` — draws at `(x, y - z)`. Called from the object's own Draw event.
- `GibDebrisLand(_debris)` — stamps onto `global.gibSurface` at the final `(x, y)`, then `instance_destroy`s. Called internally by `GibDebrisStep` the instant `z` lands back at 0.

### Spawn helpers

- `GibFlingAngle(_x, _y, _sourceX, _sourceY, _spread)` → direction (degrees) along the killer→victim line, +/- random `_spread`. Falls back to a fully random angle if `_sourceX` is `undefined` (no attributable killer).
- `SpawnGibDebrisSprite(_x, _y, _sourceX, _sourceY, _sprite)` → one sprite-kind `oGibDebris` (random frame/rotation/spin, `GIB_FLING_*`/`GIB_POP_*` physics range). Used for both the shared `sGeneralChunks` burst and a unit's own unique gib.
- `SpawnColorPixel(_x, _y, _sourceX, _sourceY, _colorDark, _colorBright)` → one pixel-kind `oGibDebris` (`BLOOD_PIXEL_*` physics range — the name is now stale/generic, describes "single pixel particle" physics, not blood specifically — color randomly interpolated `_colorDark`→`_colorBright`). Added 2026-07-12 follow-up as the generalized base under `SpawnBloodPixel`.
- `SpawnBloodPixel(_x, _y, _sourceX, _sourceY)` → thin `SpawnColorPixel` wrapper fixed to `BLOOD_PIXEL_COLOR_DARK`→`BRIGHT` (red tones). Unchanged signature/behavior from before the generalization.
- `DrawBloodSplatterInstant(_x, _y)` → stamps a random `sGeneralSplatters` frame straight onto `global.gibSurface`, no instance, no physics.

### Orchestrators (call these; everything above is plumbing)

- `SpawnUnitHitBlood(_unit, _source)` — non-lethal unit hit: `GIB_HIT_PARTICLE_MIN`-`MAX` (2-4) blood pixels. Called from `ApplyDamage`'s non-lethal branch (unit case). Hard-exits immediately if `_unit.object_index == oMudGolemUnit`.
- `SpawnUnitDeathGibs(_unit, _source)` — death: instant splatter (always) → `GIB_CHUNK_COUNT_MIN`-`MAX` (3-5) general chunks (only if `UnitDefinition.usesGeneralChunks`) → the unit's own unique gib (only if `UnitDefinition.gibSprite` is set) → `GIB_DEATH_PARTICLE_MIN`-`MAX` (4-8) blood pixels. Called from `ApplyDamage`'s lethal branch, BEFORE `instance_destroy` (reads `_target.x`/`y`/`object_index`). Hard-exits immediately if `_unit.object_index == oMudGolemUnit`.
- `SpawnBuildingHitParticles(_building, _source)` — non-lethal building hit, added 2026-07-12 follow-up ("add grey particles to buildings when they are hit"): `GIB_BUILDING_HIT_PARTICLE_MIN`-`MAX` (2-4) single-pixel particles via `SpawnColorPixel`, gray by default (`BUILDING_HIT_PARTICLE_COLOR_DARK`/`BRIGHT`) unless `BuildingDefinition.hitParticleColorDark`/`hitParticleColorBright` is set for that building type (both `undefined` today — every building uses the shared gray). Called from `ApplyDamage`'s non-lethal branch (building/else case). No death-particle equivalent exists for buildings — the request only covered hits, not destruction.

### Per-unit data (`UnitDefinitions.gml`)

- `UnitDefinition.gibSprite` — this unit's unique on-death gib sprite, or `undefined`. Set for Peasant/Soldier/Archer/Knight (`sPeasantGib`/`sSoldierGib`/`sArcherGib`/`sKnightGib`). Not set for Bomb Goblin (no sprite exists) or Mud Golem (excluded entirely).
- `UnitDefinition.usesGeneralChunks` — `true` by default; `false` only for Bomb Goblin (already has its own explosion animation, no unique gib sprite either — general debris would look mismatched).

### Per-building data (`BuildingDefinitions.gml`)

- `BuildingDefinition.hitParticleColorDark` / `hitParticleColorBright` — optional per-building-type override for `SpawnBuildingHitParticles`' color range. Both `undefined` for every registered building today (falls back to the shared gray macros) — placeholder for a future pass giving each building type its own color, per the request ("we will make specific color coded particles for each building later").

## Usage

```gml
// ApplyDamage (UnitCombatHelpers.gml), non-lethal branch
if (variable_instance_exists(_target, "fsm")) {
    SpawnUnitHitBlood(_target, _source);
}

// ApplyDamage, lethal branch, BEFORE instance_destroy(_target)
if (variable_instance_exists(_target, "fsm")) {
    SpawnUnitDeathGibs(_target, _source);
}
```

## Known assumptions / scope limits (flag if wrong)

- Mud Golem excluded from BOTH hit particles and death gibs, not just death -- explicit 2026-07-12 clarification ("we will handle his" covers everything this pass).
- Chunk count (3-5) isn't specified by the request ("most all units") -- picked to read as "a few pieces," not a pile. Same for the exact `GIB_*`/`BLOOD_PIXEL_*` physics constants -- all placeholders, not tuned.
- "When they stop moving" is interpreted as "the vertical arc (`z`) has completed" -- the ground-plane slide (`vx`/`vy`) keeps decaying independently via friction and is never separately checked against a stop threshold. In practice friction is high enough that horizontal motion is negligible by the time the arc lands, but it's not an exact "both velocities near zero" check.
- Lost-surface recovery (`oGibSurfaceControl.Step`) recreates a BLANK surface -- every gib stamped before the loss is gone. No persistence-across-loss was requested; flag if that turns out to matter in practice (e.g. frequent window resizing during play).
- Splatters/chunks/pixels are stamped at the dying/hit unit's raw `(x, y)` (typically feet position) -- no per-unit offset tuning.
