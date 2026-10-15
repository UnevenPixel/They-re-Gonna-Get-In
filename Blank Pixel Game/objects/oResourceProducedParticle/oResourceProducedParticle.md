# oResourceProducedParticle

Both particle "kinds" of the resource-produced burst (`SpawnResourceProducedParticles`, `ResourceParticleScripts.gml`) -- one icon particle, several sparkle squares -- share this one object.

## Create_0

`depth = -room_height - 1` -- most instances in this project use `depth = -y` (ranging `-room_height` to 0, see `oUnitParent/Step_0.gml`, lower-on-screen draws in front); pushing particles past the most-negative end of that range (2026-07-06) guarantees they draw on top of everything depth-sorted, regardless of where in the room they spawn.

Defensive placeholder defaults (`kind`/`resourceIndex`/`color`/`squareSize`/`vx`/`vy`/`life`/`lifeMax`) -- `SpawnResourceProducedParticles` always sets these immediately after `instance_create_layer`, same "Create sets placeholders, the spawning function fills in the real ones right after" pattern as buildings/projectiles elsewhere (`BuildingApplyDefinition`, `ProjectileInit`).

## Step_0

Drifts, gently gathers downward gravity (`RESOURCE_PARTICLE_GRAVITY`), fades, then self-destroys once `life` runs out. Scaled by `global.matchSpeed` like every other timed/animated thing in this project, so effects pause along with the match instead of continuing to animate at 0x speed.

## Draw_0

Icon particles show the actual resource's `sResourceIcons` frame; square particles are a small flat-color square. Both fade out over their lifetime (`life`/`lifeMax`) rather than popping out abruptly.
