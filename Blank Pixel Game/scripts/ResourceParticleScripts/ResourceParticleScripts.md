# ResourceParticleScripts

The little burst of particles a resource building fires off every time it produces one whole unit of its resource. One particle shows the actual resource's icon (`sResourceIcons`, via `ResourceIconIndex` -- see `ResourceUIScripts.gml`); the rest are tiny 1-2px squares colored somewhere between gold and white, for sparkle around the real icon. Both particle "kinds" are handled by one object (`oResourceProducedParticle`) rather than two, since they share identical drift/gravity/fade/self-destroy behavior and differ only in what Draw does with them -- see that object's Create/Step/Draw.

Wired from `PlayResourceProducedEffect` (`BuildingDefinitions.gml`), which `BuildingUpdateProduction` already calls exactly once per whole unit produced (even when several are produced in one frame).

## SpawnResourceProducedParticles

Spawns one icon particle (the resource's `sResourceIcons` frame) plus `RESOURCE_PARTICLE_SQUARE_COUNT` tiny square particles (1-2px, color randomly interpolated between `RESOURCE_PARTICLE_GOLD_COLOR` and `c_white`) at the building's position. The icon particle drifts straight up; squares burst outward at a random angle/speed with a slight upward bias, then gravity takes over. All particles fade out and self-destroy after `RESOURCE_PARTICLE_LIFE` steps.

No-ops the icon particle specifically (squares still spawn) if `_resource` isn't one of the 10 base resources `sResourceIcons` covers -- e.g. xp/fateTokens have no icon (see `ResourceIconIndex`).

## API

- `RESOURCE_PARTICLE_SQUARE_COUNT`, `RESOURCE_PARTICLE_LIFE`, `RESOURCE_PARTICLE_SPEED_MIN`, `RESOURCE_PARTICLE_SPEED_MAX`, `RESOURCE_PARTICLE_GRAVITY`, `RESOURCE_PARTICLE_GOLD_COLOR`.
- `SpawnResourceProducedParticles(_building, _resource)`.
