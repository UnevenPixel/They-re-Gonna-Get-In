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
