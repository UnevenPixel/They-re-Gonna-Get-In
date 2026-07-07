// Depth-sort override -- most instances in this project use depth = -y
// (see oUnitParent/Step_0.gml) so lower-on-screen draws in front of
// higher-up. That only ever ranges from -room_height to 0, so pushing
// particles past the most-negative end of that range (2026-07-06 request)
// guarantees they draw on top of everything depth = -y sorted, regardless
// of where in the room they spawn.
depth = -room_height - 1;

// Defensive defaults -- SpawnResourceProducedParticles
// (ResourceParticleScripts.gml) always sets these immediately after
// instance_create_layer, same "Create sets placeholders, the spawning
// function fills in the real ones right after" pattern as buildings/
// projectiles elsewhere in this project (see BuildingApplyDefinition,
// ProjectileInit).
kind          = "square"; // "icon" (shows a sResourceIcons frame) or "square" (flat-color tiny square)
resourceIndex = 0;        // sResourceIcons frame -- only used when kind == "icon"
color         = c_white;  // only used when kind == "square"
squareSize    = 1;        // px -- only used when kind == "square"
vx            = 0;
vy            = 0;
life          = 1;
lifeMax       = 1;
