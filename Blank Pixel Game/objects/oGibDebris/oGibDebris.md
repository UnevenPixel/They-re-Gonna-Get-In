# oGibDebris

2026-07-12 request ("set up gibbing"). Generic flying-then-landing debris object -- general chunks, a unit's own unique gib, and single-pixel blood particles all reuse this ONE object, just spawned with different fields. See `SpawnGibDebrisSprite`/`SpawnBloodPixel` (`GibScripts.gml`), which always set every field below immediately after `instance_create_layer`, same "Create sets placeholders, the spawning function fills in the real ones right after" pattern as `oResourceProducedParticle`.

## Create_0

- `kind`: `"sprite"` (chunk/unique gib, drawn with rotation) or `"pixel"` (blood particle, flat-color dot).
- `gibSprite`: sprite_index to draw when `kind == "sprite"`.
- `frame`: picked once at spawn -- which frame of `gibSprite` (`sGeneralChunks`/`sGeneralSplatters` have several variants, per-unit gibs have just one).
- `angle`: current draw rotation, degrees -- frozen at whatever it is the instant this lands.
- `spinSpeed`: degrees/step at 1x match speed, `kind == "sprite"` only.
- `pixelColor`/`pixelSize`: `kind == "pixel"` only.

**Fake-gravity arc physics** (full model in `GibDebrisStep`, `GibScripts.gml`): `x`/`y` is the real ground position (slides via `vx`/`vy`, dragged to a stop by `GIB_GROUND_FRICTION` -- the "flung away from who killed them" component); `z`/`vz` is a SEPARATE visual-only height (pulled down by `GIB_GRAVITY` -- the "arc" component, drawn as a y-offset, never affecting the real ground position). Landing is detected purely off `z` crossing back down through 0.

## Step_0 / Draw_0

`GibDebrisStep(id)` / `GibDebrisDraw(id)` -- both delegate entirely to `GibScripts.gml`.
